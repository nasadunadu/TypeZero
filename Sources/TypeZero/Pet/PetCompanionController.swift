import Foundation
import AppKit
import SwiftUI
import CoreAudio
import UniformTypeIdentifiers

/// Central @MainActor lifecycle & state coordinator for TypeZero's independent Desktop Cat Companion.
/// Combines:
/// 1) `chanke17/KuroCat` 2.5D sticker cat + NKRO hardware input + rich easter eggs & skins
/// 2) `Chingyim/Clack-Clack` 10.58s forehead-butting shift handover + authentic mechanical keyboard/mouse WAV audio + privacy/pause sync
/// 3) `TypeZero` Cloud Voice -> Pinyin Keystroke -> Text choreography (`PetVoiceBridge`) while keeping `FloatingPillPanel` 100% separate
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
    @Published public private(set) var visualStyle: PetVisualStyle
    @Published private(set) var coatTheme: CatCoatTheme
    @Published private(set) var customSkinID: String
    @Published public private(set) var scale: CGFloat
    @Published public private(set) var fullClickThrough: Bool
    @Published public private(set) var fullScreenOverlay: Bool
    @Published public private(set) var autoHideFullscreen: Bool
    @Published public private(set) var whiteOutline: Bool
    @Published public private(set) var flipHorizontal: Bool
    @Published public private(set) var rotationDeg: CGFloat
    @Published private(set) var eyeTheme: EyeColorTheme
    @Published public private(set) var overrideSkinIris: Bool
    @Published private(set) var keyboardTheme: KeyboardTheme
    @Published public private(set) var customKeyboardID: String
    @Published public private(set) var keyboardMarquee: Bool
    @Published private(set) var marqueeMode: KeyboardMarqueeMode
    @Published public private(set) var keyboardKeyGlow: Bool
    @Published public private(set) var showKeyLegends: Bool
    @Published public private(set) var levelKeyboard: Bool
    @Published public private(set) var showKeyBadges: Bool
    @Published public private(set) var showMouseBadges: Bool
    @Published public private(set) var enableAnger: Bool
    @Published public private(set) var enableDragAnimation: Bool
    @Published public private(set) var petInteraction: Bool
    @Published public private(set) var footEasterEgg: Bool
    @Published public private(set) var tailEasterEgg: Bool
    @Published public private(set) var tabletMode: Int
    @Published public private(set) var autoHeadphonesOnMusic: Bool
    @Published public private(set) var hourlyAnnouncement: Bool
    @Published public private(set) var pauseInputSync: Bool
    @Published public private(set) var privacyMode: Bool
    @Published public private(set) var reducedMotion: Bool
    @Published public private(set) var obsCaptureMode: Int
    @Published public private(set) var obsHideDesktop: Bool

    // Voice typing & Handover & Sound Effects
    @Published public private(set) var enableVoiceTyping: Bool
    @Published public private(set) var voiceBadgeMode: PetVoiceBadgeMode
    @Published public private(set) var enableHandoverAnimation: Bool
    @Published public private(set) var enableHandoverSound: Bool
    @Published public private(set) var duelVoiceStyle: PetDuelVoiceStyle
    @Published public private(set) var duelVolume: Int
    @Published public private(set) var keyboardSound: Bool
    @Published public private(set) var voiceTypingSound: Bool
    @Published public private(set) var keyboardTone: PetKeyboardTone
    @Published public private(set) var keyboardVolume: Int
    @Published public private(set) var mouseSound: Bool
    @Published public private(set) var mouseTone: PetMouseTone
    @Published public private(set) var mouseVolume: Int

    // Live metrics & libraries
    @Published public private(set) var todayPhysicalKeys: Int = 0
    @Published public private(set) var todayVoiceKeys: Int = 0
    @Published public private(set) var currentKPM: Int = 0
    @Published public private(set) var petTouchCount: Int = 0
    @Published public private(set) var isHandoverRunning: Bool = false
    @Published private(set) var importedSkins: [SkinSpec] = []
    @Published private(set) var importedKeyboardSkins: [KeyboardSkinSpec] = []
    @Published public private(set) var inputStatusText: String = InputEngine.shared.status.rawValue
    @Published public private(set) var inputNeedsPermission: Bool = InputEngine.shared.status.needsAttention
    @Published public var statusNotice: String = ""

    public var onOpenPetSettingsTab: (() -> Void)?

    private var overlayWindow: PetOverlayWindow?
    private var renderTimer: Timer?
    private var renderCadence: RenderCadence = .paused
    private var minuteTimer: Timer?
    private var lastAnnouncedHour: Int = -1
    private var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    private var screensAsleep = false
    private var hiddenByFullscreen = false
    private var lastFullscreenCheckTime: CFTimeInterval = 0
    private var fullscreenCheckInFlight = false
    private let fullscreenCheckQueue = DispatchQueue(label: "io.github.typezero.pet.fullscreen", qos: .utility)
    private var lastMusicCheckTime: CFTimeInterval = 0
    private var musicAudioSustainedSince: CFTimeInterval = 0
    private var cachedMusicPlaying = false
    private let musicCheckQueue = DispatchQueue(label: "io.github.typezero.pet.music", qos: .utility)
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isEngineAttached = false

    var physics: CatPhysics? {
        overlayWindow?.catView.physics
    }

    public var typingLimbMode: Int {
        footEasterEgg ? (tailEasterEgg ? 0 : 1) : (tailEasterEgg ? 2 : 3)
    }

    private init() {
        let s = CatSettings.shared
        self.isEnabled = s.isEnabled
        self.visualStyle = s.visualStyle
        self.coatTheme = s.coatTheme
        self.customSkinID = s.customSkin
        self.scale = s.scale
        self.fullClickThrough = s.fullClickThrough
        self.fullScreenOverlay = s.fullScreenOverlay
        self.autoHideFullscreen = s.autoHideFullscreen
        self.whiteOutline = s.whiteOutline
        self.flipHorizontal = s.flipHorizontal
        self.rotationDeg = s.rotationDeg
        self.eyeTheme = s.eyeTheme
        self.overrideSkinIris = s.overrideSkinIris
        self.keyboardTheme = s.keyboardTheme
        self.customKeyboardID = s.customKeyboard
        self.keyboardMarquee = s.keyboardMarquee
        self.marqueeMode = s.marqueeMode
        self.keyboardKeyGlow = s.keyboardKeyGlow
        self.showKeyLegends = s.showKeyLegends
        self.levelKeyboard = s.levelKeyboard
        self.showKeyBadges = s.showKeyBadges
        self.showMouseBadges = s.showMouseBadges
        self.enableAnger = s.enableAnger
        self.enableDragAnimation = s.enableDragAnimation
        self.petInteraction = s.petInteraction
        self.footEasterEgg = s.footEasterEgg
        self.tailEasterEgg = s.tailEasterEgg
        self.tabletMode = s.tabletMode
        self.autoHeadphonesOnMusic = s.autoHeadphonesOnMusic
        self.hourlyAnnouncement = s.hourlyAnnouncement
        self.pauseInputSync = s.pauseInputSync
        self.privacyMode = s.privacyMode
        self.reducedMotion = s.reducedMotion
        self.obsCaptureMode = s.obsCaptureMode
        self.obsHideDesktop = s.obsHideDesktop
        self.enableVoiceTyping = s.enableVoiceTyping
        self.voiceBadgeMode = s.voiceBadgeMode
        self.enableHandoverAnimation = s.enableHandoverAnimation
        self.enableHandoverSound = s.enableHandoverSound
        self.duelVoiceStyle = s.duelVoiceStyle
        self.duelVolume = s.duelVolume
        self.keyboardSound = s.keyboardSound
        self.voiceTypingSound = s.voiceTypingSound
        self.keyboardTone = s.keyboardTone
        self.keyboardVolume = s.keyboardVolume
        self.mouseSound = s.mouseSound
        self.mouseTone = s.mouseTone
        self.mouseVolume = s.mouseVolume
        self.todayPhysicalKeys = InputEngine.shared.totalKeystrokesToday
        self.todayVoiceKeys = PetVoiceBridge.shared.todayVoiceKeystrokes
        self.currentKPM = InputEngine.shared.currentKPM
        self.petTouchCount = UserDefaults.standard.integer(forKey: "TypeZero.Pet.PetCount")
        SkinLibrary.shared.reload()
        KeyboardSkinLibrary.shared.reload()
        self.importedSkins = SkinLibrary.shared.skins
        self.importedKeyboardSkins = KeyboardSkinLibrary.shared.skins
        Self.sharedIfInitialized = self

        PetVoiceBridge.shared.onVoiceStatsUpdated = { [weak self] count in
            Task { @MainActor in
                self?.todayVoiceKeys = count
            }
        }
    }

    public func bootstrapOnLaunchIfNeeded() {
        observePowerNotificationsIfNeeded()
        startHourlyTimerIfNeeded()
        if isEnabled {
            activateOverlay()
        }
    }

    public func shutdown() {
        configureRenderTimer(for: .paused)
        minuteTimer?.invalidate()
        minuteTimer = nil
        PetAudioBank.shared.stopAll()
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
            let rec = CatSettings.shared.coatTheme.recommendedEyeTheme
            CatSettings.shared.eyeTheme = rec
            eyeTheme = rec
        }

        if !isEngineAttached {
            let engine = InputEngine.shared
            engine.onKeyDown = { [weak self] key in
                DispatchQueue.main.async {
                    guard let self, self.isEnabled else { return }
                    self.overlayWindow?.catView.physics.triggerKeyDown(key)
                    self.todayPhysicalKeys = engine.totalKeystrokesToday
                    self.currentKPM = engine.currentKPM
                    self.wakeToActive()
                }
            }
            engine.onKeyUp = { [weak self] key in
                DispatchQueue.main.async {
                    guard let self, self.isEnabled else { return }
                    self.overlayWindow?.catView.physics.triggerKeyUp(key)
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
            engine.onStatusChanged = { [weak self] st in
                DispatchQueue.main.async {
                    self?.inputStatusText = st.rawValue
                    self?.inputNeedsPermission = st.needsAttention
                }
            }
            engine.start()
            inputStatusText = engine.status.rawValue
            inputNeedsPermission = engine.status.needsAttention
            isEngineAttached = true
        }

        win.applyWindowLevelAndBehavior()
        win.applyOBSMode()
        if !(obsCaptureMode > 0 && obsHideDesktop) {
            win.alphaValue = 1.0
            win.orderFrontRegardless()
        }
        lastFrameTime = CACurrentMediaTime()
        wakeToActive(immediateRedraw: true)
    }

    private func deactivateOverlay() {
        configureRenderTimer(for: .paused)
        PetAudioBank.shared.stopAll()
        overlayWindow?.catView.physics.clackSim.handover.cancel()
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
        let handover = catView.physics.clackSim.handover
        handover.onDuelStart = {
            PetAudioBank.shared.playHandoverDuelSound()
        }
        handover.onHandoverCompleted = { [weak self] newCoat, newCustomID, skinName in
            guard let self else { return }
            CatSettings.shared.coatTheme = newCoat
            CatSettings.shared.customSkin = newCustomID
            if !CatSettings.shared.overrideSkinIris && newCustomID.isEmpty {
                let rec = newCoat.recommendedEyeTheme
                CatSettings.shared.eyeTheme = rec
                self.eyeTheme = rec
            }
            self.coatTheme = newCoat
            self.customSkinID = newCustomID
            self.isHandoverRunning = false
            if let p = self.physics {
                p.bodySquash.velocity -= 1.5
                p.earTwitch.velocity += 4.2
            }
            self.overlayWindow?.catView.showToast(text: "🐾 换班完成：\(skinName) 接管键盘！")
            self.overlayWindow?.catView.needsDisplay = true
        }

        catView.onRequestPermission = { [weak self] in
            self?.openInputMonitoringSettings()
        }
        catView.onUserInteraction = { [weak self] in
            guard let self else { return }
            self.petTouchCount = catView.physics.totalPetSessions
            self.flipHorizontal = CatSettings.shared.flipHorizontal
            self.rotationDeg = CatSettings.shared.rotationDeg
            self.wakeToActive()
        }
        catView.onScaleChanged = { [weak self] newScale in
            self?.scale = newScale
        }
        catView.onDropSkinFiles = { [weak self] urls in
            for url in urls {
                self?.importDroppedFile(url)
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

    // MARK: - Breed Selection & 10.58s Original Clack-Clack Forehead-Butting Shift Handover

    func selectBuiltInCoat(_ target: CatCoatTheme) {
        let currentIsSame = (customSkinID.isEmpty && coatTheme == target)
        if currentIsSame && !(physics?.isHandoverActive ?? false) { return }

        if isEnabled && enableHandoverAnimation, let p = physics {
            let nowMs = CACurrentMediaTime() * 1000.0
            let curSkin = customSkinID.isEmpty ? nil : CatSettings.shared.activeSkin
            p.clackSim.handover.startHandover(
                fromCoat: coatTheme,
                fromCustomID: customSkinID,
                fromSkin: curSkin,
                toCoat: target,
                toCustomID: "",
                toSkin: nil,
                nowMs: nowMs
            )
            isHandoverRunning = true
            wakeToActive(immediateRedraw: true)
        } else {
            p?.clackSim.handover.syncInstant(coat: target, customSkinID: "", skin: nil)
            CatSettings.shared.customSkin = ""
            CatSettings.shared.coatTheme = target
            if !CatSettings.shared.overrideSkinIris {
                let rec = target.recommendedEyeTheme
                CatSettings.shared.eyeTheme = rec
                eyeTheme = rec
            }
            customSkinID = ""
            coatTheme = target
            isHandoverRunning = false
            overlayWindow?.catView.needsDisplay = true
        }
    }

    func selectCustomSkin(id: String) {
        guard let spec = SkinLibrary.shared.skin(id: id) else { return }
        if customSkinID == id && !(physics?.isHandoverActive ?? false) { return }

        if isEnabled && enableHandoverAnimation, let p = physics {
            let nowMs = CACurrentMediaTime() * 1000.0
            let curSkin = customSkinID.isEmpty ? nil : CatSettings.shared.activeSkin
            p.clackSim.handover.startHandover(
                fromCoat: coatTheme,
                fromCustomID: customSkinID,
                fromSkin: curSkin,
                toCoat: coatTheme,
                toCustomID: id,
                toSkin: spec,
                nowMs: nowMs
            )
            isHandoverRunning = true
            wakeToActive(immediateRedraw: true)
        } else {
            p?.clackSim.handover.syncInstant(coat: coatTheme, customSkinID: id, skin: spec)
            CatSettings.shared.customSkin = id
            customSkinID = id
            isHandoverRunning = false
            overlayWindow?.catView.needsDisplay = true
        }
    }

    private var p: CatPhysics? { physics }

    /// Triggers a live 10.58s Original Clack-Clack Forehead-Butting Shift Handover immediately!
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
        let nowMs = CACurrentMediaTime() * 1000.0
        let curSkin = customSkinID.isEmpty ? nil : CatSettings.shared.activeSkin
        p.clackSim.handover.startHandover(
            fromCoat: coatTheme,
            fromCustomID: customSkinID,
            fromSkin: curSkin,
            toCoat: nextCoat,
            toCustomID: "",
            toSkin: nil,
            nowMs: nowMs,
            force: true
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

    public func testHourlyAnnouncement() {
        if !isEnabled {
            setEnabled(true)
        }
        let hour = Calendar.current.component(.hour, from: Date())
        showHourlyToast(hour: hour)
    }

    // MARK: - Complete Settings Mutators (KuroCat + Clack-Clack + TypeZero)

    public func setVisualStyle(_ style: PetVisualStyle) {
        visualStyle = style
        CatSettings.shared.visualStyle = style
        wakeToActive(immediateRedraw: true)
    }

    public func setScale(_ value: CGFloat) {
        let clamped = max(0.45, min(2.0, value))
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

    public func resetPoseAndPosition() {
        setRotationDeg(0)
        setFlipHorizontal(false)
        setScale(0.92)
        resetPosition()
    }

    public func setFullClickThrough(_ value: Bool) {
        fullClickThrough = value
        CatSettings.shared.fullClickThrough = value
        overlayWindow?.catView.updateHoverAndClickThrough()
    }

    public func setFullScreenOverlay(_ value: Bool) {
        fullScreenOverlay = value
        CatSettings.shared.fullScreenOverlay = value
        overlayWindow?.applyWindowLevelAndBehavior()
    }

    public func setAutoHideFullscreen(_ value: Bool) {
        autoHideFullscreen = value
        CatSettings.shared.autoHideFullscreen = value
        if !value && hiddenByFullscreen {
            hiddenByFullscreen = false
            overlayWindow?.alphaValue = 1.0
            wakeToActive(immediateRedraw: true)
        }
    }

    public func setWhiteOutline(_ value: Bool) {
        whiteOutline = value
        CatSettings.shared.whiteOutline = value
        wakeToActive(immediateRedraw: true)
    }

    public func setFlipHorizontal(_ value: Bool) {
        flipHorizontal = value
        CatSettings.shared.flipHorizontal = value
        wakeToActive(immediateRedraw: true)
    }

    public func setRotationDeg(_ value: CGFloat) {
        var snapped = max(-180, min(180, value))
        for anchor in [-180.0, -90.0, 0.0, 90.0, 180.0] as [CGFloat] {
            if abs(snapped - anchor) < 3.5 {
                snapped = anchor
                break
            }
        }
        rotationDeg = snapped
        CatSettings.shared.rotationDeg = snapped
        wakeToActive(immediateRedraw: true)
    }

    func selectEyeTheme(_ theme: EyeColorTheme) {
        eyeTheme = theme
        overrideSkinIris = true
        CatSettings.shared.overrideSkinIris = true
        CatSettings.shared.eyeTheme = theme
        wakeToActive(immediateRedraw: true)
    }

    public func resetEyeToBreedDefault() {
        overrideSkinIris = false
        CatSettings.shared.overrideSkinIris = false
        let rec = coatTheme.recommendedEyeTheme
        eyeTheme = rec
        CatSettings.shared.eyeTheme = rec
        wakeToActive(immediateRedraw: true)
    }

    func selectKeyboardTheme(_ theme: KeyboardTheme) {
        customKeyboardID = ""
        keyboardTheme = theme
        CatSettings.shared.customKeyboard = ""
        CatSettings.shared.keyboardTheme = theme
        wakeToActive(immediateRedraw: true)
    }

    public func selectCustomKeyboard(id: String) {
        guard KeyboardSkinLibrary.shared.skin(id: id) != nil else { return }
        customKeyboardID = id
        CatSettings.shared.customKeyboard = id
        wakeToActive(immediateRedraw: true)
    }

    public func setKeyboardMarquee(_ value: Bool) {
        keyboardMarquee = value
        CatSettings.shared.keyboardMarquee = value
        wakeToActive(immediateRedraw: true)
    }

    func setMarqueeMode(_ mode: KeyboardMarqueeMode) {
        marqueeMode = mode
        CatSettings.shared.marqueeMode = mode
        wakeToActive(immediateRedraw: true)
    }

    public func setKeyboardKeyGlow(_ value: Bool) {
        keyboardKeyGlow = value
        CatSettings.shared.keyboardKeyGlow = value
        if !value {
            physics?.keyGlow.removeAll()
            physics?.kbSparkTimer = 0
        }
        wakeToActive(immediateRedraw: true)
    }

    public func setShowKeyLegends(_ value: Bool) {
        showKeyLegends = value
        CatSettings.shared.showKeyLegends = value
        wakeToActive(immediateRedraw: true)
    }

    public func setLevelKeyboard(_ value: Bool) {
        levelKeyboard = value
        CatSettings.shared.levelKeyboard = value
        wakeToActive(immediateRedraw: true)
    }

    public func setShowKeyBadges(_ value: Bool) {
        showKeyBadges = value
        CatSettings.shared.showKeyBadges = value
        if !value {
            physics?.floatingKeycaps.removeAll()
            physics?.clackSim.pose.bubbles.removeAll()
        }
        wakeToActive(immediateRedraw: true)
    }

    public func setShowMouseBadges(_ value: Bool) {
        showMouseBadges = value
        CatSettings.shared.showMouseBadges = value
        wakeToActive(immediateRedraw: true)
    }

    public func setEnableAnger(_ value: Bool) {
        enableAnger = value
        CatSettings.shared.enableAnger = value
        wakeToActive(immediateRedraw: true)
    }

    public func setEnableDragAnimation(_ value: Bool) {
        enableDragAnimation = value
        CatSettings.shared.enableDragAnimation = value
    }

    public func setPetInteraction(_ value: Bool) {
        petInteraction = value
        CatSettings.shared.petInteraction = value
    }

    public func setFootEasterEgg(_ value: Bool) {
        footEasterEgg = value
        CatSettings.shared.footEasterEgg = value
    }

    public func setTailEasterEgg(_ value: Bool) {
        tailEasterEgg = value
        CatSettings.shared.tailEasterEgg = value
    }

    public func setTypingLimbMode(_ mode: Int) {
        let clamped = max(0, min(3, mode))
        let f = (clamped == 0 || clamped == 1)
        let t = (clamped == 0 || clamped == 2)
        footEasterEgg = f
        tailEasterEgg = t
        CatSettings.shared.footEasterEgg = f
        CatSettings.shared.tailEasterEgg = t
    }

    public func setTabletMode(_ mode: Int) {
        let clamped = max(0, min(2, mode))
        tabletMode = clamped
        CatSettings.shared.tabletMode = clamped
        wakeToActive(immediateRedraw: true)
    }

    public func setAutoHeadphonesOnMusic(_ value: Bool) {
        autoHeadphonesOnMusic = value
        CatSettings.shared.autoHeadphonesOnMusic = value
        if !value {
            cachedMusicPlaying = false
            musicAudioSustainedSince = 0
            overlayWindow?.catView.physics.isMusicPlaying = false
        }
        wakeToActive(immediateRedraw: true)
    }

    public func setHourlyAnnouncement(_ value: Bool) {
        hourlyAnnouncement = value
        CatSettings.shared.hourlyAnnouncement = value
        if value {
            startHourlyTimerIfNeeded()
        }
    }

    public func setPauseInputSync(_ value: Bool) {
        pauseInputSync = value
        CatSettings.shared.pauseInputSync = value
        if value {
            PetAudioBank.shared.stopAll()
            physics?.clearVirtualKeys()
            physics?.clackSim.clearAllInputs()
            physics?.keyGlow.removeAll()
        }
        wakeToActive(immediateRedraw: true)
    }

    public func setPrivacyMode(_ value: Bool) {
        privacyMode = value
        CatSettings.shared.privacyMode = value
        if value {
            PetAudioBank.shared.stopAll()
            physics?.floatingKeycaps.removeAll()
            physics?.keyGlow.removeAll()
            physics?.clackSim.clearAllInputs()
        }
        wakeToActive(immediateRedraw: true)
    }

    public func setReducedMotion(_ value: Bool) {
        reducedMotion = value
        CatSettings.shared.reducedMotion = value
        wakeToActive(immediateRedraw: true)
    }

    public func setOBSCaptureMode(_ mode: Int) {
        let clamped = max(0, min(2, mode))
        obsCaptureMode = clamped
        CatSettings.shared.obsCaptureMode = clamped
        if clamped == 0 {
            obsHideDesktop = false
            CatSettings.shared.obsHideDesktop = false
        }
        overlayWindow?.applyOBSMode()
        wakeToActive(immediateRedraw: true)
    }

    public func setOBSHideDesktop(_ value: Bool) {
        obsHideDesktop = value
        CatSettings.shared.obsHideDesktop = value
        overlayWindow?.applyOBSMode()
        wakeToActive(immediateRedraw: true)
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
        if !value {
            PetAudioBank.shared.stopAll()
        }
    }

    public func setDuelVoiceStyle(_ style: PetDuelVoiceStyle) {
        duelVoiceStyle = style
        CatSettings.shared.duelVoiceStyle = style
    }

    public func setDuelVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        duelVolume = clamped
        CatSettings.shared.duelVolume = clamped
    }

    public func previewDuelVoice() {
        PetAudioBank.shared.previewDuelVoice(duelVoiceStyle, volume: duelVolume)
    }

    public func setKeyboardSound(_ value: Bool) {
        keyboardSound = value
        CatSettings.shared.keyboardSound = value
        if !value {
            PetAudioBank.shared.stopAll()
        }
    }

    public func setVoiceTypingSound(_ value: Bool) {
        voiceTypingSound = value
        CatSettings.shared.voiceTypingSound = value
    }

    public func setKeyboardTone(_ tone: PetKeyboardTone) {
        keyboardTone = tone
        CatSettings.shared.keyboardTone = tone
        PetAudioBank.shared.previewKeyboardTone(tone, volume: keyboardVolume)
    }

    public func setKeyboardVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        keyboardVolume = clamped
        CatSettings.shared.keyboardVolume = clamped
    }

    public func previewKeyboardTone() {
        PetAudioBank.shared.previewKeyboardTone(keyboardTone, volume: keyboardVolume)
    }

    public func setMouseSound(_ value: Bool) {
        mouseSound = value
        CatSettings.shared.mouseSound = value
    }

    public func setMouseTone(_ tone: PetMouseTone) {
        mouseTone = tone
        CatSettings.shared.mouseTone = tone
        PetAudioBank.shared.previewMouseTone(tone, volume: mouseVolume)
    }

    public func setMouseVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        mouseVolume = clamped
        CatSettings.shared.mouseVolume = clamped
    }

    public func previewMouseTone() {
        PetAudioBank.shared.previewMouseTone(mouseTone, volume: mouseVolume)
    }

    // MARK: - Skin & Keyboard Skin Management (.kurocat & .kurokb, Trash-Safe!)

    public func importSkinViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "导入 .kurocat 桌宠皮肤"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let ut = UTType(filenameExtension: "kurocat") {
            panel.allowedContentTypes = [ut, .json]
        }
        if panel.runModal() == .OK, let url = panel.url {
            importDroppedFile(url)
        }
    }

    public func importKeyboardSkinViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "导入 .kurokb / .json 键盘皮肤"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.json]
        if let kbUT = UTType(filenameExtension: "kurokb") {
            types.insert(kbUT, at: 0)
        }
        panel.allowedContentTypes = types
        if panel.runModal() == .OK, let url = panel.url {
            importKeyboardSkinFile(url)
        }
    }

    public func importDroppedFile(_ url: URL) {
        if KeyboardSkinSpec.looksLikeKeyboardJSON(url) {
            importKeyboardSkinFile(url)
        } else {
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

    public func importKeyboardSkinFile(_ url: URL) {
        do {
            let newID = try KeyboardSkinLibrary.shared.importFile(url)
            importedKeyboardSkins = KeyboardSkinLibrary.shared.skins
            selectCustomKeyboard(id: newID)
            if let kb = KeyboardSkinLibrary.shared.skin(id: newID) {
                statusNotice = "✅ 已导入键盘皮肤「\(kb.name)」"
            }
        } catch {
            statusNotice = "⚠️ \(error.localizedDescription)"
        }
    }

    public func renameImportedSkin(id: String) {
        guard let skin = SkinLibrary.shared.skin(id: id) else { return }
        let alert = NSAlert()
        alert.messageText = "重命名桌宠皮肤"
        alert.informativeText = "为「\(skin.name)」输入新名称（最多 40 字）："
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = skin.name
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != skin.name else { return }
        do {
            let newID = try SkinLibrary.shared.rename(id: id, newName: trimmed)
            importedSkins = SkinLibrary.shared.skins
            if customSkinID == id {
                CatSettings.shared.customSkin = newID
                customSkinID = newID
            }
            statusNotice = "✅ 已重命名为「\(trimmed)」"
            wakeToActive(immediateRedraw: true)
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
        wakeToActive(immediateRedraw: true)
    }

    public func removeImportedKeyboardSkin(id: String) {
        if customKeyboardID == id {
            CatSettings.shared.customKeyboard = ""
            customKeyboardID = ""
        }
        KeyboardSkinLibrary.shared.remove(id: id)
        importedKeyboardSkins = KeyboardSkinLibrary.shared.skins
        wakeToActive(immediateRedraw: true)
    }

    public func openSkinWorkshop() {
        if let url = URL(string: "https://workshop.kurocat.cc/") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openKeyboardPlaza() {
        if let url = URL(string: "https://workshop.kurocat.cc/#keyboards") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openInputMonitoringSettings() {
        InputEngine.shared.requestPermissionsAndOpenSettings()
    }

    // MARK: - Right-Click Quick Context Menu on Desktop Cat

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "TypeZero 桌面搭子")

        let header = NSMenuItem(
            title: "🐱 桌面搭子 · 今日敲键 \(todayPhysicalKeys + todayVoiceKeys) · KPM \(InputEngine.shared.currentKPM)",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        if inputNeedsPermission {
            let permItem = NSMenuItem(title: "🔑 开启「输入监控」全局跟随权限…", action: #selector(handleOpenInputSettings), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
        }
        menu.addItem(.separator())

        // Style submenu
        let styleSub = NSMenu()
        for st in PetVisualStyle.allCases {
            let item = NSMenuItem(title: st.title, action: #selector(handleStyleMenuPick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = st.rawValue
            item.state = (visualStyle == st) ? .on : .off
            styleSub.addItem(item)
        }
        let styleParent = NSMenuItem(title: "🎨 画风引擎（\(visualStyle.title)）", action: nil, keyEquivalent: "")
        styleParent.submenu = styleSub
        menu.addItem(styleParent)

        // Breed & Handover submenu
        let breedSub = NSMenu()
        for coat in CatCoatTheme.allCases {
            let item = NSMenuItem(title: "换班：\(coat.shortTitle)", action: #selector(handleCoatMenuPick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = coat.rawValue
            item.state = (customSkinID.isEmpty && coatTheme == coat) ? .on : .off
            breedSub.addItem(item)
        }
        if !importedSkins.isEmpty {
            breedSub.addItem(.separator())
            for sk in importedSkins {
                let item = NSMenuItem(title: "皮肤：\(SkinLibrary.shared.displayName(for: sk))", action: #selector(handleCustomSkinMenuPick(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = sk.id
                item.state = (customSkinID == sk.id) ? .on : .off
                breedSub.addItem(item)
            }
        }
        let breedParent = NSMenuItem(title: "🐱 猫咪品种换班", action: nil, keyEquivalent: "")
        breedParent.submenu = breedSub
        menu.addItem(breedParent)

        let demoItem = NSMenuItem(title: "🎬 立即演示「顶额头吵架换班」", action: #selector(handleDemoHandoverAction), keyEquivalent: "")
        demoItem.target = self
        menu.addItem(demoItem)

        menu.addItem(.separator())

        let marqueeItem = NSMenuItem(title: "✨ 键盘 RGB 流光跑马灯", action: #selector(handleToggleMarquee), keyEquivalent: "")
        marqueeItem.target = self
        marqueeItem.state = keyboardMarquee ? .on : .off
        menu.addItem(marqueeItem)

        let glowItem = NSMenuItem(title: "💡 按键单键背光光晕", action: #selector(handleToggleKeyGlow), keyEquivalent: "")
        glowItem.target = self
        glowItem.state = keyboardKeyGlow ? .on : .off
        menu.addItem(glowItem)

        let kbSoundItem = NSMenuItem(title: "🔊 键盘敲击声（\(keyboardTone.title)）", action: #selector(handleToggleKeyboardSound), keyEquivalent: "")
        kbSoundItem.target = self
        kbSoundItem.state = keyboardSound ? .on : .off
        menu.addItem(kbSoundItem)

        let mouseSoundItem = NSMenuItem(title: "🖱️ 鼠标点击声（\(mouseTone.title)）", action: #selector(handleToggleMouseSound), keyEquivalent: "")
        mouseSoundItem.target = self
        mouseSoundItem.state = mouseSound ? .on : .off
        menu.addItem(mouseSoundItem)

        let levelKbItem = NSMenuItem(title: "⌨️ 键盘水平摆放（平行屏幕）", action: #selector(handleToggleLevelKeyboard), keyEquivalent: "")
        levelKbItem.target = self
        levelKbItem.state = levelKeyboard ? .on : .off
        menu.addItem(levelKbItem)

        menu.addItem(.separator())

        let pauseItem = NSMenuItem(title: "⏸️ 暂停键鼠同步", action: #selector(handleTogglePauseSync), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.state = pauseInputSync ? .on : .off
        menu.addItem(pauseItem)

        let privacyItem = NSMenuItem(title: "🛡️ 隐私模式（隐藏具体键位与键名）", action: #selector(handleTogglePrivacyMode), keyEquivalent: "")
        privacyItem.target = self
        privacyItem.state = privacyMode ? .on : .off
        menu.addItem(privacyItem)

        let clickThroughItem = NSMenuItem(title: "👻 完全鼠标穿透（按住 ⌥ 可拖动）", action: #selector(handleToggleClickThrough), keyEquivalent: "")
        clickThroughItem.target = self
        clickThroughItem.state = fullClickThrough ? .on : .off
        menu.addItem(clickThroughItem)

        menu.addItem(.separator())

        let resetPosItem = NSMenuItem(title: "📍 重置位置到屏幕右下角", action: #selector(handleResetPositionAction), keyEquivalent: "")
        resetPosItem.target = self
        menu.addItem(resetPosItem)

        let openPanelItem = NSMenuItem(title: "⚙️ 打开「桌面搭子」完整设置…", action: #selector(handleOpenSettingsAction), keyEquivalent: ",")
        openPanelItem.target = self
        menu.addItem(openPanelItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(title: "暂时关闭桌面搭子", action: #selector(handleDisablePetAction), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        return menu
    }

    @objc private func handleOpenInputSettings() { openInputMonitoringSettings() }
    @objc private func handleStyleMenuPick(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let st = PetVisualStyle(rawValue: raw) else { return }
        setVisualStyle(st)
    }
    @objc private func handleCoatMenuPick(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let coat = CatCoatTheme(rawValue: raw) else { return }
        selectBuiltInCoat(coat)
    }
    @objc private func handleCustomSkinMenuPick(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        selectCustomSkin(id: id)
    }
    @objc private func handleDemoHandoverAction() { playShiftHandoverDemo() }
    @objc private func handleToggleMarquee() { setKeyboardMarquee(!keyboardMarquee) }
    @objc private func handleToggleKeyGlow() { setKeyboardKeyGlow(!keyboardKeyGlow) }
    @objc private func handleToggleKeyboardSound() { setKeyboardSound(!keyboardSound) }
    @objc private func handleToggleMouseSound() { setMouseSound(!mouseSound) }
    @objc private func handleToggleLevelKeyboard() { setLevelKeyboard(!levelKeyboard) }
    @objc private func handleTogglePauseSync() { setPauseInputSync(!pauseInputSync) }
    @objc private func handleTogglePrivacyMode() { setPrivacyMode(!privacyMode) }
    @objc private func handleToggleClickThrough() { setFullClickThrough(!fullClickThrough) }
    @objc private func handleResetPositionAction() { resetPosition() }
    @objc private func handleOpenSettingsAction() { onOpenPetSettingsTab?() }
    @objc private func handleDisablePetAction() { setEnabled(false) }

    // MARK: - Hourly Toast Timer (Inherited from KuroCat)

    private func startHourlyTimerIfNeeded() {
        guard minuteTimer == nil else { return }
        let t = Timer(timeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkHourlyAnnouncement()
            }
        }
        t.tolerance = 4.0
        RunLoop.main.add(t, forMode: .common)
        minuteTimer = t
    }

    private func checkHourlyAnnouncement() {
        guard isEnabled, hourlyAnnouncement else { return }
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        if minute == 0 && hour != lastAnnouncedHour {
            lastAnnouncedHour = hour
            showHourlyToast(hour: hour)
        }
    }

    private func showHourlyToast(hour: Int) {
        let period: String
        let displayHour: Int
        if hour == 0 {
            period = "凌晨"; displayHour = 12
        } else if hour < 6 {
            period = "凌晨"; displayHour = hour
        } else if hour == 12 {
            period = "中午"; displayHour = 12
        } else if hour < 12 {
            period = "上午"; displayHour = hour
        } else {
            period = hour < 18 ? "下午" : "晚上"
            displayHour = hour - 12
        }
        overlayWindow?.catView.showToast(text: "🕐 \(period) \(displayHour) 点整")
        wakeToActive(immediateRedraw: true)
    }

    // MARK: - Adaptive 60/30/15 FPS Render Loop, Fullscreen Auto-Hide & Headphones

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
        workspaceObservers.append(
            nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isEnabled, self.fullScreenOverlay, !self.hiddenByFullscreen else { return }
                    if !(self.obsCaptureMode > 0 && self.obsHideDesktop) {
                        self.overlayWindow?.orderFrontRegardless()
                    }
                }
            }
        )
    }

    private func updateFullscreenAutoHide(now: CFTimeInterval) -> Bool {
        let obsBg = (obsCaptureMode > 0 && obsHideDesktop)
        if !autoHideFullscreen || obsBg {
            if hiddenByFullscreen {
                hiddenByFullscreen = false
                overlayWindow?.alphaValue = 1.0
                lastFrameTime = now
                overlayWindow?.catView.needsDisplay = true
            }
            return false
        }
        if now - lastFullscreenCheckTime <= 0.6 || fullscreenCheckInFlight {
            return hiddenByFullscreen
        }
        lastFullscreenCheckTime = now
        fullscreenCheckInFlight = true
        fullscreenCheckQueue.async { [weak self] in
            let fs = Self.isOtherAppFullscreen()
            Task { @MainActor in
                guard let self else { return }
                self.fullscreenCheckInFlight = false
                let obsNow = (self.obsCaptureMode > 0 && self.obsHideDesktop)
                guard self.autoHideFullscreen && !obsNow else { return }
                if fs != self.hiddenByFullscreen {
                    self.hiddenByFullscreen = fs
                    self.overlayWindow?.alphaValue = fs ? 0.0 : 1.0
                    if fs {
                        self.overlayWindow?.ignoresMouseEvents = true
                    } else {
                        self.lastFrameTime = CACurrentMediaTime()
                        self.overlayWindow?.catView.needsDisplay = true
                    }
                }
            }
        }
        return hiddenByFullscreen
    }

    nonisolated private static func isOtherAppFullscreen() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              front.bundleIdentifier != "com.apple.finder" else {
            return false
        }
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let pid = front.processIdentifier
        for w in list {
            guard let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid,
                  let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            for screen in NSScreen.screens {
                if rect.width >= screen.frame.width - 2 && rect.height >= screen.frame.height - 2 {
                    return true
                }
            }
        }
        return false
    }

    private func renderTick() {
        guard isEnabled, !screensAsleep, let overlayWindow else {
            configureRenderTimer(for: .paused)
            return
        }
        let now = CACurrentMediaTime()
        if updateFullscreenAutoHide(now: now) {
            configureRenderTimer(for: .fullscreenHidden)
            return
        }
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

        view.updateHoverAndClickThrough()
        physics.step(dt: dt, windowFrameInScreen: physicsFrame)
        view.tickToast(dt: dt)

        let curKPM = input.currentKPM
        if currentKPM != curKPM {
            currentKPM = curKPM
        }
        if isHandoverRunning != physics.isHandoverActive {
            isHandoverRunning = physics.isHandoverActive
        }

        let lastDirectInput = pauseInputSync ? physics.lastVirtualKeyTime : max(input.lastKeyActivityTime, max(input.lastMouseClickTime, physics.lastVirtualKeyTime))
        let mouseMoving = !pauseInputSync && (now - input.lastMouseMoveTime < 0.12)
        let mouseStartedMoving = mouseMoving && now - previousMouseMoveTime >= 0.12
        let mouseNearPet = mouseMoving && windowFrame.insetBy(dx: -24, dy: -24).contains(input.lastMouseLocation)
        let isAsleep = visualStyle == .clackOriginal ? physics.clackSim.pose.sleeping : (physics.sleepiness >= 0.95)
        let hasActiveSparkles = physics.sparkles.contains { !$0.isSleepZ }
        let clackActive = visualStyle == .clackOriginal && (physics.clackSim.pose.active || !physics.clackSim.pose.bubbles.isEmpty)
        let hasMotion = physics.isHandoverActive
            || clackActive
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

        let isActive = now - lastDirectInput < 0.8 || (!pauseInputSync && !input.activeKeys.isEmpty)
            || mouseStartedMoving || mouseNearPet
            || (!pauseInputSync && (input.leftMouseDown || input.rightMouseDown || input.otherMouseDown))
            || view.isDraggingOrResizing || hasMotion
            || wasToastActive || view.toastActive

        let desiredCadence: RenderCadence = isActive ? .active : (isAsleep ? .asleep : .idle)
        if desiredCadence != renderCadence {
            if desiredCadence == .asleep {
                CatRenderer.purgeVolatileCaches()
            }
            configureRenderTimer(for: desiredCadence)
        }
        if isActive || visualStyle == .clackOriginal || view.poseNeedsDisplay() {
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

        let ownSoundActive = PetAudioBank.shared.isRecentlyPlayingOwnSound
        musicCheckQueue.async { [weak self] in
            let audioRunning = Self.isAnyAudioOutputRunning()
            Task { @MainActor in
                guard let self else { return }
                let playing: Bool
                if audioRunning {
                    if !self.cachedMusicPlaying && ownSoundActive {
                        // Ignore our own short typing clicks / duel meow so they don't falsely trigger headphones
                        playing = false
                    } else {
                        if self.musicAudioSustainedSince == 0 {
                            self.musicAudioSustainedSince = now
                        }
                        playing = (now - self.musicAudioSustainedSince) >= 1.5
                    }
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
