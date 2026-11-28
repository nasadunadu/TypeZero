import Foundation
import AppKit
import CoreGraphics
import ImageIO
import Vision

// MARK: - Cat Photo Visual DNA Model (Shared by Vision VLM, On-Device Vision Fallback & Coat Compiler)

public enum CatPatternFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case solid = "solid"
    case tuxedoBicolor = "tuxedo_bicolor"
    case tabby = "tabby"
    case tabbyBicolor = "tabby_bicolor"
    case calico = "calico"
    case tortoiseshell = "tortoiseshell"
    case colorpoint = "colorpoint"
    case ragdollBicolor = "ragdoll_bicolor"
    case shaded = "shaded"
    case van = "van"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .solid:          return "纯色"
        case .tuxedoBicolor:  return "奶牛 / 双色"
        case .tabby:          return "经典虎斑"
        case .tabbyBicolor:   return "虎斑加白"
        case .calico:         return "三花"
        case .tortoiseshell:  return "玳瑁"
        case .colorpoint:     return "重点色挖煤"
        case .ragdollBicolor: return "布偶开脸"
        case .shaded:         return "金 / 银渐层"
        case .van:            return "梵纹白猫"
        }
    }
}

public enum CatFaceBlaze: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "none"
    case noseBridgeBlaze = "nose_bridge_blaze"
    case invertedV = "inverted_v"
    case skewLeft = "skew_left"
    case skewRight = "skew_right"
    case helmetCap = "helmet_cap"
    case splitHalf = "split_half"
    case eyePatchLeft = "eye_patch_left"
    case eyePatchRight = "eye_patch_right"
    case whiteMuzzle = "white_muzzle"
    case sealMask = "seal_mask"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none:            return "纯色面庞"
        case .noseBridgeBlaze: return "窄鼻梁白嘴套 (狸白经典)"
        case .invertedV:       return "宽正八字开脸"
        case .skewLeft:        return "左偏刘海"
        case .skewRight:       return "右偏刘海"
        case .helmetCap:       return "齐眉警长帽"
        case .splitHalf:       return "阴阳半脸"
        case .eyePatchLeft:    return "左眼海盗斑"
        case .eyePatchRight:   return "右眼海盗斑"
        case .whiteMuzzle:     return "仅下嘴套白"
        case .sealMask:        return "挖煤渐变脸"
        }
    }
}

public enum CatChestBibStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "none"
    case locket = "locket"
    case triangleCollar = "triangle_collar"
    case fullBib = "full_bib"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none:           return "无白胸"
        case .locket:         return "胸口小撮白"
        case .triangleCollar: return "倒三角白领巾"
        case .fullBib:        return "整片大白胸腹"
        }
    }
}

public enum CatSockStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "none"
    case mitten = "mitten"
    case highSock = "high_sock"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none:     return "原色爪"
        case .mitten:   return "白手套"
        case .highSock: return "长白袜"
        }
    }
}

public struct CatPhotoDNA: Codable, Equatable, Sendable {
    public var name: String
    public var breedBadge: String
    public var patternFamily: CatPatternFamily
    public var faceBlaze: CatFaceBlaze
    public var blazeWidth: Double
    public var foreheadM: Bool
    public var cheekStripes: Bool
    public var chinSpot: Bool
    public var chestBib: CatChestBibStyle
    public var frontLeftSock: CatSockStyle
    public var frontRightSock: CatSockStyle
    public var hindSocks: Bool
    public var tailRings: Bool
    public var tailTipDip: Bool
    public var heterochromia: Bool

    public var primaryFurHex: String
    public var secondaryFurHex: String
    public var tertiaryFurHex: String
    public var irisLeftHex: String
    public var irisRightHex: String
    public var noseHex: String
    public var earInnerHex: String

    public var isSleekBuild: Bool
    public var cheekFullness: Double
    public var earSize: Double
    public var patchSeed: Int

    public init(
        name: String = "年糕",
        breedBadge: String = "奶牛小猫",
        patternFamily: CatPatternFamily = .tuxedoBicolor,
        faceBlaze: CatFaceBlaze = .invertedV,
        blazeWidth: Double = 0.56,
        foreheadM: Bool = false,
        cheekStripes: Bool = false,
        chinSpot: Bool = false,
        chestBib: CatChestBibStyle = .fullBib,
        frontLeftSock: CatSockStyle = .mitten,
        frontRightSock: CatSockStyle = .mitten,
        hindSocks: Bool = true,
        tailRings: Bool = false,
        tailTipDip: Bool = true,
        heterochromia: Bool = false,
        primaryFurHex: String = "#1D1D22",
        secondaryFurHex: String = "#F4EFE6",
        tertiaryFurHex: String = "#D98C46",
        irisLeftHex: String = "#D8B94B",
        irisRightHex: String = "#D8B94B",
        noseHex: String = "#ECA2A6",
        earInnerHex: String = "#E4A6A8",
        isSleekBuild: Bool = false,
        cheekFullness: Double = 1.06,
        earSize: Double = 1.0,
        patchSeed: Int = 17
    ) {
        self.name = name
        self.breedBadge = breedBadge
        self.patternFamily = patternFamily
        self.faceBlaze = faceBlaze
        self.blazeWidth = blazeWidth
        self.foreheadM = foreheadM
        self.cheekStripes = cheekStripes
        self.chinSpot = chinSpot
        self.chestBib = chestBib
        self.frontLeftSock = frontLeftSock
        self.frontRightSock = frontRightSock
        self.hindSocks = hindSocks
        self.tailRings = tailRings
        self.tailTipDip = tailTipDip
        self.heterochromia = heterochromia
        self.primaryFurHex = Self.normalizeHex(primaryFurHex, fallback: "#1D1D22")
        self.secondaryFurHex = Self.normalizeHex(secondaryFurHex, fallback: "#F4EFE6")
        self.tertiaryFurHex = Self.normalizeHex(tertiaryFurHex, fallback: "#D98C46")
        self.irisLeftHex = Self.normalizeHex(irisLeftHex, fallback: "#D8B94B")
        self.irisRightHex = Self.normalizeHex(irisRightHex, fallback: self.irisLeftHex)
        self.noseHex = Self.normalizeHex(noseHex, fallback: "#ECA2A6")
        self.earInnerHex = Self.normalizeHex(earInnerHex, fallback: "#E4A6A8")
        self.isSleekBuild = isSleekBuild
        self.cheekFullness = min(1.22, max(0.88, cheekFullness))
        self.earSize = min(1.20, max(0.85, earSize))
        self.patchSeed = max(0, min(999, patchSeed))
    }

    public static func normalizeHex(_ raw: String, fallback: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        let validHex = cleaned.prefix(6)
        guard validHex.count == 6,
              validHex.allSatisfy({ ("0"..."9").contains($0) || ("A"..."F").contains($0) }) else {
            return fallback
        }
        return "#" + String(validHex)
    }

    public mutating func sanitize() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { name = "小咪" } else { name = String(trimmedName.prefix(20)) }
        let trimmedBadge = breedBadge.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBadge.isEmpty { breedBadge = patternFamily.title } else { breedBadge = String(trimmedBadge.prefix(24)) }
        blazeWidth = min(0.90, max(0.25, blazeWidth))
        cheekFullness = min(1.22, max(0.88, cheekFullness))
        earSize = min(1.20, max(0.85, earSize))
        primaryFurHex = Self.normalizeHex(primaryFurHex, fallback: "#232328")
        secondaryFurHex = Self.normalizeHex(secondaryFurHex, fallback: "#F4EFE6")
        tertiaryFurHex = Self.normalizeHex(tertiaryFurHex, fallback: "#D98C46")
        irisLeftHex = Self.normalizeHex(irisLeftHex, fallback: "#D8B94B")
        irisRightHex = heterochromia
            ? Self.normalizeHex(irisRightHex, fallback: "#6EC8F5")
            : irisLeftHex
        noseHex = Self.normalizeHex(noseHex, fallback: "#ECA2A6")
        earInnerHex = Self.normalizeHex(earInnerHex, fallback: "#E4A6A8")
    }
}

public struct CatPhotoAnalysisResult: Sendable {
    public let dna: CatPhotoDNA
    public let previewPNG: Data
    public let usedVisionModel: Bool
    public let sourceSummary: String
}

public struct FishPhotoAnalysisResult: Sendable {
    public let dna: FishPhotoDNA
    public let previewPNG: Data
    public let usedVisionModel: Bool
    public let sourceSummary: String
}

public struct PetPhotoAnalysisResult: Sendable {
    public let species: String // "cat" | "fish"
    public let catDNA: CatPhotoDNA?
    public let fishDNA: FishPhotoDNA?
    public let previewPNG: Data
    public let usedVisionModel: Bool
    public let sourceSummary: String
}

// MARK: - Dual-Engine Photo Analyzer (Cloud/BYOK Vision VLM + Native macOS Vision Foreground Fallback)

