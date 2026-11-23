import Foundation
import AppKit
import AVFoundation
import Carbon.HIToolbox
import CSherpaOnnx

/// Built-in deterministic regression test suite (`TypeZero --self-test`).
/// Runs in <50ms on pure CommandLineTools without requiring full Xcode / XCTest installation.
public enum SelfTestSuite {
    @discardableResult
    public static func runAll() -> Int32 {
        var passed = 0
        var failed = 0

        func expect(_ condition: @autoclosure () -> Bool, _ label: String) {
            if condition() {
                passed += 1
                print("  ✓ PASS: \(label)")
            } else {
                failed += 1
                print("  ✗ FAIL: \(label)")
            }
        }

        print("==> Running TypeZero Core Regression Suite...")

        // 1. Fuzzy Accent Phonetic Skeleton (`zh/z`, `ing/in`, `n/l`)
        expect(
            PhoneticIndexer.fuzzySkeleton("清晨") == PhoneticIndexer.fuzzySkeleton("亲臣"),
            "Fuzzy skeleton matches '清晨' (qingchen) <-> '亲臣' (qincen)"
        )
        expect(
            PhoneticIndexer.fuzzySkeleton("实验") == PhoneticIndexer.fuzzySkeleton("思言"),
            "Fuzzy skeleton matches '实验' (shiyan) <-> '思言' (siyan)"
        )
        expect(
            PhoneticIndexer.fuzzySkeleton("张伟") == PhoneticIndexer.fuzzySkeleton("赞尾"),
            "Fuzzy skeleton matches '张伟' (zhangwei) <-> '赞尾' (zanwei)"
        )
        expect(
            PhoneticIndexer.fuzzySkeleton("林峰") == PhoneticIndexer.fuzzySkeleton("宁风"),
            "Fuzzy skeleton collapses n/l & eng/en ('林峰' <-> '宁风')"
        )

        // 2. Lexicon Store Smart Rename Merge & Recall (in isolated temp file)
        let tempLexiconURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tz_selftest_\(UUID().uuidString).json")
        defer {
            try? FileManager.default.trashItem(at: tempLexiconURL, resultingItemURL: nil)
        }
        let store = PersonalLexiconStore(customStorageURL: tempLexiconURL)
        store.upsert(term: "张伟", aliases: ["张威"], category: .person, weight: 8)
        store.upsert(term: "章玮", aliases: ["章维"], category: .memo, weight: 7)

        if let wrongItem = store.entries.first(where: { $0.term == "章玮" }) {
            store.updateEntry(
                id: wrongItem.id,
                newTerm: "张伟",
                newAliases: wrongItem.aliases,
                newCategory: .person,
                newWeight: 9
            )
        }
        let mergedMatches = store.entries.filter { $0.term == "张伟" }
        expect(mergedMatches.count == 1, "Renaming '章玮' -> '张伟' smart-merges into single entry without duplicates")
        expect(
            mergedMatches.first?.aliases.contains("章玮") == true && mergedMatches.first?.aliases.contains("章维") == true,
            "Smart merge preserves old wrong term '章玮' and its aliases inside '张伟'"
        )

        let recalled = store.recallRelevantTerms(for: "这件事交给章维跟进一下", limit: 10)
        expect(recalled.contains(where: { $0.term == "张伟" }), "Sub-ms recall hits '张伟' from misheard '章维'")

        // 3. Markdown Auto-Continued Duplicate List Marker Prevention (`2. 2. ` -> `2. `)
        let cleanExpected = "现在我们做几件事：\n1. 检查代码质量；\n2. 准备 GitHub 分支；\n3. 写现状日志。"
        let buggyEditorBox = "现在我们做几件事：\n1. 检查代码质量；\n2. 2. 准备 GitHub 分支；\n3. 3. 写现状日志。"
        expect(
            ContextInjector.extractLeadingListMarker("2. 准备分支") == "2. ",
            "Extracts leading numbered list marker '2. '"
        )
        expect(
            ContextInjector.extractLeadingListMarker("- 无序要点") == "- ",
            "Extracts leading bullet list marker '- '"
        )
        expect(
            ContextInjector.containsDuplicatedListMarker(in: buggyEditorBox, expected: cleanExpected),
            "Detects Markdown editor duplicated list markers ('2. 2. ' / '3. 3. ')"
        )
        expect(
            ContextInjector.collapseDuplicatedListMarkers(buggyEditorBox) == cleanExpected,
            "Cleanly collapses '2. 2. ' and '3. 3. ' back to single markers"
        )

        // 4. Deterministic Pangu Spacing, Full-Width Chinese Punctuation & Percentage ITN
        let formatted = PolishEngine.applyPostFormattingRules(
            "使用DeepSeek提升百分之35速度。",
            context: ActiveScreenContext(appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true),
            config: .default
        )
        expect(
            formatted == "使用 DeepSeek 提升 35% 速度",
            "Applies CJK-Latin Pangu spacing, percentage ITN, and strips trailing period in IM"
        )
        let normQ = PolishEngine.applyPostFormattingRules(
            "今天发财报会不会一样? 太好了!",
            context: ActiveScreenContext(appName: "微信", bundleID: "com.tencent.xinwechat", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true),
            config: .default
        )
        expect(
            normQ == "今天发财报会不会一样？ 太好了！",
            "Normalizes stray half-width ?/! directly after CJK characters to crisp full-width punctuation"
        )
        let noBlankLines = PolishEngine.applyPostFormattingRules(
            "第一段说明。\n\n第二段继续。",
            context: .empty,
            config: .default
        )
        expect(
            noBlankLines == "第一段说明。\n第二段继续。",
            "Collapses unwanted blank empty lines (\\n\\n) to clean single newline"
        )
        let strippedMd = PolishEngine.applyPostFormattingRules(
            "### 核心结论\n这是**重点内容**，请确认。",
            context: ActiveScreenContext(appName: "微信", bundleID: "com.tencent.xinwechat", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true),
            config: .default
        )
        expect(
            strippedMd == "核心结论\n这是重点内容，请确认。",
            "Strips stray Markdown headings/bold markers in non-code chat/doc apps"
        )
        expect(
            PersonalLexiconStore.isCommonOrDisposableAutoLearnTerm("v0.4.2")
                && PersonalLexiconStore.isCommonOrDisposableAutoLearnTerm("今天")
                && !PersonalLexiconStore.isCommonOrDisposableAutoLearnTerm("星河")
                && !PersonalLexiconStore.isCommonOrDisposableAutoLearnTerm("DeepSeek"),
            "Auto-learn pollution filter skips common words & version numbers while keeping proper nouns"
        )

        // 5. Keychain Provider Slot Isolation & Safety Guardrail
        expect(KeychainHelper.providerSlot(for: "https://api.deepseek.com/v1") == "deepseek_api_key", "Routes DeepSeek slot")
        expect(KeychainHelper.providerSlot(for: "https://ark.cn-beijing.volces.com/api/v3") == "ark_api_key", "Routes Volcengine Ark slot")
        expect(ContextInjector.isAllowedTarget(bundleID: "com.tencent.xinwechat", appName: "微信"), "Allows universal dictation input in all user-focused IM apps")

        // 6. Dual-Engine Acoustic Stack (Seed-ASR 2.0 Polyphase 16kHz Resampler + Local FP32 Model Detection)
        let legacyJSON = #"{"baseURL":"https://api.deepseek.com/v1","modelName":"deepseek-flash"}"#.data(using: .utf8) ?? Data()
        let decodedLegacy = try? JSONDecoder().decode(LLMConfig.self, from: legacyJSON)
        expect(decodedLegacy?.enableVolcSeedASR == true, "Legacy config.json auto-enables Volcengine Seed-ASR 2.0 dual engine")

        let wave48k: [Float] = (0..<4800).map { i in Float(sin(2.0 * Double.pi * 1000.0 * Double(i) / 48_000.0) * 0.45) }
        let resampled16k = StreamingASREngine.resampleFloatTo16kHzInt16(wave48k, sourceRate: 48_000.0)
        let maxAmp = resampled16k.map { abs(Int($0)) }.max() ?? 0
        expect(
            resampled16k.count >= 1580 && resampled16k.count <= 1620 && maxAmp > 10_000,
            "Polyphase AVAudioConverter resamples 48kHz Float32 -> 16kHz Int16 mono accurately (\(resampled16k.count) samples, peak \(maxAmp))"
        )

        if let modelInfo = StreamingASREngine.senseVoiceModelPaths() {
            expect(modelInfo.isFullFP32, "Local lossless 886MB SenseVoice FP32 model detected and prioritized")
        }

        // 7. Word-Boundary Acronym Glide Correction ("Su" / "s Su" -> "SEO" without touching "Summary" / "Supabase")
        let seoEntry = LexiconEntry(term: "SEO", aliases: ["Su", "s Su", "艾斯伊欧"], phoneticKey: "seo", category: .project, weight: 10)
        let glideFixed = PolishEngine.applyInstantLocalDictionary(
            "招这个 Su 的人做日本的 s Su，让 Summary 看一下 Supabase",
            entries: [seoEntry],
            context: .empty,
            config: .default,
            stripPeriod: false
        )
        expect(
            glideFixed == "招这个 SEO 的人做日本的 SEO，让 Summary 看一下 Supabase",
            "Word-boundary dictionary fixes 'Su' / 's Su' -> 'SEO' while keeping 'Summary' & 'Supabase' intact"
        )

        // 8. Multi-Paragraph Auto-Learn, Selection Voice Teach-in & Context-Ranked Hotwords
        let multiOrig = "第一段背景说明。\n\n第二段我们让星合跟进一下海外投放。\n\n第三段收尾。"
        let multiEdited = "第一段背景说明。\n\n第二段我们让星河跟进一下海外投放。\n\n第三段收尾。"
        let learnedMulti = store.learnFromManualEditIfApplicable(injectedText: multiOrig, editedBoxValue: multiEdited)
        expect(
            learnedMulti?.wrong == "星合" && learnedMulti?.corrected == "星河",
            "Multi-paragraph auto-learn extracts '星合' -> '星河' across newline-separated text"
        )

        let taughtVoice = store.learnFromSelectionRewrite(selectedText: "Su", rewrittenText: "SEO")
        expect(
            taughtVoice?.wrong == "Su" && taughtVoice?.corrected == "SEO",
            "Selection voice rewrite permanently learns 'Su' -> 'SEO' into personal lexicon"
        )

        let dynamicHot = store.topAcousticContextualStrings(contextHint: "正在对比 Semrush 与 GitHub 增长数据", limit: 15)
        expect(
            dynamicHot.contains("Semrush") && dynamicHot.contains("GitHub"),
            "Context-ranked hotwords dynamically inject live CamelCase/uppercase terms from active context"
        )

        // 9. Default Capsule Micro-Symbol Mode (`enableLiveInlineTyping == false`) + Smart <=28-Char Clean Cloud Bypass
        expect(
            LLMConfig.default.enableLiveInlineTyping == false,
            "Default config turns OFF frontend inline typing in favor of capsule symbol counter + instant paste"
        )
        expect(
            PolishEngine.canBypassCloudPolish(
                locallyFixed: "好的，那你动手把这3点改上吧。",
                recalledTerms: [],
                formattingStyle: .structured,
                isHighAccuracyLocalASR: true,
                isPunctuatedCloudASR: true
            ),
            "Clean <=28-char Seed-ASR sentence bypasses Pass-2 LLM in 0ms"
        )
        expect(
            !PolishEngine.canBypassCloudPolish(
                locallyFixed: "嗯，那个帮我看一下第一点不对改成第二点。",
                recalledTerms: [],
                formattingStyle: .structured,
                isHighAccuracyLocalASR: true,
                isPunctuatedCloudASR: true
            ),
            "Sentence with fillers or self-corrections still routes to Pass-2 LLM"
        )
        AudioLevelBus.shared.reset()
        AudioLevelBus.shared.pushRecognizedCount(14)
        let symSnap = AudioLevelBus.shared.sampleRecognizedSymbolProgress()
        expect(
            symSnap.exactTarget == 14 && symSnap.smoothProgress > 0,
            "Capsule Micro-Symbol counter smoothly advances toward recognized character count"
        )
        AudioLevelBus.shared.reset()

        // 10. Full Left & Right Modifier Hotkeys + Combo Isolation + Unified Check-to-Activate LLM Config
        expect(
            TriggerKeyOption.presetMatrixOrder.count == 10,
            "Symmetric 2x5 hotkey preset grid exposes all Left/Right modifiers + Fn + Option+Space"
        )
        let leftOptFlags = NSEvent.ModifierFlags.option.rawValue | HotkeyMonitor.nxDeviceLeftAltMask
        let rightOptFlags = NSEvent.ModifierFlags.option.rawValue | HotkeyMonitor.nxDeviceRightAltMask
        expect(
            HotkeyMonitor.matchesSingleModifierPress(option: .leftOption, keyCode: 58, rawFlags: leftOptFlags)
                && !HotkeyMonitor.matchesSingleModifierPress(option: .rightOption, keyCode: 58, rawFlags: leftOptFlags),
            "Left Option (keyCode 58) triggers ONLY .leftOption and never leaks into .rightOption"
        )
        expect(
            HotkeyMonitor.matchesSingleModifierPress(option: .rightOption, keyCode: 61, rawFlags: rightOptFlags)
                && !HotkeyMonitor.matchesSingleModifierPress(option: .leftOption, keyCode: 61, rawFlags: rightOptFlags),
            "Right Option (keyCode 61) triggers ONLY .rightOption and never leaks into .leftOption"
        )
        let leftCtrlFlags = NSEvent.ModifierFlags.control.rawValue | HotkeyMonitor.nxDeviceLeftCtrlMask
        let rightShiftFlags = NSEvent.ModifierFlags.shift.rawValue | HotkeyMonitor.nxDeviceRightShiftMask
        expect(
            HotkeyMonitor.matchesSingleModifierPress(option: .leftControl, keyCode: 59, rawFlags: leftCtrlFlags)
                && HotkeyMonitor.matchesSingleModifierPress(option: .rightShift, keyCode: 60, rawFlags: rightShiftFlags),
            "Left Control (59) & Right Shift (60) match cleanly via hardware keyCode + device mask"
        )
        expect(
            HotkeyMonitor.formatComboLabel(keyCode: 49, carbonModifiers: UInt32(controlKey | optionKey)) == "⌃ + ⌥ + Space",
            "Custom combo formatter outputs crisp macOS keycap symbols ('⌃ + ⌥ + Space')"
        )

        var cfg = LLMConfig.default
        cfg.selectProvider(.volcengine)
        cfg.modelName = "ep-20260915-fast"
        cfg.selectProvider(.custom)
        cfg.baseURL = "http://localhost:11434/v1"
        cfg.modelName = "qwen2.5:7b"
        cfg.selectProvider(.deepseek)
        cfg.selectProvider(.volcengine)
        let restoredVolcModel = cfg.modelName
        cfg.selectProvider(.custom)
        expect(
            restoredVolcModel == "ep-20260915-fast"
                && cfg.baseURL == "http://localhost:11434/v1"
                && PolishEngine.isKeylessLocalEndpoint(cfg.baseURL),
            "Provider switching preserves per-provider model IDs/URLs and supports keyless local Ollama endpoints"
        )
        expect(
            KeychainHelper.providerSlot(for: .dashscope) == "dashscope_api_key"
                && KeychainHelper.providerSlot(for: .openai) == "openai_api_key"
                && KeychainHelper.providerSlot(for: .gemini) == "gemini_api_key"
                && KeychainHelper.providerSlot(for: .anthropic) == "anthropic_api_key"
                && KeychainHelper.providerSlot(for: .custom) == "custom_api_key",
            "Unified provider selector routes DashScope, OpenAI, Gemini, Anthropic, and Custom keys to isolated Keychain slots"
        )
        expect(
            LLMProviderOption.infer(from: "https://api.openai.com/v1") == .openai
                && LLMProviderOption.infer(from: "https://generativelanguage.googleapis.com/v1beta/openai") == .gemini
                && LLMProviderOption.infer(from: "https://api.anthropic.com/v1") == .anthropic
                && PolishEngine.isAnthropicEndpoint("https://api.anthropic.com/v1")
                && PolishEngine.normalizeAnthropicMessagesEndpoint("https://api.anthropic.com/v1") == "https://api.anthropic.com/v1/messages",
            "Accurately detects OpenAI, Google Gemini, and native Anthropic Claude Messages API endpoints"
        )
        let oaiGpt5 = PolishEngine.buildOpenAICompatiblePayload(
            endpoint: "https://api.openai.com/v1/chat/completions",
            model: "gpt-5-mini",
            systemPrompt: "sys",
            userContent: "hi",
            maxTokens: 200,
            stream: true
        )
        let gemini25 = PolishEngine.buildOpenAICompatiblePayload(
            endpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            model: "gemini-2.5-flash",
            systemPrompt: "sys",
            userContent: "hi",
            maxTokens: 200,
            stream: true
        )
        let gemini38 = PolishEngine.buildOpenAICompatiblePayload(
            endpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            model: "gemini-3.8-flash",
            systemPrompt: "sys",
            userContent: "hi",
            maxTokens: 200,
            stream: true
        )
        expect(
            (oaiGpt5["max_completion_tokens"] as? Int) == 200
                && oaiGpt5["max_tokens"] == nil
                && (oaiGpt5["reasoning_effort"] as? String) == "minimal"
                && (gemini25["reasoning_effort"] as? String) == "none"
                && (gemini38["reasoning_effort"] as? String) == "minimal",
            "Builds provider-accurate OpenAI GPT-5 (max_completion_tokens) and Gemini 2.5/3.8 (reasoning_effort) payloads"
        )

        expect(
            LLMConfig.default.showInDock == false,
            "Default app mode runs cleanly in top Menu Bar without cluttering the macOS Dock"
        )

        // v0.4.5: OpenAI / Groq Cloud ASR endpoint normalization, 16kHz WAV encoding, hotword prompt hint & ASRProvider migration
        let legacyLocalJSON = #"{"enableVolcSeedASR":false,"baseURL":"https://api.openai.com/v1","modelName":"gpt-4.1-mini"}"#
        let decodedLegacyLocal = try? JSONDecoder().decode(LLMConfig.self, from: Data(legacyLocalJSON.utf8))
        let explicitOpenAIASRJSON = #"{"asrProvider":"openAIWhisper","openAIASRBaseURL":"https://api.groq.com/openai/v1","openAIASRModel":"whisper-large-v3-turbo"}"#
        let decodedOpenAIASR = try? JSONDecoder().decode(LLMConfig.self, from: Data(explicitOpenAIASRJSON.utf8))
        expect(
            decodedLegacyLocal?.asrProvider == .localSenseVoice
                && decodedOpenAIASR?.asrProvider == .openAIWhisper
                && decodedOpenAIASR?.openAIASRModel == "whisper-large-v3-turbo"
                && decodedOpenAIASR?.enableVolcSeedASR == false,
            "ASRProviderOption migrates legacy enableVolcSeedASR configs and preserves OpenAI/Groq ASR settings"
        )
        expect(
            OpenAITranscriptionClient.normalizeTranscriptionEndpoint("https://api.openai.com/v1") == "https://api.openai.com/v1/audio/transcriptions"
                && OpenAITranscriptionClient.normalizeTranscriptionEndpoint("https://api.groq.com/openai/v1/") == "https://api.groq.com/openai/v1/audio/transcriptions"
                && OpenAITranscriptionClient.normalizeTranscriptionEndpoint("https://relay.example.com") == "https://relay.example.com/v1/audio/transcriptions"
                && OpenAITranscriptionClient.normalizeTranscriptionEndpoint("https://api.openai.com/v1/audio/transcriptions") == "https://api.openai.com/v1/audio/transcriptions"
                && OpenAITranscriptionClient.isGroqEndpoint("https://api.groq.com/openai/v1"),
            "Normalizes OpenAI, Groq, and custom transcription endpoints cleanly without duplicating path segments"
        )
        let samplePCM: [Int16] = [0, 1000, -1000, 32000, -32000, 500]
        let wavBytes = OpenAITranscriptionClient.encodePCM16ToWAV(samplePCM, sampleRate: 16_000)
        let riffHeader = String(data: wavBytes.prefix(4), encoding: .ascii)
        let waveHeader = String(data: wavBytes.subdata(in: 8..<12), encoding: .ascii)
        let dataChunkTag = String(data: wavBytes.subdata(in: 36..<40), encoding: .ascii)
        let encodedSampleRate = wavBytes.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        let encodedDataSize = wavBytes.subdata(in: 40..<44).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        expect(
            wavBytes.count == 44 + samplePCM.count * 2
                && riffHeader == "RIFF"
                && waveHeader == "WAVE"
                && dataChunkTag == "data"
                && encodedSampleRate == 16_000
                && encodedDataSize == UInt32(samplePCM.count * 2),
            "Encodes 16kHz mono Int16 PCM into a valid 44-byte RIFF/WAVE payload in memory"
        )
        let promptHint = OpenAITranscriptionClient.buildPromptHint(
            hotwords: ["TypeZero", "typezero", "DeepSeek", "SwiftUI", "A", "Groq"],
            maxChars: 24
        )
        let enPromptHint = OpenAITranscriptionClient.buildPromptHint(
            hotwords: ["五彩石", "TypeZero", "火山引擎", "DeepSeek"],
            maxChars: 80,
            languageLocale: "en-US"
        )
        expect(
            promptHint == "TypeZero, DeepSeek"
                && enPromptHint == "TypeZero, DeepSeek"
                && OpenAITranscriptionClient.isoLanguageCode(from: "auto") == nil
                && OpenAITranscriptionClient.isoLanguageCode(from: "zh-CN") == "zh"
                && OpenAITranscriptionClient.isoLanguageCode(from: "en-US") == "en",
            "Deduplicates and bounds OpenAI/Groq vocabulary prompt hints, filters CJK terms in EN mode, and omits language for auto"
        )

        // 12b. Anti-Translation Language Guardrails & Legacy speechLocale Auto-Migration
        let legacyLocaleJSON = #"{"speechLocale":"zh-CN","modelName":"deepseek-flash"}"#.data(using: .utf8)!
        let explicitLocaleJSON = #"{"speechLocale":"zh-CN","speechLocaleExplicitlySet":true,"modelName":"deepseek-flash"}"#.data(using: .utf8)!
        let migratedLocaleCfg = try? JSONDecoder().decode(LLMConfig.self, from: legacyLocaleJSON)
        let explicitLocaleCfg = try? JSONDecoder().decode(LLMConfig.self, from: explicitLocaleJSON)
        expect(
            LLMConfig.default.speechLocale == "auto"
                && migratedLocaleCfg?.speechLocale == "auto"
                && explicitLocaleCfg?.speechLocale == "zh-CN"
                && LLMConfig.senseVoiceLanguageCode(for: "auto") == "auto"
                && LLMConfig.senseVoiceLanguageCode(for: "zh-CN") == "zh"
                && LLMConfig.senseVoiceLanguageCode(for: "en-US") == "en",
            "Defaults speechLocale to auto, migrates legacy unconfigured zh-CN to auto, preserves explicit user choice, and maps SenseVoice language"
        )

        let enRaw = "Hey team, let's push the release tomorrow afternoon after we verify the audio pipeline."
        let badEnToZh = "嘿团队，我们在验证完音频管线后，明天下午再发布这个版本吧。"
        let goodEnPolished = "Hey team, let's push the release tomorrow afternoon after we verify the audio pipeline."
        let zhRaw = "我们今天下午三点开会同步一下最新的产品进展和发布计划"
        let badZhToEn = "We will have a meeting at 3 pm this afternoon to sync on the latest product progress and release plan."
        let mixedRaw = "我们用 DeepSeek 和 TypeZero 来做语音输入法"
        let mixedOut = "我们用 DeepSeek 和 TypeZero 来做语音输入法。"
        expect(
            PolishEngine.guardAgainstUnexpectedTranslation(rawInput: enRaw, llmOutput: badEnToZh) == enRaw
                && PolishEngine.guardAgainstUnexpectedTranslation(rawInput: enRaw, llmOutput: goodEnPolished) == goodEnPolished
                && PolishEngine.guardAgainstUnexpectedTranslation(rawInput: zhRaw, llmOutput: badZhToEn) == zhRaw
                && PolishEngine.guardAgainstUnexpectedTranslation(rawInput: mixedRaw, llmOutput: mixedOut) == mixedOut,
            "Anti-translation circuit breaker rejects accidental En->Zh and Zh->En LLM translations while preserving normal EN, ZH, and mixed polishing"
        )
        expect(
            CloudAuthClient.isVoucherCode("tz-a3k9-7m2p")
                && CloudAuthClient.normalizedVoucherCode(" tz-a3k9-7m2p ") == "TZ-A3K9-7M2P"
                && !CloudAuthClient.isVoucherCode("volc-raw-api-key-12345")
                && !CloudAuthClient.isVoucherCode("TZ-123"),
            "Detects and normalizes Doubao ASR voucher codes (TZ-XXXX-XXXX) without matching standard API keys"
        )
        expect(
            AppUpdater.isNewerVersion("0.5.6", than: "0.5.5")
                && AppUpdater.isNewerVersion("v0.10.0", than: "0.5.9")
                && !AppUpdater.isNewerVersion("0.5.5", than: "0.5.5")
                && !AppUpdater.isNewerVersion("0.5.4", than: "0.5.5"),
            "Semantic version comparator accurately detects newer releases for in-app auto-updater"
        )

        // 13. Zero-Rewind Atomic Polish Routing (WeChat/QQ & Long Drafts >= 25 Chars) + Prefix-Preserving Replacement Diff
        let wechatCtx = ActiveScreenContext(appName: "微信", bundleID: "com.tencent.xinwechat", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true)
        let notesCtx = ActiveScreenContext(appName: "Notes", bundleID: "com.apple.Notes", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true)
        let longDraft = "似乎我在微信里面发不是特别容易回行比如现在我说很长的字我在看一个巴黎视频第一他有真人出镜感第二讲解很轻快"
        expect(
            wechatCtx.prefersAtomicPolishReplacement
                && !notesCtx.prefersAtomicPolishReplacement
                && !LiveInputSession.shouldUseLiveSSEStream(draft: "你好世界", context: wechatCtx)
                && LiveInputSession.shouldUseLiveSSEStream(draft: "帮我查一下今天的日程", context: notesCtx)
                && !LiveInputSession.shouldUseLiveSSEStream(draft: longDraft, context: notesCtx),
            "Routes WeChat/QQ and long (>24 char) drafts to steady atomic post-polish replacement instead of SSE backspace rewind"
        )
        let atomicDiff = LiveInputSession.computeAtomicReplacementDiff(
            emitted: "似乎我在微信里面发不是特别容易回行，第2天视频很好看",
            finalText: "似乎我在微信里面发不是特别容易回行，第 2 天视频很好看。\n1. 画面稳"
        )
        expect(
            atomicDiff.commonPrefixCount == 19
                && atomicDiff.replaceCount == 7
                && atomicDiff.replacementSuffix == " 2 天视频很好看。\n1. 画面稳",
            "Preserves unchanged leading prefix in atomic replacement diff so only the divergent tail is selected and pasted"
        )
        let mergedExact = LiveInputSession.buildMergedBoxReplacement(
            boxText: "明天我要开三个会第一个上午开会第二个中午吃饭",
            alreadyEmitted: "明天我要开三个会第一个上午开会第二个中午吃饭",
            finalText: "明天我要开 3 个会：\n1. 上午开会；\n2. 中午吃饭。"
        )
        let mergedWithPrefix = LiveInputSession.buildMergedBoxReplacement(
            boxText: "张总你好，明天我要开三个会第一个上午开会",
            alreadyEmitted: "明天我要开三个会第一个上午开会",
            finalText: "明天我要开 3 个会：\n1. 上午开会。"
        )
        expect(
            mergedExact == "明天我要开 3 个会：\n1. 上午开会；\n2. 中午吃饭。"
                && mergedWithPrefix == "张总你好，明天我要开 3 个会：\n1. 上午开会。"
                && LiveInputSession.buildMergedBoxReplacement(boxText: "完全不相关的内容", alreadyEmitted: "明天开会", finalText: "明天开会。") == nil
                && !ContextInjector.pasteboardContainsNonTextRichObject(typeNames: ["public.utf8-plain-text", "NSStringPboardType"])
                && ContextInjector.pasteboardContainsNonTextRichObject(typeNames: ["public.utf8-plain-text", "public.tiff"]),
            "Cmd+A/Cmd+C zero-rewind merge preserves user-typed prefixes and guards against flattening rich media/images"
        )

        // 14. Steady Window-Bottom Pill Anchor (Never chases mouse cursor, never flips to window top)
        let vf = CGRect(x: 0, y: 60, width: 1920, height: 990)
        let pillSz = CGSize(width: 140, height: 34)
        let midWin = CGRect(x: 200, y: 120, width: 1000, height: 680) // cocoaBottomY = 1080 - 800 = 280
        let midAnchor = ContextInjector.anchorWindowBottomCocoaOrigin(
            forWindowQuartzRect: midWin,
            pillSize: pillSz,
            primaryScreenHeight: 1080,
            visibleFrame: vf,
            horizontalRatio: 0.64
        )
        let flushBottomWin = CGRect(x: 200, y: 80, width: 1000, height: 940) // cocoaBottomY = 1080 - 1020 = 60 (flush with Dock)
        let flushAnchor = ContextInjector.anchorWindowBottomCocoaOrigin(
            forWindowQuartzRect: flushBottomWin,
            pillSize: pillSz,
            primaryScreenHeight: 1080,
            visibleFrame: vf,
            horizontalRatio: 0.64
        )
        expect(
            abs(midAnchor.x - (200 + 640 - 70)) < 1.0
                && abs(midAnchor.y - (280 - 34 - 10)) < 1.0
                && flushAnchor.y >= vf.minY + 12 && flushAnchor.y < 120,
            "Tier-3 window anchor locks pill beneath WeChat compose pane and stays tucked at bottom when window is flush with Dock"
        )

        // 49. Live inline typing zero-deadlock under deep (>6 char) early punctuation/word revisions across many turns
        var simEmitted = "我发现有一个问题就是我在打字用语音的过程中"
        var simTarget = simEmitted
        var simCloudRaw = simEmitted
        // Seed-ASR inserts a comma 12 chars earlier AND adds new words at the end
        let rev1 = LiveInputSession.reconcileLiveTargetAdvance(
            emitted: simEmitted,
            targetConfirmed: simTarget,
            lastCloudRaw: simCloudRaw,
            newStable: "我发现有一个问题，就是我在打字用语音的过程中，出着出着字就不继续往前出了",
            isCloudStream: true
        )
        simTarget = rev1.nextTarget
        simCloudRaw = rev1.nextCloudRaw
        simEmitted = simTarget
        let rev2 = LiveInputSession.reconcileLiveTargetAdvance(
            emitted: simEmitted,
            targetConfirmed: simTarget,
            lastCloudRaw: simCloudRaw,
            newStable: "我发现有一个问题，就是我在打字用语音的过程中，出着出着字就不继续往前出了，现在测试连续跟出",
            isCloudStream: true
        )
        expect(
            rev1.didAdvanceOrRevise
                && rev1.nextTarget.hasPrefix("我发现有一个问题就是我在打字用语音的过程中")
                && rev1.nextTarget.contains("出着出着字就不继续往前出了")
                && rev2.didAdvanceOrRevise
                && rev2.nextTarget.hasSuffix("现在测试连续跟出"),
            "Live inline typing never deadlocks on deep (>6 char) cloud revisions and continues streaming every utterance"
        )

        // 50. Live inline typing zero-stall when Doubao DDC deletes filler words mid-sentence
        let ddcEmitted = "我觉得那个嗯就是这个方案"
        let ddcShrink = LiveInputSession.reconcileLiveTargetAdvance(
            emitted: ddcEmitted,
            targetConfirmed: ddcEmitted,
            lastCloudRaw: ddcEmitted,
            newStable: "我觉得这个方案",
            isCloudStream: true
        )
        let ddcNext = LiveInputSession.reconcileLiveTargetAdvance(
            emitted: ddcEmitted,
            targetConfirmed: ddcShrink.nextTarget,
            lastCloudRaw: ddcShrink.nextCloudRaw,
            newStable: "我觉得这个方案非常丝滑",
            isCloudStream: true
        )
        expect(
            ddcShrink.nextCloudRaw == "我觉得这个方案"
                && ddcNext.didAdvanceOrRevise
                && ddcNext.nextTarget == "我觉得那个嗯就是这个方案非常丝滑",
            "Live inline typing absorbs Doubao DDC filler deletion with 0 payback stall on the very next syllable"
        )

        // 51. Empty-box guard detects sent/cleared input box on AX apps (prevents ghost re-paste after Enter/Send)
        expect(
            LiveInputSession.isBoxClearedAfterLiveEmit(currentBoxText: "", alreadyEmitted: "这是一段已经发出去的语音内容", isRichSlowEditor: false) == true
                && LiveInputSession.isBoxClearedAfterLiveEmit(currentBoxText: nil, alreadyEmitted: "这是一段在微信里的语音内容", isRichSlowEditor: true) == false
                && LiveInputSession.isBoxClearedAfterLiveEmit(currentBoxText: "", alreadyEmitted: "", isRichSlowEditor: false) == false,
            "Empty-box guard aborts re-paste when AX input box is cleared after live emit without breaking WeChat nil AX"
        )

        // 52. Atomic probe copyTimeout guard aborts blind Shift+Left re-paste into emptied box
        expect(
            LiveInputSession.shouldAbortOnAtomicProbeFailure(probeReason: "copyTimeout", alreadyEmitted: "已经发出去了的六十个字草稿") == true
                && LiveInputSession.shouldAbortOnAtomicProbeFailure(probeReason: "richMediaGuard", alreadyEmitted: "带图片的草稿") == false
                && LiveInputSession.shouldAbortOnAtomicProbeFailure(probeReason: "copyTimeout", alreadyEmitted: "") == false,
            "Atomic probe copyTimeout aborts blind Shift+Left re-paste when box was already emptied"
        )

        // 53. Physical Return/Enter detection triggers on bare Return / Cmd+Return and ignores Shift+Return soft newlines
        expect(
            HotkeyMonitor.isUserSubmitEnterKey(keyCode: 36, modifiers: []) == true
                && HotkeyMonitor.isUserSubmitEnterKey(keyCode: 36, modifiers: [.command]) == true
                && HotkeyMonitor.isUserSubmitEnterKey(keyCode: 76, modifiers: []) == true
                && HotkeyMonitor.isUserSubmitEnterKey(keyCode: 36, modifiers: [.shift]) == false
                && HotkeyMonitor.isUserSubmitEnterKey(keyCode: 36, modifiers: [.option]) == false,
            "Submit-Enter detector recognizes bare/Cmd Return while preserving Shift+Enter and Option+Enter soft newlines"
        )

        print("==> Summary: \(passed) passed, \(failed) failed.")
        return failed == 0 ? 0 : 1
    }

