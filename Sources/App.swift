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
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let session = Session.shared
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var titleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NSHostingController(rootView: Panel(session: session))
        panel.sizingOptions = [.preferredContentSize]
        popover.contentViewController = panel
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        // Deferred a turn so an item is never swapped out from inside its own
        // click handler (right-click toggles a session directly).
        session.onChange = { [weak self] in DispatchQueue.main.async { self?.refresh() } }
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
        updateItem()
        // The countdown only needs the minute, so it ticks twice a minute and
        // only while there is one to show.
        titleTimer?.invalidate()
        titleTimer = nil
        guard session.isActive, session.showsTimeInMenuBar, session.endDate != nil else { return }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.updateItem() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        titleTimer = timer
    }

    // Once a status item changes width, macOS 27 keeps reporting its old
    // position, so a popover opened from it lands off centre. The item is
    // therefore rebuilt whenever its width has to change: a new item reports
    // where it really is, and its autosave name keeps it in the same place.
    // The countdown uses fixed-width digits ("0:15"), so ticking never changes
    // the width; only showing or hiding it does. Nothing changes while the
    // panel is open, so it cannot drift away from the item it points at.
    private func updateItem() {
        guard !popover.isShown else { return }
        let title = session.showsTimeInMenuBar ? session.remaining.map { " " + Clock.short($0) } ?? "" : ""
        if let button = statusItem?.button, button.title.count == title.count {
            if button.title != title { button.title = title }
        } else {
            rebuildItem(title: title)
        }
        guard let button = statusItem?.button else { return }
        button.image = MenuBarIcon.image(active: session.isActive)
        button.setAccessibilityLabel(session.isActive ? "Pervitin, keeping this Mac awake" : "Pervitin, off")
    }

    private func rebuildItem(title: String) {
        if let old = statusItem { NSStatusBar.system.removeStatusItem(old) }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "pervitin"
        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
            button.title = title
        }
        statusItem = item
    }

    func popoverDidClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.updateItem() }
    }
}