public enum PhotoCatAnalyzer {
    private static let visionSystemPrompt = """
    你是顶级猫咪品种、毛色遗传学与写实插画美术总监。请极其仔细地观察照片里这只猫的每一处真实细节（毛色深浅、身上是否有虎斑横纹、白毛只到脖子领巾还是铺满整片肚子、前腿和前爪到底是深色虎斑腿还是纯白袜子、鼻梁白色是否切入眼眶），输出纯 JSON 对象（严禁 Markdown 代码块）：
    {
      "breedBadge": "精准简短特征名，如 黑狸花白领巾 / 海双布偶 / 三花小猫 / 奶牛警长 / 金渐层英短 / 橘白起司",
      "patternFamily": "solid | tuxedo_bicolor | tabby | tabby_bicolor | calico | tortoiseshell | colorpoint | ragdoll_bicolor | shaded | van",
      "faceBlaze": "none | nose_bridge_blaze | inverted_v | skew_left | skew_right | helmet_cap | split_half | eye_patch_left | eye_patch_right | white_muzzle | seal_mask",
      "blazeWidth": 0.45,
      "foreheadM": false,
      "cheekStripes": false,
      "chinSpot": false,
      "chestBib": "none | locket | triangle_collar | full_bib",
      "frontLeftSock": "none | mitten | high_sock",
      "frontRightSock": "none | mitten | high_sock",
      "hindSocks": false,
      "tailRings": false,
      "tailTipDip": false,
      "heterochromia": false,
      "primaryFurHex": "#RRGGBB",
      "secondaryFurHex": "#RRGGBB",
      "tertiaryFurHex": "#RRGGBB",
      "irisLeftHex": "#RRGGBB",
      "irisRightHex": "#RRGGBB",
      "noseHex": "#RRGGBB",
      "earInnerHex": "#RRGGBB",
      "isSleekBuild": false,
      "cheekFullness": 1.06,
      "earSize": 1.00
    }
    【极其关键的写实还原铁律（严禁犯错）】：
    1. 虎斑纹必查：只要额头有 M 纹、脸颊有眼线纹、身上或前腿有一圈圈深色条纹，哪怕带白嘴套/白胸，也必须选 tabby 或 tabby_bicolor（foreheadM=true, cheekStripes=true, tailRings=true, tailTipDip=false；注意狸花/虎斑猫尾尖绝大多数是纯黑深色而非白色！），绝对禁止选成没有条纹的 tuxedo_bicolor！
    2. 深色黑狸花/炭黑虎斑色彩铁律：primaryFurHex 必须填人眼看到的【深沉主毛色】，偏黑的深色狸花猫（黑炭条纹占大面积、底绒深暖灰褐）primaryFurHex 必须填深炭黑褐色（#38312B ~ #443B33），tertiaryFurHex 填纯墨黑条纹色（#141314），绝对禁止把局部反光浅灰毛尖当成主色填成浅灰咖色（> #605850）！纯黑/奶牛黑猫填 #1A1A1F。
    3. 开脸精确区分（nose_bridge_blaze vs inverted_v）：
       - 如果两只眼睛四周 100% 被深色/虎斑毛包裹，白色只是从两眼内侧鼻梁中间窄窄一道向下散开包住粉鼻子和白嘴套（最典型的白嘴白领巾狸花猫！），必须选 "nose_bridge_blaze"！
       - 只有宽大的白色倒 V 直接盖住半边内脸颊时才选 "inverted_v"。
    4. 白领巾 vs 整片白肚皮（triangle_collar vs full_bib）：
       - 如果白色主要集中在下巴与脖子正下方的倒三角白围脖/白领巾，领巾往下胸膛和前肩依然布满深色虎斑横纹，必须选 "triangle_collar"（绝不能选 full_bib 把整片胸膛涂白盖住虎斑纹）！
       - 只有从脖子一直到大肚子整面全白时才选 "full_bib"。
    5. 前腿与前爪严禁臆测白手套：仔细看两条前腿下半截和前脚趾！如果整条前腿都是深色带黑色手镯横纹一直到深色脚掌（前爪没有明显白手套），frontLeftSock 和 frontRightSock 必须填 "none"！只有前脚掌真有一截纯白手套才填 "mitten"。
    6. 耳内与鼻头与瞳色：狸花猫耳内是棕灰耳毛（earInnerHex 填 #76604E，勿填假粉红）；粉鼻头填柔和樱花粉 #F0A6AE，砖红鼻填 #B86B5E；绿瞳填通透翡翠绿 #589154。
    """

    private static let fishVisionSystemPrompt = """
    你是顶级观赏鱼分类学家、水族摄影白平衡专家与 2D 矢量角色美术总监。请极其仔细地观察用户上传的观赏鱼照片（可能是 1–4 张同条鱼的不同角度），剥离水族箱紫粉灯/蓝灯/暖黄灯色偏，忽略缸底的其他配鱼（如异形鱼、清道夫、底栖鱼），只提取画面主体的那条鱼的真实特征，输出严格符合以下字段的纯 JSON 对象（不要输出 Markdown 代码块）：
    {
      "species": "fish",
      "breedBadge": "精准简短品种名，如 红斑狗头河豚 / 斑马狗头 / 泰狮金鱼 / 半月斗鱼 / 红白锦鲤 / 小丑鱼 / 神仙鱼",
      "bodyProfile": "puffer_torpedo | goldfish_round | betta_flow | koi_stream | angelfish_disc | clownfish_oval",
      "spotPattern": "ringed_ocelli | spotted | striped_vertical | calico_blotch | solid_gradient | saddle_back",
      "primaryBodyHex": "#RRGGBB",
      "bellyHex": "#RRGGBB",
      "dorsalHex": "#RRGGBB",
      "spotOuterHex": "#RRGGBB",
      "spotInnerHex": "#RRGGBB",
      "finHex": "#RRGGBB",
      "irisHex": "#RRGGBB",
      "hasBuckTeeth": false,
      "canPuffUp": false,
      "finLength": 1.00,
      "plumpness": 1.10
    }
    【关键写实铁律】：
    1. 河豚 / 狗头识别（红斑狗头 / 血钻狗头 / 斑马狗头等）：凡是方头圆肚、高凸圆眼、宽扇形条纹尾鳍、厚唇露小板牙的淡水河豚，bodyProfile 必须填 "puffer_torpedo"，hasBuckTeeth=true，canPuffUp=true！
    2. 双层靶心斑（ringed_ocelli）：若体侧分布着【深褐黑外环 + 鲜朱红内芯】的双层圆斑（红斑狗头/血钻狗头的灵魂特征！），spotPattern 必须填 "ringed_ocelli"，spotOuterHex 填深褐黑（#4A2A24），spotInnerHex 填鲜朱红（#DF3B36）！
    3. 严禁把水族紫灯/蓝灯色偏当真鱼色：如果鱼缸开着紫粉灯/蓝灯把白肚皮照成紫色或粉紫色，必须白平衡还原回鱼的真实体色（例如红斑狗头真实底色是奶油香槟黄 #EFE4C4、象牙白肚皮 #F7F3E7、金橄榄扇形尾鳍 #C5B268、琥珀红凸眼 #E24E24）！
    4. 多鱼去噪：若照片缸底有黄金达摩异形、清道夫或其他配鱼，彻底忽略配鱼，只描述画面中心主角大鱼。
    """

    public static let maxPhotoCount = 4

