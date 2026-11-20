// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

/// A feature's coloured symbol, name and main control. The description is a tooltip;
/// `status` is shown only for live state.
struct FeatureHeader<Control: View>: View {
    let symbol: String
    let tint: Tint
    let title: String
    let help: String
    var status: String?
    var isOn = true
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .saturation(isOn ? 1 : 0)
                .opacity(isOn ? 1 : 0.6)
                .accessibilityHidden(true)
                .help(help)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.title)
                    .foregroundStyle(Theme.primary)
                if let status {
                    Text(status)
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .help(help)
            Spacer(minLength: 0)
            control
        }
    }
}

/// A thick track that fills with the tint up to the thumb.
struct TintSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Tint
    @Environment(\.isEnabled) private var isEnabled

    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double, tint: Tint) {
        _value = value
        self.range = range
        self.step = step
        self.tint = tint
    }


    private let height: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            let travel = proxy.size.width - height
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.control)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: height + travel * fraction)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .padding(4)
                    .frame(width: height, height: height)
                    .offset(x: travel * fraction)
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let raw = (drag.location.x - height / 2) / max(travel, 1)
                set(range.lowerBound + min(max(raw, 0), 1) * (range.upperBound - range.lowerBound))
            })
        }
        .frame(height: height)
        .saturation(isEnabled ? 1 : 0)
        .accessibilityElement()
        .accessibilityAdjustableAction { direction in
            set(value + (direction == .increment ? step : -step))
        }
    }

    private func set(_ raw: Double) {
        let stepped = (raw / step).rounded() * step
        let clamped = min(max(stepped, range.lowerBound), range.upperBound)
        if clamped != value { value = clamped }
    }
}

/// One chip per time step: minus takes that much off the session, plus adds it or starts one.
struct KeepAwakeTimeButtons: View {
    @ObservedObject var keepAwake: KeepAwakeManager
    /// Short labels ("15m") for the menu bar panel.
    var compact = false

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            ForEach(KeepAwakeManager.extensions, id: \.seconds) { option in
                HStack(spacing: 0) {
                    step("minus", "Take \(option.label) off the current session") { keepAwake.shorten(by: option.seconds) }
                        .disabled(!keepAwake.canShorten)
                    Text(compact ? option.label.replacingOccurrences(of: " min", with: "m").replacingOccurrences(of: " hr", with: "h") : option.label)
                        .font(Theme.bodyStrong)
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                    step("plus", keepAwake.isActive ? "Add \(option.label) to the current session" : "Keep awake for \(option.label)") { keepAwake.extend(by: option.seconds) }
                        .disabled(!keepAwake.canExtend)
                }
                .padding(.horizontal, compact ? 0 : Theme.Space.xs)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(Theme.control, in: Capsule())
            }
        }
    }

    private func step(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: compact ? 20 : 24, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(StepButtonStyle())
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct StepButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Tint.awake.start : Theme.tertiary.opacity(0.5))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct KeepAwakeDurationMenu: View {
    @ObservedObject var keepAwake: KeepAwakeManager

    var body: some View {
        Menu {
            Picker("Duration", selection: $keepAwake.duration) {
                ForEach(KeepAwakeManager.Duration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: Theme.Space.xs) {
                Text(keepAwake.duration.label)
                    .foregroundStyle(Theme.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
            }
            .font(Theme.bodyStrong)
            .padding(.horizontal, Theme.Space.m)
            .frame(minHeight: 28)
            .background(Theme.control, in: Capsule())
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Default duration")
    }
}

/// Time chips, then the switch's default duration and the lid option as labelled rows.
struct KeepAwakeSettings: View {
    @ObservedObject var keepAwake: KeepAwakeManager

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            HStack {
                Text("The switch keeps it awake for")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: Theme.Space.s)
                KeepAwakeDurationMenu(keepAwake: keepAwake)
                    .help("How long Keep Awake runs when you turn the switch on")
            }
            if keepAwake.hasTimedSession {
                KeepAwakeTimeButtons(keepAwake: keepAwake)
            }
            VStack(spacing: Theme.Space.m) {
                HStack {
                    Text("Stay awake with the lid closed")
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondary)
                    Spacer(minLength: Theme.Space.s)
                    Toggle("Stay awake with the lid closed", isOn: $keepAwake.worksWithLidClosed)
                        .toggleStyle(TintSwitchStyle(tint: .awake, small: true))
                        .help("Without this, closing the lid puts the Mac to sleep even while Keep Awake is on")
                }
            }
        }
    }
}

struct PermissionNotice: View {
    @ObservedObject var controller: MotionController

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("One thing first")
                    .font(Theme.title)
                    .foregroundStyle(Theme.primary)
                Text("Dă-i needs Accessibility access to see your shortcuts and swipes, and to block input while locked.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Open Settings…") { controller.openAccessibilitySettings() }
                .buttonStyle(PillButtonStyle(tint: .brand))
        }
        .card()
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Tint.brand.gradient, lineWidth: 1)
        }
    }
}

extension KeepAwakeManager {
    var shortStatus: String {
        endDate.map { "until \($0.formatted(date: .omitted, time: .shortened))" } ?? "until switched off"
    }

    var statusLine: String? {
        guard isActive else { return nil }
        guard let endDate else { return "Awake until you switch it off" }
        return "Awake until \(endDate.formatted(date: .omitted, time: .shortened))"
    }
}

extension MotionController {
    /// The multiplier without the sign, e.g. "1.25" or "2".
    var multiplierDigits: String {
        var text = String(format: "%.2f", speed / 40)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    var spaceSwitchingStatus: String? {
        hasAccessibilityPermission ? nil : "Waiting for Accessibility access"
    }
}
