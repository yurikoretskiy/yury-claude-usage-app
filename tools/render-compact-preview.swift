#!/usr/bin/env swift
// Preview the current compact icon — simply draws the template PNG and
// overlays the percentage, matching the production renderer exactly.

import AppKit
import Foundation

let repo = FileManager.default.currentDirectoryPath
let tmplURL = URL(fileURLWithPath: repo).appendingPathComponent("ClaudeUsage/Resources/compact-mascot.png")
let template = NSImage(contentsOf: tmplURL)!
let orange = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)

func renderCompact(percentage: Double, height: CGFloat) -> NSImage {
    let scale = height / 22
    let aspect = template.size.width / template.size.height
    let width = max(height, floor(height * aspect))
    let pctNumber = "\(Int(round(percentage)))"
    let baseFont: CGFloat
    switch pctNumber.count {
    case 1:  baseFont = 14
    case 2:  baseFont = 12
    default: baseFont = 9
    }
    let font = NSFont.monospacedDigitSystemFont(ofSize: baseFont * scale, weight: .heavy)
    let img = NSImage(size: NSSize(width: width, height: height))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    template.draw(in: NSRect(x: 0, y: 0, width: width, height: height),
                  from: NSRect(origin: .zero, size: template.size),
                  operation: .sourceOver, fraction: 1.0)
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: orange, .paragraphStyle: p
    ]
    let ts = (pctNumber as NSString).size(withAttributes: attrs)
    let bodyCY = height * 0.55
    (pctNumber as NSString).draw(in: NSRect(x: 0, y: bodyCY - ts.height / 2,
                                            width: width, height: ts.height),
                                 withAttributes: attrs)
    img.unlockFocus()
    return img
}

let samples: [Double] = [8, 38, 75, 100]
let nativeH: CGFloat = 22
let zoom: CGFloat = 8
let pad: CGFloat = 20
let gap: CGFloat = 14

let aspect = template.size.width / template.size.height
let nativeW = max(nativeH, floor(nativeH * aspect))
let zoomedH = nativeH * zoom
let zoomedW = nativeW * zoom
let zoomRowW = pad * 2 + CGFloat(samples.count) * zoomedW + CGFloat(samples.count - 1) * gap
let stripH: CGFloat = 34
let labelH: CGFloat = 20
let total = pad + labelH + stripH + 4 + stripH + pad + labelH + zoomedH + pad
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
let spacing = (zoomRowW - pad * 2 - CGFloat(samples.count) * nativeW - stripInnerPad * 2) / CGFloat(samples.count - 1)
for (i, pct) in samples.enumerated() {
    let img = renderCompact(percentage: pct, height: nativeH)
    let x = pad + stripInnerPad + CGFloat(i) * (nativeW + spacing)
    img.draw(in: NSRect(x: x, y: lightY + (stripH - nativeH) / 2,
                        width: nativeW, height: nativeH),
             from: .zero, operation: .sourceOver, fraction: 1.0)
    img.draw(in: NSRect(x: x, y: darkY + (stripH - nativeH) / 2,
                        width: nativeW, height: nativeH),
             from: .zero, operation: .sourceOver, fraction: 1.0)
}

let zoomY = pad
("8x zoom" as NSString).draw(at: NSPoint(x: pad, y: zoomY + zoomedH + 4),
                              withAttributes: subAttrs)
for (i, pct) in samples.enumerated() {
    let img = renderCompact(percentage: pct, height: zoomedH)
    let x = pad + CGFloat(i) * (zoomedW + gap)
    img.draw(in: NSRect(x: x, y: zoomY, width: zoomedW, height: zoomedH),
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
