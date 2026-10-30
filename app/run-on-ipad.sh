#!/bin/zsh
# Builds the Pip Sandbox app, installs it on the iPad and opens it.
# Adapted from Glass Clock's Scripts/run-on-ipad.sh, with its own bundle ID and build folder,
# so it never touches Glass Clock on the iPad. Free Personal Team: no App Groups, so the build
# swaps in Config/FreeTeam.entitlements (settings shared through the keychain instead).
#   --debug  a Debug build instead of Release
set -euo pipefail
cd "$(dirname "$0")"

TEAM=2UUL2QMJGB
BUILD_DIR="${TMPDIR:-/tmp}/pipsandbox-build"
CONFIG=Release
[[ "${1:-}" == --debug ]] && CONFIG=Debug

DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPad/ && (/connected/ || /available/) {print $3; exit}')
[[ -n "$DEVICE" ]] || { echo "No connected iPad found."; exit 1; }

xcodebuild -project PipSandbox.xcodeproj -scheme GlassClock -configuration $CONFIG \
  -destination "generic/platform=iOS" -derivedDataPath "$BUILD_DIR" \
  DEVELOPMENT_TEAM=$TEAM CODE_SIGN_ENTITLEMENTS=Config/FreeTeam.entitlements -allowProvisioningUpdates -quiet build

# If this fails with "Could not allocate a resource": `pkill -x CoreDeviceService`, then retry.
xcrun devicectl device install app --device "$DEVICE" \
  "$BUILD_DIR/Build/Products/$CONFIG-iphoneos/GlassClock.app" >/dev/null
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing com.aarondennel.pipsandbox >/dev/null
echo "Pip Sandbox is running on the iPad."
