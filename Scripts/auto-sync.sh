#!/bin/zsh
# Runs after each Claude reply (Stop hook in .claude/settings.local.json).
# If anything changed: commits it, pushes to GitHub and copies it to Google Drive. It no longer
# installs on the iPad: Scripts/install-build.sh does that, on purpose.
# Prints a one-line summary as hook JSON so it shows in the app.
cd "$(dirname "$0")/.."
LOG="${TMPDIR:-/tmp}/glassclock-auto-sync.log"

say() { jq -cn --arg m "$1" '{systemMessage: $m}'; exit 0; }

[[ -n "$(git status --porcelain)" ]] || exit 0
# Only on main and the rebuild: on another branch (such as a prototype being built) the work
# isn't finished, and committing, pushing or installing it would be premature.
[[ "$(git branch --show-current)" == (main|rebuild|from-415) ]] || exit 0
[[ -f .git/MERGE_HEAD ]] && say "Auto-sync skipped: a merge is in progress."

CHANGED=$(git status --porcelain | awk '{print $NF}')
git add -A
git commit -q -m "Auto-save: $(echo "$CHANGED" | head -5 | xargs basename -a | paste -sd ', ' -)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" >"$LOG" 2>&1 \
  || say "Auto-sync: commit failed (see $LOG)."

if git push -q >>"$LOG" 2>&1; then MSG="Saved to GitHub."
else MSG="Saved locally, but the GitHub push failed (see $LOG)."; fi

# Mirror into Google Drive for desktop's folder (skipped if it isn't installed).
DRIVE=$(print -l ~/Library/CloudStorage/GoogleDrive-*/"My Drive"(N/) | head -1)
if [[ -n "$DRIVE" ]]; then
  if rsync -a --delete --exclude .git --exclude xcuserdata --exclude .DS_Store \
      ./ "$DRIVE/GlassClock/" >>"$LOG" 2>&1; then MSG="$MSG Copied to Google Drive."
  else MSG="$MSG Google Drive copy failed (see $LOG)."; fi
fi

# No install here any more (25 Oct 2026): installing after every reply put untried builds on
# the iPad with no record of which one it was, and an evening of them turned glitchy. Install
# on purpose with Scripts/install-build.sh, which also records what's on the iPad.
if echo "$CHANGED" | grep -qvE '\.md$|^References/|^\.claude/'; then
  MSG="$MSG Not installed: say 'put it on the iPad' when you want to try it."
fi
say "$MSG"
