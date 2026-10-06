#!/bin/bash
# Builds a Release Microkit.app, installs it to /Applications, then deletes the build folder.
# The build folder holds only regenerable caches (hundreds of MB), so it never outlives the install.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Microkit.xcodeproj -scheme Microkit -configuration Release -derivedDataPath build build -quiet

BUILT="build/Build/Products/Release/Microkit.app"
DEST="/Applications/Microkit.app"

osascript -e 'quit app id "in.pooya.microkit"' 2>/dev/null || true
rm -rf "$DEST"
ditto "$BUILT" "$DEST"
codesign --verify --deep --strict "$DEST"
rm -rf build
echo "Installed $DEST"
open "$DEST"