    public static func analyzeImage(
        at url: URL,
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async throws -> CatPhotoAnalysisResult {
        try await analyzeImages(
            at: [url],
            preferredName: preferredName,
            llmConfig: llmConfig,
            byokAPIKey: byokAPIKey,
            cloudJWT: cloudJWT
        )
    }

    public static func analyzeImages(
        at urls: [URL],
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async throws -> CatPhotoAnalysisResult {
        let images = urls.prefix(maxPhotoCount).compactMap { loadOrientedCGImage(from: $0, maxPixelSize: 1024) }
        guard !images.isEmpty else {
            throw NSError(domain: "PhotoCatAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取所选照片，请换一张清晰的猫咪照片"])
        }
        return await analyzeCGImages(
            images,
            preferredName: preferredName,
            llmConfig: llmConfig,
            byokAPIKey: byokAPIKey,
            cloudJWT: cloudJWT
        )
    }

    public static func analyzeCGImage(
        _ cgImage: CGImage,
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async -> CatPhotoAnalysisResult {
        await analyzeCGImages(
            [cgImage],
            preferredName: preferredName,
            llmConfig: llmConfig,
            byokAPIKey: byokAPIKey,
            cloudJWT: cloudJWT
        )
    }

    public static func analyzeCGImages(
        _ cgImages: [CGImage],
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async -> CatPhotoAnalysisResult {
        let bounded = Array(cgImages.prefix(maxPhotoCount))
        guard let first = bounded.first else {
            return CatPhotoAnalysisResult(dna: CatPhotoDNA(), previewPNG: Data(), usedVisionModel: false, sourceSummary: "")
        }

        // Stage 0: On-device Apple Vision cat crop + foreground photometry across ALL uploaded angles (1..4 photos)
        let preps = bounded.map { prepareLocalVisionFeatures(from: $0, preferredName: preferredName) }
        let primaryPrep = preps.first ?? prepareLocalVisionFeatures(from: first, preferredName: preferredName)
        let mergedPrep = mergePhotometryPreps(preps, fallback: primaryPrep)

        let maxDim = bounded.count > 1 ? 560 : 640
        let dataURLs: [String] = preps.compactMap { p in
            guard let jpegData = encodeJPEG(p.croppedCatImage, maxDimension: maxDim, compression: 0.76) else { return nil }
            return "data:image/jpeg;base64," + jpegData.base64EncodedString()
        }

        // Stage 1: Joint Multimodal Vision LLM (fuses face, body, tail & paws across all uploaded photos!)
        if !dataURLs.isEmpty {
            let trimmedBYOK = byokAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedJWT = cloudJWT.trimmingCharacters(in: .whitespacesAndNewlines)

            func finalize(_ raw: CatPhotoDNA) -> CatPhotoAnalysisResult {
                var calibrated = calibrateWithPhotometry(raw, prep: mergedPrep)
                let cleanName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
                calibrated.name = cleanName.isEmpty ? mergedPrep.dna.name : cleanName
                calibrated.sanitize()
                return CatPhotoAnalysisResult(
                    dna: calibrated,
                    previewPNG: mergedPrep.previewPNG,
                    usedVisionModel: true,
                    sourceSummary: "✨ 多模态视觉 + 像素测光精修 · \(calibrated.breedBadge)"
                )
            }

            if !llmConfig.useOfficialCloudTrial && !trimmedBYOK.isEmpty {
                if let remoteDNA = await requestBYOKVisionDNA(dataURLs: dataURLs, config: llmConfig, apiKey: trimmedBYOK) {
                    return finalize(remoteDNA)
                }
            }
            if !trimmedJWT.isEmpty {
                if let cloudDNA = await requestOfficialCloudVisionDNA(dataURLs: dataURLs, jwt: trimmedJWT) {
                    return finalize(cloudDNA)
                }
            }
            if !trimmedBYOK.isEmpty {
                if let remoteDNA = await requestBYOKVisionDNA(dataURLs: dataURLs, config: llmConfig, apiKey: trimmedBYOK) {
                    return finalize(remoteDNA)
                }
            }
        }

        // Stage 2: Instant zero-dependency On-Device Apple Vision result
        return CatPhotoAnalysisResult(
            dna: mergedPrep.dna,
            previewPNG: mergedPrep.previewPNG,
            usedVisionModel: false,
            sourceSummary: mergedPrep.dna.breedBadge
        )
    }

    // MARK: - Multi-Photo Fish Vision & Anti-Actinic Photometry Pipeline

    public static func analyzeFishImages(
        at urls: [URL],
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async throws -> FishPhotoAnalysisResult {
        let images = urls.prefix(maxPhotoCount).compactMap { loadOrientedCGImage(from: $0, maxPixelSize: 1024) }
        guard !images.isEmpty else {
            throw NSError(domain: "PhotoCatAnalyzer", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法读取所选小鱼照片"])
        }
        return await analyzeFishCGImages(
            images,
            preferredName: preferredName,
            llmConfig: llmConfig,
            byokAPIKey: byokAPIKey,
            cloudJWT: cloudJWT
        )
    }

    public static func analyzeFishCGImages(
        _ cgImages: [CGImage],
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async -> FishPhotoAnalysisResult {
        let bounded = Array(cgImages.prefix(maxPhotoCount))
        guard let first = bounded.first else {
            return FishPhotoAnalysisResult(dna: FishPhotoDNA(), previewPNG: Data(), usedVisionModel: false, sourceSummary: "")
        }

        let fishPreps = bounded.map { prepareLocalFishVisionFeatures(from: $0, preferredName: preferredName) }
        let primary = fishPreps.first ?? prepareLocalFishVisionFeatures(from: first, preferredName: preferredName)
        let maxDim = bounded.count > 1 ? 560 : 640
        let dataURLs: [String] = fishPreps.compactMap { p in
            guard let jpeg = encodeJPEG(p.croppedFishImage, maxDimension: maxDim, compression: 0.78) else { return nil }
            return "data:image/jpeg;base64," + jpeg.base64EncodedString()
        }

        if !dataURLs.isEmpty {
            let trimmedBYOK = byokAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedJWT = cloudJWT.trimmingCharacters(in: .whitespacesAndNewlines)

            func finalizeFish(_ raw: FishPhotoDNA) -> FishPhotoAnalysisResult {
                var calibrated = calibrateFishWithPhotometry(raw, preps: fishPreps)
                let cleanName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
                calibrated.name = cleanName.isEmpty ? primary.dna.name : cleanName
                calibrated.sanitize()
                return FishPhotoAnalysisResult(
                    dna: calibrated,
                    previewPNG: primary.previewPNG,
                    usedVisionModel: true,
                    sourceSummary: "✨ 多模态鱼类视觉 + 抗紫光校准 · \(calibrated.breedBadge)"
                )
            }

            if !llmConfig.useOfficialCloudTrial && !trimmedBYOK.isEmpty {
                if let remote = await requestBYOKFishVisionDNA(dataURLs: dataURLs, config: llmConfig, apiKey: trimmedBYOK) {
                    return finalizeFish(remote)
                }
            }
            if !trimmedJWT.isEmpty {
                if let cloud = await requestOfficialCloudFishVisionDNA(dataURLs: dataURLs, jwt: trimmedJWT) {
                    return finalizeFish(cloud)
                }
            }
            if !trimmedBYOK.isEmpty {
                if let remote = await requestBYOKFishVisionDNA(dataURLs: dataURLs, config: llmConfig, apiKey: trimmedBYOK) {
                    return finalizeFish(remote)
                }
            }
        }

        var localDNA = primary.dna
        let cleanName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.isEmpty { localDNA.name = cleanName }
        localDNA.sanitize()
        return FishPhotoAnalysisResult(
            dna: localDNA,
            previewPNG: primary.previewPNG,
            usedVisionModel: false,
            sourceSummary: localDNA.breedBadge
        )
    }

    // MARK: - Strict Auto-Species Routing (`cat` vs `fish` — NEVER cross-generates!)

    /// Fast (~35ms) on-device Apple Vision species classifier (`VNRecognizeAnimalsRequest` + `VNClassifyImageRequest`).
    /// Uses word-boundary token matching (never loose substrings like `"cat"` in `"location"`).
    /// Returns `"cat"`, `"fish"`, or `nil` if ambiguous.
    public static func detectLocalSpecies(from cgImages: [CGImage]) -> String? {
        guard !cgImages.isEmpty else { return nil }
        let catTokens: Set<String> = [
            "cat", "cats", "feline", "kitten", "kittens", "tabby", "siamese", "persian", "felidae"
        ]
        let strongFishTokens: Set<String> = [
            "fish", "fishes", "fishtank", "aquarium", "puffer", "blowfish", "goldfish", "koi",
            "clownfish", "betta", "angelfish", "carp", "catfish", "guppy", "shark", "stingray",
            "seahorse", "eel", "coral", "reef", "aquatic", "marine"
        ]
        let mediumAquaticTokens: Set<String> = [
            "underwater", "sea", "ocean", "seafood", "tank"
        ]

        var catScore = 0.0
        var fishScore = 0.0

        for img in cgImages.prefix(maxPhotoCount) {
            let handler = VNImageRequestHandler(cgImage: img, options: [:])
            let animalReq = VNRecognizeAnimalsRequest()
            let classifyReq = VNClassifyImageRequest()
            try? handler.perform([animalReq, classifyReq])

            if let obsList = animalReq.results {
                for obs in obsList {
                    for lbl in obs.labels {
                        let id = lbl.identifier.lowercased()
                        if id == "cat" && lbl.confidence >= 0.30 {
                            catScore += Double(lbl.confidence) * 3.5
                        }
                    }
                }
            }

            if let classObs = classifyReq.results {
                for obs in classObs where obs.confidence >= 0.04 {
                    let id = obs.identifier.lowercased()
                    let parts = Set(id.split(separator: "_").map(String.init))
                    if !parts.isDisjoint(with: catTokens) && !parts.contains("catfish") {
                        catScore += Double(obs.confidence) * 1.8
                    } else if !parts.isDisjoint(with: strongFishTokens) || id.contains("fish") || id.contains("aquarium") || id.contains("puffer") {
                        fishScore += Double(obs.confidence) * 2.6
                    } else if !parts.isDisjoint(with: mediumAquaticTokens) {
                        fishScore += Double(obs.confidence) * 0.75
                    }
                }
            }
        }

        if catScore >= 0.55 && catScore >= fishScore * 1.25 {
            return "cat"
        }
        if fishScore >= 0.25 && fishScore > catScore * 1.15 {
            return "fish"
        }
        return nil
    }

    /// Unified entry point for photo upload: automatically detects whether the uploaded photo(s) are a Cat or a Fish,
    /// NEVER allowing a cat to be generated in the fish lane or a fish in the cat lane!
    public static func detectSpeciesAndAnalyze(
        _ cgImages: [CGImage],
        preferredSpecies: String = "cat",
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async -> PetPhotoAnalysisResult {
        let bounded = Array(cgImages.prefix(maxPhotoCount))
        guard !bounded.isEmpty else {
            return PetPhotoAnalysisResult(
                species: preferredSpecies == "fish" ? "fish" : "cat",
                catDNA: preferredSpecies == "fish" ? nil : CatPhotoDNA(),
                fishDNA: preferredSpecies == "fish" ? FishPhotoDNA.crossRiverPufferPreset : nil,
                previewPNG: Data(),
                usedVisionModel: false,
                sourceSummary: ""
            )
        }

        var resolvedSpecies = detectLocalSpecies(from: bounded)

        // If on-device Apple Vision was uncertain, ask Cloud/BYOK multimodal model to classify species first!
        if resolvedSpecies == nil {
            let previewURLs: [String] = bounded.prefix(2).compactMap { img in
                guard let jpg = encodeJPEG(img, maxDimension: 384, compression: 0.72) else { return nil }
                return "data:image/jpeg;base64," + jpg.base64EncodedString()
            }
            let trimmedBYOK = byokAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedJWT = cloudJWT.trimmingCharacters(in: .whitespacesAndNewlines)
            if !previewURLs.isEmpty {
                if !llmConfig.useOfficialCloudTrial && !trimmedBYOK.isEmpty {
                    resolvedSpecies = await requestBYOKSpeciesDetect(dataURLs: previewURLs, config: llmConfig, apiKey: trimmedBYOK)
                }
                if resolvedSpecies == nil, !trimmedJWT.isEmpty {
                    resolvedSpecies = await requestOfficialCloudSpeciesDetect(dataURLs: previewURLs, jwt: trimmedJWT)
                }
                if resolvedSpecies == nil, !trimmedBYOK.isEmpty {
                    resolvedSpecies = await requestBYOKSpeciesDetect(dataURLs: previewURLs, config: llmConfig, apiKey: trimmedBYOK)
                }
            }
        }

        let finalSpecies = (resolvedSpecies ?? (preferredSpecies == "fish" ? "fish" : "cat"))
        if finalSpecies == "fish" {
            let fishRes = await analyzeFishCGImages(
                bounded,
                preferredName: preferredName,
                llmConfig: llmConfig,
                byokAPIKey: byokAPIKey,
                cloudJWT: cloudJWT
            )
            return PetPhotoAnalysisResult(
                species: "fish",
                catDNA: nil,
                fishDNA: fishRes.dna,
                previewPNG: fishRes.previewPNG,
                usedVisionModel: fishRes.usedVisionModel,
                sourceSummary: fishRes.sourceSummary
            )
        } else {
            let catRes = await analyzeCGImages(
                bounded,
                preferredName: preferredName,
                llmConfig: llmConfig,
                byokAPIKey: byokAPIKey,
                cloudJWT: cloudJWT
            )
            return PetPhotoAnalysisResult(
                species: "cat",
                catDNA: catRes.dna,
                fishDNA: nil,
                previewPNG: catRes.previewPNG,
                usedVisionModel: catRes.usedVisionModel,
                sourceSummary: catRes.sourceSummary
            )
        }
    }

    private static func requestOfficialCloudSpeciesDetect(dataURLs: [String], jwt: String) async -> String? {
        guard let first = dataURLs.first,
              let url = URL(string: "\(CloudAuthClient.baseURL)/api/pet/analyze-photo") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 14.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["species": "auto", "imageDataUrl": first, "imageDataUrls": dataURLs]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = payload
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let sp = (wrapper["species"] as? String) ?? ((wrapper["dna"] as? [String: Any])?["species"] as? String)
        if sp == "fish" || sp == "cat" { return sp }
        return nil
    }

    private static func requestBYOKSpeciesDetect(dataURLs: [String], config: LLMConfig, apiKey: String) async -> String? {
        guard !dataURLs.isEmpty else { return nil }
        let base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty else { return nil }
        let sys = "判断图片中的主体宠物是猫还是鱼，仅输出纯 JSON：{\"species\":\"cat\"} 或 {\"species\":\"fish\"}。"
        let userTxt = "判断主体动物是 cat 还是 fish。"

        if PolishEngine.isAnthropicEndpoint(base) {
            let endpoint = PolishEngine.normalizeAnthropicMessagesEndpoint(base)
            guard let url = URL(string: endpoint) else { return nil }
            var blocks: [[String: Any]] = dataURLs.map { du in
                let rawB64 = du.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                return ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": rawB64]]
            }
            blocks.append(["type": "text", "text": userTxt])
            let payload: [String: Any] = [
                "model": config.modelName.isEmpty ? "claude-haiku-5-5" : config.modelName,
                "max_tokens": 32,
                "system": sys,
                "messages": [["role": "user", "content": blocks]]
            ]
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 12.0
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = root["content"] as? [[String: Any]],
                  let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String else { return nil }
            let low = text.lowercased()
            if low.contains("fish") { return "fish" }
            if low.contains("cat") { return "cat" }
            return nil
        }

        let endpoint = base.hasSuffix("/chat/completions") ? base : "\(base)/chat/completions"
        guard let url = URL(string: endpoint) else { return nil }
        var model = config.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if config.selectedProvider == .dashscope && model == "qwen-flash" { model = "qwen-vl-max" }
        var userBlocks: [[String: Any]] = [["type": "text", "text": userTxt]]
        for du in dataURLs { userBlocks.append(["type": "image_url", "image_url": ["url": du]]) }
        var payload: [String: Any] = [
            "model": model.isEmpty ? "deepseek-flash" : model,
            "stream": false,
            "max_tokens": 32,
            "messages": [
                ["role": "system", "content": sys],
                ["role": "user", "content": userBlocks]
            ]
        ]
        if base.contains("deepseek.com") { payload["thinking"] = ["type": "disabled"] }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 12.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let sessionConfig = URLSessionConfiguration.ephemeral
        if PolishEngine.shouldUseDirectConnection(for: base) { sessionConfig.connectionProxyDictionary = [:] }
        let session = URLSession(configuration: sessionConfig)
        defer { session.finishTasksAndInvalidate() }

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else { return nil }
        let low = content.lowercased()
        if low.contains("fish") { return "fish" }
        if low.contains("cat") { return "cat" }
        return nil
    }

    private struct LocalFishPrepOutput {
        let croppedFishImage: CGImage
        let previewPNG: Data
        let dna: FishPhotoDNA
        let hasPurpleActinicCast: Bool
        let crimsonSpotScore: Double
    }

    private static func prepareLocalFishVisionFeatures(from sourceImage: CGImage, preferredName: String) -> LocalFishPrepOutput {
        // Isolate primary foreground fish via Apple Vision instance mask so bottom tankmates (plecos) are excluded!
        var cropped = sourceImage
        let fgReq = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: sourceImage, options: [:])
        let grid = 80
        var fgMask = [Bool](repeating: false, count: grid * grid)
        var maskOK = false

        if (try? handler.perform([fgReq])) != nil,
           let result = fgReq.results?.first,
           let maskBuf = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler) {
            CVPixelBufferLockBaseAddress(maskBuf, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(maskBuf, .readOnly) }
            let mw = CVPixelBufferGetWidth(maskBuf)
            let mh = CVPixelBufferGetHeight(maskBuf)
            let bpr = CVPixelBufferGetBytesPerRow(maskBuf)
            if let base = CVPixelBufferGetBaseAddress(maskBuf)?.assumingMemoryBound(to: UInt8.self), mw > 0, mh > 0 {
                var minX = mw, maxX = 0, minY = mh, maxY = 0
                var count = 0
                for gy in 0..<grid {
                    let my = min(mh - 1, gy * mh / grid)
                    for gx in 0..<grid {
                        let mx = min(mw - 1, gx * mw / grid)
                        let v = base[my * bpr + mx]
                        // Favor central-upper main swimmer; ignore thin bottom substrate strip unless full frame
                        if v > 128 {
                            fgMask[gy * grid + gx] = true
                            count += 1
                            if mx < minX { minX = mx }
                            if mx > maxX { maxX = mx }
                            if my < minY { minY = my }
                            if my > maxY { maxY = my }
                        }
                    }
                }
                if count > 240 && maxX > minX + 16 && maxY > minY + 16 {
                    maskOK = true
                    let scaleX = CGFloat(sourceImage.width) / CGFloat(mw)
                    let scaleY = CGFloat(sourceImage.height) / CGFloat(mh)
                    let padX = CGFloat(maxX - minX) * scaleX * 0.12
                    let padY = CGFloat(maxY - minY) * scaleY * 0.16
                    let rx = max(0, CGFloat(minX) * scaleX - padX)
                    let ry = max(0, CGFloat(minY) * scaleY - padY)
                    let rw = min(CGFloat(sourceImage.width) - rx, CGFloat(maxX - minX) * scaleX + padX * 2)
                    let rh = min(CGFloat(sourceImage.height) - ry, CGFloat(maxY - minY) * scaleY + padY * 2)
                    if let sub = sourceImage.cropping(to: CGRect(x: rx, y: ry, width: rw, height: rh)) {
                        cropped = sub
                    }
                }
            }
        }

        let previewPNG = renderSquarePreviewPNG(from: cropped, size: 160)

        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        var rgba = [UInt8](repeating: 0, count: grid * grid * 4)
        if let ctx = CGContext(data: &rgba, width: grid, height: grid, bitsPerComponent: 8, bytesPerRow: grid * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: grid, height: grid))
        }

        var purplePixels = 0.0, crimsonPixels = 0.0, creamPixels = 0.0, totalPixels = 0.0
        for gy in 10..<(grid - 10) {
            for gx in 8..<(grid - 8) {
                let idx = gy * grid + gx
                if maskOK && !fgMask[idx] { continue }
                let r = Double(rgba[idx * 4]) / 255.0
                let g = Double(rgba[idx * 4 + 1]) / 255.0
                let b = Double(rgba[idx * 4 + 2]) / 255.0
                totalPixels += 1
                if (r > g + 0.06 && b > g + 0.08) || (b > g + 0.14 && b > 0.45) {
                    purplePixels += 1
                }
                if r > 0.48 && (r - g) > 0.16 && (r - b) > 0.10 {
                    crimsonPixels += 1
                }
                if r > 0.62 && g > 0.56 && b > 0.42 && abs(r - g) < 0.16 {
                    creamPixels += 1
                }
            }
        }
        let denom = max(1.0, totalPixels)
        let hasPurpleCast = (purplePixels / denom) > 0.14
        let crimsonScore = crimsonPixels / denom

        var dna = FishPhotoDNA.crossRiverPufferPreset
        dna.name = preferredName.isEmpty ? "红斑" : preferredName
        if crimsonScore < 0.015 && (creamPixels / denom) < 0.12 {
            dna.breedBadge = "观赏小鱼"
            dna.spotPattern = .solidGradient
            dna.hasBuckTeeth = false
        }
        dna.sanitize()
        return LocalFishPrepOutput(
            croppedFishImage: cropped,
            previewPNG: previewPNG,
            dna: dna,
            hasPurpleActinicCast: hasPurpleCast,
            crimsonSpotScore: crimsonScore
        )
    }

    private static func calibrateFishWithPhotometry(_ raw: FishPhotoDNA, preps: [LocalFishPrepOutput]) -> FishPhotoDNA {
        var dna = raw
        let anyPurpleCast = preps.contains(where: \.hasPurpleActinicCast)
        // Strip purple/magenta actinic aquarium LED cast from cream-ivory bellies & bodies!
        if anyPurpleCast {
            let bc = CatCoatCompiler.rgbComponents(dna.bellyHex)
            if bc.b > bc.g + 0.04 || bc.r > bc.g + 0.06 {
                dna.bellyHex = "#F7F3E7"
            }
            let pc = CatCoatCompiler.rgbComponents(dna.primaryBodyHex)
            if pc.b > pc.g + 0.05 && dna.bodyProfile == .pufferTorpedo {
                dna.primaryBodyHex = "#EFE4C4"
            }
        }
        if dna.bodyProfile == .pufferTorpedo {
            dna.canPuffUp = true
            dna.hasBuckTeeth = true
            if dna.spotPattern == .ringedOcelli {
                let sc = CatCoatCompiler.rgbComponents(dna.spotInnerHex)
                if sc.r < 0.65 { dna.spotInnerHex = "#DF3B36" }
            }
        }
        return dna
    }

    static func parseFishVisionTextResponse(_ raw: String) -> FishPhotoDNA? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = cleaned.firstIndex(of: "{"), let last = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[first...last])
        }
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return parseFishVisionJSONDict(dict)
    }

