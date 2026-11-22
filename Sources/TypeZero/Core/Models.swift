import Foundation

public enum SidebarTab: String, CaseIterable, Identifiable, Sendable {
    case home = "洞察总览"
    case history = "口述历史"
    case dictionary = "个人词库"
    case settings = "引擎与快捷键"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .home: return "sparkles.rectangle.stack"
        case .history: return "clock.arrow.circlepath"
        case .dictionary: return "character.book.closed"
        case .settings: return "slider.horizontal.3"
        }
    }
}

public enum DictationMode: String, Codable {
    case dictate = "口述成稿"
    case rewriteSelection = "选中改写"
}

public enum PipelinePhase: Equatable {
    case idle
    case listening(livePreview: String, mode: DictationMode)
    case polishing(rawText: String)
    case completed(finalText: String, latencyMs: Int)
    case savedToClipboard(textPreview: String)
    case error(message: String)
}

public enum TriggerKeyOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case fnKey = "fn"
    case leftOption = "leftOption"
    case rightOption = "rightOption"
    case leftCommand = "leftCommand"
    case rightCommand = "rightCommand"
    case leftControl = "leftControl"
    case rightControl = "rightControl"
    case leftShift = "leftShift"
    case rightShift = "rightShift"
    case optionSpace = "optionSpace"
    case custom = "custom"

    public var id: String { rawValue }

    /// Ordered 2×5 symmetric preset matrix (Row 1: Fn + Left/Right Option + Left/Right Command; Row 2: ⌥Space + Left/Right Control + Left/Right Shift).
    public static let presetMatrixOrder: [TriggerKeyOption] = [
        .fnKey, .leftOption, .rightOption, .leftCommand, .rightCommand,
        .optionSpace, .leftControl, .rightControl, .leftShift, .rightShift
    ]

    public var displayName: String {
        switch self {
        case .fnKey: return "Fn (地球键)"
        case .leftOption: return "左侧 Option (⌥)"
        case .rightOption: return "右侧 Option (⌥)"
        case .leftCommand: return "左侧 Command (⌘)"
        case .rightCommand: return "右侧 Command (⌘)"
        case .leftControl: return "左侧 Control (⌃)"
        case .rightControl: return "右侧 Control (⌃)"
        case .leftShift: return "左侧 Shift (⇧)"
        case .rightShift: return "右侧 Shift (⇧)"
        case .optionSpace: return "Option + Space (⌥Space)"
        case .custom: return "自定义快捷键"
        }
    }

    public var shortLabel: String {
        switch self {
        case .fnKey: return "Fn 地球键"
        case .leftOption: return "左侧 Option ⌥"
        case .rightOption: return "右侧 Option ⌥"
        case .leftCommand: return "左侧 Command ⌘"
        case .rightCommand: return "右侧 Command ⌘"
        case .leftControl: return "左侧 Control ⌃"
        case .rightControl: return "右侧 Control ⌃"
        case .leftShift: return "左侧 Shift ⇧"
        case .rightShift: return "右侧 Shift ⇧"
        case .optionSpace: return "⌥ + Space"
        case .custom: return "自定义键"
        }
    }

    public var compactSidebarLabel: String {
        switch self {
        case .fnKey: return "Fn 地球键"
        case .leftOption: return "左 Option ⌥"
        case .rightOption: return "右 Option ⌥"
        case .leftCommand: return "左 Command ⌘"
        case .rightCommand: return "右 Command ⌘"
        case .leftControl: return "左 Control ⌃"
        case .rightControl: return "右 Control ⌃"
        case .leftShift: return "左 Shift ⇧"
        case .rightShift: return "右 Shift ⇧"
        case .optionSpace: return "⌥ + Space"
        case .custom: return "自定义"
        }
    }

    /// Left-side typing modifiers frequently used in `⌘+C` / `⇧+A` / `⌃+C` combos — protected by hold-to-talk combo debounce.
    public var isComboProneLeftModifier: Bool {
        switch self {
        case .leftOption, .leftCommand, .leftControl, .leftShift:
            return true
        default:
            return false
        }
    }

    public var isSingleModifierKey: Bool {
        switch self {
        case .optionSpace, .custom:
            return false
        default:
            return true
        }
    }
}

