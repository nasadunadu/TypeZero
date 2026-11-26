import Foundation
import CoreAudio
import AudioToolbox

/// Thread-safe, zero-permission macOS CoreAudio output muter for dictation sessions.
/// - Mutes the current default system output device in <1ms when dictation starts so speakers /
///   videos / music never bleed into the microphone.
/// - Respects existing user mute state: if the user already muted their Mac, `restoreIfNeeded()`
///   never unmutes it.
/// - Supports both hardware `kAudioDevicePropertyMute` and fallback volume ducking for USB DACs
///   that omit a master mute property.
public final class SystemAudioDucker: @unchecked Sendable {
    private let lock = NSLock()
    private var didAutoMute: Bool = false
    private var mutedDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var usedVolumeFallback: Bool = false
    private var savedVolumeScalar: Float32 = 0.0
    private var sessionGeneration: UInt64 = 0

    public init() {}

    deinit {
        restoreIfNeeded(scheduleBluetoothRecheck: false)
    }

    /// Pure helper: chooses either Master mute (`0`) or ALL settable stereo output channels (`[1, 2]`),
    /// preventing half-muted USB/Bluetooth/HDMI interfaces where channel 2 was previously skipped.
    public static func muteElementsToUpdate(hasMainSettable: Bool, settableChannels: [AudioObjectPropertyElement]) -> [AudioObjectPropertyElement] {
        if hasMainSettable {
            return [kAudioObjectPropertyElementMain]
        }
        return settableChannels
    }

    /// Pure helper: returns deduplicated output devices to unmute (both the originally muted device AND the
    /// current default output device in case Bluetooth HFP<->A2DP or output routing changed during dictation).
    public static func devicesToRestore(mutedDeviceID: AudioDeviceID, currentDefaultDeviceID: AudioDeviceID) -> [AudioDeviceID] {
        var result: [AudioDeviceID] = []
        if mutedDeviceID != kAudioObjectUnknown {
            result.append(mutedDeviceID)
        }
        if currentDefaultDeviceID != kAudioObjectUnknown && currentDefaultDeviceID != mutedDeviceID {
            result.append(currentDefaultDeviceID)
        }
        return result
    }

    public func muteIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !didAutoMute else { return }

        let deviceID = Self.defaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        // Path 1: Standard hardware mute property (works on built-in speakers, AirPods, Bluetooth, most USB audio)
        if let currentMute = Self.getMuteState(deviceID: deviceID) {
            if currentMute != 0 {
                // Already muted by user — do nothing and never unmute later!
                return
            }
            if Self.setMuteState(deviceID: deviceID, muted: true) {
                sessionGeneration &+= 1
                didAutoMute = true
                mutedDeviceID = deviceID
                usedVolumeFallback = false
                return
            }
        }

