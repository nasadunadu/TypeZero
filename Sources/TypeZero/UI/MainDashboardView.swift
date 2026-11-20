import SwiftUI
import AppKit

// MARK: - Swiss Warm Editorial Design System (Warm Parchment #F6F5F0 × Royal Violet #5A46E8)

enum TZTheme {
    static let paperBg      = Color(red: 0.965, green: 0.961, blue: 0.941) // #F6F5F0 Warm Parchment
    static let sidebarBg    = Color(red: 0.937, green: 0.925, blue: 0.894) // #EFECE4 Warm Linen
    static let cardBg       = Color(red: 0.992, green: 0.988, blue: 0.976) // #FDFCF9 Warm Porcelain
    static let sandWell     = Color(red: 0.918, green: 0.902, blue: 0.859) // #EAE6DB Sand Capsule / Well
    static let softWell     = Color(red: 0.953, green: 0.945, blue: 0.922) // #F3F1EB Subtle Input Fill
    static let inkPrimary   = Color(red: 0.090, green: 0.086, blue: 0.106) // #17161B Deep Pine Ink
    static let inkSecondary = Color(red: 0.400, green: 0.392, blue: 0.427) // #66646D Warm Graphite
    static let inkMuted     = Color(red: 0.565, green: 0.553, blue: 0.592) // #908D97 Muted Slate
    static let violet       = Color(red: 0.353, green: 0.275, blue: 0.910) // #5A46E8 Royal Violet
    static let lilacTint    = Color(red: 0.925, green: 0.914, blue: 0.984) // #ECE9FB Soft Lilac
    static let emerald      = Color(red: 0.078, green: 0.502, blue: 0.290) // #14804A Crisp Emerald
    static let emeraldTint  = Color(red: 0.890, green: 0.961, blue: 0.918)
    static let activeGreen       = Color(red: 0.055, green: 0.635, blue: 0.345) // #0EA258 Vibrant Running Green
    static let activeGreenBg     = Color(red: 0.875, green: 0.972, blue: 0.922) // #DFF8EB Fresh Mint Card Fill
    static let activeGreenBorder = Color(red: 0.075, green: 0.655, blue: 0.365) // #13A75D Crisp Active Border
    static let amber        = Color(red: 0.780, green: 0.435, blue: 0.055)
    static let amberTint    = Color(red: 0.988, green: 0.949, blue: 0.882)
    static let crimson      = Color(red: 0.820, green: 0.196, blue: 0.235)
    static let hairline     = Color(red: 0.090, green: 0.086, blue: 0.106).opacity(0.085)
    static let strongLine   = Color(red: 0.090, green: 0.086, blue: 0.106).opacity(0.16)
}

struct TZPrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 11 : 15)
            .padding(.vertical, compact ? 5.5 : 7.5)
            .background(
                RoundedRectangle(cornerRadius: compact ? 7 : 9)
                    .fill(TZTheme.violet.opacity(isEnabled ? (configuration.isPressed ? 0.84 : 1.0) : 0.40))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TZSecondaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    var destructive: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
            .foregroundStyle(destructive ? TZTheme.crimson : TZTheme.inkPrimary.opacity(isEnabled ? 0.88 : 0.4))
            .padding(.horizontal, compact ? 10 : 13)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: compact ? 7 : 9)
                    .fill(configuration.isPressed ? TZTheme.sandWell : TZTheme.softWell)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 7 : 9)
                    .strokeBorder(destructive ? TZTheme.crimson.opacity(0.28) : TZTheme.hairline, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
    }
}

struct TZEditorialHeader: View {
    let badge: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
                Text(badge)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(TZTheme.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(TZTheme.sandWell)
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                Rectangle()
                    .fill(TZTheme.violet)
                    .frame(width: 2.5, height: 14)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(TZTheme.inkSecondary)
            }

            Rectangle()
                .fill(TZTheme.strongLine)
                .frame(height: 1)
                .padding(.top, 2)
        }
    }
}

struct TZTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(TZTheme.inkPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7.5)
            .background(TZTheme.softWell)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(TZTheme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func tzInputStyle() -> some View {
        modifier(TZTextFieldModifier())
    }

    func tzCardSurface(cornerRadius: CGFloat = 14, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(TZTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(TZTheme.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.022), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Navigation Root Shell

public struct MainDashboardView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var lexiconStore: PersonalLexiconStore

    public init(appState: AppState) {
        self.appState = appState
        self.lexiconStore = appState.lexiconStore
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(TZTheme.hairline)
                .frame(width: 1)
            mainContent
        }
        .frame(minWidth: 960, minHeight: 650)
        .background(TZTheme.paperBg)
        .preferredColorScheme(.light)
        .sheet(isPresented: $appState.showOnboardingSheet) {
            OnboardingWizardSheet(appState: appState)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Brand Masthead
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(TZTheme.cardBg)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(TZTheme.hairline, lineWidth: 1))
                        MobiusMarkView(size: 21)
                    }
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text("TypeZero")
                            .font(.system(size: 17.5, weight: .bold, design: .serif))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Text(sidebarASRStatusText)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(sidebarASRStatusReady ? TZTheme.emerald : TZTheme.violet)
                    }
                }

                Rectangle()
                    .fill(TZTheme.hairline)
                    .frame(height: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 26)
            .padding(.bottom, 10)

            // Navigation Items
            ForEach(SidebarTab.allCases) { tab in
                let isSelected = (appState.selectedTab == tab)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        appState.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? TZTheme.violet : TZTheme.inkSecondary)
                            .frame(width: 20)
                        Text(tab.rawValue)
                            .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                        Spacer()
                        if tab == .dictionary {
                            Text("\(lexiconStore.entries.count)")
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(isSelected ? TZTheme.violet : TZTheme.inkMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isSelected ? TZTheme.lilacTint : TZTheme.sandWell.opacity(0.65))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(isSelected ? TZTheme.cardBg : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(isSelected ? TZTheme.hairline : Color.clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Bottom Engine Telemetry Card
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(appState.accessibilityGranted && appState.micAuthorized ? TZTheme.emerald : TZTheme.amber)
                        .frame(width: 7, height: 7)
                    Text(activeEngineShortLabel)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TZTheme.inkPrimary)
                        .lineLimit(1)
                    Spacer()
                }

                HStack {
                    Text("触发键")
                        .foregroundStyle(TZTheme.inkMuted)
                    Spacer()
                    Text(shortTriggerLabel)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(TZTheme.sandWell)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .font(.system(size: 11))

                if appState.averagePolishLatencyMs > 0 {
                    HStack {
                        Text("平均首包延迟")
                            .foregroundStyle(TZTheme.inkMuted)
                        Spacer()
                        Text("\(appState.averagePolishLatencyMs) ms")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(TZTheme.violet)
                    }
                    .font(.system(size: 11))
                }

                if !appState.accessibilityGranted {
                    Button {
                        appState.requestAllPermissions()
                    } label: {
                        Text("授权辅助功能上屏")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: true))
                    .padding(.top, 2)
                }
            }
            .padding(13)
            .background(TZTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(TZTheme.hairline, lineWidth: 1))
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 14)
        .frame(width: 226)
        .background(TZTheme.sidebarBg)
    }

    private var sidebarASRStatusReady: Bool {
        switch appState.llmConfig.asrProvider {
        case .volcSeedASR:
            return !appState.volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.senseVoiceLoaded
        case .openAIWhisper:
            return appState.hasEffectiveOpenAIASRKey || appState.senseVoiceLoaded
        case .localSenseVoice:
            return appState.senseVoiceLoaded
        }
    }

    private var sidebarASRStatusText: String {
        switch appState.llmConfig.asrProvider {
        case .volcSeedASR:
            if !appState.volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return appState.senseVoiceFullFP32 ? "SEED-ASR 2.0 + FP32" : "SEED-ASR 2.0 · CLOUD"
            }
        case .openAIWhisper:
            if appState.hasEffectiveOpenAIASRKey {
                let tag = appState.isGroqASRSelected ? "GROQ WHISPER" : "OPENAI ASR"
                return appState.senseVoiceFullFP32 ? "\(tag) + FP32" : "\(tag) · CLOUD"
            }
        case .localSenseVoice:
            break
        }
        if appState.senseVoiceLoaded {
            return appState.senseVoiceFullFP32 ? "SENSEVOICE FP32 · FULL" : "SENSEVOICE INT8 · LOCAL"
        }
        return "LOADING ENGINE…"
    }

    private var activeEngineShortLabel: String {
        if appState.llmConfig.formattingStyle == .verbatimLocal {
            return "纯原声不排版"
        }
        switch appState.llmConfig.selectedProvider {
        case .deepseek: return "DeepSeek 4 Flash"
        case .volcengine: return "火山 Doubao-Seed"
        case .dashscope: return "百炼 Qwen-Flash"
        case .openai: return "OpenAI \(appState.llmConfig.modelName)"
        case .gemini: return "Gemini \(appState.llmConfig.modelName)"
        case .anthropic: return "Claude \(appState.llmConfig.modelName)"
        case .custom: return appState.llmConfig.modelName
        }
    }

    private var shortTriggerLabel: String {
        appState.activeTriggerCompactLabel
    }

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !appState.statusBanner.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TZTheme.violet)
                        Text(appState.statusBanner)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Spacer()
                        Button {
                            appState.statusBanner = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TZTheme.inkMuted)
                                .padding(5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(TZTheme.lilacTint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(TZTheme.violet.opacity(0.22), lineWidth: 1))
                }

                switch appState.selectedTab {
                case .home:
                    HomeInsightsSection(appState: appState)
                case .history:
                    HistoryListSection(appState: appState)
                case .dictionary:
                    PersonalDictionarySection(appState: appState, lexiconStore: lexiconStore)
                case .settings:
                    EngineSettingsSection(appState: appState)
                }
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 32)
        }
    }
}

