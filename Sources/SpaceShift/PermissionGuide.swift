// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

/// A floating strip pinned to the System Settings window, offering the app
/// icon to drag into the Accessibility list.
@MainActor
final class PermissionGuide {
    private static let settingsBundleID = "com.apple.systempreferences"
    private static let size = NSSize(width: 384, height: 80)
    private static let settingsSidebarWidth: CGFloat = 215

    private var panel: NSPanel?
    private var timer: Timer?
    private var sawSettings = false

    func show() {
        guard timer == nil else { return }
        sawSettings = false
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PermissionGuideView().frame(
            width: Self.size.width, height: Self.size.height))
        self.panel = panel

        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.follow() }
        }
    }

    func close() {
        timer?.invalidate()
        timer = nil
        panel?.close()
        panel = nil
    }

    private func follow() {
        guard let settings = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.settingsBundleID).first else {
            if sawSettings { close() }
            return
        }
        guard settings.isActive, let frame = settingsWindowFrame(pid: settings.processIdentifier) else {
            panel?.orderOut(nil)
            return
        }
        sawSettings = true

        let detailWidth = frame.width - Self.settingsSidebarWidth
        let origin = NSPoint(
            x: frame.minX + Self.settingsSidebarWidth + (detailWidth - Self.size.width) / 2,
            y: frame.minY + 16
        )
        panel?.setFrameOrigin(origin)
        panel?.orderFrontRegardless()
    }

    /// Frame of the largest System Settings window, in AppKit screen coordinates.
    private func settingsWindowFrame(pid: pid_t) -> NSRect? {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]], let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }

        let frames = windows.compactMap { window -> CGRect? in
            guard window[kCGWindowOwnerPID as String] as? pid_t == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
        guard let bounds = frames.max(by: { $0.width * $0.height < $1.width * $1.height }),
              bounds.width > Self.settingsSidebarWidth + Self.size.width else { return nil }
        return NSRect(x: bounds.minX, y: primaryHeight - bounds.maxY, width: bounds.width, height: bounds.height)
    }
}

private struct PermissionGuideView: View {
    var body: some View {
        HStack(spacing: Theme.Space.m) {
            AppDragSource()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text("Drag Dă-i into the list above")
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.primary)
                Text("Or switch it on if it is already listed.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .preferredColorScheme(.dark)
    }
}

private struct AppDragSource: NSViewRepresentable {
    func makeNSView(context: Context) -> DragSourceView { DragSourceView() }
    func updateNSView(_ nsView: DragSourceView, context: Context) {}
}

private final class DragSourceView: NSView, NSDraggingSource {
    private let icon: NSImage = NSApp.applicationIconImage

    // The panel never becomes key, so the first click must already start the drag.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        icon.draw(in: bounds)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
        item.setDraggingFrame(bounds, contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }
}
