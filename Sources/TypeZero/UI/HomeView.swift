import SwiftUI
import AppKit

// MARK: - Home View (Zero Truncation · Liquid-Silk Aurora Hero · Precision DIN KPIs)

struct HomeView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var scheme

    @State private var showSandbox: Bool = false

    private var isRecordingNow: Bool {
        if case .listening = appState.phase { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerBar

            readinessAuroraCard

            engineLifecycleBanner

            if showSandbox || isRecordingNow || !appState.sandboxText.isEmpty {
                inlineSandboxCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            metricsStrip

            activityRhythmCard

            quickAccessFooter
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: showSandbox)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isRecordingNow)
    }

    // MARK: Top Header Bar

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("主页")
                .font(TZFont.title(25))
                .foregroundStyle(TZTheme.inkPrimary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    showSandbox.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showSandbox ? "text.cursor" : "rectangle.and.pencil.and.ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(showSandbox ? TZTheme.accent : TZTheme.inkMuted)
                    Text("试音沙盒")
                }
            }
            .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

            Button {
                if isRecordingNow {
                    Task { await appState.finishDictationSession() }
                } else {
                    showSandbox = true
                    appState.beginDictationSession()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isRecordingNow ? "stop.fill" : "mic.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(isRecordingNow ? "停止并润色" : "开始试音")
                }
            }
            .buttonStyle(TZPrimaryButtonStyle(compact: false, capsule: true))
        }
    }

    // MARK: Real 3D Ray-Traced Silk-Glass Aurora Hero Banner (Powered by hero-aurora-light/dark.png!)

    private var readinessAuroraCard: some View {
        let isDark = (scheme == .dark)
        let heroAsset = isDark ? "hero-aurora-dark" : "hero-aurora-light"
        let triggerHint = appState.triggerBehavior == .tapToggle ? "按一下" : "按住"

        return ZStack(alignment: .leading) {
            // Base calm milky-pearl (Light) / smoked obsidian (Dark) glass layer
            LinearGradient(
                colors: isDark
                    ? [Color(red: 0.105, green: 0.112, blue: 0.175), Color(red: 0.115, green: 0.130, blue: 0.215)]
                    : [Color.white.opacity(0.92), Color(red: 0.962, green: 0.968, blue: 1.000).opacity(0.90)],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Restrained, desaturated silk-glass aurora wave masked cleanly to the right 55% (zero neon glare behind text!)
            GeometryReader { geo in
                if let heroImg = TZAssetStore.image(named: heroAsset) {
                    heroImg
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .saturation(isDark ? 0.78 : 0.62)
                        .opacity(isDark ? 0.62 : 0.56)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .clear, location: 0.36),
                                    .init(color: .white.opacity(0.45), location: 0.55),
                                    .init(color: .white, location: 0.78),
                                    .init(color: .white, location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .allowsHitTesting(false)

            // Subtle live pulse bloom when actively listening
            if isRecordingNow {
                RadialGradient(
                    colors: [TZTheme.accent.opacity(0.28), Color.clear],
                    center: UnitPoint(x: 0.78, y: 0.50),
                    startRadius: 10,
                    endRadius: 240
                )
                .allowsHitTesting(false)
            }

            // Layer 2: Real 3D Brushed-Aluminum / Obsidian Keycap + Hairline + Crisp 2-Line Headline
            HStack(spacing: 18) {
                TZKeycapView(
                    label: compactKeycapSymbol,
                    size: .large,
                    highlighted: isRecordingNow
                )

                Rectangle()
                    .fill(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.09))
                    .frame(width: 1, height: 54)

                VStack(alignment: .leading, spacing: 7) {
                    Text("\(triggerHint) \(appState.activeTriggerCompactLabel) 随时开口，\n说完自动上屏")
                        .font(.system(size: 17, weight: .bold))
                        .lineSpacing(3)
                        .foregroundStyle(TZTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(TZTheme.emerald)
                            .frame(width: 6.5, height: 6.5)
                            .shadow(color: TZTheme.emerald.opacity(0.75), radius: 3.5)
                        Text(activeEngineSummaryLine)
                            .font(TZFont.mono(11, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 175)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .frame(height: 124)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        // Crisp 360° crystal bevel rim (Matches v2-01/02!)
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isRecordingNow
                            ? [TZTheme.accent.opacity(0.85), TZTheme.cyan.opacity(0.65)]
                            : (isDark
                                ? [Color.white.opacity(0.24), Color.white.opacity(0.06), Color.white.opacity(0.14)]
                                : [Color.white, Color.white.opacity(0.45), Color.white.opacity(0.92)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isRecordingNow ? 1.6 : 1.25
                )
        )
        .shadow(
            color: Color(red: 0.36, green: 0.30, blue: 0.94).opacity(isRecordingNow ? 0.30 : (isDark ? 0.30 : 0.14)),
            radius: 18,
            x: 0,
            y: 7
        )
    }

    // MARK: Contextual Engine Lifecycle Banner (Zero-Noise Activation & Low-Quota Handover)

    @ViewBuilder
    private var engineLifecycleBanner: some View {
        if !appState.hasAnyEngineReady && !appState.isCloudTrialEnded {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TZTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(TZTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("注册免费领取 1 个月超级 VIP")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("解锁自研大模型 · 超快转换 · 智能整理 · 自动去语病")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                }

                Spacer()

                Button("免费领取超级 VIP") {
                    appState.showOnboardingSheet = true
                }
                .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(TZTheme.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(TZTheme.accent.opacity(0.28), lineWidth: 1))
        } else if appState.isCloudTrialLow && !appState.hasPersonalBYOKASRReady && !appState.lowTrialBannerDismissed,
                  let trial = appState.activeCloudTrial {
            let daysPart = trial.daysRemaining.map { " · 剩 \($0) 天" } ?? ""
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TZTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("1 个月免费体验剩余 \(trial.remainingPercent)%（约 \(Int(trial.asrRemainingMinutes.rounded())) 分钟\(daysPart)）")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("提前绑定个人 API Key（每天仅约 5 分钱），免费用完瞬间自动无感切换不断档")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                Spacer()
                Button("开通教程 ↗") {
                    NSWorkspace.shared.open(CloudAuthClient.byokGuideURL)
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                Button("去配置") {
                    appState.openCustomEngineSetup()
                }
                .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
                Button {
                    appState.lowTrialBannerDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(TZTheme.inkMuted)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(TZTheme.amber.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(TZTheme.amber.opacity(0.30), lineWidth: 1))
        } else if appState.isCloudTrialEnded && !appState.hasAnyEngineReady {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(TZTheme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("1 个月免费云端体验已完成")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("2 分钟绑定个人 API Key 继续无限用（每天约 5 分钱），或切本机离线永久 ¥0")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                Spacer()
                Button("查看教程 ↗") {
                    NSWorkspace.shared.open(CloudAuthClient.byokGuideURL)
                }
                .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                Button("绑定个人 Key") {
                    appState.openCustomEngineSetup()
                }
                .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(TZTheme.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(TZTheme.amber.opacity(0.32), lineWidth: 1))
        }
    }

    // MARK: Collapsible Lightweight Try-Out Sandbox

    private var inlineSandboxCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isRecordingNow ? TZTheme.accent : TZTheme.emerald)
                    .frame(width: 7, height: 7)
                Text(isRecordingNow ? "正在聆听，松开或再按快捷键即刻润色…" : "原位试音沙盒")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(TZTheme.inkPrimary)

                Spacer()

                if !appState.sandboxText.isEmpty {
                    Button("复制") {
                        ContextInjector.saveToSafetyClipboard(appState.sandboxText)
                        appState.statusBanner = "已复制试音文本"
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))

                    Button("清空") {
                        appState.sandboxText = ""
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                }

                if !isRecordingNow {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showSandbox = false
                            if appState.sandboxText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                appState.sandboxText = ""
                            }
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TZTheme.inkMuted)
                            .frame(width: 22, height: 22)
                            .background(TZTheme.recessedWell)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack(alignment: .topLeading) {
                if appState.sandboxText.isEmpty {
                    Text("按快捷键说一段话试试，例如：「今天做三件事，第一优化界面，第二测速接口，第三发版……」")
                        .font(.system(size: 13))
                        .foregroundStyle(TZTheme.inkMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $appState.sandboxText)
                    .font(.system(size: 13.5))
                    .foregroundStyle(TZTheme.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .frame(minHeight: 74, maxHeight: 120)
            }
            .background(TZTheme.recessedWell)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isRecordingNow ? TZTheme.accent.opacity(0.6) : TZTheme.cardBorder, lineWidth: 1)
            )
        }
        .tzElevatedCard(cornerRadius: 15, padding: 14, activeBorder: isRecordingNow ? TZTheme.accent.opacity(0.55) : nil)
    }

    // MARK: 3-Column DIN Alternate Metric Cards (Sparkline Overlaid Bottom-Right — ZERO Truncation!)

    private var metricsStrip: some View {
        let series = appState.recentDailySeries(days: 7)
        let savedHours = Double(appState.timeSavedMinutes) / 60.0
        let savedVal: String = appState.timeSavedMinutes >= 60
            ? String(format: "%.1f", savedHours)
            : "\(appState.timeSavedMinutes)"
        let savedUnit: String = appState.timeSavedMinutes >= 60 ? "小时" : "分钟"

        return HStack(spacing: 13) {
            metricCard(
                icon: "waveform",
                tint: TZTheme.accent,
                softTint: TZTheme.accentSoft,
                value: formatNumber(appState.totalCharactersDictated),
                unit: "字",
                label: "累计口述",
                sparkValues: series
            )
            metricCard(
                icon: "clock.fill",
                tint: TZTheme.emerald,
                softTint: TZTheme.emeraldSoft,
                value: savedVal,
                unit: savedUnit,
                label: "节省时间",
                sparkValues: series.map { $0 * 0.65 }
            )
            metricCard(
                icon: "bolt.fill",
                tint: TZTheme.cyan,
                softTint: TZTheme.cyanSoft,
                value: appState.averageCharactersPerMinute > 0 ? "\(appState.averageCharactersPerMinute)" : "—",
                unit: "字/分",
                label: "平均语速",
                sparkValues: Array(series.reversed())
            )
        }
    }

    private func metricCard(
        icon: String,
        tint: Color,
        softTint: Color,
        value: String,
        unit: String,
        label: String,
        sparkValues: [Double]
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(softTint)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(tint.opacity(0.24), lineWidth: 0.9)
                    )
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(TZFont.metric(24))
                        .foregroundStyle(TZTheme.inkPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                    Text(unit)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Text(label)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TZTheme.inkMuted)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            TZSparklineView(values: sparkValues, tint: tint)
                .allowsHitTesting(false)
        }
        .tzElevatedCard(cornerRadius: 15, padding: 15)
    }

    // MARK: 20-Week Refined Activity Rhythm Card (Softer Cells + Clean Proportions)

    private var activityRhythmCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2.5) {
                    Text("创作节律")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("今日 \(formatNumber(appState.todayCharactersDictated)) 字 · 累计活跃 \(appState.activeDaysCount) 天")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkMuted)
                }

                Spacer()

                HStack(spacing: 4.5) {
                    Text("少").font(.system(size: 10.5)).foregroundStyle(TZTheme.inkMuted)
                    ForEach([0, 120, 450, 1000], id: \.self) { sample in
                        RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                            .fill(TZActivityHeatmapGrid.cellColor(for: sample))
                            .frame(width: 11, height: 11)
                    }
                    Text("多").font(.system(size: 10.5)).foregroundStyle(TZTheme.inkMuted)
                }
            }

            TZActivityHeatmapGrid(dailyMap: appState.dailyCountMap())
        }
        .tzElevatedCard(cornerRadius: 16, padding: 18)
    }

    // MARK: Lightweight Quick-Jump Strip (Crisp Short Labels — ZERO Ellipsis!)

    private var quickAccessFooter: some View {
        HStack(spacing: 12) {
            quickJumpTile(
                icon: "clock.fill",
                tint: TZTheme.accent,
                title: "口述历史",
                subtitle: "\(appState.history.count) 条本地记录"
            ) {
                withAnimation(.easeOut(duration: 0.14)) { appState.selectedTab = .history }
            }

            quickJumpTile(
                icon: "book.closed.fill",
                tint: TZTheme.emerald,
                title: "个人词库",
                subtitle: "\(appState.lexiconStore.entries.count) 个专属热词"
            ) {
                withAnimation(.easeOut(duration: 0.14)) { appState.selectedTab = .dictionary }
            }

            quickJumpTile(
                icon: "waveform",
                tint: TZTheme.cyan,
                title: "语音与引擎",
                subtitle: appState.isOfficialCloudTrialActive ? "TypeZero 自研云端引擎" : "自定义引擎与额度"
            ) {
                appState.selectedSettingsTab = .engines
                withAnimation(.easeOut(duration: 0.14)) { appState.selectedTab = .settings }
            }
        }
    }

    private func quickJumpTile(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TZTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .tzElevatedCard(cornerRadius: 14, padding: 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private var compactKeycapSymbol: String {
        switch appState.triggerKey {
        case .fnKey: return "Fn"
        case .leftOption, .rightOption: return "⌥"
        case .leftCommand, .rightCommand: return "⌘"
        case .leftControl, .rightControl: return "⌃"
        case .leftShift, .rightShift: return "⇧"
        case .optionSpace: return "⌥␣"
        case .custom: return appState.customHotkey.label
        }
    }

    private var activeEngineSummaryLine: String {
        if appState.isOfficialCloudTrialActive {
            let modeText = appState.llmConfig.formattingStyle == .verbatimLocal ? "原声直出" : "智能整理"
            if appState.averagePolishLatencyMs > 0 {
                return "超级 VIP · 自研大模型  ·  \(modeText)  ·  \(appState.averagePolishLatencyMs) ms"
            }
            return "超级 VIP · 自研大模型  ·  \(modeText)"
        }
        let asr: String = {
            switch appState.llmConfig.asrProvider {
            case .volcSeedASR: return "豆包 2.0"
            case .openAIWhisper: return appState.isGroqASRSelected ? "Groq Whisper" : "OpenAI ASR"
            case .localSenseVoice: return appState.senseVoiceFullFP32 ? "本地 FP32" : "本地离线"
            }
        }()
        let llm: String = {
            if appState.llmConfig.formattingStyle == .verbatimLocal { return "原声直出" }
            return appState.llmConfig.selectedProvider.shortName
        }()
        if appState.averagePolishLatencyMs > 0 {
            return "\(asr)  ·  \(llm)  ·  \(appState.averagePolishLatencyMs) ms"
        }
        return "\(asr)  ·  \(llm)"
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - 20-Week Refined Activity Heatmap Grid (Softer Translucent Empty Cells)

struct TZActivityHeatmapGrid: View {
    let dailyMap: [Date: Int]
    private let weeks = 20
    private let daysPerWeek = 7

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        HStack(spacing: 5.5) {
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: 5.5) {
                    ForEach(0..<daysPerWeek, id: \.self) { d in
                        let offset = -((weeks - 1 - w) * 7 + (6 - d))
                        let dayDate = cal.date(byAdding: .day, value: offset, to: today) ?? today
                        let chars = dailyMap[dayDate] ?? 0
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Self.cellColor(for: chars))
                            .frame(maxWidth: .infinity)
                            .frame(height: 15)
                    }
                }
            }
        }
    }

    static func cellColor(for chars: Int) -> Color {
        if chars == 0 { return TZTheme.recessedWell.opacity(0.68) }
        if chars < 200 { return TZTheme.accent.opacity(0.32) }
        if chars < 800 { return TZTheme.accent.opacity(0.64) }
        return TZTheme.accent
    }
}

// MARK: - Reusable Quick Lexicon Fix Sheet (Used by History)

struct QuickLexiconFixSheet: View {
    let record: DictationRecord
    @Binding var term: String
    @Binding var alias: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("加入词库纠偏")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TZTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }

            Text(record.polishedText)
                .font(.system(size: 12))
                .foregroundStyle(TZTheme.inkSecondary)
                .lineLimit(3)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TZTheme.recessedWell)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("正确标准词")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                TextField("例如：DeepSeek / Antigravity / 张伟", text: $term)
                    .tzRecessedInput()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("被误听成的词（选填）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
                TextField("例如：迪普西克 / 反重力", text: $alias)
                    .tzRecessedInput()
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                Button("记入词库") {
                    let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, alias.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .buttonStyle(TZPrimaryButtonStyle(compact: true, capsule: false))
                .disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 400)
        .background(TZTheme.canvasBg)
    }
}
