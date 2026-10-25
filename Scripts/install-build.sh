#!/bin/zsh
# Puts one chosen build on the iPad and records it, so it's always clear what you're running.
#   Scripts/install-build.sh                 the latest commit on this branch
#   Scripts/install-build.sh <tag|commit>    an earlier build, e.g. stable-ipad-22oct-1615
#   --stable                                 also tag it as a stable point (stable-ipad-<date>)
# Builds from a clean copy of that commit, so unsaved edits never reach the iPad, then tags it
# ipad-<date> and moves the `on-ipad` tag to it. `git log -1 on-ipad` shows what's on the iPad.
# Any other options (--meter, --debug, --rebuild) are passed to run-on-ipad.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

REF=HEAD; STABLE=false; PASS=()
for option in "$@"; do
  case "$option" in
    --stable) STABLE=true ;;
    --*) PASS+=("$option") ;;
    *) REF="$option" ;;
  esac
done
COMMIT=$(git rev-parse --verify "$REF^{commit}")
[[ "$REF" == HEAD && -n "$(git status --porcelain)" ]] && echo "Note: unsaved edits aren't in this build (only the last commit is)."

COPY="${TMPDIR:-/tmp}/glassclock-install"
rm -rf "$COPY"; mkdir -p "$COPY"
git archive "$COMMIT" | tar -x -C "$COPY"
# The copy's own script does the build and install, as it did when that build was made.
zsh "$COPY/Scripts/run-on-ipad.sh" "${PASS[@]}"

STAMP=$(date +%d%b-%H%M | tr '[:upper:]' '[:lower:]')
git tag -f "ipad-$STAMP" "$COMMIT" >/dev/null
git tag -f on-ipad "$COMMIT" >/dev/null
$STABLE && git tag -f "stable-ipad-$STAMP" "$COMMIT" >/dev/null
git push -q -f origin "ipad-$STAMP" on-ipad $($STABLE && echo "stable-ipad-$STAMP") 2>/dev/null || echo "Tags saved here; the GitHub push failed."
echo "On the iPad: $(git log -1 --format='%h %s' "$COMMIT" | cut -c1-90)"
