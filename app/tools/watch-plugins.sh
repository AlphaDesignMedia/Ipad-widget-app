#!/bin/zsh
# Waits for the plugin agent: checks GitHub's pip-plugins branch every 2 minutes and exits once it has moved.
# The app agent runs this in the background during a session, then runs ./tools/take-plugins.sh.
#   ./tools/watch-plugins.sh [seconds between checks]
set -uo pipefail
cd "$(dirname "$0")/../.."
known=$(git rev-parse -q --verify refs/remotes/origin/pip-plugins || echo none)
while true; do
  now=$(git ls-remote origin refs/heads/pip-plugins 2>/dev/null | cut -f1)
  if [[ -n "$now" && "$now" != "$known" ]]; then
    echo "pip-plugins moved: ${known:0:7} -> ${now:0:7}. Next: app/tools/take-plugins.sh"
    exit 0
  fi
  sleep "${1:-120}"
done