public struct CustomHotkeySpec: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var carbonModifiers: UInt32
    public var label: String

    /// Default custom shortcut: `⌃ + Space` (`kVK_Space = 49`, `controlKey = 4096`)
    public static let `default` = CustomHotkeySpec(keyCode: 49, carbonModifiers: 4096, label: "⌃ + Space")

    public init(keyCode: UInt16, carbonModifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.label = label
    }
}

public enum ASRProviderOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case volcSeedASR = "volcSeedASR"
    case openAIWhisper = "openAIWhisper"
    case localSenseVoice = "localSenseVoice"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .volcSeedASR: return "豆包流式语音大模型 2.0"
        case .openAIWhisper: return "OpenAI / Groq 云端语音大模型"
        case .localSenseVoice: return "纯本机 SenseVoice FP32 离线满血模型"
        }
    }

    public var shortName: String {
        switch self {
        case .volcSeedASR: return "豆包 Seed-ASR"
        case .openAIWhisper: return "OpenAI / Groq"
        case .localSenseVoice: return "本机 SenseVoice"
        }
    }
}

public enum LLMProviderOption: String, CaseIterable, Codable, Identifiable, Sendable {
    case deepseek = "deepseek"
    case volcengine = "volcengine"
    case dashscope = "dashscope"
    case openai = "openai"
    case gemini = "gemini"
    case anthropic = "anthropic"
    case custom = "custom"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .deepseek: return "DeepSeek 4 Flash"
        case .volcengine: return "火山方舟 Doubao-Seed"
        case .dashscope: return "阿里百炼 Qwen-Flash"
        case .openai: return "OpenAI GPT"
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        case .custom: return "自定义 OpenAI 兼容接口"
        }
    }

    public var shortName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .volcengine: return "火山方舟"
        case .dashscope: return "阿里百炼"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .anthropic: return "Claude"
        case .custom: return "自定义接口"
        }
    }

    public var subtitle: String {
        switch self {
        case .deepseek: return "极速主力推荐 · KV 缓存命中约 210ms 首包"
        case .volcengine: return "字节豆包大模型 · 支持 Seed-2.1-lite 或 ep- 接入点"
        case .dashscope: return "阿里云百炼兼容模式 · 通义极速轻量模型"
        case .openai: return "OpenAI 官方直连 · 兼容 gpt-4.1-mini / gpt-5-mini / gpt-4o-mini"
        case .gemini: return "Google AI Studio 官方兼容通道 · 支持 gemini-3.8-flash / 2.5-flash"
        case .anthropic: return "Anthropic 原生 Messages 流式协议 · 支持 claude-haiku-5-5 / 4-5"
        case .custom: return "支持 SiliconFlow / OpenRouter / MiniMax / 本地 Ollama"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/v1"
        case .volcengine: return "https://ark.cn-beijing.volces.com/api/v3"
        case .dashscope: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .openai: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .custom: return "https://api.siliconflow.cn/v1"
        }
    }

    public var defaultModelName: String {
        switch self {
        case .deepseek: return "deepseek-flash"
        case .volcengine: return "doubao-seed-2-1-lite-260915"
        case .dashscope: return "qwen-flash"
        case .openai: return "gpt-4.1-mini"
        case .gemini: return "gemini-3.8-flash"
        case .anthropic: return "claude-haiku-5-5"
        case .custom: return "deepseek-ai/DeepSeek-V3"
        }
    }

    public static func infer(from baseURL: String) -> LLMProviderOption {
        let u = baseURL.lowercased()
        if u.contains("deepseek.com") { return .deepseek }
        if u.contains("volces.com") || u.contains("volcengine") { return .volcengine }
        if u.contains("aliyuncs.com") { return .dashscope }
        if u.contains("openai.com") { return .openai }
        if u.contains("generativelanguage.googleapis.com") { return .gemini }
        if u.contains("anthropic.com") { return .anthropic }
        return .custom
    }
}

