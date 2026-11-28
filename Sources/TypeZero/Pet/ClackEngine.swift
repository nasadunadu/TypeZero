import Foundation
import CoreGraphics
import QuartzCore

// MARK: - 1:1 Port of Chingyim/Clack-Clack Stage Math, 3D Keyboard, Pose Physics & 10.58s Shift Handover

enum ClackStageConst {
    static let width: CGFloat = 564
    static let height: CGFloat = 480
    static let anchorX: CGFloat = 230
    static let anchorY: CGFloat = 405
    static let baseScale: CGFloat = 0.84

    // Window-aligned Clack stage anchor inside TypeZero's 564x388 overlay so cat center matches KuroCat (286, 318)
    static let overlayAnchorX: CGFloat = 282
    static let overlayAnchorY: CGFloat = 368
    static let overlayBaseScale: CGFloat = 0.80

    static let kbRect = CGRect(x: 118, y: 331, width: 276, height: 72)
    static let kbBaseZ: CGFloat = 8
    static let capTopZ: CGFloat = 11.8
    static let kbCenterX: CGFloat = kbRect.minX + kbRect.width * 0.5 // 256
    static let kbFrontY: CGFloat = kbRect.minY + kbRect.height       // 403
    static let perspDist: CGFloat = 520
    static let tiltScaleY: CGFloat = 0.68
    static let projBaseY: CGFloat = 340

    static let mouseRest = CGPoint(x: 96, y: 344)
    static let mouseBounds = (left: CGFloat(73), right: CGFloat(106), top: CGFloat(329), bottom: CGFloat(361))
    static let pawRestLeft = CGPoint(x: 209, y: 322)
    static let pawRestRight = CGPoint(x: 250, y: 323)

    static func projectDeck(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat = 0) -> CGPoint {
        let s = perspDist / (perspDist + kbFrontY - y)
        let dx = (x - kbCenterX) * s
        return CGPoint(
            x: kbCenterX + dx,
            y: projBaseY + (y - kbRect.minY) * tiltScaleY * s - z * s
        )
    }

    static func unprojectDeck(_ pt: CGPoint) -> CGPoint {
        let dy = pt.y - projBaseY
        let ny = kbRect.minY + dy * (perspDist + kbRect.height) / (perspDist * tiltScaleY + dy)
        let nx = kbCenterX + (pt.x - kbCenterX) * (perspDist + kbFrontY - ny) / perspDist
        return CGPoint(x: nx, y: ny)
    }

    static func deckQuad(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ z: CGFloat) -> [CGPoint] {
        [
            projectDeck(x, y, z),
            projectDeck(x + w, y, z),
            projectDeck(x + w, y + h, z),
            projectDeck(x, y + h, z)
        ]
    }

    static func screenToStage(_ pt: CGPoint, scale: CGFloat) -> CGPoint {
        let s = scale * baseScale
        return CGPoint(
            x: (pt.x - anchorX) / s + anchorX,
            y: (pt.y - anchorY) / s + anchorY
        )
    }

    /// Maps a point in `CatCanvasView`'s 564x388 overlay coordinates into Clack's 564x480 internal stage coordinates.
    static func overlayPointToInternal(_ overlayPt: CGPoint) -> CGPoint {
        CGPoint(
            x: (overlayPt.x - overlayAnchorX) / overlayBaseScale + 230.0,
            y: (overlayPt.y - overlayAnchorY) / overlayBaseScale + 405.0
        )
    }
}

// MARK: - 3D Mechanical Keyboard Key Definitions

struct ClackKeyDef {
    let code: String
    let label: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isLeftPawSide: Bool
}

enum ClackKeyboardMap {
    static let keys: [ClackKeyDef] = {
        let rows: [[(String, String, CGFloat)]] = [
            [
                ("Escape", "esc", 1), ("Digit1", "1", 1), ("Digit2", "2", 1), ("Digit3", "3", 1),
                ("Digit4", "4", 1), ("Digit5", "5", 1), ("Digit6", "6", 1), ("Digit7", "7", 1),
                ("Digit8", "8", 1), ("Digit9", "9", 1), ("Digit0", "0", 1), ("Minus", "−", 1),
                ("Equal", "+", 1), ("Backspace", "⌫", 1.8)
            ],
            [
                ("Tab", "⇥", 1.35), ("KeyQ", "Q", 1), ("KeyW", "W", 1), ("KeyE", "E", 1),
                ("KeyR", "R", 1), ("KeyT", "T", 1), ("KeyY", "Y", 1), ("KeyU", "U", 1),
                ("KeyI", "I", 1), ("KeyO", "O", 1), ("KeyP", "P", 1), ("BracketLeft", "[", 1),
                ("BracketRight", "]", 1), ("Backslash", "\\", 1.45)
            ],
            [
                ("CapsLock", "⇪", 1.7), ("KeyA", "A", 1), ("KeyS", "S", 1), ("KeyD", "D", 1),
                ("KeyF", "F", 1), ("KeyG", "G", 1), ("KeyH", "H", 1), ("KeyJ", "J", 1),
                ("KeyK", "K", 1), ("KeyL", "L", 1), ("Semicolon", ";", 1), ("Quote", "'", 1),
                ("Enter", "↵", 2.1)
            ],
            [
                ("ShiftLeft", "⇧", 2.15), ("KeyZ", "Z", 1), ("KeyX", "X", 1), ("KeyC", "C", 1),
                ("KeyV", "V", 1), ("KeyB", "B", 1), ("KeyN", "N", 1), ("KeyM", "M", 1),
                ("Comma", ",", 1), ("Period", ".", 1), ("Slash", "/", 1), ("ShiftRight", "⇧", 2.65)
            ],
            [
                ("ControlLeft", "ctrl", 1.35), ("AltLeft", "⌥", 1.2), ("MetaLeft", "⌘", 1.35),
                ("Space", "", 5.5), ("MetaRight", "⌘", 1.3), ("AltRight", "⌥", 1.2),
                ("ControlRight", "ctrl", 1), ("ArrowLeft", "←", 1), ("ArrowDown", "↓", 1), ("ArrowRight", "→", 1)
            ]
        ]
        let kb = ClackStageConst.kbRect
        var out: [ClackKeyDef] = []
        for (rowIdx, row) in rows.enumerated() {
            let totalUnits = row.reduce(CGFloat(0)) { $0 + $1.2 }
            let unitW = (kb.width - 12.0) / totalUnits
            var cursor: CGFloat = 0
            for (code, label, u) in row {
                let w = u * unitW - 2.0
                let x = kb.minX + kb.width - 6.0 - cursor * unitW - w
                let y = kb.minY + kb.height - 6.0 - CGFloat(rowIdx) * 12.0 - 10.0
                let isLeftSide = !((cursor + u * 0.5) < (totalUnits * 0.5))
                cursor += u
                if code == "ArrowDown" {
                    out.append(ClackKeyDef(code: "ArrowDown", label: "↓", x: x, y: y, width: w, height: 4.5, isLeftPawSide: isLeftSide))
                    out.append(ClackKeyDef(code: "ArrowUp", label: "↑", x: x, y: y + 5.5, width: w, height: 4.5, isLeftPawSide: isLeftSide))
                } else {
                    out.append(ClackKeyDef(code: code, label: label, x: x, y: y, width: w, height: 10.0, isLeftPawSide: isLeftSide))
                }
            }
        }
        return out
    }()

