//
//  Style.swift
//  Pervitin
//
//  The type scale, colours, sliding grey and footer every protowaldganger app
//  shares. Kept identical to Hadrian's Wall's copy.
//

import AppKit
import SwiftUI

// The visual language shared by every protowaldganger app: black and white
// chrome in the system typeface, one grey that slides to what you pick, and
// colour only where it carries meaning (Apple HIG, Color): system colours, so
// light, dark and Increase Contrast adapt for free; each colour means one
// thing in every app; and colour is never the only signal.
enum Style {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let raised = Color(nsColor: .controlBackgroundColor)
    static let well = Color.primary.opacity(0.04)
    static let track = Color.primary.opacity(0.08)
    static let hairline = Color.primary.opacity(0.08)
    static let ink = Color.primary.opacity(0.62)
    static let slide = Animation.spring(response: 0.3, dampingFraction: 0.86)

    /// Switches, selections and default buttons: black in light mode, a quiet
    /// grey in dark mode so white knobs and labels stay readable.
    static let accent = Color(nsColor: NSColor(name: "protowaldganger.accent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.56, alpha: 1) : NSColor(white: 0.08, alpha: 1)
    })

    // Status: the same three meanings in every app.
    /// On, done, smaller, added.
    static let positive = Color(nsColor: .systemGreen)
    /// Needs you, skipped, not finished setting up.
    static let caution = Color(nsColor: .systemOrange)
    /// Failed, removed, destructive.
    static let negative = Color(nsColor: .systemRed)

    /// Kinds of things (categories, chart series), in one fixed order so the
    /// first kind is blue in every app. Green and red come last, so they only
    /// appear as a kind once the others run out and never compete with status.
    static let seriesColors: [NSColor] = [.systemBlue, .systemOrange, .systemPurple, .systemTeal, .systemPink,
                                          .systemYellow, .systemIndigo, .systemBrown, .systemGray, .systemMint, .systemCyan,
                                          .systemGreen, .systemRed]
    static func series(_ index: Int) -> Color { Color(nsColor: seriesColors[index % seriesColors.count]) }

    static let title = Font.system(size: 24, weight: .semibold)
    static let body = Font.system(size: 13)
    static let detail = Font.system(size: 11)
    static let footer = Font.system(size: 11)
}

/// A small status dot. Its shape repeats the colour's meaning, so it reads
/// without colour too: filled when on, a ring when off, and filled with a
/// ring around it when something needs you.
struct StatusDot: View {
    enum Tone { case on, caution, off }
    var tone: Tone
    var size: CGFloat = 8

    var body: some View {
        ZStack {
            switch tone {
            case .on:
                Circle().fill(Style.positive)
            case .caution:
                Circle().fill(Style.caution)
                Circle().strokeBorder(Style.caution.opacity(0.35), lineWidth: 1).padding(-2.5)
            case .off:
                Circle().strokeBorder(Color.primary.opacity(0.45), lineWidth: 1.2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// The same last line in every protowaldganger app.
struct MakerFooter: View {
    let name: String
    @ObservedObject var updates: UpdateCheck

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(name) • by protowaldganger")
            Spacer(minLength: 8)
            if let available = updates.available {
                Link("Update \(available) available", destination: updates.releasesPage)
                    .padding(.trailing, 14)
            }
            Text(version)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 14)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
        }
        .font(Style.footer)
        .foregroundColor(.secondary)
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Style.hairline).frame(height: 1)
        }
    }
}
