#!/usr/bin/env swift
// Generate variant mockups for the compact menu-bar icon.
// Each variant shown at native size on both light and dark menu-bar strips,
// and at 6x zoom for pixel inspection.

import AppKit
import Foundation

let repo = FileManager.default.currentDirectoryPath
let mascotURL = URL(fileURLWithPath: repo).appendingPathComponent("ClaudeUsage/Resources/claudecode-color.png")
let mascot = NSImage(contentsOf: mascotURL)!

let coral = NSColor(red: 0.88, green: 0.45, blue: 0.30, alpha: 1.0)
let orange = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)

// Produce a monochrome (coral) silhouette of the mascot via tinting
func tintedMascot(_ color: NSColor, size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .none
    mascot.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                from: NSRect(origin: .zero, size: mascot.size),
                operation: .sourceOver, fraction: 1.0)
    color.set()
    NSRect(x: 0, y: 0, width: size, height: size).fill(using: .sourceAtop)
    img.unlockFocus()
    return img
}

// ── Variant A: mascot left + number right (pill), ~34×22 ──
func variantA(pct: Double, scale: CGFloat) -> NSImage {
    let h: CGFloat = 22 * scale
    let w: CGFloat = 34 * scale
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    NSGraphicsContext.current?.shouldAntialias = true

    // Background pill (dark, like current full widget)
    NSColor(white: 0.06, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 1 * scale, width: w, height: h - 2 * scale),
                 xRadius: 5 * scale, yRadius: 5 * scale).fill()

    // Mascot on left (native color), 16px equivalent
    NSGraphicsContext.current?.imageInterpolation = .none
    let mSize: CGFloat = 16 * scale
    mascot.draw(in: NSRect(x: 3 * scale, y: (h - mSize) / 2, width: mSize, height: mSize),
                from: NSRect(origin: .zero, size: mascot.size),
                operation: .sourceOver, fraction: 1.0)

    // Number on right
    NSGraphicsContext.current?.imageInterpolation = .high
    let pctNumber = "\(Int(round(pct)))"
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12 * scale, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: orange
    ]
    let ts = (pctNumber as NSString).size(withAttributes: attrs)
    let textX = 3 * scale + mSize + 2 * scale
    let availW = w - textX - 3 * scale
    (pctNumber as NSString).draw(
        at: NSPoint(x: textX + (availW - ts.width) / 2, y: (h - ts.height) / 2),
        withAttributes: attrs)
    img.unlockFocus()
    return img
}

// ── Variant B: monochrome mascot silhouette as background + number on top (22×22) ──
func variantB(pct: Double, scale: CGFloat) -> NSImage {
    let size: CGFloat = 22 * scale
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSGraphicsContext.current?.shouldAntialias = true

    // Faded coral silhouette
    let silhouette = tintedMascot(NSColor(white: 0.5, alpha: 0.45), size: size)
    silhouette.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                    from: .zero, operation: .sourceOver, fraction: 1.0)

    // Big bold number centered
    let pctNumber = "\(Int(round(pct)))"
    let fs: CGFloat = pctNumber.count == 1 ? 15 : (pctNumber.count == 2 ? 12 : 9)
    let font = NSFont.monospacedDigitSystemFont(ofSize: fs * scale, weight: .heavy)
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: orange, .paragraphStyle: p
    ]
    let ts = (pctNumber as NSString).size(withAttributes: attrs)
    (pctNumber as NSString).draw(
        in: NSRect(x: 0, y: (size - ts.height) / 2, width: size, height: ts.height),
        withAttributes: attrs)
    img.unlockFocus()
    return img
}

// ── Variant C: tiny mascot head-only (top) + number below in dark pill (22×22) ──
func variantC(pct: Double, scale: CGFloat) -> NSImage {
    let size: CGFloat = 22 * scale
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSGraphicsContext.current?.shouldAntialias = true

    NSColor(white: 0.06, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 1 * scale, width: size, height: size - 2 * scale),
                 xRadius: 4 * scale, yRadius: 4 * scale).fill()

    // Mascot as small icon on top half
    NSGraphicsContext.current?.imageInterpolation = .none
    let mW: CGFloat = 12 * scale
    let mH: CGFloat = 9 * scale
    mascot.draw(in: NSRect(x: (size - mW) / 2, y: size - mH - 2 * scale, width: mW, height: mH),
                from: NSRect(x: 0, y: mascot.size.height * 0.15,
                              width: mascot.size.width,
                              height: mascot.size.height * 0.5),
                operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.current?.imageInterpolation = .high
    let pctNumber = "\(Int(round(pct)))"
    let fs: CGFloat = pctNumber.count == 1 ? 10 : (pctNumber.count == 2 ? 8.5 : 7)
    let font = NSFont.monospacedDigitSystemFont(ofSize: fs * scale, weight: .heavy)
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: orange, .paragraphStyle: p
    ]
    let ts = (pctNumber as NSString).size(withAttributes: attrs)
    (pctNumber as NSString).draw(
        in: NSRect(x: 0, y: 2 * scale, width: size, height: ts.height),
        withAttributes: attrs)
    img.unlockFocus()
    return img
}