    static let byCode: [String: ClackKeyDef] = {
        var d: [String: ClackKeyDef] = [:]
        for k in keys { d[k.code] = k }
        return d
    }()

    static func targetPoint(for code: String) -> (pt: CGPoint, isLeft: Bool)? {
        guard let k = byCode[code] else { return nil }
        let p = ClackStageConst.projectDeck(k.x + k.width * 0.5, k.y + k.height * 0.5, ClackStageConst.capTopZ)
        return (p, k.isLeftPawSide)
    }

    static func bubbleText(for code: String) -> String {
        if code == "Space" { return "空格" }
        switch code {
        case "MouseLeft": return "左键"
        case "MouseRight": return "右键"
        case "MouseMiddle": return "中键"
        case "WheelUp": return "↑ 滚动"
        case "WheelDown": return "↓ 滚动"
        default:
            if let k = byCode[code], !k.label.isEmpty {
                return k.label
            }
            return code
                .replacingOccurrences(of: "Key", with: "")
                .replacingOccurrences(of: "Digit", with: "")
                .replacingOccurrences(of: "Left", with: "")
                .replacingOccurrences(of: "Right", with: "")
        }
    }
}

extension PhysicalKey {
    var clackCode: String {
        switch self {
        case .escape: return "Escape"
        case .grave: return "Escape"
        case .k1, .f1: return "Digit1"
        case .k2, .f2: return "Digit2"
        case .k3, .f3: return "Digit3"
        case .k4, .f4: return "Digit4"
        case .k5, .f5: return "Digit5"
        case .k6, .f6: return "Digit6"
        case .k7, .f7: return "Digit7"
        case .k8, .f8: return "Digit8"
        case .k9, .f9: return "Digit9"
        case .k0, .f10: return "Digit0"
        case .minus, .f11: return "Minus"
        case .equal, .f12: return "Equal"
        case .backspace, .forwardDelete: return "Backspace"
        case .tab: return "Tab"
        case .q: return "KeyQ"
        case .w: return "KeyW"
        case .e: return "KeyE"
        case .r: return "KeyR"
        case .t: return "KeyT"
        case .y: return "KeyY"
        case .u: return "KeyU"
        case .i: return "KeyI"
        case .o: return "KeyO"
        case .p: return "KeyP"
        case .leftBracket: return "BracketLeft"
        case .rightBracket: return "BracketRight"
        case .backslash: return "Backslash"
        case .capsLock: return "CapsLock"
        case .a: return "KeyA"
        case .s: return "KeyS"
        case .d: return "KeyD"
        case .f: return "KeyF"
        case .g: return "KeyG"
        case .h: return "KeyH"
        case .j: return "KeyJ"
        case .k: return "KeyK"
        case .l: return "KeyL"
        case .semicolon: return "Semicolon"
        case .quote: return "Quote"
        case .enter: return "Enter"
        case .leftShift: return "ShiftLeft"
        case .z: return "KeyZ"
        case .x: return "KeyX"
        case .c: return "KeyC"
        case .v: return "KeyV"
        case .b: return "KeyB"
        case .n: return "KeyN"
        case .m: return "KeyM"
        case .comma: return "Comma"
        case .period: return "Period"
        case .slash: return "Slash"
        case .rightShift: return "ShiftRight"
        case .leftControl: return "ControlLeft"
        case .leftOption: return "AltLeft"
        case .leftCommand: return "MetaLeft"
        case .space: return "Space"
        case .rightCommand: return "MetaRight"
        case .rightOption: return "AltRight"
        case .rightControl, .fn: return "ControlRight"
        case .arrowLeft: return "ArrowLeft"
        case .arrowDown: return "ArrowDown"
        case .arrowUp: return "ArrowUp"
        case .arrowRight: return "ArrowRight"
        }
    }
}

// MARK: - Live Seated Cat Pose & Input Engine (1:1 Port of `class Je`)

