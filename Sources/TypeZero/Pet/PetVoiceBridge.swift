import Foundation
import CoreGraphics
import QuartzCore

/// Real-time Cloud Voice -> Pinyin Keystroke Choreography -> Text Bridge.
/// Converts streamed Chinese / English / punctuation text from TypeZero's ASR & LLM Polish pipeline
/// into authentic mechanical keyboard keystrokes (`J` -> `I` -> `N`) so the desktop cat furiously
/// taps real keys with both paws (+ 3-key hind foot & tail easter eggs) as text appears on screen!
final class PetVoiceBridge {
    static let shared = PetVoiceBridge()

    struct KeyStep: Equatable {
        let key: PhysicalKey
        let spokenCharLabel: String
    }

    private static let pinyinCacheLock = NSLock()
    private static var pinyinKeyCache: [Character: [PhysicalKey]] = [:]

    private let queueLock = NSLock()
    private var pendingSteps: [KeyStep] = []
    private var pacerTimer: DispatchSourceTimer?
    private var isPacerRunning = false
    private var activeReleaseDeadlines: [PhysicalKey: CFTimeInterval] = [:]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private(set) var todayVoiceKeystrokes: Int = 0
    private var statsDay: String = ""

    var onVoiceStatsUpdated: ((Int) -> Void)?

    private init() {
        loadTodayVoiceStats()
    }

    // MARK: - Character / Pinyin Decomposition

    /// Converts arbitrary text (Chinese characters, English words, digits, punctuation) into
    /// authentic QWERTY mechanical keyboard key steps (`PhysicalKey`).
    /// - Chinese `'今'` -> `[(.j, ""), (.i, ""), (.n, "今")]`
    /// - English `'Hi'` -> `[(.h, "H"), (.i, "i")]`
    static func decomposeToKeystrokes(_ text: String) -> [KeyStep] {
        guard !text.isEmpty else { return [] }
        var steps: [KeyStep] = []
        steps.reserveCapacity(text.count * 3)

        for ch in text {
            if let directKey = PhysicalKey.fromCharacter(ch) {
                let spoken = (ch == "\n" || ch == "\r") ? "↵" : (ch == " " ? "␣" : String(ch).uppercased())
                steps.append(KeyStep(key: directKey, spokenCharLabel: spoken))
                continue
            }

            // CJK Ideographs & non-ASCII letters -> fast cached CFStringTransform to Latin Pinyin
            let pyKeys = pinyinKeys(for: ch)
            if !pyKeys.isEmpty {
                for (idx, pk) in pyKeys.enumerated() {
                    let spoken = (idx == pyKeys.count - 1) ? String(ch) : ""
                    steps.append(KeyStep(key: pk, spokenCharLabel: spoken))
                }
            }
        }
        return steps
    }

    private static func pinyinKeys(for ch: Character) -> [PhysicalKey] {
        pinyinCacheLock.lock()
        if let cached = pinyinKeyCache[ch] {
            pinyinCacheLock.unlock()
            return cached
        }
        pinyinCacheLock.unlock()

        let mutable = NSMutableString(string: String(ch)) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        let latin = (mutable as String).lowercased()

        var keys: [PhysicalKey] = []
        for scalar in latin {
            if scalar >= "a" && scalar <= "z", let pk = PhysicalKey.fromCharacter(scalar) {
                keys.append(pk)
            }
        }
        // Cap per-character syllable length to <= 4 keys so rapid Chinese speech stays ultra-snappy!
        if keys.count > 4 {
            keys = Array(keys.prefix(4))
        }

        pinyinCacheLock.lock()
        if pinyinKeyCache.count > 2048 {
            pinyinKeyCache.removeAll(keepingCapacity: true)
        }
        pinyinKeyCache[ch] = keys
        pinyinCacheLock.unlock()
        return keys
    }

    // MARK: - Live Voice Typing Enqueue Hooks (Safe from any thread / pacerQueue)

    func enqueueTypedText(_ text: String) {
        guard CatSettings.shared.isEnabled, CatSettings.shared.enableVoiceTyping else { return }
        let steps = Self.decomposeToKeystrokes(text)
        guard !steps.isEmpty else { return }

        queueLock.lock()
        // Prevent unbounded backlog if an entire 500-char paragraph is pasted at once:
        // cap queue at 42 crisp keystrokes (~420ms exhilarating stenographer burst!)
        let maxQueue = 42
        if pendingSteps.count + steps.count > maxQueue {
            let allowed = max(0, maxQueue - pendingSteps.count)
            if allowed > 0 {
                pendingSteps.append(contentsOf: steps.suffix(allowed))
            }
        } else {
            pendingSteps.append(contentsOf: steps)
        }
        let needStart = !isPacerRunning
        if needStart { isPacerRunning = true }
        queueLock.unlock()

        if needStart {
            DispatchQueue.main.async { [weak self] in
                self?.startKeyChoreographyTimer()
            }
        }
    }

