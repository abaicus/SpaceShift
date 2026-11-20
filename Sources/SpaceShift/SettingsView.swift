// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: MotionController
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @ObservedObject var keepAwake: KeepAwakeManager
    @State private var dropTarget: Tool?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            section("Tools", note: "Drag to reorder. A tool you switch off stops working and disappears from the window and the menu bar.") {
                ForEach(Array(controller.toolOrder.enumerated()), id: \.element) { index, tool in
                    if index > 0 { divider }
                    toolRow(tool, index: index)
                }
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
        .padding(.top, Theme.Space.l)
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
            .padding(.leading, Theme.Space.m + 16 + Theme.Space.s + 28 + Theme.Space.m)
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

    private func isOn(_ tool: Tool) -> Binding<Bool> {
        switch tool {
        case .spaceSwitching: $controller.showsSpaceSwitching
        case .smartZoom: $controller.showsSmartZoom
        case .keepAwake: $keepAwake.isAvailable
        case .inputLock: $controller.showsInputLock
        }
    }

    private func toolRow(_ tool: Tool, index: Int) -> some View {
        let isOn = isOn(tool)
        return HStack(spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Image(systemName: tool.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tool.tint.gradient, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .saturation(isOn.wrappedValue ? 1 : 0)
                    .opacity(isOn.wrappedValue ? 1 : 0.6)
                    .accessibilityHidden(true)
            }
            Text(tool.title)
                .font(Theme.body)
                .foregroundStyle(Theme.primary)
            Spacer()
            Toggle(tool.title, isOn: isOn)
                .toggleStyle(TintSwitchStyle(tint: tool.tint, small: true))
                .help(isOn.wrappedValue ? "Switch \(tool.title) off and hide it" : "Switch \(tool.title) on and show it")
        }
        .padding(.leading, Theme.Space.m)
        .padding(.trailing, Theme.Space.l)
        .frame(height: 48)
        .background(dropTarget == tool ? Color.white.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .help("Drag to reorder")
        .draggable(tool.rawValue) {
            Label(tool.title, systemImage: tool.symbol)
                .font(Theme.body)
                .padding(Theme.Space.s)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let dragged = items.first.flatMap(Tool.init(rawValue:)) else { return false }
            withAnimation(.snappy(duration: 0.2)) { controller.moveTool(dragged, to: index) }
            return true
        } isTargeted: { targeted in
            if targeted { dropTarget = tool } else if dropTarget == tool { dropTarget = nil }
        }
        .contextMenu {
            Button("Move Up") { controller.moveTool(tool, to: index - 1) }
                .disabled(index == 0)
            Button("Move Down") { controller.moveTool(tool, to: index + 1) }
                .disabled(index == controller.toolOrder.count - 1)
        }
        .accessibilityAction(named: "Move up") { controller.moveTool(tool, to: index - 1) }
        .accessibilityAction(named: "Move down") { controller.moveTool(tool, to: index + 1) }
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
