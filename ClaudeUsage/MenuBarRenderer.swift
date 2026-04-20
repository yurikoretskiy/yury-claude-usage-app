import AppKit
import SwiftUI

enum MenuBarRenderer {
    // Retro-digital colors
    static let orangeColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    static let dimOrangeColor = NSColor(red: 0.30, green: 0.18, blue: 0.02, alpha: 1.0)
    static let backgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.0)

    // Cache the logo image (SPM puts resources in Bundle.module)
    private static let logoImage: NSImage? = loadBundledImage(named: "claude-logo")
    // Cache the Claude Code pixel mascot for compact mode
    private static let mascotImage: NSImage? = loadBundledImage(named: "claudecode-color")
    // Compact-mode outline template (Gemini mascot silhouette, text erased)
    private static let compactTemplate: NSImage? = loadBundledImage(named: "compact-mascot")

    private static func loadBundledImage(named name: String) -> NSImage? {
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) { return img }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) { return img }
        let execURL = Bundle.main.executableURL?.deletingLastPathComponent()
        if let resURL = execURL?.deletingLastPathComponent().appendingPathComponent("Resources/\(name).png"),
           let img = NSImage(contentsOf: resURL) { return img }
        return nil
    }

    static func renderMenuBarImage(percentage: Double) -> NSImage {
        let height: CGFloat = 22

        // Pre-calculate percentage text width
        let pctNumber = "\(Int(round(percentage)))"
        let numFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .heavy)
        let pctSymFont = NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .bold)
        let numSize = (pctNumber as NSString).size(withAttributes: [.font: numFont])
        let pctSymSize = ("%" as NSString).size(withAttributes: [.font: pctSymFont])
        let pctTotalWidth = numSize.width + pctSymSize.width + 1

        // Layout constants
        let leftPad: CGFloat = 5
        let logoDrawSize: CGFloat = 16
        let logoRightMargin: CGFloat = 4
        let barSegments = 18
        let segW: CGFloat = 4.0
        let segGap: CGFloat = 1.8
        let barRightMargin: CGFloat = 5
        let rightPad: CGFloat = 5

        let barTotalWidth = CGFloat(barSegments) * segW + CGFloat(barSegments - 1) * segGap
        let totalWidth = leftPad + logoDrawSize + logoRightMargin + barTotalWidth + barRightMargin + pctTotalWidth + rightPad

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flippable: false) { _ in
            let rect = NSRect(x: 0, y: 0, width: totalWidth, height: height)

            // Enable anti-aliasing
            NSGraphicsContext.current?.shouldAntialias = true
            NSGraphicsContext.current?.imageInterpolation = .high

            // Black rounded pill background
            let bgRect = rect.insetBy(dx: 0.5, dy: 1.5)
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 5, yRadius: 5)
            backgroundColor.setFill()
            bgPath.fill()

            // Subtle border
            NSColor(white: 0.2, alpha: 0.5).setStroke()
            bgPath.lineWidth = 0.5
            bgPath.stroke()

            var x: CGFloat = leftPad

            // Draw the actual Claude logo PNG
            if let logo = logoImage {
                let logoRect = NSRect(
                    x: x,
                    y: (height - logoDrawSize) / 2,
                    width: logoDrawSize,
                    height: logoDrawSize
                )
                logo.draw(in: logoRect,
                          from: NSRect(origin: .zero, size: logo.size),
                          operation: .sourceOver,
                          fraction: 1.0)
            }
            x += logoDrawSize + logoRightMargin

            // Progress bar segments
            let segH: CGFloat = 12
            let segY: CGFloat = (height - segH) / 2
            let filledCount = Int(round(percentage / 100.0 * Double(barSegments)))

            for i in 0..<barSegments {
                let segRect = NSRect(x: x, y: segY, width: segW, height: segH)
                let color = i < filledCount ? orangeColor : dimOrangeColor
                color.setFill()
                NSBezierPath(roundedRect: segRect, xRadius: 0.8, yRadius: 0.8).fill()
                x += segW + segGap
            }

            x += barRightMargin - segGap

            // Percentage: number in large font, "%" in smaller font
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: numFont,
                .foregroundColor: orangeColor
            ]
            let symAttrs: [NSAttributedString.Key: Any] = [
                .font: pctSymFont,
                .foregroundColor: orangeColor
            ]

            let numY = (height - numSize.height) / 2
            (pctNumber as NSString).draw(at: NSPoint(x: x, y: numY), withAttributes: numAttrs)
            x += numSize.width + 1
            let symY = numY + (numSize.height - pctSymSize.height) / 2 + 1
            ("%" as NSString).draw(at: NSPoint(x: x, y: symY), withAttributes: symAttrs)
        }

        return image
    }

    /// 22x22 compact icon: Claude Code mascot outline (from Gemini-generated PNG)
    /// tinted orange, with a large orange percentage number centered in the body.
    static func renderCompactMenuBarImage(percentage: Double) -> NSImage {
        let size: CGFloat = 22
        let pctNumber = "\(Int(round(percentage)))"
        let fontSize: CGFloat
        switch pctNumber.count {
        case 1:  fontSize = 12
        case 2:  fontSize = 10
        default: fontSize = 8
        }
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .heavy)

        return NSImage(size: NSSize(width: size, height: size), flippable: false) { _ in
            NSGraphicsContext.current?.shouldAntialias = true
            NSGraphicsContext.current?.imageInterpolation = .high

            let canvas = NSRect(x: 0, y: 0, width: size, height: size)

            // Draw the template (black outline on white). Then tint it orange by
            // painting orange with .sourceIn — keeps only the outline pixels, colored.
            if let tmpl = compactTemplate {
                // Produce a tinted copy each render (cheap at 22x22).
                let tinted = NSImage(size: NSSize(width: size, height: size))
                tinted.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                // Draw template first
                tmpl.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                          from: NSRect(origin: .zero, size: tmpl.size),
                          operation: .sourceOver, fraction: 1.0)
                // Knock out the white background: multiply with inverse so only the
                // black outline remains visible, then recolor to orange.
                // Simpler path: use CIFilter to keep outline. For now, approximate
                // by redrawing with a compositing trick below.
                tinted.unlockFocus()

                // Build a grayscale mask where black outline = opaque, white = clear.
                if let mask = outlineMask(from: tmpl, targetSize: size) {
                    orangeColor.setFill()
                    canvas.fill()
                    mask.draw(in: canvas,
                              from: NSRect(origin: .zero, size: mask.size),
                              operation: .destinationIn,
                              fraction: 1.0)
                }
            }

            // Percentage text centered horizontally; vertically centered inside the
            // body area (a bit above geometric center since legs extend below).
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: orangeColor,
                .paragraphStyle: paragraph
            ]
            let textSize = (pctNumber as NSString).size(withAttributes: attrs)
            let bodyCenterY: CGFloat = size * 0.52
            let textRect = NSRect(x: 0,
                                  y: bodyCenterY - textSize.height / 2,
                                  width: size,
                                  height: textSize.height)
            (pctNumber as NSString).draw(in: textRect, withAttributes: attrs)
        }
    }

    /// Convert the template (dark-on-white PNG) into a mask where the outline
    /// pixels are opaque black and the white background is transparent.
    /// Returned NSImage can be used with .destinationIn to tint.
    private static func outlineMask(from template: NSImage, targetSize: CGFloat) -> NSImage? {
        let px = Int(targetSize * 2) // 2x for sharper downscale
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: px, height: px).fill()
        NSGraphicsContext.current?.imageInterpolation = .high
        template.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
                      from: NSRect(origin: .zero, size: template.size),
                      operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        // Convert each pixel: alpha = 255 - luminance (dark = opaque).
        guard let data = rep.bitmapData else { return nil }
        let bpr = rep.bytesPerRow
        for y in 0..<px {
            for x in 0..<px {
                let i = y * bpr + x * 4
                let r = Int(data[i]), g = Int(data[i+1]), b = Int(data[i+2])
                let lum = (r + g + b) / 3
                let alpha = max(0, 255 - lum)
                data[i] = 0; data[i+1] = 0; data[i+2] = 0
                data[i+3] = UInt8(alpha)
            }
        }
        let out = NSImage(size: NSSize(width: targetSize, height: targetSize))
        out.addRepresentation(rep)
        return out
    }
}

// Helper to create NSImage with drawing closure
extension NSImage {
    convenience init(size: NSSize, flippable: Bool, drawingHandler: @escaping (NSGraphicsContext?) -> Void) {
        self.init(size: size)
        self.lockFocus()
        let ctx = NSGraphicsContext.current
        drawingHandler(ctx)
        self.unlockFocus()
    }
}
