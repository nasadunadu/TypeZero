import Foundation
import AppKit

public extension Notification.Name {
    static let typeZeroActivateMainWindow = Notification.Name("io.github.typezero.macos.activateMainWindow")
}

public enum DMGMigrationMode: Equatable, Sendable {
    case freshInstall
    case upgradeInstalled(existingVersion: String)
    case alreadyInstalled(existingVersion: String)
}

/// Guards startup lifecycle on macOS:
/// 1. Single-instance enforcement (activates existing main window; terminates stale DMG-hosted instances when the installed app launches).
/// 2. Installer volume / App Translocation detection with one-click copy to `/Applications`, safe relaunch, and automatic DMG ejection.
/// 3. Gentle background ejection of already-installed TypeZero DMG volumes so desktop disk images never stay stuck.
public enum AppLaunchGuard {
    public static let expectedBundleID = "io.github.typezero.macos"

    // MARK: - Pure Testable Classification Logic

    public static func isAppTranslocatedPath(_ path: String) -> Bool {
        path.contains("/AppTranslocation/")
    }

    public static func isPath(_ path: String, insideVolume mountPoint: String) -> Bool {
        let normalizedMount = mountPoint.hasSuffix("/") && mountPoint.count > 1
            ? String(mountPoint.dropLast())
            : mountPoint
        guard !normalizedMount.isEmpty else { return false }
        return path == normalizedMount || path.hasPrefix(normalizedMount + "/")
    }

    public static func isInstallerBundlePath(
        _ path: String,
        mountedDMGPoints: [String],
        isReadOnlyVolume: Bool,
        isRootVolume: Bool
    ) -> Bool {
        guard path.hasSuffix(".app") else { return false }
        if isAppTranslocatedPath(path) {
            return true
        }
        for mountPoint in mountedDMGPoints where isPath(path, insideVolume: mountPoint) {
            return true
        }
        if path.hasPrefix("/Volumes/") && !isRootVolume && isReadOnlyVolume {
            return true
        }
        return false
    }

    /// Parses `hdiutil info -plist` XML output and returns unique mounted disk-image paths under `/Volumes/`.
    public static func parseMountedDMGPoints(fromPlistData data: Data) -> [String] {
        guard !data.isEmpty,
              let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let images = root["images"] as? [[String: Any]] else {
            return []
        }

        var result: [String] = []
        var seen = Set<String>()
        for image in images {
            guard let entities = image["system-entities"] as? [[String: Any]] else { continue }
            for entity in entities {
                if let mountPoint = entity["mount-point"] as? String,
                   mountPoint.hasPrefix("/Volumes/"),
                   !seen.contains(mountPoint) {
                    seen.insert(mountPoint)
                    result.append(mountPoint)
                }
            }
        }
        return result
    }

    public static func determineDMGMigrationMode(
        currentVersion: String,
        installedVersion: String?
    ) -> DMGMigrationMode {
        guard let installed = installedVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !installed.isEmpty else {
            return .freshInstall
        }
        if AppUpdater.isNewerVersion(currentVersion, than: installed) {
            return .upgradeInstalled(existingVersion: installed)
        }
        return .alreadyInstalled(existingVersion: installed)
    }

    /// Only auto-ejects mounted TypeZero DMG volumes whose bundled app matches our bundle ID
    /// and is the same or older version than the currently running installed app (never interrupts a newer upgrade DMG).
    public static func shouldAutoEjectInstallerDMG(
        dmgAppVersion: String?,
        runningAppVersion: String,
        dmgBundleID: String?
    ) -> Bool {
        guard dmgBundleID == expectedBundleID else { return false }
        if let dmgVer = dmgAppVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !dmgVer.isEmpty,
           AppUpdater.isNewerVersion(dmgVer, than: runningAppVersion) {
            return false
        }
        return true
    }

    // MARK: - Startup Enforcement (Pre-SwiftUI, Zero UI)

    /// Runs before `TypeZeroApp.main()`. Ensures only one installed instance runs at a time,
    /// and cleanly terminates any lingering DMG-hosted instance when the user opens the installed app.
    public static func enforceSingleInstanceBeforeAppLaunch() {
        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentBundleURL.pathExtension == "app" else { return }

        let bundleID = Bundle.main.bundleIdentifier ?? expectedBundleID
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID && !$0.isTerminated }
        guard !others.isEmpty else { return }

