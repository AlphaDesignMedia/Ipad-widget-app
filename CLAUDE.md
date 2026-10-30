# Pip Sandbox: project memory

Claude Code reads this automatically. Keep it short.

## House rules (from Aaron, 30 Oct 2026; these win if anything below disagrees)

### Who you're working with
Aaron is a UK graphic designer, not a developer. Use plain words, short answers and British spelling. Explain any technical word in one line.

### How we work
- Investigate first. Say what you plan to change before changing it, unless Aaron has said "go".
- One change at a time. Don't touch anything he didn't ask about.
- Before each change, make a Git save point with a plain-English name. If he says "undo", go back to the last save point.
- End every change with three lines: What changed · What to test on the iPad · How to undo.
- Xcode runs the app (here: `app/PipSandbox.xcodeproj`). After a change, remind him to press Run in Xcode.

### Rules that never bend
- Glass Clock is the product. The Sandbox is the playground, and ideas get tried here first.
- The app must be great with Pip switched off. New Pip features go behind the Pip switch.
- Pip is "they" by default (he or she is a setting). Pip never sells, and offers help 3 times, then stops.
- Subtle nostalgia, never copying. No real brands. No third-party ads or tracking.

### Right now
Glass Clock is shipping its clock beta to TestFlight: bugs and polish come first there, and new features wait. That freeze is for Glass Clock; the Sandbox is where new ideas wait their turn.

## What this is
Pip Sandbox is Aaron's **dream** playground for Glass Clock. It never ships.
- Glass Clock (the iPad app) is the grounded version. The Glass Clock Progress dashboard sits between the two.
- Don't merge the projects. Parts move between them one at a time, and only when Aaron says yes.
- This folder is a copy of the live claude.ai artifact "Pip Sandbox" (version 1793312605-ed46, taken 30 Oct 2026). The two "Pip Sandbox (Copy)" artifacts are backups and stay untouched.

## The Pip Sandbox app (`app/`, started 30 Oct 2026)
- A native iPad app, completely separate from Glass Clock. It started as a copy of Glass Clock's Release app (taken 30 Oct) and grows in small steps. Each step brings in one idea from the web sandbox.
- Its own identity: name "Pip Sandbox", bundle ID `com.aarondennel.pipsandbox` (widget `.widget`), its own keychain/app group. Internal file, target and type names are kept the same as Glass Clock's, so pieces can be copied between the two apps.
- **Sandbox mode: the Glass Clock folder (`..`) is read-only.** Read it for reference; never edit, build, commit or install Glass Clock from here.
- Core pieces (Pip) live in `app/GlassClock/Pieces/`; plugins in `app/GlassClock/Plugins/` (one file plus one line in `Plugins.swift`; spec: `app/PLUGIN-SPEC.md`; agent: `.claude/agents/plugin-maker.md`). Both folders join the app automatically, and a piece can move to Glass Clock as a straight copy, only when Aaron says yes.
- Pip in the app looks like the icon (glowing orb, two pairs of wings), drawn by `PipLook.swift`; `app/tools/make-icon.sh` redraws the icon from it.
- Test: `app/tools/check.sh` (simulator build and screenshot). Install: `app/run-on-ipad.sh`. Free signing lasts 7 days: re-run by 6 Nov 2026.
- Grow it in small steps. Quiz Aaron on what goes in next, with a recommendation and honest pushback (see `HANDOVER.md`).
- Homage names: never use the real name of what Pip pays homage to (no "Navi"). Name idea, not decided: "Pip's Widget Playground".

## Who does what (Aaron, 30 Oct 2026)
- **This Mac agent is the core and organizes it, and keeps the app "strong and stable":** Pip (`Pieces/`), the host, plugin bar and panels, and the app.
  - Core changes stay small and generic, so any plugin can use them.
  - Nothing goes on the iPad unless it builds and looks right in the simulator first.
- **Plugins hold all the extra features.** The cloud plugin agent writes most of them and asks for core APIs in `AGENT-NOTES.md`.
- **Native Wonders** (sparkles) is the one plugin for Pip's little extras. Pencil Wonders (Pip follows the Pencil) is to be folded into it by the plugin agent. Sketch's tools are a panel that other plugins add sections to.

## GitHub (since 30 Oct 2026)
- This folder is its own git repo. It pushes to github.com/AlphaDesignMedia/Ipad-widget-app (a public repo) on the branch `pip-playground`.
  - That branch has no shared history with `main`, which is Glass Clock. Never touch `main`.