    static func parseFishVisionJSONDict(_ dict: [String: Any]) -> FishPhotoDNA? {
        var dna = FishPhotoDNA()
        if let b = dict["breedBadge"] as? String, !b.isEmpty { dna.breedBadge = b }
        if let bp = dict["bodyProfile"] as? String, let prof = FishBodyProfile(rawValue: bp) { dna.bodyProfile = prof }
        if let sp = dict["spotPattern"] as? String, let pat = FishSpotPattern(rawValue: sp) { dna.spotPattern = pat }
        if let v = dict["primaryBodyHex"] as? String { dna.primaryBodyHex = v }
        if let v = dict["bellyHex"] as? String { dna.bellyHex = v }
        if let v = dict["dorsalHex"] as? String { dna.dorsalHex = v }
        if let v = dict["spotOuterHex"] as? String { dna.spotOuterHex = v }
        if let v = dict["spotInnerHex"] as? String { dna.spotInnerHex = v }
        if let v = dict["finHex"] as? String { dna.finHex = v }
        if let v = dict["irisHex"] as? String { dna.irisHex = v }
        if let bt = dict["hasBuckTeeth"] as? Bool { dna.hasBuckTeeth = bt }
        if let pu = dict["canPuffUp"] as? Bool { dna.canPuffUp = pu }
        if let fl = (dict["finLength"] as? NSNumber)?.doubleValue { dna.finLength = fl }
        if let pl = (dict["plumpness"] as? NSNumber)?.doubleValue { dna.plumpness = pl }
        dna.sanitize()
        return dna
    }