// MARK: - 1. Home Insights (Editorial 4-Column Strip + Activity Rhythm + Sandbox)

struct HomeInsightsSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TZEditorialHeader(
                badge: "ZERO-LATENCY VOICE ENGINE · V0.4",
                title: "说话，不要打字",
                subtitle: "端侧 SenseVoice 16kHz 单字匀速流式生长 ｜ 云端 DeepSeek 4 Flash 亚秒级结构化排版与专属词库纠偏"
            )

            // 4-Column Editorial Big-Number Strip (replaces bulky 2x2 white bricks)
            HStack(spacing: 0) {
                EditorialStatColumn(
                    value: formatCount(appState.totalCharactersDictated),
                    unit: "字",
                    label: "累计口述成稿",
                    highlight: true
                )
                verticalHairline
                EditorialStatColumn(
                    value: "\(appState.timeSavedMinutes)",
                    unit: "分钟",
                    label: "累计节省敲键时间"
                )
                verticalHairline
                EditorialStatColumn(
                    value: "\(appState.averageCharactersPerMinute)",
                    unit: "字/分",
                    label: "平均口述吞吐语速"
                )
                verticalHairline
                EditorialStatColumn(
                    value: appState.averagePolishLatencyMs > 0 ? "\(appState.averagePolishLatencyMs)" : "—",
                    unit: "ms",
                    label: "云端平均首包延迟"
                )
            }
            .tzCardSurface(cornerRadius: 15, padding: 22)

            // Activity Rhythm Heatmap Card
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("创作节律热力矩阵")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                        Text("过去 26 周每日语音创作密度分布 · 活跃 \(appState.activeDaysCount) 天 · 词库守护 \(appState.lexiconStore.entries.count) 词")
                            .font(.system(size: 12))
                            .foregroundStyle(TZTheme.inkSecondary)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Text("少").font(.system(size: 10.5)).foregroundStyle(TZTheme.inkMuted)
                        ForEach([0, 120, 450, 1000], id: \.self) { sample in
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(ActivityHeatmapGrid.cellColor(for: sample))
                                .frame(width: 10, height: 10)
                        }
                        Text("多").font(.system(size: 10.5)).foregroundStyle(TZTheme.inkMuted)
                    }
                }

                ActivityHeatmapGrid(dailyMap: appState.dailyCountMap())
            }
            .tzCardSurface(cornerRadius: 15, padding: 22)

            // Instant Test Playground
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isRecordingNow ? TZTheme.crimson : TZTheme.violet)
                            .frame(width: 8, height: 8)
                        Text("原位试音与排版沙盒")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                    }
                    Spacer()
                    if !appState.sandboxText.isEmpty {
                        Button("清空") {
                            appState.sandboxText = ""
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    }
                    Button {
                        if isRecordingNow {
                            Task { await appState.finishDictationSession() }
                        } else {
                            appState.beginDictationSession()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isRecordingNow ? "stop.fill" : "mic.fill")
                                .font(.system(size: 11))
                            Text(isRecordingNow ? "停止并触发排版" : "点击试音（或直接按快捷键）")
                        }
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: true))
                }

                Text("日常在任意外部软件（Antigravity / Cursor / 飞书 / 邮件）聚焦输入框后点按 \(appState.activeTriggerDisplayName) 即可直接原位出字；也可在此沙盒内试测 `1. 2. 3.` 列表与专属词库命中效果。")
                    .font(.system(size: 12))
                    .foregroundStyle(TZTheme.inkSecondary)

                ZStack(alignment: .topLeading) {
                    if appState.sandboxText.isEmpty {
                        Text("试着点按快捷键说：「我们今天做三件事，第一优化 SwiftUI 前端排版，第二检查 DeepSeek 接口延迟，第三推送到 GitHub 分支……」")
                            .font(.system(size: 13))
                            .foregroundStyle(TZTheme.inkMuted)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $appState.sandboxText)
                        .font(.system(size: 14))
                        .foregroundStyle(TZTheme.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 102, maxHeight: 150)
                }
                .background(TZTheme.softWell)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isRecordingNow ? TZTheme.violet.opacity(0.55) : TZTheme.hairline, lineWidth: isRecordingNow ? 1.4 : 1)
                )
            }
            .tzCardSurface(cornerRadius: 15, padding: 22)
        }
    }

    private var isRecordingNow: Bool {
        if case .listening = appState.phase { return true }
        return false
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(TZTheme.hairline)
            .frame(width: 1, height: 54)
            .padding(.horizontal, 18)
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 10_000 {
            return String(format: "%.1fK", Double(n) / 1000.0)
        }
        return "\(n)"
    }
}

struct EditorialStatColumn: View {
    let value: String
    let unit: String
    let label: String
    var highlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(highlight ? TZTheme.violet : TZTheme.inkPrimary)
                Text(unit)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(TZTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActivityHeatmapGrid: View {
    let dailyMap: [Date: Int]
    private let weeks = 26
    private let daysPerWeek = 7

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        HStack(spacing: 5) {
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: 5) {
                    ForEach(0..<daysPerWeek, id: \.self) { d in
                        let offset = -((weeks - 1 - w) * 7 + (6 - d))
                        let dayDate = cal.date(byAdding: .day, value: offset, to: today) ?? today
                        let chars = dailyMap[dayDate] ?? 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Self.cellColor(for: chars))
                            .frame(maxWidth: .infinity)
                            .frame(height: 12.5)
                    }
                }
            }
        }
    }

    static func cellColor(for chars: Int) -> Color {
        if chars == 0 { return TZTheme.sandWell.opacity(0.62) }
        if chars < 200 { return Color(red: 0.81, green: 0.78, blue: 0.97) }
        if chars < 800 { return Color(red: 0.58, green: 0.51, blue: 0.94) }
        return TZTheme.violet
    }
}

// MARK: - 2. History Section (Editorial Diff Cards + 1-Click Copy & Lexicon Backflow)

struct HistoryListSection: View {
    @ObservedObject var appState: AppState
    @State private var quickFixTerm: String = ""
    @State private var quickFixAlias: String = ""
    @State private var copiedRecordID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TZEditorialHeader(
                badge: "UTTERANCE ARCHIVE · \(appState.history.count) RECORDS",
                title: "口述历史与原声对照",
                subtitle: "保留每一条声学原稿与大模型结构化成品对照 ｜ 发现偶发误听可一键回流至专属词库"
            )

