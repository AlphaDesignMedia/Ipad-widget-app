# Overnight plan — 21 Oct 2026, starting 4 a.m.

Done before bed (21 Oct, ~12:30 a.m.):
- Classic is a fixed glass settings panel over the full-window backdrop (no jittery divider).
- Panels: sidebar tucks away in portrait; tapping a group opens its settings; settings title switches groups.
- A four-card, skippable first-launch tour ("Show the tour" in Widget settings brings it back).
- First swipe gestures in Panels: swipe right across the preview for the groups list, swipe left for settings.

Also done before bed (~12:45 a.m.), owner's direction:
- Panels' right panel is now ONE scrolling list of every setting (like Classic, all open). The left
  sidebar is just quick navigation: tapping a group glides the list to it and lights it up
  (`focus(_:)`, `settingsList`, `focusRequest`, `highlighted` in ContentView.swift). When the
  sidebar is tucked away, glass jump chips sit at the top of the list. Keep this model.
- Swipe: the preview leans with your finger (rubber band, springs back) and glass edge tabs
  show where a hidden panel lives; light haptics on open/close.
- Tour rebuilt as animated, annotated mini-scenes of the app (Onboarding.swift), with an
  "I don't want a fancy layout" button that switches to Classic. Finishing the tour lands in Panels.

Also done (~1 a.m.), owner loved the focus/jump and gestures — "lean further into the gestures":
- Panels are now custom floating glass panels (no system sidebar/inspector, no sidebar toggle
  buttons). Question-mark button in the top bar reopens the tour.
- Pinch the clock card: it follows the fingers, then settles on the next widget size up/down.
- Pinch the settings panel: text and rows get bigger/smaller in steps (experiment; owner may not
  keep it). Stored as "settingsTextSize".
- Tap the clock (Panels) jumps to Fonts. Swipe up/down on the preview flicks through backdrops.
- Owner: hold off on the photo backdrop work for now.

## NEW TOP PRIORITY (owner, ~1:10 a.m.) — the widget on the real Home Screen

Do this BEFORE item 1 below. The owner reports, on the iPad (iPadOS 27, they use Tinted/Clear):

A. **Default/Dark vs Clear/Tinted look like two different clock styles.** In full-colour mode
   `ClockFace` draws `LightLayer` + the full text style (glow, inner colour, shadow, dark edge);
   in accented mode it switches to the transparency-only glass recipe (`textStyle(accented: true)`,
   no light layer). The owner wants ONE look across all four. Direction: design a single glass
   recipe that reads the same in both — e.g. build the full-colour glass from the same layers as
   the accented one (frosted body + rim + soft inner glow), with the person's colour applied as
   a tint on top in full-colour mode (and via the kept-colour swatch in accented mode when
   "keep colours" is on). Make the in-app Light/Dark/Clear/Tinted preview show the same thing.
   Put a side-by-side of all four in Screenshots/overnight (StyleGallery can render pages).
B. **"Keep colours" has regressed to plain system glass** — kept parts show as solid shapes on
   the regular system glass, not the person's colours. No widget code changed since commit
   e96863c (only app UI changed tonight), so first check: (1) the keep settings actually reach
   the widget after Apply (free-team builds share settings through the keychain — see
   Config/FreeTeam.entitlements and how ClockStyle.load() reads them); (2) the timeline isn't
   being rejected (simulator: `xcrun simctl spawn booted log show --predicate 'process == "chronod"'`
   for "too large timeline archive" / "Watchdog provision violated") with the owner's current
   style; (3) the many reinstalls tonight — a reinstall may leave the Home Screen widget on an
   old archive until its next reload. Read DESIGN_SYSTEM.md §"Keeping colours" first: it lists
   what already failed on iPadOS 27 (ImageRenderer images = blank widget; masked swatches get
   recoloured; only swatches CLIPPED to a vector outline keep colour). Don't reintroduce those.
   The simulator is iPadOS 26.5 and does NOT show kept colours on Clear; Tinted is the better
   simulator check. You cannot see the iPad: install it, and in the Morning summary give the
   owner a 3-step Home Screen test (which style to set, what they should see).
C. **Glass effect styles (plan + try one).** The owner loved a look where the glass edge bends
   the clock and text around it (a lens/refraction rim). Explore new card/text "glass styles":
   a lensing rim (offset/scaled copy of the digits visible through a thick rim), a prism edge
   with a faint colour split, and — in the app preview only, since widgets can't animate —
   a highlight that moves with the iPad's tilt (CoreMotion, respect Reduce Motion). Widgets
   can't sample the wallpaper or run glassEffect, so widget versions must be drawn. Add the
   best one as a new option and write the others up as a short plan in the Morning summary.

D. **Background generator (owner idea, ~1:20 a.m.; do after A–C, only if time — otherwise
   write a short design for the morning).** A generated abstract "light sculpture" behind the
   clock, in the spirit of light passing through glass (think Apple's "Air" artwork — make
   something original, not a copy). Keep it simple: a random seed plus ONE or TWO sliders
   (e.g. "Flow" for how swirly/complex, "Glow" for how soft/bright) and a palette from the
   clock's colours. I'm Feeling Lucky rerolls the seed. In the app it can be a live SwiftUI
   shader / MeshGradient. In the widget it must be a still image made ONCE per style (never per
   minute — archive limit), drawn with Core Graphics/Core Image like ClockRaster (ImageRenderer
   left widgets blank on iPadOS 27), used as the card background in full-colour mode; on
   Clear/Tinted it only shows if kept as `.fullColor` and clipped (see B).

## Tonight's work (in order)

1. **Panels as the fun, interactive mode** (the big one — "really cook on this").
   Classic stays the quick, functional mode; Panels becomes the playful one.
   - Panels slide in with your finger: a live, rubber-banded drag from the left and right
     edges that follows the finger and springs open or closed, instead of jumping.
   - Grab handles: small glass pills on each edge showing where a panel lives.
   - Tapping a part of the clock opens the matching settings (tap the time → Fonts,
     the AM/PM or date → Fonts' detail group, the card → Card, the glow → Effects).
   - (Done: scroll-to-and-highlight. Tap-a-part-of-the-clock should call `focus(section)`.)
   - Polish the tour scenes if anything looks off; keep it skippable.
   - Pinch the preview to switch widget size; swipe up/down on it to cycle backdrops.
   - Haptics on open/close; respects Reduce Motion (fades instead of slides).
2. **Apple-style backdrops**: original mesh-gradient wallpapers in the spirit of iPadOS
   (not Apple's own images), and default the preview to one.
3. **Two more fonts with pairings** (open-licence, e.g. Fraunces and Bricolage Grotesque).
4. **Themed I'm Feeling Lucky**: named themes (e.g. "Midnight Neon", "Sunday Paper")
   that set fonts, colours, effects and a matching backdrop, with the theme name shown.
5. Screenshots of both interfaces, update DESIGN_SYSTEM.md, save to GitHub, install on the iPad.

## Waiting for you in the morning
- Try the gestures on the iPad and say what feels good or fiddly.
- Earth photo backdrop: save that image to Downloads so it can be added.
- Figma design system: still to finish (components, screens).
