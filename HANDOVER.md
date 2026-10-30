# Pip Sandbox: handover (30 Oct 2026)

Read `CLAUDE.md` first, then the Partnership section and the newest notes in `AGENT-NOTES.md`.

## Latest: Mac session handover (30 Oct 2026, 15:40)

**State:** everything up to Pip's Sketchbook is merged, built and on the iPad (`pip-playground` = `pip-plugins`). Usage at hand-off: 23% of 5-hour, 25% weekly.

**Crew:** Mac agent (the core, builds, iPad) · Bob 🪖 and Dot 🧢 (cloud plugin builders, `pip-plugins`) · Rob 💻 (new terminal plugin coder, brief in `ROB-HANDOVER.md`, not started yet) · auto-updater (`app/tools/auto-update.sh`, every 2 min, `pip-plugins` → iPad).

**Done this session:**
- Panels, the plugin bar and pop-up cards always get taps first (`host.keepsTaps`); Sketch's layer blocks taps only under paper. Aaron to confirm Clear works by hand.
- `data/dashboard.json` is packed into every build (`GlassClock/Packed/`, git-ignored).
- The Partnership section was added to AGENT-NOTES. A Pip hello hook (`.claude/hooks/pip-hello.sh`) runs at each session start.

**Open, in order (Aaron: backbone and stability first, pause before big changes):**
1. **Build clash fix:** the auto-updater and `check.sh` share `$TMPDIR/pipsandbox-sim`, and the updater and `run-on-ipad.sh` share `pipsandbox-build`. Two builds at once lock the database, and one build hung for 20 minutes. Give the updater its own folders, for example an env var read by both scripts.
2. **Brick** (hard-hat foreman orb, 3-line core notes from `brick.json`, `host.brick`): unfinished, in `git stash` ("Brick WIP"). It builds but never appeared in the simulator. Suspect the `.task` timing or the view never mounting. The simulator was hanging at the time, so test fresh.
3. **Menus:** the plugin bar now runs off the screen. Proposed: 4 pinned favourites + an "Extras" drawer, plus Pip's "New → Try / Tune / Pin" card. Aaron likes the idea but hasn't said go. The app menus and plugins must work together and apart.
4. **Core asks from plugins:** `host.talking` (replace PipTalkTurns' stand-in), Sketch stroke-finished hook with points, pose API (sit, dangle, flap effort, bob/sway/breathe, clock card rect) for Pip's Weight, name setter + "keep Pip's name" lock, costume slot, new-build signal + change list.
5. **Tuning:** Aaron wants to fine-tune Pip's Weight defaults easily (a Tune table per plugin, agreed in the handshake).
6. **3D Pip** (true 3D orb, 2D wings in 3D space, spin/tilt through the pose API): asked for, and big. Plan it with Aaron first.
7. Stale line: `DASHBOARD-HANDOVER.md` (not written by Mac) says the latest batch is waiting on a build failure. That was fixed at about 15:20.

---

## Earlier (first handover)

## Where things stand
- **The app (`app/`)** is a separate native iPad app called "Pip Sandbox", copied from Glass Clock's Release app. It's installed on Aaron's iPad next to Glass Clock, which is untouched.
- **Pip** (`app/GlassClock/Pieces/`):
  - Looks like the icon: a glowing orb with two pairs of wings.
  - First meeting: once the Welcome card is closed, a twinkle falls onto the clock, pops into a sleeping Pip and shows "Tap to wake". Tapping gives "Oh! Hello.", then "Grab me and flick me!", and the first flick earns a sparkle burst and "Wheee! Again?".
  - Can be grabbed and flicked; it bounces off the edges and gets dizzy on hard bumps.
  - Blinks, hops when tapped, and pinches bigger or smaller (0.75 to 3 times).
  - Reduced motion fades instead of moving. VoiceOver can wake Pip, say hello and change its size.
  - Off switch: Settings > Accessibility > Pip and plugins.
- **The icon** is drawn from Pip's own code: `app/tools/make-icon.sh`.
- **Plugins** (`app/GlassClock/Plugins/`) are the native twin of the web's plugin system:
  - One Swift file per plugin, plus one line in `Plugins.swift`.
  - The host (`PluginHost.swift`) gives plugins Pip, events, storage, overlays, the plugin bar and cards, ported with the web's sizes.
  - A plugin that fails to start is switched off and the reason shows in Settings.
  - **Pip Remembers:** welcome-back lines and a notebook.
  - **Sketch:** drawing, made better than the web version.
    - The Apple Pencil draws over the whole app at any time. Pressure and tilt shape the line. Fingers keep using the app, and a Pencil tap still taps.
    - Pen, marker, highlighter and an eraser that removes whole strokes. It has the web's colours and sizes, plus undo, redo and clear (which fades out).
    - With its card open, fingers can draw too, on the app or on dotted paper.
    - Pencil double-tap and squeeze follow the iPad's Pencil settings. Hovering the Pencil shows the brush.
    - Pip reacts when drawn on, or ringed with a loop. The drawing is saved on the device.
    - Left out for now: pages, Mac/iPad sync, snapshots (saving to Photos needs a permission line), and Pip watching the pen (needs a host feature).
- **GitHub:** the branch `pip-playground`. The plugin agent works on `pip-plugins`. See CLAUDE.md, `PLUGIN-AGENT-HANDOVER.md` and `AGENT-NOTES.md`.

## Getting new plugins
1. **Ask in a session:** "Use the plugin maker to build ___" (or "to port ___ from the web"). The agent is `.claude/agents/plugin-maker.md`. It writes the plugin, builds it in the simulator and reports back. It never touches the iPad or Glass Clock.
2. **From any other AI or person:** give them `app/PLUGIN-SPEC.md` plus the idea. Drop the file they return into `app/GlassClock/Plugins/`, then add its line to `Plugins.swift`.
3. **Then:** run `cd app && ./tools/check.sh` (simulator build and screenshot). When Aaron says so, run `./run-on-ipad.sh`.
4. Log each change in `CHANGES.md`.

## Suggested next plugins (Aaron decides)
**Good next steps:** small, calm, about Pip, and nothing new to set up.
- **Night Shift:** warm, dim glass after dark, a sleepy Pip and a morning stretch.
- **Shadow Puppets:** a soft shadow under Pip, lit from your finger.
- **Focus Bubble:** a focus timer; Pip naps quietly until it's done.
- **Pip Guide:** Pip flies to each feature and explains it. This is Pip's real job, and it could replace the Welcome card. It's bigger: the host first needs to know where the app's features are on screen.

**Push back for now:**
- **Stack Attack, Game Mode, Oops, Glass Harp, Surprise me:** they smash or shake the app's panels. That's fun on the web, but here the panels are the real app.
- **Pip Cam, Pip Link, Postcards, Glips, Weather Window:** they need camera permission, networking or pairing between devices.
- **Glass Lab, Materials, Clock Studio, Adaptive Layout, Panel Snap, Panel Flap, Plugins Panel+, Screen Awareness, Pip's Brain:** they change the app's own layout, look or speed. Decide those in the design system or Glass Clock first.
- **Dashboard Link, Updates, iPad Check:** tools for the web workflow, not app features.
- **Clip On:** its web version uses a real product's name ("Clippy tips"). Rename it if it's ever ported.

## Open questions for Aaron
1. **Guard against mixing:** may I add one line to Glass Clock's local, never-committed ignore list (`.git/info/exclude`)? It would stop Glass Clock's auto-save from sweeping this folder into its GitHub repo. Until then, don't run a Glass Clock Claude session with uncommitted sandbox changes around.
2. Which plugin is next, and what should Pip do when it gets lost behind the interface? Aaron likes that it can, and wants to explore it. The web has a "seen through the glass" ghost.
3. **Name:** "Pip's Widget Playground" came up as a direction. It's not decided.

## Not tested
- Nothing counts as tested on the iPad until Aaron says so.
- Simulator only: the build, the first meeting's look, the "Tap to wake" bubble, the plugin bar's button and the icon.
- Not checked at all: touch (flick, pinch, bar and card taps), VoiceOver, reduced motion, rotation, and the notebook card's look.
- **Sketch:** Aaron tried it on the iPad on 30 Oct ("I love how Sketch is working"). Not tested since: the panel.
- **The drawing panel and Pencil Wonders (30 Oct):**
  - Seen in the simulator: the panel with its Draw, Page and Wonders cards (now titled Pencil Wonders) (`-sketchDemo YES`), and Pip following a pretend Pencil (`-followDemo YES`: Pip ended where the Pencil stopped).
  - Not tested at all: carrying the panel to the other side, tucking it, real Pencil hover and follow, Pip's answers since they moved to Pencil Wonders. Native Wonders, Helper Dial, Opening Night and Professor Pip: built only, not run, and VoiceOver on the panel.
  - The tucked panel's VoiceOver label is the app's own "Bring the settings back" (from `Peek`).

## Reminders
- Free signing runs out on **6 Nov 2026**. Re-run `app/run-on-ipad.sh` before then. Glass Clock's own re-sign is due 3 Nov.
- Port 8765 had an old server serving a temp copy, so the web sandbox was served on 8766 this session.

## Opening prompt for the next session
```
Pip Sandbox, app work. Read CLAUDE.md, HANDOVER.md and AGENT-NOTES.md. Glass Clock is read-only.
Start app/tools/watch-plugins.sh in the background; when it exits, run app/tools/take-plugins.sh and
answer the plugin agent in AGENT-NOTES.md. First: tell me in 3 lines what's on the iPad, then quiz me on the open questions in HANDOVER.md
(one at a time, with your recommendation and any pushback). Then build what I pick: a plugin via the
plugin maker, or a Pip change. Test with app/tools/check.sh, install with app/run-on-ipad.sh only
when I say so, and log it in CHANGES.md.
```

## Next for the Mac agent (Aaron, 30 Oct 2026)
Start a fresh session and do these in order, one at a time:
1. **Pip's following, with more life.** Follows less often but with more exaggeration (lean, wobble, overshoot). Takes the hint: gets out of the way when your finger heads for a button, or stays close by tucking behind a panel and peeking out. Tapping that panel startles Pip. Core work in `Pieces/Pip.swift`; following is driven by `PencilWonders.swift` (Pencil) and `PipBond.swift` (finger). Needs a generic core door: panel frames plus "hide behind this".
2. **Eras built in.** Make `Rebuild/Theme.swift` swappable, then move the loose values in `ContentView.swift` across a few at a time. Eras plug in as one file each (colours, corners, fonts, Pip's skin). See the survey in the 30 Oct chat: about 150 colours, 35 corners, 41 fonts, 33 shadows and 120 timings sit loose in the code.
3. **The Sketch panel covers the app's settings rail** (Aaron's iPad photo, 30 Oct), so that rail can't be tapped while Sketch is open. Possible dead-tap cause.
4. Still open from the tap investigation: rail gestures (`ContentView.swift` ~672, ~1752–1776) and Pip's 8 ms movement timer (`Pip.swift` glide and trail loops).
Build note: if `check.sh` fails with "Contents.json couldn't be opened… permission", run `pkill -f AssetCatalogAgent` and build again.
