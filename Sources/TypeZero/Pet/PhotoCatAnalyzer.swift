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
        case .none:          return "纯色面庞"
        case .invertedV:     return "正八字开脸"
        case .skewLeft:      return "左偏刘海"
        case .skewRight:     return "右偏刘海"
        case .helmetCap:     return "齐眉警长帽"
        case .splitHalf:     return "阴阳半脸"
        case .eyePatchLeft:  return "左眼海盗斑"
        case .eyePatchRight: return "右眼海盗斑"
        case .whiteMuzzle:   return "奶白嘴套"
        case .sealMask:      return "挖煤渐变脸"
        }
    }
}

public enum CatChestBibStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "none"
    case locket = "locket"
    case fullBib = "full_bib"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none:    return "无白胸"
        case .locket:  return "胸口小撮白"
        case .fullBib: return "大白胸围脖"
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

// MARK: - Dual-Engine Photo Analyzer (Cloud/BYOK Vision VLM + Native macOS Vision Foreground Fallback)

public enum PhotoCatAnalyzer {
    private static let visionSystemPrompt = """
    你是顶级猫咪品种、毛色遗传学与 2D 矢量角色美术总监。请仔细观察用户上传的猫咪照片，剥离室内黄光/阴影色偏（例如白毛在暖光下仍应还原为纯净奶白 #F5F1E8 而非脏黄，纯黑毛还原为深邃绒黑 #1C1B20），输出严格符合以下字段的纯 JSON 对象（不要输出任何 Markdown 代码块或额外解释）：
    {
      "breedBadge": "简短花色品种名，如 海双布偶 / 三花小猫 / 奶牛警长 / 金渐层英短 / 狸花白手套 / 橘白起司 / 纯白异瞳",
      "patternFamily": "solid | tuxedo_bicolor | tabby | tabby_bicolor | calico | tortoiseshell | colorpoint | ragdoll_bicolor | shaded | van",
      "faceBlaze": "none | inverted_v | skew_left | skew_right | helmet_cap | split_half | eye_patch_left | eye_patch_right | white_muzzle | seal_mask",
      "blazeWidth": 0.56,
      "foreheadM": false,
      "cheekStripes": false,
      "chinSpot": false,
      "chestBib": "none | locket | full_bib",
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
    关键色彩语义约定：
    1. solid（纯色猫）：primaryFurHex 为通体主毛色。
    2. tuxedo_bicolor（奶牛/蓝白/橘白等双色加白猫）：primaryFurHex 填有色毛（如黑 #1C1B20 / 蓝灰 #7B8594 / 橘 #DB964D），secondaryFurHex 填奶白毛（#F5F1E8）；根据面部白色开脸形状选择 faceBlaze（正八字选 inverted_v 并给 blazeWidth 0.35~0.80；偏分选 skew_left/skew_right；齐眉黑帽白下半脸选 helmet_cap；单眼斑选 eye_patch_left/right）。
    3. ragdoll_bicolor（海双/蓝双布偶）：primaryFurHex 填重点耳背深色（海豹褐 #4A3529 或蓝灰 #8792A1），secondaryFurHex 填奶白 #F6F2EA，faceBlaze 选 inverted_v，irisLeftHex/irisRightHex 填冰湖蓝 #6BC5F8，cheekFullness 1.12~1.20。
    4. colorpoint（暹罗/重点色挖煤）：primaryFurHex 填身体浅奶油色 #F3E8D6，secondaryFurHex 填挖煤重点深色 #3A281F，faceBlaze 选 seal_mask。
    5. calico（三花）：primaryFurHex 填奶白底色 #F5F1E8，secondaryFurHex 填暖橘斑 #DC8E43，tertiaryFurHex 填墨黑灰斑 #252429。
    6. tortoiseshell（玳瑁）：primaryFurHex 填深褐黑底 #26201E，secondaryFurHex 填琥珀金橘斑 #D68A3E，tertiaryFurHex 填暖奶油斑 #E6BA7E。
    7. tabby / tabby_bicolor（狸花/美短/橘虎斑）：primaryFurHex 填底毛色，secondaryFurHex 填奶白胸腹色 #F4EFE6，tertiaryFurHex 填深色虎斑条纹色（如黑褐 #34302D、深银灰 #4E5356 或深橘 #A65E2A），foreheadM=true，cheekStripes=true，tailRings=true。
    8. shaded（金渐层/银渐层）：primaryFurHex 填背顶渐层暖杏金 #DFAA67 或浅银灰 #C5CAC8，secondaryFurHex 填下颌胸腹奶白 #F7F4EC，tertiaryFurHex 填柔和细纹/尾尖深色 #6E5238 或 #5B6063。
    9. 异瞳鸳鸯眼（heterochromia=true）时分别准确填写猫自身左眼（画面右侧）与右眼（画面左侧）虹膜颜色；若闭眼看不到瞳色，请按该品种最经典高颜值瞳色补全。
    """

