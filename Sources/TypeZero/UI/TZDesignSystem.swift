import SwiftUI
import AppKit

// MARK: - AppAppearanceOption Bridge

extension AppAppearanceOption {
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Native Full-Bleed macOS Window Chrome Configurator

struct TZWindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { configure(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window { configure(window) }
        }
    }

    private func configure(_ window: NSWindow) {
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.toolbar = nil
    }
}

// MARK: - Adaptive High-Craft Color System (Apple Liquid Glass × CNC Obsidian)

enum TZTheme {
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    // Studio Canvas Fallback
    static let canvasBg = dynamic(
        light: rgba(0.938, 0.943, 0.976),
        dark:  rgba(0.067, 0.071, 0.100)
    )
    static let canvasBgBottom = dynamic(
        light: rgba(0.916, 0.924, 0.968),
        dark:  rgba(0.047, 0.051, 0.075)
    )

    // Sidebar Tint Fallback
    static let sidebarTop = dynamic(
        light: rgba(0.925, 0.918, 0.965, 0.86),
        dark:  rgba(0.058, 0.062, 0.090, 0.90)
    )
    static let sidebarBottom = dynamic(
        light: rgba(0.888, 0.884, 0.948, 0.90),
        dark:  rgba(0.075, 0.079, 0.115, 0.94)
    )

    // Translucent Frosted Crystal Glass Cards (lets silk canvas breathe softly underneath!)
    static let cardBg = dynamic(
        light: rgba(1.000, 1.000, 1.000, 0.78),
        dark:  rgba(0.102, 0.108, 0.155, 0.82)
    )
    static let cardElevated = dynamic(
        light: rgba(1.000, 1.000, 1.000, 0.92),
        dark:  rgba(0.140, 0.148, 0.205, 0.94)
    )
    static let recessedWell = dynamic(
        light: rgba(0.912, 0.918, 0.958, 0.85),
        dark:  rgba(0.058, 0.062, 0.090, 0.88)
    )
    static let hoverFill = dynamic(
        light: rgba(0.388, 0.355, 0.960, 0.065),
        dark:  rgba(0.486, 0.455, 1.000, 0.125)
    )

    // Delicate Glass Borders & Hairlines
    static let cardBorder = dynamic(
        light: rgba(0.280, 0.270, 0.460, 0.100),
        dark:  rgba(1.000, 1.000, 1.000, 0.105)
    )
    static let hairline = dynamic(
        light: rgba(0.240, 0.235, 0.410, 0.070),
        dark:  rgba(1.000, 1.000, 1.000, 0.075)
    )
    static let strongLine = dynamic(
        light: rgba(0.240, 0.235, 0.410, 0.160),
        dark:  rgba(1.000, 1.000, 1.000, 0.180)
    )

    // Ink / Typography
    static let inkPrimary = dynamic(
        light: rgba(0.072, 0.078, 0.120),
        dark:  rgba(0.965, 0.972, 0.995)
    )
    static let inkSecondary = dynamic(
        light: rgba(0.315, 0.332, 0.415),
        dark:  rgba(0.665, 0.688, 0.770)
    )
    static let inkMuted = dynamic(
        light: rgba(0.500, 0.520, 0.615),
        dark:  rgba(0.455, 0.478, 0.568)
    )

    // Brand & Semantic Accents
    static let accent = dynamic(
        light: rgba(0.385, 0.315, 0.955),
        dark:  rgba(0.530, 0.495, 1.000)
    )
    static let accentSoft = dynamic(
        light: rgba(0.385, 0.315, 0.955, 0.120),
        dark:  rgba(0.530, 0.495, 1.000, 0.210)
    )
    static let cyan = dynamic(
        light: rgba(0.015, 0.560, 0.840),
        dark:  rgba(0.220, 0.775, 0.990)
    )
    static let cyanSoft = dynamic(
        light: rgba(0.015, 0.560, 0.840, 0.120),
        dark:  rgba(0.220, 0.775, 0.990, 0.190)
    )
    static let emerald = dynamic(
        light: rgba(0.045, 0.600, 0.345),
        dark:  rgba(0.145, 0.815, 0.425)
    )
    static let emeraldSoft = dynamic(
        light: rgba(0.045, 0.600, 0.345, 0.125),
        dark:  rgba(0.145, 0.815, 0.425, 0.190)
    )
    static let amber = dynamic(
        light: rgba(0.810, 0.465, 0.030),
        dark:  rgba(0.965, 0.670, 0.160)
    )
    static let amberSoft = dynamic(
        light: rgba(0.960, 0.620, 0.043, 0.145),
        dark:  rgba(0.965, 0.670, 0.160, 0.195)
    )
    static let crimson = dynamic(
        light: rgba(0.855, 0.185, 0.235),
        dark:  rgba(0.975, 0.445, 0.445)
    )
    static let crimsonSoft = dynamic(
        light: rgba(0.855, 0.185, 0.235, 0.110),
        dark:  rgba(0.975, 0.445, 0.445, 0.175)
    )
}