            // Quick correction bar
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13.5))
                    .foregroundStyle(TZTheme.violet)
                TextField("正确标准词（如 DeepSeek）", text: $quickFixTerm)
                    .tzInputStyle()
                TextField("刚才被误听成的词（如 迪普西克）", text: $quickFixAlias)
                    .tzInputStyle()
                Button("记入词库纠偏") {
                    guard !quickFixTerm.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    appState.lexiconStore.upsert(
                        term: quickFixTerm,
                        aliases: quickFixAlias.isEmpty ? [] : [quickFixAlias],
                        category: .project,
                        weight: 9
                    )
                    appState.statusBanner = "✅ 已将「\(quickFixTerm)」加入核心纠偏词库"
                    quickFixTerm = ""
                    quickFixAlias = ""
                }
                .buttonStyle(TZPrimaryButtonStyle())
            }
            .tzCardSurface(cornerRadius: 13, padding: 14)

            if appState.history.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("尚无口述记录")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("点按 \(appState.activeTriggerDisplayName) 口述任意内容后，此处将自动记录原声粗稿、排版成品与首包耗时。")
                        .font(.system(size: 13))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .tzCardSurface(cornerRadius: 14, padding: 26)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.history) { rec in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(rec.mode.rawValue)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2.5)
                                    .background(TZTheme.lilacTint)
                                    .foregroundStyle(TZTheme.violet)
                                    .clipShape(Capsule())

                                Text(rec.targetAppName.isEmpty ? "外部应用" : rec.targetAppName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(TZTheme.inkSecondary)

                                Spacer()

                                Text("首包 \(rec.polishLatencyMs)ms · 录音 \(String(format: "%.1fs", rec.durationSeconds))")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(TZTheme.inkMuted)

                                Button {
                                    ContextInjector.saveToSafetyClipboard(rec.polishedText)
                                    copiedRecordID = rec.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                        if copiedRecordID == rec.id { copiedRecordID = nil }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: copiedRecordID == rec.id ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 10.5))
                                        Text(copiedRecordID == rec.id ? "已复制" : "复制")
                                    }
                                }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            }

                            Text(rec.polishedText)
                                .font(.system(size: 14.5))
                                .lineSpacing(4)
                                .foregroundStyle(TZTheme.inkPrimary)
                                .textSelection(.enabled)

                            if rec.rawTranscript != rec.polishedText {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("声学原稿")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(TZTheme.inkMuted)
                                        .padding(.top, 1)
                                    Text(rec.rawTranscript)
                                        .font(.system(size: 12))
                                        .foregroundStyle(TZTheme.inkSecondary)
                                        .textSelection(.enabled)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(TZTheme.softWell)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .tzCardSurface(cornerRadius: 14, padding: 16)
                    }
                }
            }
        }
    }
}

// MARK: - 3. Personal Dictionary (Inline Editor + Category Filter Pills + Smart Merge)

struct PersonalDictionarySection: View {
    @ObservedObject var appState: AppState
    @ObservedObject var lexiconStore: PersonalLexiconStore

    @State private var newTerm: String = ""
    @State private var newAliases: String = ""
    @State private var newCategory: LexiconCategory = .person
    @State private var rawCorpusInput: String = ""
    @State private var isDistilling: Bool = false
    @State private var searchFilter: String = ""
    @State private var selectedCategoryFilter: LexiconCategory? = nil

    @State private var editingID: UUID? = nil
    @State private var editTerm: String = ""
    @State private var editAliases: String = ""
    @State private var editCategory: LexiconCategory = .person
    @State private var editPinnedCore: Bool = false

    @State private var isBatchMode: Bool = false
    @State private var selectedIDs: Set<UUID> = []

    var filteredEntries: [LexiconEntry] {
        lexiconStore.entries.filter { entry in
            if let cat = selectedCategoryFilter, entry.category != cat {
                return false
            }
            guard !searchFilter.isEmpty else { return true }
            return entry.term.localizedCaseInsensitiveContains(searchFilter) ||
                entry.phoneticKey.localizedCaseInsensitiveContains(searchFilter) ||
                entry.aliases.contains(where: { $0.localizedCaseInsensitiveContains(searchFilter) })
        }
    }

    private func beginInlineEdit(_ item: LexiconEntry) {
        editingID = item.id
        editTerm = item.term
        editAliases = item.aliases.joined(separator: "，")
        editCategory = item.category
        editPinnedCore = item.weight >= 9
    }

