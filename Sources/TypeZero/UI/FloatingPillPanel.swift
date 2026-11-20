import SwiftUI
import AppKit

/// Zero-overhead real-time audio envelope bus:
/// Decouples 90Hz microphone buffer callbacks from SwiftUI's root `AppState.objectWillChange`,
/// eliminating 90x/sec full-app view hierarchy diffs while giving `TimelineView` silky 60/120fps smoothed amplitude!
public final class AudioLevelBus: @unchecked Sendable {
    public static let shared = AudioLevelBus()

    private let lock = NSLock()
    private var rawTarget: Float = 0.06
    private var displayEnvelope: Float = 0.06
    private var targetSymbolCount: Int = 0
    private var displaySymbolProgress: Double = 0.0

    private init() {}

    public func push(_ level: Float) {
        lock.lock()
        rawTarget = max(0.05, min(1.0, level))
        lock.unlock()
    }

    public func pushRecognizedCount(_ count: Int) {
        lock.lock()
        targetSymbolCount = max(0, count)
        lock.unlock()
    }

    public func reset() {
        lock.lock()
        rawTarget = 0.05
        displayEnvelope = 0.05
        targetSymbolCount = 0
        displaySymbolProgress = 0.0
        lock.unlock()
    }

    /// Fast-attack, smooth-release ballistic envelope read on each animation frame (~0.0005ms, zero SwiftUI diff!).
    public func sampleBallisticEnvelope() -> Float {
        lock.lock()
        defer { lock.unlock() }
        let coeff: Float = rawTarget > displayEnvelope ? 0.38 : 0.14
        displayEnvelope += (rawTarget - displayEnvelope) * coeff
        return displayEnvelope
    }

    /// Smoothly steps the recognized character counter 1-by-1 at 60/120fps so micro-symbols glide out fluidly!
    public func sampleRecognizedSymbolProgress() -> (smoothProgress: Double, exactTarget: Int) {
        lock.lock()
        defer { lock.unlock() }
        let targetD = Double(targetSymbolCount)
        if targetD > displaySymbolProgress {
            let delta = targetD - displaySymbolProgress
            let step = max(0.32, delta * 0.24)
            displaySymbolProgress = min(targetD, displaySymbolProgress + step)
        } else if targetD < displaySymbolProgress {
            displaySymbolProgress += (targetD - displaySymbolProgress) * 0.30
        }
        return (displaySymbolProgress, targetSymbolCount)
    }
}

/// Ultra-minimalist, zero-text floating acoustic micro-pill:
/// - Strictly NEVER displays live transcribed text (text streams exclusively inside the user's selected input box!).
/// - Decouples Accessibility IPC caret queries onto a background serial queue (zero main-thread stalls!).
/// - Glides at 60fps in pure memory and renders a 60/120fps continuous fluid sine-wave visualization.
public final class FloatingPillController: @unchecked Sendable {
    private var panel: NSPanel?
    private weak var boundAppState: AppState?
    private var lerpTimer: DispatchSourceTimer?
    private var axPollTimer: DispatchSourceTimer?
    private let axPollQueue = DispatchQueue(label: "io.github.typezero.pill.axcaret", qos: .utility)

    private let coordLock = NSLock()
    private var cachedTargetOrigin: CGPoint? = nil
    private var currentOrigin: CGPoint = .zero
    private var isRequestedVisible: Bool = false
    private let pillSize = CGSize(width: 224, height: 58)

    public init() {}

    @MainActor
    public func attach(appState: AppState) {
        self.boundAppState = appState
        // Pre-warm panel offscreen so first Fn press shows in 0ms without NSHostingView creation hitch!
        ensurePanelCreated()
    }

    @MainActor
    private func ensurePanelCreated() {
        guard panel == nil, let appState = boundAppState else { return }

        let contentView = FloatingPillView(appState: appState)
        let hosting = NSHostingView(rootView: contentView)

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: pillSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = hosting

        self.panel = p
    }

