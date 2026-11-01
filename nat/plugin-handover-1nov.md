# Handover for the plugin maker · Sun 1 Nov 2026, 06:00 · from Mac · Rob

For a fresh plugin chat. Read this, then the top notes in `AGENT-NOTES.md` (newest first). Branch: `pip-plugins`.

## Who's who
- **Aaron**: director, UK graphic designer. Plain words, British spelling, short answers, ASCII drawings. Every change ends
  with: What changed · What to test on the iPad · How to undo. Updates end with one line: did · didn't test · what's next.
- **You (plugin maker, was "Jules")**: plugins in `app/GlassClock/Plugins/`, branch `pip-plugins`. GitHub Actions builds every
  push; keep it green. Core changes are asked for in AGENT-NOTES, not made (sheet Q was a one-off, with Aaron's go).
- **Robyn**: core lead. Owns `Pieces/`, `PluginHost.swift`, `PluginBar.swift`, `ContentView.swift`, the app files and the
  widget extension (`GlassClockWidget/`).
- **Rob (me, the Mac)**: takes your work (`take-plugins.sh`: merge into `pip-playground`, build, push, iPad), tests in the
  simulator, Tess (every plugin, late frames), stress runs, iPad installs. I own TICKETS.md, TESTS.md, `app/tools/`, MenuStress.swift.

## Rules that matter
- Never touch `main` or the Glass Clock project. The Sandbox app lives here; Glass Clock is separate.
- The Dashboard is **Aaron's private mission control**: never shipped, no real brands in what we add.
- **The board.json gist address is secret**: it lives only on the Mac (`app/GlassClock/Private/board-feed.txt`, git-ignored)
  and is packed into the app at build. Never write it into code, notes, logs or commits. `Feed.boardBase` reads the file;
  no file (Actions) = no board.json, headline only.
- Stability first: anything crashing, freezing or slow gets parked (`// parked: <reason>, ticket <date>`).
- Reuse what's there (Aaron, repeatedly: "dont try and re make what is already there").

## Where the Dashboard is now (on the iPad since 05:50, build 4fd06b4)
```
 top bar:  Classic · Panels · [Dashboard]          plugin bar stays at the bottom
 ┌ groups pill ┐  ┌ stage: Progress widget ┐  ┌ column of SettingsCards ┐
 │ At a glance │  │ (tap → Needs you)      │  │ each group in turn      │
 └─────────────┘  └────────────────────────┘  └─────────────────────────┘
```
- **Files:** `Dashboard.swift` (plugin, `Feed`, `DashboardData`), `DashboardPanels.swift` (the tab screen `PanelsScreen`,
  groups `DashGroup`, panels, `ForRobList`), `DashboardWidget.swift` (canvas tile), `DashboardQueue.swift`,
  `NextAction.swift`, `BusyPip.swift`, `StableSwitch.swift` (these four show only inside the dashboard: `addsTo: Dashboard.panelsSlot`).
- **Core hook (sheet Q, ede400e):** `SandboxPlugin.screen(_:)` + `screenName`, `PipHost.openScreen` / `screenPlugins` /
  `activeScreen`; the top switch adds a tab per screen plugin; off / Pause all / Safe mode falls back. Robyn is reviewing it.
- **Live feed:** `Feed` downloads board.json (private gist) + status.json (widget gist) at most once a minute while open.
  Read-only, off switch, keeps the last good copy, footer "Live · checked …" / "last checked …" (kept across launches).
  `DashboardData` decodes each part on its own (one bad part doesn't lose the board). `outboxForRob` → the For Rob group.
- **Updating the board:** the master chat writes a BOARD.JSON block → Aaron → Rob runs `board-push` (clipboard → tidy with
  `app/tools/board-fix.py` → check → private gist → read back). Bad paste / no network = nothing changes. Latest: 05:55.
  board.json may also carry `answers` (not shown in the app yet).

## Aaron's asks, in order
1. **Lay it out like his Home Screen** (05:40): "make them more like widgets… i need to lay it out like my home screen".
   Widgets in Small / Medium / Large on `HomeGrid` (Workspace.swift:1125, public; iPadOS spacing 170 pt / gap 38.5 pt),
   each on the clock widget's own `ClockCard` + `ClockStyle.load()`. Tap a widget → its full card. Sketch in AGENT-NOTES
   (bc8b471). Today's Panels-look tab is "not quite right but its in".
2. **Real iPad Home Screen widgets** after that (dbb71a3): new widget kinds in the existing extension (Robyn's), reading a
   saved copy of the board from the app group; tap → opens the Dashboard tab. Never the gist address in the widget.
3. **Swipe to close** the dev panels (7a0a041): Robyn for the plugin side panel; the dashboard is a tab now, nothing to close.
4. **Drop look for Pip** everywhere: needs Robyn's look hook (`host.pipStyle`, spec in AGENT-NOTES 84fd35f); `PipLooks.apply`
   has the two lines ready to un-comment.

## Open bugs and numbers
- Canvas tile covering the groups pill: **fixed by you (ee57a56), not taken or tested yet.**
- "Live · checked…" shows twice on the tab (stage + At a glance). Small.
- 13" iPad portrait is 1032 pt, above the 980 pt "wide" line, so portrait keeps the 3-part layout with a narrow stage.
- Tess 04:52 (busy Mac, load 67, treat as noisy): Pip Looks 🟢 3 late / 110 ms (was 50 / 281, your fix worked);
  Dashboard 🔴 11 late / 578 ms; Pip Remembers 🔴 a 2.4 s hang (new; re-test on a quiet Mac).
- Simulator checks passed (sheet P): fold, clock colour follows, live feed off → footer says off, Need you 5 everywhere.
  Not yet tested: landscape (the Mac won't rotate the simulator from a script; check on the iPad), Reduce Motion, the tab check.

## Held
- `outboxForRob` job "Test Low Power Mode turning on Simpler effects… port-* branch": Glass Clock work; Rob holds it until
  Aaron says go (Glass Clock is off-limits for the Sandbox team).

## How Rob tests your next push
`take-plugins` at background priority → simulator: `-checkP grid` (dashboard), a tab check (`-checkQ`, ready to add), Tess,
the dashboard stress run → iPad when Aaron says. Put a "Rob, to test" list in your AGENT-NOTES entry and he'll answer
with did · didn't test · what's next.