    private func commitInlineEdit(_ id: UUID) {
        let parsedAliases = editAliases
            .components(separatedBy: CharacterSet(charactersIn: ",，/、;；"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        lexiconStore.updateEntry(
            id: id,
            newTerm: editTerm,
            newAliases: parsedAliases,
            newCategory: editCategory,
            newWeight: editPinnedCore ? 10 : 7
        )
        appState.statusBanner = "✅ 已更新词条「\(editTerm)」并同步纠偏映射"
        editingID = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TZEditorialHeader(
                badge: "FUZZY PHONETIC INDEX · \(lexiconStore.entries.count) TERMS",
                title: "个人专属词库",
                subtitle: "模糊声韵骨架 0.5ms 极速近音召回 ｜ 点击任意词条即可原地修改标准词、编辑误听映射或一键删除"
            )

            // AI Corpus Distillation & Importer Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("会议纪要与名单智能提纯器")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.prompt = "扫描文件夹提取词条"
                        if panel.runModal() == .OK, let dir = panel.url {
                            let added = lexiconStore.importFromMarkdownFolder(dir, maxEntries: 120)
                            appState.statusBanner = "扫描文件夹完成：新增 \(added) 个高频词条"
                        }
                    } label: {
                        Label("扫描本地纪要目录", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))

                    Button {
                        let added = lexiconStore.importFromLocalBrowserHistory(maxEntries: 60)
                        appState.statusBanner = "已从本机浏览历史只读提取 \(added) 个高频专有词"
                    } label: {
                        Label("提取浏览高频词", systemImage: "safari")
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                }

                ZStack(alignment: .topLeading) {
                    if rawCorpusInput.isEmpty {
                        Text("在此粘贴会议纪要片段、PRD 文档或人名列表，可按行直接入库或交由大模型自动提纯专有名词与同音误听词…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(TZTheme.inkMuted)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $rawCorpusInput)
                        .font(.system(size: 13))
                        .foregroundStyle(TZTheme.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(height: 70)
                }
                .background(TZTheme.softWell)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TZTheme.hairline, lineWidth: 1))

                HStack {
                    Text("所有词条仅存储于本机 Application Support 目录，绝不进入代码仓库")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkMuted)
                    Spacer()
                    Button("按行直接导入") {
                        let lines = rawCorpusInput
                            .components(separatedBy: CharacterSet(charactersIn: "\n,，、;；"))
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { $0.count >= 2 }
                            .map { (term: $0, aliases: [String](), category: newCategory) }
                        let count = lexiconStore.bulkUpsert(lines)
                        rawCorpusInput = ""
                        appState.statusBanner = "直接批量导入 \(count) 个词条"
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    .disabled(rawCorpusInput.isEmpty)

                    Button(isDistilling ? "智能提纯中…" : "AI 自动提纯专有词") {
                        guard !rawCorpusInput.isEmpty, !isDistilling else { return }
                        isDistilling = true
                        let text = rawCorpusInput
                        Task {
                            await appState.distillPastedCorpus(text)
                            rawCorpusInput = ""
                            isDistilling = false
                        }
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: true))
                    .disabled(isDistilling || rawCorpusInput.isEmpty)
                }
            }
            .tzCardSurface(cornerRadius: 14, padding: 16)

            // Quick Single Entry Bar
            HStack(spacing: 10) {
                TextField("新增标准词（人名 / 产品 / 术语）", text: $newTerm)
                    .tzInputStyle()
                TextField("常见误听词，逗号分隔（可选）", text: $newAliases)
                    .tzInputStyle()
                Picker("", selection: $newCategory) {
                    ForEach(LexiconCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .labelsHidden()
                .frame(width: 115)

                Button("添加词条") {
                    let aliases = newAliases
                        .components(separatedBy: CharacterSet(charactersIn: ",，/、;；"))
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    lexiconStore.upsert(term: newTerm, aliases: aliases, category: newCategory, weight: 8)
                    newTerm = ""
                    newAliases = ""
                }
                .buttonStyle(TZPrimaryButtonStyle())
            }
            .tzCardSurface(cornerRadius: 13, padding: 13)

            // Category Filter Pills + Search + Batch Delete Toolbar
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    FilterPillButton(
                        title: "全部 (\(lexiconStore.entries.count))",
                        isActive: selectedCategoryFilter == nil
                    ) {
                        selectedCategoryFilter = nil
                    }

                    ForEach([LexiconCategory.person, .project, .memo, .autoLearned], id: \.self) { cat in
                        let cnt = lexiconStore.entries.filter { $0.category == cat }.count
                        if cnt > 0 || selectedCategoryFilter == cat {
                            FilterPillButton(
                                title: "\(cat.rawValue) (\(cnt))",
                                isActive: selectedCategoryFilter == cat
                            ) {
                                selectedCategoryFilter = (selectedCategoryFilter == cat) ? nil : cat
                            }
                        }
                    }

                    Spacer()

                    if isBatchMode && !selectedIDs.isEmpty {
                        Button {
                            let removedCount = selectedIDs.count
                            lexiconStore.removeBatch(ids: selectedIDs)
                            selectedIDs.removeAll()
                            appState.statusBanner = "🗑️ 已批量清理 \(removedCount) 个词条"
                        } label: {
                            Label("删除已选 (\(selectedIDs.count))", systemImage: "trash.fill")
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true))
                    }

                    Button(isBatchMode ? "完成批量清理" : "批量选择删除") {
                        isBatchMode.toggle()
                        if !isBatchMode { selectedIDs.removeAll() }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12.5))
                        .foregroundStyle(TZTheme.inkMuted)
                    TextField("搜索词条、误听词或拼音（如 deepseek / zhangwei / mcp）…", text: $searchFilter)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(TZTheme.inkPrimary)
                    if !searchFilter.isEmpty {
                        Button {
                            searchFilter = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(TZTheme.inkMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(TZTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TZTheme.hairline, lineWidth: 1))
            }

            // Editable Lexicon Rows
            LazyVStack(spacing: 8) {
                ForEach(filteredEntries) { item in
                    if editingID == item.id {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Circle().fill(TZTheme.violet).frame(width: 6, height: 6)
                                    Text("编辑词条映射")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(TZTheme.violet)
                                }
                                Spacer()
                                Toggle("★ 核心常驻置顶（100% 随句预热）", isOn: $editPinnedCore)
                                    .toggleStyle(.checkbox)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TZTheme.inkPrimary)
                            }

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("正确标准词")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TZTheme.inkSecondary)
                                    TextField("标准词", text: $editTerm)
                                        .tzInputStyle()
                                        .onSubmit { commitInlineEdit(item.id) }
                                }
                                .frame(width: 195)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("常见误听词（逗号或斜杠分隔，改标准词会自动把旧错词并入纠偏表）")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TZTheme.inkSecondary)
                                    TextField("误听词1，误听词2…", text: $editAliases)
                                        .tzInputStyle()
                                        .onSubmit { commitInlineEdit(item.id) }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("所属分类")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TZTheme.inkSecondary)
                                    Picker("", selection: $editCategory) {
                                        ForEach(LexiconCategory.allCases) { cat in
                                            Text(cat.rawValue).tag(cat)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 115)
                                }
                            }

                            HStack(spacing: 8) {
                                Button {
                                    editingID = nil
                                    lexiconStore.remove(id: item.id)
                                } label: {
                                    Label("删除此词", systemImage: "trash")
                                }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true))

                                Spacer()

                                Button("取消") {
                                    editingID = nil
                                }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true))

                                Button("保存修改") {
                                    commitInlineEdit(item.id)
                                }
                                .buttonStyle(TZPrimaryButtonStyle(compact: true))
                            }
                        }
                        .padding(15)
                        .background(TZTheme.lilacTint.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(TZTheme.violet.opacity(0.45), lineWidth: 1.2)
                        )
                    } else {
                        HStack(spacing: 10) {
                            if isBatchMode {
                                Button {
                                    if selectedIDs.contains(item.id) {
                                        selectedIDs.remove(item.id)
                                    } else {
                                        selectedIDs.insert(item.id)
                                    }
                                } label: {
                                    Image(systemName: selectedIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 15))
                                        .foregroundStyle(selectedIDs.contains(item.id) ? TZTheme.violet : TZTheme.inkMuted)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(item.term)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TZTheme.inkPrimary)

                            if item.weight >= 9 {
                                Text("★ 常驻")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(TZTheme.amberTint)
                                    .foregroundStyle(TZTheme.amber)
                                    .clipShape(Capsule())
                            }

                            Text(item.phoneticKey)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(TZTheme.inkMuted)

                            if !item.aliases.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(item.aliases.prefix(4), id: \.self) { al in
                                        Text(al)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(TZTheme.violet)
                                            .padding(.horizontal, 6.5)
                                            .padding(.vertical, 2)
                                            .background(TZTheme.lilacTint)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    if item.aliases.count > 4 {
                                        Text("+\(item.aliases.count - 4)")
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(TZTheme.inkMuted)
                                    }
                                }
                            }

                            Spacer()

                            Text(item.category.rawValue)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2.5)
                                .background(TZTheme.softWell)
                                .clipShape(Capsule())

                            Button {
                                beginInlineEdit(item)
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))

                            Button {
                                lexiconStore.remove(id: item.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11.5))
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9.5)
                        .background(TZTheme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(TZTheme.hairline, lineWidth: 1))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isBatchMode {
                                if selectedIDs.contains(item.id) {
                                    selectedIDs.remove(item.id)
                                } else {
                                    selectedIDs.insert(item.id)
                                }
                            } else {
                                beginInlineEdit(item)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct FilterPillButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? .white : TZTheme.inkSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5.5)
                .background(
                    Capsule()
                        .fill(isActive ? TZTheme.violet : TZTheme.sandWell.opacity(0.75))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4. Engine & Hotkey Settings (Left/Right Full Hotkey Matrix + Check-to-Activate Engine & Key Panels)

struct EngineSettingsSection: View {
    @ObservedObject var appState: AppState
    @State private var expandedASRProvider: ASRProviderOption? = nil
    @State private var expandedLLMProvider: LLMProviderOption? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TZEditorialHeader(
                badge: "STUDIO PREFERENCES",
                title: "引擎与快捷键设置",
                subtitle: "左右侧全套修饰键与自定义组合键一键绑定 ｜ 点开配置并校验通过后才切换唯一生效引擎"
            )

            // Card 1: Global Hotkey (Full Left & Right + Custom Recorder) & Input Behavior
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Text("1. 快捷键与输入方式")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    PermissionBadge(title: "麦克风", ok: appState.micAuthorized)
                    PermissionBadge(title: "辅助功能上屏", ok: appState.accessibilityGranted)
                }

                Divider().overlay(TZTheme.hairline)

                // Symmetric Left & Right Hotkey Selector + Click-to-Record
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("全局快捷键")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(TZTheme.violet)
                                .frame(width: 6, height: 6)
                            Text("当前生效：\(appState.activeTriggerDisplayName)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(TZTheme.violet)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(TZTheme.lilacTint)
                        .clipShape(Capsule())

                        Spacer()

                        if appState.isRecordingShortcut {
                            HStack(spacing: 6) {
                                Text("● 请按下左/右修饰键或组合键（Esc 取消）")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .background(Capsule().fill(TZTheme.violet))
                                Button("取消") {
                                    appState.cancelShortcutCapture()
                                }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            }
                        } else {
                            Button {
                                appState.startShortcutCapture()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "keyboard")
                                        .font(.system(size: 11))
                                    Text(appState.triggerKey == .custom ? "重录快捷键 (\(appState.customHotkey.label))" : "点击录制自定义键")
                                }
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        }
                    }

                    TZHotkeyPresetGrid(appState: appState)
                }
                .padding(.vertical, 2)

                Divider().overlay(TZTheme.hairline)

                TZMatrixControlRow(label: "触发方式") {
                    TZSegmentBar(
                        items: [
                            ("点按启停（免按住）", appState.triggerBehavior == .tapToggle, { appState.triggerBehavior = .tapToggle }),
                            ("按住说话 · 松开上屏", appState.triggerBehavior == .holdToTalk, { appState.triggerBehavior = .holdToTalk })
                        ]
                    )
                }

                Divider().overlay(TZTheme.hairline)

                TZMatrixControlRow(label: "上屏模式") {
                    TZSegmentBar(
                        items: [
                            ("胶囊跳符 · 松手瞬贴（默认）", !appState.llmConfig.enableLiveInlineTyping, { appState.llmConfig.enableLiveInlineTyping = false }),
                            ("开启前端输入框逐字跳出", appState.llmConfig.enableLiveInlineTyping, { appState.llmConfig.enableLiveInlineTyping = true })
                        ]
                    )
                }
            }
            .tzCardSurface(cornerRadius: 14, padding: 16)

            // Card 2: Acoustic Recognition Engine & Key (Expand to Inspect -> Verify & Activate Only on Explicit Confirm)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("2. 语音识别引擎与密钥")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Text("点开配置并校验通过后才生效 · 唯一生效引擎")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkMuted)
                }

                // ASR Option A: Doubao Seed-ASR 2.0 + Inline Key
                let volcASRActive = (appState.llmConfig.asrProvider == .volcSeedASR)
                let volcASRExpanded = (expandedASRProvider == .volcSeedASR)
                let hasVolcSpeechKey = !appState.volcSpeechKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let isActivatingVolc = (appState.activatingASRProvider == .volcSeedASR)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: volcASRExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(volcASRActive ? TZTheme.activeGreen : TZTheme.inkMuted.opacity(0.65))
                            .frame(width: 12, height: 12)
                        EngineStatusDot(isActive: volcASRActive)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 7) {
                                Text("豆包流式语音大模型 2.0")
                                    .font(.system(size: 13, weight: volcASRActive ? .semibold : .medium))
                                    .foregroundStyle(volcASRActive ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                                Text("Seed-ASR 2.0")
                                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(volcASRActive ? TZTheme.activeGreen : TZTheme.inkMuted)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(volcASRActive ? TZTheme.activeGreenBg : TZTheme.sandWell.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            if volcASRExpanded || volcASRActive {
                                Text("字节双向流国内直连 · 挂载专属词库热词 · 断网自动无损切回本机热备")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(volcASRActive ? TZTheme.inkSecondary : TZTheme.inkMuted)
                            }
                        }

                        Spacer()

                        KeyStatusPill(isConfigured: hasVolcSpeechKey, muted: !volcASRActive)
                        EngineStatusBadge(isActive: volcASRActive)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.14)) {
                            expandedASRProvider = volcASRExpanded ? nil : .volcSeedASR
                        }
                    }

                    if volcASRExpanded {
                        Divider().overlay(TZTheme.hairline)

                        HStack(spacing: 8) {
                            Text("API Key")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .frame(width: 60, alignment: .leading)
                            SecureField("粘贴火山豆包语音 API Key（绑定 volc.seedasr.sauc.duration）", text: $appState.volcSpeechKeyInput)
                                .tzCompactInputStyle()
                                .onSubmit { appState.saveVolcSpeechAPIKey() }
                            Button("保存") {
                                appState.saveVolcSpeechAPIKey()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            Button(appState.isProbingSeedASR ? "测速中…" : "⚡ 测速") {
                                Task { await appState.runSeedASRProbe() }
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            .disabled(appState.isProbingSeedASR || appState.activatingASRProvider != nil)
                            if !volcASRActive {
                                Button(isActivatingVolc ? "校验中…" : "校验并切换") {
                                    Task { _ = await appState.activateASRProvider(.volcSeedASR) }
                                }
                                .buttonStyle(TZPrimaryButtonStyle(compact: true))
                                .disabled(appState.activatingASRProvider != nil)
                            }
                        }

                        if let err = appState.asrActivationErrors[.volcSeedASR], !err.isEmpty {
                            InlineProbeBanner(message: err)
                        } else if !appState.lastSeedASRProbeSummary.isEmpty {
                            InlineProbeBanner(message: appState.lastSeedASRProbeSummary)
                        } else if !hasVolcSpeechKey {
                            InlineWarnBanner(message: "⚠️ 尚未填入火山语音 API Key；填入后点击「校验并切换」通过验证才会点亮生效。")
                        }
                    }
                }
                .tzSelectableEngineCard(isSelected: volcASRActive, isExpanded: volcASRExpanded)

                // ASR Option B: OpenAI / Groq Cloud Speech LLM (`/v1/audio/transcriptions`)
                let openAIASRActive = (appState.llmConfig.asrProvider == .openAIWhisper)
                let openAIASRExpanded = (expandedASRProvider == .openAIWhisper)
                let openAIKeylessLocal = PolishEngine.isKeylessLocalEndpoint(appState.llmConfig.openAIASRBaseURL)
                let openAIASRReady = appState.hasEffectiveOpenAIASRKey
                let isActivatingOpenAI = (appState.activatingASRProvider == .openAIWhisper)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: openAIASRExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(openAIASRActive ? TZTheme.activeGreen : TZTheme.inkMuted.opacity(0.65))
                            .frame(width: 12, height: 12)
                        EngineStatusDot(isActive: openAIASRActive)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 7) {
                                Text("OpenAI / Groq 云端语音大模型")
                                    .font(.system(size: 13, weight: openAIASRActive ? .semibold : .medium))
                                    .foregroundStyle(openAIASRActive ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                                Text(appState.llmConfig.openAIASRModel)
                                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(openAIASRActive ? TZTheme.activeGreen : TZTheme.inkMuted)
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(openAIASRActive ? TZTheme.activeGreenBg : TZTheme.sandWell.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            if openAIASRExpanded || openAIASRActive {
                                Text("支持 OpenAI gpt-4o-mini-transcribe 与 Groq whisper-large-v3-turbo · 自动复用 OpenAI Key · 注入专属热词")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(openAIASRActive ? TZTheme.inkSecondary : TZTheme.inkMuted)
                            }
                        }

                        Spacer()

                        if appState.isOpenAIASRReusingLLMKey {
                            Text("复用 OpenAI 密钥")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(openAIASRActive ? TZTheme.activeGreen : TZTheme.inkMuted)
                                .padding(.horizontal, 7.5)
                                .padding(.vertical, 2.5)
                                .background(openAIASRActive ? TZTheme.activeGreenBg : TZTheme.softWell.opacity(0.8))
                                .overlay(Capsule().strokeBorder(openAIASRActive ? TZTheme.activeGreen.opacity(0.28) : TZTheme.hairline, lineWidth: 0.8))
                                .clipShape(Capsule())
                        } else {
                            KeyStatusPill(isConfigured: openAIASRReady, keylessLocal: openAIKeylessLocal, muted: !openAIASRActive)
                        }
                        EngineStatusBadge(isActive: openAIASRActive)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.14)) {
                            expandedASRProvider = openAIASRExpanded ? nil : .openAIWhisper
                        }
                    }

                    if openAIASRExpanded {
                        Divider().overlay(TZTheme.hairline)

                        // Quick presets: OpenAI Mini / OpenAI Full / Groq Turbo
                        HStack(spacing: 6) {
                            Text("快捷预设")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .frame(width: 60, alignment: .leading)

                            TZASRPresetPill(
                                title: "OpenAI Mini",
                                isActive: !appState.isGroqASRSelected && appState.llmConfig.openAIASRModel == "gpt-4o-mini-transcribe"
                            ) {
                                appState.applyOpenAIASRPreset(baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini-transcribe")
                            }
                            TZASRPresetPill(
                                title: "OpenAI Full",
                                isActive: !appState.isGroqASRSelected && appState.llmConfig.openAIASRModel == "gpt-4o-transcribe"
                            ) {
                                appState.applyOpenAIASRPreset(baseURL: "https://api.openai.com/v1", model: "gpt-4o-transcribe")
                            }
                            TZASRPresetPill(
                                title: "Groq 极速 Whisper",
                                isActive: appState.isGroqASRSelected
                            ) {
                                appState.applyOpenAIASRPreset(baseURL: "https://api.groq.com/openai/v1", model: "whisper-large-v3-turbo")
                            }
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Text("接口地址")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .frame(width: 60, alignment: .leading)
                            TextField("https://api.openai.com/v1 或 https://api.groq.com/openai/v1", text: $appState.llmConfig.openAIASRBaseURL)
                                .tzCompactInputStyle()
                            Text("模型 ID")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TZTheme.inkSecondary)
                            TextField("gpt-4o-mini-transcribe", text: $appState.llmConfig.openAIASRModel)
                                .tzCompactInputStyle()
                                .frame(width: 185)
                        }

                        HStack(spacing: 8) {
                            Text("API Key")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(TZTheme.inkSecondary)
                                .frame(width: 60, alignment: .leading)
                            SecureField(
                                appState.isGroqASRSelected
                                    ? "粘贴 Groq API Key (gsk_...)"
                                    : (appState.isOpenAIASRReusingLLMKey
                                        ? "已自动复用下方 OpenAI 密钥（留空即可，或填入独立覆盖 Key）"
                                        : "粘贴 OpenAI API Key（若下方已填 OpenAI 排版 Key 将自动复用）"),
                                text: $appState.openAIASRKeyInput
                            )
                            .tzCompactInputStyle()
                            .onSubmit { appState.saveOpenAIASRConfig() }

                            Button("保存") {
                                appState.saveOpenAIASRConfig()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))

                            Button(appState.isProbingOpenAIASR ? "测速中…" : "⚡ 测速") {
                                Task { await appState.runOpenAIASRProbe() }
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            .disabled(appState.isProbingOpenAIASR || appState.activatingASRProvider != nil)

                            if !openAIASRActive {
                                Button(isActivatingOpenAI ? "校验中…" : "校验并切换") {
                                    Task { _ = await appState.activateASRProvider(.openAIWhisper) }
                                }
                                .buttonStyle(TZPrimaryButtonStyle(compact: true))
                                .disabled(appState.activatingASRProvider != nil)
                            }
                        }

                        if let err = appState.asrActivationErrors[.openAIWhisper], !err.isEmpty {
                            InlineProbeBanner(message: err)
                        } else if !appState.lastOpenAIASRProbeSummary.isEmpty {
                            InlineProbeBanner(message: appState.lastOpenAIASRProbeSummary)
                        } else if !openAIASRReady {
                            InlineWarnBanner(
                                message: appState.isGroqASRSelected
                                    ? "⚠️ 尚未填入 Groq API Key；填入后点击「校验并切换」通过验证才会点亮生效。"
                                    : "⚠️ 尚未检测到 OpenAI API Key；请在此填入后点击「校验并切换」（无密钥时不会生效）。"
                            )
                        }
                    }
                }
                .tzSelectableEngineCard(isSelected: openAIASRActive, isExpanded: openAIASRExpanded)

                // ASR Option C: Pure Local SenseVoice FP32
                let localASRActive = (appState.llmConfig.asrProvider == .localSenseVoice)
                let localASRExpanded = (expandedASRProvider == .localSenseVoice)
                let isActivatingLocal = (appState.activatingASRProvider == .localSenseVoice)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: localASRExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(localASRActive ? TZTheme.activeGreen : TZTheme.inkMuted.opacity(0.65))
                            .frame(width: 12, height: 12)
                        EngineStatusDot(isActive: localASRActive)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 7) {
                                Text("纯本机 SenseVoice FP32 离线满血模型")
                                    .font(.system(size: 13, weight: localASRActive ? .semibold : .medium))
                                    .foregroundStyle(localASRActive ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                                Text(appState.senseVoiceFullFP32 ? "886MB FP32" : "本机引擎")
                                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(localASRActive ? TZTheme.activeGreen : TZTheme.inkMuted)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(localASRActive ? TZTheme.activeGreenBg : TZTheme.sandWell.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            if localASRExpanded || localASRActive {
                                Text("音频 100% 留在本机内存零联网 · 飞机与高敏内网环境首选 · 也是所有云端语音的离线热备")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(localASRActive ? TZTheme.inkSecondary : TZTheme.inkMuted)
                            }
                        }

                        Spacer()

                        Text(appState.senseVoiceFullFP32 ? "满血包已就绪" : (appState.senseVoiceLoaded ? "基础包已就绪" : "待下载模型"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(
                                appState.senseVoiceLoaded
                                    ? (localASRActive ? TZTheme.activeGreen : TZTheme.inkMuted)
                                    : (localASRActive ? TZTheme.amber : TZTheme.amber.opacity(0.72))
                            )
                            .padding(.horizontal, 7.5)
                            .padding(.vertical, 2.5)
                            .background(
                                appState.senseVoiceLoaded
                                    ? (localASRActive ? TZTheme.activeGreenBg : TZTheme.softWell.opacity(0.8))
                                    : TZTheme.amberTint.opacity(localASRActive ? 1.0 : 0.55)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        appState.senseVoiceLoaded
                                            ? (localASRActive ? TZTheme.activeGreen.opacity(0.28) : TZTheme.hairline)
                                            : TZTheme.amber.opacity(0.20),
                                        lineWidth: 0.8
                                    )
                            )
                            .clipShape(Capsule())
                        EngineStatusBadge(isActive: localASRActive)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.14)) {
                            expandedASRProvider = localASRExpanded ? nil : .localSenseVoice
                        }
                    }

                    if appState.isDownloadingOfflineModel {
                        Divider().overlay(TZTheme.hairline)
                        HStack(spacing: 8) {
                            ProgressView(value: appState.offlineDownloadProgress)
                                .tint(TZTheme.violet)
                            Text(appState.offlineDownloadStatusText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(TZTheme.violet)
                                .lineLimit(1)
                            Button("取消") {
                                appState.cancelOfflineModelDownload()
                            }
                            .buttonStyle(TZSecondaryButtonStyle(compact: true, destructive: true))
                        }
                    } else if localASRExpanded {
                        Divider().overlay(TZTheme.hairline)
                        HStack(spacing: 8) {
                            if !appState.senseVoiceFullFP32 {
                                Text("尚未安装 886MB 无损浮点离线满血包：")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(TZTheme.inkSecondary)
                                Button("⬇ 下载 886MB 离线满血包") {
                                    appState.startOfflineModelDownload()
                                }
                                .buttonStyle(TZSecondaryButtonStyle(compact: true))
                            } else {
                                Text("本机 886MB FP32 无损离线模型已就绪，可随时切换为纯本地零联网模式。")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(TZTheme.inkSecondary)
                            }
                            Spacer()
                            if !localASRActive {
                                Button(isActivatingLocal ? "校验中…" : "校验并切换") {
                                    Task { _ = await appState.activateASRProvider(.localSenseVoice) }
                                }
                                .buttonStyle(TZPrimaryButtonStyle(compact: true))
                                .disabled(appState.activatingASRProvider != nil)
                            }
                        }

                        if let err = appState.asrActivationErrors[.localSenseVoice], !err.isEmpty {
                            InlineProbeBanner(message: err)
                        }
                    }
                }
                .tzSelectableEngineCard(isSelected: localASRActive, isExpanded: localASRExpanded)
            }
            .tzCardSurface(cornerRadius: 14, padding: 16)

            // Card 3: Formatting LLM Engine & Keys (Expand to Inspect -> Verify & Activate Only on Explicit Confirm)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("3. 排版大模型与密钥")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Text("点开配置并校验通过后才生效 · 唯一生效模型")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkMuted)
                }

                TZMatrixControlRow(label: "整理力度") {
                    TZSegmentBar(
                        items: [
                            ("结构化分点分段", appState.llmConfig.formattingStyle == .structured, { appState.llmConfig.formattingStyle = .structured }),
                            ("轻度去口癖纠错", appState.llmConfig.formattingStyle == .lightPolish, { appState.llmConfig.formattingStyle = .lightPolish }),
                            ("纯原声直出（不调大模型）", appState.llmConfig.formattingStyle == .verbatimLocal, { appState.llmConfig.formattingStyle = .verbatimLocal })
                        ]
                    )
                }

                if appState.llmConfig.formattingStyle == .verbatimLocal {
                    InlineWarnBanner(message: "💡 当前整理力度为「纯原声直出」，听写经本地词库修词后直接上屏，暂不调用下方云端排版模型。")
                }

                VStack(spacing: 6) {
                    ForEach(LLMProviderOption.allCases) { provider in
                        LLMProviderUnifiedCard(
                            appState: appState,
                            provider: provider,
                            isExpanded: expandedLLMProvider == provider,
                            onToggleExpand: {
                                withAnimation(.easeOut(duration: 0.14)) {
                                    expandedLLMProvider = (expandedLLMProvider == provider) ? nil : provider
                                }
                            }
                        )
                    }
                }
            }
            .tzCardSurface(cornerRadius: 14, padding: 16)

            // Card 4: Compact Smart Switches (2-Col) & System Maintenance Bar
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("4. 智能细节开关与系统维护")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Text("录音中按 Esc 随时取消并撤回已上屏草稿")
                        .font(.system(size: 11))
                        .foregroundStyle(TZTheme.inkMuted)
                }

                Divider().overlay(TZTheme.hairline)

                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 0) {
                        CompactSwitchRow(icon: "speaker.slash.fill", title: "听写时自动静音外放（说完自动恢复）", isOn: $appState.llmConfig.enableAutoMuteDuringDictation)
                        Divider().overlay(TZTheme.hairline)
                        CompactSwitchRow(icon: "hare.fill", title: "28 字内干净短句免检直通", isOn: $appState.llmConfig.enableFastBypassForShortPhrases)
                        Divider().overlay(TZTheme.hairline)
                        CompactSwitchRow(icon: "waveform.and.mic", title: "25dB 气声耳语自动增益", isOn: $appState.llmConfig.enableWhisperAGC)
                        Divider().overlay(TZTheme.hairline)
                        CompactSwitchRow(icon: "textformat.abc.dottedunderline", title: "中英文盘古留白与数字规整", isOn: $appState.llmConfig.enablePanguSpacing)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 0) {
                        CompactSwitchRow(icon: "brain.head.profile", title: "改字无感自学习词库", isOn: $appState.llmConfig.enableAutoLearn)
                        Divider().overlay(TZTheme.hairline)
                        CompactSwitchRow(icon: "bubble.left.and.bubble.right.fill", title: "聊天与终端去句末句号", isOn: $appState.llmConfig.stripTrailingPeriodInChatApps)
                        Divider().overlay(TZTheme.hairline)
                        CompactSwitchRow(icon: "dock.rectangle", title: "在程序坞 (Dock) 显示图标", isOn: $appState.llmConfig.showInDock)
                    }
                    .frame(maxWidth: .infinity)
                }

                Divider().overlay(TZTheme.hairline)

                HStack(spacing: 8) {
                    Button("请求系统权限") {
                        appState.requestAllPermissions()
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))

                    Button("重置辅助功能缓存") {
                        appState.resetStaleTCCAndOpenSettings()
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))

                    Spacer()

                    Button("新手引导") {
                        appState.showOnboardingSheet = true
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                }
            }
            .tzCardSurface(cornerRadius: 14, padding: 15)
        }
        .onDisappear {
            if appState.isRecordingShortcut {
                appState.cancelShortcutCapture()
            }
        }
    }
}

