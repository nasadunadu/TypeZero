import Foundation
import AppKit
import CoreGraphics

// MARK: - Parametric Fish Species DNA (`FishPhotoDNA` -> `.kurocat` v2 `"species": "fish"`)

public enum FishBodyProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case pufferTorpedo = "puffer_torpedo"   // 河豚/狗头（方头圆肚 + 鼓球基因）
    case goldfishRound = "goldfish_round"   // 金鱼/兰寿/泰狮（圆滚滚大肚 + 飘逸宽尾）
    case bettaFlow     = "betta_flow"       // 斗鱼（修长体态 + 超长半月飘鳍）
    case koiStream     = "koi_stream"       // 锦鲤（经典流线体 + 叉形尾）
    case angelfishDisc = "angelfish_disc"   // 神仙鱼（高背菱形 + 长背臀鳍）
    case clownfishOval = "clownfish_oval"   // 小丑鱼（小巧椭圆 + 圆润短鳍）

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pufferTorpedo: return "河豚 / 狗头"
        case .goldfishRound: return "圆肚金鱼"
        case .bettaFlow:     return "飘逸斗鱼"
        case .koiStream:     return "流线锦鲤"
        case .angelfishDisc: return "神仙鱼"
        case .clownfishOval: return "小丑鱼"
        }
    }
}

public enum FishSpotPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case ringedOcelli    = "ringed_ocelli"    // 红斑狗头灵魂：深褐黑外环 + 鲜红内芯双层靶心斑
    case spotted         = "spotted"          // 斑点/波点
    case stripedVertical = "striped_vertical" // 竖条纹（小丑鱼/虎皮/神仙）
    case calicoBlotch    = "calico_blotch"    // 锦鲤/三色块斑
    case solidGradient   = "solid_gradient"   // 纯色/金属渐变（斗鱼/红金鱼）
    case saddleBack      = "saddle_back"      // 背部鞍斑渐变

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ringedOcelli:    return "红芯环斑"
        case .spotted:         return "圆点斑"
        case .stripedVertical: return "竖条纹"
        case .calicoBlotch:    return "块斑"
        case .solidGradient:   return "纯色渐变"
        case .saddleBack:      return "背鞍纹"
        }
    }
}

public struct FishPhotoDNA: Codable, Equatable, Sendable {
    public var name: String
    public var breedBadge: String
    public var bodyProfile: FishBodyProfile
    public var spotPattern: FishSpotPattern
    public var primaryBodyHex: String   // e.g. #EFE4C4 奶油香槟黄
    public var bellyHex: String         // e.g. #F7F3E7 象牙白圆肚
    public var dorsalHex: String        // e.g. #B85C46 头背暖棕红鞍斑
    public var spotOuterHex: String     // e.g. #4A2A24 深褐黑斑外环
    public var spotInnerHex: String     // e.g. #DF3B36 鲜朱红斑内芯
    public var finHex: String           // e.g. #C5B268 金橄榄色扇形条纹尾鳍/胸鳍
    public var irisHex: String          // e.g. #E24E24 高凸琥珀红大圆眼
    public var hasBuckTeeth: Bool       // 河豚标志性露两颗小白板牙
    public var canPuffUp: Bool          // 河豚专属：戳肚/拎起鼓成刺球
    public var finLength: Double        // 0.75...1.65
    public var plumpness: Double        // 0.85...1.30
    public var spotSeed: Int

    public init(
        name: String = "红斑",
        breedBadge: String = "红斑狗头河豚",
        bodyProfile: FishBodyProfile = .pufferTorpedo,
        spotPattern: FishSpotPattern = .ringedOcelli,
        primaryBodyHex: String = "#EFE4C4",
        bellyHex: String = "#F7F3E7",
        dorsalHex: String = "#B85C46",
        spotOuterHex: String = "#4A2A24",
        spotInnerHex: String = "#DF3B36",
        finHex: String = "#C5B268",
        irisHex: String = "#E24E24",
        hasBuckTeeth: Bool = true,
        canPuffUp: Bool = true,
        finLength: Double = 1.0,
        plumpness: Double = 1.12,
        spotSeed: Int = 7
    ) {
        self.name = name
        self.breedBadge = breedBadge
        self.bodyProfile = bodyProfile
        self.spotPattern = spotPattern
        self.primaryBodyHex = CatPhotoDNA.normalizeHex(primaryBodyHex, fallback: "#EFE4C4")
        self.bellyHex = CatPhotoDNA.normalizeHex(bellyHex, fallback: "#F7F3E7")
        self.dorsalHex = CatPhotoDNA.normalizeHex(dorsalHex, fallback: "#B85C46")
        self.spotOuterHex = CatPhotoDNA.normalizeHex(spotOuterHex, fallback: "#4A2A24")
        self.spotInnerHex = CatPhotoDNA.normalizeHex(spotInnerHex, fallback: "#DF3B36")
        self.finHex = CatPhotoDNA.normalizeHex(finHex, fallback: "#C5B268")
        self.irisHex = CatPhotoDNA.normalizeHex(irisHex, fallback: "#E24E24")
        self.hasBuckTeeth = hasBuckTeeth
        self.canPuffUp = canPuffUp
        self.finLength = min(1.65, max(0.75, finLength))
        self.plumpness = min(1.30, max(0.85, plumpness))
        self.spotSeed = spotSeed
    }

    public mutating func sanitize() {
        name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        if name.isEmpty { name = "泡泡" }
        breedBadge = String(breedBadge.trimmingCharacters(in: .whitespacesAndNewlines).prefix(18))
        if breedBadge.isEmpty { breedBadge = bodyProfile.title }
        primaryBodyHex = CatPhotoDNA.normalizeHex(primaryBodyHex, fallback: "#EFE4C4")
        bellyHex = CatPhotoDNA.normalizeHex(bellyHex, fallback: "#F7F3E7")
        dorsalHex = CatPhotoDNA.normalizeHex(dorsalHex, fallback: "#B85C46")
        spotOuterHex = CatPhotoDNA.normalizeHex(spotOuterHex, fallback: "#4A2A24")
        spotInnerHex = CatPhotoDNA.normalizeHex(spotInnerHex, fallback: "#DF3B36")
        finHex = CatPhotoDNA.normalizeHex(finHex, fallback: "#C5B268")
        irisHex = CatPhotoDNA.normalizeHex(irisHex, fallback: "#E24E24")
        finLength = min(1.65, max(0.75, finLength))
        plumpness = min(1.30, max(0.85, plumpness))
    }

    public static var crossRiverPufferPreset: FishPhotoDNA {
        FishPhotoDNA()
    }
}

// MARK: - Fish DNA Compiler (Compiles `FishPhotoDNA` -> `.kurocat` v2 JSON with `"species": "fish"`)

public enum FishCoatCompiler {
    static func compileSkinSpec(from rawDNA: FishPhotoDNA, previewPNG: Data? = nil) throws -> SkinSpec {
        let data = try compileJSONData(from: rawDNA, previewPNG: previewPNG)
        return try SkinSpec.parse(data)
    }

    public static func compileJSONData(from rawDNA: FishPhotoDNA, previewPNG: Data? = nil, author: String = "TypeZero 鱼类骨骼") throws -> Data {
        var dna = rawDNA
        dna.sanitize()

        let palette: [String: Any] = [
            "body": dna.primaryBodyHex,
            "belly": dna.bellyHex,
            "legs": dna.finHex,
            "paws": dna.finHex,
            "tail": dna.finHex,
            "earOuter": dna.dorsalHex,
            "iris": dna.irisHex,
            "irisLeft": dna.irisHex,
            "irisRight": dna.irisHex,
            "stripes": dna.spotOuterHex,
            "nose": dna.spotInnerHex
        ]

        let dnaData = try JSONEncoder().encode(dna)
        let dnaDict = (try JSONSerialization.jsonObject(with: dnaData) as? [String: Any]) ?? [:]

        var root: [String: Any] = [
            "formatVersion": SkinSpec.formatVersion,
            "species": "fish",
            "name": dna.name,
            "author": author,
            "palette": palette,
            "typezeroFishDNA": dnaDict
        ]

        if let png = previewPNG, !png.isEmpty, png.count <= 420 * 1024 {
            root["preview"] = "data:image/png;base64," + png.base64EncodedString()
        }

        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }
}

