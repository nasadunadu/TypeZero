import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

public enum AppToneProfile: String {
    case instantMessaging = "即时聊天"
    case emailAndFormalDoc = "邮件与正式文档"
    case aiPromptAndNotes = "AI提问与笔记"
    case shellTerminal = "命令行终端"
}

public struct ActiveScreenContext {
    public let appName: String
    public let bundleID: String
    public let windowTitle: String
    public let selectedText: String
    public let precedingText: String
    public let hasFocusedTextInput: Bool

    public var isStrictShellTerminal: Bool {
        let lower = bundleID.lowercased() + " " + appName.lowercased()
        return ["apple.terminal", "iterm", "warp", "ghostty", "alacritty", "kitty"]
            .contains { lower.contains($0) }
    }

    public var isCodeOrTerminal: Bool {
        let lower = bundleID.lowercased() + " " + appName.lowercased()
        return ["terminal", "iterm", "warp", "ghostty", "xcode", "cursor", "vscode", "code", "zed", "antigravity"]
            .contains { lower.contains($0) }
    }

    public var isInstantMessaging: Bool {
        let lower = bundleID.lowercased() + " " + appName.lowercased()
        return ["telegram", "slack", "discord", "lark", "feishu", "messages", "whatsapp", "dingtalk", "wechat", "xinwechat", "微信", "qq"]
            .contains { lower.contains($0) }
    }

    public var isEmailOrFormalDoc: Bool {
        let lower = bundleID.lowercased() + " " + appName.lowercased() + " " + windowTitle.lowercased()
        return ["apple.mail", "outlook", "spark", "mimestream", "gmail", "word", "pages", "docs.google"]
            .contains { lower.contains($0) }
    }

    /// P1: App-Aware Tone Matrix routing
    public var toneProfile: AppToneProfile {
        if isStrictShellTerminal { return .shellTerminal }
        if isInstantMessaging { return .instantMessaging }
        if isEmailOrFormalDoc { return .emailAndFormalDoc }
        return .aiPromptAndNotes
    }

    public static let empty = ActiveScreenContext(
        appName: "",
        bundleID: "",
        windowTitle: "",
        selectedText: "",
        precedingText: "",
        hasFocusedTextInput: true
    )
}

/// Doubao-grade Adaptive Cruise Typewriter + Prefix-Preserving Zero-Flicker SSE Morph Session:
/// - Runs character emission on a dedicated `.userInteractive` real-time serial queue (100% isolated from `@MainActor` UI!).
/// - Uses Phase-Locked Adaptive Cruise Pacing (`11ms–42ms` dynamic interval based on live queue depth) so characters glide out continuously with ZERO burst-and-freeze stutter!
/// - Preserves matching leading characters during SSE LLM polish so unchanged prefixes NEVER flicker or re-type!
public final class LiveInputSession: @unchecked Sendable {
    private static let pacerQueue = DispatchQueue(label: "io.github.typezero.typewriter.pacer", qos: .userInteractive)

    private var context: ActiveScreenContext
    /// Characters actually emitted to the OS input box so far
    private var emittedText: String = ""
    /// Characters confirmed by Local Agreement, waiting in the smooth adaptive cruise queue
    private var targetConfirmedText: String = ""
    private var previousHypothesis: String = ""
    private var pacerTimer: DispatchSourceTimer?
    private var lastEmitUptimeNs: UInt64 = 0
    private let stateLock = NSLock()

    // Prefix-preserving SSE streaming state
    private var draftBeforeSSE: String = ""
    private var sseAccumulated: String = ""
    private var sseHasDiverged: Bool = false
    /// Buffers up to 5 chars immediately following a '\n' so we can detect & skip Markdown editor auto-inserted `2. ` / `- ` markers!
    private var postNewlineGuardBuffer: String? = nil

    private static let unstableTrailingPunctuation = CharacterSet(charactersIn: "。，、！？；：.,!?;:… ")

    public init(context: ActiveScreenContext) {
        self.context = context
        startSmoothTypewriterPacer()
    }

    public func updateContext(_ newContext: ActiveScreenContext) {
        stateLock.lock()
        self.context = newContext
        stateLock.unlock()
    }

    deinit {
        stopPacer()
    }

