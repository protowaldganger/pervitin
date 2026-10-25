//
//  App.swift
//  Pervitin
//

import AppKit
import SwiftUI

@main
enum Pervitin {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

// One status item and one popover. Left click opens the panel; right click
// (or control-click) starts or stops a session with the last chosen length.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = Session.shared
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var drainTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Square and icon-only, so the item never changes width and the
        // popover always sits centred under it.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "pervitin"
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let panel = NSHostingController(rootView: Panel(session: session))
        panel.sizingOptions = [.preferredContentSize]
        popover.contentViewController = panel
        popover.behavior = .transient
        popover.animates = true

        session.onChange = { [weak self] in self?.refresh() }
        refresh()
        UpdateCheck.shared.startIfEnabled()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            session.toggle()
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    // MARK: Menu bar

    private func refresh() {
        updateIcon()
        // The tube drains in twelve steps, so checking twice a minute is
        // plenty, and only while a session has an end.
        drainTimer?.invalidate()
        drainTimer = nil
        guard session.isActive, session.endDate != nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.updateIcon() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        drainTimer = timer
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let level = session.isActive ? session.remainingFraction : 0
        let image = MenuBarIcon.image(active: session.isActive, level: level)
        if button.image !== image { button.image = image }
        if session.isActive, let left = session.remaining {
            button.setAccessibilityLabel("Pervitin, awake for \(Clock.long(left)) more")
            button.toolTip = "\(Clock.long(left)) left"
        } else {
            button.setAccessibilityLabel(session.isActive ? "Pervitin, keeping this Mac awake" : "Pervitin, off")
            button.toolTip = nil
        }
    }
}
