#!/bin/zsh
# Puts the plugin agent's work on Aaron's iPad with nobody at the Mac. launchd runs it every 2 minutes
# (set up by tools/auto-update-setup.sh). One pass:
#   1. If GitHub's pip-plugins has something new: merge it into pip-playground, build for the simulator,
#      write the result in AUTO-UPDATE.md, push pip-playground. A conflict or a failed build changes
#      nothing in the app; the reason goes in AUTO-UPDATE.md for the plugin agent, and a Mac notification.
#   2. If the iPad doesn't have the latest pip-playground yet: install it (retries every 15 minutes while
#      the iPad is away or locked).
# It never touches main or Glass Clock, and it stands aside while someone is working in the folder
# (uncommitted changes, or not on pip-playground).
#   ./tools/auto-update.sh          one pass (what launchd runs)
#   ./tools/auto-update.sh --dry    say what it would do, change nothing
set -uo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin"
cd "$(dirname "$0")/../.." || exit 1
STATE="$HOME/Library/Application Support/PipSandboxAutoUpdate"
mkdir -p "$STATE"
DRY=${1:-}

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*"; }
tell() { osascript -e "display notification \"$1\" with title \"Pip Sandbox\"" >/dev/null 2>&1; }
remember() { print -r -- "$2" > "$STATE/$1"; }
recall() { cat "$STATE/$1" 2>/dev/null; }

# Someone is working here: stay out of the way.
[[ "$(git branch --show-current)" == pip-playground ]] || { log "Not on pip-playground; skipped."; exit 0; }
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { log "Uncommitted changes; skipped."; exit 0; }

git fetch -q origin pip-plugins pip-playground || { log "Couldn't reach GitHub."; exit 0; }
# In the job's own clone, GitHub is the truth (a merge that failed to push is simply redone).
if [[ "$(git config --get pipsandbox.autoclone)" == true ]]; then
  git reset -q --hard origin/pip-playground
else
  git merge -q --ff-only origin/pip-playground 2>/dev/null
fi

plugins=$(git rev-parse origin/pip-plugins)
new=$(git log --oneline HEAD..origin/pip-plugins)
if [[ -n "$new" && "$plugins" != "$(recall failed)" ]]; then
  log "New from the plugin agent:"; print -r -- "$new"
  [[ "$DRY" == --dry ]] && { log "(dry run) would merge, build, push and install."; exit 0; }
  outside=""
  when=$(date '+%d %b %Y, %H:%M')
  report() {  # status line, details
    { print "# Auto-update"
      print ""
      print "Written by \`app/tools/auto-update.sh\` on Aaron's Mac after each push to \`pip-plugins\`."
      print ""
      print "**$when · $1**"
      print ""
      print "Commits:"; print -r -- "$new" | sed 's/^/- /'
      [[ -n "$outside" ]] && { print ""; print "Changed outside \`Plugins/\` (the core is the Mac agent's: ask in AGENT-NOTES.md):"; print -r -- "$outside" | sed 's/^/- /'; }
      [[ -n "${2:-}" ]] && { print ""; print '```'; print -r -- "$2"; print '```'; }
    } > AUTO-UPDATE.md
  }
  fail() {  # status line, details: write it down, push it, tell Aaron, don't retry this push
    report "$1" "$2"
    git add AUTO-UPDATE.md && git commit -q -m "Auto-update: $1" && git push -q origin pip-playground
    remember failed "$plugins"
    tell "$1. Details in AUTO-UPDATE.md."
    log "$1"; print -r -- "$2"
  }

  if ! git merge -q --no-commit --no-ff origin/pip-plugins 2>/dev/null; then
    conflicts=$(git diff --name-only --diff-filter=U)
    git merge --abort
    fail "Merge conflict, so nothing changed" "Files that clash with pip-playground:
$conflicts
Fix: merge origin/pip-playground into pip-plugins, resolve, push again."
    exit 0
  fi
  # Only what the merge actually brings in (not the core's own changes since the agents branched).
  outside=$(git diff --name-only --cached HEAD | grep -v -E '^(app/GlassClock/Plugins/|AGENT-NOTES\.md$|IDEA-INBOX\.md$|AUTO-UPDATE\.md$|CHANGES\.md$)')
  report "Merged and building"
  git add AUTO-UPDATE.md
  if ! out=$(cd app && ./tools/check.sh --build 2>&1); then
    git merge --abort 2>/dev/null || git reset -q --hard HEAD
    # Another build on this Mac held the build folder: not the agents' fault, so just try again next pass.
    if print -r -- "$out" | grep -q -E 'database is locked|concurrent builds'; then
      log "Another build was running on this Mac; trying again in 2 minutes."
      exit 0
    fi
    fail "Build failed, so nothing changed" "$(print -r -- "$out" | tail -40)"
    exit 0
  fi
  report "Built, merged and on its way to the iPad"
  git add AUTO-UPDATE.md
  git commit -q --no-edit -m "Auto-update: merge pip-plugins ($(print -r -- "$new" | wc -l | tr -d ' ') commits)"
  git push -q origin pip-playground || log "Push failed; the merge is only on this Mac for now."
  rm -f "$STATE/failed"
  log "Merged and built."
fi

# The iPad: install the latest pip-playground once, retrying every 15 minutes while it's away.
head=$(git rev-parse HEAD)
[[ "$head" == "$(recall installed)" ]] && exit 0
if [[ "$head" == "$(recall tried)" ]] && (( $(date +%s) - $(recall triedAt || print 0) < 900 )); then exit 0; fi
[[ "$DRY" == --dry ]] && { log "(dry run) would install $head on the iPad."; exit 0; }
remember tried "$head"; remember triedAt "$(date +%s)"
log "Installing on the iPad..."
if out=$(cd app && ./run-on-ipad.sh 2>&1) && print -r -- "$out" | grep -q "running on the iPad"; then
  remember installed "$head"
  tell "The latest plugins are on your iPad."
  log "Installed."
else
  log "Not installed (is the iPad awake and on the same Wi-Fi?). Trying again in 15 minutes."
  print -r -- "$out" | tail -5
fi