// MARK: - Calm Steady Front-Facing Aquatic Physics (Rock-Steady Body Like KuroCat + Left/Right Elongated Typing Fins!)

struct FishBubbleParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var radius: CGFloat
    var age: CGFloat
    var life: CGFloat
}

struct FishSplashDroplet {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var radius: CGFloat
    var age: CGFloat
    var life: CGFloat
}

final class FishSwimPhysics {
    /// Rock-steady centered anchor right behind the keyboard — identical visual grounding to KuroCat!
    static let bodyCenterAnchor = CGPoint(x: 184, y: 170)

    var pos = Spring2D(FishSwimPhysics.bodyCenterAnchor)
    var microTilt = Spring1D(0)        // gentle ±0.03 rad head lean (never dizzy!)
    var puff = Spring1D(0)             // 0 = calm front puffer, 1 = puffed-up spiky balloon in place!
    var leftFinSlap = Spring1D(0)      // subtle tap recoil on left elongated fin
    var rightFinSlap = Spring1D(0)     // subtle tap recoil on right elongated fin
    var mouthOpen = Spring1D(0.24)     // 0.24 = goofy buck-tooth smile, 0.78 = blowing bubbles / puff

    private(set) var swimPhase: CGFloat = 0
    private(set) var finPhase: CGFloat = 0
    private(set) var puffHoldTimer: CGFloat = 0
    private(set) var recentKeyTimer: CGFloat = 0
    private(set) var targetKeyPoint: CGPoint? = nil
    private var nextBubbleCooldown: CGFloat = 2.0

    var bubbles: [FishBubbleParticle] = []
    var droplets: [FishSplashDroplet] = []

    func triggerKeySwoop(at keyPt: CGPoint, isLeftSide: Bool, now: CFTimeInterval) {
        targetKeyPoint = keyPt
        recentKeyTimer = 0.28
        // Body stays rock-steady; only a tiny micro-tilt toward the active side + fin slap impulse!
        microTilt.target = isLeftSide ? -0.028 : 0.028
        if isLeftSide {
            leftFinSlap.value = min(1.0, leftFinSlap.value + 0.85)
        } else {
            rightFinSlap.value = min(1.0, rightFinSlap.value + 0.85)
        }

        // 3 gentle micro droplets on the tapped keycap
        for idx in 0..<3 {
            let ang = -CGFloat.pi * (0.28 + CGFloat(idx) * 0.22) + CGFloat.random(in: -0.08...0.08)
            let spd = CGFloat.random(in: 34...58)
            droplets.append(FishSplashDroplet(
                x: keyPt.x + CGFloat.random(in: -4...4),
                y: keyPt.y - 5,
                vx: cos(ang) * spd,
                vy: sin(ang) * spd - 12,
                radius: CGFloat.random(in: 2.0...3.2),
                age: 0,
                life: CGFloat.random(in: 0.26...0.38)
            ))
        }
        if droplets.count > 16 { droplets.removeFirst(droplets.count - 16) }
        _ = now
    }

    func triggerPuffUp(duration: CGFloat = 2.1) {
        puffHoldTimer = max(puffHoldTimer, duration)
        puff.target = 1.0
        puff.velocity = max(puff.velocity, 6.0)
        mouthOpen.value = 0.82
        spawnMouthBubbles(count: 3)
    }

    func registerBellyPoke(now: CFTimeInterval) {
        triggerPuffUp(duration: 2.2)
        _ = now
    }

    func spawnMouthBubbles(count: Int) {
        // Spawn clearly outside & above the upper-right head contour so bubbles NEVER overlap the eyeball!
        let baseX = pos.point.x + 58.0 + puff.value * 18.0
        let baseY = pos.point.y - 46.0 - puff.value * 14.0
        for i in 0..<count {
            let f = CGFloat(i)
            bubbles.append(FishBubbleParticle(
                x: baseX + f * 7.5 + CGFloat.random(in: -2...4),
                y: baseY - f * 15.0,
                vx: CGFloat.random(in: 4...10),
                vy: -CGFloat.random(in: 22...32),
                radius: max(3.2, 5.8 - f * 1.0 + CGFloat.random(in: -0.4...0.4)),
                age: 0,
                life: CGFloat.random(in: 1.4...2.2)
            ))
        }
        if bubbles.count > 14 { bubbles.removeFirst(bubbles.count - 14) }
    }

    func step(
        dt: CGFloat,
        now: CFTimeInterval,
        time: CGFloat,
        mouseActive: Bool,
        mouseCenter: CGPoint,
        mouseClickLeft: Bool,
        mouseClickRight: Bool,
        isDragging: Bool,
        anger: CGFloat,
        petIntensity: CGFloat,
        canPuffUp: Bool,
        reducedMotion: Bool
    ) {
        let motionMul: CGFloat = reducedMotion ? 0.35 : 1.0
        // Calm, soothing tail wag & idle fin breath (never frantic!)
        swimPhase += dt * (2.6 + (recentKeyTimer > 0 ? 1.8 : 0.0)) * motionMul
        finPhase += dt * 3.8 * motionMul

        // 1. In-place puff-up lifecycle (poke/drag/very fast typing)
        if canPuffUp && (isDragging || anger > 0.55 || petIntensity > 0.70) {
            puffHoldTimer = max(puffHoldTimer, 0.55)
        }
        if puffHoldTimer > 0 && canPuffUp {
            let wasPuffed = puff.value > 0.35
            puffHoldTimer = max(0, puffHoldTimer - dt)
            puff.target = 1.0
            if puffHoldTimer <= 0.01 && wasPuffed {
                spawnMouthBubbles(count: 3)
            }
        } else {
            puff.target = 0.0
        }
        puff.step(dt: dt, stiffness: 185, damping: 14)

        // 2. Rock-steady body anchor with gentle ±1.6px underwater breathing (zero dizzy typing wobble!)
        // When operating the left mouse, calmly glide 16px left so the left fin arcs naturally onto the mouse.
        if recentKeyTimer > 0 {
            recentKeyTimer = max(0, recentKeyTimer - dt)
        } else {
            microTilt.target = mouseActive ? -0.025 : 0.0
        }
        let breatheY = sin(time * 2.1) * 1.6 * motionMul
        let dragLiftY: CGFloat = isDragging ? -8.0 : 0.0
        let mouseSlideX: CGFloat = mouseActive ? -16.0 : 0.0
        pos.target = CGPoint(x: Self.bodyCenterAnchor.x + mouseSlideX, y: Self.bodyCenterAnchor.y + breatheY + dragLiftY)
        pos.step(dt: dt, stiffness: mouseActive ? 75 : 120, damping: 18)
        microTilt.step(dt: dt, stiffness: 140, damping: 20)

        if mouseActive && mouseClickLeft {
            leftFinSlap.value = max(leftFinSlap.value, 0.72)
        }
        if mouseActive && mouseClickRight {
            leftFinSlap.value = max(leftFinSlap.value, 0.72)
        }
        leftFinSlap.target = 0
        rightFinSlap.target = 0
        leftFinSlap.step(dt: dt, stiffness: 260, damping: 20)
        rightFinSlap.step(dt: dt, stiffness: 260, damping: 20)

        mouthOpen.target = puff.value > 0.25 ? 0.75 : 0.24
        mouthOpen.step(dt: dt, stiffness: 140, damping: 16)

        // 3. Occasional gentle ambient bubbles
        nextBubbleCooldown -= dt
        if nextBubbleCooldown <= 0 {
            nextBubbleCooldown = CGFloat.random(in: 3.4...5.8)
            mouthOpen.value = max(mouthOpen.value, 0.48)
            spawnMouthBubbles(count: Int.random(in: 1...2))
        }

        // 4. Advance bubbles & micro splash droplets
        for i in bubbles.indices {
            bubbles[i].age += dt
            bubbles[i].x += (bubbles[i].vx + sin(time * 3.2 + CGFloat(i)) * 4.5) * dt
            bubbles[i].y += bubbles[i].vy * dt
            bubbles[i].vx *= (1.0 - min(0.9, dt * 1.4))
        }
        bubbles.removeAll { $0.age >= $0.life }

        for i in droplets.indices {
            droplets[i].age += dt
            droplets[i].x += droplets[i].vx * dt
            droplets[i].y += droplets[i].vy * dt
            droplets[i].vy += 200.0 * dt
        }
        droplets.removeAll { $0.age >= $0.life }
        _ = (now, mouseCenter)
    }
}

