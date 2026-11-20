// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices
import Carbon.HIToolbox
import AppKit
import SwiftUI
import Foundation

@MainActor
final class MotionController: ObservableObject {
    @Published var speed: Double {
        didSet {
            engine.velocity = speed
            storage.set(speed, forKey: speedKey)
        }
    }
    @Published var isEnabled: Bool {
        didSet {
            storage.set(isEnabled, forKey: enabledKey)
            configureEngine()
        }
    }
    @Published var smartZoomShortcut: SmartZoomShortcut? {
        didSet {
            configureEngine()
            storage.set(smartZoomShortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: smartZoomKey)
        }
    }
    /// Tools switched off in Settings are stopped and hidden everywhere.
    @Published var showsSpaceSwitching: Bool {
        didSet {
            storage.set(showsSpaceSwitching, forKey: showsSpaceKey)
            configureEngine()
        }
    }
    @Published var showsSmartZoom: Bool {
        didSet {
            storage.set(showsSmartZoom, forKey: showsZoomKey)
            if !showsSmartZoom, recordingTarget == .smartZoom { stopRecording() }
            configureEngine()
        }
    }
    /// The order of the tools in the window, the menu bar panel and Settings.
    @Published var toolOrder: [Tool] {
        didSet { storage.set(toolOrder.map(\.rawValue), forKey: toolOrderKey) }
    }
    @Published var showsInputLock: Bool {
        didSet {
            storage.set(showsInputLock, forKey: showsLockKey)
            if !showsInputLock, recordingTarget == .inputLock { stopRecording() }
            configureEngine()
        }
    }
    @Published var inputLockShortcut: SmartZoomShortcut? {
        didSet {
            configureEngine()
            storage.set(inputLockShortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: inputLockKey)
        }
    }
    @Published private(set) var isInputLocked = false
    enum RecordingTarget { case smartZoom, inputLock }
    @Published private(set) var recordingTarget: RecordingTarget?
    var isRecordingSmartZoom: Bool { recordingTarget == .smartZoom }
    var isRecordingInputLock: Bool { recordingTarget == .inputLock }
    private var isTapRunning = false
    @Published private(set) var recordingHint: String?
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var isRunning = false
    @Published private(set) var message = "Starting…"
    /// Name of the app holding Secure Input, which hides all key presses from the app.
    @Published private(set) var keyboardBlocker: String?

    private let engine = HotkeyEngine()
    private let storage = UserDefaults.standard
    private let speedKey = "gestureVelocity"
    private let enabledKey = "acceleratorEnabled"
    private let smartZoomKey = "smartZoomShortcut"
    private let showsSpaceKey = "toolSpaceSwitching"
    private let showsZoomKey = "toolSmartZoom"
    private let showsLockKey = "toolInputLock"
    private let toolOrderKey = "toolOrder"
    private let inputLockKey = "inputLockShortcut"
    private let lockOverlay = LockOverlay()
    private var permissionTimer: Timer?
    private var secureInputTimer: Timer?
    private var recordingMonitor: Any?
    private let permissionGuide = PermissionGuide()