// MARK: - Studio Liquid-Glass Canvas Backdrop (Powered by Real CGI canvas-glass-light/dark PNG!)

struct TZCanvasBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let isDark = (scheme == .dark)
        let assetName = isDark ? "canvas-glass-dark" : "canvas-glass-light"

        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [TZTheme.canvasBg, TZTheme.canvasBgBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let img = TZAssetStore.image(named: assetName) {
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .saturation(isDark ? 0.78 : 0.65)
                        .blur(radius: 3)
                        .opacity(isDark ? 0.44 : 0.36)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Crisp 1px Hairline Divider

struct TZHairline: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(TZTheme.hairline)
            .frame(height: 1)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Typography System (Plan 3: DIN Alternate Numerals × Avenir Next Brand × SF Mono × PingFang SC)

enum TZFont {
    static func brand(_ size: CGFloat) -> Font {
        Font.custom("AvenirNext-DemiBold", size: size)
    }

    static func metric(_ size: CGFloat) -> Font {
        Font.custom("DINAlternate-Bold", size: size).monospacedDigit()
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        Font.system(size: size, weight: .bold)
    }

    static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight)
    }
}

// MARK: - Native macOS Frosted Vibrancy Backdrop

struct TZVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = state
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Razor-Sharp Precision Sapphire-Indigo Optical Jewel Brand Squircle Emblem

struct TZBrandEmblemView: View {
    var size: CGFloat = 40
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let isDark = (scheme == .dark)
        let corner = size * 0.245
        let squircle = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack {
            // 1. Rich deep sapphire-indigo optical crystal body (high-contrast anchor on both Light & Dark sidebars)
            squircle
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.33, green: 0.29, blue: 0.94), location: 0.0),
                            .init(color: Color(red: 0.23, green: 0.19, blue: 0.84), location: 0.52),
                            .init(color: Color(red: 0.11, green: 0.09, blue: 0.54), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. Subtle internal bottom-right cyan-sapphire optical crystal refraction (crisp, zero blur mud)
            squircle
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.22, green: 0.74, blue: 0.98).opacity(0.36),
                            Color(red: 0.26, green: 0.56, blue: 1.00).opacity(0.10),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.86, y: 0.88),
                        startRadius: 0,
                        endRadius: size * 0.72
                    )
                )

            // 3. Clean upper curved optical-glass specular meniscus
            squircle
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.52)
                    )
                )
                .padding(1)

            // 4. Precision-cut inner specular bevel rim (bright top-left catchlight -> deep shaded bottom-right chamfer)
            squircle
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.66), location: 0.0),
                            .init(color: Color(red: 0.66, green: 0.74, blue: 1.00).opacity(0.24), location: 0.48),
                            .init(color: Color(red: 0.07, green: 0.05, blue: 0.34).opacity(0.46), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )

            // 5. Razor-sharp 3D woven Pure-White / Ice-Silver Möbius centerpiece (>11:1 contrast)
            MobiusMarkView(size: size * 0.76, monochromeWhite: true)
                .shadow(
                    color: Color(red: 0.06, green: 0.04, blue: 0.30).opacity(0.42),
                    radius: max(1.2, size * 0.04),
                    x: 0,
                    y: max(0.8, size * 0.028)
                )
        }
        .frame(width: size, height: size)
        // Tight outer edge anchor so the squircle silhouette is razor-sharp against light sidebars
        .overlay(
            squircle
                .stroke(
                    Color(red: 0.14, green: 0.11, blue: 0.52).opacity(isDark ? 0.52 : 0.24),
                    lineWidth: 0.5
                )
        )
        // Crisp physical contact shadow + subtle lift (no blurry neon fog!)
        .shadow(color: Color.black.opacity(isDark ? 0.42 : 0.20), radius: 1.5, x: 0, y: 0.8)
        .shadow(color: Color(red: 0.22, green: 0.18, blue: 0.74).opacity(isDark ? 0.34 : 0.22), radius: 5.5, x: 0, y: 3)
    }
}

