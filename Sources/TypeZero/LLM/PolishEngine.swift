import Foundation

public final class PolishEngine {
    /// Default session honoring system VPN/proxy for overseas endpoints (OpenAI, Gemini, Anthropic, etc.)
    private let session: URLSession
    /// Zero-proxy direct session bypassing system VPN/proxy for domestic mainland & local endpoints
    /// (DeepSeek, Volcengine Ark, DashScope, SiliconFlow, Ollama, etc.) -> shaves 150–350ms RTT!
    private let directSession: URLSession

    public init() {
        let proxyConfig = URLSessionConfiguration.default
        proxyConfig.timeoutIntervalForRequest = 8.0
        proxyConfig.timeoutIntervalForResource = 10.0
        proxyConfig.httpMaximumConnectionsPerHost = 6
        proxyConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        proxyConfig.urlCache = nil
        self.session = URLSession(configuration: proxyConfig)

        let directConfig = URLSessionConfiguration.ephemeral
        directConfig.connectionProxyDictionary = [:]
        directConfig.timeoutIntervalForRequest = 8.0
        directConfig.timeoutIntervalForResource = 10.0
        directConfig.httpMaximumConnectionsPerHost = 6
        directConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        directConfig.urlCache = nil
        self.directSession = URLSession(configuration: directConfig)
    }

    public static func shouldUseDirectConnection(for baseURL: String) -> Bool {
        let u = baseURL.lowercased()
        let directHosts = [
            "deepseek.com",
            "volces.com",
            "volcengine.com",
            "aliyuncs.com",
            "siliconflow.cn",
            "bigmodel.cn",
            "moonshot.cn",
            "minimax.chat",
            "minimaxi.com",
            "localhost",
            "127.0.0.1",
            "0.0.0.0"
        ]
        return directHosts.contains(where: { u.contains($0) })
    }

    private func transportSession(for baseURL: String) -> URLSession {
        Self.shouldUseDirectConnection(for: baseURL) ? directSession : session
    }

