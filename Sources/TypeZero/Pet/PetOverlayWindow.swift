import Foundation
import AppKit

private struct RenderedPose {
    struct ForegroundAppearance: Equatable {
        let style: PetVisualStyle
        let coat: CatCoatTheme
        let skinId: String
        let eyes: EyeColorTheme
        let tabletKeyboard: KeyboardTheme?
        let size: CGSize
        let flipped: Bool
        let rotationDeg: CGFloat
        let whiteOutline: Bool
        let overrideSkinIris: Bool
        let tabletActive: Bool
        let handoverActive: Bool
        let dictationListening: Bool
    }

    struct Appearance: Equatable {
        let foreground: ForegroundAppearance
        let keyboard: KeyboardTheme
        let keyboardSkinId: String
        let showsLegends: Bool
        let levelKeyboard: Bool
        let keyGlowEnabled: Bool
        let marqueeMode: Int
        let captureMode: Int
        let showEditControls: Bool
        let englishLabels: Bool
    }

    let appearance: Appearance
    let marqueeBucket: Int
    let hasEffects: Bool
    let head: CGPoint
    let tail: CGPoint
    let tailBend: CGPoint
    let leftPaw: CGPoint
    let rightPaw: CGPoint
    let eyeClosure: CGFloat
    let headTurn: CGPoint
    let headTilt: CGFloat
    let eyeGaze: CGPoint
    let mouseOffset: CGPoint
    let mousePressLeft: CGFloat
    let mousePressRight: CGFloat
    let mousePressMiddle: CGFloat
    let pawOnMouse: Bool
    let hindFoot: CGPoint
    let hindFootActive: CGFloat
    let yawnAmount: CGFloat
    let earFold: CGFloat
    let earTwitch: CGFloat
    let pupilScale: CGFloat
    let bodyTilt: CGFloat
    let bodySquash: CGFloat
    let lieIntensity: CGFloat
    let anger: CGFloat
    let dizzy: CGFloat
    let petIntensity: CGFloat
    let douniLoaf: CGFloat
    let douniMouse: CGFloat
    let douniLeftRaise: CGFloat
    let douniRightRaise: CGFloat
    let douniLeftTarget: CGPoint
    let douniRightTarget: CGPoint
    let douniBreath: CGFloat
    let douniAccentBucket: Int
    let hunt: CGFloat
    let tabletNib: CGPoint
    let tabletPress: CGFloat
    let toastActive: Bool
    let toastProgress: CGFloat
    let nameBubbleActive: Bool
    let nameBubbleProgress: CGFloat
    let nameBubbleBobBucket: Int
    let showPermissionPill: Bool
    let permissionPillText: String

    init(physics: CatPhysics, settings: CatSettings, skin: SkinSpec, size: CGSize,
         showPermissionPill: Bool, permissionPillText: String,
         toastActive: Bool = false, toastProgress: CGFloat = 0,
         nameBubbleActive: Bool = false, nameBubbleProgress: CGFloat = 0, nameBubbleBobBucket: Int = 0) {
        let coat = settings.coatTheme
        let tabletActive = physics.isTabletActive
        let kbTheme = settings.keyboardTheme
        let fgAppearance = ForegroundAppearance(
            style: settings.visualStyle,
            coat: coat,
            skinId: skin.id,
            eyes: settings.eyeTheme,
            tabletKeyboard: tabletActive ? kbTheme : nil,
            size: size,
            flipped: settings.flipHorizontal,
            rotationDeg: settings.rotationDeg,
            whiteOutline: settings.whiteOutline,
            overrideSkinIris: settings.overrideSkinIris,
            tabletActive: tabletActive,
            handoverActive: physics.isHandoverActive,
            dictationListening: physics.isDictationListening
        )
        appearance = Appearance(
            foreground: fgAppearance,
            keyboard: kbTheme,
            keyboardSkinId: settings.activeKeyboardSkin.id,
            showsLegends: settings.showKeyLegends,
            levelKeyboard: settings.levelKeyboard,
            keyGlowEnabled: settings.keyboardKeyGlow,
            marqueeMode: settings.marqueeMode.rawValue,
            captureMode: settings.obsCaptureMode,
            showEditControls: settings.isEditMode,
            englishLabels: settings.isEnglish
        )

        let scruff = physics.scruffDrag.value
        let loaf = physics.douniLoafBlend.value
        let asleep = physics.sleepiness >= 0.95
        let usesDouniDesk = (skin.renderStyle == .douni || skin.renderStyle == .beagle)
        let keyboardVisible = usesDouniDesk ? (loaf < 0.99 && scruff < 0.99) : (scruff * 2.6 < 0.99)
        marqueeBucket = (settings.keyboardMarquee && keyboardVisible)
            ? CatRenderer.marqueeBucket(phase: physics.marqueePhase, asleep: asleep)
            : -1

        let pet = max(physics.petHeadIntensity, physics.petBodyIntensity)
        hasEffects = physics.isHandoverActive
            || settings.visualStyle == .clackOriginal
            || physics.isDictationListening
            || !physics.sparkles.isEmpty
            || !physics.floatingKeycaps.isEmpty || !physics.keyGlow.isEmpty
            || !physics.tabletTrail.isEmpty || physics.kbSparkTimer > 0.005
            || physics.angerIntensity.value > 0.02 || physics.dizzyIntensity.value > 0.02
            || physics.scruffDizzyIntensity.value > 0.02
            || physics.huntIntensity.value > 0.02
            || scruff > 0.02 || physics.isChangingLie
            || abs(physics.scruffSwing.value) > 0.01 || abs(physics.scruffSwingY.value) > 0.01
            || abs(physics.scruffTailSwing.value) > 0.01
            || (loaf > 0.005 && loaf < 0.995)
            || abs(physics.douniLoafBlend.velocity) > 0.02
            || abs(physics.douniLeftRaise.velocity) > 0.05 || abs(physics.douniRightRaise.velocity) > 0.05
            || abs(physics.douniMouseBlend.velocity) > 0.05
            || abs(physics.kbImpactY.value) > 0.01 || abs(physics.kbImpactTilt.value) > 0.01
            || pet > 0.02
            || toastActive
            || nameBubbleActive

        head = CatRenderer.headPosition(physics, skin: skin)
        let tailCurve = CatRenderer.tailCurve(physics)
        tail = tailCurve.tip
        tailBend = tailCurve.control2
        leftPaw = physics.leftPaw.point
        rightPaw = physics.rightPaw.point
        eyeClosure = physics.effectiveEyeClosure
        headTurn = CGPoint(x: physics.headYaw.value, y: physics.headPitch.value)
        headTilt = physics.headTilt.value
        eyeGaze = physics.eyeGaze.point
        mouseOffset = physics.mouseOffset.point
        mousePressLeft = physics.mousePressLeft.value
        mousePressRight = physics.mousePressRight.value
        mousePressMiddle = physics.mousePressMiddle.value
        pawOnMouse = physics.leftPawOnMouse
        hindFoot = physics.hindFoot.point
        hindFootActive = physics.hindFootActive.value
        yawnAmount = physics.yawnAmount
        earFold = physics.earFold.value
        earTwitch = physics.earTwitch.value
        pupilScale = physics.pupilScale.value
        bodyTilt = physics.bodyTilt.value
        bodySquash = physics.bodySquash.value
        lieIntensity = physics.lieIntensity.value
        anger = physics.angerIntensity.value
        dizzy = max(physics.dizzyIntensity.value, physics.scruffDizzyIntensity.value)
        petIntensity = pet
        douniLoaf = loaf
        douniMouse = physics.douniMouseBlend.value
        douniLeftRaise = physics.douniLeftRaise.value
        douniRightRaise = physics.douniRightRaise.value
        douniLeftTarget = physics.douniLeftKeyTarget.point
        douniRightTarget = physics.douniRightKeyTarget.point
        if usesDouniDesk && loaf > 0.85 {
            douniBreath = sin(physics.time * (asleep ? 1.7 : 2.3))
            douniAccentBucket = (asleep || pet > 0.05) ? Int((physics.time * (asleep ? 15.0 : 24.0)).rounded()) : 0
        } else {
            douniBreath = 0
            douniAccentBucket = 0
        }
        hunt = physics.huntIntensity.value
        tabletNib = physics.tabletNib.point
        tabletPress = physics.tabletPenPress.value
        self.toastActive = toastActive
        self.toastProgress = toastProgress
        self.nameBubbleActive = nameBubbleActive
        self.nameBubbleProgress = nameBubbleProgress
        self.nameBubbleBobBucket = nameBubbleBobBucket
        self.showPermissionPill = showPermissionPill
        self.permissionPillText = showPermissionPill ? permissionPillText : ""
    }

