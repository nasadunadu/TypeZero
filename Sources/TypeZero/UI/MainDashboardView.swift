import SwiftUI
import AppKit

// MARK: - Root Navigation Shell (Real CGI Silk Frosted Sidebar + Luminous Active Pill + Single-Row Status Capsule)

public struct MainDashboardView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var lexiconStore: PersonalLexiconStore
    @Environment(\.colorScheme) private var systemScheme

    public init(appState: AppState) {
        self.appState = appState
        self.lexiconStore = appState.lexiconStore
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            // Crisp dual-tone glass seam separating sidebar & main stage
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(TZTheme.cardBorder)
                    .frame(width: 1)
                Rectangle()
                    .fill(Color.white.opacity(effectiveScheme == .dark ? 0.05 : 0.65))
                    .frame(width: 1)
                    .offset(x: 1)
            }
            .frame(width: 1)
            .ignoresSafeArea(.all, edges: .top)
            mainContent
        }
        .frame(minWidth: 940, minHeight: 650)
        .background(TZCanvasBackdrop())
        .ignoresSafeArea(.all, edges: .top)
        .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
        .sheet(isPresented: $appState.showOnboardingSheet) {
            OnboardingSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.showTrialExhaustedSheet) {
            TrialExhaustedSheetView(appState: appState)
        }
    }

    // MARK: Full-Height Translucent Silk-Glass Sidebar (Powered by sidebar-silk-light/dark.png!)

    private var sidebar: some View {
        let isDark = (effectiveScheme == .dark)
        let silkAsset = isDark ? "sidebar-silk-dark" : "sidebar-silk-light"

        return VStack(alignment: .leading, spacing: 5) {
            // Crystal-Glass 3D Brand Lockup
            HStack(spacing: 11) {
                TZBrandEmblemView(size: 40)
                Text("TypeZero")
                    .font(TZFont.brand(19))
                    .tracking(-0.3)
                    .foregroundStyle(TZTheme.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.top, 44)
            .padding(.bottom, 20)

            // 4 Minimalist Navigation Tabs
            ForEach(SidebarTab.allCases) { tab in
                sidebarNavButton(for: tab, isDark: isDark)
            }

            Spacer()

            // Sleek Single-Row Frosted Glass Status Capsule
            sidebarStatusCapsule
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 12)
        .frame(width: 204)
        .background(
            GeometryReader { geo in
                ZStack {
                    TZVisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                    LinearGradient(
                        colors: [TZTheme.sidebarTop, TZTheme.sidebarBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    if let silkImg = TZAssetStore.image(named: silkAsset) {
                        silkImg
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .saturation(isDark ? 0.80 : 0.68)
                            .blur(radius: 2)
                            .opacity(isDark ? 0.48 : 0.44)
                    }
                }
            }
            .ignoresSafeArea(.all, edges: .top)
        )
    }

    private func sidebarNavButton(for tab: SidebarTab, isDark: Bool) -> some View {
        let isSelected = (appState.selectedTab == tab)

        return Button {
            withAnimation(.easeOut(duration: 0.14)) {
                appState.selectedTab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? tab.activeIcon : tab.icon)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? TZTheme.accent : TZTheme.inkSecondary)
                    .frame(width: 19)

                Text(tab.rawValue)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? TZTheme.inkPrimary : TZTheme.inkSecondary)

                Spacer()

                if tab == .dictionary && !lexiconStore.entries.isEmpty {
                    Text("\(lexiconStore.entries.count)")
                        .font(TZFont.mono(10.5, weight: .medium))
                        .foregroundStyle(isSelected ? TZTheme.accent : TZTheme.inkMuted)
                } else if tab == .history && !appState.history.isEmpty {
                    Text("\(appState.history.count)")
                        .font(TZFont.mono(10.5, weight: .medium))
                        .foregroundStyle(isSelected ? TZTheme.accent : TZTheme.inkMuted)
                } else if tab == .style && !appState.llmConfig.normalizedCustomStylePrompt.isEmpty {
                    Text("已自定义")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(isSelected ? TZTheme.accent : TZTheme.inkMuted)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2)
                        .background(isSelected ? TZTheme.accentSoft : TZTheme.recessedWell.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 11)
            .padding(.vertical, 9.5)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                isDark
                                    ? LinearGradient(colors: [Color(red: 0.21, green: 0.22, blue: 0.35).opacity(0.88), Color(red: 0.13, green: 0.14, blue: 0.23).opacity(0.92)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color.white.opacity(0.95), Color(red: 0.96, green: 0.965, blue: 1.0).opacity(0.86)], startPoint: .top, endPoint: .bottom)
                            )
                        // Soft purple light spill radiating rightward from the left indicator bar (Matches v2-01!)
                        RadialGradient(
                            colors: [TZTheme.accent.opacity(isDark ? 0.34 : 0.20), Color.clear],
                            center: UnitPoint(x: 0.02, y: 0.5),
                            startRadius: 2,
                            endRadius: 68
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
                .shadow(
                    color: isSelected
                        ? (isDark ? Color.black.opacity(0.45) : Color(red: 0.38, green: 0.32, blue: 0.96).opacity(0.16))
                        : .clear,
                    radius: 10,
                    x: 0,
                    y: 3.5
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? LinearGradient(
                                colors: isDark
                                    ? [Color.white.opacity(0.24), Color.white.opacity(0.06)]
                                    : [Color.white, Color(red: 0.42, green: 0.36, blue: 0.96).opacity(0.14), Color.white.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.05
                    )
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(TZTheme.accent)
                        .frame(width: 3.2, height: 18)
                        .shadow(color: TZTheme.accent.opacity(isDark ? 0.85 : 0.55), radius: 5)
                        .padding(.leading, 4.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sidebarStatusCapsule: some View {
        let ready = appState.accessibilityGranted && appState.micAuthorized
        let isDark = (effectiveScheme == .dark)

        return VStack(spacing: 7) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(ready ? TZTheme.emerald : TZTheme.amber)
                        .frame(width: 7.5, height: 7.5)
                        .shadow(color: (ready ? TZTheme.emerald : TZTheme.amber).opacity(0.80), radius: 4.5)
                    Text(ready ? "就绪" : "待授权")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                }

                Spacer(minLength: 2)

                TZKeycapView(label: compactSidebarKeyLabel, size: .small)

                Button {
                    if appState.cloudUser == nil && !appState.hasPersonalBYOKASRReady && !(appState.llmConfig.asrProvider == .localSenseVoice && appState.senseVoiceLoaded) {
                        appState.showOnboardingSheet = true
                    } else {
                        appState.selectedSettingsTab = .engines
                        appState.selectedTab = .settings
                    }
                } label: {
                    Text(sidebarEngineBadge.text)
                        .font(TZFont.mono(10, weight: .semibold))
                        .foregroundStyle(sidebarEngineBadge.fg)
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 3.5)
                        .background(sidebarEngineBadge.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help(sidebarEngineBadge.tooltip)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8.5)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.76))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isDark
                                ? [Color.white.opacity(0.20), Color.white.opacity(0.06)]
                                : [Color.white, Color.white.opacity(0.45), Color.white.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.05
                    )
            )
            .shadow(color: Color(red: 0.26, green: 0.24, blue: 0.54).opacity(isDark ? 0.34 : 0.10), radius: 9, x: 0, y: 3.5)

            if !appState.accessibilityGranted {
                Button {
                    appState.requestAllPermissions()
                } label: {
                    Text("开启辅助功能上屏")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TZAccentButtonStyle(compact: true, capsule: false))
            }

            if let upd = appState.availableUpdate {
                Button {
                    Task { await appState.installAvailableUpdate() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10.5))
                        Text(appState.isInstallingUpdate ? "更新中…" : "升级 \(upd.tag)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(TZTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5.5)
                    .background(TZTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(appState.isInstallingUpdate)
            }
        }
    }

    // MARK: Right Main Content Stage

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if appState.shouldShowUpdateBanner, let upd = appState.availableUpdate {
                    updateToastBanner(upd)
                }

                if !appState.statusBanner.isEmpty {
                    statusToastBanner
                }

                switch appState.selectedTab {
                case .home:
                    HomeView(appState: appState)
                case .history:
                    HistoryView(appState: appState)
                case .dictionary:
                    DictionaryView(appState: appState, lexiconStore: lexiconStore)
                case .style:
                    StyleView(appState: appState)
                case .settings:
                    SettingsView(appState: appState)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 32)
        }
    }

    private func updateToastBanner(_ upd: AppVersionManifest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TZTheme.accent)
                VStack(alignment: .leading, spacing: 1.5) {
                    Text("发现新版本 TypeZero \(upd.tag)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Text(appState.isInstallingUpdate ? appState.updateStatusText : "支持应用内校验 SHA-256 无损升级，保留全部配置与词库")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if !appState.isInstallingUpdate {
                    Button("稍后") { appState.dismissUpdateBanner() }
                        .buttonStyle(TZSecondaryButtonStyle(compact: true, capsule: true))
                    Button("一键升级") { Task { await appState.installAvailableUpdate() } }
                        .buttonStyle(TZAccentButtonStyle(compact: true, capsule: true))
                }
            }
            if appState.isInstallingUpdate {
                ProgressView(value: appState.updateDownloadProgress).tint(TZTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(TZTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(TZTheme.accent.opacity(0.30), lineWidth: 1))
    }

    private var statusToastBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TZTheme.accent)
            Text(appState.statusBanner)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TZTheme.inkPrimary)
            Spacer()
            Button {
                appState.statusBanner = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(TZTheme.inkMuted)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(TZTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TZTheme.accent.opacity(0.28), lineWidth: 1))
    }

    // MARK: Helpers

    private var effectiveScheme: ColorScheme {
        appState.llmConfig.appearance.colorScheme ?? systemScheme
    }

    private var sidebarEngineBadge: (text: String, fg: Color, bg: Color, tooltip: String) {
        if appState.isOfficialCloudTrialActive, let trial = appState.activeCloudTrial {
            let daysNote = trial.daysRemaining.map { "剩余 \($0) 天" } ?? "生效中"
            let tip = "超级 VIP（自研大模型）· \(daysNote)"
            if trial.isLow {
                return ("VIP \(trial.remainingPercent)%", TZTheme.amber, TZTheme.amber.opacity(0.14), tip)
            }
            return ("超级 VIP", TZTheme.emerald, TZTheme.emeraldSoft, tip)
        }
        if appState.llmConfig.asrProvider == .localSenseVoice && appState.senseVoiceLoaded {
            return ("本机离线", TZTheme.emerald, TZTheme.emeraldSoft, "100% 本机离线引擎运行中（永久免费）")
        }
        if appState.hasPersonalBYOKASRReady {
            return ("自有引擎", TZTheme.inkPrimary, TZTheme.recessedWell.opacity(0.85), "个人 API Key 引擎直连运行中")
        }
        if appState.isCloudTrialEnded {
            return ("绑定 API", TZTheme.amber, TZTheme.amber.opacity(0.14), "1 个月超级 VIP 已到期，点击绑定自有 API 无限续用")
        }
        return ("领超级 VIP", TZTheme.accent, TZTheme.accentSoft, "注册免费领 1 个月超级 VIP（自研大模型）")
    }

    private var compactSidebarKeyLabel: String {
        switch appState.triggerKey {
        case .fnKey: return "Fn"
        case .leftOption: return "左⌥"
        case .rightOption: return "右⌥"
        case .leftCommand: return "左⌘"
        case .rightCommand: return "右⌘"
        case .leftControl: return "左⌃"
        case .rightControl: return "右⌃"
        case .leftShift: return "左⇧"
        case .rightShift: return "右⇧"
        case .optionSpace: return "⌥␣"
        case .custom: return appState.customHotkey.label
        }
    }
}
