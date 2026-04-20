#!/usr/bin/env swift
// Converts Gemini_Generated_Image_*.png into a clean compact-mode template.
// Steps: load → erase the baked-in "75%" with white → trim whitespace →
// resize to 128x128 → save to ClaudeUsage/Resources/compact-mascot.png.

import AppKit
import Foundation

let repo = FileManager.default.currentDirectoryPath
let srcURL = URL(fileURLWithPath: repo).appendingPathComponent("Gemini_Generated_Image_1z37bg1z37bg1z37.png")
guard let src = NSImage(contentsOf: srcURL) else {
    FileHandle.standardError.write("Could not load \(srcURL.path)\n".data(using: .utf8)!)
    exit(1)
}

// Bake into a bitmap we can paint over
let w = Int(src.size.width)
let h = Int(src.size.height)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: w, pixelsHigh: h,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 32
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: w, height: h).fill()
src.draw(in: NSRect(x: 0, y: 0, width: w, height: h),
         from: NSRect(origin: .zero, size: src.size),
         operation: .sourceOver, fraction: 1.0)

// Paint a generous white rectangle over the "75%" in the body center
let fx = CGFloat(w)
let fy = CGFloat(h)
let eraseRect = NSRect(x: fx * 0.30, y: fy * 0.34,
                       width: fx * 0.40, height: fy * 0.34)
NSColor.white.setFill()
eraseRect.fill()
NSGraphicsContext.restoreGraphicsState()

// Detect bounding box of non-white (outline) pixels to trim margins
guard let data = rep.bitmapData else { exit(1) }
let bpr = rep.bytesPerRow
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w {
        let i = y * bpr + x * 4
        let r = data[i], g = data[i+1], b = data[i+2]
        // Consider "dark" pixels part of outline
        if Int(r) + Int(g) + Int(b) < 420 {
            if x < minX { minX = x }
            if y < minY { minY = y }
            if x > maxX { maxX = x }
            if y > maxY { maxY = y }
        }
    }
}
let pad = 20
minX = max(0, minX - pad)
minY = max(0, minY - pad)
maxX = min(w - 1, maxX + pad)
maxY = min(h - 1, maxY + pad)
let cropW = maxX - minX + 1
let cropH = maxY - minY + 1

// Crop to a square centered on bbox
let side = max(cropW, cropH)
let cx = (minX + maxX) / 2
let cy = (minY + maxY) / 2
let sqX = max(0, cx - side / 2)
let sqY = max(0, cy - side / 2)
let sqSide = min(side, min(w - sqX, h - sqY))

// Render cropped region into a new 256x256 square template
let outSize = 256
let outImage = NSImage(size: NSSize(width: outSize, height: outSize))
outImage.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: outSize, height: outSize).fill()
NSGraphicsContext.current?.imageInterpolation = .high

// Because NSBitmapImageRep uses flipped coordinates, flip Y for the source rect
let srcRect = NSRect(x: CGFloat(sqX),
                     y: CGFloat(h - sqY - sqSide),
                     width: CGFloat(sqSide),
                     height: CGFloat(sqSide))
if let cg = rep.cgImage {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.interpolationQuality = .high
    // Draw the cropped sub-image
    if let sub = cg.cropping(to: CGRect(x: sqX, y: sqY, width: sqSide, height: sqSide)) {
        ctx.draw(sub, in: CGRect(x: 0, y: 0, width: outSize, height: outSize))
    } else {
        // Fallback via NSImage
        let tmp = NSImage(size: NSSize(width: sqSide, height: sqSide))
        tmp.lockFocus()
        rep.draw(in: NSRect(x: 0, y: 0, width: sqSide, height: sqSide),
                 from: srcRect, operation: .sourceOver, fraction: 1.0,
                 respectFlipped: true, hints: nil)
        tmp.unlockFocus()
        tmp.draw(in: NSRect(x: 0, y: 0, width: outSize, height: outSize))
    }
}
outImage.unlockFocus()

guard let tiff = outImage.tiffRepresentation,
      let outRep = NSBitmapImageRep(data: tiff),
      let png = outRep.representation(using: .png, properties: [:]) else { exit(1) }
let outURL = URL(fileURLWithPath: repo).appendingPathComponent("ClaudeUsage/Resources/compact-mascot.png")
try png.write(to: outURL)
print("Wrote \(outURL.path) (\(png.count) bytes)")
