#!/bin/zsh
# Measures smoothness on the real iPad with the app's own stress tests (StressTest in
# GlassClock/StyleGallery.swift), so changes can be compared by numbers rather than by eye.
#   Scripts/stress-on-ipad.sh build             optimised Debug build (stress hooks on), installed
#   Scripts/stress-on-ipad.sh run '<env json>'  runs one test, prints the STRESS line
# Examples:
#   run '{"GLASSCLOCK_STRESS_MOODS":"300","GLASSCLOCK_STRESS_DRAG":"1"}'   fast slider drag
#   run '{"GLASSCLOCK_STRESS_MOODS":"10","GLASSCLOCK_MOOD_PAIR":"0,2"}'    Bold glass <-> Neon
#   run '{"GLASSCLOCK_STRESS_HOME":"24"}'                                  Home Screen style taps
# Add "GLASSCLOCK_STRESS_IDLE":"1" for a baseline with nothing changing.
# Afterwards, Scripts/run-on-ipad.sh puts the normal build back.
cd "$(dirname "$0")/.."
DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPad/ && (/connected/ || /available/) {print $3; exit}')
BD="${TMPDIR:-/tmp}/glassclock-bench"
if [[ "$1" == build ]]; then
  xcodebuild -project GlassClock.xcodeproj -scheme GlassClock -configuration Debug \
    -destination "generic/platform=iOS" -derivedDataPath "$BD" \
    DEVELOPMENT_TEAM=2UUL2QMJGB CODE_SIGN_ENTITLEMENTS=Config/FreeTeam.entitlements \
    SWIFT_OPTIMIZATION_LEVEL=-O -allowProvisioningUpdates -quiet build 2>&1 | grep -E 'error' | head
  xcrun devicectl device install app --device $DEVICE "$BD/Build/Products/Debug-iphoneos/GlassClock.app" >/dev/null && echo installed
  exit
fi
OUT="${TMPDIR:-/tmp}/bench-out.txt"; : > "$OUT"
xcrun devicectl device process launch --device $DEVICE --terminate-existing --console \
  --environment-variables "$2" com.aarondennel.glassclock > "$OUT" 2>&1 &
PID=$!
for i in {1..40}; do grep -aq 'STRESS' "$OUT" && break; sleep 1; done
kill $PID 2>/dev/null
grep -a 'STRESS' "$OUT" || { echo "no result"; tail -5 "$OUT"; }
