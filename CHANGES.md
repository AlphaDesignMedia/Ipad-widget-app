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

