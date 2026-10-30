#!/bin/zsh
# Switches the auto-update on or off: a launchd job on this Mac that runs tools/auto-update.sh every
# 2 minutes while Aaron is logged in, so the plugin agent's pushes reach the iPad with nobody at the Mac.
#   ./tools/auto-update-setup.sh         switch it on (again)
#   ./tools/auto-update-setup.sh --off   switch it off
# Log: ~/Library/Logs/PipSandboxAutoUpdate.log. The Mac has to be awake for it to run.
# macOS won't let background jobs read Google Drive folders, so the job works in its own clone from
# GitHub at ~/PipSandboxAutoUpdate (made here). This folder is never touched by it.
set -uo pipefail
LABEL=com.aarondennel.pipsandbox.autoupdate
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CLONE="$HOME/PipSandboxAutoUpdate"
SCRIPT="$CLONE/app/tools/auto-update.sh"
LOG="$HOME/Library/Logs/PipSandboxAutoUpdate.log"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
if [[ "${1:-}" == --off ]]; then
  rm -f "$PLIST"
  echo "Auto-update is off."
  exit 0
fi

if [[ ! -d "$CLONE/.git" ]]; then
  git clone -q -b pip-playground https://github.com/AlphaDesignMedia/Ipad-widget-app.git "$CLONE" || { echo "Couldn't clone from GitHub."; exit 1; }
fi
git -C "$CLONE" config pipsandbox.autoclone true
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/zsh</string><string>$SCRIPT</string></array>
  <key>StartInterval</key><integer>120</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$(id -u)" "$PLIST" && echo "Auto-update is on: every 2 minutes. Log: $LOG"
