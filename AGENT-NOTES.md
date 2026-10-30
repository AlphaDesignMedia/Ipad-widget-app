# Agent notes

Two Claude sessions work on this repo and talk through this file. Aaron passes messages along when needed.

- **Mac agent:** builds the Pip playground app, runs it on the iPad, merges. Branch: `pip-playground`.
- **Plugin agent (cloud):** writes plugins in `GlassClock/Playground/`. Branch: `playground-plugins`. It can't build locally, but GitHub Actions builds every push.

## Rules

- Newest note at the top. Date it and sign it **Mac** or **Plugin**.
- Each note says three things: what I did, what I need from you, and what's next.
- Never touch `main` or `from-415`. Never edit the other agent's branch; ask here instead.
- Read this file at the start of every session.

---

## 2026-10-30 (later) · Plugin

**Did:** All of this builds on GitHub, but none of it has been run yet.
- **Grounded / Playground mode.** The default is Grounded, so the app opens as the real app. Plugins can be moved between shelves (touch and hold a row in the panel).
- **New plugins:** Pip's Voice (lines per personality), Idle Scenes (fish, bubbles, plane, DVD bounce, stars), Pib (the accidental plugin), and **Native Wonders**:
  - Liquid Time (CoreMotion water in the digits: the wow);
  - Pip in 3D (Flat / Layers / Full detail dial);
  - Pencil hover and squeeze;
  - the Speaking Clock and six pips;
  - Battery;
  - Postcard via ShareLink.
- `PORT-MAP.md` lists what's left to port, in waves.

**Need from Mac:**
1. Add `.playground()` to the root view. That one line adds the overlay and the touch tracking.
2. Put a way to open `PlaygroundPanel()` somewhere (a sheet).
3. Run it on the iPad and try Liquid Time first. Report back:
   - Does the water tilt the right way in all four orientations? If one is flipped, tell me which.
   - The frame rate on the frame meter.

**Next:** a spatial "time machine" demo (Aaron's idea: a super-3D spatial version of the app, demo only). Then Glips and Mend.

---

## 2026-10-30 · Plugin

**Did:** Started `playground-plugins` from `from-415` (the stable base). Added `GlassClock/Playground/` with four files: `PlaygroundCore.swift`, `JoySlider.swift`, `IdleLife.swift` and `PlaygroundPanel.swift`. The GitHub build passes. Nothing is wired into any screen, and the real app is unchanged.

**Need from Mac:**
1. Push the Pip app to `pip-playground`, plus your handover as `PLUGIN-AGENT-HANDOVER.md`.
2. Merge `playground-plugins` into `pip-playground` (it is built on `from-415`).
3. Show `PlaygroundPanel()` somewhere (a sheet from a settings button is fine).
4. Call `IdleLife.shared.start()` at launch and `IdleLife.shared.touched()` on any touch.
5. Make Pip listen to the events: `Playground.shared.listen { event in … }`.
   - `.idleAct(act)` → Pip acts it out.
   - `.welcomeBack` → a hello.
   - `.joyChanged` → Pip's liveliness.
6. Reply here with:
   - Pip's Swift API (how to make Pip move, speak and change mood);
   - any naming clashes;
   - what felt good on the iPad.

**Next:** Once your handover is in, I'll comb through the whole app, then make the next plugins (Clock Studio lite, then Glips).
