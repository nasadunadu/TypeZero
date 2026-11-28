import Foundation
import AppKit
import CoreGraphics

// MARK: - 1:1 Pixel-Exact Native CoreGraphics Port of Chingyim/Clack-Clack Vector Renderer (`class Ts`)

struct ClackBreedPalette {
    let fur: NSColor
    let edge: NSColor
    let iris: NSColor
    let whisker: NSColor
    let point: NSColor?
    let tabby: Bool
    let isSilverTabby: Bool

    static func palette(for coat: CatCoatTheme) -> ClackBreedPalette {
        switch coat {
        case .classicBlack:
            return ClackBreedPalette(
                fur: hex(0x19171B),
                edge: hex(0x333036),
                iris: hex(0xE5F672),
                whisker: hex(0xB4AEAD),
                point: nil,
                tabby: false,
                isSilverTabby: false
            )
        case .siamese:
            return ClackBreedPalette(
                fur: hex(0xEEE2CF),
                edge: hex(0x6C594A),
                iris: hex(0x69D1FF),
                whisker: hex(0x675044),
                point: hex(0x3D2C22),
                tabby: false,
                isSilverTabby: false
            )
        case .orangeWhite:
            // Authentic Clack-Clack 「黄粽子」 (`huangzongzi`)!
            return ClackBreedPalette(
                fur: hex(0xD79754),
                edge: hex(0x8C603D),
                iris: hex(0xB7BE73),
                whisker: hex(0xFFF5DF),
                point: nil,
                tabby: true,
                isSilverTabby: false
            )
        case .shorthair:
            // Silver-white American Shorthair using Clack-Clack's tabby spline rig!
            return ClackBreedPalette(
                fur: hex(0xB9BEB9),
                edge: hex(0x5E6364),
                iris: hex(0xD8C967),
                whisker: hex(0xF6F7F5),
                point: nil,
                tabby: true,
                isSilverTabby: true
            )
        }
    }

    static func resolve(coat: CatCoatTheme, customSkin: SkinSpec? = nil) -> ClackBreedPalette {
        guard let sk = customSkin, !sk.builtIn else {
            return palette(for: coat)
        }
        func ns(_ c: SkinColor) -> NSColor {
            NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
        }
        let p = sk.palette
        let furCol = ns(p.body)
        let edgeCol = Self.lerpColor(furCol, ns(p.earOuter), 0.55)
        let irisCol = p.iris.map(ns) ?? coat.recommendedEyeTheme.primaryColor
        let whiskerCol = ns(p.whiskers)
        let ptCol = sk.colorpoint ? p.points.map(ns) : nil
        return ClackBreedPalette(
            fur: furCol,
            edge: edgeCol,
            iris: irisCol,
            whisker: whiskerCol,
            point: ptCol,
            tabby: p.stripes != nil && !sk.colorpoint,
            isSilverTabby: p.body.luminance > 0.55
        )
    }

    var bibCream: NSColor {
        isSilverTabby ? Self.hex(0xF6F7F5) : Self.hex(0xFFF4DF)
    }
    var stripeDark: NSColor {
        isSilverTabby ? Self.hex(0x4E5355) : Self.hex(0xAA632F)
    }
    var stripeMid: NSColor {
        isSilverTabby ? Self.hex(0x686E70) : Self.hex(0xBF8046)
    }
    var tailTipLight: NSColor {
        isSilverTabby ? Self.hex(0xDFE3DF) : Self.hex(0xEFC394)
    }

    static func hex(_ rgb: Int, alpha: CGFloat = 1.0) -> NSColor {
        NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    static func lerpColor(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
        let u = max(0, min(1, t))
        if u == 0 { return a }
        if u == 1 { return b }
        let ca = a.usingColorSpace(.sRGB) ?? a
        let cb = b.usingColorSpace(.sRGB) ?? b
        return NSColor(
            srgbRed: ca.redComponent + (cb.redComponent - ca.redComponent) * u,
            green: ca.greenComponent + (cb.greenComponent - ca.greenComponent) * u,
            blue: ca.blueComponent + (cb.blueComponent - ca.blueComponent) * u,
            alpha: ca.alphaComponent + (cb.alphaComponent - ca.alphaComponent) * u
        )
    }
}

enum ClackRenderer {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    // Precomputed static 3D keyboard geometry (`Vn()`)
    private struct KeycapMesh {
        let skirt: CGPath
        let front: CGPath
        let top: CGPath
        let center: CGPoint
        let xx: CGFloat, xy: CGFloat, yx: CGFloat, yy: CGFloat
    }

    private struct KeyboardMesh {
        let boardEdge: CGPath
        let boardTop: CGPath
        let plate: CGPath
        let caps: [(key: ClackKeyDef, up: KeycapMesh, down: KeycapMesh)]
    }

    private static let cachedKeyboard: KeyboardMesh = {
        let kb = ClackStageConst.kbRect
        let a = ClackStageConst.deckQuad(kb.minX, kb.minY, kb.width, kb.height, ClackStageConst.kbBaseZ)
        let l = ClackStageConst.deckQuad(kb.minX, kb.minY, kb.width, kb.height, 0)
        let boardEdge = roundedPoly([a[0], a[1], a[2], l[2], l[3], a[3]], radius: 3.1)
        let boardTop = roundedPoly(a, radius: 3.1)
        let plate = roundedPoly(
            ClackStageConst.deckQuad(kb.minX + 5, kb.minY + 5, kb.width - 10, kb.height - 10, ClackStageConst.kbBaseZ),
            radius: 2.0
        )
        func buildCap(_ k: ClackKeyDef, pressed: Bool) -> KeycapMesh {
            let zTop = ClackStageConst.capTopZ - (pressed ? 1.9 : 0.0)
            let sx: CGFloat = 1.15
            let sy: CGFloat = min(1.05, k.height * 0.12)
            let i = ClackStageConst.deckQuad(k.x, k.y, k.width, k.height, ClackStageConst.kbBaseZ)
            let r = ClackStageConst.deckQuad(k.x + sx, k.y + sy, k.width - 2 * sx, k.height - 2 * sy, zTop)
            let cx = k.x + k.width * 0.5
            let cy = k.y + k.height * 0.5
            let h = ClackStageConst.projectDeck(cx, cy, zTop)
            let u = ClackStageConst.projectDeck(cx + 1, cy, zTop)
            let d = ClackStageConst.projectDeck(cx, cy + 1, zTop)
            return KeycapMesh(
                skirt: roundedPoly([r[0], r[1], i[1], i[2], i[3], i[0]], radius: 0.75),
                front: roundedPoly([r[3], r[2], i[2], i[3]], radius: 0.55),
                top: roundedPoly(r, radius: 0.85),
                center: h,
                xx: h.x - u.x, xy: h.y - u.y,
                yx: h.x - d.x, yy: h.y - d.y
            )
        }
        let sortedKeys = ClackKeyboardMap.keys.sorted { $0.y < $1.y }
        let caps = sortedKeys.map { k in (k, buildCap(k, pressed: false), buildCap(k, pressed: true)) }
        return KeyboardMesh(boardEdge: boardEdge, boardTop: boardTop, plate: plate, caps: caps)
    }()

    // MARK: - Main Draw Entry Point (In 564x480 Flipped Top-Down Logical Space)

    static func drawStage(
        in ctx: CGContext,
        pose: ClackPose,
        breed: CatCoatTheme,
        handover: ClackHandoverFrame?,
        customSkin: SkinSpec? = nil,
        anchorX: CGFloat = ClackStageConst.overlayAnchorX,
        anchorY: CGFloat = ClackStageConst.overlayAnchorY,
        baseScale: CGFloat = ClackStageConst.overlayBaseScale,
        whiteOutline: Bool = false,
        showKeyLabels: Bool = true,
        showKeyBubbles: Bool = true,
        isDictationListening: Bool = false,
        isMusicPlaying: Bool = false
    ) {
        let nowMs = CACurrentMediaTime() * 1000.0
        ctx.saveGState()
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        ctx.translateBy(x: anchorX, y: anchorY)
        ctx.scaleBy(x: baseScale, y: baseScale)
        ctx.translateBy(x: -230.0, y: -405.0)

        // 1. Soft radial ground shadows under cat(s), keyboard, and mouse
        if let hf = handover {
            let stageClip = CGRect(x: hf.leftEdge, y: -480, width: hf.rightEdge - hf.leftEdge, height: ClackStageConst.height * 3.0)
            ctx.saveGState()
            ctx.clip(to: stageClip)
            for actor in [hf.resident, hf.visitor].compactMap({ $0 }) {
                drawShadow(in: ctx, x: actor.x, y: actor.y, rx: 75, ry: 6, alpha: 0.23)
            }
            ctx.restoreGState()
        } else {
            drawShadow(in: ctx, x: 229, y: 330, rx: 75, ry: 6, alpha: 0.23)
        }
        drawShadow(in: ctx, x: 257, y: 382, rx: 140, ry: 7, alpha: 0.10)
        drawShadow(in: ctx, x: pose.mouse.x - 4, y: pose.mouse.y + 20, rx: 19, ry: 4.3, alpha: 0.20)

        // 2. Standing / Walking / Head-Butting Handover Cats OR Seated Cat Back Layer
        var seatedPose: ClackPose? = (handover == nil) ? pose : nil
        var seatedPal = ClackBreedPalette.resolve(coat: breed, customSkin: customSkin)

        if let hf = handover {
            let stageClip = CGRect(x: hf.leftEdge, y: -480, width: hf.rightEdge - hf.leftEdge, height: ClackStageConst.height * 3.0)
            ctx.saveGState()
            ctx.clip(to: stageClip)
            let order: [ClackHandoverActor?] = (hf.resident != nil && hf.resident!.y > hf.visitor.y)
                ? [hf.visitor, hf.resident]
                : [hf.resident, hf.visitor]
            for maybeActor in order {
                guard let actor = maybeActor else { continue }
                if actor.stand > 0 {
                    drawWithOptionalStickerOutline(
                        in: ctx,
                        bounds: CGRect(x: actor.x - 145, y: actor.y - 255, width: 290, height: 275),
                        enabled: whiteOutline
                    ) { subCtx in
                        drawStandingHandoverCat(in: subCtx, actor: actor)
                    }
                } else {
                    seatedPose = ClackHandoverDirector.blendWorkingPose(actor, livePose: pose)
                    seatedPal = ClackBreedPalette.resolve(coat: actor.breed, customSkin: actor.customSkin)
                }
            }
            ctx.restoreGState()
        }

        if let sp = seatedPose {
            drawWithOptionalStickerOutline(
                in: ctx,
                bounds: CGRect(x: 130, y: 120, width: 250, height: 230),
                enabled: whiteOutline
            ) { subCtx in
                drawSeatedTail(in: subCtx, pose: sp, pal: seatedPal)
                drawSeatedBody(in: subCtx, pose: sp, pal: seatedPal)
            }
        }

        // 3. 3D Perspective Mechanical Keyboard & Mouse
        drawKeyboard(in: ctx, pose: pose, showKeyLabels: showKeyLabels, nowMs: nowMs)
        drawMouse(in: ctx, pose: pose, nowMs: nowMs)

        // 4. Reaching Front Arms + 3D Head & Expressive Eyes
        if let sp = seatedPose {
            drawWithOptionalStickerOutline(
                in: ctx,
                bounds: CGRect(x: 55, y: 40, width: 340, height: 325),
                enabled: whiteOutline
            ) { subCtx in
                drawReachingArm(in: subCtx, pose: sp, isLeft: true, pal: seatedPal)
                drawReachingArm(in: subCtx, pose: sp, isLeft: false, pal: seatedPal)
                drawCatHead(in: subCtx, pose: sp, pal: seatedPal, tension: 0, profile: 0, bodyClip: nil)
            }

            if isMusicPlaying && handover == nil {
                drawMusicNotes(in: ctx, pose: sp)
            }
            if isDictationListening && handover == nil {
                drawVoiceListeningPill(in: ctx, pose: sp)
            }
        }

        // 5. Floating Keycap Bubbles & Sleep 'z's
        if handover == nil && showKeyBubbles && !pose.bubbles.isEmpty {
            drawBubbles(in: ctx, bubbles: pose.bubbles, nowMs: nowMs)
        }
        if handover == nil && pose.sleeping {
            drawSleepZs(in: ctx, time: pose.time)
        }

        ctx.restoreGState()
    }

    // MARK: - KuroCat Desk Seamless Integration (1:1 Clack-Clack Handover Behind KuroCat Keyboard!)

    static func drawHandoverBackOnKuroDesk(
        in ctx: CGContext,
        frame hf: ClackHandoverFrame,
        livePose: ClackPose,
        whiteOutline: Bool
    ) {
        ctx.saveGState()
        ctx.translateBy(x: 184.0, y: 236.0)
        ctx.scaleBy(x: 0.78, y: 0.78)
        ctx.translateBy(x: -231.0, y: -330.0)

        let stageClip = CGRect(x: hf.leftEdge, y: -320, width: hf.rightEdge - hf.leftEdge, height: 960)
        ctx.clip(to: stageClip)

        for actor in [hf.resident, hf.visitor].compactMap({ $0 }) {
            drawShadow(in: ctx, x: actor.x, y: actor.y, rx: 72, ry: 5.5, alpha: 0.20)
        }

        let order: [ClackHandoverActor?] = (hf.resident != nil && hf.resident!.y > hf.visitor.y)
            ? [hf.visitor, hf.resident]
            : [hf.resident, hf.visitor]
        for maybeActor in order {
            guard let actor = maybeActor else { continue }
            if actor.stand > 0 {
                drawWithOptionalStickerOutline(
                    in: ctx,
                    bounds: CGRect(x: actor.x - 145, y: actor.y - 255, width: 290, height: 275),
                    enabled: whiteOutline
                ) { subCtx in
                    drawStandingHandoverCat(in: subCtx, actor: actor)
                }
            } else {
                let sp = ClackHandoverDirector.blendWorkingPose(actor, livePose: livePose)
                let pal = ClackBreedPalette.resolve(coat: actor.breed, customSkin: actor.customSkin)
                drawWithOptionalStickerOutline(
                    in: ctx,
                    bounds: CGRect(x: 130, y: 120, width: 250, height: 230),
                    enabled: whiteOutline
                ) { subCtx in
                    drawSeatedTail(in: subCtx, pose: sp, pal: pal)
                    drawSeatedBody(in: subCtx, pose: sp, pal: pal)
                }
            }
        }
        ctx.restoreGState()
    }

    static func drawHandoverFrontOnKuroDesk(
        in ctx: CGContext,
        frame hf: ClackHandoverFrame,
        livePose: ClackPose,
        whiteOutline: Bool
    ) {
        let seatedActor: ClackHandoverActor? = [hf.resident, hf.visitor].compactMap({ $0 }).first(where: { $0.stand <= 0 })
        guard let actor = seatedActor else { return }

        ctx.saveGState()
        ctx.translateBy(x: 184.0, y: 236.0)
        ctx.scaleBy(x: 0.78, y: 0.78)
        ctx.translateBy(x: -231.0, y: -330.0)

        let sp = ClackHandoverDirector.blendWorkingPose(actor, livePose: livePose)
        let pal = ClackBreedPalette.resolve(coat: actor.breed, customSkin: actor.customSkin)
        drawWithOptionalStickerOutline(
            in: ctx,
            bounds: CGRect(x: 55, y: 40, width: 340, height: 325),
            enabled: whiteOutline
        ) { subCtx in
            drawReachingArm(in: subCtx, pose: sp, isLeft: true, pal: pal)
            drawReachingArm(in: subCtx, pose: sp, isLeft: false, pal: pal)
            drawCatHead(in: subCtx, pose: sp, pal: pal, tension: 0, profile: 0, bodyClip: nil)
        }
        ctx.restoreGState()
    }

