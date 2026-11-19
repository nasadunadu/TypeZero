import Foundation

/// In-app downloader & extractor for the lossless 886MB `SenseVoice-Small FP32` offline hot-standby model.
/// Allows non-technical colleagues receiving `TypeZero.app` to install the full offline acoustic pack in 1 click!
public final class OfflineModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private static let mirrorURLStrings: [String] = [
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09.tar.bz2",
        "https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09.tar.bz2"
    ]

    private let lock = NSLock()
    private var session: URLSession?
    private var activeTask: URLSessionDownloadTask?
    private var currentMirrorIndex: Int = 0
    private var isCancelledManually: Bool = false

    public var onProgress: (@MainActor (_ fraction: Double, _ statusText: String) -> Void)?
    public var onCompletion: (@MainActor (_ success: Bool, _ message: String) -> Void)?

    public override init() {
        super.init()
    }

    public func startDownload() {
        lock.lock()
        guard activeTask == nil else {
            lock.unlock()
            return
        }
        isCancelledManually = false
        currentMirrorIndex = 0
        lock.unlock()

        startFromCurrentMirror()
    }

    public func cancelDownload() {
        lock.lock()
        isCancelledManually = true
        let task = activeTask
        activeTask = nil
        let sess = session
        session = nil
        lock.unlock()

        task?.cancel()
        sess?.invalidateAndCancel()
        Task { @MainActor [weak self] in
            self?.onCompletion?(false, "已取消离线模型下载")
        }
    }

    private func startFromCurrentMirror() {
        lock.lock()
        let idx = currentMirrorIndex
        lock.unlock()

        guard idx < Self.mirrorURLStrings.count,
              let url = URL(string: Self.mirrorURLStrings[idx]) else {
            Task { @MainActor [weak self] in
                self?.onCompletion?(false, "❌ 离线模型下载失败，请检查网络连接后重试")
            }
            return
        }

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30.0
        cfg.timeoutIntervalForResource = 3600.0
        let newSession = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        let task = newSession.downloadTask(with: url)

        lock.lock()
        self.session = newSession
        self.activeTask = task
        lock.unlock()

        let mirrorNote = idx == 0 ? "连接官方源…" : "已切换加速镜像下载…"
        Task { @MainActor [weak self] in
            self?.onProgress?(0.01, mirrorNote)
        }
        task.resume()
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 886_000_000
        let frac = min(0.95, max(0.01, Double(totalBytesWritten) / Double(expected)))
        let mbDone = Int(totalBytesWritten / 1_048_576)
        let mbTotal = max(mbDone, Int(expected / 1_048_576))
        let status = "正在下载离线满血包 \(mbDone) / \(mbTotal) MB (\(Int(frac * 100))%)"

        Task { @MainActor [weak self] in
            self?.onProgress?(frac, status)
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            tryNextMirrorOrFail(session: session, errorMsg: "HTTP \(http.statusCode)")
            return
        }

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let modelsRoot = appSupport.appendingPathComponent("TypeZero/Models", isDirectory: true)
        try? fm.createDirectory(at: modelsRoot, withIntermediateDirectories: true)

        let archiveDest = modelsRoot.appendingPathComponent("sensevoice-fp32-download.tar.bz2")
        if fm.fileExists(atPath: archiveDest.path) {
            try? fm.trashItem(at: archiveDest, resultingItemURL: nil)
        }

        do {
            try fm.moveItem(at: location, to: archiveDest)
        } catch {
            cleanupSession(session)
            Task { @MainActor [weak self] in
                self?.onCompletion?(false, "❌ 保存模型压缩包失败：\(error.localizedDescription)")
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.onProgress?(0.97, "下载完成，正在解压 886MB 无损模型权重…")
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            proc.arguments = ["-xjf", archiveDest.path, "-C", modelsRoot.path]

            do {
                try proc.run()
                proc.waitUntilExit()
                try? fm.trashItem(at: archiveDest, resultingItemURL: nil)
                self.cleanupSession(session)

                let modelPath = modelsRoot
                    .appendingPathComponent("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2025-09-09/model.onnx")
                    .path
                if proc.terminationStatus == 0 && fm.fileExists(atPath: modelPath) {
                    Task { @MainActor in
                        self.onProgress?(1.0, "离线满血底座安装完成")
                        self.onCompletion?(true, "✅ 本机 886MB SenseVoice FP32 离线满血底座已安装并激活")
                    }
                } else {
                    Task { @MainActor in
                        self.onCompletion?(false, "❌ 解压离线模型未成功（退出码 \(proc.terminationStatus)）")
                    }
                }
            } catch {
                try? fm.trashItem(at: archiveDest, resultingItemURL: nil)
                self.cleanupSession(session)
                Task { @MainActor in
                    self.onCompletion?(false, "❌ 解压失败：\(error.localizedDescription)")
                }
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        lock.lock()
        let cancelled = isCancelledManually
        lock.unlock()
        if cancelled { return }
        tryNextMirrorOrFail(session: session, errorMsg: error.localizedDescription)
    }

    private func tryNextMirrorOrFail(session: URLSession, errorMsg: String) {
        session.invalidateAndCancel()
        lock.lock()
        activeTask = nil
        self.session = nil
        currentMirrorIndex += 1
        let nextIdx = currentMirrorIndex
        lock.unlock()

        if nextIdx < Self.mirrorURLStrings.count {
            startFromCurrentMirror()
        } else {
            Task { @MainActor [weak self] in
                self?.onCompletion?(false, "❌ 离线模型下载失败：\(errorMsg)")
            }
        }
    }

    private func cleanupSession(_ session: URLSession) {
        session.finishTasksAndInvalidate()
        lock.lock()
        activeTask = nil
        if self.session === session {
            self.session = nil
        }
        lock.unlock()
    }
}
