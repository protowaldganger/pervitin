//
//  Style.swift
//  Pervitin
//
//  The type scale, colours, sliding grey and footer every protowaldganger app
//  shares. Kept identical to Hadrian's Wall's copy.
//

import AppKit
import SwiftUI

// The visual language shared by every protowaldganger app.
enum Style {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let raised = Color(nsColor: .controlBackgroundColor)
    static let well = Color.primary.opacity(0.04)
    static let track = Color.primary.opacity(0.08)
    static let hairline = Color.primary.opacity(0.08)
    static let ink = Color.primary.opacity(0.62)
    static let slide = Animation.spring(response: 0.3, dampingFraction: 0.86)

    static let title = Font.system(size: 24, weight: .semibold)
    static let body = Font.system(size: 13)
    static let detail = Font.system(size: 11)
    static let footer = Font.system(size: 11)
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
            Text("\(name) \(version) · by protowaldganger")
            Spacer(minLength: 8)
            if let available = updates.available {
                Link("Update \(available) available", destination: updates.releasesPage)
                    .padding(.trailing, 14)
            }
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