    private static let stickerColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    private static func drawWithOptionalStickerOutline(
        in ctx: CGContext,
        bounds: CGRect,
        enabled: Bool,
        drawBlock: (CGContext) -> Void
    ) {
        guard enabled else {
            drawBlock(ctx)
            return
        }
        let scale: CGFloat = 2.0
        let pxW = max(1, Int(ceil(bounds.width * scale)))
        let pxH = max(1, Int(ceil(bounds.height * scale)))
        guard let off = CGContext(
            data: nil,
            width: pxW,
            height: pxH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: stickerColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            drawBlock(ctx)
            return
        }
        off.setAllowsAntialiasing(true)
        off.setShouldAntialias(true)
        off.setLineJoin(.round)
        off.setLineCap(.round)
        off.translateBy(x: 0, y: CGFloat(pxH))
        off.scaleBy(x: scale, y: -scale)
        off.translateBy(x: -bounds.minX, y: -bounds.minY)
        drawBlock(off)
        guard let img = off.makeImage() else {
            drawBlock(ctx)
            return
        }

        ctx.saveGState()
        ctx.translateBy(x: bounds.minX, y: bounds.maxY)
        ctx.scaleBy(x: 1.0, y: -1.0)
        let drawRect = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let r: CGFloat = 3.2
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for k in 0..<8 {
            let ang = CGFloat(k) * (.pi * 0.25)
            ctx.draw(img, in: drawRect.offsetBy(dx: cos(ang) * r, dy: sin(ang) * r))
        }
        ctx.setBlendMode(.sourceIn)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
        ctx.fill(drawRect.insetBy(dx: -r - 2, dy: -r - 2))
        ctx.endTransparencyLayer()
        ctx.draw(img, in: drawRect)
        ctx.restoreGState()
    }

    // MARK: - Basic Vector Helpers

