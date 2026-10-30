#!/bin/zsh
# Takes the plugin agent's work: merges GitHub's pip-plugins into pip-playground, builds it for the simulator,
# pushes pip-playground and installs it on the iPad. Stops at the first problem, leaving pip-playground as it was.
#   ./tools/take-plugins.sh            all of it
#   ./tools/take-plugins.sh --no-ipad  merge, build and push; no install
set -uo pipefail
cd "$(dirname "$0")/../.."
[[ "$(git branch --show-current)" == pip-playground ]] || { echo "Switch to pip-playground first."; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Commit local changes first."; exit 1; }
git fetch -q origin pip-plugins || { echo "Couldn't reach GitHub."; exit 1; }

new=$(git log --oneline HEAD..origin/pip-plugins)
[[ -n "$new" ]] || { echo "Nothing new on pip-plugins."; exit 0; }
echo "New from the plugin agent:"; echo "$new"
outside=$(git diff --name-only HEAD...origin/pip-plugins | grep -v -E '^(app/GlassClock/Plugins/|AGENT-NOTES\.md$)')
[[ -n "$outside" ]] && { echo "Heads-up: it also changed files outside Plugins/:"; echo "$outside"; }

git merge -q --no-edit origin/pip-plugins || { git merge --abort; echo "Merge conflict. Nothing changed."; exit 1; }
if ! (cd app && ./tools/check.sh --build); then
  git reset -q --hard ORIG_HEAD
  echo "Build failed, so the merge was undone. Write the errors in AGENT-NOTES.md for the plugin agent."
  exit 1
fi
git push -q origin pip-playground || echo "Push failed; the merge is only on this Mac."
[[ "${1:-}" == --no-ipad ]] && exit 0
(cd app && ./run-on-ipad.sh) || { echo "Not installed: is the iPad unlocked and on the same Wi-Fi (or plugged in)?"; exit 1; }