    public var currentText: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return emittedText
    }

    /// P3 Prefix-Preserving SSE Streaming Polish:
    /// Flushes any pending 1–2 characters in the typewriter queue, snapshots `draftBeforeSSE`,
    /// and prepares to keep unchanged prefix characters untouched on screen!
    @discardableResult
    public func prepareForSSEPolishStream() -> Bool {
        stopPacer()
        stateLock.lock()
        let ctx = self.context
        if targetConfirmedText.count > emittedText.count && targetConfirmedText.hasPrefix(emittedText) {
            let rem = String(targetConfirmedText.dropFirst(emittedText.count))
            emittedText = targetConfirmedText
            stateLock.unlock()
            ContextInjector.typeCleanUnicode(rem)
            stateLock.lock()
        }
        draftBeforeSSE = emittedText
        sseAccumulated = ""
        sseHasDiverged = false
        postNewlineGuardBuffer = nil
        stateLock.unlock()

        guard ContextInjector.isAllowedTarget(bundleID: ctx.bundleID, appName: ctx.appName),
              AXIsProcessTrusted() else {
            return false
        }
        if !ctx.hasFocusedTextInput && !ContextInjector.isLikelyEditableFocusNow() {
            return false
        }
        return true
    }

    public func consumeSSEChunk(_ delta: String) {
        guard !delta.isEmpty else { return }
        stateLock.lock()
        sseAccumulated.append(delta)

        if sseHasDiverged {
            emittedText.append(delta)
            targetConfirmedText = emittedText
            stateLock.unlock()
            emitSSEDeltaGuardingAutoList(delta)
            return
        }

        // Still matching `draftBeforeSSE` prefix? Keep screen rock-steady with ZERO backspaces!
        if draftBeforeSSE.hasPrefix(sseAccumulated) {
            stateLock.unlock()
            return
        }

        // First divergence point reached! Keep common prefix intact, only backspace the changed tail!
        sseHasDiverged = true
        let dChars = Array(draftBeforeSSE)
        let sChars = Array(sseAccumulated)
        var common = 0
        let lim = min(dChars.count, sChars.count)
        while common < lim && dChars[common] == sChars[common] {
            common += 1
        }

        let backspacesNeeded = dChars.count - common
        let newSuffix = common < sChars.count ? String(sChars[common...]) : ""
        emittedText = sseAccumulated
        targetConfirmedText = sseAccumulated
        stateLock.unlock()

        if backspacesNeeded > 0 {
            if common == 0,
               backspacesNeeded > 14,
               let box = ContextInjector.readCurrentFocusedValue(),
               box.trimmingCharacters(in: .whitespacesAndNewlines) == draftBeforeSSE.trimmingCharacters(in: .whitespacesAndNewlines) {
                ContextInjector.sendSelectAllEvent()
                usleep(4_000)
                if newSuffix.isEmpty {
                    ContextInjector.sendCleanBackspaces(count: 1)
                }
            } else {
                ContextInjector.sendCleanBackspaces(count: backspacesNeeded)
                if !newSuffix.isEmpty {
                    usleep(4_000)
                }
            }
        }
        if !newSuffix.isEmpty {
            emitSSEDeltaGuardingAutoList(newSuffix)
        }
    }

    /// Streams SSE text while preventing Markdown-aware editors (Antigravity, Notion, Feishu, Obsidian)
    /// from producing `2. 2. ` or `- - ` when `Shift+Return` auto-inserts the next list marker!
    private func emitSSEDeltaGuardingAutoList(_ text: String) {
        for ch in text {
            if ch == "\n" {
                flushPostNewlineGuardBufferIfAny()
                ContextInjector.sendSoftNewlineShiftReturn()
                stateLock.lock()
                postNewlineGuardBuffer = ""
                stateLock.unlock()
                continue
            }

            stateLock.lock()
            let hasGuard = (postNewlineGuardBuffer != nil)
            if hasGuard {
                postNewlineGuardBuffer?.append(ch)
                let buf = postNewlineGuardBuffer ?? ""
                // Wait up to 5 chars (e.g. "12. X" or "2. 准") to see if a list prefix formed
                let mightStillBeBuildingPrefix = buf.count < 5 && buf.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" || $0 == "*" || $0 == "•" || $0 == " " })
                if mightStillBeBuildingPrefix {
                    stateLock.unlock()
                    continue
                }
                postNewlineGuardBuffer = nil
                stateLock.unlock()
                ContextInjector.typePostNewlineSkippingEditorAutoMarker(buf)
            } else {
                stateLock.unlock()
                ContextInjector.typeCleanUnicode(String(ch))
            }
        }
    }

    private func flushPostNewlineGuardBufferIfAny() {
        stateLock.lock()
        let pending = postNewlineGuardBuffer
        postNewlineGuardBuffer = nil
        stateLock.unlock()
        if let pending, !pending.isEmpty {
            ContextInjector.typePostNewlineSkippingEditorAutoMarker(pending)
        }
    }

    /// Reconciles final post-formatted text AND cleans up any residual duplicated list prefixes (`2. 2. ` -> `2. `).
    public func finishSSEPolishStream(with finalFormatted: String) {
        flushPostNewlineGuardBufferIfAny()

        stateLock.lock()
        let currentOnScreen = sseHasDiverged ? emittedText : draftBeforeSSE
        emittedText = finalFormatted
        targetConfirmedText = finalFormatted
        stateLock.unlock()

        if currentOnScreen != finalFormatted {
            ContextInjector.applyCleanUnicodeDelta(from: currentOnScreen, to: finalFormatted)
        }

        // Final DOM truth verification for multi-line lists: if an editor asynchronously inserted `2. 2. `, snap it clean!
        if finalFormatted.contains("\n") {
            usleep(12_000)
            if let actualBox = ContextInjector.readCurrentFocusedValue(),
               ContextInjector.containsDuplicatedListMarker(in: actualBox, expected: finalFormatted) {
                let collapsed = ContextInjector.collapseDuplicatedListMarkers(actualBox)
                if collapsed.trimmingCharacters(in: .whitespacesAndNewlines) == finalFormatted.trimmingCharacters(in: .whitespacesAndNewlines) {
                    ContextInjector.sendSelectAllEvent()
                    usleep(6_000)
                    ContextInjector.pasteViaClipboardPreservingSnapshot(finalFormatted)
                }
            }
        }
    }

    /// Starts a 6ms high-refresh real-time clock on dedicated `pacerQueue` driving the ProMotion Single-Char Pacer.
    private func startSmoothTypewriterPacer() {
        let timer = DispatchSource.makeTimerSource(queue: Self.pacerQueue)
        timer.schedule(deadline: .now() + .milliseconds(4), repeating: .milliseconds(6), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.tickAdaptiveCruiseStep()
        }
        self.pacerTimer = timer
        timer.resume()
    }

    private func stopPacer() {
        pacerTimer?.cancel()
        pacerTimer = nil
    }

    private func tickAdaptiveCruiseStep() {
        guard AXIsProcessTrusted() else { return }

        stateLock.lock()
        // Doubao iOS-style Live Tail Revision: if Seed-ASR 2.0 revised the last 1–6 chars near the cursor
        // (e.g. "星合" -> "星河", "期末" -> "契合"), snap back those <=6 chars in <1ms on this serial queue!
        if !targetConfirmedText.hasPrefix(emittedText) {
            let eChars = Array(emittedText)
            let tChars = Array(targetConfirmedText)
            var common = 0
            let lim = min(eChars.count, tChars.count)
            while common < lim && eChars[common] == tChars[common] {
                common += 1
            }
            let eraseCount = eChars.count - common
            if eraseCount > 0 && eraseCount <= 6 && !emittedText.suffix(eraseCount).contains("\n") {
                emittedText = String(eChars.prefix(common))
                lastEmitUptimeNs = DispatchTime.now().uptimeNanoseconds
                stateLock.unlock()
                ContextInjector.sendCleanBackspaces(count: eraseCount)
                return
            }
            stateLock.unlock()
            return
        }

        let emittedCount = emittedText.count
        let targetCount = targetConfirmedText.count
        guard targetCount > emittedCount else {
            stateLock.unlock()
            return
        }

        let backlog = targetCount - emittedCount
        let nowNs = DispatchTime.now().uptimeNanoseconds

        // Doubao iOS ProMotion Single-Glyph Curve (11ms–18ms per character, 0ms instant first char):
        // Eliminates the old 58ms slow-motion brake while preserving crisp 1-by-1 character popping!
        let requiredIntervalMs: UInt64 = {
            if backlog == 1 { return 18 }
            if backlog == 2 { return 14 }
            if backlog <= 5 { return 11 }
            return 8
        }()

        if lastEmitUptimeNs > 0 && (nowNs - lastEmitUptimeNs) < requiredIntervalMs * 1_000_000 {
            stateLock.unlock()
            return
        }

        // Strict single-character emission for CJK so every single character visibly pops out one-by-one!
        let stepCount: Int = {
            if backlog > 18 { return 2 }
            let nextChar = targetConfirmedText[targetConfirmedText.index(targetConfirmedText.startIndex, offsetBy: emittedCount)]
            if nextChar.isASCII && backlog >= 3 { return 2 }
            return 1
        }()

        let startIdx = targetConfirmedText.index(targetConfirmedText.startIndex, offsetBy: emittedCount)
        let endIdx = targetConfirmedText.index(startIdx, offsetBy: min(stepCount, backlog))
        let chunk = String(targetConfirmedText[startIdx..<endIdx])
        emittedText.append(chunk)
        lastEmitUptimeNs = nowNs
        stateLock.unlock()

        ContextInjector.typeCleanUnicode(chunk)
    }

    /// Updates the confirmed target string:
    /// - Cloud `Seed-ASR 2.0` (`isCloudStream == true`): zero `dropLast(1)` lag + live <=6-char tail self-correction + 0ms instant first-char fire!
    /// - Local offline `SenseVoice` (`isCloudStream == false`): uses `computeLocalAgreement` anti-flicker guard.
    @discardableResult
    public func updateLiveText(_ rawHypothesis: String, flushTrailingChar: Bool = false, isCloudStream: Bool = false) -> Bool {
        stateLock.lock()
        let ctx = self.context
        let isStartOfUtterance = targetConfirmedText.isEmpty
        stateLock.unlock()

        guard ContextInjector.isAllowedTarget(bundleID: ctx.bundleID, appName: ctx.appName),
              AXIsProcessTrusted() else {
            return false
        }

        let trimmedHypothesis = Self.stripTrailingPunctuation(rawHypothesis)
        guard !trimmedHypothesis.isEmpty else { return true }

        let stableCandidate: String
        if isCloudStream {
            stableCandidate = trimmedHypothesis
        } else {
            stableCandidate = Self.computeLocalAgreement(
                prev: previousHypothesis,
                curr: trimmedHypothesis,
                fastFirstSyllable: isStartOfUtterance,
                flushTrailingChar: flushTrailingChar
            )
        }
        previousHypothesis = trimmedHypothesis

        var didAdvanceOrRevise = false
        stateLock.lock()
        if isCloudStream {
            if stableCandidate.hasPrefix(targetConfirmedText) {
                if stableCandidate.count > targetConfirmedText.count {
                    targetConfirmedText = stableCandidate
                    didAdvanceOrRevise = true
                }
            } else {
                // Check if divergence from currently `emittedText` is strictly within the last <= 6 characters near cursor
                let eChars = Array(emittedText)
                let sChars = Array(stableCandidate)
                var common = 0
                let lim = min(eChars.count, sChars.count)
                while common < lim && eChars[common] == sChars[common] {
                    common += 1
                }
                let eraseFromEmitted = eChars.count - common
                if eraseFromEmitted <= 6 && sChars.count >= common + 1 && !stableCandidate.contains("\n") {
                    targetConfirmedText = stableCandidate
                    didAdvanceOrRevise = true
                } else if let continuation = Self.extractNewContinuationSuffix(alreadyConfirmed: targetConfirmedText, newStable: stableCandidate),
                          !continuation.isEmpty {
                    targetConfirmedText.append(continuation)
                    didAdvanceOrRevise = true
                }
            }
        } else {
            if let continuation = Self.extractNewContinuationSuffix(alreadyConfirmed: targetConfirmedText, newStable: stableCandidate),
               !continuation.isEmpty {
                targetConfirmedText.append(continuation)
                didAdvanceOrRevise = true
            }
        }
        stateLock.unlock()

        // Fire first character IMMEDIATELY (`0.0ms` wait) on `pacerQueue` instead of waiting for next timer tick!
        if didAdvanceOrRevise {
            Self.pacerQueue.async { [weak self] in
                self?.tickAdaptiveCruiseStep()
            }
        }
        return true
    }

    /// Pass 2 (On stop tap): Stops pacer, flushes any remaining confirmed chars, and applies final text cleanly.
    /// P4 Safety Vault: Returns `false` if no editable text field accepted the input, keeping `finalText` safely in NSPasteboard!
    @discardableResult
    public func finalizeAfterKeyRelease(with finalText: String) -> Bool {
        stopPacer()
        guard ContextInjector.isAllowedTarget(bundleID: context.bundleID, appName: context.appName),
              AXIsProcessTrusted() else {
            ContextInjector.saveToSafetyClipboard(finalText)
            return false
        }

        // If user never clicked into an input field (e.g. Finder or desktop focused), save directly to Safety Vault clipboard!
        if !ContextInjector.isLikelyEditableFocusNow() && !context.hasFocusedTextInput {
            ContextInjector.saveToSafetyClipboard(finalText)
            return false
        }

        stateLock.lock()
        let alreadyEmitted = emittedText
        stateLock.unlock()

        if alreadyEmitted.isEmpty {
            ContextInjector.pasteViaClipboardPreservingSnapshot(finalText)
            stateLock.lock()
            emittedText = finalText
            targetConfirmedText = finalText
            stateLock.unlock()
            return true
        }

        if let actualValue = ContextInjector.readCurrentFocusedValue(),
           !actualValue.contains(alreadyEmitted) {
            ContextInjector.pasteViaClipboardPreservingSnapshot(finalText)
            stateLock.lock()
            emittedText = finalText
            targetConfirmedText = finalText
            stateLock.unlock()
            return true
        }

        if finalText == alreadyEmitted {
            return true
        }

        if finalText.hasPrefix(alreadyEmitted) {
            let tail = String(finalText.dropFirst(alreadyEmitted.count))
            if !tail.contains("\n") {
                ContextInjector.typeCleanUnicode(tail)
                stateLock.lock()
                emittedText = finalText
                targetConfirmedText = finalText
                stateLock.unlock()
                return true
            }
        }

        let currentBoxText = ContextInjector.readCurrentFocusedValue()
        if let box = currentBoxText,
           box.trimmingCharacters(in: .whitespacesAndNewlines) == alreadyEmitted.trimmingCharacters(in: .whitespacesAndNewlines) {
            ContextInjector.sendSelectAllEvent()
        } else {
            ContextInjector.selectLeftCharacters(count: alreadyEmitted.count)
        }
        usleep(12_000)
        ContextInjector.pasteViaClipboardPreservingSnapshot(finalText)
        stateLock.lock()
        emittedText = finalText
        targetConfirmedText = finalText
        stateLock.unlock()
        return true
    }

    private static func stripTrailingPunctuation(_ s: String) -> String {
        var scalars = s.unicodeScalars
        while let last = scalars.last, unstableTrailingPunctuation.contains(last) {
            scalars.removeLast()
        }
        return String(scalars)
    }

    private static func computeLocalAgreement(
        prev: String,
        curr: String,
        fastFirstSyllable: Bool = false,
        flushTrailingChar: Bool = false
    ) -> String {
        let pChars = Array(prev)
        let cChars = Array(curr)
        guard !cChars.isEmpty else { return "" }

        // On breath micro-pause (>=180ms) or VAD segment seal, immediately release even the final trailing character!
        if flushTrailingChar {
            return curr
        }

        // First-Syllable Fast Icebreaker: on the very first words spoken (~140ms in),
        // emit leading characters immediately without waiting an extra ASR cycle!
        if fastFirstSyllable && cChars.count >= 2 {
            return String(cChars.dropLast(1))
        }

        var common = 0
        let limit = min(pChars.count, cChars.count)
        while common < limit && pChars[common] == cChars[common] {
            common += 1
        }

        // Anti-Clumping Syllable Progression:
        // If user is actively speaking (`cChars.count > pChars.count`) and SenseVoice merely flipped a homophone
        // 1–2 chars back (e.g. "的" -> "得"), do NOT stall and clump 4 chars on the next frame — advance smoothly up to `cChars.count - 1`!
        if cChars.count > pChars.count && cChars.count >= 3 {
            return String(cChars.dropLast(1))
        }

        if common < limit && cChars.count >= 4 && pChars.count >= 3 {
            let pTail = Self.alphanumericOnly(String(pChars.suffix(4))).suffix(2)
            let cBody = Self.alphanumericOnly(String(cChars.dropLast(1)))
            if !pTail.isEmpty && cBody.hasSuffix(pTail) {
                return String(cChars.dropLast(1))
            }
        }
        let safeLen = cChars.count > 2 ? min(common, max(0, cChars.count - 1)) : common
        guard safeLen > 0 else { return "" }
        return String(cChars[0..<safeLen])
    }

    /// Prevents mid-sentence punctuation/homophone revisions in earlier clauses from ever freezing the typewriter stream!
    /// Finds where `alreadyConfirmed` ends inside `newStable` using tail-anchor matching (ignoring punctuation shifts) and returns the newly spoken suffix.
    private static func extractNewContinuationSuffix(alreadyConfirmed: String, newStable: String) -> String? {
        guard !newStable.isEmpty else { return nil }
        if alreadyConfirmed.isEmpty { return newStable }

        // Fast path 1: exact prefix match
        if newStable.hasPrefix(alreadyConfirmed) {
            let diff = String(newStable.dropFirst(alreadyConfirmed.count))
            return diff.isEmpty ? nil : diff
        }

        // Fast path 2: Punctuation-insensitive character alignment!
        // SenseVoice frequently changes an earlier "，" to "。" or inserts/removes a comma two sentences ago as context grows.
        let confirmedCore = Self.alphanumericOnly(alreadyConfirmed)
        let newChars = Array(newStable)

        // Map each character index in `newStable` to how many non-punctuation core characters have been seen up to it
        var coreSeen = 0
        var coreMatchIndex: Int? = nil
        let targetCoreCount = confirmedCore.count
        guard targetCoreCount > 0 else { return nil }

        // First try exact 3-char tail anchor search near the end for supreme accuracy on slight word edits
        let anchorLen = min(3, confirmedCore.count)
        let tailAnchor = String(confirmedCore.suffix(anchorLen))

        var runningCore = ""
        var coreEndToRawIdx: [Int: Int] = [:]
        for (idx, ch) in newChars.enumerated() {
            if Self.isCoreChar(ch) {
                runningCore.append(ch)
                coreSeen += 1
                coreEndToRawIdx[coreSeen] = idx
            }
        }

        // Require `newStable` to actually have MORE spoken content than what we already confirmed
        guard coreSeen > targetCoreCount else { return nil }

        // Search for `tailAnchor` near `targetCoreCount` (+/- 4 chars tolerance) in `runningCore`
        let rChars = Array(runningCore)
        let aChars = Array(tailAnchor)
        let minEnd = max(aChars.count, targetCoreCount - 4)
        let maxEnd = min(rChars.count - 1, targetCoreCount + 4)

        if minEnd <= maxEnd {
            for candidateEnd in stride(from: maxEnd, through: minEnd, by: -1) {
                let slice = Array(rChars[(candidateEnd - aChars.count)..<candidateEnd])
                if slice == aChars, let rawIdx = coreEndToRawIdx[candidateEnd] {
                    coreMatchIndex = rawIdx
                    break
                }
            }
        }

        // Fallback: align directly by core spoken syllable count if even the anchor had a 1-char homophone flip
        if coreMatchIndex == nil, let fallbackRawIdx = coreEndToRawIdx[targetCoreCount] {
            coreMatchIndex = fallbackRawIdx
        }

        guard let cutIdx = coreMatchIndex, cutIdx + 1 < newChars.count else { return nil }
        let suffix = String(newChars[(cutIdx + 1)...])
        return suffix.isEmpty ? nil : suffix
    }

    private static func isCoreChar(_ c: Character) -> Bool {
        for scalar in c.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                return true
            }
        }
        return false
    }

    private static func alphanumericOnly(_ s: String) -> String {
        return String(s.filter { isCoreChar($0) })
    }
}