    private static func M(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private static func W(_ a: [CGFloat], _ b: [CGFloat], _ t: CGFloat) -> [CGFloat] {
        [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
    }

    private static func ae(_ p0: [CGFloat], _ p1: [CGFloat], _ p2: [CGFloat], _ p3: [CGFloat]) -> [[CGFloat]] {
        let o = W(p0, p1, 0.5)
        let i = W(p1, p2, 0.5)
        let r = W(p2, p3, 0.5)
        let a = W(o, i, 0.5)
        let l = W(i, r, 0.5)
        return [o, a, W(a, l, 0.5), l, r, p3]
    }

    private static func roundedPoly(_ pts: [CGPoint], radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        guard pts.count >= 3 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
        }
        let start = mid(pts[pts.count - 1], pts[0])
        path.move(to: start)
        for idx in 0..<pts.count {
            let curr = pts[idx]
            let nextMid = mid(curr, pts[(idx + 1) % pts.count])
            path.addArc(tangent1End: curr, tangent2End: nextMid, radius: radius)
            path.addLine(to: nextMid)
        }
        path.closeSubpath()
        return path
    }

    private static func fillPath(_ ctx: CGContext, _ path: CGPath, _ color: NSColor) {
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()
    }

    private static func fillEllipse(_ ctx: CGContext, x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat, color: NSColor, rotation: CGFloat = 0) {
        ctx.saveGState()
        ctx.translateBy(x: x, y: y)
        if rotation != 0 { ctx.rotate(by: rotation) }
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        ctx.restoreGState()
    }

    private static func drawShadow(in ctx: CGContext, x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat, alpha: CGFloat) {
        guard rx > 0, ry > 0 else { return }
        let colors = [
            NSColor(srgbRed: 25/255, green: 23/255, blue: 27/255, alpha: alpha).cgColor,
            NSColor(srgbRed: 25/255, green: 23/255, blue: 27/255, alpha: 0).cgColor
        ] as CFArray
        let locs: [CGFloat] = [0, 1]
        guard let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locs) else { return }
        ctx.saveGState()
        ctx.translateBy(x: x, y: y)
        ctx.scaleBy(x: rx, y: ry)
        ctx.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        ctx.clip()
        ctx.drawRadialGradient(grad, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    private static func linearGradient(_ stops: [(CGFloat, NSColor)]) -> CGGradient? {
        let cols = stops.map { $0.1.cgColor } as CFArray
        let locs = stops.map { max(0, min(1, $0.0)) }
        return CGGradient(colorsSpace: colorSpace, colors: cols, locations: locs)
    }

    private static func fillPathWithLinearGradient(_ ctx: CGContext, path: CGPath, start: CGPoint, end: CGPoint, stops: [(CGFloat, NSColor)]) {
        guard let grad = linearGradient(stops) else { return }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(grad, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    private static func strokePathWithLinearGradient(_ ctx: CGContext, path: CGPath, lineWidth: CGFloat, start: CGPoint, end: CGPoint, stops: [(CGFloat, NSColor)]) {
        guard let grad = linearGradient(stops) else { return }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(grad, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    // MARK: - 3D Perspective Keyboard (`Qn`) & Mouse (`Zn`)

    private static func drawKeyboard(in ctx: CGContext, pose: ClackPose, showKeyLabels: Bool, nowMs: Double) {
        let kb = cachedKeyboard
        fillPath(ctx, kb.boardEdge, ClackBreedPalette.hex(0x232226))
        fillPath(ctx, kb.boardTop, ClackBreedPalette.hex(0x39373B))
        fillPath(ctx, kb.plate, ClackBreedPalette.hex(0xABA69D))

        for item in kb.caps {
            let k = item.key
            let isDown = pose.pressed.contains(k.code) || (nowMs - (pose.flashes[k.code] ?? 0) < 135.0)
            let mesh = isDown ? item.down : item.up
            let isAccent = (k.code == "Escape" || k.code == "Enter")

            let skirtCol = isDown ? 0xB6C36B : (isAccent ? 0xD8A358 : 0xD3CDBF)
            let frontCol = isDown ? 0x98A454 : (isAccent ? 0xB88948 : 0xB7B0A4)
            let topCol   = isDown ? 0xD8EA82 : (isAccent ? 0xF6BF60 : 0xFAF8F1)

            fillPath(ctx, mesh.skirt, ClackBreedPalette.hex(skirtCol))
            fillPath(ctx, mesh.front, ClackBreedPalette.hex(frontCol))
            fillPath(ctx, mesh.top, ClackBreedPalette.hex(topCol))

            if showKeyLabels && !k.label.isEmpty {
                ctx.saveGState()
                ctx.concatenate(CGAffineTransform(a: mesh.xx, b: mesh.xy, c: mesh.yx, d: mesh.yy, tx: mesh.center.x, ty: mesh.center.y))
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
                let fontSize: CGFloat = k.height < 6.0 ? 4.0 : 6.0
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                    .foregroundColor: ClackBreedPalette.hex(0x5C5752)
                ]
                let ns = NSAttributedString(string: k.label, attributes: attrs)
                let sz = ns.size()
                ns.draw(at: CGPoint(x: -sz.width * 0.5, y: -sz.height * 0.5))
                NSGraphicsContext.restoreGraphicsState()
                ctx.restoreGState()
            }
        }
    }

    private static func drawMouse(in ctx: CGContext, pose: ClackPose, nowMs: Double) {
        let base = ClackStageConst.unprojectDeck(CGPoint(x: pose.mouse.x, y: pose.mouse.y + 7.0))
        func o(_ dx: CGFloat, _ dy: CGFloat, _ z: CGFloat = 0) -> CGPoint {
            ClackStageConst.projectDeck(base.x + dx, base.y + dy, z)
        }
        let body = CGMutablePath()
        let a = o(0, -23, 10)
        let l = o(0, 27, 3)
        body.move(to: a)
        body.addCurve(to: o(21, -1, 8), control1: o(12, -23, 11), control2: o(21, -14, 11))
        body.addCurve(to: o(17, 17, 4), control1: o(21, 6, 7), control2: o(19, 13, 5))
        body.addCurve(to: l, control1: o(14, 24, 3), control2: o(7, 27, 3))
        body.addCurve(to: o(-17, 17, 4), control1: o(-7, 27, 3), control2: o(-14, 24, 3))
        body.addCurve(to: o(-21, -1, 8), control1: o(-19, 13, 5), control2: o(-21, 6, 7))
        body.addCurve(to: a, control1: o(-21, -14, 11), control2: o(-12, -23, 11))
        body.closeSubpath()

        ctx.saveGState()
        ctx.translateBy(x: 0, y: 2.7)
        fillPath(ctx, body, ClackBreedPalette.hex(0xA69E96))
        ctx.setStrokeColor(ClackBreedPalette.hex(0x625D5B).cgColor)
        ctx.setLineWidth(1.1)
        ctx.addPath(body)
        ctx.strokePath()
        ctx.restoreGState()

        let hCenter = o(-8, -12, 12)
        if let rGrad = linearGradient([
            (0.0, ClackBreedPalette.hex(0xFFFDF6)),
            (0.55, ClackBreedPalette.hex(0xF5F1E8)),
            (1.0, ClackBreedPalette.hex(0xDAD4CA))
        ]) {
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            ctx.drawRadialGradient(rGrad, startCenter: hCenter, startRadius: 1.0, endCenter: hCenter, endRadius: max(8, l.y - a.y), options: [.drawsAfterEndLocation])
            ctx.restoreGState()
        }

        func btnDown(_ code: String) -> Bool {
            pose.buttons.contains(code) || (nowMs - (pose.flashes[code] ?? 0) < 135.0)
        }
        let cMid = o(0, 0, 10)
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()

        for (code, side) in [("MouseLeft", CGFloat(1)), ("MouseRight", CGFloat(-1))] {
            let seam = CGMutablePath()
            seam.move(to: cMid)
            seam.addCurve(to: o(side * 24, 4, 6), control1: o(side * 6, 0, 10), control2: o(side * 13, 3, 8))
            let btn = CGMutablePath()
            btn.addPath(seam)
            btn.addLine(to: o(side * 26, 32))
            btn.addLine(to: o(0, 32))
            btn.addLine(to: l)
            btn.addCurve(to: cMid, control1: o(0, 20, 5), control2: o(0, 8, 10))
            btn.closeSubpath()
            fillPath(ctx, btn, btnDown(code) ? ClackBreedPalette.hex(0xD8E58E) : NSColor(srgbRed: 1, green: 253/255, blue: 247/255, alpha: 0.38))
            ctx.setStrokeColor(ClackBreedPalette.hex(0xCEC7BB).cgColor)
            ctx.setLineWidth(0.8)
            ctx.addPath(seam)
            ctx.strokePath()
        }

        let midLine = CGMutablePath()
        midLine.move(to: cMid)
        midLine.addCurve(to: l, control1: o(0, 8, 10), control2: o(0, 20, 5))
        ctx.setStrokeColor(ClackBreedPalette.hex(0xB6AEA3).cgColor)
        ctx.setLineWidth(1.05)
        ctx.addPath(midLine)
        ctx.strokePath()

        let pWheel = o(0, 15, 7.5)
        let gWheel = o(0, 18, 6.5)
        let wScale = max(0.2, o(1, 15, 7.5).x - pWheel.x)
        ctx.saveGState()
        ctx.translateBy(x: pWheel.x, y: pWheel.y)
        ctx.rotate(by: atan2(pWheel.x - gWheel.x, gWheel.y - pWheel.y))
        ctx.scaleBy(x: wScale, y: wScale)
        fillPath(ctx, CGPath(roundedRect: CGRect(x: -3, y: -5.2, width: 6, height: 10.4), cornerWidth: 3, cornerHeight: 3, transform: nil), ClackBreedPalette.hex(0x756B60))
        let wheelActive = ["MouseMiddle", "WheelUp", "WheelDown"].contains(where: btnDown)
        fillPath(ctx, CGPath(roundedRect: CGRect(x: -2.05, y: -4.45, width: 4.1, height: 8.4), cornerWidth: 2.05, cornerHeight: 2.05, transform: nil), ClackBreedPalette.hex(wheelActive ? 0xB58A3D : 0xE0B56B))
        ctx.restoreGState()
        ctx.restoreGState()

        ctx.setStrokeColor(ClackBreedPalette.hex(0x7D766E).cgColor)
        ctx.setLineWidth(0.95)
        ctx.addPath(body)
        ctx.strokePath()
    }

    // MARK: - Tabby Markings (`re`, `Ze`, `je`, `jn`) & Seated Cat (`ts`, `en`, `Ms`, `ns`)

    private static func tabbyLegStops(pal: ClackBreedPalette, isRight: Bool, farBlend: CGFloat = 0) -> [(CGFloat, NSColor)] {
        let baseFur = ClackBreedPalette.lerpColor(pal.fur, pal.isSilverTabby ? ClackBreedPalette.hex(0x9FA5A0) : ClackBreedPalette.hex(0xBE8046), farBlend)
        let bandCol = ClackBreedPalette.lerpColor(
            pal.isSilverTabby ? ClackBreedPalette.hex(0x555A5C) : ClackBreedPalette.hex(0xBF7C40),
            pal.isSilverTabby ? ClackBreedPalette.hex(0x464B4D) : ClackBreedPalette.hex(0xA66D39),
            farBlend
        )
        let sockCol = ClackBreedPalette.lerpColor(pal.bibCream, pal.isSilverTabby ? ClackBreedPalette.hex(0xE2E5E2) : ClackBreedPalette.hex(0xEDDEC6), farBlend)
        let l: CGFloat = isRight ? 0.71 : 0.80
        return [
            (0.0, baseFur), (0.31, baseFur),
            (0.33, bandCol), (0.38, bandCol),
            (0.40, baseFur), (0.52, baseFur),
            (0.54, bandCol), (0.58, bandCol),
            (0.60, baseFur), (l, baseFur),
            (l + 0.018, sockCol), (1.0, sockCol)
        ]
    }

    private static func drawTabbyTailRings(in ctx: CGContext, pal: ClackBreedPalette, p0: [CGFloat], p1: [CGFloat], p2: [CGFloat], p3: [CGFloat], width: CGFloat) {
        func eval(_ t: CGFloat) -> CGPoint {
            let u = 1.0 - t
            return CGPoint(
                x: u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
                y: u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1]
            )
        }
        ctx.saveGState()
        ctx.setLineWidth(width)
        ctx.setLineCap(.butt)
        for (a, l, col) in [(CGFloat(0.08), CGFloat(0.24), pal.stripeDark), (0.46, 0.64, pal.stripeDark), (0.82, 1.0, pal.tailTipLight)] {
            ctx.beginPath()
            ctx.move(to: eval(a))
            for step in 1...8 {
                ctx.addLine(to: eval(a + (l - a) * CGFloat(step) / 8.0))
            }
            ctx.setStrokeColor(col.cgColor)
            ctx.strokePath()
        }
        fillEllipse(ctx, x: p3[0], y: p3[1], rx: width * 0.5, ry: width * 0.5, color: pal.tailTipLight)
        ctx.restoreGState()
    }

    // Exact port of `function je(t, e, n)` — white chest bib + 6 tabby side stripes clipped outside bib!
    private static func drawTabbyBodyBibAndStripes(in ctx: CGContext, pal: ClackBreedPalette, standBlend e: CGFloat, mapPt: (CGFloat, CGFloat) -> CGPoint) {
        func s(_ o: CGFloat, _ i: CGFloat, _ r: CGFloat, _ a: CGFloat) -> CGPoint {
            mapPt(o + (r - o) * e, i + (a - i) * e)
        }
        let bib = CGMutablePath()
        bib.move(to: s(-46, -190, 64, -141))
        bib.addCurve(to: s(-13, -109, 60, -98), control1: s(-32, -155, 67, -122), control2: s(-16, -145, 62, -107))
        bib.addCurve(to: s(-38, 3, 58, -75), control1: s(-12, -41, 58, -92), control2: s(-26, -18, 57, -83))
        bib.addLine(to: s(37, 3, 80, -73))
        bib.addLine(to: s(13, -109, 97, -79))
        bib.addQuadCurve(to: s(48, -190, 86, -143), control: s(16, -144, 106, -98))
        bib.closeSubpath()

        fillPath(ctx, bib, pal.bibCream)

        // Even-odd exterior clip so side stripes never cross into the white chest bib!
        ctx.saveGState()
        let exterior = CGMutablePath()
        exterior.addRect(CGRect(x: -2048, y: -2048, width: 4096, height: 4096))
        exterior.addPath(bib)
        ctx.addPath(exterior)
        ctx.clip(using: .evenOdd)

        ctx.setFillColor(pal.stripeMid.cgColor)
        for side in [-1.0, 1.0] as [CGFloat] {
            for idx in 0..<3 {
                let r = -130.0 + 23.0 * CGFloat(idx)
                let a = -65.0 + 27.0 * CGFloat(idx) + (side + 1.0) * 7.0
                let st = CGMutablePath()
                st.move(to: s(side * 72, r, a, -192))
                st.addQuadCurve(to: s(side * 38, r + 12, a + 7, -124 + CGFloat(idx % 2) * 11), control: s(side * 53, r + 15, a - 6, -148))
                st.addQuadCurve(to: s(side * 73, r + 9, a + 13, -192), control: s(side * 55, r + 24, a + 10, -152))
                st.closeSubpath()
                ctx.addPath(st)
                ctx.fillPath()
            }
        }
        ctx.restoreGState()
    }

    private static func drawSeatedTail(in ctx: CGContext, pose: ClackPose, pal: ClackBreedPalette) {
        let s = pose.tail * 0.28
        let o = pose.tailTip * 0.38
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 282, y: 288))
        path.addCurve(to: CGPoint(x: 325, y: 279 + s), control1: CGPoint(x: 304, y: 289), control2: CGPoint(x: 314, y: 297))
        path.addCurve(to: CGPoint(x: 363, y: 252 + o), control1: CGPoint(x: 335, y: 262 + s), control2: CGPoint(x: 343, y: 252 + o))

        ctx.saveGState()
        ctx.setStrokeColor(pal.edge.cgColor)
        ctx.setLineWidth(18.5)
        ctx.addPath(path)
        ctx.strokePath()

        ctx.setStrokeColor((pal.point ?? pal.fur).cgColor)
        ctx.setLineWidth(17.0)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        if pal.tabby {
            drawTabbyTailRings(in: ctx, pal: pal, p0: [325, 279 + s], p1: [335, 262 + s], p2: [343, 252 + o], p3: [363, 252 + o], width: 17.0)
        }
    }

    private struct HindFootCurves {
        let start: [CGFloat]
        let toe: [CGFloat]
        let end: [CGFloat]
        let curves: [[CGFloat]]
        let marking: [CGFloat]
    }

    private static func makeHindFoot(_ t: [CGFloat], _ e: [CGFloat], _ n: [CGFloat], _ s: [CGFloat], _ o: [CGFloat], _ i: [CGFloat], _ r: [CGFloat]) -> HindFootCurves {
        let a = ae(t, e, n, s) + [W(s, o, 2.0 / 3.0), W(i, o, 2.0 / 3.0), i]
        return HindFootCurves(start: t, toe: s, end: i, curves: a, marking: r)
    }

    private static let hindFeet = (
        left: makeHindFoot([175, 314], [169, 325], [178, 333], [188, 330], [195, 329], [194, 322], [183, 325]),
        right: makeHindFoot([265, 322], [264, 332], [276, 334], [283, 327], [288, 323], [284, 315], [277, 325])
    )

    private static func drawPawMarking(_ ctx: CGContext, pal: ClackBreedPalette, x: CGFloat, y: CGFloat) {
        if pal.tabby {
            fillEllipse(ctx, x: x, y: y, rx: 14, ry: 14, color: pal.bibCream)
            return
        }
        guard let pt = pal.point else { return }
        let p = CGPath(ellipseIn: CGRect(x: x - 12, y: y - 10, width: 24, height: 20), transform: nil)
        fillPathWithLinearGradient(ctx, path: p, start: CGPoint(x: 0, y: y - 12), end: CGPoint(x: 0, y: y + 2), stops: [
            (0.0, pal.fur), (0.6, ClackBreedPalette.hex(0x765E4C)), (1.0, pt)
        ])
    }

    private static func drawSeatedBody(in ctx: CGContext, pose: ClackPose, pal: ClackBreedPalette, warp: ((CGFloat, CGFloat, Bool) -> CGPoint)? = nil) {
        let mapS: (CGFloat, CGFloat, Bool) -> CGPoint = warp ?? { x, y, _ in CGPoint(x: x, y: y) }
        func o(_ u: CGFloat, _ d: CGFloat) -> CGPoint {
            let c = ClackSimulation.spineWeight(d)
            return mapS(u + c * pose.trunk.x, d + c * (pose.trunk.y + pose.breath), false)
        }
        let headOff = CGPoint(x: pose.headLean.x + pose.turn * 1.35, y: pose.headLean.y + pose.gaze.y * 0.65)
        let path = CGMutablePath()
        path.move(to: mapS(190 + headOff.x, 148 + headOff.y + pose.breath, false))
        path.addCurve(to: o(163, 254), control1: o(185, 183), control2: o(169, 216))
        path.addCurve(to: mapS(hindFeet.left.start[0], hindFeet.left.start[1], false), control1: o(158, 277), control2: o(161, 302))

        for idx in stride(from: 0, to: hindFeet.left.curves.count, by: 3) {
            let c1 = hindFeet.left.curves[idx], c2 = hindFeet.left.curves[idx + 1], c3 = hindFeet.left.curves[idx + 2]
            path.addCurve(to: mapS(c3[0], c3[1], false), control1: mapS(c1[0], c1[1], false), control2: mapS(c2[0], c2[1], false))
        }
        path.addCurve(
            to: mapS(hindFeet.right.start[0], hindFeet.right.start[1], false),
            control1: mapS(209, 326, true),
            control2: mapS(249, 326, true)
        )
        for idx in stride(from: 0, to: hindFeet.right.curves.count, by: 3) {
            let c1 = hindFeet.right.curves[idx], c2 = hindFeet.right.curves[idx + 1], c3 = hindFeet.right.curves[idx + 2]
            path.addCurve(to: mapS(c3[0], c3[1], false), control1: mapS(c1[0], c1[1], false), control2: mapS(c2[0], c2[1], false))
        }
        path.addCurve(to: o(294, 229), control1: o(304, 295), control2: o(304, 260))
        path.addCurve(to: mapS(271 + headOff.x, 148 + headOff.y + pose.breath, false), control1: o(288, 209), control2: o(277, 176))
        path.closeSubpath()

        fillPath(ctx, path, pal.fur)
        ctx.saveGState()
        ctx.setStrokeColor(pal.edge.cgColor)
        ctx.setLineWidth(1.0)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        if pal.point != nil || pal.tabby {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            if pal.tabby {
                drawTabbyBodyBibAndStripes(in: ctx, pal: pal, standBlend: 0) { u, d in o(231 + u, 330 + d) }
            }
            drawPawMarking(ctx, pal: pal, x: hindFeet.left.marking[0], y: hindFeet.left.marking[1])
            drawPawMarking(ctx, pal: pal, x: hindFeet.right.marking[0], y: hindFeet.right.marking[1])
            ctx.restoreGState()
        }
    }

    // MARK: - Reaching Front Arms (`Ms`, `sn`, `ns`, `rn`)

    private static func shoulderPoint(_ pose: ClackPose, isLeft: Bool) -> CGPoint {
        let w = ClackSimulation.spineWeight(211)
        return CGPoint(
            x: (isLeft ? 200.0 : 265.0) + pose.trunk.x * w,
            y: 211.0 + (pose.trunk.y + pose.breath) * w
        )
    }

    private struct ArmGeometry {
        let left: [CGFloat], curveLeft: [CGFloat], wristLeft: [CGFloat], tipLeft: [CGFloat]
        let tipRight: [CGFloat], wristRight: [CGFloat], curveRight: [CGFloat], right: [CGFloat]
        let width: CGFloat
        let direction: CGPoint
    }

    private static func computeArmGeometry(start t: CGPoint, control e: CGPoint, paw n: CGPoint, grip s: CGFloat = 0, slim o: CGFloat = 0) -> ArmGeometry {
        let i = max(1.0, hypot(e.x - t.x, e.y - t.y))
        let r = max(1.0, hypot(n.x - e.x, n.y - e.y))
        let a = CGPoint(x: (e.x - t.x) / i, y: (e.y - t.y) / i)
        let l = CGPoint(x: (n.x - e.x) / r, y: (n.y - e.y) / r)
        let h = 10.2 - 2.4 * o
        let u = 15.0 + 7.0 * s
        let d = 6.5 + 1.2 * s
        let c = [t.x - a.y * u, t.y + a.x * u]
        let f = [t.x + a.y * u, t.y - a.x * u]
        let p = [e.x - (a.y + l.y) * d, e.y + (a.x + l.x) * d]
        let g = [2.0 * e.x - p[0], 2.0 * e.y - p[1]]
        let x = [n.x - l.y * h, n.y + l.x * h]
        let y = [n.x + l.y * h, n.y - l.x * h]
        let b = [x[0] + l.x * 14.0, x[1] + l.y * 14.0]
        let m = [y[0] + l.x * 14.0, y[1] + l.y * 14.0]
        return ArmGeometry(left: c, curveLeft: p, wristLeft: x, tipLeft: b, tipRight: m, wristRight: y, curveRight: g, right: f, width: h, direction: l)
    }

    private static func drawReachingArm(in ctx: CGContext, pose: ClackPose, isLeft: Bool, pal: ClackBreedPalette) {
        let start = shoulderPoint(pose, isLeft: isLeft)
        let paw = isLeft ? pose.left.point : pose.right.point
        let restY = isLeft ? ClackStageConst.pawRestLeft.y : ClackStageConst.pawRestRight.y
        let o = pose.keyboardReady * max(0, min(1, (restY - paw.y) / 48.0))
        let defaultCtrl = CGPoint(
            x: (start.x + paw.x) * 0.5 + (isLeft ? -1.0 : 1.0) * (4.0 + 20.0 * o),
            y: (start.y + paw.y) * 0.5 + 9.0 + 27.0 * o
        )
        let grip = isLeft ? (min(1.0, pose.mouseReach / 0.85) * max(0, min(1, (start.x - paw.x - 8.0) / 42.0))) : 0.0
        let ctrl: CGPoint
        if !isLeft || grip <= 0 {
            ctrl = defaultCtrl
        } else {
            let ax = start.x - paw.x, ay = start.y - paw.y
            let h = max(1.0, hypot(ax, ay))
            let u = 0.13 * sqrt(max(0, 98.0 * 98.0 - (h * 0.5) * (h * 0.5)))
            let gripCtrl = CGPoint(
                x: (start.x + paw.x) * 0.5 + 2.0 * ay / h * u,
                y: (start.y + paw.y) * 0.5 - 2.0 * ax / h * u
            )
            ctrl = CGPoint(
                x: defaultCtrl.x + (gripCtrl.x - defaultCtrl.x) * grip,
                y: defaultCtrl.y + (gripCtrl.y - defaultCtrl.y) * grip
            )
        }

        let geom = computeArmGeometry(start: start, control: ctrl, paw: paw, grip: grip, slim: 0)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: geom.left[0], y: geom.left[1]))
        path.addQuadCurve(to: CGPoint(x: geom.wristLeft[0], y: geom.wristLeft[1]), control: CGPoint(x: geom.curveLeft[0], y: geom.curveLeft[1]))
        path.addCurve(
            to: CGPoint(x: geom.wristRight[0], y: geom.wristRight[1]),
            control1: CGPoint(x: geom.tipLeft[0], y: geom.tipLeft[1]),
            control2: CGPoint(x: geom.tipRight[0], y: geom.tipRight[1])
        )
        path.addQuadCurve(to: CGPoint(x: geom.right[0], y: geom.right[1]), control: CGPoint(x: geom.curveRight[0], y: geom.curveRight[1]))

        if grip > 0 {
            let m = geom.width + 2.0 * grip
            let pad = CGMutablePath()
            pad.move(to: CGPoint(x: -31, y: 8))
            pad.addCurve(to: CGPoint(x: -5, y: m), control1: CGPoint(x: -18, y: 8), control2: CGPoint(x: -13, y: m))
            pad.addLine(to: CGPoint(x: 0, y: m))
            pad.addCurve(to: CGPoint(x: 0, y: -m), control1: CGPoint(x: 14, y: m), control2: CGPoint(x: 14, y: -m))
            pad.addLine(to: CGPoint(x: -5, y: -m))
            pad.addCurve(to: CGPoint(x: -31, y: -8), control1: CGPoint(x: -13, y: -m), control2: CGPoint(x: -18, y: -8))
            pad.closeSubpath()
            let xf = CGAffineTransform(a: geom.direction.x, b: geom.direction.y, c: -geom.direction.y, d: geom.direction.x, tx: paw.x, ty: paw.y)
            path.addPath(pad, transform: xf)
        }

        paintArmPath(in: ctx, path: path, start: start, control: ctrl, end: paw, width: geom.width, pal: pal, landingOpt: nil, isRight: !isLeft)
    }

    private struct LandingArmGradOpt {
        let amount: CGFloat
        let far: Bool
        let top: CGFloat
        let bottom: CGFloat
    }

