import Foundation
import SwiftUI
import AppKit

@MainActor
public final class AppState: ObservableObject {
    @Published public var phase: PipelinePhase = .idle {
        didSet {
            pillController.setVisible(phase != .idle)
        }
    }
    @Published public var audioLevel: Float = 0.08
    @Published public var history: [DictationRecord] = []
    @Published public var llmConfig: LLMConfig = .default {
        didSet {
            syncASREngineConfig()
            if oldValue.asrProvider != llmConfig.asrProvider
                || oldValue.openAIASRBaseURL != llmConfig.openAIASRBaseURL {
                lastOpenAIASRProbeSummary = ""
                asrEngine.prewarmCloudSocketIfReady()
            }
            if oldValue.speechLocale != llmConfig.speechLocale {
                asrEngine.reloadSenseVoiceModelAsync()
            }
            if oldValue.selectedProvider != llmConfig.selectedProvider {
                apiKeyInput = KeychainHelper.loadAPIKey(for: llmConfig.selectedProvider)
                lastBenchmarkSummary = ""
                polishEngine.prewarmConnection(baseURL: llmConfig.baseURL, apiKey: apiKeyInput)
            }
            if oldValue.showInDock != llmConfig.showInDock {
                applyDockVisibilityPolicy()
            }
            saveConfig()
        }
    }
    @Published public var selectedTab: SidebarTab = .home
    @Published public var selectedSettingsTab: SettingsSectionTab = .general
    @Published public var triggerKey: TriggerKeyOption = .fnKey {
        didSet {
            hotkeyMonitor.triggerOption = triggerKey
            UserDefaults.standard.set(triggerKey.rawValue, forKey: "tz_trigger_key")
        }
    }
    @Published public var customHotkey: CustomHotkeySpec = .default {
        didSet {
            hotkeyMonitor.customSpec = customHotkey
            if let encoded = try? JSONEncoder().encode(customHotkey) {
                UserDefaults.standard.set(encoded, forKey: "tz_custom_hotkey_spec")
            }
        }
    }
    @Published public var isRecordingShortcut: Bool = false
    @Published public var triggerBehavior: TriggerBehavior = .tapToggle {
        didSet {
            hotkeyMonitor.behavior = triggerBehavior
            UserDefaults.standard.set(triggerBehavior.rawValue, forKey: "tz_trigger_behavior")
        }
    }
    @Published public var apiKeyInput: String = ""
    @Published public var volcSpeechKeyInput: String = ""
    @Published public var doubaoVoucherInput: String = ""
    @Published public var openAIASRKeyInput: String = ""
    @Published public var savedProviderKeyFlags: [LLMProviderOption: Bool] = [:]
    @Published public var micAuthorized: Bool = false
    @Published public var speechAuthorized: Bool = false
    @Published public var accessibilityGranted: Bool = false
    @Published public var senseVoiceLoaded: Bool = false
    @Published public var senseVoiceFullFP32: Bool = false
    @Published public var statusBanner: String = ""
    @Published public var sandboxText: String = ""
    @Published public var isBenchmarkingLLM: Bool = false
    @Published public var lastBenchmarkSummary: String = ""
    @Published public var isProbingSeedASR: Bool = false
    @Published public var lastSeedASRProbeSummary: String = ""
    @Published public var isProbingOpenAIASR: Bool = false
    @Published public var lastOpenAIASRProbeSummary: String = ""
    @Published public var activatingASRProvider: ASRProviderOption? = nil
    @Published public var asrActivationErrors: [ASRProviderOption: String] = [:]
    @Published public var activatingLLMProvider: LLMProviderOption? = nil
    @Published public var llmActivationErrors: [LLMProviderOption: String] = [:]
    @Published public var llmProviderBenchmarkSummaries: [LLMProviderOption: String] = [:]
    @Published public var showOnboardingSheet: Bool = false
    @Published public var isDownloadingOfflineModel: Bool = false
    @Published public var offlineDownloadProgress: Double = 0.0
    @Published public var offlineDownloadStatusText: String = ""

    // TypeZero Cloud Auth & Official Free Trial + Doubao ASR Voucher
    @Published public var cloudUser: CloudUserProfile? = nil
    @Published public var cloudCapabilities: CloudCapabilities? = nil
    @Published public var voucherProfile: CloudVoucherProfile? = nil
    @Published public var cloudEmailInput: String = ""
    @Published public var cloudCodeInput: String = ""
    @Published public var cloudCodeSent: Bool = false
    @Published public var isCloudAuthBusy: Bool = false
    @Published public var isWaitingGoogleOAuth: Bool = false
    @Published public var cloudAuthMessage: String = ""
    private var googlePollTask: Task<Void, Never>? = nil

    public var hasOwnVolcSpeechKey: Bool {
        !volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var hasDoubaoVoucher: Bool {
        CloudAuthClient.isVoucherCode(doubaoVoucherInput)
    }

    public var isDoubaoVoucherExhaustedOrRevoked: Bool {
        guard let vp = voucherProfile else { return false }
        return vp.exhausted || vp.revoked
    }

    public var hasAnyVolcSpeechCredential: Bool {
        hasOwnVolcSpeechKey || hasDoubaoVoucher
    }

    /// Priority rule:
    /// - If an active (non-exhausted, non-revoked) voucher exists, consume the gifted voucher quota first.
    /// - Once the voucher is exhausted/revoked (or removed), seamlessly auto-switch to the user's own Doubao API Key.
    public var effectiveDoubaoSpeechCredential: String {
        let own = volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let voucher = CloudAuthClient.isVoucherCode(doubaoVoucherInput)
            ? CloudAuthClient.normalizedVoucherCode(doubaoVoucherInput)
            : ""
        if !voucher.isEmpty && !isDoubaoVoucherExhaustedOrRevoked {
            return voucher
        }
        if !own.isEmpty {
            return own
        }
        return voucher
    }

    public var isUsingDoubaoVoucher: Bool {
        CloudAuthClient.isVoucherCode(effectiveDoubaoSpeechCredential)
    }

    // In-App Auto-Update
    @Published public var availableUpdate: AppVersionManifest? = nil
    @Published public var isCheckingForUpdate: Bool = false
    @Published public var isInstallingUpdate: Bool = false
    @Published public var updateDownloadProgress: Double = 0.0
    @Published public var updateStatusText: String = ""
    @Published public var skippedUpdateVersion: String = UserDefaults.standard.string(forKey: "tz_skipped_update_version") ?? ""
    private var updateCheckTimer: Timer? = nil

    public var currentAppVersion: String {
        AppUpdater.currentAppVersion
    }

    public var shouldShowUpdateBanner: Bool {
        guard let upd = availableUpdate else { return false }
        return isInstallingUpdate || upd.version != skippedUpdateVersion
    }

    public var isOfficialCloudTrialActive: Bool {
        guard llmConfig.useOfficialCloudTrial else { return false }
        let token = KeychainHelper.loadCloudJWT().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return false }
        if let u = cloudUser, u.balanceCny <= 0 || u.isBanned { return false }
        return true
    }

    public let lexiconStore = PersonalLexiconStore()
    private let asrEngine = StreamingASREngine()
    private let polishEngine = PolishEngine()
    private let hotkeyMonitor = HotkeyMonitor()
    private let pillController = FloatingPillController()
    private let modelDownloader = OfflineModelDownloader()
    private let audioDucker = SystemAudioDucker()

    private var activeContext: ActiveScreenContext = .empty
    private var activeMode: DictationMode = .dictate
    private var isSessionActive: Bool = false
    private var isFinalizingSession: Bool = false
    private var userSubmittedViaEnter: Bool = false
    private var liveInputSession: LiveInputSession? = nil
    private var sandboxBaseBeforeSession: String = ""
    private var isTypingInsideOwnApp: Bool = false
    private var permissionPollTimer: Timer? = nil
    private var workspaceActivateObserver: NSObjectProtocol? = nil
    private var llmKeepAliveTask: Task<Void, Never>? = nil