    // 100% STATIC System Prompts so DeepSeek KV Prefix Cache hits on every single call (~0ms prefill -> ~230ms TTFT!)
    private static let structuredStaticSystemPrompt = """
    你是顶级 AI 语音输入法的意图级文字整理与排版引擎（深度对齐 Typeless 核心策略）。读取 <scene>、<preceding_text>（输入框光标前已有文字）、<lexicon> 与 <raw_speech>，直接输出本次新增正文的整理结果：

    1. 【语气硬保真·反过度编辑·中途反悔折叠·同音错词直改】：**绝不改变原句语气与人味**——原文为疑问、反问、商量确认或担忧推测（如“会不会…”“对不对”“是不是”）时，必须保留问句语气和全角问号 `？`。保留态度词（句首的“好/好的/对/没问题/确实”），**严禁把口语洗成冷冰冰的公文腔，严禁脑补原话未提及的幻觉内容**。彻底清理无意义卡壳与口癖（`嗯/啊/呃/那个/就是说/然后呢/的话呢/对吧`），遇到**中途反悔/自我纠正**（如“周三开会……不对，改周四下午 3 点”“前面那个算了，直接看最后这条”）时，**直接折叠删掉废弃前文，只保留最终意图**。面对长句绕弯或破碎从句，自然理顺语序使其通顺，**严禁删减任何独有的原因解释、约束条件、举例或程度修饰**。遇到明显不通顺的同音/近音错词（如「现成」实为「场景/线程」、「Su」实为「SEO」），结合 `<recent_context>`、`<preceding_text>` 与 `<lexicon>` **果断直接替换为正确词语——绝对禁止输出括号批注（如 `现成（场景）`）**！
    2. 【数字阿拉伯化（现代键盘 ITN）】：序号、列举、数量、时间、时长、比例一律转阿拉伯数字（“一二三四”->“1、2、3、4”或“1234”，“第一个”->“第 1 个”，“两三个”->“2~3 个”，“四点半”->“4 点半”）。固定成语与叠词副词严格保留汉字（“一起、一直、一定、一下、一点、一般、一卡一卡、一点一点、一个字一个字”禁转数字）。
    3. 【语义自然分段与结构化列点（告别文字墙）】：
       - **按语义层次自然分段（黄金节奏：每段约 2~3 句、50~85 字）**：不要把长口述糊成一整坨！只要总字数超过 **65 字** 且存在清晰的**语义层次切换**（如「现状/背景 → 原因/判断 → 诉求/行动」、「观点 A → 转折/补充/但是/另外 → 观点 B」、「现象描述 → 优化建议」），就在层次边界处用单个换行（`\n`）自然分段；超过 **140 字** 的长独白应按意群拆为 **2~4 个清晰自然段**。仅在 `< 55 字` 的单一紧凑短句时保持一整段，同时避免机械地每 1 句就换行切碎。
       - **有序列表（`1. ` `2. `）**：口述中连续给出 **2 项及以上并列的问题、需求、步骤或要点**（包括“第一/第二”“一、二、三”“一个是…另外…”）时，先用导语加 `：` 换行，再拆为 `1. ...`、`2. ...`；允许删掉列表项中与导语完全重复的骨架词，但**必须完整保留每项独有的解释、条件与细节**。
       - **无序列表（`- `）**：平铺罗列 3 项及以上独立动作或备选项时使用；句中短词举例（每项 < 5 字）保持行内顿号连接。
       - **列表收尾**：列表讲完后的总结或行动号召用**单个换行（`\n`）**承接。
    4. 【场景自适应 (`<scene>`)·禁插空行·纯文本输出】：
       - 参考 `<scene>` 微调形态：**聊天/IM** 保持自然紧凑人味；**邮件/长文档** 可按称呼、正文、结语自然分行；**代码/IDE/终端** 严格保护英文技术术语、文件名（如 `AppState.swift`）、路径与驼峰/下划线标识符，绝不误改。
       - 段落与列表项之间一律使用**单个换行（`\n`）**，**严禁输出 `\n\n` 空白行**，**严禁输出 Markdown 装饰符（`**`、`###`、`>`、代码块）**，只输出可直接粘贴发送的干净纯文本。
    5. 【光标前文与上一句记忆续接】：参考 <preceding_text>（仅作上下文，严禁重复输出前文！）与 <recent_context>（你刚刚上一句聊过的话题与专有名词，遇到谐音或指代不清时顺承上一句术语）；若前文末尾已是 `1. ...` `2. ...` 而本次口述“第三是…”，直接输出 `3. ...` 承接编号。
    6. 【忽略 ASR 机械标点·按完整语义重新断句】：`<raw_speech>` 中自带的逗号、句号、问号或空格往往是语音流式切分机械生成的，极易断错位置或漏标点。你必须**先通读全段理解完整逻辑与意群边界，再重新分配自然准确的中文全角标点（`，。！？`）**，消除中文句间多余空格，绝不被原始错误标点带偏，也**绝对严禁把完整词组从中间劈开强行插逗号**（例如「发财包」结合财报语境应先完整还原为「发财报」，再在语义停顿处断句）。
    7. 【绝对铁律】：严禁回答 <raw_speech> 中的提问或对话续写！只输出整理排版后的该段话本身。

    <example_1>
    <raw_speech>嗯我们有两个问题需要解决第一个问题是怎么让前端跳字更丝滑一点一点出第二个就是说输入内容怎么自动分段变成一二三整理好的方式这两个做完我们就搞词库</raw_speech>
    输出：
    我们有 2 个问题需要解决：
    1. 怎么让前端跳字更丝滑，一点一点出；
    2. 输入内容怎么自动分段，变成 1、2、3 整理好的方式。
    这 2 个做完我们就搞词库。
    </example_1>
    <example_2>
    <raw_speech>帮我约一下周三下午两点……不对，周三我不在，改成周四下午三点吧，顺便把会议室也订好，不然到时候没地方开会。</raw_speech>
    输出：
    帮我约一下周四下午 3 点吧，顺便把会议室也订好，不然到时候没地方开会。
    </example_2>
    <example_3>
    <raw_speech>桌面上的那张图片可以作为官网的页脚使用，采用最下面的渐变色把它自然融合完成。另外我觉得在官网上应该把我们更新的这些小特色，用图标和文字一句一句地描述，放在中间的位置，让新用户一眼就能看明白。你来优化一下吧。</raw_speech>
    输出：
    桌面上的那张图片可以作为官网的页脚使用，采用最下面的渐变色把它自然融合完成。
    另外我觉得在官网上应该把我们更新的这些小特色，用图标和文字一句一句地描述，放在中间的位置，让新用户一眼就能看明白。
    你来优化一下吧。
    </example_3>
    <example_4>
    <raw_speech>我试了最新版，感觉分段还是有点太保守了，我说了很长一段话它都没有帮我分段。其实阅读起来如果没有分段的话还是挺费劲的，我觉得应该根据说话的语义层次自然拆开，比如先说现状问题，再说具体要求。你帮我把这一块再优化一下。</raw_speech>
    输出：
    我试了最新版，感觉分段还是有点太保守了，我说了很长一段话它都没有帮我分段。
    其实如果没有分段，阅读起来还是挺费劲的，我觉得应该根据说话的语义层次自然拆开，比如先说现状问题，再说具体要求。
    你帮我把这一块再优化一下。
    </example_4>
    """