        let mountedDMGs = queryMountedDMGPoints()
        let currentIsInstaller = isBundleOnInstallerVolume(currentBundleURL, mountedDMGPoints: mountedDMGs)

        // If the newly launched process is itself on a DMG / Translocation, defer to the interactive
        // migration prompt so the user can choose to switch/upgrade and eject the DMG cleanly.
        guard !currentIsInstaller else { return }

        var normalPeers: [NSRunningApplication] = []
        var installerPeers: [NSRunningApplication] = []
        for peer in others {
            if let peerURL = peer.bundleURL?.standardizedFileURL,
               isBundleOnInstallerVolume(peerURL, mountedDMGPoints: mountedDMGs) {
                installerPeers.append(peer)
            } else {
                normalPeers.append(peer)
            }
        }

        // Terminate any stale instance still running out of a DMG so the desktop disk image unlocks.
        for dmgPeer in installerPeers {
            terminateAndWait(dmgPeer, timeout: 1.5)
        }

        // If another normal installed instance is already active, bring its main window to front and exit.
        if let existing = normalPeers.first {
            DistributedNotificationCenter.default().postNotificationName(
                .typeZeroActivateMainWindow,
                object: bundleID,
                userInfo: nil,
                deliverImmediately: true
            )
            existing.activate()
            // Flush distnoted IPC before terminating so the existing instance reliably surfaces its window
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.12))
            exit(0)
        }
    }

    // MARK: - Interactive DMG / Translocation Migration Prompt

    /// Detects launch directly from a DMG or Gatekeeper AppTranslocation read-only path and offers
    /// one-click installation into `/Applications` (or switching to an existing install) + automatic DMG ejection.
    /// Returns `true` when the app is handing off and terminating, so callers skip normal initialization.
    @MainActor
    public static func promptInstallerVolumeMigrationIfNeeded() -> Bool {
        if ProcessInfo.processInfo.environment["TYPEZERO_SKIP_MOVE_PROMPT"] == "1" {
            return false
        }

        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentBundleURL.pathExtension == "app" else { return false }

        let mountedDMGs = queryMountedDMGPoints()
        guard isBundleOnInstallerVolume(currentBundleURL, mountedDMGPoints: mountedDMGs) else {
            return false
        }

        let targetAppURL = resolveInstallDestinationURL()
        let installedExists = FileManager.default.fileExists(atPath: targetAppURL.path)
        let installedVersion = installedExists ? readAppBundleVersion(at: targetAppURL) : nil
        let currentVersion = AppUpdater.currentAppVersion
        let mode = determineDMGMigrationMode(currentVersion: currentVersion, installedVersion: installedVersion)
        let dmgVolumesToEject = findTypeZeroInstallerMountPoints(
            mountedDMGPoints: mountedDMGs,
            currentBundleURL: currentBundleURL
        )

        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        let alert = NSAlert()
        alert.alertStyle = .informational
        if let icon = NSApp.applicationIconImage {
            alert.icon = icon
        }

        switch mode {
        case .freshInstall:
            alert.messageText = "将 TypeZero 移至“应用程序”并推出安装包？"
            alert.informativeText = """
            您正在直接从安装包镜像运行 TypeZero，这会导致桌面上的安装包一直提示“正在使用”而无法推出，且无法自动更新。

            点击下方按钮将自动安装到“\(targetAppURL.deletingLastPathComponent().path)”、打开正式版，并自动推出桌面安装包。
            """
            alert.addButton(withTitle: "移动到“应用程序”并推出安装包")
            alert.addButton(withTitle: "暂不移动")

            let resp = alert.runModal()
            guard resp == .alertFirstButtonReturn else { return false }
            return performInstallAndRelaunch(
                sourceAppURL: currentBundleURL,
                targetAppURL: targetAppURL,
                dmgVolumesToEject: dmgVolumesToEject
            )

        case .upgradeInstalled(let existingVer):
            alert.messageText = "用安装包中的 TypeZero v\(currentVersion) 更新已安装版本？"
            alert.informativeText = """
            检测到安装包版本（v\(currentVersion)）新于“应用程序”中已安装版本（v\(existingVer)）。

            点击下方按钮将自动替换升级到“应用程序”、重启新版，并自动推出桌面安装包。
            """
            alert.addButton(withTitle: "升级并推出安装包")
            alert.addButton(withTitle: "暂不移动")

            let resp = alert.runModal()
            guard resp == .alertFirstButtonReturn else { return false }
            return performInstallAndRelaunch(
                sourceAppURL: currentBundleURL,
                targetAppURL: targetAppURL,
                dmgVolumesToEject: dmgVolumesToEject
            )

        case .alreadyInstalled(let existingVer):
            alert.messageText = "“应用程序”中已安装 TypeZero v\(existingVer)"
            alert.informativeText = """
            您当前从安装包镜像打开了 TypeZero，继续运行会锁定桌面上的安装包导致无法推出。

            建议直接切换打开“应用程序”中的正式版，并自动推出桌面安装包。
            """
            alert.addButton(withTitle: "打开已安装版本并推出安装包")
            alert.addButton(withTitle: "覆盖重新安装")
            alert.addButton(withTitle: "暂不移动")

            let resp = alert.runModal()
            if resp == .alertFirstButtonReturn {
                return performSwitchToInstalledAndEject(
                    targetAppURL: targetAppURL,
                    dmgVolumesToEject: dmgVolumesToEject
                )
            } else if resp == .alertSecondButtonReturn {
                return performInstallAndRelaunch(
                    sourceAppURL: currentBundleURL,
                    targetAppURL: targetAppURL,
                    dmgVolumesToEject: dmgVolumesToEject
                )
            }
            return false
        }
    }

    // MARK: - Background Gentle Ejection for Already-Installed DMG Volumes

    /// Called after a normal installed instance starts. Gently detaches any leftover desktop
    /// TypeZero DMG whose version is <= the running app (never uses `-force` so user-opened files stay safe).
    public static func ejectStaleInstallerDMGsInBackground() {
        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentBundleURL.pathExtension == "app" else { return }

        let runningVersion = AppUpdater.currentAppVersion
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.6) {
            let mountedDMGs = queryMountedDMGPoints()
            guard !isBundleOnInstallerVolume(currentBundleURL, mountedDMGPoints: mountedDMGs) else {
                return
            }

            for mountPoint in mountedDMGs {
                let candidateApp = URL(fileURLWithPath: mountPoint, isDirectory: true)
                    .appendingPathComponent("TypeZero.app", isDirectory: true)
                guard FileManager.default.fileExists(atPath: candidateApp.path) else { continue }
                let dmgBundleID = readAppBundleIdentifier(at: candidateApp)
                let dmgVersion = readAppBundleVersion(at: candidateApp)
                guard shouldAutoEjectInstallerDMG(
                    dmgAppVersion: dmgVersion,
                    runningAppVersion: runningVersion,
                    dmgBundleID: dmgBundleID
                ) else {
                    continue
                }
                gentleDetachDMG(mountPoint: mountPoint, retries: 3, intervalSeconds: 0.5)
            }
        }
    }

    // MARK: - Execution Helpers

    @MainActor
    private static func performInstallAndRelaunch(
        sourceAppURL: URL,
        targetAppURL: URL,
        dmgVolumesToEject: [String]
    ) -> Bool {
        do {
            let fm = FileManager.default
            let targetParent = targetAppURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: targetParent.path) {
                try fm.createDirectory(at: targetParent, withIntermediateDirectories: true)
            }

            let workDir = fm.temporaryDirectory
                .appendingPathComponent("TypeZero-Install-\(UUID().uuidString.prefix(8))", isDirectory: true)
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
            let stagedAppURL = workDir.appendingPathComponent("TypeZero.app", isDirectory: true)

            let copyRes = try runProcess("/usr/bin/ditto", arguments: [sourceAppURL.path, stagedAppURL.path])
            guard copyRes.status == 0 else {
                throw NSError(
                    domain: "TypeZero.LaunchGuard",
                    code: Int(copyRes.status),
                    userInfo: [NSLocalizedDescriptionKey: "复制应用失败（ditto exit \(copyRes.status)）"]
                )
            }

            // Strip quarantine attribute on the newly copied bundle (does not invalidate Developer ID signature)
            _ = try? runProcess("/usr/bin/xattr", arguments: ["-dr", "com.apple.quarantine", stagedAppURL.path])

            // Stop any other running TypeZero instances before replacing target bundle
            let bundleID = Bundle.main.bundleIdentifier ?? expectedBundleID
            let currentPID = ProcessInfo.processInfo.processIdentifier
            for peer in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                where peer.processIdentifier != currentPID && !peer.isTerminated {
                terminateAndWait(peer, timeout: 1.5)
            }

            try launchDetachedHandoffScript(
                workDir: workDir,
                mode: "install",
                stagedAppPath: stagedAppURL.path,
                targetAppPath: targetAppURL.path,
                dmgVolumesToEject: dmgVolumesToEject
            )
            exit(0)
        } catch {
            let errAlert = NSAlert()
            errAlert.alertStyle = .warning
            errAlert.messageText = "自动移动到“应用程序”失败"
            errAlert.informativeText = "\(error.localizedDescription)\n\n请手动将安装包中的 TypeZero.app 拖入“应用程序”文件夹后再打开。"
            errAlert.addButton(withTitle: "继续运行")
            errAlert.runModal()
            return false
        }
    }

    @MainActor
    private static func performSwitchToInstalledAndEject(
        targetAppURL: URL,
        dmgVolumesToEject: [String]
    ) -> Bool {
        do {
            let fm = FileManager.default
            let workDir = fm.temporaryDirectory
                .appendingPathComponent("TypeZero-Switch-\(UUID().uuidString.prefix(8))", isDirectory: true)
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

            // If the installed app is already running, notify it to surface its main window immediately
            let bundleID = Bundle.main.bundleIdentifier ?? expectedBundleID
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let installedRunning = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first { peer in
                    peer.processIdentifier != currentPID
                        && !peer.isTerminated
                        && peer.bundleURL?.standardizedFileURL == targetAppURL.standardizedFileURL
                }
            if let existing = installedRunning {
                DistributedNotificationCenter.default().postNotificationName(
                    .typeZeroActivateMainWindow,
                    object: bundleID,
                    userInfo: nil,
                    deliverImmediately: true
                )
                existing.activate()
            }

            try launchDetachedHandoffScript(
                workDir: workDir,
                mode: "switch",
                stagedAppPath: "",
                targetAppPath: targetAppURL.path,
                dmgVolumesToEject: dmgVolumesToEject
            )
            exit(0)
        } catch {
            return false
        }
    }

    /// Spawns a detached POSIX shell script passing all paths as positional arguments (safe with spaces/special chars, zero `rm`).
    /// Steps: wait for current DMG process to exit -> swap into `/Applications` if installing (old copy moved to `~/.Trash`) ->
    /// gently detach DMG volumes with retries -> open installed `/Applications/TypeZero.app`.
    private static func launchDetachedHandoffScript(
        workDir: URL,
        mode: String,
        stagedAppPath: String,
        targetAppPath: String,
        dmgVolumesToEject: [String]
    ) throws {
        let scriptURL = workDir.appendingPathComponent("handoff-launch.sh")
        let script = """
        #!/bin/sh
        PARENT_PID="$1"
        MODE="$2"
        STAGED="$3"
        TARGET="$4"
        shift 4

        i=0
        while kill -0 "$PARENT_PID" 2>/dev/null && [ "$i" -lt 40 ]; do
          sleep 0.25
          i=$((i + 1))
        done

        if [ "$MODE" = "install" ]; then
          if [ -d "$TARGET" ]; then
            TRASH_DEST="$HOME/.Trash/TypeZero-old-$(date +%s)-$$.app"
            mv "$TARGET" "$TRASH_DEST" 2>/dev/null || exit 1
          fi
          mv "$STAGED" "$TARGET" || {
            if [ -n "${TRASH_DEST:-}" ] && [ -d "$TRASH_DEST" ]; then
              mv "$TRASH_DEST" "$TARGET"
            fi
            exit 1
          }
        fi

        for VOL in "$@"; do
          [ -n "$VOL" ] || continue
          attempt=0
          while [ -d "$VOL" ] && [ "$attempt" -lt 8 ]; do
            if /usr/bin/hdiutil detach "$VOL" -quiet 2>/dev/null; then
              break
            fi
            sleep 0.4
            attempt=$((attempt + 1))
          done
        done

        /usr/bin/open "$TARGET"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        var args = [
            scriptURL.path,
            String(ProcessInfo.processInfo.processIdentifier),
            mode,
            stagedAppPath,
            targetAppPath
        ]
        args.append(contentsOf: dmgVolumesToEject)
        proc.arguments = args
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
    }

    // MARK: - System Inspection Utilities

    private static func resolveInstallDestinationURL() -> URL {
        let fm = FileManager.default
        if fm.isWritableFile(atPath: "/Applications") {
            return URL(fileURLWithPath: "/Applications/TypeZero.app", isDirectory: true)
        }
        return fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("TypeZero.app", isDirectory: true)
    }

    private static func isBundleOnInstallerVolume(_ bundleURL: URL, mountedDMGPoints: [String]) -> Bool {
        let values = try? bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey, .volumeIsRootFileSystemKey])
        let isReadOnly = values?.volumeIsReadOnly ?? false
        let isRoot = values?.volumeIsRootFileSystem ?? false
        return isInstallerBundlePath(
            bundleURL.path,
            mountedDMGPoints: mountedDMGPoints,
            isReadOnlyVolume: isReadOnly,
            isRootVolume: isRoot
        )
    }

    private static func queryMountedDMGPoints() -> [String] {
        guard let res = try? runProcess("/usr/bin/hdiutil", arguments: ["info", "-plist"]),
              res.status == 0,
              let data = res.stdout.data(using: .utf8) else {
            return []
        }
        return parseMountedDMGPoints(fromPlistData: data)
    }

    private static func findTypeZeroInstallerMountPoints(
        mountedDMGPoints: [String],
        currentBundleURL: URL
    ) -> [String] {
        var matched: [String] = []
        var seen = Set<String>()

        for mountPoint in mountedDMGPoints {
            if isPath(currentBundleURL.path, insideVolume: mountPoint) {
                if !seen.contains(mountPoint) {
                    seen.insert(mountPoint)
                    matched.append(mountPoint)
                }
                continue
            }
            let appURL = URL(fileURLWithPath: mountPoint, isDirectory: true)
                .appendingPathComponent("TypeZero.app", isDirectory: true)
            if FileManager.default.fileExists(atPath: appURL.path),
               readAppBundleIdentifier(at: appURL) == expectedBundleID,
               !seen.contains(mountPoint) {
                seen.insert(mountPoint)
                matched.append(mountPoint)
            }
        }
        return matched
    }

    private static func readInfoPlist(at appBundleURL: URL) -> [String: Any]? {
        let plistURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return dict
    }

    private static func readAppBundleVersion(at appBundleURL: URL) -> String? {
        readInfoPlist(at: appBundleURL)?["CFBundleShortVersionString"] as? String
    }

    private static func readAppBundleIdentifier(at appBundleURL: URL) -> String? {
        readInfoPlist(at: appBundleURL)?["CFBundleIdentifier"] as? String
    }

    private static func terminateAndWait(_ app: NSRunningApplication, timeout: TimeInterval) {
        _ = app.terminate()
        let deadline = Date().addingTimeInterval(timeout)
        while !app.isTerminated && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if !app.isTerminated {
            _ = app.forceTerminate()
            let forceDeadline = Date().addingTimeInterval(0.5)
            while !app.isTerminated && Date() < forceDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    private static func gentleDetachDMG(mountPoint: String, retries: Int, intervalSeconds: TimeInterval) {
        for attempt in 0..<retries {
            guard FileManager.default.fileExists(atPath: mountPoint) else { return }
            if let res = try? runProcess("/usr/bin/hdiutil", arguments: ["detach", mountPoint, "-quiet"]),
               res.status == 0 {
                return
            }
            if attempt + 1 < retries {
                Thread.sleep(forTimeInterval: intervalSeconds)
            }
        }
    }

    private static func runProcess(_ path: String, arguments: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        try p.run()
        p.waitUntilExit()
        let outStr = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errStr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, outStr, errStr)
    }
}
