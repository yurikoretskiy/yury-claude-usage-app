#!/usr/bin/env swift
// Converts a Gemini-generated icon PNG (coral pixel outline on dark bg with
// baked-in "75%" and sparkle watermark) into a clean compact-mode template.
//
// Pipeline:
//   1. Load source
//   2. Sample the dark background color from a known-empty corner
//   3. Paint that color over the "75%" region (center body)
//   4. Paint that color over the Gemini sparkle watermark (bottom-right corner)
//   5. Detect the bounding box of coral (non-bg) pixels, add padding, square-crop
//   6. Downscale with nearest-neighbor to preserve the pixel-art feel, output 256x256
//   7. Save to ClaudeUsage/Resources/compact-mascot.png

import AppKit
import Foundation

let repo = FileManager.default.currentDirectoryPath
let srcURL = URL(fileURLWithPath: repo)
    .appendingPathComponent("Gemini_Generated_Image_aswh90aswh90aswh.png")
guard let src = NSImage(contentsOf: srcURL) else {
    FileHandle.standardError.write("Could not load \(srcURL.path)\n".data(using: .utf8)!)
    exit(1)
}

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
src.draw(in: NSRect(x: 0, y: 0, width: w, height: h),
         from: NSRect(origin: .zero, size: src.size),
         operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let data = rep.bitmapData else { exit(1) }
let bpr = rep.bytesPerRow

// Sample background from top-left corner (10,10) — guaranteed empty
let bgI = 10 * bpr + 10 * 4
let bgColor = NSColor(
    red: CGFloat(data[bgI]) / 255.0,
    green: CGFloat(data[bgI+1]) / 255.0,
    blue: CGFloat(data[bgI+2]) / 255.0,
    alpha: 1.0
)
print("Sampled bg: r=\(data[bgI]) g=\(data[bgI+1]) b=\(data[bgI+2])")

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
bgColor.setFill()

// Erase "75%" — covers full digit span including "%" slash/circles
let fx = CGFloat(w)
let fy = CGFloat(h)
let eraseText = NSRect(x: fx * 0.22, y: fy * 0.28,
                       width: fx * 0.56, height: fy * 0.44)
eraseText.fill()

// Erase Gemini sparkle in bottom-right corner (~last 8%)
let eraseStar = NSRect(x: fx * 0.90, y: 0, width: fx * 0.10, height: fy * 0.14)
eraseStar.fill()
NSGraphicsContext.restoreGraphicsState()

// Detect coral bounding box: a pixel is "coral" if red dominates green and blue
// by a clear margin. Background is near-uniform dark so this cleanly isolates ink.
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w {
        let i = y * bpr + x * 4
        let r = Int(data[i]), g = Int(data[i+1]), b = Int(data[i+2])
        if r > 140 && r > g + 30 && r > b + 30 {
            if x < minX { minX = x }
            if y < minY { minY = y }
            if x > maxX { maxX = x }
            if y > maxY { maxY = y }
        }
    }
}
if minX >= maxX {
    FileHandle.standardError.write("No coral pixels detected\n".data(using: .utf8)!)
    exit(1)
}
print("Coral bbox: x=\(minX)-\(maxX) y=\(minY)-\(maxY)")

let pad = 30
minX = max(0, minX - pad)
minY = max(0, minY - pad)
maxX = min(w - 1, maxX + pad)
maxY = min(h - 1, maxY + pad)

// Crop to bbox (preserve aspect) then paste into a square canvas with bg padding
let bbW = maxX - minX + 1
let bbH = maxY - minY + 1

guard let cg = rep.cgImage,
      let sub = cg.cropping(to: CGRect(x: minX, y: minY, width: bbW, height: bbH))
else { exit(1) }

// Render into a square canvas sized to the longer edge; fill with bg color first
let side = max(bbW, bbH)
let outSize = 256
let scale = CGFloat(outSize) / CGFloat(side)
let drawW = CGFloat(bbW) * scale
let drawH = CGFloat(bbH) * scale
let drawX = (CGFloat(outSize) - drawW) / 2
let drawY = (CGFloat(outSize) - drawH) / 2

guard let outRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: outSize, pixelsHigh: outSize,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 32
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: outRep)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: outSize, height: outSize).fill()
NSGraphicsContext.current?.cgContext.interpolationQuality = .high
NSGraphicsContext.current?.cgContext.draw(
    sub,
    in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH)
)
NSGraphicsContext.restoreGraphicsState()

// Convert dark background to transparent: alpha scales with "coralness".
// We keep the original RGB (so the coral texture is preserved) and set alpha
// from red-channel dominance over green/blue. Pixels with no coral signal
// become fully transparent; pure coral pixels stay fully opaque.
if let outData = outRep.bitmapData {
    let obpr = outRep.bytesPerRow
    for y in 0..<outSize {
        for x in 0..<outSize {
            let i = y * obpr + x * 4
            let r = Int(outData[i])
            let g = Int(outData[i+1])
            let b = Int(outData[i+2])
            // Coralness: how much red dominates, clamped to [0, 255].
            let dominance = max(0, r - max(g, b))
            // Remap: dominance >= 60 → fully opaque; 0 → transparent; linear in between.
            var alpha = 0
            if dominance >= 60 {
                alpha = 255
            } else if dominance > 10 {
                alpha = Int(Double(dominance - 10) / 50.0 * 255.0)
            }
            outData[i+3] = UInt8(max(0, min(255, alpha)))
        }
    }
}

guard let png = outRep.representation(using: .png, properties: [:]) else { exit(1) }
let outURL = URL(fileURLWithPath: repo)
    .appendingPathComponent("ClaudeUsage/Resources/compact-mascot.png")
try png.write(to: outURL)
print("Wrote \(outURL.path) (\(png.count) bytes)")