// MARK: - Photorealistic 3D Brushed-Aluminum / Matte-Obsidian Mechanical Keycap (keycap-3d-light/dark.png!)

struct TZKeycapView: View {
    enum Size { case small, medium, large }

    let label: String
    var size: Size = .small
    var highlighted: Bool = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let isDark = (scheme == .dark)

        if size == .large {
            let capBox: CGFloat = 78
            let assetName = isDark ? "keycap-3d-dark" : "keycap-3d-light"

            ZStack {
                if let keyImg = TZAssetStore.image(named: assetName) {
                    keyImg
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: capBox, height: capBox)
                        .shadow(
                            color: highlighted || isDark
                                ? Color(red: 0.48, green: 0.40, blue: 1.0).opacity(isDark ? 0.48 : 0.32)
                                : Color(red: 0.14, green: 0.16, blue: 0.30).opacity(0.22),
                            radius: isDark ? 12 : 9,
                            x: 0,
                            y: 5
                        )

                    // Placed at QA-verified optical center of the blank top face (-15% Light / -14.1% Dark)
                    Text(label)
                        .font(TZFont.mono(17, weight: .semibold))
                        .foregroundStyle(
                            highlighted
                                ? TZTheme.accent
                                : (isDark ? Color.white.opacity(0.92) : Color(red: 0.24, green: 0.26, blue: 0.34))
                        )
                        .shadow(color: isDark ? Color.black.opacity(0.55) : Color.white.opacity(0.85), radius: 1, y: 0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: 50)
                        .offset(y: isDark ? -(capBox * 0.141) : -(capBox * 0.150))
                } else {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(TZTheme.cardElevated)
                        .frame(width: 64, height: 58)
                        .overlay(Text(label).font(TZFont.mono(16, weight: .bold)))
                }
            }
            .frame(width: capBox, height: capBox)
        } else {
            let isSmall = (size == .small)
            let radius: CGFloat = isSmall ? 6 : 8
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isDark ? Color(red: 0.055, green: 0.058, blue: 0.085) : Color(red: 0.78, green: 0.80, blue: 0.87))
                    .offset(y: 1.8)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: highlighted
                                ? (isDark ? [Color(red: 0.25, green: 0.23, blue: 0.48), Color(red: 0.16, green: 0.15, blue: 0.34)]
                                          : [Color(red: 0.95, green: 0.94, blue: 1.00), Color(red: 0.89, green: 0.88, blue: 0.99)])
                                : (isDark ? [Color(red: 0.19, green: 0.20, blue: 0.26), Color(red: 0.12, green: 0.13, blue: 0.18)]
                                          : [Color.white, Color(red: 0.93, green: 0.94, blue: 0.97)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                highlighted ? TZTheme.accent.opacity(0.55) : TZTheme.cardBorder,
                                lineWidth: 1
                            )
                    )

                Text(label)
                    .font(TZFont.mono(isSmall ? 10.5 : 12, weight: .bold))
                    .foregroundStyle(highlighted ? TZTheme.accent : TZTheme.inkPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, isSmall ? 7 : 11)
            }
            .frame(minWidth: isSmall ? 26 : 38, minHeight: isSmall ? 21 : 28)
            .fixedSize()
            .padding(.bottom, 1.5)
            .shadow(color: Color.black.opacity(isDark ? 0.36 : 0.08), radius: 2.5, x: 0, y: 1.5)
        }
    }
}

// MARK: - Optical 3D Liquid-Crystal Button Styles (Top Specular Gloss + Bottom Caustic Bounce Glow!)