// MARK: - Unified Hotkey Grid & Check-to-Activate Provider Cards

struct TZHotkeyPresetGrid: View {
    @ObservedObject var appState: AppState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(TriggerKeyOption.presetMatrixOrder) { opt in
                let selected = (appState.triggerKey == opt)
                Button {
                    if appState.isRecordingShortcut {
                        appState.cancelShortcutCapture()
                    }
                    appState.triggerKey = opt
                } label: {
                    Text(opt.shortLabel)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? TZTheme.violet : TZTheme.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6.5)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(selected ? TZTheme.cardBg : TZTheme.softWell)
                                .shadow(color: selected ? Color.black.opacity(0.05) : .clear, radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(selected ? TZTheme.violet.opacity(0.65) : TZTheme.hairline, lineWidth: selected ? 1.25 : 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(TZTheme.sandWell.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 9.5))
    }
}

struct LLMProviderUnifiedCard: View {
    @ObservedObject var appState: AppState
    let provider: LLMProviderOption
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var draftAPIKey: String = ""
    @State private var draftModelName: String = ""
    @State private var draftBaseURL: String = ""
    @State private var didLoadDraft: Bool = false

    private func syncDraftFromStore() {
        let savedKey = KeychainHelper.loadAPIKey(for: provider)
        draftAPIKey = savedKey
        if appState.llmConfig.selectedProvider == provider {
            draftModelName = appState.llmConfig.modelName
            draftBaseURL = appState.llmConfig.baseURL
        } else {
            draftModelName = appState.llmConfig.providerModels[provider.rawValue] ?? provider.defaultModelName
            draftBaseURL = (provider == .custom && !appState.llmConfig.customBaseURL.isEmpty)
                ? appState.llmConfig.customBaseURL
                : provider.defaultBaseURL
        }
        didLoadDraft = true
    }