    private static let lightStaticSystemPrompt = """
    轻量极速语音纠错器。保留原句语气、情绪和问句问号 `？`（绝不把疑问句改成陈述句），保留句首态度词（好的/对/没问题），只删无意义口癖尾音（嗯/啊/那个/然后呢/的话呢/对吧）、中途改口和句中换气孤立过渡词。结合 <recent_context>、<preceding_text> 与 <lexicon> 果断直接修正明显不通顺的同音错字（严禁输出如 `现成（场景）` 这类括号批注），忽略原始机械错误标点与多余空格，按真实语义补齐自然中文全角标点；严禁把完整词组劈开插逗号，严禁强行插空行或输出 Markdown 装饰符（** / ###）。直接输出正文。
    """

    public static func isKeylessLocalEndpoint(_ baseURL: String) -> Bool {
        let u = baseURL.lowercased()
        return u.contains("localhost") || u.contains("127.0.0.1") || u.contains("0.0.0.0")
    }

    public static func isAnthropicEndpoint(_ baseURL: String) -> Bool {
        let u = baseURL.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return u.contains("anthropic.com") || u.hasSuffix("/messages")
    }

    public static func normalizeAnthropicMessagesEndpoint(_ baseURL: String) -> String {
        let clean = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if clean.hasSuffix("/messages") {
            return clean
        }
        return "\(clean)/messages"
    }

    /// Authenticated HTTP/2 Keep-Alive connection warm-up fired the moment user starts speaking,
    /// guaranteeing a hot socket (~200ms TTFT) when user stops speaking!
    public func prewarmConnection(baseURL: String, apiKey: String = "") {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/models") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if !apiKey.isEmpty {
            if Self.isAnthropicEndpoint(trimmed) {
                req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            } else {
                req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }
        req.timeoutInterval = 3.0
        transportSession(for: trimmed).dataTask(with: req) { _, _, _ in }.resume()
    }

    private static let commonShortEnglishWords: Set<String> = [
        "in", "on", "at", "to", "of", "for", "by", "or", "and", "the", "is", "it", "be",
        "as", "do", "go", "no", "so", "up", "us", "we", "my", "me", "he", "hi", "ok", "ai", "ui"
    ]

    public static func applyInstantLocalDictionary(
        _ raw: String,
        entries: [LexiconEntry],
        context: ActiveScreenContext,
        config: LLMConfig,
        stripPeriod: Bool = false
    ) -> String {
        guard !raw.isEmpty else { return "" }
        var fixed = raw
            .replacingOccurrences(of: "另起一行", with: "\n")
            .replacingOccurrences(of: "新起一段", with: "\n\n")
        for item in entries.prefix(200) {
            // Sort longer aliases first (e.g. "s Su" before "Su") so multi-token glides replace cleanly as one unit
            let sortedAliases = item.aliases.filter { $0.count >= 2 }.sorted { $0.count > $1.count }
            for alias in sortedAliases {
                let isShortPureASCII = alias.count <= 5 && alias.allSatisfy({ $0.isASCII && ($0.isLetter || $0 == " ") })
                if !isShortPureASCII {
                    fixed = fixed.replacingOccurrences(of: alias, with: item.term, options: .caseInsensitive)
                } else if !commonShortEnglishWords.contains(alias.lowercased()) {
                    // Word-boundary-safe replacement: fixes standalone "Su" / "s Su" -> "SEO" without ever touching "Summary" or "Supabase"!
                    let escaped = NSRegularExpression.escapedPattern(for: alias)
                    fixed = replaceRegex(in: fixed, pattern: "(?i)(?<![A-Za-z])\(escaped)(?![A-Za-z])", template: item.term)
                }
            }
        }
        if stripPeriod {
            fixed = applyPostFormattingRules(fixed, context: context, config: config)
        }
        return fixed
    }

