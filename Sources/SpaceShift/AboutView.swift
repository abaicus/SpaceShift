// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

struct AboutView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    private let source = URL(string: "https://github.com/abaicus/SpaceShift")!
    private let upstream = URL(string: "https://github.com/ReutS1/SpaceShift")!
    private let license = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            VStack(spacing: Theme.Space.m) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                VStack(spacing: Theme.Space.xs) {
                    Text("Dă-i")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.primary)
                    Text("înainte cu tupeu")
                        .font(Theme.body)
                        .foregroundStyle(Tint.brand.gradient)
                }
                if !version.isEmpty {
                    Text("Version \(version)")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.tertiary)
                }
            }
            Text("Faster Space switching, Smart Zoom from any shortcut, and Keep Awake.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                link("Source code", detail: "GitHub", url: source)
                divider
                link("Based on SpaceShift", detail: "by ReutS1", url: upstream)
                divider
                link("License", detail: "GNU GPL v3.0", url: license)
            }
            .card(padding: 0)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.bottom, Theme.Space.xl)
        .padding(.top, Theme.Space.s)
        .frame(width: 320)
        .background { Theme.background.ignoresSafeArea() }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, Theme.Space.l)
    }

    private func link(_ title: String, detail: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: Theme.Space.s) {
                Text(title)
                    .foregroundStyle(Theme.primary)
                Spacer(minLength: Theme.Space.s)
                Text(detail)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.tertiary)
            }
            .font(Theme.body)
            .padding(.horizontal, Theme.Space.l)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(url.absoluteString)
    }
}

/// Replaces the standard About menu item with the app's own window.
struct AboutCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About Dă-i") {
            openWindow(id: "about")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
