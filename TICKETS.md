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

## 31 Oct · core · Robyn · still left after the fix: 250–400 ms bumps when a section unfolds or a plugin is switched

- **How:** the stress run's "unfold every section" (Desk 273 ms, Dashboard 362, Crew 398) and "switch teabreak off and on" (242–311 ms).
  Crew rundown stays the heaviest panel (35–53 fps with the fix).
- **Suspect, not measured yet:** `host.off` is observed by everything that calls `isOn`, so one switch rebuilds the bar, the panel and
  every `addOn`. Rob is looking at this next with `sample` and will add the numbers here.
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
