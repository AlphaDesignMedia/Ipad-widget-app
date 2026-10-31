#!/bin/zsh
# Tess the Tester: one full run over every plugin-bar button in the iPad simulator, then a table in TESTS.md.
# Run it after take-plugins.sh, never on a loop. Polite: background priority, 4 cores, one simulator, shut down at the end.
#   ./tools/tess.sh            build, run, write TESTS.md
#   ./tools/tess.sh --no-build use the last build
# In the app (MenuStress.swift, debug only) Tess opens each plugin, scrolls it to the bottom, flips each switch once and back,
# and closes it, then does Pause all and resume. Red = a crash, a hang over 1 s, or more than 10 late frames.
set -uo pipefail
cd "$(dirname "$0")/.."
BUILD="${TESS_BUILD:-${TMPDIR:-/tmp}/pipsandbox-tess}"   # TESS_BUILD=<folder> reuses a warm build folder
APP_ID=com.aarondennel.pipsandbox
SIM=$(xcrun simctl list devices available | grep "iPad Pro 13-inch" | grep -oE '[0-9A-F-]{36}' | head -1)
[[ -n "$SIM" ]] || { echo "No iPad simulator found."; exit 1; }

if [[ "${1:-}" != --no-build ]]; then
  mkdir -p GlassClock/Packed && cp ../data/dashboard.json GlassClock/Packed/dashboard.json
  LOG=$(mktemp)
  if ! taskpolicy -b xcodebuild -project PipSandbox.xcodeproj -scheme GlassClock -configuration Debug -destination "id=$SIM" \
      -derivedDataPath "$BUILD" -jobs 4 -quiet build >"$LOG" 2>&1; then
    grep -E "error:" "$LOG" | sed 's|.*/app/||' | sort -u
    echo "Build failed, so Tess didn't run."
    exit 1
  fi
fi

xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl install "$SIM" "$BUILD/Build/Products/Debug-iphonesimulator/GlassClock.app"
DIAG="$(xcrun simctl get_app_container "$SIM" $APP_ID data)/Documents/Diagnostics"
rm -f "$DIAG/tess-result.txt" "$DIAG/tess-now.txt"
PID=$(xcrun simctl launch --terminate-running-process "$SIM" $APP_ID -hasSeenTour YES -plugsOpen NO -frameMeter YES -tess YES | awk '{print $2}')

# Wait for "DONE", or for the app to die (a crash: tess-now.txt says which plugin it was on). About 5 s a plugin.
crashed=""
for i in {1..200}; do
  sleep 3
  grep -q '^DONE' "$DIAG/tess-result.txt" 2>/dev/null && break
  if ! ps -p "$PID" >/dev/null 2>&1; then crashed=$(cat "$DIAG/tess-now.txt" 2>/dev/null || echo "launch"); break; fi
done
[[ -z "$crashed" ]] && ! grep -q '^DONE' "$DIAG/tess-result.txt" 2>/dev/null && crashed="timed out on $(cat "$DIAG/tess-now.txt" 2>/dev/null)"

# The table, newest run at the top of TESTS.md.
commit=$(git rev-parse --short HEAD)
table=$(mktemp)
{
  echo "## $(date '+%d %b %Y, %H:%M') · Tess · \`$commit\` · iPad Pro 13\" simulator"
  echo
  echo "Red: a crash, a hang over 1 s, or more than 10 late frames while it was open. Simulator numbers: compare runs, not the iPad."
  echo
  echo "| | Plugin | id | Crash | Hang > 1 s | Late frames | Worst ms | Switches flipped |"
  echo "|---|---|---|---|---|---|---|---|"
  reds=0
  while IFS=$'\t' read -r id name late worst switches; do
    [[ "$id" == DONE || -z "$id" ]] && continue
    hang=no; (( worst > 1000 )) && hang=yes
    flag="🟢"; if [[ $hang == yes ]] || (( late > 10 )); then flag="🔴"; reds=$((reds + 1)); fi
    echo "| $flag | $name | \`$id\` | no | $hang | $late | $worst | $switches |"
  done < <(cat "$DIAG/tess-result.txt" 2>/dev/null)
  if [[ -n "$crashed" ]]; then echo "| 🔴 | **stopped here** | \`$crashed\` | **yes** | | | | |"; reds=$((reds + 1)); fi
  echo
  echo "**$reds red.** Tickets for each red one go in \`TICKETS.md\` (plugins for Jules, core for Robyn)."
  echo
} > "$table"
if [[ -f ../TESTS.md ]]; then
  { sed -n '1,/^---$/p' ../TESTS.md; echo; cat "$table"; sed -n '/^---$/,$p' ../TESTS.md | tail -n +2; } > ../TESTS.md.new && mv ../TESTS.md.new ../TESTS.md
else
  { echo "# Tests"; echo; echo "Tess's runs, newest at the top. \`app/tools/tess.sh\` writes them; Rob keeps this file."; echo; echo "---"; echo; cat "$table"; } > ../TESTS.md
fi
cat "$table"
xcrun simctl shutdown "$SIM" 2>/dev/null
