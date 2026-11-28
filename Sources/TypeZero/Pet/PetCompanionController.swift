import Foundation
import AppKit
import SwiftUI
import CoreAudio
import UniformTypeIdentifiers

/// Central @MainActor lifecycle & state coordinator for TypeZero's independent Desktop Cat Companion.
/// Keeps `FloatingPillPanel` 100% independent while driving both:
/// 1) Everyday physical keyboard & mouse companionship (`InputEngine`)
/// 2) Cloud Voice -> Pinyin Keystroke -> Text typing (`PetVoiceBridge`) + Multi-Cat Shift Handover (`ShiftHandoverState`)
@MainActor
public final class PetCompanionController: ObservableObject {
    private enum RenderCadence {
        case paused
        case fullscreenHidden // 2 Hz while hidden behind fullscreen app
        case asleep           // 15 Hz while sleeping
        case idle             // 30 Hz while awake at rest
        case active           // 60 Hz during input, voice typing, or shift handover

        var interval: TimeInterval {
            switch self {
            case .paused:           return 0
            case .fullscreenHidden: return 0.5
            case .asleep:           return 1.0 / 15.0
            case .idle:             return 1.0 / 30.0
            case .active:           return 1.0 / 60.0
            }
        }

        var tolerance: TimeInterval {
            switch self {
            case .paused:           return 0
            case .fullscreenHidden: return 0.15
            case .asleep:           return 0.012
            case .idle:             return 0.004
            case .active:           return 0.002
            }
        }
    }

    public static let shared = PetCompanionController()
    nonisolated(unsafe) private(set) static var sharedIfInitialized: PetCompanionController?

    // Published SwiftUI state for PetCompanionView & MainDashboardView
    @Published public private(set) var isEnabled: Bool
    @Published private(set) var coatTheme: CatCoatTheme
    @Published private(set) var customSkinID: String
    @Published public private(set) var scale: CGFloat
    @Published public private(set) var fullClickThrough: Bool
    @Published public private(set) var whiteOutline: Bool
    @Published public private(set) var autoHeadphonesOnMusic: Bool
    @Published public private(set) var footEasterEgg: Bool
    @Published public private(set) var keyboardMarquee: Bool
    @Published public private(set) var enableVoiceTyping: Bool
    @Published public private(set) var voiceBadgeMode: PetVoiceBadgeMode
    @Published public private(set) var enableHandoverAnimation: Bool
    @Published public private(set) var enableHandoverSound: Bool
    @Published public private(set) var todayPhysicalKeys: Int = 0
    @Published public private(set) var todayVoiceKeys: Int = 0
    @Published public private(set) var petTouchCount: Int = 0
    @Published public private(set) var isHandoverRunning: Bool = false
    @Published private(set) var importedSkins: [SkinSpec] = []
    @Published public var statusNotice: String = ""

    public var onOpenPetSettingsTab: (() -> Void)?

    private var overlayWindow: PetOverlayWindow?
    private var renderTimer: Timer?
    private var renderCadence: RenderCadence = .paused
    private var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    private var screensAsleep = false
    private var hiddenByFullscreen = false
    private var lastMusicCheckTime: CFTimeInterval = 0
    private var musicAudioSustainedSince: CFTimeInterval = 0
    private var cachedMusicPlaying = false
    private let musicCheckQueue = DispatchQueue(label: "io.github.typezero.pet.music", qos: .utility)
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isEngineAttached = false

    var physics: CatPhysics? {
        overlayWindow?.catView.physics
    }

    private init() {
        let s = CatSettings.shared
        self.isEnabled = s.isEnabled
        self.coatTheme = s.coatTheme
        self.customSkinID = s.customSkin
        self.scale = s.scale
        self.fullClickThrough = s.fullClickThrough
        self.whiteOutline = s.whiteOutline
        self.autoHeadphonesOnMusic = s.autoHeadphonesOnMusic
        self.footEasterEgg = s.footEasterEgg
        self.keyboardMarquee = s.keyboardMarquee
        self.enableVoiceTyping = s.enableVoiceTyping
        self.voiceBadgeMode = s.voiceBadgeMode
        self.enableHandoverAnimation = s.enableHandoverAnimation
        self.enableHandoverSound = s.enableHandoverSound
        self.todayPhysicalKeys = InputEngine.shared.totalKeystrokesToday
        self.todayVoiceKeys = PetVoiceBridge.shared.todayVoiceKeystrokes
        self.petTouchCount = UserDefaults.standard.integer(forKey: "TypeZero.Pet.PetCount")
        self.importedSkins = SkinLibrary.shared.skins
        Self.sharedIfInitialized = self

        PetVoiceBridge.shared.onVoiceStatsUpdated = { [weak self] count in
            Task { @MainActor in
                self?.todayVoiceKeys = count
            }
        }
    }

