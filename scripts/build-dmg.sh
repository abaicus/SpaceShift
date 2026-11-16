#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

project_dir="${0:A:h:h}"
app_path="$project_dir/dist/Dă-i.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
# ASCII file name: release hosts rewrite non-ASCII asset names.
dmg_path="$project_dir/dist/Da-i-$version.dmg"
stage_dir="$(mktemp -d /private/tmp/da-i-dmg.XXXXXX)"

cleanup() {
    if [[ "$stage_dir" == /private/tmp/da-i-dmg.* && -d "$stage_dir" ]]; then
        rm -rf "$stage_dir"
    fi
}
trap cleanup EXIT

if [[ ! -d "$app_path" ]]; then
    "$project_dir/scripts/build-app.sh" release
fi

ditto "$app_path" "$stage_dir/Dă-i.app"
ln -s /Applications "$stage_dir/Applications"

rm -f "$dmg_path"
hdiutil create -volname "Dă-i $version" -srcfolder "$stage_dir" -fs HFS+ \
    -format UDZO -imagekey zlib-level=9 "$dmg_path" >/dev/null

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$dmg_path"
fi

echo "$dmg_path"
