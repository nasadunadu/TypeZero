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

/// Dynamic-Island-inspired floating acoustic HUD capsule:
/// - Default Obsidian glass look (high contrast on both light & dark apps), switchable to Frosted Light or System in Settings.
/// - Strictly NEVER displays live transcribed text (text streams directly in the target input box).
/// - Decouples Accessibility IPC caret queries onto a background serial queue (zero main-thread stalls).
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
    private let pillSize = CGSize(width: 240, height: 64)

    public init() {}

    @MainActor
    public func attach(appState: AppState) {
        self.boundAppState = appState
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

// MARK: - Vector Möbius Infinity Brand Mark

public struct MobiusMarkView: View {
    public var size: CGFloat = 24
    public var monochromeWhite: Bool = false

    public init(size: CGFloat = 24, monochromeWhite: Bool = false) {
        self.size = size
        self.monochromeWhite = monochromeWhite
    }

    private func mobiusPoint(_ t: Double, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> CGPoint {
        let s = sin(t)
        let c = cos(t)
        let denom = 1.0 + 0.72 * s * s
        let x = cx + rx * CGFloat(c / denom)
        let y = cy + ry * CGFloat((1.65 * s * c) / denom)
        return CGPoint(x: x, y: y)
    }

    private func arcPath(from startT: Double, to endT: Double, steps: Int, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> Path {
        var path = Path()
        for i in 0...steps {
            let t = startT + (endT - startT) * Double(i) / Double(steps)
            let pt = mobiusPoint(t, cx: cx, cy: cy, rx: rx, ry: ry)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        return path
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let cx = w * 0.5
            let cy = h * 0.5
            let rx = w * 0.39
            let ry = h * 0.40
            let strokeW = max(2.1, w * 0.148)
            let roundStyle = StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round)

            // 1. Single unbroken closed loop (guarantees 100% seamless 9 & 3 o'clock outer poles!)
            var fullLoop = arcPath(from: 0, to: Double.pi * 2.0, steps: 140, cx: cx, cy: cy, rx: rx, ry: ry)
            fullLoop.closeSubpath()

            // Localized back-underpass arm around center crossing (t = 3*pi/2), extending well past recess radius
            let backCrossArm = arcPath(
                from: Double.pi * 1.5 - 0.85,
                to: Double.pi * 1.5 + 0.85,
                steps: 48,
                cx: cx,
                cy: cy,
                rx: rx,
                ry: ry
            )
            // Localized front-overpass arm around center crossing (t = pi/2), extending well past crown radius
            let frontCrossArm = arcPath(
                from: Double.pi * 0.5 - 0.74,
                to: Double.pi * 0.5 + 0.74,
                steps: 48,
                cx: cx,
                cy: cy,
                rx: rx,
                ry: ry
            )
            // Short central shadow-caster bar along front overpass
            let crossingShadowBar = arcPath(
                from: Double.pi * 0.5 - 0.34,
                to: Double.pi * 0.5 + 0.34,
                steps: 24,
                cx: cx,
                cy: cy,
                rx: rx,
                ry: ry
            )

            // Unified single top-left-lit gradient shared IDENTICALLY by fullLoop and frontCrossArm -> 0.000 seam!
            let topY = cy - ry * 0.65 - strokeW * 0.5
            let botY = cy + ry * 0.65 + strokeW * 0.5
            let unifiedShading: GraphicsContext.Shading = monochromeWhite
                ? .linearGradient(
                    Gradient(stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: Color(red: 0.965, green: 0.980, blue: 1.00), location: 0.52),
                        .init(color: Color(red: 0.855, green: 0.900, blue: 1.00), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: cx - rx * 0.25, y: topY),
                    endPoint: CGPoint(x: cx + rx * 0.25, y: botY)
                )
                : .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.45, green: 0.40, blue: 1.00), location: 0.0),
                        .init(color: Color(red: 0.36, green: 0.58, blue: 1.00), location: 0.52),
                        .init(color: Color(red: 0.20, green: 0.80, blue: 1.00), location: 1.0)
                    ]),
                    startPoint: CGPoint(x: cx - rx, y: topY),
                    endPoint: CGPoint(x: cx + rx, y: botY)
                )

            // Pass 1: Continuous unbroken Möbius base
            context.stroke(fullLoop, with: unifiedShading, style: roundStyle)

            // Pass 2: Smooth localized 3D underpass shading + cast shadow strictly clipped to backCrossArm
            // (Both radial recess & cast shadow hit 0.000 alpha long before the arm endpoints -> zero cap crease!)
            let backMask = backCrossArm.strokedPath(StrokeStyle(lineWidth: strokeW, lineCap: .butt, lineJoin: .round))
            context.drawLayer { layer in
                layer.clip(to: backMask)
                let centerPt = CGPoint(x: cx, y: cy)
                layer.fill(
                    Path(CGRect(x: cx - strokeW * 2.5, y: cy - strokeW * 2.5, width: strokeW * 5.0, height: strokeW * 5.0)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(
                                color: monochromeWhite
                                    ? Color(red: 0.22, green: 0.30, blue: 0.74).opacity(0.46)
                                    : Color.black.opacity(0.32),
                                location: 0.0
                            ),
                            .init(
                                color: monochromeWhite
                                    ? Color(red: 0.34, green: 0.42, blue: 0.84).opacity(0.16)
                                    : Color.black.opacity(0.08),
                                location: 0.50
                            ),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: centerPt,
                        startRadius: 0,
                        endRadius: strokeW * 1.60
                    )
                )
                layer.addFilter(.blur(radius: max(0.85, strokeW * 0.28)))
                layer.stroke(
                    crossingShadowBar,
                    with: .color(
                        monochromeWhite
                            ? Color(red: 0.07, green: 0.05, blue: 0.40).opacity(0.70)
                            : Color.black.opacity(0.46)
                    ),
                    style: StrokeStyle(lineWidth: strokeW * 1.44, lineCap: .round, lineJoin: .round)
                )
            }

            // Pass 3: Redraw front overpass arm with the EXACT same unified gradient (mathematically invisible blend at endpoints!)
            context.stroke(frontCrossArm, with: unifiedShading, style: StrokeStyle(lineWidth: strokeW, lineCap: .butt, lineJoin: .round))

            // Pass 4: Whisper-clean luminous crown highlight right on top of the central front overpass
            if monochromeWhite && size >= 20 {
                let crownMask = frontCrossArm.strokedPath(StrokeStyle(lineWidth: strokeW, lineCap: .butt, lineJoin: .round))
                context.drawLayer { layer in
                    layer.clip(to: crownMask)
                    layer.fill(
                        Path(CGRect(x: cx - strokeW * 1.8, y: cy - strokeW * 1.8, width: strokeW * 3.6, height: strokeW * 3.6)),
                        with: .radialGradient(
                            Gradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)]),
                            center: CGPoint(x: cx - strokeW * 0.12, y: cy - strokeW * 0.18),
                            startRadius: 0,
                            endRadius: strokeW * 1.32
                        )
                    )
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Obsidian Dynamic Island / Frosted Liquid Glass Floating Pill View