struct ClackPawSpring {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct ClackKeyBubble {
    let id: Int
    let code: String
    let customLabel: String?
    let atMs: Double
    let x: CGFloat
    let y: CGFloat
}

struct ClackPose {
    var mouse: CGPoint = ClackStageConst.mouseRest
    var mouseReach: CGFloat = 0
    var headYaw: CGFloat = 0
    var headPitch: CGFloat = 0
    var left = ClackPawSpring(x: ClackStageConst.pawRestLeft.x, y: ClackStageConst.pawRestLeft.y)
    var right = ClackPawSpring(x: ClackStageConst.pawRestRight.x, y: ClackStageConst.pawRestRight.y)
    var trunk: CGPoint = .zero
    var headLean: CGPoint = .zero
    var keyboardReady: CGFloat = 0
    var gaze: CGPoint = .zero
    var turn: CGFloat = 0
    var breath: CGFloat = 0
    var closed: CGFloat = 0
    var petting: CGFloat = 0
    var tail: CGFloat = 0
    var tailTip: CGFloat = 0
    var earLeft: CGFloat = 0
    var earRight: CGFloat = 0
    var time: CGFloat = 0
    var active: Bool = false
    var sleeping: Bool = false
    var pressed: Set<String> = []
    var buttons: Set<String> = []
    var flashes: [String: Double] = [:]
    var bubbles: [ClackKeyBubble] = []

    static let neutral = ClackPose()
}

// MARK: - 1:1 Shift Handover Timeline & Actor State (`Tt`, `Le`, `class os`)

enum ClackHandoverTiming {
    static let approachEnd: Double = 1550
    static let braceEnd: Double    = 2420
    static let duelEnd: Double     = 5420   // Exact 3,000ms forehead-to-forehead standoff + "老吴！！" audio!
    static let turnEnd: Double     = 6000
    static let exitEnd: Double     = 7920
    static let watchEnd: Double    = 8150
    static let walkEnd: Double     = 9250
    static let sitEnd: Double      = 10200
    static let end: Double         = 10580
}

struct ClackHandoverActor {
    let breed: CatCoatTheme
    let customSkin: SkinSpec?
    let x: CGFloat
    let y: CGFloat
    let settlingAtKeys: Bool
    let turningToExit: Bool
    let stand: CGFloat
    let heading: CGFloat
    let look: CGFloat
    let pitch: CGFloat
    let tension: CGFloat
    let lean: CGFloat
    let stride: CGFloat
    let step: CGFloat
    let crouch: CGFloat
    let working: CGFloat
}

struct ClackHandoverFrame {
    let resident: ClackHandoverActor?
    let visitor: ClackHandoverActor
    let leftEdge: CGFloat
    let rightEdge: CGFloat
}

final class ClackHandoverDirector {
    struct HandoverTarget: Equatable {
        let coat: CatCoatTheme
        let customSkinID: String
        let skinName: String
        let customSkin: SkinSpec?

        static func == (lhs: HandoverTarget, rhs: HandoverTarget) -> Bool {
            lhs.coat == rhs.coat && lhs.customSkinID == rhs.customSkinID
        }
    }

    private(set) var chosen: HandoverTarget
    private var activePlay: (from: HandoverTarget, to: HandoverTarget, startMs: Double)?
    private var didFireDuelAudio = false
    var onDuelStart: (() -> Void)?
    var onHandoverCompleted: ((CatCoatTheme, String, String) -> Void)?

    init(initialBreed: CatCoatTheme, initialCustomSkinID: String = "", initialSkin: SkinSpec? = nil) {
        self.chosen = HandoverTarget(
            coat: initialBreed,
            customSkinID: initialCustomSkinID,
            skinName: initialSkin?.name ?? initialBreed.shortTitle,
            customSkin: initialCustomSkinID.isEmpty ? nil : initialSkin
        )
    }

    var isPlaying: Bool {
        activePlay != nil
    }

    var currentElapsedMs: Double {
        guard let p = activePlay else { return 0 }
        return CACurrentMediaTime() * 1000.0 - p.startMs
    }

    func startHandover(
        fromCoat: CatCoatTheme,
        fromCustomID: String = "",
        fromSkin: SkinSpec? = nil,
        toCoat: CatCoatTheme,
        toCustomID: String = "",
        toSkin: SkinSpec? = nil,
        nowMs: Double,
        force: Bool = false
    ) {
        let src = HandoverTarget(
            coat: fromCoat,
            customSkinID: fromCustomID,
            skinName: fromSkin?.name ?? fromCoat.shortTitle,
            customSkin: fromCustomID.isEmpty ? nil : fromSkin
        )
        let dst = HandoverTarget(
            coat: toCoat,
            customSkinID: toCustomID,
            skinName: toSkin?.name ?? toCoat.shortTitle,
            customSkin: toCustomID.isEmpty ? nil : toSkin
        )
        chosen = dst
        if force || activePlay == nil {
            activePlay = (from: src, to: dst, startMs: nowMs)
            didFireDuelAudio = false
        }
    }

    func syncInstant(coat: CatCoatTheme, customSkinID: String, skin: SkinSpec?) {
        chosen = HandoverTarget(
            coat: coat,
            customSkinID: customSkinID,
            skinName: skin?.name ?? coat.shortTitle,
            customSkin: customSkinID.isEmpty ? nil : skin
        )
        activePlay = nil
        didFireDuelAudio = false
    }

    func cancel() {
        activePlay = nil
        didFireDuelAudio = false
    }

    func evaluateFrame(nowMs: Double, scale: CGFloat) -> ClackHandoverFrame? {
        guard let p = activePlay else { return nil }
        let elapsed = nowMs - p.startMs
        if elapsed >= ClackHandoverTiming.braceEnd && elapsed < ClackHandoverTiming.duelEnd && !didFireDuelAudio {
            didFireDuelAudio = true
            onDuelStart?()
        }
        if elapsed < ClackHandoverTiming.end {
            return Self.computeFrame(
                from: p.from.coat,
                fromSkin: p.from.customSkin,
                to: p.to.coat,
                toSkin: p.to.customSkin,
                elapsedMs: elapsed,
                scale: scale
            )
        } else {
            let finished = p.to
            activePlay = nil
            didFireDuelAudio = false
            onHandoverCompleted?(finished.coat, finished.customSkinID, finished.skinName)
            if chosen != finished {
                activePlay = (from: finished, to: chosen, startMs: nowMs)
                return Self.computeFrame(
                    from: finished.coat,
                    fromSkin: finished.customSkin,
                    to: chosen.coat,
                    toSkin: chosen.customSkin,
                    elapsedMs: 0,
                    scale: scale
                )
            }
            return nil
        }
    }