        // Path 2: Fallback for rare USB DACs / HDMI monitors without a mute property — duck virtual main volume to 0
        if let currentVol = Self.getVirtualMainVolume(deviceID: deviceID), currentVol > 0.001 {
            if Self.setVirtualMainVolume(deviceID: deviceID, volume: 0.0) {
                sessionGeneration &+= 1
                didAutoMute = true
                mutedDeviceID = deviceID
                usedVolumeFallback = true
                savedVolumeScalar = currentVol
            }
        }
    }

    public func restoreIfNeeded(scheduleBluetoothRecheck: Bool = true) {
        lock.lock()
        guard didAutoMute else {
            lock.unlock()
            return
        }
        let devID = mutedDeviceID
        let fallback = usedVolumeFallback
        let prevVol = savedVolumeScalar
        let gen = sessionGeneration
        didAutoMute = false
        mutedDeviceID = kAudioObjectUnknown
        usedVolumeFallback = false
        savedVolumeScalar = 0.0
        lock.unlock()

        applyRestore(mutedDeviceID: devID, usedVolumeFallback: fallback, savedVolume: prevVol)

        // When Bluetooth headphones (AirPods/Sony/Bose) transition from HFP call profile back to A2DP stereo
        // ~250–450ms after AVAudioEngine teardown, CoreAudio can transiently drop an early unmute or switch device ID.
        // Re-verify once after +450ms ONLY if no new dictation session has started (`sessionGeneration == gen`).
        if scheduleBluetoothRecheck {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .milliseconds(450)) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let stillSameSession = (!self.didAutoMute && self.sessionGeneration == gen)
                self.lock.unlock()
                guard stillSameSession else { return }
                self.applyRestoreIfStillSilenced(mutedDeviceID: devID, usedVolumeFallback: fallback, savedVolume: prevVol)
            }
        }
    }

    private func applyRestore(mutedDeviceID: AudioDeviceID, usedVolumeFallback: Bool, savedVolume: Float32) {
        let targets = Self.devicesToRestore(
            mutedDeviceID: mutedDeviceID,
            currentDefaultDeviceID: Self.defaultOutputDeviceID()
        )
        for targetID in targets {
            if usedVolumeFallback {
                _ = Self.setVirtualMainVolume(deviceID: targetID, volume: savedVolume)
            } else {
                _ = Self.setMuteState(deviceID: targetID, muted: false)
            }
        }
    }

    private func applyRestoreIfStillSilenced(mutedDeviceID: AudioDeviceID, usedVolumeFallback: Bool, savedVolume: Float32) {
        let targets = Self.devicesToRestore(
            mutedDeviceID: mutedDeviceID,
            currentDefaultDeviceID: Self.defaultOutputDeviceID()
        )
        for targetID in targets {
            if usedVolumeFallback {
                if let cur = Self.getVirtualMainVolume(deviceID: targetID), cur < 0.005 {
                    _ = Self.setVirtualMainVolume(deviceID: targetID, volume: savedVolume)
                }
            } else if let curMute = Self.getMuteState(deviceID: targetID), curMute != 0 {
                _ = Self.setMuteState(deviceID: targetID, muted: false)
            }
        }
    }

    // MARK: - CoreAudio Property Helpers

    private static func defaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : AudioDeviceID(kAudioObjectUnknown)
    }

    private static func mutePropertyAddress(element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private static func isMuteSettable(deviceID: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var addr = mutePropertyAddress(element: element)
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr && settable.boolValue
    }

    private static func getMuteState(deviceID: AudioDeviceID) -> UInt32? {
        var mainAddr = mutePropertyAddress(element: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(deviceID, &mainAddr) {
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &mainAddr, 0, nil, &size, &muted) == noErr {
                return muted
            }
        }
        var foundChannel = false
        var anyUnmuted = false
        for elem: AudioObjectPropertyElement in [1, 2] {
            var addr = mutePropertyAddress(element: elem)
            guard AudioObjectHasProperty(deviceID, &addr) else { continue }
            var muted: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr {
                foundChannel = true
                if muted == 0 { anyUnmuted = true }
            }
        }
        guard foundChannel else { return nil }
        return anyUnmuted ? 0 : 1
    }

    private static func setMuteState(deviceID: AudioDeviceID, muted: Bool) -> Bool {
        let hasMain = isMuteSettable(deviceID: deviceID, element: kAudioObjectPropertyElementMain)
        let channels = hasMain ? [] : ([1, 2] as [AudioObjectPropertyElement]).filter {
            isMuteSettable(deviceID: deviceID, element: $0)
        }
        let elements = muteElementsToUpdate(hasMainSettable: hasMain, settableChannels: channels)
        guard !elements.isEmpty else { return false }

        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var anySucceeded = false
        for elem in elements {
            var addr = mutePropertyAddress(element: elem)
            if AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &value) == noErr {
                anySucceeded = true
            }
        }
        return anySucceeded
    }

    private static func getVirtualMainVolume(deviceID: AudioDeviceID) -> Float32? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return nil }
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &volume) == noErr ? volume : nil
    }

    private static func setVirtualMainVolume(deviceID: AudioDeviceID, volume: Float32) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &addr) else { return false }
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(deviceID, &addr, &settable) == noErr, settable.boolValue else { return false }
        var v = max(0.0, min(1.0, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &v) == noErr
    }
}
