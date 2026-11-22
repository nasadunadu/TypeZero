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
        TypeZeroApp.main()
    }
}

@MainActor
final class TypeZeroAppDelegate: NSObject, NSApplicationDelegate {
    static var openMainWindowAction: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Stay resident silently in the top macOS Menu Bar when main window is closed
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Re-opening TypeZero from Spotlight or Applications brings the main dashboard right back
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
        .defaultSize(width: 960, height: 680)

        MenuBarExtra("TypeZero", systemImage: "infinity") {
            TypeZeroMenuBarContent(appState: appState)
        }
    }
}

private struct MainWindowHost: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MainDashboardView(appState: appState)
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

private struct TypeZeroMenuBarContent: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开 TypeZero 主界面") {
            presentMainWindow(tab: nil)
        }
        .keyboardShortcut(",", modifiers: [.command])

        Button("引擎与快捷键设置…") {
            presentMainWindow(tab: .settings)
        }

        Button("个人专属词库（\(appState.lexiconStore.entries.count) 词）…") {
            presentMainWindow(tab: .dictionary)
        }

        Divider()

        Text("快捷键：\(appState.activeTriggerDisplayName)")
        Text("今日累计：\(appState.totalCharactersDictated) 字")

        Button("手动开始/结束试音") {
            if case .listening = appState.phase {
                Task { await appState.finishDictationSession() }
            } else {
                appState.beginDictationSession()
            }
        }

        if !appState.history.isEmpty {
            Divider()
            Text("最近口述救生舱（点击复制）")
            ForEach(appState.history.prefix(5)) { rec in
                Button(String(rec.polishedText.replacingOccurrences(of: "\n", with: " ").prefix(26))) {
                    ContextInjector.saveToSafetyClipboard(rec.polishedText)
                }
            }
        }

        Divider()

        Toggle("在程序坞 (Dock) 显示图标", isOn: $appState.llmConfig.showInDock)

        Button("退出 TypeZero") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .onAppear {
            let stateRef = appState
            TypeZeroAppDelegate.openMainWindowAction = { [weak stateRef] in
                guard stateRef != nil else { return }
                presentMainWindow(tab: nil)
            }
        }
    }

    @MainActor
    private func presentMainWindow(tab: SidebarTab?) {
        if let tab {
            appState.selectedTab = tab
        }
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
