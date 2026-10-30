#!/bin/zsh
# Redraws the app icon from Pip's own look, so the icon always matches Pip in the app.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
cat GlassClock/Pieces/PipLook.swift tools/icon-main.swift > "$TMP/icon.swift"
swift "$TMP/icon.swift" GlassClock/Assets.xcassets/AppIcon.appiconset/AppIcon.png
rm -rf "$TMP"
