import Foundation
import AppKit
import AVFoundation

// MARK: - 4-Stage Multi-Cat Shift Handover State Machine ("走入 -> 炸毛吵架交接 -> 旧猫下班 -> 新猫落座上岗")

enum ShiftHandoverPhase: Equatable {
    case idle
    case entering       // 0.00s .. 1.20s: Incoming cat trots in from left while outgoing cat turns head sharply left
    case arguing        // 1.20s .. 3.80s: Both cats face nose-to-nose with arched backs, airplane ears & bickering audio
    case exitingOld     // 3.80s .. 5.05s: Outgoing cat turns right & trots off-stage; incoming cat steps to seat center
    case settlingNew    // 5.05s .. 5.85s: Incoming cat sits down at desk with squash-and-stretch bounce & ring burst
}

struct ShiftHandoverState {
    static let enterEnd: CGFloat = 1.20
    static let argueEnd: CGFloat = 3.80
    static let exitEnd: CGFloat  = 5.05
    static let totalEnd: CGFloat = 5.85

    private(set) var phase: ShiftHandoverPhase = .idle
    private(set) var elapsed: CGFloat = 0

    private(set) var outgoingSkin: SkinSpec = SkinSpec.builtIn(.classicBlack)
    private(set) var outgoingEye: EyeColorTheme = .neonChartreuse
    private(set) var incomingSkin: SkinSpec = SkinSpec.builtIn(.siamese)
    private(set) var incomingEye: EyeColorTheme = .siameseBlue

    private var pendingCoat: CatCoatTheme = .siamese
    private var pendingCustomSkinID: String = ""
    private var didCommitIncomingSkin: Bool = false

    var onCommitSkin: ((CatCoatTheme, String, EyeColorTheme, String) -> Void)?

    var isActive: Bool {
        phase != .idle
    }

    mutating func start(
        outgoingSkin: SkinSpec,
        outgoingEye: EyeColorTheme,
        incomingSkin: SkinSpec,
        incomingEye: EyeColorTheme,
        targetCoat: CatCoatTheme,
        targetCustomSkinID: String
    ) {
        self.outgoingSkin = outgoingSkin
        self.outgoingEye = outgoingEye
        self.incomingSkin = incomingSkin
        self.incomingEye = incomingEye
        self.pendingCoat = targetCoat
        self.pendingCustomSkinID = targetCustomSkinID
        self.elapsed = 0
        self.didCommitIncomingSkin = false
        self.phase = .entering
    }

    mutating func cancel() {
        phase = .idle
        elapsed = 0
        didCommitIncomingSkin = false
    }

    mutating func step(dt: CGFloat, physics: CatPhysics) {
        guard phase != .idle else { return }
        elapsed += dt
        physics.sleepiness = 0

        if elapsed < Self.enterEnd {
            phase = .entering
            // Outgoing cat turns head sharply left noticing the incoming coworker!
            if elapsed > 0.25 {
                physics.headYaw.target = -0.92
                physics.headPitch.target = 0.08
                physics.earFold.target = 0.35
            }
        } else if elapsed < Self.argueEnd {
            if phase != .arguing {
                phase = .arguing
                if CatSettings.shared.enableHandoverSound {
                    PetAudioBank.shared.playNextBickerClip()
                }
            }
        } else if elapsed < Self.exitEnd {
            phase = .exitingOld
        } else if elapsed < Self.totalEnd {
            if !didCommitIncomingSkin {
                didCommitIncomingSkin = true
                phase = .settlingNew
                physics.bodySquash.velocity -= 2.6
                physics.headOffsetY.velocity += 34
                physics.earTwitch.velocity += 5.8
                physics.headYaw.value = 0
                physics.headYaw.target = 0
                physics.earFold.target = 0
                onCommitSkin?(pendingCoat, pendingCustomSkinID, incomingEye, incomingSkin.name)
            } else {
                phase = .settlingNew
            }
        } else {
            phase = .idle
            elapsed = 0
        }
    }
}