public enum TriggerBehavior: String, CaseIterable, Codable, Identifiable {
    case tapToggle = "tapToggle"
    case holdToTalk = "holdToTalk"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tapToggle: return "按一下开始 · 再按停止（免按住）"
        case .holdToTalk: return "按住说话 · 松开停止"
        }
    }
}

public enum FormattingStyle: String, CaseIterable, Codable, Identifiable {
    case structured = "structured"
    case lightPolish = "lightPolish"
    case verbatimLocal = "verbatimLocal"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .structured: return "结构化精炼（去语病 · 自动分段/1.2.3.列点）"
        case .lightPolish: return "轻度纠错（仅删嗯啊 · 保留原句式）"
        case .verbatimLocal: return "纯本地直出（零云端 · 原声秒出）"
        }
    }
}

public enum LexiconCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case person = "人名/称呼"
    case project = "项目/技术"
    case finance = "标的/商业"
    case memo = "纪要/备忘"
    case browser = "浏览高频"
    case autoLearned = "纠错自学习"

    public var id: String { rawValue }
}

public struct LexiconEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var term: String
    public var aliases: [String]
    public var phoneticKey: String
    public var category: LexiconCategory
    public var weight: Int
    public var hitCount: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        term: String,
        aliases: [String] = [],
        phoneticKey: String = "",
        category: LexiconCategory = .project,
        weight: Int = 1,
        hitCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.aliases = aliases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.phoneticKey = phoneticKey.isEmpty ? PhoneticIndexer.normalize(term) : phoneticKey
        self.category = category
        self.weight = weight
        self.hitCount = hitCount
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.term = (try? c.decode(String.self, forKey: .term)) ?? ""
        self.aliases = (try? c.decode([String].self, forKey: .aliases)) ?? []
        let decodedPhonetic = (try? c.decode(String.self, forKey: .phoneticKey)) ?? ""
        self.phoneticKey = decodedPhonetic.isEmpty ? PhoneticIndexer.normalize(self.term) : decodedPhonetic
        self.category = (try? c.decode(LexiconCategory.self, forKey: .category)) ?? .project
        self.weight = (try? c.decode(Int.self, forKey: .weight)) ?? 5
        self.hitCount = (try? c.decode(Int.self, forKey: .hitCount)) ?? 0
        self.createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

public struct DictationRecord: Identifiable, Codable {
    public var id: UUID
    public var timestamp: Date
    public var rawTranscript: String
    public var polishedText: String
    public var durationSeconds: Double
    public var polishLatencyMs: Int
    public var targetAppName: String
    public var mode: DictationMode
    public var matchedTerms: [String]

    public var characterCount: Int {
        polishedText.count
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawTranscript: String,
        polishedText: String,
        durationSeconds: Double,
        polishLatencyMs: Int,
        targetAppName: String,
        mode: DictationMode = .dictate,
        matchedTerms: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawTranscript = rawTranscript
        self.polishedText = polishedText
        self.durationSeconds = max(0.2, durationSeconds)
        self.polishLatencyMs = polishLatencyMs
        self.targetAppName = targetAppName
        self.mode = mode
        self.matchedTerms = matchedTerms
    }
}

public struct LLMConfig: Codable, Equatable {
    public var selectedProvider: LLMProviderOption
    public var baseURL: String
    public var modelName: String
    public var customBaseURL: String
    public var providerModels: [String: String]
    public var formattingStyle: FormattingStyle
    public var asrProvider: ASRProviderOption
    public var openAIASRBaseURL: String
    public var openAIASRModel: String
    public var enableVolcSeedASR: Bool
    public var enableLiveInlineTyping: Bool
    public var enableFastBypassForShortPhrases: Bool
    public var stripTrailingPeriodInChatApps: Bool
    public var enablePanguSpacing: Bool
    public var enableWhisperAGC: Bool
    public var enableAutoLearn: Bool
    public var enableAutoMuteDuringDictation: Bool
    public var showInDock: Bool
    public var speechLocale: String
    public var useOfficialCloudTrial: Bool