    func enqueueBackspaces(_ count: Int) {
        guard count > 0, CatSettings.shared.isEnabled, CatSettings.shared.enableVoiceTyping else { return }
        let clamped = min(count, 8)
        let steps = (0..<clamped).map { _ in KeyStep(key: .backspace, spokenCharLabel: "⌫") }

        queueLock.lock()
        pendingSteps.append(contentsOf: steps)
        let needStart = !isPacerRunning
        if needStart { isPacerRunning = true }
        queueLock.unlock()

        if needStart {
            DispatchQueue.main.async { [weak self] in
                self?.startKeyChoreographyTimer()
            }
        }
    }

    func playDemoVoiceBurst() {
        let sample = "今天下午三点产品评审，黑猫帮我把语音敲成文字！"
        enqueueTypedText(sample)
    }

    // MARK: - Main-Thread 60Hz Choreography Pacer

    private func startKeyChoreographyTimer() {
        pacerTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(18), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.tickChoreographyOnMain()
            }
        }
        pacerTimer = timer
        timer.resume()
    }

    private func stopKeyChoreographyTimer() {
        pacerTimer?.cancel()
        pacerTimer = nil
        queueLock.lock()
        isPacerRunning = false
        queueLock.unlock()
    }

    @MainActor
    private func tickChoreographyOnMain() {
        let now = CACurrentMediaTime()
        guard let physics = PetCompanionController.sharedIfInitialized?.physics else {
            queueLock.lock()
            pendingSteps.removeAll()
            isPacerRunning = false
            queueLock.unlock()
            stopKeyChoreographyTimer()
            return
        }

        // 1. Release any virtual keys whose 62ms overlap hold window expired
        for (k, deadline) in activeReleaseDeadlines where now >= deadline {
            activeReleaseDeadlines.removeValue(forKey: k)
            physics.setVirtualKeyState(k, isDown: false)
        }

        // 2. Pop 1 (or 2 under heavy burst) next key steps so paws + 3rd foot dance dynamically!
        queueLock.lock()
        let backlog = pendingSteps.count
        let popCount = backlog > 18 ? 2 : (backlog > 0 ? 1 : 0)
        var popped: [KeyStep] = []
        if popCount > 0 {
            popped = Array(pendingSteps.prefix(popCount))
            pendingSteps.removeFirst(popCount)
        }
        let queueEmptyAfterPop = pendingSteps.isEmpty
        queueLock.unlock()

        if !popped.isEmpty {
            let badgeMode = CatSettings.shared.voiceBadgeMode
            for step in popped {
                // If pressing the exact same key again while still held, briefly release so paw re-slaps!
                if activeReleaseDeadlines[step.key] != nil {
                    physics.setVirtualKeyState(step.key, isDown: false)
                }
                let suppressBadge: Bool
                let customLabel: String?
                switch badgeMode {
                case .mechanicalKey:
                    suppressBadge = false
                    customLabel = nil // Uses authentic mechanical keycap label ("J", "I", "N", "␣")!
                case .spokenChar:
                    suppressBadge = step.spokenCharLabel.isEmpty
                    customLabel = step.spokenCharLabel
                case .off:
                    suppressBadge = true
                    customLabel = nil
                }
                physics.setVirtualKeyState(
                    step.key,
                    isDown: true,
                    customBadgeLabel: customLabel,
                    suppressBadge: suppressBadge
                )
                // Hold 64ms (~3.5 ticks) so consecutive keys overlap -> activates dual-paw + 3rd hind foot kick!
                activeReleaseDeadlines[step.key] = now + 0.064
                incrementVoiceStats()
            }
            PetCompanionController.sharedIfInitialized?.wakeToActive(immediateRedraw: true)
        }

        if queueEmptyAfterPop && activeReleaseDeadlines.isEmpty {
            physics.clearVirtualKeys()
            stopKeyChoreographyTimer()
        }
    }

    // MARK: - Daily Voice-Typed Keystroke Stats

    private func loadTodayVoiceStats() {
        let today = Self.dayFormatter.string(from: Date())
        statsDay = today
        let savedDay = UserDefaults.standard.string(forKey: "TypeZero.Pet.VoiceStatsDay") ?? ""
        if savedDay == today {
            todayVoiceKeystrokes = UserDefaults.standard.integer(forKey: "TypeZero.Pet.TodayVoiceKeys")
        } else {
            todayVoiceKeystrokes = 0
            UserDefaults.standard.set(today, forKey: "TypeZero.Pet.VoiceStatsDay")
            UserDefaults.standard.set(0, forKey: "TypeZero.Pet.TodayVoiceKeys")
        }
    }

    private func incrementVoiceStats() {
        let today = Self.dayFormatter.string(from: Date())
        if today != statsDay {
            statsDay = today
            todayVoiceKeystrokes = 0
            UserDefaults.standard.set(today, forKey: "TypeZero.Pet.VoiceStatsDay")
        }
        todayVoiceKeystrokes += 1
        if todayVoiceKeystrokes % 6 == 0 {
            UserDefaults.standard.set(todayVoiceKeystrokes, forKey: "TypeZero.Pet.TodayVoiceKeys")
        }
        onVoiceStatsUpdated?(todayVoiceKeystrokes)
    }

    func flushStats() {
        UserDefaults.standard.set(statsDay, forKey: "TypeZero.Pet.VoiceStatsDay")
        UserDefaults.standard.set(todayVoiceKeystrokes, forKey: "TypeZero.Pet.TodayVoiceKeys")
    }
}
