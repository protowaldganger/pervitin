//
//  Panel.swift
//  Pervitin
//
//  The popover. Tap a length and the Mac stays awake; the grey slides to
//  what is running. One button to stop, three switches, the shared footer.
//

import AppKit
import SwiftUI

struct Panel: View {
    @ObservedObject var session: Session
    @ObservedObject var updates = UpdateCheck.shared
    @Namespace var chipSelection

    private struct Preset {
        let minutes: Int
        let label: String
        let spoken: String
    }

    private static let presets = [
        Preset(minutes: 15, label: "15m", spoken: "15 minutes"),
        Preset(minutes: 30, label: "30m", spoken: "30 minutes"),
        Preset(minutes: 60, label: "1h", spoken: "1 hour"),
        Preset(minutes: 120, label: "2h", spoken: "2 hours"),
        Preset(minutes: 240, label: "4h", spoken: "4 hours"),
        Preset(minutes: 480, label: "8h", spoken: "8 hours"),
        Preset(minutes: 0, label: "∞", spoken: "Until stopped")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            chips
            if session.untilEnabled { until }
            if session.isActive { stopButton }
            Rectangle().fill(Style.hairline).frame(height: 1)
            VStack(spacing: 8) {
                option("Let the display sleep", $session.displayMaySleep)
                option("Open at login", Binding(get: { session.opensAtLogin },
                                                set: { session.opensAtLogin = $0 }))
                option("Check for updates", Binding(get: { updates.isEnabled },
                                                    set: { updates.isEnabled = $0 }))
            }
            MakerFooter(name: "Pervitin", updates: updates)
        }
        .padding(20)
        .frame(width: 320)
        .animation(Style.slide, value: session.isActive)
        .animation(Style.slide, value: session.untilEnabled)
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.isActive ? "Wach" : "Aus")
                    .font(Style.title)
                status
            }
            Spacer()
            Circle()
                .fill(session.isActive ? Color.green : Style.track)
                .frame(width: 8, height: 8)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var status: some View {
        if session.isActive, let end = session.endDate {
            TimelineView(.periodic(from: Date(), by: 1)) { _ in
                Text(Clock.long(max(0, end.timeIntervalSinceNow)) + " left, until "
                     + end.formatted(date: .omitted, time: .shortened))
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundColor(.secondary)
        } else {
            Text(session.isActive ? "Until you stop it"
                 : session.untilEnabled ? "Pick a time, then start" : "Tap a length to start")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    // Tapping a length starts at once, or restarts with the new length.
    // "Until" opens the time row instead.
    private var chips: some View {
        HStack(spacing: 2) {
            ForEach(Self.presets, id: \.minutes) { preset in
                chip(preset.label,
                     selected: session.isActive && !session.untilEnabled && session.presetMinutes == preset.minutes,
                     spoken: preset.spoken) {
                    session.begin(minutes: preset.minutes)
                }
            }
            chip("Until", selected: session.untilEnabled, spoken: "Until a time") {
                if session.isActive {
                    if !session.untilEnabled { session.beginUntil() }
                } else {
                    session.untilEnabled.toggle()
                }
            }
        }
        .padding(2)
        .background(Capsule().fill(Style.track))
    }

    private func chip(_ label: String, selected: Bool, spoken: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Style.slide) { action() }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: selected ? .semibold : .regular).monospacedDigit())
                .foregroundColor(selected ? .primary : .secondary)
                .frame(maxWidth: .infinity, minHeight: 26)
                .background {
                    if selected {
                        Capsule()
                            .fill(Style.raised)
                            .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                            .matchedGeometryEffect(id: "chip", in: chipSelection)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var until: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Awake until").font(Style.body)
                Spacer()
                DatePicker("Until", selection: $session.untilTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
            if !session.isActive {
                bigButton("Wach bleiben", primary: true) { session.beginUntil() }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var stopButton: some View {
        bigButton("Schlafen lassen", primary: false) { session.stop() }
            .transition(.opacity)
    }

    private func bigButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Style.slide) { action() }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(primary ? Style.canvas : .primary)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(primary ? Color.primary : Style.track))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }

    private func option(_ title: String, _ isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(Style.body)
            Spacer()
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }
}
