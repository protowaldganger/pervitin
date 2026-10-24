//
//  MenuBarIcon.swift
//  Pervitin
//

import AppKit

// A small tablet tube, drawn in code so the app ships no image files for it.
// Empty when off, filled when keeping the Mac awake.
enum MenuBarIcon {
    private static let off = draw(filled: false)
    private static let on = draw(filled: true)

    static func image(active: Bool) -> NSImage {
        active ? on : off
    }

    private static func draw(filled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 18), flipped: false) { _ in
            NSColor.black.set()
            let cap = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 13, width: 9, height: 3.5), xRadius: 1, yRadius: 1)
            cap.fill()
            let body = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 1.75, width: 7, height: 10.5), xRadius: 2, yRadius: 2)
            if filled {
                body.fill()
            } else {
                body.lineWidth = 1.5
                body.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pervitin"
        return image
    }
}