    func foregroundDiffers(from previous: RenderedPose) -> Bool {
        if appearance.foreground != previous.appearance.foreground || hasEffects || previous.hasEffects
            || pawOnMouse != previous.pawOnMouse || douniAccentBucket != previous.douniAccentBucket {
            return true
        }
        func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        let movement = max(distance(head, previous.head),
                           distance(tail, previous.tail),
                           distance(tailBend, previous.tailBend),
                           distance(leftPaw, previous.leftPaw),
                           distance(rightPaw, previous.rightPaw),
                           abs(eyeClosure - previous.eyeClosure) * 40,
                           distance(headTurn, previous.headTurn) * 24,
                           abs(headTilt - previous.headTilt) * 52,
                           distance(eyeGaze, previous.eyeGaze) * 10,
                           distance(mouseOffset, previous.mouseOffset),
                           distance(hindFoot, previous.hindFoot) * max(hindFootActive, previous.hindFootActive),
                           abs(hindFootActive - previous.hindFootActive) * 30,
                           abs(yawnAmount - previous.yawnAmount) * 25,
                           abs(earFold - previous.earFold) * 25,
                           abs(earTwitch - previous.earTwitch) * 18,
                           abs(pupilScale - previous.pupilScale) * 20,
                           abs(bodyTilt - previous.bodyTilt) * 45,
                           abs(bodySquash - previous.bodySquash) * 40,
                           abs(lieIntensity - previous.lieIntensity) * 60,
                           abs(anger - previous.anger) * 20,
                           abs(dizzy - previous.dizzy) * 25,
                           abs(petIntensity - previous.petIntensity) * 15,
                           abs(douniLoaf - previous.douniLoaf) * 90,
                           abs(douniMouse - previous.douniMouse) * 50,
                           abs(douniLeftRaise - previous.douniLeftRaise) * 55,
                           abs(douniRightRaise - previous.douniRightRaise) * 55,
                           distance(douniLeftTarget, previous.douniLeftTarget) * 0.4,
                           distance(douniRightTarget, previous.douniRightTarget) * 0.4,
                           abs(douniBreath - previous.douniBreath) * 15,
                           abs(hunt - previous.hunt) * 40,
                           distance(tabletNib, previous.tabletNib),
                           abs(tabletPress - previous.tabletPress) * 20)
        let scale = max(appearance.foreground.size.width / CatCanvasView.stageSize.width,
                        appearance.foreground.size.height / CatCanvasView.stageSize.height)
        return movement * scale >= 0.65
    }

    func visiblyDiffers(from previous: RenderedPose) -> Bool {
        if marqueeBucket != previous.marqueeBucket
            || appearance != previous.appearance
            || toastActive != previous.toastActive
            || abs(toastProgress - previous.toastProgress) > 0.004
            || nameBubbleActive != previous.nameBubbleActive
            || abs(nameBubbleProgress - previous.nameBubbleProgress) > 0.004
            || nameBubbleBobBucket != previous.nameBubbleBobBucket
            || showPermissionPill != previous.showPermissionPill
            || permissionPillText != previous.permissionPillText {
            return true
        }
        let scale = max(appearance.foreground.size.width / CatCanvasView.stageSize.width,
                        appearance.foreground.size.height / CatCanvasView.stageSize.height)
        let pressMovement = max(abs(mousePressLeft - previous.mousePressLeft),
                                abs(mousePressRight - previous.mousePressRight),
                                abs(mousePressMiddle - previous.mousePressMiddle)) * 20
        if pressMovement * scale >= 0.65 {
            return true
        }
        return foregroundDiffers(from: previous)
    }
}

final class CatCanvasView: NSView {
    private static let fgColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private enum ActiveCursor { case arrow, openHand, pointingHand, crosshair, closedHand }

    let physics = CatPhysics()
    var onRequestPermission: (() -> Void)?
    var onRightClickMenu: ((NSEvent) -> Void)?
    var onUserInteraction: (() -> Void)?
    var onScaleChanged: ((CGFloat) -> Void)?
    var onDropSkinFiles: (([URL]) -> Void)?
    var onDropPhotoURLs: (([URL]) -> Void)?
    var onHeadPetMilestone: (() -> Void)?

    /// Transparent horizontal stage runway (`102pt` on each side -> `564pt` total width) so Clack-Clack's
    /// 10.58s 2-cat walking entrance, forehead-butting arched-back duel, and walking exit never clip!
    static let stagePadX: CGFloat = 102
    static let contentTopInset: CGFloat = 68
    static let stageSize = CGSize(
        width: CatPhysics.canvasSize.width + stagePadX * 2, // 564pt
        height: CatPhysics.canvasSize.height + contentTopInset // 388pt
    )

    private var lastHoverCanvasPt: CGPoint?
    private var isDragging = false
    private var pendingDoubleClickToggle = false
    private var doubleClickDownScreenPt: CGPoint = .zero
    private var isRotating = false
    private var rotateStartMouseAngle: CGFloat = 0
    private var rotateStartDeg: CGFloat = 0
    private var rotateDragged = false
    private var activeResizeCorner: Int = -1
    private var resizeAnchorScreenPt: CGPoint = .zero
    private var resizeStartFrame: CGRect = .zero
    private var dragStartScreenPt: CGPoint = .zero
    private var dragStartWindowOrigin: CGPoint = .zero
    private var dragScruffAnchorDelta: CGPoint = .zero
    private var lastDragScreenPt: CGPoint = .zero
    private var activeCursor: ActiveCursor = .arrow
    private var lastHoverWasInside = false
    private var lastDrawnPose: RenderedPose?
    private var cachedForegroundImage: CGImage?
    private var cachedForegroundPose: RenderedPose?
    private var cachedForegroundBackingScale: CGFloat = 0

