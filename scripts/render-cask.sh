#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-only
# Renders dist/da-i.rb, the Homebrew cask abaicus/homebrew-tap copies from each release.
set -euo pipefail

project_dir="${0:A:h:h}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
dmg_path="$project_dir/dist/Da-i-$version.dmg"
cask_path="$project_dir/dist/da-i.rb"

if [[ ! -f "$dmg_path" ]]; then
    "$project_dir/scripts/build-dmg.sh" >/dev/null
fi
sha="$(shasum -a 256 "$dmg_path" | cut -d' ' -f1)"

# Quoted heredoc: the cask's own #{version} must reach the file untouched.
template="$(cat <<'CASK'
cask "da-i" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/abaicus/da-i/releases/download/v#{version}/Da-i-#{version}.dmg"
  name "Dă-i"
  desc "Menu-bar utility for faster Space switching, Smart Zoom, keep-awake and input lock"
  homepage "https://github.com/abaicus/da-i"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Dă-i.app"

  # Ad-hoc signed, not notarized: Gatekeeper would block the quarantined app.
  # The checksum is pinned above; this drops the flag on that verified download.
  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-dr", "com.apple.quarantine", "{{appdir}}/Dă-i.app"]
  end

  uninstall quit: "local.da-i.app"

  zap trash: "~/Library/Preferences/local.da-i.app.plist"

  caveats <<~EOS
    Dă-i needs Accessibility permission for Space Switching, Smart Zoom and Input Lock:
    System Settings → Privacy & Security → Accessibility.

    The build is ad-hoc signed, so macOS ties that permission to the exact
    binary. After every upgrade, remove Dă-i from the Accessibility list and
    add it again.
  EOS
end
CASK
)"
template="${template//@VERSION@/$version}"
print -r -- "${template//@SHA256@/$sha}" > "$cask_path"

echo "$cask_path"