// MARK: - Procedural 2.5D Side-Profile Walking & Confrontation Renderer

enum ShiftHandoverRenderer {
    private static func smoothStep(_ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, x))
        return t * t * (3.0 - 2.0 * t)
    }

    private static func nsColor(_ sc: SkinColor, alphaMul: CGFloat = 1.0) -> NSColor {
        NSColor(srgbRed: sc.r, green: sc.g, blue: sc.b, alpha: sc.a * alphaMul)
    }

    static func drawEnteringIncomingCat(in ctx: CGContext, handover: ShiftHandoverState, whiteOutline: Bool) {
        let u = smoothStep(handover.elapsed / ShiftHandoverState.enterEnd)
        let x: CGFloat = -48.0 + (108.0 - (-48.0)) * u
        let gaitPhase = handover.elapsed * 14.5
        drawSideProfileCat(
            in: ctx,
            skin: handover.incomingSkin,
            eyeTheme: handover.incomingEye,
            footCenterX: x,
            groundY: 243.0,
            facingRight: true,
            walkAmount: 1.0 - max(0, (u - 0.85) / 0.15),
            gaitPhase: gaitPhase,
            archAmount: max(0, (u - 0.72) / 0.28) * 0.45,
            yowlOpen: 0,
            whiteOutline: whiteOutline,
            alpha: 1.0
        )
    }

    static func drawConfrontationOrExit(in ctx: CGContext, handover: ShiftHandoverState, whiteOutline: Bool) {
        if handover.phase == .arguing {
            let localT = handover.elapsed - ShiftHandoverState.enterEnd
            let dur = ShiftHandoverState.argueEnd - ShiftHandoverState.enterEnd
            let archIn = min(1.0, localT / 0.22)
            // Alternating rapid cat bickering syllables: incoming yowls -> outgoing snaps back -> chorus!
            let inTalk = max(0, sin(localT * 17.5) * (sin(localT * 3.8) > -0.2 ? 1.0 : 0.2))
            let outTalk = max(0, sin(localT * 19.0 + 1.9) * (sin(localT * 3.8 + 2.1) > -0.25 ? 1.0 : 0.2))
            let lungeIn = sin(localT * 9.2) * 3.2
            let lungeOut = sin(localT * 8.6 + 1.4) * 3.0

            drawSideProfileCat(
                in: ctx,
                skin: handover.incomingSkin,
                eyeTheme: handover.incomingEye,
                footCenterX: 108.0 + max(0, lungeIn),
                groundY: 243.0,
                facingRight: true,
                walkAmount: 0,
                gaitPhase: localT * 12.0,
                archAmount: 0.92 * archIn,
                yowlOpen: inTalk,
                whiteOutline: whiteOutline,
                alpha: 1.0
            )

            drawSideProfileCat(
                in: ctx,
                skin: handover.outgoingSkin,
                eyeTheme: handover.outgoingEye,
                footCenterX: 238.0 - max(0, lungeOut),
                groundY: 243.0,
                facingRight: false,
                walkAmount: 0,
                gaitPhase: localT * 13.5 + 1.2,
                archAmount: 0.96 * archIn,
                yowlOpen: outTalk,
                whiteOutline: whiteOutline,
                alpha: 1.0
            )

            // Draw comic confrontation sparks & angry clash icons right between their noses!
            let clashAlpha = min(1.0, min(localT / 0.18, (dur - localT) / 0.20))
            drawArgumentSparks(in: ctx, center: CGPoint(x: 173.0, y: 162.0), time: localT, alpha: clashAlpha)
        } else if handover.phase == .exitingOld {
            let u = (handover.elapsed - ShiftHandoverState.argueEnd) / (ShiftHandoverState.exitEnd - ShiftHandoverState.argueEnd)
            let clampedU = max(0, min(1, u))
            // Outgoing cat turns right and trots off-canvas!
            let oldWalkU = smoothStep(clampedU)
            let oldX: CGFloat = 238.0 + (416.0 - 238.0) * oldWalkU
            let oldAlpha: CGFloat = clampedU > 0.80 ? max(0, 1.0 - (clampedU - 0.80) / 0.20) : 1.0

            // Incoming cat waits 0.18s watching it leave, then trots cleanly to seat center x = 184!
            let newMoveRaw = max(0, min(1, (clampedU - 0.16) / 0.78))
            let newMoveU = smoothStep(newMoveRaw)
            let newX: CGFloat = 108.0 + (184.0 - 108.0) * newMoveU
            let newWalking: CGFloat = (clampedU > 0.16 && clampedU < 0.94) ? 1.0 : 0.0

            drawSideProfileCat(
                in: ctx,
                skin: handover.incomingSkin,
                eyeTheme: handover.incomingEye,
                footCenterX: newX,
                groundY: 243.0,
                facingRight: true,
                walkAmount: newWalking,
                gaitPhase: handover.elapsed * 14.5,
                archAmount: max(0, (1.0 - clampedU * 2.5)) * 0.5,
                yowlOpen: 0,
                whiteOutline: whiteOutline,
                alpha: 1.0
            )

            if oldAlpha > 0.01 {
                drawSideProfileCat(
                    in: ctx,
                    skin: handover.outgoingSkin,
                    eyeTheme: handover.outgoingEye,
                    footCenterX: oldX,
                    groundY: 243.0,
                    facingRight: true,
                    walkAmount: 1.0,
                    gaitPhase: handover.elapsed * 16.0 + 0.8,
                    archAmount: 0.15,
                    yowlOpen: 0,
                    whiteOutline: whiteOutline,
                    alpha: oldAlpha
                )
            }
        }
    }

    static func drawSettleRingBurst(in ctx: CGContext, handover: ShiftHandoverState) {
        let p = max(0, min(1, (handover.elapsed - ShiftHandoverState.exitEnd) / (ShiftHandoverState.totalEnd - ShiftHandoverState.exitEnd)))
        guard p > 0 && p < 1 else { return }
        let center = CGPoint(x: CatPhysics.seatAnchor.x, y: 178)
        let radius = 34.0 + p * 112.0
        let alpha = (1.0 - p) * 0.62
        ctx.saveGState()
        ctx.setStrokeColor(handover.incomingEye.primaryColor.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(3.4 * (1.0 - p))
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.restoreGState()
    }

    static func drawCloudVoiceAura(in ctx: CGContext, physics: CatPhysics, skin: SkinSpec) {
        let headCenter = CatRenderer.headPosition(physics, skin: skin)
        let pulse = 0.5 + 0.5 * sin(physics.time * 6.4)
        let badgeCenter = CGPoint(x: headCenter.x + 42 * skin.shape.headScale, y: headCenter.y - 34 * skin.shape.headScale)

        ctx.saveGState()
        // Subtle glowing wireless cloud-typing pill beside ear
        let pillRect = CGRect(x: badgeCenter.x - 16, y: badgeCenter.y - 10, width: 32, height: 20)
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.setShadow(offset: .zero, blur: 8, color: NSColor(calibratedRed: 0.38, green: 0.34, blue: 0.98, alpha: 0.55).cgColor)
        ctx.setFillColor(NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.18, alpha: 0.88).cgColor)
        ctx.addPath(pillPath)
        ctx.fillPath()

        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.52, green: 0.48, blue: 1.0, alpha: 0.72).cgColor)
        ctx.setLineWidth(1.1)
        ctx.addPath(pillPath)
        ctx.strokePath()

        // 3 animated voice waveform bars inside the mini cloud pill
        let heights: [CGFloat] = [
            5.0 + 6.0 * abs(sin(physics.time * 9.5)),
            7.0 + 7.5 * pulse,
            4.5 + 6.5 * abs(cos(physics.time * 8.2))
        ]
        ctx.setFillColor(NSColor(calibratedRed: 0.78, green: 0.95, blue: 0.28, alpha: 0.96).cgColor)
        for i in 0..<3 {
            let bh = heights[i]
            let bx = badgeCenter.x - 7.5 + CGFloat(i) * 6.0
            let bar = CGRect(x: bx, y: badgeCenter.y - bh * 0.5, width: 3.0, height: bh)
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    // MARK: - Detailed Side-Profile Cat Vector Builder

    private static func drawSideProfileCat(
        in ctx: CGContext,
        skin: SkinSpec,
        eyeTheme: EyeColorTheme,
        footCenterX: CGFloat,
        groundY: CGFloat,
        facingRight: Bool,
        walkAmount: CGFloat,
        gaitPhase: CGFloat,
        archAmount: CGFloat,
        yowlOpen: CGFloat,
        whiteOutline: Bool,
        alpha: CGFloat
    ) {
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.translateBy(x: footCenterX, y: groundY)
        if !facingRight {
            ctx.scaleBy(x: -1, y: 1)
        }

        let pal = skin.palette
        let isOrangeWhite = (skin.id == "builtin:3")
        let isShorthair = (skin.id == "builtin:2")
        let isClassicBlack = (skin.id == "builtin:0")
        let isColorpoint = skin.colorpoint

        // Resolve authentic breed coat colors for side-profile silhouette
        let mainCoat: NSColor = isOrangeWhite
            ? nsColor(pal.earOuter) // warm ginger coat on back & cap, white chest/legs!
            : nsColor(pal.body)
        let chestBellyColor: NSColor? = (pal.belly != nil) ? nsColor(pal.belly!) : nil
        let legColor: NSColor = nsColor(pal.legs)
        let pawColor: NSColor = nsColor(pal.paws)
        let earColor: NSColor = nsColor(pal.earOuter)
        let tailColor: NSColor = nsColor(pal.tail)
        let pointColor: NSColor? = pal.points.map { nsColor($0) }
        let stripeColor: NSColor? = pal.stripes.map { nsColor($0, alphaMul: 0.65) }
        let irisColor: NSColor = pal.iris.map { nsColor($0) } ?? eyeTheme.primaryColor

        let bobY = walkAmount * abs(sin(gaitPhase * 2.0)) * -3.2
        let archLift = archAmount * 15.0

        // Helper closure to paint entire silhouette either as crisp white sticker outline pass or main color pass
        func buildTorsoPath() -> CGPath {
            let p = CGMutablePath()
            // Chest front (+28, -42) -> arched spine -> rump (-30, -40) -> belly -> back to chest
            p.move(to: CGPoint(x: 27, y: -44 + bobY))
            p.addCurve(
                to: CGPoint(x: -30, y: -42 + bobY),
                control1: CGPoint(x: 10, y: -56 - archLift + bobY),
                control2: CGPoint(x: -14, y: -58 - archLift + bobY)
            )
            p.addCurve(
                to: CGPoint(x: -26, y: -22 + bobY),
                control1: CGPoint(x: -37, y: -36 + bobY),
                control2: CGPoint(x: -35, y: -25 + bobY)
            )
            p.addCurve(
                to: CGPoint(x: 26, y: -22 + bobY),
                control1: CGPoint(x: -8, y: -19 - archLift * 0.32 + bobY),
                control2: CGPoint(x: 12, y: -18 - archLift * 0.20 + bobY)
            )
            p.addCurve(
                to: CGPoint(x: 27, y: -44 + bobY),
                control1: CGPoint(x: 33, y: -26 + bobY),
                control2: CGPoint(x: 33, y: -38 + bobY)
            )
            p.closeSubpath()
            return p
        }

        let headCenter = CGPoint(x: 32 - archAmount * 3.0, y: -58 + bobY + archAmount * 3.5)
        let headRx: CGFloat = 22.5 * skin.shape.headScale
        let headRy: CGFloat = 19.5 * skin.shape.headScale

        func drawLimb(hipX: CGFloat, phaseOffset: CGFloat, isBackLayer: Bool) {
            let swing = sin(gaitPhase + phaseOffset) * 11.5 * walkAmount
            let lift = max(0, -cos(gaitPhase + phaseOffset)) * 6.5 * walkAmount
            let stanceSpread: CGFloat = (1.0 - walkAmount) * (isBackLayer ? -4.5 : 3.5)
            let footX = hipX + swing + stanceSpread
            let footY = -lift

            let path = CGMutablePath()
            path.move(to: CGPoint(x: hipX, y: -26 + bobY))
            path.addQuadCurve(
                to: CGPoint(x: footX, y: footY - 3),
                control: CGPoint(x: (hipX + footX) * 0.5 + (hipX > 0 ? 2.5 : -2.5), y: -13 + bobY * 0.5)
            )

            ctx.saveGState()
            if whiteOutline {
                ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
                ctx.setLineWidth(12.2)
                ctx.setLineCap(.round)
                ctx.addPath(path)
                ctx.strokePath()
            }
            let baseShade: CGFloat = isBackLayer ? 0.84 : 1.0
            let limbCol = isBackLayer
                ? NSColor(calibratedRed: legColor.redComponent * baseShade,
                          green: legColor.greenComponent * baseShade,
                          blue: legColor.blueComponent * baseShade,
                          alpha: 1.0)
                : legColor
            ctx.setStrokeColor(limbCol.cgColor)
            ctx.setLineWidth(9.2)
            ctx.setLineCap(.round)
            ctx.addPath(path)
            ctx.strokePath()

            // Cute paw sock tip
            let pawRect = CGRect(x: footX - 5.2, y: footY - 6.8, width: 11.4, height: 6.8)
            ctx.setFillColor(pawColor.cgColor)
            ctx.fillEllipse(in: pawRect)
            ctx.restoreGState()
        }

        // 1. Tail (whips fast & puffs up when arguing!)
        let tailPath = CGMutablePath()
        let tailRoot = CGPoint(x: -29, y: -38 + bobY)
        let tailWhip = sin(gaitPhase * (archAmount > 0.3 ? 1.8 : 0.7)) * (6.0 + archAmount * 14.0)
        let tailTip = CGPoint(x: -54 - archAmount * 4.0, y: -74 - archAmount * 10.0 + tailWhip * 0.4 + bobY)
        tailPath.move(to: tailRoot)
        tailPath.addCurve(
            to: tailTip,
            control1: CGPoint(x: -48, y: -42 + tailWhip + bobY),
            control2: CGPoint(x: -60, y: -58 - tailWhip * 0.6 + bobY)
        )
        let tailWidth: CGFloat = (9.0 + archAmount * 4.2) * skin.shape.tailThickness
        if whiteOutline {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
            ctx.setLineWidth(tailWidth + 3.2)
            ctx.setLineCap(.round)
            ctx.addPath(tailPath)
            ctx.strokePath()
        }
        ctx.setStrokeColor(tailColor.cgColor)
        ctx.setLineWidth(tailWidth)
        ctx.setLineCap(.round)
        ctx.addPath(tailPath)
        ctx.strokePath()

        // 2. Far-side legs (diagonal gait)
        drawLimb(hipX: -19, phaseOffset: .pi, isBackLayer: true)
        drawLimb(hipX: 18, phaseOffset: 0, isBackLayer: true)

        // 3. Torso + Head white sticker outline pass
        let torsoPath = buildTorsoPath()
        let headRect = CGRect(x: headCenter.x - headRx, y: headCenter.y - headRy, width: headRx * 2, height: headRy * 2)
        if whiteOutline {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.96).cgColor)
            ctx.setLineWidth(3.4)
            ctx.setLineJoin(.round)
            ctx.addPath(torsoPath)
            ctx.strokePath()
            ctx.strokeEllipse(in: headRect)
            ctx.restoreGState()
        }

        // 4. Torso fill + breed belly/stripes
        ctx.saveGState()
        ctx.addPath(torsoPath)
        ctx.clip()
        ctx.setFillColor(mainCoat.cgColor)
        ctx.fill(CGRect(x: -50, y: -90, width: 100, height: 90))

        if let belly = chestBellyColor {
            ctx.setFillColor(belly.cgColor)
            // White chest bib & lower belly for orange-white / shorthair
            ctx.fillEllipse(in: CGRect(x: 8, y: -46 + bobY, width: 28, height: 28))
            ctx.fillEllipse(in: CGRect(x: -24, y: -29 + bobY, width: 48, height: 14))
        }
        if let stripe = stripeColor, (isShorthair || isOrangeWhite || !skin.marks.isEmpty) {
            ctx.setStrokeColor(stripe.cgColor)
            ctx.setLineWidth(3.0)
            ctx.setLineCap(.round)
            for sx in [-18.0, -7.0, 4.0] as [CGFloat] {
                ctx.move(to: CGPoint(x: sx, y: -54 - archLift * 0.7 + bobY))
                ctx.addQuadCurve(
                    to: CGPoint(x: sx - 2, y: -31 + bobY),
                    control: CGPoint(x: sx + 3, y: -42 - archLift * 0.4 + bobY)
                )
                ctx.strokePath()
            }
        }
        ctx.restoreGState()

        // 5. Near-side legs
        drawLimb(hipX: -17, phaseOffset: 0, isBackLayer: false)
        drawLimb(hipX: 20, phaseOffset: .pi, isBackLayer: false)

        // 6. Back Ear (slightly behind head)
        let earFlatten = archAmount * 12.0 // Airplane ears flattened backward during argument!
        func makeEarPath(offsetX: CGFloat, scale: CGFloat) -> CGPath {
            let ep = CGMutablePath()
            let base = CGPoint(x: headCenter.x + offsetX, y: headCenter.y - headRy * 0.68)
            ep.move(to: CGPoint(x: base.x - 6 * scale, y: base.y + 4))
            ep.addLine(to: CGPoint(x: base.x - (3 + earFlatten) * scale, y: base.y - (16 - archAmount * 4.0) * scale))
            ep.addLine(to: CGPoint(x: base.x + 8 * scale, y: base.y + 2))
            ep.closeSubpath()
            return ep
        }

        let farEar = makeEarPath(offsetX: 2, scale: 0.88)
        if whiteOutline {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
            ctx.setLineWidth(3.0)
            ctx.addPath(farEar)
            ctx.strokePath()
        }
        ctx.setFillColor(earColor.cgColor)
        ctx.addPath(farEar)
        ctx.fillPath()

        // 7. Head + Siamese face mask / OrangeWhite muzzle
        ctx.saveGState()
        ctx.addEllipse(in: headRect)
        ctx.clip()
        let headFill = isOrangeWhite ? mainCoat : nsColor(pal.headBody ?? pal.body)
        ctx.setFillColor(headFill.cgColor)
        ctx.fill(headRect)

        if isColorpoint, let ptCol = pointColor {
            // Signature Siamese dark roasted face mask on front muzzle!
            ctx.setFillColor(ptCol.cgColor)
            ctx.fillEllipse(in: CGRect(x: headCenter.x + 2, y: headCenter.y - 10, width: 24, height: 22))
        } else if isOrangeWhite, let belly = chestBellyColor {
            // Cute white lower cheek & muzzle blaze on orange-white cat
            ctx.setFillColor(belly.cgColor)
            ctx.fillEllipse(in: CGRect(x: headCenter.x + 3, y: headCenter.y + 1, width: 23, height: 19))
        }
        ctx.restoreGState()

        // Near Ear (on top of head)
        let nearEar = makeEarPath(offsetX: -6, scale: 1.0)
        if whiteOutline {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
            ctx.setLineWidth(3.0)
            ctx.addPath(nearEar)
            ctx.strokePath()
        }
        ctx.setFillColor(earColor.cgColor)
        ctx.addPath(nearEar)
        ctx.fillPath()
        if let inner = pal.earInner {
            let innerEar = makeEarPath(offsetX: -5.5, scale: 0.56)
            ctx.setFillColor(nsColor(inner).cgColor)
            ctx.addPath(innerEar)
            ctx.fillPath()
        }

        // 8. Expressive Eye (slanted fierce glare during argument, bright round/almond when walking!)
        let eyeCenter = CGPoint(x: headCenter.x + 9.5, y: headCenter.y - 2.2)
        ctx.saveGState()
        let eyeRect = CGRect(x: eyeCenter.x - 6.2, y: eyeCenter.y - 5.6, width: 12.4, height: 11.2)
        ctx.addEllipse(in: eyeRect)
        ctx.clip()
        ctx.setFillColor(irisColor.cgColor)
        ctx.fill(eyeRect)

        // Vertical slit pupil
        let pupilW: CGFloat = archAmount > 0.4 ? 2.8 : 4.2
        ctx.setFillColor(NSColor(calibratedWhite: 0.06, alpha: 0.96).cgColor)
        ctx.fillEllipse(in: CGRect(x: eyeCenter.x - pupilW * 0.5 + 1.2, y: eyeCenter.y - 4.4, width: pupilW, height: 8.8))

        // Crisp eye highlight dot
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        ctx.fillEllipse(in: CGRect(x: eyeCenter.x - 2.2, y: eyeCenter.y - 3.4, width: 2.6, height: 2.6))

        // Angry slanted upper eyelid during confrontation!
        if archAmount > 0.25 {
            let lidCol = isColorpoint ? (pointColor ?? mainCoat) : headFill
            ctx.setFillColor(lidCol.cgColor)
            let lid = CGMutablePath()
            lid.move(to: CGPoint(x: eyeCenter.x - 8, y: eyeCenter.y - 8))
            lid.addLine(to: CGPoint(x: eyeCenter.x + 8, y: eyeCenter.y - 8))
            lid.addLine(to: CGPoint(x: eyeCenter.x + 8, y: eyeCenter.y - 0.5 * archAmount + 1.2))
            lid.addLine(to: CGPoint(x: eyeCenter.x - 8, y: eyeCenter.y - 5.2))
            lid.closeSubpath()
            ctx.addPath(lid)
            ctx.fillPath()
        }
        ctx.restoreGState()

        // 9. Animated Yowling Mouth ("哇啦哇啦") & Whiskers
        if yowlOpen > 0.08 {
            let mouthOpenH = 2.5 + yowlOpen * 6.2
            let mouthRect = CGRect(x: headCenter.x + 13.5, y: headCenter.y + 4.8, width: 7.5, height: mouthOpenH)
            ctx.setFillColor(NSColor(calibratedRed: 0.86, green: 0.34, blue: 0.42, alpha: 0.95).cgColor)
            ctx.fillEllipse(in: mouthRect)
            // Tiny cute white fang!
            ctx.setFillColor(NSColor.white.cgColor)
            let fang = CGMutablePath()
            fang.move(to: CGPoint(x: mouthRect.minX + 2.0, y: mouthRect.minY + 0.5))
            fang.addLine(to: CGPoint(x: mouthRect.minX + 3.4, y: mouthRect.minY + 3.2))
            fang.addLine(to: CGPoint(x: mouthRect.minX + 4.8, y: mouthRect.minY + 0.5))
            fang.closeSubpath()
            ctx.addPath(fang)
            ctx.fillPath()
        }

        // Whiskers
        let whiskerCol = isClassicBlack
            ? NSColor(calibratedWhite: 0.92, alpha: 0.72)
            : nsColor(pal.whiskers)
        ctx.setStrokeColor(whiskerCol.cgColor)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        for (wy, dy) in [(3.5, -1.8), (7.0, 0.8)] as [(CGFloat, CGFloat)] {
            ctx.move(to: CGPoint(x: headCenter.x + 14, y: headCenter.y + wy))
            ctx.addLine(to: CGPoint(x: headCenter.x + 27, y: headCenter.y + wy + dy))
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    private static func drawArgumentSparks(in ctx: CGContext, center: CGPoint, time: CGFloat, alpha: CGFloat) {
        guard alpha > 0.02 else { return }
        ctx.saveGState()
        ctx.setAlpha(alpha)

        // Pulsing comic anger cross-vein (💢) & lightning sparks between the two bickering cats!
        let pulse = 0.88 + 0.20 * sin(time * 16.0)
        ctx.translateBy(x: center.x, y: center.y + sin(time * 9.0) * 3.0)
        ctx.scaleBy(x: pulse, y: pulse)

        ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.32, blue: 0.28, alpha: 0.95).cgColor)
        ctx.setLineWidth(2.6)
        ctx.setLineCap(.round)

        // 4 curved 💢 vein ticks
        let offsets: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-9, -3, -3, -9),
            (9, -3, 3, -9),
            (-9, 3, -3, 9),
            (9, 3, 3, 9)
        ]
        for (x1, y1, x2, y2) in offsets {
            ctx.move(to: CGPoint(x: x1, y: y1))
            ctx.addQuadCurve(to: CGPoint(x: x2, y: y2), control: CGPoint(x: x1 * 0.28, y: y2 * 0.28))
            ctx.strokePath()
        }

        // Tiny golden spark rays
        ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.24, alpha: 0.90).cgColor)
        ctx.setLineWidth(2.0)
        let raySpin = time * 4.0
        for i in 0..<3 {
            let ang = raySpin + CGFloat(i) * (.pi * 2.0 / 3.0)
            let r0: CGFloat = 13.0
            let r1: CGFloat = 19.0
            ctx.move(to: CGPoint(x: cos(ang) * r0, y: sin(ang) * r0))
            ctx.addLine(to: CGPoint(x: cos(ang) * r1, y: sin(ang) * r1))
            ctx.strokePath()
        }

        ctx.restoreGState()
    }
}

