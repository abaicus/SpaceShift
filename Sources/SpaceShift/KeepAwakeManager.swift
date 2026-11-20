// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import IOKit
import IOKit.pwr_mgt

/// Holds a power assertion so the Mac and its display stay awake, optionally
/// for a limited time and optionally with the lid closed.
@MainActor
final class KeepAwakeManager: ObservableObject {
    enum Duration: Int, CaseIterable, Identifiable {
        case indefinitely = 0
        case fiveMinutes = 300
        case thirtyMinutes = 1800
        case oneHour = 3600
        case twoHours = 7200
        case fiveHours = 18000
        case eightHours = 28800

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .indefinitely: "Indefinitely"
            case .fiveMinutes: "5 minutes"
            case .thirtyMinutes: "30 minutes"
            case .oneHour: "1 hour"
            case .twoHours: "2 hours"
            case .fiveHours: "5 hours"
            case .eightHours: "8 hours"
            }
        }
    }

    @Published var isActive = false {
        didSet { if oldValue != isActive { apply() } }
    }
    @Published var duration: Duration {
        didSet {
            storage.set(duration.rawValue, forKey: durationKey)
            if isActive { scheduleEnd() }
        }
    }
    @Published var worksWithLidClosed: Bool {
        didSet {
            storage.set(worksWithLidClosed, forKey: lidKey)
            if isActive { setLidSleepDisabled(worksWithLidClosed) }
        }
    }
    @Published private(set) var endDate: Date?
    /// Off when the tool is switched off in Settings.
    @Published var isAvailable: Bool {
        didSet {
            storage.set(isAvailable, forKey: availableKey)
            if !isAvailable { isActive = false }
        }
    }

    private let storage = UserDefaults.standard
    private let durationKey = "keepAwakeDuration"
    private let lidKey = "keepAwakeLidClosed"
    private let availableKey = "toolKeepAwake"
    private var assertion: IOPMAssertionID = 0
    private var endTimer: Timer?
    private var pendingEnd: Date?
    private var rootDomain: io_connect_t = 0
    private var terminationObserver: NSObjectProtocol?

    init() {
        duration = Duration(rawValue: storage.integer(forKey: durationKey)) ?? .indefinitely
        worksWithLidClosed = storage.bool(forKey: lidKey)
        isAvailable = storage.object(forKey: availableKey) as? Bool ?? true
        // The lid override outlives the process, so it must be cleared on quit.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isActive = false }
        }
    }

    private func apply() {
        if isActive {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Dă-i Keep Awake" as CFString,
                &assertion
            )
            guard result == kIOReturnSuccess else {
                isActive = false
                return
            }
            if worksWithLidClosed { setLidSleepDisabled(true) }
            scheduleEnd()
        } else {
            endTimer?.invalidate()
            endTimer = nil
            endDate = nil
            if assertion != 0 { IOPMAssertionRelease(assertion) }
            assertion = 0
            setLidSleepDisabled(false)
        }
    }

    /// Quick time steps offered next to the duration, in seconds.
    static let extensions: [(label: String, seconds: TimeInterval)] = [
        ("15 min", 900), ("30 min", 1800), ("1 hr", 3600), ("2 hr", 7200),
    ]

    /// Pushes the end time back, or starts a timed session if Keep Awake is off.
    func extend(by seconds: TimeInterval) {
        if !isActive {
            pendingEnd = Date().addingTimeInterval(seconds)
            isActive = true
        } else if let endDate {
            scheduleEnd(at: endDate.addingTimeInterval(seconds))
        }
    }

    /// Pulls the end time in; switches off if that leaves no time.
    func shorten(by seconds: TimeInterval) {
        guard isActive, let endDate else { return }
        let end = endDate.addingTimeInterval(-seconds)
        if end > Date() {
            scheduleEnd(at: end)
        } else {
            isActive = false
        }
    }

    /// False while awake with no end time, or when the switch would start such a session.
    var hasTimedSession: Bool {
        isActive ? endDate != nil : duration != .indefinitely
    }

    var canShorten: Bool {
        isActive && endDate != nil
    }

    var canExtend: Bool {
        !isActive || endDate != nil
    }

    private func scheduleEnd() {
        let end = pendingEnd ?? (duration == .indefinitely ? nil : Date().addingTimeInterval(TimeInterval(duration.rawValue)))
        pendingEnd = nil
        scheduleEnd(at: end)
    }

    private func scheduleEnd(at end: Date?) {
        endTimer?.invalidate()
        endTimer = nil
        endDate = end
        guard let end else { return }

        endTimer = Timer.scheduledTimer(withTimeInterval: max(end.timeIntervalSinceNow, 0), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.isActive = false }
        }
    }

    private func setLidSleepDisabled(_ disabled: Bool) {
        if rootDomain == 0 {
            guard disabled else { return }
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
            guard service != 0 else { return }
            defer { IOObjectRelease(service) }
            guard IOServiceOpen(service, mach_task_self_, 0, &rootDomain) == kIOReturnSuccess else {
                rootDomain = 0
                return
            }
        }
        // Selector 12 is kPMSetClamshellSleepState on the root power domain's user client.
        var input: UInt64 = disabled ? 1 : 0
        IOConnectCallScalarMethod(rootDomain, 12, &input, 1, nil, nil)
    }
}
