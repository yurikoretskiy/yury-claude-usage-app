import AppKit
import SwiftUI

enum MenuBarRenderer {
    // Retro-digital colors
    static let orangeColor = NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    static let dimOrangeColor = NSColor(red: 0.30, green: 0.18, blue: 0.02, alpha: 1.0)
    static let backgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.0)
    // Coral sampled from yrojko Gemini reference — used only by compact mode.
    static let coralColor = NSColor(red: 252.0/255.0, green: 172.0/255.0, blue: 152.0/255.0, alpha: 1.0)

    // Cache the logo image (SPM puts resources in Bundle.module)
    private static let logoImage: NSImage? = loadBundledImage(named: "claude-logo")

    private static func loadBundledImage(named name: String, extensions: [String] = ["png"]) -> NSImage? {
        for ext in extensions {
            if let url = Bundle.module.url(forResource: name, withExtension: ext),
               let img = NSImage(contentsOf: url) { return img }
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let img = NSImage(contentsOf: url) { return img }
            let execURL = Bundle.main.executableURL?.deletingLastPathComponent()
            if let resURL = execURL?.deletingLastPathComponent().appendingPathComponent("Resources/\(name).\(ext)"),
               let img = NSImage(contentsOf: resURL) { return img }
        }
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

    /// 5×7 pixel-digit bitmap. "7" and "5" transcribed from the yrojko Gemini
    /// reference; other digits drawn in matching chunky retro style. Row 0 = top.
    private static let pixelDigits5x7: [Character: [String]] = [
        "0": ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#####"],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": ["#####", "....#", "....#", "#####", "#....", "#....", "#####"],
        "3": ["#####", "....#", "....#", "#####", "....#", "....#", "#####"],
        "4": ["#...#", "#...#", "#...#", "#####", "....#", "....#", "....#"],
        "5": ["#####", "#....", "#....", "####.", "....#", "#...#", ".###."],
        "6": ["#####", "#....", "#....", "#####", "#...#", "#...#", "#####"],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": ["#####", "#...#", "#...#", "#####", "#...#", "#...#", "#####"],
        "9": ["#####", "#...#", "#...#", "#####", "....#", "....#", "#####"]
    ]

    private static func drawPixelDigit(_ digit: Character, at origin: NSPoint, unit: CGFloat) {
        guard let rows = pixelDigits5x7[digit] else { return }
        let rowCount = rows.count
        for (rowIndex, row) in rows.enumerated() {
            let y = origin.y + CGFloat(rowCount - rowIndex - 1) * unit
            for (columnIndex, cell) in row.enumerated() where cell == "#" {
                NSRect(
                    x: origin.x + CGFloat(columnIndex) * unit,
                    y: y,
                    width: unit,
                    height: unit
                ).fill()
            }
        }
    }

    /// Compact icon: yrojko-faithful silhouette drawn as a SINGLE continuous
    /// coral outline (no internal seams). Path traces body top → down right
    /// side with a pin notch → across bottom with 4 leg notches (2 on left,
    /// 2 on right, middle gap) → up left side with a pin notch → close.
    /// Digit rendering is unchanged for now.
    static func renderCompactMenuBarImage(percentage: Double) -> NSImage {
        let width: CGFloat = 36
        let height: CGFloat = 22

        return NSImage(size: NSSize(width: width, height: height), flippable: false) { _ in
            NSGraphicsContext.current?.shouldAntialias = false
            NSGraphicsContext.current?.imageInterpolation = .none

            // --- Layout constants tuned to yrojko proportions (scaled to 22px tall) ---
            let bodyL: CGFloat = 5        // body left edge (inside left pin)
            let bodyR: CGFloat = 31       // body right edge (inside right pin)
            let bodyTop: CGFloat = 21     // 1px top pad
            let bodyBot: CGFloat = 4      // legs extend below to y=0
            // Pin geometry (62% vertical position from body top)
            let pinTop: CGFloat = 12
            let pinBot: CGFloat = 8
            let leftPinX: CGFloat = 0
            let rightPinX: CGFloat = 36
            // Leg X edges (4 legs: 2 left-cluster, 2 right-cluster, middle gap)
            // Centers at 12.5%, 29%, 71%, 87.5% of body width; each leg 2px wide
            let legY: CGFloat = 0
            let l1L: CGFloat = 7,  l1R: CGFloat = 9
            let l2L: CGFloat = 12, l2R: CGFloat = 14
            let l3L: CGFloat = 22, l3R: CGFloat = 24
            let l4L: CGFloat = 27, l4R: CGFloat = 29

            // --- Build single continuous path (counter-clockwise from top-left) ---
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bodyL, y: bodyTop))
            // Top edge
            path.line(to: NSPoint(x: bodyR, y: bodyTop))
            // Down right side to right-pin top
            path.line(to: NSPoint(x: bodyR, y: pinTop))
            // Right pin: out, down, back in
            path.line(to: NSPoint(x: rightPinX, y: pinTop))
            path.line(to: NSPoint(x: rightPinX, y: pinBot))
            path.line(to: NSPoint(x: bodyR,     y: pinBot))
            // Down to body bottom-right
            path.line(to: NSPoint(x: bodyR, y: bodyBot))
            // Across bottom with 4 leg notches (right-cluster first going left)
            path.line(to: NSPoint(x: l4R, y: bodyBot))
            path.line(to: NSPoint(x: l4R, y: legY))
            path.line(to: NSPoint(x: l4L, y: legY))
            path.line(to: NSPoint(x: l4L, y: bodyBot))
            path.line(to: NSPoint(x: l3R, y: bodyBot))
            path.line(to: NSPoint(x: l3R, y: legY))
            path.line(to: NSPoint(x: l3L, y: legY))
            path.line(to: NSPoint(x: l3L, y: bodyBot))
            // Middle gap (no legs)
            path.line(to: NSPoint(x: l2R, y: bodyBot))
            path.line(to: NSPoint(x: l2R, y: legY))
            path.line(to: NSPoint(x: l2L, y: legY))
            path.line(to: NSPoint(x: l2L, y: bodyBot))
            path.line(to: NSPoint(x: l1R, y: bodyBot))
            path.line(to: NSPoint(x: l1R, y: legY))
            path.line(to: NSPoint(x: l1L, y: legY))
            path.line(to: NSPoint(x: l1L, y: bodyBot))
            // Body bottom-left
            path.line(to: NSPoint(x: bodyL, y: bodyBot))
            // Up left side to left-pin bottom
            path.line(to: NSPoint(x: bodyL, y: pinBot))
            // Left pin: out, up, back in
            path.line(to: NSPoint(x: leftPinX, y: pinBot))
            path.line(to: NSPoint(x: leftPinX, y: pinTop))
            path.line(to: NSPoint(x: bodyL,    y: pinTop))
            // Close to top-left
            path.close()

            coralColor.setStroke()
            path.lineWidth = 1.0
            path.lineJoinStyle = .miter
            path.stroke()

            // --- Pixel digits centered in the body ---
            let pctNumber = "\(Int(round(percentage)))"
            let unit: CGFloat = pctNumber.count >= 3 ? 1.0 : (pctNumber.count == 2 ? 1.5 : 2.0)
            let glyphW = 5 * unit
            let glyphH = 7 * unit
            let glyphGap = unit
            let totalW = CGFloat(pctNumber.count) * glyphW
                       + CGFloat(max(0, pctNumber.count - 1)) * glyphGap
            let bodyMidX = (bodyL + bodyR) / 2
            let bodyMidY = (bodyBot + bodyTop) / 2
            let startX = round(bodyMidX - totalW / 2)
            let startY = round(bodyMidY - glyphH / 2)

            coralColor.setFill()
            for (index, digit) in pctNumber.enumerated() {
                let x = startX + CGFloat(index) * (glyphW + glyphGap)
                drawPixelDigit(digit, at: NSPoint(x: x, y: startY), unit: unit)
            }
        }
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