    @MainActor
    public func setVisible(_ visible: Bool) {
        isRequestedVisible = visible
        if visible {
            ensurePanelCreated()
            guard let panel else { return }

            if !panel.isVisible {
                let sizeSnapshot = pillSize
                // Resolve initial anchor off-main-thread so the pill spawns right beneath the input box
                // without flashing at the bottom Dock first (bounded by a 60ms fast-path fallback).
                var hasShown = false
                let presentAt: @MainActor (CGPoint) -> Void = { [weak self] pos in
                    guard let self, self.isRequestedVisible, !hasShown, let panel = self.panel else { return }
                    hasShown = true
                    self.currentOrigin = pos
                    panel.alphaValue = 0.0
                    panel.setFrame(NSRect(origin: pos, size: sizeSnapshot), display: true)
                    panel.orderFrontRegardless()
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.10
                        panel.animator().alphaValue = 1.0
                    }
                    self.startDualLayerCaretTracking()
                }

                axPollQueue.async { [weak self] in
                    let resolved = ContextInjector.getFocusedCaretCocoaOrigin(pillSize: sizeSnapshot)
                    if let resolved, let self {
                        self.coordLock.lock()
                        self.cachedTargetOrigin = resolved
                        self.coordLock.unlock()
                    }
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            let target = resolved ?? self?.defaultBottomOrigin() ?? .zero
                            presentAt(target)
                        }
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(65)) { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        presentAt(self.defaultBottomOrigin())
                    }
                }
            }
        } else {
            stopDualLayerCaretTracking()
            AudioLevelBus.shared.reset()
            coordLock.lock()
            cachedTargetOrigin = nil
            coordLock.unlock()
            panel?.orderOut(nil)
        }
    }

    @MainActor
    private func startDualLayerCaretTracking() {
        stopDualLayerCaretTracking()
        let sizeSnapshot = pillSize

        // Layer 1 (Background Queue, 7Hz): Off-main-thread AX caret query with 35ms IPC timeout — NEVER blocks UI or typewriter!
        let poll = DispatchSource.makeTimerSource(queue: axPollQueue)
        poll.schedule(deadline: .now(), repeating: .milliseconds(140), leeway: .milliseconds(15))
        poll.setEventHandler { [weak self] in
            guard let self else { return }
            if let caret = ContextInjector.getFocusedCaretCocoaOrigin(pillSize: sizeSnapshot) {
                self.coordLock.lock()
                self.cachedTargetOrigin = caret
                self.coordLock.unlock()
            }
        }
        self.axPollTimer = poll
        poll.resume()

        // Layer 2 (Main Queue, 60fps): Pure in-memory float Lerp (~0.001ms per tick) — magnetic glide!
        let lerp = DispatchSource.makeTimerSource(queue: .main)
        lerp.schedule(deadline: .now() + .milliseconds(16), repeating: .milliseconds(16), leeway: .milliseconds(2))
        lerp.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.stepPureMemoryLerp()
            }
        }
        self.lerpTimer = lerp
        lerp.resume()
    }

    @MainActor
    private func stopDualLayerCaretTracking() {
        axPollTimer?.cancel()
        axPollTimer = nil
        lerpTimer?.cancel()
        lerpTimer = nil
    }

    @MainActor
    private func stepPureMemoryLerp() {
        guard let panel, panel.isVisible else { return }
        coordLock.lock()
        let targetOpt = cachedTargetOrigin
        coordLock.unlock()

        let target = targetOpt ?? defaultBottomOrigin()
        let dx = target.x - currentOrigin.x
        let dy = target.y - currentOrigin.y
        let dist = hypot(dx, dy)
        guard dist > 0.5 else { return }

        // Snap immediately if jumping across screen on initial caret discovery; glide smoothly while typing
        if dist > 260 {
            currentOrigin = target
        } else {
            let factor: CGFloat = 0.20
            currentOrigin.x += dx * factor
            currentOrigin.y += dy * factor
        }
        panel.setFrameOrigin(currentOrigin)
    }

    @MainActor
    private func defaultBottomOrigin() -> CGPoint {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return .zero }
        let vf = screen.visibleFrame
        return CGPoint(x: vf.midX - pillSize.width * 0.5, y: vf.minY + 22)
    }
}

/// Custom vector Möbius Strip brand mark.
public struct MobiusMarkView: View {
    public var size: CGFloat = 24

    public init(size: CGFloat = 24) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let cx = w * 0.5
            let cy = h * 0.52
            let rx = w * 0.38
            let ry = h * 0.24

