import Foundation
import AppKit
import CoreGraphics

// MARK: - Parametric Fish Species DNA (`FishPhotoDNA` -> `.kurocat` v2 `"species": "fish"`)

public enum FishBodyProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case pufferTorpedo = "puffer_torpedo"   // 河豚/狗头（方头圆肚流线体 + 鼓球基因）
    case goldfishRound = "goldfish_round"   // 金鱼/兰寿/泰狮（圆滚滚大肚 + 飘逸宽尾）
    case bettaFlow     = "betta_flow"       // 斗鱼（修长体态 + 超长半月飘鳍）
    case koiStream     = "koi_stream"       // 锦鲤（经典流线体 + 叉形尾）
    case angelfishDisc = "angelfish_disc"   // 神仙鱼（高背菱形圆盘 + 长背臀鳍）
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
    public var dorsalHex: String        // e.g. #A67E56 头背暖棕红鞍斑
    public var spotOuterHex: String     // e.g. #4A2B24 深褐黑斑外环
    public var spotInnerHex: String     // e.g. #DF3B36 鲜朱红斑内芯
    public var finHex: String           // e.g. #C5B268 金橄榄色扇形条纹尾鳍
    public var irisHex: String          // e.g. #E24E24 高凸琥珀红大圆眼
    public var hasBuckTeeth: Bool       // 河豚标志性露两颗小白板牙
    public var canPuffUp: Bool          // 河豚专属：戳肚/拎起/飙手速鼓成刺球
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
        self.dorsalHex = CatPhotoDNA.normalizeHex(dorsalHex, fallback: "#A86C52")
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
        dorsalHex = CatPhotoDNA.normalizeHex(dorsalHex, fallback: "#A86C52")
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

    public static func compileJSONData(from rawDNA: FishPhotoDNA, previewPNG: Data? = nil) throws -> Data {
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
            "author": "TypeZero 鱼类骨骼",
            "palette": palette,
            "typezeroFishDNA": dnaDict
        ]

        if let png = previewPNG, !png.isEmpty, png.count <= 420 * 1024 {
            root["preview"] = "data:image/png;base64," + png.base64EncodedString()
        }

        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }
}

// MARK: - 60fps Aquatic Swim, Key-Swoop, Mouse-Hug & Puffer Balloon Physics (`方案 A`)

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
    static let restAnchor = CGPoint(x: 196, y: 158)

    var pos = Spring2D(FishSwimPhysics.restAnchor)
    var pitch = Spring1D(0)           // radians (+ = nose tilts down toward keys)
    var roll = Spring1D(0)            // radians (gentle banking during horizontal swoops)
    var facing = Spring1D(1.0)        // +1 = facing right-front 3/4, -1 = turns slightly left for mouse
    var puff = Spring1D(0)            // 0 = sleek torpedo puffer, 1 = puffed-up spiky balloon!
    var leftFinSlap = Spring1D(0)     // near-side pectoral downward tap impulse
    var rightFinSlap = Spring1D(0)    // far-side pectoral downward tap impulse
    var mouseHug = Spring1D(0)        // 0 = hovering above keyboard, 1 = snuggled atop left mouse
    var mouthOpen = Spring1D(0.22)    // 0.22 = goofy buck-tooth smile, 0.85 = blowing bubbles / puff

    private(set) var swimPhase: CGFloat = 0
    private(set) var finPhase: CGFloat = 0
    private(set) var puffHoldTimer: CGFloat = 0
    private(set) var recentKeyTimer: CGFloat = 0
    private(set) var targetKeyPoint: CGPoint? = nil
    private var nextBubbleCooldown: CGFloat = 1.4
    private var rapidPokeCount: Int = 0
    private var lastPokeTime: CFTimeInterval = 0

    var bubbles: [FishBubbleParticle] = []
    var droplets: [FishSplashDroplet] = []

    func triggerKeySwoop(at keyPt: CGPoint, isLeftSide: Bool, now: CFTimeInterval) {
        targetKeyPoint = keyPt
        recentKeyTimer = 0.42
        mouseHug.target = 0
        if isLeftSide {
            leftFinSlap.value = min(1.3, leftFinSlap.value + 0.95)
            leftFinSlap.velocity = 9.0
        } else {
            rightFinSlap.value = min(1.3, rightFinSlap.value + 0.95)
            rightFinSlap.velocity = 9.0
        }
        mouthOpen.value = max(mouthOpen.value, 0.52)

        // Emit 5 crisp high-contrast glistening water droplets arcing cleanly above the white keycaps!
        for idx in 0..<5 {
            let ang = -CGFloat.pi * (0.20 + CGFloat(idx) * 0.15) + CGFloat.random(in: -0.06...0.06)
            let spd = CGFloat.random(in: 54...90)
            droplets.append(FishSplashDroplet(
                x: keyPt.x + CGFloat.random(in: -7...7),
                y: keyPt.y - 9,
                vx: cos(ang) * spd,
                vy: sin(ang) * spd - 20,
                radius: CGFloat.random(in: 2.8...4.3),
                age: 0,
                life: CGFloat.random(in: 0.38...0.54)
            ))
        }
        if droplets.count > 24 { droplets.removeFirst(droplets.count - 24) }
        _ = now
    }

    func triggerPuffUp(duration: CGFloat = 2.2) {
        puffHoldTimer = max(puffHoldTimer, duration)
        puff.target = 1.0
        puff.velocity = max(puff.velocity, 6.2)
        mouthOpen.value = 0.85
        spawnMouthBubbles(count: 3)
    }

    func registerBellyPoke(now: CFTimeInterval) {
        if now - lastPokeTime < 1.2 {
            rapidPokeCount += 1
        } else {
            rapidPokeCount = 1
        }
        lastPokeTime = now
        if rapidPokeCount >= 1 {
            triggerPuffUp(duration: 2.3)
        }
    }

    func spawnMouthBubbles(count: Int) {
        let dir: CGFloat = facing.value >= -0.1 ? 1.0 : -1.0
        // Spawn clearly in front & rising above the snout into open air (never buried on the cheek!)
        let mx = pos.point.x + dir * (69.0 + puff.value * 8.0)
        let my = pos.point.y - 6.0
        for i in 0..<count {
            let stepF = CGFloat(i)
            bubbles.append(FishBubbleParticle(
                x: mx + dir * (stepF * 5.5 + CGFloat.random(in: 0...4)),
                y: my - stepF * 15.0 - CGFloat.random(in: 2...6),
                vx: dir * CGFloat.random(in: 6...14),
                vy: -CGFloat.random(in: 26...40),
                radius: max(3.2, 6.2 - stepF * 1.1 + CGFloat.random(in: -0.4...0.6)),
                age: 0,
                life: CGFloat.random(in: 1.3...2.1)
            ))
        }
        if bubbles.count > 18 { bubbles.removeFirst(bubbles.count - 18) }
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
        let activeSpeed: CGFloat = (recentKeyTimer > 0 || mouseActive) ? 1.0 : 0.0
        swimPhase += dt * (3.7 + activeSpeed * 4.6 + puff.value * 2.2) * motionMul
        finPhase += dt * (7.2 + activeSpeed * 5.8 + puff.value * 3.5) * motionMul

        // 1. Puff-up lifecycle (dragging, rapid typing anger, intense belly poking, or manual trigger)
        if canPuffUp && (isDragging || anger > 0.42 || petIntensity > 0.65) {
            puffHoldTimer = max(puffHoldTimer, 0.55)
        }
        if puffHoldTimer > 0 && canPuffUp {
            let wasPuffed = puff.value > 0.35
            puffHoldTimer = max(0, puffHoldTimer - dt)
            puff.target = 1.0
            if puffHoldTimer <= 0.01 && wasPuffed {
                spawnMouthBubbles(count: 4)
            }
        } else {
            puff.target = 0.0
        }
        puff.step(dt: dt, stiffness: 190, damping: 14)

        // 2. Swim Target: Key Swoop -> Mouse Hug -> Buoyancy Hover
        if recentKeyTimer > 0 {
            recentKeyTimer = max(0, recentKeyTimer - dt)
        }
        let floatY = sin(time * 2.15) * 4.8 * motionMul
        let floatX = sin(time * 0.78) * 9.5 * motionMul

        if recentKeyTimer > 0, let kpt = targetKeyPoint {
            // Crisp nose-down swoop clearing the popped keycap cleanly while the angled pectoral fin taps toward the key!
            let clampedX = max(124, min(268, kpt.x - 16.0))
            let clampedY = max(166, min(202, kpt.y - 54.0))
            pos.target = CGPoint(x: clampedX, y: clampedY)
            pitch.target = 0.22 * motionMul
            facing.target = (kpt.x < 138) ? -1.0 : 1.0
            mouseHug.target = 0.0
        } else if mouseActive {
            // Glide smoothly down-left, turning nose-left so plump belly snuggles directly over the desk mouse & fins hug the buttons!
            pos.target = CGPoint(x: mouseCenter.x + 48.0, y: mouseCenter.y - 36.0 + floatY * 0.25)
            pitch.target = 0.16 * motionMul
            facing.target = -1.0
            mouseHug.target = 1.0
            if mouseClickLeft {
                leftFinSlap.value = max(leftFinSlap.value, 0.92)
            }
            if mouseClickRight {
                rightFinSlap.value = max(rightFinSlap.value, 0.92)
            }
        } else {
            pos.target = CGPoint(x: Self.restAnchor.x + floatX, y: Self.restAnchor.y + floatY)
            pitch.target = sin(time * 1.45) * 0.045 * motionMul
            facing.target = 1.0
            mouseHug.target = 0.0
        }

        let prevX = pos.point.x
        pos.step(dt: dt, stiffness: recentKeyTimer > 0 ? 230 : (mouseActive ? 165 : 88), damping: recentKeyTimer > 0 ? 19 : (mouseActive ? 16 : 13))
        let vx = (pos.point.x - prevX) / max(0.001, dt)
        roll.target = max(-0.16, min(0.16, vx * 0.00055))
        roll.step(dt: dt, stiffness: 120, damping: 16)
        pitch.step(dt: dt, stiffness: 140, damping: 16)
        facing.step(dt: dt, stiffness: 110, damping: 16)
        mouseHug.step(dt: dt, stiffness: 120, damping: 16)

        leftFinSlap.target = 0
        rightFinSlap.target = 0
        leftFinSlap.step(dt: dt, stiffness: 260, damping: 18)
        rightFinSlap.step(dt: dt, stiffness: 260, damping: 18)

        mouthOpen.target = puff.value > 0.2 ? 0.72 : 0.24
        mouthOpen.step(dt: dt, stiffness: 140, damping: 16)

        // 3. Ambient Bubble Emitter
        nextBubbleCooldown -= dt
        if nextBubbleCooldown <= 0 {
            nextBubbleCooldown = CGFloat.random(in: 2.6...4.8)
            mouthOpen.value = max(mouthOpen.value, 0.56)
            spawnMouthBubbles(count: Int.random(in: 1...2))
        }

        // 4. Advance Bubbles & Key-Splash Water Droplets
        for i in bubbles.indices {
            bubbles[i].age += dt
            bubbles[i].x += (bubbles[i].vx + sin(time * 4.5 + CGFloat(i)) * 8.0) * dt
            bubbles[i].y += bubbles[i].vy * dt
            bubbles[i].vx *= (1.0 - min(0.9, dt * 1.6))
        }
        bubbles.removeAll { $0.age >= $0.life }

        for i in droplets.indices {
            droplets[i].age += dt
            droplets[i].x += droplets[i].vx * dt
            droplets[i].y += droplets[i].vy * dt
            droplets[i].vy += 210.0 * dt
        }
        droplets.removeAll { $0.age >= $0.life }
    }
}

