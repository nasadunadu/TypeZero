#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

/// Renders the TypeZero 2.0 flagship macOS squircle icon:
/// Deep Sapphire-Indigo optical crystal squircle + razor-sharp 3D woven Pure-White/Ice-Silver Möbius ribbon.
/// Unified 1:1 with `TZBrandEmblemView` & `MobiusMarkView` across Sidebar, Menu Bar, Dock, and Finder.
func renderMobiusIcon(pixelSize: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let cg = nsCtx.cgContext
    let s = CGFloat(pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)
    cg.interpolationQuality = .high

    // 1. Apple macOS standard icon inset & continuous squircle card
    let pad = s * 0.095
    let cardRect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let cardSide = cardRect.width
    let corner = cardSide * 0.24
    let squirclePath = CGPath(roundedRect: cardRect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Crisp outer drop shadow
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -s * 0.022),
        blur: s * 0.042,
        color: NSColor(calibratedRed: 0.08, green: 0.06, blue: 0.32, alpha: 0.28).cgColor
    )
    cg.addPath(squirclePath)
    cg.setFillColor(NSColor(calibratedRed: 0.28, green: 0.24, blue: 0.90, alpha: 1.0).cgColor)
    cg.fillPath()
    cg.restoreGState()

    // 2. Clipped Sapphire-Indigo Optical Crystal Body
    cg.saveGState()
    cg.addPath(squirclePath)
    cg.clip()

    // Diagonal jewel base: Top-Left (#544AEF) -> Mid (#3B31D6) -> Bottom-Right (#1C178A)
    let bgColors = [
        NSColor(calibratedRed: 0.33, green: 0.29, blue: 0.94, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.23, green: 0.19, blue: 0.84, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.11, green: 0.09, blue: 0.54, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.52, 1.0])!
    cg.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
        end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
        options: []
    )

    // Subtle bottom-right cyan-sapphire optical crystal refraction
    let causticColors = [
        NSColor(calibratedRed: 0.22, green: 0.74, blue: 0.98, alpha: 0.34).cgColor,
        NSColor(calibratedRed: 0.26, green: 0.56, blue: 1.00, alpha: 0.09).cgColor,
        NSColor(calibratedRed: 0.26, green: 0.56, blue: 1.00, alpha: 0.00).cgColor
    ] as CFArray
    let causticGrad = CGGradient(colorsSpace: colorSpace, colors: causticColors, locations: [0.0, 0.55, 1.0])!
    let causticCenter = CGPoint(x: cardRect.minX + cardSide * 0.86, y: cardRect.minY + cardSide * 0.14)
    cg.drawRadialGradient(
        causticGrad,
        startCenter: causticCenter,
        startRadius: 0,
        endCenter: causticCenter,
        endRadius: cardSide * 0.72,
        options: []
    )

    // Clean top curved optical-glass specular meniscus
    let sheenColors = [
        NSColor(calibratedWhite: 1.0, alpha: 0.28).cgColor,
        NSColor(calibratedWhite: 1.0, alpha: 0.06).cgColor,
        NSColor(calibratedWhite: 1.0, alpha: 0.00).cgColor
    ] as CFArray
    let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 0.45, 1.0])!
    cg.drawLinearGradient(
        sheenGrad,
        start: CGPoint(x: cardRect.midX, y: cardRect.maxY),
        end: CGPoint(x: cardRect.midX, y: cardRect.midY - cardSide * 0.02),
        options: []
    )

    // 3. Razor-Sharp 3D Woven Pure-White / Ice-Silver Möbius Centerpiece (0.000 pole seam architecture!)
    let cx = s * 0.5
    let cy = s * 0.5
    let glyphBox = cardSide * 0.76
    let rx = glyphBox * 0.39
    let ry = glyphBox * 0.40
    let strokeW = max(2.2, glyphBox * 0.148)

    // CoreGraphics has +Y pointing UP, so negate Y relative to SwiftUI to keep exact same orientation
    func mobiusPoint(_ t: Double) -> CGPoint {
        let st = sin(t)
        let ct = cos(t)
        let denom = 1.0 + 0.72 * st * st
        let x = cx + rx * CGFloat(ct / denom)
        let y = cy - ry * CGFloat((1.65 * st * ct) / denom)
        return CGPoint(x: x, y: y)
    }

    func makeArc(from startT: Double, to endT: Double, steps: Int, closed: Bool = false) -> CGPath {
        let p = CGMutablePath()
        for i in 0...steps {
            let t = startT + (endT - startT) * Double(i) / Double(steps)
            let pt = mobiusPoint(t)
            if i == 0 {
                p.move(to: pt)
            } else {
                p.addLine(to: pt)
            }
        }
        if closed { p.closeSubpath() }
        return p
    }

    let fullLoop = makeArc(from: 0, to: Double.pi * 2.0, steps: 200, closed: true)
    let backCrossArm = makeArc(from: Double.pi * 1.5 - 0.85, to: Double.pi * 1.5 + 0.85, steps: 64)
    let frontCrossArm = makeArc(from: Double.pi * 0.5 - 0.74, to: Double.pi * 0.5 + 0.74, steps: 60)
    let crossingShadowBar = makeArc(from: Double.pi * 0.5 - 0.34, to: Double.pi * 0.5 + 0.34, steps: 32)

    // Unified top-left-lit pearl-white gradient shared IDENTICALLY by fullLoop & frontCrossArm
    let topY = cy + ry * 0.65 + strokeW * 0.5
    let botY = cy - ry * 0.65 - strokeW * 0.5
    let unifiedRibbonColors = [
        NSColor(calibratedWhite: 1.00, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.965, green: 0.980, blue: 1.00, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.855, green: 0.900, blue: 1.00, alpha: 1.0).cgColor
    ] as CFArray
    let unifiedRibbonGrad = CGGradient(colorsSpace: colorSpace, colors: unifiedRibbonColors, locations: [0.0, 0.52, 1.0])!
    let gradStart = CGPoint(x: cx - rx * 0.25, y: topY)
    let gradEnd = CGPoint(x: cx + rx * 0.25, y: botY)

    // Soft tight shadow cast by the entire Möbius sculpture onto the sapphire bed
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -cardSide * 0.026),
        blur: cardSide * 0.036,
        color: NSColor(calibratedRed: 0.04, green: 0.03, blue: 0.24, alpha: 0.46).cgColor
    )
    cg.addPath(fullLoop)
    cg.setStrokeColor(NSColor(calibratedRed: 0.92, green: 0.95, blue: 1.00, alpha: 1.0).cgColor)
    cg.setLineWidth(strokeW * 0.94)
    cg.setLineJoin(.round)
    cg.strokePath()
    cg.restoreGState()

    // 3a. Pass 1: Continuous unbroken Möbius base (ZERO seams at 9 & 3 o'clock!)
    let fullOutline = fullLoop.copy(strokingWithWidth: strokeW, lineCap: .round, lineJoin: .round, miterLimit: 4)
    cg.saveGState()
    cg.addPath(fullOutline)
    cg.clip()
    cg.drawLinearGradient(unifiedRibbonGrad, start: gradStart, end: gradEnd, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    cg.restoreGState()

    // 3b. Pass 2: Smooth localized 3D underpass shading + cast shadow strictly clipped to backCrossArm
    // Both fade to 0.000 alpha long before the arm endpoints -> ZERO butt-cap crease!
    let backOutline = backCrossArm.copy(strokingWithWidth: strokeW, lineCap: .butt, lineJoin: .round, miterLimit: 4)
    cg.saveGState()
    cg.addPath(backOutline)
    cg.clip()

    let recessColors = [
        NSColor(calibratedRed: 0.22, green: 0.30, blue: 0.74, alpha: 0.46).cgColor,
        NSColor(calibratedRed: 0.34, green: 0.42, blue: 0.84, alpha: 0.16).cgColor,
        NSColor(calibratedRed: 0.34, green: 0.42, blue: 0.84, alpha: 0.00).cgColor
    ] as CFArray
    let recessGrad = CGGradient(colorsSpace: colorSpace, colors: recessColors, locations: [0.0, 0.50, 1.0])!
    cg.drawRadialGradient(
        recessGrad,
        startCenter: CGPoint(x: cx, y: cy),
        startRadius: 0,
        endCenter: CGPoint(x: cx, y: cy),
        endRadius: strokeW * 1.60,
        options: []
    )

    cg.saveGState()
    cg.setShadow(
        offset: .zero,
        blur: max(1.0, strokeW * 0.30),
        color: NSColor(calibratedRed: 0.05, green: 0.04, blue: 0.34, alpha: 0.74).cgColor
    )
    cg.addPath(crossingShadowBar)
    cg.setStrokeColor(NSColor(calibratedRed: 0.07, green: 0.05, blue: 0.40, alpha: 0.70).cgColor)
    cg.setLineWidth(strokeW * 1.44)
    cg.setLineCap(.round)
    cg.strokePath()
    cg.restoreGState()
    cg.restoreGState()

    // 3c. Pass 3: Redraw front overpass arm with the EXACT same unified gradient (zero endpoint seam!)
    let frontOutline = frontCrossArm.copy(strokingWithWidth: strokeW, lineCap: .butt, lineJoin: .round, miterLimit: 4)
    cg.saveGState()
    cg.addPath(frontOutline)
    cg.clip()
    cg.drawLinearGradient(unifiedRibbonGrad, start: gradStart, end: gradEnd, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // 3d. Whisper-clean luminous crown highlight right on the central front overpass
    let crownColors = [
        NSColor(calibratedWhite: 1.0, alpha: 0.55).cgColor,
        NSColor(calibratedWhite: 1.0, alpha: 0.00).cgColor
    ] as CFArray
    let crownGrad = CGGradient(colorsSpace: colorSpace, colors: crownColors, locations: [0.0, 1.0])!
    let crownCenter = CGPoint(x: cx - strokeW * 0.12, y: cy + strokeW * 0.18)
    cg.drawRadialGradient(
        crownGrad,
        startCenter: crownCenter,
        startRadius: 0,
        endCenter: crownCenter,
        endRadius: strokeW * 1.32,
        options: []
    )
    cg.restoreGState()

    // 4. Precision-cut inner bevel rim
    let bevelWidth = max(1.0, cardSide * 0.022)
    let insetRect = cardRect.insetBy(dx: bevelWidth * 0.5, dy: bevelWidth * 0.5)
    let bevelPath = CGPath(roundedRect: insetRect, cornerWidth: max(2, corner - bevelWidth * 0.5), cornerHeight: max(2, corner - bevelWidth * 0.5), transform: nil)
    let bevelStroke = bevelPath.copy(strokingWithWidth: bevelWidth, lineCap: .round, lineJoin: .round, miterLimit: 4)
    cg.saveGState()
    cg.addPath(bevelStroke)
    cg.clip()
    let bevelColors = [
        NSColor(calibratedWhite: 1.0, alpha: 0.66).cgColor,
        NSColor(calibratedRed: 0.66, green: 0.74, blue: 1.00, alpha: 0.24).cgColor,
        NSColor(calibratedRed: 0.07, green: 0.05, blue: 0.34, alpha: 0.48).cgColor
    ] as CFArray
    let bevelGrad = CGGradient(colorsSpace: colorSpace, colors: bevelColors, locations: [0.0, 0.48, 1.0])!
    cg.drawLinearGradient(
        bevelGrad,
        start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
        end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
        options: []
    )
    cg.restoreGState()

    cg.restoreGState() // end squircle clip

    // Crisp outer dark-indigo hairline anchor
    cg.addPath(squirclePath)
    cg.setStrokeColor(NSColor(calibratedRed: 0.14, green: 0.11, blue: 0.52, alpha: 0.24).cgColor)
    cg.setLineWidth(max(1.0, s * 0.004))
    cg.strokePath()

    NSGraphicsContext.restoreGraphicsState()

    let pngData = rep.representation(using: .png, properties: [:])!
    try pngData.write(to: url)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("Usage: generate-icon.swift <output-iconset-dir>\n", stderr)
    exit(1)
}

let iconsetDir = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let specs: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for spec in specs {
    try renderMobiusIcon(pixelSize: spec.px, to: iconsetDir.appendingPathComponent(spec.name))
}
print("Generated TypeZero 2.0 Sapphire-Indigo 3D Möbius iconset at \(iconsetDir.path)")
