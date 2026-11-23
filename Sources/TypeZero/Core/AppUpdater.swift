import Foundation
import CryptoKit
import AppKit

public struct MacOSReleaseAsset: Codable, Equatable, Sendable {
    public let dmgUrl: String
    public let fallbackDmgUrl: String?
    public let fileName: String?
    public let sizeBytes: Int64?
    public let sha256: String?
}

public struct AppVersionManifest: Codable, Equatable, Sendable {
    public let ok: Bool
    public let version: String
    public let tag: String
    public let name: String?
    public let publishedAt: String?
    public let releaseNotes: String?
    public let releaseUrl: String?
    public let macos: MacOSReleaseAsset?
}

public enum AppUpdaterError: LocalizedError {
    case invalidURL
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case mountFailed(String)
    case appNotFoundInDMG
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "更新包下载地址无效"
        case .downloadFailed(let msg):
            return "下载更新包失败：\(msg)"
        case .checksumMismatch:
            return "安装包 SHA-256 校验未通过，已中止更新以保护安全"
        case .mountFailed(let msg):
            return "挂载安装包失败：\(msg)"
        case .appNotFoundInDMG:
            return "安装包内未找到 TypeZero.app"
        case .installFailed(let msg):
            return "替换安装失败：\(msg)"
        }
    }
}

public enum AppUpdater {
    public static let compiledVersion = "0.5.6"
    public static let versionEndpoint = "\(CloudAuthClient.baseURL)/api/version"

    public static var currentAppVersion: String {
        if let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let trimmed = short.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return compiledVersion
    }

