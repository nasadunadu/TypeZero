import SwiftUI
import AppKit

// MARK: - Settings View (V3 Dual-Mode Engine Architecture · Self-Developed Cloud vs Custom BYOK/Offline)

private enum EnginePanelMode {
    case official
    case custom
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var scheme

    @State private var inspectedMode: EnginePanelMode = .official
    @State private var inspectedASR: ASRProviderOption = .volcSeedASR
    @State private var inspectedLLM: LLMProviderOption = .deepseek
    @State private var showVoucherDrawer: Bool = false

    @State private var draftLLMKey: String = ""
    @State private var draftLLMModel: String = ""
    @State private var draftLLMBaseURL: String = ""

    @State private var justClaimedTrial: Bool = false
    @State private var resendCooldown: Int = 0
    @State private var cooldownTimer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 13) {
                Text("设置")
                    .font(TZFont.title(24))
                    .foregroundStyle(TZTheme.inkPrimary)

                TZSegmentedBar(
                    items: SettingsSectionTab.allCases.map { tab in
                        TZSegmentedBar.Item(
                            title: tab.rawValue,
                            icon: tab.icon,
                            isSelected: appState.selectedSettingsTab == tab
                        ) {
                            withAnimation(.easeOut(duration: 0.16)) {
                                appState.selectedSettingsTab = tab
                            }
                        }
                    }
                )
            }

            switch appState.selectedSettingsTab {
            case .general:
                generalTabContent
            case .engines:
                enginesTabContent
            case .account:
                accountTabContent
            }
        }
        .onAppear {
            syncInspectedModeFromState()
            inspectedASR = appState.llmConfig.asrProvider
            inspectedLLM = appState.llmConfig.selectedProvider
            loadLLMDraft(for: inspectedLLM)
        }
        .onChange(of: appState.isOfficialCloudTrialActive) { _, isOfficial in
            if isOfficial {
                inspectedMode = .official
            }
        }
        .onChange(of: inspectedLLM) { _, next in
            loadLLMDraft(for: next)
        }
        .onDisappear {
            if appState.isRecordingShortcut {
                appState.cancelShortcutCapture()
            }
            cooldownTimer?.invalidate()
            cooldownTimer = nil
        }
    }

    private func syncInspectedModeFromState() {
        if appState.isOfficialCloudTrialActive {
            inspectedMode = .official
        } else if appState.hasPersonalBYOKASRReady
                    || (appState.llmConfig.asrProvider == .localSenseVoice && appState.senseVoiceLoaded)
                    || appState.isCloudTrialEnded {
            inspectedMode = .custom
        } else {
            inspectedMode = .official
        }
    }

    // MARK: - Tab 1: 通用与快捷键

    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            TZGroupedSection(title: "快捷键与交互") {
                // Row 1: Shortcut Keycap + Preset Menu + Record
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全局快捷键")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Text("在任意软件输入框按下即触发听写")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkMuted)
                    }

                    Spacer()

                    if appState.isRecordingShortcut {
                        HStack(spacing: 7) {
                            Text("按下任意修饰键或组合键…")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5.5)
                                .background(Capsule().fill(TZTheme.accent))
                            Button("取消") { appState.cancelShortcutCapture() }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        }
                    } else {
                        TZKeycapView(label: appState.activeTriggerCompactLabel, size: .medium, highlighted: true)

                        Menu {
                            ForEach(TriggerKeyOption.presetMatrixOrder) { opt in
                                Button {
                                    appState.triggerKey = opt
                                } label: {
                                    HStack {
                                        Text(opt.displayName)
                                        if appState.triggerKey == opt {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("切换预设")
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(TZTheme.inkMuted)
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(TZTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(TZTheme.cardBorder, lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()

                        Button {
                            appState.startShortcutCapture()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "record.circle")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(TZTheme.accent)
                                Text("录制")
                            }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                TZHairline(leadingInset: 16)

                settingsControlRow(title: "触发方式", subtitle: "录音中按 Esc 随时取消并撤回已上屏草稿") {
                    TZSegmentedBar(
                        items: [
                            .init(title: "点按启停", isSelected: appState.triggerBehavior == .tapToggle) {
                                appState.triggerBehavior = .tapToggle
                            },
                            .init(title: "按住说话", isSelected: appState.triggerBehavior == .holdToTalk) {
                                appState.triggerBehavior = .holdToTalk
                            }
                        ],
                        compact: true
                    )
                    .frame(width: 210)
                }

                TZHairline(leadingInset: 16)

                settingsControlRow(title: "上屏方式", subtitle: "支持前端实时逐字跳出或说完瞬间贴入") {
                    TZSegmentedBar(
                        items: [
                            .init(title: "逐字流式", isSelected: appState.llmConfig.enableLiveInlineTyping) {
                                appState.llmConfig.enableLiveInlineTyping = true
                            },
                            .init(title: "松手瞬贴", isSelected: !appState.llmConfig.enableLiveInlineTyping) {
                                appState.llmConfig.enableLiveInlineTyping = false
                            }
                        ],
                        compact: true
                    )
                    .frame(width: 210)
                }
            }

            // Appearance & Floating HUD Pickers (Refined Apple System Settings Grade Thumbnails!)
            TZGroupedSection(title: "外观与悬浮胶囊") {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("界面外观")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        HStack(spacing: 11) {
                            ForEach(AppAppearanceOption.allCases) { opt in
                                appearancePreviewCard(opt)
                            }
                        }
                    }

                    TZHairline()

                    VStack(alignment: .leading, spacing: 9) {
                        Text("悬浮听写胶囊")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        HStack(spacing: 11) {
                            ForEach(FloatingPillStyleOption.allCases) { styleOpt in
                                pillStylePreviewCard(styleOpt)
                            }
                        }
                    }
                }
                .padding(16)
            }

            // Smart Switches
            TZGroupedSection(title: "智能体验") {
                settingsSwitchRow(icon: "speaker.slash.fill", tint: TZTheme.accent, title: "听写时自动静音外放", subtitle: "录音结束自动恢复系统音量", isOn: $appState.llmConfig.enableAutoMuteDuringDictation)
                TZHairline(leadingInset: 54)
                settingsSwitchRow(icon: "hare.fill", tint: TZTheme.emerald, title: "28 字内短句免检直通", subtitle: "干净短句跳过云端排版，极速落字", isOn: $appState.llmConfig.enableFastBypassForShortPhrases)
                TZHairline(leadingInset: 54)
                settingsSwitchRow(icon: "waveform.and.mic", tint: TZTheme.cyan, title: "气声耳语自动增益 (25dB)", subtitle: "办公室小声说话也能清晰识别", isOn: $appState.llmConfig.enableWhisperAGC)
                TZHairline(leadingInset: 54)
                settingsSwitchRow(icon: "textformat.abc", tint: TZTheme.accent, title: "中英文盘古留白与数字规整", subtitle: "自动在中文与英文数字间补齐空格", isOn: $appState.llmConfig.enablePanguSpacing)
                TZHairline(leadingInset: 54)
                settingsSwitchRow(icon: "brain.head.profile", tint: TZTheme.amber, title: "改字无感自学习词库", subtitle: "监测到手动修正专有名词时自动沉淀", isOn: $appState.llmConfig.enableAutoLearn)
                TZHairline(leadingInset: 54)
                settingsSwitchRow(icon: "bubble.left.fill", tint: TZTheme.cyan, title: "聊天与终端去句末句号", subtitle: "在飞书、微信与终端中输出更自然", isOn: $appState.llmConfig.stripTrailingPeriodInChatApps)
                TZHairline(leadingInset: 54)
                settingsSwitchRow(icon: "dock.rectangle", tint: TZTheme.inkSecondary, title: "在程序坞 (Dock) 显示图标", subtitle: "关闭后仅静默常驻顶部菜单栏", isOn: $appState.llmConfig.showInDock)
            }

            // Permissions & Maintenance
            TZGroupedSection(title: "系统权限与维护") {
                HStack(spacing: 8) {
                    TZPermissionPill(title: "麦克风", ok: appState.micAuthorized)
                    TZPermissionPill(title: "辅助功能上屏", ok: appState.accessibilityGranted)
                    Spacer()
                    Button("请求权限") { appState.requestAllPermissions() }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    Button("重置缓存") { appState.resetStaleTCCAndOpenSettings() }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    Button("新手引导") { appState.showOnboardingSheet = true }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: Refined Authentic Apple-Grade Visual Previews (Matches v2-03!)

    private func appearancePreviewCard(_ opt: AppAppearanceOption) -> some View {
        let selected = (appState.llmConfig.appearance == opt)
        let isDarkUI = (scheme == .dark)

        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                appState.llmConfig.appearance = opt
            }
        } label: {
            VStack(spacing: 8) {
                // Soft miniature studio wallpaper behind crisp miniature macOS window
                ZStack {
                    LinearGradient(
                        colors: opt == .dark
                            ? [Color(red: 0.12, green: 0.14, blue: 0.24), Color(red: 0.08, green: 0.09, blue: 0.15)]
                            : [Color(red: 0.87, green: 0.89, blue: 0.96), Color(red: 0.93, green: 0.91, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Group {
                        switch opt {
                        case .light:
                            miniMacWindow(dark: false)
                        case .dark:
                            miniMacWindow(dark: true)
                        case .system:
                            HStack(spacing: 0) {
                                miniMacWindow(dark: false).clipped()
                                miniMacWindow(dark: true).clipped()
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(opt == .dark ? 0.18 : 0.75), lineWidth: 0.7)
                    )
                    .shadow(color: Color.black.opacity(0.22), radius: 5, x: 0, y: 2.5)
                    .padding(7)
                }
                .frame(height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                HStack(spacing: 5) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? TZTheme.accent : TZTheme.inkMuted.opacity(0.45))
                    Text(opt.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                selected
                    ? (isDarkUI ? Color(red: 0.16, green: 0.16, blue: 0.28) : Color(red: 0.955, green: 0.950, blue: 1.000))
                    : TZTheme.recessedWell.opacity(0.50)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? TZTheme.accent.opacity(0.75) : TZTheme.cardBorder, lineWidth: selected ? 1.4 : 0.9)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func miniMacWindow(dark: Bool) -> some View {
        HStack(spacing: 0) {
            // Mini pearl-lavender / obsidian sidebar
            VStack(alignment: .leading, spacing: 3.5) {
                HStack(spacing: 2.5) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 3.8, height: 3.8)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 3.8, height: 3.8)
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 3.8, height: 3.8)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(TZTheme.accent.opacity(dark ? 0.55 : 0.35))
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10))
                    .frame(width: 18, height: 3.5)
                Spacer()
            }
            .padding(5)
            .frame(width: 34)
            .background(dark ? Color(red: 0.10, green: 0.11, blue: 0.16) : Color(red: 0.92, green: 0.91, blue: 0.96))

            // Mini main pane with tiny aurora card + stat pills
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: dark
                                ? [Color(red: 0.19, green: 0.20, blue: 0.36), Color(red: 0.12, green: 0.26, blue: 0.40)]
                                : [Color(red: 0.90, green: 0.91, blue: 1.00), Color(red: 0.82, green: 0.94, blue: 1.00)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 12)
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                        .frame(height: 11)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                        .frame(height: 11)
                }
                Spacer()
            }
            .padding(5)
            .frame(maxWidth: .infinity)
            .background(dark ? Color(red: 0.06, green: 0.07, blue: 0.10) : Color.white)
        }
    }

    private func pillStylePreviewCard(_ opt: FloatingPillStyleOption) -> some View {
        let selected = (appState.llmConfig.floatingPillStyle == opt)
        let isDarkUI = (scheme == .dark)

        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                appState.llmConfig.floatingPillStyle = opt
            }
        } label: {
            VStack(spacing: 8) {
                // Unified refined studio backdrop across all 3 pill options!
                ZStack {
                    LinearGradient(
                        colors: isDarkUI
                            ? [Color(red: 0.10, green: 0.11, blue: 0.16), Color(red: 0.08, green: 0.09, blue: 0.13)]
                            : [Color(red: 0.91, green: 0.92, blue: 0.96), Color(red: 0.87, green: 0.89, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    miniCapsuleGraphic(for: opt)
                }
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                HStack(spacing: 5) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? TZTheme.accent : TZTheme.inkMuted.opacity(0.45))
                    Text(opt.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                selected
                    ? (isDarkUI ? Color(red: 0.16, green: 0.16, blue: 0.28) : Color(red: 0.955, green: 0.950, blue: 1.000))
                    : TZTheme.recessedWell.opacity(0.50)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? TZTheme.accent.opacity(0.75) : TZTheme.cardBorder, lineWidth: selected ? 1.4 : 0.9)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func miniCapsuleGraphic(for opt: FloatingPillStyleOption) -> some View {
        let isLightPill = (opt == .frostedLight)
        let isSplit = (opt == .system)

        return HStack(spacing: 7) {
            MobiusMarkView(size: 13.5, monochromeWhite: false)
            Canvas { ctx, size in
                let midY = size.height * 0.5
                for layer in (0..<3).reversed() {
                    var path = Path()
                    let phase = Double(layer) * 1.15 + 0.5
                    let freq = layer == 0 ? 2.6 : (layer == 1 ? 1.9 : 1.4)
                    let amp: CGFloat = (layer == 0 ? 5.6 : (layer == 1 ? 4.2 : 2.9))
                    for xInt in stride(from: 0, through: Int(size.width), by: 1) {
                        let x = CGFloat(xInt)
                        let norm = Double(x / max(1, size.width))
                        let env = pow(sin(norm * Double.pi), 1.25)
                        let y = midY + CGFloat(sin(norm * Double.pi * freq + phase) * Double(amp) * env)
                        if xInt == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    let lw: CGFloat = layer == 0 ? 1.7 : (layer == 1 ? 1.15 : 0.85)
                    let shading: GraphicsContext.Shading = layer == 0
                        ? .linearGradient(
                            Gradient(colors: isLightPill
                                ? [Color(red: 0.353, green: 0.275, blue: 0.910), Color(red: 0.08, green: 0.65, blue: 0.92)]
                                : [Color(red: 0.56, green: 0.50, blue: 1.00), Color(red: 0.24, green: 0.85, blue: 1.00)]),
                            startPoint: CGPoint(x: 0, y: midY),
                            endPoint: CGPoint(x: size.width, y: midY)
                        )
                        : .color((isLightPill ? TZTheme.accent : Color(red: 0.54, green: 0.50, blue: 1.0)).opacity(layer == 1 ? 0.45 : 0.22))
                    ctx.stroke(path, with: shading, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: 44, height: 15)
        }
        .padding(.horizontal, 13)
        .frame(height: 28)
        .background(
            Group {
                if isLightPill {
                    Capsule().fill(Color.white.opacity(0.95))
                } else if isSplit {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(red: 0.10, green: 0.11, blue: 0.15), Color(red: 0.26, green: 0.28, blue: 0.38)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                } else {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(red: 0.13, green: 0.14, blue: 0.18), Color(red: 0.06, green: 0.07, blue: 0.09)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: isLightPill
                            ? [Color.white, Color.black.opacity(0.10)]
                            : [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )
        )
        .shadow(color: Color.black.opacity(isLightPill ? 0.12 : 0.28), radius: 6, x: 0, y: 3)
    }

    // MARK: - Tab 2: 语音与引擎 (Dual-Mode Master Switch)

    private var enginesTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Master Mode Selector: TypeZero Self-Developed Cloud Engine vs Custom BYOK / Offline
            TZGroupedSection(title: "运行模式") {
                Text(appState.isOfficialCloudTrialActive ? "当前：超级 VIP（自研大模型）" : "当前：自定义引擎")
                    .font(TZFont.mono(11))
                    .foregroundStyle(TZTheme.inkMuted)
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        engineModeCard(
                            mode: .official,
                            title: "超级 VIP · 自研大模型",
                            subtitle: "注册免费送 1 个月 · 超快转换 · 智能整理去语病",
                            icon: "crown.fill",
                            isActive: appState.isOfficialCloudTrialActive,
                            gradient: [Color(red: 0.44, green: 0.36, blue: 1.0), Color(red: 0.06, green: 0.72, blue: 0.64)]
                        )
                        engineModeCard(
                            mode: .custom,
                            title: "自定义引擎（BYOK / 离线）",
                            subtitle: "绑定个人 API Key 无限用 · 或纯本机离线",
                            icon: "key.fill",
                            isActive: !appState.isOfficialCloudTrialActive,
                            gradient: [Color(red: 0.14, green: 0.56, blue: 0.96), Color(red: 0.36, green: 0.32, blue: 0.92)]
                        )
                    }

                    TZHairline()

                    if inspectedMode == .official {
                        officialCloudEnginePane
                    } else {
                        customEngineOverviewBar
                    }
                }
                .padding(16)
            }

            if inspectedMode == .custom {
                // Group 1: Custom ASR Engine Selector
                TZGroupedSection(title: "语音识别引擎 (ASR)") {
                    Button {
                        NSWorkspace.shared.open(CloudAuthClient.doubaoGuideURL)
                    } label: {
                        HStack(spacing: 3) {
                            Text("豆包语音开通教程")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                    }
                    .buttonStyle(.plain)
                } content: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            asrSelectorCard(
                                provider: .volcSeedASR,
                                title: "豆包 2.0",
                                subtitle: "中文首选 · 推荐组合",
                                icon: "waveform",
                                gradient: [Color(red: 0.44, green: 0.36, blue: 1.0), Color(red: 0.28, green: 0.46, blue: 0.98)]
                            )
                            asrSelectorCard(
                                provider: .openAIWhisper,
                                title: "OpenAI / Groq",
                                subtitle: "多语云端大模型",
                                icon: "cloud.fill",
                                gradient: [Color(red: 0.06, green: 0.65, blue: 0.92), Color(red: 0.12, green: 0.44, blue: 0.94)]
                            )
                            asrSelectorCard(
                                provider: .localSenseVoice,
                                title: "本地离线",
                                subtitle: appState.senseVoiceFullFP32 ? "886MB FP32 已就绪" : "永久 ¥0 零联网",
                                icon: "cpu.fill",
                                gradient: [Color(red: 0.08, green: 0.72, blue: 0.45), Color(red: 0.04, green: 0.54, blue: 0.34)]
                            )
                        }

                        TZHairline()

                        inspectedASRDetailPane
                    }
                    .padding(16)
                }

                // Group 2: Custom AI Formatting LLM Engine
                TZGroupedSection(title: "AI 智能成文 (LLM)") {
                    Button {
                        NSWorkspace.shared.open(CloudAuthClient.deepseekGuideURL)
                    } label: {
                        HStack(spacing: 3) {
                            Text("DeepSeek 开通教程")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TZTheme.accent)
                    }
                    .buttonStyle(.plain)
                } content: {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("模型服务商")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TZTheme.inkSecondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                                ForEach(LLMProviderOption.allCases) { p in
                                    llmProviderPill(p)
                                }
                            }
                        }

                        inspectedLLMDetailPane
                    }
                    .padding(16)
                }
            }

            // Shared Preferences Across Both Modes: Language & Formatting Strength
            TZGroupedSection(title: "识别与成文偏好") {
                Text("双模式通用生效")
                    .font(.system(size: 11))
                    .foregroundStyle(TZTheme.inkMuted)
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text("识别语言")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        TZSegmentedBar(
                            items: [
                                .init(title: "自动识别", isSelected: appState.llmConfig.speechLocale == "auto") {
                                    appState.setSpeechLocale("auto")
                                },
                                .init(title: "锁定中文", isSelected: appState.llmConfig.speechLocale == "zh-CN") {
                                    appState.setSpeechLocale("zh-CN")
                                },
                                .init(title: "锁定英文", isSelected: appState.llmConfig.speechLocale == "en-US") {
                                    appState.setSpeechLocale("en-US")
                                }
                            ],
                            compact: true
                        )
                        .frame(width: 280)
                    }

                    TZHairline()

                    HStack(spacing: 12) {
                        Text("整理力度")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        TZSegmentedBar(
                            items: [
                                .init(title: "结构化分点", isSelected: appState.llmConfig.formattingStyle == .structured) {
                                    appState.llmConfig.formattingStyle = .structured
                                },
                                .init(title: "轻度去口癖", isSelected: appState.llmConfig.formattingStyle == .lightPolish) {
                                    appState.llmConfig.formattingStyle = .lightPolish
                                },
                                .init(title: "原声直出", isSelected: appState.llmConfig.formattingStyle == .verbatimLocal) {
                                    appState.llmConfig.formattingStyle = .verbatimLocal
                                }
                            ],
                            compact: true
                        )
                        .frame(width: 310)
                    }

                    if appState.llmConfig.formattingStyle == .verbatimLocal {
                        TZInlineFeedbackBanner(message: "当前为「原声直出」，听写经本地词库修词后直接上屏，不调用云端成文润色。", isWarning: true)
                    }
                }
                .padding(16)
            }
        }
    }

    private func engineModeCard(
        mode: EnginePanelMode,
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        gradient: [Color]
    ) -> some View {
        let isInspected = (inspectedMode == mode)
        let isDarkUI = (scheme == .dark)

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                inspectedMode = mode
            }
            if mode == .official, let u = appState.cloudUser, u.effectiveTrial.isUsable, !appState.llmConfig.useOfficialCloudTrial {
                appState.setUseOfficialCloudTrial(true)
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: gradient[0].opacity(isInspected || isActive ? 0.30 : 0.12), radius: 4, y: 2)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 30, height: 30)

                    Spacer()

                    if isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(TZTheme.emerald)
                                .frame(width: 6, height: 6)
                                .shadow(color: TZTheme.emerald.opacity(0.6), radius: 3)
                            Text("生效中")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(TZTheme.emerald)
                        }
                        .padding(.horizontal, 7.5)
                        .padding(.vertical, 3)
                        .background(TZTheme.emeraldSoft)
                        .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(
                isInspected
                    ? (isDarkUI ? Color(red: 0.15, green: 0.15, blue: 0.26) : Color(red: 0.955, green: 0.950, blue: 1.000))
                    : TZTheme.recessedWell.opacity(0.50)
            )
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        isInspected
                            ? TZTheme.accent.opacity(0.80)
                            : (isActive ? TZTheme.emerald.opacity(0.45) : TZTheme.cardBorder),
                        lineWidth: isInspected ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var officialCloudEnginePane: some View {
        if let user = appState.cloudUser {
            let trial = user.effectiveTrial
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(trial.isUsable ? (trial.isLow ? TZTheme.amber : TZTheme.emerald) : TZTheme.inkMuted)
                                .frame(width: 7.5, height: 7.5)
                            Text(user.email)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                        }
                        Text(trial.isUsable
                             ? "TypeZero 自研云端语音 + 智能成文双引擎运行中 · 音频流式即用即焚"
                             : (trial.isExpired ? "1 个月免费体验已到期 · 词库与个人风格已完整保留" : "免费体验包已用完 · 词库与个人风格已完整保留"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }

                    Spacer()

                    if let days = trial.daysRemaining, trial.isUsable {
                        Text("剩余 \(days) 天")
                            .font(TZFont.mono(11.5, weight: .semibold))
                            .foregroundStyle(days <= 5 ? TZTheme.amber : TZTheme.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(days <= 5 ? TZTheme.amber.opacity(0.14) : TZTheme.accentSoft)
                            .clipShape(Capsule())
                    }
                }

                if trial.isUsable {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("免费体验包剩余")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TZTheme.inkSecondary)
                            Spacer()
                            Text("\(trial.remainingPercent)%")
                                .font(TZFont.metric(18))
                                .foregroundStyle(trial.isLow ? TZTheme.amber : TZTheme.emerald)
                        }

                        ProgressView(value: Double(trial.remainingPercent) / 100.0)
                            .tint(trial.isLow ? TZTheme.amber : TZTheme.accent)

                        HStack(spacing: 16) {
                            Label(
                                String(format: "语音识别：已用 %.1f / %d 分钟", trial.asrUsedMinutes, trial.asrQuotaMinutes),
                                systemImage: "mic.fill"
                            )
                            Label(
                                "智能成文：已用 \(trial.llmUsedCount) / \(trial.llmQuotaCount) 次",
                                systemImage: "sparkles"
                            )
                            Spacer()
                        }
                        .font(TZFont.mono(11))
                        .foregroundStyle(TZTheme.inkMuted)
                    }
                    .padding(12)
                    .background(TZTheme.recessedWell.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 10) {
                        if !appState.llmConfig.useOfficialCloudTrial {
                            Button("启用自研云端引擎") {
                                appState.setUseOfficialCloudTrial(true)
                            }
                            .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                        }

                        Text(appState.hasPersonalBYOKASRReady
                             ? "✓ 已预置个人引擎：免费体验用完后将自动无感无缝切换"
                             : "💡 提前填好个人 API Key 后，仍优先用完免费额度，用完自动无感接管")
                            .font(.system(size: 11.5))
                            .foregroundStyle(appState.hasPersonalBYOKASRReady ? TZTheme.emerald : TZTheme.inkSecondary)
                            .lineLimit(2)

                        Spacer()

                        if !appState.hasPersonalBYOKASRReady {
                            Button("提前配置 Key →") {
                                withAnimation(.easeOut(duration: 0.15)) { inspectedMode = .custom }
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        }

                        Button("刷新") {
                            Task { await appState.refreshCloudAccount() }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    }
                } else {
                    // Ended / Expired CTA Card inside Official Mode
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TypeZero 软件永久免费，无需会员订阅。2 分钟绑定个人 API Key（推荐豆包语音 + DeepSeek，日常每天仅约 5 分钱），或切本机离线永久 ¥0。")
                            .font(.system(size: 12))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button("去绑定个人 API Key →") {
                                appState.openCustomEngineSetup()
                                inspectedMode = .custom
                            }
                            .buttonStyle(TZPrimaryButtonStyle(compact: true, capsule: true))

                            Button("查看豆包 & DeepSeek 开通教程 ↗") {
                                NSWorkspace.shared.open(CloudAuthClient.byokGuideURL)
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                            Button("切本机离线（永久 ¥0）") {
                                appState.switchToLocalOfflineEngine()
                                inspectedMode = .custom
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                        }
                    }
                    .padding(12)
                    .background(TZTheme.amber.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TZTheme.amber.opacity(0.28), lineWidth: 1))
                }

                if justClaimedTrial {
                    Text("✓ 1 个月 TypeZero 自研云端引擎已免费激活，现在即可按快捷键开口！")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TZTheme.emerald)
                }
            }
        } else {
            // Not signed in yet: inline 15-second registration card
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("邮箱注册，免费领取 1 个月超级 VIP")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("包含自研大模型、超快语音转换、智能分段整理与自动去语病，零配置开箱即用。")
                        .font(.system(size: 12))
                        .foregroundStyle(TZTheme.inkSecondary)
                }

                if !appState.cloudCodeSent {
                    HStack(spacing: 8) {
                        TextField("输入常用邮箱（QQ / 163 / Gmail / Outlook）", text: $appState.cloudEmailInput)
                            .tzRecessedInput()
                            .onSubmit { triggerSendCode() }
                        Button(appState.isCloudAuthBusy ? "发送中…" : "获取验证码") {
                            triggerSendCode()
                        }
                        .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: false))
                        .disabled(appState.isCloudAuthBusy)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("6 位验证码已发送至 \(appState.cloudEmailInput)")
                                .font(.system(size: 12))
                                .foregroundStyle(TZTheme.inkSecondary)
                            Spacer()
                            Button("换邮箱") {
                                appState.cloudCodeSent = false
                                appState.cloudCodeInput = ""
                            }
                            .font(.system(size: 11.5))
                            .foregroundStyle(TZTheme.inkMuted)
                            .buttonStyle(.plain)
                            Button(resendCooldown > 0 ? "\(resendCooldown)s 后重发" : "重发") {
                                triggerSendCode()
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(resendCooldown > 0 ? TZTheme.inkMuted : TZTheme.accent)
                            .buttonStyle(.plain)
                            .disabled(resendCooldown > 0 || appState.isCloudAuthBusy)
                        }

                        HStack(spacing: 8) {
                            TextField("输入 6 位数字验证码", text: $appState.cloudCodeInput)
                                .tzRecessedInput()
                                .font(TZFont.mono(14, weight: .bold))
                                .frame(maxWidth: 220)
                                .onSubmit { triggerVerifyCode() }
                            Button(appState.isCloudAuthBusy ? "激活中…" : "验证并免费领取 1 个月") {
                                triggerVerifyCode()
                            }
                            .buttonStyle(TZAccentButtonStyle(compact: false, capsule: false))
                            .disabled(appState.isCloudAuthBusy)
                        }
                    }
                }

                if !appState.cloudAuthMessage.isEmpty {
                    TZInlineFeedbackBanner(message: appState.cloudAuthMessage)
                }
            }
        }
    }

    private var customEngineOverviewBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13.5))
                    .foregroundStyle(TZTheme.accent)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text("官方最省心推荐组合：豆包语音 2.0 + DeepSeek（每天约 5 分钱 · 充 ¥10 用半年）")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("TypeZero 软件本体永久 ¥0 订阅费；个人 API Key 仅存本机 Keychain 并直连官方，零中转更安心。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.open(CloudAuthClient.doubaoGuideURL)
                } label: {
                    HStack(spacing: 4) {
                        Text("🎙️ 豆包语音开通教程")
                        Image(systemName: "arrow.up.right").font(.system(size: 9.5, weight: .semibold))
                    }
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                Button {
                    NSWorkspace.shared.open(CloudAuthClient.deepseekGuideURL)
                } label: {
                    HStack(spacing: 4) {
                        Text("✨ DeepSeek 开通教程")
                        Image(systemName: "arrow.up.right").font(.system(size: 9.5, weight: .semibold))
                    }
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                Button {
                    NSWorkspace.shared.open(CloudAuthClient.byokGuideURL)
                } label: {
                    HStack(spacing: 4) {
                        Text("费用对比 & 排障")
                        Image(systemName: "arrow.up.right").font(.system(size: 9.5, weight: .semibold))
                    }
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                Spacer()

                if appState.isOfficialCloudTrialActive {
                    Button("立即切自定义模式") {
                        appState.setUseOfficialCloudTrial(false)
                    }
                    .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
                }
            }

            if appState.isOfficialCloudTrialActive {
                Text("💡 提示：你当前仍在使用免费「自研云端引擎」。现在填好下方个人 Key 会作为热备静默待命，免费额度用尽瞬间自动无缝切换！")
                    .font(.system(size: 11))
                    .foregroundStyle(TZTheme.emerald)
            }
        }
        .padding(12)
        .background(TZTheme.accentSoft.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(TZTheme.accent.opacity(0.24), lineWidth: 1))
    }

    private func asrSelectorCard(
        provider: ASRProviderOption,
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color]
    ) -> some View {
        let isActive = (appState.llmConfig.asrProvider == provider)
        let isInspected = (inspectedASR == provider)
        let isDarkUI = (scheme == .dark)

        return Button {
            withAnimation(.easeOut(duration: 0.14)) {
                inspectedASR = provider
            }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: gradient[0].opacity(isInspected || isActive ? 0.30 : 0.12), radius: 4, y: 2)
                        Image(systemName: icon)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 28, height: 28)

                    Spacer()

                    if isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(TZTheme.emerald)
                                .frame(width: 6, height: 6)
                                .shadow(color: TZTheme.emerald.opacity(0.6), radius: 3)
                            Text("生效中")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(TZTheme.emerald)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(TZTheme.emeraldSoft)
                        .clipShape(Capsule())
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                isInspected
                    ? (isDarkUI ? Color(red: 0.15, green: 0.15, blue: 0.26) : Color(red: 0.955, green: 0.950, blue: 1.000))
                    : TZTheme.recessedWell.opacity(0.50)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isInspected
                            ? TZTheme.accent.opacity(0.78)
                            : (isActive ? TZTheme.emerald.opacity(0.50) : TZTheme.cardBorder),
                        lineWidth: isInspected ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var inspectedASRDetailPane: some View {
        switch inspectedASR {
        case .volcSeedASR:
            let isActive = (appState.llmConfig.asrProvider == .volcSeedASR)
            let isActivating = (appState.activatingASRProvider == .volcSeedASR)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("火山豆包流式语音 2.0")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(CloudAuthClient.doubaoGuideURL)
                    } label: {
                        HStack(spacing: 3) {
                            Text("如何开通豆包 API Key？看 2 分钟图文教程")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Text("API Key")
                        .font(TZFont.mono(11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 56, alignment: .leading)
                    SecureField("粘贴火山豆包语音 API Key", text: $appState.volcSpeechKeyInput)
                        .tzRecessedInput(compact: true)
                        .onSubmit { appState.saveVolcSpeechAPIKey() }
                    Button("保存") { appState.saveVolcSpeechAPIKey() }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    Button(appState.isProbingSeedASR ? "测速中…" : "⚡ 测速") {
                        Task { await appState.runSeedASRProbe() }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    .disabled(appState.isProbingSeedASR || appState.activatingASRProvider != nil)

                    if !isActive {
                        Button(isActivating ? "校验中…" : "校验并切换") {
                            Task { _ = await appState.activateASRProvider(.volcSeedASR) }
                        }
                        .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                        .disabled(appState.activatingASRProvider != nil)
                    }
                }

                if showVoucherDrawer || appState.hasDoubaoVoucher {
                    voucherDrawerView
                } else {
                    HStack {
                        Button {
                            withAnimation(.easeOut(duration: 0.14)) { showVoucherDrawer = true }
                        } label: {
                            HStack(spacing: 4) {
                                Text("使用朋友赠送的官方增容码 / 兑换码")
                                Image(systemName: "chevron.right").font(.system(size: 9.5, weight: .semibold))
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }

                if let err = appState.asrActivationErrors[.volcSeedASR], !err.isEmpty {
                    TZInlineFeedbackBanner(message: err)
                } else if !appState.lastSeedASRProbeSummary.isEmpty {
                    TZInlineFeedbackBanner(message: appState.lastSeedASRProbeSummary)
                }
            }

        case .openAIWhisper:
            let isActive = (appState.llmConfig.asrProvider == .openAIWhisper)
            let isActivating = (appState.activatingASRProvider == .openAIWhisper)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("预设")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 56, alignment: .leading)
                    presetChip("OpenAI Mini", active: !appState.isGroqASRSelected && appState.llmConfig.openAIASRModel == "gpt-4o-mini-transcribe") {
                        appState.applyOpenAIASRPreset(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini-transcribe")
                    }
                    presetChip("OpenAI Full", active: !appState.isGroqASRSelected && appState.llmConfig.openAIASRModel == "gpt-4o-transcribe") {
                        appState.applyOpenAIASRPreset(baseURL: "https://api.openai.com/v1", model: "gpt-4o-transcribe")
                    }
                    presetChip("Groq Turbo", active: appState.isGroqASRSelected) {
                        appState.applyOpenAIASRPreset(baseURL: "https://api.groq.com/openai/v1", model: "whisper-large-v3-turbo")
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("接口")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 56, alignment: .leading)
                    TextField("https://api.openai.com/v1", text: $appState.llmConfig.openAIASRBaseURL)
                        .tzRecessedInput(compact: true)
                    TextField("模型 ID", text: $appState.llmConfig.openAIASRModel)
                        .tzRecessedInput(compact: true)
                        .frame(width: 175)
                }

                HStack(spacing: 8) {
                    Text("API Key")
                        .font(TZFont.mono(11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 56, alignment: .leading)
                    SecureField(
                        appState.isOpenAIASRReusingLLMKey ? "已复用 OpenAI 密钥（可留空）" : "粘贴 OpenAI / Groq API Key",
                        text: $appState.openAIASRKeyInput
                    )
                    .tzRecessedInput(compact: true)
                    .onSubmit { appState.saveOpenAIASRConfig() }

                    Button("保存") { appState.saveOpenAIASRConfig() }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    Button(appState.isProbingOpenAIASR ? "测速中…" : "⚡ 测速") {
                        Task { await appState.runOpenAIASRProbe() }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    .disabled(appState.isProbingOpenAIASR || appState.activatingASRProvider != nil)

                    if !isActive {
                        Button(isActivating ? "校验中…" : "校验并切换") {
                            Task { _ = await appState.activateASRProvider(.openAIWhisper) }
                        }
                        .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                        .disabled(appState.activatingASRProvider != nil)
                    }
                }

                if let err = appState.asrActivationErrors[.openAIWhisper], !err.isEmpty {
                    TZInlineFeedbackBanner(message: err)
                } else if !appState.lastOpenAIASRProbeSummary.isEmpty {
                    TZInlineFeedbackBanner(message: appState.lastOpenAIASRProbeSummary)
                }
            }

        case .localSenseVoice:
            let isActive = (appState.llmConfig.asrProvider == .localSenseVoice)
            let isActivating = (appState.activatingASRProvider == .localSenseVoice)
            VStack(alignment: .leading, spacing: 10) {
                if appState.isDownloadingOfflineModel {
                    HStack(spacing: 10) {
                        ProgressView(value: appState.offlineDownloadProgress).tint(TZTheme.accent)
                        Text(appState.offlineDownloadStatusText)
                            .font(TZFont.mono(11))
                            .foregroundStyle(TZTheme.accent)
                            .lineLimit(1)
                        Button("取消") { appState.cancelOfflineModelDownload() }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true))
                    }
                } else {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.senseVoiceFullFP32 ? "886MB SenseVoice FP32 满血包已就绪" : "本机零联网语音识别")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("音频 100% 留在本机内存，同时作为云端断网热备")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TZTheme.inkMuted)
                        }
                        Spacer()
                        if !appState.senseVoiceFullFP32 {
                            Button("下载 886MB 满血包") { appState.startOfflineModelDownload() }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        }
                        if !isActive {
                            Button(isActivating ? "校验中…" : "校验并切换") {
                                Task { _ = await appState.activateASRProvider(.localSenseVoice) }
                            }
                            .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                            .disabled(appState.activatingASRProvider != nil)
                        }
                    }
                }

                if let err = appState.asrActivationErrors[.localSenseVoice], !err.isEmpty {
                    TZInlineFeedbackBanner(message: err)
                }
            }
        }
    }

    private var voucherDrawerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("朋友兑换码（优先消耗赠送时长，用完自动切回自有 Key）")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                Spacer()
                if !appState.hasDoubaoVoucher {
                    Button("收起") {
                        withAnimation(.easeOut(duration: 0.14)) { showVoucherDrawer = false }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(TZTheme.inkMuted)
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                TextField("粘贴兑换码，如 TZ-XXXX-XXXX", text: $appState.doubaoVoucherInput)
                    .tzRecessedInput(compact: true)
                    .font(TZFont.mono(12))
                    .onSubmit { Task { await appState.saveDoubaoVoucherCode() } }
                Button("兑换激活") { Task { await appState.saveDoubaoVoucherCode() } }
                    .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                if appState.hasDoubaoVoucher {
                    Button("移除") {
                        appState.clearDoubaoVoucherCode()
                        showVoucherDrawer = false
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                }
            }

            if let vp = appState.voucherProfile, appState.hasDoubaoVoucher {
                let pct = vp.quotaMinutes > 0 ? min(1.0, vp.usedMinutes / vp.quotaMinutes) : 1.0
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(String(format: "%@ · 剩 %.1f / %.0f 分钟", vp.code, vp.remainingMinutes, vp.quotaMinutes))
                            .font(TZFont.mono(11, weight: .semibold))
                            .foregroundStyle((vp.exhausted || vp.revoked) ? TZTheme.crimson : TZTheme.inkPrimary)
                        Spacer()
                        Button("刷新") {
                            Task { await appState.refreshVoucherStatusIfApplicable(notifyUserOnLowOrExhausted: true) }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    }
                    ProgressView(value: pct)
                        .tint((vp.exhausted || vp.revoked) ? TZTheme.crimson : TZTheme.accent)
                }
            }
        }
        .padding(11)
        .background(TZTheme.accentSoft.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TZTheme.accent.opacity(0.24), lineWidth: 1))
    }

    private func llmProviderPill(_ provider: LLMProviderOption) -> some View {
        let isActive = (appState.llmConfig.selectedProvider == provider)
        let isInspected = (inspectedLLM == provider)
        let isDarkUI = (scheme == .dark)
        let hasKey = (appState.savedProviderKeyFlags[provider] ?? false)
            || (provider == .custom && PolishEngine.isKeylessLocalEndpoint(appState.llmConfig.customBaseURL))

        return Button {
            withAnimation(.easeOut(duration: 0.14)) {
                inspectedLLM = provider
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isActive ? TZTheme.emerald : (hasKey ? TZTheme.accent : TZTheme.inkMuted.opacity(0.32)))
                    .frame(width: 6.5, height: 6.5)
                    .shadow(color: isActive ? TZTheme.emerald.opacity(0.6) : .clear, radius: 3)
                Text(provider.shortName)
                    .font(.system(size: 12, weight: isInspected || isActive ? .semibold : .medium))
                    .foregroundStyle(isInspected || isActive ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isInspected
                    ? (isDarkUI ? Color(red: 0.16, green: 0.16, blue: 0.28) : Color(red: 0.955, green: 0.950, blue: 1.000))
                    : TZTheme.recessedWell.opacity(0.55)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isInspected
                            ? TZTheme.accent.opacity(0.75)
                            : (isActive ? TZTheme.emerald.opacity(0.45) : TZTheme.cardBorder),
                        lineWidth: isInspected ? 1.35 : 0.9
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var inspectedLLMDetailPane: some View {
        let provider = inspectedLLM
        let isActive = (appState.llmConfig.selectedProvider == provider)
        let isActivating = (appState.activatingLLMProvider == provider)
        let activationError = appState.llmActivationErrors[provider]
        let benchmarkSummary = appState.llmProviderBenchmarkSummaries[provider]
            ?? (isActive ? appState.lastBenchmarkSummary : "")

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(provider.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TZTheme.inkPrimary)
                if isActive {
                    Text("生效中")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TZTheme.emerald)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(TZTheme.emeraldSoft)
                        .clipShape(Capsule())
                }
                Spacer()
                if provider == .deepseek {
                    Button {
                        NSWorkspace.shared.open(CloudAuthClient.deepseekGuideURL)
                    } label: {
                        HStack(spacing: 3) {
                            Text("1 分钟开通 DeepSeek Key 教程")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(provider.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkMuted)
                        .lineLimit(1)
                }
            }

            if provider == .custom {
                HStack(spacing: 8) {
                    Text("接口")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 56, alignment: .leading)
                    TextField("https://api.siliconflow.cn/v1 或 http://localhost:11434/v1", text: $draftLLMBaseURL)
                        .tzRecessedInput(compact: true)
                    TextField("模型 ID", text: $draftLLMModel)
                        .tzRecessedInput(compact: true)
                        .frame(width: 170)
                }
            }

            HStack(spacing: 8) {
                Text("API Key")
                    .font(TZFont.mono(11.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                    .frame(width: 56, alignment: .leading)

                SecureField(
                    provider == .custom ? "API Key（本地 Ollama 可留空）" : "粘贴 \(provider.shortName) API Key",
                    text: $draftLLMKey
                )
                .tzRecessedInput(compact: true)
                .onSubmit { saveCurrentLLMDraft() }

                if provider != .custom {
                    TextField("模型 ID", text: $draftLLMModel)
                        .tzRecessedInput(compact: true)
                        .frame(width: 155)
                }

                Button("保存") { saveCurrentLLMDraft() }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))

                Button(appState.isBenchmarkingLLM ? "测速中…" : "⚡ 测速") {
                    Task {
                        await appState.runLLMProviderBenchmark(
                            provider: provider,
                            baseURL: draftLLMBaseURL,
                            modelName: draftLLMModel,
                            apiKey: draftLLMKey
                        )
                    }
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                .disabled(appState.isBenchmarkingLLM || appState.activatingLLMProvider != nil)

                if !isActive {
                    Button(isActivating ? "校验中…" : "校验并切换") {
                        Task {
                            _ = await appState.activateLLMProvider(
                                provider,
                                baseURL: draftLLMBaseURL,
                                modelName: draftLLMModel,
                                apiKey: draftLLMKey
                            )
                        }
                    }
                    .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
                    .disabled(appState.activatingLLMProvider != nil)
                }
            }

            if let err = activationError, !err.isEmpty {
                TZInlineFeedbackBanner(message: err)
            } else if !benchmarkSummary.isEmpty {
                TZInlineFeedbackBanner(message: benchmarkSummary)
            }
        }
        .padding(13)
        .background(TZTheme.recessedWell.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(TZTheme.cardBorder, lineWidth: 1))
    }

    // MARK: - Tab 3: 账户与关于

    private var accountTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            TZGroupedSection(title: "TypeZero 账户") {
                if let user = appState.cloudUser {
                    let trial = user.effectiveTrial
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 7) {
                                    Circle()
                                        .fill(trial.isUsable ? TZTheme.emerald : TZTheme.inkMuted)
                                        .frame(width: 7.5, height: 7.5)
                                    Text(user.email)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(TZTheme.inkPrimary)
                                }
                                Text(String(format: "已累计开口成文 %d 字 · 省时约 %.1f 小时", appState.totalCharactersDictated, appState.estimatedTimeSavedHours))
                                    .font(TZFont.mono(11.5))
                                    .foregroundStyle(TZTheme.inkMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(trial.isUsable ? "\(trial.remainingPercent)%" : (trial.isExpired ? "已到期" : "已用完"))
                                    .font(TZFont.metric(24))
                                    .foregroundStyle(trial.isUsable ? (trial.isLow ? TZTheme.amber : TZTheme.emerald) : TZTheme.amber)
                                Text(trial.daysRemaining.map { trial.isUsable ? "自研引擎 · 剩 \($0) 天" : "1 个月体验已结束" } ?? "自研云端引擎")
                                    .font(.system(size: 11))
                                    .foregroundStyle(TZTheme.inkMuted)
                            }
                        }

                        TZHairline()

                        HStack(spacing: 8) {
                            Button("管理语音与引擎") {
                                appState.selectedSettingsTab = .engines
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))

                            Button("API 开通教程 ↗") {
                                NSWorkspace.shared.open(CloudAuthClient.byokGuideURL)
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))

                            Spacer()

                            Button("刷新状态") { Task { await appState.refreshCloudAccount() } }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            Button("退出登录") { appState.logoutCloudAccount() }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true))
                        }
                    }
                    .padding(18)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("登录账号，免费领取 1 个月 TypeZero 自研云端引擎")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundStyle(TZTheme.inkPrimary)
                                Text("赠送 30 天（300 分钟语音识别 + 1,500 次智能成文），零配置开箱即用")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TZTheme.inkSecondary)
                            }
                            Spacer()
                            Button("立即去领取 →") {
                                inspectedMode = .official
                                appState.selectedSettingsTab = .engines
                            }
                            .buttonStyle(TZPrimaryButtonStyle(compact: true, capsule: true))
                        }
                    }
                    .padding(18)
                }
            }

            TZGroupedSection(title: "官方增容码 / 老友兑换码") {
                VStack(alignment: .leading, spacing: 10) {
                    voucherDrawerView
                }
                .padding(16)
            }

            TZGroupedSection(title: "软件更新与关于") {
                HStack(spacing: 12) {
                    TZBrandEmblemView(size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 7) {
                            Text("TypeZero")
                                .font(TZFont.brand(15.5))
                                .foregroundStyle(TZTheme.inkPrimary)
                            Text("v\(appState.currentAppVersion)")
                                .font(TZFont.mono(11))
                                .foregroundStyle(TZTheme.inkMuted)
                        }
                        Text(appState.availableUpdate.map { "发现新版本 \($0.tag)，支持应用内校验无损升级" } ?? "当前已是最新版本")
                            .font(.system(size: 12))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }
                    Spacer()
                    Button("新手引导") {
                        appState.showOnboardingSheet = true
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                    Button("API 配置教程 ↗") {
                        NSWorkspace.shared.open(CloudAuthClient.byokGuideURL)
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                    if appState.availableUpdate != nil {
                        Button(appState.isInstallingUpdate ? "更新中…" : "一键升级并重启") {
                            Task { await appState.installAvailableUpdate() }
                        }
                        .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
                        .disabled(appState.isInstallingUpdate)
                    } else {
                        Button(appState.isCheckingForUpdate ? "检查中…" : "检查更新") {
                            Task { await appState.checkForUpdates(manual: true) }
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                        .disabled(appState.isCheckingForUpdate)
                    }
                }
                .padding(16)

                if appState.isInstallingUpdate {
                    TZHairline()
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: appState.updateDownloadProgress).tint(TZTheme.accent)
                        Text(appState.updateStatusText)
                            .font(TZFont.mono(11))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: Row Helpers & Draft Sync

    private func settingsControlRow<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkMuted)
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12.5)
    }

    private func settingsSwitchRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .fill(tint.opacity(0.13))
                    .overlay(RoundedRectangle(cornerRadius: 7.5, style: .continuous).strokeBorder(tint.opacity(0.20), lineWidth: 0.7))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(TZTheme.inkMuted)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(TZTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10.5)
    }

    private func presetChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? TZTheme.accent : TZTheme.inkSecondary)
                .padding(.horizontal, 9.5)
                .padding(.vertical, 4.5)
                .background(active ? TZTheme.accentSoft : TZTheme.recessedWell)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(active ? TZTheme.accent.opacity(0.45) : TZTheme.cardBorder, lineWidth: 0.9))
        }
        .buttonStyle(.plain)
    }

    private func loadLLMDraft(for provider: LLMProviderOption) {
        draftLLMKey = KeychainHelper.loadAPIKey(for: provider)
        if appState.llmConfig.selectedProvider == provider {
            draftLLMModel = appState.llmConfig.modelName
            draftLLMBaseURL = appState.llmConfig.baseURL
        } else {
            draftLLMModel = appState.llmConfig.providerModels[provider.rawValue] ?? provider.defaultModelName
            draftLLMBaseURL = (provider == .custom && !appState.llmConfig.customBaseURL.isEmpty)
                ? appState.llmConfig.customBaseURL
                : provider.defaultBaseURL
        }
    }

    private func saveCurrentLLMDraft() {
        appState.saveLLMProviderDraft(
            provider: inspectedLLM,
            baseURL: draftLLMBaseURL,
            modelName: draftLLMModel,
            apiKey: draftLLMKey
        )
    }

    private func triggerSendCode() {
        Task {
            await appState.sendCloudEmailCode()
            if appState.cloudCodeSent {
                startCooldown()
            }
        }
    }

    private func triggerVerifyCode() {
        Task {
            await appState.verifyCloudEmailCode()
            if appState.cloudUser != nil {
                justClaimedTrial = true
            }
        }
    }

    private func startCooldown() {
        cooldownTimer?.invalidate()
        resendCooldown = 60
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                if resendCooldown > 1 {
                    resendCooldown -= 1
                } else {
                    resendCooldown = 0
                    timer.invalidate()
                }
            }
        }
    }
}
