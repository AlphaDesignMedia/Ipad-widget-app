# Changes

## Web sandbox (republish these files to the "Pip Sandbox" artifact)
_None yet._

## Pip Sandbox app (`app/`, native, not part of the artifact)
- 30 Oct 2026 · `app/` · Copied Glass Clock's app, widget, shared code and config.
- 30 Oct 2026 · `app/` (project, entitlements, `Shared/ClockStyle.swift`, visible names) · Gave it its own identity: "Pip Sandbox", `com.aarondennel.pipsandbox`.
- 30 Oct 2026 · `app/run-on-ipad.sh` · New install script with its own build folder.
- 30 Oct 2026 · `CLAUDE.md` · Added the app section and the "Glass Clock is read-only" rule.
- 30 Oct 2026 · `app/GlassClock/Pieces/Pip.swift`, `PipLook.swift` · Pip: first meeting (twinkle, sleep, wake), grab and flick, bumps, blinks, pinch to resize; looks like the icon.
- 30 Oct 2026 · `app/GlassClock/GlassClockApp.swift`, `ContentView.swift` · Two small hooks: Pip over the app; "Pip and plugins" group in Settings > Accessibility.
- 30 Oct 2026 · `app/GlassClock/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, `app/tools/make-icon.sh`, `icon-main.swift` · Fairy icon drawn from Pip's own look.
- 30 Oct 2026 · `app/GlassClock/Plugins/` (PluginHost, PluginBar, Plugins, PipRemembers) · Plugin system and the first plugin.
- 30 Oct 2026 · `app/PLUGIN-SPEC.md`, `app/tools/check.sh`, `.claude/agents/plugin-maker.md`, `HANDOVER.md` · How plugins get made and tested; handover.
- 30 Oct 2026 · `app/GlassClock/Plugins/Sketch.swift`, `Plugins.swift` (one line) · Sketch: Apple Pencil draws over the whole app, with pressure and tilt; tools, colours, undo, paper; Pip reacts.
- 30 Oct 2026 · `.gitignore`, `PLUGIN-AGENT-HANDOVER.md`, `AGENT-NOTES.md`, `app/tools/watch-plugins.sh`, `take-plugins.sh`, `CLAUDE.md` · On GitHub as the branch `pip-playground`; the plugin agent's branch is `pip-plugins`.
- 30 Oct 2026 · `app/GlassClock/Playground/` (4 files, the plugin agent's, unchanged), `Plugins/PlaygroundBridge.swift`, `Plugins.swift` (one line), `.github/workflows/build.yml` · The plugin agent's Joy Slider and Idle Life, connected to Pip and the plugin bar through a bridge; GitHub builds both pip branches.
- 30 Oct 2026 · `.github/workflows/build.yml`, `Playground/PlaygroundCore.swift`, `Plugins/PluginDesk.swift`, `IDEA-INBOX.md` (from the plugin agent) · Merged: the GitHub build, a Swift 6 fix, and Plugin Desk (review every plugin: keep, tweak or scrap, with notes).
- 30 Oct 2026 · `Plugins/PluginHost.swift`, `PluginBar.swift`, `Pieces/Pip.swift` (core) · Panels that move like the app's settings; plugins can add sections to another plugin's panel; events between plugins (`host.post`, `.ink`); Pip can follow a point; one Joy level for every plugin.
- 30 Oct 2026 · `Plugins/Sketch.swift`, `PencilWonders.swift` (new), `Plugins.swift` (one line) · Sketch's tools are now a panel. Pencil Wonders: Pip follows the Pencil and answers drawings (moved out of Sketch).
- 30 Oct 2026 · `Plugins/NativeWonders.swift`, `HelperDial.swift`, `OpeningNight.swift`, `ProfessorPip.swift` (from the plugin agent) · Merged. Professor Pip: handles the new events and skips Pencil positions.
- 30 Oct 2026 · `CLAUDE.md`, `PLUGIN-AGENT-HANDOVER.md`, `HANDOVER.md`, `app/PLUGIN-SPEC.md`, `AGENT-NOTES.md` · Who does what: the Mac agent owns the core, plugins hold the extras. The spec covers the new core pieces.

- 30 Oct 2026 · `Pieces/Pip.swift` (core) · Pip follows with more life: leans into moves, overshoots, wobbles upright when it stops.
- 30 Oct 2026 · `Plugins/PluginHost.swift`, `PluginBar.swift` (core), `LiquidIcons.swift` (new), `Plugins.swift` (one line) · `host.barLook`: a plugin can restyle the plugin bar. Liquid Icons: each bar icon is a drop of liquid glass (Drops / Puddle / Blob).
- 30 Oct 2026 · `Plugins/PipsNews.swift` (new), `Plugins.swift` (one line) · Pip's News: Pip whispers what's new after appearing or waking; tap Pip to see it. 3 offers each, then stops.
- 30 Oct 2026 · `PluginHost.swift`, `Workspace.swift`, `LiquidIcons.swift`, `PluginBar.swift`, `PipsNews.swift` · Liquid Icons "Whole app" switch (on): the settings rail becomes drops, icons only; BarLook gains merge + wholeApp, host gains activeBarLook; News line.
- 30 Oct 2026 · `LooksTimeMachine.swift`, `Plugins.swift`, `PipsNews.swift` · Looks Time Machine v1: slide through the app's looks; save and go back to snapshots of your settings. News line.
