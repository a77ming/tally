#!/usr/bin/env swift
// Renders the Tally app icon into build/icon.iconset/*.png plus a 512px preview.
// Run from repo root: swift Scripts/make-icon.swift

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let canvas: CGFloat = 1024

// MARK: - Squircle (continuous-corner approximation)

/// Superellipse-style rounded rect, approximating Apple's continuous corners.
func squirclePath(in rect: CGRect, cornerRadius r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let k: CGFloat = 0.55 // smoothing of the corner handles
    let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY

    path.move(to: CGPoint(x: minX + r, y: maxY))
    // top edge -> top-right corner
    path.addLine(to: CGPoint(x: maxX - r, y: maxY))
    path.addCurve(to: CGPoint(x: maxX, y: maxY - r),
                  control1: CGPoint(x: maxX - r * (1 - k), y: maxY),
                  control2: CGPoint(x: maxX, y: maxY - r * (1 - k)))
    // right edge -> bottom-right corner
    path.addLine(to: CGPoint(x: maxX, y: minY + r))
    path.addCurve(to: CGPoint(x: maxX - r, y: minY),
                  control1: CGPoint(x: maxX, y: minY + r * (1 - k)),
                  control2: CGPoint(x: maxX - r * (1 - k), y: minY))
    // bottom edge -> bottom-left corner
    path.addLine(to: CGPoint(x: minX + r, y: minY))
    path.addCurve(to: CGPoint(x: minX, y: minY + r),
                  control1: CGPoint(x: minX + r * (1 - k), y: minY),
                  control2: CGPoint(x: minX, y: minY + r * (1 - k)))
    // left edge -> top-left corner
    path.addLine(to: CGPoint(x: minX, y: maxY - r))
    path.addCurve(to: CGPoint(x: minX + r, y: maxY),
                  control1: CGPoint(x: minX, y: maxY - r * (1 - k)),
                  control2: CGPoint(x: minX + r * (1 - k), y: maxY))
    path.closeSubpath()
    return path
}

func capsulePath(in rect: CGRect) -> CGPath {
    let r = min(rect.width, rect.height) / 2
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}

func srgb(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha)
}

// MARK: - Master render at 1024x1024

func renderMaster() -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil,
                        width: Int(canvas), height: Int(canvas),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high

    // Background squircle: inset ~100px, corner radius ~185 (185/824 of the shape).
    let inset: CGFloat = 100
    let shapeRect = CGRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    let cornerRadius = shapeRect.width * 185.0 / 824.0
    let shape = squirclePath(in: shapeRect, cornerRadius: cornerRadius)

    // Vertical gradient: #E8835B (top) -> #C25B36 (bottom).
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let bgGradient = CGGradient(colorsSpace: colorSpace,
                                colors: [srgb(0xE8835B), srgb(0xC25B36)] as CFArray,
                                locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: canvas / 2, y: shapeRect.maxY),
                           end: CGPoint(x: canvas / 2, y: shapeRect.minY),
                           options: [])

    // Soft white sheen on the top half, ~8% -> transparent.
    let sheen = CGGradient(colorsSpace: colorSpace,
                           colors: [srgb(0xFFFFFF, alpha: 0.08), srgb(0xFFFFFF, alpha: 0.0)] as CFArray,
                           locations: [0.0, 1.0])!
    ctx.drawLinearGradient(sheen,
                           start: CGPoint(x: canvas / 2, y: shapeRect.maxY),
                           end: CGPoint(x: canvas / 2, y: shapeRect.midY),
                           options: [])
    ctx.restoreGState()

    // Three vertical rounded-capped white bars, vertically centered.
    let innerHeight = shapeRect.height
    let barWidth = canvas * 0.09
    let gap = canvas * 0.07
    let heights: [CGFloat] = [0.45, 0.70, 0.55].map { $0 * innerHeight }
    let totalWidth = barWidth * 3 + gap * 2
    var x = (canvas - totalWidth) / 2
    let centerY = canvas / 2

    ctx.saveGState()
    // Subtle drop shadow: black 15%, blur 12, visually offset 4px downward.
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: srgb(0x000000, alpha: 0.15))
    ctx.setFillColor(srgb(0xFFFFFF, alpha: 0.96))
    for h in heights {
        let bar = CGRect(x: x, y: centerY - h / 2, width: barWidth, height: h)
        ctx.addPath(capsulePath(in: bar))
        ctx.fillPath()
        x += barWidth + gap
    }
    ctx.restoreGState()

    return ctx.makeImage()!
}

// MARK: - Scaling + PNG output

func scaled(_ image: CGImage, to size: Int) -> CGImage {
    if size == Int(canvas) { return image }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Cannot create PNG destination at \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("Failed to write \(url.path)")
    }
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/icon.iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let master = renderMaster()

// Required iconset entries: (filename, pixel size)
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in entries {
    writePNG(scaled(master, to: size), to: iconset.appendingPathComponent(name))
}

// 512px preview for the README.
writePNG(scaled(master, to: 512), to: root.appendingPathComponent("build/icon-preview.png"))

print("✓ build/icon.iconset (\(entries.count) sizes) + build/icon-preview.png")