    public func bootstrapOnLaunchIfNeeded() {
        observePowerNotificationsIfNeeded()
        if isEnabled {
            activateOverlay()
        }
    }

    public func shutdown() {
        configureRenderTimer(for: .paused)
        InputEngine.shared.flushStats()
        PetVoiceBridge.shared.flushStats()
        if isEngineAttached {
            InputEngine.shared.stop()
            isEngineAttached = false
        }
        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObservers.removeAll()
    }

    // MARK: - Enable / Disable Lifecycle

    public func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        CatSettings.shared.isEnabled = enabled
        if enabled {
            activateOverlay()
            overlayWindow?.catView.showToast(text: "🐱 \(CatSettings.shared.activeSkin.name) 已上岗陪打！")
        } else {
            deactivateOverlay()
        }
    }

    private func activateOverlay() {
        if overlayWindow == nil {
            let win = PetOverlayWindow()
            setupWindowCallbacks(win)
            overlayWindow = win
        }
        guard let win = overlayWindow else { return }

        if !CatSettings.shared.overrideSkinIris && CatSettings.shared.customSkin.isEmpty {
            CatSettings.shared.eyeTheme = CatSettings.shared.coatTheme.recommendedEyeTheme
        }

        if !isEngineAttached {
            let engine = InputEngine.shared
            engine.onKeyDown = { [weak self] key in
                DispatchQueue.main.async {
                    guard let self, self.isEnabled else { return }
                    self.overlayWindow?.catView.physics.triggerKeyDown(key)
                    self.todayPhysicalKeys = engine.totalKeystrokesToday
                    self.wakeToActive()
                }
            }
            engine.onMouseClick = { [weak self] button, isDown in
                DispatchQueue.main.async {
                    guard let self, self.isEnabled else { return }
                    self.overlayWindow?.catView.physics.triggerMouseClick(button: button, isDown: isDown)
                    self.wakeToActive()
                }
            }
            engine.start()
            isEngineAttached = true
        }

        win.applyWindowLevelAndBehavior()
        win.alphaValue = 1.0
        win.orderFrontRegardless()
        lastFrameTime = CACurrentMediaTime()
        wakeToActive(immediateRedraw: true)
    }

    private func deactivateOverlay() {
        configureRenderTimer(for: .paused)
        overlayWindow?.catView.physics.handover.cancel()
        overlayWindow?.catView.physics.clearVirtualKeys()
        overlayWindow?.catView.physics.isDictationListening = false
        isHandoverRunning = false
        overlayWindow?.orderOut(nil)
        if isEngineAttached {
            InputEngine.shared.flushStats()
            InputEngine.shared.stop()
            isEngineAttached = false
        }
    }

    private func setupWindowCallbacks(_ win: PetOverlayWindow) {
        let catView = win.catView
        catView.physics.handover.onCommitSkin = { [weak self] newCoat, newCustomID, newEye, skinName in
            guard let self else { return }
            CatSettings.shared.coatTheme = newCoat
            CatSettings.shared.customSkin = newCustomID
            if !CatSettings.shared.overrideSkinIris {
                CatSettings.shared.eyeTheme = newEye
            }
            self.coatTheme = newCoat
            self.customSkinID = newCustomID
            self.overlayWindow?.catView.showToast(text: "🐾 换班完成：\(skinName) 接管键盘！")
        }

        catView.onRequestPermission = {
            InputEngine.shared.openAccessibilitySettings()
        }
        catView.onUserInteraction = { [weak self] in
            guard let self else { return }
            self.petTouchCount = catView.physics.totalPetSessions
            self.wakeToActive()
        }
        catView.onScaleChanged = { [weak self] newScale in
            self?.scale = newScale
        }
        catView.onDropSkinFiles = { [weak self] urls in
            for url in urls {
                self?.importSkinFile(url)
            }
        }
        catView.onRightClickMenu = { [weak self] event in
            guard let self else { return }
            self.wakeToActive()
            let menu = self.buildContextMenu()
            NSMenu.popUpContextMenu(menu, with: event, for: catView)
        }
    }

    // MARK: - Dictation Session Hooks (Called by AppState & ContextInjector)

    public func notifyDictationStarted() {
        guard isEnabled, let p = physics else { return }
        p.isDictationListening = true
        wakeToActive(immediateRedraw: true)
    }

    public func notifyDictationFinished() {
        guard let p = physics else { return }
        p.isDictationListening = false
        wakeToActive(immediateRedraw: true)
    }

    // MARK: - Breed Selection & Multi-Cat Shift Handover ("换班交接仪式")

    func selectBuiltInCoat(_ target: CatCoatTheme) {
        let currentIsSame = (customSkinID.isEmpty && coatTheme == target)
        if currentIsSame && !(physics?.handover.isActive ?? false) { return }

        let targetSkin = SkinSpec.builtIn(target)
        let targetEye = target.recommendedEyeTheme

        if isEnabled && enableHandoverAnimation, let p = physics {
            let outSkin = CatSettings.shared.activeSkin
            let outEye = CatSettings.shared.eyeTheme
            p.handover.start(
                outgoingSkin: outSkin,
                outgoingEye: outEye,
                incomingSkin: targetSkin,
                incomingEye: targetEye,
                targetCoat: target,
                targetCustomSkinID: ""
            )
            isHandoverRunning = true
            wakeToActive(immediateRedraw: true)
        } else {
            CatSettings.shared.customSkin = ""
            CatSettings.shared.coatTheme = target
            if !CatSettings.shared.overrideSkinIris {
                CatSettings.shared.eyeTheme = targetEye
            }
            customSkinID = ""
            coatTheme = target
            overlayWindow?.catView.needsDisplay = true
        }
    }

    func selectCustomSkin(id: String) {
        guard let spec = SkinLibrary.shared.skin(id: id) else { return }
        if customSkinID == id && !(physics?.handover.isActive ?? false) { return }

        if isEnabled && enableHandoverAnimation, let p = physics {
            let outSkin = CatSettings.shared.activeSkin
            let outEye = CatSettings.shared.eyeTheme
            p.handover.start(
                outgoingSkin: outSkin,
                outgoingEye: outEye,
                incomingSkin: spec,
                incomingEye: CatSettings.shared.eyeTheme,
                targetCoat: coatTheme,
                targetCustomSkinID: id
            )
            isHandoverRunning = true
            wakeToActive(immediateRedraw: true)
        } else {
            CatSettings.shared.customSkin = id
            customSkinID = id
            overlayWindow?.catView.needsDisplay = true
        }
    }

    /// Triggers a live Shift Handover demonstration right away (auto-enables pet if currently off!).
    public func playShiftHandoverDemo() {
        if !isEnabled {
            setEnabled(true)
        }
        guard let p = physics else { return }
        let nextCoat: CatCoatTheme = {
            switch coatTheme {
            case .classicBlack: return .siamese
            case .siamese:      return .orangeWhite
            case .orangeWhite:  return .classicBlack
            case .shorthair:    return .siamese
            }
        }()
        let outSkin = CatSettings.shared.activeSkin
        let outEye = CatSettings.shared.eyeTheme
        let inSkin = SkinSpec.builtIn(nextCoat)
        let inEye = nextCoat.recommendedEyeTheme
        p.handover.start(
            outgoingSkin: outSkin,
            outgoingEye: outEye,
            incomingSkin: inSkin,
            incomingEye: inEye,
            targetCoat: nextCoat,
            targetCustomSkinID: ""
        )
        isHandoverRunning = true
        wakeToActive(immediateRedraw: true)
    }

    public func playVoiceTypingDemo() {
        if !isEnabled {
            setEnabled(true)
        }
        PetVoiceBridge.shared.playDemoVoiceBurst()
    }

    // MARK: - Settings Mutators

    public func setScale(_ value: CGFloat) {
        let clamped = max(0.55, min(1.65, value))
        scale = clamped
        if let win = overlayWindow {
            win.applyScale(clamped)
        } else {
            CatSettings.shared.scale = clamped
        }
    }

    public func resetPosition() {
        overlayWindow?.resetPosition()
        overlayWindow?.catView.showToast(text: "📍 已归位至屏幕右下角")
    }

    public func setFullClickThrough(_ value: Bool) {
        fullClickThrough = value
        CatSettings.shared.fullClickThrough = value
        overlayWindow?.catView.updateHoverAndClickThrough()
    }

    public func setWhiteOutline(_ value: Bool) {
        whiteOutline = value
        CatSettings.shared.whiteOutline = value
        overlayWindow?.catView.needsDisplay = true
    }

    public func setAutoHeadphonesOnMusic(_ value: Bool) {
        autoHeadphonesOnMusic = value
        CatSettings.shared.autoHeadphonesOnMusic = value
        if !value {
            cachedMusicPlaying = false
            musicAudioSustainedSince = 0
            overlayWindow?.catView.physics.isMusicPlaying = false
        }
        overlayWindow?.catView.needsDisplay = true
    }

    public func setFootEasterEgg(_ value: Bool) {
        footEasterEgg = value
        CatSettings.shared.footEasterEgg = value
    }

    public func setKeyboardMarquee(_ value: Bool) {
        keyboardMarquee = value
        CatSettings.shared.keyboardMarquee = value
        overlayWindow?.catView.needsDisplay = true
    }

    public func setEnableVoiceTyping(_ value: Bool) {
        enableVoiceTyping = value
        CatSettings.shared.enableVoiceTyping = value
    }

    public func setVoiceBadgeMode(_ mode: PetVoiceBadgeMode) {
        voiceBadgeMode = mode
        CatSettings.shared.voiceBadgeMode = mode
    }

    public func setEnableHandoverAnimation(_ value: Bool) {
        enableHandoverAnimation = value
        CatSettings.shared.enableHandoverAnimation = value
    }

    public func setEnableHandoverSound(_ value: Bool) {
        enableHandoverSound = value
        CatSettings.shared.enableHandoverSound = value
    }

    public func importSkinViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "导入 .kurocat 桌宠皮肤"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let ut = UTType(filenameExtension: "kurocat") {
            panel.allowedContentTypes = [ut]
        }
        if panel.runModal() == .OK, let url = panel.url {
            importSkinFile(url)
        }
    }

    public func importSkinFile(_ url: URL) {
        do {
            let newID = try SkinLibrary.shared.importFile(url)
            importedSkins = SkinLibrary.shared.skins
            selectCustomSkin(id: newID)
            if let sp = SkinLibrary.shared.skin(id: newID) {
                statusNotice = "✅ 已导入并切换皮肤「\(sp.name)」"
            }
        } catch {
            statusNotice = "⚠️ \(error.localizedDescription)"
        }
    }

    public func removeImportedSkin(id: String) {
        if customSkinID == id {
            CatSettings.shared.customSkin = ""
            customSkinID = ""
        }
        SkinLibrary.shared.remove(id: id)
        importedSkins = SkinLibrary.shared.skins
        overlayWindow?.catView.needsDisplay = true
    }

    // MARK: - Right-Click Quick Context Menu on Desktop Cat

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "TypeZero 桌面搭子")

        let header = NSMenuItem(title: "🐱 TypeZero 桌面搭子 · 今日敲键 \(todayPhysicalKeys + todayVoiceKeys)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for coat in CatCoatTheme.allCases {
            let item = NSMenuItem(title: "换班：\(coat.shortTitle)", action: #selector(handleCoatMenuPick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = coat.rawValue
            item.state = (customSkinID.isEmpty && coatTheme == coat) ? .on : .off
            menu.addItem(item)
        }

        let demoItem = NSMenuItem(title: "🎬 立即演示双猫换班交接", action: #selector(handleDemoHandoverAction), keyEquivalent: "")
        demoItem.target = self
        menu.addItem(demoItem)

        menu.addItem(.separator())

        let clickThroughItem = NSMenuItem(title: "完全鼠标穿透（按住 ⌥ 可拖动）", action: #selector(handleToggleClickThrough), keyEquivalent: "")
        clickThroughItem.target = self
        clickThroughItem.state = fullClickThrough ? .on : .off
        menu.addItem(clickThroughItem)

        let resetPosItem = NSMenuItem(title: "重置位置到屏幕右下角", action: #selector(handleResetPositionAction), keyEquivalent: "")
        resetPosItem.target = self
        menu.addItem(resetPosItem)

        let openPanelItem = NSMenuItem(title: "打开「桌面搭子」设置页…", action: #selector(handleOpenSettingsAction), keyEquivalent: "")
        openPanelItem.target = self
        menu.addItem(openPanelItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(title: "暂时关闭桌面搭子", action: #selector(handleDisablePetAction), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        return menu
    }

    @objc private func handleCoatMenuPick(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let coat = CatCoatTheme(rawValue: raw) else { return }
        selectBuiltInCoat(coat)
    }

    @objc private func handleDemoHandoverAction() {
        playShiftHandoverDemo()
    }

    @objc private func handleToggleClickThrough() {
        setFullClickThrough(!fullClickThrough)
    }

    @objc private func handleResetPositionAction() {
        resetPosition()
    }

    @objc private func handleOpenSettingsAction() {
        onOpenPetSettingsTab?()
    }

    @objc private func handleDisablePetAction() {
        setEnabled(false)
    }

    // MARK: - Adaptive 60/30/15 FPS Render Loop & Audio Output Headphones

    func wakeToActive(immediateRedraw: Bool = false) {
        guard isEnabled, !screensAsleep else { return }
        if !hiddenByFullscreen && renderCadence != .active {
            configureRenderTimer(for: .active)
        }
        if immediateRedraw, !hiddenByFullscreen {
            overlayWindow?.catView.needsDisplay = true
        }
    }

    private func configureRenderTimer(for cadence: RenderCadence) {
        guard cadence != renderCadence || (cadence != .paused && renderTimer == nil) else { return }
        renderTimer?.invalidate()
        renderTimer = nil
        renderCadence = cadence
        guard cadence != .paused else { return }
        let timer = Timer(timeInterval: cadence.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.renderTick()
            }
        }
        timer.tolerance = cadence.tolerance
        RunLoop.main.add(timer, forMode: .common)
        renderTimer = timer
    }

    private func observePowerNotificationsIfNeeded() {
        guard workspaceObservers.isEmpty else { return }
        let nc = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.screensAsleep = true
                    self?.configureRenderTimer(for: .paused)
                }
            }
        )
        workspaceObservers.append(
            nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.screensAsleep = false
                    self.lastFrameTime = CACurrentMediaTime()
                    self.wakeToActive(immediateRedraw: true)
                }
            }
        )
    }

    private func renderTick() {
        guard isEnabled, !screensAsleep, let overlayWindow else {
            configureRenderTimer(for: .paused)
            return
        }
        let now = CACurrentMediaTime()
        pollMusicStateIfNeeded(now: now)

        let dt = CGFloat(now - lastFrameTime)
        lastFrameTime = now

        let view = overlayWindow.catView
        let physics = view.physics
        let input = InputEngine.shared
        let windowFrame = overlayWindow.frame
        let physicsFrame = overlayWindow.physicsFrameInScreen
        let previousMouseMoveTime = input.lastMouseMoveTime
        let wasBlinking = physics.isBlinking
        let wasYawning = physics.isYawning
        let wasToastActive = view.toastActive

        physics.step(dt: dt, windowFrameInScreen: physicsFrame)
        view.updateHoverAndClickThrough()
        view.tickToast(dt: dt)

        if isHandoverRunning != physics.handover.isActive {
            isHandoverRunning = physics.handover.isActive
        }

        let lastDirectInput = max(input.lastKeyActivityTime, max(input.lastMouseClickTime, physics.lastVirtualKeyTime))
        let mouseMoving = now - input.lastMouseMoveTime < 0.12
        let mouseStartedMoving = mouseMoving && now - previousMouseMoveTime >= 0.12
        let mouseNearPet = mouseMoving && windowFrame.insetBy(dx: -24, dy: -24).contains(input.lastMouseLocation)
        let isAsleep = physics.sleepiness >= 0.95
        let hasActiveSparkles = physics.sparkles.contains { !$0.isSleepZ }
        let hasMotion = physics.handover.isActive
            || physics.isDictationListening
            || !physics.virtualActiveKeys.isEmpty
            || hasActiveSparkles || !physics.floatingKeycaps.isEmpty
            || !physics.keyGlow.isEmpty || !physics.tabletTrail.isEmpty
            || physics.kbSparkTimer > 0.005
            || physics.petHeadIntensity > 0.02 || physics.petBodyIntensity > 0.02
            || physics.huntIntensity.value > 0.02
            || physics.scruffDrag.value > 0.02 || physics.isChangingLie
            || abs(physics.scruffSwing.value) > 0.01 || abs(physics.scruffSwingY.value) > 0.01
            || abs(physics.scruffTailSwing.value) > 0.01
            || abs(physics.kbImpactY.value) > 0.01 || abs(physics.kbImpactTilt.value) > 0.01
            || physics.angerIntensity.value > 0.02 || physics.dizzyIntensity.value > 0.02
            || physics.scruffDizzyIntensity.value > 0.02 || physics.mousePressMiddle.value > 0.02
            || wasYawning || physics.isYawning
            || (!isAsleep && (wasBlinking || physics.isBlinking))

        let isActive = now - lastDirectInput < 0.8 || !input.activeKeys.isEmpty
            || mouseStartedMoving || mouseNearPet
            || input.leftMouseDown || input.rightMouseDown || input.otherMouseDown
            || view.isDraggingOrResizing || hasMotion
            || wasToastActive || view.toastActive

        let desiredCadence: RenderCadence = isActive ? .active : (isAsleep ? .asleep : .idle)
        if desiredCadence != renderCadence {
            if desiredCadence == .asleep {
                CatRenderer.purgeVolatileCaches()
            }
            configureRenderTimer(for: desiredCadence)
        }
        if isActive || view.poseNeedsDisplay() {
            view.needsDisplay = true
        }
    }

    // MARK: - CoreAudio Sustained Output Detection (Headphones Easter Egg)

    private func pollMusicStateIfNeeded(now: CFTimeInterval) {
        guard CatSettings.shared.autoHeadphonesOnMusic else {
            if cachedMusicPlaying {
                cachedMusicPlaying = false
                musicAudioSustainedSince = 0
                overlayWindow?.catView.physics.isMusicPlaying = false
            }
            return
        }
        if now - lastMusicCheckTime < 1.0 { return }
        lastMusicCheckTime = now

        musicCheckQueue.async { [weak self] in
            let audioRunning = Self.isAnyAudioOutputRunning()
            Task { @MainActor in
                guard let self else { return }
                let playing: Bool
                if audioRunning {
                    if self.musicAudioSustainedSince == 0 {
                        self.musicAudioSustainedSince = now
                    }
                    playing = (now - self.musicAudioSustainedSince) >= 1.5
                } else {
                    self.musicAudioSustainedSince = 0
                    playing = false
                }
                self.cachedMusicPlaying = playing
                self.overlayWindow?.catView.physics.isMusicPlaying = playing
            }
        }
    }

    nonisolated private static func isAnyAudioOutputRunning() -> Bool {
        func deviceHasOutputAndRunning(_ devID: AudioDeviceID) -> Bool {
            var sSize: UInt32 = 0
            var sAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyDataSize(devID, &sAddr, 0, nil, &sSize) == noErr, sSize > 0 else {
                return false
            }
            let buf = UnsafeMutableRawPointer.allocate(
                byteCount: Int(sSize),
                alignment: MemoryLayout<AudioBufferList>.alignment
            )
            defer { buf.deallocate() }
            var outChannels: UInt32 = 0
            if AudioObjectGetPropertyData(devID, &sAddr, 0, nil, &sSize, buf) == noErr {
                let abl = UnsafeMutableAudioBufferListPointer(buf.assumingMemoryBound(to: AudioBufferList.self))
                for b in abl { outChannels += b.mNumberChannels }
            }
            guard outChannels > 0 else { return false }

            var running: UInt32 = 0
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            var runAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectGetPropertyData(devID, &runAddr, 0, nil, &runSize, &running) == noErr else {
                return false
            }
            return running != 0
        }

        var propSize: UInt32 = 0
        var listAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &propSize) == noErr,
           propSize >= UInt32(MemoryLayout<AudioDeviceID>.size) {
            let count = Int(propSize) / MemoryLayout<AudioDeviceID>.size
            var devices = [AudioDeviceID](repeating: AudioDeviceID(kAudioObjectUnknown), count: count)
            if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &propSize, &devices) == noErr {
                for dev in devices where dev != kAudioObjectUnknown {
                    if deviceHasOutputAndRunning(dev) { return true }
                }
                return false
            }
        }
        return false
    }
}
