# Tickets

Problems found on the Mac, newest at the top. **Plugin** tickets are for Jules (fixed on `pip-plugins`).
**Core** tickets are for Robyn (Pip, host, plugin bar, panels, top bar). Each says: date, plugin id, what Aaron
saw, how to make it happen, log lines or numbers, and what was parked. Rob keeps this file.

**How to measure (simulator):** build, then launch with
`xcrun simctl launch <sim> com.aarondennel.pipsandbox -hasSeenTour YES -plugsOpen NO -plugsPaused NO -frameMeter YES -stressMenus YES`.
About a minute later the numbers are in the app's `Documents/Diagnostics/stress-<time>.txt` (and the log, category `stress`).
`-holdMenu dashboard` just opens a menu and leaves it, for `sample <pid> 5` or Instruments. `-plugsOff '(liquid)'` starts
with plugins switched off. Simulator numbers run on the Mac's chip: compare before with after, not with the iPad.

---

## 31 Oct · Tess's first run · 6 red, no crashes, no hangs (full table in `TESTS.md`)

- **Core · Robyn · the four side panels are the four worst:** Sketch 43 late frames, Dashboard 33, Crew rundown 28, Stationery
  Cupboard 26, against 1–9 for every pop-up card. Those are exactly the plugins with `panel: true`, so the cost is opening a
  `PluginPanel`, not the plugins. Re-run Tess after the `PerFrame` fix (top ticket below) before blaming anything else.
  Job H (every card a panel) would make this matter for every plugin, so it's worth settling first. Parked: nothing.
- **Plugin · `looks` · Jules · Pip Looks: 19 late frames, worst 850 ms** when its card opens. That's close to a freeze. Suspect: switching
  Pip's look rebuilds Pip (or the bar) in one go. How: `./tools/tess.sh`, or `-holdMenu looks` then `sample <pid> 5`.
  Not parked yet (it isn't a crash or a hang over 1 s). Rob will sample it.
- **Plugin · `bond` · Jules · Pip's Bond: 15 late frames** (worst 115 ms), flipping its 2 switches. Mild. Not parked.
- **Tess can't see everything:** most cards show "0 switches flipped". Their toggles aren't UIKit switches she can find, so only the
  open and scroll were tested there.

## 31 Oct · core · Robyn · Pip's layer redraws the plugin bar and every overlay about 60 times a second

- **What Aaron saw:** the developer menus stutter and freeze; Pause all made everything smooth.
- **Cause:** in `PipLayer.body` (`Pieces/Pip.swift`), `pipView` and `bubble` read `pip.hop`, `lean`, `squash` and `pos`
  inside the layer's own body. Pip's Weight changes `hop` every frame while Pip bobs, so the whole layer re-runs, and with it
  `PluginBar` (40 buttons, each a Liquid Icons glass drop) and every plugin's overlay. In a 5 s `sample` with nothing open, the main
  thread was busy the whole time, and `AppGlass.body`, `PluginBar.button`, `LiquidIcons.Drop.body` and `PipsWeight.tick` were
  the top app frames. The app used ~96% of a core sitting still. With plugins paused it used 6%.
- **Fix (tested, not committed, because `Pieces/` is yours):** read the per-frame values in their own small view, so only Pip redraws:

```swift
/// Reads inside here are tracked by this view, not the layer, so Pip's bob redraws only Pip.
private struct PerFrame<C: View>: View {
    @ViewBuilder let content: () -> C
    var body: some View { content() }
}
// in PipLayer.body:
if pip.shown { PerFrame { pipView } }
if pipOn, let line = pip.bubble, pip.shown { PerFrame { bubble(line, size: geo.size) } }
```

- **Numbers** (iPad Pro 13" simulator, stress run, fps · late frames · worst ms):

| step | before | after |
|---|---|---|
| nothing open | 18 · 18 · 183 (just after launch) | 60 · 1 · 129 |
| Dashboard open | 48 · 15 · 219 | 58 · 3 · 164 |
| Dashboard scroll | 6 · 17 · 234 | 60 · 0 · 0 |
| Dashboard switch a plugin ×6 | 8 · 18 · 249 | 60 · 6 · 311 |
| Crew open | 12 · 13 · 382 | 51 · 6 · 255 |
| Crew scroll | 10 · 20 · 243 | 44 · 11 · 50 |
| Crew switch a plugin ×6 | 11 · 25 · 796 | 35 · 27 · 295 |

- **Parked:** nothing. This one's core.

## 31 Oct · core · Robyn · still left after the fix: 250–400 ms bumps when a section unfolds

- **How:** the stress run's "unfold every section" (Desk 273 ms, Dashboard 362, Crew 398).
- **Measured, and it's not `host.off`** (Rob was wrong to suspect it): with Crew held open, flipping Tea Break off and on 10 times
  in 5 s (`-holdMenu crew -flipLoop teabreak`, `sample <pid> 5`) took the main thread from 35% busy to 36%, about **7 ms a switch**.
  Most of that 35% is Pip's bob redrawing the bar (the `PerFrame` ticket below).
- **Suspect now, not measured:** a `DevFold` builds all its rows the moment it opens, inside a `withAnimation(.snappy)`, so a long list
  (Plugin Desk's 40 rows, Crew's sections) lays out in one frame. Worth a `LazyVStack` for long lists, or opening without the animation.
  One more lead: in the flip sample `ClockFace`/`ClockArtwork` rebuilt once (28 ms). It might be the minute ticking over, so not proven.
- **Parked:** nothing.

## 31 Oct · plugin · liquid · Jules · Liquid Icons costs a lot of the processor even when nothing moves

- **What Aaron saw:** menus run slow (the same report as above).
- **How:** idle CPU in the simulator, 8 s windows, nothing open. Before the core fix: all on ~96–101%, Liquid Icons off ~57%.
  **With** the core fix: all on 17–62%, Liquid Icons off 11–12%, everything paused 6%.
- **Why, from the code:** every bar button is a `Drop` with its own `.appGlass(.circle, interactive: true)` inside one
  `GlassEffectContainer`: ~40 live, interactive glass shapes that are always on screen, plus the settings rail when "Whole app" is on.
- **Ideas:** one glass shape for the bar with plain icons on it, and the drop look only on the open button; or `interactive: false`;
  or "Whole app" off by default.
- **Parked:** `LiquidIcons()` in `Plugins.swift` on `pip-plugins`.
- **Watch out:** `LooksTimeMachine.swift:42` calls `LiquidIcons.apply(host)` whenever a look has `liquid` set, and the host's
  `activeBarLook` only checks `chosen("liquid")`, which is true for a parked plugin. So a look can bring the drops back while parked.
  Guard it with `host.isOn("liquid")`, as line 72 does.

## 31 Oct · plugin · flags · Jules · Pip's flags never shows anywhere

- **What Aaron saw:** asked to profile "the Flags panel".
- **Cause:** `PipFlags` has `addsTo: "desk"`, but Plugin Desk is a pop-up card (`panel: false`), and only `PluginPanel` shows other
  plugins' sections. So the Flags card is never built. Job H (every plugin card opens as a panel) would make it appear, under "More".
- **Parked:** nothing (it costs nothing while hidden).