    private var toastText: String? = nil
    private var toastProgress: CGFloat = 0
    private var toastPhase: Double = 0
    private let toastFadeIn: Double = 0.35
    private let toastHold: Double = 3.2
    private let toastFadeOut: Double = 0.40
    var toastActive: Bool { toastText != nil }

    private var nameBubbleText: String? = nil
    private var nameBubbleMood: String = ""
    private var nameBubbleProgress: CGFloat = 0
    private var nameBubblePhase: Double = 0
    private let nameBubbleFadeIn: Double = 0.38
    private let nameBubbleHold: Double = 3.10
    private let nameBubbleFadeOut: Double = 0.52
    var nameBubbleActive: Bool { nameBubbleText != nil }
    private var lastPetMilestoneTime: CFTimeInterval = -100
    var forceClickThroughForModal = false

    var isDraggingOrResizing: Bool { isDragging || isRotating || activeResizeCorner >= 0 }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let settings = CatSettings.shared
        if settings.obsCaptureMode == 2 {
            ctx.setFillColor(NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0).cgColor)
            ctx.fill(bounds)
        } else {
            ctx.clear(bounds)
        }

        let scaleX = bounds.width / Self.stageSize.width
        let scaleY = bounds.height / Self.stageSize.height
        let status = InputEngine.shared.status
        let showPill = status.needsAttention && !AXIsProcessTrusted()
        let pillText = status.permissionPillText

        // Mode B: 1:1 Original Chingyim/Clack-Clack Stage Renderer
        if settings.visualStyle == .clackOriginal {
            ctx.saveGState()
            ctx.scaleBy(x: scaleX, y: scaleY)
            if settings.flipHorizontal || abs(settings.rotationDeg) > 0.05 {
                let cx = Self.stageSize.width * 0.5
                let cy = Self.stageSize.height * 0.56
                ctx.translateBy(x: cx, y: cy)
                if abs(settings.rotationDeg) > 0.05 {
                    ctx.rotate(by: settings.rotationDeg * .pi / 180.0)
                }
                if settings.flipHorizontal {
                    ctx.scaleBy(x: -1, y: 1)
                }
                ctx.translateBy(x: -cx, y: -cy)
            }

            let priv = settings.isEffectivePrivacyActive
            ClackRenderer.drawStage(
                in: ctx,
                pose: physics.clackSim.pose,
                breed: settings.coatTheme,
                handover: physics.clackSim.currentHandoverFrame,
                customSkin: settings.customSkin.isEmpty ? nil : settings.activeSkin,
                anchorX: ClackStageConst.overlayAnchorX,
                anchorY: ClackStageConst.overlayAnchorY,
                baseScale: ClackStageConst.overlayBaseScale,
                whiteOutline: settings.whiteOutline,
                showKeyLabels: settings.showKeyLegends && !priv,
                showKeyBubbles: settings.showKeyBadges && !priv,
                isDictationListening: physics.isDictationListening,
                isMusicPlaying: physics.isMusicPlaying
            )

            ctx.translateBy(x: Self.stagePadX, y: Self.contentTopInset)
            if settings.isEditMode {
                CatRenderer.drawEditOverlay(
                    in: ctx,
                    isEnglish: settings.isEnglish,
                    scale: settings.scale,
                    rotationDeg: settings.rotationDeg,
                    flipped: settings.flipHorizontal
                )
            }
            if showPill {
                CatRenderer.drawOverlays(in: ctx, showPermissionPill: true, permissionPillText: pillText)
            }
            if toastActive, let text = toastText {
                drawToastPill(in: ctx, text: text, alpha: toastProgress)
            } else if nameBubbleActive, let nameText = nameBubbleText, !physics.isHandoverActive, physics.scruffDrag.value < 0.18 {
                drawFloatingCatName(in: ctx, name: nameText, mood: nameBubbleMood, alpha: nameBubbleProgress, phase: CGFloat(nameBubblePhase))
            }
            ctx.restoreGState()
            cachedForegroundImage = nil
            cachedForegroundPose = nil
            return
        }

        // Mode A: KuroCat 2.5D Sticker Style + 1:1 Clack-Clack Handover Behind KuroCat Keyboard
        ctx.saveGState()
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.translateBy(x: Self.stagePadX, y: Self.contentTopInset)

        let skin = settings.activeSkin
        let bobBucket = nameBubbleActive ? Int((nameBubblePhase * 24.0).rounded()) : 0
        let currentPose = RenderedPose(
            physics: physics,
            settings: settings,
            skin: skin,
            size: bounds.size,
            showPermissionPill: showPill,
            permissionPillText: pillText,
            toastActive: toastActive,
            toastProgress: toastProgress,
            nameBubbleActive: nameBubbleActive,
            nameBubbleProgress: nameBubbleProgress,
            nameBubbleBobBucket: bobBucket
        )

        if physics.sleepiness >= 0.95,
           !physics.isHandoverActive,
           !physics.isDictationListening,
           settings.obsCaptureMode != 2,
           CatRenderer.canSplitLayers(physics: physics, skin: skin),
           settings.keyboardMarquee,
           !currentPose.hasEffects {
            let backingScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
            let needRebuild: Bool = {
                guard cachedForegroundImage != nil,
                      let fgPose = cachedForegroundPose,
                      cachedForegroundBackingScale == backingScale else { return true }
                return currentPose.foregroundDiffers(from: fgPose)
            }()
            if needRebuild {
                cachedForegroundImage = renderForegroundBitmap(backingScale: backingScale)
                cachedForegroundPose = currentPose
                cachedForegroundBackingScale = backingScale
            }
            if let fgImage = cachedForegroundImage {
                CatRenderer.drawBackdrop(in: ctx, physics: physics)
                ctx.saveGState()
                ctx.translateBy(x: 0, y: CatPhysics.canvasSize.height)
                ctx.scaleBy(x: 1, y: -1)
                ctx.draw(fgImage, in: CGRect(origin: .zero, size: CatPhysics.canvasSize))
                ctx.restoreGState()
                CatRenderer.drawOverlays(in: ctx, showPermissionPill: showPill, permissionPillText: pillText)
                if toastActive, let text = toastText {
                    drawToastPill(in: ctx, text: text, alpha: toastProgress)
                } else if nameBubbleActive, let nameText = nameBubbleText, !physics.isHandoverActive, physics.scruffDrag.value < 0.18 {
                    drawFloatingCatName(in: ctx, name: nameText, mood: nameBubbleMood, alpha: nameBubbleProgress, phase: CGFloat(nameBubblePhase))
                }
                lastDrawnPose = currentPose
                ctx.restoreGState()
                return
            }
        }

        cachedForegroundImage = nil
        cachedForegroundPose = nil
        CatRenderer.draw(in: ctx, physics: physics, showPermissionPill: showPill, permissionPillText: pillText)
        if toastActive, let text = toastText {
            drawToastPill(in: ctx, text: text, alpha: toastProgress)
        } else if nameBubbleActive, let nameText = nameBubbleText, !physics.isHandoverActive, physics.scruffDrag.value < 0.18 {
            drawFloatingCatName(in: ctx, name: nameText, mood: nameBubbleMood, alpha: nameBubbleProgress, phase: CGFloat(nameBubblePhase))
        }
        lastDrawnPose = currentPose
        ctx.restoreGState()
    }

    private func renderForegroundBitmap(backingScale: CGFloat) -> CGImage? {
        let scale = bounds.width / Self.stageSize.width
        let pxW = max(1, Int((CatPhysics.canvasSize.width * scale * backingScale).rounded()))
        let pxH = max(1, Int((CatPhysics.canvasSize.height * scale * backingScale).rounded()))
        guard let offCtx = CGContext(
            data: nil,
            width: pxW,
            height: pxH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: Self.fgColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        offCtx.translateBy(x: 0, y: CGFloat(pxH))
        offCtx.scaleBy(x: CGFloat(pxW) / CatPhysics.canvasSize.width,
                       y: -CGFloat(pxH) / CatPhysics.canvasSize.height)
        CatRenderer.drawForeground(in: offCtx, physics: physics)
        return offCtx.makeImage()
    }

    func poseNeedsDisplay() -> Bool {
        if physics.isHandoverActive || physics.isDictationListening || CatSettings.shared.visualStyle == .clackOriginal {
            return true
        }
        guard let previous = lastDrawnPose else { return true }
        let settings = CatSettings.shared
        let status = InputEngine.shared.status
        let showPill = status.needsAttention && !AXIsProcessTrusted()
        let current = RenderedPose(
            physics: physics,
            settings: settings,
            skin: settings.activeSkin,
            size: bounds.size,
            showPermissionPill: showPill,
            permissionPillText: status.permissionPillText,
            toastActive: toastActive,
            toastProgress: toastProgress,
            nameBubbleActive: nameBubbleActive,
            nameBubbleProgress: nameBubbleProgress,
            nameBubbleBobBucket: nameBubbleActive ? Int((nameBubblePhase * 24.0).rounded()) : 0
        )
        return current.visiblyDiffers(from: previous)
    }

    /// Returns point in KuroCat's inner `360 x 320` space (can be `< 0` or `> 360` when inside the left/right handover runway).
    func canvasPoint(fromScreenPoint screenPt: CGPoint) -> CGPoint? {
        guard let win = window else { return nil }
        let frame = win.frame
        guard frame.contains(screenPt) else { return nil }
        let stageX = (screenPt.x - frame.minX) / frame.width * Self.stageSize.width
        let stageY = (frame.maxY - screenPt.y) / frame.height * Self.stageSize.height
        return CGPoint(x: stageX - Self.stagePadX, y: stageY - Self.contentTopInset)
    }

    func clackInternalStagePoint(fromScreenPoint screenPt: CGPoint) -> CGPoint? {
        guard let win = window else { return nil }
        let frame = win.frame
        guard frame.contains(screenPt) else { return nil }
        var stageX = (screenPt.x - frame.minX) / frame.width * Self.stageSize.width
        let stageY = (frame.maxY - screenPt.y) / frame.height * Self.stageSize.height
        if CatSettings.shared.flipHorizontal {
            stageX = Self.stageSize.width - stageX
        }
        return ClackStageConst.overlayPointToInternal(CGPoint(x: stageX, y: stageY))
    }

    func updateHoverAndClickThrough() {
        guard let win = window else { return }
        let settings = CatSettings.shared
        if forceClickThroughForModal || (settings.obsCaptureMode > 0 && settings.obsHideDesktop) {
            if !win.ignoresMouseEvents { win.ignoresMouseEvents = true }
            physics.clackHoverStagePoint = nil
            setCursorIfNeeded(.arrow)
            return
        }
        if isDraggingOrResizing {
            if win.ignoresMouseEvents { win.ignoresMouseEvents = false }
            if isDragging { syncDraggedWindowPosition(win: win) }
            return
        }

        let screenPt = NSEvent.mouseLocation
        guard let pt = canvasPoint(fromScreenPoint: screenPt) else {
            if lastHoverWasInside || lastHoverCanvasPt != nil {
                lastHoverWasInside = false
                lastHoverCanvasPt = nil
                physics.updateTailHover(canvasPoint: nil)
                physics.clackHoverStagePoint = nil
            }
            if !win.ignoresMouseEvents { win.ignoresMouseEvents = true }
            setCursorIfNeeded(.arrow)
            return
        }
        lastHoverWasInside = true
        let clackPt = clackInternalStagePoint(fromScreenPoint: screenPt)
        physics.clackHoverStagePoint = clackPt

        if settings.isEditMode {
            let editHit = CatRenderer.hitTestEditOverlay(point: pt)
            let shouldIgnore = (editHit < 0)
            if win.ignoresMouseEvents != shouldIgnore {
                win.ignoresMouseEvents = shouldIgnore
            }
            if editHit == 20 { setCursorIfNeeded(.pointingHand) }
            else if editHit >= 0 && editHit <= 3 { setCursorIfNeeded(.crosshair) }
            else if editHit == 12 { setCursorIfNeeded(.openHand) }
            else { setCursorIfNeeded(.arrow) }
            return
        }

        let showPill = InputEngine.shared.status.needsAttention && !AXIsProcessTrusted()

        if settings.visualStyle == .clackOriginal || physics.isHandoverActive {
            let catPt = CatRenderer.canvasPointToCatSpace(pt, flipped: settings.flipHorizontal, rotationDeg: settings.rotationDeg)
            let pillZone = showPill ? CatRenderer.hitTest(point: catPt, physics: physics, showPermissionPill: true) : .none
            if pillZone == .permissionPill {
                if win.ignoresMouseEvents { win.ignoresMouseEvents = false }
                setCursorIfNeeded(.pointingHand)
                return
            }
            let hitClackCat = clackPt.map { physics.clackSim.hitTestDeskOrCat($0) } ?? false
            let optionHeld = NSEvent.modifierFlags.contains(.option)
            if settings.fullClickThrough && !optionHeld {
                if !win.ignoresMouseEvents { win.ignoresMouseEvents = true }
                setCursorIfNeeded(.arrow)
            } else {
                let shouldIgnore = !hitClackCat
                if win.ignoresMouseEvents != shouldIgnore {
                    win.ignoresMouseEvents = shouldIgnore
                }
                setCursorIfNeeded(hitClackCat ? .openHand : .arrow)
            }
            return
        }

        let catPt = CatRenderer.canvasPointToCatSpace(
            pt,
            flipped: settings.flipHorizontal,
            rotationDeg: settings.rotationDeg
        )
        let zone = CatRenderer.hitTest(point: catPt, physics: physics, showPermissionPill: showPill)
        physics.updateTailHover(canvasPoint: catPt)

        if zone == .head && settings.petInteraction && !physics.isHandoverActive {
            let skipPetForHunt = ((settings.activeSkin.renderStyle == .douni || settings.activeSkin.renderStyle == .beagle) && physics.huntIntensity.value > 0.20)
            if !skipPetForHunt, let prev = lastHoverCanvasPt {
                let delta = hypot(catPt.x - prev.x, catPt.y - prev.y)
                if delta > 1.2 && delta < 80 {
                    physics.registerPetStroke(canvasPoint: catPt, delta: delta, isHead: true)
                    onUserInteraction?()
                }
            }
            lastHoverCanvasPt = catPt
        } else {
            lastHoverCanvasPt = nil
        }

        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if settings.fullClickThrough && !optionHeld {
            let shouldIgnore = (zone != .permissionPill)
            if win.ignoresMouseEvents != shouldIgnore {
                win.ignoresMouseEvents = shouldIgnore
            }
            setCursorIfNeeded(.arrow)
        } else {
            let shouldIgnore = (zone == .none)
            if win.ignoresMouseEvents != shouldIgnore {
                win.ignoresMouseEvents = shouldIgnore
            }
            if zone == .head || zone == .body {
                setCursorIfNeeded(.openHand)
            } else if zone == .permissionPill {
                setCursorIfNeeded(.pointingHand)
            } else {
                setCursorIfNeeded(.arrow)
            }
        }
    }

    private func setCursorIfNeeded(_ target: ActiveCursor) {
        guard activeCursor != target else { return }
        activeCursor = target
        switch target {
        case .arrow: NSCursor.arrow.set()
        case .openHand: NSCursor.openHand.set()
        case .pointingHand: NSCursor.pointingHand.set()
        case .crosshair: NSCursor.crosshair.set()
        case .closedHand: NSCursor.closedHand.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onUserInteraction?()
        pendingDoubleClickToggle = false
        guard let win = window else { return }
        let screenPt = NSEvent.mouseLocation
        let settings = CatSettings.shared
        let showPill = InputEngine.shared.status.needsAttention && !AXIsProcessTrusted()

        if let pt = canvasPoint(fromScreenPoint: screenPt) {
            if settings.isEditMode {
                let hit = CatRenderer.hitTestEditOverlay(point: pt)
                if hit == 20 {
                    if event.clickCount == 2 {
                        settings.rotationDeg = 0
                        onUserInteraction?()
                        needsDisplay = true
                        return
                    }
                    isRotating = true
                    rotateDragged = false
                    rotateStartDeg = settings.rotationDeg
                    let center = CGPoint(x: win.frame.midX, y: win.frame.midY)
                    rotateStartMouseAngle = atan2(-(screenPt.y - center.y), screenPt.x - center.x)
                    setCursorIfNeeded(.closedHand)
                    return
                }
                if hit >= 0 && hit <= 3 {
                    activeResizeCorner = hit
                    resizeStartFrame = win.frame
                    let f = win.frame
                    switch hit {
                    case 0: resizeAnchorScreenPt = CGPoint(x: f.maxX, y: f.minY)
                    case 1: resizeAnchorScreenPt = CGPoint(x: f.minX, y: f.minY)
                    case 2: resizeAnchorScreenPt = CGPoint(x: f.maxX, y: f.maxY)
                    default: resizeAnchorScreenPt = CGPoint(x: f.minX, y: f.maxY)
                    }
                    return
                }
                if hit < 0 {
                    settings.isEditMode = false
                    needsDisplay = true
                    return
                }
            }

            let catPt = CatRenderer.canvasPointToCatSpace(
                pt,
                flipped: settings.flipHorizontal,
                rotationDeg: settings.rotationDeg
            )
            let zone = CatRenderer.hitTest(point: catPt, physics: physics, showPermissionPill: showPill)
            if zone == .permissionPill {
                onRequestPermission?()
                return
            }

            let clackHit = (settings.visualStyle == .clackOriginal)
                && (clackInternalStagePoint(fromScreenPoint: screenPt).map { physics.clackSim.hitTestCat($0) } ?? false)
            if event.clickCount == 2 && (zone == .head || zone == .body || clackHit || settings.isEditMode) {
                pendingDoubleClickToggle = true
                doubleClickDownScreenPt = screenPt
                dragStartScreenPt = screenPt
                dragStartWindowOrigin = win.frame.origin
                return
            }
        }

        isDragging = true
        dragStartScreenPt = screenPt
        lastDragScreenPt = screenPt
        dragStartWindowOrigin = win.frame.origin
        dragScruffAnchorDelta = computeScruffAnchorDelta(window: win, cursorScreenPt: screenPt)
        if settings.visualStyle == .kuroSticker && !physics.isHandoverActive {
            physics.setDragging(true, dragDx: 0)
        }
        setCursorIfNeeded(.closedHand)
    }

    private func computeScruffAnchorDelta(window win: NSWindow, cursorScreenPt screenPt: CGPoint) -> CGPoint {
        let s = CatSettings.shared
        guard s.enableDragAnimation, s.visualStyle == .kuroSticker, !physics.isHandoverActive else { return .zero }
        let pinchCanvas = CatRenderer.scruffPinchCanvasPoint(skin: s.activeSkin, flipped: s.flipHorizontal, rotationDeg: s.rotationDeg)
        let scale = win.frame.width / Self.stageSize.width
        let pinchOffsetX = (pinchCanvas.x + Self.stagePadX) * scale
        let pinchOffsetY = win.frame.height - (pinchCanvas.y + Self.contentTopInset) * scale
        return CGPoint(
            x: (screenPt.x - pinchOffsetX) - win.frame.origin.x,
            y: (screenPt.y - pinchOffsetY) - win.frame.origin.y
        )
    }

    private func syncDraggedWindowPosition(win: NSWindow) {
        let currentScreenPt = NSEvent.mouseLocation
        let t = max(0, min(1, physics.scruffDrag.value))
        let ease = t * t * (3.0 - 2.0 * t)
        let newOrigin = CGPoint(
            x: dragStartWindowOrigin.x + (currentScreenPt.x - dragStartScreenPt.x) + dragScruffAnchorDelta.x * ease,
            y: dragStartWindowOrigin.y + (currentScreenPt.y - dragStartScreenPt.y) + dragScruffAnchorDelta.y * ease
        )
        win.setFrameOrigin(newOrigin)
    }

    override func mouseDragged(with event: NSEvent) {
        onUserInteraction?()
        guard let win = window else { return }
        let currentScreenPt = NSEvent.mouseLocation
        let settings = CatSettings.shared
        if pendingDoubleClickToggle {
            if hypot(currentScreenPt.x - doubleClickDownScreenPt.x, currentScreenPt.y - doubleClickDownScreenPt.y) >= 4.0 {
                pendingDoubleClickToggle = false
                isDragging = true
                lastDragScreenPt = currentScreenPt
                dragScruffAnchorDelta = computeScruffAnchorDelta(window: win, cursorScreenPt: dragStartScreenPt)
                if settings.visualStyle == .kuroSticker && !physics.isHandoverActive {
                    physics.setDragging(true, dragDx: 0)
                }
                setCursorIfNeeded(.closedHand)
            } else {
                return
            }
        }
        if isRotating {
            let center = CGPoint(x: win.frame.midX, y: win.frame.midY)
            let curAngle = atan2(-(currentScreenPt.y - center.y), currentScreenPt.x - center.x)
            var deltaDeg = (curAngle - rotateStartMouseAngle) * 180.0 / .pi
            while deltaDeg > 180 { deltaDeg -= 360 }
            while deltaDeg < -180 { deltaDeg += 360 }
            if abs(deltaDeg) > 2.0 { rotateDragged = true }
            var deg = rotateStartDeg + deltaDeg
            while deg > 180 { deg -= 360 }
            while deg < -180 { deg += 360 }
            for snap in [-180.0, -90.0, 0.0, 90.0, 180.0] as [CGFloat] {
                if abs(deg - snap) < 5.0 { deg = (snap == -180.0) ? 180.0 : snap; break }
            }
            settings.rotationDeg = deg
            onUserInteraction?()
            needsDisplay = true
            return
        }
        if activeResizeCorner >= 0 {
            let dx = abs(currentScreenPt.x - resizeAnchorScreenPt.x)
            let dy = abs(currentScreenPt.y - resizeAnchorScreenPt.y)
            let sx = dx / Self.stageSize.width
            let sy = dy / Self.stageSize.height
            let newScale = max(0.45, min(2.20, max(sx, sy)))
            let newW = Self.stageSize.width * newScale
            let newH = Self.stageSize.height * newScale
            let originX = (activeResizeCorner == 0 || activeResizeCorner == 2)
                ? (resizeAnchorScreenPt.x - newW)
                : resizeAnchorScreenPt.x
            let originY = (activeResizeCorner == 2 || activeResizeCorner == 3)
                ? (resizeAnchorScreenPt.y - newH)
                : resizeAnchorScreenPt.y
            settings.scale = newScale
            win.setFrame(CGRect(x: originX, y: originY, width: newW, height: newH), display: true)
            onScaleChanged?(newScale)
            needsDisplay = true
            return
        }
        guard isDragging else { return }
        let rawDx = currentScreenPt.x - lastDragScreenPt.x
        let rawDy = -(currentScreenPt.y - lastDragScreenPt.y)
        lastDragScreenPt = currentScreenPt
        if settings.visualStyle == .kuroSticker && !physics.isHandoverActive {
            let rad = -settings.rotationDeg * .pi / 180.0
            let localDx = rawDx * cos(rad) - rawDy * sin(rad)
            let localDy = rawDx * sin(rad) + rawDy * cos(rad)
            physics.setDragging(true, dragDx: settings.flipHorizontal ? -localDx : localDx, dragDy: localDy)
        }
        syncDraggedWindowPosition(win: win)
    }

    override func mouseUp(with event: NSEvent) {
        onUserInteraction?()
        guard let win = window else { return }
        if pendingDoubleClickToggle {
            pendingDoubleClickToggle = false
            CatSettings.shared.isEditMode.toggle()
            needsDisplay = true
            return
        }
        if isRotating {
            isRotating = false
            if !rotateDragged {
                CatSettings.shared.flipHorizontal.toggle()
                onUserInteraction?()
            }
            setCursorIfNeeded(.pointingHand)
            needsDisplay = true
            return
        }
        if activeResizeCorner >= 0 {
            activeResizeCorner = -1
            UserDefaults.standard.set(Double(win.frame.origin.x), forKey: "TypeZero.Pet.PosX")
            UserDefaults.standard.set(Double(win.frame.origin.y), forKey: "TypeZero.Pet.PosY")
            return
        }
        guard isDragging else { return }
        isDragging = false
        dragScruffAnchorDelta = .zero
        physics.setDragging(false)
        setCursorIfNeeded(.openHand)
        UserDefaults.standard.set(Double(win.frame.origin.x), forKey: "TypeZero.Pet.PosX")
        UserDefaults.standard.set(Double(win.frame.origin.y), forKey: "TypeZero.Pet.PosY")
    }

    override func rightMouseDown(with event: NSEvent) {
        onUserInteraction?()
        onRightClickMenu?(event)
    }

    override func scrollWheel(with event: NSEvent) {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if CatSettings.shared.fullClickThrough && !optionHeld { return }
        if event.momentumPhase != [] { return }
        let raw = event.scrollingDeltaY
        guard abs(raw) > 0.01 else { return }
        let delta: CGFloat = event.hasPreciseScrollingDeltas
            ? max(-0.18, min(0.18, raw * 0.0045))
            : max(-0.20, min(0.20, raw * 0.06))
        guard abs(delta) > 0.0005 else { return }
        onUserInteraction?()
        let newScale = max(0.45, min(2.20, CatSettings.shared.scale * (1.0 + delta)))
        (window as? PetOverlayWindow)?.applyScale(newScale)
        onScaleChanged?(newScale)
    }

    override func magnify(with event: NSEvent) {
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if CatSettings.shared.fullClickThrough && !optionHeld { return }
        onUserInteraction?()
        let factor = max(0.5, min(1.5, 1.0 + event.magnification))
        let newScale = max(0.45, min(2.20, CatSettings.shared.scale * factor))
        (window as? PetOverlayWindow)?.applyScale(newScale)
        onScaleChanged?(newScale)
    }

    // MARK: Drag & drop of .kurocat & .kurokb / .json skins onto the cat

    private static let photoExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "bmp", "tiff"]

    private static func droppedSkinURLs(from sender: NSDraggingInfo) -> [URL] {
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        return urls.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "kurocat" || ext == "kurokb" || ext == "json" || photoExtensions.contains(ext)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        registerForDraggedTypes([.fileURL])
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        cachedForegroundImage = nil
        cachedForegroundPose = nil
        needsDisplay = true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Self.droppedSkinURLs(from: sender).isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = Self.droppedSkinURLs(from: sender)
        guard !urls.isEmpty else { return false }
        let photoURLs = urls.filter { Self.photoExtensions.contains($0.pathExtension.lowercased()) }
        if !photoURLs.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.onDropPhotoURLs?(Array(photoURLs.prefix(PhotoCatAnalyzer.maxPhotoCount))) }
            return true
        }
        DispatchQueue.main.async { [weak self] in self?.onDropSkinFiles?(urls) }
        return true
    }

    // MARK: - Toast Pill

    func showToast(text: String) {
        toastText = text
        toastPhase = 0
        toastProgress = 0
        onUserInteraction?()
        needsDisplay = true
    }

    @discardableResult
    func tickToast(dt: CGFloat) -> Bool {
        guard toastActive else { return false }
        toastPhase += Double(dt)
        if toastPhase < toastFadeIn {
            toastProgress = CGFloat(toastPhase / toastFadeIn)
        } else if toastPhase < toastFadeIn + toastHold {
            toastProgress = 1.0
        } else if toastPhase < toastFadeIn + toastHold + toastFadeOut {
            let fadeOutElapsed = toastPhase - (toastFadeIn + toastHold)
            toastProgress = CGFloat(1.0 - fadeOutElapsed / toastFadeOut)
        } else {
            toastText = nil
            toastProgress = 0
            toastPhase = 0
            return false
        }
        return true
    }

    // MARK: - Subtle Head-Tracking Cat Name Bubble ("偶尔出现在脑袋上")

    func showNameBubble(name: String, mood: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let resolvedMood: String = {
            if let m = mood, !m.isEmpty { return m }
            let isAsleep = CatSettings.shared.visualStyle == .clackOriginal
                ? physics.clackSim.pose.sleeping
                : (physics.sleepiness >= 0.85)
            if isAsleep { return "💤" }
            if physics.isMusicPlaying { return "🎵" }
            if physics.petHeadIntensity > 0.35 { return "💛" }
            return "🐾"
        }()
        nameBubbleText = trimmed
        nameBubbleMood = resolvedMood
        nameBubblePhase = 0
        nameBubbleProgress = 0
        needsDisplay = true
    }

    @discardableResult
    func tickNameBubble(dt: CGFloat) -> Bool {
        if physics.petHeadIntensity > 0.68 {
            let now = CACurrentMediaTime()
            if now - lastPetMilestoneTime > 55.0 {
                lastPetMilestoneTime = now
                onHeadPetMilestone?()
            }
        }
        guard nameBubbleActive else { return false }
        nameBubblePhase += Double(dt)
        if nameBubblePhase < nameBubbleFadeIn {
            let t = CGFloat(nameBubblePhase / nameBubbleFadeIn)
            nameBubbleProgress = 1.0 - pow(1.0 - t, 3.0)
        } else if nameBubblePhase < nameBubbleFadeIn + nameBubbleHold {
            nameBubbleProgress = 1.0
        } else if nameBubblePhase < nameBubbleFadeIn + nameBubbleHold + nameBubbleFadeOut {
            let elapsed = nameBubblePhase - (nameBubbleFadeIn + nameBubbleHold)
            let t = CGFloat(elapsed / nameBubbleFadeOut)
            nameBubbleProgress = max(0, 1.0 - t * t)
        } else {
            nameBubbleText = nil
            nameBubbleMood = ""
            nameBubbleProgress = 0
            nameBubblePhase = 0
            return false
        }
        return true
    }

    private func drawFloatingCatName(in ctx: CGContext, name: String, mood: String, alpha: CGFloat, phase: CGFloat) {
        let skin = CatSettings.shared.activeSkin
        let isClack = (CatSettings.shared.visualStyle == .clackOriginal)
        let headCenter: CGPoint = isClack
            ? CGPoint(x: 180 + physics.clackSim.pose.headLean.x * 0.78, y: 78 + physics.clackSim.pose.headLean.y * 0.78)
            : CatRenderer.headPosition(physics, skin: skin)
        let headTopY = headCenter.y - (isClack ? 36.0 : (38.0 * skin.shape.headScale))
        let accent: NSColor = {
            if let iris = skin.palette.irisLeft ?? skin.palette.iris {
                return NSColor(srgbRed: iris.r, green: iris.g, blue: iris.b, alpha: 1.0)
            }
            return CatSettings.shared.eyeTheme.primaryColor
        }()
        Self.drawCatNameBadgeStatic(
            in: ctx,
            headCenterX: headCenter.x,
            headTopY: headTopY,
            minX: -Self.stagePadX + 10,
            maxX: CatPhysics.canvasSize.width + Self.stagePadX - 10,
            minY: -Self.contentTopInset + 6,
            name: name,
            mood: mood,
            accentColor: accent,
            alpha: alpha,
            phase: phase
        )
    }

    static func drawCatNameBadgeStatic(
        in ctx: CGContext,
        headCenterX: CGFloat,
        headTopY: CGFloat,
        minX: CGFloat,
        maxX: CGFloat,
        minY: CGFloat,
        name: String,
        mood: String,
        accentColor: NSColor,
        alpha: CGFloat,
        phase: CGFloat
    ) {
        guard alpha > 0.01 else { return }
        let font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        let moodTag: String = {
            if mood == "💤" { return " zZ" }
            if mood == "🎵" { return " ♪" }
            return ""
        }()
        let displayStr = name + moodTag
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.98, alpha: 1.0)
        ]
        let attrStr = NSAttributedString(string: displayStr, attributes: attrs)
        let sz = attrStr.size()

        let iconW: CGFloat = 11.0
        let iconGap: CGFloat = 6.0
        let padX: CGFloat = 11.5
        let padY: CGFloat = 5.0
        let pillW = padX * 2 + iconW + iconGap + sz.width
        let pillH = max(23.0, sz.height + padY * 2)

        let bobY = sin(phase * 2.5) * 2.4
        let popLift = (1.0 - alpha) * 4.5
        let pillX = max(minX, min(maxX - pillW, headCenterX - pillW * 0.5))
        let pillY = max(minY, headTopY - pillH - 28.0 + bobY + popLift)
        let rect = CGRect(x: pillX, y: pillY, width: pillW, height: pillH)
        let radius = pillH * 0.5
        let pointerX = max(rect.minX + radius + 3, min(rect.maxX - radius - 3, headCenterX))

        ctx.saveGState()
        let scalePop: CGFloat = 0.90 + 0.10 * alpha
        if abs(scalePop - 1.0) > 0.002 {
            let anchor = CGPoint(x: pointerX, y: rect.maxY + 4.0)
            ctx.translateBy(x: anchor.x, y: anchor.y)
            ctx.scaleBy(x: scalePop, y: scalePop)
            ctx.translateBy(x: -anchor.x, y: -anchor.y)
        }

        ctx.setAlpha(max(0, min(1, alpha)))
        ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 7.0, color: NSColor.black.withAlphaComponent(0.28).cgColor)

        let bubble = CGMutablePath()
        bubble.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
        bubble.move(to: CGPoint(x: pointerX - 4.0, y: rect.maxY - 0.8))
        bubble.addQuadCurve(
            to: CGPoint(x: pointerX + 4.0, y: rect.maxY - 0.8),
            control: CGPoint(x: pointerX, y: rect.maxY + 4.8)
        )
        bubble.closeSubpath()

        ctx.setFillColor(NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.15, alpha: 0.90).cgColor)
        ctx.addPath(bubble)
        ctx.fillPath()

        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.34).cgColor)
        ctx.setLineWidth(1.0)
        let inner = rect.insetBy(dx: 0.5, dy: 0.5)
        ctx.addPath(CGPath(roundedRect: inner, cornerWidth: radius - 0.5, cornerHeight: radius - 0.5, transform: nil))
        ctx.strokePath()

        let pawCX = rect.minX + padX + iconW * 0.5
        let pawCY = rect.midY + 1.4
        ctx.setFillColor(accentColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: pawCX - 3.3, y: pawCY - 2.2, width: 6.6, height: 4.8))
        for (tx, ty) in [(-3.6, -4.2), (0.0, -5.2), (3.6, -4.2)] as [(CGFloat, CGFloat)] {
            ctx.fillEllipse(in: CGRect(x: pawCX + tx - 1.45, y: pawCY + ty - 1.55, width: 2.9, height: 3.1))
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        let textX = rect.minX + padX + iconW + iconGap
        let textY = rect.midY - sz.height * 0.5
        attrStr.draw(at: CGPoint(x: textX, y: textY))
        NSGraphicsContext.restoreGraphicsState()

        ctx.restoreGState()
    }

    private func drawToastPill(in ctx: CGContext, text: String, alpha: CGFloat) {
        guard alpha > 0.01 else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let sz = attrStr.size()

        let padX: CGFloat = 16
        let padY: CGFloat = 9
        let pillW = sz.width + padX * 2
        let pillH = sz.height + padY * 2

        let skin = CatSettings.shared.activeSkin
        let headCenter = CatSettings.shared.visualStyle == .clackOriginal
            ? CGPoint(x: 180 + physics.clackSim.pose.headLean.x, y: 78 + physics.clackSim.pose.headLean.y)
            : CatRenderer.headPosition(physics, skin: skin)
        let headTopY = headCenter.y - 38.0 * skin.shape.headScale

        let rect = CGRect(
            x: max(-Self.stagePadX + 12, min(CatPhysics.canvasSize.width + Self.stagePadX - pillW - 12, headCenter.x - pillW / 2)),
            y: max(-Self.contentTopInset + 8, headTopY - pillH - 22),
            width: pillW,
            height: pillH
        )
        let cornerRadius = rect.height / 2

        ctx.saveGState()
        ctx.setAlpha(max(0, min(1, alpha)))
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.35).cgColor)

        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 0.90).cgColor)
        ctx.addPath(path)
        ctx.fillPath()

        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(NSColor(calibratedWhite: 0.48, alpha: 0.50).cgColor)
        ctx.setLineWidth(1.0)
        let inner = rect.insetBy(dx: 0.5, dy: 0.5)
        ctx.addPath(CGPath(roundedRect: inner, cornerWidth: cornerRadius - 0.5, cornerHeight: cornerRadius - 0.5, transform: nil))
        ctx.strokePath()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        let textY = rect.midY - sz.height / 2
        attrStr.draw(at: CGPoint(x: rect.midX - sz.width / 2, y: textY))
        NSGraphicsContext.restoreGraphicsState()

        ctx.restoreGState()
    }
}