public enum ContextInjector {
    public static func isAccessibilityTrusted(promptIfNeeded: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func isAllowedTarget(bundleID: String, appName: String) -> Bool {
        // Universal macOS dictation input: allow typing & pasting into all user-focused apps
        return true
    }

    private static func asAXElement(_ ref: CFTypeRef?) -> AXUIElement? {
        guard let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(ref, to: AXUIElement.self)
    }

    private static func asAXValue(_ ref: CFTypeRef?) -> AXValue? {
        guard let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        return unsafeBitCast(ref, to: AXValue.self)
    }

    /// Reads the live string value of the currently focused input box (works across Cocoa & Chromium/Electron)
    public static func readCurrentFocusedValue() -> String? {
        guard AXIsProcessTrusted(),
              let frontApp = NSWorkspace.shared.frontmostApplication,
              isAllowedTarget(bundleID: frontApp.bundleIdentifier ?? "", appName: frontApp.localizedName ?? "") else {
            return nil
        }
        let appElem = AXUIElementCreateApplication(frontApp.processIdentifier)
        AXUIElementSetMessagingTimeout(appElem, 0.035)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let elem = asAXElement(focusedRef) else {
            return nil
        }
        var valRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valRef) == .success,
           let str = valRef as? String {
            return str
        }
        return nil
    }

