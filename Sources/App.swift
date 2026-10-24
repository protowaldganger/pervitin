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
    private var titleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }
        item.autosaveName = "pervitin"
        statusItem = item

        let panel = NSHostingController(rootView: Panel(session: session))
        panel.sizingOptions = [.preferredContentSize]
        popover.contentViewController = panel
        popover.behavior = .transient
        popover.animates = true

        session.onChange = { [weak self] in self?.refresh() }
        refresh()
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
        guard let button = statusItem?.button else { return }
        button.image = MenuBarIcon.image(active: session.isActive)
        button.setAccessibilityLabel(session.isActive ? "Pervitin, keeping this Mac awake" : "Pervitin, off")
        updateTitle()

        // The countdown only needs the minute, so it ticks twice a minute and
        // only while there is one to show.
        titleTimer?.invalidate()
        titleTimer = nil
        guard session.isActive, session.showsTimeInMenuBar, session.endDate != nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.updateTitle() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        titleTimer = timer
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }
        if session.showsTimeInMenuBar, let left = session.remaining {
            button.title = " " + Clock.short(left)
        } else {
            button.title = ""
        }
    }
}
