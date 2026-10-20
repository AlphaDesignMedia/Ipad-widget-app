#!/bin/zsh
# Runs after each Claude reply (Stop hook in .claude/settings.local.json).
# If anything changed: commits it, pushes to GitHub, copies it to Google Drive, and reinstalls on the iPad
# when app code changed (doc-only changes skip the iPad build).
# Prints a one-line summary as hook JSON so it shows in the app.
cd "$(dirname "$0")/.."
LOG="${TMPDIR:-/tmp}/glassclock-auto-sync.log"

say() { jq -cn --arg m "$1" '{systemMessage: $m}'; exit 0; }

[[ -n "$(git status --porcelain)" ]] || exit 0
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

if echo "$CHANGED" | grep -qvE '\.md$|^References/|^\.claude/'; then
  if Scripts/run-on-ipad.sh >>"$LOG" 2>&1; then MSG="$MSG Installed on iPad."
  elif grep -q "No connected iPad" "$LOG"; then MSG="$MSG iPad not connected, so not installed."
  else MSG="$MSG iPad install failed (see $LOG)."; fi
fi
say "$MSG"