    public static let `default` = LLMConfig()

    public init(
        selectedProvider: LLMProviderOption? = nil,
        baseURL: String = "https://api.deepseek.com/v1",
        modelName: String = "deepseek-flash",
        customBaseURL: String = "https://api.siliconflow.cn/v1",
        providerModels: [String: String] = [:],
        formattingStyle: FormattingStyle = .structured,
        asrProvider: ASRProviderOption? = nil,
        openAIASRBaseURL: String = "https://api.openai.com/v1",
        openAIASRModel: String = "gpt-4o-mini-transcribe",
        enableVolcSeedASR: Bool = true,
        enableLiveInlineTyping: Bool = false,
        enableFastBypassForShortPhrases: Bool = true,
        stripTrailingPeriodInChatApps: Bool = true,
        enablePanguSpacing: Bool = true,
        enableWhisperAGC: Bool = true,
        enableAutoLearn: Bool = true,
        enableAutoMuteDuringDictation: Bool = true,
        showInDock: Bool = false,
        speechLocale: String = "zh-CN",
        useOfficialCloudTrial: Bool = false
    ) {
        let resolvedProvider = selectedProvider ?? LLMProviderOption.infer(from: baseURL)
        self.selectedProvider = resolvedProvider
        self.baseURL = baseURL
        self.modelName = modelName
        self.customBaseURL = (resolvedProvider == .custom && !baseURL.isEmpty) ? baseURL : customBaseURL
        var mergedModels = providerModels
        mergedModels[resolvedProvider.rawValue] = modelName
        self.providerModels = mergedModels
        self.formattingStyle = formattingStyle
        let resolvedASR = asrProvider ?? (enableVolcSeedASR ? .volcSeedASR : .localSenseVoice)
        self.asrProvider = resolvedASR
        self.openAIASRBaseURL = openAIASRBaseURL
        self.openAIASRModel = openAIASRModel
        self.enableVolcSeedASR = (resolvedASR == .volcSeedASR)
        self.enableLiveInlineTyping = enableLiveInlineTyping
        self.enableFastBypassForShortPhrases = enableFastBypassForShortPhrases
        self.stripTrailingPeriodInChatApps = stripTrailingPeriodInChatApps
        self.enablePanguSpacing = enablePanguSpacing
        self.enableWhisperAGC = enableWhisperAGC
        self.enableAutoLearn = enableAutoLearn
        self.enableAutoMuteDuringDictation = enableAutoMuteDuringDictation
        self.showInDock = showInDock
        self.speechLocale = speechLocale
        self.useOfficialCloudTrial = useOfficialCloudTrial
    }

    public mutating func selectASRProvider(_ provider: ASRProviderOption) {
        asrProvider = provider
        enableVolcSeedASR = (provider == .volcSeedASR)
    }

    public mutating func selectProvider(_ provider: LLMProviderOption) {
        // Persist current provider's edits before switching
        providerModels[selectedProvider.rawValue] = modelName
        if selectedProvider == .custom && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            customBaseURL = baseURL
        }
        selectedProvider = provider
        baseURL = (provider == .custom) ? customBaseURL : provider.defaultBaseURL
        let savedModel = providerModels[provider.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        modelName = savedModel.isEmpty ? provider.defaultModelName : savedModel
    }

