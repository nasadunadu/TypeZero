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
    var microTilt = Spring1D(0)        // gentle ±0.03 rad head lean during typing (never dizzy!)
    var puff = Spring1D(0)             // 0 = normal puffer, 1 = puffed-up derpy spiky balloon!
    var leftFinSlap = Spring1D(0)      // subtle tap recoil on left elongated fin
    var rightFinSlap = Spring1D(0)     // subtle tap recoil on right elongated fin
    var mouthOpen = Spring1D(0.24)     // 0.24 = goofy buck-tooth smile, 0.78 = blowing bubbles / puff

    // MARK: - Fast-Typing Emotional Arc (Happy -> Serious -> Reluctant 💢 -> POOF Derpy Balloon!)
    /// Smooth 0..1 intensity tracking frantic typing escalation:
    /// 0.00-0.28 happy | 0.28-0.56 serious | 0.56-0.85 reluctant/grumpy | >=0.86 POOF into wide-eyed derpy spiky ball!
    var typingFrenzy = Spring1D(0)
    private var frenzyEnergy: CGFloat = 0
    private var recentKeyTimestamps: [CFTimeInterval] = []
    private var lastPuffFromFrenzy: Bool = false

    // MARK: - Calm Infrequent Idle Volumetric 3D Swim Showcase + Tail-Tap Keyboard Trick
    var sideBlend = Spring1D(0)        // 0 = front-facing steady desk posture, 1 = free-swimming 3D fish!
    var bodyYaw = Spring1D(0)          // true 3D yaw angle in radians: 0 = facing viewer, +π/2 = right, -π/2 = left (ZERO paper-flip!)
    var tailYaw = Spring1D(0)          // lagging tail yaw angle for realistic underwater S-curve follow-through!
    var swimPitch = Spring1D(0)        // buoyant swim pitch; lifts nose up during tail-tap trick!
    var tailTapFlex = Spring1D(0)      // 0..1 downward broom-fan tail flex to kiss a keycap!

    var facingSign: CGFloat {
        let s = sin(bodyYaw.value)
        if abs(s) < 0.02 { return showcaseDir >= 0 ? 1.0 : -1.0 }
        return s >= 0 ? 1.0 : -1.0
    }

    private(set) var isShowcaseActive: Bool = false
    private var showcaseForced: Bool = false
    private var showcaseElapsed: CGFloat = 0
    private let showcaseDuration: CGFloat = 7.6
    private var showcaseDir: CGFloat = 1.0          // alternates +1 / -1 each patrol
    private var showcaseTapKey: PhysicalKey = .n
    private var showcaseDidTriggerTap: Bool = false
    private var idleSeconds: CGFloat = 0
    private var nextShowcaseCooldown: CGFloat = 15.0 // calm & unhurried (not frequent!)
    private var pendingTailTapKey: PhysicalKey? = nil
    private(set) var tailTapRippleTimer: CGFloat = 0
    private(set) var tailTapRipplePoint: CGPoint? = nil

    private(set) var swimPhase: CGFloat = 0
    private(set) var finPhase: CGFloat = 0
    private(set) var puffHoldTimer: CGFloat = 0
    private(set) var recentKeyTimer: CGFloat = 0
    private(set) var targetKeyPoint: CGPoint? = nil
    private var nextBubbleCooldown: CGFloat = 2.0

    var bubbles: [FishBubbleParticle] = []
    var droplets: [FishSplashDroplet] = []

    func consumePendingTailTapKey() -> PhysicalKey? {
        defer { pendingTailTapKey = nil }
        return pendingTailTapKey
    }

    func cancelShowcaseToFront(cooldownRange: ClosedRange<CGFloat> = 16.0...26.0) {
        if isShowcaseActive {
            isShowcaseActive = false
            showcaseForced = false
            showcaseElapsed = 0
            sideBlend.target = 0
            bodyYaw.target = 0
            tailYaw.target = 0
            swimPitch.target = 0
            tailTapFlex.target = 0
        }
        idleSeconds = 0
        nextShowcaseCooldown = CGFloat.random(in: cooldownRange)
    }

    /// Triggers one graceful volumetric left/right 3D swim showcase + playful broom-fan tail keycap tap!
    func triggerIdleShowcaseNow(direction: CGFloat? = nil, forced: Bool = true) {
        guard puff.value < 0.25 else { return }
        isShowcaseActive = true
        showcaseForced = forced
        showcaseElapsed = 0
        showcaseDidTriggerTap = false
        if let dir = direction {
            showcaseDir = dir >= 0 ? 1.0 : -1.0
        } else {
            showcaseDir = -showcaseDir
        }
        // Choose a real top/home-row key on the tail's exact side of the keyboard!
        let leftTailKeys: [PhysicalKey] = [.n, .m, .b, .k, .j]
        let rightTailKeys: [PhysicalKey] = [.v, .c, .x, .f, .d]
        showcaseTapKey = (showcaseDir > 0 ? leftTailKeys : rightTailKeys).randomElement() ?? .space
        // Start from front-facing 0° so takeoff smoothly turns into side profile with zero snap!
        bodyYaw.value = 0
        tailYaw.value = 0
        bodyYaw.target = showcaseDir * (.pi * 0.5)
        tailYaw.target = showcaseDir * (.pi * 0.5)
    }

    /// Deterministic snapshot helper for Visual QA verification sheets.
    func setShowcaseSnapshot(elapsed: CGFloat, direction: CGFloat = 1.0, tapKey: PhysicalKey = .n) {
        isShowcaseActive = true
        showcaseForced = true
        showcaseDir = direction >= 0 ? 1.0 : -1.0
        showcaseTapKey = tapKey
        showcaseElapsed = elapsed
        showcaseDidTriggerTap = elapsed > 2.95
        let yawVal = showcaseDir * (.pi * 0.5)
        bodyYaw = Spring1D(yawVal)
        tailYaw = Spring1D(yawVal)
        sideBlend = Spring1D(1.0)
        let tapPt = KeyboardLayout.canvasPoint(for: tapKey)
        let preX = max(116, min(260, tapPt.x + showcaseDir * 70.0))
        pos = Spring2D(CGPoint(x: preX, y: 148))
    }

    /// Deterministic 3D yaw snapshot helper for verifying continuous volumetric U-turn frames!
    func setTurnAngleSnapshot(bodyYawDeg: CGFloat, tailYawDeg: CGFloat, center: CGPoint = CGPoint(x: 184, y: 146)) {
        isShowcaseActive = true
        showcaseForced = true
        sideBlend = Spring1D(1.0)
        bodyYaw = Spring1D(bodyYawDeg * .pi / 180.0)
        tailYaw = Spring1D(tailYawDeg * .pi / 180.0)
        swimPitch = Spring1D(0)
        tailTapFlex = Spring1D(0)
        pos = Spring2D(center)
    }

    func setTypingFrenzySnapshot(_ level: CGFloat) {
        frenzyEnergy = max(0, min(1.0, level))
        typingFrenzy.value = frenzyEnergy
        typingFrenzy.target = frenzyEnergy
    }

    func triggerKeySwoop(at keyPt: CGPoint, isLeftSide: Bool, now: CFTimeInterval) {
        // Any real typing instantly returns the fish to its rock-steady front-facing desk posture!
        cancelShowcaseToFront()

        targetKeyPoint = keyPt
        recentKeyTimer = 0.28
        microTilt.target = isLeftSide ? -0.028 : 0.028
        if isLeftSide {
            leftFinSlap.value = min(1.0, leftFinSlap.value + 0.85)
        } else {
            rightFinSlap.value = min(1.0, rightFinSlap.value + 0.85)
        }

        // Accumulate fast-typing frenzy (Happy -> Serious -> Reluctant 💢 -> POOF Derpy Spiky Balloon!)
        recentKeyTimestamps.append(now)
        if recentKeyTimestamps.count > 48 {
            recentKeyTimestamps.removeFirst(recentKeyTimestamps.count - 48)
        }
        if puffHoldTimer <= 0.05 {
            frenzyEnergy = min(1.05, frenzyEnergy + 0.062)
        } else if lastPuffFromFrenzy {
            // Keep puffed a little longer while user keeps hammering keys!
            puffHoldTimer = min(3.4, max(puffHoldTimer, 1.35))
        }

        spawnKeyDroplets(at: keyPt, count: 3)
    }

    private func spawnKeyDroplets(at keyPt: CGPoint, count: Int) {
        for idx in 0..<count {
            let ang = -CGFloat.pi * (0.24 + CGFloat(idx) * (0.52 / CGFloat(max(1, count)))) + CGFloat.random(in: -0.08...0.08)
            let spd = CGFloat.random(in: 36...62)
            droplets.append(FishSplashDroplet(
                x: keyPt.x + CGFloat.random(in: -4...4),
                y: keyPt.y - 5,
                vx: cos(ang) * spd,
                vy: sin(ang) * spd - 14,
                radius: CGFloat.random(in: 2.0...3.3),
                age: 0,
                life: CGFloat.random(in: 0.28...0.42)
            ))
        }
        if droplets.count > 18 { droplets.removeFirst(droplets.count - 18) }
    }

    func triggerPuffUp(duration: CGFloat = 2.4, fromFrenzy: Bool = false) {
        cancelShowcaseToFront()
        lastPuffFromFrenzy = fromFrenzy
        puffHoldTimer = max(puffHoldTimer, duration)
        puff.target = 1.0
        puff.velocity = max(puff.velocity, 6.8)
        mouthOpen.value = 0.85
        spawnMouthBubbles(count: 3)
    }

    func registerBellyPoke(now: CFTimeInterval) {
        triggerPuffUp(duration: 2.4, fromFrenzy: false)
        _ = now
    }

    func spawnMouthBubbles(count: Int) {
        // Spawn clearly outside & above the snout/head contour using true 3D yaw so bubbles ALWAYS rise in front of the snout!
        let sb = max(0, min(1, sideBlend.value))
        let yawSin = sin(bodyYaw.value)
        let faceSign: CGFloat = abs(yawSin) > 0.12 ? (yawSin >= 0 ? 1.0 : -1.0) : showcaseDir
        let baseX: CGFloat
        let baseY: CGFloat
        if isShowcaseActive || sb > 0.30 {
            baseX = pos.point.x + yawSin * 56.0 + (abs(yawSin) < 0.35 ? faceSign * 26.0 : 0.0)
            baseY = pos.point.y - 12.0 - cos(bodyYaw.value) * 14.0
        } else {
            baseX = pos.point.x + 58.0 + puff.value * 18.0
            baseY = pos.point.y - 46.0 - puff.value * 14.0
        }
        for i in 0..<count {
            let f = CGFloat(i)
            bubbles.append(FishBubbleParticle(
                x: baseX + faceSign * f * 7.0 + CGFloat.random(in: -2...4),
                y: baseY - f * 15.0,
                vx: faceSign * CGFloat.random(in: 4...10),
                vy: -CGFloat.random(in: 22...32),
                radius: max(3.2, 5.8 - f * 1.0 + CGFloat.random(in: -0.4...0.4)),
                age: 0,
                life: CGFloat.random(in: 1.5...2.2)
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
        isDictating: Bool = false,
        anger: CGFloat,
        enableAnger: Bool = true,
        petIntensity: CGFloat,
        canPuffUp: Bool,
        reducedMotion: Bool
    ) {
        let motionMul: CGFloat = reducedMotion ? 0.45 : 1.0
        let swimSpeed: CGFloat = isShowcaseActive ? 5.6 : (2.6 + (recentKeyTimer > 0 ? 1.8 : 0.0) + typingFrenzy.value * 2.2)
        swimPhase += dt * swimSpeed * motionMul
        finPhase += dt * (3.8 + typingFrenzy.value * 3.0) * motionMul

        // 1. Fast-typing emotional escalation (Happy -> Serious -> Reluctant 💢 -> POOF Derpy Spiky Balloon!)
        recentKeyTimestamps.removeAll { now - $0 > 2.4 }
        let kps = CGFloat(recentKeyTimestamps.count) / 2.4
        if enableAnger {
            // 3 kps -> gentle serious, 5.5 kps -> reluctant 💢, >=7.5 kps or rapid burst -> POOF derpy balloon!
            let rateTarget = max(0, min(1.0, (kps - 2.0) / 5.8))
            let combined = max(frenzyEnergy, max(rateTarget, anger * 0.92))
            if kps < 2.5 && recentKeyTimer <= 0.01 {
                frenzyEnergy = max(0, frenzyEnergy - dt * 0.24)
            } else {
                frenzyEnergy = max(frenzyEnergy - dt * 0.08, combined)
            }
            if canPuffUp && frenzyEnergy >= 0.86 && puffHoldTimer <= 0.05 {
                // Comedic flip! Furious typing pops the puffer into a bewildered wide-eyed derpy spiky balloon!
                triggerPuffUp(duration: 3.0, fromFrenzy: true)
            }
        } else {
            frenzyEnergy = max(0, frenzyEnergy - dt * 0.4)
        }
        // Once puffed into the derpy balloon, clear angry tension so expression flips straight to innocent wide-eyed derp!
        typingFrenzy.target = puff.value > 0.28 ? 0.0 : max(0, min(1.0, frenzyEnergy))
        typingFrenzy.step(dt: dt, stiffness: 85, damping: 16)

        // 2. In-place puff-up lifecycle (frenzy climax / poke / drag)
        if canPuffUp && (isDragging || petIntensity > 0.70 || (enableAnger && anger > 0.78)) {
            if puffHoldTimer <= 0.05 {
                triggerPuffUp(duration: 2.2, fromFrenzy: anger > 0.78)
            } else {
                puffHoldTimer = max(puffHoldTimer, 0.55)
            }
        }
        if puffHoldTimer > 0 && canPuffUp {
            let wasPuffed = puff.value > 0.35
            puffHoldTimer = max(0, puffHoldTimer - dt)
            puff.target = 1.0
            if puffHoldTimer <= 0.01 && wasPuffed {
                spawnMouthBubbles(count: 3)
                // Cool down frenzy after deflating so the fish returns happy & relaxed!
                frenzyEnergy = min(frenzyEnergy, 0.14)
                lastPuffFromFrenzy = false
            }
        } else {
            puff.target = 0.0
        }
        puff.step(dt: dt, stiffness: 185, damping: 14)

        // 3. Calm Infrequent Idle Side-Swim Showcase + Tail-Tap Keyboard Trick!
        let userBusy = recentKeyTimer > 0.02
            || (!showcaseForced && mouseActive)
            || mouseClickLeft || mouseClickRight
            || isDragging || isDictating
            || puff.value > 0.15 || puffHoldTimer > 0.01
            || typingFrenzy.value > 0.12

        if userBusy {
            cancelShowcaseToFront(cooldownRange: reducedMotion ? 28.0...42.0 : 16.0...26.0)
        } else if !isShowcaseActive {
            idleSeconds += dt
            if idleSeconds >= nextShowcaseCooldown {
                triggerIdleShowcaseNow(direction: nil, forced: false)
            }
        }

        if isShowcaseActive {
            showcaseElapsed += dt
            let t = showcaseElapsed
            let dir = showcaseDir
            let roamScale: CGFloat = reducedMotion ? 0.55 : 1.0
            let tapPt = KeyboardLayout.canvasPoint(for: showcaseTapKey)

            func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
                let u = max(0, min(1, (x - edge0) / max(0.0001, edge1 - edge0)))
                return u * u * (3 - 2 * u)
            }

            let halfPi = CGFloat.pi * 0.5
            if t < 0.80 {
                // Phase 1: Lift gracefully above desk while turning head 0° -> ±90° into full fish profile!
                let k = smoothstep(0.0, 0.80, t)
                sideBlend.target = 1.0
                bodyYaw.target = dir * halfPi * k
                tailYaw.target = dir * halfPi * max(0, k - 0.16) / 0.84
                pos.target = CGPoint(x: Self.bodyCenterAnchor.x + dir * 12 * k, y: 170 - 24 * k)
                swimPitch.target = -0.05 * k
                tailTapFlex.target = 0
            } else if t < 2.25 {
                // Phase 2: Leisurely glide across the keyboard showing full fish body & flank ocelli
                let k = smoothstep(0.80, 2.25, t)
                let targetX = Self.bodyCenterAnchor.x + dir * (12 + 46 * roamScale * k)
                let waveY = sin(swimPhase * 0.75) * 5.0 * motionMul
                sideBlend.target = 1.0
                bodyYaw.target = dir * halfPi
                tailYaw.target = dir * halfPi
                pos.target = CGPoint(x: targetX, y: 146 + waveY)
                swimPitch.target = cos(swimPhase * 0.75) * 0.05
                tailTapFlex.target = 0
                if abs(t - 1.45) < dt * 1.1 {
                    spawnMouthBubbles(count: 2)
                }
            } else if t < 3.60 {
                // Phase 3: 「尾巴炫技触碰键盘」— Arc nose playfully up, dip golden broom-fan tail down to kiss `tapPt` dead-center!
                let enterK = smoothstep(2.25, 2.86, t)
                let exitK = 1.0 - smoothstep(3.04, 3.60, t)
                let tapArc = min(enterK, exitK)

                let anchorX = max(116, min(260, tapPt.x + dir * 70.0))
                let anchorY = max(144, min(182, tapPt.y - 76.0))
                let restX = Self.bodyCenterAnchor.x + dir * (58 * roamScale)
                pos.target = CGPoint(
                    x: restX + (anchorX - restX) * min(1, enterK * 1.25),
                    y: 146 + (anchorY - 146) * tapArc
                )
                sideBlend.target = 1.0
                bodyYaw.target = dir * halfPi
                tailYaw.target = dir * halfPi
                swimPitch.target = -0.25 * tapArc
                tailTapFlex.target = tapArc

                if !showcaseDidTriggerTap && t >= 2.86 {
                    showcaseDidTriggerTap = true
                    pendingTailTapKey = showcaseTapKey
                    tailTapRipplePoint = tapPt
                    tailTapRippleTimer = 0.45
                    spawnKeyDroplets(at: tapPt, count: 4)
                    spawnMouthBubbles(count: 2)
                }
            } else if t < 4.85 {
                // Phase 4a: TRUE VOLUMETRIC 3D U-TURN! Head curves smoothly +90° -> 0° (chubby front face toward glass!) -> -90°, tail lags in a real S-curve!
                let uK = smoothstep(3.60, 4.85, t)
                let turnAngle = dir * halfPi * (1.0 - 2.0 * uK) // +90° -> 0° -> -90° smoothly!
                let startX = max(116, min(260, tapPt.x + dir * 70.0))
                // Gentle U-arc forward dip toward the viewer at the midpoint of the turn (`sin(uK * π)` peaks at 0°)
                let arcForwardDip = sin(uK * .pi) * 10.0
                let driftX = startX - dir * (22.0 * uK)
                sideBlend.target = 1.0
                bodyYaw.target = turnAngle
                // Tail lags behind the head turn for natural curved aquatic follow-through!
                let lagK = smoothstep(3.84, 5.10, t)
                tailYaw.target = dir * halfPi * (1.0 - 2.0 * lagK)
                pos.target = CGPoint(x: driftX, y: 146 + arcForwardDip)
                swimPitch.target = 0
                tailTapFlex.target = 0
                if abs(t - 4.22) < dt * 1.1 {
                    spawnMouthBubbles(count: 2)
                }
            } else if t < 6.45 {
                // Phase 4b: Calm opposite-direction cruise showing the other flank, then curving back to center!
                let startX = max(116, min(260, tapPt.x + dir * 70.0)) - dir * 22.0
                let oppX = Self.bodyCenterAnchor.x - dir * (50 * roamScale)
                let midK = smoothstep(4.85, 5.75, t)
                let backK = smoothstep(5.75, 6.45, t)
                let curX = (startX + (oppX - startX) * midK) * (1 - backK) + Self.bodyCenterAnchor.x * backK
                let waveY = sin(swimPhase * 0.75) * 4.5 * motionMul
                sideBlend.target = 1.0
                bodyYaw.target = -dir * halfPi * (1.0 - backK * 0.35)
                tailYaw.target = -dir * halfPi
                pos.target = CGPoint(x: curX, y: 144 + waveY)
                swimPitch.target = cos(swimPhase * 0.75) * 0.045
                tailTapFlex.target = 0
            } else if t < showcaseDuration {
                // Phase 5: Smoothly turn head back to 0° (front-facing) while descending gracefully behind keyboard!
                let k = smoothstep(6.45, showcaseDuration, t)
                bodyYaw.target = -dir * halfPi * 0.65 * (1.0 - k)
                tailYaw.target = -dir * halfPi * (1.0 - k * 0.85)
                // Only blend back to seated desk rig once head is nearly facing front (`k > 0.35`) so there's zero double-image!
                sideBlend.target = k > 0.35 ? max(0, 1.0 - (k - 0.35) / 0.65) : 1.0
                pos.target = CGPoint(x: Self.bodyCenterAnchor.x, y: 144 + (Self.bodyCenterAnchor.y - 144) * k)
                swimPitch.target = 0
                tailTapFlex.target = 0
            } else {
                cancelShowcaseToFront(cooldownRange: reducedMotion ? 30.0...44.0 : 18.0...28.0)
            }

            pos.step(dt: dt, stiffness: (t >= 2.25 && t < 3.60) ? 88 : 54, damping: 14)
            sideBlend.step(dt: dt, stiffness: 58, damping: 14)
            bodyYaw.step(dt: dt, stiffness: 42, damping: 12)
            tailYaw.step(dt: dt, stiffness: 22, damping: 9)
            swimPitch.step(dt: dt, stiffness: 68, damping: 15)
            tailTapFlex.step(dt: dt, stiffness: 120, damping: 15)
            microTilt.target = 0
            microTilt.step(dt: dt, stiffness: 120, damping: 18)
        } else {
            // 4. Rock-steady front-facing desk anchor (zero dizzy typing wobble!)
            if recentKeyTimer > 0 {
                recentKeyTimer = max(0, recentKeyTimer - dt)
            } else {
                microTilt.target = mouseActive ? -0.025 : 0.0
            }
            let breatheY = sin(time * 2.1) * 1.6 * motionMul
            let dragLiftY: CGFloat = isDragging ? -8.0 : 0.0
            let mouseSlideX: CGFloat = mouseActive ? -16.0 : 0.0
            // Subtle grumpy tremor when typing gets furious right before puffing!
            let grumpyJitterX: CGFloat = (typingFrenzy.value > 0.62 && puff.value < 0.2) ? sin(time * 36.0) * 1.1 * (typingFrenzy.value - 0.62) : 0.0
            pos.target = CGPoint(x: Self.bodyCenterAnchor.x + mouseSlideX + grumpyJitterX, y: Self.bodyCenterAnchor.y + breatheY + dragLiftY)
            pos.step(dt: dt, stiffness: mouseActive ? 75 : 120, damping: 18)
            microTilt.step(dt: dt, stiffness: 140, damping: 20)

            sideBlend.target = 0
            sideBlend.step(dt: dt, stiffness: 95, damping: 17)
            bodyYaw.target = 0
            bodyYaw.step(dt: dt, stiffness: 70, damping: 15)
            tailYaw.target = 0
            tailYaw.step(dt: dt, stiffness: 45, damping: 13)
            swimPitch.target = 0
            swimPitch.step(dt: dt, stiffness: 90, damping: 16)
            tailTapFlex.target = 0
            tailTapFlex.step(dt: dt, stiffness: 110, damping: 16)
        }

        if tailTapRippleTimer > 0 {
            tailTapRippleTimer = max(0, tailTapRippleTimer - dt)
        }

        if mouseActive && (mouseClickLeft || mouseClickRight) {
            leftFinSlap.value = max(leftFinSlap.value, 0.72)
        }
        leftFinSlap.target = 0
        rightFinSlap.target = 0
        leftFinSlap.step(dt: dt, stiffness: 260, damping: 20)
        rightFinSlap.step(dt: dt, stiffness: 260, damping: 20)

        mouthOpen.target = puff.value > 0.25 ? 0.75 : (typingFrenzy.value > 0.35 ? 0.08 : 0.24)
        mouthOpen.step(dt: dt, stiffness: 140, damping: 16)

        // 5. Occasional gentle ambient bubbles
        nextBubbleCooldown -= dt
        if nextBubbleCooldown <= 0 {
            nextBubbleCooldown = CGFloat.random(in: 3.6...6.2)
            if typingFrenzy.value < 0.45 {
                mouthOpen.value = max(mouthOpen.value, 0.48)
                spawnMouthBubbles(count: Int.random(in: 1...2))
            }
        }

        // 6. Advance bubbles & micro splash droplets
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
        _ = mouseCenter
    }
}

// MARK: - Dual-Mode 2.5D Vector Fish Renderer (Steady Front Typing + Idle Side-Swim & Tail-Tap + Zero Headphones!)

enum FishRenderer {
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// Head anchor point for floating `🫧 <name>` badge cleanly above either front-facing or 3D swimming crown!
    static func headPosition(_ physics: CatPhysics, dna: FishPhotoDNA) -> CGPoint {
        let swim = physics.fishSwim
        let c = swim.pos.point
        let puff = max(0, min(1, swim.puff.value))
        let sb = max(0, min(1, swim.sideBlend.value))
        let frontTopY = c.y - (52.0 * CGFloat(dna.plumpness) + puff * 18.0)
        let sideTopY = c.y - (38.0 * CGFloat(dna.plumpness))
        let sideHeadX = c.x + sin(swim.bodyYaw.value) * 14.0
        return CGPoint(
            x: c.x + (sideHeadX - c.x) * sb,
            y: frontTopY + (sideTopY - frontTopY) * sb
        )
    }

    static func hitTestFish(point pt: CGPoint, physics: CatPhysics) -> Bool {
        let swim = physics.fishSwim
        let c = swim.pos.point
        let puff = max(0, min(1, swim.puff.value))
        let sb = max(0, min(1, swim.sideBlend.value))
        let rx: CGFloat = (62.0 + puff * 16.0) * (1 - sb) + 78.0 * sb
        let ry: CGFloat = (64.0 + puff * 14.0) * (1 - sb) + 46.0 * sb
        let dx = (pt.x - c.x) / rx
        let dy = (pt.y - c.y) / ry
        return (dx * dx + dy * dy) <= 1.0
    }

    // MARK: - Two-Pass Desk Sandwich Rendering

    /// Pass 1 (Drawn BEHIND Keyboard & Mouse): Steady front-facing puffer torso during typing/rest.
    static func drawBodyBehindDesk(
        in ctx: CGContext,
        physics: CatPhysics,
        dna: FishPhotoDNA,
        whiteOutline: Bool
    ) {
        let swim = physics.fishSwim
        let sb = max(0, min(1, swim.sideBlend.value))
        let frontAlpha = max(0, min(1, 1.0 - sb * 1.45))
        guard frontAlpha > 0.02 else { return }

        let pos = swim.pos.point
        let puff = max(0, min(1, swim.puff.value))

        ctx.saveGState()
        if frontAlpha < 0.99 { ctx.setAlpha(frontAlpha) }
        if whiteOutline {
            drawWithStickerOutline(in: ctx, bounds: CGRect(x: 40, y: 40, width: 310, height: 260)) { subCtx in
                drawFrontBodyAndTail(in: subCtx, physics: physics, dna: dna, pos: pos, puff: puff)
            }
        } else {
            drawFrontBodyAndTail(in: ctx, physics: physics, dna: dna, pos: pos, puff: puff)
        }
        ctx.restoreGState()
    }

    /// Pass 2 (Drawn IN FRONT OF Keyboard & Mouse):
    /// - When steady (`sideBlend < 0.55`): elongated translucent left & right typing/mouse fins!
    /// - When idle patrolling (`sideBlend > 0.20`): full lifted aquarium side-profile fish whose broom-fan tail can cleanly dip onto the keyboard!
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
        let sb = max(0, min(1, swim.sideBlend.value))

        // Keycap tap ripples (from regular fin typing OR idle tail-tap trick!)
        if swim.recentKeyTimer > 0.02, let kpt = swim.targetKeyPoint {
            drawKeyTapRipple(in: ctx, center: kpt, progress: 1.0 - min(1.0, swim.recentKeyTimer / 0.28))
        }
        if swim.tailTapRippleTimer > 0.02, let tpt = swim.tailTapRipplePoint {
            let p = 1.0 - min(1.0, swim.tailTapRippleTimer / 0.45)
            drawKeyTapRipple(in: ctx, center: tpt, progress: p)
            drawTailTapSparkleArc(in: ctx, center: tpt, progress: p)
        }
        drawSplashDroplets(in: ctx, droplets: swim.droplets)

        // A. Front-facing elongated translucent typing/mouse fins (gracefully retract as fish lifts up to swim!)
        let finAlpha = max(0, min(1, 1.0 - sb * 1.85))
        if finAlpha > 0.02 {
            let finCol = CatCoatCompiler.swiftUIColor(dna.finHex)
            let bodyCol = CatCoatCompiler.swiftUIColor(dna.primaryBodyHex)
            let spotOuterCol = CatCoatCompiler.swiftUIColor(dna.spotOuterHex)
            let contourCol = blendColor(spotOuterCol, NSColor(srgbRed: 0.16, green: 0.11, blue: 0.10, alpha: 1.0), t: 0.46)
            let plump = CGFloat(dna.plumpness)

            let frenzySwell: CGFloat = (puff < 0.28 && dna.canPuffUp) ? max(0, swim.typingFrenzy.value - 0.56) * 14.0 : 0.0
            let bodyHalfW = (46.0 + puff * 14.0 + frenzySwell) * min(1.12, plump)
            let leftShoulder = CGPoint(x: pos.x - bodyHalfW + 5.0, y: pos.y + 11.0)
            let rightShoulder = CGPoint(x: pos.x + bodyHalfW - 5.0, y: pos.y + 11.0)

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

            ctx.saveGState()
            if finAlpha < 0.99 { ctx.setAlpha(finAlpha) }
            drawElongatedPectoralFin(in: ctx, shoulder: leftShoulder, tip: leftTarget, isLeft: true, isReaching: leftActive, finScale: CGFloat(dna.finLength), finCol: finCol, bodyCol: bodyCol, contourCol: contourCol, whiteOutline: whiteOutline)
            drawElongatedPectoralFin(in: ctx, shoulder: rightShoulder, tip: rightTarget, isLeft: false, isReaching: rightActive, finScale: CGFloat(dna.finLength), finCol: finCol, bodyCol: bodyCol, contourCol: contourCol, whiteOutline: whiteOutline)
            ctx.restoreGState()
        }

        // B. Full Side-Profile Free-Swimming Showcase Fish (`待机游动展示鱼形态 + 尾巴炫技轻拍键盘`)
        let sideAlpha = max(0, min(1, (sb - 0.18) / 0.52))
        if sideAlpha > 0.02 {
            ctx.saveGState()
            if sideAlpha < 0.99 { ctx.setAlpha(sideAlpha) }
            if whiteOutline {
                drawWithStickerOutline(in: ctx, bounds: CGRect(x: 10, y: 36, width: 340, height: 265)) { subCtx in
                    drawSideShowcaseFish(in: subCtx, physics: physics, dna: dna, pos: pos)
                }
            } else {
                drawSideShowcaseFish(in: ctx, physics: physics, dna: dna, pos: pos)
            }
            ctx.restoreGState()
        }

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

        // Cute symmetrical rosy puffer cheek blushes (warmer when getting annoyed/pouting, rosy-cute when puffed!)
        let frenzy = max(0, min(1, swim.typingFrenzy.value))
        let angerGate = max(0, min(1, 1.0 - puff * 3.0))
        let reluctance = max(0, min(1, (frenzy - 0.56) / 0.28)) * angerGate
        let blushA: CGFloat = 0.28 + puff * 0.28 + reluctance * 0.30 + physics.petHeadIntensity * 0.22
        ctx.setFillColor(NSColor(srgbRed: 0.96, green: 0.40, blue: 0.42, alpha: min(0.75, blushA)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -36 - puff * 6, y: -13, width: 13 + puff * 2, height: 8.5 + puff * 1.5))
        ctx.fillEllipse(in: CGRect(x: 23 + puff * 4, y: -13, width: 13 + puff * 2, height: 8.5 + puff * 1.5))

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
        // Emotion arc: Happy -> Serious upper lids -> Reluctant V-brows -> POOF wide-eyed innocent derpy balloon (`O_o`)!
        let eyeOffsetX: CGFloat = 31.0 * min(1.10, plump) + puff * 8.0
        let eyeY: CGFloat = -28.0 * min(1.10, plump) - puff * 8.0
        let eyeR: CGFloat = 10.6 + puff * 2.2
        drawFrontFishEye(in: ctx, center: CGPoint(x: -eyeOffsetX, y: eyeY), radius: eyeR, isLeft: true, irisCol: irisCol, bodyCol: bodyCol, contourCol: contourCol, gaze: physics.eyeGaze.point, blink: physics.effectiveEyeClosure, puff: puff, frenzy: frenzy)
        drawFrontFishEye(in: ctx, center: CGPoint(x: eyeOffsetX, y: eyeY), radius: eyeR, isLeft: false, irisCol: irisCol, bodyCol: bodyCol, contourCol: contourCol, gaze: physics.eyeGaze.point, blink: physics.effectiveEyeClosure, puff: puff, frenzy: frenzy)

        // Cute anime red cross-vein `💢` when getting seriously reluctant right before puffing (vanishes immediately upon puffing into derpy ball!)
        if reluctance > 0.25 {
            drawReluctantAngerMark(in: ctx, center: CGPoint(x: -14, y: -44 * min(1.12, plump)), alpha: min(1.0, (reluctance - 0.25) / 0.55))
        }

        // 6. Front-Center Mouth: Happy buck-tooth smile -> Serious straight -> Reluctant frown -> Derpy tiny `•o•` when puffed!
        drawFrontFishMouth(
            in: ctx,
            dna: dna,
            puff: puff,
            frenzy: frenzy,
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

    // MARK: - Front-Facing Protruding 3D Eyes & Emotional Arc (Happy -> Serious -> Reluctant 💢 -> Derpy Puff `O_o`)

    private static func drawFrontFishEye(
        in ctx: CGContext,
        center: CGPoint,
        radius: CGFloat,
        isLeft: Bool,
        irisCol: NSColor,
        bodyCol: NSColor,
        contourCol: NSColor,
        gaze: CGPoint,
        blink: CGFloat,
        puff: CGFloat,
        frenzy: CGFloat
    ) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)

        // Anger/seriousness vanishes the instant the puffer pops into a wide-eyed derpy spiky balloon!
        let angerGate = max(0, min(1, 1.0 - puff * 3.0))
        let seriousness = max(0, min(1, (frenzy - 0.28) / 0.30)) * angerGate
        let reluctance = max(0, min(1, (frenzy - 0.56) / 0.28)) * angerGate

        // Protruding fleshy puffer eye socket turret
        let turretR = radius * 1.24
        ctx.setFillColor(blendColor(bodyCol, NSColor.white, t: 0.14).cgColor)
        ctx.fillEllipse(in: CGRect(x: -turretR, y: -turretR * 0.94, width: turretR * 2, height: turretR * 1.88))
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.68).cgColor)
        ctx.setLineWidth(1.45)
        ctx.strokeEllipse(in: CGRect(x: -turretR, y: -turretR * 0.94, width: turretR * 2, height: turretR * 1.88))

        if blink > 0.72 && puff < 0.25 && seriousness < 0.25 {
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

        // When puffed into derpy spiky ball (`puff > 0.35`): pupils look slightly wide & innocently bewildered (`O_o`)!
        let derpyOut: CGFloat = puff > 0.30 ? (isLeft ? -0.10 : 0.10) * puff : 0.0
        let gx = (max(-1, min(1, gaze.x)) * (1.0 - puff * 0.65) + derpyOut) * radius * 0.28
        let gy = (max(-1, min(1, gaze.y)) * (1.0 - puff * 0.65)) * radius * 0.25
        let pupilR = radius * (puff > 0.25 ? (0.44 - puff * 0.14) : (0.52 - seriousness * 0.06))
        ctx.setFillColor(NSColor(srgbRed: 0.09, green: 0.07, blue: 0.09, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: gx - pupilR, y: gy - pupilR, width: pupilR * 2, height: pupilR * 2))

        // Crisp glossy wet catchlights (extra sparkling bright when derpy-puffed!)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.96).cgColor)
        let hlR = radius * (0.27 + puff * 0.04)
        ctx.fillEllipse(in: CGRect(x: -radius * 0.42, y: -radius * 0.48, width: hlR * 2, height: hlR * 1.8))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.74).cgColor)
        ctx.fillEllipse(in: CGRect(x: radius * 0.18, y: radius * 0.18, width: hlR * 0.92, height: hlR * 0.92))

        // Progressive Serious -> Reluctant/Grumpy slanted upper eyelid (`严肃 -> 不情愿`)!
        if seriousness > 0.04 {
            let lidDrop = radius * (0.30 * seriousness + 0.22 * reluctance)
            let slant = radius * (0.16 * seriousness + 0.30 * reluctance) * (isLeft ? 1.0 : -1.0)
            let lidPath = CGMutablePath()
            lidPath.move(to: CGPoint(x: -radius - 3, y: -radius - 3))
            lidPath.addLine(to: CGPoint(x: radius + 3, y: -radius - 3))
            lidPath.addLine(to: CGPoint(x: radius + 3, y: -radius + lidDrop + slant))
            lidPath.addLine(to: CGPoint(x: -radius - 3, y: -radius + lidDrop - slant))
            lidPath.closeSubpath()

            ctx.setFillColor(blendColor(bodyCol, NSColor(srgbRed: 0.85, green: 0.72, blue: 0.56, alpha: 1.0), t: 0.35).cgColor)
            ctx.addPath(lidPath)
            ctx.fillPath()

            // Crisp dark eyelid crease emphasizing serious/reluctant stare
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.88).cgColor)
            ctx.setLineWidth(1.65)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: -radius - 1, y: -radius + lidDrop - slant))
            ctx.addLine(to: CGPoint(x: radius + 1, y: -radius + lidDrop + slant))
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.setStrokeColor(contourCol.withAlphaComponent(0.90).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: irisRect)

        // Expressive furrowed brow line perched right over the turret during Stage 1-2 (`严肃 -> 很不情愿`)
        if seriousness > 0.18 {
            let browA = min(1.0, (seriousness - 0.15) * 1.15)
            let innerDip = 3.2 * seriousness + 4.8 * reluctance
            let outerLift = 1.5 * reluctance
            let sign: CGFloat = isLeft ? 1.0 : -1.0 // +x is toward center for left eye
            let brow = CGMutablePath()
            brow.move(to: CGPoint(x: -sign * radius * 0.85, y: -turretR - 2.0 - outerLift))
            brow.addQuadCurve(
                to: CGPoint(x: sign * radius * 0.82, y: -turretR + innerDip),
                control: CGPoint(x: 0, y: -turretR + innerDip * 0.35 - 1.5)
            )
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.86 * browA).cgColor)
            ctx.setLineWidth(2.0 + reluctance * 0.5)
            ctx.setLineCap(.round)
            ctx.addPath(brow)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    private static func drawReluctantAngerMark(in ctx: CGContext, center: CGPoint, alpha: CGFloat) {
        let a = max(0, min(1, alpha))
        guard a > 0.05 else { return }
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.setStrokeColor(NSColor(srgbRed: 0.90, green: 0.22, blue: 0.22, alpha: 0.92 * a).cgColor)
        ctx.setLineWidth(1.9)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        // Classic crisp 4-quadrant anime cross-vein `💢`
        let r: CGFloat = 5.2
        let gap: CGFloat = 1.6
        for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] as [(CGFloat, CGFloat)] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: sx * r, y: sy * gap))
            p.addQuadCurve(to: CGPoint(x: sx * gap, y: sy * r), control: CGPoint(x: sx * gap * 0.9, y: sy * gap * 0.9))
            ctx.addPath(p)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private static func drawFrontFishMouth(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        puff: CGFloat,
        frenzy: CGFloat,
        mouthOpen: CGFloat,
        bellyCol: NSColor,
        contourCol: NSColor
    ) {
        let my: CGFloat = -11.0 - puff * 2.0
        let lipCol = blendColor(bellyCol, NSColor(srgbRed: 0.97, green: 0.82, blue: 0.76, alpha: 1.0), t: 0.48)

        ctx.saveGState()
        ctx.translateBy(x: 0, y: my)

        // Stage 3 Climax (`puff > 0.30`): Instant flip into adorably stunned, innocent derpy `"•o•"` puffer mouth!
        if puff > 0.30 {
            let r = 5.4 + puff * 1.5
            ctx.setFillColor(lipCol.cgColor)
            ctx.fillEllipse(in: CGRect(x: -r, y: -r * 0.92, width: r * 2, height: r * 1.84))
            ctx.setFillColor(NSColor(srgbRed: 0.50, green: 0.20, blue: 0.23, alpha: 0.92).cgColor)
            ctx.fillEllipse(in: CGRect(x: -r * 0.54, y: -r * 0.48, width: r * 1.08, height: r * 0.96))
            // Tiny pink tongue dot inside the bewildered "o"
            ctx.setFillColor(NSColor(srgbRed: 0.92, green: 0.48, blue: 0.50, alpha: 0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: -r * 0.30, y: r * 0.05, width: r * 0.60, height: r * 0.38))
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.80).cgColor)
            ctx.setLineWidth(1.35)
            ctx.strokeEllipse(in: CGRect(x: -r, y: -r * 0.92, width: r * 2, height: r * 1.84))
            ctx.restoreGState()
            return
        }

        // Stage 1 -> Stage 2 (`严肃 -> 很不情愿瘪嘴`): Smooth progression from straight serious line to grumpy pouting frown (`︵`)!
        if frenzy > 0.32 {
            let seriousness = max(0, min(1, (frenzy - 0.32) / 0.26))
            let reluctance = max(0, min(1, (frenzy - 0.56) / 0.28))
            let w: CGFloat = 9.5 + reluctance * 2.2
            let archLift: CGFloat = -reluctance * 5.2 // curves mouth center UP and corners DOWN into an unmistakable reluctant pout `︵`!
            let cornerDrop: CGFloat = reluctance * 3.0

            let lipCurve = CGMutablePath()
            lipCurve.move(to: CGPoint(x: -w, y: cornerDrop))
            lipCurve.addQuadCurve(to: CGPoint(x: w, y: cornerDrop), control: CGPoint(x: 0, y: archLift))

            // Soft plump coral lip cushion behind the pout
            ctx.setStrokeColor(lipCol.cgColor)
            ctx.setLineWidth(5.4)
            ctx.setLineCap(.round)
            ctx.addPath(lipCurve)
            ctx.strokePath()

            // Crisp grumpy/serious mouth line
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.86).cgColor)
            ctx.setLineWidth(1.65 + seriousness * 0.25)
            ctx.setLineCap(.round)
            ctx.addPath(lipCurve)
            ctx.strokePath()

            // Tiny pinched lower pout crease when really reluctant
            if reluctance > 0.25 {
                let chin = CGMutablePath()
                chin.move(to: CGPoint(x: -4.2, y: cornerDrop + 2.8))
                chin.addQuadCurve(to: CGPoint(x: 4.2, y: cornerDrop + 2.8), control: CGPoint(x: 0, y: cornerDrop + 1.4))
                ctx.setStrokeColor(contourCol.withAlphaComponent(0.45 * reluctance).cgColor)
                ctx.setLineWidth(1.1)
                ctx.addPath(chin)
                ctx.strokePath()
            }
            ctx.restoreGState()
            return
        }

        // Stage 0 (Calm & Happy): Friendly, goofy front-facing puffer smile (`◡`) with two cute rounded ivory buck teeth!
        let openH = 4.6 + mouthOpen * 3.4
        let smileW: CGFloat = 10.5

        let cavity = CGMutablePath()
        cavity.move(to: CGPoint(x: -smileW, y: -1.6))
        cavity.addQuadCurve(to: CGPoint(x: smileW, y: -1.6), control: CGPoint(x: 0, y: -3.2))
        cavity.addQuadCurve(to: CGPoint(x: -smileW, y: -1.6), control: CGPoint(x: 0, y: openH + 5.2))
        cavity.closeSubpath()

        ctx.setFillColor(NSColor(srgbRed: 0.56, green: 0.22, blue: 0.26, alpha: 0.90).cgColor)
        ctx.addPath(cavity); ctx.fillPath()

        ctx.saveGState()
        ctx.addPath(cavity); ctx.clip()
        ctx.setFillColor(NSColor(srgbRed: 0.90, green: 0.45, blue: 0.48, alpha: 0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: -5.5, y: openH - 0.8, width: 11.0, height: 6.5))

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

        let lowerArc = CGMutablePath()
        lowerArc.move(to: CGPoint(x: -smileW * 0.62, y: openH + 3.0))
        lowerArc.addQuadCurve(to: CGPoint(x: smileW * 0.62, y: openH + 3.0), control: CGPoint(x: 0, y: openH + 5.6))
        ctx.setStrokeColor(lipCol.withAlphaComponent(0.90).cgColor)
        ctx.setLineWidth(2.4)
        ctx.addPath(lowerArc); ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - True Volumetric 3D Multi-Angle Swimming Fish (`真实体积感 3D 游动转身 + 尾鳍滞后甩弯`, ZERO Paper-Flip!)

    private static func drawSideShowcaseFish(
        in ctx: CGContext,
        physics: CatPhysics,
        dna: FishPhotoDNA,
        pos: CGPoint
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
        let ps = min(1.16, max(0.88, plump))
        let finScale = CGFloat(dna.finLength)

        // True continuous 3D yaw angles (`0` = front-facing plump 3D head-on, `+π/2` = right, `-π/2` = left)
        let yaw = max(-.pi * 0.5, min(.pi * 0.5, swim.bodyYaw.value))
        let tYaw = max(-.pi * 0.5, min(.pi * 0.5, swim.tailYaw.value))
        let s = sin(yaw)          // -1 (left) .. 0 (front) .. +1 (right)
        let c = max(0, cos(yaw))  //  0 (side) .. +1 (front)
        let sideAmt = abs(s)      //  0 (full plump front) .. 1 (full side profile)
        let dirSign: CGFloat = s >= 0 ? 1.0 : -1.0

        let ts = sin(tYaw)
        let tc = max(0, cos(tYaw))
        let tailSideAmt = abs(ts)
        let tapFlex = max(0, min(1, swim.tailTapFlex.value))
        let tailWave = sin(swim.swimPhase) * (8.0 * (1.0 - tapFlex * 0.7))

        // Subtle 3D closeness boost (+6%) when nose arcs toward the front glass mid-turn!
        let depthZoom: CGFloat = 1.0 + 0.06 * c
        // Pitch only applies proportionally to side orientation (keeps fish upright & calm when facing viewer mid-turn!)
        let worldPitch = swim.swimPitch.value * s

        ctx.saveGState()
        ctx.translateBy(x: pos.x, y: pos.y)
        ctx.scaleBy(x: depthZoom, y: depthZoom)
        ctx.rotate(by: worldPitch)

        // =========================================================================
        // LAYER 1 (BEHIND TORSO): Lagging Tail Peduncle & Broom-Fan Tail, Rounded Dorsal/Anal Fins, Far Eye & Far Pectoral Fin
        // =========================================================================

        // Convex blend `blend ∈ [0, 1]` (0 = chubby front puffer, 1 = full side profile) — ALWAYS sums to 1.0 (never `sin+cos = 1.414`!)
        let blend = sideAmt * sideAmt * (3.0 - 2.0 * sideAmt)
        let crownY: CGFloat = -(33.0 * (1.0 - blend) + 27.0 * blend) * ps
        let bellyY: CGFloat = +(33.0 * (1.0 - blend) + 27.0 * blend) * ps

        // 1A. Volumetric Broom-Fan Caudal Tail + Curved Peduncle
        // Coupled `bodyYaw` + lagging `tailYaw`: at `±90°` equals `-54` (exact tail-tap contact!), and during `-42°/-14°` mid-turn still curves visibly past the rear hip!
        let droopY: CGFloat = tapFlex * 46.0
        let tailTurnDrop: CGFloat = tc * 6.0
        let pedEndX: CGFloat = (-26.0 * s - 28.0 * ts) * (1.0 - tapFlex * 0.07)
        let pedEnd = CGPoint(
            x: pedEndX,
            y: droopY * 0.38 + tailTurnDrop + tailWave * 0.28 * max(sideAmt, tailSideAmt)
        )
        let fanLen: CGFloat = (dna.bodyProfile == .bettaFlow ? 50.0 : 40.0) * finScale
        let fanSpread: CGFloat = (dna.bodyProfile == .bettaFlow ? 34.0 : 25.0) * finScale
        let tailCombined = (-26.0 * s - 28.0 * ts) / 54.0 // -1..+1 directional vector of tail swing
        let tailVisStrength = abs(tailCombined)
        let tailOutSign: CGFloat = tailCombined >= 0 ? 1.0 : -1.0 // +1 = tail extends RIGHT, -1 = tail extends LEFT
        let effectiveFanLen = fanLen * (1.0 - tapFlex * 0.14) * (0.55 + 0.45 * tailVisStrength)
        let tailTip = CGPoint(
            x: pedEnd.x + tailOutSign * effectiveFanLen,
            y: droopY + tailTurnDrop * 0.4 + tailWave * (0.45 + 0.55 * tailVisStrength)
        )

        if tailVisStrength > 0.14 {
            let fanVisSpread = fanSpread * (0.64 + 0.36 * tailVisStrength)
            let fan = CGMutablePath()
            fan.move(to: CGPoint(x: pedEnd.x - tailOutSign * 4, y: pedEnd.y - 8))
            fan.addQuadCurve(
                to: CGPoint(x: tailTip.x - tailOutSign * 3, y: tailTip.y - fanVisSpread * 0.72),
                control: CGPoint(x: (pedEnd.x + tailTip.x) * 0.5, y: (pedEnd.y + tailTip.y) * 0.5 - fanVisSpread * 0.58)
            )
            fan.addCurve(
                to: CGPoint(x: tailTip.x + tailOutSign * 2, y: tailTip.y + fanVisSpread * 0.78),
                control1: CGPoint(x: tailTip.x + tailOutSign * 6, y: tailTip.y - fanVisSpread * 0.24),
                control2: CGPoint(x: tailTip.x + tailOutSign * 8, y: tailTip.y + fanVisSpread * 0.28)
            )
            fan.addQuadCurve(
                to: CGPoint(x: pedEnd.x - tailOutSign * 4, y: pedEnd.y + 9),
                control: CGPoint(x: (pedEnd.x + tailTip.x) * 0.5, y: (pedEnd.y + tailTip.y) * 0.5 + fanVisSpread * 0.58)
            )
            fan.closeSubpath()

            ctx.saveGState()
            ctx.addPath(fan); ctx.clip()
            if let grad = makeLinearGradient([
                (0.0, finCol.withAlphaComponent(0.95)),
                (0.60, blendColor(finCol, dorsalCol, t: 0.20).withAlphaComponent(0.84)),
                (1.0, NSColor(srgbRed: 0.99, green: 0.96, blue: 0.88, alpha: 0.65))
            ]) {
                ctx.drawLinearGradient(grad, start: pedEnd, end: tailTip, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.42).cgColor)
            ctx.setLineWidth(1.15)
            ctx.setLineCap(.round)
            for i in -3...4 {
                let f = (CGFloat(i) - 0.5) / 3.5
                let sy = pedEnd.y + f * 6.5
                let ey = tailTip.y + f * (fanVisSpread * 0.68)
                let ex = tailTip.x - tailOutSign * abs(f) * 3.0
                ctx.beginPath()
                ctx.move(to: CGPoint(x: pedEnd.x - tailOutSign * 2, y: sy))
                ctx.addQuadCurve(to: CGPoint(x: ex, y: ey), control: CGPoint(x: (pedEnd.x + ex) * 0.5, y: (sy + ey) * 0.5 + droopY * 0.08))
                ctx.strokePath()
            }
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.76).cgColor)
            ctx.setLineWidth(1.55)
            ctx.setLineJoin(.round)
            ctx.addPath(fan); ctx.strokePath()
            ctx.restoreGState()

            // Curved muscular tail peduncle seamlessly bridging rear hip -> broom-fan tail ONLY during front/3/4 turns (`blend < 0.72`),
            // stroking ONLY top/bottom edges so there is ZERO vertical seam line where it meets the torso!
            if blend < 0.72 {
                let hipAnchor = CGPoint(x: tailOutSign * 14.0, y: 4.0)
                let ped = CGMutablePath()
                ped.move(to: CGPoint(x: hipAnchor.x, y: hipAnchor.y - 13))
                ped.addQuadCurve(to: CGPoint(x: pedEnd.x, y: pedEnd.y - 8.5), control: CGPoint(x: (hipAnchor.x + pedEnd.x) * 0.5, y: hipAnchor.y - 11))
                ped.addLine(to: CGPoint(x: pedEnd.x, y: pedEnd.y + 8.5))
                ped.addQuadCurve(to: CGPoint(x: hipAnchor.x, y: hipAnchor.y + 13), control: CGPoint(x: (hipAnchor.x + pedEnd.x) * 0.5, y: hipAnchor.y + 12))
                ped.closeSubpath()

                ctx.saveGState()
                ctx.setFillColor(bodyCol.cgColor)
                ctx.addPath(ped); ctx.fillPath()
                if dna.spotPattern == .ringedOcelli {
                    ctx.saveGState()
                    ctx.addPath(ped); ctx.clip()
                    let midPt = CGPoint(x: (hipAnchor.x + pedEnd.x) * 0.58, y: (hipAnchor.y + pedEnd.y) * 0.58)
                    ctx.setFillColor(spotOuterCol.withAlphaComponent(0.90).cgColor)
                    ctx.fillEllipse(in: CGRect(x: midPt.x - 5.2, y: midPt.y - 4.6, width: 10.4, height: 9.2))
                    ctx.setFillColor(spotInnerCol.cgColor)
                    ctx.fillEllipse(in: CGRect(x: midPt.x - 3.0, y: midPt.y - 2.6, width: 6.0, height: 5.2))
                    ctx.restoreGState()
                }
                ctx.setStrokeColor(contourCol.withAlphaComponent(0.84).cgColor)
                ctx.setLineWidth(1.65)
                ctx.setLineCap(.round)
                // Stroke top & bottom peduncle edges ONLY (open root behind torso -> zero seam!)
                ctx.beginPath()
                ctx.move(to: CGPoint(x: hipAnchor.x, y: hipAnchor.y - 13))
                ctx.addQuadCurve(to: CGPoint(x: pedEnd.x, y: pedEnd.y - 8.5), control: CGPoint(x: (hipAnchor.x + pedEnd.x) * 0.5, y: hipAnchor.y - 11))
                ctx.move(to: CGPoint(x: hipAnchor.x, y: hipAnchor.y + 13))
                ctx.addQuadCurve(to: CGPoint(x: pedEnd.x, y: pedEnd.y + 8.5), control: CGPoint(x: (hipAnchor.x + pedEnd.x) * 0.5, y: hipAnchor.y + 12))
                ctx.strokePath()
                ctx.restoreGState()
            }
        }

        // 1B. Soft Rounded-Fan Dorsal Fin STRICTLY Anchored 9px INSIDE the Body Roof (`crownY + 9`) — NEVER floats or squishes!
        let dorsalCenterX: CGFloat = -20.0 * s
        let dorsalRootY: CGFloat = crownY + 9.0 + 4.0 * blend
        let dorsalHeight: CGFloat = (19.0 * (1.0 - blend) + 23.0 * blend) * finScale
        let dorsalHalfW: CGFloat = 10.0
        drawRoundedAquaFin(
            in: ctx,
            centerRoot: CGPoint(x: dorsalCenterX, y: dorsalRootY),
            halfRootWidth: dorsalHalfW,
            height: dorsalHeight,
            tiltX: -7.5 * s - tailWave * 0.30 * blend,
            isTop: true,
            finCol: finCol,
            contourCol: contourCol
        )

        // 1C. Soft Rounded-Fan Ventral Anal Fin Anchored 9px INSIDE Belly Contour (fades in cleanly for side cruising only!)
        if blend > 0.45 {
            let analA = min(1.0, (blend - 0.45) / 0.35)
            ctx.saveGState()
            ctx.setAlpha(analA)
            drawRoundedAquaFin(
                in: ctx,
                centerRoot: CGPoint(x: -22.0 * s, y: bellyY - 9.0 - 4.0 * blend),
                halfRootWidth: 9.0,
                height: 20.0 * finScale,
                tiltX: -7.0 * s - tailWave * 0.22 * dirSign,
                isTop: false,
                finCol: finCol,
                contourCol: contourCol
            )
            ctx.restoreGState()
        }

        // 1D. Compute 3D Spherical Coordinates for BOTH Eyes (`φ = ±0.64 rad`) and BOTH Pectoral Fins (`φ = ±1.18 rad`)
        let eyeAzimuth: CGFloat = 0.64
        let leftEyeAng = yaw - eyeAzimuth
        let rightEyeAng = yaw + eyeAzimuth
        let eyeRadiusX: CGFloat = 45.0 * (0.94 + 0.06 * sideAmt)
        let eyeBaseY: CGFloat = -(11.5 * blend + 13.0 * (1.0 - blend)) * ps

        let eyes3D: [(isLeft: Bool, x: CGFloat, y: CGFloat, z: CGFloat)] = [
            (true,  eyeRadiusX * sin(leftEyeAng),  eyeBaseY, cos(leftEyeAng)),
            (false, eyeRadiusX * sin(rightEyeAng), eyeBaseY, cos(rightEyeAng))
        ]

        // Draw any FAR-SIDE eye (`z <= 0.08`) BEHIND the snout silhouette — WITH a subtle amber-red iris/pupil sliver so it reads as a real eye!
        for e in eyes3D where e.z <= 0.08 {
            let outSign: CGFloat = e.x >= 0 ? 1.0 : -1.0
            let farX = e.x + outSign * 4.5 * (1.0 - max(0, e.z + 0.5))
            let farY = e.y - 3.5 * blend
            let r: CGFloat = 7.2
            ctx.saveGState()
            ctx.setFillColor(blendColor(bodyCol, NSColor.white, t: 0.10).cgColor)
            ctx.fillEllipse(in: CGRect(x: farX - r, y: farY - r * 0.94, width: r * 2, height: r * 1.88))
            // Subtle protruding iris + pupil peeking on the outer edge of the far eye socket!
            ctx.setFillColor(irisCol.withAlphaComponent(0.92).cgColor)
            ctx.fillEllipse(in: CGRect(x: farX + outSign * 1.2 - 4.4, y: farY - 4.4, width: 8.8, height: 8.8))
            ctx.setFillColor(NSColor(srgbRed: 0.10, green: 0.08, blue: 0.10, alpha: 0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: farX + outSign * 2.2 - 2.2, y: farY - 2.2, width: 4.4, height: 4.4))
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.88).cgColor)
            ctx.fillEllipse(in: CGRect(x: farX + outSign * 1.0 - 1.2, y: farY - 3.2, width: 2.4, height: 2.2))
            ctx.setStrokeColor(contourCol.withAlphaComponent(0.75).cgColor)
            ctx.setLineWidth(1.35)
            ctx.strokeEllipse(in: CGRect(x: farX - r, y: farY - r * 0.94, width: r * 2, height: r * 1.88))
            ctx.restoreGState()
        }

        let pecAzimuth: CGFloat = 1.18
        let pecs3D: [(side: CGFloat, x: CGFloat, z: CGFloat)] = [
            (-1.0, 44.0 * sin(yaw - pecAzimuth), cos(yaw - pecAzimuth)),
            ( 1.0, 44.0 * sin(yaw + pecAzimuth), cos(yaw + pecAzimuth))
        ]
        let pecFlutter = sin(swim.finPhase * 2.2) * 0.28
        for pf in pecs3D where pf.z <= 0.05 {
            drawVolumetricPectoralFin(
                in: ctx,
                origin: CGPoint(x: pf.x, y: 5.5),
                sweepDir: pf.side * c - s * (1.0 - c * 0.5),
                flutter: pecFlutter * pf.side,
                finScale: finScale * 0.85,
                finCol: finCol,
                contourCol: contourCol
            )
        }

        // =========================================================================
        // LAYER 2: VOLUMETRIC PLUMP 3D TORSO (Smooth Rounded Cheek at EVERY Angle — ZERO Blunt Chop-Off!)
        // =========================================================================
        let body = makeVolumetricSwimBodyPath(s: s, c: c, ps: ps, pedEndY: pedEnd.y, droopY: droopY)

        ctx.saveGState()
        ctx.addPath(body); ctx.clip()

        let topShade = blendColor(bodyCol, dorsalCol, t: 0.26)
        if let grad = makeLinearGradient([
            (0.00, topShade),
            (0.32, bodyCol),
            (0.68, blendColor(bodyCol, bellyCol, t: 0.62)),
            (1.00, bellyCol)
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: -35 * ps), end: CGPoint(x: 0, y: 35 * ps), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Subtle 3D cylindrical rim shading so the fish visibly reads as a round plump sphere/torpedo while turning!
        if (1.0 - blend) > 0.10 {
            let rimA = 0.26 * (1.0 - blend)
            if let sideGrad = makeLinearGradient([
                (0.00, topShade.withAlphaComponent(rimA)),
                (0.24, NSColor.clear),
                (0.76, NSColor.clear),
                (1.00, topShade.withAlphaComponent(rimA))
            ]) {
                ctx.drawLinearGradient(sideGrad, start: CGPoint(x: -50, y: 0), end: CGPoint(x: 50, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        }

        // =========================================================================
        // LAYER 3: 3D CYLINDRICAL SKIN MARKINGS (Evenly Spaced Crimson Ocelli Wrapping Curved Cheeks & Flanks!)
        // =========================================================================
        drawVolumetricFlankMarkings(
            in: ctx,
            dna: dna,
            yaw: yaw,
            s: s,
            c: c,
            ps: ps,
            droopY: droopY,
            dorsalCol: dorsalCol,
            spotOuterCol: spotOuterCol,
            spotInnerCol: spotInnerCol,
            bellyCol: bellyCol
        )

        // Glossy wet aquatic forehead/back highlight
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.24).cgColor)
        ctx.fillEllipse(in: CGRect(x: -17 - 6 * s, y: crownY + 5.0, width: 34, height: 8))

        // Cute 3D cheek blushes tracking the cheek azimuths (`φ = ±0.56`)
        for blushAz in [-0.56, 0.56] as [CGFloat] {
            let a = yaw + blushAz
            let bz = cos(a)
            if bz > 0.05 {
                let bx = 44.0 * sin(a)
                let bw = 11.5 * (0.45 + 0.55 * bz)
                ctx.setFillColor(NSColor(srgbRed: 0.95, green: 0.44, blue: 0.44, alpha: 0.30 * min(1, bz * 1.4)).cgColor)
                ctx.fillEllipse(in: CGRect(x: bx - bw * 0.5, y: 0.5 + 1.5 * (1.0 - blend), width: bw, height: 7.5))
            }
        }

        ctx.restoreGState() // end torso clip

        // Crisp KuroCat-style outer contour
        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.86).cgColor)
        ctx.setLineWidth(1.85)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(body); ctx.strokePath()
        ctx.restoreGState()

        // =========================================================================
        // LAYER 4 (IN FRONT OF TORSO): Near-Side Eyes (`z > 0.08`), 3D Perspective Mouth + Buck Teeth, Near Pectoral Fin(s)
        // =========================================================================

        drawVolumetricSwimMouth(
            in: ctx,
            dna: dna,
            s: s,
            c: c,
            bellyCol: bellyCol,
            contourCol: contourCol
        )

        let visibleEyes = eyes3D.filter { $0.z > 0.08 }.sorted { $0.z < $1.z }
        for e in visibleEyes {
            let eyeScaleX = 0.72 + 0.28 * e.z
            let eyeR: CGFloat = 9.8 * (0.90 + 0.12 * e.z)
            ctx.saveGState()
            ctx.translateBy(x: e.x, y: e.y)
            ctx.scaleBy(x: eyeScaleX, y: 1.0)
            drawFrontFishEye(
                in: ctx,
                center: .zero,
                radius: eyeR,
                isLeft: e.isLeft,
                irisCol: irisCol,
                bodyCol: bodyCol,
                contourCol: contourCol,
                gaze: CGPoint(x: 0.32 * s, y: tapFlex * 0.45),
                blink: physics.effectiveEyeClosure,
                puff: 0,
                frenzy: 0
            )
            ctx.restoreGState()
        }

        for pf in pecs3D where pf.z > 0.05 {
            let sweep = pf.side * c - s * (1.0 - c * 0.45)
            drawVolumetricPectoralFin(
                in: ctx,
                origin: CGPoint(x: pf.x, y: 4.5 + 3.0 * (1.0 - blend)),
                sweepDir: sweep,
                flutter: pecFlutter * pf.side,
                finScale: finScale * (0.78 + 0.22 * pf.z),
                finCol: finCol,
                contourCol: contourCol
            )
        }

        ctx.restoreGState()
    }

    /// Soft plump rounded translucent aqua fin (used for dorsal & anal fins across ALL 3D yaw angles — NEVER needle-thin or detached!).
    private static func drawRoundedAquaFin(
        in ctx: CGContext,
        centerRoot: CGPoint,
        halfRootWidth: CGFloat,
        height: CGFloat,
        tiltX: CGFloat,
        isTop: Bool,
        finCol: NSColor,
        contourCol: NSColor
    ) {
        let vy: CGFloat = isTop ? -1.0 : 1.0
        let rootL = CGPoint(x: centerRoot.x - halfRootWidth, y: centerRoot.y)
        let rootR = CGPoint(x: centerRoot.x + halfRootWidth, y: centerRoot.y)
        let peak = CGPoint(x: centerRoot.x + tiltX, y: centerRoot.y + vy * height)
        let fanHalfSpread = halfRootWidth * 1.25

        let p = CGMutablePath()
        p.move(to: rootL)
        p.addCurve(
            to: CGPoint(x: peak.x - fanHalfSpread * 0.45, y: peak.y + vy * 2.0),
            control1: CGPoint(x: rootL.x - 4.0 + tiltX * 0.35, y: centerRoot.y + vy * height * 0.55),
            control2: CGPoint(x: peak.x - fanHalfSpread * 0.95, y: peak.y + vy * 4.0)
        )
        p.addQuadCurve(
            to: CGPoint(x: peak.x + fanHalfSpread * 0.55, y: peak.y + vy * 2.5),
            control: CGPoint(x: peak.x, y: peak.y - vy * 3.5)
        )
        p.addCurve(
            to: rootR,
            control1: CGPoint(x: peak.x + fanHalfSpread * 0.95, y: peak.y + vy * 5.0),
            control2: CGPoint(x: rootR.x + 3.0 + tiltX * 0.35, y: centerRoot.y + vy * height * 0.55)
        )
        p.closeSubpath()

        ctx.saveGState()
        ctx.addPath(p); ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.88)),
            (1.0, NSColor(srgbRed: 0.99, green: 0.96, blue: 0.89, alpha: 0.56))
        ]) {
            ctx.drawLinearGradient(grad, start: centerRoot, end: peak, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(0.95)
        ctx.setLineCap(.round)
        for f in [-0.6, -0.2, 0.2, 0.6] as [CGFloat] {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: centerRoot.x + f * halfRootWidth * 0.65, y: centerRoot.y))
            ctx.addQuadCurve(
                to: CGPoint(x: peak.x + f * fanHalfSpread * 0.72, y: peak.y + vy * 2.5),
                control: CGPoint(x: centerRoot.x + tiltX * 0.45 + f * halfRootWidth * 0.75, y: centerRoot.y + vy * height * 0.52)
            )
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.72).cgColor)
        ctx.setLineWidth(1.4)
        ctx.setLineJoin(.round)
        ctx.addPath(p); ctx.strokePath()
        ctx.restoreGState()
    }

    /// Continuous volumetric body contour across ANY 3D yaw (`s = sin(yaw)`, `c = cos(yaw)`):
    /// Smoothly morphs between a chubby 92px-wide front puffer (`blend = 0`) and a sleek 102px-long side-profile torpedo (`blend = 1`) —
    /// Rear edge uses a full rounded cubic cheek until `blend > 0.78` so there is NEVER a flat chopped-off stump!
    private static func makeVolumetricSwimBodyPath(s: CGFloat, c: CGFloat, ps: CGFloat, pedEndY: CGFloat, droopY: CGFloat) -> CGPath {
        let sideAmt = abs(s)
        let dirSign: CGFloat = s >= 0 ? 1.0 : -1.0
        let blend = sideAmt * sideAmt * (3.0 - 2.0 * sideAmt)
        // Only pinch the rear into a tail peduncle once near full side profile (`blend > 0.72`)!
        let pedBlend = max(0, min(1, (blend - 0.70) / 0.30))
        let pedSmooth = pedBlend * pedBlend * (3.0 - 2.0 * pedBlend)

        let headX: CGFloat = 45.0 * ps * (1.0 - blend) + 54.0 * blend
        let rearX: CGFloat = -45.0 * ps * (1.0 - pedSmooth) - (54.0 - droopY * 0.08) * pedSmooth
        let crownY: CGFloat = -(33.0 * (1.0 - blend) + 27.0 * blend) * ps
        let bellyY: CGFloat = +(33.0 * (1.0 - blend) + 27.0 * blend) * ps
        let snoutMidY: CGFloat = 2.0 * blend

        func pt(_ lx: CGFloat, _ ly: CGFloat) -> CGPoint {
            CGPoint(x: lx * dirSign, y: ly)
        }

        let p = CGMutablePath()
        p.move(to: pt(headX, snoutMidY))
        // Upper forehead arch -> crown
        p.addCurve(
            to: pt(24.0 * blend, crownY),
            control1: pt(headX, crownY * (0.64 - 0.08 * blend)),
            control2: pt(headX * (0.62 + 0.16 * blend), crownY)
        )

        if pedSmooth > 0.04 {
            // Sleek torpedo taper smoothly narrowing into the tail peduncle at side profile (`|yaw| > 64°`)
            let rearTopY = -12.0 * ps * (1.0 - pedSmooth) + (pedEndY - 8.5) * pedSmooth
            let rearBotY = +12.0 * ps * (1.0 - pedSmooth) + (pedEndY + 8.5) * pedSmooth
            p.addCurve(
                to: pt(rearX, rearTopY),
                control1: pt(-4.0 * blend, crownY * 1.03),
                control2: pt(rearX * 0.66, -16.0 + droopY * 0.22)
            )
            p.addQuadCurve(
                to: pt(rearX, rearBotY),
                control: pt(rearX - 7.0 * (1.0 - pedSmooth), (rearTopY + rearBotY) * 0.5)
            )
            p.addCurve(
                to: pt(22.0 * blend, bellyY),
                control1: pt(rearX * 0.66, 18.0 + droopY * 0.22),
                control2: pt(-6.0 * blend, bellyY * 1.08)
            )
        } else {
            // Smooth plump 3D rounded puffer cheek & rear hip across all front & 3/4 turn angles (`0° .. 64°`) — ZERO blunt vertical chop!
            p.addCurve(
                to: pt(rearX, 0),
                control1: pt(-24.0 * ps, crownY),
                control2: pt(rearX, crownY * 0.62)
            )
            p.addCurve(
                to: pt(22.0 * blend, bellyY),
                control1: pt(rearX, bellyY * 0.64),
                control2: pt(-24.0 * ps, bellyY)
            )
        }

        // Plump belly -> chin -> snout
        p.addCurve(
            to: pt(headX, snoutMidY),
            control1: pt(headX * (0.62 + 0.16 * blend), bellyY * (0.96 - 0.04 * blend)),
            control2: pt(headX, bellyY * (0.64 - 0.10 * blend))
        )
        p.closeSubpath()
        return p
    }

    /// Maps double-ringed crimson ocelli & dorsal mottling onto a real 3D rotating cylinder so spots wrap organically around the puffer as it turns!
    private static func drawVolumetricFlankMarkings(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        yaw: CGFloat,
        s: CGFloat,
        c: CGFloat,
        ps: CGFloat,
        droopY: CGFloat,
        dorsalCol: NSColor,
        spotOuterCol: NSColor,
        spotInnerCol: NSColor,
        bellyCol: NSColor
    ) {
        let sideAmt = abs(s)
        let dirSign: CGFloat = s >= 0 ? 1.0 : -1.0

        switch dna.spotPattern {
        case .ringedOcelli:
            // Warm russet crown mottling smoothly orbiting the forehead & upper back
            let warmDorsal = blendColor(dorsalCol, spotInnerCol, t: 0.34)
            let browAzimuths: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.0, -24.0 * ps, 13.0, 5.8),
                (-0.52, -21.5 * ps, 11.5, 5.2),
                ( 0.52, -21.5 * ps, 11.5, 5.2),
                (-1.12, -21.0 * ps, 12.0, 5.4),
                ( 1.12, -21.0 * ps, 12.0, 5.4)
            ]
            for (az, by, rx, ry) in browAzimuths {
                let a = yaw + az
                let z = cos(a)
                if z > -0.25 {
                    let bx = 45.0 * sin(a)
                    let sx = max(0.38, min(1.0, z + 0.35))
                    ctx.setFillColor(warmDorsal.withAlphaComponent(0.60).cgColor)
                    ctx.fillEllipse(in: CGRect(x: bx - rx * sx, y: by - ry, width: rx * sx * 2, height: ry * 2))
                }
            }

            // Evenly spaced 3D flank double-ringed crimson ocelli across cheeks & flanks (no clumping behind pectoral fin!)
            let singleSideSpots: [(az: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat)] = [
                (0.92, -6.5, 5.6, 5.0),
                (1.32, -10.5, 6.4, 5.8),
                (1.74, -5.5, 7.0, 6.2),
                (2.16, -8.5, 6.2, 5.5),
                (1.08,  9.5, 5.8, 5.2),
                (1.54,  8.0, 6.8, 6.0),
                (1.98,  9.5, 6.0, 5.4)
            ]
            for side in [-1.0, 1.0] as [CGFloat] {
                for sp in singleSideSpots {
                    let a = yaw + side * sp.az
                    let z = cos(a)
                    guard z > -0.05 else { continue }
                    let sx = 44.0 * sin(a)
                    let foreshorten = max(0.42, min(1.0, 0.30 + z * 0.72))
                    let rx = sp.rx * foreshorten
                    let ry = sp.ry
                    ctx.setFillColor(spotOuterCol.withAlphaComponent(0.92).cgColor)
                    ctx.fillEllipse(in: CGRect(x: sx - rx, y: sp.y - ry, width: rx * 2, height: ry * 2))
                    ctx.setFillColor(spotInnerCol.cgColor)
                    ctx.fillEllipse(in: CGRect(x: sx - rx * 0.58, y: sp.y - ry * 0.58, width: rx * 1.16, height: ry * 1.16))
                }
            }

            // Extra rear peduncle ocelli visible during side cruising & tail-tap!
            if sideAmt > 0.68 {
                let tailSpotA = min(1.0, (sideAmt - 0.68) / 0.25)
                for (ox, oy, rx, ry) in [
                    (-36.0, -3.5 + droopY * 0.14, 5.6, 5.0),
                    (-46.5,  1.2 + droopY * 0.28, 4.8, 4.3),
                    (-34.0,  7.5 + droopY * 0.14, 5.2, 4.6)
                ] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                    let wx = ox * dirSign
                    ctx.setFillColor(spotOuterCol.withAlphaComponent(0.92 * tailSpotA).cgColor)
                    ctx.fillEllipse(in: CGRect(x: wx - rx, y: oy - ry, width: rx * 2, height: ry * 2))
                    ctx.setFillColor(spotInnerCol.withAlphaComponent(tailSpotA).cgColor)
                    ctx.fillEllipse(in: CGRect(x: wx - rx * 0.58, y: oy - ry * 0.58, width: rx * 1.16, height: ry * 1.16))
                }
            }

        case .spotted:
            ctx.setFillColor(spotOuterCol.withAlphaComponent(0.84).cgColor)
            for side in [-1.0, 1.0] as [CGFloat] {
                for (az, sy, r) in [(1.0, -7.0, 5.4), (1.48, -6.0, 6.2), (1.96, -6.0, 5.8), (1.25, 8.5, 5.8), (1.76, 8.5, 5.5)] as [(CGFloat, CGFloat, CGFloat)] {
                    let a = yaw + side * az
                    let z = cos(a)
                    guard z > -0.05 else { continue }
                    let sx = 44.0 * sin(a)
                    let rx = r * max(0.42, 0.30 + z * 0.72)
                    ctx.fillEllipse(in: CGRect(x: sx - rx, y: sy - r * 0.9, width: rx * 2, height: r * 1.8))
                }
            }

        case .stripedVertical:
            for az in [-1.8, -1.1, 1.1, 1.8] as [CGFloat] {
                let a = yaw + az
                let z = cos(a)
                guard z > 0.05 else { continue }
                let sx = 45.0 * sin(a)
                let w = 10.0 * max(0.45, z)
                let band = CGPath(roundedRect: CGRect(x: sx - w * 0.5, y: -34, width: w, height: 68), cornerWidth: 4, cornerHeight: 4, transform: nil)
                ctx.setFillColor(bellyCol.cgColor); ctx.addPath(band); ctx.fillPath()
                ctx.setStrokeColor(spotOuterCol.withAlphaComponent(0.85).cgColor); ctx.setLineWidth(1.9); ctx.addPath(band); ctx.strokePath()
            }

        case .calicoBlotch:
            for (az, oy, rx, ry, col) in [
                (-1.25, -13.0, 15.0, 11.0, spotInnerCol),
                ( 1.35, -10.0, 16.0, 11.5, spotInnerCol),
                (-1.85,   6.0, 14.0, 10.0, spotOuterCol.withAlphaComponent(0.84)),
                ( 1.75,   8.0, 14.0, 10.0, dorsalCol.withAlphaComponent(0.84))
            ] as [(CGFloat, CGFloat, CGFloat, CGFloat, NSColor)] {
                let a = yaw + az
                let z = cos(a)
                guard z > -0.1 else { continue }
                let sx = 44.0 * sin(a)
                let fx = max(0.45, z + 0.25)
                ctx.setFillColor(col.cgColor)
                ctx.fillEllipse(in: CGRect(x: sx - rx * fx, y: oy - ry, width: rx * fx * 2, height: ry * 2))
            }

        case .saddleBack:
            ctx.setFillColor(dorsalCol.withAlphaComponent(0.72).cgColor)
            ctx.fillEllipse(in: CGRect(x: -38, y: -36 * ps, width: 76, height: 24))

        case .solidGradient:
            break
        }
    }

    private static func drawVolumetricSwimMouth(
        in ctx: CGContext,
        dna: FishPhotoDNA,
        s: CGFloat,
        c: CGFloat,
        bellyCol: NSColor,
        contourCol: NSColor
    ) {
        let lipCol = blendColor(bellyCol, NSColor(srgbRed: 0.97, green: 0.82, blue: 0.76, alpha: 1.0), t: 0.50)
        let mx = 46.5 * s
        let my = 4.2 + 2.6 * c
        let halfW = 5.6 + 4.4 * c

        ctx.saveGState()
        ctx.translateBy(x: mx, y: my)

        let cavity = CGMutablePath()
        cavity.move(to: CGPoint(x: -halfW, y: -0.5))
        cavity.addQuadCurve(to: CGPoint(x: halfW, y: -0.5), control: CGPoint(x: 0, y: -2.0))
        cavity.addQuadCurve(to: CGPoint(x: -halfW, y: -0.5), control: CGPoint(x: 0, y: 6.2 + 1.5 * c))
        cavity.closeSubpath()

        ctx.setFillColor(NSColor(srgbRed: 0.55, green: 0.21, blue: 0.25, alpha: 0.90).cgColor)
        ctx.addPath(cavity); ctx.fillPath()

        if dna.hasBuckTeeth {
            ctx.saveGState()
            ctx.addPath(cavity); ctx.clip()
            let toothCol = NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1.0)
            ctx.setFillColor(toothCol.cgColor)
            if c > 0.30 {
                let tw = 3.2 * (0.72 + 0.28 * c)
                let t1 = CGPath(roundedRect: CGRect(x: -tw - 0.3, y: -1.4, width: tw, height: 3.9), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
                let t2 = CGPath(roundedRect: CGRect(x: 0.3, y: -1.4, width: tw, height: 3.9), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
                ctx.addPath(t1); ctx.fillPath()
                ctx.addPath(t2); ctx.fillPath()
            } else {
                let t1 = CGPath(roundedRect: CGRect(x: -1.6 + s * 1.4, y: -1.4, width: 3.3, height: 3.8), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
                ctx.addPath(t1); ctx.fillPath()
            }
            ctx.restoreGState()
        }

        let smileLip = CGMutablePath()
        smileLip.move(to: CGPoint(x: -halfW - 1.0, y: -0.8))
        smileLip.addQuadCurve(to: CGPoint(x: halfW + 1.0, y: -0.8), control: CGPoint(x: 0, y: 1.4))
        ctx.setStrokeColor(lipCol.cgColor); ctx.setLineWidth(3.2); ctx.setLineCap(.round)
        ctx.addPath(smileLip); ctx.strokePath()

        ctx.setStrokeColor(contourCol.withAlphaComponent(0.78).cgColor); ctx.setLineWidth(1.35)
        ctx.addPath(cavity); ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawVolumetricPectoralFin(
        in ctx: CGContext,
        origin: CGPoint,
        sweepDir: CGFloat,
        flutter: CGFloat,
        finScale: CGFloat,
        finCol: NSColor,
        contourCol: NSColor
    ) {
        let dirSign: CGFloat = sweepDir >= 0 ? 1.0 : -1.0
        let lenScale = max(0.58, min(1.05, 0.55 + abs(sweepDir) * 0.50)) * finScale

        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: dirSign, y: 1.0)
        ctx.rotate(by: flutter)

        let pec = CGMutablePath()
        pec.move(to: CGPoint(x: -2, y: -5))
        pec.addCurve(to: CGPoint(x: 16 * lenScale, y: -8), control1: CGPoint(x: 5, y: -10), control2: CGPoint(x: 12 * lenScale, y: -11))
        pec.addQuadCurve(to: CGPoint(x: 14 * lenScale, y: 11), control: CGPoint(x: 20 * lenScale, y: 2))
        pec.addCurve(to: CGPoint(x: -2, y: 5.5), control1: CGPoint(x: 8 * lenScale, y: 12), control2: CGPoint(x: 2, y: 9))
        pec.closeSubpath()

        ctx.saveGState()
        ctx.addPath(pec); ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.84)),
            (1.0, NSColor(srgbRed: 1.0, green: 0.98, blue: 0.92, alpha: 0.56))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: -2, y: 0), end: CGPoint(x: 18 * lenScale, y: 2), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(0.9)
        for ry in [-4.5, 0.0, 5.0] as [CGFloat] {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: ry * 0.45))
            ctx.addLine(to: CGPoint(x: 14 * lenScale, y: ry))
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.setStrokeColor(contourCol.withAlphaComponent(0.68).cgColor)
        ctx.setLineWidth(1.25)
        ctx.addPath(pec); ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawSideFinFan(
        in ctx: CGContext,
        rootA: CGPoint,
        rootB: CGPoint,
        tip: CGPoint,
        finCol: NSColor,
        contourCol: NSColor
    ) {
        let p = CGMutablePath()
        p.move(to: rootA)
        p.addQuadCurve(to: tip, control: CGPoint(x: (rootA.x + tip.x) * 0.5 + 3, y: (rootA.y + tip.y) * 0.5))
        p.addQuadCurve(to: rootB, control: CGPoint(x: (rootB.x + tip.x) * 0.5 - 6, y: (rootB.y + tip.y) * 0.5))
        p.closeSubpath()

        ctx.saveGState()
        ctx.addPath(p); ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.86)),
            (1.0, NSColor(srgbRed: 0.98, green: 0.95, blue: 0.88, alpha: 0.54))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: (rootA.x + rootB.x) * 0.5, y: (rootA.y + rootB.y) * 0.5), end: tip, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(0.95)
        for t in [0.25, 0.50, 0.75] as [CGFloat] {
            let sx = rootA.x + (rootB.x - rootA.x) * t
            let sy = rootA.y + (rootB.y - rootA.y) * t
            ctx.beginPath()
            ctx.move(to: CGPoint(x: sx, y: sy))
            ctx.addLine(to: CGPoint(x: tip.x + (t - 0.5) * 8, y: tip.y + (rootA.y < tip.y ? -3 : 3)))
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.70).cgColor)
        ctx.setLineWidth(1.35)
        ctx.addPath(p); ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawTailTapSparkleArc(in ctx: CGContext, center: CGPoint, progress: CGFloat) {
        let p = max(0, min(1, progress))
        let a = (1.0 - p) * 0.90
        guard a > 0.05 else { return }
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y - 6)
        ctx.setStrokeColor(NSColor(srgbRed: 0.98, green: 0.72, blue: 0.22, alpha: a).cgColor)
        ctx.setLineWidth(2.0)
        ctx.setLineCap(.round)
        let r0: CGFloat = 10 + p * 8
        let r1: CGFloat = 16 + p * 11
        for ang in [-2.45, -1.57, -0.68] as [CGFloat] {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: cos(ang) * r0, y: sin(ang) * r0))
            ctx.addLine(to: CGPoint(x: cos(ang) * r1, y: sin(ang) * r1))
            ctx.strokePath()
        }
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