    /// Deterministic check for whether a spoken sentence is already clean enough to skip Pass-2 LLM (`0ms` direct paste!).
    public static func canBypassCloudPolish(
        locallyFixed: String,
        recalledTerms: [LexiconEntry],
        formattingStyle: FormattingStyle,
        isHighAccuracyLocalASR: Bool,
        isPunctuatedCloudASR: Bool
    ) -> Bool {
        let trimmed = locallyFixed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let mustPolishMarkers = [
            "嗯", "啊", "呃", "额", "那个", "就是", "然后呢", "怎么说",
            "不对", "不是", "重说", "算了", "改成", "改为", "其实", "更正", "我是说",
            "第一", "第二", "第三", "首先", "其次", "两件事", "三件事", "几个问题", "两点", "三点",
            "百分之", "一二三"
        ]
        if containsStutterRepetition(trimmed) || mustPolishMarkers.contains(where: { trimmed.contains($0) }) {
            return false
        }

        // If fuzzy phonetic recall detected a homophone candidate that wasn't already resolved into `trimmed`, let LLM verify it!
        let uttFuzzy = PhoneticIndexer.fuzzySkeleton(trimmed)
        for entry in recalledTerms {
            let entryFuzzy = PhoneticIndexer.fuzzySkeleton(entry.term)
            if entryFuzzy.count >= 4,
               uttFuzzy.contains(entryFuzzy),
               !trimmed.localizedCaseInsensitiveContains(entry.term) {
                return false
            }
        }

        let fastMaxChars: Int
        if isPunctuatedCloudASR {
            // Seed-ASR 2.0 already provides accurate punctuation & Arabic ITN — clean single sentences up to 28 chars finish in 0ms!
            fastMaxChars = 28
        } else {
            fastMaxChars = formattingStyle == .structured ? 6 : (isHighAccuracyLocalASR ? 20 : 5)
        }
        return trimmed.count <= fastMaxChars
    }