    public static func analyzeImage(
        at url: URL,
        preferredName: String = "",
        llmConfig: LLMConfig,
        byokAPIKey: String,
        cloudJWT: String
    ) async throws -> CatPhotoAnalysisResult {
        guard let cgImage = loadOrientedCGImage(from: url, maxPixelSize: 1024) else {
            throw NSError(domain: "PhotoCatAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取该图片，请选择 JPG / PNG / HEIC / WebP 格式的猫咪照片"])
        }
        return await analyzeCGImage(
            cgImage,
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
        // Stage 0: Fast on-device Apple Vision cat detection + foreground mask + avatar crop + local baseline DNA
        let localPrep = prepareLocalVisionFeatures(from: cgImage, preferredName: preferredName)

        // Stage 1: Try Multimodal Vision LLM (Personal BYOK -> Official TypeZero Cloud) for semantic & blaze precision
        if let jpegData = encodeJPEG(localPrep.croppedCatImage, maxDimension: 640, compression: 0.78) {
            let dataURL = "data:image/jpeg;base64," + jpegData.base64EncodedString()

            // Path A: User's personal BYOK key if configured
            let trimmedBYOK = byokAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !llmConfig.useOfficialCloudTrial && !trimmedBYOK.isEmpty {
                if var remoteDNA = await requestBYOKVisionDNA(dataURL: dataURL, config: llmConfig, apiKey: trimmedBYOK) {
                    if !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        remoteDNA.name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        remoteDNA.name = localPrep.dna.name
                    }
                    remoteDNA.sanitize()
                    return CatPhotoAnalysisResult(
                        dna: remoteDNA,
                        previewPNG: localPrep.previewPNG,
                        usedVisionModel: true,
                        sourceSummary: "✨ 多模态视觉精修 · \(remoteDNA.breedBadge)"
                    )
                }
            }

            // Path B: Official TypeZero Cloud `/api/pet/analyze-photo`
            let trimmedJWT = cloudJWT.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedJWT.isEmpty {
                if var cloudDNA = await requestOfficialCloudVisionDNA(dataURL: dataURL, jwt: trimmedJWT) {
                    if !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        cloudDNA.name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        cloudDNA.name = localPrep.dna.name
                    }
                    cloudDNA.sanitize()
                    return CatPhotoAnalysisResult(
                        dna: cloudDNA,
                        previewPNG: localPrep.previewPNG,
                        usedVisionModel: true,
                        sourceSummary: "✨ 云端视觉深度还原 · \(cloudDNA.breedBadge)"
                    )
                }
            }

