#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-Debug}"
case "$configuration" in Debug|Release) ;; *) echo "Usage: $0 [Debug|Release]" >&2; exit 2;; esac
mkdir -p .build/ModuleCache dist
if [ ! -f Resources/Tether.icns ]; then
    xcrun swift -module-cache-path "$PWD/.build/ModuleCache" scripts/generate-icon.swift .build/Tether.iconset
    python3 scripts/assemble-icon.py
fi
xcodebuild -project Tether.xcodeproj -scheme Tether -configuration "$configuration" \
    -derivedDataPath "$PWD/.build/xcode" -arch arm64 -arch x86_64 ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO build
rm -rf "dist/$configuration/Tether.app"
mkdir -p "dist/$configuration"
ditto ".build/xcode/Build/Products/$configuration/Tether.app" "dist/$configuration/Tether.app"
echo "Built: dist/$configuration/Tether.app"
