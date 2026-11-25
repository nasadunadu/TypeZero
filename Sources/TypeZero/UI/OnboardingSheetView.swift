import SwiftUI

// MARK: - First-Run Onboarding Sheet (V2 High-Craft Clean 3-Step Setup)

struct OnboardingSheetView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                TZBrandEmblemView(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("欢迎使用 TypeZero")
                        .font(TZFont.title(19))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("完成以下 3 步，即可在任意输入框开口成文")
                        .font(.system(size: 12.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                Spacer()
                Text("v\(appState.currentAppVersion)")
                    .font(TZFont.mono(11, weight: .semibold))
                    .foregroundStyle(TZTheme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(TZTheme.accentSoft)
                    .clipShape(Capsule())
            }

            TZHairline()

            // Step 1: System Permissions
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    stepNumber("1")
                    Text("授予麦克风与辅助功能权限")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    TZPermissionPill(title: "麦克风", ok: appState.micAuthorized)
                    TZPermissionPill(title: "辅助功能", ok: appState.accessibilityGranted)
                }
                HStack(spacing: 10) {
                    Button("一键打开权限授权") {
                        appState.requestAllPermissions()
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: true, capsule: true))

                    Text("允许麦克风，并在「系统设置 → 辅助功能」开启 TypeZero")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
            }
            .tzElevatedCard(cornerRadius: 13, padding: 14)

            // Step 2: Free ¥1.00 Email Trial OR Personal BYOK API Keys
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    stepNumber("2")
                    Text("领 ¥1.00 免费体验 或 填入个人 API Key")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    if appState.isOfficialCloudTrialActive {
                        TZPermissionPill(title: "官方体验已激活", ok: true)
                    }
                }

                // Inline Email Trial Box
                VStack(alignment: .leading, spacing: 8) {
                    if let user = appState.cloudUser {
                        Text(String(format: "✓ 已登录 %@ · 剩余体验额度 ¥%.2f", user.email, user.balanceCny))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TZTheme.emerald)
                    } else {
                        Text("零配置马上试：输入邮箱免费领 ¥1.00（约 60 分钟豆包 2.0 + 300 次 DeepSeek 润色）")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                        HStack(spacing: 7) {
                            TextField("输入邮箱（Gmail / QQ / 163 / Outlook）", text: $appState.cloudEmailInput)
                                .tzRecessedInput(compact: true)
                            Button(appState.cloudCodeSent ? "重发" : "发验证码") {
                                Task { await appState.sendCloudEmailCode() }
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            .disabled(appState.isCloudAuthBusy)
                        }
                        if appState.cloudCodeSent {
                            HStack(spacing: 7) {
                                TextField("6 位验证码", text: $appState.cloudCodeInput)
                                    .tzRecessedInput(compact: true)
                                    .frame(maxWidth: 160)
                                Button("验证并领 ¥1.00") {
                                    Task { await appState.verifyCloudEmailCode() }
                                }
                                .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                                .disabled(appState.isCloudAuthBusy)
                            }
                        }
                    }
                    if !appState.cloudAuthMessage.isEmpty {
                        TZInlineFeedbackBanner(message: appState.cloudAuthMessage)
                    }
                }
                .padding(10)
                .background(TZTheme.accentSoft.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                HStack(spacing: 7) {
                    Picker("", selection: Binding(
                        get: { appState.llmConfig.asrProvider },
                        set: { appState.selectASRProvider($0) }
                    )) {
                        Text("豆包语音").tag(ASRProviderOption.volcSeedASR)
                        Text("OpenAI语音").tag(ASRProviderOption.openAIWhisper)
                        Text("仅本机离线").tag(ASRProviderOption.localSenseVoice)
                    }
                    .labelsHidden()
                    .frame(width: 98)

                    if appState.llmConfig.asrProvider == .volcSeedASR {
                        SecureField("粘贴火山豆包语音 API Key（选填）", text: $appState.volcSpeechKeyInput)
                            .tzRecessedInput(compact: true)
                        Button("保存") { appState.saveVolcSpeechAPIKey() }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    } else if appState.llmConfig.asrProvider == .openAIWhisper {
                        SecureField("粘贴 OpenAI / Groq API Key", text: $appState.openAIASRKeyInput)
                            .tzRecessedInput(compact: true)
                        Button("保存") { appState.saveOpenAIASRConfig() }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    } else {
                        Text("已选纯本机离线，可在下方下载 886MB 满血包")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack(spacing: 7) {
                    Picker("", selection: Binding(
                        get: { appState.llmConfig.selectedProvider },
                        set: { appState.selectLLMProvider($0) }
                    )) {
                        ForEach([LLMProviderOption.deepseek, .openai, .gemini, .anthropic, .volcengine, .dashscope], id: \.self) { p in
                            Text(p.shortName).tag(p)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 98)
                    SecureField("粘贴 \(appState.llmConfig.selectedProvider.shortName) API Key（选填）", text: $appState.apiKeyInput)
                        .tzRecessedInput(compact: true)
                    Button("保存") { appState.saveAPIKey() }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                }
            }
            .tzElevatedCard(cornerRadius: 13, padding: 14)

            // Step 3: Trigger Shortcut & Optional Offline Pack
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    stepNumber("3")
                    Text("选择顺手快捷键")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    TZKeycapView(label: appState.activeTriggerCompactLabel, size: .small, highlighted: true)
                }

                HStack(spacing: 6) {
                    ForEach([TriggerKeyOption.fnKey, .rightOption, .leftOption, .rightCommand, .optionSpace], id: \.self) { opt in
                        let selected = (appState.triggerKey == opt)
                        Button {
                            appState.triggerKey = opt
                        } label: {
                            Text(opt.compactSidebarLabel)
                                .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? TZTheme.accent : TZTheme.inkSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(selected ? TZTheme.accentSoft : TZTheme.recessedWell)
                                .clipShape(RoundedRectangle(cornerRadius: 7.5, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                                        .strokeBorder(selected ? TZTheme.accent.opacity(0.55) : TZTheme.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if appState.isDownloadingOfflineModel {
                    HStack(spacing: 8) {
                        ProgressView(value: appState.offlineDownloadProgress).tint(TZTheme.accent)
                        Text(appState.offlineDownloadStatusText)
                            .font(TZFont.mono(10.5))
                            .foregroundStyle(TZTheme.accent)
                            .lineLimit(1)
                    }
                } else if !appState.senseVoiceFullFP32 {
                    HStack(spacing: 8) {
                        Button("后台下载 886MB 离线满血模型") {
                            appState.startOfflineModelDownload()
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        Text("可选 · 经常无网/飞机上建议开启")
                            .font(.system(size: 11))
                            .foregroundStyle(TZTheme.inkMuted)
                    }
                }
            }
            .tzElevatedCard(cornerRadius: 13, padding: 14)

            // Footer
            HStack {
                Text("聚焦任意输入框 → 按 \(appState.activeTriggerCompactLabel) 说话 → 再按瞬间成稿")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkMuted)
                Spacer()
                Button("完成配置，开始体验") {
                    if !appState.volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        appState.saveVolcSpeechAPIKey()
                    }
                    if !appState.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        appState.saveAPIKey()
                    }
                    appState.completeOnboarding()
                }
                .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))
            }
        }
        .padding(24)
        .frame(width: 570)
        .background(TZTheme.canvasBg)
        .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
    }

    private func stepNumber(_ num: String) -> some View {
        Text(num)
            .font(TZFont.metric(12))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(TZTheme.accent)
            .clipShape(Circle())
    }
}
