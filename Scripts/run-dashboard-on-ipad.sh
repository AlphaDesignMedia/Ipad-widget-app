#!/bin/zsh
# Builds Glass Dashboard (the progress dashboard's companion app and Home Screen widget),
# installs it on the plugged-in iPad and opens it. Same approach as run-on-ipad.sh:
#   --debug    a Debug build instead of Release
# No App Groups or keychain sharing, so the free Personal Team needs no entitlements swap.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=2UUL2QMJGB
BUILD_DIR="${TMPDIR:-/tmp}/glassdashboard-build"
CONFIG=Release
for option in "$@"; do
  [[ "$option" == --debug ]] && CONFIG=Debug
done
# Xcode 27.1 lists a reachable iPad as "available (paired)" rather than "connected".
DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPad/ && (/connected/ || /available/) {print $3; exit}')
[[ -n "$DEVICE" ]] || { echo "No connected iPad found."; exit 1; }
xcodebuild -project GlassClock.xcodeproj -scheme GlassDashboard -configuration $CONFIG \
  -destination "generic/platform=iOS" -derivedDataPath "$BUILD_DIR" \
  DEVELOPMENT_TEAM=$TEAM -allowProvisioningUpdates -quiet build

# If this fails with "Could not allocate a resource", see run-on-ipad.sh.
xcrun devicectl device install app --device "$DEVICE" \
  "$BUILD_DIR/Build/Products/$CONFIG-iphoneos/GlassDashboard.app" >/dev/null
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing \
  com.aarondennel.glassdashboard >/dev/null
echo "Glass Dashboard is running on the iPad."