    // Exact 1:1 port of `function Le(t, e, n, s)` from Clack-Clack!
    static func computeFrame(
        from residentBreed: CatCoatTheme,
        fromSkin: SkinSpec? = nil,
        to visitorBreed: CatCoatTheme,
        toSkin: SkinSpec? = nil,
        elapsedMs n: Double,
        scale: CGFloat
    ) -> ClackHandoverFrame {
        func M(_ a: CGFloat, _ b: CGFloat, _ u: CGFloat) -> CGFloat { a + (b - a) * u }
        func q(_ x: CGFloat) -> CGFloat { x * x * (3.0 - 2.0 * x) }
        func I(_ val: Double, _ t0: Double, _ t1: Double) -> CGFloat {
            CGFloat(max(0.0, min(1.0, (val - t0) / (t1 - t0))))
        }

        let i = q(I(n, 0, ClackHandoverTiming.approachEnd))
        let r = q(I(n, ClackHandoverTiming.approachEnd, ClackHandoverTiming.braceEnd))
        let a = q(I(n, ClackHandoverTiming.approachEnd + 190, ClackHandoverTiming.braceEnd))
        let l = q(I(n, ClackHandoverTiming.duelEnd + 40, ClackHandoverTiming.duelEnd + 365))
        let h = q(I(n, ClackHandoverTiming.duelEnd + 140, ClackHandoverTiming.turnEnd))
        let u = I(n, ClackHandoverTiming.turnEnd, ClackHandoverTiming.exitEnd)
        let d = q(I(n, ClackHandoverTiming.duelEnd + 100, ClackHandoverTiming.duelEnd + 680))
        let c = q(I(n, ClackHandoverTiming.watchEnd, ClackHandoverTiming.walkEnd))
        let f = q(I(n, ClackHandoverTiming.walkEnd + 280, ClackHandoverTiming.sitEnd))

        let effScale: CGFloat = 1.0
        let leftEdge = max(-52.0, ClackStageConst.screenToStage(CGPoint(x: 4, y: 0), scale: effScale).x)
        let rightEdge = min(518.0, ClackStageConst.screenToStage(CGPoint(x: ClackStageConst.width - 6, y: 0), scale: effScale).x)
        let startX = leftEdge - 140.0
        let yTurn = q(I(n, ClackHandoverTiming.walkEnd - 80, ClackHandoverTiming.walkEnd + 420))
        let bPad = max(0.0, ClackStageConst.screenToStage(CGPoint(x: 5, y: 0), scale: effScale).x - 4.0)

        let visitorX = M(M(M(startX, 54.0, i), 115.0 + bPad, r), 231.0, c)
        let duelT = I(n, ClackHandoverTiming.braceEnd, ClackHandoverTiming.duelEnd)
        let headButtLean = 1.55 * q(I(Double(duelT), 0, 0.16)) + 0.3 * sin(duelT * .pi * 4.0)
        let visitorStride = sin(.pi * i) + 0.5 * sin(.pi * r) + sin(.pi * c)

        let visitor = ClackHandoverActor(
            breed: visitorBreed,
            customSkin: toSkin,
            x: visitorX,
            y: M(324.0, 330.0, c),
            settlingAtKeys: yTurn > 0,
            turningToExit: false,
            stand: 1.0 - f,
            heading: 1.0 - yTurn,
            look: (0.53 + a * 0.12 + d * 0.09 - c * 0.21) * (1.0 - yTurn) * (1.0 - f),
            pitch: -0.035 * d * (1.0 - c),
            tension: a * (1.0 - d),
            lean: headButtLean * a * (1.0 - d),
            stride: visitorStride,
            step: (visitorX - startX) / 86.0 * 2.0 * .pi,
            crouch: q(I(n, ClackHandoverTiming.walkEnd + 130, ClackHandoverTiming.walkEnd + 350)) * (1.0 - f),
            working: q(I(n, ClackHandoverTiming.sitEnd, ClackHandoverTiming.end))
        )

        let resident: ClackHandoverActor?
        if n < ClackHandoverTiming.exitEnd {
            let kBase = 344.0 + bPad
            let easeExit = u < 0.16 ? (u * u / 0.32) : (u - 0.08)
            let exitWalkDX = (rightEdge + 136.0 - kBase) * easeExit / 0.92
            resident = ClackHandoverActor(
                breed: residentBreed,
                customSkin: fromSkin,
                x: M(231.0, kBase, r) + exitWalkDX,
                y: M(330.0, 324.0, r),
                settlingAtKeys: false,
                turningToExit: h > 0 && h < 1,
                stand: r,
                heading: M(-1.0, 1.0, h),
                look: M(-0.53 - 0.12 * a, 0.6, l) * q(I(n, 470, ClackHandoverTiming.approachEnd)),
                pitch: 0,
                tension: a * (1.0 - l),
                lean: headButtLean * a * (1.0 - l),
                stride: 0.75 * sin(.pi * r) + 0.38 * sin(.pi * h) + q(I(Double(u), 0, 0.16)),
                step: r * .pi * 2.5 + h * .pi + exitWalkDX / 118.0 * 2.0 * .pi,
                crouch: sin(.pi * r) + 0.22 * sin(.pi * h),
                working: 1.0 - q(I(n, 540, ClackHandoverTiming.approachEnd))
            )
        } else {
            resident = nil
        }

        _ = scale
        return ClackHandoverFrame(resident: resident, visitor: visitor, leftEdge: leftEdge, rightEdge: rightEdge)
    }

