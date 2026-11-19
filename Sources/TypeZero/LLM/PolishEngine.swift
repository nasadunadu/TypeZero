import Foundation

public final class PolishEngine {
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 10.0
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    // 100% STATIC System Prompts so DeepSeek KV Prefix Cache hits on every single call (~0ms prefill -> ~230ms TTFT!)
    private static let structuredStaticSystemPrompt = """
    你是顶级 AI 语音输入法的意图级文字整理与排版引擎（深度对齐 Typeless 核心策略）。读取 <scene>、<preceding_text>（输入框光标前已有文字）、<lexicon> 与 <raw_speech>，直接输出本次新增正文的整理结果：

    1. 【语气硬保真·态度词保留·口癖清净】：**绝不改变原句语气**——原文为疑问、反问、商量确认或担忧推测（如“会不会…”“对不对”“是不是”）时，必须保留问句语气和全角问号 `？`。保留表达态度和人情味的词（如句首的“好/好的/对/没问题/确实”），彻底清理无意义卡壳、口癖与尾音（`嗯/啊/呃/那个/就是说/然后呢/的话呢/对吧`）、中途改口，以及句中停顿换气带出的孤立过渡词（如“……优化。好，既然……”中的孤立“好，/行，”）。同时结合语境、近音/连读规律与 <lexicon> 大胆还原声学错音与英文滑音（如“Su”->“SEO”），不浓缩实质细节，禁洗成冷冰冰的公文腔。
    2. 【数字阿拉伯化（现代键盘 ITN）】：序号、列举、数量、时间、时长、比例一律转阿拉伯数字（“一二三四”->“1、2、3、4”或“1234”，“第一个”->“第 1 个”，“两三个”->“2~3 个”，“四点半”->“4 点半”）。固定成语与叠词副词严格保留汉字（“一起、一直、一定、一下、一点、一般、一卡一卡、一点一点、一个字一个字”禁转数字）。
    3. 【混合文体路由与克制列表（绝不机械凑编号）】：
       - 叙事型、观点型、解释型口述保持自然段，**绝不按字数强行拆成编号清单**。
       - 有序列表（`1. ` `2. `）：仅在出现 2 项及以上明确顺序/编号的分句（“第一/第二、首先/其次、有2个问题”）时，先用自然段写背景/导语加`：`换行，局部拆为 `1. ...`、`2. ...`（只有“第一”无“第二”严禁拆列表）。
       - 无序列表（`- `）：仅在平铺罗列 3 项及以上独立动作或要点时使用；句中随口短词举例（每项<5字，如“比如分段、回车、去语病”）保持行内顿号连接。
       - 列表收尾：列表讲完后的总结句用**单个换行（`\\n`）**承接，列表项之间与收尾均严禁插空行。
    4. 【克制换行·绝对禁止插空行·纯文本输出】：**严禁输出 `\\n\\n` 空白行**！绝不因为逗号、连接词或字数到了就强行断行；聊天场景或 `<120` 字围绕同一主题的连贯话一律保持紧凑一整段；仅超 120 字且出现明显独立新话题时才用**单个换行（`\\n`）**。**严禁输出 Markdown 装饰符（禁止 `**加粗**`、`### 标题`、`>` 引用、表格或反引号代码块）**，只输出可直接粘贴发送的干净纯文本。
    5. 【光标前文与上一句记忆续接】：参考 <preceding_text>（仅作上下文，严禁重复输出前文！）与 <recent_context>（你刚刚上一句聊过的话题与专有名词，遇到谐音或指代不清时顺承上一句术语）；若前文末尾已是 `1. ...` `2. ...` 而本次口述“第三是…”，直接输出 `3. ...` 承接编号。
    6. 【中文自然断句与词组完整红线】：遇到声学漏标点的长句，必须先识别完整多字词组并顺承语境还原错音，再在真实意群停顿处补齐自然中文全角标点（`，。！？`）；**绝对严禁把完整词组从中间劈开强行插逗号**（例如「发财包」结合财报语境应先完整还原为「发财报」，在「发财报」之后再断句，绝不可断成「发财，报」）。
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
    <raw_speech>那要不就先这样吧这次不用再做了如果我再遇见这样的case的话我直接给你就好了我们一点点优化好既然没有数据集做某一句的优化没有意义</raw_speech>
    输出：
    那要不就先这样吧，这次不用再做了。如果我再遇见这样的 case 的话，我直接给你就好了，我们一点点优化。既然没有数据集，做某一句的优化没有意义。
    </example_2>
    <example_3>
    <recent_context>今天拼多多发财报会不会像阿里巴巴一样？</recent_context>
    <raw_speech>今天太搞笑了有点不敢相信是不是会一起发财包这事赶在一起那就不知道会怎么样了</raw_speech>
    输出：
    今天太搞笑了，有点不敢相信，是不是会一起发财报？这事赶在一起，那就不知道会怎么样了。
    </example_3>
    """