    var body: some View {
        let isActive = (appState.llmConfig.selectedProvider == provider)
        let activeModelBadge = isActive
            ? appState.llmConfig.modelName
            : (appState.llmConfig.providerModels[provider.rawValue] ?? provider.defaultModelName)
        let effectiveURL = didLoadDraft
            ? draftBaseURL
            : (isActive ? appState.llmConfig.baseURL : ((provider == .custom && !appState.llmConfig.customBaseURL.isEmpty) ? appState.llmConfig.customBaseURL : provider.defaultBaseURL))
        let isLocalKeyless = PolishEngine.isKeylessLocalEndpoint(effectiveURL)
        let hasKey = didLoadDraft
            ? (!draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLocalKeyless)
            : ((appState.savedProviderKeyFlags[provider] ?? false) || isLocalKeyless)
        let isActivatingThis = (appState.activatingLLMProvider == provider)
        let activationError = appState.llmActivationErrors[provider]
        let benchmarkSummary = appState.llmProviderBenchmarkSummaries[provider]
            ?? (isActive ? appState.lastBenchmarkSummary : "")

        VStack(alignment: .leading, spacing: 10) {
            // Expandable Header Row — tapping ONLY expands/collapses, NEVER switches active model!
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? TZTheme.activeGreen : TZTheme.inkMuted.opacity(0.65))
                    .frame(width: 12, height: 12)
                EngineStatusDot(isActive: isActive)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(provider.title)
                            .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(isActive ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                        Text(activeModelBadge)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(isActive ? TZTheme.activeGreen : TZTheme.inkMuted)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(isActive ? TZTheme.activeGreenBg : TZTheme.sandWell.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if isExpanded || isActive {
                        Text(provider.subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(isActive ? TZTheme.inkSecondary : TZTheme.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                KeyStatusPill(isConfigured: hasKey, keylessLocal: isLocalKeyless, muted: !isActive)
                EngineStatusBadge(isActive: isActive)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !didLoadDraft {
                    syncDraftFromStore()
                }
                onToggleExpand()
            }

            // Inline Key, Model, Speed-Test & Explicit Verify-to-Activate Drawer
            if isExpanded {
                Divider().overlay(TZTheme.hairline)

                if provider == .custom {
                    HStack(spacing: 8) {
                        Text("接口地址")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                            .frame(width: 60, alignment: .leading)
                        TextField("https://api.siliconflow.cn/v1 或 http://localhost:11434/v1", text: $draftBaseURL)
                            .tzCompactInputStyle()
                        Text("模型 ID")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                        TextField("模型名称", text: $draftModelName)
                            .tzCompactInputStyle()
                            .frame(width: 175)
                    }
                }

                HStack(spacing: 8) {
                    Text("API Key")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 60, alignment: .leading)

                    SecureField(
                        provider == .custom ? "粘贴 API Key（本地 Ollama / LM Studio 可留空）" : "粘贴 \(provider.shortName) API Key",
                        text: $draftAPIKey
                    )
                    .tzCompactInputStyle()
                    .onSubmit {
                        appState.saveLLMProviderDraft(
                            provider: provider,
                            baseURL: draftBaseURL,
                            modelName: draftModelName,
                            apiKey: draftAPIKey
                        )
                    }

                    if provider != .custom {
                        TextField("模型 ID", text: $draftModelName)
                            .tzCompactInputStyle()
                            .frame(width: 165)
                    }

                    Button("保存") {
                        appState.saveLLMProviderDraft(
                            provider: provider,
                            baseURL: draftBaseURL,
                            modelName: draftModelName,
                            apiKey: draftAPIKey
                        )
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))

                    Button(appState.isBenchmarkingLLM ? "测速中…" : "⚡ 测速") {
                        Task {
                            await appState.runLLMProviderBenchmark(
                                provider: provider,
                                baseURL: draftBaseURL,
                                modelName: draftModelName,
                                apiKey: draftAPIKey
                            )
                        }
                    }
                    .buttonStyle(TZSecondaryButtonStyle(compact: true))
                    .disabled(appState.isBenchmarkingLLM || appState.activatingLLMProvider != nil)

                    if !isActive {
                        Button(isActivatingThis ? "校验中…" : "校验并切换") {
                            Task {
                                _ = await appState.activateLLMProvider(
                                    provider,
                                    baseURL: draftBaseURL,
                                    modelName: draftModelName,
                                    apiKey: draftAPIKey
                                )
                            }
                        }
                        .buttonStyle(TZPrimaryButtonStyle(compact: true))
                        .disabled(appState.activatingLLMProvider != nil)
                    }
                }

                if let err = activationError, !err.isEmpty {
                    InlineProbeBanner(message: err)
                } else if !benchmarkSummary.isEmpty {
                    InlineProbeBanner(message: benchmarkSummary)
                } else if !hasKey {
                    InlineWarnBanner(message: "⚠️ 尚未填入「\(provider.shortName)」API Key；填入后点击「校验并切换」通过验证才会点亮生效。")
                }
            }
        }
        .tzSelectableEngineCard(isSelected: isActive, isExpanded: isExpanded)
        .onAppear {
            syncDraftFromStore()
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                syncDraftFromStore()
            }
        }
    }
}

private struct TZASRPresetPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? TZTheme.violet : TZTheme.inkSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? TZTheme.cardBg : TZTheme.sandWell.opacity(0.65))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isActive ? TZTheme.violet.opacity(0.55) : TZTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct EngineStatusDot: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(TZTheme.activeGreen.opacity(0.24))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(TZTheme.activeGreen)
                    .frame(width: 7.5, height: 7.5)
            } else {
                Circle()
                    .fill(TZTheme.inkMuted.opacity(0.38))
                    .frame(width: 6.5, height: 6.5)
            }
        }
        .frame(width: 14, height: 14)
    }
}

