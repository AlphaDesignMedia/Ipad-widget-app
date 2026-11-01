#!/bin/bash
# sync-dashboard.sh · Jules, 1 Nov 2026 · refreshes the Sandbox app's dashboard file.
#
#   data/dashboard.json  ──copy──▶  app/GlassClock/Plugins/dashboard.json  (packed into the app at build)
#   --live: also fetches the live board's headline (the small file that feeds the iPad widget) and adds it as "live".
#
# Read-only on the live side: it only downloads. The app itself never goes online.
# Use:   app/tools/sync-dashboard.sh          (copy only)
#        app/tools/sync-dashboard.sh --live   (copy + live headline; needs the internet)
# Then build as normal (take-plugins.sh or check.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."
SRC=data/dashboard.json
OUT=app/GlassClock/Plugins/dashboard.json
LIVE_URL="https://gist.githubusercontent.com/AlphaDesignMedia/1f2abb87c59f63844a9f7523f37da9f4/raw/status.json"

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SRC" || { echo "✋ $SRC isn't valid JSON. Nothing changed."; exit 1; }

LIVE_FILE=""
if [ "${1:-}" = "--live" ]; then
  LIVE_FILE=$(mktemp)
  if curl -fsS -m 10 "$LIVE_URL?t=$(date +%s)" -o "$LIVE_FILE"; then echo "📡 live headline fetched"
  else echo "⚠️ couldn't reach the live headline; copying without it"; LIVE_FILE=""; fi
fi

python3 - "$SRC" "$OUT" "$LIVE_FILE" <<'PY'
import json, sys
src, out, live = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(src))
if live:
    try:
        L = json.load(open(live))
        keep = ("needYou", "toTry", "upNext", "done", "latestUpdate", "ipadBuild", "updatedAt")
        d["live"] = {k: L[k] for k in keep if k in L}
    except Exception as e:
        print("⚠️ live headline wasn't readable (%s); left out" % e)
json.dump(d, open(out, "w"), indent=1, ensure_ascii=False)
open(out, "a").write("\n")
print("✅ %s ← %s%s" % (out, src, " + live" if "live" in d else ""))
PY
[ -n "$LIVE_FILE" ] && rm -f "$LIVE_FILE"
exit 0
