#!/bin/zsh
# Headless smoke test of the Pip Sandbox. Usage: tools/smoke.sh [path/to/src]  (default: ../src)
# Builds src/test.html = index.html + rAF shim (after <head>) + smoke body (before </body>), serves it, prints the result.
# db, room and downloads only exist inside claude.ai, so plugins that use them fall back or wait.
cd "$(dirname "$0")"; SRC=${1:-../src}; PORT=8791
python3 -I -c '
import sys; s,b,i=[open(p).read() for p in sys.argv[1:4]]
open(sys.argv[4],"w").write(i.replace("<head>","<head>"+s,1).replace("</body>",b+"</body>",1))' shim.html smoke-body.html "$SRC/index.html" "$SRC/test.html"
lsof -ti:$PORT | xargs kill 2>/dev/null
python3 -m http.server $PORT --directory "$SRC" >/dev/null 2>&1 & SV=$!; sleep 1
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --virtual-time-budget=25000 \
  --dump-dom "http://localhost:$PORT/test.html" 2>/dev/null | python3 -I -c '
import sys,re,html; m=re.search(r"<pre id=\"OUT\">(.*?)</pre>",sys.stdin.read(),re.S); print(html.unescape(m.group(1)) if m else "NO OUTPUT")'
kill $SV; rm -f "$SRC/test.html"