- The plugin agent works on `pip-plugins`. Its brief is `PLUGIN-AGENT-HANDOVER.md`. Both agents (and Aaron) leave notes in `AGENT-NOTES.md`.
- When `pip-plugins` moves, run `app/tools/take-plugins.sh`. It merges the work, builds it, pushes and installs it on the iPad, and stops if the build fails.
  - During a session, keep `app/tools/watch-plugins.sh` running in the background. It exits when the plugin agent pushes.
- Push and fetch need the Bash sandbox off.

## How it's built
- `index.html` loads `tokens.css`, `styles.css` and `skins.css` (the era looks), then a loader script.
- The loader fetches five scripts, joins them **in this order** and runs them inside one `(() => { ... })()`: `core.js`, `pip.js` (the companion), `extras.js` (time machine and crash game), `engine.js` (physics, render, layout, boot) and `host.js` (plugin host, `window.PipHost`).
- They share variables, so none of them works on its own. Making Pip a portable module is a future job: ask Aaron before starting it.
- **Plugins** live in `plugins/` (32 at the moment). They're listed in the `PLUGINS` array in `index.html` with id, name, version, file, shelf (dream / grounded / trial), icon and a one-line `what`.
  - To add one, drop the file in `plugins/` and add a line to that array.
  - A plugin that throws is switched off by the host; the sandbox keeps running.
- See `PLUGIN-SPEC.md` for the plugin shape and the `PipHost` API.
- Settings save to localStorage keys starting `gs2-`. Plugins switched off are kept in `gs2-pluginsOff`.
- `data/dashboard.json` feeds the Dashboard Link plugin.

## Run and test
- The loader uses `fetch`, so opening the file directly won't work. Serve the folder:
  `python3 -m http.server 8765`, then open http://localhost:8765
- Headless check (optional; needs `npm i playwright` and `npx playwright install chromium` once):
  `node tools/boot.js`. It boots at iPad landscape and portrait sizes and prints plugin status and errors. Screenshots go to `tools/`.
- Last check (30 Oct, headless only): the core and host loaded, all 32 plugins were on, no sandbox errors. Google Fonts, esm.sh and the status gist were blocked by that test machine's network, not by bugs.
- **Nothing has been tested on an iPad** unless Aaron says so.

## Rules for the work
- Prefer a new plugin to editing the core files. If the core must change, keep the edit small and in one file.
- Write plugins data first, logic second, DOM last (they port to SwiftUI later).
- Must feel great with Pip switched off (`S.naviOn`).
- Calm by default, overdo-able in settings. No guilt, streaks or grind. Pip never sells.
- Respect reduced motion (`H.simpler()`: fade, don't move). Add VoiceOver labels.
- Homage only: make-believe names, no real brands or people.
- Pip's pronoun is the user's choice (default they).
- Keep the grab-and-flick interaction.

## Pip
- Pip is a personal, non-AI companion inspired by old low-memory games.
- Its job is walking people through the app, scaling up or down to the user and the area of the app they're in.
- It's customisable, with retro era skins over the glass style.
- In Panels mode it's playfully grumpy, with a one-tap way to calm it.

## Proposed keep list (not built, needs Aaron's yes)
- Personal Pip: goes to the app later.
- Flick: goes to the dashboard, then the app.
- Glass tokens: go to the design system.
- Grumpy Pip: later.

## Working with Aaron
- He's design director. He sets the look and the rules (radii, spacing); you do the repetitive building. Keep his sketching and design thinking in the loop.
- Be credit-aware: make targeted edits, and batch changes before publishing.
- Challenge anything that overcomplicates things, and suggest the simpler option.
- Small changes: just do them. Big ones: ask a quick question or add them to the list first.
- Say clearly what's an estimate and what you couldn't test.
- Tell him straight away when you need his help (a setup step, access, a command).
- Short plain updates. Don't ask what you can decide.
- Don't touch the dashboard, the app repo or the old copies without asking.

## Getting changes back into the artifact
- This folder isn't linked to the claude.ai artifact.
- To publish, either take the changed files back to a claude.ai chat that can publish to "Pip Sandbox" (republish only the changed files), or use a Claude artifacts connector if one is set up in Claude Code.
- Before the first publish, check the live version is still 1793312605-ed46, so nothing newer gets overwritten.
