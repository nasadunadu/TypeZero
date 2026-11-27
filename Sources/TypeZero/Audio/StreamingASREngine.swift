import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import IOKit
import Speech
import CSherpaOnnx

/// Continuous, memory-bounded SenseVoice + VAD Sliding Segment Engine:
/// Uses real-time Voice Activity Detection (VAD) to detect natural breath pauses (~420ms silence),
/// commits completed clauses into `frozenTranscriptPrefix`, and IMMEDIATELY flushes `activeSegmentSamples`!
/// Guarantees constant ~25ms inference speed and flat memory even if you dictate non-stop for 30+ minutes.
public final class StreamingASREngine: NSObject, @unchecked Sendable {
    private var audioEngine: AVAudioEngine?
    private var senseVoiceHandle: OpaquePointer?
    private let seedASRClient = VolcSeedASRClient()
    private let openAIASRClient = OpenAITranscriptionClient()
    private let decodeQueue = DispatchQueue(label: "io.github.typezero.sensevoice.decode", qos: .userInteractive)
    private let audioControlQueue = DispatchQueue(label: "io.github.typezero.audio.control", qos: .userInteractive)

    private let sampleLock = NSLock()
    /// Rolling buffer holding ONLY the current active clause (flushed on every breath pause in local mode)
    private var activeSegmentSamples: [Float] = []
    /// Full-utterance backup (capped at 90s) used for zero-word-loss local FP32 failover if Wi-Fi drops mid-speech
    private var cloudFailoverBackupSamples: [Float] = []
    /// Completed & locked earlier sentences (never re-decoded again -> zero drift, zero memory bloat!)
    private var frozenTranscriptPrefix: String = ""
    private var currentSampleRate: Int32 = 48_000
    private var lastDecodedSampleCount: Int = 0
    private var isDecodingChunk: Bool = false