    private static let manualAXLock = NSLock()
    private static var manualAXEnabledPIDs: Set<pid_t> = []

    /// Enables Chromium/Electron manual accessibility tree once per process so apps like Feishu,
    /// Cursor, Notion, and Chrome expose accurate text-input & caret AX geometry.
    private static func enableManualAccessibilityIfNeeded(appElem: AXUIElement, pid: pid_t) {
        manualAXLock.lock()
        let alreadyEnabled = manualAXEnabledPIDs.contains(pid)
        if !alreadyEnabled {
            if manualAXEnabledPIDs.count > 64 { manualAXEnabledPIDs.removeAll() }
            manualAXEnabledPIDs.insert(pid)
        }
        manualAXLock.unlock()
        if !alreadyEnabled {
            _ = AXUIElementSetAttributeValue(appElem, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
    }

    private static func axElementQuartzRect(_ elem: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(elem, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(elem, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let pVal = asAXValue(posRef),
              let sVal = asAXValue(sizeRef) else {
            return nil
        }
        var pt = CGPoint.zero
        var sz = CGSize.zero
        guard AXValueGetValue(pVal, .cgPoint, &pt),
              AXValueGetValue(sVal, .cgSize, &sz),
              sz.width > 1, sz.height > 1 else {
            return nil
        }
        return CGRect(origin: pt, size: sz)
    }

    /// Converts a Quartz screen rect (top-left origin) into a Cocoa origin for the floating pill,
    /// placing it directly beneath the anchor rect (or flipping cleanly above if near the Dock/bottom).
    private static func anchorPillCocoaOrigin(forQuartzRect qRect: CGRect, pillSize: CGSize, gap: CGFloat) -> CGPoint? {
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height
        let cocoaBottomY = primaryHeight - qRect.maxY
        let cocoaTopY = primaryHeight - qRect.minY
        let anchorCenter = CGPoint(x: qRect.midX, y: (cocoaBottomY + cocoaTopY) * 0.5)

        let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(anchorCenter) }) ?? NSScreen.main ?? primaryScreen
        let vf = activeScreen.visibleFrame

        let rawX = qRect.midX - pillSize.width * 0.5
        let belowY = cocoaBottomY - pillSize.height - gap
        let aboveY = cocoaTopY + gap
        let preferredY = (belowY >= vf.minY + 12) ? belowY : aboveY

        let clampedX = max(vf.minX + 8, min(vf.maxX - pillSize.width - 8, rawX))
        let clampedY = max(vf.minY + 12, min(vf.maxY - pillSize.height - 12, preferredY))
        return CGPoint(x: clampedX, y: clampedY)
    }

    /// Queries the active text caret or focused input box coordinates using a 3-tier anchor cascade:
    ///   Tier 1: Exact AX text caret bounds (`kAXBoundsForRange`)
    ///   Tier 2: Focused text-input element frame (`kAXPosition` + `kAXSize`) for Electron/Chromium apps (Feishu, Cursor, Chrome)
    ///   Tier 3: Mouse pointer inside the focused window (near where the user clicked to type), or focused window bottom-center
    public static func getFocusedCaretCocoaOrigin(pillSize: CGSize) -> CGPoint? {
        guard AXIsProcessTrusted(),
              let frontApp = NSWorkspace.shared.frontmostApplication,
              isAllowedTarget(bundleID: frontApp.bundleIdentifier ?? "", appName: frontApp.localizedName ?? "") else {
            return nil
        }

        let pid = frontApp.processIdentifier
        let appElem = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElem, 0.080)
        enableManualAccessibilityIfNeeded(appElem: appElem, pid: pid)

        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
           let elem = asAXElement(focusedRef) {
            AXUIElementSetMessagingTimeout(elem, 0.080)

            // Tier 1: Exact caret bounds
            var rangeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(elem, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
               let rangeVal = rangeRef {
                var boundsRef: CFTypeRef?
                if AXUIElementCopyParameterizedAttributeValue(
                    elem,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    rangeVal,
                    &boundsRef
                ) == .success, let bVal = asAXValue(boundsRef) {
                    var quartzRect = CGRect.zero
                    if AXValueGetValue(bVal, .cgRect, &quartzRect),
                       quartzRect.height >= 4, quartzRect.height <= 220,
                       (quartzRect.origin.x != 0 || quartzRect.origin.y != 0),
                       let origin = anchorPillCocoaOrigin(forQuartzRect: quartzRect, pillSize: pillSize, gap: 10) {
                        return origin
                    }
                }
            }

            // Tier 2: Focused input element box (ideal for Electron/Feishu/Chrome/Cursor compose boxes)
            if let elemRect = axElementQuartzRect(elem),
               elemRect.width >= 40, elemRect.height >= 16, elemRect.height <= 560,
               let origin = anchorPillCocoaOrigin(forQuartzRect: elemRect, pillSize: pillSize, gap: 8) {
                return origin
            }
        }

        // Tier 3: Focused window + mouse proximity fallback (prevents dropping far away to the Dock)
        var winRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
           let winElem = asAXElement(winRef),
           let winQuartz = axElementQuartzRect(winElem),
           let primaryScreen = NSScreen.screens.first {
            let primaryHeight = primaryScreen.frame.height
            let winCocoa = CGRect(
                x: winQuartz.origin.x,
                y: primaryHeight - winQuartz.maxY,
                width: winQuartz.width,
                height: winQuartz.height
            )
            let mouseCocoa = NSEvent.mouseLocation
            if winCocoa.contains(mouseCocoa) {
                let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseCocoa) }) ?? NSScreen.main ?? primaryScreen
                let vf = activeScreen.visibleFrame
                let rawX = mouseCocoa.x - pillSize.width * 0.5
                let belowY = mouseCocoa.y - pillSize.height - 18
                let aboveY = mouseCocoa.y + 18
                let preferredY = (belowY >= vf.minY + 12) ? belowY : aboveY
                return CGPoint(
                    x: max(vf.minX + 8, min(vf.maxX - pillSize.width - 8, rawX)),
                    y: max(vf.minY + 12, min(vf.maxY - pillSize.height - 12, preferredY))
                )
            }
            if let origin = anchorPillCocoaOrigin(forQuartzRect: winQuartz, pillSize: pillSize, gap: 12) {
                return origin
            }
        }