// MARK: - Front-Facing Steady 2.5D Vector Fish Renderer (Head Forward + Elongated Typing Fins + Zero Headphones!)

enum FishRenderer {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// Head anchor point for floating `🫧 <name>` badge cleanly above the front-facing puffer's crown!
    static func headPosition(_ physics: CatPhysics, dna: FishPhotoDNA) -> CGPoint {
        let c = physics.fishSwim.pos.point
        let puff = max(0, min(1, physics.fishSwim.puff.value))
        let topY = c.y - (52.0 * CGFloat(dna.plumpness) + puff * 18.0)
        return CGPoint(x: c.x, y: topY)
    }

    static func hitTestFish(point pt: CGPoint, physics: CatPhysics) -> Bool {
        let c = physics.fishSwim.pos.point
        let puff = max(0, min(1, physics.fishSwim.puff.value))
        let rx: CGFloat = 62.0 + puff * 16.0
        let ry: CGFloat = 64.0 + puff * 14.0
        let dx = (pt.x - c.x) / rx
        let dy = (pt.y - c.y) / ry
        return (dx * dx + dy * dy) <= 1.0
    }

    // MARK: - Two-Pass Desk Sandwich Rendering (Back: Body/Tail/Face behind keyboard; Front: Elongated Pectoral Fins over keys & mouse!)

    /// Pass 1 (Drawn BEHIND Keyboard & Mouse): Steady front-facing puffer torso, curled right tail, dorsal crest, eyes & buck-toothed smile.
    static func drawBodyBehindDesk(
        in ctx: CGContext,
        physics: CatPhysics,
        dna: FishPhotoDNA,
        whiteOutline: Bool
    ) {
        let swim = physics.fishSwim
        let pos = swim.pos.point
        let puff = max(0, min(1, swim.puff.value))

        if whiteOutline {
            drawWithStickerOutline(in: ctx, bounds: CGRect(x: 40, y: 40, width: 310, height: 260)) { subCtx in
                drawFrontBodyAndTail(in: subCtx, physics: physics, dna: dna, pos: pos, puff: puff)
            }
        } else {
            drawFrontBodyAndTail(in: ctx, physics: physics, dna: dna, pos: pos, puff: puff)
        }
    }

    /// Pass 2 (Drawn IN FRONT OF Keyboard & Mouse): Elongated curved translucent left & right typing/mouse fins + water droplets + bubbles!
    /// Note: Fish NEVER wears headphones — keeping 100% aquatic visual consistency!
    static func drawFinsAndEffectsInFront(
        in ctx: CGContext,
        physics: CatPhysics,
        dna: FishPhotoDNA,
        whiteOutline: Bool
    ) {
        let swim = physics.fishSwim
        let pos = swim.pos.point
        let puff = max(0, min(1, swim.puff.value))

        // Gentle keycap ripple & droplets
        if swim.recentKeyTimer > 0.02, let kpt = swim.targetKeyPoint {
            drawKeyTapRipple(in: ctx, center: kpt, progress: 1.0 - min(1.0, swim.recentKeyTimer / 0.28))
        }
        drawSplashDroplets(in: ctx, droplets: swim.droplets)

        // Two graceful elongated translucent pectoral fins driven 1:1 by KuroCat's `leftPaw` & `rightPaw`!
        let finCol = CatCoatCompiler.swiftUIColor(dna.finHex)
        let bodyCol = CatCoatCompiler.swiftUIColor(dna.primaryBodyHex)
        let spotOuterCol = CatCoatCompiler.swiftUIColor(dna.spotOuterHex)
        let contourCol = blendColor(spotOuterCol, NSColor(srgbRed: 0.16, green: 0.11, blue: 0.10, alpha: 1.0), t: 0.46)
        let plump = CGFloat(dna.plumpness)

        let bodyHalfW = (46.0 + puff * 14.0) * min(1.12, plump)
        let leftShoulder = CGPoint(x: pos.x - bodyHalfW + 5.0, y: pos.y + 11.0)
        let rightShoulder = CGPoint(x: pos.x + bodyHalfW - 5.0, y: pos.y + 11.0)

        // Use exact CatPhysics leftPaw & rightPaw coordinates (so typing left/right keys & gripping left mouse feel identical to KuroCat!)
        let idleBreathL = CGPoint(x: sin(swim.finPhase) * 1.5, y: cos(swim.finPhase) * 1.3)
        let idleBreathR = CGPoint(x: -sin(swim.finPhase + 0.9) * 1.5, y: cos(swim.finPhase + 0.9) * 1.3)

        let rawLeftTip = physics.leftPaw.point
        let rawRightTip = physics.rightPaw.point
        let leftActive = physics.leftPawTyping || physics.leftPawOnMouse
        let rightActive = physics.rightPawTyping

        let leftTarget: CGPoint = leftActive
            ? CGPoint(x: rawLeftTip.x, y: rawLeftTip.y + swim.leftFinSlap.value * 2.5)
            : CGPoint(x: 150.0 + idleBreathL.x, y: 234.0 + idleBreathL.y)
        let rightTarget: CGPoint = rightActive
            ? CGPoint(x: rawRightTip.x, y: rawRightTip.y + swim.rightFinSlap.value * 2.5)
            : CGPoint(x: 218.0 + idleBreathR.x, y: 234.0 + idleBreathR.y)

        // Draw elongated translucent fins directly (NEVER wrap with an opaque white sticker outline cutting across the cheek!)
        drawElongatedPectoralFin(in: ctx, shoulder: leftShoulder, tip: leftTarget, isLeft: true, isReaching: leftActive, finScale: CGFloat(dna.finLength), finCol: finCol, bodyCol: bodyCol, contourCol: contourCol, whiteOutline: whiteOutline)
        drawElongatedPectoralFin(in: ctx, shoulder: rightShoulder, tip: rightTarget, isLeft: false, isReaching: rightActive, finScale: CGFloat(dna.finLength), finCol: finCol, bodyCol: bodyCol, contourCol: contourCol, whiteOutline: whiteOutline)

        // Crisp rising ambient water bubbles
        drawWaterBubbles(in: ctx, bubbles: swim.bubbles)
    }

    // MARK: - Front-Facing Puffer Body, Curled Tail & Iconic Face (`鱼头向前`)