    // Exact 1:1 port of `function an(t, e)` blending working pose during sit/stand handover ends
    static func blendWorkingPose(_ actor: ClackHandoverActor, livePose e: ClackPose) -> ClackPose {
        let n = actor.working
        if n >= 0.999 { return e }
        func M(_ a: CGFloat, _ b: CGFloat, _ u: CGFloat) -> CGFloat { a + (b - a) * u }
        func lerpPt(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: M(a.x, b.x, n), y: M(a.y, b.y, n))
        }
        var out = e
        out.headYaw = M(actor.look, e.headYaw, n)
        out.headPitch = M(actor.pitch, e.headPitch, n)
        out.gaze = lerpPt(CGPoint(x: actor.look * 9.0, y: actor.pitch * 12.0), e.gaze)
        out.turn = e.turn * n
        out.headLean = lerpPt(.zero, e.headLean)
        out.trunk = lerpPt(.zero, e.trunk)
        let lp = lerpPt(ClackStageConst.pawRestLeft, e.left.point)
        let rp = lerpPt(ClackStageConst.pawRestRight, e.right.point)
        out.left.x = lp.x; out.left.y = lp.y
        out.right.x = rp.x; out.right.y = rp.y
        out.closed = e.closed * n
        out.breath = e.breath * n
        out.tail = e.tail * n
        out.tailTip = e.tailTip * n
        out.earLeft = e.earLeft * n
        out.earRight = e.earRight * n
        out.keyboardReady = e.keyboardReady * n
        out.mouseReach = e.mouseReach * n
        return out
    }
}

// MARK: - Complete Clack-Clack Simulation Controller (Drives Pose + Handover + Hit Regions)

final class ClackSimulation {
    var pose = ClackPose()
    let handover: ClackHandoverDirector

    private var latestPress: [String: Double] = [:]
    private var lastActionMs: Double = CACurrentMediaTime() * 1000.0
    private var previousStageCursor: CGPoint?
    private var lastScreenMouse: CGPoint?
    private var mouseTarget: CGPoint = ClackStageConst.mouseRest
    private var gripUntilMs: Double = 0
    private var graspStart: CGPoint?
    private var graspTime: CGFloat = 0
    private var readyUntilMs: Double = 0
    private var keyDirection: CGFloat = 0
    private var breathPhase: CGFloat = 0
    private var tailPhase: CGFloat = 0
    private var nextBlink: CGFloat = 2.4
    private var blinkIndex: Int = 0
    private var nextBubbleID: Int = 1
    private var anonymousUntilMs: Double = 0

    var isDictationListening: Bool = false {
        didSet {
            if isDictationListening {
                lastActionMs = CACurrentMediaTime() * 1000.0
                pose.sleeping = false
            }
        }
    }

    private(set) var currentHandoverFrame: ClackHandoverFrame?

    init(initialBreed: CatCoatTheme, initialCustomSkinID: String = "", initialSkin: SkinSpec? = nil) {
        self.handover = ClackHandoverDirector(
            initialBreed: initialBreed,
            initialCustomSkinID: initialCustomSkinID,
            initialSkin: initialSkin
        )
    }

    func triggerKeyDown(
        code: String,
        showBubble: Bool,
        customBubbleLabel: String? = nil,
        privacy: Bool = false,
        nowMs: Double? = nil
    ) {
        let now = nowMs ?? (CACurrentMediaTime() * 1000.0)
        lastActionMs = now
        if privacy {
            anonymousUntilMs = now + 400.0
            pose.pressed.removeAll()
            pose.flashes.removeAll()
            pose.bubbles.removeAll()
            return
        }
        pose.pressed.insert(code)
        latestPress[code] = now
        pose.flashes[code] = now

        if showBubble && currentHandoverFrame == nil {
            let anchor: CGPoint
            if code.hasPrefix("Mouse") || code.hasPrefix("Wheel") {
                anchor = pose.mouse
            } else if let kp = ClackKeyboardMap.targetPoint(for: code)?.pt {
                anchor = kp
            } else {
                anchor = CGPoint(x: 248, y: ClackStageConst.kbRect.minY)
            }
            let bubble = ClackKeyBubble(
                id: nextBubbleID,
                code: code,
                customLabel: customBubbleLabel,
                atMs: now,
                x: anchor.x,
                y: min(anchor.y - 35.0, ClackStageConst.kbRect.minY - 26.0)
            )
            nextBubbleID += 1
            pose.bubbles.append(bubble)
            if pose.bubbles.count > 7 {
                pose.bubbles.removeFirst(pose.bubbles.count - 7)
            }
        }
    }

    func triggerKeyUp(code: String) {
        pose.pressed.remove(code)
    }

    func clearAllInputs() {
        pose.pressed.removeAll()
        pose.buttons.removeAll()
        pose.flashes.removeAll()
        pose.bubbles.removeAll()
        anonymousUntilMs = 0
    }

    func triggerMouseButton(code: String, isDown: Bool, showBubble: Bool, privacy: Bool = false) {
        let now = CACurrentMediaTime() * 1000.0
        if privacy {
            pose.buttons.removeAll()
            return
        }
        if isDown {
            pose.buttons.insert(code)
            latestPress[code] = now
            pose.flashes[code] = now
            lastActionMs = now
            gripUntilMs = now + 450.0
            if showBubble && currentHandoverFrame == nil {
                let bubble = ClackKeyBubble(
                    id: nextBubbleID,
                    code: code,
                    customLabel: nil,
                    atMs: now,
                    x: pose.mouse.x,
                    y: min(pose.mouse.y - 35.0, ClackStageConst.kbRect.minY - 26.0)
                )
                nextBubbleID += 1
                pose.bubbles.append(bubble)
                if pose.bubbles.count > 7 {
                    pose.bubbles.removeFirst(pose.bubbles.count - 7)
                }
            }
        } else {
            pose.buttons.remove(code)
        }
    }

