// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Carbon.HIToolbox

/// A user-recorded trigger for Smart Zoom.
struct SmartZoomShortcut: Codable, Equatable {
    enum Kind: String, Codable {
        /// A key pressed with modifiers, or a bare function key.
        case key
        /// A key without modifiers, pressed twice quickly.
        case doubleKey
        /// A single modifier tapped twice quickly; `modifiers` holds its bit.
        case doubleModifier
        case mouseButton
    }

    var kind: Kind
    /// Virtual key code, or mouse button number (2 = middle). Unused for `doubleModifier`.
    var code: Int64
    /// Device-independent modifier bits, shared by NSEvent and CGEvent flags.
    var modifiers: UInt64
    var label: String

    static let modifierFlags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    static let modifierMask = UInt64(modifierFlags.rawValue)
    /// Longest gap between the two presses of a double-tap, in seconds.
    static let doubleTapInterval: TimeInterval = 0.4

    static func key(_ event: NSEvent) -> SmartZoomShortcut? {
        guard let name = keyName(event) else { return nil }
        let flags = event.modifierFlags.intersection(modifierFlags)
        return SmartZoomShortcut(
            kind: .key, code: Int64(event.keyCode), modifiers: UInt64(flags.rawValue),
            label: symbols(for: flags) + name)
    }

    static func doubleKey(_ event: NSEvent) -> SmartZoomShortcut? {
        guard let name = keyName(event) else { return nil }
        return SmartZoomShortcut(kind: .doubleKey, code: Int64(event.keyCode), modifiers: 0, label: "\(name) \(name)")
    }

    static func doubleModifier(_ flag: NSEvent.ModifierFlags) -> SmartZoomShortcut {
        let symbol = symbols(for: flag)
        return SmartZoomShortcut(
            kind: .doubleModifier, code: 0, modifiers: UInt64(flag.rawValue), label: "\(symbol) \(symbol)")
    }

    static func mouseButton(_ event: NSEvent) -> SmartZoomShortcut {
        let flags = event.modifierFlags.intersection(modifierFlags)
        let name = event.buttonNumber == 2 ? "Middle Click" : "Mouse Button \(event.buttonNumber + 1)"
        return SmartZoomShortcut(
            kind: .mouseButton, code: Int64(event.buttonNumber), modifiers: UInt64(flags.rawValue),
            label: symbols(for: flags) + name)
    }

    static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        functionKeys[Int64(keyCode)] != nil
    }

    static func keyName(_ event: NSEvent) -> String? {
        let keyCode = Int64(event.keyCode)
        let name = functionKeys[keyCode] ?? namedKeys[keyCode] ?? event.charactersIgnoringModifiers?.uppercased()
        return name?.isEmpty == false ? name : nil
    }

    /// Why this shortcut cannot be used, or nil if it is free.
    var conflict: String? {
        guard kind == .key else { return nil }
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))

        if flags == .control, code == 123 || code == 124 {
            return "\(label) switches Spaces"
        }
        if Self.systemHotKeys.contains(where: { $0.code == code && $0.modifiers == modifiers }) {
            return "\(label) is used by macOS"
        }
        if flags == .command || flags == [.command, .shift] {
            return "\(label) belongs to apps. Add ⌃ or ⌥"
        }
        if Self.reservedCombos.contains(where: { $0.code == code && $0.flags == flags }) {
            return "\(label) is used by macOS"
        }
        return nil
    }

    /// Shortcuts currently enabled under System Settings → Keyboard Shortcuts.
    private static var systemHotKeys: [(code: Int64, modifiers: UInt64)] {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let hotKeys = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return [] }

        return hotKeys.compactMap { hotKey in
            guard hotKey[kHISymbolicHotKeyEnabled as String] as? Bool == true,
                  let code = hotKey[kHISymbolicHotKeyCode as String] as? Int,
                  let carbon = hotKey[kHISymbolicHotKeyModifiers as String] as? Int else { return nil }
            var flags: NSEvent.ModifierFlags = []
            if carbon & cmdKey != 0 { flags.insert(.command) }
            if carbon & shiftKey != 0 { flags.insert(.shift) }
            if carbon & optionKey != 0 { flags.insert(.option) }
            if carbon & controlKey != 0 { flags.insert(.control) }
            return (Int64(code), UInt64(flags.rawValue))
        }
    }

    /// Fixed system combinations that do not appear in the symbolic hot key list.
    private static let reservedCombos: [(code: Int64, flags: NSEvent.ModifierFlags)] = [
        (53, [.command, .option]),           // Force Quit
        (12, [.command, .control]),          // Lock Screen
        (3, [.command, .control]),           // Full Screen
        (49, [.command, .control]),          // Emoji picker
        (2, [.command, .option]),            // Show/hide Dock
        (4, [.command, .option]),            // Hide Others
        (13, [.command, .option]),           // Close All
        (46, [.command, .option]),           // Minimize All
        (53, [.command, .option, .shift]),   // Force quit frontmost app
        (12, [.command, .option, .shift]),   // Log Out immediately
    ]

    static func symbols(for flags: NSEvent.ModifierFlags) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result
    }

    private static let namedKeys: [Int64: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤", 117: "⌦",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    private static let functionKeys: [Int64: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
        100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13",
        107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]
}

