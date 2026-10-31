#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh Release
app="$PWD/dist/Release/Tether.app"
if [ -n "${SIGNING_IDENTITY:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
    codesign --verify --strict --verbose=2 "$app"
else
    codesign --force --sign - "$app"
    echo "Ad-hoc signed for local evaluation. Developer ID and notarization are required for distribution."
fi
stage=$(mktemp -d "${TMPDIR:-/tmp}/tether-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Tether.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Tether -srcfolder "$stage" -ov -format UDZO dist/Tether-2.1.0.dmg
if [ -n "${SIGNING_IDENTITY:-}" ]; then
    codesign --timestamp --sign "$SIGNING_IDENTITY" dist/Tether-2.1.0.dmg
fi
