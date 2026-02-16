#!/usr/bin/env swift

import AppKit
import CoreGraphics

func generateIcon(pixelSize: Int) -> NSBitmapImageRep {
    let s = CGFloat(pixelSize)
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
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let ctx = context.cgContext

    // Black background with rounded rect
    let inset = s * 0.12
    let bgRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = s * 0.2
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.addPath(bgPath)
    ctx.fillPath()

    // White rounded border (inner)
    let borderInset = s * 0.15
    let borderRect = CGRect(x: borderInset, y: borderInset, width: s - borderInset * 2, height: s - borderInset * 2)
    let borderCorner = s * 0.18
    let borderPath = CGPath(roundedRect: borderRect, cornerWidth: borderCorner, cornerHeight: borderCorner, transform: nil)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(s * 0.02)
    ctx.addPath(borderPath)
    ctx.strokePath()

    // Pen icon
    let penLineWidth = s * 0.04
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(penLineWidth)

    let centerX = s / 2
    let centerY = s / 2
    let penLength = s * 0.28

    let tipX = centerX - penLength * 0.7
    let tipY = centerY - penLength * 0.7
    let topX = centerX + penLength * 0.7
    let topY = centerY + penLength * 0.7

    // Pen body
    ctx.move(to: CGPoint(x: tipX, y: tipY))
    ctx.addLine(to: CGPoint(x: topX, y: topY))
    ctx.strokePath()

    // Pen nib
    let nibSize = s * 0.06
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.move(to: CGPoint(x: tipX, y: tipY))
    ctx.addLine(to: CGPoint(x: tipX + nibSize, y: tipY + nibSize * 0.3))
    ctx.addLine(to: CGPoint(x: tipX + nibSize * 0.3, y: tipY + nibSize))
    ctx.closePath()
    ctx.fillPath()

    // Pen grip lines
    let gripOffset1 = penLength * 0.35
    let gripOffset2 = penLength * 0.45
    let gripLen = s * 0.04
    let perpX = -0.707 * gripLen
    let perpY = 0.707 * gripLen

    for offset in [gripOffset1, gripOffset2] {
        let gx = tipX + 0.707 * offset * 2
        let gy = tipY + 0.707 * offset * 2
        ctx.move(to: CGPoint(x: gx + perpX, y: gy + perpY))
        ctx.addLine(to: CGPoint(x: gx - perpX, y: gy - perpY))
    }
    ctx.setLineWidth(s * 0.015)
    ctx.strokePath()

    NSGraphicsContext.current = nil
    return rep
}

func savePNG(_ rep: NSBitmapImageRep, path: String) {
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to generate PNG: \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Generated: \(path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

let outputDir = "QuickNote/Assets.xcassets/AppIcon.appiconset"

for size in [128, 256, 512, 1024] {
    let rep = generateIcon(pixelSize: size)
    savePNG(rep, path: "\(outputDir)/icon_\(size).png")
}

print("Done!")
