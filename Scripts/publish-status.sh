#!/bin/zsh
# Publishes the progress dashboard's numbers as status.json to a secret GitHub Gist,
# which the Glass Dashboard widget reads (the widget can't sign in to Claude).
# The owner agreed to the gist holding the counts, the iPad build's name and time, and the
# latest update's title (23 Oct 2026).
#
#   Scripts/publish-status.sh <folder>
#
# <folder> holds the dashboard's collections saved by Claude's ArtifactData tool
# (list with out_dir) from https://claude.ai/artifact/UQ9Yo6F6RBNdoUn8B9sqeW:
#   <folder>/decisions/*.json  <folder>/items/*.json  <folder>/builds/*.json  <folder>/chat/*.json
# Run it whenever the dashboard changes (Studio/working-rhythm.md). Needs gh signed in, and
# the Bash sandbox off so gh can reach the keychain.
set -euo pipefail

GIST_ID=1f2abb87c59f63844a9f7523f37da9f4
DIR=${1:?"Give the folder with the saved dashboard collections"}
GH=${GH:-$HOME/.local/bin/gh}
OUT="${TMPDIR:-/tmp}/glass-dashboard-status/status.json"
mkdir -p "$(dirname "$OUT")"

/usr/bin/python3 -I - "$DIR" "$OUT" <<'PY'
import glob, json, os, sys
from datetime import datetime, timezone

folder, out = sys.argv[1], sys.argv[2]
def docs(name):
    return [json.load(open(f)) for f in sorted(glob.glob(os.path.join(folder, name, "*.json")))]
def when(text):
    # Dates come as "…Z" or "…+01:00"; anything unreadable sorts first.
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except (AttributeError, ValueError):
        return datetime.min.replace(tzinfo=timezone.utc)

items = docs("items")
lane = lambda name: sum(1 for i in items if i.get("lane") == name)
builds = sorted(docs("builds"), key=lambda b: when(b.get("at")))
cards = sorted((c for c in docs("chat") if c.get("from") == "claude"), key=lambda c: when(c.get("at")))
latest = builds[-1] if builds else {}
card = cards[-1] if cards else {}

status = {
    "needYou": sum(1 for d in docs("decisions") if not d.get("answer")),
    "toTry": lane("ipad"),
    "upNext": lane("next"),
    "done": lane("done"),
    "ipadBuild": latest.get("title", ""),
    "ipadBuildAt": latest.get("at", ""),
    "latestUpdate": card.get("title") or card.get("text", "")[:80],
    "updatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
json.dump(status, open(out, "w"), indent=2)
print(json.dumps(status, indent=2))
PY

if [[ "$GIST_ID" == fill-in-after-first-run ]]; then
  # First run: makes the secret gist; put the id it prints into GIST_ID above.
  "$GH" gist create "$OUT" --desc "Glass Dashboard status"
else
  "$GH" gist edit "$GIST_ID" "$OUT" --filename status.json
fi
