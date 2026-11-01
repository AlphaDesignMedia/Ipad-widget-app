#!/bin/zsh
# board-push · Rob, 1 Nov 2026 · the master chat's BOARD.JSON → the private board gist, in one step.
#   board-push            takes BOARD.JSON from the clipboard, tidies it (board-fix.py), checks it, uploads it
#   board-push -          the same, from standard input (for tests)
#   board-push --outbox   prints the "outboxForRob" items that aren't done (session start)
# The gist's address lives only on this Mac (app/GlassClock/Private/board-feed.txt). This script never prints it.
# Anything wrong (bad paste, no network, upload fails) → nothing changes, the last good copy stays, one line says why.
emulate -L zsh
setopt pipe_fail
here=${0:A:h}
feed=$here/../GlassClock/Private/board-feed.txt
fix=$here/board-fix.py
keep=$HOME/.pip-board                     # last good copy, on this Mac only
mkdir -p $keep && chmod 700 $keep
work=$(mktemp -d) && trap 'rm -rf $work' EXIT

say() { print -r -- "$1"; }
stop() { say "✋ $1 Nothing changed; the last good board stays online."; exit 1; }

[[ -r $feed ]] || stop "No private address on this Mac (Private/board-feed.txt is missing)."
base=$(tr -d '[:space:]' < $feed)
[[ $base == https://gist.githubusercontent.com/*/raw/ ]] || stop "Private/board-feed.txt doesn't look like a gist address."
gist=${${base#https://gist.githubusercontent.com/}#*/}; gist=${gist%%/*}

# The board online now (also the base the new block merges onto). GitHub's API first (no cache lag), the raw address
# (what the app reads, can lag a minute or two) as a fallback.
valid() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' $1 2>/dev/null; }
fetch() {
    { gh api "gists/$gist" --jq '.files["board.json"].content' > $1 2>/dev/null && valid $1 } ||
    { curl -fsS --max-time 10 "${base}board.json?t=$(date +%s)" -o $1 2>/dev/null && valid $1 }
}

if [[ $1 == --outbox ]]; then
    if fetch $work/now.json; then cp $work/now.json $keep/last-good.json; src="online"
    elif [[ -r $keep/last-good.json ]]; then src="offline: last good copy from $(stat -f '%Sm' -t '%a %e %b, %H:%M' $keep/last-good.json)"; cp $keep/last-good.json $work/now.json
    else say "✋ Couldn't reach the board and there's no copy on this Mac yet."; exit 1; fi
    python3 - $work/now.json "$src" <<'PY'
import json, sys
b = json.load(open(sys.argv[1]))
todo = [o for o in (b.get("outboxForRob") or []) if isinstance(o, dict) and not o.get("done")]
print(f"📬 Outbox for Rob ({sys.argv[2]}, board {b.get('syncedAt', '?')}): {len(todo) or 'nothing'} to do")
for o in todo:
    print(f"  • {o.get('date', '?')}: {o.get('command', '').strip()}")
PY
    exit 0
fi

# 1. The paste.
if [[ $1 == - ]]; then cat > $work/paste.txt; else pbpaste > $work/paste.txt; fi
[[ -s $work/paste.txt ]] || stop "The clipboard is empty."
python3 - $work/paste.txt <<'PY' || exit 1
import json, sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
a, b = t.find("{"), t.rfind("}")
if a < 0 or b < a:
    sys.exit("✋ No JSON in the clipboard (no { … }). Nothing changed; the last good board stays online.")
try:
    d = json.loads(t[a:b + 1])
except json.JSONDecodeError as e:
    sys.exit(f"✋ Not valid JSON: {e.msg}, line {e.lineno} column {e.colno}. Nothing changed; the last good board stays online.")
if not isinstance(d, dict):
    sys.exit("✋ BOARD.JSON should be one { … } object. Nothing changed; the last good board stays online.")
o = d.get("outboxForRob")
if o is not None and not (isinstance(o, list) and all(isinstance(x, dict) and isinstance(x.get("command"), str) for x in o)):
    sys.exit("✋ outboxForRob should be a list of { date, done, command }. Nothing changed; the last good board stays online.")
PY

# 2. The board it merges onto: online now, else stop (merging onto an old copy could undo newer parts).
fetch $work/old.json || stop "Couldn't download the current board (no network?)."
cp $work/old.json $keep/last-good.json

# 3. Tidy and merge, then check the result.
python3 $fix $work/old.json < $work/paste.txt > $work/board.json 2> $work/fix.txt || stop "board-fix.py failed: $(tail -1 $work/fix.txt)"
python3 - $work/board.json <<'PY' || exit 1
import json, sys
b = json.load(open(sys.argv[1]))
missing = [k for k in ("syncedAt", "status") if not b.get(k)]
if missing:
    sys.exit("✋ The tidied board has no " + " or ".join(missing) + ". Nothing changed; the last good board stays online.")
PY

# 4. Upload, then read it back.
gh gist edit $gist -f board.json $work/board.json >/dev/null 2> $work/gh.txt || stop "Upload failed: $(head -1 $work/gh.txt | cut -c1-120)"
same() { python3 -c 'import json,sys; sys.exit(json.load(open(sys.argv[1])) != json.load(open(sys.argv[2])))' $1 $2 2>/dev/null; }
gh api "gists/$gist" --jq '.files["board.json"].content' > $work/back.json 2>/dev/null && same $work/back.json $work/board.json \
    || stop "Uploaded, but reading it back didn't match. Check with: board-push --outbox."
cp $work/board.json $keep/last-good.json
python3 - $work/board.json <<'PY'
import json, sys
b = json.load(open(sys.argv[1]))
todo = [o for o in (b.get("outboxForRob") or []) if not o.get("done")]
print("✅ board pushed: %s · %d need you · %d up next · %d builds · %d for Rob to do" % (
    b.get("syncedAt"), len(b.get("needsYou") or []), len(b.get("upNext") or []), len(b.get("builds") or []), len(todo)))
PY
say "   Checked: GitHub has exactly this board. The iPad sees it within a couple of minutes (next check while the dashboard is open)."