// MARK: - Real Douyin Dual-Cat Bickering Audio Bank (Rotates Authentic Clips!)

final class PetAudioBank {
    static let shared = PetAudioBank()

    private static let clipNames = [
        "cat_bicker_01",
        "cat_bicker_02",
        "cat_bicker_03",
        "cat_bicker_04"
    ]

    private var player: AVAudioPlayer?
    private var clipCursor: Int = 0
    private var resolvedURLs: [URL] = []

    private init() {
        resolvedURLs = Self.discoverClips()
    }

    var availableClipCount: Int {
        if resolvedURLs.isEmpty {
            resolvedURLs = Self.discoverClips()
        }
        return resolvedURLs.count
    }

    func playNextBickerClip() {
        if resolvedURLs.isEmpty {
            resolvedURLs = Self.discoverClips()
        }
        guard !resolvedURLs.isEmpty else { return }
        let url = resolvedURLs[clipCursor % resolvedURLs.count]
        clipCursor += 1

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 0.72
            p.prepareToPlay()
            p.play()
            self.player = p
        } catch {
            // Non-fatal if output audio device is unavailable
        }
    }

    private static func discoverClips() -> [URL] {
        var found: [URL] = []
        let cwd = FileManager.default.currentDirectoryPath
        for name in clipNames {
            if let bundled = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "PetAudio") {
                found.append(bundled)
            } else if let flat = Bundle.main.url(forResource: name, withExtension: "m4a") {
                found.append(flat)
            } else {
                let devPath = (cwd as NSString).appendingPathComponent("Resources/PetAudio/\(name).m4a")
                if FileManager.default.fileExists(atPath: devPath) {
                    found.append(URL(fileURLWithPath: devPath))
                }
            }
        }
        return found
    }
}