        return nil
    }

    /// Captures frontmost app name, window title, and any highlighted text (for Selected-Text Rewrite mode).
    public static func captureCurrentContext() -> ActiveScreenContext {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "Unknown"
        let bundleID = frontApp?.bundleIdentifier ?? ""

        guard isAllowedTarget(bundleID: bundleID, appName: appName),
              AXIsProcessTrusted(),
              let pid = frontApp?.processIdentifier else {
            return ActiveScreenContext(appName: appName, bundleID: bundleID, windowTitle: "", selectedText: "", precedingText: "", hasFocusedTextInput: false)
        }

        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.035)

        var windowTitle = ""
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let win = asAXElement(focusedWindow) {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success,
               let titleStr = titleRef as? String {
                windowTitle = String(titleStr.prefix(100))
            }
        }

        var selectedText = ""
        var precedingText = ""
        var editableFocus = true
        if bundleID == "com.apple.finder" {
            editableFocus = false
        }

        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
           let elem = asAXElement(focusedRef) {
            var selectedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(elem, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
               let selStr = selectedRef as? String {
                selectedText = String(selStr.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200))
            }
            var valRef: CFTypeRef?
            if selectedText.isEmpty,
               AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valRef) == .success,
               let fullVal = valRef as? String,
               !fullVal.isEmpty {
                precedingText = String(fullVal.suffix(140))
            }
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String {
                // Only treat genuinely non-editable controls/desktop as non-input;
                // Qt / Electron / Canvas apps often report AXWindow/AXApplication even when the compose cursor is active.
                let nonEditableRoles: Set<String> = ["AXDesktop", "AXButton", "AXImage", "AXToolbar"]
                if nonEditableRoles.contains(role) {
                    editableFocus = false
                } else {
                    editableFocus = true
                }
            }
        }

        return ActiveScreenContext(
            appName: appName,
            bundleID: bundleID,
            windowTitle: windowTitle,
            selectedText: selectedText,
            precedingText: precedingText,
            hasFocusedTextInput: editableFocus
        )
    }

    public static func isLikelyEditableFocusNow() -> Bool {
        return captureCurrentContext().hasFocusedTextInput
    }

    public static func saveToSafetyClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - Zero-Modifier Unicode Streaming Delta (Works in Electron/Antigravity/Chrome/Cocoa)

    public static func applyCleanUnicodeDelta(from oldText: String, to newText: String) {
        guard AXIsProcessTrusted(), oldText != newText else { return }

        let oldChars = Array(oldText)
        let newChars = Array(newText)

        var commonLen = 0
        let minLen = min(oldChars.count, newChars.count)
        while commonLen < minLen && oldChars[commonLen] == newChars[commonLen] {
            commonLen += 1
        }

        let backspaceCount = oldChars.count - commonLen
        if backspaceCount > 0 {
            sendCleanBackspaces(count: backspaceCount)
        }

        if commonLen < newChars.count {
            let suffix = String(newChars[commonLen...])
            typeCleanUnicode(suffix)
        }
    }

    private static func stampAndPost(_ down: CGEvent, _ up: CGEvent, flags: CGEventFlags) {
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: HotkeyMonitor.syntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: HotkeyMonitor.syntheticEventMarker)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    /// Explicitly sets `CGEventFlags(rawValue: 0)` to wipe `.maskSecondaryFn`, `.maskAlternate`, and `.maskCommand`
    /// so held Fn/Option keys NEVER turn Backspace into Forward-Delete or Word-Delete!
    public static func sendCleanBackspaces(count: Int) {
        guard count > 0, AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .privateState)
        let deleteKey = CGKeyCode(kVK_Delete)
        for i in 0..<count {
            if let down = CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: false) {
                stampAndPost(down, up, flags: CGEventFlags(rawValue: 0))
            }
            // Prevent macOS CGEventTap ring-buffer overflow when backspacing long >20 char clauses
            if i > 0 && i % 14 == 0 {
                usleep(1_200)
            }
        }
    }

    /// Instant Cmd+A selection for zero-flicker atomic morph when input box contains only the streamed draft.
    public static func sendSelectAllEvent() {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .privateState)
        let aKey = CGKeyCode(kVK_ANSI_A)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: aKey, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: aKey, keyDown: false) {
            stampAndPost(down, up, flags: .maskCommand)
        }
    }

    /// Highlights the streamed draft via Shift+Left Arrow so Cmd+V replaces it in one atomic frame without backspace flicker.
    public static func selectLeftCharacters(count: Int) {
        guard count > 0, AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .privateState)
        let leftArrow = CGKeyCode(kVK_LeftArrow)
        for _ in 0..<count {
            if let down = CGEvent(keyboardEventSource: source, virtualKey: leftArrow, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: leftArrow, keyDown: false) {
                stampAndPost(down, up, flags: .maskShift)
            }
        }
    }

    /// Detects whether `Shift+Return` caused a Markdown-aware editor (Antigravity, Notion, Feishu, Obsidian)
    /// to auto-insert the next list prefix (`2. `, `3. `, `- `), and skips typing the duplicate prefix if already present!
    public static func typePostNewlineSkippingEditorAutoMarker(_ bufferedLineStart: String) {
        guard !bufferedLineStart.isEmpty, AXIsProcessTrusted() else { return }

        if let marker = extractLeadingListMarker(bufferedLineStart) {
            usleep(10_000)
            if let liveBox = readCurrentFocusedValue() {
                let trimmedMarker = marker.trimmingCharacters(in: .whitespaces)
                if liveBox.hasSuffix("\n" + marker) || liveBox.hasSuffix("\n" + trimmedMarker + " ") {
                    let remainder = String(bufferedLineStart.dropFirst(marker.count))
                    if !remainder.isEmpty {
                        typeCleanUnicode(remainder)
                    }
                    return
                }
            }
        }
        typeCleanUnicode(bufferedLineStart)
    }

    public static func extractLeadingListMarker(_ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"^(\d+\.\s+|[-*•]\s+)"#) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    public static func containsDuplicatedListMarker(in actualBox: String, expected: String) -> Bool {
        guard actualBox != expected else { return false }
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^[ \t]*(\d+\.|[-*•])\s+\1\s+"#) else { return false }
        let range = NSRange(actualBox.startIndex..<actualBox.endIndex, in: actualBox)
        let expectedRange = NSRange(expected.startIndex..<expected.endIndex, in: expected)
        return regex.firstMatch(in: actualBox, range: range) != nil && regex.firstMatch(in: expected, range: expectedRange) == nil
    }

    public static func collapseDuplicatedListMarkers(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^([ \t]*)(\d+\.|[-*•])\s+\2\s+"#) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1$2 ")
    }

    public static func typeCleanUnicode(_ text: String) {
        guard !text.isEmpty, AXIsProcessTrusted() else { return }
        let lines = text.components(separatedBy: "\n")
        for (lineIdx, line) in lines.enumerated() {
            if !line.isEmpty {
                if lineIdx > 0 {
                    typePostNewlineSkippingEditorAutoMarker(line)
                } else {
                    typeRawUnicodeLine(line)
                }
            }
            if lineIdx < lines.count - 1 {
                sendSoftNewlineShiftReturn()
            }
        }
    }

    fileprivate static func sendSoftNewlineShiftReturn() {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .privateState)
        let returnKey = CGKeyCode(kVK_Return)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: returnKey, keyDown: false) {
            stampAndPost(down, up, flags: .maskShift)
        }
    }

    private static func typeRawUnicodeLine(_ text: String) {
        guard !text.isEmpty, AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .privateState)
        let utf16Units = Array(text.utf16)
        let chunkSize = 12

        var idx = 0
        while idx < utf16Units.count {
            let end = min(idx + chunkSize, utf16Units.count)
            var slice = Array(utf16Units[idx..<end])
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                down.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: &slice)
                up.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: &slice)
                stampAndPost(down, up, flags: CGEventFlags(rawValue: 0))
            }
            idx = end
        }
    }

    /// Universal 100% reliable clipboard paste with snapshot restoration (works in every Electron, Web, and native editor).
    public static func pasteViaClipboardPreservingSnapshot(_ text: String) {
        guard !text.isEmpty, AXIsProcessTrusted() else { return }
        if let front = NSWorkspace.shared.frontmostApplication,
           !isAllowedTarget(bundleID: front.bundleIdentifier ?? "", appName: front.localizedName ?? "") {
            return
        }

        let pasteboard = NSPasteboard.general
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .privateState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            stampAndPost(keyDown, keyUp, flags: .maskCommand)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            guard !savedItems.isEmpty else { return }
            pasteboard.clearContents()
            let restored: [NSPasteboardItem] = savedItems.map { dict in
                let pbItem = NSPasteboardItem()
                for (type, data) in dict {
                    pbItem.setData(data, forType: type)
                }
                return pbItem
            }
            pasteboard.writeObjects(restored)
        }
    }

    public static func injectTextAtCursor(_ text: String, in context: ActiveScreenContext? = nil) {
        pasteViaClipboardPreservingSnapshot(text)
    }
}
