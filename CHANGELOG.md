# Changelog

All notable changes to Dă-i (formerly SpaceShift) are documented here.

## [Unreleased]

## [3.0] - 2026-11-17

First release of the fork, renamed from SpaceShift to Dă-i.

### Added

- Smart Zoom from a shortcut you record: a key combination, a double-tapped
  key or modifier, or a middle/side mouse button. Shortcuts that macOS or
  apps already use are refused.
- Keep Awake, with a default duration, time chips (15 min, 30 min, 1 hr, 2 hr)
  whose + and − lengthen or shorten a session, and an optional lid-closed mode.
- Menu bar panel with the Space Switching and Keep Awake switches, replacing
  the menu.
- Settings window to switch individual tools off, which stops and hides them.
- Custom About window.
- Floating guide on the System Settings window for dragging the app into the
  Accessibility list.
- A notice when another app's Secure Input hides key presses.

### Changed

- Renamed the app to Dă-i (bundle identifier `local.da-i.app`). Settings
  carry over; Accessibility access must be granted again.
- New icon and a redesigned dark window with one colour per tool.
- The Space Switching switch only controls Space switching; Smart Zoom keeps
  working when it is off.
- The app appears in the Dock and Command-Tab while a window is open.
- The installer is a plain drag-to-Applications disk image.

### Removed

- Donation window and its menu entries.
- The previous installer artwork and its tooling.

## [2.5] - 2026-09-15

### Fixed

- Restored keyboard and trackpad Space switching on macOS 27 by attaching the
  IOHID gesture payload now required by Dock.
- Corrected the physical trackpad swipe direction on macOS 27.
- Kept the pre-macOS 27 gesture path unchanged for backward compatibility.

### Changed

- Allowed release builds to use the bundled macOS 26.5 SDK when the standalone
  macOS 27 Command Line Tools cannot load SwiftUI macro implementations.

## [2.4] - 2026-08-18

### Added

- Adjustable native Space-switching speed from 1× to 2.5×.
- Support for `Control + Left/Right Arrow` and physical three-finger swipes.
- Menu bar controls, speed presets, and transition testing.
- Native Launch at Login integration through `SMAppService`.
- Drag-to-Applications DMG installer and release build tooling.
- Optional donation window with a locally generated QR code.
- About SpaceShift command in the menu bar menu.

### Changed

- Replaced the application and installer artwork with the new SpaceShift icon.
- Licensed the SpaceShift source code under GNU GPL v3.0.

### Security

- No networking, analytics, updater, or event logging.
- Optimized and stripped release binary with hardened runtime enabled.

[3.0]: https://github.com/abaicus/da-i/releases/tag/v3.0
[2.5]: https://github.com/ReutS1/SpaceShift/releases/tag/v2.5
[2.4]: https://github.com/ReutS1/SpaceShift/releases/tag/v2.4
