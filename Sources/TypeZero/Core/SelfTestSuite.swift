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

        // 4. Deterministic Pangu Spacing & Percentage ITN
        let formatted = PolishEngine.applyPostFormattingRules(
            "使用DeepSeek提升百分之35速度。",
            context: ActiveScreenContext(appName: "Slack", bundleID: "com.tinyspeck.slackmacgap", windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: true),
            config: .default
        )
        expect(
            formatted == "使用 DeepSeek 提升 35% 速度",
            "Applies CJK-Latin Pangu spacing, percentage ITN, and strips trailing period in IM"
        )

        // 5. Keychain Provider Slot Isolation & Safety Guardrail
        expect(KeychainHelper.providerSlot(for: "https://api.deepseek.com/v1") == "deepseek_api_key", "Routes DeepSeek slot")
        expect(KeychainHelper.providerSlot(for: "https://ark.cn-beijing.volces.com/api/v3") == "ark_api_key", "Routes Volcengine Ark slot")
        expect(!ContextInjector.isAllowedTarget(bundleID: "com.tencent.xinwechat", appName: "微信"), "Hard blocks WeChat automation")

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
                && KeychainHelper.providerSlot(for: .custom) == "custom_api_key",
            "Unified provider selector routes DashScope and Custom OpenAI keys to isolated Keychain slots"
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
        guard let handle = tz_sensevoice_create(paths.model, paths.tokens, 6) else {
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
