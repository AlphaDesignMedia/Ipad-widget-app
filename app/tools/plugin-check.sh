#!/bin/bash
# PLUGIN CHECK (Jules, 31 Oct). Part of the Plugin Kit: reads every plugin and flags the things that have made the app
# stutter or broken a rule before, so nobody has to spot them by eye. It only warns: it never stops a build.
# Run: app/tools/plugin-check.sh  (from anywhere). On GitHub it posts each warning as an annotation on the line.
# To quiet one line on purpose, end it with:  // check: ok <why>
cd "$(dirname "$0")/../GlassClock/Plugins" || exit 0
gh=${GITHUB_ACTIONS:+1}
banned=$(echo ivaN | rev)   # the homage name, never written out in our source
total=0

warn() { # file line rule message
  total=$((total+1))
  printf '  %-26s %5s  %-12s %s\n' "$1" "$2" "$3" "$4"
  [ -n "$gh" ] && echo "::warning file=app/GlassClock/Plugins/$1,line=$2,title=Plugin check: $3::$4"
}

scan() { # rule regex message
  grep -nE "$2" -- *.swift 2>/dev/null | grep -v '// check: ok' | while IFS=: read -r f n _; do
    warn "$f" "$n" "$1" "$3"
  done
}

echo "🔍 Plugin check: warnings only. Each one is worth a look, not always a fix."
{
scan internet  'URLSession|URLRequest|WKWebView|NWConnection' "Uses the internet. Plugins don't, without Aaron's yes."
scan timer     'Timer\.(publish|scheduledTimer)' "A timer keeps running while nothing happens. Prefer a Task that stops itself."
scan loop      'repeatForever' "A looping animation. Make sure it only runs while it's on screen."
scan everyframe 'TimelineView\(\.animation\)' "Redraws every frame. Add paused: when nothing moves."
scan name      "\\b$banned\\b" "The homage name. Use Pip."
for f in *.swift; do
  case "$f" in PluginHost.swift|PluginBar.swift|Plugins.swift|PipTalkTurns.swift|DevFold.swift|PluginRisk.swift) continue;; esac
  if grep -q 'Button\|Toggle(' "$f" && ! grep -q 'accessibilityLabel\|accessibilityHint' "$f"; then
    warn "$f" 1 voiceover "Buttons but no VoiceOver labels."
  fi
  if grep -q 'PluginInfo(' "$f" && ! grep -q '// Keeper:' "$f"; then nokeeper+=("${f%.swift}"); fi
done
} | tee /tmp/plugin-check.out
n=$(grep -c . /tmp/plugin-check.out)
# Keeper lines: one summary, not a warning per plugin (they're being added as plugins are next touched).
k=$(for f in *.swift; do grep -q 'PluginInfo(' "$f" && ! grep -q '// Keeper:' "$f" && echo "$f"; done | wc -l | tr -d ' ')
[ "$k" -gt 0 ] && echo "🔑 $k plugin(s) without a '// Keeper:' line yet. Add one when you next touch them."
echo "🔍 $n warning(s)."
exit 0
