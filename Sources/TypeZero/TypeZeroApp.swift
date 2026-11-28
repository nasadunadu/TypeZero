import SwiftUI
import AppKit

@main
enum TypeZeroMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTestSuite.runAll())
        }
        if CommandLine.arguments.contains("--bench-asr") {
            exit(SelfTestSuite.runDualASRSmokeBenchmark())
        }
        if let idx = CommandLine.arguments.firstIndex(of: "--ab-verify"), idx + 1 < CommandLine.arguments.count {
            exit(SelfTestSuite.runEmpiricalABVerification(wavPath: CommandLine.arguments[idx + 1]))
        }
        if let idx = CommandLine.arguments.firstIndex(of: "--dump-onboarding-qa"), idx + 1 < CommandLine.arguments.count {
            exit(SelfTestSuite.dumpOnboardingQASnapshots(outDir: CommandLine.arguments[idx + 1]))
        }
        AppLaunchGuard.enforceSingleInstanceBeforeAppLaunch()
        TypeZeroApp.main()
    }
}

@MainActor
final class TypeZeroAppDelegate: NSObject, NSApplicationDelegate {
    static var openMainWindowAction: (() -> Void)?
    private var activateWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activateWindowObserver = DistributedNotificationCenter.default().addObserver(
            forName: .typeZeroActivateMainWindow,
            object: Bundle.main.bundleIdentifier ?? AppLaunchGuard.expectedBundleID,
            queue: .main
        ) { _ in
            Task { @MainActor in
                Self.openMainWindowAction?()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let obs = activateWindowObserver {
            DistributedNotificationCenter.default().removeObserver(obs)
            activateWindowObserver = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.openMainWindowAction?()
        return true
    }
}

struct TypeZeroApp: App {
    @NSApplicationDelegateAdaptor(TypeZeroAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("TypeZero", id: "main") {
            MainWindowHost(appState: appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 680)

        MenuBarExtra("TypeZero", systemImage: "infinity") {
            TypeZeroMenuBarPopover(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MainWindowHost: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MainDashboardView(appState: appState)
            .background(TZWindowChromeConfigurator())
            .onAppear {
                TypeZeroAppDelegate.openMainWindowAction = {
                    openWindow(id: "main")
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        for window in NSApp.windows where window.identifier?.rawValue == "main" || window.title == "TypeZero" {
                            window.deminiaturize(nil)
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                        }
                    }
                }
            }
    }
}

// MARK: - Clean Frosted Glass Menu Bar Popover (No Test-Mic Button — Focused on Status, Open Main Window & Core Settings)

private struct TypeZeroMenuBarPopover: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var hoveredAction: String? = nil

    var body: some View {
        let ready = appState.accessibilityGranted && appState.micAuthorized
        let isDark = (scheme == .dark)

        VStack(alignment: .leading, spacing: 11) {
            // 1. Identity & Live Status Header
            HStack(spacing: 10) {
                TZBrandEmblemView(size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("TypeZero")
                            .font(TZFont.brand(15.5))
                            .foregroundStyle(TZTheme.inkPrimary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ready ? TZTheme.emerald : TZTheme.amber)
                                .frame(width: 6, height: 6)
                            Text(ready ? "就绪" : "待授权")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(ready ? TZTheme.emerald : TZTheme.amber)
                        }
                        .padding(.horizontal, 6.5)
                        .padding(.vertical, 2)
                        .background(ready ? TZTheme.emeraldSoft : TZTheme.amberSoft)
                        .clipShape(Capsule())
                    }
                    HStack(spacing: 4) {
                        Text("按")
                            .font(.system(size: 10.5))
                            .foregroundStyle(TZTheme.inkMuted)
                        Text(appState.activeTriggerCompactLabel)
                            .font(TZFont.mono(10, weight: .semibold))
                            .foregroundStyle(TZTheme.inkPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(TZTheme.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                    .strokeBorder(TZTheme.cardBorder, lineWidth: 0.7)
                            )
                        Text("随时开口 · \(activeEngineShortText)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(TZTheme.inkMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            // 2. Compact Today & Total Telemetry Strip
            HStack(spacing: 8) {
                statMiniTile(label: "今日口述", value: formatNum(appState.todayCharactersDictated), unit: "字")
                statMiniTile(label: "累计成稿", value: formatNum(appState.totalCharactersDictated), unit: "字")
            }

            if let upd = appState.availableUpdate {
                Button {
                    presentMainWindow(tab: .settings, settingsTab: .account)
                    Task { await appState.installAvailableUpdate() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11.5))
                        Text("发现新版本 \(upd.tag) · 点击升级")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundStyle(TZTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(TZTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8.5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // 3. Unmistakable Primary Action Button: Open Main Window
            let openHovered = (hoveredAction == "open")
            Button {
                presentMainWindow(tab: .home)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("打开 TypeZero 主界面")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("⌘,")
                        .font(TZFont.mono(10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: openHovered
                                        ? [Color(red: 0.41, green: 0.36, blue: 0.99), Color(red: 0.28, green: 0.23, blue: 0.90)]
                                        : [Color(red: 0.36, green: 0.31, blue: 0.96), Color(red: 0.24, green: 0.20, blue: 0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        RoundedRectangle(cornerRadius: 10.5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.24), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(0.8)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10.5, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.9
                        )
                )
                .shadow(
                    color: Color(red: 0.28, green: 0.22, blue: 0.90).opacity(openHovered ? 0.42 : 0.28),
                    radius: openHovered ? 8 : 5.5,
                    x: 0,
                    y: 2.5
                )
                .contentShape(RoundedRectangle(cornerRadius: 10.5, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { inside in
                hoveredAction = inside ? "open" : (hoveredAction == "open" ? nil : hoveredAction)
            }

            // 4. Crisp 3-Column Quick-Jump Dock (History / Dictionary / Settings)
            HStack(spacing: 7) {
                quickJumpTile(
                    id: "history",
                    icon: "clock.fill",
                    tint: TZTheme.accent,
                    tintSoft: TZTheme.accentSoft,
                    title: "口述历史",
                    subtitle: "\(appState.history.count) 条"
                ) {
                    presentMainWindow(tab: .history)
                }
                quickJumpTile(
                    id: "dict",
                    icon: "book.closed.fill",
                    tint: TZTheme.emerald,
                    tintSoft: TZTheme.emeraldSoft,
                    title: "个人词库",
                    subtitle: "\(appState.lexiconStore.entries.count) 词"
                ) {
                    presentMainWindow(tab: .dictionary)
                }
                quickJumpTile(
                    id: "settings",
                    icon: "gearshape.fill",
                    tint: TZTheme.cyan,
                    tintSoft: TZTheme.cyanSoft,
                    title: "偏好设置",
                    subtitle: "引擎 · 外观"
                ) {
                    presentMainWindow(tab: .settings)
                }
            }

            // 5. Grouped Quick Toggles Card
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "dock.rectangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 18)
                    Text("在程序坞显示图标")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Toggle("", isOn: $appState.llmConfig.showInDock)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(TZTheme.accent)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8.5)

                TZHairline(leadingInset: 38)

                HStack(spacing: 9) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TZTheme.inkSecondary)
                        .frame(width: 18)
                    Text("听写时自动静音")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(TZTheme.inkPrimary)
                    Spacer()
                    Toggle("", isOn: $appState.llmConfig.enableAutoMuteDuringDictation)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(TZTheme.accent)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8.5)
            }
            .background(TZTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10.5, style: .continuous)
                    .strokeBorder(TZTheme.cardBorder, lineWidth: 0.9)
            )

            // 6. Clean Compact Footer (Update + Quit)
            HStack(spacing: 8) {
                let updateHovered = (hoveredAction == "update")
                Button {
                    presentMainWindow(tab: .settings, settingsTab: .account)
                    Task { await appState.checkForUpdates(manual: true) }
                } label: {
                    HStack(spacing: 5.5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(updateHovered ? TZTheme.accent : TZTheme.inkSecondary)
                        Text(appState.isCheckingForUpdate ? "检查中…" : "检查更新")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(TZTheme.inkSecondary)
                        Text("v\(appState.currentAppVersion)")
                            .font(TZFont.mono(10))
                            .foregroundStyle(TZTheme.inkMuted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(updateHovered ? TZTheme.hoverFill : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(appState.isCheckingForUpdate || appState.isInstallingUpdate)
                .onHover { inside in
                    hoveredAction = inside ? "update" : (hoveredAction == "update" ? nil : hoveredAction)
                }

                Spacer()

                let quitHovered = (hoveredAction == "quit")
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 4.5) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        Text("退出")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("⌘Q")
                            .font(TZFont.mono(9.5))
                            .opacity(0.75)
                    }
                    .foregroundStyle(quitHovered ? TZTheme.crimson : TZTheme.crimson.opacity(isDark ? 0.90 : 0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(quitHovered ? TZTheme.crimsonSoft : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    hoveredAction = inside ? "quit" : (hoveredAction == "quit" ? nil : hoveredAction)
                }
            }
        }
        .padding(14)
        .frame(width: 288)
        .background(TZCanvasBackdrop())
        .preferredColorScheme(appState.llmConfig.appearance.colorScheme)
        .onAppear {
            let stateRef = appState
            TypeZeroAppDelegate.openMainWindowAction = { [weak stateRef] in
                guard stateRef != nil else { return }
                presentMainWindow(tab: nil)
            }
        }
    }

    private func quickJumpTile(
        id: String,
        icon: String,
        tint: Color,
        tintSoft: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        let hovered = (hoveredAction == id)
        return Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                        .fill(tintSoft)
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(spacing: 1.5) {
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TZTheme.inkPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(TZFont.mono(9.5))
                        .foregroundStyle(TZTheme.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovered ? TZTheme.cardElevated : TZTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(hovered ? tint.opacity(0.42) : TZTheme.cardBorder, lineWidth: hovered ? 1.0 : 0.9)
            )
            .shadow(
                color: hovered ? tint.opacity(0.14) : Color.black.opacity(0.03),
                radius: hovered ? 5 : 2,
                x: 0,
                y: hovered ? 2 : 1
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            hoveredAction = inside ? id : (hoveredAction == id ? nil : hoveredAction)
        }
    }

    private var activeEngineShortText: String {
        if appState.isOfficialCloudTrialActive { return "自研云端引擎" }
        switch appState.llmConfig.asrProvider {
        case .volcSeedASR: return "豆包 2.0"
        case .openAIWhisper: return appState.isGroqASRSelected ? "Groq" : "OpenAI"
        case .localSenseVoice: return "本地离线"
        }
    }

    private func statMiniTile(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(TZTheme.inkMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(TZFont.metric(19))
                    .foregroundStyle(TZTheme.inkPrimary)
                Text(unit)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(TZTheme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TZTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(TZTheme.cardBorder, lineWidth: 0.9))
    }

    private func formatNum(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    @MainActor
    private func presentMainWindow(tab: SidebarTab?, settingsTab: SettingsSectionTab? = nil) {
        if let tab { appState.selectedTab = tab }
        if let settingsTab { appState.selectedSettingsTab = settingsTab }
        dismiss()
        openWindow(id: "main")
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.identifier?.rawValue == "main" || window.title == "TypeZero" {
                window.deminiaturize(nil)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}