            // Path C: Fallback to BYOK even if `useOfficialCloudTrial` was on but cloud wasn't reachable
            if !trimmedBYOK.isEmpty {
                if var remoteDNA = await requestBYOKVisionDNA(dataURL: dataURL, config: llmConfig, apiKey: trimmedBYOK) {
                    if !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        remoteDNA.name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        remoteDNA.name = localPrep.dna.name
                    }
                    remoteDNA.sanitize()
                    return CatPhotoAnalysisResult(
                        dna: remoteDNA,
                        previewPNG: localPrep.previewPNG,
                        usedVisionModel: true,
                        sourceSummary: "✨ 视觉模型深度还原 · \(remoteDNA.breedBadge)"
                    )
                }
            }
        }

        // Stage 2: Instant zero-dependency On-Device Apple Vision result (100% offline capable!)
        return CatPhotoAnalysisResult(
            dna: localPrep.dna,
            previewPNG: localPrep.previewPNG,
            usedVisionModel: false,
            sourceSummary: "⚡️ 本机 Vision 前景提取 · \(localPrep.dna.breedBadge)（可在右侧自由微调细节）"
        )
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

    private static func requestOfficialCloudVisionDNA(dataURL: String, jwt: String) async -> CatPhotoDNA? {
        guard let url = URL(string: "\(CloudAuthClient.baseURL)/api/pet/analyze-photo") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 14.0
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["imageDataUrl": dataURL]
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

    private static func requestBYOKVisionDNA(dataURL: String, config: LLMConfig, apiKey: String) async -> CatPhotoDNA? {
        let base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty else { return nil }

        // Anthropic Messages native vision format
        if PolishEngine.isAnthropicEndpoint(base) {
            let endpoint = PolishEngine.normalizeAnthropicMessagesEndpoint(base)
            guard let url = URL(string: endpoint) else { return nil }
            let rawB64 = dataURL.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            let payload: [String: Any] = [
                "model": config.modelName.isEmpty ? "claude-haiku-5-5" : config.modelName,
                "max_tokens": 520,
                "system": visionSystemPrompt,
                "messages": [[
                    "role": "user",
                    "content": [
                        ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": rawB64]],
                        ["type": "text", "text": "请提取这只猫咪的花色、开脸、五官与毛色 JSON。"]
                    ]
                ]]
            ]
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 15.0
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
        var payload: [String: Any] = [
            "model": model.isEmpty ? "deepseek-flash" : model,
            "stream": false,
            "max_tokens": 520,
            "messages": [
                ["role": "system", "content": visionSystemPrompt],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "请提取这只猫咪的花色、开脸、五官与毛色 JSON。"],
                        ["type": "image_url", "image_url": ["url": dataURL]]
                    ]
                ]
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
        } else if (blackRatio > 0.16 || greyBlueRatio > 0.22) && (whiteRatio > 0.18 || botWhiteFrac > 0.28) {
            let isBlue = greyBlueRatio > blackRatio * 1.15
            dna.patternFamily = stripeContrast > 0.068 ? .tabbyBicolor : .tuxedoBicolor
            dna.breedBadge = isBlue ? "蓝白英短" : "奶牛警长"
            dna.name = defaultName.isEmpty ? (isBlue ? "芋泥" : "警长") : defaultName
            dna.primaryFurHex = isBlue ? hexFromSum(greyRGB, fallback: "#7B8594") : "#1E1E24"
            dna.secondaryFurHex = "#F5F1E8"
            dna.tertiaryFurHex = "#44484D"
            if abs(leftTopDark - rightTopDark) > topTotal * 0.14 {
                dna.faceBlaze = leftTopDark > rightTopDark ? .skewLeft : .skewRight
            } else {
                dna.faceBlaze = .invertedV
            }
            dna.chestBib = .fullBib
            dna.frontLeftSock = .mitten
            dna.frontRightSock = .mitten
            dna.hindSocks = true
            dna.cheekFullness = isBlue ? 1.14 : 1.04
            dna.irisLeftHex = isBlue ? "#DF9E38" : "#D6EA52"
            dna.irisRightHex = dna.irisLeftHex
            dna.noseHex = isBlue ? "#C97D82" : "#ECA2A6"
        } else if stripeContrast > 0.058 {
            dna.patternFamily = .tabby
            dna.breedBadge = greyBlueRatio > brownSealRatio ? "美短银虎斑" : "中华狸花猫"
            dna.name = defaultName.isEmpty ? "虎子" : defaultName
            dna.primaryFurHex = greyBlueRatio > brownSealRatio ? "#BFC4C0" : "#8D7B68"
            dna.secondaryFurHex = "#F2EEE4"
            dna.tertiaryFurHex = greyBlueRatio > brownSealRatio ? "#4B4F52" : "#2D2723"
            dna.faceBlaze = .whiteMuzzle
            dna.foreheadM = true
            dna.cheekStripes = true
            dna.tailRings = true
            dna.chestBib = .locket
            dna.irisLeftHex = "#C8D062"
            dna.irisRightHex = "#C8D062"
            dna.noseHex = "#B86B5E"
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
        return LocalPrepOutput(croppedCatImage: croppedCat, previewPNG: previewPNG, dna: dna)
    }
}