// MARK: - 3/4 Vector Sticker Fish Renderer (KuroCat Tactile Craft + Cross River Puffer Artistry)

enum FishRenderer {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// Head anchor point for floating `🫧 <name>` badge tracking above the swimming fish!
    static func headPosition(_ physics: CatPhysics, dna: FishPhotoDNA) -> CGPoint {
        let p = physics.fishSwim.pos.point
        let puff = max(0, min(1, physics.fishSwim.puff.value))
        let dir: CGFloat = physics.fishSwim.facing.value >= 0 ? 1.0 : -1.0
        let liftY: CGFloat = 34.0 * CGFloat(dna.plumpness) + puff * 26.0
        return CGPoint(x: p.x + dir * 16.0, y: p.y - liftY)
    }

    static func hitTestFish(point pt: CGPoint, physics: CatPhysics) -> Bool {
        let c = physics.fishSwim.pos.point
        let puff = max(0, min(1, physics.fishSwim.puff.value))
        let rx: CGFloat = 86.0 + puff * 10.0
        let ry: CGFloat = 48.0 + puff * 24.0
        let dx = (pt.x - c.x) / rx
        let dy = (pt.y - c.y) / ry
        return (dx * dx + dy * dy) <= 1.0
    }

    static func draw(
        in ctx: CGContext,
        physics: CatPhysics,
        dna: FishPhotoDNA,
        whiteOutline: Bool,
        isPreview: Bool = false
    ) {
        let swim = physics.fishSwim
        let pos = swim.pos.point
        let puff = max(0, min(1, swim.puff.value))
        let facingSign: CGFloat = swim.facing.value >= -0.15 ? 1.0 : -1.0

        // 1. Soft aquatic hover shadow cast onto the desk / keyboard below
        drawHoverShadow(in: ctx, fishPos: pos, puff: puff)

        // 2. Crisp keycap tap ripple ring + high-contrast splash droplets
        if swim.recentKeyTimer > 0.02, let kpt = swim.targetKeyPoint {
            drawKeyTapRipple(in: ctx, center: kpt, progress: 1.0 - min(1.0, swim.recentKeyTimer / 0.42))
        }
        drawSplashDroplets(in: ctx, droplets: swim.droplets)

        // 3. Draw Fish Character (with optional crisp KuroCat-matching white die-cut sticker outline!)
        if whiteOutline {
            drawWithStickerOutline(in: ctx, bounds: CGRect(x: 0, y: 0, width: 360, height: 320)) { subCtx in
                drawFishBodyAndFins(in: subCtx, physics: physics, dna: dna, pos: pos, facingSign: facingSign, puff: puff)
            }
        } else {
            drawFishBodyAndFins(in: ctx, physics: physics, dna: dna, pos: pos, facingSign: facingSign, puff: puff)
        }

        // 4. Optional Music Headphones perched right behind protruding eyes!
        if !isPreview && physics.musicIntensity > 0.05 {
            drawMiniFishHeadphones(in: ctx, pos: pos, facingSign: facingSign, puff: puff, intensity: physics.musicIntensity, phase: physics.musicPhase)
        }

        // 5. Glistening translucent water bubbles floating upward
        drawWaterBubbles(in: ctx, bubbles: swim.bubbles)
    }

