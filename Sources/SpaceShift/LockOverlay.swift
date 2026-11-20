// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

/// A banner at the top of the screen while Input Lock is on, saying how to unlock.
@MainActor
final class LockOverlay {
    private var panel: NSPanel?

    func show(unlockWith shortcut: String) {
        hide()
        let host = NSHostingView(rootView: LockBanner(shortcut: shortcut))
        let size = host.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 16))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

struct LockBanner: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Tint.lock.gradient, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Keyboard and mouse locked")
                    .font(Theme.title)
                    .foregroundStyle(Theme.primary)
                Text("Press \(shortcut) to unlock")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(.vertical, Theme.Space.m)
        .padding(.leading, Theme.Space.m)
        .padding(.trailing, Theme.Space.xl)
        .background(Theme.surface, in: Capsule())
        .overlay { Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1) }
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .padding(Theme.Space.xl)
        .preferredColorScheme(.dark)
    }
}
