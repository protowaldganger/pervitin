//
//  Session.swift
//  Pervitin
//

import AppKit
import IOKit.pwr_mgt
import ServiceManagement

// Keeps the Mac awake by holding macOS power assertions, the same public
// mechanism `caffeinate` uses. Nothing is written anywhere except the app's
// own preferences, and nothing leaves the Mac.
final class Session: NSObject, ObservableObject {
    static let shared = Session()

    @Published private(set) var isActive = false
    // nil while active means "until stopped".
    @Published private(set) var endDate: Date?
    private(set) var startDate: Date?

    // How long a session lasts: minutes from now (0 = until stopped), or a
    // time of day when `untilEnabled` is on. Right-click starts with these.
    @Published private(set) var presetMinutes: Int {
        didSet { save(presetMinutes, "presetMinutes") }
    }
    @Published var untilEnabled: Bool {
        didSet { save(untilEnabled, "untilEnabled") }
    }
    // Moving the time during an until-session moves its end.
    @Published var untilTime: Date {
        didSet { save(untilTime, "untilTime"); if untilEnabled && isActive { start() } }
    }

    // Off: the display stays on and the screen saver stays away.
    // On: only the system is kept awake.
    @Published var displayMaySleep: Bool {
        didSet { save(displayMaySleep, "displayMaySleep"); if isActive { applyAssertions() } }
    }

    var onChange: (() -> Void)?

    var remaining: TimeInterval? {
        endDate.map { max(0, $0.timeIntervalSinceNow) }
    }

    // How much of the session is left, 1 at the start and 0 at the end; 1
    // throughout a session without an end. Drives the draining tube.
    var remainingFraction: Double {
        guard let endDate, let startDate else { return 1 }
        let total = endDate.timeIntervalSince(startDate)
        return total > 0 ? min(1, max(0, endDate.timeIntervalSinceNow / total)) : 0
    }

    // Asking macOS for the login item's status is a round trip to a system
    // service, so it is read when the panel opens, not on every redraw.
    @Published private(set) var opensAtLogin = false

    func refreshLoginItem() {
        let enabled = SMAppService.mainApp.status == .enabled
        if enabled != opensAtLogin { opensAtLogin = enabled }
    }

    func setOpensAtLogin(_ wanted: Bool) {
        do {
            if wanted {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        refreshLoginItem()
    }

    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    private var activityAssertion: IOPMAssertionID = 0
    private var endTimer: Timer?
    private var activityTimer: Timer?
    private var screensAreAsleep = false

    private override init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "presetMinutes": 60,
            "untilEnabled": false,
            "displayMaySleep": false
        ])
        presetMinutes = defaults.integer(forKey: "presetMinutes")
        untilEnabled = defaults.bool(forKey: "untilEnabled")
        untilTime = (defaults.object(forKey: "untilTime") as? Date) ?? Date().addingTimeInterval(3600)
        displayMaySleep = defaults.bool(forKey: "displayMaySleep")
        super.init()

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screensDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screensDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screensDidSleep), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screensDidWake), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    // MARK: Starting and stopping

    func toggle() {
        isActive ? stop() : start()
    }

    // One click: start (or restart) for this many minutes, 0 for no end.
    func begin(minutes: Int) {
        untilEnabled = false
        presetMinutes = minutes
        start()
    }

    func beginUntil() {
        untilEnabled = true
        start()
    }

    func start() {
        // Only a switch from off to on is announced; changing the length of a
        // running session is not.
        if !isActive { Chime.on() }
        endTimer?.invalidate()
        endTimer = nil
        let now = Date()
        startDate = now
        endDate = plannedEnd(from: now)
        isActive = true
        applyAssertions()
        if let endDate { scheduleEnd(at: endDate) }
        onChange?()
    }

    func stop(quietly: Bool = false) {
        if isActive && !quietly { Chime.off() }
        endTimer?.invalidate()
        endTimer = nil
        stopActivityPulse()
        drop(&systemAssertion)
        drop(&displayAssertion)
        drop(&activityAssertion)
        isActive = false
        endDate = nil
        startDate = nil
        onChange?()
    }

    private func plannedEnd(from now: Date) -> Date? {
        if untilEnabled {
            let time = Calendar.current.dateComponents([.hour, .minute], from: untilTime)
            return Calendar.current.nextDate(after: now, matching: time, matchingPolicy: .nextTime)
        }
        return presetMinutes > 0 ? now.addingTimeInterval(TimeInterval(presetMinutes * 60)) : nil
    }

    private func scheduleEnd(at date: Date) {
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in self?.stop() }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        endTimer = timer
    }

    // MARK: Power assertions

    private func applyAssertions() {
        hold(&systemAssertion, type: "PreventUserIdleSystemSleep")
        if displayMaySleep {
            drop(&displayAssertion)
            stopActivityPulse()
            drop(&activityAssertion)
        } else {
            hold(&displayAssertion, type: "PreventUserIdleDisplaySleep")
            startActivityPulse()
        }
    }

    private func hold(_ assertion: inout IOPMAssertionID, type: String) {
        guard assertion == 0 else { return }
        let reason = "Pervitin is keeping this Mac awake" as CFString
        if IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &assertion) != kIOReturnSuccess {
            assertion = 0
        }
    }

    private func drop(_ assertion: inout IOPMAssertionID) {
        guard assertion != 0 else { return }
        IOPMAssertionRelease(assertion)
        assertion = 0
    }

    // The display assertion alone does not always hold off the screen saver,
    // so the idle clock it counts against is reset every 30 seconds. Paused
    // while the screens sleep or the screen is locked, so a display you put to
    // sleep yourself stays asleep.
    private func startActivityPulse() {
        guard activityTimer == nil, !screensAreAsleep else { return }
        declareActivity()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.declareActivity() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        activityTimer = timer
    }

    private func stopActivityPulse() {
        activityTimer?.invalidate()
        activityTimer = nil
    }

    private func declareActivity() {
        IOPMAssertionDeclareUserActivity("Pervitin" as CFString, kIOPMUserActiveLocal, &activityAssertion)
    }

    // MARK: System events

    @objc private func systemDidWake() {
        guard isActive, let endDate else { return }
        endTimer?.invalidate()
        endTimer = nil
        if endDate <= Date() {
            stop()
        } else {
            scheduleEnd(at: endDate)
        }
    }

    @objc private func screensDidSleep() {
        screensAreAsleep = true
        stopActivityPulse()
    }

    @objc private func screensDidWake() {
        screensAreAsleep = false
        if isActive && !displayMaySleep { startActivityPulse() }
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

enum Clock {
    // 1:42:10 or 42:10
    static func long(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600, minutes = total % 3600 / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

}

// macOS's own alert sounds, from /System/Library/Sounds, so the app ships no
// audio. They follow the Sound settings, including the alert volume.
private enum Chime {
    static func on() { NSSound(named: NSSound.Name("Hero"))?.play() }
    static func off() { NSSound(named: NSSound.Name("Bottle"))?.play() }
}