/// Turns the key, modifier and mouse events seen while recording into a shortcut.
@MainActor
final class ShortcutRecorder {
    enum Outcome {
        case captured(SmartZoomShortcut)
        case hint(String)
        case cancelled
        case ignored
    }

    private var pendingKey: (code: UInt16, time: TimeInterval)?
    private var pendingModifier: (flag: NSEvent.ModifierFlags, time: TimeInterval)?
    private var modifierDown: (flag: NSEvent.ModifierFlags, time: TimeInterval)?
    private var previousFlags: NSEvent.ModifierFlags = []

    func handle(_ event: NSEvent) -> Outcome {
        switch event.type {
        case .otherMouseDown:
            return .captured(.mouseButton(event))
        case .keyDown:
            return handleKey(event)
        case .flagsChanged:
            return handleModifier(event)
        default:
            return .ignored
        }
    }

    private func handleKey(_ event: NSEvent) -> Outcome {
        modifierDown = nil
        pendingModifier = nil
        guard !event.isARepeat else { return .ignored }

        let flags = event.modifierFlags.intersection(SmartZoomShortcut.modifierFlags)
        if flags.isEmpty, event.keyCode == 53 { return .cancelled }

        if !flags.isDisjoint(with: [.control, .option, .command])
            || (flags.isEmpty && SmartZoomShortcut.isFunctionKey(event.keyCode)) {
            pendingKey = nil
            guard let shortcut = SmartZoomShortcut.key(event) else { return .ignored }
            if let conflict = shortcut.conflict { return .hint(conflict) }
            return .captured(shortcut)
        }

        guard flags.isEmpty, let name = SmartZoomShortcut.keyName(event) else {
            pendingKey = nil
            return .hint("Add ⌃, ⌥ or ⌘, or double-tap a key")
        }
        if let pendingKey, pendingKey.code == event.keyCode,
           event.timestamp - pendingKey.time < SmartZoomShortcut.doubleTapInterval,
           let shortcut = SmartZoomShortcut.doubleKey(event) {
            return .captured(shortcut)
        }
        pendingKey = (event.keyCode, event.timestamp)
        return .hint("Press \(name) again quickly, or add ⌃ ⌥ ⌘")
    }

    private func handleModifier(_ event: NSEvent) -> Outcome {
        let flags = event.modifierFlags.intersection(SmartZoomShortcut.modifierFlags)
        defer { previousFlags = flags }
        pendingKey = nil

        let single: [NSEvent.ModifierFlags] = [.control, .option, .shift, .command]
        if previousFlags.isEmpty, single.contains(flags) {
            modifierDown = (flags, event.timestamp)
            return .ignored
        }
        guard flags.isEmpty, let down = modifierDown, down.flag == previousFlags,
              event.timestamp - down.time < SmartZoomShortcut.doubleTapInterval else {
            modifierDown = nil
            if !flags.isEmpty { pendingModifier = nil }
            return .ignored
        }
        modifierDown = nil

        if let pendingModifier, pendingModifier.flag == down.flag,
           event.timestamp - pendingModifier.time < SmartZoomShortcut.doubleTapInterval {
            return .captured(.doubleModifier(down.flag))
        }
        pendingModifier = (down.flag, event.timestamp)
        return .hint("Tap \(SmartZoomShortcut.symbols(for: down.flag)) again quickly for a double-tap")
    }
}
