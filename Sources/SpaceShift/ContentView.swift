// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: MotionController
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @ObservedObject var keepAwake: KeepAwakeManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            if !controller.hasAccessibilityPermission, controller.showsSpaceSwitching || controller.showsSmartZoom || controller.showsInputLock {
                PermissionNotice(controller: controller)
            } else if controller.showsSpaceSwitching, let blocker = controller.keyboardBlocker {
                keyboardNotice(blocker)
            }
            ForEach(controller.toolOrder) { tool in
                switch tool {
                case .spaceSwitching:
                    if controller.showsSpaceSwitching { spaceSwitchingCard }
                case .smartZoom:
                    if controller.showsSmartZoom {
                        smartZoomRow
                            .card(padding: Theme.Space.xl)
                    }
                case .keepAwake:
                    if keepAwake.isAvailable { keepAwakeCard }
                case .inputLock:
                    if controller.showsInputLock { inputLockCard }
                }
            }
            if !controller.showsSpaceSwitching, !controller.showsSmartZoom, !keepAwake.isAvailable, !controller.showsInputLock {
                Text("Every tool is switched off. Turn one on in Settings.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
                    .card(padding: Theme.Space.xl)
            }
            footer
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.bottom, Theme.Space.l)
        .background(alignment: .top) {
            // Fills the title bar too, and sets the name level with the traffic lights.
            ZStack(alignment: .top) {
                Theme.background
                Text("Dă-i")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.tertiary)
                    .frame(height: 28)
            }
            .ignoresSafeArea()
        }
        .onAppear { launchAtLogin.refresh() }
        .onDisappear { controller.stopRecording() }
    }

    private func keyboardNotice(_ blocker: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Key presses are hidden right now")
                .font(Theme.title)
                .foregroundStyle(Theme.primary)
            Text("\(blocker) has Secure Input switched on, so ⌃← and ⌃→ run at macOS speed. Swipes and mouse buttons still work.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var spaceSwitchingCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            FeatureHeader(
                symbol: "chevron.right.2", tint: .brand, title: "Space Switching",
                help: "Speeds up ⌃← and ⌃→ and three-finger swipes between Spaces",
                status: controller.spaceSwitchingStatus, isOn: controller.isEnabled
            ) {
                Toggle("Faster Space switching", isOn: $controller.isEnabled)
                    .toggleStyle(TintSwitchStyle(tint: .brand))
                    .help("Turn faster Space switching on or off")
            }
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(controller.multiplierDigits)
                        .font(Theme.display)
                        .monospacedDigit()
                        .foregroundStyle(Theme.primary)
                        .contentTransition(.numericText())
                    Text("×")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Tint.brand.gradient)
                    Spacer()
                    Button {
                        controller.testRight()
                    } label: {
                        Label("Try it", systemImage: "play.fill")
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(!controller.isRunning)
                    .help("Switch one Space to the right at this speed")
                }
                TintSlider(value: $controller.speed, in: 40...100, step: 5, tint: .brand)
                    .accessibilityLabel("Switching speed")
                    .accessibilityValue(controller.approximateMultiplier)
                    .help("How much faster than macOS the Space animation plays")
                HStack {
                    Text("Same as macOS")
                    Spacer()
                    Text("2.5× faster")
                }
                .font(Theme.caption)
                .foregroundStyle(Theme.tertiary)
            }
            .disabled(!controller.isEnabled)
            .opacity(controller.isEnabled ? 1 : 0.4)
            .animation(.snappy(duration: 0.15), value: controller.speed)
        }
        .card(glow: controller.isEnabled ? .brand : nil, padding: Theme.Space.xl)
    }

    private var keepAwakeCard: some View {
        VStack(spacing: Theme.Space.xl) {
            FeatureHeader(
                symbol: "cup.and.saucer.fill", tint: .awake, title: "Keep Awake",
                help: "Stops the Mac and its display from going to sleep",
                status: keepAwake.statusLine, isOn: keepAwake.isActive
            ) {
                Toggle("Keep Awake", isOn: $keepAwake.isActive)
                    .toggleStyle(TintSwitchStyle(tint: .awake))
                    .help("Stop the Mac and its display from sleeping")
            }
            KeepAwakeSettings(keepAwake: keepAwake)
        }
        .card(glow: keepAwake.isActive ? .awake : nil, padding: Theme.Space.xl)
    }

    private var smartZoomRow: some View {
        FeatureHeader(
            symbol: "plus.magnifyingglass", tint: .zoom, title: "Smart Zoom",
            help: "Zooms into the column or image under the pointer, like a two-finger double-tap on a trackpad",
            status: recordingStatus(.smartZoom),
            isOn: controller.smartZoomShortcut != nil || controller.isRecordingSmartZoom
        ) {
            shortcutControls(.smartZoom, tint: .zoom, shortcut: $controller.smartZoomShortcut)
        }
    }

    private var inputLockCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            FeatureHeader(
                symbol: "lock.fill", tint: .lock, title: "Input Lock",
                help: "Blocks typing, clicks, scrolling and gestures until you press the shortcut again. For when a baby or a cat gets at the keyboard. Locking the screen also releases it.",
                status: recordingStatus(.inputLock),
                isOn: controller.inputLockShortcut != nil || controller.isRecordingInputLock
            ) {
                shortcutControls(.inputLock, tint: .lock, shortcut: $controller.inputLockShortcut)
            }
            if let shortcut = controller.inputLockShortcut, !controller.isRecordingInputLock {
                HStack {
                    Text("\(shortcut.label) locks and unlocks")
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondary)
                    Spacer(minLength: Theme.Space.s)
                    Button {
                        controller.lockInput()
                    } label: {
                        Label("Lock now", systemImage: "lock.fill")
                    }
                    .buttonStyle(PillButtonStyle(tint: .lock))
                    .disabled(!controller.hasAccessibilityPermission)
                    .help("Lock the keyboard and mouse now. Press \(shortcut.label) to unlock.")
                }
            }
        }
        .card(padding: Theme.Space.xl)
    }

    private func recordingStatus(_ target: MotionController.RecordingTarget) -> String? {
        guard controller.recordingTarget == target else { return nil }
        return controller.recordingHint ?? "Press keys, double-tap one, press two in a row, or click a mouse button"
    }

    private func shortcutControls(
        _ target: MotionController.RecordingTarget, tint: Tint, shortcut: Binding<SmartZoomShortcut?>
    ) -> some View {
        let isRecording = controller.recordingTarget == target
        return HStack(spacing: Theme.Space.s) {
            if shortcut.wrappedValue != nil, !isRecording {
                Button("Remove") { shortcut.wrappedValue = nil }
                    .buttonStyle(PillButtonStyle(quiet: true))
                    .help("Remove shortcut")
            }
            Button(isRecording ? "Listening…" : (shortcut.wrappedValue?.label ?? "Set Shortcut")) {
                if isRecording {
                    controller.stopRecording()
                } else {
                    controller.stopRecording()
                    switch target {
                    case .smartZoom: controller.startRecordingSmartZoom()
                    case .inputLock: controller.startRecordingInputLock()
                    }
                }
            }
            .buttonStyle(PillButtonStyle(tint: isRecording ? tint : nil))
            .help(isRecording ? "Press Esc to cancel" : "Click, then press the shortcut you want: a key combination, a double-tap, two keys in a row, or a mouse button")
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.l) {
            Spacer()
            Button("Settings") { openWindow(id: "settings") }
                .help("Choose which tools appear, and open at login")
            Button("About") { openWindow(id: "about") }
                .help("Version, licence and source code")
        }
        .buttonStyle(.plain)
        .font(Theme.body)
        .foregroundStyle(Theme.secondary)
        .padding(.horizontal, Theme.Space.xl)
    }
}
