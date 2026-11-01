#!/usr/bin/env python3
"""board-fix.py · Jules, 1 Nov 2026 · tidies the master chat's BOARD.JSON block for the live feed.

  pbpaste | python3 app/tools/board-fix.py [previous-board.json] > /tmp/board.json

- Finds the JSON inside the paste (labels and ``` fences are fine).
- Shapes it the way the app reads it: plain-text "needsYou" / "upNext" / "reminders" / "ideas" become objects,
  a missing "syncedAt" comes from "updatedAt" (UK time), builds get a date.
- Merges onto the previous board: parts the block leaves out keep their last values; new builds go on top.
  Previous board: the argument, else data/dashboard.json.
Nothing is sent anywhere. Prints the result; check it, then upload it as board.json.
"""
import json, os, re, sys
from datetime import datetime, timezone
try:
    from zoneinfo import ZoneInfo
    UK = ZoneInfo("Europe/London")
except Exception:
    UK = timezone.utc

def grab(text):
    a, b = text.find("{"), text.rfind("}")
    if a < 0 or b < a:
        sys.exit("✋ No JSON found in the paste.")
    return json.loads(text[a:b + 1])

def iso_from(words):
    """'Sun 1 Nov, 4:20 am' -> '2026-11-01T04:20:00Z' (this year, UK time)."""
    m = re.search(r"(\d{1,2})\s+([A-Za-z]{3})[a-z]*,?\s+(\d{1,2})(?::(\d{2}))?\s*([ap]m)", words or "", re.I)
    if not m:
        return None
    day, mon, hour, minute, ampm = m.groups()
    month = "jan feb mar apr may jun jul aug sep oct nov dec".split().index(mon.lower()) + 1
    hour = int(hour) % 12 + (12 if ampm.lower() == "pm" else 0)
    local = datetime(datetime.now().year, month, int(day), hour, int(minute or 0), tzinfo=UK)
    return local.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def objects(items, key):
    return [{key: x} if isinstance(x, str) else x for x in (items or [])]

new = grab(sys.stdin.read())
prev_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "data", "dashboard.json")
try:
    board = json.load(open(prev_path))
except Exception:
    board = {}

# Shape
words = new.pop("updatedAt", None) or (new.get("status") or {}).get("updatedAt")
synced = new.get("syncedAt") or iso_from(words) or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
new["syncedAt"] = synced
if "status" in new and words and not new["status"].get("updatedAt"):
    new["status"]["updatedAt"] = words
for part, key in (("needsYou", "q"), ("upNext", "title"), ("reminders", "title"), ("ideas", "title")):
    if part in new:
        new[part] = objects(new[part], key)
if "builds" in new:
    new["builds"] = [dict(b, at=b.get("at") or synced) for b in objects(new["builds"], "title")]

# Merge onto the last board
for part, value in new.items():
    if part == "status":
        board["status"] = {**(board.get("status") or {}), **value}
    elif part == "builds":
        titles = {b.get("title") for b in value}
        board["builds"] = (value + [b for b in board.get("builds", []) if b.get("title") not in titles])[:10]
    else:
        board[part] = value
board.pop("live", None)
json.dump(board, sys.stdout, indent=1, ensure_ascii=False)
sys.stdout.write("\n")
print("✅ board ready: %s · %d need you · %d up next · %d builds" % (
    board.get("syncedAt"), len(board.get("needsYou") or []), len(board.get("upNext") or []), len(board.get("builds") or [])),
    file=sys.stderr)
