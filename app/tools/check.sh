#!/bin/zsh
# The plugin maker's test: builds the app for the iPad simulator, opens it and saves a screenshot.
# Never touches the real iPad or Glass Clock.
#   ./tools/check.sh           build, run, screenshot after 8 seconds
#   ./tools/check.sh --build   build only
#   ./tools/check.sh --fresh   as if Pip had never been met (shows the first meeting)
# Prints only compiler errors, or "Build OK." and the screenshot's path.
set -uo pipefail
cd "$(dirname "$0")/.."
BUILD="${TMPDIR:-/tmp}/pipsandbox-sim"
SIM=$(xcrun simctl list devices available | grep "iPad Pro 13-inch" | grep -oE '[0-9A-F-]{36}' | head -1)
[[ -n "$SIM" ]] || SIM=$(xcrun simctl list devices available | grep "iPad" | grep -oE '[0-9A-F-]{36}' | head -1)
[[ -n "$SIM" ]] || { echo "No iPad simulator found."; exit 1; }

LOG=$(mktemp)
# Packs the dashboard's data into the app (Dashboard plugin reads it); the folder joins the app by itself.
mkdir -p GlassClock/Packed && cp ../data/dashboard.json GlassClock/Packed/dashboard.json
if ! xcodebuild -project PipSandbox.xcodeproj -scheme GlassClock -configuration Debug -destination "id=$SIM" \
    -derivedDataPath "$BUILD" -quiet build >"$LOG" 2>&1; then
  grep -E "error:" "$LOG" | sed 's|.*/app/||' | sort -u
  echo "Build failed."
  exit 1
fi
echo "Build OK."
[[ "${1:-}" == --build ]] && exit 0

xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl install "$SIM" "$BUILD/Build/Products/Debug-iphonesimulator/GlassClock.app"
[[ "${1:-}" == --fresh ]] && xcrun simctl spawn "$SIM" defaults delete com.aarondennel.pipsandbox pipMet 2>/dev/null
# -hasSeenTour YES skips the app's Welcome card, which Pip waits behind.
xcrun simctl launch --terminate-running-process "$SIM" com.aarondennel.pipsandbox -hasSeenTour YES >/dev/null
sleep 8
mkdir -p tools/shots
xcrun simctl io "$SIM" screenshot tools/shots/check.png >/dev/null 2>&1
sips -Z 1000 tools/shots/check.png >/dev/null
echo "Screenshot: app/tools/shots/check.png"
