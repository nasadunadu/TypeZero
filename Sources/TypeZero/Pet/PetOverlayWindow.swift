import Foundation
import AppKit

private struct RenderedPose {
    struct ForegroundAppearance: Equatable {
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
    let showPermissionPill: Bool
    let permissionPillText: String

    init(physics: CatPhysics, settings: CatSettings, skin: SkinSpec, size: CGSize,
         showPermissionPill: Bool, permissionPillText: String,
         toastActive: Bool = false, toastProgress: CGFloat = 0) {
        let coat = settings.coatTheme
        let tabletActive = physics.isTabletActive
        let kbTheme = settings.keyboardTheme
        let fgAppearance = ForegroundAppearance(
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
            handoverActive: physics.handover.isActive,
            dictationListening: physics.isDictationListening
        )
        appearance = Appearance(
            foreground: fgAppearance,
            keyboard: kbTheme,
            keyboardSkinId: settings.activeKeyboardSkin.id,
            showsLegends: settings.showKeyLegends,
            levelKeyboard: settings.levelKeyboard,
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
        hasEffects = physics.handover.isActive
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
        let scale = max(appearance.foreground.size.width / CatPhysics.canvasSize.width,
                        appearance.foreground.size.height / CatPhysics.canvasSize.height)
        return movement * scale >= 0.65
    }

    func visiblyDiffers(from previous: RenderedPose) -> Bool {
        if marqueeBucket != previous.marqueeBucket
            || appearance != previous.appearance
            || toastActive != previous.toastActive
            || abs(toastProgress - previous.toastProgress) > 0.004
            || showPermissionPill != previous.showPermissionPill
            || permissionPillText != previous.permissionPillText {
            return true
        }
        let scale = max(appearance.foreground.size.width / CatPhysics.canvasSize.width,
                        appearance.foreground.size.height / CatPhysics.canvasSize.height)
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

    static let contentTopInset: CGFloat = 64

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
        ctx.clear(bounds)

        let totalCanvasH = CatPhysics.canvasSize.height + CatCanvasView.contentTopInset
        let scaleX = bounds.width / CatPhysics.canvasSize.width
        let scaleY = bounds.height / totalCanvasH
        ctx.saveGState()
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.translateBy(x: 0, y: CatCanvasView.contentTopInset)

        let settings = CatSettings.shared
        let skin = settings.activeSkin
        let status = InputEngine.shared.status
        let showPill = status.needsAttention && !AXIsProcessTrusted()
        let pillText = status.permissionPillText
        let currentPose = RenderedPose(
            physics: physics,
            settings: settings,
            skin: skin,
            size: bounds.size,
            showPermissionPill: showPill,
            permissionPillText: pillText,
            toastActive: toastActive,
            toastProgress: toastProgress
        )

        if physics.sleepiness >= 0.95,
           !physics.handover.isActive,
           !physics.isDictationListening,
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
        }
        lastDrawnPose = currentPose
        ctx.restoreGState()
    }

    private func renderForegroundBitmap(backingScale: CGFloat) -> CGImage? {
        let scale = bounds.width / CatPhysics.canvasSize.width
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
        if physics.handover.isActive || physics.isDictationListening { return true }
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
            toastProgress: toastProgress
        )
        return current.visiblyDiffers(from: previous)
    }

    func canvasPoint(fromScreenPoint screenPt: CGPoint) -> CGPoint? {
        guard let win = window else { return nil }
        let frame = win.frame
        guard frame.contains(screenPt) else { return nil }
        let localX = (screenPt.x - frame.minX) / frame.width * CatPhysics.canvasSize.width
        let totalCanvasH = CatPhysics.canvasSize.height + CatCanvasView.contentTopInset
        let localY = (frame.maxY - screenPt.y) / frame.height * totalCanvasH - CatCanvasView.contentTopInset
        return CGPoint(x: localX, y: localY)
    }

    func updateHoverAndClickThrough() {
        guard let win = window else { return }
        if forceClickThroughForModal {
            if !win.ignoresMouseEvents { win.ignoresMouseEvents = true }
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
            }
            if !win.ignoresMouseEvents { win.ignoresMouseEvents = true }
            setCursorIfNeeded(.arrow)
            return
        }
        lastHoverWasInside = true