struct TZPrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    var capsule: Bool = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let isDark = (scheme == .dark)
        let fgColor: Color = isDark ? Color(red: 0.08, green: 0.085, blue: 0.13) : .white
        let radius: CGFloat = capsule ? 999 : (compact ? 9 : 11)

        configuration.label
            .font(.system(size: compact ? 12 : 12.5, weight: .semibold))
            .foregroundStyle(fgColor.opacity(isEnabled ? 1.0 : 0.45))
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 6.5 : 8.5)
            .background(
                ZStack {
                    if isDark {
                        // Frosted Platinum Luminous Pill (v2-02)
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.99, green: 0.99, blue: 1.00), Color(red: 0.85, green: 0.87, blue: 0.97)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        // Optical Crystal Violet Pill (v2-01) — rich depth + glossy top arc + bottom cyan-lavender caustic bounce!
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.485, green: 0.405, blue: 1.000),
                                        Color(red: 0.345, green: 0.255, blue: 0.935),
                                        Color(red: 0.265, green: 0.195, blue: 0.845)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        // Top curved glossy crystal highlight reflection (refined restraint)
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.32), Color.white.opacity(0.05), Color.clear],
                                    startPoint: .top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.52)
                                )
                            )
                            .padding(1.5)
                        // Subtle bottom internal lavender bounce light
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.clear, Color(red: 0.58, green: 0.76, blue: 1.00).opacity(0.22)],
                                    startPoint: UnitPoint(x: 0.5, y: 0.65),
                                    endPoint: .bottom
                                )
                            )
                            .padding(1.2)
                    }
                }
                .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1.0) : 0.42)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDark ? 0.95 : 0.45),
                                Color.white.opacity(isDark ? 0.35 : 0.10),
                                Color(red: 0.65, green: 0.80, blue: 1.0).opacity(isDark ? 0.35 : 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.95
                    )
            )
            .shadow(
                color: isDark
                    ? Color(red: 0.65, green: 0.68, blue: 1.0).opacity(isEnabled ? 0.30 : 0)
                    : Color(red: 0.35, green: 0.26, blue: 0.96).opacity(isEnabled ? 0.28 : 0),
                radius: compact ? 6 : 9,
                x: 0,
                y: compact ? 2.5 : 3.5
            )
            .scaleEffect(configuration.isPressed ? 0.974 : 1.0)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}

struct TZAccentButtonStyle: ButtonStyle {
    var compact: Bool = false
    var capsule: Bool = true
    var tint: Color? = nil
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = capsule ? 999 : (compact ? 8.5 : 10.5)
        let top = tint ?? Color(red: 0.475, green: 0.395, blue: 1.000)
        let bottom = tint?.opacity(0.84) ?? Color(red: 0.285, green: 0.215, blue: 0.865)

        configuration.label
            .font(.system(size: compact ? 12 : 12.5, weight: .semibold))
            .foregroundStyle(.white.opacity(isEnabled ? 1.0 : 0.6))
            .padding(.horizontal, compact ? 13 : 16)
            .padding(.vertical, compact ? 6.5 : 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.38), Color.clear], startPoint: .top, endPoint: .center))
                        .padding(1.2)
                }
                .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1.0) : 0.42)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.52), Color.white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.95
                    )
            )
            .shadow(color: top.opacity(isEnabled ? 0.36 : 0), radius: 9, x: 0, y: 3.5)
            .scaleEffect(configuration.isPressed ? 0.974 : 1.0)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}

/// Frosted Translucent Glass Secondary Button (Matches v2-01's glowing frosted pill controls!)
struct TZSecondaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    var destructive: Bool = false
    var capsule: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = capsule ? 999 : (compact ? 8.5 : 10)
        let isDark = (scheme == .dark)

        configuration.label
            .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
            .foregroundStyle(destructive ? TZTheme.crimson : TZTheme.inkPrimary.opacity(isEnabled ? 0.92 : 0.42))
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 6 : 7.5)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            configuration.isPressed
                                ? TZTheme.recessedWell
                                : (destructive
                                    ? TZTheme.crimsonSoft.opacity(0.60)
                                    : (isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.76)))
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: destructive
                                ? [TZTheme.crimson.opacity(0.40), TZTheme.crimson.opacity(0.20)]
                                : (isDark
                                    ? [Color.white.opacity(0.22), Color.white.opacity(0.07)]
                                    : [Color.white, Color(red: 0.30, green: 0.28, blue: 0.50).opacity(0.12), Color.white.opacity(0.85)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.05
                    )
            )
            .shadow(color: Color(red: 0.24, green: 0.22, blue: 0.48).opacity(isDark ? 0.32 : 0.08), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.980 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

// MARK: - Frosted Milky Liquid-Glass Card Modifier (Translucent Glass + Diagonal Specular Crystal Rim!)

struct TZElevatedCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 15
    var padding: CGFloat = 16
    var activeBorder: Color? = nil
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let isDark = (scheme == .dark)
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isDark
                                    ? [Color(red: 0.13, green: 0.14, blue: 0.20).opacity(0.82), Color(red: 0.09, green: 0.10, blue: 0.14).opacity(0.86)]
                                    : [Color.white.opacity(0.86), Color(red: 0.975, green: 0.978, blue: 1.000).opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Outer whisper definition hairline
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(activeBorder ?? TZTheme.cardBorder, lineWidth: activeBorder != nil ? 1.45 : 0.85)
            )
            // Diagonal crystal-glass specular rim catching light top-left & bottom-right (Matches v2-01/02!)
            .overlay(
                RoundedRectangle(cornerRadius: max(4, cornerRadius - 0.8), style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isDark
                                ? [Color.white.opacity(0.22), Color.white.opacity(0.04), Color.white.opacity(0.10)]
                                : [Color.white, Color.white.opacity(0.32), Color.white.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.15
                    )
                    .padding(0.8)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.34 : 0.03), radius: 2, x: 0, y: 1)
            .shadow(color: Color(red: 0.28, green: 0.26, blue: 0.56).opacity(isDark ? 0.26 : 0.095), radius: 16, x: 0, y: 7)
    }
}