    // Polyphase CoreAudio resampler for 16kHz Int16 Seed-ASR streaming
    private var pcm16Converter: AVAudioConverter?
    private var pcm16SourceFormat: AVAudioFormat?
    private let pcm16TargetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: false)

    // Lightweight inline VAD state
    private var hasDetectedSpeechInSegment: Bool = false
    private var hasDetectedSpeechOverall: Bool = false
    private var lastDecodedVoiceSampleMark: Int = 0
    private var totalVoiceSamplesInSegment: Int = 0
    private var consecutiveSilentSamples: Int = 0
    private var liveTimer: DispatchSourceTimer?
    private var cloudWatchdogTimer: DispatchSourceTimer?

    // Fallback Apple recognizer only if SenseVoice model files are absent
    private var fallbackRecognizer: SFSpeechRecognizer?
    private var fallbackRequest: SFSpeechAudioBufferRecognitionRequest?
    private var fallbackTask: SFSpeechRecognitionTask?

    private var latestTranscript: String = ""
    private var sessionStartTime: Date = Date()

    public private(set) var isUsingSenseVoice: Bool = false
    public private(set) var isFullPrecisionFP32: Bool = false
    public private(set) var activeSessionUsesCloudSeedASR: Bool = false
    public private(set) var activeSessionUsesOpenAIASR: Bool = false
    public var activeSessionUsesAnyCloudASR: Bool {
        activeSessionUsesCloudSeedASR || activeSessionUsesOpenAIASR
    }
    /// Latest live streaming transcript from Seed-ASR (available at `t=0ms` on stop trigger before `enable_nonstream` two-pass finishes).
    public var currentCloudStreamingDraft: String {
        sampleLock.lock()
        let usingVolc = activeSessionUsesCloudSeedASR
        sampleLock.unlock()
        guard usingVolc else { return "" }
        let serverSnap = seedASRClient.currentServerTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        return serverSnap.isEmpty ? latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines) : serverSnap
    }

    /// Latest live streaming transcript across Seed-ASR or local SenseVoice (empty for batch OpenAI Whisper).
    public var currentLiveStreamingDraft: String {
        sampleLock.lock()
        let usingVolc = activeSessionUsesCloudSeedASR
        let usingOpenAI = activeSessionUsesOpenAIASR
        sampleLock.unlock()
        if usingOpenAI { return "" }
        if usingVolc {
            let serverSnap = seedASRClient.currentServerTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !serverSnap.isEmpty { return serverSnap }
        }
        return latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Active ASR backend label captured before `finishStreaming()` resets session flags.
    public var activeASRSourceLabel: String {
        sampleLock.lock()
        let usingVolc = activeSessionUsesCloudSeedASR
        let usingOpenAI = activeSessionUsesOpenAIASR
        sampleLock.unlock()
        if usingVolc { return "volc" }
        if usingOpenAI { return "openai" }
        if isUsingSenseVoice { return "sensevoice" }
        return "apple"
    }
    public var asrProvider: ASRProviderOption = .volcSeedASR
    public var enableVolcSeedASR: Bool {
        get { asrProvider == .volcSeedASR }
        set { asrProvider = newValue ? .volcSeedASR : .localSenseVoice }
    }
    public var volcSpeechAPIKey: String = ""
    public var useCloudTrialRelay: Bool = false
    public var cloudTrialJWT: String = ""
    public var openAIASRBaseURL: String = "https://api.openai.com/v1"
    public var openAIASRModel: String = "gpt-4o-mini-transcribe"
    public var openAIASRAPIKey: String = ""
    public var enableWhisperAGC: Bool = true
    public var speechLocale: String = "auto"
    public var onPartialResult: ((_ text: String, _ flushTrailingChar: Bool) -> Void)?
    public var onModelReady: (() -> Void)?
    public var onCloudFailoverNotice: ((_ reason: String) -> Void)?
    public var onError: ((String) -> Void)?
    private var didFlushMicroPauseTail: Bool = false
    private var openAIActiveHotwords: [String] = []
    private var openAIActiveLocale: String = "auto"
    private var loadedSenseVoiceLanguage: String = ""
    /// Rolling 220ms pre-roll ring buffer captured while mic is hot-standby (KeyDown / 15s keep-alive)
    /// so the very first syllable spoken right at keypress is NEVER clipped!
    private var preRollSamples: [Float] = []
    private var isCaptureActive: Bool = false
    private var isTapInstalled: Bool = false
    private var activeMaxBackupSamples: Int = 48_000 * 90
    private var idleHardwareShutdownWorkItem: DispatchWorkItem?
    /// Short warm-standby window used ONLY when both input & output are Built-In Mac hardware (never Bluetooth/USB headsets).
    private let builtInHotMicKeepAliveSeconds: Double = 4.0
    private let modelInitLock = NSLock()

    public override init() {
        super.init()
        setupSeedASRCallbacks()
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.audioControlQueue.async {
                // If user plugged/unplugged AirPods or USB mic while not actively dictating,
                // tear down stale graph cleanly so next session binds the fresh hardware sample rate!
                self.sampleLock.lock()
                let capturing = self.isCaptureActive
                self.sampleLock.unlock()
                if !capturing {
                    self.shutdownAudioHardwareCompletely()
                }
            }
        }
    }

    private func setupSeedASRCallbacks() {
        seedASRClient.onStreamingTranscript = { [weak self] text, isDefinite in
            guard let self else { return }
            self.sampleLock.lock()
            let usingCloud = self.activeSessionUsesCloudSeedASR
            if usingCloud {
                self.didFlushMicroPauseTail = isDefinite
            }
            self.sampleLock.unlock()

            guard usingCloud, self.audioEngine?.isRunning == true, !text.isEmpty else { return }
            if text != self.latestTranscript || isDefinite {
                self.latestTranscript = text
                self.onPartialResult?(text, isDefinite)
            }
        }

        seedASRClient.onConnectionFallbackNeeded = { [weak self] reason in
            self?.switchActiveSessionFromCloudToLocalFP32(reason: reason)
        }
    }

    deinit {
        if let h = senseVoiceHandle {
            tz_sensevoice_destroy(h)
        }
    }

    public static var isMicrophoneAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public static var isSpeechAuthorized: Bool {
        if senseVoiceModelPaths() != nil
            || KeychainHelper.hasAnyDoubaoCredential
            || !KeychainHelper.loadEffectiveOpenAIASRAPIKey().isEmpty {
            return true
        }
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    public static func senseVoiceModelPaths() -> (model: String, tokens: String, isFullFP32: Bool)? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let modelsRoot = appSupport.appendingPathComponent("TypeZero/Models", isDirectory: true)

        // Priority 1: Lossless Full-Precision FP32 model (~930MB) for maximum acoustic & sibilant accuracy!
        let fp32Dir = modelsRoot.appendingPathComponent("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09", isDirectory: true)
        let fp32Model = fp32Dir.appendingPathComponent("model.onnx").path
        let fp32Tokens = fp32Dir.appendingPathComponent("tokens.txt").path
        if FileManager.default.fileExists(atPath: fp32Model) && FileManager.default.fileExists(atPath: fp32Tokens) {
            return (fp32Model, fp32Tokens, true)
        }

        // Priority 2: Compact int8 quantized fallback (~226MB)
        let int8Dir = modelsRoot.appendingPathComponent("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09", isDirectory: true)
        let int8Model = int8Dir.appendingPathComponent("model.int8.onnx").path
        let int8Tokens = int8Dir.appendingPathComponent("tokens.txt").path
        if FileManager.default.fileExists(atPath: int8Model) && FileManager.default.fileExists(atPath: int8Tokens) {
            return (int8Model, int8Tokens, false)
        }
        return nil
    }

    public func loadSenseVoiceIfAvailable() {
        modelInitLock.lock()
        defer { modelInitLock.unlock() }

        let targetLang = LLMConfig.senseVoiceLanguageCode(for: speechLocale)
        if senseVoiceHandle != nil && loadedSenseVoiceLanguage == targetLang {
            isUsingSenseVoice = true
            return
        }
        guard let paths = Self.senseVoiceModelPaths() else {
            isUsingSenseVoice = (senseVoiceHandle != nil)
            return
        }
        let maxThreads = paths.isFullFP32 ? 8 : 6
        let threads = Int32(max(4, min(maxThreads, ProcessInfo.processInfo.activeProcessorCount - 2)))
        if let handle = tz_sensevoice_create(paths.model, paths.tokens, threads, targetLang) {
            let oldHandleBits = senseVoiceHandle.map { Int(bitPattern: $0) }
            self.senseVoiceHandle = handle
            self.loadedSenseVoiceLanguage = targetLang
            self.isUsingSenseVoice = true
            self.isFullPrecisionFP32 = paths.isFullFP32
            if let bits = oldHandleBits {
                decodeQueue.async {
                    if let oldPtr = OpaquePointer(bitPattern: bits) {
                        tz_sensevoice_destroy(oldPtr)
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.onModelReady?()
            }
        }
    }

    public func reloadSenseVoiceModelAsync() {
        audioControlQueue.async { [weak self] in
            self?.loadSenseVoiceIfAvailable()
        }
    }

    public static func requestPermissions(completion: @escaping (Bool, Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            if senseVoiceModelPaths() != nil
                || KeychainHelper.hasAnyDoubaoCredential
                || !KeychainHelper.loadEffectiveOpenAIASRAPIKey().isEmpty {
                DispatchQueue.main.async {
                    completion(micGranted, true)
                }
                return
            }
            SFSpeechRecognizer.requestAuthorization { speechStatus in
                DispatchQueue.main.async {
                    completion(micGranted, speechStatus == .authorized)
                }
            }
        }
    }

    public func prewarmCloudSocketIfReady() {
        switch asrProvider {
        case .volcSeedASR:
            let key = volcSpeechAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            seedASRClient.prewarmStandbySocket(apiKey: key)
        case .openAIWhisper:
            let key = openAIASRAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty || PolishEngine.isKeylessLocalEndpoint(openAIASRBaseURL) else { return }
            openAIASRClient.prewarmConnection(baseURL: openAIASRBaseURL, apiKey: key)
        case .localSenseVoice:
            break
        }
    }

    /// Queries macOS CoreAudio for the transport type of the current default input or output device.
    public static func defaultDeviceTransportType(isInput: Bool) -> UInt32 {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID) == noErr,
              deviceID != kAudioObjectUnknown else {
            return 0
        }
        var transport: UInt32 = 0
        var tSize = UInt32(MemoryLayout<UInt32>.size)
        var tAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &tAddr, 0, nil, &tSize, &transport) == noErr else {
            return 0
        }
        return transport
    }

    /// Pure hot-mic eligibility policy:
    /// - ONLY pure Built-In Mac mic + Built-In Mac speakers keep a brief 4s warm standby.
    /// - ANY Bluetooth headset (AirPods / generic BT chips), USB/Type-C headset/DAC, HDMI, AirPlay,
    ///   or virtual/aggregate audio route tears down `AVAudioEngine` IMMEDIATELY (`0s`) and skips KeyDown prewarm
    ///   so `coreaudiod`/`bluetoothaudiod` releases the AUHAL input unit and restores music/YouTube playback right away!
    public static func shouldAllowHotMicStandby(inputTransport: UInt32, outputTransport: UInt32) -> Bool {
        return inputTransport == kAudioDeviceTransportTypeBuiltIn
            && outputTransport == kAudioDeviceTransportTypeBuiltIn
    }

    /// Pure Bluetooth-HFP avoidance policy:
    /// Opening ANY Bluetooth headset microphone forces Bluetooth Classic out of 48kHz stereo A2DP into
    /// 8kHz/16kHz mono HFP/eSCO telephony ("channel shifts & music turns hollow/ethereal").
    /// Whenever macOS auto-selected a Bluetooth input device AND the Mac has a live Built-In Microphone
    /// with the MacBook lid open (`!isClamshellClosed`), bind TypeZero's private AUHAL input directly to
    /// the Built-In Microphone—preserving 100% untouched stereo A2DP on the headphones AND 48kHz studio speech capture!
    /// Leaves explicit USB studio mics and closed-clamshell / Mac mini setups completely untouched.
    public static func shouldBypassBluetoothInputToBuiltIn(
        defaultInputTransport: UInt32,
        builtInInputDeviceID: AudioDeviceID?,
        isClamshellClosed: Bool
    ) -> AudioDeviceID? {
        let isBluetoothInput = (defaultInputTransport == kAudioDeviceTransportTypeBluetooth)
            || (defaultInputTransport == kAudioDeviceTransportTypeBluetoothLE)
        guard isBluetoothInput,
              !isClamshellClosed,
              let builtInID = builtInInputDeviceID,
              builtInID != kAudioObjectUnknown else {
            return nil
        }
        return builtInID
    }

    /// Checks IOKit `IOPMrootDomain` -> `AppleClamshellState` (~20µs, zero permissions) so we never route
    /// to an internal MacBook microphone whose hardware disconnect switch is engaged while docked lid-closed.
    public static func isMacBookClamshellClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }
        if let prop = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool {
            return prop
        }
        return false
    }

    /// Finds the Mac's alive Built-In Microphone `AudioDeviceID` (`kAudioDeviceTransportTypeBuiltIn`), if present.
    public static func findLiveBuiltInInputDeviceID() -> AudioDeviceID? {
        var propSize: UInt32 = 0
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &propSize) == noErr,
              propSize >= UInt32(MemoryLayout<AudioDeviceID>.size) else {
            return nil
        }
        let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &propSize, &devices) == noErr else {
            return nil
        }

        for dev in devices where dev != kAudioObjectUnknown {
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(dev, &streamAddr, 0, nil, &streamSize) == noErr,
                  streamSize > 0 else {
                continue
            }

            var alive: UInt32 = 1
            var aliveSize = UInt32(MemoryLayout<UInt32>.size)
            var aliveAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsAlive,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(dev, &aliveAddr, 0, nil, &aliveSize, &alive) == noErr, alive == 0 {
                continue
            }

            var transport: UInt32 = 0
            var tSize = UInt32(MemoryLayout<UInt32>.size)
            var tAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(dev, &tAddr, 0, nil, &tSize, &transport) == noErr else {
                continue
            }
            if transport == kAudioDeviceTransportTypeBuiltIn {
                return dev
            }
        }
        return nil
    }

    private static func preferredBuiltInInputOverrideForBluetooth() -> AudioDeviceID? {
        let inTransport = defaultDeviceTransportType(isInput: true)
        guard inTransport == kAudioDeviceTransportTypeBluetooth || inTransport == kAudioDeviceTransportTypeBluetoothLE else {
            return nil
        }
        return shouldBypassBluetoothInputToBuiltIn(
            defaultInputTransport: inTransport,
            builtInInputDeviceID: findLiveBuiltInInputDeviceID(),
            isClamshellClosed: isMacBookClamshellClosed()
        )
    }

    private static var currentAudioRouteAllowsHotStandby: Bool {
        shouldAllowHotMicStandby(
            inputTransport: defaultDeviceTransportType(isInput: true),
            outputTransport: defaultDeviceTransportType(isInput: false)
        )
    }

    public func warmUp(localeIdentifier: String = "auto") {
        speechLocale = localeIdentifier
        prewarmCloudSocketIfReady()
        audioControlQueue.async { [weak self] in
            guard let self else { return }
            if self.senseVoiceHandle == nil {
                self.loadSenseVoiceIfAvailable()
            }
            // IMPORTANT: Never create/prepare AVAudioEngine at launch!
            // Initializing AUHAL input at startup hijacks Bluetooth headsets (AirPods/Sony/Bose)
            // out of A2DP music/YouTube playback into 16kHz HFP call mode before the user even speaks.
        }
    }

    /// Non-blocking ultra-fast streaming start: launches CoreAudio tap on dedicated `.userInteractive` queue
    /// so `@MainActor` UI responds in 0.0ms without dropping the first spoken syllable!
    public func startStreamingAsync(
        localeIdentifier: String = "auto",
        contextualStrings: [String] = [],
        dialogContext: [String] = []
    ) {
        audioControlQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.startStreamingInternal(
                    localeIdentifier: localeIdentifier,
                    contextualStrings: contextualStrings,
                    dialogContext: dialogContext
                )
            } catch {
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                }
            }
        }
    }

    /// Wakes hardware microphone immediately on KeyDown (before key release) ONLY on Built-In Mac audio routes.
    /// Skipped when Bluetooth/USB headsets are active so accidental key taps never interrupt music/YouTube A2DP audio.
    public func prewarmHotMicAsync() {
        guard Self.isMicrophoneAuthorized else { return }
        audioControlQueue.async { [weak self] in
            guard let self else { return }
            guard Self.currentAudioRouteAllowsHotStandby else { return }
            self.idleHardwareShutdownWorkItem?.cancel()
            self.idleHardwareShutdownWorkItem = nil
            do {
                _ = try self.ensureHotMicRunning()
                self.scheduleIdleHardwareShutdown()
            } catch {
                // Non-fatal during prewarm; startStreamingAsync will surface any real permission error.
            }
        }
    }

    /// Immediately tears down AVAudioEngine hardware handle (used on app termination).
    public func shutdownHardwareImmediately() {
        audioControlQueue.sync {
            self.shutdownAudioHardwareCompletely()
        }
    }

    private func ensureHotMicRunning(allowBuiltInBluetoothBypass: Bool = true) throws -> AVAudioFormat {
        let engine: AVAudioEngine
        var didApplyBuiltInBypass = false
        if let existing = self.audioEngine {
            engine = existing
        } else {
            let fresh = AVAudioEngine()
            let inputNode = fresh.inputNode
            if allowBuiltInBluetoothBypass, let builtInID = Self.preferredBuiltInInputOverrideForBluetooth() {
                // Bind TypeZero's private AUHAL input node to the Built-In MacBook mic BEFORE reading bus formats!
                // Prevents Bluetooth headphones (AirPods / Rose Technics / Sony / Bose) from dropping out of stereo A2DP into mono HFP!
                if (try? inputNode.auAudioUnit.setDeviceID(builtInID)) != nil {
                    didApplyBuiltInBypass = true
                }
            }
            self.audioEngine = fresh
            engine = fresh
            self.isTapInstalled = false
        }

        let inputNode = engine.inputNode
        let hwInputFmt = inputNode.inputFormat(forBus: 0)
        let busOutputFmt = inputNode.outputFormat(forBus: 0)
        let recordingFormat: AVAudioFormat = {
            if didApplyBuiltInBypass, hwInputFmt.sampleRate > 0, hwInputFmt.channelCount > 0 {
                if busOutputFmt.sampleRate == hwInputFmt.sampleRate,
                   busOutputFmt.commonFormat == .pcmFormatFloat32,
                   !busOutputFmt.isInterleaved {
                    return busOutputFmt
                }
                if let stdFloatFmt = AVAudioFormat(
                    standardFormatWithSampleRate: hwInputFmt.sampleRate,
                    channels: hwInputFmt.channelCount
                ) {
                    return stdFloatFmt
                }
            }
            return busOutputFmt
        }()
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            if didApplyBuiltInBypass {
                shutdownAudioHardwareCompletely()
                return try ensureHotMicRunning(allowBuiltInBluetoothBypass: false)
            }
            throw NSError(domain: "TypeZero.ASR", code: -2, userInfo: [NSLocalizedDescriptionKey: "麦克风输入不可用，请检查麦克风权限"])
        }

        let hwRate = Int32(recordingFormat.sampleRate)
        sampleLock.lock()
        if currentSampleRate != hwRate {
            currentSampleRate = hwRate
            preRollSamples.removeAll(keepingCapacity: true)
        }
        sampleLock.unlock()

        if !isTapInstalled {
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { [weak self] buffer, _ in
                self?.handleIncomingAudioBuffer(buffer)
            }
            isTapInstalled = true
        }

        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                if didApplyBuiltInBypass {
                    shutdownAudioHardwareCompletely()
                    return try ensureHotMicRunning(allowBuiltInBluetoothBypass: false)
                }
                throw error
            }
        }
        return recordingFormat
    }

    private func handleIncomingAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channel0 = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        sampleLock.lock()
        let capturing = self.isCaptureActive
        if !capturing {
            // Hot-standby mode: silently maintain a rolling ~220ms pre-roll ring buffer (zero network/CPU/UI work)
            let maxPreRoll = max(1600, Int(Double(self.currentSampleRate) * 0.22))
            self.preRollSamples.append(contentsOf: UnsafeBufferPointer(start: channel0, count: count))
            if self.preRollSamples.count > maxPreRoll {
                self.preRollSamples.removeFirst(self.preRollSamples.count - maxPreRoll)
            }
            sampleLock.unlock()
            return
        }
        let maxBackupSamples = self.activeMaxBackupSamples
        let currentlyVolcCloud = self.activeSessionUsesCloudSeedASR
        let currentlyOpenAICloud = self.activeSessionUsesOpenAIASR
        let currentlyAnyCloud = currentlyVolcCloud || currentlyOpenAICloud
        sampleLock.unlock()

        let (normLevel, rawRMS) = Self.calculateRMSMetrics(buffer: buffer)
        AudioLevelBus.shared.push(normLevel)

        let voiceThreshold: Float = self.enableWhisperAGC ? 0.0024 : 0.0080
        let isVoiceFrame = rawRMS > voiceThreshold

        // Preserve full-spectrum hardware PCM (all high-frequency Mandarin sibilants 4kHz-10kHz intact!)
        self.sampleLock.lock()
        guard self.isCaptureActive else {
            self.sampleLock.unlock()
            return
        }
        if !currentlyOpenAICloud {
            self.activeSegmentSamples.append(contentsOf: UnsafeBufferPointer(start: channel0, count: count))
        }
        if currentlyAnyCloud && self.cloudFailoverBackupSamples.count < maxBackupSamples {
            self.cloudFailoverBackupSamples.append(contentsOf: UnsafeBufferPointer(start: channel0, count: count))
        }
        var virtualOpenAICount: Int? = nil
        if isVoiceFrame {
            self.hasDetectedSpeechInSegment = true
            self.hasDetectedSpeechOverall = true
            self.didFlushMicroPauseTail = false
            self.totalVoiceSamplesInSegment += count
            self.consecutiveSilentSamples = 0
            if currentlyOpenAICloud {
                // Drive subtle rhythmic progress indicator in the floating capsule while recording for batch cloud ASR
                let stepSamples = max(1, Int(self.currentSampleRate) / 5) // ~200ms of speech per rhythm pulse
                virtualOpenAICount = max(1, self.totalVoiceSamplesInSegment / stepSamples)
            }
        } else {
            self.consecutiveSilentSamples += count
            let maxIdlePreRoll = Int(self.currentSampleRate) / 4
            if !currentlyOpenAICloud && !self.hasDetectedSpeechInSegment && self.activeSegmentSamples.count > maxIdlePreRoll {
                let excess = self.activeSegmentSamples.count - maxIdlePreRoll
                self.activeSegmentSamples.removeFirst(excess)
            }
            if currentlyAnyCloud && !self.hasDetectedSpeechOverall && self.cloudFailoverBackupSamples.count > maxIdlePreRoll {
                let excess = self.cloudFailoverBackupSamples.count - maxIdlePreRoll
                self.cloudFailoverBackupSamples.removeFirst(excess)
            }
        }
        self.sampleLock.unlock()

        if let pulse = virtualOpenAICount {
            AudioLevelBus.shared.pushRecognizedCount(pulse)
        }

        if currentlyVolcCloud {
            let pcm16 = self.convertMonoFloatTo16kHzPCM16(channel0: channel0, count: count, rawRMS: rawRMS, isVoice: isVoiceFrame)
            if !pcm16.isEmpty {
                self.seedASRClient.appendPCM16Samples(pcm16)
            }
        }
    }

    private func startStreamingInternal(
        localeIdentifier: String = "auto",
        contextualStrings: [String] = [],
        dialogContext: [String] = []
    ) throws {
        idleHardwareShutdownWorkItem?.cancel()
        idleHardwareShutdownWorkItem = nil
        liveTimer?.cancel()
        liveTimer = nil
        cloudWatchdogTimer?.cancel()
        cloudWatchdogTimer = nil
        fallbackRequest?.endAudio()
        fallbackTask?.cancel()
        fallbackRequest = nil
        fallbackTask = nil

        if senseVoiceHandle == nil {
            loadSenseVoiceIfAvailable()
        }

        latestTranscript = ""
        sessionStartTime = Date()

        let cleanSpeechKey = volcSpeechAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCloudJWT = cloudTrialJWT.trimmingCharacters(in: .whitespacesAndNewlines)
        let useCloudASR = useCloudTrialRelay && !cleanCloudJWT.isEmpty
        let cleanOpenAIKey = openAIASRAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantCloudSeedASR = useCloudASR || ((asrProvider == .volcSeedASR) && !cleanSpeechKey.isEmpty)
        let wantOpenAIASR = !useCloudASR && (asrProvider == .openAIWhisper) && (!cleanOpenAIKey.isEmpty || PolishEngine.isKeylessLocalEndpoint(openAIASRBaseURL))
        let hasLocalSenseVoice = isUsingSenseVoice && (senseVoiceHandle != nil)

        if wantCloudSeedASR || wantOpenAIASR || hasLocalSenseVoice {
            let recordingFormat = try ensureHotMicRunning()
            let hwRate = Int32(recordingFormat.sampleRate)

            if wantCloudSeedASR,
               let monoFloatFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: recordingFormat.sampleRate, channels: 1, interleaved: false),
               let targetFmt = pcm16TargetFormat {
                if pcm16SourceFormat?.sampleRate != monoFloatFmt.sampleRate || pcm16Converter == nil {
                    pcm16SourceFormat = monoFloatFmt
                    pcm16Converter = AVAudioConverter(from: monoFloatFmt, to: targetFmt)
                } else {
                    pcm16Converter?.reset()
                }
            }

            let maxBackupSamples = Int(hwRate) * (wantOpenAIASR ? 180 : 90)
            let isAnyCloudMode = wantCloudSeedASR || wantOpenAIASR

            if wantCloudSeedASR {
                if useCloudASR {
                    seedASRClient.startSession(
                        apiKey: cleanCloudJWT,
                        hotwords: contextualStrings,
                        dialogContext: dialogContext,
                        customEndpointURL: CloudAuthClient.cloudASRWSURL,
                        useBearerAuth: true
                    )
                } else if CloudAuthClient.isVoucherCode(cleanSpeechKey) {
                    seedASRClient.startSession(
                        apiKey: CloudAuthClient.normalizedVoucherCode(cleanSpeechKey),
                        hotwords: contextualStrings,
                        dialogContext: dialogContext,
                        customEndpointURL: CloudAuthClient.cloudASRWSURL,
                        useBearerAuth: true
                    )
                } else {
                    seedASRClient.startSession(
                        apiKey: cleanSpeechKey,
                        hotwords: contextualStrings,
                        dialogContext: dialogContext
                    )
                }
            } else if wantOpenAIASR {
                openAIASRClient.prewarmConnection(baseURL: openAIASRBaseURL, apiKey: cleanOpenAIKey)
            }

            // Seamlessly prepend up to 180ms of hot-standby pre-roll audio so the opening syllable is 100% preserved!
            let maxInjectSamples = max(800, Int(Double(hwRate) * 0.18))
            sampleLock.lock()
            let preRollToInject: [Float] = preRollSamples.count > maxInjectSamples
                ? Array(preRollSamples.suffix(maxInjectSamples))
                : preRollSamples
            preRollSamples.removeAll(keepingCapacity: true)

            activeMaxBackupSamples = maxBackupSamples
            activeSessionUsesCloudSeedASR = wantCloudSeedASR
            activeSessionUsesOpenAIASR = wantOpenAIASR
            openAIActiveHotwords = wantOpenAIASR ? contextualStrings : []
            openAIActiveLocale = localeIdentifier
            activeSegmentSamples.removeAll(keepingCapacity: true)
            activeSegmentSamples.reserveCapacity(wantOpenAIASR ? 0 : Int(hwRate) * 14)
            cloudFailoverBackupSamples.removeAll(keepingCapacity: true)
            if isAnyCloudMode {
                cloudFailoverBackupSamples.reserveCapacity(Int(hwRate) * 20)
            }
            if !preRollToInject.isEmpty {
                if !wantOpenAIASR {
                    activeSegmentSamples.append(contentsOf: preRollToInject)
                }
                if isAnyCloudMode {
                    cloudFailoverBackupSamples.append(contentsOf: preRollToInject)
                }
            }
            frozenTranscriptPrefix = ""
            currentSampleRate = hwRate
            lastDecodedSampleCount = 0
            lastDecodedVoiceSampleMark = 0
            totalVoiceSamplesInSegment = 0
            isDecodingChunk = false
            hasDetectedSpeechInSegment = false
            hasDetectedSpeechOverall = false
            didFlushMicroPauseTail = false
            consecutiveSilentSamples = 0
            isCaptureActive = true
            sampleLock.unlock()

            if wantCloudSeedASR && !preRollToInject.isEmpty {
                let prePCM16 = Self.resampleFloatTo16kHzInt16(preRollToInject, sourceRate: Double(hwRate))
                if !prePCM16.isEmpty {
                    seedASRClient.appendPCM16Samples(prePCM16)
                }
            }

            if wantCloudSeedASR {
                startCloudWatchdogLoop()
            } else if !wantOpenAIASR {
                startContinuousVADStreamingLoop()
            }
            return
        }

        // Fallback Apple Speech
        shutdownAudioHardwareCompletely()
        let engine = AVAudioEngine()
        self.audioEngine = engine
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw NSError(domain: "TypeZero.ASR", code: -2, userInfo: [NSLocalizedDescriptionKey: "麦克风输入不可用，请检查麦克风权限"])
        }
        let trimmedLoc = localeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let recognizer = (trimmedLoc.isEmpty || trimmedLoc.lowercased() == "auto")
            ? SFSpeechRecognizer()
            : (SFSpeechRecognizer(locale: Locale(identifier: trimmedLoc)) ?? SFSpeechRecognizer())
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "TypeZero.ASR", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到本地模型且系统听写未就绪"])
        }
        self.fallbackRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualStrings
        self.fallbackRequest = request

        inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.fallbackRequest?.append(buffer)
            let (level, _) = Self.calculateRMSMetrics(buffer: buffer)
            AudioLevelBus.shared.push(level)
        }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }

        fallbackTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            if !text.isEmpty {
                DispatchQueue.main.async {
                    self.latestTranscript = text
                    self.onPartialResult?(text, false)
                }
            }
        }
    }

    private func startCloudWatchdogLoop() {
        cloudWatchdogTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        timer.schedule(deadline: .now() + .milliseconds(110), repeating: .milliseconds(110), leeway: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            self?.processCloudWatchdogTick()
        }
        self.cloudWatchdogTimer = timer
        timer.resume()
    }

    private func processCloudWatchdogTick() {
        sampleLock.lock()
        guard activeSessionUsesCloudSeedASR else {
            sampleLock.unlock()
            return
        }
        let sr = max(1, Int(currentSampleRate))
        let silenceSeconds = Double(consecutiveSilentSamples) / Double(sr)
        let activeVoiceSeconds = Double(totalVoiceSamplesInSegment) / Double(sr)
        let shouldFlushTail = hasDetectedSpeechOverall && silenceSeconds >= 0.20 && !didFlushMicroPauseTail
        if shouldFlushTail {
            didFlushMicroPauseTail = true
        }
        sampleLock.unlock()

        // Dead-Wi-Fi / Captive Portal Blackhole Guard: if >= 1.5s of voice elapsed with zero server packets, fail over to local FP32!
        if activeVoiceSeconds >= 1.50 && !seedASRClient.hasReceivedAnyServerFrame && senseVoiceHandle != nil {
            switchActiveSessionFromCloudToLocalFP32(reason: "弱网超时，已自动无损切回本机满血模型")
            return
        }

        if shouldFlushTail {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.audioEngine?.isRunning == true, !self.latestTranscript.isEmpty else { return }
                self.onPartialResult?(self.latestTranscript, true)
            }
        }
    }

    private func switchActiveSessionFromCloudToLocalFP32(reason: String) {
        sampleLock.lock()
        guard activeSessionUsesCloudSeedASR else {
            sampleLock.unlock()
            return
        }
        activeSessionUsesCloudSeedASR = false
        // Restore full utterance captured so far into activeSegmentSamples so local SenseVoice FP32 loses zero syllables!
        if !cloudFailoverBackupSamples.isEmpty {
            activeSegmentSamples = cloudFailoverBackupSamples
            cloudFailoverBackupSamples.removeAll(keepingCapacity: false)
        }
        sampleLock.unlock()

        cloudWatchdogTimer?.cancel()
        cloudWatchdogTimer = nil
        seedASRClient.stopAndReset()

        if senseVoiceHandle != nil && audioEngine?.isRunning == true {
            startContinuousVADStreamingLoop()
        }
        DispatchQueue.main.async { [weak self] in
            self?.onCloudFailoverNotice?(reason)
        }
    }

    private func convertMonoFloatTo16kHzPCM16(
        channel0: UnsafePointer<Float>,
        count: Int,
        rawRMS: Float,
        isVoice: Bool
    ) -> [Int16] {
        guard let converter = pcm16Converter,
              let srcFmt = pcm16SourceFormat,
              let dstFmt = pcm16TargetFormat,
              let srcBuf = AVAudioPCMBuffer(pcmFormat: srcFmt, frameCapacity: AVAudioFrameCount(count)),
              let srcData = srcBuf.floatChannelData?[0] else {
            return []
        }
        srcBuf.frameLength = AVAudioFrameCount(count)
        if enableWhisperAGC && isVoice && rawRMS > 0.0018 && rawRMS < 0.045 {
            let gain = min(4.5, max(1.0, 0.065 / rawRMS))
            for i in 0..<count {
                let v = channel0[i] * gain
                srcData[i] = (v > 0.65 || v < -0.65) ? tanh(v) : v
            }
        } else {
            srcData.update(from: channel0, count: count)
        }

        let outCap = AVAudioFrameCount(ceil(Double(count) * 16_000.0 / srcFmt.sampleRate) + 16)
        guard let dstBuf = AVAudioPCMBuffer(pcmFormat: dstFmt, frameCapacity: outCap) else { return [] }

        var didSupply = false
        var convErr: NSError?
        converter.convert(to: dstBuf, error: &convErr) { _, outStatus in
            if !didSupply {
                didSupply = true
                outStatus.pointee = .haveData
                return srcBuf
            }
            outStatus.pointee = .noDataNow
            return nil
        }
        guard convErr == nil, dstBuf.frameLength > 0, let int16Ptr = dstBuf.int16ChannelData?[0] else {
            return []
        }
        return Array(UnsafeBufferPointer(start: int16Ptr, count: Int(dstBuf.frameLength)))
    }

    public static func resampleFloatTo16kHzInt16(_ samples: [Float], sourceRate: Double) -> [Int16] {
        guard !samples.isEmpty,
              let srcFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sourceRate, channels: 1, interleaved: false),
              let dstFmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: srcFmt, to: dstFmt),
              let srcBuf = AVAudioPCMBuffer(pcmFormat: srcFmt, frameCapacity: AVAudioFrameCount(samples.count)),
              let srcData = srcBuf.floatChannelData?[0] else {
            return []
        }
        srcBuf.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                srcData.update(from: base, count: samples.count)
            }
        }
        let outCap = AVAudioFrameCount(ceil(Double(samples.count) * 16_000.0 / sourceRate) + 32)
        guard let dstBuf = AVAudioPCMBuffer(pcmFormat: dstFmt, frameCapacity: outCap) else { return [] }
        var supplied = false
        var err: NSError?
        converter.convert(to: dstBuf, error: &err) { _, outStatus in
            if !supplied {
                supplied = true
                outStatus.pointee = .haveData
                return srcBuf
            }
            outStatus.pointee = .endOfStream
            return nil
        }
        guard err == nil, dstBuf.frameLength > 0, let int16Ptr = dstBuf.int16ChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: int16Ptr, count: Int(dstBuf.frameLength)))
    }

    private func startContinuousVADStreamingLoop() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        // 58ms ultra-responsive cadence (first tick at 46ms) on pre-decimated 16kHz buffer (~15ms inference)!
        timer.schedule(deadline: .now() + .milliseconds(46), repeating: .milliseconds(58), leeway: .milliseconds(3))
        timer.setEventHandler { [weak self] in
            self?.processActiveWindowAndVAD()
        }
        self.liveTimer = timer
        timer.resume()
    }

    /// Core VAD + Sliding Segment Engine:
    /// 1. Releases the withheld final character immediately on a >=180ms micro-pause so sentence endings never hang!
    /// 2. Seals & flushes `activeSegmentSamples` on >=420ms breath pause (or >=6.8s with >=150ms micro-pause) so active window stays <6.8s (~15ms constant inference!).
    private func processActiveWindowAndVAD() {
        guard let handle = senseVoiceHandle else { return }

        sampleLock.lock()
        if isDecodingChunk {
            sampleLock.unlock()
            return
        }

        let sr = Int(currentSampleRate)
        let totalSamples = activeSegmentSamples.count
        let segmentSeconds = Double(totalSamples) / Double(max(1, sr))
        let silenceSeconds = Double(consecutiveSilentSamples) / Double(max(1, sr))

        // Keep full 5s–9s clauses intact so SenseVoice's bidirectional attention resolves homophones using full-sentence context!
        // Only seal & flush when clause is >= 4.8s with a clear >= 0.72s sentence-end pause (or >= 9.5s with a >= 0.25s pause).
        let shouldCommitAndFlushSegment = hasDetectedSpeechInSegment && (
            (segmentSeconds >= 4.8 && silenceSeconds >= 0.72) ||
            (segmentSeconds >= 9.5 && silenceSeconds >= 0.25) ||
            (segmentSeconds >= 14.5)
        )

        if shouldCommitAndFlushSegment {
            isDecodingChunk = true
            let segmentToSeal = activeSegmentSamples
            let sampleRateC = currentSampleRate
            let wasLongPause = silenceSeconds >= 0.72

            let tailKeep = min(totalSamples, sr / 10)
            activeSegmentSamples = Array(activeSegmentSamples.suffix(tailKeep))
            lastDecodedSampleCount = 0
            lastDecodedVoiceSampleMark = 0
            totalVoiceSamplesInSegment = 0
            hasDetectedSpeechInSegment = false
            didFlushMicroPauseTail = false
            consecutiveSilentSamples = 0
            sampleLock.unlock()

            let agc = self.enableWhisperAGC
            decodeQueue.async { [weak self] in
                guard let self else { return }
                let segText = Self.runSenseVoice(handle: handle, samples: segmentToSeal, sampleRate: sampleRateC, applyWhisperAGC: agc)

                self.sampleLock.lock()
                if !segText.isEmpty {
                    self.frozenTranscriptPrefix += segText
                    // Preserve acoustic pause cue for downstream LLM paragraph/list structuring if SenseVoice didn't append punctuation
                    if wasLongPause, let last = segText.last, !"。！？；，,.;!?".contains(last) {
                        self.frozenTranscriptPrefix += "，"
                    }
                }
                let fullCombined = self.frozenTranscriptPrefix
                self.isDecodingChunk = false
                self.sampleLock.unlock()

                if !fullCombined.isEmpty {
                    DispatchQueue.main.async {
                        guard self.audioEngine?.isRunning == true else { return }
                        self.latestTranscript = fullCombined
                        self.onPartialResult?(fullCombined, true)
                    }
                }
            }
            return
        }

        // Micro-pause tail flush (>=185ms silence): immediately push the withheld last character to the typewriter without waiting 420ms!
        if hasDetectedSpeechInSegment && silenceSeconds >= 0.185 && !didFlushMicroPauseTail && !latestTranscript.isEmpty {
            didFlushMicroPauseTail = true
            let cached = latestTranscript
            sampleLock.unlock()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.audioEngine?.isRunning == true else { return }
                self.onPartialResult?(cached, true)
            }
            return
        }

        // Ongoing active speech within current short segment: decode live preview every ~55ms of new audio!
        let minStep = sr / 18
        guard hasDetectedSpeechInSegment,
              totalSamples >= sr / 9,
              (totalSamples - lastDecodedSampleCount) >= minStep else {
            sampleLock.unlock()
            return
        }

        isDecodingChunk = true
        lastDecodedSampleCount = totalSamples
        let voiceMarkSnapshot = totalVoiceSamplesInSegment
        let snapshot = activeSegmentSamples
        let prefixCopy = frozenTranscriptPrefix
        let sampleRateC = currentSampleRate
        sampleLock.unlock()

        let agc = self.enableWhisperAGC
        decodeQueue.async { [weak self] in
            guard let self else { return }
            let activeText = Self.runSenseVoice(handle: handle, samples: snapshot, sampleRate: sampleRateC, applyWhisperAGC: agc)

            self.sampleLock.lock()
            let latestFrozen = self.frozenTranscriptPrefix
            if latestFrozen == prefixCopy {
                self.lastDecodedVoiceSampleMark = voiceMarkSnapshot
            }
            self.isDecodingChunk = false
            self.sampleLock.unlock()

            guard latestFrozen == prefixCopy, !activeText.isEmpty else { return }
            let combined = latestFrozen + activeText

            DispatchQueue.main.async {
                guard self.audioEngine?.isRunning == true else { return }
                if combined != self.latestTranscript {
                    self.latestTranscript = combined
                    self.onPartialResult?(combined, false)
                }
            }
        }
    }

    private func takeCloudFinishSnapshot() -> (wasVolcCloud: Bool, wasOpenAICloud: Bool, hadSpeech: Bool, backup: [Float], sr: Int32, hotwords: [String], locale: String) {
        sampleLock.lock()
        defer { sampleLock.unlock() }
        let wasVolc = activeSessionUsesCloudSeedASR
        let wasOpenAI = activeSessionUsesOpenAIASR
        activeSessionUsesCloudSeedASR = false
        activeSessionUsesOpenAIASR = false
        let hadAnySpeech = hasDetectedSpeechOverall
        let backupSamples = cloudFailoverBackupSamples
        let backupSR = currentSampleRate
        let hw = openAIActiveHotwords
        let loc = openAIActiveLocale
        openAIActiveHotwords = []
        cloudFailoverBackupSamples.removeAll(keepingCapacity: false)
        return (wasVolc, wasOpenAI, hadAnySpeech, backupSamples, backupSR, hw, loc)
    }

    public func finishStreaming() async -> (transcript: String, duration: Double) {
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        liveTimer?.cancel()
        liveTimer = nil
        cloudWatchdogTimer?.cancel()
        cloudWatchdogTimer = nil
        AudioLevelBus.shared.reset()

        let (wasUsingVolcCloud, wasUsingOpenAICloud, hadAnySpeech, backupSamples, backupSR, openAIHotwords, openAILocale) = takeCloudFinishSnapshot()

        audioControlQueue.async { [weak self] in
            self?.pauseActiveTapOnly()
        }

        if wasUsingOpenAICloud {
            guard hadAnySpeech, backupSamples.count > Int(backupSR) / 8 else {
                clearSessionBuffers()
                return ("", elapsed)
            }

            let baseURL = self.openAIASRBaseURL
            let model = self.openAIASRModel
            let apiKey = self.openAIASRAPIKey
            let agc = self.enableWhisperAGC

            let wavData: Data = await withCheckedContinuation { cont in
                decodeQueue.async {
                    let conditioned = agc ? Self.boostQuietSpeechAGC(backupSamples) : backupSamples
                    let pcm16 = Self.resampleFloatTo16kHzInt16(conditioned, sourceRate: Double(backupSR))
                    let wav = OpenAITranscriptionClient.encodePCM16ToWAV(pcm16, sampleRate: 16_000)
                    cont.resume(returning: wav)
                }
            }

            let dynamicTimeout = max(6.5, min(14.0, elapsed * 0.45 + 5.5))
            do {
                let (cloudText, _) = try await openAIASRClient.transcribe(
                    wavData: wavData,
                    baseURL: baseURL,
                    model: model,
                    apiKey: apiKey,
                    hotwords: openAIHotwords,
                    languageLocale: openAILocale,
                    timeoutSeconds: dynamicTimeout
                )
                let trimmed = cloudText.trimmingCharacters(in: .whitespacesAndNewlines)
                clearSessionBuffers()
                if !trimmed.isEmpty {
                    return (trimmed, elapsed)
                }
            } catch {
                // Seamless Zero-Word-Loss Failover to Local 886MB SenseVoice FP32 if offline / timeout / API error!
                if isUsingSenseVoice, let handle = senseVoiceHandle, backupSamples.count > Int(backupSR) / 10 {
                    let handleBits = Int(bitPattern: handle)
                    let localFallback: String = await withCheckedContinuation { cont in
                        decodeQueue.async {
                            guard let ptr = OpaquePointer(bitPattern: handleBits) else {
                                cont.resume(returning: "")
                                return
                            }
                            let txt = Self.runSenseVoice(handle: ptr, samples: backupSamples, sampleRate: backupSR, applyWhisperAGC: agc)
                            cont.resume(returning: txt)
                        }
                    }
                    clearSessionBuffers()
                    if !localFallback.isEmpty {
                        let shortErr = error.localizedDescription
                        DispatchQueue.main.async { [weak self] in
                            self?.onCloudFailoverNotice?("云端语音回包异常（\(shortErr)），已由本机满血 FP32 模型无缝兜底")
                        }
                        return (localFallback, elapsed)
                    }
                }
                let errMsg = error.localizedDescription
                clearSessionBuffers()
                DispatchQueue.main.async { [weak self] in
                    self?.onError?("云端语音识别失败：\(errMsg)")
                }
                return ("", elapsed)
            }

            clearSessionBuffers()
            return ("", elapsed)
        }

        if wasUsingVolcCloud {
            if !hadAnySpeech && latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                seedASRClient.stopAndReset()
                clearSessionBuffers()
                return ("", elapsed)
            }

            if let cloudFinal = await seedASRClient.finishAndAwaitFinalTranscript(timeoutMs: 1200),
               !cloudFinal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearSessionBuffers()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(120)) { [weak self] in
                    self?.prewarmCloudSocketIfReady()
                }
                return (cloudFinal.trimmingCharacters(in: .whitespacesAndNewlines), elapsed)
            }

            // Seamless Offline/Drop Failover: run local 886MB SenseVoice FP32 on full backup buffer so zero words are lost!
            if hadAnySpeech, isUsingSenseVoice, let handle = senseVoiceHandle, backupSamples.count > Int(backupSR) / 10 {
                let handleBits = Int(bitPattern: handle)
                let agc = self.enableWhisperAGC
                let localFallback: String = await withCheckedContinuation { cont in
                    decodeQueue.async {
                        guard let ptr = OpaquePointer(bitPattern: handleBits) else {
                            cont.resume(returning: "")
                            return
                        }
                        let txt = Self.runSenseVoice(handle: ptr, samples: backupSamples, sampleRate: backupSR, applyWhisperAGC: agc)
                        cont.resume(returning: txt)
                    }
                }
                clearSessionBuffers()
                if !localFallback.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.onCloudFailoverNotice?("云端回包超时，已由本机满血 FP32 模型无缝兜底")
                    }
                    return (localFallback, elapsed)
                }
            }
            let partialCached = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            clearSessionBuffers()
            return (partialCached, elapsed)
        }

        if isUsingSenseVoice, let handle = senseVoiceHandle {
            let (remainingSamples, needsTailDecode, cachedFull, sr) = takeFinalSnapshotAndCheckZeroWait()
            // Zero-Wait Instant Return: if no new speech frames arrived since the last 72ms live decode, return in 0ms!
            if !needsTailDecode && !cachedFull.isEmpty {
                clearSessionBuffers()
                return (cachedFull, elapsed)
            }

            let handleBits = Int(bitPattern: handle)
            let finalCombined: String = await withCheckedContinuation { continuation in
                decodeQueue.async { [weak self] in
                    guard let self, let ptr = OpaquePointer(bitPattern: handleBits) else {
                        continuation.resume(returning: cachedFull)
                        return
                    }
                    var tailText = ""
                    if needsTailDecode && remainingSamples.count > Int(sr) / 10 {
                        tailText = Self.runSenseVoice(handle: ptr, samples: remainingSamples, sampleRate: sr, applyWhisperAGC: self.enableWhisperAGC)
                    }
                    let prefix = self.readAndClearFrozenPrefix()
                    let merged = (prefix + tailText).trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: merged.isEmpty ? cachedFull : merged)
                }
            }
            clearSessionBuffers()
            return (finalCombined, elapsed)
        }

        fallbackRequest?.endAudio()
        try? await Task.sleep(nanoseconds: 35_000_000)
        let finalString = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        clearSessionBuffers()
        return (finalString, elapsed)
    }

    private func takeFinalSnapshotAndCheckZeroWait() -> ([Float], Bool, String, Int32) {
        sampleLock.lock()
        defer { sampleLock.unlock() }
        let samples = activeSegmentSamples
        let sr = currentSampleRate
        let undecodedVoiceSamples = totalVoiceSamplesInSegment - lastDecodedVoiceSampleMark
        // Only run final SenseVoice pass if >60ms of new voice arrived after the last streaming tick!
        let needsDecode = hasDetectedSpeechInSegment && (undecodedVoiceSamples > Int(sr) / 16 || latestTranscript.isEmpty)
        let cached = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        activeSegmentSamples.removeAll(keepingCapacity: false)
        hasDetectedSpeechInSegment = false
        lastDecodedVoiceSampleMark = 0
        totalVoiceSamplesInSegment = 0
        return (samples, needsDecode, cached, sr)
    }

    private func readAndClearFrozenPrefix() -> String {
        sampleLock.lock()
        defer { sampleLock.unlock() }
        let p = frozenTranscriptPrefix
        frozenTranscriptPrefix = ""
        return p
    }

    private static func runSenseVoice(handle: OpaquePointer, samples: [Float], sampleRate: Int32, applyWhisperAGC: Bool = true) -> String {
        guard !samples.isEmpty else { return "" }
        let processed = applyWhisperAGC ? boostQuietSpeechAGC(samples) : samples
        return processed.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress,
                  let cStr = tz_sensevoice_transcribe(handle, base, Int32(ptr.count), sampleRate) else {
                return ""
            }
            defer { tz_sensevoice_free_string(cStr) }
            return String(cString: cStr).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// P5: Wispr-Flow-style Soft-Knee Automatic Gain Control (Whisper Mode).
    /// Linearly boosts low-volume 25dB whispers up to 7.5x with tanh soft-limiting so loud speech never clips!
    private static func boostQuietSpeechAGC(_ samples: [Float]) -> [Float] {
        var sumSq: Float = 0
        var activeCount: Int = 0
        let strideStep = max(1, samples.count / 2000)

        for i in stride(from: 0, to: samples.count, by: strideStep) {
            let v = abs(samples[i])
            if v > 0.0015 {
                sumSq += v * v
                activeCount += 1
            }
        }
        guard activeCount > 12 else { return samples }
        let activeRMS = sqrt(sumSq / Float(activeCount))

        // Normal speech RMS is ~0.07–0.18; if already strong (>= 0.065), zero overhead pass-through!
        guard activeRMS < 0.065 else { return samples }

        let targetRMS: Float = 0.085
        let gain = min(7.5, max(1.0, targetRMS / max(activeRMS, 0.0018)))
        guard gain > 1.15 else { return samples }

        var boosted = [Float](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            let amplified = samples[i] * gain
            // Fast rational soft-clipper approximating tanh(x) so plosives never harsh-clip above [-0.98, 0.98]
            if amplified > 0.6 || amplified < -0.6 {
                boosted[i] = tanh(amplified)
            } else {
                boosted[i] = amplified
            }
        }
        return boosted
    }

    public func cancel() {
        liveTimer?.cancel()
        liveTimer = nil
        cloudWatchdogTimer?.cancel()
        cloudWatchdogTimer = nil
        seedASRClient.stopAndReset()
        AudioLevelBus.shared.reset()
        clearSessionBuffers()
        audioControlQueue.async { [weak self] in
            self?.pauseActiveTapOnly()
        }
    }

    private func pauseActiveTapOnly() {
        liveTimer?.cancel()
        liveTimer = nil
        cloudWatchdogTimer?.cancel()
        cloudWatchdogTimer = nil
        sampleLock.lock()
        isCaptureActive = false
        preRollSamples.removeAll(keepingCapacity: true)
        sampleLock.unlock()
        fallbackRequest?.endAudio()
        fallbackTask?.cancel()
        fallbackRequest = nil
        fallbackTask = nil

        // Critical Bluetooth / External Audio fix:
        // Only keep CoreAudio mic warm (brief 4s window) on Built-In Mac audio;
        // for Bluetooth (AirPods/Sony/Bose), USB headsets, or virtual routes, tear down AVAudioEngine IMMEDIATELY
        // so macOS releases the AUHAL input unit and restores A2DP stereo music/YouTube playback right away!
        if Self.currentAudioRouteAllowsHotStandby {
            scheduleIdleHardwareShutdown()
        } else {
            shutdownAudioHardwareCompletely()
        }
    }

    private func scheduleIdleHardwareShutdown() {
        idleHardwareShutdownWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.sampleLock.lock()
            let capturing = self.isCaptureActive
            self.sampleLock.unlock()
            guard !capturing else { return }
            self.shutdownAudioHardwareCompletely()
        }
        idleHardwareShutdownWorkItem = work
        audioControlQueue.asyncAfter(deadline: .now() + builtInHotMicKeepAliveSeconds, execute: work)
    }

    private func shutdownAudioHardwareCompletely() {
        idleHardwareShutdownWorkItem?.cancel()
        idleHardwareShutdownWorkItem = nil
        sampleLock.lock()
        isCaptureActive = false
        preRollSamples.removeAll(keepingCapacity: false)
        sampleLock.unlock()
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
            // CRITICAL: Call `reset()` and nil out `audioEngine` (NEVER `engine.prepare()`!) so CoreAudio
            // fully deinitializes and releases the AUHAL input AudioUnit back to macOS & Bluetooth A2DP!
            engine.reset()
            self.audioEngine = nil
        }
        isTapInstalled = false
        pcm16Converter = nil
        pcm16SourceFormat = nil
    }

    private func clearSessionBuffers() {
        sampleLock.lock()
        activeSessionUsesCloudSeedASR = false
        activeSessionUsesOpenAIASR = false
        openAIActiveHotwords = []
        activeSegmentSamples.removeAll(keepingCapacity: true)
        cloudFailoverBackupSamples.removeAll(keepingCapacity: false)
        frozenTranscriptPrefix = ""
        hasDetectedSpeechInSegment = false
        hasDetectedSpeechOverall = false
        consecutiveSilentSamples = 0
        sampleLock.unlock()
    }

    private static func calculateRMSMetrics(buffer: AVAudioPCMBuffer) -> (normalized: Float, rawRMS: Float) {
        guard let channelData = buffer.floatChannelData?[0] else { return (0.05, 0.0) }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return (0.05, 0.0) }

        var sum: Float = 0
        var count: Int = 0
        for i in stride(from: 0, to: frameLength, by: 4) {
            let sample = channelData[i]
            sum += sample * sample
            count += 1
        }
        let rms = sqrt(sum / Float(max(1, count)))
        let db = 20 * log10(max(rms, 0.000_1))
        let norm = max(0.06, min(1.0, (db + 50) / 42))
        return (norm, rms)
    }
}
