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

struct TypeZeroApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("TypeZero") {
            MainDashboardView(appState: appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 660)

        MenuBarExtra("TypeZero", systemImage: "infinity") {
            Text("TypeZero · 说话，不要打字")
            Divider()
            Text("快捷键：\(appState.activeTriggerDisplayName)")
            Text("专属词库：\(appState.lexiconStore.entries.count) 词")
            Text("今日累计：\(appState.totalCharactersDictated) 字")
            Divider()
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
            Button("退出 TypeZero") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