    /// Live dual-engine smoke benchmark (`TypeZero --bench-asr`): tests both Local 886MB FP32 SenseVoice and Cloud Volcengine Seed-ASR 2.0 on real audio without printing any credentials.
    public static func runDualASRSmokeBenchmark() -> Int32 {
        print("==> Running Dual-ASR Live Smoke Benchmark (Seed-ASR 2.0 + Local 886MB FP32)...")
        guard let paths = StreamingASREngine.senseVoiceModelPaths() else {
            print("  ✗ Local SenseVoice model not found.")
            return 1
        }
        let modelDir = URL(fileURLWithPath: paths.model).deletingLastPathComponent()
        let wavURL = modelDir.appendingPathComponent("test_wavs/zh.wav")
        guard let audioFile = try? AVAudioFile(forReading: wavURL) else {
            print("  ✗ Sample test_wavs/zh.wav not found at \(wavURL.path)")
            return 1
        }
        let fmt = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount),
              (try? audioFile.read(into: buf)) != nil,
              let ch0 = buf.floatChannelData?[0] else {
            return 1
        }
        let floatSamples = Array(UnsafeBufferPointer(start: ch0, count: Int(buf.frameLength)))
        let sr = Int32(fmt.sampleRate)

        // 1. Local 886MB SenseVoice FP32
        let tLoad0 = DispatchTime.now().uptimeNanoseconds
        guard let handle = tz_sensevoice_create(paths.model, paths.tokens, 6, "auto") else {
            print("  ✗ Failed to load SenseVoice model (\(paths.isFullFP32 ? "FP32" : "INT8"))")
            return 1
        }
        defer { tz_sensevoice_destroy(handle) }
        let loadMs = (DispatchTime.now().uptimeNanoseconds - tLoad0) / 1_000_000