    public mutating func syncActiveEndpointEdits() {
        providerModels[selectedProvider.rawValue] = modelName
        if selectedProvider == .custom && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            customBaseURL = baseURL
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedURL = (try? c.decode(String.self, forKey: .baseURL)) ?? "https://api.deepseek.com/v1"
        let decodedModel = (try? c.decode(String.self, forKey: .modelName)) ?? "deepseek-flash"
        let upgradedModel = (decodedModel == "deepseek-chat" || decodedModel.isEmpty) ? "deepseek-flash" : decodedModel
        let inferredProvider = LLMProviderOption.infer(from: decodedURL)
        let resolvedProvider = (try? c.decode(LLMProviderOption.self, forKey: .selectedProvider)) ?? inferredProvider

        self.selectedProvider = resolvedProvider
        self.baseURL = decodedURL
        self.modelName = upgradedModel
        let decodedCustomURL = (try? c.decode(String.self, forKey: .customBaseURL)) ?? ""
        if !decodedCustomURL.isEmpty {
            self.customBaseURL = decodedCustomURL
        } else {
            self.customBaseURL = (resolvedProvider == .custom) ? decodedURL : LLMProviderOption.custom.defaultBaseURL
        }
        var modelsMap = (try? c.decode([String: String].self, forKey: .providerModels)) ?? [:]
        if let savedEp = UserDefaults.standard.string(forKey: "tz_ark_ep_id"),
           !savedEp.isEmpty,
           modelsMap[LLMProviderOption.volcengine.rawValue] == nil {
            modelsMap[LLMProviderOption.volcengine.rawValue] = savedEp
        }
        modelsMap[resolvedProvider.rawValue] = upgradedModel
        self.providerModels = modelsMap

        self.formattingStyle = (try? c.decode(FormattingStyle.self, forKey: .formattingStyle)) ?? .structured
        let legacyVolcFlag = (try? c.decode(Bool.self, forKey: .enableVolcSeedASR)) ?? true
        let resolvedASR = (try? c.decode(ASRProviderOption.self, forKey: .asrProvider))
            ?? (legacyVolcFlag ? .volcSeedASR : .localSenseVoice)
        self.asrProvider = resolvedASR
        let decodedOpenAIASRURL = (try? c.decode(String.self, forKey: .openAIASRBaseURL)) ?? "https://api.openai.com/v1"
        self.openAIASRBaseURL = decodedOpenAIASRURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "https://api.openai.com/v1" : decodedOpenAIASRURL
        let decodedOpenAIASRModel = (try? c.decode(String.self, forKey: .openAIASRModel)) ?? "gpt-4o-mini-transcribe"
        self.openAIASRModel = decodedOpenAIASRModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "gpt-4o-mini-transcribe" : decodedOpenAIASRModel
        self.enableVolcSeedASR = (resolvedASR == .volcSeedASR)
        self.enableLiveInlineTyping = (try? c.decode(Bool.self, forKey: .enableLiveInlineTyping)) ?? false
        self.enableFastBypassForShortPhrases = (try? c.decode(Bool.self, forKey: .enableFastBypassForShortPhrases)) ?? true
        self.stripTrailingPeriodInChatApps = (try? c.decode(Bool.self, forKey: .stripTrailingPeriodInChatApps)) ?? true
        self.enablePanguSpacing = (try? c.decode(Bool.self, forKey: .enablePanguSpacing)) ?? true
        self.enableWhisperAGC = (try? c.decode(Bool.self, forKey: .enableWhisperAGC)) ?? true
        self.enableAutoLearn = (try? c.decode(Bool.self, forKey: .enableAutoLearn)) ?? true
        self.enableAutoMuteDuringDictation = (try? c.decode(Bool.self, forKey: .enableAutoMuteDuringDictation)) ?? true
        self.showInDock = (try? c.decode(Bool.self, forKey: .showInDock)) ?? false
        self.speechLocale = (try? c.decode(String.self, forKey: .speechLocale)) ?? "zh-CN"
        self.useOfficialCloudTrial = (try? c.decode(Bool.self, forKey: .useOfficialCloudTrial)) ?? false
    }
}