    private static func requestOfficialCloudFishVisionDNA(dataURLs: [String], jwt: String) async -> FishPhotoDNA? {
        guard let first = dataURLs.first,
              let url = URL(string: "\(CloudAuthClient.baseURL)/api/pet/analyze-photo") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 18.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["species": "fish", "imageDataUrl": first, "imageDataUrls": dataURLs]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = payload
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if let dnaDict = wrapper["dna"] as? [String: Any] { return parseFishVisionJSONDict(dnaDict) }
            if let rawText = wrapper["content"] as? String { return parseFishVisionTextResponse(rawText) }
        } catch {
            return nil
        }
        return nil
    }

    private static func requestBYOKFishVisionDNA(dataURLs: [String], config: LLMConfig, apiKey: String) async -> FishPhotoDNA? {
        guard !dataURLs.isEmpty else { return nil }
        let base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty else { return nil }
        let userInstruction = dataURLs.count > 1
            ? "以上 \(dataURLs.count) 张照片是同一条观赏鱼的不同角度或不同鱼缸灯光。请自动剥离紫粉/蓝水族灯色偏并忽略缸底配鱼，综合还原最准确的唯一鱼类特征 JSON。"
            : "请剥离鱼缸灯光色偏并忽略配鱼，提取画面主角鱼的品种、体色、斑纹与五官 JSON。"

        if PolishEngine.isAnthropicEndpoint(base) {
            let endpoint = PolishEngine.normalizeAnthropicMessagesEndpoint(base)
            guard let url = URL(string: endpoint) else { return nil }
            var blocks: [[String: Any]] = dataURLs.map { du in
                let rawB64 = du.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                return ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": rawB64]]
            }
            blocks.append(["type": "text", "text": userInstruction])
            let payload: [String: Any] = [
                "model": config.modelName.isEmpty ? "claude-haiku-5-5" : config.modelName,
                "max_tokens": 520,
                "system": fishVisionSystemPrompt,
                "messages": [["role": "user", "content": blocks]]
            ]
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 18.0
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = root["content"] as? [[String: Any]],
                  let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String else {
                return nil
            }
            return parseFishVisionTextResponse(text)
        }

        let endpoint = base.hasSuffix("/chat/completions") ? base : "\(base)/chat/completions"
        guard let url = URL(string: endpoint) else { return nil }
        var model = config.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if config.selectedProvider == .dashscope && model == "qwen-flash" { model = "qwen-vl-max" }
        var userBlocks: [[String: Any]] = [["type": "text", "text": userInstruction]]
        for du in dataURLs {
            userBlocks.append(["type": "image_url", "image_url": ["url": du]])
        }
        var payload: [String: Any] = [
            "model": model.isEmpty ? "deepseek-flash" : model,
            "stream": false,
            "max_tokens": 520,
            "messages": [
                ["role": "system", "content": fishVisionSystemPrompt],
                ["role": "user", "content": userBlocks]
            ]
        ]
        if base.contains("deepseek.com") { payload["thinking"] = ["type": "disabled"] }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 18.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let sessionConfig = URLSessionConfiguration.ephemeral
        if PolishEngine.shouldUseDirectConnection(for: base) { sessionConfig.connectionProxyDictionary = [:] }
        let session = URLSession(configuration: sessionConfig)
        defer { session.finishTasksAndInvalidate() }

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            return nil
        }
        return parseFishVisionTextResponse(content)
    }

    // MARK: - Orientation-Safe Image Loading & Encoding

    public static func loadOrientedCGImage(from url: URL, maxPixelSize: Int = 1024) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    private static func encodeJPEG(_ cgImage: CGImage, maxDimension: Int, compression: CGFloat) -> Data? {
        let w = cgImage.width, h = cgImage.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(1.0, CGFloat(maxDimension) / CGFloat(max(w, h)))
        let outW = max(1, Int((CGFloat(w) * scale).rounded()))
        let outH = max(1, Int((CGFloat(h) * scale).rounded()))
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: outW, height: outH))
        guard let scaled = ctx.makeImage() else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, scaled, [kCGImageDestinationLossyCompressionQuality: compression] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    public static func renderSquarePreviewPNG(from cgImage: CGImage, size: Int = 160) -> Data {
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Data() }
        ctx.interpolationQuality = .high
        let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
        let side = min(w, h)
        let cropRect = CGRect(x: (w - side) * 0.5, y: (h - side) * 0.5, width: side, height: side)
        let sub = cgImage.cropping(to: cropRect) ?? cgImage
        ctx.draw(sub, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let outImg = ctx.makeImage() else { return Data() }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return Data() }
        CGImageDestinationAddImage(dest, outImg, nil)
        guard CGImageDestinationFinalize(dest) else { return Data() }
        return data as Data
    }

    // MARK: - Multimodal Vision Network Clients (Cloud & BYOK)

    private static func requestOfficialCloudVisionDNA(dataURLs: [String], jwt: String) async -> CatPhotoDNA? {
        guard let first = dataURLs.first,
              let url = URL(string: "\(CloudAuthClient.baseURL)/api/pet/analyze-photo") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 18.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "imageDataUrl": first,
            "imageDataUrls": dataURLs
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = payload

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            if let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let dnaDict = wrapper["dna"] as? [String: Any] {
                    return parseVisionJSONDict(dnaDict)
                }
                if let rawText = wrapper["content"] as? String {
                    return parseVisionTextResponse(rawText)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func requestBYOKVisionDNA(dataURLs: [String], config: LLMConfig, apiKey: String) async -> CatPhotoDNA? {
        guard !dataURLs.isEmpty else { return nil }
        let base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty else { return nil }
        let userInstruction = dataURLs.count > 1
            ? "以上 \(dataURLs.count) 张照片是同一只猫咪的不同角度（如正脸、全身、侧身、尾巴或爪子）。请综合所有照片互补观察，输出最完整准确的唯一 JSON。"
            : "请提取这只猫咪的花色、开脸、五官与毛色 JSON。"

        // Anthropic Messages native vision format
        if PolishEngine.isAnthropicEndpoint(base) {
            let endpoint = PolishEngine.normalizeAnthropicMessagesEndpoint(base)
            guard let url = URL(string: endpoint) else { return nil }
            var blocks: [[String: Any]] = dataURLs.map { du in
                let rawB64 = du.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                return ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": rawB64]]
            }
            blocks.append(["type": "text", "text": userInstruction])
            let payload: [String: Any] = [
                "model": config.modelName.isEmpty ? "claude-haiku-5-5" : config.modelName,
                "max_tokens": 520,
                "system": visionSystemPrompt,
                "messages": [["role": "user", "content": blocks]]
            ]
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 18.0
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = root["content"] as? [[String: Any]],
                  let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String else {
                return nil
            }
            return parseVisionTextResponse(text)
        }

        // OpenAI-compatible Chat Completions multimodal format (DeepSeek 4 Flash, Doubao Seed, Gemini, OpenAI, Qwen-VL)
        let endpoint = base.hasSuffix("/chat/completions") ? base : "\(base)/chat/completions"
        guard let url = URL(string: endpoint) else { return nil }
        var model = config.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if config.selectedProvider == .dashscope && model == "qwen-flash" {
            model = "qwen-vl-max"
        }
        var userBlocks: [[String: Any]] = [["type": "text", "text": userInstruction]]
        for du in dataURLs {
            userBlocks.append(["type": "image_url", "image_url": ["url": du]])
        }
        var payload: [String: Any] = [
            "model": model.isEmpty ? "deepseek-flash" : model,
            "stream": false,
            "max_tokens": 520,
            "messages": [
                ["role": "system", "content": visionSystemPrompt],
                ["role": "user", "content": userBlocks]
            ]
        ]
        if base.contains("deepseek.com") {
            payload["thinking"] = ["type": "disabled"]
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let sessionConfig = URLSessionConfiguration.ephemeral
        if PolishEngine.shouldUseDirectConnection(for: base) {
            sessionConfig.connectionProxyDictionary = [:]
        }
        let session = URLSession(configuration: sessionConfig)
        defer { session.finishTasksAndInvalidate() }

        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            return nil
        }
        return parseVisionTextResponse(content)
    }

    static func parseVisionTextResponse(_ raw: String) -> CatPhotoDNA? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return parseVisionJSONDict(dict)
    }

    static func parseVisionJSONDict(_ dict: [String: Any]) -> CatPhotoDNA? {
        var dna = CatPhotoDNA()
        if let badge = dict["breedBadge"] as? String, !badge.isEmpty {
            dna.breedBadge = badge
        }
        if let pf = dict["patternFamily"] as? String, let fam = CatPatternFamily(rawValue: pf) {
            dna.patternFamily = fam
        }
        if let fb = dict["faceBlaze"] as? String, let blaze = CatFaceBlaze(rawValue: fb) {
            dna.faceBlaze = blaze
        }
        if let bw = (dict["blazeWidth"] as? NSNumber)?.doubleValue {
            dna.blazeWidth = bw
        }
        if let fm = dict["foreheadM"] as? Bool { dna.foreheadM = fm }
        if let cs = dict["cheekStripes"] as? Bool { dna.cheekStripes = cs }
        if let ch = dict["chinSpot"] as? Bool { dna.chinSpot = ch }
        if let cb = dict["chestBib"] as? String, let bib = CatChestBibStyle(rawValue: cb) {
            dna.chestBib = bib
        }
        if let fl = dict["frontLeftSock"] as? String, let s = CatSockStyle(rawValue: fl) {
            dna.frontLeftSock = s
        }
        if let fr = dict["frontRightSock"] as? String, let s = CatSockStyle(rawValue: fr) {
            dna.frontRightSock = s
        }
        if let hs = dict["hindSocks"] as? Bool { dna.hindSocks = hs }
        if let tr = dict["tailRings"] as? Bool { dna.tailRings = tr }
        if let td = dict["tailTipDip"] as? Bool { dna.tailTipDip = td }
        if let het = dict["heterochromia"] as? Bool { dna.heterochromia = het }

        if let v = dict["primaryFurHex"] as? String { dna.primaryFurHex = v }
        if let v = dict["secondaryFurHex"] as? String { dna.secondaryFurHex = v }
        if let v = dict["tertiaryFurHex"] as? String { dna.tertiaryFurHex = v }
        if let v = dict["irisLeftHex"] as? String { dna.irisLeftHex = v }
        if let v = dict["irisRightHex"] as? String { dna.irisRightHex = v }
        if let v = dict["noseHex"] as? String { dna.noseHex = v }
        if let v = dict["earInnerHex"] as? String { dna.earInnerHex = v }

        if let sb = dict["isSleekBuild"] as? Bool { dna.isSleekBuild = sb }
        if let cf = (dict["cheekFullness"] as? NSNumber)?.doubleValue { dna.cheekFullness = cf }
        if let es = (dict["earSize"] as? NSNumber)?.doubleValue { dna.earSize = es }
        dna.sanitize()
        return dna
    }

    // MARK: - On-Device Apple Vision Foreground Mask + Anatomical Zone Color Classifier

    private struct LocalPrepOutput {
        let croppedCatImage: CGImage
        let previewPNG: Data
        let dna: CatPhotoDNA
        let nonWhiteMedianLum: Double
        let nonWhiteDarkHex: String
        let lowerWhiteRatio: Double
        let bottomPawsDarkRatio: Double
    }

    private static func mergePhotometryPreps(_ preps: [LocalPrepOutput], fallback: LocalPrepOutput) -> LocalPrepOutput {
        guard preps.count > 1 else { return fallback }
        let n = Double(preps.count)
        let avgLum = preps.reduce(0.0) { $0 + $1.nonWhiteMedianLum } / n
        let avgLowerWhite = preps.reduce(0.0) { $0 + $1.lowerWhiteRatio } / n
        let avgPawDark = preps.reduce(0.0) { $0 + $1.bottomPawsDarkRatio } / n
        let darkest = preps.min(by: { $0.nonWhiteMedianLum < $1.nonWhiteMedianLum }) ?? fallback
        var fusedDNA = fallback.dna
        // If a secondary photo clearly captured tabby stripes while primary was a close-up, promote tabby!
        if fusedDNA.patternFamily != .tabby && fusedDNA.patternFamily != .tabbyBicolor,
           let tabbyPrep = preps.first(where: { $0.dna.patternFamily == .tabby || $0.dna.patternFamily == .tabbyBicolor }) {
            fusedDNA = tabbyPrep.dna
            fusedDNA.name = fallback.dna.name
        }
        return LocalPrepOutput(
            croppedCatImage: fallback.croppedCatImage,
            previewPNG: fallback.previewPNG,
            dna: fusedDNA,
            nonWhiteMedianLum: avgLum,
            nonWhiteDarkHex: darkest.nonWhiteDarkHex,
            lowerWhiteRatio: avgLowerWhite,
            bottomPawsDarkRatio: avgPawDark
        )
    }

    /// Anchors VLM-guessed hex colors against the real foreground-masked cat pixel photometry so dark/black cats
    /// are NEVER washed out into mid-grey and non-existent white arms/bellies are corrected!
    private static func calibrateWithPhotometry(_ raw: CatPhotoDNA, prep: LocalPrepOutput) -> CatPhotoDNA {
        var dna = raw
        let c = CatCoatCompiler.rgbComponents(dna.primaryFurHex)
        let vlmLum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

        switch dna.patternFamily {
        case .tabby, .tabbyBicolor:
            dna.foreheadM = true
            dna.cheekStripes = true
            dna.tailRings = true
            dna.tailTipDip = true
            // If real cat fur is dark (< 0.28 median luminance) and VLM gave washed-out grey (> 0.27), pull down to rich dark charcoal-umber!
            if prep.nonWhiteMedianLum < 0.29 && vlmLum > 0.25 {
                let targetScale = max(0.38, min(0.72, (prep.nonWhiteMedianLum * 1.15) / max(0.08, vlmLum)))
                let nr = max(0.16, min(0.30, c.r * targetScale))
                let ng = max(0.14, min(0.26, c.g * targetScale))
                let nb = max(0.12, min(0.23, c.b * targetScale))
                dna.primaryFurHex = String(format: "#%02X%02X%02X", Int((nr * 255).rounded()), Int((ng * 255).rounded()), Int((nb * 255).rounded()))
                dna.tertiaryFurHex = "#141314"
            }
            // If lower torso isn't overwhelmingly white (< 36%), prefer V-shaped `triangleCollar` over full-torso white vest!
            if dna.chestBib == .fullBib && prep.lowerWhiteRatio < 0.36 {
                dna.chestBib = .triangleCollar
            }
            // If bottom paw region is predominantly dark (> 72% dark), clear hallucinated white front mittens & hind socks!
            if prep.bottomPawsDarkRatio > 0.72 {
                dna.frontLeftSock = .none
                dna.frontRightSock = .none
                dna.hindSocks = false
            }
            // Tabby & tabby-bicolor cats genetically have solid dark/black tail tips (not white tips)
            dna.tailTipDip = false
        case .solid, .tuxedoBicolor:
            if prep.nonWhiteMedianLum < 0.18 && vlmLum > 0.20 {
                dna.primaryFurHex = prep.nonWhiteDarkHex
            }
        default:
            break
        }
        return dna
    }

    private static func prepareLocalVisionFeatures(from sourceImage: CGImage, preferredName: String) -> LocalPrepOutput {
        let width = sourceImage.width
        let height = sourceImage.height

        // 1. Detect Cat bounding box via VNRecognizeAnimalsRequest so wide room shots zoom right onto the cat!
        var croppedCat = sourceImage
        let animalReq = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: sourceImage, options: [:])
        try? handler.perform([animalReq])
        if let observations = animalReq.results,
           let catObs = observations.first(where: { obs in obs.labels.contains { $0.identifier.lowercased() == "cat" } }) ?? observations.first {
            let bb = catObs.boundingBox // normalized bottom-left origin
            let padX = bb.width * 0.14
            let padY = bb.height * 0.14
            let minX = max(0.0, bb.minX - padX)
            let maxX = min(1.0, bb.maxX + padX)
            let minY = max(0.0, bb.minY - padY)
            let maxY = min(1.0, bb.maxY + padY)
            let rect = CGRect(
                x: (minX * CGFloat(width)).rounded(.down),
                y: ((1.0 - maxY) * CGFloat(height)).rounded(.down),
                width: max(32.0, ((maxX - minX) * CGFloat(width)).rounded()),
                height: max(32.0, ((maxY - minY) * CGFloat(height)).rounded())
            )
            if let sub = sourceImage.cropping(to: rect) {
                croppedCat = sub
            }
        }

        let previewPNG = renderSquarePreviewPNG(from: croppedCat, size: 160)

        // 2. Rasterize croppedCat to 96x96 sRGB grid + apply VNGenerateForegroundInstanceMaskRequest
        let grid = 96
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        var rgba = [UInt8](repeating: 0, count: grid * grid * 4)
        if let ctx = CGContext(
            data: &rgba, width: grid, height: grid, bitsPerComponent: 8, bytesPerRow: grid * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            ctx.interpolationQuality = .medium
            ctx.draw(croppedCat, in: CGRect(x: 0, y: 0, width: grid, height: grid))
        }

        var fgMask = [Bool](repeating: false, count: grid * grid)
        var maskSucceeded = false
        let fgReq = VNGenerateForegroundInstanceMaskRequest()
        let cropHandler = VNImageRequestHandler(cgImage: croppedCat, options: [:])
        if (try? cropHandler.perform([fgReq])) != nil,
           let result = fgReq.results?.first,
           let maskBuf = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: cropHandler) {
            CVPixelBufferLockBaseAddress(maskBuf, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(maskBuf, .readOnly) }
            let mw = CVPixelBufferGetWidth(maskBuf)
            let mh = CVPixelBufferGetHeight(maskBuf)
            let bpr = CVPixelBufferGetBytesPerRow(maskBuf)
            if let base = CVPixelBufferGetBaseAddress(maskBuf)?.assumingMemoryBound(to: UInt8.self), mw > 0, mh > 0 {
                var fgCount = 0
                for gy in 0..<grid {
                    let my = min(mh - 1, gy * mh / grid)
                    for gx in 0..<grid {
                        let mx = min(mw - 1, gx * mw / grid)
                        let v = base[my * bpr + mx]
                        if v > 120 {
                            fgMask[gy * grid + gx] = true
                            fgCount += 1
                        }
                    }
                }
                if fgCount > (grid * grid) / 14 {
                    maskSucceeded = true
                }
            }
        }

        if !maskSucceeded {
            // Center-weighted elliptical mask when foreground segmentation is unavailable
            for gy in 0..<grid {
                let ny = (Double(gy) - 48.0) / 42.0
                for gx in 0..<grid {
                    let nx = (Double(gx) - 48.0) / 40.0
                    fgMask[gy * grid + gx] = (nx * nx + ny * ny <= 1.0)
                }
            }
        }

        // 3. Grey-world soft illuminant balance + pigment bucket statistics across top/mid/lower anatomical zones
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, countFG = 0.0
        for i in 0..<(grid * grid) where fgMask[i] {
            sumR += Double(rgba[i * 4]) / 255.0
            sumG += Double(rgba[i * 4 + 1]) / 255.0
            sumB += Double(rgba[i * 4 + 2]) / 255.0
            countFG += 1.0
        }
        let avgR = countFG > 0 ? sumR / countFG : 0.5
        let avgG = countFG > 0 ? sumG / countFG : 0.5
        let avgB = countFG > 0 ? sumB / countFG : 0.5
        let meanLum = (avgR + avgG + avgB) / 3.0
        // Gentle 30% white-balance correction so warm room lamps don't turn white fur orange, without erasing real ginger!
        let gainR = meanLum > 0.08 ? min(1.16, max(0.86, 1.0 + ((meanLum / max(0.08, avgR)) - 1.0) * 0.30)) : 1.0
        let gainG = meanLum > 0.08 ? min(1.12, max(0.90, 1.0 + ((meanLum / max(0.08, avgG)) - 1.0) * 0.30)) : 1.0
        let gainB = meanLum > 0.08 ? min(1.22, max(0.84, 1.0 + ((meanLum / max(0.08, avgB)) - 1.0) * 0.30)) : 1.0

        var whiteRatio = 0.0
        var blackRatio = 0.0
        var gingerRatio = 0.0
        var greyBlueRatio = 0.0
        var brownSealRatio = 0.0

        var topDark = 0.0, topTotal = 0.0
        var botWhite = 0.0, botTotal = 0.0
        var leftTopDark = 0.0, rightTopDark = 0.0
        var edgeEnergy = 0.0, edgeSamples = 0.0

        var nonWhiteLums: [Double] = []
        nonWhiteLums.reserveCapacity(grid * grid / 2)
        var bottomDarkCount = 0.0, bottomTotalCount = 0.0
        var lowerTorsoWhite = 0.0, lowerTorsoTotal = 0.0
        var gingerRGB = (r: 0.0, g: 0.0, b: 0.0, n: 0.0)
        var darkRGB = (r: 0.0, g: 0.0, b: 0.0, n: 0.0)
        var greyRGB = (r: 0.0, g: 0.0, b: 0.0, n: 0.0)

        for gy in 0..<grid {
            for gx in 0..<grid {
                let idx = gy * grid + gx
                guard fgMask[idx] else { continue }
                let r = min(1.0, Double(rgba[idx * 4]) / 255.0 * gainR)
                let g = min(1.0, Double(rgba[idx * 4 + 1]) / 255.0 * gainG)
                let b = min(1.0, Double(rgba[idx * 4 + 2]) / 255.0 * gainB)

                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let chroma = maxC - minC
                let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b

                let isWhite = lum > 0.68 && chroma < 0.17
                if !isWhite {
                    nonWhiteLums.append(lum)
                }
                if gy >= Int(Double(grid) * 0.55) && gy < Int(Double(grid) * 0.85) {
                    lowerTorsoTotal += 1
                    if isWhite { lowerTorsoWhite += 1 }
                }
                if gy >= Int(Double(grid) * 0.78) {
                    bottomTotalCount += 1
                    if !isWhite && lum < 0.42 { bottomDarkCount += 1 }
                }
                let isBlack = lum < 0.22 && chroma < 0.14
                let isGinger = (r > b + 0.13) && (r > g + 0.04) && lum > 0.22 && lum < 0.82
                let isSealBrown = (r > b + 0.07) && lum >= 0.14 && lum <= 0.42 && !isGinger
                let isGreyBlue = !isWhite && !isBlack && !isGinger && chroma < 0.15

                if isWhite { whiteRatio += 1 }
                if isBlack {
                    blackRatio += 1
                    darkRGB.r += r; darkRGB.g += g; darkRGB.b += b; darkRGB.n += 1
                }
                if isGinger {
                    gingerRatio += 1
                    gingerRGB.r += r; gingerRGB.g += g; gingerRGB.b += b; gingerRGB.n += 1
                }
                if isSealBrown {
                    brownSealRatio += 1
                    darkRGB.r += r; darkRGB.g += g; darkRGB.b += b; darkRGB.n += 1
                }
                if isGreyBlue {
                    greyBlueRatio += 1
                    greyRGB.r += r; greyRGB.g += g; greyRGB.b += b; greyRGB.n += 1
                }

                if gy < grid / 2 {
                    topTotal += 1
                    if !isWhite {
                        topDark += 1
                        if gx < grid / 2 { leftTopDark += 1 } else { rightTopDark += 1 }
                    }
                } else {
                    botTotal += 1
                    if isWhite { botWhite += 1 }
                }

                if gx + 1 < grid && fgMask[idx + 1] {
                    let r2 = Double(rgba[(idx + 1) * 4]) / 255.0
                    let g2 = Double(rgba[(idx + 1) * 4 + 1]) / 255.0
                    let b2 = Double(rgba[(idx + 1) * 4 + 2]) / 255.0
                    let lum2 = 0.2126 * r2 + 0.7152 * g2 + 0.0722 * b2
                    edgeEnergy += abs(lum - lum2)
                    edgeSamples += 1
                }
            }
        }

        let total = max(1.0, countFG)
        whiteRatio /= total
        blackRatio /= total
        gingerRatio /= total
        greyBlueRatio /= total
        brownSealRatio /= total
        let stripeContrast = edgeSamples > 0 ? edgeEnergy / edgeSamples : 0
        let botWhiteFrac = botTotal > 0 ? botWhite / botTotal : 0
        let topColoredFrac = topTotal > 0 ? topDark / topTotal : 0
        nonWhiteLums.sort()
        let nonWhiteMedianLum = nonWhiteLums.isEmpty ? 0.35 : nonWhiteLums[nonWhiteLums.count * 42 / 100]
        let lowerWhiteRatio = lowerTorsoTotal > 0 ? (lowerTorsoWhite / lowerTorsoTotal) : 0
        let bottomPawsDarkRatio = bottomTotalCount > 0 ? (bottomDarkCount / bottomTotalCount) : 0.5

        func hexFromSum(_ s: (r: Double, g: Double, b: Double, n: Double), fallback: String) -> String {
            guard s.n > 5 else { return fallback }
            let ri = max(0, min(255, Int((s.r / s.n * 255.0).rounded())))
            let gi = max(0, min(255, Int((s.g / s.n * 255.0).rounded())))
            let bi = max(0, min(255, Int((s.b / s.n * 255.0).rounded())))
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }

        let defaultName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        var dna = CatPhotoDNA()

        // Classify coat family from pigment & zone ratios
        if whiteRatio > 0.20 && gingerRatio > 0.12 && (blackRatio + brownSealRatio) > 0.10 {
            dna.patternFamily = .calico
            dna.breedBadge = "三花小猫"
            dna.name = defaultName.isEmpty ? "小花" : defaultName
            dna.primaryFurHex = "#F5F1E8"
            dna.secondaryFurHex = hexFromSum(gingerRGB, fallback: "#DB8E43")
            dna.tertiaryFurHex = "#242328"
            dna.faceBlaze = .invertedV
            dna.chestBib = .fullBib
            dna.irisLeftHex = "#D9B24C"
            dna.irisRightHex = "#D9B24C"
            dna.noseHex = "#ECA2A6"
        } else if (blackRatio + brownSealRatio) > 0.32 && gingerRatio > 0.16 && whiteRatio < 0.18 {
            dna.patternFamily = .tortoiseshell
            dna.breedBadge = "玳瑁小猫"
            dna.name = defaultName.isEmpty ? "琥珀" : defaultName
            dna.primaryFurHex = "#26201E"
            dna.secondaryFurHex = hexFromSum(gingerRGB, fallback: "#D68A3E")
            dna.tertiaryFurHex = "#E6BA7E"
            dna.faceBlaze = .none
            dna.chestBib = .none
            dna.frontLeftSock = .none
            dna.frontRightSock = .none
            dna.hindSocks = false
            dna.irisLeftHex = "#D6B849"
            dna.irisRightHex = "#D6B849"
            dna.noseHex = "#342B2A"
        } else if whiteRatio > 0.72 {
            if gingerRatio > 0.06 || blackRatio > 0.06 {
                dna.patternFamily = .van
                dna.breedBadge = "梵纹白猫"
                dna.name = defaultName.isEmpty ? "雪球" : defaultName
                dna.primaryFurHex = "#F7F5EF"
                dna.secondaryFurHex = gingerRatio >= blackRatio ? "#DC954E" : "#242429"
                dna.faceBlaze = .none
                dna.chestBib = .fullBib
                dna.irisLeftHex = "#6CC6F6"
                dna.irisRightHex = "#E0B949"
                dna.heterochromia = false
            } else {
                dna.patternFamily = .solid
                dna.breedBadge = "纯白猫咪"
                dna.name = defaultName.isEmpty ? "糯米" : defaultName
                dna.primaryFurHex = "#F7F5F0"
                dna.secondaryFurHex = "#FFFFFF"
                dna.faceBlaze = .none
                dna.chestBib = .none
                dna.frontLeftSock = .none
                dna.frontRightSock = .none
                dna.hindSocks = false
                dna.irisLeftHex = "#70CAF8"
                dna.irisRightHex = "#70CAF8"
            }
            dna.noseHex = "#F0A8AE"
        } else if blackRatio > 0.58 && whiteRatio < 0.12 {
            dna.patternFamily = .solid
            dna.breedBadge = "玄猫小黑"
            dna.name = defaultName.isEmpty ? "煤球" : defaultName
            dna.primaryFurHex = "#19191E"
            dna.secondaryFurHex = "#2B2B33"
            dna.faceBlaze = .none
            dna.chestBib = .none
            dna.frontLeftSock = .none
            dna.frontRightSock = .none
            dna.hindSocks = false
            dna.tailTipDip = false
            dna.irisLeftHex = "#CBEF43"
            dna.irisRightHex = "#CBEF43"
            dna.noseHex = "#26252B"
        } else if gingerRatio > 0.26 {
            if whiteRatio > 0.22 || botWhiteFrac > 0.30 {
                dna.patternFamily = stripeContrast > 0.055 ? .tabbyBicolor : .tuxedoBicolor
                dna.breedBadge = "橘白起司猫"
                dna.name = defaultName.isEmpty ? "黄油" : defaultName
                dna.primaryFurHex = hexFromSum(gingerRGB, fallback: "#DC9850")
                dna.secondaryFurHex = "#F5F0E6"
                dna.tertiaryFurHex = "#A8622C"
                dna.faceBlaze = .invertedV
                dna.foreheadM = true
                dna.cheekStripes = true
                dna.chestBib = .fullBib
                dna.frontLeftSock = .mitten
                dna.frontRightSock = .mitten
                dna.hindSocks = true
                dna.tailRings = true
            } else if whiteRatio > 0.10 {
                dna.patternFamily = .shaded
                dna.breedBadge = "金渐层"
                dna.name = defaultName.isEmpty ? "泡芙" : defaultName
                dna.primaryFurHex = "#DFAA67"
                dna.secondaryFurHex = "#F7F3EA"
                dna.tertiaryFurHex = "#6E5036"
                dna.faceBlaze = .whiteMuzzle
                dna.foreheadM = true
                dna.chestBib = .fullBib
                dna.irisLeftHex = "#62C384"
                dna.irisRightHex = "#62C384"
                dna.cheekFullness = 1.14
            } else {
                dna.patternFamily = .tabby
                dna.breedBadge = "大橘虎斑"
                dna.name = defaultName.isEmpty ? "大橘" : defaultName
                dna.primaryFurHex = hexFromSum(gingerRGB, fallback: "#DE9A52")
                dna.secondaryFurHex = "#F5EBD9"
                dna.tertiaryFurHex = "#A65E2A"
                dna.faceBlaze = .whiteMuzzle
                dna.foreheadM = true
                dna.cheekStripes = true
                dna.chestBib = .none
                dna.frontLeftSock = .none
                dna.frontRightSock = .none
                dna.hindSocks = false
                dna.tailRings = true
                dna.irisLeftHex = "#E5B43C"
                dna.irisRightHex = "#E5B43C"
            }
            dna.noseHex = "#E7999B"
        } else if brownSealRatio > 0.16 && whiteRatio > 0.30 {
            if botWhiteFrac > 0.40 && topColoredFrac > 0.35 {
                dna.patternFamily = .ragdollBicolor
                dna.breedBadge = "海双布偶"
                dna.name = defaultName.isEmpty ? "布丁" : defaultName
                dna.primaryFurHex = "#4C372B"
                dna.secondaryFurHex = "#F6F2EA"
                dna.faceBlaze = .invertedV
                dna.chestBib = .fullBib
                dna.frontLeftSock = .mitten
                dna.frontRightSock = .mitten
                dna.hindSocks = true
                dna.irisLeftHex = "#6DC7F7"
                dna.irisRightHex = "#6DC7F7"
                dna.cheekFullness = 1.15
                dna.noseHex = "#ECA4A8"
            } else {
                dna.patternFamily = .colorpoint
                dna.breedBadge = "挖煤暹罗"
                dna.name = defaultName.isEmpty ? "摩卡" : defaultName
                dna.primaryFurHex = "#F2E7D5"
                dna.secondaryFurHex = "#3A281F"
                dna.faceBlaze = .sealMask
                dna.chestBib = .none
                dna.frontLeftSock = .none
                dna.frontRightSock = .none
                dna.hindSocks = false
                dna.isSleekBuild = true
                dna.irisLeftHex = "#72CBF9"
                dna.irisRightHex = "#72CBF9"
                dna.noseHex = "#2D1E1B"
            }
        } else if stripeContrast > 0.050 || ((blackRatio + brownSealRatio) > 0.28 && whiteRatio > 0.05 && whiteRatio < 0.36) {
            let hasWhiteBib = whiteRatio > 0.07
            let isDarkCharcoalTabby = nonWhiteMedianLum < 0.28 || blackRatio > 0.22
            dna.patternFamily = hasWhiteBib ? .tabbyBicolor : .tabby
            dna.breedBadge = isDarkCharcoalTabby ? (hasWhiteBib ? "黑狸花白领巾" : "黑炭狸花猫") : (greyBlueRatio > brownSealRatio ? "美短银虎斑" : "中华狸花猫")
            dna.name = defaultName.isEmpty ? "花椒" : defaultName
            dna.primaryFurHex = isDarkCharcoalTabby ? "#3D352E" : (greyBlueRatio > brownSealRatio ? "#B6BCB8" : "#6D5E4F")
            dna.secondaryFurHex = "#F5F1E8"
            dna.tertiaryFurHex = isDarkCharcoalTabby ? "#141314" : (greyBlueRatio > brownSealRatio ? "#424649" : "#241F1C")
            dna.faceBlaze = hasWhiteBib ? .noseBridgeBlaze : .whiteMuzzle
            dna.foreheadM = true
            dna.cheekStripes = true
            dna.tailRings = true
            dna.tailTipDip = true
            dna.chestBib = hasWhiteBib ? (lowerWhiteRatio > 0.38 ? .fullBib : .triangleCollar) : .locket
            dna.frontLeftSock = bottomPawsDarkRatio > 0.68 ? .none : .mitten
            dna.frontRightSock = bottomPawsDarkRatio > 0.68 ? .none : .mitten
            dna.hindSocks = bottomPawsDarkRatio < 0.55 && hasWhiteBib
            dna.earInnerHex = "#78624F"
            dna.irisLeftHex = "#5A9456"
            dna.irisRightHex = "#5A9456"
            dna.noseHex = hasWhiteBib ? "#F0A4AE" : "#B86B5E"
        } else if (blackRatio > 0.16 || greyBlueRatio > 0.22) && (whiteRatio > 0.18 || botWhiteFrac > 0.28) {
            let isBlue = greyBlueRatio > blackRatio * 1.15
            dna.patternFamily = .tuxedoBicolor
            dna.breedBadge = isBlue ? "蓝白英短" : "奶牛警长"
            dna.name = defaultName.isEmpty ? (isBlue ? "芋泥" : "警长") : defaultName
            dna.primaryFurHex = isBlue ? hexFromSum(greyRGB, fallback: "#7B8594") : "#1A1A20"
            dna.secondaryFurHex = "#F5F1E8"
            dna.tertiaryFurHex = "#34363B"
            if abs(leftTopDark - rightTopDark) > topTotal * 0.14 {
                dna.faceBlaze = leftTopDark > rightTopDark ? .skewLeft : .skewRight
            } else {
                dna.faceBlaze = .invertedV
            }
            dna.chestBib = lowerWhiteRatio > 0.35 ? .fullBib : .triangleCollar
            dna.frontLeftSock = .mitten
            dna.frontRightSock = .mitten
            dna.hindSocks = true
            dna.tailTipDip = false
            dna.cheekFullness = isBlue ? 1.14 : 1.04
            dna.irisLeftHex = isBlue ? "#DF9E38" : "#D6EA52"
            dna.irisRightHex = dna.irisLeftHex
            dna.noseHex = isBlue ? "#C97D82" : "#ECA2A6"
        } else {
            dna.patternFamily = .solid
            dna.breedBadge = "英短蓝猫"
            dna.name = defaultName.isEmpty ? "蓝宝" : defaultName
            dna.primaryFurHex = hexFromSum(greyRGB, fallback: "#757F8E")
            dna.secondaryFurHex = "#8D97A6"
            dna.faceBlaze = .none
            dna.chestBib = .none
            dna.frontLeftSock = .none
            dna.frontRightSock = .none
            dna.hindSocks = false
            dna.cheekFullness = 1.15
            dna.irisLeftHex = "#E29B32"
            dna.irisRightHex = "#E29B32"
            dna.noseHex = "#50555E"
        }

        dna.sanitize()
        let darkHexSample = hexFromSum(darkRGB, fallback: "#1C1B20")
        return LocalPrepOutput(
            croppedCatImage: croppedCat,
            previewPNG: previewPNG,
            dna: dna,
            nonWhiteMedianLum: nonWhiteMedianLum,
            nonWhiteDarkHex: darkHexSample,
            lowerWhiteRatio: lowerWhiteRatio,
            bottomPawsDarkRatio: bottomPawsDarkRatio
        )
    }
}