    private static func paintArmPath(
        in ctx: CGContext,
        path: CGPath,
        start n: CGPoint,
        control s: CGPoint,
        end o: CGPoint,
        width i: CGFloat,
        pal r: ClackBreedPalette,
        landingOpt l: LandingArmGradOpt?,
        isRight h: Bool
    ) {
        let u = l?.amount ?? 0
        let d = 1.0 - u
        let spine = CGMutablePath()
        spine.move(to: n)
        spine.addQuadCurve(to: o, control: s)

        let edgeRGB: (CGFloat, CGFloat, CGFloat)
        if r.tabby {
            edgeRGB = (142.0 / 255.0, 96.0 / 255.0, 62.0 / 255.0)
        } else if r.point != nil {
            edgeRGB = (104.0 / 255.0, 84.0 / 255.0, 68.0 / 255.0)
        } else {
            edgeRGB = (234.0 / 255.0, 232.0 / 255.0, 227.0 / 255.0)
        }
        let strokeStops: [(CGFloat, NSColor)] = [
            (0.28, NSColor(srgbRed: edgeRGB.0, green: edgeRGB.1, blue: edgeRGB.2, alpha: 0)),
            (0.55, NSColor(srgbRed: edgeRGB.0, green: edgeRGB.1, blue: edgeRGB.2, alpha: 0.65)),
            (1.0, (r.point != nil || r.tabby) ? r.edge : ClackBreedPalette.hex(0xEEECE6))
        ]
        if d > 0.001 {
            ctx.saveGState()
            ctx.setAlpha(d)
            strokePathWithLinearGradient(ctx, path: path, lineWidth: 3.6, start: n, end: o, stops: strokeStops)
            strokePathWithLinearGradient(ctx, path: spine, lineWidth: (i * 2.0 + 3.6) * d, start: n, end: o, stops: strokeStops)
            ctx.restoreGState()
        }

        // Fill + core spine
        let bottomY = l?.bottom ?? o.y
        if r.tabby {
            let g0 = W([n.x, n.y], [o.x, bottomY - 66.0], u)
            let g1 = CGPoint(x: o.x, y: o.y + (bottomY - o.y) * u)
            let stops = tabbyLegStops(pal: r, isRight: h, farBlend: (l?.far == true) ? u : 0)
            fillPathWithLinearGradient(ctx, path: path, start: CGPoint(x: g0[0], y: g0[1]), end: g1, stops: stops)
            if d > 0.001 {
                strokePathWithLinearGradient(ctx, path: spine, lineWidth: i * 2.0 * d, start: CGPoint(x: g0[0], y: g0[1]), end: g1, stops: stops)
            }
        } else if r.point != nil || (l?.far == true && u > 0) {
            let far = l?.far ?? false
            func a(_ p0: CGFloat, _ p1: CGFloat) -> CGFloat { p0 + (p1 - p0) * u }
            let gs = CGPoint(x: a(n.x, o.x), y: a(n.y, l?.top ?? n.y))
            let ge = CGPoint(x: o.x, y: a(o.y, l?.bottom ?? o.y))
            let stops: [(CGFloat, NSColor)]
            if let pt = r.point {
                let hFar = far ? max(0, (u - 0.9) * 10.0) : 0
                stops = [
                    (0.0, ClackBreedPalette.lerpColor(r.fur, ClackBreedPalette.hex(0xB49A81), hFar)),
                    (a(0.22, 0.20), ClackBreedPalette.lerpColor(r.fur, ClackBreedPalette.hex(0xB1987E), hFar)),
                    (a(0.49, 0.57), ClackBreedPalette.lerpColor(ClackBreedPalette.hex(0xD4C2AC), far ? ClackBreedPalette.hex(0xAC9178) : r.fur, u)),
                    (a(0.76, 0.85), ClackBreedPalette.lerpColor(ClackBreedPalette.hex(0x856A55), ClackBreedPalette.hex(far ? 0x705945 : 0xB8A18A), u)),
                    (a(0.98, 1.0), ClackBreedPalette.lerpColor(pt, ClackBreedPalette.hex(far ? 0x584333 : 0x79614C), u))
                ]
            } else {
                stops = [
                    (0.0, ClackBreedPalette.lerpColor(r.fur, ClackBreedPalette.hex(0x211F22), u)),
                    (1.0, ClackBreedPalette.lerpColor(r.fur, ClackBreedPalette.hex(0x171619), u))
                ]
            }
            fillPathWithLinearGradient(ctx, path: path, start: gs, end: ge, stops: stops)
            if d > 0.001 {
                strokePathWithLinearGradient(ctx, path: spine, lineWidth: i * 2.0 * d, start: gs, end: ge, stops: stops)
            }
        } else {
            fillPath(ctx, path, r.fur)
            if d > 0.001 {
                ctx.saveGState()
                ctx.setStrokeColor(r.fur.cgColor)
                ctx.setLineWidth(i * 2.0 * d)
                ctx.addPath(spine)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }

        if let lOpt = l, u > 0.001 {
            let bAlpha = max(0, (u - 0.83) / 0.17)
            let stops: [(CGFloat, NSColor)] = [
                (0.0, r.edge.withAlphaComponent(bAlpha)),
                (0.18 + 0.42 * d, r.edge),
                (1.0, r.edge)
            ]
            ctx.saveGState()
            ctx.setAlpha(u)
            strokePathWithLinearGradient(ctx, path: path, lineWidth: lOpt.far ? 1.7 : 1.9, start: n, end: o, stops: stops)
            ctx.restoreGState()
        }
    }

    // MARK: - 3D Head, Ears, Siamese Mask, Tabby Forehead, Fierce Duel Eyes & Puffy Whisker Pads (`nn` & `es`)

    private struct EarPoints {
        let side: CGFloat
        let pointFn: (CGFloat, CGFloat, CGFloat) -> [CGFloat]
        var outer: [CGFloat]
        var outerBase: [CGFloat]
        var outerTip: [CGFloat]
        var temple: [CGFloat]
        var inner: [CGFloat]
        var innerBase: [CGFloat]
        var innerTip: [CGFloat]
        var tip: [CGFloat]
    }

    private static func make3DProjector(yaw: CGFloat, pitch: CGFloat) -> (
        project: (CGFloat, CGFloat, CGFloat) -> [CGFloat],
        contour: (CGFloat, CGFloat, CGFloat) -> [CGFloat],
        crownControl: [CGFloat],
        cy: CGFloat,
        cp: CGFloat
    ) {
        let n = cos(yaw), s = sin(yaw)
        let o = cos(pitch), i = sin(pitch)
        let r = hypot(n, 0.76 * s)
        let project: (CGFloat, CGFloat, CGFloat) -> [CGFloat] = { h, u, d in
            [h * n + d * s, u * o + (d * n - h * s) * i]
        }
        let contour: (CGFloat, CGFloat, CGFloat) -> [CGFloat] = { h, u, d in
            [h * r + d * s, u * o + (d * n - h * s) * i]
        }
        return (project, contour, contour(0, -38, -9), n, o)
    }

    private static func makeEar(project: @escaping (CGFloat, CGFloat, CGFloat) -> [CGFloat], side: CGFloat, earOffset: CGFloat) -> EarPoints {
        let sFn: (CGFloat, CGFloat, CGFloat) -> [CGFloat] = { a, l, h in
            let u = max(0, (-36.0 - l) / 23.0) * earOffset
            let d = -5.0 - (a - 34.0) * 0.5 + (l + 28.0) * 0.22 + h
            return project(side * a + 0.38 * u, l, d - side * 0.4 * u)
        }
        let o = sFn(50, -14, 0)
        let i = project(side * 57, 2, -3)
        let r = [o[0] + (o[0] - i[0]) * 0.75, o[1] + (o[1] - i[1]) * 0.75]
        return EarPoints(
            side: side,
            pointFn: sFn,
            outer: o,
            outerBase: r,
            outerTip: sFn(47, -57, 0),
            temple: i,
            inner: sFn(16, -34, 0),
            innerBase: sFn(20, -36, 0),
            innerTip: sFn(36, -61, 0),
            tip: sFn(41, -59, 0)
        )
    }

    private static func appendEarCurve(_ path: CGMutablePath, _ ear: EarPoints, outerFirst: Bool) {
        if outerFirst {
            path.addCurve(to: CGPoint(x: ear.tip[0], y: ear.tip[1]), control1: CGPoint(x: ear.outerBase[0], y: ear.outerBase[1]), control2: CGPoint(x: ear.outerTip[0], y: ear.outerTip[1]))
            path.addCurve(to: CGPoint(x: ear.inner[0], y: ear.inner[1]), control1: CGPoint(x: ear.innerTip[0], y: ear.innerTip[1]), control2: CGPoint(x: ear.innerBase[0], y: ear.innerBase[1]))
        } else {
            path.addCurve(to: CGPoint(x: ear.tip[0], y: ear.tip[1]), control1: CGPoint(x: ear.innerBase[0], y: ear.innerBase[1]), control2: CGPoint(x: ear.innerTip[0], y: ear.innerTip[1]))
            path.addCurve(to: CGPoint(x: ear.outer[0], y: ear.outer[1]), control1: CGPoint(x: ear.outerTip[0], y: ear.outerTip[1]), control2: CGPoint(x: ear.outerBase[0], y: ear.outerBase[1]))
        }
    }

    private static func drawEye(
        in ctx: CGContext,
        pose: ClackPose,
        side n: CGFloat,
        center: [CGFloat],
        scaleX: CGFloat,
        scaleY: CGFloat,
        irisColor: NSColor,
        tension a: CGFloat,
        profile l: CGFloat
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center[0], y: center[1])
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.rotate(by: (n < 0 ? 0.12 : -0.10) * (1.0 - l))

        let openH = 1.0 - pose.closed
        if openH < 0.08 {
            let line = CGMutablePath()
            line.move(to: CGPoint(x: -13, y: 2))
            line.addQuadCurve(to: CGPoint(x: 13, y: 1), control: CGPoint(x: 0, y: 7.5))
            ctx.setStrokeColor(irisColor.cgColor)
            ctx.setLineWidth(1.35)
            ctx.addPath(line)
            ctx.strokePath()
        } else {
            ctx.scaleBy(x: 1.0, y: max(0.08, openH))
            let u = -23.0 + 20.0 * a
            let d = n * (11.0 + 4.0 * l) * a
            if a > 0 {
                let browClip = CGMutablePath()
                browClip.move(to: CGPoint(x: -21, y: u + d))
                browClip.addLine(to: CGPoint(x: 21, y: u - d))
                browClip.addLine(to: CGPoint(x: 21, y: 20))
                browClip.addLine(to: CGPoint(x: -21, y: 20))
                browClip.closeSubpath()
                ctx.addPath(browClip)
                ctx.clip()
            }
            let irisRect = CGRect(x: -16.4, y: -14.7, width: 32.8, height: 29.4)
            ctx.setFillColor(irisColor.cgColor)
            ctx.fillEllipse(in: irisRect)

            ctx.saveGState()
            ctx.addEllipse(in: irisRect)
            ctx.clip()
            fillEllipse(ctx, x: pose.gaze.x * 1.05, y: pose.gaze.y * 1.05, rx: 5.3, ry: 10.1, color: ClackBreedPalette.hex(0x151518))
            if a > 0 {
                ctx.beginPath()
                ctx.move(to: CGPoint(x: -21, y: u + d))
                ctx.addLine(to: CGPoint(x: 21, y: u - d))
                ctx.setStrokeColor(ClackBreedPalette.hex(0x2E2422).cgColor)
                ctx.setLineWidth(3.0 * a)
                ctx.strokePath()
            }
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    // Exact port of `function nn(t, e, n, s=0, o=0, i)`
    private static func drawCatHead(
        in ctx: CGContext,
        pose e: ClackPose,
        pal n: ClackBreedPalette,
        tension s: CGFloat,
        profile o: CGFloat,
        bodyClip: (path: CGPath, ctm: CGAffineTransform)?
    ) {
        ctx.saveGState()
        let rLean = CGPoint(x: e.headLean.x + e.turn * 1.35, y: e.headLean.y + e.gaze.y * 0.65)
        ctx.translateBy(x: 231.0 + rLean.x, y: 126.0 + rLean.y + e.breath)
        ctx.rotate(by: e.turn * 0.008 + e.headLean.x * 0.00035)

        let proj = make3DProjector(yaw: e.headYaw, pitch: e.headPitch)
        func c(_ v: [CGFloat], _ px: CGFloat, _ py: CGFloat) -> [CGFloat] {
            o == 0 ? v : [v[0] + (px - v[0]) * o, v[1] + (py - v[1]) * o]
        }

        var f = makeEar(project: proj.project, side: -1, earOffset: e.earLeft)
        var p = makeEar(project: proj.project, side: 1, earOffset: e.earRight)
        if o > 0 {
            f.temple = c(f.temple, -46, 9); f.outer = c(f.outer, -35, -7); f.outerBase = c(f.outerBase, -37, -17)
            f.outerTip = c(f.outerTip, -40, -51); f.tip = c(f.tip, -34, -55); f.innerTip = c(f.innerTip, -29, -59)
            f.innerBase = c(f.innerBase, -10, -43); f.inner = c(f.inner, 1, -32)
            p.inner = c(p.inner, -7, -42); p.innerBase = c(p.innerBase, -4, -52); p.innerTip = c(p.innerTip, 1, -66)
            p.tip = c(p.tip, 9, -62); p.outerTip = c(p.outerTip, 15, -60); p.outerBase = c(p.outerBase, 27, -42)
            p.outer = c(p.outer, 30, -32); p.temple = c(p.temple, 44, -22)
        }

        let xJawL = c(proj.contour(-49, 42, 5), -34, 47)
        let cJawL = c(proj.contour(-62, 26, 0), -52, 37)
        let crown = c(proj.crownControl, -2, -38)
        let bJawR = c(proj.contour(49, 40, 5), 39, 24)
        let mJawR = c(proj.contour(61, 23, 0), 46, -4)
        let tChinR = c(proj.contour(36, 56, 12), 33, 48)
        let wChinL = c(proj.contour(-34, 58, 12), -13, 51)

        let upperArc = CGMutablePath()
        upperArc.move(to: CGPoint(x: f.outer[0], y: f.outer[1]))
        appendEarCurve(upperArc, f, outerFirst: true)
        upperArc.addQuadCurve(to: CGPoint(x: p.inner[0], y: p.inner[1]), control: CGPoint(x: crown[0], y: crown[1]))
        appendEarCurve(upperArc, p, outerFirst: false)
        upperArc.addCurve(to: CGPoint(x: bJawR[0], y: bJawR[1]), control1: CGPoint(x: p.temple[0], y: p.temple[1]), control2: CGPoint(x: mJawR[0], y: mJawR[1]))

        let headOpen = CGMutablePath()
        headOpen.move(to: CGPoint(x: xJawL[0], y: xJawL[1]))
        headOpen.addCurve(to: CGPoint(x: f.outer[0], y: f.outer[1]), control1: CGPoint(x: cJawL[0], y: cJawL[1]), control2: CGPoint(x: f.temple[0], y: f.temple[1]))
        appendEarCurve(headOpen, f, outerFirst: true)
        headOpen.addQuadCurve(to: CGPoint(x: p.inner[0], y: p.inner[1]), control: CGPoint(x: crown[0], y: crown[1]))
        appendEarCurve(headOpen, p, outerFirst: false)
        headOpen.addCurve(to: CGPoint(x: bJawR[0], y: bJawR[1]), control1: CGPoint(x: p.temple[0], y: p.temple[1]), control2: CGPoint(x: mJawR[0], y: mJawR[1]))

        if o < 1.0 {
            ctx.saveGState()
            ctx.setAlpha(1.0 - o)
            ctx.setStrokeColor(n.edge.cgColor)
            ctx.setLineWidth(0.85)
            ctx.addPath(headOpen)
            ctx.strokePath()
            ctx.restoreGState()
        }

        let headFull = CGMutablePath()
        headFull.addPath(headOpen)
        headFull.addCurve(to: CGPoint(x: xJawL[0], y: xJawL[1]), control1: CGPoint(x: tChinR[0], y: tChinR[1]), control2: CGPoint(x: wChinL[0], y: wChinL[1]))
        headFull.closeSubpath()

        fillPath(ctx, headFull, n.fur)

        if o > 0 {
            ctx.saveGState()
            ctx.setAlpha(o)
            if let bc = bodyClip {
                let headInv = ctx.ctm.inverted()
                let bodyToHead = bc.ctm.concatenating(headInv)
                let mask = CGMutablePath()
                mask.addRect(CGRect(x: -350, y: -350, width: 700, height: 700))
                mask.addPath(bc.path, transform: bodyToHead)
                ctx.addPath(mask)
                ctx.clip(using: .evenOdd)
            }
            let chinArc = CGMutablePath()
            chinArc.move(to: CGPoint(x: bJawR[0], y: bJawR[1]))
            chinArc.addCurve(to: CGPoint(x: xJawL[0], y: xJawL[1]), control1: CGPoint(x: tChinR[0], y: tChinR[1]), control2: CGPoint(x: wChinL[0], y: wChinL[1]))
            ctx.setStrokeColor(n.edge.cgColor)
            ctx.setLineWidth(1.9)
            ctx.addPath(chinArc)
            ctx.strokePath()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setAlpha(o)
            ctx.setStrokeColor(n.edge.cgColor)
            ctx.setLineWidth(1.9)
            ctx.addPath(upperArc)
            ctx.strokePath()
            ctx.restoreGState()
        }

        let P = e.gaze.y * 0.55 + 6.0 * e.keyboardReady
        let sinYaw = sin(e.headYaw)

        // Siamese dark roasted face mask + ears + nose!
        if let ptCol = n.point {
            ctx.saveGState()
            ctx.addPath(headFull)
            ctx.clip()

            ctx.saveGState()
            let maskCenter = c(proj.project(0, P + 6, 17), 31, 18)
            ctx.translateBy(x: maskCenter[0], y: maskCenter[1])
            ctx.scaleBy(x: 54.0 * proj.cy + (47.0 - 54.0 * proj.cy) * o, y: max(1, 38.0 * proj.cp))
            if let rGrad = linearGradient([
                (0.0, ptCol),
                (0.48, ClackBreedPalette.hex(0x453126)),
                (0.72, ClackBreedPalette.hex(0x846B58)),
                (1.0, ClackBreedPalette.hex(0xEEE2CF, alpha: 0))
            ]) {
                ctx.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
                ctx.clip()
                ctx.drawRadialGradient(rGrad, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [.drawsAfterEndLocation])
            }
            ctx.restoreGState()

            // Cute pale Siamese nose highlight
            let nose = c(proj.project(0, P + 14, 24), 38, 26)
            let nw = 3.1 * proj.cy
            let nosePath = CGMutablePath()
            nosePath.move(to: CGPoint(x: nose[0] - nw, y: nose[1]))
            nosePath.addQuadCurve(to: CGPoint(x: nose[0] + nw, y: nose[1]), control: CGPoint(x: nose[0], y: nose[1] - 2))
            nosePath.addQuadCurve(to: CGPoint(x: nose[0] - nw, y: nose[1]), control: CGPoint(x: nose[0], y: nose[1] + 5))
            nosePath.closeSubpath()
            fillPath(ctx, nosePath, ClackBreedPalette.hex(0xF6E9D8))

            let earDark = CGMutablePath()
            for ear in [f, p] {
                if o > 0 {
                    earDark.move(to: CGPoint(x: ear.outer[0], y: ear.outer[1]))
                    appendEarCurve(earDark, ear, outerFirst: true)
                    let isL = ear.side < 0
                    let c1 = c(ear.pointFn(24, -33, 0), isL ? -25 : 0, isL ? -40 : -42)
                    let c2 = c(ear.pointFn(40, -25, 0), isL ? -43 : 13, isL ? -25 : -40)
                    earDark.addCurve(to: CGPoint(x: ear.outer[0], y: ear.outer[1]), control1: CGPoint(x: c1[0], y: c1[1]), control2: CGPoint(x: c2[0], y: c2[1]))
                    earDark.closeSubpath()
                } else {
                    let gt = max(0, ear.side * sinYaw) * (9.0 - 12.0 * e.headPitch)
                    earDark.move(to: CGPoint(x: ear.tip[0], y: ear.tip[1]))
                    earDark.addCurve(to: CGPoint(x: ear.inner[0], y: ear.inner[1]), control1: CGPoint(x: ear.innerTip[0], y: ear.innerTip[1]), control2: CGPoint(x: ear.innerBase[0], y: ear.innerBase[1]))
                    let b1 = ear.pointFn(24, -33, 0), b2 = ear.pointFn(40, -25 - gt, 0), b3 = ear.pointFn(50, -14 - gt, 0)
                    earDark.addCurve(to: CGPoint(x: b3[0], y: b3[1]), control1: CGPoint(x: b1[0], y: b1[1]), control2: CGPoint(x: b2[0], y: b2[1]))
                    let e1 = ear.pointFn(74, -10 - gt, 0), e2 = ear.pointFn(74, -76, 0), e3 = ear.pointFn(41, -76, 0)
                    earDark.addLine(to: CGPoint(x: e1[0], y: e1[1]))
                    earDark.addLine(to: CGPoint(x: e2[0], y: e2[1]))
                    earDark.addLine(to: CGPoint(x: e3[0], y: e3[1]))
                    earDark.closeSubpath()
                }
            }
            fillPath(ctx, earDark, ptCol)
            ctx.restoreGState()
        }

        // Tabby (`黄粽子` / `美短`) white lower muzzle, 4 forehead M-stripes, cheek stripes & pink nose (`jn`)!
        if n.tabby {
            ctx.saveGState()
            ctx.addPath(headFull)
            ctx.clip()
            let mapHead: (CGFloat, CGFloat, CGFloat) -> CGPoint = { vx, vy, vz in
                let r = c(proj.project(vx, vy, vz), 17.0 + vx * 0.65 + vz * 0.45, vy * 0.91 + 7.0)
                return CGPoint(x: r[0], y: r[1])
            }
            let muzzle = CGMutablePath()
            muzzle.move(to: mapHead(-52, 42, 3))
            muzzle.addCurve(to: mapHead(0, 31, 28), control1: mapHead(-35, 36, 12), control2: mapHead(-15, 37, 24))
            muzzle.addCurve(to: mapHead(52, 42, 3), control1: mapHead(14, 37, 24), control2: mapHead(36, 36, 12))
            muzzle.addLine(to: mapHead(65, 73, 0))
            muzzle.addLine(to: mapHead(-65, 73, 0))
            muzzle.closeSubpath()
            fillPath(ctx, muzzle, n.bibCream)

            ctx.setFillColor(n.stripeDark.cgColor)
            for fx in [-15.0, -5.0, 5.0, 15.0] as [CGFloat] {
                let mid = abs(fx) < 10.0
                let st = CGMutablePath()
                st.move(to: mapHead(fx, -41, 2))
                st.addQuadCurve(to: mapHead(fx * 0.85, mid ? -11 : -18, 21), control: mapHead(fx - 5, -24, 16))
                st.addQuadCurve(to: mapHead(fx + 3, -41, 2), control: mapHead(fx + 4, -23, 16))
                st.closeSubpath()
                ctx.addPath(st)
                ctx.fillPath()
            }
            for side in [-1.0, 1.0] as [CGFloat] {
                for sy in [8.0, 18.0] as [CGFloat] {
                    let ck = CGMutablePath()
                    ck.move(to: mapHead(side * 57, sy - 8, 0))
                    ck.addQuadCurve(to: mapHead(side * 32, sy + 4, 21), control: mapHead(side * 44, sy + 3, 10))
                    ck.addQuadCurve(to: mapHead(side * 57, sy, 0), control: mapHead(side * 42, sy + 10, 12))
                    ck.closeSubpath()
                    ctx.addPath(ck)
                    ctx.fillPath()
                }
            }
            // Cute pink triangle nose
            let noseP = CGMutablePath()
            noseP.move(to: mapHead(-4, 17, 26))
            noseP.addQuadCurve(to: mapHead(4, 17, 26), control: mapHead(0, 15, 27))
            noseP.addQuadCurve(to: mapHead(-4, 17, 26), control: mapHead(0, 25, 28))
            noseP.closeSubpath()
            fillPath(ctx, noseP, ClackBreedPalette.hex(0xAF6D57))

            // Inner ear triangles
            for ear in [f, p] {
                let b = W(ear.tip, ear.outer, 0.7)
                let y = W(ear.tip, ear.inner, 0.7)
                let t0 = W(ear.tip, b, 0.2)
                let ep = CGMutablePath()
                ep.move(to: CGPoint(x: t0[0], y: t0[1]))
                ep.addLine(to: CGPoint(x: b[0], y: b[1]))
                ep.addLine(to: CGPoint(x: y[0], y: y[1]))
                ep.closeSubpath()
                fillPath(ctx, ep, ClackBreedPalette.hex(n.isSilverTabby ? 0xD8AEB4 : 0xE9AC83))
            }
            ctx.restoreGState()
        }

        // Eyes, Puffy Confrontation Whisker Pads (`s > 0`), and Dual-Clipped Whiskers!
        let leftWhiskers = CGMutablePath()
        let rightWhiskers = CGMutablePath()
        let G = c(proj.project(0, P + 20, 26), 26, 38)
        let Rt = s * (proj.cy + (1.12 - proj.cy) * o)
        let ue = s * proj.cp
        func U(_ vx: CGFloat, _ vy: CGFloat) -> [CGFloat] {
            [vx * (1.0 + (vx < 0 ? 0.07 : -0.46) * o), vy * (vx > 0 ? 1.0 - 0.18 * o : 1.0) - 0.14 * vx * o]
        }
        let Xt = min(1.0, s * 8.0)
        let En = Xt * Xt * (3.0 - 2.0 * Xt)
        let ce: CGFloat = 14.0, fe: CGFloat = 36.0, ye: CGFloat = 8.0 + 8.0 * s
        let curCTM = ctx.ctm
        let Rn: CGFloat = (s > 0 && o > 0 && abs(curCTM.d) > 0.001) ? (s * (fe - ce) * curCTM.b / curCTM.d) : 0

        for v in [-1.0, 1.0] as [CGFloat] {
            let L = max(0, v * sinYaw)
            let isLeft = (v < 0)
            let eyePos = c(proj.project(v * 23.0 + e.turn * 0.35, P, 16.0 - 24.0 * L), isLeft ? ce : fe, isLeft ? ye : ye - Rn)
            let A = cos(e.headYaw + v * 0.29) / cos(0.29) * (1.0 - 0.12 * L)
            let gt: CGFloat = isLeft ? (1.02 + 0.1 * s) : 0.32
            drawEye(in: ctx, pose: e, side: v, center: eyePos, scaleX: A + (gt - A) * o, scaleY: proj.cp, irisColor: n.iris, tension: s, profile: o)

            if !isLeft && o >= 0.999 { continue }
            let wTarget = isLeft ? leftWhiskers : rightWhiskers
            for idx in 0..<3 {
                let fi = CGFloat(idx)
                let Ft = 25.0 + fi * 5.0 + 6.0 * e.keyboardReady
                let pe = -0.6 + fi * 3.4
                let ge = c(proj.project(v * (29.0 + fi * 0.5), Ft, 31), isLeft ? 0 : 38, 26 + fi * 5)
                let be = c(proj.project(v * 38.0, Ft + pe * 0.5 - 0.45, 40), isLeft ? -11 : 38, 26 + fi * 5)
                let xe = c(proj.project(v * (idx == 1 ? 48.0 : 46.5), Ft + pe, 50), isLeft ? -24 : 38, isLeft ? 22 + fi * 8 : 26 + fi * 5)
                if s > 0 {
                    let uPt = U(v * (idx == 1 ? 9.0 : 7.0), fi * 2.3 - 2.0)
                    let Ut = G[0] + uPt[0] * Rt
                    let Kt = G[1] + uPt[1] * ue
                    let me = (idx == 1 ? 34.0 : 31.0) * (isLeft ? 1.0 - 0.15 * o : 1.0 - 0.78 * o)
                    let ve = (fi - 1.0) * 7.0
                    let p0 = W(ge, [Ut, Kt], En)
                    let p1 = W(be, [Ut + v * me * 0.5, Kt + ve * 0.35 - 1.0], s)
                    let p2 = W(xe, [Ut + v * me, Kt + ve], s)
                    wTarget.move(to: CGPoint(x: p0[0], y: p0[1]))
                    wTarget.addQuadCurve(to: CGPoint(x: p2[0], y: p2[1]), control: CGPoint(x: p1[0], y: p1[1]))
                } else {
                    wTarget.move(to: CGPoint(x: ge[0], y: ge[1]))
                    wTarget.addQuadCurve(to: CGPoint(x: xe[0], y: xe[1]), control: CGPoint(x: be[0], y: be[1]))
                }
            }
        }

        // Puffy peanut whisker pads during head-butting confrontation (`s > 0`)!
        if s > 0.005 && abs(Rt) > 0.005 && abs(ue) > 0.005 {
            ctx.saveGState()
            ctx.translateBy(x: G[0], y: G[1])
            ctx.scaleBy(x: Rt, y: ue)
            func up(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                let r = U(x, y)
                return CGPoint(x: r[0], y: r[1])
            }
            let pad = CGMutablePath()
            pad.move(to: up(-14, -2))
            pad.addQuadCurve(to: up(0, -4), control: up(-10, -9))
            pad.addQuadCurve(to: up(14, -1), control: up(11, -9))
            pad.addCurve(to: up(0, 4), control1: up(15, 8), control2: up(6, 11))
            pad.addCurve(to: up(-14, -2), control1: up(-7, 12), control2: up(-17, 8))
            pad.closeSubpath()
            fillPath(ctx, pad, ClackBreedPalette.hex(n.point != nil ? 0xEEDCCA : 0xDED4C4))
            ctx.setStrokeColor(n.edge.cgColor)
            ctx.setLineWidth(1.8)
            ctx.addPath(pad)
            ctx.strokePath()
            ctx.restoreGState()
        }

        for (wPath, wAlpha) in [(rightWhiskers, 1.0 - o * o), (leftWhiskers, CGFloat(1.0))] where wAlpha > 0.005 {
            ctx.saveGState()
            ctx.setAlpha(wAlpha)
            ctx.setLineWidth(1.35)
            ctx.setStrokeColor((n.tabby ? ClackBreedPalette.hex(0xF2E4CD) : ClackBreedPalette.hex(0x676269)).cgColor)
            ctx.addPath(wPath)
            ctx.strokePath()

            ctx.addPath(headFull)
            ctx.clip()
            ctx.setStrokeColor(n.whisker.cgColor)
            ctx.addPath(wPath)
            ctx.strokePath()
            ctx.restoreGState()
        }

        ctx.restoreGState()
    }

    // MARK: - Exact 14-Segment Spline Standing / Walking / Braced Handover Renderer (`lt`, `bs`, `xs`, `gs`, `ps`)

    private static let splineSeated: [[CGFloat]] = [
        [40, -182],
        [34, -207, -34, -193, -43, -166], [-52, -139, -61, -115, -68, -76],
        [-72, -57, -70, -36, -56, -16], [-61, -11, -60, -4, -55, -1],
        [-52, 3, -47, 3, -43, 0], [-40, 0, -37, -3, -37, -8],
        [-36, -8, -34, -7, -33, -7], [-32, -7, -30, -7, -29, -8],
        [-29, -8, -29, -8, -29, -7], [-29, -1, -25, 3, -19, 3],
        [-13, 3, -9, 0, -9, -7], [26, -15, 73, -62, 63, -101],
        [54, -127, 46, -157, 40, -182]
    ]

    private static let splineWalking: [[CGFloat]] = [
        [51, -159],
        [21, -143, -1, -170, -39, -161], [-69, -156, -84, -128, -83, -100],
        [-82, -71, -92, -54, -90, -18], [-91, -12, -95, -2, -85, 0],
        [-80, 1, -73, 1, -68, 0], [-62, -1, -63, -11, -69, -15],
        [-67, -38, -44, -58, -25, -83], [-11, -77, 10, -73, 18, -76],
        [15, -56, 23, -31, 25, -13], [21, 0, 29, 2, 40, 1],
        [50, 2, 55, -7, 46, -15], [48, -34, 65, -65, 75, -84],
        [106, -96, 89, -139, 51, -159]
    ]

    private static let splineBraced: [[CGFloat]] = [
        [55, -148],
        [27, -182, 6, -197, -22, -190], [-57, -189, -82, -160, -90, -120],
        [-94, -95, -90, -59, -96, -16], [-99, -11, -101, -2, -91, 0],
        [-84, 1, -78, 1, -73, 0], [-66, -2, -69, -13, -76, -16],
        [-72, -42, -54, -68, -35, -83], [-18, -84, 0, -75, 12, -68],
        [22, -47, 32, -27, 36, -14], [34, -2, 42, 2, 52, 0],
        [64, 2, 70, -10, 58, -17], [53, -32, 44, -51, 46, -67],
        [100, -49, 96, -115, 55, -148]
    ]

    private static let splineFrontStand: [[CGFloat]] = [
        [26, -135],
        [9, -148, -9, -146, -28, -136], [-47, -126, -57, -90, -52, -61],
        [-50, -44, -45, -23, -44, -13], [-48, -6, -46, 0, -39, 1],
        [-34, 2, -29, 2, -24, 0], [-17, -3, -19, -10, -24, -13],
        [-25, -25, -27, -33, -25, -39], [-23, -43, -17, -46, -19, -51],
        [-21, -37, -23, -20, -25, -13], [-29, -5, -27, 1, -18, 1],
        [-11, 2, -6, 0, -7, -10], [16, -18, 44, -58, 46, -83],
        [45, -108, 41, -124, 26, -135]
    ]

    private static let farHindBraced: [[CGFloat]] = [
        [-67, -156, -64, -142, -64, -122], [-62, -91, -59, -48, -59, -15],
        [-62, -10, -62, -1, -55, 0], [-50, 1, -42, 1, -38, 0],
        [-32, -2, -34, -12, -40, -15], [-41, -47, -39, -88, -34, -119]
    ]

    private static let farHindSeated: [[CGFloat]] = [
        [22, -116, 25, -110, 26, -101], [30, -79, 34, -30, 34, -9],
        [32, -3, 35, 2, 41, 2], [48, 3, 54, 1, 55, -4],
        [56, -9, 55, -13, 53, -15], [68, -36, 73, -70, 63, -101]
    ]

    private static let foreLegStanding: [[CGFloat]] = [
        [20, -117, 20, -119, 19, -119], [15, -84, 9, -36, 9, -7],
        [9, -1, 13, 3, 19, 3], [25, 3, 29, 0, 29, -7],
        [29, -39, 46, -85, 49, -119]
    ]

    private static let landingHs: [[CGFloat]] = {
        func qt(_ p: [CGFloat]) -> [CGFloat] { [p[0] - 231, p[1] - 330] }
        func hn(_ curves: [[CGFloat]]) -> [[CGFloat]] {
            [0, 3, 6].map { idx in
                qt(curves[idx]) + qt(curves[idx + 1]) + qt(curves[idx + 2])
            }
        }
        return [
            [40, -182],
            [28, -200, -36, -208, -41, -182],
            [-46, -147, -62, -114, -68, -76],
            [-73, -53, -70, -28] + qt(hindFeet.left.start)
        ] + hn(hindFeet.left.curves)
    }()

    private static let landingTe: [CGFloat] = [73, -35, 73, -70, 63, -101]
    private static let landingDs: [CGFloat] = [57, -121, 46, -154, 40, -182]
    private static let landingUs: [[CGFloat]] = {
        func qt(_ p: [CGFloat]) -> [CGFloat] { [p[0] - 231, p[1] - 330] }
        func hn(_ curves: [[CGFloat]]) -> [[CGFloat]] {
            [0, 3, 6].map { idx in
                qt(curves[idx]) + qt(curves[idx + 1]) + qt(curves[idx + 2])
            }
        }
        return [
            [28, -89, 28, -82, 26, -76],
            [31, -56, 35, -24] + qt(hindFeet.right.start)
        ] + hn(hindFeet.right.curves) + [[57, -31, 56, -56, 48, -77]]
    }()

    private struct BaseLandingArm {
        let start: [CGFloat]
        let control: [CGFloat]
        let end: [CGFloat]
        let toe: [CGFloat]
    }

    private static let baseLandingArms: [BaseLandingArm] = [true, false].map { isLeft in
        let sh = shoulderPoint(.neutral, isLeft: isLeft)
        let pw = isLeft ? ClackStageConst.pawRestLeft : ClackStageConst.pawRestRight
        let s = [sh.x - 231.0, sh.y - 330.0]
        let o = [pw.x - 231.0, pw.y - 330.0]
        let i = [(s[0] + o[0]) * 0.5 + (isLeft ? -4.0 : 4.0), (s[1] + o[1]) * 0.5 + 9.0]
        let contour = armContour(start: CGPoint(x: s[0], y: s[1]), control: CGPoint(x: i[0], y: i[1]), end: CGPoint(x: o[0], y: o[1])).contour
        return BaseLandingArm(start: s, control: i, end: o, toe: contour[6])
    }

    private static func armContour(start: CGPoint, control: CGPoint, end: CGPoint) -> (contour: [[CGFloat]], width: CGFloat) {
        let g = computeArmGeometry(start: start, control: control, paw: end)
        let c: [[CGFloat]] = [
            g.left, W(g.left, g.curveLeft, 2.0 / 3.0), W(g.wristLeft, g.curveLeft, 2.0 / 3.0), g.wristLeft
        ] + ae(g.wristLeft, g.tipLeft, g.tipRight, g.wristRight) + [
            W(g.wristRight, g.curveRight, 2.0 / 3.0), W(g.right, g.curveRight, 2.0 / 3.0), g.right
        ]
        return (c, g.width)
    }

    private static func ot(_ t: ClackHandoverActor, _ e: CGFloat, _ n: CGFloat, _ isBelly: Bool = false) -> [CGFloat] {
        let o = t.stand
        let i = isBelly ? 12.0 * max(0, 1.0 - pow(e / 37.0, 2)) : 0
        if t.turningToExit {
            let l = isBelly ? 32.0 * max(0, 1.0 - pow(e / 45.0, 2)) : 0
            return [e * 0.9, n * 0.67 - l]
        }
        let r = max(0, min(1, (-n - 16.0) / 60.0))
        let a = min(1, max(0, (abs(e) - 30.0) / 30.0)) * max(0, 1.0 - abs(n + 65.0) / 65.0)
        return [
            e * (1.0 - 0.09 * o * r),
            n + o * (max(0, min(1, (-n - 16.0) / 166.0)) * (12.0 * t.crouch - 7.0) - 15.0 * a * r - i)
        ]
    }

    private struct StandingKinematics {
        let bob: CGFloat
        let headX: CGFloat
        let headY: CGFloat
        let profile: CGFloat
        let nod: CGFloat
        let landingArms: [(contour: [[CGFloat]], width: CGFloat)]?
        let landingBelly: [[CGFloat]]?
        let fore: CGPoint
        let hind: CGPoint
        let farFore: CGPoint
        let farHind: CGPoint
    }

    private static func stepFootOffset(_ t: ClackHandoverActor, isFore: Bool, isNear: Bool) -> CGPoint {
        let ph = t.step + (isNear ? 0 : .pi) + (isFore ? 0 : .pi)
        return CGPoint(
            x: t.stride * 24.0 * sin(ph),
            y: -t.stride * 19.0 * max(0, cos(ph))
        )
    }

    private static func computeStandingKinematics(_ t: ClackHandoverActor, pal: ClackBreedPalette) -> StandingKinematics {
        let e = t.stand
        let sinStep = sin(t.step)
        let n = -2.4 * t.stride * sinStep * sinStep
        let s = 12.0 * t.crouch + n
        let o = e * t.heading * (69.0 + t.lean)
        let i = M(-147.0, -111.0, t.tension)
        let r: CGFloat = t.settlingAtKeys ? -211.0 : -134.0
        let a = M(-204.0, M(r, i, abs(t.heading)), e) + s
        let l = e * min(1.0, abs(t.look) / 0.49)
        let useLanding = t.settlingAtKeys || (t.turningToExit && pal.tabby)
        let nod = 0.035 * t.tension + 0.56 * t.pitch

        let lArms: [(contour: [[CGFloat]], width: CGFloat)]?
        let lBelly: [[CGFloat]]?
        if useLanding {
            lArms = baseLandingArms.map { arm in
                func mapP(_ p: [CGFloat]) -> CGPoint {
                    let q = ot(t, p[0], p[1])
                    return CGPoint(x: q[0], y: q[1])
                }
                var built = armContour(start: mapP(arm.start), control: mapP(arm.control), end: mapP(arm.end))
                let dx = arm.toe[0] - built.contour[6][0]
                let dy = arm.toe[1] - built.contour[6][1]
                for idx in built.contour.indices {
                    built.contour[idx][0] += dx
                    built.contour[idx][1] += dy
                }
                return built
            }
            let b0 = ot(t, hindFeet.left.end[0] - 231, hindFeet.left.end[1] - 330, false)
            let b1 = ot(t, 209 - 231, 326 - 330, true)
            let b2 = ot(t, 249 - 231, 326 - 330, true)
            let b3 = ot(t, hindFeet.right.start[0] - 231, hindFeet.right.start[1] - 330, false)
            lBelly = ae(b0, b1, b2, b3)
        } else {
            lArms = nil
            lBelly = nil
        }

        return StandingKinematics(
            bob: s, headX: o, headY: a, profile: l, nod: nod,
            landingArms: lArms, landingBelly: lBelly,
            fore: stepFootOffset(t, isFore: true, isNear: true),
            hind: stepFootOffset(t, isFore: false, isNear: true),
            farFore: stepFootOffset(t, isFore: true, isNear: false),
            farHind: stepFootOffset(t, isFore: false, isNear: false)
        )
    }

    // Exact port of `function z(t, e, n, s, o=false, i=false)`
    private static func zPoint(
        _ t: ClackHandoverActor,
        _ e: StandingKinematics,
        seg n: Int,
        coord s: Int,
        far o: Bool = false,
        foreOverride i: Bool = false
    ) -> [CGFloat] {
        let r = t.stand
        let a = abs(t.heading)
        let l = splineSeated[n]
        let h = splineWalking[n]
        let u = splineBraced[n]
        let d = splineFrontStand[n]
        let c = o && n >= 2 && n <= 7
        let f = c ? farHindBraced[n - 2] : u

        var p = M(h[s], f[s], t.tension)
        var g = M(h[s + 1], f[s + 1], t.tension)
        let origG = g
        let isForeHalf = n >= 8
        let strideOff: CGPoint = o ? (isForeHalf ? e.farFore : e.farHind) : (isForeHalf ? e.fore : e.hind)
        let m = max(0, min(1, (origG + 82.0) / 69.0))
        p += strideOff.x * m
        g += strideOff.y * m
        if o {
            p += (isForeHalf ? 17.0 : 35.0) * (0.2 + 0.8 * m) * (c ? (1.0 - t.tension) : 1.0)
            g -= 8.0 * m
        }
        g += (1.0 - m) * e.bob

        if let landingArms = e.landingArms, let landingBelly = e.landingBelly {
            let k = isForeHalf && (o || i || (n >= 9 && n <= 11))
            let E: [CGFloat]
            if k {
                let G = (n == 8) ? 0 : (1 + (n - 9) * 3 + s / 2)
                E = landingArms[o ? 1 : 0].contour[G]
            } else if !o && (n == 7 || n == 8) {
                E = landingBelly[(n - 7) * 3 + s / 2]
            } else {
                let G: [CGFloat] = o ? landingUs[n - 2] : (n == 12 ? landingTe : (n == 13 ? landingDs : landingHs[n]))
                E = ot(t, G[s], G[s + 1])
            }
            return [M(E[0], p, a), M(E[1], g, a)]
        }

        var T = l[s], w = l[s + 1]
        var P = d[s], S = d[s + 1]
        if o && !isForeHalf {
            let k = farHindSeated[n - 2]
            T = k[s]; w = k[s + 1]
            P += 64.0 + 16.0 * m
            S -= 6.0 * m
        } else if isForeHalf && (o || i) {
            let k = foreLegStanding[n - 8]
            w = k[s + 1]
            let E = max(0, min(1, (-w - 16.0) / 100.0))
            T = k[s] - (o ? 0 : (38.0 + 26.0 * E))
            P += T - l[s]
            S += w - l[s + 1]
            if o { S -= 4.0 * m }
        }
        return [M(T, M(P, p, a), r), M(w, M(S + (1.0 - m) * e.bob, g, a), r)]
    }

    private static func buildBodyPath(_ t: ClackHandoverActor, _ e: StandingKinematics, trunkOnly: Bool = false) -> CGPath {
        let path = CGMutablePath()
        let p0 = zPoint(t, e, seg: 0, coord: 0)
        path.move(to: CGPoint(x: p0[0], y: p0[1]))
        var seg = 1
        while seg < splineSeated.count {
            if trunkOnly && seg == 3 {
                let i = zPoint(t, e, seg: 2, coord: 4)
                let r = zPoint(t, e, seg: 7, coord: 4)
                path.addQuadCurve(to: CGPoint(x: r[0], y: r[1]), control: CGPoint(x: i[0], y: r[1]))
                seg = 8
                continue
            }
            if trunkOnly && seg == 9 {
                let i = zPoint(t, e, seg: 8, coord: 4)
                let r = zPoint(t, e, seg: 12, coord: 4)
                let a = 18.0 * t.stand * abs(t.heading)
                path.addCurve(
                    to: CGPoint(x: r[0], y: r[1]),
                    control1: CGPoint(x: i[0], y: i[1] - a),
                    control2: CGPoint(x: r[0], y: r[1] - a)
                )
                seg = 13
                continue
            }
            let c1 = zPoint(t, e, seg: seg, coord: 0)
            let c2 = zPoint(t, e, seg: seg, coord: 2)
            let c3 = zPoint(t, e, seg: seg, coord: 4)
            path.addCurve(to: CGPoint(x: c3[0], y: c3[1]), control1: CGPoint(x: c1[0], y: c1[1]), control2: CGPoint(x: c2[0], y: c2[1]))
            seg += 1
        }
        path.closeSubpath()
        return path
    }

    private static func buildLimbSubpath(_ t: ClackHandoverActor, _ e: StandingKinematics, isFore: Bool, isFar: Bool) -> CGPath {
        let startSeg = isFore ? 9 : 3
        let endSeg = isFore ? 12 : 7
        let path = CGMutablePath()
        let l = zPoint(t, e, seg: startSeg - 1, coord: 4, far: isFar, foreOverride: isFore)
        path.move(to: CGPoint(x: l[0], y: l[1]))
        for h in startSeg...endSeg {
            let c1 = zPoint(t, e, seg: h, coord: 0, far: isFar, foreOverride: isFore)
            let c2 = zPoint(t, e, seg: h, coord: 2, far: isFar, foreOverride: isFore)
            let c3 = zPoint(t, e, seg: h, coord: 4, far: isFar, foreOverride: isFore)
            path.addCurve(to: CGPoint(x: c3[0], y: c3[1]), control1: CGPoint(x: c1[0], y: c1[1]), control2: CGPoint(x: c2[0], y: c2[1]))
        }
        path.addQuadCurve(to: CGPoint(x: l[0], y: l[1]), control: CGPoint(x: l[0], y: min(l[1] - 5.0, -98.0)))
        path.closeSubpath()
        return path
    }

    private static func fillStandingGradient(_ ctx: CGContext, path: CGPath, pal: ClackBreedPalette, topY: CGFloat, bottomY: CGFloat, isFar: Bool) {
        if pal.tabby {
            let stops = tabbyLegStops(pal: pal, isRight: isFar, farBlend: isFar ? 1.0 : 0.0)
            fillPathWithLinearGradient(ctx, path: path, start: CGPoint(x: 0, y: bottomY - 66.0), end: CGPoint(x: 0, y: bottomY), stops: stops)
            return
        }
        let endY = max(topY + 1.0, bottomY)
        let stops: [(CGFloat, NSColor)]
        if pal.point != nil {
            stops = [
                (0.0, isFar ? ClackBreedPalette.hex(0xB49A81) : pal.fur),
                (0.57, isFar ? ClackBreedPalette.hex(0xAC9178) : pal.fur),
                (0.85, ClackBreedPalette.hex(isFar ? 0x705945 : 0xB8A18A)),
                (1.0, ClackBreedPalette.hex(isFar ? 0x584333 : 0x79614C))
            ]
        } else {
            stops = [
                (0.0, isFar ? ClackBreedPalette.hex(0x211F22) : pal.fur),
                (1.0, isFar ? ClackBreedPalette.hex(0x171619) : pal.fur)
            ]
        }
        fillPathWithLinearGradient(ctx, path: path, start: CGPoint(x: 0, y: topY), end: CGPoint(x: 0, y: endY), stops: stops)
    }

    private static func drawStandingTail(in ctx: CGContext, actor e: ClackHandoverActor, kin s: StandingKinematics, pal n: ClackBreedPalette) {
        let standingPts: [[CGFloat]] = [[-67, -112], [-91, -131], [-102, -162], [-99, -193], [-98, -215], [-86, -234], [-70, -239]]
        let seatedPts: [[CGFloat]]   = [[51, -42], [73, -41], [83, -33], [94, -51], [104, -68], [112, -78], [132, -78]]
        let pts: [[CGFloat]] = seatedPts.enumerated().map { idx, sp in
            let a = CGFloat(idx) / 6.0
            let l = abs(e.heading)
            let h: CGFloat = e.heading < 0 ? -1.0 : 1.0
            let u = standingPts[idx][1] + (1.0 - e.tension) * 21.0 * a
            let d = a * 4.0 * e.stride * sin(e.step - a)
            let c = M(sp[0] * h, standingPts[idx][0], l)
            return [M(sp[0] * h, c, e.stand), M(sp[1], M(sp[1], u, l) + d + s.bob, e.stand)]
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: pts[0][0], y: pts[0][1]))
        path.addCurve(to: CGPoint(x: pts[3][0], y: pts[3][1]), control1: CGPoint(x: pts[1][0], y: pts[1][1]), control2: CGPoint(x: pts[2][0], y: pts[2][1]))
        path.addCurve(to: CGPoint(x: pts[6][0], y: pts[6][1]), control1: CGPoint(x: pts[4][0], y: pts[4][1]), control2: CGPoint(x: pts[5][0], y: pts[5][1]))

        let outerW = M(18.5, 22.0, e.stand)
        let innerW = M(17.0, 20.0, e.stand)
        ctx.saveGState()
        ctx.setStrokeColor(n.edge.cgColor)
        ctx.setLineWidth(outerW)
        ctx.addPath(path)
        ctx.strokePath()

        ctx.setStrokeColor((n.point ?? n.fur).cgColor)
        ctx.setLineWidth(innerW)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        if n.tabby {
            drawTabbyTailRings(in: ctx, pal: n, p0: pts[3], p1: pts[4], p2: pts[5], p3: pts[6], width: innerW)
        }
    }

    private static func drawLandingArm(_ ctx: CGContext, actor e: ClackHandoverActor, kin n: StandingKinematics, pal s: ClackBreedPalette, isFar o: Bool) {
        guard let landingArms = n.landingArms else { return }
        let i = abs(e.heading)
        let r = landingArms[o ? 1 : 0]
        let l = CGMutablePath()
        let h = zPoint(e, n, seg: 8, coord: 4, far: o, foreOverride: true)
        l.move(to: CGPoint(x: h[0], y: h[1]))
        for y in 9...12 {
            let c1 = zPoint(e, n, seg: y, coord: 0, far: o, foreOverride: true)
            let c2 = zPoint(e, n, seg: y, coord: 2, far: o, foreOverride: true)
            let c3 = zPoint(e, n, seg: y, coord: 4, far: o, foreOverride: true)
            l.addCurve(to: CGPoint(x: c3[0], y: c3[1]), control1: CGPoint(x: c1[0], y: c1[1]), control2: CGPoint(x: c2[0], y: c2[1]))
        }
        func mid(_ a: [CGFloat], _ b: [CGFloat]) -> CGPoint { CGPoint(x: (a[0] + b[0]) * 0.5, y: (a[1] + b[1]) * 0.5) }
        let d = mid(h, zPoint(e, n, seg: 12, coord: 4, far: o, foreOverride: true))
        let c = mid(zPoint(e, n, seg: 9, coord: 4, far: o, foreOverride: true), zPoint(e, n, seg: 11, coord: 4, far: o, foreOverride: true))
        let f = mid(zPoint(e, n, seg: 9, coord: 0, far: o, foreOverride: true), zPoint(e, n, seg: 12, coord: 2, far: o, foreOverride: true))
        let p = CGPoint(x: 1.5 * f.x - 0.5 * d.x, y: 1.5 * f.y - 0.5 * d.y)
        let g = (i * 255.0).rounded() / 255.0
        let opt = g > 0 ? LandingArmGradOpt(amount: g, far: o, top: o ? -137.0 : -148.0 + n.bob, bottom: zPoint(e, n, seg: 10, coord: 4, far: o, foreOverride: true)[1]) : nil
        paintArmPath(in: ctx, path: l, start: d, control: p, end: c, width: r.width, pal: s, landingOpt: opt, isRight: o)
    }

    private static func drawStandingTabbyBodyBib(_ ctx: CGContext, clipPath: CGPath, actor n: ClackHandoverActor, kin s: StandingKinematics, pal: ClackBreedPalette) {
        let o = n.stand * abs(n.heading)
        ctx.saveGState()
        ctx.addPath(clipPath)
        ctx.clip()
        drawTabbyBodyBibAndStripes(in: ctx, pal: pal, standBlend: o) { ix, iy in
            let a = s.landingArms != nil ? ot(n, ix, iy) : [ix, iy]
            let l = min(1.0, max(0, -iy / 120.0))
            return CGPoint(
                x: M(a[0], ix, o),
                y: M(a[1], iy + s.bob * l + (1.0 - n.tension) * 18.0 * l, o)
            )
        }
        ctx.restoreGState()
    }

    // Exact port of `function bs(t, e)` + `xs` + `gs`
    private static func drawStandingHandoverCat(in ctx: CGContext, actor e: ClackHandoverActor) {
        let pal = ClackBreedPalette.resolve(coat: e.breed, customSkin: e.customSkin)
        let kin = computeStandingKinematics(e, pal: pal)
        let dirSign: CGFloat = e.heading < 0 ? -1.0 : 1.0

        ctx.saveGState()
        ctx.translateBy(x: e.x, y: e.y)
        ctx.scaleBy(x: dirSign, y: 1.0)

        drawStandingTail(in: ctx, actor: e, kin: kin, pal: pal)

        let bodyPath: CGPath?
        if kin.landingArms != nil {
            bodyPath = drawLandingBody(in: ctx, actor: e, kin: kin, pal: pal)
        } else {
            bodyPath = drawStandardStandingBody(in: ctx, actor: e, kin: kin, pal: pal)
        }
        let bodyClipInfo: (path: CGPath, ctm: CGAffineTransform)? = bodyPath.map { ($0, ctx.ctm) }

        ctx.translateBy(x: dirSign * kin.headX, y: kin.headY)
        let lookFlip: CGFloat = (e.look < 0 ? -1.0 : 1.0) * dirSign
        ctx.scaleBy(x: lookFlip, y: 1.0)
        ctx.rotate(by: kin.nod)
        ctx.translateBy(x: -231.0, y: -126.0)

        var headPose = ClackPose.neutral
        headPose.headYaw = abs(e.look)
        headPose.headPitch = e.pitch
        headPose.gaze = CGPoint(x: abs(e.look) * 10.0, y: e.pitch * 10.0)
        drawCatHead(in: ctx, pose: headPose, pal: pal, tension: e.tension, profile: kin.profile, bodyClip: bodyClipInfo)

        ctx.restoreGState()
    }

    private static func drawLandingBody(in ctx: CGContext, actor e: ClackHandoverActor, kin n: StandingKinematics, pal s: ClackBreedPalette) -> CGPath? {
        let o = abs(e.heading)
        let i = 1.0 - o
        if o <= 0.001 {
            ctx.saveGState()
            ctx.translateBy(x: -231.0, y: -330.0)
            drawSeatedBody(in: ctx, pose: .neutral, pal: s) { px, py, isBelly in
                let q = ot(e, px - 231.0, py - 330.0, isBelly)
                return CGPoint(x: 231.0 + q[0], y: 330.0 + q[1])
            }
            ctx.restoreGState()
            drawLandingArm(ctx, actor: e, kin: n, pal: s, isFar: true)
            drawLandingArm(ctx, actor: e, kin: n, pal: s, isFar: false)
            return nil
        }

        let a = CGMutablePath()
        let p0 = zPoint(e, n, seg: 0, coord: 0)
        a.move(to: CGPoint(x: p0[0], y: p0[1]))
        for w in 1...8 {
            let c1 = zPoint(e, n, seg: w, coord: 0)
            let c2 = zPoint(e, n, seg: w, coord: 2)
            let c3 = zPoint(e, n, seg: w, coord: 4)
            a.addCurve(to: CGPoint(x: c3[0], y: c3[1]), control1: CGPoint(x: c1[0], y: c1[1]), control2: CGPoint(x: c2[0], y: c2[1]))
        }
        let lStroke = CGMutablePath()
        lStroke.addPath(a)

        let h = ot(e, hindFeet.right.end[0] - 231.0, hindFeet.right.end[1] - 330.0)
        let u = splineWalking[8], d = splineWalking[12]
        let c = [M(h[0], u[4], o), M(h[1], u[5] + n.bob, o)]
        a.addLine(to: CGPoint(x: c[0], y: c[1]))

        func f(_ w: Int, _ P: CGFloat) -> CGPoint {
            let S = ot(e, landingTe[w], landingTe[w + 1])
            return CGPoint(x: M(S[0], M(u[4], d[4], P), o), y: M(S[1], M(u[5], d[5], P) + n.bob, o))
        }
        let pCtrl1 = f(0, 1.0 / 3.0), gCtrl2 = f(2, 2.0 / 3.0)
        let r12 = zPoint(e, n, seg: 12, coord: 4)

        let xSeam = CGMutablePath()
        xSeam.move(to: CGPoint(x: c[0], y: c[1]))
        xSeam.addCurve(to: CGPoint(x: r12[0], y: r12[1]), control1: pCtrl1, control2: gCtrl2)
        a.addCurve(to: CGPoint(x: r12[0], y: r12[1]), control1: pCtrl1, control2: gCtrl2)
        lStroke.move(to: CGPoint(x: r12[0], y: r12[1]))

        let c13_1 = zPoint(e, n, seg: 13, coord: 0), c13_2 = zPoint(e, n, seg: 13, coord: 2), c13_3 = zPoint(e, n, seg: 13, coord: 4)
        a.addCurve(to: CGPoint(x: c13_3[0], y: c13_3[1]), control1: CGPoint(x: c13_1[0], y: c13_1[1]), control2: CGPoint(x: c13_2[0], y: c13_2[1]))
        lStroke.addCurve(to: CGPoint(x: c13_3[0], y: c13_3[1]), control1: CGPoint(x: c13_1[0], y: c13_1[1]), control2: CGPoint(x: c13_2[0], y: c13_2[1]))
        a.closeSubpath()

        let farHindPath = buildLimbSubpath(e, n, isFore: false, isFar: true)
        let nearHindFoot = zPoint(e, n, seg: 5, coord: 4, far: false)
        let farHindFoot = zPoint(e, n, seg: 5, coord: 4, far: true)

        fillPath(ctx, farHindPath, s.fur)
        ctx.saveGState()
        ctx.setAlpha(o)
        fillStandingGradient(ctx, path: farHindPath, pal: s, topY: -137.0, bottomY: farHindFoot[1], isFar: true)
        ctx.restoreGState()
        ctx.saveGState()
        ctx.setStrokeColor(s.edge.cgColor)
        ctx.setLineWidth(M(1.0, 1.9, o))
        ctx.addPath(farHindPath)
        ctx.strokePath()
        ctx.restoreGState()

        let T = min(1.0, i / 0.5)
        if !s.tabby && T < 1.0 {
            drawLandingArm(ctx, actor: e, kin: n, pal: s, isFar: true)
        }

        fillPath(ctx, a, s.fur)
        ctx.saveGState()
        ctx.setAlpha(o)
        if s.tabby {
            ctx.addPath(buildLimbSubpath(e, n, isFore: false, isFar: false))
            ctx.clip()
        }
        fillStandingGradient(ctx, path: a, pal: s, topY: -148.0 + n.bob, bottomY: nearHindFoot[1], isFar: false)
        ctx.restoreGState()

        if s.tabby {
            drawStandingTabbyBodyBib(ctx, clipPath: a, actor: e, kin: n, pal: s)
        }

        ctx.saveGState()
        ctx.setStrokeColor(s.edge.cgColor)
        ctx.setLineWidth(M(1.0, 1.9, o))
        ctx.addPath(lStroke)
        ctx.strokePath()
        ctx.setAlpha(i)
        ctx.addPath(xSeam)
        ctx.strokePath()
        ctx.restoreGState()

        if (s.point != nil || s.tabby) && i > 0.005 {
            let combo = CGMutablePath()
            combo.addPath(a)
            combo.addPath(farHindPath)
            ctx.saveGState()
            ctx.addPath(combo)
            ctx.clip()
            ctx.setAlpha(i)
            for (footDef, curToe) in [(hindFeet.left, nearHindFoot), (hindFeet.right, farHindFoot)] {
                drawPawMarking(ctx, pal: s, x: curToe[0] + (footDef.marking[0] - footDef.toe[0]), y: curToe[1] + (footDef.marking[1] - footDef.toe[1]))
            }
            ctx.restoreGState()
        }

        ctx.saveGState()
        if s.tabby {
            let eo = CGMutablePath()
            eo.addRect(CGRect(x: -350, y: -350, width: 700, height: 700))
            eo.addPath(a, transform: CGAffineTransform(translationX: 0, y: -240.0 * T))
            ctx.addPath(eo)
            ctx.clip(using: .evenOdd)
        } else if T < 1.0 {
            ctx.addPath(a)
            ctx.clip()
            ctx.setAlpha(T * T * (3.0 - 2.0 * T))
        }
        drawLandingArm(ctx, actor: e, kin: n, pal: s, isFar: true)
        ctx.restoreGState()
        drawLandingArm(ctx, actor: e, kin: n, pal: s, isFar: false)

        return a
    }

    private static func drawStandardStandingBody(in ctx: CGContext, actor e: ClackHandoverActor, kin n: StandingKinematics, pal s: ClackBreedPalette) -> CGPath {
        let farForePath = buildLimbSubpath(e, n, isFore: true, isFar: true)
        let farHindPath = buildLimbSubpath(e, n, isFore: false, isFar: true)
        let farForeFoot = zPoint(e, n, seg: 10, coord: 4, far: true)
        let farHindFoot = zPoint(e, n, seg: 5, coord: 4, far: true)

        for (p, botY) in [(farHindPath, farHindFoot[1]), (farForePath, farForeFoot[1])] {
            fillStandingGradient(ctx, path: p, pal: s, topY: -137.0, bottomY: botY, isFar: true)
            ctx.saveGState()
            ctx.setStrokeColor(s.edge.cgColor)
            ctx.setLineWidth(1.7)
            ctx.addPath(p)
            ctx.strokePath()
            ctx.restoreGState()
        }

        let bodyPath = buildBodyPath(e, n, trunkOnly: false)
        let a = e.stand * abs(e.heading)
        let l = max(0, 1.0 - a / 0.7)

        if s.tabby {
            let trunkOnly = buildBodyPath(e, n, trunkOnly: true)
            let nearForeFoot = zPoint(e, n, seg: 10, coord: 4, far: false)
            let nearHindFoot = zPoint(e, n, seg: 5, coord: 4, far: false)
            let nearHindSub = buildLimbSubpath(e, n, isFore: false, isFar: false)
            let nearForeSub = buildLimbSubpath(e, n, isFore: true, isFar: false)

            func paintTabbyLimb(_ limbPath: CGPath, _ foot: [CGFloat], _ isRight: Bool) {
                let startPt = CGPoint(x: foot[0], y: M(foot[1] - 66.0, -118.0, l))
                let endPt = CGPoint(x: foot[0], y: foot[1])
                fillPathWithLinearGradient(ctx, path: limbPath, start: startPt, end: endPt, stops: tabbyLegStops(pal: s, isRight: isRight))
                strokePathWithLinearGradient(ctx, path: limbPath, lineWidth: 1.7, start: startPt, end: endPt, stops: [
                    (0.0, s.edge.withAlphaComponent(0)),
                    (0.65, s.edge),
                    (1.0, s.edge)
                ])
            }

            fillPath(ctx, bodyPath, s.fur)
            ctx.saveGState()
            ctx.addPath(bodyPath)
            ctx.clip()
            paintTabbyLimb(nearHindSub, nearHindFoot, false)
            paintTabbyLimb(nearForeSub, nearForeFoot, false)
            ctx.restoreGState()

            fillPath(ctx, trunkOnly, s.fur)
            ctx.saveGState()
            ctx.addPath(bodyPath)
            ctx.clip()
            drawStandingTabbyBodyBib(ctx, clipPath: trunkOnly, actor: e, kin: n, pal: s)
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setStrokeColor(s.edge.cgColor)
            ctx.setLineWidth(M(1.0, 1.9, e.stand))
            ctx.addPath(bodyPath)
            ctx.strokePath()
            ctx.restoreGState()

            if l > 0.005 {
                ctx.saveGState()
                ctx.addPath(bodyPath)
                ctx.clip()
                let eo = CGMutablePath()
                eo.addRect(CGRect(x: -350, y: -350, width: 700, height: 700))
                eo.addPath(bodyPath, transform: CGAffineTransform(translationX: 0, y: -240.0 * l))
                ctx.addPath(eo)
                ctx.clip(using: .evenOdd)
                paintTabbyLimb(farForePath, farForeFoot, true)
                paintTabbyLimb(nearForeSub, nearForeFoot, false)
                ctx.restoreGState()
            }
        } else {
            fillPath(ctx, bodyPath, s.fur)
            if e.stand > 0 {
                ctx.saveGState()
                ctx.addPath(bodyPath)
                ctx.clip()
                let splitX = zPoint(e, n, seg: 8, coord: 2)[0]
                for isFore in [false, true] {
                    let foot = zPoint(e, n, seg: isFore ? 10 : 5, coord: 4)
                    let rect = isFore ? CGRect(x: splitX, y: -300, width: 320, height: 410) : CGRect(x: -300, y: -300, width: splitX + 300, height: 410)
                    let rPath = CGPath(rect: rect, transform: nil)
                    fillStandingGradient(ctx, path: rPath, pal: s, topY: M(-17.0, -148.0 + n.bob, e.stand), bottomY: foot[1], isFar: false)
                }
                ctx.restoreGState()
            }
            ctx.saveGState()
            ctx.setStrokeColor(s.edge.cgColor)
            ctx.setLineWidth(M(1.0, 1.9, e.stand))
            ctx.addPath(bodyPath)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // Signature Clack-Clack 3-spike raised fur tuft on top of the arched back during head-butting duel!
        let tuftScale = e.tension * e.stand
        if tuftScale > 0.03 {
            let peak = zPoint(e, n, seg: 1, coord: 4)
            ctx.saveGState()
            ctx.translateBy(x: peak[0], y: peak[1])
            ctx.scaleBy(x: tuftScale, y: tuftScale)
            let spikes = CGMutablePath()
            spikes.move(to: CGPoint(x: -14, y: 4))
            spikes.addQuadCurve(to: CGPoint(x: -3, y: 0), control: CGPoint(x: -8, y: 0))
            spikes.addLine(to: CGPoint(x: -8, y: -3))
            spikes.addQuadCurve(to: CGPoint(x: 5, y: 0), control: CGPoint(x: 0, y: -3))
            spikes.addLine(to: CGPoint(x: 1, y: -4))
            spikes.addQuadCurve(to: CGPoint(x: 17, y: 4), control: CGPoint(x: 10, y: -2))

            let tuftFill = CGMutablePath()
            tuftFill.addPath(spikes)
            tuftFill.addLine(to: CGPoint(x: 16, y: 7))
            tuftFill.addLine(to: CGPoint(x: -14, y: 7))
            tuftFill.closeSubpath()
            fillPath(ctx, tuftFill, s.fur)

            ctx.setStrokeColor(s.edge.cgColor)
            ctx.setLineWidth(1.4)
            ctx.addPath(spikes)
            ctx.strokePath()
            ctx.restoreGState()
        }

        if !s.tabby && l > 0.005 {
            ctx.saveGState()
            ctx.setAlpha(l * l * (3.0 - 2.0 * l))
            for isFar in [true, false] {
                if !isFar {
                    ctx.addPath(bodyPath)
                    ctx.clip()
                }
                let uPath = isFar ? farForePath : buildLimbSubpath(e, n, isFore: true, isFar: false)
                let foot = zPoint(e, n, seg: 10, coord: 4, far: isFar)
                fillPathWithLinearGradient(ctx, path: uPath, start: CGPoint(x: 0, y: -118), end: CGPoint(x: 0, y: foot[1]), stops: [
                    (0.22, s.fur),
                    (0.76, s.point != nil ? ClackBreedPalette.hex(0x856A55) : s.fur),
                    (1.0, s.point ?? s.fur)
                ])
                strokePathWithLinearGradient(ctx, path: uPath, lineWidth: 1.7, start: CGPoint(x: 0, y: -118), end: CGPoint(x: 0, y: foot[1]), stops: [
                    (0.28, NSColor.clear),
                    (1.0, (s.point != nil || s.tabby) ? s.edge : ClackBreedPalette.hex(0xEEECE6))
                ])
            }
            ctx.restoreGState()
        }

        return bodyPath
    }

    // MARK: - Keycap Bubbles (`drawBubbles`), Sleep `z`s & TypeZero Cloud Voice Pill

    private static func drawBubbles(in ctx: CGContext, bubbles: [ClackKeyBubble], nowMs: Double) {
        for b in bubbles {
            let age = max(0, CGFloat(nowMs - b.atMs) / 1000.0)
            let life: CGFloat = b.code.hasPrefix("Wheel") ? 1.0 : 1.15
            let alpha = min(1.0, age * 10.0) * min(1.0, (life - age) * 3.0)
            guard alpha > 0.01 else { continue }

            let text = b.customLabel ?? ClackKeyboardMap.bubbleText(for: b.code)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: ClackBreedPalette.hex(0x302D32)
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let sz = attrStr.size()
            let pillW = max(28.0, sz.width + 18.0)
            let pillH: CGFloat = 25.0
            let bx = b.x + sin(CGFloat(b.id) * 2.4) * age * 9.0
            let by = b.y - age * 65.0

            ctx.saveGState()
            ctx.setAlpha(alpha)
            let lipRect = CGRect(x: bx - pillW * 0.5, y: by + 3.0, width: pillW, height: pillH)
            fillPath(ctx, CGPath(roundedRect: lipRect, cornerWidth: 8, cornerHeight: 8, transform: nil), ClackBreedPalette.hex(0x595459))

            let topRect = CGRect(x: bx - pillW * 0.5, y: by, width: pillW, height: pillH)
            let topPath = CGPath(roundedRect: topRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            fillPath(ctx, topPath, ClackBreedPalette.hex(0xFFFDF6))
            ctx.setStrokeColor(ClackBreedPalette.hex(0xB0AAAB).cgColor)
            ctx.setLineWidth(1.5)
            ctx.addPath(topPath)
            ctx.strokePath()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
            attrStr.draw(at: CGPoint(x: bx - sz.width * 0.5, y: by + (pillH - sz.height) * 0.5))
            NSGraphicsContext.restoreGraphicsState()
            ctx.restoreGState()
        }
    }

    private static func drawSleepZs(in ctx: CGContext, time: CGFloat) {
        ctx.saveGState()
        ctx.setAlpha(0.5 + sin(time * 1.5) * 0.2)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        let col = ClackBreedPalette.hex(0x6D9475)
        let z1 = NSAttributedString(string: "z", attributes: [
            .font: NSFont(name: "Georgia-Bold", size: 15) ?? NSFont.boldSystemFont(ofSize: 15),
            .foregroundColor: col
        ])
        let z2 = NSAttributedString(string: "z", attributes: [
            .font: NSFont(name: "Georgia-Bold", size: 10) ?? NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: col
        ])
        z1.draw(at: CGPoint(x: 283, y: 122 + sin(time) * 3.0))
        z2.draw(at: CGPoint(x: 295, y: 108 + sin(time + 1.0) * 3.0))
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
    }

    private static func drawMusicNotes(in ctx: CGContext, pose: ClackPose) {
        ctx.saveGState()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        for idx in 0..<2 {
            let phase = (pose.time * 0.8 + CGFloat(idx) * 0.5).truncatingRemainder(dividingBy: 1.0)
            let alpha = sin(.pi * phase) * 0.85
            let nx = 285.0 + CGFloat(idx) * 18.0 + sin(pose.time * 3.0 + CGFloat(idx)) * 4.0
            let ny = 104.0 - phase * 28.0
            let note = NSAttributedString(string: idx == 0 ? "♪" : "♫", attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: ClackBreedPalette.hex(0x5A46E8, alpha: alpha)
            ])
            note.draw(at: CGPoint(x: nx, y: ny))
        }
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
    }

    private static func drawVoiceListeningPill(in ctx: CGContext, pose: ClackPose) {
        let hx = 288.0 + pose.headLean.x
        let hy = 84.0 + pose.headLean.y + pose.breath
        let pillRect = CGRect(x: hx - 17, y: hy - 11, width: 34, height: 22)
        let path = CGPath(roundedRect: pillRect, cornerWidth: 11, cornerHeight: 11, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 7, color: ClackBreedPalette.hex(0x5A46E8, alpha: 0.45).cgColor)
        fillPath(ctx, path, ClackBreedPalette.hex(0x18171F, alpha: 0.90))
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(ClackBreedPalette.hex(0x8D82FF, alpha: 0.72).cgColor)
        ctx.setLineWidth(1.1)
        ctx.addPath(path)
        ctx.strokePath()

        let bars: [CGFloat] = [
            5.0 + 7.0 * abs(sin(pose.time * 9.5)),
            7.5 + 8.0 * abs(sin(pose.time * 7.2 + 1.1)),
            4.5 + 7.0 * abs(cos(pose.time * 8.6))
        ]
        ctx.setFillColor(ClackBreedPalette.hex(0xE5F672).cgColor)
        for i in 0..<3 {
            let bh = bars[i]
            let bx = hx - 8.0 + CGFloat(i) * 6.5
            let bRect = CGRect(x: bx, y: hy - bh * 0.5, width: 3.0, height: bh)
            ctx.addPath(CGPath(roundedRect: bRect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    /// Renders a 6-panel PNG contact sheet of the 1:1 Clack-Clack handover & seated typing for automated visual verification.
    @discardableResult
    static func renderVerificationContactSheet(to outputPath: String) -> Bool {
        let panelW = 564
        let panelH = 480
        let cols = 3
        let rows = 2
        let totalW = panelW * cols
        let totalH = panelH * rows
        guard let ctx = CGContext(
            data: nil,
            width: totalW,
            height: totalH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: stickerColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        ctx.translateBy(x: 0, y: CGFloat(totalH))
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.setFillColor(NSColor(srgbRed: 0.94, green: 0.94, blue: 0.92, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))

        let timesMs: [Double?] = [950, 2050, 3600, 5750, 9550, nil]
        for (idx, maybeT) in timesMs.enumerated() {
            let col = idx % cols
            let row = idx / cols
            let ox = CGFloat(col * panelW)
            let oy = CGFloat(row * panelH)
            ctx.saveGState()
            ctx.translateBy(x: ox, y: oy)
            ctx.clip(to: CGRect(x: 0, y: 0, width: panelW, height: panelH))

            var pose = ClackPose.neutral
            if let tMs = maybeT {
                let hf = ClackHandoverDirector.computeFrame(
                    from: .classicBlack,
                    to: (idx == 4 ? .orangeWhite : .siamese),
                    elapsedMs: tMs,
                    scale: 1.0
                )
                drawStage(
                    in: ctx,
                    pose: pose,
                    breed: .classicBlack,
                    handover: hf,
                    anchorX: ClackStageConst.anchorX,
                    anchorY: ClackStageConst.anchorY,
                    baseScale: ClackStageConst.baseScale,
                    whiteOutline: false,
                    showKeyLabels: true,
                    showKeyBubbles: true
                )
            } else {
                let nowMs = CACurrentMediaTime() * 1000.0
                pose.pressed = ["KeyJ", "KeyF"]
                pose.flashes = ["KeyJ": nowMs - 20]
                if let kp = ClackKeyboardMap.targetPoint(for: "KeyJ") {
                    pose.right.x = kp.pt.x; pose.right.y = kp.pt.y - 3
                    pose.bubbles = [ClackKeyBubble(id: 1, code: "KeyJ", customLabel: nil, atMs: nowMs - 140, x: kp.pt.x, y: kp.pt.y - 36)]
                }
                drawStage(
                    in: ctx,
                    pose: pose,
                    breed: .orangeWhite,
                    handover: nil,
                    anchorX: ClackStageConst.anchorX,
                    anchorY: ClackStageConst.anchorY,
                    baseScale: ClackStageConst.baseScale,
                    whiteOutline: false,
                    showKeyLabels: true,
                    showKeyBubbles: true
                )
            }
            ctx.restoreGState()
        }

        guard let cgImg = ctx.makeImage() else { return false }
        let rep = NSBitmapImageRep(cgImage: cgImg)
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)) != nil
    }
}