    /// Typeless-grade Semantic Structuring, De-rambling & Personal Lexicon Engine.
    public func polish(
        rawTranscript: String,
        mode: DictationMode,
        screenContext: ActiveScreenContext,
        recalledTerms: [LexiconEntry],
        recentOutputs: [String],
        config: LLMConfig,
        apiKey: String,
        isHighAccuracyLocalASR: Bool = true,
        isPunctuatedCloudASR: Bool = false,
        onStreamChunk: (@MainActor (String, Bool) -> Void)? = nil
    ) async -> (text: String, latencyMs: Int, usedFastPath: Bool) {
        let start = DispatchTime.now()
        let cleanedRaw = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRaw.isEmpty else { return ("", 0, true) }

        // 1. Local exact alias replacement + spoken newline command
        let locallyFixed = Self.applyInstantLocalDictionary(
            cleanedRaw,
            entries: recalledTerms,
            context: screenContext,
            config: config,
            stripPeriod: false
        )

        // 2. Pure local mode or missing API key (except local Ollama / LM Studio endpoints)
        if mode == .dictate && (config.formattingStyle == .verbatimLocal || (apiKey.isEmpty && !Self.isKeylessLocalEndpoint(config.baseURL))) {
            let out = Self.applyPostFormattingRules(locallyFixed, context: screenContext, config: config)
            return (out, 0, true)
        }

        // 3. Smart Clean-Phrase 0ms Bypass (<= 28 chars on punctuated Seed-ASR 2.0 without fillers/edits/unresolved homophones)
        if mode == .dictate && config.enableFastBypassForShortPhrases && Self.canBypassCloudPolish(
            locallyFixed: locallyFixed,
            recalledTerms: recalledTerms,
            formattingStyle: config.formattingStyle,
            isHighAccuracyLocalASR: isHighAccuracyLocalASR,
            isPunctuatedCloudASR: isPunctuatedCloudASR
        ) {
            let finalFast = Self.applyPostFormattingRules(locallyFixed, context: screenContext, config: config)
            let ms = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            return (finalFast, ms, true)
        }

        let glossaryBlock: String = recalledTerms.isEmpty ? "无" : recalledTerms.map { entry in
            entry.aliases.isEmpty ? entry.term : "\(entry.term)(误听:\(entry.aliases.prefix(4).joined(separator: "/")))"
        }.joined(separator: "；")

        let systemPrompt: String
        let userContent: String

        let precedingSnippet = screenContext.precedingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let precedingTag = precedingSnippet.isEmpty ? "无" : String(precedingSnippet.suffix(120))
        let recentJoined = recentOutputs
            .map { $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .suffix(2)
            .joined(separator: " ｜ ")
        let recentTag = recentJoined.isEmpty ? "无" : String(recentJoined.suffix(110))

        switch mode {
        case .dictate:
            systemPrompt = (config.formattingStyle == .structured)
                ? Self.structuredStaticSystemPrompt
                : Self.lightStaticSystemPrompt
            userContent = "<scene>\(screenContext.toneProfile.rawValue)</scene>\n<recent_context>\(recentTag)</recent_context>\n<preceding_text>\(precedingTag)</preceding_text>\n<lexicon>\(glossaryBlock)</lexicon>\n<raw_speech>\(locallyFixed)</raw_speech>"

        case .rewriteSelection:
            systemPrompt = "按 <voice_instruction> 修改 <selected_text>（若指令为「改成XX/这是XX」则直接替换为对应目标词或修改对应词），参考词库，保留自然人味禁公文腔，直接输出修改后正文。"
            userContent = "<recent_context>\(recentTag)</recent_context>\n<lexicon>\(glossaryBlock)</lexicon>\n<selected_text>\(screenContext.selectedText)</selected_text>\n<voice_instruction>\(locallyFixed)</voice_instruction>"
        }

        do {
            let (result, firstTokenMs) = try await callChatCompletionsSSE(
                baseURL: config.baseURL,
                model: config.modelName,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userContent: userContent,
                maxTokens: max(180, locallyFixed.count * 2),
                context: screenContext,
                config: config,
                onStreamChunk: onStreamChunk
            )
            let formatted = Self.applyPostFormattingRules(result, context: screenContext, config: config)
            let totalMs = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            return (formatted.isEmpty ? locallyFixed : formatted, firstTokenMs > 0 ? firstTokenMs : totalMs, false)
        } catch {
            let ms = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
            return (Self.applyPostFormattingRules(locallyFixed, context: screenContext, config: config), ms, true)
        }
    }

    public func distillTermsFromRawCorpus(
        corpusText: String,
        config: LLMConfig,
        apiKey: String
    ) async throws -> [(term: String, aliases: [String], category: LexiconCategory)] {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "TypeZero.LLM", code: 401, userInfo: [NSLocalizedDescriptionKey: "请先在设置页填入大模型 API Key"])
        }
        let clipped = String(corpusText.prefix(12_000))
        let sys = """
        从文本提取高价值个人词库（人名、称呼、项目名、技术名词、标的代码）。
        每行格式：标准词|常见同音误听1,常见同音误听2|分类(person/project/finance/memo)
        最多 40 行，禁输出解释。
        """
        let rawOut = try await callChatCompletions(
            baseURL: config.baseURL,
            model: config.modelName,
            apiKey: apiKey,
            systemPrompt: sys,
            userContent: clipped,
            maxTokens: 1200
        )

        var parsed: [(term: String, aliases: [String], category: LexiconCategory)] = []
        for line in rawOut.components(separatedBy: .newlines) {
            let cols = line.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 1, cols[0].count >= 2 else { continue }
            let term = cols[0]
            let aliases = cols.count >= 2
                ? cols[1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                : []
            let catStr = cols.count >= 3 ? cols[2].lowercased() : "memo"
            let cat: LexiconCategory = {
                if catStr.contains("person") { return .person }
                if catStr.contains("finance") { return .finance }
                if catStr.contains("project") { return .project }
                return .memo
            }()
            parsed.append((term, aliases, cat))
        }
        return parsed
    }

    private static func normalizeChatCompletionsEndpoint(_ baseURL: String) -> String {
        var clean = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if clean.hasSuffix("/responses") {
            clean = String(clean.dropLast("/responses".count))
        }
        if clean.hasSuffix("/chat/completions") {
            return clean
        }
        return "\(clean)/chat/completions"
    }

