//
//  Panel.swift
//  Pervitin
//
//  The popover. One choice, one button, three switches; the grey slides to
//  what you pick.
//

import AppKit
import SwiftUI

struct Panel: View {
    @ObservedObject var session: Session
    @Namespace var chipSelection

    private static let slide = Animation.spring(response: 0.3, dampingFraction: 0.86)

    private struct Preset {
        let minutes: Int
        let label: String
    }

    private static let presets = [
        Preset(minutes: 15, label: "15m"), Preset(minutes: 30, label: "30m"),
        Preset(minutes: 60, label: "1h"), Preset(minutes: 120, label: "2h"),
        Preset(minutes: 240, label: "4h"), Preset(minutes: 480, label: "8h"),
        Preset(minutes: 0, label: "∞")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            chips
            until
            mainButton
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
            VStack(spacing: 8) {
                option("Let the display sleep", $session.displayMaySleep)
                option("Show time in menu bar", $session.showsTimeInMenuBar)
                option("Open at login", Binding(get: { session.opensAtLogin },
                                                set: { session.opensAtLogin = $0 }))
            }
            footer
        }
        .padding(20)
        .frame(width: 296)
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.isActive ? "Wach" : "Aus")
                    .font(.system(size: 24, weight: .semibold))
                status
            }
            Spacer()
            Circle()
                .fill(session.isActive ? Color.green : Color.primary.opacity(0.18))
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
            Text(session.isActive ? "Until you stop it" : "Pick how long, then start")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var chips: some View {
        HStack(spacing: 2) {
            ForEach(Self.presets, id: \.minutes) { preset in
                let selected = !session.untilEnabled && session.presetMinutes == preset.minutes
                Button {
                    withAnimation(Self.slide) {
                        session.untilEnabled = false
                        session.presetMinutes = preset.minutes
                    }
                } label: {
                    Text(preset.label)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular).monospacedDigit())
                        .foregroundColor(selected ? .primary : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "chip", in: chipSelection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
    }

    private var until: some View {
        HStack {
            Toggle("Until a time", isOn: $session.untilEnabled)
                .toggleStyle(.checkbox)
            Spacer()
            DatePicker("Until", selection: $session.untilTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(!session.untilEnabled)
        }
        .font(.system(size: 13))
    }

    private var mainButton: some View {
        Button {
            withAnimation(Self.slide) { session.toggle() }
        } label: {
            Text(session.isActive ? "Schlafen lassen" : "Wach bleiben")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(session.isActive ? .primary : Color(nsColor: .windowBackgroundColor))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(session.isActive ? Color.primary.opacity(0.08) : Color.primary))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }

    private func option(_ title: String, _ isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
    }

    private var footer: some View {
        HStack {
            Text("Pervitin " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""))
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
    }
}