// ── Variant D: starburst Claude logo + number in small pill (22×22) ──
let starburstURL = URL(fileURLWithPath: repo).appendingPathComponent("ClaudeUsage/Resources/claude-logo.png")
let starburst = NSImage(contentsOf: starburstURL)!

func variantD(pct: Double, scale: CGFloat) -> NSImage {
    let size: CGFloat = 22 * scale
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSGraphicsContext.current?.shouldAntialias = true

    NSGraphicsContext.current?.imageInterpolation = .high
    starburst.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                   from: NSRect(origin: .zero, size: starburst.size),
                   operation: .sourceOver, fraction: 1.0)

    // Solid dark disc in center
    let discR: CGFloat = 8 * scale
    NSColor(white: 0.06, alpha: 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: size/2 - discR, y: size/2 - discR,
                                 width: discR * 2, height: discR * 2)).fill()

    let pctNumber = "\(Int(round(pct)))"
    let fs: CGFloat = pctNumber.count == 1 ? 11 : (pctNumber.count == 2 ? 9 : 7)
    let font = NSFont.monospacedDigitSystemFont(ofSize: fs * scale, weight: .heavy)
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: orange, .paragraphStyle: p
    ]
    let ts = (pctNumber as NSString).size(withAttributes: attrs)
    (pctNumber as NSString).draw(
        in: NSRect(x: 0, y: (size - ts.height) / 2, width: size, height: ts.height),
        withAttributes: attrs)
    img.unlockFocus()
    return img
}

// ── Compose the mockup sheet ──
struct Variant { let name: String; let render: (Double, CGFloat) -> NSImage; let nativeW: CGFloat }
let variants: [Variant] = [
    Variant(name: "A  mascot + number (pill, 34x22)", render: variantA, nativeW: 34),
    Variant(name: "B  mascot silhouette + big number (22x22)", render: variantB, nativeW: 22),
    Variant(name: "C  mini mascot over number (22x22)", render: variantC, nativeW: 22),
    Variant(name: "D  starburst + number disc (22x22)", render: variantD, nativeW: 22),
]
let samples: [Double] = [8, 38, 100]
let scale: CGFloat = 6
let rowPad: CGFloat = 24
let labelH: CGFloat = 22
let gap: CGFloat = 18
let maxRowW = variants.map { rowPad * 2 + $0.nativeW * scale * 3 + gap * 2 }.max()!
let sheetW = maxRowW
let rowHeight = labelH + labelH + 22 + labelH + 22 * scale + rowPad
let sheetH = rowPad + CGFloat(variants.count) * rowHeight

let sheet = NSImage(size: NSSize(width: sheetW, height: sheetH))
sheet.lockFocus()
NSColor(white: 0.15, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
    .foregroundColor: NSColor.white
]
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 10, weight: .regular),
    .foregroundColor: NSColor(white: 0.7, alpha: 1.0)
]

for (idx, v) in variants.enumerated() {
    let rowY = sheetH - rowPad - CGFloat(idx + 1) * rowHeight
    // Variant title
    (v.name as NSString).draw(at: NSPoint(x: rowPad, y: rowY + rowHeight - labelH),
                              withAttributes: titleAttrs)
    // "Native" label
    ("native 22h:" as NSString).draw(at: NSPoint(x: rowPad, y: rowY + rowHeight - labelH * 2),
                                      withAttributes: subAttrs)

    // Native samples on a light menu-bar strip
    let stripY = rowY + rowHeight - labelH * 2 - 24
    let stripH: CGFloat = 24
    NSColor(white: 0.93, alpha: 1.0).setFill()
    NSRect(x: rowPad, y: stripY, width: sheetW - rowPad * 2, height: stripH).fill()
    for (i, pct) in samples.enumerated() {
        let native = v.render(pct, 1)
        let x = rowPad + 12 + CGFloat(i) * (v.nativeW + 22)
        native.draw(in: NSRect(x: x, y: stripY + (stripH - 22) / 2, width: v.nativeW, height: 22),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    // Native samples on dark strip (beneath)
    let darkY = stripY - stripH - 2
    NSColor(white: 0.10, alpha: 1.0).setFill()
    NSRect(x: rowPad, y: darkY, width: sheetW - rowPad * 2, height: stripH).fill()
    for (i, pct) in samples.enumerated() {
        let native = v.render(pct, 1)
        let x = rowPad + 12 + CGFloat(i) * (v.nativeW + 22)
        native.draw(in: NSRect(x: x, y: darkY + (stripH - 22) / 2, width: v.nativeW, height: 22),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // Zoomed row
    let zoomY = darkY - 22 * scale - 8
    for (i, pct) in samples.enumerated() {
        let zoomed = v.render(pct, scale)
        let x = rowPad + CGFloat(i) * (v.nativeW * scale + gap)
        zoomed.draw(in: NSRect(x: x, y: zoomY, width: v.nativeW * scale, height: 22 * scale),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
        let lbl = "\(Int(pct))%"
        (lbl as NSString).draw(at: NSPoint(x: x, y: zoomY - 14), withAttributes: subAttrs)
    }
}

sheet.unlockFocus()
guard let tiff = sheet.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
let outURL = URL(fileURLWithPath: repo).appendingPathComponent("images/compact-variants.png")
try png.write(to: outURL)
print("Wrote \(outURL.path)")
