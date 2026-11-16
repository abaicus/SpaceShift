// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

/// The menu bar panel: the two switches, time for Keep Awake, and a way into the app.
struct StatusPanel: View {
    @ObservedObject var controller: MotionController
    @ObservedObject var keepAwake: KeepAwakeManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            if !controller.hasAccessibilityPermission, controller.showsSpaceSwitching || controller.showsSmartZoom {
                Button("Allow Accessibility access…") { controller.openAccessibilitySettings() }
                    .buttonStyle(PillButtonStyle(tint: .brand, fills: true))
                    .help("Dă-i needs it to see your shortcuts and swipes")
            }
            if controller.showsSpaceSwitching {
                row("Space Switching", detail: controller.isEnabled ? controller.approximateMultiplier : nil) {
                    Toggle("Faster Space switching", isOn: $controller.isEnabled)
                        .toggleStyle(TintSwitchStyle(tint: .brand))
                        .help("Turn faster Space switching on or off")
                }
            }
            if keepAwake.isAvailable {
                row("Keep Awake", detail: keepAwake.isActive ? keepAwake.shortStatus : nil) {
                    Toggle("Keep Awake", isOn: $keepAwake.isActive)
                        .toggleStyle(TintSwitchStyle(tint: .awake))
                        .help("Stop the Mac and its display from sleeping")
                }
                KeepAwakeTimeButtons(keepAwake: keepAwake, compact: true)
            }
            HStack {
                Button("Open Dă-i") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .help("Speed, Smart Zoom shortcut and the other settings")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.plain)
            .font(Theme.body)
            .foregroundStyle(Theme.secondary)
        }
        .padding(Theme.Space.l)
        .frame(width: 320)
        .background { Theme.background }
        .preferredColorScheme(.dark)
    }

    private func row<Control: View>(_ title: String, detail: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: Theme.Space.s) {
            Text(title)
                .font(Theme.title)
                .foregroundStyle(Theme.primary)
            if let detail {
                Text(detail)
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
            control()
        }
    }
}