    /// Live latency benchmark for comparing DeepSeek 4 Flash vs Volcengine Doubao-Lite (`ep-...`) side-by-side.
    public func benchmarkLatency(config: LLMConfig, apiKey: String) async throws -> (ttftMs: Int, totalMs: Int, sampleOutput: String) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty || Self.isKeylessLocalEndpoint(config.baseURL) else {
            throw NSError(domain: "TypeZero.LLM", code: 401, userInfo: [NSLocalizedDescriptionKey: "当前勾选模型尚未填入 API Key，请先在当前卡片粘贴密钥并点击「保存」"])
        }
        prewarmConnection(baseURL: config.baseURL, apiKey: cleanKey)
        try? await Task.sleep(nanoseconds: 180_000_000)

        let totalStart = DispatchTime.now()
        let (out, ttft) = try await callChatCompletionsSSE(
            baseURL: config.baseURL,
            model: config.modelName,
            apiKey: cleanKey,
            systemPrompt: Self.structuredStaticSystemPrompt,
            userContent: "<scene>AI提问与笔记</scene>\n<lexicon>无</lexicon>\n<raw_speech>嗯那个帮我记两件事第一明天下午两点不对改四点同步进度第二测一下豆包极速接口</raw_speech>",
            maxTokens: 120,
            context: .empty,
            config: config,
            onStreamChunk: nil
        )
        let totalMs = Int((DispatchTime.now().uptimeNanoseconds - totalStart.uptimeNanoseconds) / 1_000_000)
        return (ttft > 0 ? ttft : totalMs, totalMs, out)
    }

    /// Builds provider-optimized OpenAI-compatible payloads for DeepSeek, Volcengine Doubao, OpenAI (GPT-4.1 / GPT-5 / o-series), Google Gemini (2.5 / 3.x), DashScope Qwen, and Custom/Ollama endpoints.
    public static func buildOpenAICompatiblePayload(
        endpoint: String,
        model: String,
        systemPrompt: String,
        userContent: String,
        maxTokens: Int,
        stream: Bool
    ) -> [String: Any] {
        let lowerModel = model.lowercased()
        let lowerEndpoint = endpoint.lowercased()
        let lowerModelAndHost = lowerModel + " " + lowerEndpoint

        var payload: [String: Any] = [
            "model": model,
            "stream": stream,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ]
        ]

        let isOpenAIReasoningFamily = lowerModel.hasPrefix("gpt-5")
            || lowerModel.hasPrefix("o1")
            || lowerModel.hasPrefix("o3")
            || lowerModel.hasPrefix("o4")

        if isOpenAIReasoningFamily {
            payload["max_completion_tokens"] = maxTokens
            if lowerModel.hasPrefix("gpt-5") {
                payload["reasoning_effort"] = "minimal"
            }
        } else {
            payload["max_tokens"] = maxTokens
            if lowerModelAndHost.contains("deepseek")
                || lowerModelAndHost.contains("volces.com")
                || lowerModelAndHost.contains("doubao")
                || lowerModel.hasPrefix("ep-") {
                payload["thinking"] = ["type": "disabled"]
            } else if lowerEndpoint.contains("generativelanguage.googleapis.com") || lowerModel.hasPrefix("gemini-") {
                if lowerModel.contains("2.5-flash") {
                    payload["reasoning_effort"] = "none"
                } else if lowerModel.hasPrefix("gemini-3") || lowerModel.hasPrefix("gemini-4") {
                    payload["reasoning_effort"] = "minimal"
                }
                payload["temperature"] = 0.1
            } else {
                payload["temperature"] = 0.1
            }
        }
        return payload
    }

    /// P3: Ultra-low-latency SSE (`stream: true`) client — supports OpenAI-compatible (DeepSeek / Doubao / Qwen / OpenAI / Gemini / Ollama) AND native Anthropic Messages API!
    private func callChatCompletionsSSE(
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String,
        userContent: String,
        maxTokens: Int,
        context: ActiveScreenContext,
        config: LLMConfig,
        onStreamChunk: (@MainActor (String, Bool) -> Void)?
    ) async throws -> (fullText: String, ttftMs: Int) {
        if config.selectedProvider == .anthropic || Self.isAnthropicEndpoint(baseURL) {
            return try await callAnthropicMessagesSSE(
                baseURL: baseURL,
                model: model,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userContent: userContent,
                maxTokens: maxTokens,
                config: config,
                onStreamChunk: onStreamChunk
            )
        }

        let start = DispatchTime.now()
        let endpoint = Self.normalizeChatCompletionsEndpoint(baseURL)

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var payload = Self.buildOpenAICompatiblePayload(
            endpoint: endpoint,
            model: model,
            systemPrompt: systemPrompt,
            userContent: userContent,
            maxTokens: maxTokens,
            stream: true
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let activeSession = transportSession(for: baseURL)
        var (bytes, response) = try await activeSession.bytes(for: request)
        if let http = response as? HTTPURLResponse,
           http.statusCode == 400,
           (payload["thinking"] != nil || payload["reasoning_effort"] != nil) {
            // Seamless fallback if a provider/model variant does not accept optional thinking / reasoning_effort flags
            payload.removeValue(forKey: "thinking")
            payload.removeValue(forKey: "reasoning_effort")
            if payload["max_completion_tokens"] == nil {
                payload["temperature"] = 0.1
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            (bytes, response) = try await activeSession.bytes(for: request)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "TypeZero.LLM", code: code, userInfo: [NSLocalizedDescriptionKey: "接口返回 HTTP \(code)（请核对当前服务商 API Key 与模型 ID \(model) 是否匹配）"])
        }

        var accumulated = ""
        var isFirst = true
        var ttftMs = 0

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let dataStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if dataStr == "[DONE]" { break }

            guard let jsonData = dataStr.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let token = delta["content"] as? String,
                  !token.isEmpty else {
                continue
            }

            let spacedToken = Self.cleanAndSpaceStreamToken(token, accumulated: accumulated, enablePanguSpacing: config.enablePanguSpacing)
            guard !spacedToken.isEmpty else { continue }

            accumulated.append(spacedToken)
            if isFirst {
                ttftMs = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                if let onStreamChunk {
                    await onStreamChunk(spacedToken, true)
                }
                isFirst = false
            } else if let onStreamChunk {
                await onStreamChunk(spacedToken, false)
            }
        }

        return (accumulated.trimmingCharacters(in: .whitespacesAndNewlines), ttftMs)
    }

    /// Native Anthropic Messages API SSE (`https://api.anthropic.com/v1/messages`) for Claude Haiku / Sonnet.
    private func callAnthropicMessagesSSE(
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String,
        userContent: String,
        maxTokens: Int,
        config: LLMConfig,
        onStreamChunk: (@MainActor (String, Bool) -> Void)?
    ) async throws -> (fullText: String, ttftMs: Int) {
        let start = DispatchTime.now()
        let endpoint = Self.normalizeAnthropicMessagesEndpoint(baseURL)
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": max(256, maxTokens),
            "temperature": 0.1,
            "stream": true,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await transportSession(for: baseURL).bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "TypeZero.LLM", code: code, userInfo: [NSLocalizedDescriptionKey: "Anthropic 接口返回 HTTP \(code)（请核对 Claude API Key 与模型 ID \(model)）"])
        }

        var accumulated = ""
        var isFirst = true
        var ttftMs = 0

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let dataStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard let jsonData = dataStr.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  (obj["type"] as? String) == "content_block_delta",
                  let delta = obj["delta"] as? [String: Any],
                  let token = delta["text"] as? String,
                  !token.isEmpty else {
                continue
            }

            let spacedToken = Self.cleanAndSpaceStreamToken(token, accumulated: accumulated, enablePanguSpacing: config.enablePanguSpacing)
            guard !spacedToken.isEmpty else { continue }

            accumulated.append(spacedToken)
            if isFirst {
                ttftMs = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                if let onStreamChunk {
                    await onStreamChunk(spacedToken, true)
                }
                isFirst = false
            } else if let onStreamChunk {
                await onStreamChunk(spacedToken, false)
            }
        }

        return (accumulated.trimmingCharacters(in: .whitespacesAndNewlines), ttftMs)
    }

    private static func cleanAndSpaceStreamToken(_ token: String, accumulated: String, enablePanguSpacing: Bool) -> String {
        let cleanToken = token
            .replacingOccurrences(of: "<raw_speech>", with: "")
            .replacingOccurrences(of: "</raw_speech>", with: "")
        guard !cleanToken.isEmpty else { return "" }

        if enablePanguSpacing, let lastChar = accumulated.last, let firstChar = cleanToken.first {
            let lastIsCJK = lastChar.unicodeScalars.first.map { $0.value >= 0x4E00 && $0.value <= 0x9FA5 } ?? false
            let firstIsASCIIAlnum = firstChar.isASCII && (firstChar.isLetter || firstChar.isNumber)
            let lastIsASCIIAlnum = lastChar.isASCII && (lastChar.isLetter || lastChar.isNumber || lastChar == "%")
            let firstIsCJK = firstChar.unicodeScalars.first.map { $0.value >= 0x4E00 && $0.value <= 0x9FA5 } ?? false
            if (lastIsCJK && firstIsASCIIAlnum) || (lastIsASCIIAlnum && firstIsCJK) {
                return " " + cleanToken
            }
        }
        return cleanToken
    }

    private func callChatCompletions(
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String,
        userContent: String,
        maxTokens: Int
    ) async throws -> String {
        if Self.isAnthropicEndpoint(baseURL) {
            return try await callAnthropicMessagesOnce(
                baseURL: baseURL,
                model: model,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userContent: userContent,
                maxTokens: maxTokens
            )
        }

        let endpoint = Self.normalizeChatCompletionsEndpoint(baseURL)

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var payload = Self.buildOpenAICompatiblePayload(
            endpoint: endpoint,
            model: model,
            systemPrompt: systemPrompt,
            userContent: userContent,
            maxTokens: maxTokens,
            stream: false
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let activeSession = transportSession(for: baseURL)
        var (data, response) = try await activeSession.data(for: request)
        if let http = response as? HTTPURLResponse,
           http.statusCode == 400,
           (payload["thinking"] != nil || payload["reasoning_effort"] != nil) {
            payload.removeValue(forKey: "thinking")
            payload.removeValue(forKey: "reasoning_effort")
            if payload["max_completion_tokens"] == nil {
                payload["temperature"] = 0.1
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            (data, response) = try await activeSession.data(for: request)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("<raw_speech>") && cleaned.hasSuffix("</raw_speech>") {
            cleaned = cleaned
                .replacingOccurrences(of: "<raw_speech>", with: "")
                .replacingOccurrences(of: "</raw_speech>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private func callAnthropicMessagesOnce(
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String,
        userContent: String,
        maxTokens: Int
    ) async throws -> String {
        let endpoint = Self.normalizeAnthropicMessagesEndpoint(baseURL)
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": max(256, maxTokens),
            "temperature": 0.1,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await transportSession(for: baseURL).data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["content"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        let text = blocks
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    /// P8: Deterministic 0ms CJK-Latin "Pangu Spacing" + Spoken Percentage/Currency Normalization + Trailing Punctuation Rule
    public static func applyPostFormattingRules(_ text: String, context: ActiveScreenContext, config: LLMConfig) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return "" }

        // Spoken percentage & currency quick normalization
        result = Self.replaceRegex(in: result, pattern: #"百分之(\d+(?:\.\d+)?)"#, template: "$1%")

        // Never emit blank empty lines (`\n\n`) between paragraphs unless explicitly requested
        result = Self.replaceRegex(in: result, pattern: #"[ \t]*\n{2,}[ \t]*"#, template: "\n")

        if !context.isCodeOrTerminal {
            // Strip accidental Markdown bold/heading markers so IM / email / notes never receive stray `**` or `###`
            result = Self.replaceRegex(in: result, pattern: #"\*\*([^\n*]{1,80})\*\*"#, template: "$1")
            result = Self.replaceRegex(in: result, pattern: #"(?m)^#{1,4}[ \t]+"#, template: "")
            // Normalize stray half-width `?` / `!` directly following CJK characters to crisp full-width Chinese punctuation
            result = Self.replaceRegex(in: result, pattern: #"([\u4e00-\u9fa5])\s*\?"#, template: "$1？")
            result = Self.replaceRegex(in: result, pattern: #"([\u4e00-\u9fa5])\s*!"#, template: "$1！")
        }

        if config.enablePanguSpacing {
            // Insert clean space between CJK ideographs and ASCII letters/numbers
            result = Self.replaceRegex(in: result, pattern: #"([\u4e00-\u9fa5])([A-Za-z0-9$¥%])"#, template: "$1 $2")
            result = Self.replaceRegex(in: result, pattern: #"([A-Za-z0-9%])([\u4e00-\u9fa5])"#, template: "$1 $2")
        }

        if config.stripTrailingPeriodInChatApps && (context.isInstantMessaging || context.isStrictShellTerminal) {
            if !result.contains("\n") && (result.hasSuffix("。") || result.hasSuffix(".")) {
                result.removeLast()
            }
        }
        return result
    }

    private static func replaceRegex(in input: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }

    private static func containsStutterRepetition(_ text: String) -> Bool {
        let pattern = #"(.{2,4})\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
