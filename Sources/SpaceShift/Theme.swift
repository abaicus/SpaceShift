// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

/// A feature's two-stop colour.
struct Tint {
    let start: Color
    let end: Color

    var gradient: LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Matches the app icon.
    static let brand = Tint(start: Color(red: 1.0, green: 0.62, blue: 0.10), end: Color(red: 1.0, green: 0.18, blue: 0.42))
    static let zoom = Tint(start: Color(red: 0.30, green: 0.78, blue: 1.0), end: Color(red: 0.25, green: 0.45, blue: 1.0))
    static let lock = Tint(start: Color(red: 0.78, green: 0.56, blue: 1.0), end: Color(red: 0.48, green: 0.30, blue: 0.92))
    static let awake = Tint(start: Color(red: 0.90, green: 0.66, blue: 0.38), end: Color(red: 0.48, green: 0.26, blue: 0.11))
}

/// Design tokens shared by every window.
enum Theme {
    // Grey scale, darkest to lightest.
    static let background = Color(white: 0.07)
    static let surface = Color(white: 0.12)
    static let control = Color(white: 0.20)
    static let tertiary = Color(white: 0.52)
    static let secondary = Color(white: 0.70)
    static let primary = Color(white: 0.96)
    /// Text and glyphs on a tinted fill.
    static let onTint = Color(white: 0.05)

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let large: CGFloat = 16
    }

    static let caption = Font.system(size: 11, weight: .medium)
    static let body = Font.system(size: 13)
    static let bodyStrong = Font.system(size: 13, weight: .semibold)
    static let title = Font.system(size: 15, weight: .semibold)
    static let heading = Font.system(size: 22, weight: .bold, design: .rounded)
    static let display = Font.system(size: 64, weight: .bold, design: .rounded)
}

extension View {
    /// A raised surface; `glow` washes it with a feature's colour.
    func card(glow: Tint? = nil, padding: CGFloat = Theme.Space.l) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Theme.surface)
                if let glow {
                    shape.fill(RadialGradient(
                        colors: [glow.end.opacity(0.28), glow.start.opacity(0)],
                        center: .topLeading, startRadius: 0, endRadius: 320))
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            }
    }
}

struct PillButtonStyle: ButtonStyle {
    /// Filled with this tint when set; grey otherwise.
    var tint: Tint?
    /// Stretches to share the row equally with its siblings.
    var fills = false
    /// Text only, for a secondary action beside a filled pill.
    var quiet = false

    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration, tint: tint, fills: fills, quiet: quiet)
    }

    private struct Pill: View {
        let configuration: Configuration
        let tint: Tint?
        let fills: Bool
        let quiet: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Theme.bodyStrong)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(quiet ? Theme.secondary : (tint == nil ? Theme.primary : Theme.onTint))
                .padding(.horizontal, fills ? Theme.Space.s : Theme.Space.m)
                .frame(maxWidth: fills ? .infinity : nil, minHeight: 28)
                .background {
                    if let tint {
                        Capsule().fill(tint.gradient)
                    } else if !quiet {
                        Capsule().fill(Theme.control)
                    }
                }
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
                .contentShape(Capsule())
        }
    }
}

struct TintSwitchStyle: ToggleStyle {
    let tint: Tint
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                Capsule().fill(Theme.control)
                Capsule().fill(tint.gradient).opacity(configuration.isOn ? 1 : 0)
            }
            .frame(width: small ? 36 : 44, height: small ? 22 : 26)
            .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    .padding(3)
                    .frame(width: small ? 22 : 26, height: small ? 22 : 26)
            }
            .animation(.easeOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

struct TintCheckStyle: ToggleStyle {
    var tint = Tint.brand

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Theme.Space.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.control)
                    if configuration.isOn {
                        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(tint.gradient)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.onTint)
                    }
                }
                .frame(width: 16, height: 16)
                configuration.label
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
