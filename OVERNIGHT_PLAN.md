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
