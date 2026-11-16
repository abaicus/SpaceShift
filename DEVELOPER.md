# Dă-i developer guide

## Requirements

- macOS 14 or newer
- Apple Swift toolchain / Command Line Tools
- Apple Developer ID Application certificate for public distribution

## Local build

```sh
./scripts/build-app.sh release
open dist/Dă-i.app
```

## DMG installer

```sh
./scripts/build-dmg.sh
```

## App icon

Draw the 1024×1024 master, then regenerate the icon set and `.icns`:

```sh
swift scripts/DrawIcon.swift Resources/da-i-master.png
swift scripts/IconBuilder.swift Resources/da-i-master.png .build/icon.iconset Resources/da-i.icns
```

## Signed and notarized release

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh release
NOTARY_PROFILE="da-i-notary" ./scripts/build-dmg.sh
```

`NOTARY_PROFILE` is the name of credentials previously stored with `xcrun notarytool store-credentials`.

## Project layout

- `Sources/SpaceShift/` — SwiftUI application, menu bar panel, event interception, Smart Zoom, Keep Awake. The package keeps its original name.
- `LaunchAtLoginManager.swift` — native Login Items integration through `SMAppService.mainApp`.
- `Resources/` — Info.plist and the application icon.
- `scripts/build-app.sh` — optimized, stripped, hardened application build.
- `scripts/build-dmg.sh` — drag-to-Applications DMG named after the version in Info.plist, with optional notarization.
- `scripts/DrawIcon.swift` — draws the application icon master.
- `scripts/IconBuilder.swift` — builds the icon set and `.icns` from the master.
- `THIRD_PARTY_NOTICES.md` — required license notice.
- `SECURITY.md` — release security model and limitations.

## Release checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Move the `[Unreleased]` notes in `CHANGELOG.md` under the new version.
3. Build with the Developer ID identity, or ad-hoc if you have none.
4. Create the DMG, and notarize it if signed with a Developer ID.
5. Run `codesign --verify --deep --strict` and `hdiutil verify`.
6. Tag `vX.Y` and publish the DMG with its SHA-256 checksum.

Do not put Apple signing certificates, private keys, wallet seed phrases, or notarization credentials into the project directory.
