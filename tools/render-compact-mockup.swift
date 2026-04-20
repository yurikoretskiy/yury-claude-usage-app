#!/usr/bin/env swift
// Standalone mockup generator for the compact menu-bar icon.
// Renders 3 samples (8%, 38%, 100%) both at native 22x22 and 4x zoom,
// on a neutral background to preview against the macOS menu bar.
//
// Run: swift tools/render-compact-mockup.swift
// Output: images/compact-mockup.png

import AppKit
import Foundation

let repoRoot = FileManager.default.currentDirectoryPath
let mascotURL = URL(fileURLWithPath: repoRoot)
    .appendingPathComponent("ClaudeUsage/Resources/claudecode-color.png")
guard let mascot = NSImage(contentsOf: mascotURL) else {
    FileHandle.standardError.write("Could not load \(mascotURL.path)\n".data(using: .utf8)!)
    exit(1)
}

func renderCompact(percentage: Double, size: CGFloat) -> NSImage {
    let pctNumber = "\(Int(round(percentage)))"
    let baseFontSize: CGFloat
    switch pctNumber.count {
    case 1:  baseFontSize = 12
    case 2:  baseFontSize = 10
    default: baseFontSize = 8
    }
    // Scale font to match canvas size (base canvas = 22)
    let fontSize = baseFontSize * (size / 22.0)
    let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .heavy)

    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.shouldAntialias = true
    NSGraphicsContext.current?.imageInterpolation = .none

    mascot.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                from: NSRect(origin: .zero, size: mascot.size),
                operation: .sourceOver,
                fraction: 1.0)

    NSGraphicsContext.current?.shouldAntialias = true
    NSGraphicsContext.current?.imageInterpolation = .high

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .strokeColor: NSColor(white: 0, alpha: 0.55),
        .strokeWidth: -8,
        .paragraphStyle: paragraph
    ]
    let textSize = (pctNumber as NSString).size(withAttributes: attrs)
    let torsoCenterY = size * 0.42
    let textRect = NSRect(x: 0, y: torsoCenterY - textSize.height / 2,
                          width: size, height: textSize.height)
    (pctNumber as NSString).draw(in: textRect, withAttributes: attrs)

    image.unlockFocus()
    return image
}

// Mockup layout: white background strip (simulating light menu bar) + dark background strip
let samples: [Double] = [8, 38, 100]
let native: CGFloat = 22
let zoom: CGFloat = 6  // 6x zoom for visibility
let gap: CGFloat = 20
let pad: CGFloat = 24

// Top row: native size on light bg. Bottom row: 6x zoom on dark bg.
let zoomed = native * zoom
let rowWidth = pad * 2 + CGFloat(samples.count) * zoomed + CGFloat(samples.count - 1) * gap
let labelH: CGFloat = 22
let rowH = labelH + zoomed + labelH
let totalH = pad + labelH + native + pad + rowH + pad

let canvas = NSImage(size: NSSize(width: rowWidth, height: totalH))
canvas.lockFocus()

// Full background (dark)
NSColor(white: 0.12, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: rowWidth, height: totalH).fill()

// Top strip: simulated menu bar (near-white)
let topStripRect = NSRect(x: 0, y: totalH - pad - labelH - native - pad / 2,
                          width: rowWidth, height: native + pad)
NSColor(white: 0.95, alpha: 1.0).setFill()
topStripRect.fill()

let labelAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor(white: 0.3, alpha: 1.0)
]
let darkLabelAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor(white: 0.85, alpha: 1.0)
]

// Draw native-size icons on top strip, centered horizontally across the strip
let nativeSpacing = (rowWidth - CGFloat(samples.count) * native) / CGFloat(samples.count + 1)
for (i, pct) in samples.enumerated() {
    let img = renderCompact(percentage: pct, size: native)
    let x = nativeSpacing + CGFloat(i) * (native + nativeSpacing)
    let y = totalH - pad - native
    img.draw(in: NSRect(x: x, y: y, width: native, height: native),
             from: .zero, operation: .sourceOver, fraction: 1.0)
}
// Label above native row
("Native 22x22 (actual menu-bar size)" as NSString).draw(
    at: NSPoint(x: pad, y: totalH - pad / 2 - 8),
    withAttributes: labelAttrs
)

// Bottom section: 6x zoomed icons on dark bg
let zoomY = pad + labelH
for (i, pct) in samples.enumerated() {
    let img = renderCompact(percentage: pct, size: zoomed)
    let x = pad + CGFloat(i) * (zoomed + gap)
    img.draw(in: NSRect(x: x, y: zoomY, width: zoomed, height: zoomed),
             from: .zero, operation: .sourceOver, fraction: 1.0)
    let label = "\(Int(pct))%"
    let lblSize = (label as NSString).size(withAttributes: darkLabelAttrs)
    (label as NSString).draw(
        at: NSPoint(x: x + (zoomed - lblSize.width) / 2, y: zoomY - labelH + 4),
        withAttributes: darkLabelAttrs
    )
}
("6x zoom (pixel detail)" as NSString).draw(
    at: NSPoint(x: pad, y: zoomY + zoomed + 4),
    withAttributes: darkLabelAttrs
)

canvas.unlockFocus()

// Export
guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
let outDir = URL(fileURLWithPath: repoRoot).appendingPathComponent("images")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let outURL = outDir.appendingPathComponent("compact-mockup.png")
try png.write(to: outURL)
print("Wrote \(outURL.path)")
