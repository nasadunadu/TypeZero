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

    // MARK: - Calm Infrequent Idle Side-Swim Showcase + Tail-Tap Keyboard Trick
    var sideBlend = Spring1D(0)        // 0 = front-facing steady desk posture, 1 = full side-profile swimming fish!
    var turnCos = Spring1D(1.0)        // +1 facing right, -1 facing left (smooth 3D foreshortened pivot!)
    var swimPitch = Spring1D(0)        // buoyant swim pitch; lifts nose up during tail-tap trick!
    var tailTapFlex = Spring1D(0)      // 0..1 downward broom-fan tail flex to kiss a keycap!

    private(set) var isShowcaseActive: Bool = false
    private var showcaseForced: Bool = false
    private var showcaseElapsed: CGFloat = 0
    private let showcaseDuration: CGFloat = 7.2
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
            swimPitch.target = 0
            tailTapFlex.target = 0
        }
        idleSeconds = 0
        nextShowcaseCooldown = CGFloat.random(in: cooldownRange)
    }

    /// Triggers one graceful left/right full-fish swim showcase + playful broom-fan tail keycap tap!
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
        turnCos.value = showcaseDir
        turnCos.target = showcaseDir
        spawnMouthBubbles(count: 2)
    }

    /// Deterministic snapshot helper for Visual QA verification sheets.
    func setShowcaseSnapshot(elapsed: CGFloat, direction: CGFloat = 1.0, tapKey: PhysicalKey = .n) {
        isShowcaseActive = true
        showcaseForced = true
        showcaseDir = direction >= 0 ? 1.0 : -1.0
        showcaseTapKey = tapKey
        showcaseElapsed = elapsed
        showcaseDidTriggerTap = elapsed > 2.95
        turnCos.value = showcaseDir
        turnCos.target = showcaseDir
        sideBlend.value = 1.0
        sideBlend.target = 1.0
        let tapPt = KeyboardLayout.canvasPoint(for: tapKey)
        let preX = max(116, min(260, tapPt.x + showcaseDir * 70.0))
        pos = Spring2D(CGPoint(x: preX, y: 148))
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
        // Spawn clearly outside & above the snout/head contour so bubbles NEVER overlap eyeballs or float over the tail!
        let sb = max(0, min(1, sideBlend.value))
        let faceSign: CGFloat = turnCos.value >= 0 ? 1.0 : -1.0
        let baseX: CGFloat
        let baseY: CGFloat
        if isShowcaseActive || sb > 0.30 {
            baseX = pos.point.x + faceSign * 56.0
            baseY = pos.point.y - 12.0
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

            if t < 0.75 {
                // Phase 1: Lift gracefully above desk & morph into full aquarium fish profile
                let k = smoothstep(0.0, 0.75, t)
                sideBlend.target = 1.0
                turnCos.target = dir
                pos.target = CGPoint(x: Self.bodyCenterAnchor.x + dir * 10 * k, y: 170 - 24 * k)
                swimPitch.target = -0.06 * k
                tailTapFlex.target = 0
            } else if t < 2.25 {
                // Phase 2: Leisurely glide across the keyboard showing full fish body & flank ocelli
                let k = smoothstep(0.75, 2.25, t)
                let targetX = Self.bodyCenterAnchor.x + dir * (10 + 48 * roamScale * k)
                let waveY = sin(swimPhase * 0.75) * 5.0 * motionMul
                sideBlend.target = 1.0
                turnCos.target = dir
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

                // Exact rotated tail-tip offset at pitch=-0.25, flex=1.0 is ~(-69*dir, +76) -> anchor so broom-fan tip kisses `tapPt`!
                let anchorX = max(116, min(260, tapPt.x + dir * 70.0))
                let anchorY = max(144, min(182, tapPt.y - 76.0))
                let restX = Self.bodyCenterAnchor.x + dir * (58 * roamScale)
                pos.target = CGPoint(
                    x: restX + (anchorX - restX) * min(1, enterK * 1.25),
                    y: 146 + (anchorY - 146) * tapArc
                )
                sideBlend.target = 1.0
                turnCos.target = dir
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
            } else if t < 6.15 {
                // Phase 4: Smooth 3D mid-water turn + calm cruise across the opposite side & back to center!
                let k = smoothstep(3.60, 6.15, t)
                let startX = max(116, min(260, tapPt.x + dir * 70.0))
                let oppX = Self.bodyCenterAnchor.x - dir * (48 * roamScale)
                let midK = smoothstep(3.60, 5.15, t)
                let backK = smoothstep(5.15, 6.15, t)
                let curX = (startX + (oppX - startX) * midK) * (1 - backK) + Self.bodyCenterAnchor.x * backK
                let waveY = sin(swimPhase * 0.75) * 4.5 * motionMul
                sideBlend.target = 1.0
                turnCos.target = -dir
                pos.target = CGPoint(x: curX, y: 144 + waveY)
                swimPitch.target = cos(swimPhase * 0.75) * 0.045
                tailTapFlex.target = 0
                if abs(t - 4.35) < dt * 1.1 {
                    spawnMouthBubbles(count: 2)
                }
                _ = k
            } else if t < showcaseDuration {
                // Phase 5: Gracefully descend back behind keyboard & morph seamlessly into front-facing pose!
                let k = smoothstep(6.15, showcaseDuration, t)
                sideBlend.target = 0.0
                turnCos.target = -dir
                pos.target = CGPoint(x: Self.bodyCenterAnchor.x, y: 144 + (Self.bodyCenterAnchor.y - 144) * k)
                swimPitch.target = 0
                tailTapFlex.target = 0
            } else {
                cancelShowcaseToFront(cooldownRange: reducedMotion ? 30.0...44.0 : 18.0...28.0)
            }

            pos.step(dt: dt, stiffness: (t >= 2.25 && t < 3.60) ? 88 : 54, damping: 14)
            sideBlend.step(dt: dt, stiffness: 55, damping: 14)
            turnCos.step(dt: dt, stiffness: 46, damping: 13)
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

    /// Head anchor point for floating `🫧 <name>` badge cleanly above either front-facing or side-swimming crown!
    static func headPosition(_ physics: CatPhysics, dna: FishPhotoDNA) -> CGPoint {
        let swim = physics.fishSwim
        let c = swim.pos.point
        let puff = max(0, min(1, swim.puff.value))
        let sb = max(0, min(1, swim.sideBlend.value))
        let frontTopY = c.y - (52.0 * CGFloat(dna.plumpness) + puff * 18.0)
        let sideTopY = c.y - (38.0 * CGFloat(dna.plumpness))
        let faceSign: CGFloat = swim.turnCos.value >= 0 ? 1.0 : -1.0
        let sideHeadX = c.x + faceSign * 14.0
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

    // MARK: - Full Side-Profile Idle Swimming Showcase Fish (`待机游动展示完整鱼形态 + 尾巴炫技轻拍键盘`, Zero Headphones!)

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
        let finScale = CGFloat(dna.finLength)
        let faceSign: CGFloat = swim.turnCos.value >= 0 ? 1.0 : -1.0
        let turnScaleX: CGFloat = max(0.24, abs(swim.turnCos.value))
        let tapFlex = max(0, min(1, swim.tailTapFlex.value))
        let tailWave = sin(swim.swimPhase) * (8.5 * (1.0 - tapFlex * 0.7))

        ctx.saveGState()
        ctx.translateBy(x: pos.x, y: pos.y)
        ctx.scaleBy(x: faceSign * turnScaleX, y: 1.0)
        ctx.rotate(by: swim.swimPitch.value)

        // 1. Far-side protruding eye silhouette peeking slightly over the boxy forehead for rich 3/4 depth!
        let farEyeCenter = CGPoint(x: 42.0, y: -15.5 * min(1.12, plump))
        ctx.setFillColor(blendColor(bodyCol, NSColor.white, t: 0.10).cgColor)
        ctx.fillEllipse(in: CGRect(x: farEyeCenter.x - 7.0, y: farEyeCenter.y - 6.8, width: 14.0, height: 13.6))
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.70).cgColor)
        ctx.setLineWidth(1.35)
        ctx.strokeEllipse(in: CGRect(x: farEyeCenter.x - 7.0, y: farEyeCenter.y - 6.8, width: 14.0, height: 13.6))

        // 2. Translucent Dorsal Fin & Ventral Anal Fin
        drawSideFinFan(
            in: ctx,
            rootA: CGPoint(x: -16, y: -23 * min(1.12, plump)),
            rootB: CGPoint(x: -32, y: -17 * min(1.12, plump)),
            tip: CGPoint(x: -28 - tailWave * 0.35, y: -44 * min(1.12, plump) * finScale),
            finCol: finCol,
            contourCol: contourCol
        )
        drawSideFinFan(
            in: ctx,
            rootA: CGPoint(x: -16, y: 21 * min(1.12, plump)),
            rootB: CGPoint(x: -33, y: 15 * min(1.12, plump)),
            tip: CGPoint(x: -31 - tailWave * 0.25, y: 40 * min(1.12, plump) * finScale),
            finCol: finCol,
            contourCol: contourCol
        )

        // 3. Wide Striped Broom-Fan Caudal Tail (gracefully flexes DOWN by +46px during `tailTapTrick` to tap the keycap!)
        let droopY: CGFloat = tapFlex * 46.0
        let pedEnd = CGPoint(x: -54.0 + tapFlex * 4.0, y: droopY * 0.38 + tailWave * 0.28)
        let fanLen: CGFloat = (dna.bodyProfile == .bettaFlow ? 50.0 : 40.0) * finScale
        let fanSpread: CGFloat = (dna.bodyProfile == .bettaFlow ? 34.0 : 25.0) * finScale
        let tailTip = CGPoint(x: pedEnd.x - fanLen * (1.0 - tapFlex * 0.14), y: droopY + tailWave)

        let fan = CGMutablePath()
        fan.move(to: CGPoint(x: pedEnd.x + 4, y: pedEnd.y - 8))
        fan.addQuadCurve(
            to: CGPoint(x: tailTip.x + 3, y: tailTip.y - fanSpread * 0.72),
            control: CGPoint(x: (pedEnd.x + tailTip.x) * 0.5, y: (pedEnd.y + tailTip.y) * 0.5 - fanSpread * 0.58)
        )
        fan.addCurve(
            to: CGPoint(x: tailTip.x - 2, y: tailTip.y + fanSpread * 0.78),
            control1: CGPoint(x: tailTip.x - 6, y: tailTip.y - fanSpread * 0.24),
            control2: CGPoint(x: tailTip.x - 8, y: tailTip.y + fanSpread * 0.28)
        )
        fan.addQuadCurve(
            to: CGPoint(x: pedEnd.x + 4, y: pedEnd.y + 9),
            control: CGPoint(x: (pedEnd.x + tailTip.x) * 0.5, y: (pedEnd.y + tailTip.y) * 0.5 + fanSpread * 0.58)
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
            let ey = tailTip.y + f * (fanSpread * 0.68)
            let ex = tailTip.x + abs(f) * 3.0
            ctx.beginPath()
            ctx.move(to: CGPoint(x: pedEnd.x + 2, y: sy))
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

        // 4. Iconic Side-Profile Puffer Torpedo Body + Curved Tail Peduncle!
        let ps = min(1.16, max(0.88, plump))
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 54, y: 2))
        // Upper boxy puffer snout -> rounded dorsal arch -> curved peduncle
        body.addCurve(
            to: CGPoint(x: 24, y: -27 * ps),
            control1: CGPoint(x: 54, y: -15 * ps),
            control2: CGPoint(x: 42, y: -27 * ps)
        )
        body.addCurve(
            to: CGPoint(x: -54 + tapFlex * 4, y: pedEnd.y - 8.5),
            control1: CGPoint(x: -4, y: -28 * ps),
            control2: CGPoint(x: -34, y: -16 + droopY * 0.22)
        )
        body.addLine(to: CGPoint(x: -54 + tapFlex * 4, y: pedEnd.y + 8.5))
        // Plump cream-ivory round puffer belly -> chin
        body.addCurve(
            to: CGPoint(x: 22, y: 27 * ps),
            control1: CGPoint(x: -32, y: 18 + droopY * 0.22),
            control2: CGPoint(x: -6, y: 30 * ps)
        )
        body.addCurve(
            to: CGPoint(x: 54, y: 2),
            control1: CGPoint(x: 42, y: 25 * ps),
            control2: CGPoint(x: 54, y: 14 * ps)
        )
        body.closeSubpath()

        ctx.saveGState()
        ctx.addPath(body); ctx.clip()

        let topShade = blendColor(bodyCol, dorsalCol, t: 0.26)
        if let grad = makeLinearGradient([
            (0.00, topShade),
            (0.32, bodyCol),
            (0.68, blendColor(bodyCol, bellyCol, t: 0.62)),
            (1.00, bellyCol)
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: -30 * ps), end: CGPoint(x: 0, y: 30 * ps), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Authentic Full Side-Flank Markings (9-10 Double-Ringed Crimson Ocelli + Russet Dorsal Mottling!)
        switch dna.spotPattern {
        case .ringedOcelli:
            let warmDorsal = blendColor(dorsalCol, spotInnerCol, t: 0.34)
            for (bx, by, rx, ry) in [
                (28.0, -21.0, 12.0, 5.5),
                (6.0, -22.5, 13.0, 5.8),
                (-16.0, -18.5, 11.0, 5.2),
                (41.0, -9.0, 7.5, 4.5)
            ] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                ctx.setFillColor(warmDorsal.withAlphaComponent(0.62).cgColor)
                ctx.fillEllipse(in: CGRect(x: bx - rx, y: by - ry, width: rx * 2, height: ry * 2))
            }

            let flankOcelli: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (16, -9, 6.2, 5.6),
                (2, -6, 7.2, 6.4),
                (-11, -10, 6.6, 5.8),
                (-23, -4, 6.8, 6.0),
                (-36, -4 + droopY * 0.14, 5.8, 5.2),
                (-47, 1 + droopY * 0.28, 4.9, 4.4),
                (8, 7, 6.4, 5.6),
                (-6, 8, 7.0, 6.2),
                (-20, 9, 6.2, 5.4),
                (-34, 7 + droopY * 0.14, 5.4, 4.8)
            ]
            for (ox, oy, rx, ry) in flankOcelli {
                ctx.setFillColor(spotOuterCol.withAlphaComponent(0.92).cgColor)
                ctx.fillEllipse(in: CGRect(x: ox - rx, y: oy - ry, width: rx * 2, height: ry * 2))
                ctx.setFillColor(spotInnerCol.cgColor)
                ctx.fillEllipse(in: CGRect(x: ox - rx * 0.58, y: oy - ry * 0.58, width: rx * 1.16, height: ry * 1.16))
            }

        case .spotted:
            ctx.setFillColor(spotOuterCol.withAlphaComponent(0.84).cgColor)
            for (ox, oy, r) in [(16, -8, 5.5), (0, -6, 6.4), (-16, -6, 6.0), (-32, -2, 5.0), (4, 8, 5.8), (-14, 8, 5.6)] as [(CGFloat, CGFloat, CGFloat)] {
                ctx.fillEllipse(in: CGRect(x: ox - r, y: oy - r * 0.9, width: r * 2, height: r * 1.8))
            }

        case .stripedVertical:
            for bx in [18.0, -6.0, -30.0] as [CGFloat] {
                let band = CGPath(roundedRect: CGRect(x: bx - 5, y: -32, width: 10, height: 64), cornerWidth: 4, cornerHeight: 4, transform: nil)
                ctx.setFillColor(bellyCol.cgColor); ctx.addPath(band); ctx.fillPath()
                ctx.setStrokeColor(spotOuterCol.withAlphaComponent(0.85).cgColor); ctx.setLineWidth(2.0); ctx.addPath(band); ctx.strokePath()
            }

        case .calicoBlotch:
            for (ox, oy, rx, ry, col) in [
                (14.0, -14.0, 16.0, 11.0, spotInnerCol),
                (-16.0, -6.0, 18.0, 13.0, spotInnerCol),
                (-2.0, 10.0, 14.0, 10.0, spotOuterCol.withAlphaComponent(0.84))
            ] as [(CGFloat, CGFloat, CGFloat, CGFloat, NSColor)] {
                ctx.setFillColor(col.cgColor)
                ctx.fillEllipse(in: CGRect(x: ox - rx, y: oy - ry, width: rx * 2, height: ry * 2))
            }

        case .saddleBack:
            ctx.setFillColor(dorsalCol.withAlphaComponent(0.72).cgColor)
            ctx.fillEllipse(in: CGRect(x: -36, y: -36, width: 76, height: 24))

        case .solidGradient:
            break
        }

        // Glossy wet aquatic back highlight + cute cheek blush
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.24).cgColor)
        ctx.fillEllipse(in: CGRect(x: -6, y: -23 * ps, width: 34, height: 7))
        ctx.setFillColor(NSColor(srgbRed: 0.95, green: 0.44, blue: 0.44, alpha: 0.30).cgColor)
        ctx.fillEllipse(in: CGRect(x: 31, y: 1, width: 11, height: 7))

        ctx.restoreGState() // end side body clip

        // Crisp KuroCat-style outer contour
        ctx.saveGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.86).cgColor)
        ctx.setLineWidth(1.85)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(body); ctx.strokePath()
        ctx.restoreGState()

        // 5. High-Set Bulging 3D Amber-Red Puffer Eye (`#E24E24`)
        drawFrontFishEye(
            in: ctx,
            center: CGPoint(x: 30.0, y: -11.5 * ps),
            radius: 9.8,
            isLeft: false,
            irisCol: irisCol,
            bodyCol: bodyCol,
            contourCol: contourCol,
            gaze: CGPoint(x: 0.35, y: tapFlex * 0.45),
            blink: physics.effectiveEyeClosure,
            puff: 0,
            frenzy: 0
        )

        // 6. Cheerful Side-Profile Dog-Face Puffer Smile + Little Buck Tooth!
        let lipCol = blendColor(bellyCol, NSColor(srgbRed: 0.97, green: 0.82, blue: 0.76, alpha: 1.0), t: 0.50)
        ctx.saveGState()
        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: 42.5, y: 4.0))
        mouthPath.addQuadCurve(to: CGPoint(x: 54.0, y: 3.5), control: CGPoint(x: 48.0, y: 10.5))
        mouthPath.addQuadCurve(to: CGPoint(x: 42.5, y: 4.0), control: CGPoint(x: 48.5, y: 3.2))
        mouthPath.closeSubpath()
        ctx.setFillColor(NSColor(srgbRed: 0.54, green: 0.21, blue: 0.25, alpha: 0.90).cgColor)
        ctx.addPath(mouthPath); ctx.fillPath()
        if dna.hasBuckTeeth {
            ctx.saveGState()
            ctx.addPath(mouthPath); ctx.clip()
            let tooth = CGPath(roundedRect: CGRect(x: 48.2, y: 2.8, width: 3.4, height: 3.6), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
            ctx.setFillColor(NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1.0).cgColor)
            ctx.addPath(tooth); ctx.fillPath()
            ctx.restoreGState()
        }
        let smileLip = CGMutablePath()
        smileLip.move(to: CGPoint(x: 41.5, y: 4.2))
        smileLip.addQuadCurve(to: CGPoint(x: 54.5, y: 3.0), control: CGPoint(x: 48.0, y: 6.2))
        ctx.setStrokeColor(lipCol.cgColor); ctx.setLineWidth(3.2); ctx.setLineCap(.round)
        ctx.addPath(smileLip); ctx.strokePath()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.78).cgColor); ctx.setLineWidth(1.35)
        ctx.addPath(mouthPath); ctx.strokePath()
        ctx.restoreGState()

        // 7. Fluttering Translucent Side Pectoral Fin (authentic short helicopter paddle behind gill!)
        let pecFlutter = sin(swim.finPhase * 2.2) * 0.26
        ctx.saveGState()
        ctx.translateBy(x: 15.0, y: 3.5)
        ctx.rotate(by: pecFlutter)
        let pec = CGMutablePath()
        pec.move(to: CGPoint(x: 2, y: -5))
        pec.addCurve(to: CGPoint(x: -16 * finScale, y: -9), control1: CGPoint(x: -5, y: -11), control2: CGPoint(x: -12, y: -12))
        pec.addQuadCurve(to: CGPoint(x: -14 * finScale, y: 12), control: CGPoint(x: -20 * finScale, y: 2))
        pec.addCurve(to: CGPoint(x: 2, y: 6), control1: CGPoint(x: -8, y: 13), control2: CGPoint(x: -2, y: 10))
        pec.closeSubpath()
        ctx.saveGState()
        ctx.addPath(pec); ctx.clip()
        if let grad = makeLinearGradient([
            (0.0, finCol.withAlphaComponent(0.84)),
            (1.0, NSColor(srgbRed: 1.0, green: 0.98, blue: 0.92, alpha: 0.56))
        ]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 2, y: 0), end: CGPoint(x: -18 * finScale, y: 2), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.32).cgColor)
        ctx.setLineWidth(0.9)
        for ry in [-5.0, 0.0, 5.5] as [CGFloat] {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: ry * 0.45))
            ctx.addLine(to: CGPoint(x: -14 * finScale, y: ry))
            ctx.strokePath()
        }
        ctx.restoreGState()
        ctx.setStrokeColor(contourCol.withAlphaComponent(0.68).cgColor)
        ctx.setLineWidth(1.25)
        ctx.addPath(pec); ctx.strokePath()
        ctx.restoreGState()

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