private struct EngineStatusBadge: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4.5) {
            Circle()
                .fill(isActive ? Color.white : TZTheme.inkMuted.opacity(0.45))
                .frame(width: 5.5, height: 5.5)
            Text(isActive ? "当前生效" : "未启用")
                .font(.system(size: 10.5, weight: isActive ? .semibold : .medium))
        }
        .foregroundStyle(isActive ? .white : TZTheme.inkMuted)
        .padding(.horizontal, 8.5)
        .padding(.vertical, 3)
        .background(isActive ? TZTheme.activeGreen : TZTheme.sandWell.opacity(0.55))
        .clipShape(Capsule())
    }
}

private struct KeyStatusPill: View {
    let isConfigured: Bool
    var keylessLocal: Bool = false
    var muted: Bool = false

    var body: some View {
        let ok = isConfigured || keylessLocal
        Text(keylessLocal ? "本地免密" : (isConfigured ? "密钥已存" : "待填密钥"))
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(
                ok
                    ? (muted ? TZTheme.inkMuted : TZTheme.activeGreen)
                    : (muted ? TZTheme.amber.opacity(0.72) : TZTheme.amber)
            )
            .padding(.horizontal, 7.5)
            .padding(.vertical, 2.5)
            .background(
                ok
                    ? (muted ? TZTheme.softWell.opacity(0.8) : TZTheme.activeGreenBg)
                    : (muted ? TZTheme.amberTint.opacity(0.55) : TZTheme.amberTint)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        ok
                            ? (muted ? TZTheme.hairline : TZTheme.activeGreen.opacity(0.28))
                            : TZTheme.amber.opacity(muted ? 0.16 : 0.28),
                        lineWidth: 0.8
                    )
            )
            .clipShape(Capsule())
    }
}

