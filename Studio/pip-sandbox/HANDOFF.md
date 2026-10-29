# Pip Sandbox: handoff for the next Claude agent

_Updated Thu 29 Oct 2026, evening. Live version 1793306447-2978._

## Where things are
- **Artifact:** slug `5e823b87-0596-4cad-b8d5-89633ac3752f`, title "Pip Sandbox", https://claude.ai/artifact/Cft2LCVsnRsPFRVSkoD9hY. Ignore the two "(Copy)" backups.
- **The artifact is the source of truth.** `src/` is a snapshot of all 40 files at that version. Pull fresh files with `read_file` before editing, and compare them to `src/` to spot changes made since.
- **Capabilities:** `{db:{}, downloads:true, room:{}}`, runtime contract 0.2.92. If you add a capability, declare it first, then publish.
- **Testing guide for other platforms:** [TESTING.md](TESTING.md). Reports go to `reports/`, to the db `checks` collection, and as `TEST …` notes in Pip's Brain.

## How it's built
- `index.html` loads `core.js`, `pip.js`, `extras.js`, `engine.js` and `host.js` as one script, then each file in `PLUGINS` (30 of them, all on).
- `host.js` exposes `window.PipHost`. Recent additions:
  - `setPerch`, `smash`, `restore`
  - `interrupt`, `isBusy`, `busy(name,on)`. These drive the ✋ Stop chip, which Esc also triggers.
  - `db()`, `downloads()`, `refreshPanels`, `applyForm`, `savePrefs`
- Plugin bar boilerplate (`PB`) is in `tools/plugbar-PB.js`. The `tools/*.src.js` files contain `/*PB*/`, which is replaced with that boilerplate to make the shipped plugin.
- **Test:** `tools/smoke.sh` runs headless Chrome on port 8791. It checks that all plugins load, every card opens, Stop clears busy, smash stays closed, and the log is empty. Last run: all passing. For a new plugin, copy `tools/smoke-body.html` and add its checks.
- **Publish:** `publish_files`, patch mode, with `base_version`. After publishing, copy the changed files into `src/` so this snapshot stays current.

## Database (read at session start)
- `brains/aaron/parts/{profile,notes,lessons,progress,log}` is Pip's Brain.
  - Add entries to `log` with `from:"claude"`. Pip greets Aaron with the newest one.
  - Notes that start with `TEST` come from testers.
- `checks` holds iPad Check reports. The first real one is `uzqy4fqnz0l6nj88gaqu`:
  - iPad in the Claude app, 1590×1106 @2x, 84 fps
  - motion permission denied
  - audio suspended until the first tap
- `boards/page-N` holds Sketch pages.

## Open with Aaron
- **Blind test:** the 🎮 plugin is on quietly. Don't explain what it does until Aaron says whether he noticed anything. Then read `PipGame.stats()` with him. Details are in Claude's memory note on the sandbox.
- **Glips** (his plugin, installed 29 Oct) has three changes to fit the sandbox:
  - smashed panels stay smashed unless "Bring smashed panels back" is on
  - cracks seal after 4 quiet seconds
  - ✋ Stop interrupts repairs

  Check that he's happy with these.
- **Motion:** denied in the Claude app. If he wants tilt, try Safari, or accept it as an app limit.
- **Pip Link:** it is a demo online (claude.ai room). Real offline sharing needs the native app (Multipeer).
- **Progress dashboard:** one chat card (`chat/sandbox-handover-29oct`) points here. Sandbox items aren't in the lanes yet.

## Next likely work
- More plugins from Aaron, which he writes with other AIs. Adapt each one to PipHost:
  - use `H.busy`/`H.isBusy` for long actions
  - make sure ✋ Stop ends them
  - keep `×` smash working
- Then smoke test and publish.
- Read new test reports from other platforms, and fix the worst bug first.
- Ideas Aaron has raised but not asked for yet:
  - brains for other people
  - more surprises (the deck asks Claude for more once all have been seen)