    private static let lightStaticSystemPrompt = """
    轻量极速语音纠错器。保留原句语气、情绪和问句问号 `？`（绝不把疑问句改成陈述句），保留句首态度词（好的/对/没问题），只删无意义口癖尾音（嗯/啊/那个/然后呢/的话呢/对吧）、中途改口和句中换气孤立过渡词。结合 <recent_context> 与 <lexicon> 修同音错字并补齐自然中文全角标点；严禁把完整词组劈开插逗号，严禁强行插空行或输出 Markdown 装饰符（** / ###）。直接输出正文。
    """

    public static func isKeylessLocalEndpoint(_ baseURL: String) -> Bool {
        let u = baseURL.lowercased()
        return u.contains("localhost") || u.contains("127.0.0.1") || u.contains("0.0.0.0")
    }

    /// Authenticated HTTP/2 Keep-Alive connection warm-up fired the moment user starts speaking,
    /// guaranteeing a hot socket (~230ms TTFT) when user stops speaking!
    public func prewarmConnection(baseURL: String, apiKey: String = "") {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/models") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if !apiKey.isEmpty {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 3.0
        session.dataTask(with: req) { _, _, _ in }.resume()
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

    /// P3: Ultra-low-latency SSE (`stream: true`) Chat Completions client — starts streaming polished output at ~200ms TTFT!
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

        var payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ]
        ]
        // CRITICAL SPEED UNLOCK FOR DEEPSEEK V4 FLASH & VOLCENGINE DOUBAO:
        // Disabling chain-of-thought `thinking` cuts TTFT down to ~150-230ms with zero wasted reasoning tokens!
        let lowerModelAndHost = model.lowercased() + " " + endpoint.lowercased()
        if lowerModelAndHost.contains("deepseek") || lowerModelAndHost.contains("volces.com") || lowerModelAndHost.contains("doubao") || model.lowercased().hasPrefix("ep-") {
            payload["thinking"] = ["type": "disabled"]
        } else {
            payload["temperature"] = 0.1
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        var (bytes, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 400, payload["thinking"] != nil {
            // Seamless fallback if an older Volcengine endpoint model doesn't accept the `thinking` field
            payload.removeValue(forKey: "thinking")
            payload["temperature"] = 0.1
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            (bytes, response) = try await session.bytes(for: request)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "TypeZero.LLM", code: code, userInfo: [NSLocalizedDescriptionKey: "接口返回 HTTP \(code)（请核对当前服务商 API Key 与接入点 \(model) 是否匹配）"])
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

            // Clean any accidental XML wrapper tags on the fly
            let cleanToken = token
                .replacingOccurrences(of: "<raw_speech>", with: "")
                .replacingOccurrences(of: "</raw_speech>", with: "")
            guard !cleanToken.isEmpty else { continue }

            // Apply Pangu spacing between previous boundary char and incoming token so live SSE stream already has crisp spacing!
            var spacedToken = cleanToken
            if config.enablePanguSpacing, let lastChar = accumulated.last, let firstChar = cleanToken.first {
                let lastIsCJK = lastChar.unicodeScalars.first.map { $0.value >= 0x4E00 && $0.value <= 0x9FA5 } ?? false
                let firstIsASCIIAlnum = firstChar.isASCII && (firstChar.isLetter || firstChar.isNumber)
                let lastIsASCIIAlnum = lastChar.isASCII && (lastChar.isLetter || lastChar.isNumber || lastChar == "%")
                let firstIsCJK = firstChar.unicodeScalars.first.map { $0.value >= 0x4E00 && $0.value <= 0x9FA5 } ?? false
                if (lastIsCJK && firstIsASCIIAlnum) || (lastIsASCIIAlnum && firstIsCJK) {
                    spacedToken = " " + cleanToken
                }
            }

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

    private func callChatCompletions(
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String,
        userContent: String,
        maxTokens: Int
    ) async throws -> String {
        let endpoint = Self.normalizeChatCompletionsEndpoint(baseURL)

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ]
        ]
        let lowerModelAndHost = model.lowercased() + " " + endpoint.lowercased()
        if lowerModelAndHost.contains("deepseek") || lowerModelAndHost.contains("volces.com") || lowerModelAndHost.contains("doubao") || model.lowercased().hasPrefix("ep-") {
            payload["thinking"] = ["type": "disabled"]
        } else {
            payload["temperature"] = 0.1
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        var (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 400, payload["thinking"] != nil {
            payload.removeValue(forKey: "thinking")
            payload["temperature"] = 0.1
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            (data, response) = try await session.data(for: request)
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