struct FloatingPillView: View {
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) private var systemScheme

    private var isObsidian: Bool {
        switch appState.llmConfig.floatingPillStyle {
        case .obsidian:
            return true
        case .frostedLight:
            return false
        case .system:
            if let explicit = appState.llmConfig.appearance.colorScheme {
                return explicit == .dark
            }
            return systemScheme == .dark
        }
    }

    var body: some View {
        Group {
            switch appState.phase {
            case .idle:
                EmptyView()

            case .listening(_, let mode):
                let accentColor = mode == .rewriteSelection
                    ? Color(red: 0.68, green: 0.44, blue: 1.00)
                    : Color(red: 0.48, green: 0.45, blue: 1.00)

                if appState.llmConfig.enableLiveInlineTyping || mode == .rewriteSelection {
                    HStack(spacing: 9.5) {
                        MobiusMarkView(size: 16, monochromeWhite: false)
                        FluidSineWaveView(accent: accentColor, isDarkSurface: isObsidian)
                            .frame(width: 68, height: 18)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 33)
                    .modifier(FloatingPillSurfaceModifier(isObsidian: isObsidian, cornerRadius: 999))
                } else {
                    VStack(spacing: 4) {
                        MicroSymbolStreamView(accent: accentColor, isDarkSurface: isObsidian)
                        HStack(spacing: 8.5) {
                            MobiusMarkView(size: 14, monochromeWhite: false)
                            FluidSineWaveView(accent: accentColor, isDarkSurface: isObsidian)
                                .frame(width: 86, height: 15)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 7)
                    .modifier(FloatingPillSurfaceModifier(isObsidian: isObsidian, cornerRadius: 19))
                }

            case .polishing:
                HStack(spacing: 8) {
                    MobiusMarkView(size: 15, monochromeWhite: false)
                    ShimmerDotsView(isDarkSurface: isObsidian)
                    Text("润色")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isObsidian ? Color.white.opacity(0.75) : Color(red: 0.20, green: 0.21, blue: 0.27))
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .modifier(FloatingPillSurfaceModifier(isObsidian: isObsidian, cornerRadius: 999, accentRim: true))

            case .completed:
                HStack(spacing: 5.5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0.16, green: 0.80, blue: 0.45))
                    Text("已上屏")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isObsidian ? Color.white.opacity(0.92) : Color(red: 0.10, green: 0.11, blue: 0.14))
                }
                .padding(.horizontal, 12)
                .frame(height: 29)
                .modifier(FloatingPillSurfaceModifier(isObsidian: isObsidian, cornerRadius: 999))

            case .savedToClipboard(let msg):
                HStack(spacing: 5.5) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.24, green: 0.68, blue: 1.0))
                    Text(msg)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isObsidian ? Color.white.opacity(0.92) : Color(red: 0.10, green: 0.11, blue: 0.14))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .modifier(FloatingPillSurfaceModifier(isObsidian: isObsidian, cornerRadius: 999))

            case .error:
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.orange)
                }
                .padding(.horizontal, 11)
                .frame(height: 29)
                .modifier(FloatingPillSurfaceModifier(isObsidian: isObsidian, cornerRadius: 999))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FloatingPillSurfaceModifier: ViewModifier {
    let isObsidian: Bool
    let cornerRadius: CGFloat
    var accentRim: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if isObsidian {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.115, green: 0.120, blue: 0.148).opacity(0.96),
                                        Color(red: 0.062, green: 0.066, blue: 0.086).opacity(0.97)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.84))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: accentRim
                                ? [Color(red: 0.48, green: 0.45, blue: 1.0).opacity(0.65), Color(red: 0.24, green: 0.75, blue: 0.98).opacity(0.32)]
                                : (isObsidian
                                    ? [Color.white.opacity(0.24), Color.white.opacity(0.06)]
                                    : [Color.white, Color.black.opacity(0.10)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(
                color: Color.black.opacity(isObsidian ? 0.36 : 0.14),
                radius: 12,
                x: 0,
                y: 5
            )
    }
}