            var backLoop = Path()
            let steps = 90
            for i in 0...steps {
                let t = Double(i) / Double(steps) * Double.pi * 2.0
                let denom = 1.0 + pow(sin(t), 2)
                let x = cx + rx * CGFloat(cos(t) / denom)
                let y = cy + ry * 1.55 * CGFloat((sin(t) * cos(t)) / denom)
                if i == 0 {
                    backLoop.move(to: CGPoint(x: x, y: y))
                } else {
                    backLoop.addLine(to: CGPoint(x: x, y: y))
                }
            }
            backLoop.closeSubpath()

            let grad = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    Color(red: 0.353, green: 0.275, blue: 0.910), // #5A46E8 Royal Violet
                    Color(red: 0.486, green: 0.345, blue: 0.949),
                    Color(red: 0.220, green: 0.490, blue: 0.960)
                ]),
                startPoint: CGPoint(x: w * 0.12, y: h * 0.25),
                endPoint: CGPoint(x: w * 0.88, y: h * 0.75)
            )

            context.stroke(
                backLoop,
                with: grad,
                style: StrokeStyle(lineWidth: max(2.2, size * 0.145), lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

/// Pure acoustic wave micro-capsule — ZERO live text duplication, ZERO per-frame SwiftUI state invalidations!
struct FloatingPillView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .idle:
                EmptyView()

            case .listening(_, let mode):
                let accentColor = mode == .rewriteSelection
                    ? Color(red: 0.56, green: 0.24, blue: 0.88)
                    : Color(red: 0.353, green: 0.275, blue: 0.910)

                if appState.llmConfig.enableLiveInlineTyping || mode == .rewriteSelection {
                    HStack(spacing: 9) {
                        MobiusMarkView(size: 16)
                        FluidSineWaveView(accent: accentColor)
                            .frame(width: 62, height: 16)
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 31)
                    .background(.ultraThinMaterial)
                    .background(Color(red: 0.988, green: 0.984, blue: 0.973).opacity(0.94))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color(red: 0.09, green: 0.086, blue: 0.106).opacity(0.10), lineWidth: 0.8))
                } else {
                    // Default Fast-Paste Mode: rhythmic micro-symbols reading live character count ABOVE the sound wave!
                    VStack(spacing: 4) {
                        MicroSymbolStreamView(accent: accentColor)
                        HStack(spacing: 8) {
                            MobiusMarkView(size: 14)
                            FluidSineWaveView(accent: accentColor)
                                .frame(width: 86, height: 14)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6.5)
                    .background(.ultraThinMaterial)
                    .background(Color(red: 0.988, green: 0.984, blue: 0.973).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(red: 0.09, green: 0.086, blue: 0.106).opacity(0.10), lineWidth: 0.8)
                    )
                }

            case .polishing:
                HStack(spacing: 8) {
                    MobiusMarkView(size: 15)
                    ShimmerDotsView()
                }
                .padding(.horizontal, 13)
                .frame(height: 29)
                .background(.ultraThinMaterial)
                .background(Color(red: 0.988, green: 0.984, blue: 0.973).opacity(0.95))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.353, green: 0.275, blue: 0.910).opacity(0.22), lineWidth: 0.8))

            case .completed:
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.12, green: 0.72, blue: 0.42))
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.white.opacity(0.95))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.8))

            case .savedToClipboard(let msg):
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.10, green: 0.42, blue: 1.0))
                    Text(msg)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.10, blue: 0.14))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.white.opacity(0.96))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.10, green: 0.42, blue: 1.0).opacity(0.3), lineWidth: 0.8))

            case .error:
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.orange)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.white.opacity(0.96))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.orange.opacity(0.4), lineWidth: 0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Smooth 3-dot wave indicator during sub-300ms polish transition (replaces clunky macOS NSProgressIndicator spinner).
struct ShimmerDotsView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * 7.5
            HStack(spacing: 3.5) {
                ForEach(0..<3, id: \.self) { idx in
                    let wave = (sin(t - Double(idx) * 0.85) + 1.0) * 0.5
                    Circle()
                        .fill(Color(red: 0.353, green: 0.275, blue: 0.910).opacity(0.35 + wave * 0.65))
                        .frame(width: 4.5, height: 4.5)
                        .offset(y: CGFloat((wave - 0.5) * -3.0))
                }
            }
        }
    }
}

