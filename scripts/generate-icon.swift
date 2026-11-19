#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

/// Renders a high-craft macOS squircle icon with a warm-ivory porcelain surface
/// and an abstract 3D twisted Möbius ribbon (zero dark-background clichés).
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

    cg.setAllowsAntialiasing(true)
    cg.setShouldAntialias(true)

    // 1. Apple macOS standard icon inset & continuous squircle card (light porcelain finish)
    let pad = s * 0.095
    let cardRect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let corner = cardRect.width * 0.225
    let squircle = NSBezierPath(roundedRect: cardRect, xRadius: corner, yRadius: corner)

    // Soft drop shadow
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -s * 0.02),
        blur: s * 0.045,
        color: NSColor(calibratedWhite: 0.0, alpha: 0.16).cgColor
    )
    NSColor(calibratedRed: 0.985, green: 0.984, blue: 0.978, alpha: 1.0).setFill()
    squircle.fill()
    cg.restoreGState()

    // Subtle warm ivory-to-pearl gradient surface
    cg.saveGState()
    squircle.addClip()
    let bgColors = [
        NSColor(calibratedRed: 0.996, green: 0.995, blue: 0.992, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.945, green: 0.950, blue: 0.968, alpha: 1.0).cgColor
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    cg.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: s * 0.5, y: s - pad),
        end: CGPoint(x: s * 0.5, y: pad),
        options: []
    )

    // Soft ambient radial glow behind the Möbius ribbon
    let glowColors = [
        NSColor(calibratedRed: 0.35, green: 0.28, blue: 0.95, alpha: 0.10).cgColor,
        NSColor(calibratedRed: 0.10, green: 0.45, blue: 1.00, alpha: 0.0).cgColor
    ] as CFArray
    let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    cg.drawRadialGradient(
        glowGrad,
        startCenter: CGPoint(x: s * 0.5, y: s * 0.5),
        startRadius: 0,
        endCenter: CGPoint(x: s * 0.5, y: s * 0.5),
        endRadius: s * 0.36,
        options: []
    )

    // 2. Render 3D Twisted Sculptural Möbius Strip using layered ribbon segments for true over/under depth
    let cx = s * 0.5
    let cy = s * 0.5
    let scaleX = s * 0.285
    let scaleY = s * 0.255
    let ribbonBaseWidth = s * 0.088
    let totalSteps = 360

    // Helper for parametric twisted Möbius-Lemniscate curve rotated slightly (-14 deg) for sculptural elegance
    let tilt = -14.0 * Double.pi / 180.0
    func pointAt(_ t: Double) -> (pt: CGPoint, depth: Double, twistWidth: CGFloat) {
        let denom = 1.0 + 0.72 * pow(sin(t), 2)
        let rawX = Double(scaleX) * cos(t) / denom
        let rawY = Double(scaleY) * 1.48 * (sin(t) * cos(t)) / denom
        let rx = rawX * cos(tilt) - rawY * sin(tilt)
        let ry = rawX * sin(tilt) + rawY * cos(tilt)
        // Depth z oscillates across the central crossing so one strand cleanly passes OVER the other
        let z = sin(t)
        // Möbius half-twist modulates apparent ribbon thickness smoothly
        let widthFactor = CGFloat(0.66 + 0.34 * abs(cos(t * 0.5 + 0.4)))
        return (CGPoint(x: cx + CGFloat(rx), y: cy + CGFloat(ry)), z, ribbonBaseWidth * widthFactor)
    }

    // Sort segments back-to-front by z-depth so crossing looks genuinely 3D woven
    struct Segment {
        let p0: CGPoint
        let p1: CGPoint
        let z: Double
        let t: Double
        let width: CGFloat
    }

    var segments: [Segment] = []
    for i in 0..<totalSteps {
        let t0 = Double(i) / Double(totalSteps) * Double.pi * 2.0
        let t1 = Double(i + 1) / Double(totalSteps) * Double.pi * 2.0
        let a = pointAt(t0)
        let b = pointAt(t1)
        segments.append(Segment(p0: a.pt, p1: b.pt, z: (a.depth + b.depth) * 0.5, t: t0, width: (a.twistWidth + b.twistWidth) * 0.5))
    }

    // Subtle soft shadow under the entire Möbius sculpture
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -s * 0.018),
        blur: s * 0.028,
        color: NSColor(calibratedRed: 0.14, green: 0.22, blue: 0.58, alpha: 0.24).cgColor
    )
    let shadowPath = CGMutablePath()
    for (idx, seg) in segments.enumerated() {
        if idx == 0 { shadowPath.move(to: seg.p0) }
        shadowPath.addLine(to: seg.p1)
    }
    shadowPath.closeSubpath()
    cg.addPath(shadowPath)
    cg.setStrokeColor(NSColor(calibratedRed: 0.20, green: 0.38, blue: 0.95, alpha: 0.25).cgColor)
    cg.setLineWidth(ribbonBaseWidth * 0.85)
    cg.setLineCap(.round)
    cg.strokePath()
    cg.restoreGState()

    // Draw sorted 3D Möbius ribbon segments (underpass darker indigo, overpass luminous cobalt-violet)
    let sortedSegments = segments.sorted { $0.z < $1.z }
    for seg in sortedSegments {
        let phase = (sin(seg.t - 0.6) + 1.0) * 0.5
        let depthLift = (seg.z + 1.0) * 0.5 // 0 = back strand, 1 = front strand

        // Rich gradient from Electric Cobalt (#1864FF) -> Royal Violet (#5A46E8) -> Sky Cyan (#2294FF)
        let r = 0.09 + 0.27 * phase + 0.05 * depthLift
        let g = 0.36 - 0.10 * phase + 0.18 * depthLift
        let b = 0.94 + 0.05 * depthLift

        // Slight dark ambient occlusion right under the crossing on the back strand
        let shade = 0.78 + 0.22 * depthLift

        cg.setStrokeColor(NSColor(calibratedRed: r * shade, green: g * shade, blue: min(1.0, b * shade), alpha: 1.0).cgColor)
        cg.setLineWidth(seg.width)
        cg.setLineCap(.round)
        cg.move(to: seg.p0)
        cg.addLine(to: seg.p1)
        cg.strokePath()
    }

    // Specular silk rim highlight on the upper-front overpass curve
    for seg in sortedSegments where seg.z > 0.25 {
        let alpha = CGFloat((seg.z - 0.25) / 0.75) * 0.42
        cg.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: alpha).cgColor)
        cg.setLineWidth(seg.width * 0.20)
        cg.setLineCap(.round)
        cg.move(to: CGPoint(x: seg.p0.x, y: seg.p0.y + seg.width * 0.22))
        cg.addLine(to: CGPoint(x: seg.p1.x, y: seg.p1.y + seg.width * 0.22))
        cg.strokePath()
    }

    cg.restoreGState()

    // Crisp hairline border on squircle
    NSColor(calibratedWhite: 0.0, alpha: 0.07).setStroke()
    squircle.lineWidth = max(1.0, s * 0.004)
    squircle.stroke()

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
print("Generated Möbius iconset at \(iconsetDir.path)")