/// Smooth 3-dot luminous flow indicator during sub-300ms polish transition.
struct ShimmerDotsView: View {
    var isDarkSurface: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * 7.5
            HStack(spacing: 3.5) {
                ForEach(0..<3, id: \.self) { idx in
                    let wave = (sin(t - Double(idx) * 0.85) + 1.0) * 0.5
                    Circle()
                        .fill(
                            isDarkSurface
                                ? Color(red: 0.62, green: 0.60, blue: 1.0).opacity(0.38 + wave * 0.62)
                                : Color(red: 0.31, green: 0.275, blue: 0.90).opacity(0.35 + wave * 0.65)
                        )
                        .frame(width: 4.5, height: 4.5)
                        .offset(y: CGFloat((wave - 0.5) * -3.0))
                }
            }
        }
    }
}

/// Rhythmic micro-symbol cipher ribbon displayed ABOVE the acoustic bars when live inline typing is off.
struct MicroSymbolStreamView: View {
    let accent: Color
    var isDarkSurface: Bool = true
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
                            let pulse = 0.28 + 0.26 * (sin(t * 4.2 - Double(i) * 0.9) + 1.0) * 0.5
                            Circle()
                                .fill((isDarkSurface ? Color.white : Color.black).opacity(pulse))
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
                                .foregroundStyle(
                                    isNewest
                                        ? accent
                                        : (isDarkSurface ? Color.white.opacity(0.76) : Color(red: 0.09, green: 0.086, blue: 0.106).opacity(0.70))
                                )
                                .scaleEffect(popScale)
                                .offset(y: waveY)
                        }
                    }
                    .frame(height: 13)

                    Text("\(visibleTotal)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(isDarkSurface ? Color.white.opacity(0.90) : accent)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 1)
                        .background(accent.opacity(isDarkSurface ? 0.32 : 0.13))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// 120Hz ProMotion fluid multi-ribbon sine wave reading directly from `AudioLevelBus` without SwiftUI state diffs!
struct FluidSineWaveView: View {
    let accent: Color
    var isDarkSurface: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let smoothLevel = AudioLevelBus.shared.sampleBallisticEnvelope()
            Canvas { ctx, size in
                let midY = size.height * 0.5
                let amp = max(1.8, CGFloat(smoothLevel) * size.height * 0.47)

                let primaryShading: GraphicsContext.Shading = isDarkSurface
                    ? .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.56, green: 0.50, blue: 1.00),
                            Color(red: 0.42, green: 0.66, blue: 1.00),
                            Color(red: 0.24, green: 0.85, blue: 1.00)
                        ]),
                        startPoint: CGPoint(x: 0, y: midY),
                        endPoint: CGPoint(x: size.width, y: midY)
                    )
                    : .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.353, green: 0.275, blue: 0.910),
                            Color(red: 0.28, green: 0.46, blue: 0.98),
                            Color(red: 0.08, green: 0.65, blue: 0.92)
                        ]),
                        startPoint: CGPoint(x: 0, y: midY),
                        endPoint: CGPoint(x: size.width, y: midY)
                    )

                for layer in (0..<3).reversed() {
                    var path = Path()
                    let phaseShift = Double(layer) * 1.15
                    let speed = layer == 0 ? 10.5 : (layer == 1 ? 7.4 : 5.2)
                    let freq = layer == 0 ? 2.7 : (layer == 1 ? 2.0 : 1.5)
                    let scale: CGFloat = layer == 0 ? 1.0 : (layer == 1 ? 0.78 : 0.55)

                    for xInt in stride(from: 0, through: Int(size.width), by: 1) {
                        let x = CGFloat(xInt)
                        let norm = Double(x / max(1, size.width))
                        let envelope = pow(sin(norm * Double.pi), 1.25)
                        let yOffset = sin(norm * Double.pi * freq - t * speed + phaseShift) * Double(amp * scale) * envelope
                        let pt = CGPoint(x: x, y: midY + CGFloat(yOffset))
                        if xInt == 0 {
                            path.move(to: pt)
                        } else {
                            path.addLine(to: pt)
                        }
                    }

                    let width: CGFloat = layer == 0 ? (isDarkSurface ? 2.0 : 1.9) : (layer == 1 ? 1.35 : 1.0)
                    if layer == 0 {
                        ctx.stroke(
                            path,
                            with: primaryShading,
                            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                        )
                    } else {
                        let opacity = layer == 1 ? (isDarkSurface ? 0.50 : 0.42) : (isDarkSurface ? 0.24 : 0.20)
                        ctx.stroke(
                            path,
                            with: .color(accent.opacity(opacity)),
                            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
            }
        }
    }
}