/// Rhythmic micro-symbol cipher ribbon displayed ABOVE the acoustic sine wave when live inline typing is off:
/// Turns each recognized syllable into a delicate dancing symbol (`• · ✦ ▪`) + live character count without distracting draft text!
struct MicroSymbolStreamView: View {
    let accent: Color
    private static let glyphCycle: [String] = ["•", "·", "✦", "•", "▪", "·"]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let (smoothProg, _) = AudioLevelBus.shared.sampleRecognizedSymbolProgress()
            let visibleTotal = Int(smoothProg.rounded(.down))
            let fractionalBirth = smoothProg - Double(visibleTotal)
            let maxWindow = 12
            let windowCount = min(maxWindow, visibleTotal)
            let startSerial = max(0, visibleTotal - maxWindow)

            HStack(spacing: 5) {
                if windowCount == 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            let pulse = 0.22 + 0.20 * (sin(t * 4.2 - Double(i) * 0.9) + 1.0) * 0.5
                            Circle()
                                .fill(Color(red: 0.09, green: 0.086, blue: 0.106).opacity(pulse))
                                .frame(width: 3.2, height: 3.2)
                        }
                    }
                    .frame(height: 13)
                } else {
                    HStack(spacing: 3.2) {
                        ForEach(0..<windowCount, id: \.self) { slot in
                            let serial = startSerial + slot
                            let glyph = Self.glyphCycle[serial % Self.glyphCycle.count]
                            let isNewest = (slot == windowCount - 1)
                            let popScale: CGFloat = isNewest ? CGFloat(0.75 + 0.30 * sin(fractionalBirth * Double.pi)) : 1.0
                            let waveY = CGFloat(sin(t * 6.5 - Double(serial) * 0.65) * 1.1)
                            Text(glyph)
                                .font(.system(size: glyph == "✦" ? 8.5 : 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(isNewest ? accent : Color(red: 0.09, green: 0.086, blue: 0.106).opacity(0.68))
                                .scaleEffect(popScale)
                                .offset(y: waveY)
                        }
                    }
                    .frame(height: 13)

                    Text("\(visibleTotal)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(accent.opacity(0.11))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// 120Hz ProMotion fluid multi-ribbon sine wave reading directly from `AudioLevelBus` without SwiftUI state diffs!
struct FluidSineWaveView: View {
    let accent: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let smoothLevel = AudioLevelBus.shared.sampleBallisticEnvelope()
            Canvas { ctx, size in
                let midY = size.height * 0.5
                let amp = max(1.5, CGFloat(smoothLevel) * size.height * 0.47)

                for layer in 0..<3 {
                    var path = Path()
                    let phaseShift = Double(layer) * 1.15
                    let speed = layer == 0 ? 10.5 : (layer == 1 ? 7.4 : 5.2)
                    let freq = layer == 0 ? 2.7 : (layer == 1 ? 2.0 : 1.5)
                    let scale: CGFloat = layer == 0 ? 1.0 : (layer == 1 ? 0.78 : 0.55)

                    for xInt in stride(from: 0, through: Int(size.width), by: 2) {
                        let x = CGFloat(xInt)
                        let norm = Double(x / size.width)
                        let envelope = pow(sin(norm * Double.pi), 1.25)
                        let yOffset = sin(norm * Double.pi * freq - t * speed + phaseShift) * Double(amp * scale) * envelope
                        let pt = CGPoint(x: x, y: midY + CGFloat(yOffset))
                        if xInt == 0 {
                            path.move(to: pt)
                        } else {
                            path.addLine(to: pt)
                        }
                    }

                    let opacity = layer == 0 ? 0.94 : (layer == 1 ? 0.42 : 0.20)
                    let width: CGFloat = layer == 0 ? 1.9 : (layer == 1 ? 1.35 : 1.0)
                    ctx.stroke(
                        path,
                        with: .color(accent.opacity(opacity)),
                        style: StrokeStyle(lineWidth: width, lineCap: .round)
                    )
                }
            }
        }
    }
}