struct TZRecessedInputModifier: ViewModifier {
    var compact: Bool = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: compact ? 12.5 : 13))
            .foregroundStyle(TZTheme.inkPrimary)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 6.5 : 8)
            .background(TZTheme.recessedWell)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 9.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 9.5, style: .continuous)
                    .strokeBorder(TZTheme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func tzElevatedCard(cornerRadius: CGFloat = 15, padding: CGFloat = 16, activeBorder: Color? = nil) -> some View {
        modifier(TZElevatedCardModifier(cornerRadius: cornerRadius, padding: padding, activeBorder: activeBorder))
    }

    func tzRecessedInput(compact: Bool = false) -> some View {
        modifier(TZRecessedInputModifier(compact: compact))
    }
}

// MARK: - Apple System Settings Grouped Glass Container

struct TZGroupedSection<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var scheme

    init(
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        let isDark = (scheme == .dark)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(TZTheme.inkSecondary)
                Spacer()
                trailing()
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(
                        LinearGradient(
                            colors: isDark
                                ? [Color(red: 0.13, green: 0.14, blue: 0.20).opacity(0.84), Color(red: 0.09, green: 0.10, blue: 0.14).opacity(0.88)]
                                : [Color.white.opacity(0.86), Color(red: 0.975, green: 0.978, blue: 1.000).opacity(0.76)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(TZTheme.cardBorder, lineWidth: 0.85)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14.2, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isDark
                                ? [Color.white.opacity(0.20), Color.white.opacity(0.04), Color.white.opacity(0.09)]
                                : [Color.white, Color.white.opacity(0.32), Color.white.opacity(0.86)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
                    .padding(0.8)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.32 : 0.03), radius: 2, x: 0, y: 1)
            .shadow(color: Color(red: 0.28, green: 0.26, blue: 0.56).opacity(isDark ? 0.24 : 0.085), radius: 15, x: 0, y: 6)
        }
    }
}

// MARK: - Tactile Segmented Control Bar