private struct InlineProbeBanner: View {
    let message: String

    var body: some View {
        let isError = message.hasPrefix("❌")
        Text(message)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(isError ? TZTheme.crimson : TZTheme.emerald)
            .lineLimit(2)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isError ? TZTheme.crimson.opacity(0.08) : TZTheme.emeraldTint)
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct InlineWarnBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundStyle(TZTheme.amber)
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TZTheme.amberTint)
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private extension View {
    func tzCompactInputStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(TZTheme.inkPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(TZTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(TZTheme.hairline, lineWidth: 1))
    }

    func tzSelectableEngineCard(isSelected: Bool, isExpanded: Bool = false) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, (isSelected || isExpanded) ? 11 : 8)
            .background(
                isSelected
                    ? TZTheme.activeGreenBg.opacity(0.72)
                    : (isExpanded ? TZTheme.cardBg : TZTheme.softWell.opacity(0.45))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected
                            ? TZTheme.activeGreenBorder.opacity(0.78)
                            : (isExpanded ? TZTheme.strongLine.opacity(0.85) : TZTheme.hairline.opacity(0.75)),
                        lineWidth: isSelected ? 1.55 : 1
                    )
            )
            .shadow(color: isSelected ? TZTheme.activeGreen.opacity(0.08) : .clear, radius: 6, x: 0, y: 2)
    }
}

struct TZMatrixControlRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TZTheme.inkSecondary)
                .frame(width: 78, alignment: .leading)
            content()
        }
        .padding(.vertical, 7.5)
    }
}

struct TZSegmentBar: View {
    let items: [(title: String, isSelected: Bool, action: () -> Void)]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<items.count, id: \.self) { idx in
                let item = items[idx]
                Button(action: item.action) {
                    Text(item.title)
                        .font(.system(size: 12, weight: item.isSelected ? .semibold : .regular))
                        .foregroundStyle(item.isSelected ? TZTheme.violet : TZTheme.inkSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6.5)
                                .fill(item.isSelected ? TZTheme.cardBg : Color.clear)
                                .shadow(color: item.isSelected ? Color.black.opacity(0.05) : .clear, radius: 2, x: 0, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6.5)
                                .strokeBorder(item.isSelected ? TZTheme.violet.opacity(0.45) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(TZTheme.sandWell.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8.5))
    }
}

struct CompactSwitchRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(TZTheme.violet)
                .frame(width: 22, height: 22)
                .background(TZTheme.lilacTint)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TZTheme.inkPrimary)
                .lineLimit(1)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(TZTheme.violet)
        }
        .padding(.vertical, 6.5)
    }
}

struct PermissionBadge: View {
    let title: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(ok ? TZTheme.emeraldTint : TZTheme.amberTint)
        .foregroundStyle(ok ? TZTheme.emerald : TZTheme.amber)
        .clipShape(Capsule())
    }
}

// MARK: - 5. First-Run Colleague Onboarding Sheet (3-Step Zero-Confusion Setup)

struct OnboardingWizardSheet: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(TZTheme.cardBg)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(TZTheme.hairline, lineWidth: 1))
                    MobiusMarkView(size: 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("欢迎使用 TypeZero")
                        .font(.system(size: 21, weight: .bold, design: .serif))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text("花 60 秒完成以下 3 步配置，即可在任意软件中开口成文")
                        .font(.system(size: 12.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
                Spacer()
                Text("v0.4")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TZTheme.violet)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(TZTheme.lilacTint)
                    .clipShape(Capsule())
            }

            Divider().overlay(TZTheme.strongLine)

            // Step 1: System Permissions
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("第 1 步 · 授予麦克风与辅助功能权限")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    PermissionBadge(title: "麦克风", ok: appState.micAuthorized)
                    PermissionBadge(title: "辅助功能上屏", ok: appState.accessibilityGranted)
                }
                HStack(spacing: 10) {
                    Button("一键打开权限授权") {
                        appState.requestAllPermissions()
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: true))

                    Text("在系统弹窗允许麦克风，并在「系统设置 → 辅助功能」中打开 TypeZero 开关")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                }
            }
            .tzCardSurface(cornerRadius: 12, padding: 14)

            // Step 2: Paste Dual API Keys (supports Volcengine / OpenAI / Local ASR + 6 LLM Providers)
            VStack(alignment: .leading, spacing: 9) {
                let onboardingASRReady = (appState.llmConfig.asrProvider == .volcSeedASR && !appState.volcSpeechKeyInput.isEmpty)
                    || (appState.llmConfig.asrProvider == .openAIWhisper && appState.hasEffectiveOpenAIASRKey)
                    || (appState.llmConfig.asrProvider == .localSenseVoice && appState.senseVoiceLoaded)
                HStack {
                    Text("第 2 步 · 填入语音与排版密钥（加密存入本机钥匙串）")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    if onboardingASRReady && !appState.apiKeyInput.isEmpty {
                        PermissionBadge(title: "双引擎已就绪", ok: true)
                    }
                }

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
                    .frame(width: 96)

                    if appState.llmConfig.asrProvider == .volcSeedASR {
                        SecureField("粘贴火山豆包语音 API Key", text: $appState.volcSpeechKeyInput)
                            .tzCompactInputStyle()
                        Button("保存") {
                            appState.saveVolcSpeechAPIKey()
                        }
                        .buttonStyle(TZPrimaryButtonStyle(compact: true))
                    } else if appState.llmConfig.asrProvider == .openAIWhisper {
                        SecureField(
                            appState.isOpenAIASRReusingLLMKey
                                ? "已自动复用下方 OpenAI Key（留空即可）"
                                : "粘贴 OpenAI / Groq Key（与下方 OpenAI Key 可共用）",
                            text: $appState.openAIASRKeyInput
                        )
                        .tzCompactInputStyle()
                        Button("保存") {
                            appState.saveOpenAIASRConfig()
                        }
                        .buttonStyle(TZPrimaryButtonStyle(compact: true))
                    } else {
                        Text("已选纯本机 SenseVoice 离线识别，可在下方第 3 步一键下载 886MB 满血包")
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
                    .frame(width: 96)
                    SecureField("粘贴 \(appState.llmConfig.selectedProvider.shortName) API Key", text: $appState.apiKeyInput)
                        .tzCompactInputStyle()
                    Button("保存") {
                        appState.saveAPIKey()
                    }
                    .buttonStyle(TZPrimaryButtonStyle(compact: true))
                }
            }
            .tzCardSurface(cornerRadius: 12, padding: 14)

            // Step 3: Trigger Key & Optional Offline Pack
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("第 3 步 · 选择顺手快捷键与离线热备包（可选）")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    if appState.senseVoiceFullFP32 {
                        PermissionBadge(title: "离线满血包已装好", ok: true)
                    }
                }

                TZHotkeyPresetGrid(appState: appState)

                if appState.isDownloadingOfflineModel {
                    HStack(spacing: 8) {
                        ProgressView(value: appState.offlineDownloadProgress)
                            .tint(TZTheme.violet)
                        Text(appState.offlineDownloadStatusText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TZTheme.violet)
                            .lineLimit(1)
                    }
                } else if !appState.senseVoiceFullFP32 {
                    HStack(spacing: 8) {
                        Button("⬇ 后台下载 886MB 离线满血模型") {
                            appState.startOfflineModelDownload()
                        }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true))
                        Text("日常有网用豆包无需下载；经常坐飞机/无网建议后台下载")
                            .font(.system(size: 11))
                            .foregroundStyle(TZTheme.inkMuted)
                    }
                }
            }
            .tzCardSurface(cornerRadius: 12, padding: 14)

            // Footer
            HStack {
                Text("使用方法：聚焦任意输入框 ➔ 按一下快捷键说话 ➔ 再按一下瞬间成稿")
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
                .buttonStyle(TZPrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 590)
        .background(TZTheme.paperBg)
        .preferredColorScheme(.light)
    }
}