    /// Semantic version comparator: returns `true` iff `remote` is strictly newer than `current` (e.g. "0.5.6" > "0.5.5").
    public static func isNewerVersion(_ remote: String, than current: String) -> Bool {
        func parseParts(_ v: String) -> [Int] {
            let cleaned = v.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let core = cleaned.split(separator: "-", maxSplits: 1).first.map(String.init) ?? cleaned
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }
        let r = parseParts(remote)
        let c = parseParts(current)
        let count = max(r.count, c.count)
        guard count > 0 else { return false }
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv {
                return rv > cv
            }
        }
        return false
    }

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15.0
        cfg.timeoutIntervalForResource = 180.0
        return URLSession(configuration: cfg)
    }()

    public static func fetchLatestManifest(forceRefresh: Bool = false) async throws -> AppVersionManifest {
        let urlStr = forceRefresh ? "\(versionEndpoint)?refresh=1" : versionEndpoint
        guard let url = URL(string: urlStr) else {
            throw AppUpdaterError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw AppUpdaterError.downloadFailed("版本服务返回 HTTP \(code)")
        }
        return try JSONDecoder().decode(AppVersionManifest.self, from: data)
    }

    /// Downloads the notarized DMG, verifies SHA-256, extracts `TypeZero.app`, swaps in-place safely
    /// (moving old `.app` into `~/.Trash`), and relaunches the updated app automatically!
    public static func downloadAndInstallMacOSUpdate(
        manifest: AppVersionManifest,
        onProgress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> Bool {
        guard let macAsset = manifest.macos else {
            throw AppUpdaterError.invalidURL
        }
        let candidateURLs = [macAsset.dmgUrl, macAsset.fallbackDmgUrl ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !candidateURLs.isEmpty else {
            throw AppUpdaterError.invalidURL
        }

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TypeZero-Update-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let fileName = macAsset.fileName ?? "TypeZero-\(manifest.tag)-macOS-arm64.dmg"
        let dmgURL = workDir.appendingPathComponent(fileName)

        onProgress(0.04, "正在连接高速下载节点…")
        var lastDownloadErr: Error = AppUpdaterError.downloadFailed("无可用下载节点")
        var downloaded = false
        for (idx, rawUrl) in candidateURLs.enumerated() {
            guard let remoteURL = URL(string: rawUrl) else { continue }
            do {
                try await streamDownload(
                    from: remoteURL,
                    to: dmgURL,
                    expectedSize: macAsset.sizeBytes ?? 0,
                    onProgress: onProgress
                )
                downloaded = true
                break
            } catch {
                lastDownloadErr = error
                if idx + 1 < candidateURLs.count {
                    onProgress(0.06, "主节点较慢，自动切换备用高速线路…")
                }
            }
        }
        guard downloaded else {
            throw lastDownloadErr
        }

        // SHA-256 integrity verification
        if let expectedSha = macAsset.sha256?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           expectedSha.count == 64 {
            onProgress(0.84, "正在校验 Apple 公证安装包完整性 (SHA-256)…")
            let actualSha = try computeSHA256(fileURL: dmgURL)
            if actualSha != expectedSha {
                throw AppUpdaterError.checksumMismatch(expected: expectedSha, actual: actualSha)
            }
        }

        // Resolve writable .app install destination
        let targetAppURL = resolveWritableTargetAppURL()
        guard let targetAppURL else {
            // Fallback: open DMG directly if running outside a writable Applications bundle
            onProgress(1.0, "安装包已下载就绪，正在打开安装镜像…")
            await MainActor.run {
                _ = NSWorkspace.shared.open(dmgURL)
            }
            return false
        }

        onProgress(0.88, "正在静默挂载并解包新版本…")
        let mountDir = workDir.appendingPathComponent("mnt", isDirectory: true)
        try FileManager.default.createDirectory(at: mountDir, withIntermediateDirectories: true)

        let attachRes = try runProcess(
            "/usr/bin/hdiutil",
            arguments: ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountpoint", mountDir.path, "-quiet"]
        )
        guard attachRes.status == 0 else {
            throw AppUpdaterError.mountFailed(attachRes.stderr.isEmpty ? "exit \(attachRes.status)" : attachRes.stderr)
        }
        defer {
            _ = try? runProcess("/usr/bin/hdiutil", arguments: ["detach", mountDir.path, "-quiet", "-force"])
        }

        let mountedApp = mountDir.appendingPathComponent("TypeZero.app", isDirectory: true)
        guard FileManager.default.fileExists(atPath: mountedApp.path) else {
            throw AppUpdaterError.appNotFoundInDMG
        }

        onProgress(0.94, "正在准备新版本 TypeZero \(manifest.tag)…")
        let stagedApp = workDir.appendingPathComponent("TypeZero.app", isDirectory: true)
        let dittoRes = try runProcess("/usr/bin/ditto", arguments: [mountedApp.path, stagedApp.path])
        guard dittoRes.status == 0 else {
            throw AppUpdaterError.installFailed("解包失败（ditto exit \(dittoRes.status)）")
        }

        onProgress(0.98, "正在切换至 \(manifest.tag) 并自动重启…")
        try launchDetachedSwapAndRelaunch(stagedApp: stagedApp, targetApp: targetAppURL, parentPID: ProcessInfo.processInfo.processIdentifier)
        return true
    }

    private static func resolveWritableTargetAppURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        let fm = FileManager.default
        if bundleURL.pathExtension == "app" {
            let parent = bundleURL.deletingLastPathComponent()
            if fm.isWritableFile(atPath: parent.path) && !bundleURL.path.contains("/AppTranslocation/") {
                return bundleURL
            }
        }
        let standardApps = URL(fileURLWithPath: "/Applications/TypeZero.app")
        if fm.fileExists(atPath: standardApps.path) && fm.isWritableFile(atPath: "/Applications") {
            return standardApps
        }
        return nil
    }

    private static func launchDetachedSwapAndRelaunch(stagedApp: URL, targetApp: URL, parentPID: Int32) throws {
        let scriptURL = stagedApp.deletingLastPathComponent().appendingPathComponent("apply-update.sh")
        let trashBackupName = "TypeZero-old-\(Int(Date().timeIntervalSince1970)).app"
        let script = """
        #!/bin/sh
        PID=\(parentPID)
        TARGET="\(targetApp.path)"
        STAGED="\(stagedApp.path)"
        TRASH_DEST="$HOME/.Trash/\(trashBackupName)"

        i=0
        while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 60 ]; do
          sleep 0.25
          i=$((i + 1))
        done

        if [ -d "$TARGET" ]; then
          mv "$TARGET" "$TRASH_DEST" 2>/dev/null || exit 1
        fi
        mv "$STAGED" "$TARGET" || {
          if [ -d "$TRASH_DEST" ]; then mv "$TRASH_DEST" "$TARGET"; fi
          exit 1
        }
        open -n "$TARGET"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = [scriptURL.path]
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
    }

    private static func streamDownload(
        from remoteURL: URL,
        to destination: URL,
        expectedSize: Int64,
        onProgress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        var req = URLRequest(url: remoteURL)
        req.timeoutInterval = 30
        let (bytes, resp) = try await session.bytes(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw AppUpdaterError.downloadFailed("HTTP \(code)")
        }
        let total = http.expectedContentLength > 0 ? http.expectedContentLength : expectedSize
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        var buffer = Data()
        buffer.reserveCapacity(65_536)
        var received: Int64 = 0
        var lastReportedPct: Int = -1

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 65_536 {
                try handle.write(contentsOf: buffer)
                received += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if total > 0 {
                    let frac = min(1.0, Double(received) / Double(total))
                    let pct = Int(frac * 100)
                    if pct != lastReportedPct {
                        lastReportedPct = pct
                        let mbDone = Double(received) / 1_048_576.0
                        let mbTotal = Double(total) / 1_048_576.0
                        onProgress(0.05 + frac * 0.77, String(format: "正在下载新版安装包 %.1f / %.1f MB (%d%%)…", mbDone, mbTotal, pct))
                    }
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            received += Int64(buffer.count)
        }
        guard received > 500_000 else {
            throw AppUpdaterError.downloadFailed("安装包体积异常（仅 \(received) 字节）")
        }
        onProgress(0.82, "安装包下载完成，准备校验…")
    }

    private static func computeSHA256(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 262_144)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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
        return (p.terminationStatus, outStr.trimmingCharacters(in: .whitespacesAndNewlines), errStr.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
