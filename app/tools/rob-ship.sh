#!/bin/zsh
# Rob's one-liner: pull, build in Rob's own folder, push only if green.
#   ./tools/rob-ship.sh          pull --rebase, build, push
#   ./tools/rob-ship.sh --build  build only (no pull, no push)
# Run from ~/PipSandboxRob on pip-plugins. Push and fetch need the Bash sandbox off.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
[[ "$(git branch --show-current)" == pip-plugins ]] || { echo "Not on pip-plugins: stopped."; exit 1; }

if [[ "${1:-}" != --build ]]; then
  [[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "Commit first: uncommitted changes."; exit 1; }
  git pull -q --rebase origin pip-plugins || { echo "Pull clashed: sort it, then run again."; exit 1; }
fi

LOG=$(mktemp)
if ! (cd app && taskpolicy -b xcodebuild -project PipSandbox.xcodeproj -scheme GlassClock -configuration Debug \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "${TMPDIR:-/tmp}/pipsandbox-rob" \
    -jobs 4 -quiet build) >"$LOG" 2>&1; then
  grep -E "error:" "$LOG" | sed 's|.*/app/||' | sort -u
  echo "Red build: nothing pushed."
  exit 1
fi
echo "Green. $(grep -c 'warning:' "$LOG") warnings."
[[ "${1:-}" == --build ]] && exit 0

git push -q origin pip-plugins && echo "Pushed: the auto-updater takes it from here."
