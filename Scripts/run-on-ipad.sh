#!/bin/zsh
# Builds Glass Clock, installs it on the plugged-in iPad and relaunches it.
# Uses the free Personal Team, which can't use App Groups, so the build swaps the
# App Group entitlements for Config/FreeTeam.entitlements, which shares settings through the keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=2UUL2QMJGB
BUILD_DIR="${TMPDIR:-/tmp}/glassclock-build"
DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPad/ && /connected/ {print $3; exit}')
[[ -n "$DEVICE" ]] || { echo "No connected iPad found."; exit 1; }
UDID=$(xcodebuild -project GlassClock.xcodeproj -scheme GlassClock -showdestinations 2>/dev/null \
  | sed -n 's/.*platform:iOS, arch:arm64, id:\([^,]*\), name:.*/\1/p' | head -1)

xcodebuild -project GlassClock.xcodeproj -scheme GlassClock -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$BUILD_DIR" \
  DEVELOPMENT_TEAM=$TEAM CODE_SIGN_ENTITLEMENTS=Config/FreeTeam.entitlements -allowProvisioningUpdates -quiet build

xcrun devicectl device install app --device "$DEVICE" \
  "$BUILD_DIR/Build/Products/Debug-iphoneos/GlassClock.app" >/dev/null
xcrun devicectl device process launch --device "$DEVICE" --terminate-existing \
  com.aarondennel.glassclock >/dev/null
echo "Running on iPad."