    private let historyURL: URL
    private let configURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = appSupport.appendingPathComponent("TypeZero", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.historyURL = dir.appendingPathComponent("history.json")
        self.configURL = dir.appendingPathComponent("config.json")

        loadConfig()
        loadHistory()
        self.apiKeyInput = KeychainHelper.loadAPIKey(for: llmConfig.selectedProvider)
        let rawVolcSlot = KeychainHelper.loadVolcSpeechAPIKey()
        if CloudAuthClient.isVoucherCode(rawVolcSlot) {
            // Auto-migrate legacy voucher stored inside API Key slot into dedicated voucher slot
            let migratedCode = CloudAuthClient.normalizedVoucherCode(rawVolcSlot)
            KeychainHelper.saveDoubaoVoucherCode(migratedCode)
            KeychainHelper.saveVolcSpeechAPIKey("")
        }
        self.volcSpeechKeyInput = KeychainHelper.loadVolcSpeechAPIKey()
        self.doubaoVoucherInput = KeychainHelper.loadDoubaoVoucherCode()
        self.openAIASRKeyInput = KeychainHelper.loadOpenAIASROverrideKey()
        refreshSavedKeyFlags()
        syncASREngineConfig()
        refreshPermissionStatus()

        if let savedSpecData = UserDefaults.standard.data(forKey: "tz_custom_hotkey_spec"),
           let spec = try? JSONDecoder().decode(CustomHotkeySpec.self, from: savedSpecData) {
            self.customHotkey = spec
        }
        if let savedTrigger = UserDefaults.standard.string(forKey: "tz_trigger_key"),
           let opt = TriggerKeyOption(rawValue: savedTrigger) {
            self.triggerKey = opt
        }
        if let savedBehavior = UserDefaults.standard.string(forKey: "tz_trigger_behavior"),
           let beh = TriggerBehavior(rawValue: savedBehavior) {
            self.triggerBehavior = beh
        }

        setupCallbacks()
        hotkeyMonitor.customSpec = customHotkey
        hotkeyMonitor.triggerOption = triggerKey
        hotkeyMonitor.behavior = triggerBehavior

        // Defer NSPanel / NSHostingView attachment & permission prompts to next main RunLoop tick
        // so SwiftUI's root AttributeGraph finishes initializing @StateObject without re-entrant layout crash!
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if AppLaunchGuard.promptInstallerVolumeMigrationIfNeeded() {
                return
            }
            AppLaunchGuard.ejectStaleInstallerDMGsInBackground()
            self.applyDockVisibilityPolicy()
            self.pillController.attach(appState: self)
            self.asrEngine.warmUp(localeIdentifier: self.llmConfig.speechLocale)
            self.polishEngine.prewarmConnection(baseURL: self.llmConfig.baseURL, apiKey: self.apiKeyInput)
            self.hotkeyMonitor.start()
            self.startPermissionWatcher()
            Task { [weak self] in
                await self?.refreshCloudAccount()
                await self?.refreshVoucherStatusIfApplicable(notifyUserOnLowOrExhausted: true)
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                await self?.checkForUpdates(manual: false)
            }
            self.startPeriodicUpdateChecker()
            self.workspaceActivateObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, !self.isSessionActive else { return }
                    self.asrEngine.prewarmCloudSocketIfReady()
                }
            }
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.asrEngine.shutdownHardwareImmediately()
                self?.audioDucker.restoreIfNeeded(scheduleBluetoothRecheck: false)
            }

            if !self.micAuthorized || !self.speechAuthorized {
                StreamingASREngine.requestPermissions { [weak self] mic, speech in
                    self?.micAuthorized = mic
                    self?.speechAuthorized = speech
                    if mic && speech {
                        self?.asrEngine.warmUp(localeIdentifier: self?.llmConfig.speechLocale ?? "auto")
                    }
                }
            }

            // First-run colleague onboarding check:
            // Auto-complete silently on already-configured machines; open 3-step setup guide on a brand-new colleague's Mac!
            if !UserDefaults.standard.bool(forKey: "tz_onboarding_done_v1") {
                let hasAnyASRReady = self.hasAnyVolcSpeechCredential
                    || self.hasEffectiveOpenAIASRKey
                    || StreamingASREngine.senseVoiceModelPaths() != nil
                if self.micAuthorized && self.accessibilityGranted && hasAnyASRReady {
                    UserDefaults.standard.set(true, forKey: "tz_onboarding_done_v1")
                } else {
                    self.showOnboardingSheet = true
                }
            }
        }
    }

    private func startPeriodicUpdateChecker() {
        updateCheckTimer?.invalidate()
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 4 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates(manual: false)
            }
        }
    }

    public func checkForUpdates(manual: Bool) async {
        guard !isCheckingForUpdate, !isInstallingUpdate else { return }
        isCheckingForUpdate = true
        if manual {
            updateStatusText = "正在检查最新版本…"
        }
        defer { isCheckingForUpdate = false }

        do {
            let manifest = try await AppUpdater.fetchLatestManifest(forceRefresh: manual)
            if AppUpdater.isNewerVersion(manifest.version, than: currentAppVersion) {
                availableUpdate = manifest
                if manual {
                    skippedUpdateVersion = ""
                    UserDefaults.standard.removeObject(forKey: "tz_skipped_update_version")
                    statusBanner = "🎉 发现新版本 TypeZero \(manifest.tag)（当前 v\(currentAppVersion)），可一键自动更新并重启"
                }
            } else {
                availableUpdate = nil
                if manual {
                    statusBanner = "✅ 当前已是最新版本 TypeZero v\(currentAppVersion)"
                }
            }
            updateStatusText = ""
        } catch {
            updateStatusText = ""
            if manual {
                statusBanner = "⚠️ 检查更新失败：\(error.localizedDescription)"
            }
        }
    }

    public func dismissUpdateBanner() {
        guard let upd = availableUpdate else { return }
        skippedUpdateVersion = upd.version
        UserDefaults.standard.set(upd.version, forKey: "tz_skipped_update_version")
    }

    public func installAvailableUpdate() async {
        guard !isInstallingUpdate, let manifest = availableUpdate else { return }
        isInstallingUpdate = true
        updateDownloadProgress = 0.02
        updateStatusText = "正在准备下载 TypeZero \(manifest.tag)…"

        do {
            let willAutoRelaunch = try await AppUpdater.downloadAndInstallMacOSUpdate(manifest: manifest) { [weak self] frac, status in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.updateDownloadProgress = frac
                    self.updateStatusText = status
                }
            }
            if willAutoRelaunch {
                statusBanner = "✨ 正在重启并切换至 TypeZero \(manifest.tag)…"
                try? await Task.sleep(nanoseconds: 350_000_000)
                NSApplication.shared.terminate(nil)
            } else {
                isInstallingUpdate = false
                statusBanner = "📦 已打开 TypeZero \(manifest.tag) 安装镜像，拖入 Applications 覆盖即可完成更新"
            }
        } catch {
            isInstallingUpdate = false
            updateDownloadProgress = 0.0
            updateStatusText = ""
            statusBanner = "❌ 自动更新失败：\(error.localizedDescription)"
        }
    }

    private func startPermissionWatcher() {
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isSessionActive else { return }
                if !self.micAuthorized || !self.speechAuthorized || !self.accessibilityGranted || !self.senseVoiceLoaded || self.showOnboardingSheet {
                    self.refreshPermissionStatus()
                }
            }
        }
    }

    private func setupCallbacks() {
        asrEngine.onModelReady = { [weak self] in
            self?.refreshPermissionStatus()
        }
        modelDownloader.onProgress = { [weak self] frac, status in
            guard let self else { return }
            self.offlineDownloadProgress = frac
            self.offlineDownloadStatusText = status
        }
        modelDownloader.onCompletion = { [weak self] success, msg in
            guard let self else { return }
            self.isDownloadingOfflineModel = false
            self.offlineDownloadStatusText = msg
            self.statusBanner = msg
            if success {
                self.asrEngine.reloadSenseVoiceModelAsync()
            }
        }
        asrEngine.onCloudFailoverNotice = { [weak self] reason in
            guard let self else { return }
            ContextInjector.appendInjectionTrace("asrFailover reason=\(reason)")
            self.statusBanner = "✈️ 离线满血热备已接管：\(reason)"
            if self.isUsingDoubaoVoucher {
                Task { [weak self] in
                    await self?.refreshVoucherStatusIfApplicable(notifyUserOnLowOrExhausted: true)
                }
            }
        }
        asrEngine.onError = { [weak self] errMsg in
            guard let self else { return }
            self.isSessionActive = false
            self.audioDucker.restoreIfNeeded()
            self.hotkeyMonitor.syncRecordingState(false)
            self.phase = .error(message: errMsg)
            self.scheduleIdleReset(after: 2.5)
        }
        asrEngine.onPartialResult = { [weak self] partial, flushTail in
            guard let self, self.isSessionActive else { return }
            let instantFixed = PolishEngine.applyInstantLocalDictionary(
                partial,
                entries: self.lexiconStore.entries,
                context: self.activeContext,
                config: self.llmConfig,
                stripPeriod: false
            )

            // Drive the zero-state-diff micro-symbol rhythm ribbon above the capsule wave!
            let spokenCount = instantFixed.filter { !$0.isWhitespace }.count
            AudioLevelBus.shared.pushRecognizedCount(spokenCount)

            // NOTE: Intentionally do NOT mutate `self.phase` here — avoids triggering full-app SwiftUI view hierarchy diffs on every syllable!
            if self.llmConfig.enableLiveInlineTyping && self.activeMode == .dictate {
                if self.isTypingInsideOwnApp {
                    self.sandboxText = self.sandboxBaseBeforeSession + instantFixed
                } else {
                    _ = self.liveInputSession?.updateLiveText(
                        instantFixed,
                        flushTrailingChar: flushTail,
                        isCloudStream: self.asrEngine.activeSessionUsesCloudSeedASR
                    )
                }
            }
        }
        hotkeyMonitor.onPrewarmMic = { [weak self] in
            self?.asrEngine.prewarmHotMicAsync()
        }
        hotkeyMonitor.onTriggerStart = { [weak self] in
            self?.beginDictationSession()
        }
        hotkeyMonitor.onTriggerStop = { [weak self] in
            Task { @MainActor in
                await self?.finishDictationSession()
            }
        }
        hotkeyMonitor.onCancel = { [weak self] in
            self?.cancelDictationSession()
        }
        hotkeyMonitor.onUserSubmitKeyPressed = { [weak self] in
            self?.handleUserPressedSubmitEnter()
        }
    }

    /// Invoked when the user physically hits bare `Return` / `Enter` / `Cmd+Return` to send their message directly:
    /// - If live inline text is already in the box while still recording: cleanly stops dictation WITHOUT re-pasting!
    /// - If we're currently inside the 200-400ms DeepSeek polish window: immediately aborts post-polish pasting so no ghost text remains!
    private func handleUserPressedSubmitEnter() {
        guard !isTypingInsideOwnApp else { return }
        if isFinalizingSession {
            userSubmittedViaEnter = true
            liveInputSession?.abortBecauseUserSubmitted()
            return
        }
        guard isSessionActive,
              llmConfig.enableLiveInlineTyping,
              activeMode == .dictate,
              let emitted = liveInputSession?.currentText,
              !emitted.isEmpty else {
            return
        }
        userSubmittedViaEnter = true
        isSessionActive = false
        hotkeyMonitor.syncRecordingState(false)
        asrEngine.cancel()
        audioDucker.restoreIfNeeded()
        AudioLevelBus.shared.reset()
        liveInputSession?.abortBecauseUserSubmitted()
        liveInputSession = nil
        phase = .idle
        ContextInjector.appendInjectionTrace("submitEnter app=\(activeContext.bundleID) stoppedLiveSession emitted=\(emitted.count)")
    }

    private func playSubtleCue(_ soundName: String, volume: Float = 0.30) {
        guard let sound = NSSound(named: NSSound.Name(soundName)) else { return }
        sound.volume = volume
        sound.play()
    }

    public func cancelDictationSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        llmKeepAliveTask?.cancel()
        llmKeepAliveTask = nil
        hotkeyMonitor.syncRecordingState(false)
        asrEngine.cancel()
        audioDucker.restoreIfNeeded()
        AudioLevelBus.shared.reset()
        if isTypingInsideOwnApp {
            sandboxText = sandboxBaseBeforeSession
        } else if let emitted = liveInputSession?.currentText, !emitted.isEmpty {
            ContextInjector.sendCleanBackspaces(count: emitted.count)
        }
        liveInputSession = nil
        phase = .idle
        playSubtleCue("Funk", volume: 0.22)
    }

    public func requestAllPermissions() {
        StreamingASREngine.requestPermissions { [weak self] mic, speech in
            self?.micAuthorized = mic
            self?.speechAuthorized = speech
            if mic && speech {
                self?.asrEngine.warmUp(localeIdentifier: self?.llmConfig.speechLocale ?? "auto")
            }
        }
        self.accessibilityGranted = ContextInjector.isAccessibilityTrusted(promptIfNeeded: true)
    }

    public func refreshPermissionStatus() {
        self.micAuthorized = StreamingASREngine.isMicrophoneAuthorized
        self.speechAuthorized = StreamingASREngine.isSpeechAuthorized
        self.accessibilityGranted = ContextInjector.isAccessibilityTrusted(promptIfNeeded: false)
        self.senseVoiceLoaded = asrEngine.isUsingSenseVoice
        self.senseVoiceFullFP32 = asrEngine.isFullPrecisionFP32
    }

    public func resetStaleTCCAndOpenSettings() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", "io.github.typezero.macos"]
        try? task.run()
        task.waitUntilExit()
        self.accessibilityGranted = false
        _ = ContextInjector.isAccessibilityTrusted(promptIfNeeded: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public var activeTriggerDisplayName: String {
        triggerKey == .custom ? "自定义快捷键 (\(customHotkey.label))" : triggerKey.displayName
    }

    public var activeTriggerCompactLabel: String {
        triggerKey == .custom ? customHotkey.label : triggerKey.compactSidebarLabel
    }

    public func startShortcutCapture() {
        isRecordingShortcut = true
        hotkeyMonitor.beginInteractiveCapture { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isRecordingShortcut = false
                switch result {
                case .preset(let opt):
                    self.triggerKey = opt
                    self.statusBanner = "✅ 全局快捷键已切换为「\(opt.displayName)」"
                case .custom(let spec):
                    self.customHotkey = spec
                    self.triggerKey = .custom
                    self.statusBanner = "✅ 自定义全局快捷键已生效：「\(spec.label)」"
                case .cancelled:
                    break
                }
            }
        }
    }

    public func cancelShortcutCapture() {
        hotkeyMonitor.cancelInteractiveCapture()
        isRecordingShortcut = false
    }

    public func refreshSavedKeyFlags() {
        var flags: [LLMProviderOption: Bool] = [:]
        for p in LLMProviderOption.allCases {
            flags[p] = KeychainHelper.hasSavedAPIKey(for: p)
        }
        savedProviderKeyFlags = flags
    }

    public func selectLLMProvider(_ provider: LLMProviderOption) {
        guard llmConfig.selectedProvider != provider else { return }
        llmConfig.selectProvider(provider)
        refreshSavedKeyFlags()
    }

    public var isGroqASRSelected: Bool {
        OpenAITranscriptionClient.isGroqEndpoint(llmConfig.openAIASRBaseURL)
    }

    public var isOpenAIASRReusingLLMKey: Bool {
        let overrideEmpty = openAIASRKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && KeychainHelper.loadOpenAIASROverrideKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard overrideEmpty, !isGroqASRSelected else { return false }
        return (savedProviderKeyFlags[.openai] ?? false)
            || (llmConfig.selectedProvider == .openai && !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    public var effectiveOpenAIASRKey: String {
        let typedOverride = openAIASRKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typedOverride.isEmpty { return typedOverride }
        let saved = KeychainHelper.loadEffectiveOpenAIASRAPIKey(for: llmConfig.openAIASRBaseURL)
        if !saved.isEmpty { return saved }
        if !isGroqASRSelected && llmConfig.selectedProvider == .openai {
            return apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    public var hasEffectiveOpenAIASRKey: Bool {
        !effectiveOpenAIASRKey.isEmpty || PolishEngine.isKeylessLocalEndpoint(llmConfig.openAIASRBaseURL)
    }

    public func syncASREngineConfig() {
        asrEngine.enableWhisperAGC = llmConfig.enableWhisperAGC
        asrEngine.speechLocale = llmConfig.speechLocale
        asrEngine.asrProvider = llmConfig.asrProvider
        asrEngine.volcSpeechAPIKey = KeychainHelper.loadEffectiveDoubaoSpeechCredential(
            voucherExhaustedOrRevoked: isDoubaoVoucherExhaustedOrRevoked
        )
        asrEngine.useCloudTrialRelay = isOfficialCloudTrialActive
        asrEngine.cloudTrialJWT = KeychainHelper.loadCloudJWT()
        asrEngine.openAIASRBaseURL = llmConfig.openAIASRBaseURL
        asrEngine.openAIASRModel = llmConfig.openAIASRModel
        asrEngine.openAIASRAPIKey = effectiveOpenAIASRKey
    }

    public func setSpeechLocale(_ locale: String) {
        let normalized = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = normalized.isEmpty ? "auto" : normalized
        var updated = llmConfig
        updated.speechLocale = target
        updated.speechLocaleExplicitlySet = true
        llmConfig = updated
    }

    // MARK: - TypeZero Cloud Auth & Official Free Trial

    public func refreshVoucherStatusIfApplicable(notifyUserOnLowOrExhausted: Bool = false) async {
        let raw = KeychainHelper.loadDoubaoVoucherCode().trimmingCharacters(in: .whitespacesAndNewlines)
        guard CloudAuthClient.isVoucherCode(raw) else {
            voucherProfile = nil
            return
        }
        let code = CloudAuthClient.normalizedVoucherCode(raw)
        do {
            let (_, profile) = try await CloudAuthClient.fetchVoucherStatus(code: code)
            voucherProfile = profile
            syncASREngineConfig()
            if notifyUserOnLowOrExhausted {
                if profile.revoked {
                    if hasOwnVolcSpeechKey {
                        asrActivationErrors[.volcSeedASR] = nil
                        statusBanner = "✅ 豆包兑换码（\(profile.code)）已停用，已自动无缝切换为您自己的豆包 API Key"
                    } else {
                        let msg = "⛔ 豆包语音兑换码（\(profile.code)）已停用，请联系发放人或填入您自己的豆包 API Key"
                        asrActivationErrors[.volcSeedASR] = msg
                        statusBanner = msg
                    }
                } else if profile.exhausted {
                    if hasOwnVolcSpeechKey {
                        asrActivationErrors[.volcSeedASR] = nil
                        statusBanner = String(
                            format: "✅ 豆包兑换码额度已用完（已用 %.1f / %.0f 分钟），已自动无缝切换为您自己的豆包 API Key",
                            profile.usedMinutes,
                            profile.quotaMinutes
                        )
                    } else {
                        let msg = String(
                            format: "⛔ 豆包语音兑换码时长已用完（已用 %.1f / %.0f 分钟），请联系发放人续期或填入您自己的豆包 API Key",
                            profile.usedMinutes,
                            profile.quotaMinutes
                        )
                        asrActivationErrors[.volcSeedASR] = msg
                        statusBanner = msg
                    }
                } else if profile.remainingMinutes <= 10.0 {
                    statusBanner = hasOwnVolcSpeechKey
                        ? String(
                            format: "⚠️ 豆包语音兑换码仅剩 %.1f 分钟，用完后将自动无缝切换为您自己的豆包 API Key",
                            profile.remainingMinutes
                        )
                        : String(
                            format: "⚠️ 豆包语音兑换码仅剩 %.1f 分钟（共 %.0f 分钟），请提前填入您自己的豆包 API Key 或联系续期",
                            profile.remainingMinutes,
                            profile.quotaMinutes
                        )
                }
            }
        } catch {
            // Keep existing profile on transient network hiccup
        }
    }

    public func refreshCloudAccount() async {
        if let caps = try? await CloudAuthClient.fetchCapabilities() {
            cloudCapabilities = caps
        }
        let token = KeychainHelper.loadCloudJWT().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            cloudUser = nil
            syncASREngineConfig()
            return
        }
        do {
            let profile = try await CloudAuthClient.fetchProfile(token: token)
            cloudUser = profile
            if profile.balanceCny <= 0 && llmConfig.useOfficialCloudTrial {
                llmConfig.useOfficialCloudTrial = false
                cloudAuthMessage = "体验额度已用完，已自动切回个人 API Key 模式"
            }
            syncASREngineConfig()
        } catch {
            // Keep token if transient network error; clear only if explicitly unauthorized
            let msg = error.localizedDescription
            if msg.contains("失效") || msg.contains("401") || msg.contains("暂停") {
                KeychainHelper.saveCloudJWT("")
                cloudUser = nil
                llmConfig.useOfficialCloudTrial = false
                syncASREngineConfig()
            }
        }
    }

    public func sendCloudEmailCode() async {
        let email = cloudEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            cloudAuthMessage = "请先输入邮箱地址（推荐使用 Gmail）"
            return
        }
        isCloudAuthBusy = true
        cloudAuthMessage = ""
        defer { isCloudAuthBusy = false }
        do {
            let msg = try await CloudAuthClient.sendEmailCode(email: email)
            cloudCodeSent = true
            cloudAuthMessage = "✅ \(msg)"
        } catch {
            cloudAuthMessage = "❌ \(error.localizedDescription)"
        }
    }

    public func verifyCloudEmailCode() async {
        let email = cloudEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = cloudCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, code.count == 6 else {
            cloudAuthMessage = "请输入邮箱和 6 位数字验证码"
            return
        }
        isCloudAuthBusy = true
        cloudAuthMessage = ""
        defer { isCloudAuthBusy = false }
        do {
            let res = try await CloudAuthClient.verifyEmailCode(email: email, code: code)
            applyCloudAuthSuccess(token: res.token, user: res.user, grantedTrial: res.grantedTrial ?? false)
            cloudCodeInput = ""
            cloudCodeSent = false
        } catch {
            cloudAuthMessage = "❌ \(error.localizedDescription)"
        }
    }

    public func startCloudGoogleLogin() async {
        googlePollTask?.cancel()
        isCloudAuthBusy = true
        cloudAuthMessage = ""
        defer { isCloudAuthBusy = false }
        do {
            let started = try await CloudAuthClient.startGoogleLogin()
            if let url = URL(string: started.authUrl) {
                NSWorkspace.shared.open(url)
            }
            isWaitingGoogleOAuth = true
            cloudAuthMessage = "请在浏览器中选择 Google 账号完成授权…"
            let sid = started.sessionId
            googlePollTask = Task { [weak self] in
                for _ in 0..<90 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    do {
                        let poll = try await CloudAuthClient.pollGoogleLogin(sessionId: sid)
                        if poll.status == "completed", let tok = poll.token, let u = poll.user {
                            self.isWaitingGoogleOAuth = false
                            self.applyCloudAuthSuccess(token: tok, user: u, grantedTrial: poll.grantedTrial ?? false)
                            return
                        } else if poll.status == "error" || poll.status == "expired" {
                            self.isWaitingGoogleOAuth = false
                            self.cloudAuthMessage = "❌ \(poll.error ?? "Google 登录未完成，请重试")"
                            return
                        }
                    } catch {
                        // Ignore transient poll hiccup
                    }
                }
                self?.isWaitingGoogleOAuth = false
            }
        } catch {
            isWaitingGoogleOAuth = false
            cloudAuthMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func applyCloudAuthSuccess(token: String, user: CloudUserProfile, grantedTrial: Bool) {
        KeychainHelper.saveCloudJWT(token)
        cloudUser = user
        if user.balanceCny > 0 {
            llmConfig.useOfficialCloudTrial = true
            llmConfig.selectASRProvider(.volcSeedASR)
        }
        syncASREngineConfig()
        let bonusNote = grantedTrial
            ? String(format: "🎁 新用户已自动获赠 ¥%.2f 免费体验额度，现在即可直接按快捷键说话！", user.balanceCny)
            : String(format: "✅ 登录成功，当前体验余额 ¥%.2f", user.balanceCny)
        cloudAuthMessage = bonusNote
        statusBanner = bonusNote
    }

    public func setUseOfficialCloudTrial(_ enabled: Bool) {
        if enabled {
            guard let u = cloudUser, u.balanceCny > 0 else {
                cloudAuthMessage = "体验余额不足，请配置您自己的 API Key"
                return
            }
            llmConfig.useOfficialCloudTrial = true
            llmConfig.selectASRProvider(.volcSeedASR)
            statusBanner = "☁️ 已切换至官方免费体验通道（豆包 2.0 + DeepSeek 4 Flash）"
        } else {
            llmConfig.useOfficialCloudTrial = false
            statusBanner = "🔑 已切换至个人 API Key（BYOK）模式"
        }
        syncASREngineConfig()
    }

    public func logoutCloudAccount() {
        googlePollTask?.cancel()
        isWaitingGoogleOAuth = false
        KeychainHelper.saveCloudJWT("")
        cloudUser = nil
        llmConfig.useOfficialCloudTrial = false
        cloudAuthMessage = "已退出云端账号"
        syncASREngineConfig()
    }

    public func selectASRProvider(_ provider: ASRProviderOption) {
        guard llmConfig.asrProvider != provider else { return }
        llmConfig.selectASRProvider(provider)
    }

    /// Strict activation flow for ASR engines: validates credentials / local model & live handshake FIRST.
    /// Only switches `llmConfig.asrProvider` (lighting up the single active badge) after verification succeeds.
    @discardableResult
    public func activateASRProvider(_ provider: ASRProviderOption) async -> Bool {
        guard activatingASRProvider == nil else { return false }
        activatingASRProvider = provider
        asrActivationErrors[provider] = nil
        defer { activatingASRProvider = nil }

        switch provider {
        case .volcSeedASR:
            let typedOwn = volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typedOwn.isEmpty {
                if CloudAuthClient.isVoucherCode(typedOwn) {
                    let code = CloudAuthClient.normalizedVoucherCode(typedOwn)
                    KeychainHelper.saveDoubaoVoucherCode(code)
                    doubaoVoucherInput = code
                    volcSpeechKeyInput = KeychainHelper.loadVolcSpeechAPIKey()
                } else {
                    KeychainHelper.saveVolcSpeechAPIKey(typedOwn)
                    volcSpeechKeyInput = KeychainHelper.loadVolcSpeechAPIKey()
                }
                syncASREngineConfig()
            }
            let key = KeychainHelper.loadEffectiveDoubaoSpeechCredential(
                voucherExhaustedOrRevoked: isDoubaoVoucherExhaustedOrRevoked
            )
            guard !key.isEmpty else {
                let err = "❌ 无法生效：请先填入您自己的豆包语音 API Key（或在下方填入朋友兑换码）"
                asrActivationErrors[provider] = err
                statusBanner = err
                return false
            }
            do {
                if CloudAuthClient.isVoucherCode(key) {
                    let code = CloudAuthClient.normalizedVoucherCode(key)
                    let (asrReady, profile) = try await CloudAuthClient.fetchVoucherStatus(code: code)
                    voucherProfile = profile
                    guard asrReady else {
                        throw CloudAuthError.serverError("云端豆包语音服务暂未就绪，请稍后再试")
                    }
                    guard !profile.revoked else {
                        throw CloudAuthError.serverError("该兑换码已被停用，请联系发放人")
                    }
                    guard !profile.exhausted else {
                        throw CloudAuthError.serverError(
                            String(format: "该兑换码时长已用完（已用 %.1f / %.0f 分钟），请联系发放人续期", profile.usedMinutes, profile.quotaMinutes)
                        )
                    }
                    let rttMs = try await VolcSeedASRClient.probeHandshakeLatency(
                        apiKey: code,
                        customEndpointURL: CloudAuthClient.cloudASRWSURL,
                        useBearerAuth: true
                    )
                    llmConfig.selectASRProvider(.volcSeedASR)
                    syncASREngineConfig()
                    speechAuthorized = StreamingASREngine.isSpeechAuthorized
                    let noteTag = profile.note.isEmpty ? "" : " · \(profile.note)"
                    lastSeedASRProbeSummary = String(
                        format: "🎟️ 兑换码校验通过（%@%@）：剩余 %.1f / %.0f 分钟 · 首帧 %dms",
                        profile.code, noteTag, profile.remainingMinutes, profile.quotaMinutes, rttMs
                    )
                    statusBanner = String(
                        format: "✅ 豆包语音兑换码已生效（剩余 %.1f 分钟），现在可直接按快捷键听写",
                        profile.remainingMinutes
                    )
                    return true
                } else {
                    voucherProfile = nil
                    let rttMs = try await VolcSeedASRClient.probeHandshakeLatency(apiKey: key)
                    llmConfig.selectASRProvider(.volcSeedASR)
                    syncASREngineConfig()
                    speechAuthorized = StreamingASREngine.isSpeechAuthorized
                    let hotCount = min(65, lexiconStore.entries.count)
                    lastSeedASRProbeSummary = "⚡ 校验通过并已生效（volc.seedasr.sauc.duration）：国内直连首帧 \(rttMs)ms · 已挂载 \(hotCount) 个专属热词"
                    statusBanner = "✅ 豆包流式语音大模型 2.0 校验通过，已切换为当前唯一生效引擎"
                    return true
                }
            } catch {
                let err = "❌ 校验未通过，未生效：\(error.localizedDescription)"
                asrActivationErrors[provider] = err
                statusBanner = err
                return false
            }

        case .openAIWhisper:
            llmConfig.openAIASRBaseURL = llmConfig.openAIASRBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if llmConfig.openAIASRBaseURL.isEmpty {
                llmConfig.openAIASRBaseURL = "https://api.openai.com/v1"
            }
            llmConfig.openAIASRModel = llmConfig.openAIASRModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if llmConfig.openAIASRModel.isEmpty {
                llmConfig.openAIASRModel = isGroqASRSelected ? "whisper-large-v3-turbo" : "gpt-4o-mini-transcribe"
            }
            let typedOverride = openAIASRKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typedOverride.isEmpty {
                KeychainHelper.saveOpenAIASRAPIKey(typedOverride)
                openAIASRKeyInput = KeychainHelper.loadOpenAIASROverrideKey()
            }
            syncASREngineConfig()
            let label = isGroqASRSelected ? "Groq Whisper" : "OpenAI 语音大模型"
            guard hasEffectiveOpenAIASRKey else {
                let err = isGroqASRSelected
                    ? "❌ 无法生效：缺少 Groq API Key，请先填入有效密钥（当前配置未生效）"
                    : "❌ 无法生效：缺少 OpenAI API Key，请先填入有效密钥（当前配置未生效）"
                asrActivationErrors[provider] = err
                statusBanner = err
                return false
            }
            let effectiveKey = effectiveOpenAIASRKey
            do {
                let rttMs = try await OpenAITranscriptionClient.probeLatency(
                    baseURL: llmConfig.openAIASRBaseURL,
                    model: llmConfig.openAIASRModel,
                    apiKey: effectiveKey
                )
                llmConfig.selectASRProvider(.openAIWhisper)
                syncASREngineConfig()
                speechAuthorized = StreamingASREngine.isSpeechAuthorized
                let hotCount = min(40, lexiconStore.entries.count)
                let keyMode = isOpenAIASRReusingLLMKey ? "自动复用 OpenAI Key" : "独立密钥"
                lastOpenAIASRProbeSummary = "⚡ 校验通过并已生效（\(llmConfig.openAIASRModel)）：音频上传+转写 \(rttMs)ms · \(keyMode) · 将注入 Top-\(hotCount) 词库提示"
                statusBanner = "✅ \(label) 校验通过，已切换为当前唯一生效引擎"
                return true
            } catch {
                let err = "❌ 校验未通过，未生效：\(error.localizedDescription)"
                asrActivationErrors[provider] = err
                statusBanner = err
                return false
            }

        case .localSenseVoice:
            if StreamingASREngine.senseVoiceModelPaths() == nil {
                let err = "❌ 无法生效：本机 SenseVoice 离线模型尚未下载就绪，请先下载离线模型包"
                asrActivationErrors[provider] = err
                statusBanner = err
                return false
            }
            if !senseVoiceLoaded {
                asrEngine.reloadSenseVoiceModelAsync()
                refreshPermissionStatus()
            }
            llmConfig.selectASRProvider(.localSenseVoice)
            syncASREngineConfig()
            speechAuthorized = StreamingASREngine.isSpeechAuthorized
            statusBanner = "✅ 纯本机 SenseVoice 离线模型已校验就绪并设为当前唯一生效引擎"
            return true
        }
    }

    public func saveLLMProviderDraft(provider: LLMProviderOption, baseURL: String, modelName: String, apiKey: String) {
        let cleanModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalModel = cleanModel.isEmpty ? provider.defaultModelName : cleanModel
        let cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalURL = cleanURL.isEmpty ? provider.defaultBaseURL : cleanURL

        llmConfig.providerModels[provider.rawValue] = finalModel
        if provider == .custom {
            llmConfig.customBaseURL = finalURL
        }
        if provider == .volcengine && finalModel.hasPrefix("ep-") {
            UserDefaults.standard.set(finalModel, forKey: "tz_ark_ep_id")
        }
        if llmConfig.selectedProvider == provider {
            llmConfig.modelName = finalModel
            llmConfig.baseURL = finalURL
        }

        KeychainHelper.saveAPIKey(apiKey, for: provider)
        if llmConfig.selectedProvider == provider {
            apiKeyInput = KeychainHelper.loadAPIKey(for: provider)
            polishEngine.prewarmConnection(baseURL: llmConfig.baseURL, apiKey: apiKeyInput)
        }
        refreshSavedKeyFlags()
        syncASREngineConfig()
        speechAuthorized = StreamingASREngine.isSpeechAuthorized
        llmActivationErrors[provider] = nil
        llmProviderBenchmarkSummaries[provider] = nil
        if llmConfig.selectedProvider == provider {
            lastBenchmarkSummary = ""
        }
        let savedKey = KeychainHelper.loadAPIKey(for: provider)
        if savedKey.isEmpty && !PolishEngine.isKeylessLocalEndpoint(finalURL) {
            statusBanner = "已清空「\(provider.shortName)」API Key"
        } else if llmConfig.selectedProvider == provider {
            statusBanner = "✅ 「\(provider.title)」密钥与模型已保存"
        } else {
            statusBanner = "💾 「\(provider.title)」配置已保存（尚未设为当前生效，点击「校验并生效」启用）"
        }
    }

    /// Strict activation flow for LLM providers: verifies API key & live benchmark FIRST.
    /// Only switches `llmConfig.selectedProvider` after the check passes.
    @discardableResult
    public func activateLLMProvider(
        _ provider: LLMProviderOption,
        baseURL: String,
        modelName: String,
        apiKey: String
    ) async -> Bool {
        guard activatingLLMProvider == nil else { return false }
        activatingLLMProvider = provider
        llmActivationErrors[provider] = nil
        defer { activatingLLMProvider = nil }

        let cleanModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalModel = cleanModel.isEmpty ? provider.defaultModelName : cleanModel
        let cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalURL = cleanURL.isEmpty ? provider.defaultBaseURL : cleanURL
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let isKeylessLocal = PolishEngine.isKeylessLocalEndpoint(finalURL)
        if cleanKey.isEmpty && !isKeylessLocal {
            let err = "❌ 无法生效：请先填入「\(provider.shortName)」API Key（当前配置未生效）"
            llmActivationErrors[provider] = err
            statusBanner = err
            return false
        }

        // Persist key & model draft first so user doesn't lose edits, without switching active provider yet.
        KeychainHelper.saveAPIKey(cleanKey, for: provider)
        llmConfig.providerModels[provider.rawValue] = finalModel
        if provider == .custom {
            llmConfig.customBaseURL = finalURL
        }
        if provider == .volcengine && finalModel.hasPrefix("ep-") {
            UserDefaults.standard.set(finalModel, forKey: "tz_ark_ep_id")
        }
        refreshSavedKeyFlags()

        var probeConfig = llmConfig
        probeConfig.selectedProvider = provider
        probeConfig.baseURL = finalURL
        probeConfig.modelName = finalModel

        do {
            let res = try await polishEngine.benchmarkLatency(config: probeConfig, apiKey: cleanKey)
            llmConfig.selectProvider(provider)
            llmConfig.baseURL = finalURL
            llmConfig.modelName = finalModel
            llmConfig.syncActiveEndpointEdits()
            apiKeyInput = KeychainHelper.loadAPIKey(for: provider)
            refreshSavedKeyFlags()
            syncASREngineConfig()
            polishEngine.prewarmConnection(baseURL: llmConfig.baseURL, apiKey: apiKeyInput)

            let flatSample = res.sampleOutput.replacingOccurrences(of: "\n", with: " ↵ ")
            let summary = "⚡ 校验通过并已生效（\(finalModel)）：首字 TTFT \(res.ttftMs)ms · 总耗时 \(res.totalMs)ms · 样例：「\(flatSample)」"
            llmProviderBenchmarkSummaries[provider] = summary
            lastBenchmarkSummary = summary
            statusBanner = "✅ 「\(provider.title)」校验通过，已切换为当前唯一生效排版模型"
            return true
        } catch {
            let err = "❌ 校验未通过，未生效：\(error.localizedDescription)"
            llmActivationErrors[provider] = err
            statusBanner = err
            return false
        }
    }

    public func runLLMProviderBenchmark(
        provider: LLMProviderOption,
        baseURL: String,
        modelName: String,
        apiKey: String
    ) async {
        guard !isBenchmarkingLLM else { return }
        isBenchmarkingLLM = true
        llmActivationErrors[provider] = nil
        let cleanModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalModel = cleanModel.isEmpty ? provider.defaultModelName : cleanModel
        let cleanURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalURL = cleanURL.isEmpty ? provider.defaultBaseURL : cleanURL
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        llmProviderBenchmarkSummaries[provider] = "正在预热连接并实测 \(finalModel) 首包延迟…"
        if llmConfig.selectedProvider == provider {
            lastBenchmarkSummary = llmProviderBenchmarkSummaries[provider] ?? ""
        }
        defer { isBenchmarkingLLM = false }

        if !cleanKey.isEmpty {
            KeychainHelper.saveAPIKey(cleanKey, for: provider)
            refreshSavedKeyFlags()
        }

        var probeConfig = llmConfig
        probeConfig.selectedProvider = provider
        probeConfig.baseURL = finalURL
        probeConfig.modelName = finalModel

        do {
            let res = try await polishEngine.benchmarkLatency(config: probeConfig, apiKey: cleanKey)
            let flatSample = res.sampleOutput.replacingOccurrences(of: "\n", with: " ↵ ")
            let summary = "⚡ 实测通过（\(finalModel)）：首字 TTFT \(res.ttftMs)ms · 总耗时 \(res.totalMs)ms · 样例：「\(flatSample)」"
            llmProviderBenchmarkSummaries[provider] = summary
            if llmConfig.selectedProvider == provider {
                lastBenchmarkSummary = summary
            }
            statusBanner = "⚡ \(provider.shortName) 实测成功：首字 TTFT \(res.ttftMs)ms"
        } catch {
            let summary = "❌ 测速未通过：\(error.localizedDescription)"
            llmProviderBenchmarkSummaries[provider] = summary
            if llmConfig.selectedProvider == provider {
                lastBenchmarkSummary = summary
            }
        }
    }

    public func applyOpenAIASRPreset(baseURL: String, model: String) {
        llmConfig.openAIASRBaseURL = baseURL
        llmConfig.openAIASRModel = model
        lastOpenAIASRProbeSummary = ""
        syncASREngineConfig()
    }

    public func saveAPIKey() {
        llmConfig.syncActiveEndpointEdits()
        if llmConfig.selectedProvider == .volcengine && llmConfig.modelName.hasPrefix("ep-") {
            UserDefaults.standard.set(llmConfig.modelName, forKey: "tz_ark_ep_id")
        }
        KeychainHelper.saveAPIKey(apiKeyInput, for: llmConfig.selectedProvider)
        apiKeyInput = KeychainHelper.loadAPIKey(for: llmConfig.selectedProvider)
        refreshSavedKeyFlags()
        syncASREngineConfig()
        speechAuthorized = StreamingASREngine.isSpeechAuthorized
        polishEngine.prewarmConnection(baseURL: llmConfig.baseURL, apiKey: apiKeyInput)
        lastBenchmarkSummary = ""
        statusBanner = apiKeyInput.isEmpty
            ? "已清空「\(llmConfig.selectedProvider.shortName)」API Key"
            : "✅ 「\(llmConfig.selectedProvider.title)」密钥与模型已保存并立即生效"
    }

    public func saveVolcSpeechAPIKey() {
        let trimmed = volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if CloudAuthClient.isVoucherCode(trimmed) {
            // Gracefully route pasted voucher codes into the dedicated voucher slot without clobbering own key
            doubaoVoucherInput = CloudAuthClient.normalizedVoucherCode(trimmed)
            volcSpeechKeyInput = KeychainHelper.loadVolcSpeechAPIKey()
            Task { [weak self] in
                await self?.saveDoubaoVoucherCode()
            }
            return
        }
        KeychainHelper.saveVolcSpeechAPIKey(trimmed)
        volcSpeechKeyInput = KeychainHelper.loadVolcSpeechAPIKey()
        syncASREngineConfig()
        speechAuthorized = StreamingASREngine.isSpeechAuthorized
        lastSeedASRProbeSummary = ""
        asrActivationErrors[.volcSeedASR] = nil
        if volcSpeechKeyInput.isEmpty {
            statusBanner = hasDoubaoVoucher
                ? "已清空自有豆包 API Key（当前继续使用已存兑换码）"
                : "已清空豆包语音密钥"
        } else if isUsingDoubaoVoucher {
            let remText = voucherProfile.map { String(format: "剩余 %.1f 分钟", $0.remainingMinutes) } ?? "剩余额度"
            statusBanner = "✅ 您自己的豆包 API Key 已保存（将优先用完兑换码\(remText)，用完后自动无缝切换为自有 Key）"
        } else if llmConfig.asrProvider == .volcSeedASR {
            statusBanner = "✅ 您自己的豆包 Seed-ASR 2.0 密钥已保存并生效"
        } else {
            statusBanner = "💾 豆包自有密钥已保存（尚未设为当前生效，点击「校验并切换」启用）"
        }
    }

    public func saveDoubaoVoucherCode() async {
        let trimmed = doubaoVoucherInput.trimmingCharacters(in: .whitespacesAndNewlines)
        asrActivationErrors[.volcSeedASR] = nil
        if trimmed.isEmpty {
            clearDoubaoVoucherCode()
            return
        }
        guard CloudAuthClient.isVoucherCode(trimmed) else {
            let err = "❌ 兑换码格式应为 TZ-XXXX-XXXX（自有密钥请填上方 API Key 输入框）"
            asrActivationErrors[.volcSeedASR] = err
            statusBanner = err
            return
        }
        let code = CloudAuthClient.normalizedVoucherCode(trimmed)
        KeychainHelper.saveDoubaoVoucherCode(code)
        doubaoVoucherInput = code
        voucherProfile = nil
        syncASREngineConfig()
        speechAuthorized = StreamingASREngine.isSpeechAuthorized
        statusBanner = "🎟️ 正在校验豆包语音兑换码 \(code)…"

        do {
            let (asrReady, profile) = try await CloudAuthClient.fetchVoucherStatus(code: code)
            voucherProfile = profile
            syncASREngineConfig()
            if profile.revoked {
                let msg = hasOwnVolcSpeechKey
                    ? "⚠️ 该兑换码（\(profile.code)）已停用，当前已自动使用您自己的豆包 API Key"
                    : "⛔ 豆包语音兑换码（\(profile.code)）已停用，请联系发放人或填入自有 API Key"
                if !hasOwnVolcSpeechKey { asrActivationErrors[.volcSeedASR] = msg }
                statusBanner = msg
                return
            }
            if profile.exhausted {
                let msg = hasOwnVolcSpeechKey
                    ? String(format: "✅ 该兑换码时长已用完（已用 %.1f / %.0f 分钟），当前已自动使用您自己的豆包 API Key", profile.usedMinutes, profile.quotaMinutes)
                    : String(format: "⛔ 豆包语音兑换码时长已用完（已用 %.1f / %.0f 分钟），请联系发放人续期或填入自有 API Key", profile.usedMinutes, profile.quotaMinutes)
                if !hasOwnVolcSpeechKey { asrActivationErrors[.volcSeedASR] = msg }
                statusBanner = msg
                return
            }
            guard asrReady else {
                let msg = "⚠️ 云端豆包语音服务暂未就绪，请稍后再试"
                asrActivationErrors[.volcSeedASR] = msg
                statusBanner = msg
                return
            }
            llmConfig.selectASRProvider(.volcSeedASR)
            syncASREngineConfig()
            let noteTag = profile.note.isEmpty ? "" : "（\(profile.note)）"
            let autoSwitchHint = hasOwnVolcSpeechKey ? " · 用完自动切回自有 Key" : ""
            lastSeedASRProbeSummary = String(
                format: "🎟️ 兑换码已激活：%@%@ · 剩余 %.1f / %.0f 分钟%@",
                profile.code, noteTag, profile.remainingMinutes, profile.quotaMinutes, autoSwitchHint
            )
            statusBanner = String(
                format: "✅ 豆包兑换码已生效（剩余 %.1f 分钟%@）",
                profile.remainingMinutes, autoSwitchHint
            )
        } catch {
            let msg = "❌ 兑换码校验失败：\(error.localizedDescription)"
            asrActivationErrors[.volcSeedASR] = msg
            statusBanner = msg
        }
    }

    public func clearDoubaoVoucherCode() {
        KeychainHelper.saveDoubaoVoucherCode("")
        doubaoVoucherInput = ""
        voucherProfile = nil
        syncASREngineConfig()
        speechAuthorized = StreamingASREngine.isSpeechAuthorized
        lastSeedASRProbeSummary = ""
        asrActivationErrors[.volcSeedASR] = nil
        statusBanner = hasOwnVolcSpeechKey
            ? "已移除兑换码，已自动切回您自己的豆包 API Key"
            : "已移除豆包语音兑换码"
    }

    public func saveOpenAIASRConfig() {
        llmConfig.openAIASRBaseURL = llmConfig.openAIASRBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if llmConfig.openAIASRBaseURL.isEmpty {
            llmConfig.openAIASRBaseURL = "https://api.openai.com/v1"
        }
        llmConfig.openAIASRModel = llmConfig.openAIASRModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if llmConfig.openAIASRModel.isEmpty {
            llmConfig.openAIASRModel = isGroqASRSelected ? "whisper-large-v3-turbo" : "gpt-4o-mini-transcribe"
        }
        KeychainHelper.saveOpenAIASRAPIKey(openAIASRKeyInput)
        openAIASRKeyInput = KeychainHelper.loadOpenAIASROverrideKey()
        syncASREngineConfig()
        speechAuthorized = StreamingASREngine.isSpeechAuthorized
        lastOpenAIASRProbeSummary = ""
        asrActivationErrors[.openAIWhisper] = nil
        asrEngine.prewarmCloudSocketIfReady()
        let label = isGroqASRSelected ? "Groq Whisper" : "OpenAI 语音大模型"
        if hasEffectiveOpenAIASRKey {
            let keyNote = isOpenAIASRReusingLLMKey ? "（自动复用 OpenAI 密钥）" : ""
            if llmConfig.asrProvider == .openAIWhisper {
                statusBanner = "✅ \(label)（\(llmConfig.openAIASRModel)）已保存\(keyNote)"
            } else {
                statusBanner = "💾 \(label)（\(llmConfig.openAIASRModel)）已保存\(keyNote)（点击「校验并生效」启用）"
            }
        } else {
            statusBanner = "⚠️ 已保存 \(label) 接口设置，但当前尚未填入有效 API Key"
        }
    }

    public func runOpenAIASRProbe() async {
        guard !isProbingOpenAIASR else { return }
        isProbingOpenAIASR = true
        let label = isGroqASRSelected ? "Groq Whisper" : "OpenAI 语音"
        lastOpenAIASRProbeSummary = "正在向 \(llmConfig.openAIASRModel) 发送 0.35s 音频实测端到端延迟…"
        defer { isProbingOpenAIASR = false }

        KeychainHelper.saveOpenAIASRAPIKey(openAIASRKeyInput)
        openAIASRKeyInput = KeychainHelper.loadOpenAIASROverrideKey()
        syncASREngineConfig()
        let effectiveKey = effectiveOpenAIASRKey

        do {
            let rttMs = try await OpenAITranscriptionClient.probeLatency(
                baseURL: llmConfig.openAIASRBaseURL,
                model: llmConfig.openAIASRModel,
                apiKey: effectiveKey
            )
            let hotCount = min(40, lexiconStore.entries.count)
            let keyMode = isOpenAIASRReusingLLMKey ? "自动复用 OpenAI Key" : "独立密钥"
            lastOpenAIASRProbeSummary = "⚡ 实测通过（\(llmConfig.openAIASRModel)）：音频上传+转写 \(rttMs)ms · \(keyMode) · 将注入 Top-\(hotCount) 词库提示"
            statusBanner = "⚡ \(label) 连通成功：实测 \(rttMs)ms"
        } catch {
            lastOpenAIASRProbeSummary = "❌ \(label) 连通未通过：\(error.localizedDescription)"
        }
    }

    public func startOfflineModelDownload() {
        guard !isDownloadingOfflineModel else { return }
        isDownloadingOfflineModel = true
        offlineDownloadProgress = 0.01
        offlineDownloadStatusText = "正在初始化 886MB 离线满血包下载…"
        modelDownloader.startDownload()
    }

    public func cancelOfflineModelDownload() {
        modelDownloader.cancelDownload()
        isDownloadingOfflineModel = false
    }

    public func applyDockVisibilityPolicy() {
        let desired: NSApplication.ActivationPolicy = llmConfig.showInDock ? .regular : .accessory
        if NSApp.activationPolicy() != desired {
            NSApp.setActivationPolicy(desired)
        }
    }

    public func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "tz_onboarding_done_v1")
        showOnboardingSheet = false
    }

    public func runSeedASRProbe() async {
        guard !isProbingSeedASR else { return }
        isProbingSeedASR = true
        let typedOwn = volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typedOwn.isEmpty && !CloudAuthClient.isVoucherCode(typedOwn) {
            KeychainHelper.saveVolcSpeechAPIKey(typedOwn)
            volcSpeechKeyInput = KeychainHelper.loadVolcSpeechAPIKey()
        }
        let key = KeychainHelper.loadEffectiveDoubaoSpeechCredential(
            voucherExhaustedOrRevoked: isDoubaoVoucherExhaustedOrRevoked
        )
        asrEngine.volcSpeechAPIKey = key
        let isVoucher = CloudAuthClient.isVoucherCode(key)
        lastSeedASRProbeSummary = isVoucher
            ? "正在校验豆包语音兑换码剩余时长与云端通道…"
            : "正在通过国内直连通道实测豆包 Seed-ASR 2.0 双向流…"
        defer { isProbingSeedASR = false }

        do {
            if CloudAuthClient.isVoucherCode(key) {
                let code = CloudAuthClient.normalizedVoucherCode(key)
                let (asrReady, profile) = try await CloudAuthClient.fetchVoucherStatus(code: code)
                voucherProfile = profile
                guard asrReady else {
                    throw CloudAuthError.serverError("云端豆包语音服务暂未就绪")
                }
                guard !profile.revoked else {
                    throw CloudAuthError.serverError("该兑换码已被停用，请联系发放人")
                }
                guard !profile.exhausted else {
                    throw CloudAuthError.serverError(
                        String(format: "该兑换码时长已用完（已用 %.1f / %.0f 分钟），请联系发放人续期", profile.usedMinutes, profile.quotaMinutes)
                    )
                }
                let rttMs = try await VolcSeedASRClient.probeHandshakeLatency(
                    apiKey: code,
                    customEndpointURL: CloudAuthClient.cloudASRWSURL,
                    useBearerAuth: true
                )
                let noteTag = profile.note.isEmpty ? "" : " · \(profile.note)"
                lastSeedASRProbeSummary = String(
                    format: "🎟️ 兑换码实测通过（%@%@）：剩余 %.1f / %.0f 分钟 · 首帧 %dms",
                    profile.code, noteTag, profile.remainingMinutes, profile.quotaMinutes, rttMs
                )
                statusBanner = String(
                    format: "⚡ 豆包兑换码连通成功（剩余 %.1f 分钟 · %dms）",
                    profile.remainingMinutes, rttMs
                )
            } else {
                let rttMs = try await VolcSeedASRClient.probeHandshakeLatency(apiKey: key)
                let hotCount = min(65, lexiconStore.entries.count)
                lastSeedASRProbeSummary = "⚡ 实测通过（volc.seedasr.sauc.duration）：国内直连握手+首帧 \(rttMs)ms · 已挂载 \(hotCount) 个专属热词"
                statusBanner = "⚡ 豆包 Seed-ASR 2.0 连通成功：首帧 \(rttMs)ms"
            }
        } catch {
            lastSeedASRProbeSummary = "❌ 豆包语音连通未通过：\(error.localizedDescription)"
        }
    }

    public func runLiveEngineBenchmark() async {
        guard !isBenchmarkingLLM else { return }
        isBenchmarkingLLM = true
        llmConfig.syncActiveEndpointEdits()
        lastBenchmarkSummary = "正在预热连接并实测 \(llmConfig.modelName) 首包延迟…"
        defer { isBenchmarkingLLM = false }

        // Auto-save if user typed into field without clicking save first
        if !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            KeychainHelper.saveAPIKey(apiKeyInput, for: llmConfig.selectedProvider)
            apiKeyInput = KeychainHelper.loadAPIKey(for: llmConfig.selectedProvider)
            refreshSavedKeyFlags()
        }
        let key = KeychainHelper.loadAPIKey(for: llmConfig.selectedProvider)

        do {
            let res = try await polishEngine.benchmarkLatency(config: llmConfig, apiKey: key)
            let flatSample = res.sampleOutput.replacingOccurrences(of: "\n", with: " ↵ ")
            lastBenchmarkSummary = "⚡ 实测通过（\(llmConfig.modelName)）：首字 TTFT \(res.ttftMs)ms · 总耗时 \(res.totalMs)ms · 样例：「\(flatSample)」"
            statusBanner = "⚡ \(llmConfig.selectedProvider.shortName) 实测成功：首字 TTFT \(res.ttftMs)ms"
        } catch {
            lastBenchmarkSummary = "❌ 测速未通过：\(error.localizedDescription)"
        }
    }

    public func runStylePreview(
        sampleText: String,
        toneProfile: AppToneProfile
    ) async throws -> (output: String, ttftMs: Int, totalMs: Int, usedLocalOnly: Bool) {
        var effectiveConfig = llmConfig
        var key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if isOfficialCloudTrialActive {
            effectiveConfig.selectedProvider = .deepseek
            effectiveConfig.baseURL = CloudAuthClient.cloudLLMBaseURL
            effectiveConfig.modelName = "deepseek-flash"
            key = KeychainHelper.loadCloudJWT().trimmingCharacters(in: .whitespacesAndNewlines)
        } else if key.isEmpty {
            key = KeychainHelper.loadAPIKey(for: effectiveConfig.selectedProvider)
        }

        let syntheticContext: ActiveScreenContext = {
            switch toneProfile {
            case .instantMessaging:
                return ActiveScreenContext(appName: "Feishu", bundleID: "com.electron.lark", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true)
            case .emailAndFormalDoc:
                return ActiveScreenContext(appName: "Mail", bundleID: "com.apple.mail", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true)
            case .shellTerminal:
                return ActiveScreenContext(appName: "Terminal", bundleID: "com.apple.Terminal", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true)
            case .aiPromptAndNotes:
                return ActiveScreenContext(appName: "Notes", bundleID: "com.apple.Notes", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true)
            }
        }()

        let recalled = lexiconStore.recallRelevantTerms(for: sampleText, activeWindowTitle: "", limit: 26)
        return try await polishEngine.previewStyle(
            sampleRawSpeech: sampleText,
            sceneContext: syntheticContext,
            recalledTerms: recalled,
            config: effectiveConfig,
            apiKey: key
        )
    }

    public func beginDictationSession() {
        guard !isSessionActive, !isFinalizingSession else {
            hotkeyMonitor.syncRecordingState(isSessionActive)
            return
        }

        if !micAuthorized || !speechAuthorized || !accessibilityGranted {
            refreshPermissionStatus()
        }

        if !micAuthorized || !speechAuthorized {
            StreamingASREngine.requestPermissions { [weak self] mic, speech in
                guard let self else { return }
                self.micAuthorized = mic
                self.speechAuthorized = speech
                if !mic {
                    self.phase = .error(message: "请在系统设置→麦克风中允许 TypeZero")
                    self.scheduleIdleReset(after: 2.8)
                } else if !speech {
                    self.phase = .error(message: "请在系统设置→语音识别中允许 TypeZero")
                    self.scheduleIdleReset(after: 2.8)
                }
            }
            return
        }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontBundle = frontApp?.bundleIdentifier ?? ""
        let frontName = frontApp?.localizedName ?? ""
        isTypingInsideOwnApp = (frontBundle == "io.github.typezero.macos")
        if !isTypingInsideOwnApp && !accessibilityGranted {
            hotkeyMonitor.syncRecordingState(false)
            phase = .error(message: "请在系统设置→辅助功能中开启 TypeZero 才能写入外部输入框")
            scheduleIdleReset(after: 2.6)
            return
        }

        // 1. 0.0ms INSTANT visual + audio feedback & immediate mic stream launch (ZERO synchronous IPC or CoreAudio stall on MainActor!)
        userSubmittedViaEnter = false
        isSessionActive = true
        hotkeyMonitor.syncRecordingState(true)
        if isTypingInsideOwnApp {
            sandboxBaseBeforeSession = sandboxText
        }

        let fastInitialContext = ActiveScreenContext(
            appName: frontName,
            bundleID: frontBundle,
            windowTitle: "",
            selectedText: "",
            precedingText: "",
            hasFocusedTextInput: frontBundle != "com.apple.finder"
        )
        activeContext = fastInitialContext
        activeMode = .dictate
        AudioLevelBus.shared.reset()
        let session: LiveInputSession? = llmConfig.enableLiveInlineTyping ? LiveInputSession(context: fastInitialContext) : nil
        liveInputSession = session
        phase = .listening(livePreview: "", mode: .dictate)
        if llmConfig.enableAutoMuteDuringDictation {
            audioDucker.muteIfNeeded()
        } else {
            playSubtleCue("Tink", volume: 0.30)
        }

        // 2. Zero-wait parallel mic start!
        // Launch ASR streaming immediately (~0.5ms using in-memory lexicon + history + clipboard)
        // so the very first syllable is NEVER clipped while AXUIElement inspects heavy Electron/browser trees.
        syncASREngineConfig()
        let localeID = llmConfig.speechLocale
        let entriesSnapshot = lexiconStore.entries
        let recentSnippets = Array(history.prefix(2).map(\.polishedText))
        let ownSandboxSnapshot = isTypingInsideOwnApp ? String(sandboxText.suffix(140)) : ""
        let rawClip = (NSPasteboard.general.string(forType: .string) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let shortClipboardHint = (rawClip.count >= 2 && rawClip.count <= 42 && !rawClip.contains("\n")) ? rawClip : ""

        let currentBaseURL = llmConfig.baseURL
        let currentKey = KeychainHelper.loadAPIKey(for: llmConfig.selectedProvider)
        let didDispatchKVPrewarm = polishEngine.prewarmPrefixCacheIfNeeded(
            config: llmConfig,
            apiKey: currentKey,
            isCloudTrialRelay: isOfficialCloudTrialActive
        )
        if !didDispatchKVPrewarm {
            polishEngine.prewarmConnection(baseURL: currentBaseURL, apiKey: currentKey)
        }

        // Mid-recording HTTP/2 TLS keep-alive pulse every 5.5s so gateway idle timeouts never close the warm socket during 10-30s speeches!
        llmKeepAliveTask?.cancel()
        if llmConfig.formattingStyle != .verbatimLocal && (!currentKey.isEmpty || isOfficialCloudTrialActive) {
            let keepAliveURL = isOfficialCloudTrialActive ? CloudAuthClient.cloudLLMBaseURL : currentBaseURL
            let keepAliveKey = isOfficialCloudTrialActive ? KeychainHelper.loadCloudJWT() : currentKey
            llmKeepAliveTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_500_000_000)
                    guard !Task.isCancelled else { break }
                    let stillRecording = await MainActor.run { self?.isSessionActive == true }
                    guard stillRecording else { break }
                    self?.polishEngine.prewarmConnection(baseURL: keepAliveURL, apiKey: keepAliveKey)
                }
            }
        }

        // Immediate hotword ranking + dialog_ctx from fast in-memory sources -> instant mic open!
        let immediateHint = ([frontName, shortClipboardHint, ownSandboxSnapshot] + recentSnippets).joined(separator: " ")
        var topTerms = PersonalLexiconStore.rankHotwords(from: entriesSnapshot, contextHint: immediateHint, limit: 64)
        if shortClipboardHint.count >= 2,
           shortClipboardHint.count <= 14,
           !shortClipboardHint.contains(" "),
           !topTerms.contains(where: { $0.caseInsensitiveCompare(shortClipboardHint) == .orderedSame }) {
            topTerms.insert(shortClipboardHint, at: 0)
        }
        var dialogCtxItems: [String] = []
        let cleanOwnPre = ownSandboxSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanOwnPre.isEmpty {
            dialogCtxItems.append(String(cleanOwnPre.suffix(100)))
        }
        for snippet in recentSnippets.prefix(2) {
            let s = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty {
                dialogCtxItems.append(String(s.suffix(100)))
            }
        }
        asrEngine.startStreamingAsync(
            localeIdentifier: localeID,
            contextualStrings: topTerms,
            dialogContext: Array(dialogCtxItems.prefix(2))
        )

        // 3. In parallel, inspect active AX input-box context in background for Pass-2 LLM & rewrite-selection mode.
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let fullCtx = ContextInjector.captureCurrentContext()
            session?.updateContext(fullCtx)

            DispatchQueue.main.async {
                guard let self, self.isSessionActive else { return }
                self.activeContext = fullCtx
                if !fullCtx.selectedText.isEmpty {
                    self.activeMode = .rewriteSelection
                    self.phase = .listening(livePreview: "", mode: .rewriteSelection)
                }
            }
        }
    }

    public func finishDictationSession() async {
        guard isSessionActive, !isFinalizingSession else { return }
        isFinalizingSession = true
        defer {
            isFinalizingSession = false
            audioDucker.restoreIfNeeded()
        }
        hotkeyMonitor.syncRecordingState(false)
        llmKeepAliveTask?.cancel()
        llmKeepAliveTask = nil

        // Prepare effective LLM config & context snapshots upfront so Speculative Parallel Polish can fire at `t = 0ms`!
        let snapshotContext = activeContext
        let snapshotMode = activeMode
        let recentTexts = history.prefix(3).map(\.polishedText).reversed() as [String]
        var effectiveConfig = llmConfig
        var key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if isOfficialCloudTrialActive {
            effectiveConfig.selectedProvider = .deepseek
            effectiveConfig.baseURL = CloudAuthClient.cloudLLMBaseURL
            effectiveConfig.modelName = "deepseek-flash"
            key = KeychainHelper.loadCloudJWT().trimmingCharacters(in: .whitespacesAndNewlines)
        } else if key.isEmpty {
            key = KeychainHelper.loadAPIKey(for: effectiveConfig.selectedProvider)
        }
        let frozenConfig = effectiveConfig
        let frozenKey = key
        let localSenseVoiceFlag = asrEngine.isUsingSenseVoice

        typealias SpecPolishOutcome = (text: String, latencyMs: Int, totalMs: Int, usedFastPath: Bool)

        func makeSpeculativeTask(for candidateDraft: String) -> (task: Task<SpecPolishOutcome, Never>?, draft: String, reason: String) {
            if asrEngine.activeSessionUsesOpenAIASR {
                return (nil, "", "skip-openai")
            }
            let clean = candidateDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else {
                return (nil, "", "skip-empty")
            }
            guard frozenConfig.formattingStyle != .verbatimLocal else {
                return (nil, "", "skip-verbatim")
            }
            guard !frozenKey.isEmpty || PolishEngine.isKeylessLocalEndpoint(frozenConfig.baseURL) else {
                return (nil, "", "skip-nokey")
            }
            let eligibleForAtomicSpec = clean.count > LiveInputSession.maxDraftCharsForLiveSSE
                || snapshotContext.prefersAtomicPolishReplacement
                || !llmConfig.enableLiveInlineTyping
                || snapshotMode == .rewriteSelection
            guard eligibleForAtomicSpec else {
                return (nil, "", "skip-short-sse")
            }

            let specRecalled = lexiconStore.recallRelevantTerms(
                for: clean,
                activeWindowTitle: snapshotContext.windowTitle,
                limit: 26
            )
            let specIsCloudASR = asrEngine.activeSessionUsesAnyCloudASR
            let engine = polishEngine
            let task = Task<SpecPolishOutcome, Never> {
                let t0 = DispatchTime.now()
                let (txt, ttft, fast) = await engine.polish(
                    rawTranscript: clean,
                    mode: snapshotMode,
                    screenContext: snapshotContext,
                    recalledTerms: specRecalled,
                    recentOutputs: recentTexts,
                    config: frozenConfig,
                    apiKey: frozenKey,
                    isHighAccuracyLocalASR: localSenseVoiceFlag,
                    isPunctuatedCloudASR: specIsCloudASR,
                    onStreamChunk: nil
                )
                let tot = Int((DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000)
                return (txt, ttft, tot, fast)
            }
            return (task, clean, "launched")
        }

        // Stage 1 (`t = 0ms`): Launch speculative full-prompt DeepSeek pass immediately on stop trigger!
        let stopTriggeredAt = DispatchTime.now()
        var (specTask, specLaunchedDraft, specSkipReason) = makeSpeculativeTask(for: asrEngine.currentLiveStreamingDraft)

        // Tail-capture grace window: keep microphone & ASR stream open for 0.1s after stop trigger
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Stage 2 (`t = 100ms`): If a trailing syllable arrived during the 100ms grace window, refresh speculative pass
        // right before `finishStreaming()` waits for Seed-ASR two-pass or SenseVoice tail decode!
        let postGraceDraft = asrEngine.currentLiveStreamingDraft
        if !postGraceDraft.isEmpty && postGraceDraft != specLaunchedDraft {
            specTask?.cancel()
            (specTask, specLaunchedDraft, specSkipReason) = makeSpeculativeTask(for: postGraceDraft)
        }

        isSessionActive = false
        let asrSourceLabel = asrEngine.activeASRSourceLabel
        let sessionUsedPunctuatedCloudASR = asrEngine.activeSessionUsesAnyCloudASR
        if asrEngine.activeSessionUsesOpenAIASR {
            phase = .polishing(rawText: "云端语音转写中…")
        }
        let asrFinishStart = DispatchTime.now()
        // Release microphone hardware inside `finishStreaming()` first (0s teardown on Bluetooth/USB),
        // then restore system output audio immediately after ASR finishes (+450ms Bluetooth A2DP re-check)!
        let (rawText, duration) = await asrEngine.finishStreaming()
        audioDucker.restoreIfNeeded()
        let asrFinishMs = Int((DispatchTime.now().uptimeNanoseconds - asrFinishStart.uptimeNanoseconds) / 1_000_000)
        guard !rawText.isEmpty else {
            specTask?.cancel()
            if isTypingInsideOwnApp {
                sandboxText = sandboxBaseBeforeSession
            } else {
                _ = liveInputSession?.updateLiveText("")
            }
            liveInputSession = nil
            if case .error = phase {
                // Preserve error banner emitted by asrEngine.onError
            } else {
                phase = .idle
            }
            return
        }

        let tailFixed = PolishEngine.applyInstantLocalDictionary(
            rawText,
            entries: lexiconStore.entries,
            context: activeContext,
            config: llmConfig,
            stripPeriod: true
        )
        if isTypingInsideOwnApp && llmConfig.enableLiveInlineTyping && activeMode == .dictate {
            sandboxText = sandboxBaseBeforeSession + tailFixed
        }

        let recalled = lexiconStore.recallRelevantTerms(
            for: rawText,
            activeWindowTitle: activeContext.windowTitle,
            limit: 26
        )
        if frozenKey.isEmpty
            && !PolishEngine.isKeylessLocalEndpoint(frozenConfig.baseURL)
            && frozenConfig.formattingStyle != .verbatimLocal {
            statusBanner = "⚠️ 当前生效的「\(frozenConfig.selectedProvider.shortName)」尚未填入 API Key，本次仅执行本地词库纠偏"
        }

        phase = .polishing(rawText: tailFixed)

        let canStreamSSELive = !isTypingInsideOwnApp
            && llmConfig.enableLiveInlineTyping
            && activeMode == .dictate
            && (liveInputSession?.prepareForSSEPolishStream() == true)
        var didStreamViaSSE = false

        let finalText: String
        let polishMs: Int
        let llmTotalMs: Int
        let usedFastPath: Bool
        var specStatus = specSkipReason

        if let activeSpec = specTask {
            if !canStreamSSELive && PolishEngine.canReuseSpeculativeResult(speculativeDraft: specLaunchedDraft, finalASRTranscript: rawText) {
                let specRes = await activeSpec.value
                if !specRes.text.isEmpty {
                    finalText = specRes.text
                    polishMs = specRes.latencyMs
                    llmTotalMs = specRes.totalMs
                    usedFastPath = specRes.usedFastPath
                    specStatus = "hit"
                } else {
                    let fallbackRes = await polishEngine.polish(
                        rawTranscript: rawText,
                        mode: activeMode,
                        screenContext: activeContext,
                        recalledTerms: recalled,
                        recentOutputs: recentTexts,
                        config: frozenConfig,
                        apiKey: frozenKey,
                        isHighAccuracyLocalASR: localSenseVoiceFlag,
                        isPunctuatedCloudASR: sessionUsedPunctuatedCloudASR,
                        onStreamChunk: nil
                    )
                    finalText = fallbackRes.text
                    polishMs = fallbackRes.latencyMs
                    llmTotalMs = polishEngine.lastPolishTotalMs
                    usedFastPath = fallbackRes.usedFastPath
                    specStatus = "empty-retry"
                }
            } else {
                // Two-pass ASR corrected one or more characters (e.g. fixed English term or homophone)!
                // Discard speculative draft immediately and run full polish on the authoritative two-pass transcript!
                activeSpec.cancel()
                let freshRes = await polishEngine.polish(
                    rawTranscript: rawText,
                    mode: activeMode,
                    screenContext: activeContext,
                    recalledTerms: recalled,
                    recentOutputs: recentTexts,
                    config: frozenConfig,
                    apiKey: frozenKey,
                    isHighAccuracyLocalASR: localSenseVoiceFlag,
                    isPunctuatedCloudASR: sessionUsedPunctuatedCloudASR,
                    onStreamChunk: { [weak self] chunk, isFirst in
                        guard let self else { return }
                        if self.isTypingInsideOwnApp && self.llmConfig.enableLiveInlineTyping {
                            if isFirst {
                                self.sandboxText = self.sandboxBaseBeforeSession + chunk
                            } else {
                                self.sandboxText += chunk
                            }
                            didStreamViaSSE = true
                        } else if canStreamSSELive {
                            self.liveInputSession?.consumeSSEChunk(chunk)
                            didStreamViaSSE = true
                        }
                    }
                )
                finalText = freshRes.text
                polishMs = freshRes.latencyMs
                llmTotalMs = polishEngine.lastPolishTotalMs
                usedFastPath = freshRes.usedFastPath
                specStatus = canStreamSSELive ? "miss-sse" : "miss-twopass-fixed"
            }
        } else {
            let res = await polishEngine.polish(
                rawTranscript: rawText,
                mode: activeMode,
                screenContext: activeContext,
                recalledTerms: recalled,
                recentOutputs: recentTexts,
                config: frozenConfig,
                apiKey: frozenKey,
                isHighAccuracyLocalASR: localSenseVoiceFlag,
                isPunctuatedCloudASR: sessionUsedPunctuatedCloudASR,
                onStreamChunk: { [weak self] chunk, isFirst in
                    guard let self else { return }
                    if self.isTypingInsideOwnApp && self.llmConfig.enableLiveInlineTyping {
                        if isFirst {
                            self.sandboxText = self.sandboxBaseBeforeSession + chunk
                        } else {
                            self.sandboxText += chunk
                        }
                        didStreamViaSSE = true
                    } else if canStreamSSELive {
                        self.liveInputSession?.consumeSSEChunk(chunk)
                        didStreamViaSSE = true
                    }
                }
            )
            finalText = res.text
            polishMs = res.latencyMs
            llmTotalMs = polishEngine.lastPolishTotalMs
            usedFastPath = res.usedFastPath
        }

        let e2eMs = Int((DispatchTime.now().uptimeNanoseconds - stopTriggeredAt.uptimeNanoseconds) / 1_000_000)
        ContextInjector.appendInjectionTrace("timing provider=\(frozenConfig.selectedProvider.rawValue) model=\(frozenConfig.modelName) asr=\(asrSourceLabel) spec=\(specStatus) draft=\(specLaunchedDraft.count) chars=\(rawText.count) asrMs=\(asrFinishMs) ttftMs=\(polishMs) llmTotalMs=\(llmTotalMs) e2ePrePasteMs=\(e2eMs) fastPath=\(usedFastPath)")

        guard !finalText.isEmpty else {
            liveInputSession = nil
            phase = .idle
            return
        }

        if isOfficialCloudTrialActive {
            Task { [weak self] in
                await self?.refreshCloudAccount()
            }
        } else if isUsingDoubaoVoucher && llmConfig.asrProvider == .volcSeedASR {
            Task { [weak self] in
                await self?.refreshVoucherStatusIfApplicable(notifyUserOnLowOrExhausted: true)
            }
        }

        var landedInInput = true
        if userSubmittedViaEnter {
            // User already hit Enter and sent the message during polishing — do NOT re-paste a ghost copy!
            ContextInjector.appendInjectionTrace("finalize app=\(activeContext.bundleID) branch=abortedUserSubmitInAppState final=\(finalText.count)")
            landedInInput = true
        } else if isTypingInsideOwnApp {
            sandboxText = sandboxBaseBeforeSession + finalText
        } else if didStreamViaSSE {
            liveInputSession?.finishSSEPolishStream(with: finalText)
            landedInInput = true
        } else if llmConfig.enableLiveInlineTyping && activeMode == .dictate {
            landedInInput = liveInputSession?.finalizeAfterKeyRelease(with: finalText) ?? false
        } else {
            if ContextInjector.isLikelyEditableFocusNow() || activeContext.hasFocusedTextInput {
                ContextInjector.injectTextAtCursor(finalText, in: activeContext)
            } else {
                ContextInjector.saveToSafetyClipboard(finalText)
                landedInInput = false
            }
        }

        let trulyUsedTerms = recalled.filter { finalText.localizedCaseInsensitiveContains($0.term) }
        if !trulyUsedTerms.isEmpty {
            lexiconStore.recordTermHits(trulyUsedTerms)
        }

        // Voice Teach-in Loop: when user selected wrong text and pressed Fn to fix it, permanently learn the correction!
        if activeMode == .rewriteSelection && llmConfig.enableAutoLearn {
            if let taught = lexiconStore.learnFromSelectionRewrite(selectedText: activeContext.selectedText, rewrittenText: finalText) {
                statusBanner = "✨ 语音纠偏已永久记入词库：「\(taught.wrong)」➔「\(taught.corrected)」"
            }
        }

        let record = DictationRecord(
            rawTranscript: rawText,
            polishedText: finalText,
            durationSeconds: duration,
            polishLatencyMs: polishMs,
            targetAppName: isTypingInsideOwnApp ? "TypeZero 试音沙盒" : activeContext.appName,
            mode: activeMode,
            matchedTerms: recalled.prefix(5).map(\.term)
        )
        history.insert(record, at: 0)
        if history.count > 1000 {
            history = Array(history.prefix(1000))
        }
        saveHistory()

        liveInputSession = nil
        playSubtleCue("Pop", volume: 0.26)

        if !landedInInput {
            // P4 Safety Vault triggered: user wasn't focused inside an input field!
            phase = .savedToClipboard(textPreview: "已暂存剪贴板 · Cmd+V 粘贴")
            scheduleIdleReset(after: 2.6)
        } else {
            phase = .completed(finalText: finalText, latencyMs: polishMs)
            scheduleIdleReset(after: 0.35)
            // P6 Auto-Learn Watcher: observe manual word corrections (both single-line and multi-paragraph!) at 5.5s & 12.5s
            if llmConfig.enableAutoLearn {
                scheduleAutoLearnObservation(
                    injectedText: finalText,
                    expectedBundleID: activeContext.bundleID,
                    wasInsideSandbox: isTypingInsideOwnApp
                )
            }
        }
    }

    private func scheduleAutoLearnObservation(injectedText: String, expectedBundleID: String, wasInsideSandbox: Bool) {
        let generationCount = history.count
        Task { @MainActor [weak self] in
            for delaySec in [5.5, 6.8] {
                try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
                guard let self, !self.isSessionActive, self.history.count == generationCount else { return }

                let editedBox: String?
                if wasInsideSandbox {
                    editedBox = self.sandboxText
                } else {
                    let currentFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
                    guard currentFront == expectedBundleID else { continue }
                    editedBox = ContextInjector.readCurrentFocusedValue()
                }
                guard let boxVal = editedBox, !boxVal.isEmpty else { continue }

                if let learned = self.lexiconStore.learnFromManualEditIfApplicable(injectedText: injectedText, editedBoxValue: boxVal) {
                    self.statusBanner = "✨ 自学习词典已自动记住纠偏：「\(learned.wrong)」➔「\(learned.corrected)」"
                    return
                }
            }
        }
    }

    private func scheduleIdleReset(after seconds: Double) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if case .listening = self.phase { return }
            if case .polishing = self.phase { return }
            self.phase = .idle
        }
    }

    public func distillPastedCorpus(_ rawCorpus: String) async {
        let key = KeychainHelper.loadAPIKey(for: llmConfig.selectedProvider)
        do {
            let extracted = try await polishEngine.distillTermsFromRawCorpus(
                corpusText: rawCorpus,
                config: llmConfig,
                apiKey: key
            )
            let count = lexiconStore.bulkUpsert(extracted)
            statusBanner = "智能蒸馏完成：新增 \(count) 个专属词条（总词库 \(lexiconStore.entries.count) 词）"
        } catch {
            statusBanner = "蒸馏失败：\(error.localizedDescription)"
        }
    }

    public var totalCharactersDictated: Int {
        history.reduce(0) { $0 + $1.characterCount }
    }

    public var totalDictationMinutes: Double {
        history.reduce(0.0) { $0 + $1.durationSeconds } / 60.0
    }

    public var averageCharactersPerMinute: Int {
        let mins = totalDictationMinutes
        guard mins > 0.05 else { return 0 }
        return Int(Double(totalCharactersDictated) / mins)
    }

    public var timeSavedMinutes: Int {
        let manualMinutes = Double(totalCharactersDictated) / 45.0
        let saved = max(0, manualMinutes - totalDictationMinutes)
        return Int(saved.rounded())
    }

    public var averagePolishLatencyMs: Int {
        guard !history.isEmpty else { return 0 }
        return history.reduce(0) { $0 + $1.polishLatencyMs } / history.count
    }

    public var activeDaysCount: Int {
        let cal = Calendar.current
        let uniqueDays = Set(history.map { cal.startOfDay(for: $0.timestamp) })
        return uniqueDays.count
    }

    public var todayCharactersDictated: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return history
            .filter { cal.isDate($0.timestamp, inSameDayAs: today) }
            .reduce(0) { $0 + $1.characterCount }
    }

    public func dailyCountMap() -> [Date: Int] {
        let cal = Calendar.current
        var map: [Date: Int] = [:]
        for rec in history {
            let day = cal.startOfDay(for: rec.timestamp)
            map[day, default: 0] += rec.characterCount
        }
        return map
    }

    public func recentDailySeries(days: Int = 7) -> [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let map = dailyCountMap()
        return (0..<days).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return Double(map[day] ?? 0)
        }
    }

    public func removeHistoryRecord(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([DictationRecord].self, from: data) else { return }
        self.history = decoded
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }

    private func loadConfig() {
        if let data = try? Data(contentsOf: configURL),
           var decoded = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            if !UserDefaults.standard.bool(forKey: "tz_default_inline_on_v3") {
                decoded.enableLiveInlineTyping = true
                UserDefaults.standard.set(true, forKey: "tz_default_inline_on_v3")
                self.llmConfig = decoded
                saveConfig()
                return
            }
            self.llmConfig = decoded
        } else {
            UserDefaults.standard.set(true, forKey: "tz_default_inline_on_v3")
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(llmConfig) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
}