struct TZSegmentedBar: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let icon: String?
        let isSelected: Bool
        let action: () -> Void

        init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
            self.id = title
            self.title = title
            self.icon = icon
            self.isSelected = isSelected
            self.action = action
        }
    }

    let items: [Item]
    var compact: Bool = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let isDark = (scheme == .dark)
        HStack(spacing: 3) {
            ForEach(items) { item in
                Button(action: item.action) {
                    HStack(spacing: 5.5) {
                        if let icon = item.icon {
                            Image(systemName: icon)
                                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                                .foregroundStyle(item.isSelected ? TZTheme.accent : TZTheme.inkMuted)
                        }
                        Text(item.title)
                            .font(.system(size: compact ? 12 : 13, weight: item.isSelected ? .semibold : .medium))
                            .foregroundStyle(item.isSelected ? TZTheme.inkPrimary : TZTheme.inkSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? 5.5 : 8)
                    .padding(.horizontal, compact ? 9 : 12)
                    .background(
                        RoundedRectangle(cornerRadius: compact ? 7.5 : 9.5, style: .continuous)
                            .fill(item.isSelected ? TZTheme.cardElevated : Color.clear)
                            .shadow(
                                color: item.isSelected ? Color(red: 0.26, green: 0.24, blue: 0.54).opacity(isDark ? 0.40 : 0.12) : .clear,
                                radius: 5,
                                x: 0,
                                y: 2
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 7.5 : 9.5, style: .continuous)
                            .strokeBorder(
                                item.isSelected
                                    ? (isDark ? Color.white.opacity(0.18) : Color.white)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3.5)
        .background(TZTheme.recessedWell)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 12.5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 12.5, style: .continuous)
                .strokeBorder(TZTheme.cardBorder, lineWidth: 0.9)
        )
    }
}

// MARK: - Authentic Colored macOS App Micro-Icon Badge

struct TZAppIconBadge: View {
    let appName: String

    private var spec: (symbol: String, letter: String?, bg: [Color]) {
        let lower = appName.lowercased()
        if lower.contains("cursor") {
            return ("cube.fill", nil, [Color(red: 0.18, green: 0.19, blue: 0.24), Color(red: 0.09, green: 0.10, blue: 0.13)])
        }
        if lower.contains("antigravity") {
            return ("sparkles", nil, [Color(red: 0.36, green: 0.34, blue: 0.92), Color(red: 0.22, green: 0.48, blue: 0.94)])
        }
        if lower.contains("飞书") || lower.contains("feishu") || lower.contains("lark") {
            return ("paperplane.fill", nil, [Color(red: 0.04, green: 0.72, blue: 0.86), Color(red: 0.11, green: 0.48, blue: 0.96)])
        }
        if lower.contains("notion") {
            return ("", "N", [Color(red: 0.20, green: 0.21, blue: 0.24), Color(red: 0.11, green: 0.11, blue: 0.14)])
        }
        if lower.contains("微信") || lower.contains("wechat") {
            return ("message.fill", nil, [Color(red: 0.12, green: 0.74, blue: 0.38), Color(red: 0.07, green: 0.60, blue: 0.29)])
        }
        if lower.contains("safari") {
            return ("safari.fill", nil, [Color(red: 0.16, green: 0.62, blue: 0.98), Color(red: 0.07, green: 0.42, blue: 0.92)])
        }
        if lower.contains("chrome") || lower.contains("arc") {
            return ("globe", nil, [Color(red: 0.24, green: 0.52, blue: 0.96), Color(red: 0.20, green: 0.38, blue: 0.88)])
        }
        if lower.contains("terminal") || lower.contains("iterm") || lower.contains("warp") || lower.contains("终端") {
            return ("terminal.fill", nil, [Color(red: 0.15, green: 0.17, blue: 0.20), Color(red: 0.08, green: 0.09, blue: 0.11)])
        }
        if lower.contains("xcode") || lower.contains("code") {
            return ("chevron.left.forwardslash.chevron.right", nil, [Color(red: 0.14, green: 0.56, blue: 0.96), Color(red: 0.12, green: 0.36, blue: 0.86)])
        }
        if lower.contains("mail") || lower.contains("邮件") {
            return ("envelope.fill", nil, [Color(red: 0.22, green: 0.58, blue: 0.98), Color(red: 0.14, green: 0.42, blue: 0.92)])
        }
        if lower.contains("备忘") || lower.contains("notes") {
            return ("note.text", nil, [Color(red: 0.95, green: 0.72, blue: 0.16), Color(red: 0.88, green: 0.55, blue: 0.08)])
        }
        if lower.contains("slack") {
            return ("number", nil, [Color(red: 0.42, green: 0.18, blue: 0.48), Color(red: 0.28, green: 0.10, blue: 0.34)])
        }
        if lower.contains("typezero") || appName.isEmpty {
            return ("infinity", nil, [Color(red: 0.36, green: 0.33, blue: 0.92), Color(red: 0.24, green: 0.20, blue: 0.78)])
        }
        let initial = String(appName.prefix(1)).uppercased()
        return ("", initial, [Color(red: 0.38, green: 0.42, blue: 0.54), Color(red: 0.26, green: 0.29, blue: 0.38)])
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                .fill(LinearGradient(colors: spec.bg, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.7
                        )
                )
                .shadow(color: spec.bg[0].opacity(0.24), radius: 2.5, x: 0, y: 1.5)

            if let letter = spec.letter {
                Text(letter)
                    .font(TZFont.brand(11))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: spec.symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Monotone-Clamped KPI Micro-Sparkline With Glowing Terminal Dot

struct TZSparklineView: View {
    let values: [Double]
    let tint: Color

    private var smoothedPoints: [Double] {
        let raw = values.isEmpty ? [1, 2, 2, 3, 3, 4, 5] : values
        let total = raw.reduce(0, +)
        if total <= 0 {
            return [0.22, 0.32, 0.28, 0.46, 0.44, 0.64, 0.74]
        }
        var cumulative: [Double] = []
        var running: Double = 0
        for v in raw {
            running += max(v, total * 0.04)
            cumulative.append(running)
        }
        let maxC = max(cumulative.last ?? 1, 1)
        let maxR = max(raw.max() ?? 1, 1)
        return (0..<raw.count).map { idx in
            let cumNorm = cumulative[idx] / maxC
            let dayNorm = pow(raw[idx] / maxR, 0.6)
            return min(0.88, max(0.18, 0.16 + cumNorm * 0.52 + dayNorm * 0.22))
        }
    }

    var body: some View {
        Canvas { context, size in
            let pts = smoothedPoints
            guard pts.count >= 2 else { return }

            let padX: CGFloat = 3
            let padY: CGFloat = 3
            let usableW = size.width - padX * 2
            let usableH = size.height - padY * 2
            let stepX = usableW / CGFloat(pts.count - 1)
            let cgPts = pts.enumerated().map { idx, norm in
                CGPoint(
                    x: padX + CGFloat(idx) * stepX,
                    y: padY + usableH * (1.0 - CGFloat(norm))
                )
            }

            var slopes = Array(repeating: CGFloat(0), count: cgPts.count)
            for i in 0..<(cgPts.count - 1) {
                slopes[i] = (cgPts[i + 1].y - cgPts[i].y) / max(1, stepX)
            }
            var tangents = Array(repeating: CGFloat(0), count: cgPts.count)
            tangents[0] = slopes[0]
            tangents[cgPts.count - 1] = slopes[cgPts.count - 2]
            for i in 1..<(cgPts.count - 1) {
                tangents[i] = (slopes[i - 1] * slopes[i] <= 0) ? 0 : (slopes[i - 1] + slopes[i]) * 0.5
            }

            var linePath = Path()
            linePath.move(to: cgPts[0])
            for i in 0..<(cgPts.count - 1) {
                let p0 = cgPts[i]
                let p1 = cgPts[i + 1]
                linePath.addCurve(
                    to: p1,
                    control1: CGPoint(x: p0.x + stepX / 3.0, y: p0.y + tangents[i] * stepX / 3.0),
                    control2: CGPoint(x: p1.x - stepX / 3.0, y: p1.y - tangents[i + 1] * stepX / 3.0)
                )
            }

            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: cgPts.last!.x, y: size.height))
            fillPath.addLine(to: CGPoint(x: cgPts.first!.x, y: size.height))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.24), tint.opacity(0.0)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(
                linePath,
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.38), tint]),
                    startPoint: CGPoint(x: padX, y: size.height * 0.5),
                    endPoint: CGPoint(x: size.width - padX, y: size.height * 0.5)
                ),
                style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
            )

            if let last = cgPts.last {
                let glowRect = CGRect(x: last.x - 4.5, y: last.y - 4.5, width: 9, height: 9)
                context.fill(Path(ellipseIn: glowRect), with: .color(tint.opacity(0.28)))
                let dotRect = CGRect(x: last.x - 2.1, y: last.y - 2.1, width: 4.2, height: 4.2)
                context.fill(Path(ellipseIn: dotRect), with: .color(tint))
            }
        }
        .frame(width: 54, height: 22)
    }
}

// MARK: - Subtle Status & Permission Chips

struct TZPermissionPill: View {
    let title: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 4.5) {
            Circle()
                .fill(ok ? TZTheme.emerald : TZTheme.amber)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ok ? TZTheme.emerald : TZTheme.amber)
        }
        .padding(.horizontal, 8.5)
        .padding(.vertical, 3.5)
        .background(ok ? TZTheme.emeraldSoft : TZTheme.amberSoft)
        .clipShape(Capsule())
    }
}

struct TZInlineFeedbackBanner: View {
    let message: String
    var isWarning: Bool = false

    var body: some View {
        let isError = message.hasPrefix("❌")
        let fg: Color = isError ? TZTheme.crimson : (isWarning ? TZTheme.amber : TZTheme.emerald)
        let bg: Color = isError ? TZTheme.crimsonSoft : (isWarning ? TZTheme.amberSoft : TZTheme.emeraldSoft)

        Text(message)
            .font(TZFont.mono(11, weight: .medium))
            .foregroundStyle(fg)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