    func registerPetting(delta: CGFloat) {
        let now = CACurrentMediaTime() * 1000.0
        pose.petting = min(1.0, pose.petting + delta * 0.014)
        lastActionMs = now
    }

    func step(
        dt rawDt: CGFloat,
        cursorStagePt: CGPoint?,
        screenMousePt: CGPoint,
        paused: Bool = false,
        privacy: Bool = false,
        reducedMotion: Bool = false
    ) {
        let dt = min(max(rawDt, 0), 0.06)
        let nowMs = CACurrentMediaTime() * 1000.0
        pose.time += dt

        if paused {
            pose.pressed.removeAll()
            pose.buttons.removeAll()
            pose.bubbles.removeAll()
        } else if let prevScreen = lastScreenMouse {
            let dx = screenMousePt.x - prevScreen.x
            let dy = -(screenMousePt.y - prevScreen.y)
            if abs(dx) > 0.05 || abs(dy) > 0.05 {
                let hoveringCat = cursorStagePt.map { hitTestCat($0) } ?? false
                if (!hoveringCat || !pose.buttons.isEmpty) && !privacy {
                    let b = ClackStageConst.mouseBounds
                    mouseTarget.x = max(b.left, min(b.right, mouseTarget.x + dx * 0.16))
                    mouseTarget.y = max(b.top, min(b.bottom, mouseTarget.y + dy * 0.16))
                    gripUntilMs = nowMs + 450.0
                }
                lastActionMs = nowMs
            }
        }
        lastScreenMouse = screenMousePt

        let stageMouse = cursorStagePt ?? CGPoint(x: 230, y: 172)
        let stageMove = previousStageCursor.map { hypot(stageMouse.x - $0.x, stageMouse.y - $0.y) } ?? 0
        let overCat = cursorStagePt != nil && hitTestCat(stageMouse)
        if overCat && stageMove > 0.15 && stageMove < 110 && currentHandoverFrame == nil {
            pose.petting = min(1.0, pose.petting + stageMove * 0.014)
            lastActionMs = nowMs
        }
        previousStageCursor = stageMouse
        pose.petting = max(0, pose.petting - dt * 0.6)

        if isDictationListening {
            lastActionMs = nowMs
        }
        pose.sleeping = !paused && (nowMs - lastActionMs > 25_000) && !handover.isPlaying

        let aBlink = pose.time - nextBlink
        let blinkAmt = max(0, min(1, min(aBlink / 0.09, (0.29 - aBlink) / 0.16)))
        if aBlink >= 0.29 {
            let intervals: [CGFloat] = [4.1, 5.7, 3.3]
            nextBlink += intervals[blinkIndex % 3]
            blinkIndex += 1
        }
        let targetClosed: CGFloat = overCat ? 0 : (pose.sleeping ? 1.0 : blinkAmt)
        pose.closed += (targetClosed - pose.closed) * (1.0 - exp(-32.0 * dt))

        var leftTarget: (x: CGFloat, y: CGFloat, at: Double)? = nil
        var rightTarget: (x: CGFloat, y: CGFloat, at: Double)? = nil

        if privacy && !paused && nowMs < anonymousUntilMs {
            // Exact Clack-Clack privacy mode: gentle alternating anonymous central taps, hiding real keys!
            let altLeft = Int(nowMs / 110.0) % 2 == 0
            if altLeft, let kp = ClackKeyboardMap.targetPoint(for: "KeyF") {
                leftTarget = (kp.pt.x, kp.pt.y - 2, nowMs - 20)
            } else if let kp = ClackKeyboardMap.targetPoint(for: "KeyJ") {
                rightTarget = (kp.pt.x, kp.pt.y - 2, nowMs - 20)
            }
        } else if !paused && !privacy {
            for code in pose.pressed {
                guard let kp = ClackKeyboardMap.targetPoint(for: code) else { continue }
                let at = latestPress[code] ?? 0
                if kp.isLeft {
                    if leftTarget == nil || at >= leftTarget!.at { leftTarget = (kp.pt.x, kp.pt.y - 2, at) }
                } else {
                    if rightTarget == nil || at >= rightTarget!.at { rightTarget = (kp.pt.x, kp.pt.y - 2, at) }
                }
            }
            let leftHeld = (leftTarget != nil)
            let rightHeld = (rightTarget != nil)
            for (code, flashAt) in pose.flashes {
                if nowMs - flashAt > 120 {
                    if nowMs - flashAt > 500 { pose.flashes.removeValue(forKey: code) }
                    continue
                }
                guard let kp = ClackKeyboardMap.targetPoint(for: code) else { continue }
                if kp.isLeft && !leftHeld && flashAt >= (leftTarget?.at ?? 0) {
                    leftTarget = (kp.pt.x, kp.pt.y - 2, flashAt)
                } else if !kp.isLeft && !rightHeld && flashAt >= (rightTarget?.at ?? 0) {
                    rightTarget = (kp.pt.x, kp.pt.y - 2, flashAt)
                }
            }
        }

        let mouseClickedRecent = !paused && !privacy && ["MouseLeft", "MouseRight", "MouseMiddle", "WheelUp", "WheelDown"].contains {
            nowMs - (pose.flashes[$0] ?? 0) < 180
        }
        let grippingMouse = !paused && !privacy && (!pose.buttons.isEmpty || mouseClickedRecent || nowMs < gripUntilMs)
        let mouseLerp = 1.0 - exp(-24.0 * dt)
        pose.mouse.x += (mouseTarget.x - pose.mouse.x) * mouseLerp
        pose.mouse.y += (mouseTarget.y - pose.mouse.y) * mouseLerp

        let reachLerp = 1.0 - exp(-18.0 * dt)
        pose.mouseReach += ((grippingMouse ? 1.0 : 0.0) - pose.mouseReach) * reachLerp

        if leftTarget != nil || rightTarget != nil {
            readyUntilMs = nowMs + 440.0
            let midX: CGFloat
            if let lt = leftTarget, let rt = rightTarget { midX = (lt.x + rt.x) * 0.5 }
            else { midX = (leftTarget ?? rightTarget)!.x }
            keyDirection = max(-1.0, min(1.0, (midX - 235.0) / 115.0))
        }

        let isTypingReady = !paused && nowMs < readyUntilMs
        updatePosture(dt: dt, ready: isTypingReady, cursor: stageMouse, reducedMotion: reducedMotion)
        pose.active = isTypingReady || grippingMouse || !pose.pressed.isEmpty || pose.keyboardReady > 0.02
            || abs(pose.headLean.x) > 0.5 || pose.petting > 0.03 || stageMove > 0.2 || handover.isPlaying
        updateIdleMotion(dt: dt, reducedMotion: reducedMotion)

        let rightEffective = (grippingMouse && leftTarget != nil && (rightTarget == nil || leftTarget!.at > rightTarget!.at))
            ? leftTarget
            : rightTarget

        func slapBounce(_ target: (x: CGFloat, y: CGFloat, at: Double)) -> CGPoint {
            let lift = 16.0 * max(0, min(1, 1.0 - CGFloat(nowMs - target.at) / 55.0))
            return CGPoint(x: target.x, y: target.y - lift)
        }
        func readyHover(isLeft: Bool) -> CGPoint {
            let base = isLeft ? ClackStageConst.pawRestLeft : ClackStageConst.pawRestRight
            let s = pose.keyboardReady
            let w257 = Self.spineWeight(257)
            return CGPoint(
                x: base.x + s * ((isLeft ? 5.0 : 1.0) + pose.trunk.x * w257),
                y: base.y + s * (258.0 + pose.trunk.y * w257 - base.y)
            )
        }

        let wTarget = leftTarget.map(slapBounce) ?? readyHover(isLeft: true)
        let pTarget = rightEffective.map(slapBounce) ?? readyHover(isLeft: false)

        if grippingMouse {
            moveToGrip(dt: dt)
        } else {
            graspStart = nil
            Self.stepPaw(&pose.left, to: wTarget, dt: dt, snappy: leftTarget != nil)
        }
        Self.stepPaw(&pose.right, to: pTarget, dt: dt, snappy: rightEffective != nil)

        pose.bubbles.removeAll { nowMs - $0.atMs >= ($0.code.hasPrefix("Wheel") ? 1000.0 : 1150.0) }
        currentHandoverFrame = handover.evaluateFrame(nowMs: nowMs, scale: 1.0)
        if currentHandoverFrame != nil || privacy {
            pose.bubbles.removeAll()
        }
    }

