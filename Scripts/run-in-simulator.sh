#!/bin/zsh
# Builds Glass Clock and runs it in the iPad Simulator, set up to match the real iPad as closely
# as a Simulator can: the newest iPadOS installed (install iPadOS 27 in Xcode > Settings >
# Components) and the same iPad model. Layout and looks only: gestures, smoothness, haptics and
# widget updates are checked on the iPad (see PLAN.md).
#   Scripts/run-in-simulator.sh          build, install and launch
#   Scripts/run-in-simulator.sh --fresh  same, from a clean install (no saved settings)
#   Scripts/run-in-simulator.sh --meter  with the frame meter along the bottom
#   Scripts/run-in-simulator.sh --rebuild  the rebuilt app instead of the old one (all three combine)
set -euo pipefail
cd "$(dirname "$0")/.."

# The real iPad's model, as the Simulator names it (xcrun simctl list devicetypes).
SIM_MODEL="${SIM_MODEL:-iPad Pro (12.9-inch) (5th generation)}"  # the M1 12.9-inch
BUNDLE=com.aarondennel.glassclock
BUILD_DIR="${TMPDIR:-/tmp}/glassclock-sim-build"

# The newest iOS runtime installed.
RUNTIME=$(xcrun simctl list runtimes available -j \
  | jq -r '[.runtimes[] | select(.platform == "iOS")] | sort_by(.version | split(".") | map(tonumber)) | last | .identifier')
[[ -n "$RUNTIME" && "$RUNTIME" != null ]] || { echo "No iOS Simulator runtime installed."; exit 1; }
# The newest iPadOS comes first (it's what the iPad runs). Older ones are for checking later.
VERSION=$(xcrun simctl list runtimes available -j | jq -r --arg rt "$RUNTIME" '.runtimes[] | select(.identifier == $rt) | .version')
if (( ${VERSION%%.*} < 27 )); then
  echo "Warning: the newest Simulator here is iPadOS $VERSION, older than the iPad's iPadOS 27."
  echo "Install it with: xcodebuild -downloadPlatform iOS   (or Xcode > Settings > Components)."
fi

# One Simulator for this app on that runtime, made the first time.
NAME="Glass Clock - $SIM_MODEL"
UDID=$(xcrun simctl list devices available -j \
  | jq -r --arg rt "$RUNTIME" --arg name "$NAME" '.devices[$rt][]? | select(.name == $name) | .udid' | head -1)
if [[ -z "$UDID" ]]; then
  TYPE=$(xcrun simctl list devicetypes -j | jq -r --arg m "$SIM_MODEL" '.devicetypes[] | select(.name == $m) | .identifier')
  [[ -n "$TYPE" ]] || { echo "No Simulator model called \"$SIM_MODEL\". Pick one from: xcrun simctl list devicetypes"; exit 1; }
  UDID=$(xcrun simctl create "$NAME" "$TYPE" "$RUNTIME")
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$UDID"

xcodebuild -project GlassClock.xcodeproj -scheme GlassClock -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$BUILD_DIR" -quiet build

ARGS=()
for option in "$@"; do
  [[ "$option" == --fresh ]] && { xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true; }
  [[ "$option" == --meter ]] && ARGS+=(-frameMeter YES)
  [[ "$option" == --rebuild ]] && ARGS+=(-rebuild YES)
done
xcrun simctl install "$UDID" "$BUILD_DIR/Build/Products/Debug-iphonesimulator/GlassClock.app"
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "${ARGS[@]}" >/dev/null
echo "Running in the Simulator: $SIM_MODEL, $(echo $RUNTIME | sed 's/.*SimRuntime\.//')."