    private static func drawFrontBodyAndTail(
        in ctx: CGContext,
        physics: CatPhysics,
        dna: FishPhotoDNA,
        pos: CGPoint,
        puff: CGFloat
    ) {
        let swim = physics.fishSwim
        let bodyCol = CatCoatCompiler.swiftUIColor(dna.primaryBodyHex)
        let bellyCol = CatCoatCompiler.swiftUIColor(dna.bellyHex)
        let dorsalCol = CatCoatCompiler.swiftUIColor(dna.dorsalHex)
        let spotOuterCol = CatCoatCompiler.swiftUIColor(dna.spotOuterHex)
        let spotInnerCol = CatCoatCompiler.swiftUIColor(dna.spotInnerHex)
        let finCol = CatCoatCompiler.swiftUIColor(dna.finHex)
        let irisCol = CatCoatCompiler.swiftUIColor(dna.irisHex)
        let contourCol = blendColor(spotOuterCol, NSColor(srgbRed: 0.16, green: 0.11, blue: 0.10, alpha: 1.0), t: 0.48)

        let plump = CGFloat(dna.plumpness)
        let finScale = CGFloat(dna.finLength)
        let tailWave = sin(swim.swimPhase) * 6.5

        ctx.saveGState()
        ctx.translateBy(x: pos.x, y: pos.y)
        ctx.rotate(by: swim.microTilt.value)

        // 1. Curled Broom-Fan Striped Caudal Tail Sweeping Gracefully Out Behind Right Side (like KuroCat's tail!)
        drawFrontCurledTail(
            in: ctx,
            dna: dna,
            finScale: finScale,
            puff: puff,
            tailWave: tailWave,
            bodyCol: bodyCol,
            finCol: finCol,
            dorsalCol: dorsalCol,
            spotOuterCol: spotOuterCol,
            spotInnerCol: spotInnerCol,
            contourCol: contourCol
        )

        // 2. Cute Translucent Dorsal Fin Crown Peeking Behind Top Forehead!
        drawFrontDorsalCrest(
            in: ctx,
            profile: dna.bodyProfile,
            finScale: finScale,
            plump: plump,
            puff: puff,
            wave: tailWave * 0.45,
            finCol: finCol,
            contourCol: contourCol
        )

        // 3. Puffer Balloon Spines (strictly anchored INSIDE circular silhouette when `puff > 0.12`!)
        if puff > 0.12 && dna.canPuffUp {
            drawFrontPuffSpines(in: ctx, puff: puff, plump: plump, bodyCol: bellyCol, tipCol: dorsalCol, contourCol: contourCol)
        }

        // 4. Symmetrical Chubby Front-Facing Puffer Body Silhouette (Boxy-Rounded Brow -> Plump Pear Belly Behind Keyboard)
        let bodyPath = makeFrontBodyPath(profile: dna.bodyProfile, plump: plump, puff: puff)

        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.clip()

        // Soft 3D front-lit aquatic volume gradient: warm champagne brow & flanks -> creamy ivory round belly
        let topShade = blendColor(bodyCol, dorsalCol, t: 0.24)
        if let grad = makeLinearGradient([
            (0.00, topShade),
            (0.28, bodyCol),
            (0.62, blendColor(bodyCol, bellyCol, t: 0.58)),
            (1.00, bellyCol)
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: -58 * plump - puff * 16), end: CGPoint(x: 0, y: 66), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Subtle side-flank shading so the 3D rounded cheeks pop!
        if let sideGrad = makeLinearGradient([
            (0.00, topShade.withAlphaComponent(0.32)),
            (0.22, NSColor.clear),
            (0.78, NSColor.clear),
            (1.00, topShade.withAlphaComponent(0.32))
        ]) {
            let hw = 58.0 * plump + puff * 16.0
            ctx.drawLinearGradient(sideGrad, start: CGPoint(x: -hw, y: 0), end: CGPoint(x: hw, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Iconic Symmetrical Front-Facing Markings (Double-Ringed Crimson Ocelli on both flanks & cheeks + warm russet crown!)
        drawFrontBodyMarkings(
            in: ctx,
            dna: dna,
            plump: plump,
            puff: puff,
            dorsalCol: dorsalCol,
            spotOuterCol: spotOuterCol,
            spotInnerCol: spotInnerCol,
            bellyCol: bellyCol
        )

        // Soft glossy aquatic forehead highlight
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: CGRect(x: -20, y: -44 * plump - puff * 12, width: 40, height: 11))

        // Cute symmetrical rosy puffer cheek blushes!
        let blushA: CGFloat = 0.28 + puff * 0.24 + physics.petHeadIntensity * 0.22
        ctx.setFillColor(NSColor(srgbRed: 0.95, green: 0.44, blue: 0.44, alpha: blushA).cgColor)
        ctx.fillEllipse(in: CGRect(x: -36 - puff * 6, y: -13, width: 13, height: 8.5))
        ctx.fillEllipse(in: CGRect(x: 23 + puff * 6, y: -13, width: 13, height: 8.5))

        ctx.restoreGState() // end torso clip

        // Clean crisp hand-drawn outer contour matching KuroCat
        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.86).cgColor)
        ctx.setLineWidth(1.9)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(bodyPath)
        ctx.strokePath()
        ctx.restoreGState()

        // 5. Two Symmetrical High-Set Protruding 3D Amber-Red Puffer Eyes (`#E24E24`)
        let eyeOffsetX: CGFloat = 31.0 * min(1.10, plump) + puff * 8.0
        let eyeY: CGFloat = -28.0 * min(1.10, plump) - puff * 8.0
        let eyeR: CGFloat = 10.6 + puff * 1.8
        drawFrontFishEye(in: ctx, center: CGPoint(x: -eyeOffsetX, y: eyeY), radius: eyeR, irisCol: irisCol, bodyCol: bodyCol, contourCol: contourCol, gaze: physics.eyeGaze.point, blink: physics.effectiveEyeClosure, puff: puff)
        drawFrontFishEye(in: ctx, center: CGPoint(x: eyeOffsetX, y: eyeY), radius: eyeR, irisCol: irisCol, bodyCol: bodyCol, contourCol: contourCol, gaze: physics.eyeGaze.point, blink: physics.effectiveEyeClosure, puff: puff)

        // 6. Front-Center Plump Rounded "Dog-Head" Lips + Two Adorable Symmetrical White Buck Teeth (`两颗小板牙`)!
        drawFrontFishMouth(
            in: ctx,
            dna: dna,
            puff: puff,
            mouthOpen: max(0, min(1, swim.mouthOpen.value)),
            bellyCol: bellyCol,
            contourCol: contourCol
        )

        // 7. Comic puff-burst arcs when puffed into a spiky ball!
        if puff > 0.45 && dna.canPuffUp {
            drawComicPuffBurst(in: ctx, puff: puff, plump: plump)
        }

        ctx.restoreGState()
    }

    // MARK: - Front Body Geometry

    private static func makeFrontBodyPath(profile: FishBodyProfile, plump: CGFloat, puff: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let ps = min(1.18, max(0.88, plump))
        if puff > 0.05 {
            let rx = 50.0 * ps + puff * 16.0
            let ry = 54.0 * ps + puff * 10.0
            let smooth = puff * puff * (3.0 - 2.0 * puff)
            if smooth > 0.65 {
                p.addEllipse(in: CGRect(x: -rx, y: -ry + 4.0, width: rx * 2, height: ry * 2))
                return p
            }
        }

        let topW: CGFloat = (profile == .angelfishDisc ? 32.0 : 41.0) * ps + puff * 12.0
        let cheekW: CGFloat = (profile == .bettaFlow ? 40.0 : 51.0) * ps + puff * 14.0
        let bellyW: CGFloat = (profile == .bettaFlow ? 38.0 : 52.0) * ps + puff * 14.0
        let topY: CGFloat = -48.0 * ps - puff * 12.0
        let botY: CGFloat = 65.0 + puff * 5.0

        // Soft boxy-rounded puffer forehead -> chubby rounded cheeks -> grounded pear belly tucked behind keyboard!
        p.move(to: CGPoint(x: 0, y: topY))
        p.addCurve(
            to: CGPoint(x: cheekW, y: -6),
            control1: CGPoint(x: topW * 0.85, y: topY),
            control2: CGPoint(x: cheekW + 2, y: -32 * ps)
        )
        p.addCurve(
            to: CGPoint(x: bellyW * 0.72, y: botY),
            control1: CGPoint(x: cheekW + 2, y: 24),
            control2: CGPoint(x: bellyW, y: botY - 8)
        )
        p.addQuadCurve(to: CGPoint(x: -bellyW * 0.72, y: botY), control: CGPoint(x: 0, y: botY + 6))
        p.addCurve(
            to: CGPoint(x: -cheekW, y: -6),
            control1: CGPoint(x: -bellyW, y: botY - 8),
            control2: CGPoint(x: -cheekW - 2, y: 24)
        )
        p.addCurve(
            to: CGPoint(x: 0, y: topY),
            control1: CGPoint(x: -cheekW - 2, y: -32 * ps),
            control2: CGPoint(x: -topW * 0.85, y: topY)
        )
        p.closeSubpath()
        return p
    }

    // MARK: - Symmetrical Front-Facing Markings (Double-Ringed Crimson Ocelli on Both Cheeks & Flanks!)

    private static func drawFrontBodyMarkings(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        plump: CGFloat,
        puff: CGFloat,
        dorsalCol: NSColor,
        spotOuterCol: NSColor,
        spotInnerCol: NSColor,
        bellyCol: NSColor
    ) {
        let ps = min(1.16, plump)
        let xSpread: CGFloat = 1.0 + puff * 0.24

        switch dna.spotPattern {
        case .ringedOcelli:
            // Warm russet-terracotta forehead crown mottling (harmonized with crimson ocelli!)
            let warmDorsal = blendColor(dorsalCol, spotInnerCol, t: 0.34)
            let browBlotches: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0, -42 * ps, 16, 7.5, 0.0),
                (-19 * xSpread, -38 * ps, 11, 6.2, -0.22),
                (19 * xSpread, -38 * ps, 11, 6.2, 0.22),
                (-11 * xSpread, -26 * ps, 7.5, 5.2, -0.15),
                (11 * xSpread, -26 * ps, 7.5, 5.2, 0.15)
            ]
            for (bx, by, rx, ry, rot) in browBlotches {
                ctx.saveGState()
                ctx.translateBy(x: bx, y: by)
                ctx.rotate(by: rot)
                ctx.setFillColor(warmDorsal.withAlphaComponent(0.64).cgColor)
                ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                ctx.restoreGState()
            }

            // Organic curving double-ringed crimson ocelli wrapping BOTH cheeks & flanks (varied radii, never rigid columns!)
            let sideSpots: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (-43, -12, 5.8, 5.2),
                (-35,   2, 7.6, 6.8),
                (-45,  16, 6.8, 6.0),
                (-31,  26, 5.6, 5.0),
                (-42,  38, 6.5, 5.8),
                ( 43, -12, 5.8, 5.2),
                ( 35,   2, 7.6, 6.8),
                ( 45,  16, 6.8, 6.0),
                ( 31,  26, 5.6, 5.0),
                ( 42,  38, 6.5, 5.8)
            ]
            for (sx, sy, rx, ry) in sideSpots {
                let cx = sx * xSpread
                ctx.setFillColor(spotOuterCol.withAlphaComponent(0.92).cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - rx, y: sy - ry, width: rx * 2, height: ry * 2))
                let irx = rx * 0.58
                let iry = ry * 0.58
                ctx.setFillColor(spotInnerCol.cgColor)
                ctx.fillEllipse(in: CGRect(x: cx - irx, y: sy - iry, width: irx * 2, height: iry * 2))
            }

        case .spotted:
            ctx.setFillColor(spotOuterCol.withAlphaComponent(0.84).cgColor)
            for (sx, sy, r) in [
                (-38, -12, 6.5), (-40, 8, 7.0), (-36, 28, 6.2),
                (38, -12, 6.5), (40, 8, 7.0), (36, 28, 6.2),
                (-16, -36, 6.0), (16, -36, 6.0), (0, -40, 6.8)
            ] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.fillEllipse(in: CGRect(x: sx * xSpread - r, y: sy - r * 0.9, width: r * 2, height: r * 1.8))
            }

        case .stripedVertical:
            for sx in [-34.0, 34.0] as [CGFloat] {
                let band = CGPath(roundedRect: CGRect(x: sx * xSpread - 6, y: -48, width: 12, height: 112), cornerWidth: 5, cornerHeight: 5, transform: nil)
                ctx.setFillColor(bellyCol.cgColor)
                ctx.addPath(band); ctx.fillPath()
                ctx.setStrokeColor(spotOuterCol.withAlphaComponent(0.86).cgColor)
                ctx.setLineWidth(2.2)
                ctx.addPath(band); ctx.strokePath()
            }

        case .calicoBlotch:
            let blotches: [(CGFloat, CGFloat, CGFloat, CGFloat, NSColor)] = [
                (-28 * xSpread, -26, 20, 15, spotInnerCol),
                (32 * xSpread, -10, 22, 18, spotInnerCol),
                (-34 * xSpread, 22, 18, 15, spotOuterCol.withAlphaComponent(0.85)),
                (22 * xSpread, 34, 15, 12, dorsalCol.withAlphaComponent(0.82))
            ]
            for (x, y, rx, ry, col) in blotches {
                ctx.setFillColor(col.cgColor)
                ctx.fillEllipse(in: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
            }

        case .saddleBack:
            ctx.setFillColor(dorsalCol.withAlphaComponent(0.72).cgColor)
            ctx.fillEllipse(in: CGRect(x: -38 * xSpread, y: -56, width: 76 * xSpread, height: 32))

        case .solidGradient:
            break
        }
    }

    // MARK: - Curled Right Broom-Fan Tail & Dorsal Crown Crest

    private static func drawFrontCurledTail(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        finScale: CGFloat,
        puff: CGFloat,
        tailWave: CGFloat,
        bodyCol: NSColor,
        finCol: NSColor,
        dorsalCol: NSColor,
        spotOuterCol: NSColor,
        spotInnerCol: NSColor,
        contourCol: NSColor
    ) {
        let rootX: CGFloat = 38.0 + puff * 10.0
        let rootY: CGFloat = 34.0
        let pedEndX: CGFloat = 68.0 + puff * 8.0
        let pedEndY: CGFloat = 14.0 + tailWave * 0.45

        // 1. Curved tail peduncle emerging smoothly from right hip (carrying 2 iconic red-centered ringed spots!)
        let ped = CGMutablePath()
        ped.move(to: CGPoint(x: rootX - 4, y: rootY - 14))
        ped.addQuadCurve(to: CGPoint(x: pedEndX, y: pedEndY - 9), control: CGPoint(x: rootX + 18, y: rootY - 12))
        ped.addLine(to: CGPoint(x: pedEndX + 2, y: pedEndY + 9))
        ped.addQuadCurve(to: CGPoint(x: rootX - 4, y: rootY + 14), control: CGPoint(x: rootX + 22, y: rootY + 14))
        ped.closeSubpath()

        ctx.saveGState()
        ctx.setFillColor(bodyCol.cgColor)
        ctx.addPath(ped); ctx.fillPath()

        if dna.spotPattern == .ringedOcelli {
            ctx.saveGState()
            ctx.addPath(ped); ctx.clip()
            for (ox, oy, r) in [(rootX + 16, rootY - 2, 5.8), (pedEndX - 6, pedEndY + 1, 5.0)] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.setFillColor(spotOuterCol.withAlphaComponent(0.90).cgColor)
                ctx.fillEllipse(in: CGRect(x: ox - r, y: oy - r * 0.9, width: r * 2, height: r * 1.8))
                ctx.setFillColor(spotInnerCol.cgColor)
                ctx.fillEllipse(in: CGRect(x: ox - r * 0.56, y: oy - r * 0.50, width: r * 1.12, height: r * 1.0))
            }
            ctx.restoreGState()
        }

        ctx.setStrokeColor(contourCol.withAlphaComponent(0.84).cgColor)
        ctx.setLineWidth(1.75)
        ctx.addPath(ped); ctx.strokePath()
        ctx.restoreGState()

        // 2. Wide Striped Broom-Fan Caudal Tail Sweeping Up-Right!
        let fanLen: CGFloat = (dna.bodyProfile == .bettaFlow ? 50.0 : 38.0) * finScale
        let fanSpread: CGFloat = (dna.bodyProfile == .bettaFlow ? 34.0 : 24.0) * finScale
        let tipX = pedEndX + fanLen
        let tipY = pedEndY - 16.0 + tailWave

        let fan = CGMutablePath()
        fan.move(to: CGPoint(x: pedEndX - 2, y: pedEndY - 8))
        fan.addQuadCurve(to: CGPoint(x: tipX - 6, y: tipY - fanSpread * 0.72), control: CGPoint(x: pedEndX + fanLen * 0.45, y: pedEndY - fanSpread * 0.75))
        fan.addCurve(
            to: CGPoint(x: tipX + 4, y: tipY + fanSpread * 0.78),
            control1: CGPoint(x: tipX + 8, y: tipY - fanSpread * 0.25),
            control2: CGPoint(x: tipX + 11, y: tipY + fanSpread * 0.28)
        )
        fan.addQuadCurve(to: CGPoint(x: pedEndX, y: pedEndY + 9), control: CGPoint(x: pedEndX + fanLen * 0.48, y: pedEndY + fanSpread * 0.65))
        fan.closeSubpath()

        ctx.saveGState()
        ctx.addPath(fan); ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.95)),
            (0.65, blendColor(finCol, dorsalCol, t: 0.22).withAlphaComponent(0.84)),
            (1.0, finCol.withAlphaComponent(0.60))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: pedEndX, y: pedEndY), end: CGPoint(x: tipX + 6, y: tipY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // 8 crisp striped broom-fan tail rays!
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.42).cgColor)
        ctx.setLineWidth(1.2)
        ctx.setLineCap(.round)
        for i in -3...4 {
            let f = (CGFloat(i) - 0.5) / 3.5
            let sy = pedEndY + f * 6.5
            let ey = tipY + f * (fanSpread * 0.68)
            let ex = tipX - abs(f) * 3.0
            ctx.beginPath()
            ctx.move(to: CGPoint(x: pedEndX, y: sy))
            ctx.addQuadCurve(to: CGPoint(x: ex, y: ey), control: CGPoint(x: (pedEndX + ex) * 0.5, y: (sy + ey) * 0.5 - 3))
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.76).cgColor)
        ctx.setLineWidth(1.55)
        ctx.setLineJoin(.round)
        ctx.addPath(fan); ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawFrontDorsalCrest(
        in ctx: CGContext,
        profile: FishBodyProfile,
        finScale: CGFloat,
        plump: CGFloat,
        puff: CGFloat,
        wave: CGFloat,
        finCol: NSColor,
        contourCol: NSColor
    ) {
        let baseY = -44.0 * min(1.16, plump) - puff * 11.0
        let h: CGFloat = (profile == .angelfishDisc ? 28.0 : (profile == .bettaFlow ? 24.0 : 18.0)) * finScale
        let crest = CGMutablePath()
        crest.move(to: CGPoint(x: -11, y: baseY + 6))
        crest.addCurve(
            to: CGPoint(x: wave * 0.55, y: baseY - h),
            control1: CGPoint(x: -12, y: baseY - h * 0.68),
            control2: CGPoint(x: -4 + wave * 0.3, y: baseY - h)
        )
        crest.addCurve(
            to: CGPoint(x: 11, y: baseY + 6),
            control1: CGPoint(x: 6 + wave * 0.35, y: baseY - h),
            control2: CGPoint(x: 12, y: baseY - h * 0.62)
        )
        crest.closeSubpath()

        ctx.saveGState()
        ctx.addPath(crest); ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.86)),
            (1.0, NSColor(srgbRed: 0.96, green: 0.93, blue: 0.85, alpha: 0.54))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: baseY + 4), end: CGPoint(x: 0, y: baseY - h), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(1.0)
        for dx in [-4.5, 0.0, 4.5] as [CGFloat] {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: dx * 0.6, y: baseY + 4))
            ctx.addLine(to: CGPoint(x: dx + wave * 0.45, y: baseY - h * 0.85))
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.72).cgColor)
        ctx.setLineWidth(1.45)
        ctx.addPath(crest); ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Graceful Elongated Curved Translucent Pectoral Fins (Typing Keys & Mouse Glide!)

    private static func drawElongatedPectoralFin(
        in ctx: CGContext,
        shoulder: CGPoint,
        tip: CGPoint,
        isLeft: Bool,
        isReaching: Bool,
        finScale: CGFloat,
        finCol: NSColor,
        bodyCol: NSColor,
        contourCol: NSColor,
        whiteOutline: Bool
    ) {
        let sign: CGFloat = isLeft ? -1.0 : 1.0
        let dx = tip.x - shoulder.x
        let dy = tip.y - shoulder.y
        let dist = max(18.0, hypot(dx, dy))

        // Organic gracefully arched aquatic ribbon-to-fan curve (so mouse reach sweeps cleanly instead of looking like a straight stick!)
        let bowOut: CGFloat = isReaching ? (15.0 + min(18.0, dist * 0.14)) : 16.0
        let ctrl = CGPoint(
            x: (shoulder.x + tip.x) * 0.5 + sign * bowOut,
            y: (shoulder.y + tip.y) * 0.5 + (isReaching ? 12.0 : 14.0)
        )

        let steps = 16
        var edgeA: [CGPoint] = []
        var edgeB: [CGPoint] = []
        edgeA.reserveCapacity(steps + 1)
        edgeB.reserveCapacity(steps + 1)

        // Slender gill-pocket root tapering gently into a graceful wide translucent paddle fan!
        let baseHalfW: CGFloat = 6.2
        let waistHalfW: CGFloat = 5.6
        let fanTipHalfW: CGFloat = (15.2 + (finScale - 1.0) * 5.0)

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let u = 1.0 - t
            let px = u*u*shoulder.x + 2*u*t*ctrl.x + t*t*tip.x
            let py = u*u*shoulder.y + 2*u*t*ctrl.y + t*t*tip.y
            let tx = 2*u*(ctrl.x - shoulder.x) + 2*t*(tip.x - ctrl.x)
            let ty = 2*u*(ctrl.y - shoulder.y) + 2*t*(tip.y - ctrl.y)
            let len = max(0.001, hypot(tx, ty))
            let nx = -ty / len
            let ny = tx / len

            let halfW: CGFloat
            if t < 0.36 {
                let k = t / 0.36
                halfW = baseHalfW + (waistHalfW - baseHalfW) * k
            } else {
                let k = (t - 0.36) / 0.64
                let flare = sin(k * .pi * 0.68)
                halfW = waistHalfW + (fanTipHalfW - waistHalfW) * flare
            }
            edgeA.append(CGPoint(x: px + nx * halfW, y: py + ny * halfW))
            edgeB.append(CGPoint(x: px - nx * halfW, y: py - ny * halfW))
        }

        let endTx = 2 * (tip.x - ctrl.x)
        let endTy = 2 * (tip.y - ctrl.y)
        let endLen = max(0.001, hypot(endTx, endTy))
        let ux = endTx / endLen
        let uy = endTy / endLen
        let tipCapCenter = CGPoint(x: tip.x + ux * 10.5, y: tip.y + uy * 10.5)

        let finPath = CGMutablePath()
        finPath.move(to: edgeA[0])
        for pt in edgeA.dropFirst() { finPath.addLine(to: pt) }
        finPath.addQuadCurve(to: edgeB[steps], control: tipCapCenter)
        for pt in edgeB.reversed().dropFirst() { finPath.addLine(to: pt) }
        finPath.closeSubpath()

        // Open contour path that strokes ONLY the two fin edges + rounded paddle tip (skipping the shoulder seam so it merges organically into the body!)
        let openContour = CGMutablePath()
        openContour.move(to: edgeA[1])
        for pt in edgeA.dropFirst(2) { openContour.addLine(to: pt) }
        openContour.addQuadCurve(to: edgeB[steps], control: tipCapCenter)
        for pt in edgeB.reversed().dropFirst().dropLast() { openContour.addLine(to: pt) }

        // Subtle curved gill-arch crease tucked at the shoulder root (natural anatomical hinge!)
        ctx.saveGState()
        let gillArc = CGMutablePath()
        gillArc.move(to: CGPoint(x: shoulder.x - sign * 3.0, y: shoulder.y - 7.5))
        gillArc.addQuadCurve(
            to: CGPoint(x: shoulder.x - sign * 1.5, y: shoulder.y + 8.5),
            control: CGPoint(x: shoulder.x - sign * 7.5, y: shoulder.y + 0.5)
        )
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(1.3)
        ctx.setLineCap(.round)
        ctx.addPath(gillArc)
        ctx.strokePath()
        ctx.restoreGState()

        // Soft translucent pearly outer rim halo over keyboard (only along open edge, never over cheek!)
        if whiteOutline {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(3.4)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
            ctx.addPath(openContour)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // Genuinely translucent pearly golden-cream fin gradient + 5 delicate curved radiating fin rays!
        ctx.saveGState()
        ctx.addPath(finPath)
        ctx.clip()

        let rootBlend = blendColor(bodyCol, finCol, t: 0.52)
        if let grad = makeLinearGradient([
            (0.00, rootBlend.withAlphaComponent(0.84)),
            (0.22, finCol.withAlphaComponent(0.80)),
            (0.68, blendColor(finCol, NSColor(srgbRed: 0.99, green: 0.96, blue: 0.88, alpha: 1.0), t: 0.50).withAlphaComponent(0.68)),
            (1.00, NSColor(srgbRed: 1.0, green: 0.98, blue: 0.92, alpha: 0.56))
        ]) {
            ctx.drawLinearGradient(grad, start: shoulder, end: tipCapCenter, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // 5 curved radiating fin rays fanning gracefully into the translucent paddle!
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.30).cgColor)
        ctx.setLineWidth(0.95)
        ctx.setLineCap(.round)
        let nxEnd = -uy
        let nyEnd = ux
        for rIdx in -2...2 {
            let f = CGFloat(rIdx) / 2.2
            let rayStart = CGPoint(x: shoulder.x + ux * 4.0 + nxEnd * f * 2.2, y: shoulder.y + uy * 4.0 + nyEnd * f * 2.2)
            let rayCtrl = CGPoint(x: ctrl.x + nxEnd * f * 5.2, y: ctrl.y + nyEnd * f * 5.2)
            let rayEnd = CGPoint(x: tip.x + ux * 5.5 + nxEnd * f * (fanTipHalfW * 0.76), y: tip.y + uy * 5.5 + nyEnd * f * (fanTipHalfW * 0.76))
            ctx.beginPath()
            ctx.move(to: rayStart)
            ctx.addQuadCurve(to: rayEnd, control: rayCtrl)
            ctx.strokePath()
        }
        ctx.restoreGState()

        // Delicate open contour along sides & paddle tip (zero harsh line across the fish's body!)
        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.66).cgColor)
        ctx.setLineWidth(1.35)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(openContour)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Front-Facing Protruding 3D Eyes & Buck-Toothed Smile

    private static func drawFrontFishEye(
        in ctx: CGContext,
        center: CGPoint,
        radius: CGFloat,
        irisCol: NSColor,
        bodyCol: NSColor,
        contourCol: NSColor,
        gaze: CGPoint,
        blink: CGFloat,
        puff: CGFloat
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)

        // Protruding fleshy puffer eye socket turret
        let turretR = radius * 1.24
        ctx.setFillColor(blendColor(bodyCol, NSColor.white, t: 0.14).cgColor)
        ctx.fillEllipse(in: CGRect(x: -turretR, y: -turretR * 0.94, width: turretR * 2, height: turretR * 1.88))
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.68).cgColor)
        ctx.setLineWidth(1.45)
        ctx.strokeEllipse(in: CGRect(x: -turretR, y: -turretR * 0.94, width: turretR * 2, height: turretR * 1.88))

        if blink > 0.72 && puff < 0.25 {
            let arc = CGMutablePath()
            arc.move(to: CGPoint(x: -radius * 0.72, y: 1))
            arc.addQuadCurve(to: CGPoint(x: radius * 0.72, y: 1), control: CGPoint(x: 0, y: -radius * 0.58))
            ctx.setStrokeColor(contourCol.cgColor)
            ctx.setLineWidth(2.1)
            ctx.setLineCap(.round)
            ctx.addPath(arc)
            ctx.strokePath()
            ctx.restoreGState()
            return
        }

        let irisRect = CGRect(x: -radius, y: -radius * 0.95, width: radius * 2, height: radius * 1.9)
        ctx.saveGState()
        ctx.addEllipse(in: irisRect)
        ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, blendColor(irisCol, NSColor(srgbRed: 1.0, green: 0.74, blue: 0.30, alpha: 1.0), t: 0.35)),
            (0.55, irisCol),
            (1.0, blendColor(irisCol, NSColor(srgbRed: 0.36, green: 0.08, blue: 0.06, alpha: 1.0), t: 0.44))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: -radius), end: CGPoint(x: 0, y: radius), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        let gx = max(-1, min(1, gaze.x)) * radius * 0.28
        let gy = max(-1, min(1, gaze.y)) * radius * 0.25
        let pupilR = radius * (puff > 0.25 ? (0.48 - puff * 0.14) : 0.52)
        ctx.setFillColor(NSColor(srgbRed: 0.09, green: 0.07, blue: 0.09, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: gx - pupilR, y: gy - pupilR, width: pupilR * 2, height: pupilR * 2))

        // Crisp glossy wet catchlights
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
        let hlR = radius * 0.27
        ctx.fillEllipse(in: CGRect(x: -radius * 0.42, y: -radius * 0.48, width: hlR * 2, height: hlR * 1.8))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.68).cgColor)
        ctx.fillEllipse(in: CGRect(x: radius * 0.18, y: radius * 0.18, width: hlR * 0.85, height: hlR * 0.85))
        ctx.restoreGState()

        ctx.setStrokeColor(contourCol.withAlphaComponent(0.90).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: irisRect)
        ctx.restoreGState()
    }

    private static func drawFrontFishMouth(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        puff: CGFloat,
        mouthOpen: CGFloat,
        bellyCol: NSColor,
        contourCol: NSColor
    ) {
        let my: CGFloat = -11.0 - puff * 2.0
        let lipCol = blendColor(bellyCol, NSColor(srgbRed: 0.97, green: 0.82, blue: 0.76, alpha: 1.0), t: 0.48)

        ctx.saveGState()
        ctx.translateBy(x: 0, y: my)

        if puff > 0.35 {
            // Adorable front-facing startled ":O" puffer mouth!
            let r = 6.2 + puff * 2.0
            ctx.setFillColor(lipCol.cgColor)
            ctx.fillEllipse(in: CGRect(x: -r, y: -r * 0.88, width: r * 2, height: r * 1.76))
            ctx.setFillColor(NSColor(srgbRed: 0.46, green: 0.18, blue: 0.20, alpha: 0.92).cgColor)
            ctx.fillEllipse(in: CGRect(x: -r * 0.56, y: -r * 0.48, width: r * 1.12, height: r * 0.96))
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.82).cgColor)
            ctx.setLineWidth(1.4)
            ctx.strokeEllipse(in: CGRect(x: -r, y: -r * 0.88, width: r * 2, height: r * 1.76))
            ctx.restoreGState()
            return
        }

        // Friendly, goofy front-facing puffer smile (`◡`) with two cute rounded ivory buck teeth peeking playfully!
        let openH = 4.6 + mouthOpen * 3.4
        let smileW: CGFloat = 10.5

        // Soft happy curved mouth cavity
        let cavity = CGMutablePath()
        cavity.move(to: CGPoint(x: -smileW, y: -1.6))
        cavity.addQuadCurve(to: CGPoint(x: smileW, y: -1.6), control: CGPoint(x: 0, y: -3.2))
        cavity.addQuadCurve(to: CGPoint(x: -smileW, y: -1.6), control: CGPoint(x: 0, y: openH + 5.2))
        cavity.closeSubpath()

        ctx.setFillColor(NSColor(srgbRed: 0.56, green: 0.22, blue: 0.26, alpha: 0.90).cgColor)
        ctx.addPath(cavity); ctx.fillPath()

        // Cute soft pink tongue hint inside the smile
        ctx.saveGState()
        ctx.addPath(cavity); ctx.clip()
        ctx.setFillColor(NSColor(srgbRed: 0.90, green: 0.45, blue: 0.48, alpha: 0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: -5.5, y: openH - 0.8, width: 11.0, height: 6.5))

        // Two adorable rounded ivory buck teeth peeking playfully from the upper lip!
        if dna.hasBuckTeeth {
            let toothCol = NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1.0)
            let t1 = CGPath(roundedRect: CGRect(x: -3.8, y: -2.4, width: 3.5, height: 4.5), cornerWidth: 1.4, cornerHeight: 1.4, transform: nil)
            let t2 = CGPath(roundedRect: CGRect(x: 0.3, y: -2.4, width: 3.5, height: 4.5), cornerWidth: 1.4, cornerHeight: 1.4, transform: nil)
            ctx.setFillColor(toothCol.cgColor)
            ctx.addPath(t1); ctx.fillPath()
            ctx.addPath(t2); ctx.fillPath()
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
            ctx.setLineWidth(0.65)
            ctx.addPath(t1); ctx.strokePath()
            ctx.addPath(t2); ctx.strokePath()
        }
        ctx.restoreGState()

        // Soft curved smile lip outline with gentle upturned playful cheek corners!
        let upperArc = CGMutablePath()
        upperArc.move(to: CGPoint(x: -smileW - 1.5, y: -2.4))
        upperArc.addQuadCurve(to: CGPoint(x: smileW + 1.5, y: -2.4), control: CGPoint(x: 0, y: 0.6))
        ctx.setStrokeColor(lipCol.cgColor)
        ctx.setLineWidth(3.6)
        ctx.setLineCap(.round)
        ctx.addPath(upperArc); ctx.strokePath()

        ctx.setStrokeColor(contourCol.withAlphaComponent(0.78).cgColor)
        ctx.setLineWidth(1.4)
        ctx.setLineCap(.round)
        ctx.addPath(cavity); ctx.strokePath()

        // Soft subtle lower lip pillow cushion
        let lowerArc = CGMutablePath()
        lowerArc.move(to: CGPoint(x: -smileW * 0.62, y: openH + 3.0))
        lowerArc.addQuadCurve(to: CGPoint(x: smileW * 0.62, y: openH + 3.0), control: CGPoint(x: 0, y: openH + 5.6))
        ctx.setStrokeColor(lipCol.withAlphaComponent(0.90).cgColor)
        ctx.setLineWidth(2.4)
        ctx.addPath(lowerArc); ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - Spines (Strictly Anchored Inside Round Balloon), Comic Burst, Bubbles & Splash

    private static func drawFrontPuffSpines(
        in ctx: CGContext,
        puff: CGFloat,
        plump: CGFloat,
        bodyCol: NSColor,
        tipCol: NSColor,
        contourCol: NSColor
    ) {
        let ps = min(1.18, max(0.88, plump))
        let rx = 50.0 * ps + puff * 16.0
        let ry = 54.0 * ps + puff * 10.0
        let cy: CGFloat = 4.0
        let spineLen: CGFloat = 10.5 * puff
        let spineCol = blendColor(bodyCol, tipCol, t: 0.30)

        let count = 20
        ctx.saveGState()
        for i in 0..<count {
            let ang = CGFloat(i) / CGFloat(count) * .pi * 2.0
            // Skip bottom edge tucked behind keyboard (`sin(ang) > 0.72`) so spines sit cleanly above the keyboard!
            if sin(ang) > 0.72 { continue }
            let bx = cos(ang) * (rx - 7.0)
            let by = cy + sin(ang) * (ry - 7.0)
            let tx = cos(ang) * (rx + spineLen)
            let ty = cy + sin(ang) * (ry + spineLen)
            let nx = -sin(ang) * 4.2
            let ny = cos(ang) * 4.2

            let sp = CGMutablePath()
            sp.move(to: CGPoint(x: bx + nx, y: by + ny))
            sp.addLine(to: CGPoint(x: tx, y: ty))
            sp.addLine(to: CGPoint(x: bx - nx, y: by - ny))
            sp.closeSubpath()

            ctx.setFillColor(spineCol.cgColor)
            ctx.addPath(sp); ctx.fillPath()
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.76).cgColor)
            ctx.setLineWidth(1.25)
            ctx.setLineJoin(.round)
            ctx.addPath(sp); ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private static func drawComicPuffBurst(in ctx: CGContext, puff: CGFloat, plump: CGFloat) {
        let a = min(1.0, (puff - 0.45) / 0.45) * 0.85
        let r = 56.0 * min(1.16, plump) + puff * 14.0
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(srgbRed: 0.16, green: 0.62, blue: 0.88, alpha: a).cgColor)
        ctx.setLineWidth(2.1)
        ctx.setLineCap(.round)
        for (ang, r0, r1) in [(-0.78, r + 10, r + 19), (-0.52, r + 12, r + 21), (-2.36, r + 10, r + 19), (-2.62, r + 12, r + 21)] as [(CGFloat, CGFloat, CGFloat)] {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: cos(ang) * r0, y: sin(ang) * r0))
            ctx.addLine(to: CGPoint(x: cos(ang) * r1, y: sin(ang) * r1))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private static func drawKeyTapRipple(in ctx: CGContext, center: CGPoint, progress: CGFloat) {
        let p = max(0, min(1, progress))
        let alpha = (1.0 - p) * 0.78
        let rx = 7.0 + p * 16.0
        let ry = 3.5 + p * 7.5
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(srgbRed: 0.10, green: 0.54, blue: 0.84, alpha: alpha).cgColor)
        ctx.setLineWidth(1.8)
        ctx.strokeEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
        ctx.restoreGState()
    }

    private static func drawWaterBubbles(in ctx: CGContext, bubbles: [FishBubbleParticle]) {
        guard !bubbles.isEmpty else { return }
        ctx.saveGState()
        for b in bubbles {
            let t = b.age / max(0.01, b.life)
            let alpha = (t < 0.12 ? t / 0.12 : (1.0 - max(0, (t - 0.68) / 0.32))) * 0.94
            guard alpha > 0.02 else { continue }
            let rect = CGRect(x: b.x - b.radius, y: b.y - b.radius, width: b.radius * 2, height: b.radius * 2)
            ctx.setFillColor(NSColor(srgbRed: 0.56, green: 0.88, blue: 0.99, alpha: alpha * 0.50).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(NSColor(srgbRed: 0.16, green: 0.58, blue: 0.80, alpha: alpha * 0.92).cgColor)
            ctx.setLineWidth(1.3)
            ctx.strokeEllipse(in: rect)
            ctx.setFillColor(NSColor.white.withAlphaComponent(alpha * 0.98).cgColor)
            let hr = b.radius * 0.34
            ctx.fillEllipse(in: CGRect(x: b.x - b.radius * 0.45, y: b.y - b.radius * 0.48, width: hr * 2, height: hr * 1.6))
        }
        ctx.restoreGState()
    }

    private static func drawSplashDroplets(in ctx: CGContext, droplets: [FishSplashDroplet]) {
        guard !droplets.isEmpty else { return }
        ctx.saveGState()
        for d in droplets {
            let alpha = max(0, 1.0 - d.age / max(0.01, d.life)) * 0.92
            guard alpha > 0.03 else { continue }
            let rect = CGRect(x: d.x - d.radius, y: d.y - d.radius, width: d.radius * 2, height: d.radius * 2)
            ctx.setFillColor(NSColor(srgbRed: 0.22, green: 0.72, blue: 0.98, alpha: alpha).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(NSColor(srgbRed: 0.08, green: 0.42, blue: 0.70, alpha: alpha * 0.90).cgColor)
            ctx.setLineWidth(1.1)
            ctx.strokeEllipse(in: rect)
            ctx.setFillColor(NSColor.white.withAlphaComponent(alpha * 0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: d.x - d.radius * 0.42, y: d.y - d.radius * 0.42, width: d.radius * 0.62, height: d.radius * 0.62))
        }
        ctx.restoreGState()
    }

    private static func drawWithStickerOutline(in ctx: CGContext, bounds: CGRect, drawBlock: (CGContext) -> Void) {
        let scale: CGFloat = 2.0
        let pxW = max(1, Int(ceil(bounds.width * scale)))
        let pxH = max(1, Int(ceil(bounds.height * scale)))
        guard let off = CGContext(
            data: nil,
            width: pxW,
            height: pxH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
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
        let r: CGFloat = 3.0
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

    // MARK: - Color & Gradient Helpers

    private static func makeLinearGradient(_ stops: [(CGFloat, NSColor)]) -> CGGradient? {
        let cols = stops.map { $0.1.cgColor } as CFArray
        let locs = stops.map { max(0, min(1, $0.0)) }
        return CGGradient(colorsSpace: colorSpace, colors: cols, locations: locs)
    }

    private static func blendColor(_ a: NSColor, _ b: NSColor, t: CGFloat) -> NSColor {
        let u = max(0, min(1, t))
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
