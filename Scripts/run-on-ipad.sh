#!/bin/zsh
# Builds Glass Clock, installs it on the plugged-in iPad and relaunches it.
#   --meter    shows the frame meter (frames per second and hitches) along the bottom
#   --rebuild  opens the rebuilt app instead of the old one (PLAN.md, "The rebuild")
# Uses the free Personal Team, which can't use App Groups, so the build swaps the
# App Group entitlements for Config/FreeTeam.entitlements, which shares settings through the keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=2UUL2QMJGB
BUILD_DIR="${TMPDIR:-/tmp}/glassclock-build"
DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPad/ && /connected/ {print $3; exit}')
[[ -n "$DEVICE" ]] || { echo "No connected iPad found."; exit 1; }
# Built for any iPad rather than this one: Xcode's own connection to the iPad drops when it
# locks or sleeps, even while devicectl (which does the install) can still reach it.
xcodebuild -project GlassClock.xcodeproj -scheme GlassClock -configuration Debug \
  -destination "generic/platform=iOS" -derivedDataPath "$BUILD_DIR" \
  DEVELOPMENT_TEAM=$TEAM CODE_SIGN_ENTITLEMENTS=Config/FreeTeam.entitlements -allowProvisioningUpdates -quiet build

# "Could not allocate a resource" here, with the iPad unlocked and plugged in, meant the Mac's
# CoreDeviceService was stuck after a dropped Wi-Fi connection; `pkill -x CoreDeviceService`
# (it relaunches itself) fixed it (2026-10-20).
xcrun devicectl device install app --device "$DEVICE" \
  "$BUILD_DIR/Build/Products/Debug-iphoneos/GlassClock.app" >/dev/null
ARGS=()
for option in "$@"; do
  [[ "$option" == --meter ]] && ARGS+=(-frameMeter YES)
  [[ "$option" == --rebuild ]] && ARGS+=(-rebuild YES)
done
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing \
  com.aarondennel.glassclock "${ARGS[@]}" >/dev/null
echo "Running on iPad."
