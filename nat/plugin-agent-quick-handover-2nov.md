# Plugin agent · quick handover (Mon 2 Nov 2026)

Condensed. Chappie (ChatGPT) is writing the full one: when it arrives, it wins.

## You
The plugin maker for Pip Sandbox, Aaron's iPad playground for Glass Clock. You write plugins (Swift, one file each in
`app/GlassClock/Plugins/` plus one line in `Plugins.swift`). You don't edit the core, and you don't install on the iPad.

## Where
- **Push to `AlphaDesignMedia/Ipad-widget-app`, branch `pip-plugins`.** That's where all plugin work has gone so far, and
  where Rob takes it from. `pip-sandbox`'s own `pip-plugins` has been idle since 1 Nov 07:56. If Aaron or Rob says to
  move, move. Never touch `main`.
- GitHub Actions builds every push. Wait for green before telling anyone it's done.

## Read first
`CLAUDE.md` → `PLUGIN-AGENT-HANDOVER.md` → `app/PLUGIN-SPEC.md` → the top of `AGENT-NOTES.md` (newest first) → the open
**GitHub Issues on `pip-sandbox`**, which are Chappie's job list, each with an owner.

## Crew
| Who | Does |
|---|---|
| Aaron | director, designer, final say. Plain words, British, short. |
| Chappie | ChatGPT: ideas, files Issues, reads Rob's mailbox. Messages go via Aaron. |
| Rob | Mac: merges `pip-plugins`, tests in the simulator, installs on the iPad. |
| Robyn | core (`Pieces/`, host, bar, panels). Ask her in AGENT-NOTES for core hooks. |
| Jules | Blobby (Pip v2): `PipBlobbyLook.swift`, `BlobbyGlass.metal`. Hands off. |
| Gene Genie | plugin investigator, notes only (`nat/gene-genie-prompt.md`). |

## State (2 Nov, morning)
- **Pip's Light v2** is done and on the iPad (corners, sliders, bloom, glints, colour from Pip). Rob owns it now:
  `nat/pip-light-handover.md`.
- **Waiting on Robyn (#3):** the app's own panels (Settings, Groups, widget panel) aren't reported to the host. That
  blocks the light on them, and Pip bumping into or slipping behind panels.
- **Open Issues worth knowing:** #4 Blobby fps (Jules) · #5 plugin consolidation and Pip-led intros · #6 eyeball emoji
  as eyes · #7 glass impacts · #8 icon discovery · #9 drawing undo · #11 Pip polish · #12 dashboard worksheets ·
  #13 Pip in Home Screen widgets.

## Rules
- Pip off = the plugin shows nothing. Reduce Motion = nothing moves by itself. VoiceOver labels on.
- Calm by default. No guilt, streaks or selling. Make-believe names only. Pip is "they" unless set otherwise.
- **Light, not shadow** (Aaron). Cheap: no blur or mask every frame; save sliders when the finger lifts.
- Each plugin is self-contained and doesn't lean on other plugins, so it can be ported to Glass Clock later.

## Gotchas (learned the hard way)
- `host.panelFrame` / `cardFrame` / `barFrame` are **window space**; `pipPosition` is **inside the safe area**. Shift by
  `safeAreaInsets` (see `PipLight.swift`).
- Changing an `@AppStorage` default never reaches Aaron's iPad if the key is already saved. Use a new key.
- Blobby near panels runs at ~19 fps, against 60 for Classic. Measure before adding drawing near him.

## Every change
1. Save point (commit).
2. Push, then wait for GitHub to go green.
3. Leave Rob a test note at the top of AGENT-NOTES.
4. Tell Aaron in three lines: **What changed · What to test on the iPad · How to undo.**

Ask Aaron before anything big. Don't loop on waits.