    init() {
        let savedSpeed = storage.double(forKey: speedKey)
        speed = savedSpeed == 0 ? 60 : savedSpeed
        isEnabled = storage.object(forKey: enabledKey) as? Bool ?? true
        showsSpaceSwitching = storage.object(forKey: showsSpaceKey) as? Bool ?? true
        showsSmartZoom = storage.object(forKey: showsZoomKey) as? Bool ?? true
        showsInputLock = storage.object(forKey: showsLockKey) as? Bool ?? true
        let savedOrder = (storage.stringArray(forKey: toolOrderKey) ?? []).compactMap(Tool.init(rawValue:))
        toolOrder = savedOrder + Tool.allCases.filter { !savedOrder.contains($0) }
        inputLockShortcut = storage.data(forKey: inputLockKey)
            .flatMap { try? JSONDecoder().decode(SmartZoomShortcut.self, from: $0) }
            .flatMap { $0.conflict == nil ? $0 : nil }
        smartZoomShortcut = storage.data(forKey: smartZoomKey)
            .flatMap { try? JSONDecoder().decode(SmartZoomShortcut.self, from: $0) }
            .flatMap { $0.conflict == nil ? $0 : nil }
        engine.velocity = speed
        engine.smartZoomShortcut = showsSmartZoom ? smartZoomShortcut : nil
        engine.onLockChange = { [weak self] locked in
            MainActor.assumeIsolated { self?.inputLockChanged(locked) }
        }
        // Locking the screen or sleeping releases Input Lock, so there is always a way out.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.unlockInput() }
            }
        }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.unlockInput() }
        }
        refreshPermission()
        if !hasAccessibilityPermission { startPermissionPolling() }
        refreshSecureInput()
        secureInputTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSecureInput() }
        }
    }

    /// Carries settings over from the app's previous bundle identifier, once.
    static func migrateLegacySettings() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedLegacySettings") else { return }
        defaults.set(true, forKey: "migratedLegacySettings")
        let legacy = defaults.persistentDomain(forName: "local.spaceshift.app") ?? [:]
        for (key, value) in legacy where !key.hasPrefix("NSWindow") {
            defaults.set(value, forKey: key)
        }
    }

    var approximateMultiplier: String {
        String(format: "%.1f×", speed / 40)
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
        message = "Allow Dă-i in System Settings"
        permissionGuide.show()
        startPermissionPolling()
    }

    func refreshPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        if hasAccessibilityPermission { permissionGuide.close() }
        configureEngine()
    }

    func setPreset(_ velocity: Double) {
        speed = velocity
    }

    func testRight() {
        guard isRunning else { return }
        engine.switchSpace(.right)
    }

    func smartZoom() {
        guard isRunning else { return }
        engine.smartZoom()
    }

    /// Captures the next shortcut, double-tap or extra mouse button pressed in one of the app's windows.
    func startRecordingSmartZoom() { startRecording(.smartZoom) }
    func startRecordingInputLock() { startRecording(.inputLock) }

    private func startRecording(_ target: RecordingTarget) {
        guard recordingMonitor == nil else { return }
        // Otherwise the event tap would swallow the current shortcut before it can be re-recorded.
        engine.smartZoomShortcut = nil
        engine.inputLockShortcut = nil
        recordingTarget = target
        recordingHint = nil
        // A menu bar app's window can be clicked without becoming key, and then sees no key presses.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible && $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
        let recorder = ShortcutRecorder()
        recordingMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged, .otherMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch recorder.handle(event) {
                case .captured(let shortcut):
                    let other = target == .smartZoom ? self.inputLockShortcut : self.smartZoomShortcut
                    if shortcut == other {
                        let owner = target == .smartZoom ? "Input Lock" : "Smart Zoom"
                        self.recordingHint = "\(shortcut.label) is already used for \(owner)"
                        return
                    }
                    self.stopRecording()
                    switch target {
                    case .smartZoom: self.smartZoomShortcut = shortcut
                    case .inputLock: self.inputLockShortcut = shortcut
                    }
                case .hint(let hint):
                    self.recordingHint = hint
                case .cancelled:
                    self.stopRecording()
                case .ignored:
                    break
                }
            }
            return event.type == .flagsChanged ? event : nil
        }
    }

    func stopRecordingSmartZoom() { stopRecording() }

    func stopRecording() {
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        recordingTarget = nil
        recordingHint = nil
        configureEngine()
    }

    /// Locks the keyboard and mouse buttons until the Input Lock shortcut is pressed.
    func lockInput() {
        guard showsInputLock, inputLockShortcut != nil, isTapRunning else { return }
        engine.isLocked = true
        inputLockChanged(true)
    }

    func moveTool(_ tool: Tool, to index: Int) {
        guard let from = toolOrder.firstIndex(of: tool), toolOrder.indices.contains(index), from != index else { return }
        toolOrder.move(fromOffsets: IndexSet(integer: from), toOffset: index > from ? index + 1 : index)
    }

    func unlockInput() {
        guard isInputLocked else { return }
        engine.isLocked = false
        inputLockChanged(false)
    }

    private func inputLockChanged(_ locked: Bool) {
        isInputLocked = locked
        if locked, let shortcut = inputLockShortcut {
            lockOverlay.show(unlockWith: shortcut.label)
        } else {
            lockOverlay.hide()
        }
    }

    private func refreshSecureInput() {
        var blocker: String?
        if IsSecureEventInputEnabled() {
            blocker = "another app"
            let root = IORegistryGetRootEntry(kIOMainPortDefault)
            defer { IOObjectRelease(root) }
            let users = IORegistryEntryCreateCFProperty(root, "IOConsoleUsers" as CFString, nil, 0)?
                .takeRetainedValue() as? [[String: Any]]
            if let pid = users?.compactMap({ $0["kCGSSessionSecureInputPID"] as? Int32 }).first,
               let name = NSRunningApplication(processIdentifier: pid)?.localizedName {
                blocker = name
            }
        }
        if blocker != keyboardBlocker { keyboardBlocker = blocker }
    }

    private func configureEngine() {
        guard hasAccessibilityPermission else {
            stopEngine()
            message = "Accessibility permission required"
            return
        }
        let accelerates = isEnabled && showsSpaceSwitching
        let zoomShortcut = showsSmartZoom ? smartZoomShortcut : nil
        let lockShortcut = showsInputLock ? inputLockShortcut : nil
        if recordingTarget == nil {
            engine.smartZoomShortcut = zoomShortcut
            engine.inputLockShortcut = lockShortcut
        }
        if lockShortcut == nil, engine.isLocked {
            engine.isLocked = false
            inputLockChanged(false)
        }
        // The shortcuts share the event tap, so it keeps running while Space switching is off.
        guard accelerates || zoomShortcut != nil || lockShortcut != nil else {
            stopEngine()
            message = "Paused"
            return
        }

        engine.velocity = speed
        engine.acceleratesSpaces = accelerates
        let tapRunning = engine.start()
        isTapRunning = tapRunning
        isRunning = tapRunning && accelerates
        message = tapRunning ? (accelerates ? "Active" : "Paused") : "Event interception failed"
    }

    private func stopEngine() {
        engine.stop()
        isRunning = false
        isTapRunning = false
        if isInputLocked { inputLockChanged(false) }
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            Task { @MainActor in
                self?.refreshPermission()
            }
        }
    }
}