        if CatSettings.shared.isEditMode {
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

        let catPt = CatRenderer.canvasPointToCatSpace(
            pt,
            flipped: CatSettings.shared.flipHorizontal,
            rotationDeg: CatSettings.shared.rotationDeg
        )
        let showPill = InputEngine.shared.status.needsAttention && !AXIsProcessTrusted()
        let zone = CatRenderer.hitTest(point: catPt, physics: physics, showPermissionPill: showPill)
        physics.updateTailHover(canvasPoint: catPt)

        if zone == .head && CatSettings.shared.petInteraction && !physics.handover.isActive {
            let skipPetForHunt = ((CatSettings.shared.activeSkin.renderStyle == .douni || CatSettings.shared.activeSkin.renderStyle == .beagle) && physics.huntIntensity.value > 0.20)
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
        if CatSettings.shared.fullClickThrough && !optionHeld {
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
        let showPill = InputEngine.shared.status.needsAttention && !AXIsProcessTrusted()

        if let pt = canvasPoint(fromScreenPoint: screenPt) {
            if CatSettings.shared.isEditMode {
                let hit = CatRenderer.hitTestEditOverlay(point: pt)
                if hit == 20 {
                    if event.clickCount == 2 {
                        CatSettings.shared.rotationDeg = 0
                        needsDisplay = true
                        return
                    }
                    isRotating = true
                    rotateDragged = false
                    rotateStartDeg = CatSettings.shared.rotationDeg
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
                    CatSettings.shared.isEditMode = false
                    needsDisplay = true
                    return
                }
            }

            let catPt = CatRenderer.canvasPointToCatSpace(
                pt,
                flipped: CatSettings.shared.flipHorizontal,
                rotationDeg: CatSettings.shared.rotationDeg
            )
            let zone = CatRenderer.hitTest(point: catPt, physics: physics, showPermissionPill: showPill)
            if zone == .permissionPill {
                onRequestPermission?()
                return
            }

            if event.clickCount == 2 && (zone == .head || zone == .body || CatSettings.shared.isEditMode) {
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
        physics.setDragging(true, dragDx: 0)
        setCursorIfNeeded(.closedHand)
    }

    private func computeScruffAnchorDelta(window win: NSWindow, cursorScreenPt screenPt: CGPoint) -> CGPoint {
        let s = CatSettings.shared
        guard s.enableDragAnimation else { return .zero }
        let pinchCanvas = CatRenderer.scruffPinchCanvasPoint(skin: s.activeSkin, flipped: s.flipHorizontal, rotationDeg: s.rotationDeg)
        let scale = win.frame.width / CatPhysics.canvasSize.width
        let pinchOffsetX = pinchCanvas.x * scale
        let pinchOffsetY = win.frame.height - (pinchCanvas.y + CatCanvasView.contentTopInset) * scale
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
        if pendingDoubleClickToggle {
            if hypot(currentScreenPt.x - doubleClickDownScreenPt.x, currentScreenPt.y - doubleClickDownScreenPt.y) >= 4.0 {
                pendingDoubleClickToggle = false
                isDragging = true
                lastDragScreenPt = currentScreenPt
                dragScruffAnchorDelta = computeScruffAnchorDelta(window: win, cursorScreenPt: dragStartScreenPt)
                physics.setDragging(true, dragDx: 0)
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
            CatSettings.shared.rotationDeg = deg
            needsDisplay = true
            return
        }
        if activeResizeCorner >= 0 {
            let totalCanvasH = CatPhysics.canvasSize.height + CatCanvasView.contentTopInset
            let dx = abs(currentScreenPt.x - resizeAnchorScreenPt.x)
            let dy = abs(currentScreenPt.y - resizeAnchorScreenPt.y)
            let sx = dx / CatPhysics.canvasSize.width
            let sy = dy / totalCanvasH
            let newScale = max(0.45, min(2.20, max(sx, sy)))
            let newW = CatPhysics.canvasSize.width * newScale
            let newH = totalCanvasH * newScale
            let originX = (activeResizeCorner == 0 || activeResizeCorner == 2)
                ? (resizeAnchorScreenPt.x - newW)
                : resizeAnchorScreenPt.x
            let originY = (activeResizeCorner == 2 || activeResizeCorner == 3)
                ? (resizeAnchorScreenPt.y - newH)
                : resizeAnchorScreenPt.y
            CatSettings.shared.scale = newScale
            win.setFrame(CGRect(x: originX, y: originY, width: newW, height: newH), display: true)
            onScaleChanged?(newScale)
            needsDisplay = true
            return
        }
        guard isDragging else { return }
        let rawDx = currentScreenPt.x - lastDragScreenPt.x
        let rawDy = -(currentScreenPt.y - lastDragScreenPt.y)
        lastDragScreenPt = currentScreenPt
        let rad = -CatSettings.shared.rotationDeg * .pi / 180.0
        let localDx = rawDx * cos(rad) - rawDy * sin(rad)
        let localDy = rawDx * sin(rad) + rawDy * cos(rad)
        physics.setDragging(true, dragDx: CatSettings.shared.flipHorizontal ? -localDx : localDx, dragDy: localDy)
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

    // MARK: Drag & drop of .kurocat skins onto the cat

    private static func droppedSkinURLs(from sender: NSDraggingInfo) -> [URL] {
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        return urls.filter { $0.pathExtension.lowercased() == "kurocat" }
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
        let headCenter = CatRenderer.headPosition(physics, skin: skin)
        let headTopY = headCenter.y - 38.0 * skin.shape.headScale

        let rect = CGRect(
            x: max(8, min(CatPhysics.canvasSize.width - pillW - 8, headCenter.x - pillW / 2)),
            y: headTopY - pillH - 22,
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
            width: CatPhysics.canvasSize.width * scale,
            height: (CatPhysics.canvasSize.height + CatCanvasView.contentTopInset) * scale
        )
        let origin = PetOverlayWindow.initialOrigin(for: size)

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

        catView.frame = CGRect(origin: .zero, size: size)
        catView.autoresizingMask = [.width, .height]
        contentView = catView
    }

    func applyWindowLevelAndBehavior() {
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
            width: CatPhysics.canvasSize.width * newScale,
            height: (CatPhysics.canvasSize.height + CatCanvasView.contentTopInset) * newScale
        )
        let newOrigin = CGPoint(
            x: oldFrame.midX - newSize.width * 0.5,
            y: oldFrame.minY
        )
        setFrame(CGRect(origin: newOrigin, size: newSize), display: true)
        catView.needsDisplay = true
        UserDefaults.standard.set(Double(newOrigin.x), forKey: "TypeZero.Pet.PosX")
        UserDefaults.standard.set(Double(newOrigin.y), forKey: "TypeZero.Pet.PosY")
    }

    func resetPosition() {
        let origin = PetOverlayWindow.defaultOrigin(for: frame.size)
        setFrameOrigin(origin)
        catView.needsDisplay = true
        UserDefaults.standard.set(Double(origin.x), forKey: "TypeZero.Pet.PosX")
        UserDefaults.standard.set(Double(origin.y), forKey: "TypeZero.Pet.PosY")
    }

    var physicsFrameInScreen: CGRect {
        let scale = frame.width / CatPhysics.canvasSize.width
        var f = frame
        f.size.height -= CatCanvasView.contentTopInset * scale
        return f
    }

    private static func initialOrigin(for size: CGSize) -> CGPoint {
        let d = UserDefaults.standard
        if d.object(forKey: "TypeZero.Pet.PosX") != nil && d.object(forKey: "TypeZero.Pet.PosY") != nil {
            let saved = CGPoint(
                x: CGFloat(d.double(forKey: "TypeZero.Pet.PosX")),
                y: CGFloat(d.double(forKey: "TypeZero.Pet.PosY"))
            )
            let rect = CGRect(origin: saved, size: size)
            if NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) {
                return saved
            }
        }
        return defaultOrigin(for: size)
    }

    private static func defaultOrigin(for size: CGSize) -> CGPoint {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return CGPoint(
            x: screen.maxX - size.width - 24,
            y: screen.minY + 18
        )
    }
}
