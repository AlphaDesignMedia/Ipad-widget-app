#!/bin/zsh
# Builds Glass Clock, installs it on the plugged-in iPad and relaunches it.
#   --meter    shows the frame meter (frames per second and hitches) along the bottom
#   --rebuild  opens the rebuilt app instead of the old one (PLAN.md, "The rebuild"), as a Debug build
#   --playground  the old app with every experiment back on (it opens as the Foundation build)
#   --debug    a Debug build instead of Release (needed for --meter, which is Debug only)
# Uses the free Personal Team, which can't use App Groups, so the build swaps the
# App Group entitlements for Config/FreeTeam.entitlements, which shares settings through the keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=2UUL2QMJGB
BUILD_DIR="${TMPDIR:-/tmp}/glassclock-build"
# Release by default: the Debug build ran SwiftUI several times slower, which showed up as
# pauses and jitter on the iPad that a shipped app wouldn't have (22 Oct 2026). The frame meter
# and the rebuilt app are behind #if DEBUG (GlassClockApp.swift), so --meter and --rebuild build
# Debug: in Release, --rebuild quietly opened the old app.
CONFIG=Release
for option in "$@"; do
  [[ "$option" == --debug || "$option" == --meter || "$option" == --rebuild ]] && CONFIG=Debug
done
# Xcode 27.1 lists a reachable iPad as "available (paired)" rather than "connected".
DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPad/ && (/connected/ || /available/) {print $3; exit}')
[[ -n "$DEVICE" ]] || { echo "No connected iPad found."; exit 1; }
# Built for any iPad rather than this one: Xcode's own connection to the iPad drops when it
# locks or sleeps, even while devicectl (which does the install) can still reach it.
xcodebuild -project GlassClock.xcodeproj -scheme GlassClock -configuration $CONFIG \
  -destination "generic/platform=iOS" -derivedDataPath "$BUILD_DIR" \
  DEVELOPMENT_TEAM=$TEAM CODE_SIGN_ENTITLEMENTS=Config/FreeTeam.entitlements -allowProvisioningUpdates -quiet build

# "Could not allocate a resource" here, with the iPad unlocked and plugged in, meant the Mac's
# CoreDeviceService was stuck after a dropped Wi-Fi connection; `pkill -x CoreDeviceService`
# (it relaunches itself) fixed it (2026-10-20).
xcrun devicectl device install app --device "$DEVICE" \
  "$BUILD_DIR/Build/Products/$CONFIG-iphoneos/GlassClock.app" >/dev/null
ARGS=()
for option in "$@"; do
  [[ "$option" == --meter ]] && ARGS+=(-frameMeter YES)
  [[ "$option" == --rebuild ]] && ARGS+=(-rebuild YES)
  [[ "$option" == --playground ]] && ARGS+=(-playground YES)
done
# "--" so options like -rebuild reach the app: without it, devicectl (Xcode 27.1) read them as
# its own and stopped with "Unknown option '-r'".
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing \
  com.aarondennel.glassclock -- "${ARGS[@]}" >/dev/null
echo "Running on iPad."