    // MARK: - Core 3/4 Fish Anatomy Painter

    private static func drawFishBodyAndFins(
        in ctx: CGContext,
        physics: CatPhysics,
        dna: FishPhotoDNA,
        pos: CGPoint,
        facingSign: CGFloat,
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
        let tailWave = sin(swim.swimPhase) * (10.0 + puff * 3.0)
        let tailTipLag = sin(swim.swimPhase - 0.85) * (14.0 + puff * 4.0)
        let keyDownBoost = (swim.recentKeyTimer > 0 ? 0.52 : 0.0) + swim.mouseHug.value * 0.42
        let farFinAngle = sin(swim.finPhase + 1.2) * 0.24 - (swim.rightFinSlap.value * 0.65 + keyDownBoost * 0.45)
        let nearFinAngle = sin(swim.finPhase) * 0.28 - (swim.leftFinSlap.value * 0.78 + keyDownBoost * 0.72)

        ctx.saveGState()
        ctx.translateBy(x: pos.x, y: pos.y)
        ctx.rotate(by: swim.pitch.value * facingSign + swim.roll.value)
        ctx.scaleBy(x: facingSign, y: 1.0)

        // (A) Far-side (right-front) translucent pectoral fan fin
        drawPectoralFin(
            in: ctx,
            anchor: CGPoint(x: 34 + puff * 8, y: 14 + puff * 10),
            angle: -0.18 + farFinAngle,
            scale: 0.88 * finScale,
            finCol: finCol,
            contourCol: contourCol,
            isNear: false
        )

        // (B) Wide Striped Broom-Fan Caudal Tail Fin (`尾鳍`, with flexible S-wave & 9 fin rays!)
        drawCaudalTailFin(
            in: ctx,
            profile: dna.bodyProfile,
            finScale: finScale,
            puff: puff,
            tailWave: tailWave,
            tailTipLag: tailTipLag,
            finCol: finCol,
            dorsalCol: dorsalCol,
            contourCol: contourCol
        )

        // (C) Dorsal Fin (upper back fan) & Ventral Anal Fin (lower tail-base fan)
        drawDorsalAndAnalFins(
            in: ctx,
            profile: dna.bodyProfile,
            finScale: finScale,
            plump: plump,
            puff: puff,
            wave: tailWave * 0.35,
            finCol: finCol,
            contourCol: contourCol
        )

        // (D) Puffer Spines Ring (strictly rooted INSIDE the inflated body perimeter — ZERO floating spines!)
        if puff > 0.12 && dna.canPuffUp {
            drawPuffSpines(in: ctx, puff: puff, plump: plump, bodyCol: bellyCol, tipCol: dorsalCol, contourCol: contourCol)
        }

        // (E) Far-side protruding eye brow bump (peeking cleanly over upper-right brow in authentic 3/4 view!)
        let farEyeCenter = CGPoint(x: 56 + puff * 4, y: -15 * plump - puff * 6)
        drawFishEye(
            in: ctx,
            center: farEyeCenter,
            radius: (8.6 + puff * 1.4),
            irisCol: irisCol,
            bodyCol: bodyCol,
            contourCol: contourCol,
            gaze: physics.eyeGaze.point,
            blink: physics.effectiveEyeClosure,
            puff: puff,
            isFar: true
        )

        // (F) Main 3/4 Torso Silhouette + Internal 3D Shading + Double-Ringed Ocelli Spots!
        let bodyPath = makeTorsoPath(profile: dna.bodyProfile, plump: plump, puff: puff, tailWave: tailWave * 0.25)

        // Base champagne-to-ivory vertical 3D volume gradient clipped inside torso
        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.clip()

        let topShade = blendColor(bodyCol, dorsalCol, t: 0.30)
        if let bodyGrad = makeLinearGradient([
            (0.00, topShade),
            (0.32, bodyCol),
            (0.68, blendColor(bodyCol, bellyCol, t: 0.60)),
            (1.00, bellyCol)
        ]) {
            let gyTop = -40 * plump - puff * 26
            let gyBot = 36 * plump + puff * 30
            ctx.drawLinearGradient(bodyGrad, start: CGPoint(x: 0, y: gyTop), end: CGPoint(x: 0, y: gyBot), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Subtle warm forehead/crown saddle mottling & iconic coat pattern (`ringedOcelli`, `spotted`, etc.)
        drawFishMarkings(
            in: ctx,
            dna: dna,
            plump: plump,
            puff: puff,
            dorsalCol: dorsalCol,
            spotOuterCol: spotOuterCol,
            spotInnerCol: spotInnerCol,
            bellyCol: bellyCol
        )

        // Soft glossy aquatic specular rim highlight along upper back
        ctx.saveGState()
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.24).cgColor)
        let gloss = CGMutablePath()
        gloss.addEllipse(in: CGRect(x: -24, y: -27 * plump - puff * 18, width: 64, height: 11))
        ctx.addPath(gloss)
        ctx.fillPath()
        ctx.restoreGState()

        // Cute soft coral cheek blush when puffed up or petted!
        let blushAlpha = max(puff * 0.32, physics.petHeadIntensity * 0.35)
        if blushAlpha > 0.04 {
            ctx.setFillColor(NSColor(srgbRed: 0.96, green: 0.42, blue: 0.42, alpha: blushAlpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: 34 + puff * 4, y: -1, width: 14, height: 9))
        }

        ctx.restoreGState() // end torso clip

        // Crisp clean hand-drawn contour stroke around torso
        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.86).cgColor)
        ctx.setLineWidth(1.85)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(bodyPath)
        ctx.strokePath()
        ctx.restoreGState()

        // Subtle curved gill slit crease right in front of the near pectoral fin
        ctx.saveGState()
        let gill = CGMutablePath()
        gill.move(to: CGPoint(x: 11 + puff * 4, y: -4 - puff * 4))
        gill.addQuadCurve(to: CGPoint(x: 10 + puff * 4, y: 15 + puff * 5), control: CGPoint(x: 16 + puff * 5, y: 6))
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.addPath(gill)
        ctx.strokePath()
        ctx.restoreGState()

        // (G) Goofy Smiling Thick Lips + Two Adorable White Puffer Buck Teeth!
        drawFishMouth(
            in: ctx,
            dna: dna,
            puff: puff,
            mouthOpen: max(0, min(1, swim.mouthOpen.value)),
            bellyCol: bellyCol,
            contourCol: contourCol
        )

        // (H) Near-side Prominent Protruding 3D Amber-Red Eye!
        let nearEyeCenter = CGPoint(x: 33 + puff * 3, y: -13 * plump - puff * 6)
        drawFishEye(
            in: ctx,
            center: nearEyeCenter,
            radius: (10.5 + puff * 1.8),
            irisCol: irisCol,
            bodyCol: bodyCol,
            contourCol: contourCol,
            gaze: physics.eyeGaze.point,
            blink: physics.effectiveEyeClosure,
            puff: puff,
            isFar: false
        )

        // (I) Near-side Translucent Fan Pectoral Fin (fluttering helicopter propeller & downward key-slapper!)
        drawPectoralFin(
            in: ctx,
            anchor: CGPoint(x: 11 + puff * 4, y: 9 + puff * 7 + keyDownBoost * 5),
            angle: -0.06 + nearFinAngle,
            scale: (1.02 + keyDownBoost * 0.12) * finScale,
            finCol: finCol,
            contourCol: contourCol,
            isNear: true
        )

        // (J) Crisp comic puff-burst accent arcs when inflated into a spiky balloon!
        if puff > 0.45 && dna.canPuffUp {
            drawComicPuffBurst(in: ctx, puff: puff, plump: plump)
        }

        ctx.restoreGState()
    }

    // MARK: - Torso Geometry Morph (Streamlined Puffer <-> Plump Balloon!)

    private static func makeTorsoPath(profile: FishBodyProfile, plump: CGFloat, puff: CGFloat, tailWave: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let hScale = plump * (1.0 + puff * 0.56)
        let wPuff = puff * 7.0
        let tailBaseY = tailWave * 0.25

        // When puffed up (`puff > 0.02`) on puffer/round fish, smoothly morph into a true round plump balloon!
        if puff > 0.02 && (profile == .pufferTorpedo || profile == .goldfishRound) {
            let rx = 62.0 + puff * 3.0
            let ry = (31.0 * plump) + puff * (27.0 * plump)
            let cx = 4.0 + puff * 3.0
            let cy = 1.0 + puff * 2.0
            let smoothPuff = puff * puff * (3.0 - 2.0 * puff)
            if smoothPuff > 0.72 {
                p.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
                return p
            }
        }

        switch profile {
        case .angelfishDisc:
            p.move(to: CGPoint(x: 62 + wPuff, y: 3))
            p.addCurve(to: CGPoint(x: 2, y: -44 * hScale), control1: CGPoint(x: 46, y: -22 * hScale), control2: CGPoint(x: 24, y: -44 * hScale))
            p.addCurve(to: CGPoint(x: -54, y: tailBaseY - 7), control1: CGPoint(x: -24, y: -42 * hScale), control2: CGPoint(x: -44, y: -18))
            p.addLine(to: CGPoint(x: -54, y: tailBaseY + 9))
            p.addCurve(to: CGPoint(x: 2, y: 42 * hScale), control1: CGPoint(x: -44, y: 20), control2: CGPoint(x: -22, y: 42 * hScale))
            p.addCurve(to: CGPoint(x: 62 + wPuff, y: 3), control1: CGPoint(x: 26, y: 42 * hScale), control2: CGPoint(x: 48, y: 24 * hScale))
            p.closeSubpath()
        case .koiStream, .bettaFlow:
            let slim = (profile == .bettaFlow) ? 0.80 : 0.86
            let hs = hScale * slim
            p.move(to: CGPoint(x: 64 + wPuff, y: 2))
            p.addCurve(to: CGPoint(x: 10, y: -28 * hs), control1: CGPoint(x: 52, y: -18 * hs), control2: CGPoint(x: 34, y: -29 * hs))
            p.addCurve(to: CGPoint(x: -60, y: tailBaseY - 7), control1: CGPoint(x: -18, y: -27 * hs), control2: CGPoint(x: -44, y: -14))
            p.addLine(to: CGPoint(x: -60, y: tailBaseY + 8))
            p.addCurve(to: CGPoint(x: 12, y: 27 * hs), control1: CGPoint(x: -42, y: 15), control2: CGPoint(x: -14, y: 28 * hs))
            p.addCurve(to: CGPoint(x: 64 + wPuff, y: 2), control1: CGPoint(x: 38, y: 26 * hs), control2: CGPoint(x: 54, y: 16 * hs))
            p.closeSubpath()
        default:
            // Authentic Cross River Puffer / Plump Round Goldfish 3/4 silhouette:
            // Boxy-rounded forehead sloping back over plump dome, tapering smoothly to tail peduncle, with chubby belly!
            let browY = -26.0 * hScale
            let backY = -31.0 * hScale
            let bellyY = 30.0 * hScale + puff * 10.0
            let tailRootX: CGFloat = -58.0 + puff * 10.0

            p.move(to: CGPoint(x: 63 + wPuff, y: 4))
            // Snout up over boxy puffer forehead
            p.addCurve(
                to: CGPoint(x: 36 + wPuff * 0.5, y: browY),
                control1: CGPoint(x: 64 + wPuff, y: -11 * hScale),
                control2: CGPoint(x: 55 + wPuff * 0.7, y: browY - 2)
            )
            // Flat-rounded dorsal back tapering smoothly into tail peduncle
            p.addCurve(
                to: CGPoint(x: -12, y: backY + 2),
                control1: CGPoint(x: 18, y: backY - 1),
                control2: CGPoint(x: 0, y: backY)
            )
            p.addCurve(
                to: CGPoint(x: tailRootX, y: tailBaseY - 9),
                control1: CGPoint(x: -34, y: backY + 7 + puff * 14),
                control2: CGPoint(x: -48, y: tailBaseY - 13)
            )
            // Tail root join
            p.addLine(to: CGPoint(x: tailRootX, y: tailBaseY + 10))
            // Lower tail peduncle swelling into plump ivory puffer belly!
            p.addCurve(
                to: CGPoint(x: 6, y: bellyY),
                control1: CGPoint(x: -44, y: tailBaseY + 14),
                control2: CGPoint(x: -24, y: bellyY + 2)
            )
            // Chubby front chest rising cleanly up to the smiling puffer lips
            p.addCurve(
                to: CGPoint(x: 63 + wPuff, y: 4),
                control1: CGPoint(x: 36 + wPuff * 0.5, y: bellyY - 2),
                control2: CGPoint(x: 62 + wPuff, y: 20 * hScale)
            )
            p.closeSubpath()
        }
        return p
    }

    // MARK: - Iconic Cross River Puffer Double-Ringed Ocelli & General Fish Markings

    private static func drawFishMarkings(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        plump: CGFloat,
        puff: CGFloat,
        dorsalCol: NSColor,
        spotOuterCol: NSColor,
        spotInnerCol: NSColor,
        bellyCol: NSColor
    ) {
        let hs = plump * (1.0 + puff * 0.45)

        switch dna.spotPattern {
        case .ringedOcelli:
            // 1. Warm russet-terracotta dorsal saddle blotches across brow & upper back (harmonized with crimson ocelli!)
            let warmDorsal = blendColor(dorsalCol, spotInnerCol, t: 0.34)
            let saddles: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (44, -22 * hs, 13, 7.0, -0.18),
                (22, -25 * hs, 15, 8.0, -0.08),
                (0,  -26 * hs, 16, 8.5, 0.04),
                (-22, -22 * hs, 13, 7.0, 0.16),
                (49, 2, 7.5, 5.8, 0.1) // rosy cheek patch behind mouth!
            ]
            for (sx, sy, rx, ry, rot) in saddles {
                ctx.saveGState()
                ctx.translateBy(x: sx, y: sy)
                ctx.rotate(by: rot)
                let col = (sx > 46 && sy > -2) ? spotInnerCol.withAlphaComponent(0.58) : warmDorsal.withAlphaComponent(0.66)
                ctx.setFillColor(col.cgColor)
                ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                ctx.restoreGState()
            }

            // 2. Iconic Double-Ringed Ocelli (`深褐黑外环 + 鲜朱红内芯`) — clear breathing space behind the fluttering pectoral fin!
            let ocelli: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (23,  -7 * hs, 6.0, 5.5, -0.10),
                (9,  -16 * hs, 6.6, 5.8, -0.12),
                (-9, -15 * hs, 6.8, 6.0, -0.06),
                (-14, -3 * hs, 7.4, 6.6, 0.05),
                (-19,  9 * hs, 6.5, 5.9, 0.12),
                (-25, -13 * hs, 6.4, 5.7, -0.05),
                (-29,  1 * hs, 7.0, 6.2, 0.08),
                (-34, 11 * hs, 5.8, 5.3, 0.15),
                (-40, -7 * hs, 5.8, 5.2, -0.08),
                (-44,  4 * hs, 5.9, 5.2, 0.06),
                (-52, -1 * hs, 5.0, 4.6, 0.0)
            ]
            for (ox, oy, rx, ry, rot) in ocelli {
                ctx.saveGState()
                ctx.translateBy(x: ox, y: oy)
                ctx.rotate(by: rot)
                // Dark maroon-brown outer ring
                ctx.setFillColor(spotOuterCol.withAlphaComponent(0.92).cgColor)
                ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                // Glowing crimson-red inner ocellus core!
                let irx = rx * 0.58
                let iry = ry * 0.58
                ctx.setFillColor(spotInnerCol.cgColor)
                ctx.fillEllipse(in: CGRect(x: -irx, y: -iry, width: irx * 2, height: iry * 2))
                ctx.restoreGState()
            }

        case .spotted:
            let pts: [(CGFloat, CGFloat, CGFloat)] = [
                (26, -15 * hs, 6.5), (10, -18 * hs, 7.2), (-6, -14 * hs, 7.0),
                (16, -2 * hs, 6.0), (-2, 2 * hs, 7.4), (-18, -4 * hs, 6.8),
                (-26, 8 * hs, 5.8), (-36, -6 * hs, 5.5), (-46, 2 * hs, 5.0)
            ]
            ctx.setFillColor(spotOuterCol.withAlphaComponent(0.84).cgColor)
            for (x, y, r) in pts {
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r * 0.9, width: r * 2, height: r * 1.8))
            }

        case .stripedVertical:
            // Classic clownfish / angelfish crisp vertical bands with dark edge rim!
            for bx in [24.0, -4.0, -34.0] as [CGFloat] {
                let band = CGMutablePath()
                band.move(to: CGPoint(x: bx - 6, y: -48 * hs))
                band.addQuadCurve(to: CGPoint(x: bx - 5, y: 48 * hs), control: CGPoint(x: bx - 10, y: 0))
                band.addLine(to: CGPoint(x: bx + 6, y: 48 * hs))
                band.addQuadCurve(to: CGPoint(x: bx + 6, y: -48 * hs), control: CGPoint(x: bx + 2, y: 0))
                band.closeSubpath()
                ctx.saveGState()
                ctx.setFillColor(bellyCol.cgColor)
                ctx.addPath(band)
                ctx.fillPath()
                ctx.setStrokeColor(spotOuterCol.withAlphaComponent(0.88).cgColor)
                ctx.setLineWidth(2.4)
                ctx.addPath(band)
                ctx.strokePath()
                ctx.restoreGState()
            }

        case .calicoBlotch:
            let blotches: [(CGFloat, CGFloat, CGFloat, CGFloat, NSColor)] = [
                (26, -18 * hs, 20, 14, spotInnerCol),
                (-8, -12 * hs, 24, 16, spotInnerCol),
                (-28, 4 * hs, 16, 12, spotOuterCol.withAlphaComponent(0.85)),
                (8, 6 * hs, 14, 10, dorsalCol.withAlphaComponent(0.82))
            ]
            for (x, y, rx, ry, col) in blotches {
                ctx.setFillColor(col.cgColor)
                ctx.fillEllipse(in: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
            }

        case .saddleBack:
            for (x, rx, ry) in [(24.0, 18.0, 14.0), (-6.0, 22.0, 15.0), (-34.0, 16.0, 12.0)] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.setFillColor(dorsalCol.withAlphaComponent(0.74).cgColor)
                ctx.fillEllipse(in: CGRect(x: x - rx, y: -32 * hs, width: rx * 2, height: ry * 2))
            }

        case .solidGradient:
            break
        }
    }

    // MARK: - Fins (Striped Broom-Fan Tail, Translucent Fluttering Pectoral Fins, Dorsal & Anal)

    private static func drawCaudalTailFin(
        in ctx: CGContext,
        profile: FishBodyProfile,
        finScale: CGFloat,
        puff: CGFloat,
        tailWave: CGFloat,
        tailTipLag: CGFloat,
        finCol: NSColor,
        dorsalCol: NSColor,
        contourCol: NSColor
    ) {
        let rootX: CGFloat = -54.0 + puff * 10.0
        let rootY: CGFloat = tailWave * 0.25
        let len: CGFloat = (profile == .bettaFlow ? 62.0 : (profile == .goldfishRound ? 54.0 : 46.0)) * finScale
        let spread: CGFloat = (profile == .bettaFlow ? 40.0 : (profile == .goldfishRound ? 35.0 : 27.0)) * finScale
        let tipX = rootX - len
        let tipY = rootY + tailTipLag

        let path = CGMutablePath()
        path.move(to: CGPoint(x: rootX + 4, y: rootY - 9))
        path.addQuadCurve(
            to: CGPoint(x: tipX, y: tipY - spread),
            control: CGPoint(x: rootX - len * 0.45, y: rootY - spread * 0.65 + tailWave * 0.35)
        )
        if profile == .koiStream {
            // Classic V-forked koi tail
            path.addQuadCurve(
                to: CGPoint(x: tipX + len * 0.32, y: tipY),
                control: CGPoint(x: tipX + 4, y: tipY - spread * 0.35)
            )
            path.addQuadCurve(
                to: CGPoint(x: tipX, y: tipY + spread),
                control: CGPoint(x: tipX + 4, y: tipY + spread * 0.35)
            )
        } else {
            // Rounded broom-fan puffer / veil goldfish tail edge
            path.addCurve(
                to: CGPoint(x: tipX, y: tipY + spread),
                control1: CGPoint(x: tipX - 8, y: tipY - spread * 0.38),
                control2: CGPoint(x: tipX - 8, y: tipY + spread * 0.38)
            )
        }
        path.addQuadCurve(
            to: CGPoint(x: rootX + 4, y: rootY + 10),
            control: CGPoint(x: rootX - len * 0.45, y: rootY + spread * 0.65 + tailWave * 0.35)
        )
        path.closeSubpath()

        // Translucent golden-olive base-to-tip gradient
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.95)),
            (0.65, blendColor(finCol, dorsalCol, t: 0.25).withAlphaComponent(0.84)),
            (1.0, finCol.withAlphaComponent(0.62))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: rootX, y: rootY), end: CGPoint(x: tipX - 6, y: tipY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // 9 crisp radiating tail fin rays (`扇形尾鳍条纹`, iconic on 红斑狗头!)
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.42).cgColor)
        ctx.setLineWidth(1.25)
        ctx.setLineCap(.round)
        for i in -4...4 {
            let frac = CGFloat(i) / 4.0
            let sy = rootY + frac * 7.5
            let ey = tipY + frac * (spread * 0.88)
            let ray = CGMutablePath()
            ray.move(to: CGPoint(x: rootX + 2, y: sy))
            ray.addQuadCurve(
                to: CGPoint(x: tipX + 2, y: ey),
                control: CGPoint(x: rootX - len * 0.5, y: (sy + ey) * 0.5 + tailWave * 0.22)
            )
            ctx.addPath(ray)
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.75).cgColor)
        ctx.setLineWidth(1.6)
        ctx.setLineJoin(.round)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawDorsalAndAnalFins(
        in ctx: CGContext,
        profile: FishBodyProfile,
        finScale: CGFloat,
        plump: CGFloat,
        puff: CGFloat,
        wave: CGFloat,
        finCol: NSColor,
        contourCol: NSColor
    ) {
        let hs = plump * (1.0 + puff * 0.45)
        let dorsalH: CGFloat = (profile == .angelfishDisc ? 42.0 : (profile == .bettaFlow ? 34.0 : 24.0)) * finScale

        // Dorsal fan fin (set back near tail base on puffers, iconic upright translucent fan!)
        let dBaseX: CGFloat = -28.0 + puff * 6.0
        let dBaseY: CGFloat = -22.0 * hs
        let dorsal = CGMutablePath()
        dorsal.move(to: CGPoint(x: dBaseX + 9, y: dBaseY + 2))
        dorsal.addCurve(
            to: CGPoint(x: dBaseX - 15, y: dBaseY - dorsalH + wave * 0.5),
            control1: CGPoint(x: dBaseX + 6, y: dBaseY - dorsalH * 0.8),
            control2: CGPoint(x: dBaseX - 6, y: dBaseY - dorsalH * 1.05)
        )
        dorsal.addQuadCurve(
            to: CGPoint(x: dBaseX - 11, y: dBaseY + 7),
            control: CGPoint(x: dBaseX - 24, y: dBaseY - dorsalH * 0.32)
        )
        dorsal.closeSubpath()

        drawTranslucentFinPath(ctx, path: dorsal, anchor: CGPoint(x: dBaseX, y: dBaseY + 4), tip: CGPoint(x: dBaseX - 14, y: dBaseY - dorsalH), rayCount: 5, finCol: finCol, contourCol: contourCol)

        // Ventral anal fan fin (symmetric under rear belly)
        let aBaseX: CGFloat = -30.0 + puff * 6.0
        let aBaseY: CGFloat = 19.0 * hs
        let analH: CGFloat = dorsalH * 0.85
        let anal = CGMutablePath()
        anal.move(to: CGPoint(x: aBaseX + 8, y: aBaseY - 2))
        anal.addCurve(
            to: CGPoint(x: aBaseX - 14, y: aBaseY + analH + wave * 0.4),
            control1: CGPoint(x: aBaseX + 4, y: aBaseY + analH * 0.72),
            control2: CGPoint(x: aBaseX - 6, y: aBaseY + analH)
        )
        anal.addQuadCurve(
            to: CGPoint(x: aBaseX - 10, y: aBaseY - 6),
            control: CGPoint(x: aBaseX - 22, y: aBaseY + analH * 0.25)
        )
        anal.closeSubpath()

        drawTranslucentFinPath(ctx, path: anal, anchor: CGPoint(x: aBaseX, y: aBaseY - 3), tip: CGPoint(x: aBaseX - 12, y: aBaseY + analH), rayCount: 4, finCol: finCol, contourCol: contourCol)
    }

    private static func drawPectoralFin(
        in ctx: CGContext,
        anchor: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        finCol: NSColor,
        contourCol: NSColor,
        isNear: Bool
    ) {
        ctx.saveGState()
        ctx.translateBy(x: anchor.x, y: anchor.y)
        ctx.rotate(by: angle)
        ctx.scaleBy(x: scale, y: scale)

        // Delicate rounded translucent helicopter-propeller pectoral fan (`~24pt` short authentic puffer fin!)
        let fan = CGMutablePath()
        fan.move(to: CGPoint(x: 2, y: -5))
        fan.addCurve(
            to: CGPoint(x: -24, y: 12),
            control1: CGPoint(x: -9, y: -12),
            control2: CGPoint(x: -25, y: -2)
        )
        fan.addCurve(
            to: CGPoint(x: 2, y: 7),
            control1: CGPoint(x: -22, y: 22),
            control2: CGPoint(x: -6, y: 16)
        )
        fan.closeSubpath()

        let baseAlpha: CGFloat = isNear ? 0.78 : 0.60
        ctx.saveGState()
        ctx.addPath(fan)
        ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(baseAlpha)),
            (0.65, NSColor(srgbRed: 0.98, green: 0.95, blue: 0.86, alpha: baseAlpha * 0.72)),
            (1.0, NSColor.white.withAlphaComponent(baseAlpha * 0.45))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 2, y: 0), end: CGPoint(x: -24, y: 12), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // 6 delicate curved fin rays
        ctx.setStrokeColor(contourCol.withAlphaComponent(isNear ? 0.36 : 0.28).cgColor)
        ctx.setLineWidth(1.0)
        ctx.setLineCap(.round)
        for i in 0..<6 {
            let t = CGFloat(i) / 5.0
            let ex = -21.0 + t * 5.0
            let ey = -4.0 + t * 19.0
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 1, y: -2 + t * 6))
            ctx.addQuadCurve(to: CGPoint(x: ex, y: ey), control: CGPoint(x: -10, y: (ey - 1) * 0.5))
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.setStrokeColor(contourCol.withAlphaComponent(isNear ? 0.62 : 0.45).cgColor)
        ctx.setLineWidth(1.3)
        ctx.addPath(fan)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawTranslucentFinPath(
        _ ctx: CGContext,
        path: CGPath,
        anchor: CGPoint,
        tip: CGPoint,
        rayCount: Int,
        finCol: NSColor,
        contourCol: NSColor
    ) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.84)),
            (1.0, NSColor(srgbRed: 0.94, green: 0.91, blue: 0.84, alpha: 0.50))
        ]) {
            ctx.drawLinearGradient(grad, start: anchor, end: tip, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(1.05)
        for i in 0..<rayCount {
            let f = CGFloat(i) / CGFloat(max(1, rayCount - 1)) - 0.5
            ctx.beginPath()
            ctx.move(to: anchor)
            ctx.addLine(to: CGPoint(x: tip.x + f * 16.0, y: tip.y + f * 6.0))
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.68).cgColor)
        ctx.setLineWidth(1.45)
        ctx.setLineJoin(.round)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Protruding High-Set 3D Eyes & Buck-Toothed Smiling Puffer Lips

    private static func drawFishEye(
        in ctx: CGContext,
        center: CGPoint,
        radius: CGFloat,
        irisCol: NSColor,
        bodyCol: NSColor,
        contourCol: NSColor,
        gaze: CGPoint,
        blink: CGFloat,
        puff: CGFloat,
        isFar: Bool
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)

        // Raised fleshy puffer eye turret / socket bump
        let turretR = radius * 1.24
        ctx.setFillColor(blendColor(bodyCol, NSColor.white, t: 0.14).cgColor)
        ctx.fillEllipse(in: CGRect(x: -turretR, y: -turretR * 0.92, width: turretR * 2, height: turretR * 1.84))
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.65).cgColor)
        ctx.setLineWidth(1.4)
        ctx.strokeEllipse(in: CGRect(x: -turretR, y: -turretR * 0.92, width: turretR * 2, height: turretR * 1.84))

        if blink > 0.72 && puff < 0.25 {
            // Happy squinting arc
            let arc = CGMutablePath()
            arc.move(to: CGPoint(x: -radius * 0.75, y: 1))
            arc.addQuadCurve(to: CGPoint(x: radius * 0.75, y: 1), control: CGPoint(x: 0, y: -radius * 0.6))
            ctx.setStrokeColor(contourCol.cgColor)
            ctx.setLineWidth(2.0)
            ctx.setLineCap(.round)
            ctx.addPath(arc)
            ctx.strokePath()
            ctx.restoreGState()
            return
        }

        // Glowing metallic amber-red outer iris + golden inner shimmer ring!
        let irisRect = CGRect(x: -radius, y: -radius * 0.95, width: radius * 2, height: radius * 1.9)
        ctx.saveGState()
        ctx.addEllipse(in: irisRect)
        ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, blendColor(irisCol, NSColor(srgbRed: 1.0, green: 0.72, blue: 0.30, alpha: 1.0), t: 0.35)),
            (0.55, irisCol),
            (1.0, blendColor(irisCol, NSColor(srgbRed: 0.36, green: 0.08, blue: 0.06, alpha: 1.0), t: 0.45))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: -radius), end: CGPoint(x: 0, y: radius), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Responsive dark pupil tracking cursor / keys (shrinks slightly into goofy startled dot when puffed up!)
        let gx = max(-1, min(1, gaze.x)) * radius * 0.26
        let gy = max(-1, min(1, gaze.y)) * radius * 0.24
        let pupilR = radius * (puff > 0.25 ? (0.50 - puff * 0.14) : 0.52)
        ctx.setFillColor(NSColor(srgbRed: 0.09, green: 0.07, blue: 0.09, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: gx - pupilR, y: gy - pupilR, width: pupilR * 2, height: pupilR * 2))

        // Crisp glossy wet eye specular catchlights!
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
        let hlR = radius * 0.27
        ctx.fillEllipse(in: CGRect(x: -radius * 0.42, y: -radius * 0.48, width: hlR * 2, height: hlR * 1.8))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.68).cgColor)
        ctx.fillEllipse(in: CGRect(x: radius * 0.18, y: radius * 0.18, width: hlR * 0.85, height: hlR * 0.85))
        ctx.restoreGState()

        // Clean crisp eye rim
        ctx.setStrokeColor(contourCol.withAlphaComponent(isFar ? 0.75 : 0.90).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: irisRect)
        ctx.restoreGState()
    }

    private static func drawFishMouth(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        puff: CGFloat,
        mouthOpen: CGFloat,
        bellyCol: NSColor,
        contourCol: NSColor
    ) {
        let mx: CGFloat = 56.0 + puff * 6.0
        let my: CGFloat = 4.5 + puff * 2.0
        let lipCol = blendColor(bellyCol, NSColor(srgbRed: 0.96, green: 0.82, blue: 0.76, alpha: 1.0), t: 0.45)

        ctx.saveGState()
        ctx.translateBy(x: mx, y: my)

        if puff > 0.35 {
            // Cute surprised round "o" puffer lips!
            let r = 5.5 + puff * 2.0
            ctx.setFillColor(lipCol.cgColor)
            ctx.fillEllipse(in: CGRect(x: -r, y: -r * 0.9, width: r * 2, height: r * 1.8))
            ctx.setFillColor(NSColor(srgbRed: 0.46, green: 0.18, blue: 0.20, alpha: 0.92).cgColor)
            ctx.fillEllipse(in: CGRect(x: -r * 0.55, y: -r * 0.48, width: r * 1.1, height: r * 0.96))
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.82).cgColor)
            ctx.setLineWidth(1.4)
            ctx.strokeEllipse(in: CGRect(x: -r, y: -r * 0.9, width: r * 2, height: r * 1.8))
            ctx.restoreGState()
            return
        }

        // Plump, soft rounded "dog-head" fleshy puffer cushion lips (NOT a sharp cartoon bird beak!)
        let openH = 3.2 + mouthOpen * 4.0
        let upperLip = CGPath(roundedRect: CGRect(x: -7.5, y: -5.8, width: 16.5, height: 6.4), cornerWidth: 3.2, cornerHeight: 3.2, transform: nil)
        let lowerLip = CGPath(roundedRect: CGRect(x: -6.5, y: openH - 0.8, width: 15.0, height: 5.8), cornerWidth: 2.9, cornerHeight: 2.9, transform: nil)

        // Inner rosy mouth cavity
        let cavityRect = CGRect(x: -5.5, y: -1.6, width: 13.0, height: openH + 3.0)
        let cavity = CGPath(roundedRect: cavityRect, cornerWidth: 3.2, cornerHeight: 3.2, transform: nil)
        ctx.setFillColor(NSColor(srgbRed: 0.48, green: 0.19, blue: 0.22, alpha: 0.92).cgColor)
        ctx.addPath(cavity)
        ctx.fillPath()

        // Iconic TWO cute rounded white puffer buck teeth centered cleanly in the smiling mouth!
        if dna.hasBuckTeeth {
            ctx.saveGState()
            ctx.addPath(cavity)
            ctx.clip()
            let toothCol = NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1.0)
            let t1 = CGPath(roundedRect: CGRect(x: -1.6, y: -1.0, width: 3.7, height: 3.9), cornerWidth: 1.3, cornerHeight: 1.3, transform: nil)
            let t2 = CGPath(roundedRect: CGRect(x: 2.4, y: -1.0, width: 3.7, height: 3.9), cornerWidth: 1.3, cornerHeight: 1.3, transform: nil)
            ctx.setFillColor(toothCol.cgColor)
            ctx.addPath(t1); ctx.fillPath()
            ctx.addPath(t2); ctx.fillPath()
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.36).cgColor)
            ctx.setLineWidth(0.7)
            ctx.addPath(t1); ctx.strokePath()
            ctx.addPath(t2); ctx.strokePath()
            ctx.restoreGState()
        }

        // Fill + crisp contour on soft rounded upper & lower cushion lips
        for lip in [lowerLip, upperLip] {
            ctx.setFillColor(lipCol.cgColor)
            ctx.addPath(lip)
            ctx.fillPath()
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.76).cgColor)
            ctx.setLineWidth(1.3)
            ctx.addPath(lip)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    // MARK: - Puff-Up Soft Spines (Strictly Anchored Inside Inflated Balloon!), Comic Burst, Bubbles & Splash

    private static func drawPuffSpines(
        in ctx: CGContext,
        puff: CGFloat,
        plump: CGFloat,
        bodyCol: NSColor,
        tipCol: NSColor,
        contourCol: NSColor
    ) {
        // Exact center & radii matching the inflated round balloon in `makeTorsoPath`!
        let cx: CGFloat = 4.0 + puff * 3.0
        let cy: CGFloat = 1.0 + puff * 2.0
        let rx: CGFloat = 62.0 + puff * 3.0
        let ry: CGFloat = (31.0 * plump) + puff * (27.0 * plump)
        let spineLen: CGFloat = 10.5 * puff
        let spineCol = blendColor(bodyCol, tipCol, t: 0.30)

        let count = 20
        ctx.saveGState()
        for i in 0..<count {
            let ang = CGFloat(i) / CGFloat(count) * .pi * 2.0
            // Skip narrow tail-root exit wedge (around PI) and snout/mouth exit wedge (around 0) so ZERO spines float!
            let distFromTail = abs(atan2(sin(ang - .pi), cos(ang - .pi)))
            let distFromMouth = abs(atan2(sin(ang), cos(ang)))
            if distFromTail < 0.34 || distFromMouth < 0.24 { continue }

            // Root tucked 7pt INSIDE the balloon perimeter so every spine merges seamlessly into the skin!
            let bx = cx + cos(ang) * (rx - 7.0)
            let by = cy + sin(ang) * (ry - 7.0)
            let tx = cx + cos(ang) * (rx + spineLen)
            let ty = cy + sin(ang) * (ry + spineLen)
            let nx = -sin(ang) * 4.2
            let ny = cos(ang) * 4.2

            let sp = CGMutablePath()
            sp.move(to: CGPoint(x: bx + nx, y: by + ny))
            sp.addLine(to: CGPoint(x: tx, y: ty))
            sp.addLine(to: CGPoint(x: bx - nx, y: by - ny))
            sp.closeSubpath()

            ctx.setFillColor(spineCol.cgColor)
            ctx.addPath(sp)
            ctx.fillPath()
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.76).cgColor)
            ctx.setLineWidth(1.25)
            ctx.setLineJoin(.round)
            ctx.addPath(sp)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private static func drawComicPuffBurst(in ctx: CGContext, puff: CGFloat, plump: CGFloat) {
        let a = min(1.0, (puff - 0.45) / 0.45) * 0.85
        let ry = (31.0 * plump) + puff * (27.0 * plump)
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(srgbRed: 0.22, green: 0.66, blue: 0.88, alpha: a).cgColor)
        ctx.setLineWidth(2.1)
        ctx.setLineCap(.round)
        // 3 playful radial "噗!" motion lines above upper-right brow
        for (ang, r0, r1) in [(-0.72, ry + 14, ry + 23), (-0.48, ry + 17, ry + 26), (-0.96, ry + 13, ry + 20)] as [(CGFloat, CGFloat, CGFloat)] {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 12 + cos(ang) * r0, y: sin(ang) * r0))
            ctx.addLine(to: CGPoint(x: 12 + cos(ang) * r1, y: sin(ang) * r1))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private static func drawKeyTapRipple(in ctx: CGContext, center: CGPoint, progress: CGFloat) {
        let p = max(0, min(1, progress))
        let alpha = (1.0 - p) * 0.88
        let rx = 8.0 + p * 20.0
        let ry = 4.0 + p * 9.0
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(srgbRed: 0.08, green: 0.50, blue: 0.82, alpha: alpha).cgColor)
        ctx.setLineWidth(2.1)
        ctx.strokeEllipse(in: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
        ctx.restoreGState()
    }

    private static func drawHoverShadow(in ctx: CGContext, fishPos: CGPoint, puff: CGFloat) {
        let shadowY: CGFloat = 236.0
        let heightAbove = max(12.0, shadowY - fishPos.y)
        let scale = max(0.55, min(1.15, 86.0 / heightAbove))
        let rx = (52.0 + puff * 10.0) * scale
        let ry = (9.5 + puff * 2.0) * scale
        let alpha = max(0.06, min(0.18, 0.16 * scale))

        let colors = [
            NSColor(srgbRed: 0.08, green: 0.11, blue: 0.18, alpha: alpha).cgColor,
            NSColor(srgbRed: 0.08, green: 0.11, blue: 0.18, alpha: 0.0).cgColor
        ] as CFArray
        guard let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }
        ctx.saveGState()
        ctx.translateBy(x: fishPos.x - 4, y: shadowY)
        ctx.scaleBy(x: rx, y: ry)
        ctx.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        ctx.clip()
        ctx.drawRadialGradient(grad, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    private static func drawWaterBubbles(in ctx: CGContext, bubbles: [FishBubbleParticle]) {
        guard !bubbles.isEmpty else { return }
        ctx.saveGState()
        for b in bubbles {
            let t = b.age / max(0.01, b.life)
            let alpha = (t < 0.12 ? t / 0.12 : (1.0 - max(0, (t - 0.68) / 0.32))) * 0.95
            guard alpha > 0.02 else { continue }
            let rect = CGRect(x: b.x - b.radius, y: b.y - b.radius, width: b.radius * 2, height: b.radius * 2)
            // High-contrast ocean-sky bubble body + crisp deep-teal rim + bright white specular glint!
            ctx.setFillColor(NSColor(srgbRed: 0.56, green: 0.88, blue: 0.99, alpha: alpha * 0.52).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(NSColor(srgbRed: 0.16, green: 0.58, blue: 0.80, alpha: alpha * 0.92).cgColor)
            ctx.setLineWidth(1.35)
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
            let alpha = max(0, 1.0 - d.age / max(0.01, d.life)) * 0.96
            guard alpha > 0.03 else { continue }
            let rect = CGRect(x: d.x - d.radius, y: d.y - d.radius, width: d.radius * 2, height: d.radius * 2)
            ctx.setFillColor(NSColor(srgbRed: 0.20, green: 0.72, blue: 0.98, alpha: alpha).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(NSColor(srgbRed: 0.06, green: 0.38, blue: 0.68, alpha: alpha * 0.95).cgColor)
            ctx.setLineWidth(1.25)
            ctx.strokeEllipse(in: rect)
            ctx.setFillColor(NSColor.white.withAlphaComponent(alpha * 0.98).cgColor)
            ctx.fillEllipse(in: CGRect(x: d.x - d.radius * 0.44, y: d.y - d.radius * 0.44, width: d.radius * 0.68, height: d.radius * 0.68))
        }
        ctx.restoreGState()
    }

    private static func drawMiniFishHeadphones(
        in ctx: CGContext,
        pos: CGPoint,
        facingSign: CGFloat,
        puff: CGFloat,
        intensity: CGFloat,
        phase: CGFloat
    ) {
        let bounce = sin(phase * 2.0) * 2.0 * intensity
        ctx.saveGState()
        ctx.setAlpha(intensity)
        ctx.translateBy(x: pos.x + facingSign * 14, y: pos.y - 24 - puff * 18 + bounce)

        let band = CGMutablePath()
        band.move(to: CGPoint(x: -16, y: 12))
        band.addCurve(to: CGPoint(x: 16, y: 12), control1: CGPoint(x: -14, y: -14), control2: CGPoint(x: 14, y: -14))
        ctx.setStrokeColor(NSColor(srgbRed: 0.16, green: 0.17, blue: 0.22, alpha: 1.0).cgColor)
        ctx.setLineWidth(4.2)
        ctx.setLineCap(.round)
        ctx.addPath(band)
        ctx.strokePath()

        for sx in [-16.0, 16.0] as [CGFloat] {
            let cup = CGPath(roundedRect: CGRect(x: sx - 5, y: 6, width: 10, height: 15), cornerWidth: 4.5, cornerHeight: 4.5, transform: nil)
            ctx.setFillColor(NSColor(srgbRed: 0.20, green: 0.21, blue: 0.27, alpha: 1.0).cgColor)
            ctx.addPath(cup); ctx.fillPath()
            ctx.setStrokeColor(NSColor(srgbRed: 0.48, green: 0.86, blue: 1.0, alpha: 0.92).cgColor)
            ctx.setLineWidth(1.5)
            ctx.addPath(cup); ctx.strokePath()
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
