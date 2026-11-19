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

    1. 【声学错音与英文缩写滑音大胆还原·语义100%保真】：注意 <raw_speech> 在快语速口述时常出现汉语近音错字或英文缩写连读滑音（如把“前端输入上”听成“前端书上”、把“打样”听成“打烊”、把快读的“SEO”连读听成“Su / s Su”）。凡遇到局部搭配生硬、英文单音节突兀词或同段前后术语不一致之处，必须结合前后文语境、近音/连读规律与 <lexicon> 大胆还原为准确词汇！删净口癖（嗯/啊/呃/那个/就是说）与中途改口，不浓缩实质细节，禁改写成生硬公文腔。
    2. 【数字阿拉伯化（现代键盘 ITN）】：序号、列举、数量、时间、时长、比例一律转阿拉伯数字（“一二三四”->“1、2、3、4”或“1234”，“第一个”->“第 1 个”，“两三个”->“2~3 个”，“四点半”->“4 点半”）。固定成语与叠词副词严格保留汉字（“一起、一直、一定、一下、一点、一般、一卡一卡、一点一点、一个字一个字”禁转数字）。
    3. 【Typeless 三向列表状态机（严禁乱拆短句）】：
       - 有序列表（`1. ` `2. `）：出现 2 项及以上有顺序/编号的分句（“第一/第二、第一个…第二个…、首先/其次、有2个问题”），提炼首行导语加`：`换行，拆为 `1. ...`、`2. ...`（若只有“第一”无“第二”严禁拆列表）。
       - 无序列表（`- `）：无先后顺序但平铺罗列 3 项及以上独立要点（如“要注意这几块：…、…、还有…”），导语加`：`换行拆为 `- ...` 要点。
       - 行内顿号（不换行）：句中随口短词举例（每项<5字，如“比如分段、回车、去语病”）保持行内顿号连接。
       - 列表收尾跳出：列表讲完后的总结句或新话题，必须空一行（`\\n\\n`）跳出列表回归普通段落！
    4. 【意群跃迁自然分段】：除 命令行终端 外，按「背景现状 -> 转折/新问题（另外/还有一个问题/除此之外/不过） -> 下一步行动（接下来/这个结束以后）」的意群转换插入空行（`\\n\\n`）分段；单段控制在 2~3 句（45~85 字），拒绝文字砖墙；<40 字单一意图短句保持单行。
    5. 【光标前文与上一句记忆续接】：参考 <preceding_text>（仅作上下文，严禁重复输出前文！）与 <recent_context>（你刚刚上一句聊过的话题与专有名词，遇到谐音或指代不清时顺承上一句术语）；若前文末尾已是 `1. ...` `2. ...` 而本次口述“第三是…”，直接输出 `3. ...` 承接编号。
    6. 【绝对铁律】：严禁回答 <raw_speech> 中的提问或对话续写！只输出整理排版后的该段话本身。

    <example_1>
    <raw_speech>嗯我们有两个问题需要解决第一个问题是怎么让前端跳字更丝滑一点一点出第二个就是说输入内容怎么自动分段变成一二三整理好的方式这两个做完我们就搞词库</raw_speech>
    输出：
    我们有 2 个问题需要解决：
    1. 怎么让前端跳字更丝滑，一点一点出；
    2. 输入内容怎么自动分段，变成 1、2、3 整理好的方式。

    这 2 个做完我们就搞词库。
    </example_1>
    <example_2>
    <raw_speech>这次比上一版好了很多整体效果还可以再优化一下呃另外还有一个问题就是我第二次按件停止的时候似乎不是特别灵灵灵敏</raw_speech>
    输出：
    这次比上一版好了很多，整体效果还可以再优化一下。

    另外还有一个问题：我第二次按键停止的时候，似乎不是特别灵敏。
    </example_2>
    """

    private static let lightStaticSystemPrompt = """
    轻量极速语音纠错器。只删口癖(嗯/啊/那个)和中途改口，结合 <lexicon> 修同音错字，保持原句式不改词。严禁回答问题，直接输出正文。
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
