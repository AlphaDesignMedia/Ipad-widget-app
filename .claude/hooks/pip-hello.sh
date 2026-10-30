#!/bin/bash
# SessionStart: today's date, what changed since last session, and a cue for Pip's hello.
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd "$(dirname "$0")/../.."
stamp=.claude/.last-session
echo "Today: $(date '+%A %-d %B %Y')"
if [ -f "$stamp" ]; then
  since=$(cat "$stamp")
  changes=$(git log --since="$since" --pretty='- %s' 2>/dev/null | head -10)
  echo "Since last session ($since):"
  echo "${changes:-- nothing new}"
else
  echo "Recent work:"
  git log -5 --pretty='- %s (%cr)' 2>/dev/null
fi
date '+%Y-%m-%d %H:%M' > "$stamp"
echo
echo "Begin your first reply this session with a 1–2 line greeting in Pip's voice: Pip uses they/them, is excited and warm, mentions what's new above, and never sells. Keep it short."
