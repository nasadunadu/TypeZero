import SwiftUI
import AppKit

// MARK: - Personal Writing Style View (Built-In Rules + Open Custom Style Input + Instant Live Preview)

struct StyleView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var scheme

    @State private var showTierExamples: Bool = false
    @State private var showBuiltInRules: Bool = true
    @State private var sampleInput: String = StyleSamplePreset.meeting.rawSpeech
    @State private var selectedSampleID: String = StyleSamplePreset.meeting.id
    @State private var previewScene: AppToneProfile = .instantMessaging
    @State private var isTestingStyle: Bool = false
    @State private var previewOutput: String = ""
    @State private var previewMeta: String = ""
    @State private var previewError: String = ""
    @State private var copiedPreview: Bool = false

    private struct StyleQuickPreset: Identifiable {
        let id: String
        let title: String
        let icon: String
        let prompt: String
    }

    private struct StyleSamplePreset: Identifiable {
        let id: String
        let title: String
        let scene: AppToneProfile
        let rawSpeech: String

        static let meeting = StyleSamplePreset(
            id: "meeting",
            title: "会议改期 + 列点",
            scene: .instantMessaging,
            rawSpeech: "嗯那个帮我同步一下两件事第一周三下午两点开会不对周三我不在改周四下午三点吧顺便把会议室订好第二新版的风格页今天晚上前测完就能发"
        )
        static let casual = StyleSamplePreset(
            id: "casual",
            title: "日常沟通吐槽",
            scene: .instantMessaging,
            rawSpeech: "我觉得现在这个流程其实有点绕就是说每次改完设置还要切去别的软件试一下才能知道效果不太直观能不能就在页面里直接点一下看结果呀"
        )
        static let techMixed = StyleSamplePreset(
            id: "techMixed",
            title: "中英技术沟通",
            scene: .aiPromptAndNotes,
            rawSpeech: "我们把 DeepSeek 的 system prompt 保持静态这样可以命中 KV cache 然后用户的 custom style 放到 user message 里面延迟基本不增加"
        )

        static let all: [StyleSamplePreset] = [meeting, casual, techMixed]
    }

    private static let quickPresets: [StyleQuickPreset] = [
        .init(
            id: "concise",
            title: "极简干练",
            icon: "bolt.fill",
            prompt: "说话直接干练，去掉多余客套和冗余过渡词，优先使用简洁短句，结论放前面，少用感叹号。"
        ),
        .init(
            id: "wechat",
            title: "微信松弛感",
            icon: "bubble.left.and.bubble.right.fill",
            prompt: "保持轻松自然的聊天口吻，不要书面化和公文腔，保留口语里的亲切感和“好的/没问题/哈哈”等自然回应，句子短一点更易读。"
        ),
        .init(
            id: "formal",
            title: "商务书面",
            icon: "envelope.fill",
            prompt: "整体语气礼貌克制、条理清晰，整理成偏正式的书面表达，但不要过度官腔；多条事项用清晰的编号呈现。"
        ),
        .init(
            id: "tech",
            title: "技术极客",
            icon: "chevron.left.forwardslash.chevron.right",
            prompt: "保持工程技术表达习惯，保留所有英文专有名词、代码符号、参数名和路径原貌，逻辑紧凑，要点用简洁列表展开。"
        )
    ]

    private var activeStyleText: String {
        appState.llmConfig.normalizedCustomStylePrompt
    }

    private var hasCustomStyle: Bool {
        !activeStyleText.isEmpty
    }

    private var activeEngineBadge: String {
        if appState.llmConfig.formattingStyle == .verbatimLocal {
            return "原声直出（本地）"
        }
        if appState.isOfficialCloudTrialActive {
            return "官方云端体验 · deepseek-flash"
        }
        return "\(appState.llmConfig.selectedProvider.shortName) · \(appState.llmConfig.modelName)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection
            coreSettingsSection
            customStyleSection
            livePreviewSection
            builtInRulesSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("个人风格")
                    .font(TZFont.title(24))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text("系统内置整理规则，叠加上你自己的说话习惯，让每次语音上屏都更像你亲手打的字")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
            Spacer()
            HStack(spacing: 5.5) {
                Circle()
                    .fill(hasCustomStyle ? TZTheme.accent : TZTheme.inkMuted.opacity(0.55))
                    .frame(width: 6.5, height: 6.5)
                Text(hasCustomStyle ? "已启用个人风格" : "使用系统默认风格")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(hasCustomStyle ? TZTheme.accent : TZTheme.inkSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(hasCustomStyle ? TZTheme.accentSoft : TZTheme.recessedWell)
            .clipShape(Capsule())
        }
    }

    // MARK: - Section 1: Core Formatting Tier & Built-In Switches

    private var coreSettingsSection: some View {
        TZGroupedSection(title: "基础整理设定") {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    showTierExamples.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showTierExamples ? "收起示例" : "查看示例")
                    Image(systemName: showTierExamples ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TZTheme.accent)
            }
            .buttonStyle(.plain)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("整理程度")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        TZSegmentedBar(
                            items: [
                                .init(title: "不整理", isSelected: appState.llmConfig.formattingStyle == .verbatimLocal) {
                                    appState.llmConfig.formattingStyle = .verbatimLocal
                                },
                                .init(title: "轻度整理", isSelected: appState.llmConfig.formattingStyle == .lightPolish) {
                                    appState.llmConfig.formattingStyle = .lightPolish
                                },
                                .init(title: "深度整理", isSelected: appState.llmConfig.formattingStyle == .structured) {
                                    appState.llmConfig.formattingStyle = .structured
                                }
                            ],
                            compact: true
                        )
                        .frame(width: 290)
                    }

                    Text(tierSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(TZTheme.inkSecondary)

                    if appState.llmConfig.formattingStyle == .verbatimLocal {
                        TZInlineFeedbackBanner(
                            message: "当前为「不整理（原声直出）」，听写仅经本地词库修词直接上屏；下方个人风格设定在切换为「轻度整理」或「深度整理」后生效。",
                            isWarning: true
                        )
                    }

                    if showTierExamples {
                        tierComparisonDrawer
                    }
                }
                .padding(16)

                TZHairline(leadingInset: 16)

                styleSwitchRow(
                    icon: "bubble.left.fill",
                    tint: TZTheme.cyan,
                    title: "聊天与终端去除结尾句号",
                    subtitle: "在微信、飞书、Slack 与终端等场景自动去掉末尾句号，沟通更自然",
                    isOn: $appState.llmConfig.stripTrailingPeriodInChatApps
                )

                TZHairline(leadingInset: 54)

                styleSwitchRow(
                    icon: "textformat.abc",
                    tint: TZTheme.accent,
                    title: "中英文盘古留白与数字规整",
                    subtitle: "自动在中英文与阿拉伯数字间补齐清爽空格（如「下午 3 点开会」）",
                    isOn: $appState.llmConfig.enablePanguSpacing
                )

                TZHairline(leadingInset: 54)

                styleSwitchRow(
                    icon: "hare.fill",
                    tint: TZTheme.emerald,
                    title: "28 字内短句免检直通",
                    subtitle: hasCustomStyle
                        ? "已填写个人风格：为保证风格一致，短句将自动走大模型润色"
                        : "未填个人风格时，干净短句跳过云端润色以实现 0ms 极速上屏",
                    isOn: $appState.llmConfig.enableFastBypassForShortPhrases
                )
            }
        }
    }

    private var tierSubtitle: String {
        switch appState.llmConfig.formattingStyle {
        case .verbatimLocal:
            return "不调用云端大模型，仅做本地词库纠偏后原样直出，零额外耗时。"
        case .lightPolish:
            return "删除“嗯、啊、那个”等口癖与中途改口，修正同音错字，保留原句式与语感。"
        case .structured:
            return "深度清理口语噪声、折叠反悔内容，按语义自然分段，多条事项自动拆分为 1. 2. 3. 清单。"
        }
    }

    private var tierComparisonDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("口述原声")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(TZTheme.inkMuted)
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2)
                    .background(TZTheme.recessedWell)
                    .clipShape(Capsule())
                Text("“嗯那个有两个事第一个周三开会不对改周四三点第二个把接口测一下”")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkSecondary)
            }

            HStack(alignment: .top, spacing: 8) {
                tierExampleCard(
                    title: "不整理",
                    active: appState.llmConfig.formattingStyle == .verbatimLocal,
                    text: "嗯那个有两个事第一个周三开会不对改周四三点第二个把接口测一下"
                )
                tierExampleCard(
                    title: "轻度整理",
                    active: appState.llmConfig.formattingStyle == .lightPolish,
                    text: "有两个事，第一个周四三点开会，第二个把接口测一下。"
                )
                tierExampleCard(
                    title: "深度整理",
                    active: appState.llmConfig.formattingStyle == .structured,
                    text: "有 2 件事：\n1. 周四 3 点开会；\n2. 把接口测一下。"
                )
            }
        }
        .padding(12)
        .background(TZTheme.recessedWell.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(TZTheme.hairline, lineWidth: 1)
        )
    }

    private func tierExampleCard(title: String, active: Bool, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? TZTheme.accent : TZTheme.inkSecondary)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(TZTheme.inkPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(9)
        .background(active ? TZTheme.cardElevated : TZTheme.cardBg.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(active ? TZTheme.accent.opacity(0.45) : TZTheme.hairline, lineWidth: active ? 1.1 : 0.8)
        )
    }

    // MARK: - Section 2: Open Custom Style Input (Blank by Default)

    private var customStyleSection: some View {
        let charCount = appState.llmConfig.customStylePrompt.count
        let maxChars = LLMConfig.maxCustomStylePromptLength

        return TZGroupedSection(title: "我的个人说话风格（留空即使用默认）") {
            HStack(spacing: 10) {
                Text("\(charCount) / \(maxChars)")
                    .font(TZFont.mono(11, weight: .medium))
                    .foregroundStyle(charCount >= maxChars ? TZTheme.amber : TZTheme.inkMuted)

                if !appState.llmConfig.customStylePrompt.isEmpty {
                    Button("清空") {
                        appState.llmConfig.customStylePrompt = ""
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Text("快捷参考：")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(Self.quickPresets) { preset in
                                let isMatched = appState.llmConfig.customStylePrompt.trimmingCharacters(in: .whitespacesAndNewlines) == preset.prompt
                                Button {
                                    appState.llmConfig.customStylePrompt = preset.prompt
                                } label: {
                                    HStack(spacing: 4.5) {
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(preset.title)
                                            .font(.system(size: 11.5, weight: .medium))
                                    }
                                    .foregroundStyle(isMatched ? TZTheme.accent : TZTheme.inkSecondary)
                                    .padding(.horizontal, 9.5)
                                    .padding(.vertical, 5)
                                    .background(isMatched ? TZTheme.accentSoft : TZTheme.recessedWell)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isMatched ? TZTheme.accent.opacity(0.40) : TZTheme.hairline, lineWidth: 0.9)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                ZStack(alignment: .topLeading) {
                    if appState.llmConfig.customStylePrompt.isEmpty {
                        Text("这里默认留空，可按需填写你个人的说话风格、措辞习惯或排版偏好。例如：\n• 说话直接干练，去掉客套废话，优先使用短句\n• 保持聊天松弛感，少用感叹号，保留“好的/没问题”等自然回应\n• 多条事项优先用简短清单呈现，英文术语保持原样")
                            .font(.system(size: 12.5))
                            .lineSpacing(3.5)
                            .foregroundStyle(TZTheme.inkMuted)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: Binding(
                        get: { appState.llmConfig.customStylePrompt },
                        set: { next in
                            if next.count > maxChars {
                                appState.llmConfig.customStylePrompt = String(next.prefix(maxChars))
                            } else {
                                appState.llmConfig.customStylePrompt = next
                            }
                        }
                    ))
                    .font(.system(size: 13))
                    .lineSpacing(3.5)
                    .foregroundStyle(TZTheme.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 116, maxHeight: 168)
                }
                .background(TZTheme.recessedWell)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(hasCustomStyle ? TZTheme.accent.opacity(0.32) : TZTheme.cardBorder, lineWidth: 1)
                )

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.emerald)
                    Text("输入即自动保存并全局生效；系统的「只整理不回答」与「原语种反翻译保护」底线始终开启。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkMuted)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Section 3: Instant Live Preview Playground

    private var livePreviewSection: some View {
        TZGroupedSection(title: "即时效果试跑") {
            Text(activeEngineBadge)
                .font(TZFont.mono(11, weight: .medium))
                .foregroundStyle(TZTheme.inkMuted)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Text("测试口语：")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6.5) {
                            ForEach(StyleSamplePreset.all) { sample in
                                let selected = (selectedSampleID == sample.id)
                                Button {
                                    selectedSampleID = sample.id
                                    sampleInput = sample.rawSpeech
                                    previewScene = sample.scene
                                } label: {
                                    Text(sample.title)
                                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                                        .foregroundStyle(selected ? TZTheme.accent : TZTheme.inkSecondary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4.5)
                                        .background(selected ? TZTheme.accentSoft : TZTheme.recessedWell)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            if let latest = appState.history.first {
                                let selected = (selectedSampleID == "latest_history")
                                Button {
                                    selectedSampleID = "latest_history"
                                    sampleInput = latest.rawTranscript
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 10))
                                        Text("用最近一条听写")
                                    }
                                    .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                                    .foregroundStyle(selected ? TZTheme.accent : TZTheme.inkSecondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4.5)
                                    .background(selected ? TZTheme.accentSoft : TZTheme.recessedWell)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                ZStack(alignment: .topLeading) {
                    if sampleInput.isEmpty {
                        Text("输入或粘贴任意一段口语原文，点击下方按钮即可预览最终上屏效果…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(TZTheme.inkMuted)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $sampleInput)
                        .font(.system(size: 12.5))
                        .lineSpacing(3)
                        .foregroundStyle(TZTheme.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(5)
                        .frame(height: 68)
                }
                .background(TZTheme.recessedWell)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(TZTheme.hairline, lineWidth: 1)
                )

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Text("模拟场景")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkMuted)
                        TZSegmentedBar(
                            items: [
                                .init(title: "即时聊天", isSelected: previewScene == .instantMessaging) {
                                    previewScene = .instantMessaging
                                },
                                .init(title: "邮件文档", isSelected: previewScene == .emailAndFormalDoc) {
                                    previewScene = .emailAndFormalDoc
                                },
                                .init(title: "笔记提问", isSelected: previewScene == .aiPromptAndNotes) {
                                    previewScene = .aiPromptAndNotes
                                }
                            ],
                            compact: true
                        )
                        .frame(width: 244)
                    }

                    Spacer()

                    Button {
                        runPreview()
                    } label: {
                        HStack(spacing: 5.5) {
                            if isTestingStyle {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(isTestingStyle ? "正在生成预览…" : "测试当前风格")
                        }
                    }
                    .buttonStyle(TZAccentButtonStyle(compact: true))
                    .disabled(isTestingStyle || sampleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !previewError.isEmpty {
                    HStack(spacing: 10) {
                        TZInlineFeedbackBanner(message: "❌ \(previewError)")
                        if previewError.contains("API Key") {
                            Button("去配置") {
                                appState.selectedSettingsTab = .engines
                                appState.selectedTab = .settings
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        }
                    }
                }

                if !previewOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            HStack(spacing: 5) {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(TZTheme.accent)
                                Text("最终上屏效果")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(TZTheme.inkPrimary)
                            }

                            if !previewMeta.isEmpty {
                                Text(previewMeta)
                                    .font(TZFont.mono(10.5, weight: .medium))
                                    .foregroundStyle(TZTheme.emerald)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(TZTheme.emeraldSoft)
                                    .clipShape(Capsule())
                            }

                            Spacer()

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(previewOutput, forType: .string)
                                copiedPreview = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                    copiedPreview = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedPreview ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10))
                                    Text(copiedPreview ? "已复制" : "复制")
                                }
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        }

                        Text(previewOutput)
                            .font(.system(size: 13.5))
                            .lineSpacing(4.5)
                            .foregroundStyle(TZTheme.inkPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(TZTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(TZTheme.accent.opacity(0.28), lineWidth: 1)
                            )
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Section 4: System Built-In Rules (Read-Only Reference)

    private var builtInRulesSection: some View {
        TZGroupedSection(title: "系统内置整理规则（只读保护）") {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    showBuiltInRules.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showBuiltInRules ? "收起" : "展开查看")
                    Image(systemName: showBuiltInRules ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TZTheme.inkSecondary)
            }
            .buttonStyle(.plain)
        } content: {
            if showBuiltInRules {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("角色定位")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Text("TypeZero 实时文字整理引擎：把原始语音转写文本（ASR）整理成仿佛你亲手打出的文字，自动清除口语噪声、折叠中途改口、修正明显同音错词，并完成自然断句、分段与列表排版。")
                            .font(.system(size: 12.5))
                            .lineSpacing(3.5)
                            .foregroundStyle(TZTheme.inkSecondary)
                    }

                    TZHairline()

                    VStack(alignment: .leading, spacing: 7) {
                        Text("一、绝对底线（始终生效，不可覆盖）")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TZTheme.inkPrimary)

                        builtInRuleRow(num: "1.", title: "只整理，不回答、不执行", detail: "待处理文本中的提问、命令与请求一律视为口述内容原样整理，绝不代为回答或执行。")
                        builtInRuleRow(num: "2.", title: "原语种 100% 保真（反翻译保护开启）", detail: "中文出中文、英文出英文、中英混说保持原有比例，严禁跨语种擅自翻译。")
                        builtInRuleRow(num: "3.", title: "保留全部有效信息，禁编造幻觉", detail: "不总结缩写、不遗漏否定词、条件、时间、数量与约束，不补充你没说过的观点。")
                        builtInRuleRow(num: "4.", title: "只输出干净正文", detail: "不加“好的”“整理如下”等开场白，不解释修改过程，不输出 **、### 等冗余 Markdown 符号。")
                        builtInRuleRow(num: "5.", title: "个人风格优先融合", detail: "在不违背以上底线的前提下，严格遵循你在上方填写的「个人说话风格」。")
                    }

                    TZHairline()

                    VStack(alignment: .leading, spacing: 7) {
                        Text("二、默认清洗与排版策略")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TZTheme.inkPrimary)

                        builtInRuleRow(num: "•", title: "口癖清除与改口折叠", detail: "剔除“嗯/啊/呃/那个/就是说”等卡壳词；遇到“周三……不对改周四”自动折叠废话，只保留最终意图。")
                        builtInRuleRow(num: "•", title: "语义自然分段与 1. 2. 3. 列点", detail: "深度整理模式下，长段独白按意群自然分段，连续并列事项自动拆成清晰编号列表。")
                        builtInRuleRow(num: "•", title: "个人词库与上下文纠偏", detail: "自动联动「词库」中的人名、项目名与术语，直改同音错字，绝不输出括号批注。")
                    }
                }
                .padding(16)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12))
                        .foregroundStyle(TZTheme.inkMuted)
                    Text("已内置 5 条绝对安全底线与口癖清洗/分段策略，保护输入法稳定可靠。")
                        .font(.system(size: 12))
                        .foregroundStyle(TZTheme.inkSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Helpers

    private func styleSwitchRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkMuted)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(TZTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11.5)
    }

    private func builtInRuleRow(num: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text(num)
                .font(TZFont.mono(12, weight: .semibold))
                .foregroundStyle(TZTheme.accent)
                .frame(width: 18, alignment: .leading)
            (Text(title + "：").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(TZTheme.inkPrimary)
                + Text(detail).font(.system(size: 12.5)).foregroundStyle(TZTheme.inkSecondary))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func runPreview() {
        let trimmed = sampleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTestingStyle else { return }
        isTestingStyle = true
        previewError = ""
        copiedPreview = false

        Task {
            do {
                let res = try await appState.runStylePreview(sampleText: trimmed, toneProfile: previewScene)
                await MainActor.run {
                    previewOutput = res.output
                    if res.usedLocalOnly {
                        previewMeta = "本地直出 · 0ms"
                    } else {
                        previewMeta = "首字 \(res.ttftMs)ms · 总耗时 \(res.totalMs)ms"
                    }
                    isTestingStyle = false
                }
            } catch {
                await MainActor.run {
                    previewError = error.localizedDescription
                    isTestingStyle = false
                }
            }
        }
    }
}