    static func spineWeight(_ y: CGFloat) -> CGFloat {
        let e = max(0, min(1, (312.0 - y) / 186.0))
        return e * (0.8 + 0.2 * e)
    }

    private static func stepPaw(_ paw: inout ClackPawSpring, to target: CGPoint, dt: CGFloat, snappy: Bool) {
        let steps = max(1, Int(ceil(dt / (1.0 / 120.0))))
        let subDt = min(dt / CGFloat(steps), 1.0 / 120.0)
        let k: CGFloat = snappy ? 3600.0 : 330.0
        let damp: CGFloat = snappy ? 112.0 : 29.0
        for _ in 0..<steps {
            paw.vx += ((target.x - paw.x) * k - paw.vx * damp) * subDt
            paw.vy += ((target.y - paw.y) * k - paw.vy * damp) * subDt
            paw.x += paw.vx * subDt
            paw.y += paw.vy * subDt
        }
    }

    private func moveToGrip(dt: CGFloat) {
        if graspStart == nil {
            graspStart = pose.left.point
            graspTime = 0
        }
        graspTime += dt
        pose.left.vx = 0
        pose.left.vy = 0
        let dur: CGFloat = 0.12
        if graspTime >= dur {
            pose.left.x = pose.mouse.x
            pose.left.y = pose.mouse.y - 5.0
            return
        }
        let o = graspTime / dur
        let ease = o * o * (3.0 - 2.0 * o)
        let start = graspStart!
        let arc = sin(.pi * o)
        pose.left.x = start.x + (pose.mouse.x - start.x) * ease
        pose.left.y = start.y + (pose.mouse.y - 5.0 - start.y) * ease - 5.0 * arc * arc
    }

