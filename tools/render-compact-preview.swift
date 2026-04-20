#!/usr/bin/env swift
// Preview the current compact icon — simply draws the template PNG and
// overlays the percentage, matching the production renderer exactly.

import AppKit
import Foundation

let repo = FileManager.default.currentDirectoryPath
let tmplURL = URL(fileURLWithPath: repo).appendingPathComponent("ClaudeUsage/Resources/compact-mascot.png")
let template = NSImage(contentsOf: tmplURL)!
let orange = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)

func renderCompact(percentage: Double, size: CGFloat) -> NSImage {
    let scale = size / 22
    let pctNumber = "\(Int(round(percentage)))"
    let baseFont: CGFloat
    switch pctNumber.count {
    case 1:  baseFont = 11
    case 2:  baseFont = 9
    default: baseFont = 7
    }
    let font = NSFont.monospacedDigitSystemFont(ofSize: baseFont * scale, weight: .heavy)
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    template.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                  from: NSRect(origin: .zero, size: template.size),
                  operation: .sourceOver, fraction: 1.0)
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: orange, .paragraphStyle: p
    ]
    let ts = (pctNumber as NSString).size(withAttributes: attrs)
    let bodyCY = size * 0.52
    (pctNumber as NSString).draw(in: NSRect(x: 0, y: bodyCY - ts.height / 2,
                                            width: size, height: ts.height),
                                 withAttributes: attrs)
    img.unlockFocus()
    return img
}

let samples: [Double] = [8, 38, 75, 100]
let native: CGFloat = 22
let zoom: CGFloat = 8
let pad: CGFloat = 20
let gap: CGFloat = 14

let zoomed = native * zoom
let zoomRowW = pad * 2 + CGFloat(samples.count) * zoomed + CGFloat(samples.count - 1) * gap
let stripH: CGFloat = 34
let labelH: CGFloat = 20
let total = pad + labelH + stripH + 4 + stripH + pad + labelH + zoomed + pad
let sheet = NSImage(size: NSSize(width: zoomRowW, height: total))
sheet.lockFocus()
NSColor(white: 0.14, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: zoomRowW, height: total).fill()

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
    .foregroundColor: NSColor.white
]
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11),
    .foregroundColor: NSColor(white: 0.75, alpha: 1.0)
]

let lightY = total - pad - labelH - stripH
NSColor(white: 0.95, alpha: 1.0).setFill()
NSRect(x: pad, y: lightY, width: zoomRowW - pad * 2, height: stripH).fill()
("Native 22x22 \u{2022} light + dark menu-bar strips" as NSString)
    .draw(at: NSPoint(x: pad, y: total - pad - 14), withAttributes: titleAttrs)

let darkY = lightY - 4 - stripH
NSColor(white: 0.08, alpha: 1.0).setFill()
NSRect(x: pad, y: darkY, width: zoomRowW - pad * 2, height: stripH).fill()

let stripInnerPad: CGFloat = 30
let spacing = (zoomRowW - pad * 2 - CGFloat(samples.count) * native - stripInnerPad * 2) / CGFloat(samples.count - 1)
for (i, pct) in samples.enumerated() {
    let img = renderCompact(percentage: pct, size: native)
    let x = pad + stripInnerPad + CGFloat(i) * (native + spacing)
    img.draw(in: NSRect(x: x, y: lightY + (stripH - native) / 2,
                        width: native, height: native),
             from: .zero, operation: .sourceOver, fraction: 1.0)
    img.draw(in: NSRect(x: x, y: darkY + (stripH - native) / 2,
                        width: native, height: native),
             from: .zero, operation: .sourceOver, fraction: 1.0)
}

let zoomY = pad
("8x zoom" as NSString).draw(at: NSPoint(x: pad, y: zoomY + zoomed + 4),
                              withAttributes: subAttrs)
for (i, pct) in samples.enumerated() {
    let img = renderCompact(percentage: pct, size: zoomed)
    let x = pad + CGFloat(i) * (zoomed + gap)
    img.draw(in: NSRect(x: x, y: zoomY, width: zoomed, height: zoomed),
             from: .zero, operation: .sourceOver, fraction: 1.0)
}

sheet.unlockFocus()
if let tiff = sheet.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    let outURL = URL(fileURLWithPath: repo).appendingPathComponent("images/compact-preview.png")
    try png.write(to: outURL)
    print("Wrote \(outURL.path)")
}
