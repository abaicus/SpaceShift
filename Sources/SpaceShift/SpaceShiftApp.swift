// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification] {
            center.addObserver(self, selector: #selector(windowsChanged(_:)), name: name, object: nil)
        }
        updateActivationPolicy(closing: nil)
    }

    @objc private func windowsChanged(_ notification: Notification) {
        let closing = notification.name == NSWindow.willCloseNotification ? notification.object as? NSWindow : nil
        updateActivationPolicy(closing: closing)
    }

    /// Appears in the Dock and Command-Tab only while one of its windows is open.
    private func updateActivationPolicy(closing: NSWindow?) {
        let hasWindow = NSApp.windows.contains {
            $0 !== closing && $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel)
        }
        let policy: NSApplication.ActivationPolicy = hasWindow ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }
}

@main
struct SpaceShiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = MotionController()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @StateObject private var keepAwake = KeepAwakeManager()

    init() {
        MotionController.migrateLegacySettings()
    }

    var body: some Scene {
        WindowGroup("Dă-i", id: "main") {
            ContentView(controller: controller, launchAtLogin: launchAtLogin, keepAwake: keepAwake)
                .frame(width: 460)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) { AboutCommand() }
            CommandGroup(replacing: .appSettings) { SettingsCommand() }
        }

        Window("Settings", id: "settings") {
            SettingsView(controller: controller, launchAtLogin: launchAtLogin, keepAwake: keepAwake)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("About Dă-i", id: "about") {
            AboutView()
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            StatusPanel(controller: controller, keepAwake: keepAwake)
        } label: {
            Image(systemName: controller.isInputLocked ? "lock.fill" : "chevron.right.2")
                .accessibilityLabel("Dă-i")
        }
        .menuBarExtraStyle(.window)
    }
}
