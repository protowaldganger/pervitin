//
//  MenuBarIcon.swift
//  Pervitin
//

import AppKit

// A small tablet tube, drawn in code so the app ships no image files for it.
// Empty when off; while awake it is full and drains as the session runs down,
// so the time left shows at a glance without any text in the menu bar.
enum MenuBarIcon {
    private static let steps = 12
    private static var cache: [Int: NSImage] = [:]

    // `level` is the share of the session left, 0...1. Only used when active.
    static func image(active: Bool, level: Double) -> NSImage {
        // -1 is the empty, inactive tube. While active, never show it fully
        // empty, so an awake Mac always reads as awake.
        let step = active ? max(1, Int((level * Double(steps)).rounded(.up))) : -1
        if let cached = cache[step] { return cached }
        let image = draw(step: step)
        cache[step] = image
        return image
    }

    private static func draw(step: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let cap = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 13, width: 9, height: 3.5), xRadius: 1, yRadius: 1)
            cap.fill()

            let bodyRect = NSRect(x: 3.5, y: 1.75, width: 7, height: 10.5)
            let body = NSBezierPath(roundedRect: bodyRect, xRadius: 2, yRadius: 2)
            body.lineWidth = 1.5
            body.stroke()

            if step > 0 {
                NSGraphicsContext.saveGraphicsState()
                body.addClip()
                let height = bodyRect.height * CGFloat(step) / CGFloat(steps)
                NSBezierPath(rect: NSRect(x: bodyRect.minX, y: bodyRect.minY, width: bodyRect.width, height: height)).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pervitin"
        return image
    }
}