    private func updatePosture(dt: CGFloat, ready: Bool, cursor: CGPoint, reducedMotion: Bool) {
        let motionScale: CGFloat = reducedMotion ? 0.35 : 1.0
        let u = 1.0 - exp(-(ready ? 14.0 : 5.0) * dt)
        pose.keyboardReady += ((ready ? 1.0 : 0.0) - pose.keyboardReady) * u
        let d = pose.keyboardReady
        let c = pose.mouseReach
        let tx = ((pose.mouse.x - 230.0) * 0.53 * c * (1.0 - 0.48 * d) + 23.0 * keyDirection * d * (1.0 - 0.65 * c)) * motionScale
        let ty = (13.0 * c + 24.0 * d - 10.0 * c * d) * motionScale
        let g = 1.0 - exp(-7.4 * dt)
        let x = 1.0 - exp(-14.0 * dt)
        pose.trunk.x += (tx - pose.trunk.x) * g
        pose.trunk.y += (ty - pose.trunk.y) * g
        pose.headLean.x += (pose.trunk.x - pose.headLean.x) * x
        pose.headLean.y += (pose.trunk.y - pose.headLean.y) * x

        let bBounds = ClackStageConst.mouseBounds
        let yBlend = c * 0.32
        let mxNorm = 2.0 * (pose.mouse.x - bBounds.left) / (bBounds.right - bBounds.left) - 1.0
        let myNorm = 2.0 * (pose.mouse.y - bBounds.top) / (bBounds.bottom - bBounds.top) - 1.0
        let cxNorm = tanh((cursor.x - 231.0 - pose.headLean.x) / 165.0)
        let cyNorm = tanh((cursor.y - 126.0 - pose.headLean.y) / 165.0)
        let pTrack: CGFloat = !pose.sleeping ? (1.0 - 0.82 * d * (1.0 - c)) : 0
        let targetYaw = 0.44 * pTrack * (cxNorm * (1.0 - yBlend) + mxNorm * yBlend) * motionScale
        let targetPitch = 0.23 * pTrack * (cyNorm * (1.0 - yBlend) + myNorm * yBlend) * motionScale
        let eLerp = 1.0 - exp(-8.0 * dt)
        pose.headYaw += (targetYaw - pose.headYaw) * eLerp
        pose.headPitch += (targetPitch - pose.headPitch) * eLerp

        let rFocus = d * (1.0 - c) * 0.85
        let gx = tanh((cursor.x - 230.0) / 170.0) * 7.0 * (1.0 - rFocus) + 6.0 * keyDirection * rFocus
        let gy = tanh((cursor.y - 172.0) / 170.0) * 5.0 * (1.0 - rFocus) + 5.0 * rFocus
        let hLerp = 1.0 - exp(-13.0 * dt)
        pose.gaze.x += (gx - pose.gaze.x) * hLerp
        pose.gaze.y += (gy - pose.gaze.y) * hLerp
        pose.turn += (pose.gaze.x * 0.7 * motionScale - pose.turn) * (1.0 - exp(-6.0 * dt))
        if !ready && pose.keyboardReady < 0.002 {
            keyDirection = 0
            readyUntilMs = 0
        }
    }

    private func updateIdleMotion(dt: CGFloat, reducedMotion: Bool) {
        let motionScale: CGFloat = reducedMotion ? 0.35 : 1.0
        breathPhase += dt * (pose.sleeping ? 1.25 : 2.0)
        tailPhase += dt * (pose.sleeping ? 0.72 : (pose.active ? 2.35 : 1.45))
        pose.breath = sin(breathPhase) * 1.35 * motionScale
        let tailAmp: CGFloat = (pose.sleeping ? 2.0 : (pose.active ? 7.0 : 5.0)) * motionScale
        pose.tail += (tailAmp * sin(tailPhase) - pose.tail) * (1.0 - exp(-5.0 * dt))
        pose.tailTip += (pose.tail * 1.85 - pose.tailTip) * (1.0 - exp(-3.0 * dt))

        let earCycle = (pose.time + 4.3).truncatingRemainder(dividingBy: 7.6)
        let twitch: CGFloat = (!pose.sleeping && !reducedMotion && earCycle < 0.42) ? pow(sin(.pi * earCycle / 0.42), 2) * 9.0 : 0
        let flatten: CGFloat = pose.sleeping ? 5.0 : 3.0 * pose.petting
        let gazeTilt: CGFloat = pose.sleeping ? 0 : pose.gaze.x * 0.65 * motionScale
        let eLerp = 1.0 - exp(-12.0 * dt)
        pose.earLeft += (gazeTilt - flatten - twitch - pose.earLeft) * eLerp
        pose.earRight += (gazeTilt + flatten - pose.earRight) * eLerp
    }

    // MARK: - Hit Testing in 564x480 Stage Coordinates (For Transparent Click-Through & Petting)

    func hitTestCat(_ pt: CGPoint) -> Bool {
        if let hf = currentHandoverFrame {
            for actor in [hf.resident, hf.visitor].compactMap({ $0 }) {
                let cx = actor.x
                let cy = actor.y - (actor.stand > 0 ? 95.0 : 120.0)
                if hypot((pt.x - cx) / 95.0, (pt.y - cy) / 115.0) <= 1.0 {
                    return true
                }
            }
            return false
        }
        let headOff = CGPoint(x: pose.headLean.x + pose.turn * 1.35, y: pose.headLean.y + pose.gaze.y * 0.65)
        let ellipses: [CGRect] = [
            CGRect(x: 173 + headOff.x, y: 84 + headOff.y, width: 116, height: 100),
            CGRect(x: 175 + pose.trunk.x * 0.55, y: 154 + pose.trunk.y * 0.55, width: 111, height: 100),
            CGRect(x: 163 + pose.trunk.x * 0.35, y: 193 + pose.trunk.y * 0.35, width: 135, height: 108),
            CGRect(x: 162 + pose.trunk.x * 0.15, y: 239 + pose.trunk.y * 0.15, width: 138, height: 93),
            CGRect(x: 277, y: 279, width: 46, height: 18),
            CGRect(x: 311, y: 260 + pose.tail * 0.28, width: 30, height: 31)
        ]
        return ellipses.contains { r in
            let nx = (pt.x - r.midX) / (r.width * 0.5)
            let ny = (pt.y - r.midY) / (r.height * 0.5)
            return nx * nx + ny * ny <= 1.0
        }
    }

    func hitTestDeskOrCat(_ pt: CGPoint) -> Bool {
        if hitTestCat(pt) { return true }
        let kbHit = CGRect(x: 112, y: 325, width: 292, height: 68)
        if kbHit.contains(pt) { return true }
        let mouseHit = CGRect(x: pose.mouse.x - 22, y: pose.mouse.y - 18, width: 44, height: 44)
        return mouseHit.contains(pt)
    }
}