        // Warm pass + timed pass
        floatSamples.withUnsafeBufferPointer { ptr in
            if let warmStr = tz_sensevoice_transcribe(handle, ptr.baseAddress, Int32(ptr.count), sr) {
                tz_sensevoice_free_string(warmStr)
            }
        }
        let tInf0 = DispatchTime.now().uptimeNanoseconds
        var localOut = ""
        floatSamples.withUnsafeBufferPointer { ptr in
            if let cStr = tz_sensevoice_transcribe(handle, ptr.baseAddress, Int32(ptr.count), sr) {
                localOut = String(cString: cStr)
                tz_sensevoice_free_string(cStr)
            }
        }
        let infMs = (DispatchTime.now().uptimeNanoseconds - tInf0) / 1_000_000
        print("  ✓ [Local Standby] SenseVoice (\(paths.isFullFP32 ? "886MB FP32 Full" : "INT8")): load=\(loadMs)ms, infer=\(infMs)ms -> 「\(localOut)」")

        // 2. Cloud Volcengine Doubao Seed-ASR 2.0 (`volc.seedasr.sauc.duration`)
        let speechKey = KeychainHelper.loadVolcSpeechAPIKey()
        guard !speechKey.isEmpty else {
            print("  ! Volcengine Speech API Key not set in Keychain; skipping cloud benchmark.")
            return 0
        }