final class PetOverlayWindow: NSPanel {
    let catView = CatCanvasView()

    init() {
        let scale = CatSettings.shared.scale
        let size = CGSize(
            width: CatCanvasView.stageSize.width * scale,
            height: CatCanvasView.stageSize.height * scale
        )
        let origin = PetOverlayWindow.initialOrigin(for: size, scale: scale)

        super.init(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        title = "TypeZero Desktop Pet"
        sharingType = .readOnly

        applyWindowLevelAndBehavior()
        applyOBSMode()

        catView.frame = CGRect(origin: .zero, size: size)
        catView.autoresizingMask = [.width, .height]
        contentView = catView
    }

    func applyOBSMode() {
        let mode = CatSettings.shared.obsCaptureMode
        let hideDesktop = (mode > 0 && CatSettings.shared.obsHideDesktop)
        title = "TypeZero Desktop Pet"
        sharingType = .readOnly
        if mode == 2 {
            isOpaque = true
            backgroundColor = NSColor(calibratedRed: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        } else {
            isOpaque = false
            backgroundColor = .clear
        }
        if hideDesktop {
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            ignoresMouseEvents = true
        } else {
            applyWindowLevelAndBehavior()
        }
        catView.needsDisplay = true
    }

    func applyWindowLevelAndBehavior() {
        if CatSettings.shared.obsCaptureMode > 0 && CatSettings.shared.obsHideDesktop {
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            return
        }
        if CatSettings.shared.fullScreenOverlay {
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        } else {
            level = .floating
            collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        }
    }

    func applyScale(_ newScale: CGFloat) {
        CatSettings.shared.scale = newScale
        let oldFrame = frame
        let newSize = CGSize(
            width: CatCanvasView.stageSize.width * newScale,
            height: CatCanvasView.stageSize.height * newScale
        )
        let newOrigin = CGPoint(
            x: oldFrame.midX - newSize.width * 0.5,
            y: oldFrame.minY
        )
        setFrame(CGRect(origin: newOrigin, size: newSize), display: true)
        catView.needsDisplay = true
        UserDefaults.standard.set(Double(newOrigin.x), forKey: "TypeZero.Pet.PosX")
        UserDefaults.standard.set(Double(newOrigin.y), forKey: "TypeZero.Pet.PosY")
        UserDefaults.standard.set(true, forKey: "TypeZero.Pet.StagePosV2")
    }

    func resetPosition() {
        let scale = CatSettings.shared.scale
        let origin = PetOverlayWindow.defaultOrigin(for: frame.size, scale: scale)
        setFrameOrigin(origin)
        catView.needsDisplay = true
        UserDefaults.standard.set(Double(origin.x), forKey: "TypeZero.Pet.PosX")
        UserDefaults.standard.set(Double(origin.y), forKey: "TypeZero.Pet.PosY")
        UserDefaults.standard.set(true, forKey: "TypeZero.Pet.StagePosV2")
    }

    var physicsFrameInScreen: CGRect {
        let scale = frame.width / CatCanvasView.stageSize.width
        return CGRect(
            x: frame.minX + CatCanvasView.stagePadX * scale,
            y: frame.minY,
            width: CatPhysics.canvasSize.width * scale,
            height: CatPhysics.canvasSize.height * scale
        )
    }

    private static func initialOrigin(for size: CGSize, scale: CGFloat) -> CGPoint {
        let d = UserDefaults.standard
        if d.object(forKey: "TypeZero.Pet.PosX") != nil && d.object(forKey: "TypeZero.Pet.PosY") != nil {
            var saved = CGPoint(
                x: CGFloat(d.double(forKey: "TypeZero.Pet.PosX")),
                y: CGFloat(d.double(forKey: "TypeZero.Pet.PosY"))
            )
            // Migrate saved v1 (360-wide) origin once by shifting left by stagePadX * scale so the cat doesn't move!
            if !d.bool(forKey: "TypeZero.Pet.StagePosV2") {
                saved.x -= CatCanvasView.stagePadX * scale
                d.set(Double(saved.x), forKey: "TypeZero.Pet.PosX")
                d.set(true, forKey: "TypeZero.Pet.StagePosV2")
            }
            let innerRect = CGRect(
                x: saved.x + CatCanvasView.stagePadX * scale,
                y: saved.y,
                width: CatPhysics.canvasSize.width * scale,
                height: size.height
            )
            if NSScreen.screens.contains(where: { $0.frame.intersects(innerRect) }) {
                return saved
            }
        }
        return defaultOrigin(for: size, scale: scale)
    }

    private static func defaultOrigin(for size: CGSize, scale: CGFloat) -> CGPoint {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGPoint(
            x: screen.maxX - (CatPhysics.canvasSize.width + CatCanvasView.stagePadX) * scale - 24,
            y: screen.minY + 18
        )
    }
}
