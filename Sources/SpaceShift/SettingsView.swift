// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: MotionController
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @ObservedObject var keepAwake: KeepAwakeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            section("Tools", note: "A tool you switch off stops working and disappears from the window and the menu bar.") {
                tool("chevron.right.2", .brand, "Space Switching", isOn: $controller.showsSpaceSwitching)
                divider
                tool("plus.magnifyingglass", .zoom, "Smart Zoom", isOn: $controller.showsSmartZoom)
                divider
                tool("cup.and.saucer.fill", .awake, "Keep Awake", isOn: $keepAwake.isAvailable)
            }
            section("General", note: nil) {
                HStack {
                    Text("Open at login")
                        .font(Theme.body)
                        .foregroundStyle(Theme.primary)
                    Spacer()
                    Toggle("Open at login", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    .toggleStyle(TintSwitchStyle(tint: .brand, small: true))
                    .help("Start Dă-i when you log in")
                }
                .padding(.horizontal, Theme.Space.l)
                .frame(height: 48)
            }
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.bottom, Theme.Space.xl)
        .frame(width: 380)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Theme.background
                Text("Settings")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.tertiary)
                    .frame(height: 28)
            }
            .ignoresSafeArea()
        }
        .onAppear { launchAtLogin.refresh() }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, Theme.Space.l + 28 + Theme.Space.m)
    }

    private func section<Content: View>(_ title: String, note: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(title)
                .font(Theme.caption)
                .foregroundStyle(Theme.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, Theme.Space.l)
            VStack(spacing: 0) { content() }
                .card(padding: 0)
            if let note {
                Text(note)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.l)
            }
        }
    }

    private func tool(_ symbol: String, _ tint: Tint, _ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .saturation(isOn.wrappedValue ? 1 : 0)
                .opacity(isOn.wrappedValue ? 1 : 0.6)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.body)
                .foregroundStyle(Theme.primary)
            Spacer()
            Toggle(title, isOn: isOn)
                .toggleStyle(TintSwitchStyle(tint: tint, small: true))
                .help(isOn.wrappedValue ? "Switch \(title) off and hide it" : "Switch \(title) on and show it")
        }
        .padding(.horizontal, Theme.Space.l)
        .frame(height: 48)
    }
}

/// Replaces the standard Settings menu item with the app's own window.
struct SettingsCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
    }
}