        var finishedFlag = false
        var exitStatus: Int32 = 0
        Task {
            do {
                let probeRtt = try await VolcSeedASRClient.probeHandshakeLatency(apiKey: speechKey)
                let pcm16 = StreamingASREngine.resampleFloatTo16kHzInt16(floatSamples, sourceRate: fmt.sampleRate)
                print("  [diag] floatSamples=\(floatSamples.count) sr=\(fmt.sampleRate) -> pcm16=\(pcm16.count)")
                let client = VolcSeedASRClient()
                var partialsCount = 0
                client.onStreamingTranscript = { txt, def in
                    partialsCount += 1
                    print("  [stream #\(partialsCount) def=\(def)] \(txt)")
                }
                client.onConnectionFallbackNeeded = { reason in
                    print("  [failover] \(reason)")
                }
                client.startSession(
                    apiKey: speechKey,
                    hotwords: ["DeepSeek", "SwiftUI", "TypeZero", "SEO"],
                    dialogContext: ["我们刚刚确认了门店开放时间与海外 SEO 计划"]
                )
                // Wait 120ms for TLS+WS upgrade just like user starting to speak after pressing Fn, then stream at real-time 100ms cadence
                try? await Task.sleep(nanoseconds: 120_000_000)

                // Stream in realistic 100ms (1600-sample) slices at 95ms real-time mic cadence
                let step = 1600
                var idx = 0
                while idx < pcm16.count {
                    let end = min(pcm16.count, idx + step)
                    client.appendPCM16Samples(Array(pcm16[idx..<end]))
                    idx = end
                    try? await Task.sleep(nanoseconds: 95_000_000)
                }
                let tFin0 = DispatchTime.now().uptimeNanoseconds
                let cloudText = await client.finishAndAwaitFinalTranscript(timeoutMs: 1200) ?? ""
                let finTailMs = (DispatchTime.now().uptimeNanoseconds - tFin0) / 1_000_000
                if cloudText.isEmpty {
                    print("  ✗ [Cloud Primary] Seed-ASR 2.0 returned empty transcript")
                    exitStatus = 1
                } else {
                    print("  ✓ [Cloud Primary] Volcengine Seed-ASR 2.0 (volc.seedasr.sauc.duration): handshake_rtt=\(probeRtt)ms, tail_finalize=\(finTailMs)ms, streaming_frames=\(partialsCount) -> 「\(cloudText)」")
                }
            } catch {
                print("  ✗ [Cloud Primary] Seed-ASR 2.0 error: \(error.localizedDescription)")
                exitStatus = 1
            }
            finishedFlag = true
        }
        while !finishedFlag {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
        }
        return exitStatus
    }

    /// Scientific A/B verification on natural spoken Mandarin+English WAV (`TypeZero --ab-verify <wav>`).
    public static func runEmpiricalABVerification(wavPath: String) -> Int32 {
        let wavURL = URL(fileURLWithPath: wavPath)
        guard let audioFile = try? AVAudioFile(forReading: wavURL) else {
            print("  ✗ Could not read \(wavPath)")
            return 1
        }
        let fmt = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount),
              (try? audioFile.read(into: buf)) != nil,
              let ch0 = buf.floatChannelData?[0] else {
            return 1
        }
        let floatSamples = Array(UnsafeBufferPointer(start: ch0, count: Int(buf.frameLength)))
        var pcm16 = StreamingASREngine.resampleFloatTo16kHzInt16(floatSamples, sourceRate: fmt.sampleRate)
        // Trim leading TTS silence so `first_char` measures true speech-onset -> first-character latency!
        if let firstVoiceIdx = pcm16.firstIndex(where: { abs(Int($0)) > 650 }), firstVoiceIdx > 800 {
            pcm16.removeFirst(firstVoiceIdx - 480) // keep 30ms natural pre-roll
        }

        let speechKey = KeychainHelper.loadVolcSpeechAPIKey()
        guard !speechKey.isEmpty else {
            print("  ✗ Speech key empty")
            return 1
        }

        // Load user's actual local hotwords from Application Support (never printed to logs, only test output checked)
        let store = PersonalLexiconStore()
        let rankedHotwords = store.topAcousticContextualStrings(contextHint: "海外 SEO 投放增长", limit: 65)

        var done = false
        Task {
            // Shared client so TLS session ticket reuse is tested realistically across utterances!
            let sharedClient = VolcSeedASRClient()
            sharedClient.prewarmStandbySocket(apiKey: speechKey)
            try? await Task.sleep(nanoseconds: 250_000_000)

            func runCase(
                title: String,
                useColdClient: Bool,
                hotwords: [String],
                dialogCtx: [String],
                enableDDC: Bool,
                enableNonstream: Bool
            ) async -> String {
                let client = useColdClient ? VolcSeedASRClient() : sharedClient
                var firstCharMs: UInt64 = 0
                var firstPreview = ""
                var streamUpdates = 0
                let sessionStartNs = DispatchTime.now().uptimeNanoseconds

                client.onStreamingTranscript = { txt, _ in
                    streamUpdates += 1
                    if firstCharMs == 0 && !txt.isEmpty {
                        firstCharMs = (DispatchTime.now().uptimeNanoseconds - sessionStartNs) / 1_000_000
                        firstPreview = txt
                    }
                }
                client.startSession(
                    apiKey: speechKey,
                    hotwords: hotwords,
                    dialogContext: dialogCtx,
                    enableDDC: enableDDC,
                    enableNonstream: enableNonstream
                )

                // Feed 60ms slices at realistic 60ms microphone cadence immediately at t=0ms
                let step = 960
                var idx = 0
                while idx < pcm16.count {
                    let end = min(pcm16.count, idx + step)
                    client.appendPCM16Samples(Array(pcm16[idx..<end]))
                    idx = end
                    try? await Task.sleep(nanoseconds: 58_000_000)
                }

                let finStartNs = DispatchTime.now().uptimeNanoseconds
                let finalOut = await client.finishAndAwaitFinalTranscript(timeoutMs: 950) ?? "(nil)"
                let tailMs = (DispatchTime.now().uptimeNanoseconds - finStartNs) / 1_000_000
                print("  [\(title)] first_char=\(firstCharMs)ms (「\(firstPreview)」) | updates=\(streamUpdates) | tail_fin=\(tailMs)ms | final=「\(finalOut)」")
                return finalOut
            }

            let dynSampleCtx = ["正在讨论美国与日本的 SEO 增长以及 \(rankedHotwords.prefix(4).joined(separator: "、")) 项目进度"]
            print("==> Running Empirical A/B Verification (Loaded Lexicon=\(store.entries.count) terms, TopHotwords=\(rankedHotwords.count))...")
            _ = await runCase(title: "1: Bare (No Hotwords)", useColdClient: true, hotwords: [], dialogCtx: [], enableDDC: false, enableNonstream: false)
            let outHotOnly = await runCase(title: "2: WarmTLS + Hotwords ONLY", useColdClient: false, hotwords: rankedHotwords, dialogCtx: [], enableDDC: false, enableNonstream: false)
            let outBoth = await runCase(title: "3: WarmTLS + Hotwords + DialogCtx", useColdClient: false, hotwords: rankedHotwords, dialogCtx: dynSampleCtx, enableDDC: false, enableNonstream: false)

            // End-to-End Pass 1 Instant Dict + Pass 2 DeepSeek 4 Flash Polish
            let chosenRaw = outHotOnly.isEmpty ? outBoth : outHotOnly
            let pass1Instant = PolishEngine.applyInstantLocalDictionary(chosenRaw, entries: store.entries, context: .empty, config: .default, stripPeriod: false)
            let dsKey = KeychainHelper.loadAPIKey(for: "https://api.deepseek.com/v1")
            if !dsKey.isEmpty {
                let polishEngine = PolishEngine()
                polishEngine.prewarmConnection(baseURL: "https://api.deepseek.com/v1", apiKey: dsKey)
                try? await Task.sleep(nanoseconds: 150_000_000)
                let recalled = store.recallRelevantTerms(for: chosenRaw, activeWindowTitle: "", limit: 26)
                let (polished, ttftMs, _) = await polishEngine.polish(
                    rawTranscript: chosenRaw,
                    mode: .dictate,
                    screenContext: .empty,
                    recalledTerms: recalled,
                    recentOutputs: [],
                    config: .default,
                    apiKey: dsKey,
                    isHighAccuracyLocalASR: true
                )
                print("  [E2E Pass1 Instant] 「\(pass1Instant)」")
                print("  [E2E Pass2 DeepSeek TTFT=\(ttftMs)ms] 「\(polished)」")
            }
            done = true
        }

        while !done {
            RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.015))
        }
        return 0
    }
}
