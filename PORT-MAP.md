# Port map: what moves into Pip's Playground

This is the result of combing through everything: two web sandboxes and the Swift app. Plugin agent, 30 Oct 2026.

## What exists

| Where | What |
|---|---|
| **Swift app** (`from-415`) | A clock widget editor (Digital/Analog, 6 fonts, glass, glow, shadow, colour), Moods, a style gallery, onboarding, a guided tour, custom backdrops, a Workspace with panels, the widget, design tweaks, crash reports. `Rebuild/` is unused. |
| **Web sandbox A** (Aaron + plugin agent) | 26 plugins (HANDOVER §7). The newest: Clock Studio, Glips, Ultra Idle, Screens. |
| **Web sandbox B** (`Studio/pip-sandbox`, the Mac agent's) | 30 plugins, including some A doesn't have: Pip's Brain, Sketch, Surprise deck, Game mode, Pip Link, Pip Guide, iPad Check, Dashboard link, Clip-on. |

⚠️ **The two web sandboxes have drifted apart.** Neither is "the" sandbox. That's fine as a backup, but from now on new joy goes into the Swift playground first.

## The rule for choosing

Port only what makes Aaron smile within 5 seconds, and port cheap things before costly ones.

## Wave 1: joy, cheap, port now (the plugin agent does these)

| Plugin | Why | Swift needs | Status |
|---|---|---|---|
| 🎚️ Joy Slider | Master liveliness control | — | ✅ built |
| 💤 Idle Life | Pip alive while you idle | Task loop | ✅ built |
| 🗣️ Pip's Voice | Every line, per personality: idle moans, theories, hellos, jokes, the forgetful flaw | data only | ⏳ next |
| 🫠 Pib | The accidental plugin: nags, fake uninstaller stuck at 99% | sheets | ⏳ next |
| 🌙 Idle Scenes | Fish, bubbles, paper plane, stars drifting while you idle | TimelineView + Canvas | ⏳ next |
| 🌗 Night Shift | After 9pm: dimmer, warmer, Pip nods off | a time check | ⏳ |
| 🫧 Focus Bubble | 5/15/25-min focus ring, Pip goes quiet | a timer | ⏳ |
| 📓 Pip Remembers | Notices what changed since last time | UserDefaults | ⏳ |
| 🥚 Era Eggs | A hidden joke per era | data only | ⏳ |

## Wave 2: visual, needs Pip's Swift view from the Mac agent

- 🧭 **Spatial:** front or behind the glass, emoji bubbles.
- 🌗 **Shadow Puppets:** a shadow lit from your finger.
- 🫧 **Glips + Mend:** cracks drawn as paths that Pip seals, with Clip helping.
- ⏱️ **Clock Studio faces:** Flip, Roll, Words, Segments and Dots as new `ClockFaceKind`s, plus the ⏱️ share codes. The app already has strong styling, so port the *faces* and *codes* only, not the whole Studio.
- 🧬 **Morph:** silhouette morphing. Hard. Last.

## Wave 3: native superpowers (better in Swift than on the web)

- 📱 **Tilt (CoreMotion):** Pip slides and the glass catches light. Blocked on the web; free in native.
- ✉️ **Pip Link + Postcards over Multipeer:** offline, device to device.
- 🎵 **Glass Harp:** AVAudio plus haptics, which feels far better on device.
- 🔬 **Glass Lab:** use the real Liquid Glass API. It overlaps with Design Tweaks, so merge it there.

## Stay on the web (don't port)

- **Adaptive Layout, Panel Snap, Plugins Panel+.** Native size classes and the Workspace already do this.
- **Panel Flap, Stack Attack, Game mode.** Fun games, parked.
- **Pip's Brain, Sketch, iPad Check, Dashboard link.** Web tools for Aaron and testers.
- **Eager Pip.** It's now just Joy Slider → Giddy.

## Shortcut worth trying later

Web sandbox B suggests a **Sandbox tab**: a web view in the playground app that runs the web plugins as they are, with a tiny native bridge for tilt and Multipeer. Anything can then be tried on the iPad with no porting, and only the winners get rewritten in Swift.

## Found while combing (for the Mac agent / developer review)

- `main` is older than `from-415`. GitHub opens on `main`, so anyone cloning gets the old app.
- `ContentView.swift` is about 4,000 lines and redraws everything on each change. It's the cause of the slowness.
- `GlassClock/Rebuild/` (about 1,700 lines) is unused. Finish it or delete it.
- About 300 MB of screenshots are in git. Move them to Git LFS or out of the repo.
- There are no tests yet.
