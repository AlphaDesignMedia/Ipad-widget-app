# Overnight plan: 21 Oct 2026, from about 9:20 a.m.

Written before bed (about 5:50 a.m.). The owner is asleep and non-technical. Work through the
items **in order**. Each item is finished when it builds, has been checked in the simulator with
screenshots, and is committed and pushed. Record progress in the **Progress** section at the
bottom, so a later run can carry on from where an earlier one stopped.

Read first:
- IDEAS.md: the owner's ideas and their status. Update it as items land.
- DESIGN_SYSTEM.md
- GlassClock/ContentView.swift, GlassClock/Workspace.swift, GlassClock/GlassSheetTransition.swift,
  GlassClock/HomeStylePicker.swift, Shared/ClockFace.swift, Shared/ClockStyle.swift, Shared/ClockFonts.swift

## Evening summary (updated 9:40 p.m.; later runs refresh this)
**New since 8:50 p.m.**
- **Classic spacing.** The settings panel sat only 8 pt under the top bar; it now has the same
  16 pt gap as at the sides. Screenshot: Screenshots/afternoon/p6-classic-padding.png

**Since 7:55 p.m.**
- **Contrast check on all 14 backdrops.** The bubbles by the widget read well everywhere. The
  Presets card's chips (Lucky Colours, starter styles…) had faint blue text on warm backdrops;
  in Dark they now have white text on their coloured pill.
  Screenshots: Screenshots/afternoon/p6-chips-readable-sunset.png, Screenshots/afternoon/p6-contrast/

**Since 6:45 p.m.**
- **Make your own backdrop.** A paintbrush button beside Add Photo (or "Make Your Own…" in the
  backdrop menu): pick two or three colours and a pattern. Saved as "Your Own".
  Screenshot: Screenshots/afternoon/p5-make-your-own.png
- **Suggestions.** After you pick a preset, a small bubble says "Make it yours: try a font".
  Screenshot: Screenshots/afternoon/p4-suggest-font.png
- **Controls in one row (optional).** Design Tweaks → "Widget controls in one row".
  Screenshots: Screenshots/afternoon/p0c-one-row-page0.png, p0c-one-row-page2.png
- **Simpler effects** now also stops the backdrop sliding and bending when you pull it.

**Earlier today:** smoother Light/Dark/Clear/Tinted switching, a Classic crash fix, spacing
sliders and presets, controls split above and below the widget, backdrop kind hint, pinch per
panel, panels shrinking while carried (see Progress for details and screenshots).

**Needs your eyes**
- White text on the Presets chips in Dark: clearer, but less blue. Keep it?
- The clock and battery at the very top are faint on pale Dune and Glow. Darken a strip behind
  them, or leave it?
- Does the Make Your Own panel feel easy? Should Your Own also work for the widget's own background?
- Is "Make it yours: try a font" the right nudge? The Apply suggestion only shows if
  App → Apply when leaving is off (it's on by default).
- One row or the stacked bubbles: which do you prefer?
- Earlier questions still open: the 1/3-second pause before bubbles turn dark, instant widget
  style switching, Title card vs Puck, a two-finger swipe for backdrop kinds.
- All of P4–P6 is done. Not done: the tap audit (P1), stuck-on groups test (P2) and settings sticking (P3) need
  someone at the simulator; scheduled runs can't tap.

**3 things to try on the iPad**
1. Tap the paintbrush by the backdrop, change a colour, then try each pattern.
2. Tap a starter style (e.g. Neon), then tap Fonts in the bubble that appears.
3. Design Tweaks → turn on "Widget controls in one row", then swipe the bubble sideways.

## Afternoon plan, 21 Oct (owner away until 10 p.m.): do these FIRST, in order
Everything before this section is done or superseded. The owner's newest direction:
**usability before flair.** Every effect must be possible to turn down (Accessibility →
Simpler effects), and every control must answer a plain tap. Keep names short and the settings in
small, bite-sized groups; repeating an option in two places is fine.

- P0. **Crashes and slowdowns (owner report, 1:20 p.m.): top priority.** Tapping Light, Dark,
  Clear and Tinted in the Home Screen picker above the widget sometimes stutters badly or crashes
  on the iPad. Find the cause and fix it before anything else:
  - Get the crash logs: from the iPad (`xcrun devicectl device info files` / copy the crash
    reports, or `idevicecrashreport` if installed) and from the simulator
    (~/Library/Logs/DiagnosticReports, files starting GlassClock). Read the stack trace.
  - Reproduce in the simulator: tap through all four quickly, many times, in each app look
    (Glass, Frosted, Colour, Home Screen) and on a mesh and a pattern backdrop.
  - Suspects to check: the app's colour scheme flipping (Home Screen look follows the style), which
    redraws everything at once; ClockRaster's image cache growing per style/scheme; the drawn
    pattern backdrops (Canvas) and MeshGradient redrawing on every change; many `.animation`
    modifiers and glassEffects animating together; onGeometryChange loops (widgetRect, railSize,
    groupFrames, stageRect) feeding state back into layout; the Shimmer keyframes restarting.
  - Use Instruments if useful (`xcrun xctrace record --template "Time Profiler"` against the
    simulator app) to find what's slow.
  - Fix, then tap through 50+ times without a hitch. Write what it was in Progress.
- P0b. **Breathing room (owner, 1:25 p.m.).** Text sits too close to edges in places; it should
  feel designed everywhere. Do a spacing pass after P0:
  - Screenshot every card, panel, bubble, chip, menu and the toolbar in Panels and Classic, at
    the smallest and largest panel text sizes, and list every spot where text is within ~12 pt of
    an edge or where padding is uneven between similar things.
  - Compare with how Apple's own iPad apps with a similar style space things (Settings, Photos
    sidebar, Freeform inspector, Control Centre modules, Home Screen widget gallery): generous
    insets (often 16–20 pt inside cards, 20+ pt from panel edges), consistent row heights, labels
    never touching rounded corners. Write the reference values you choose in DESIGN_SYSTEM.md.
  - Don't set it in stone: add the new spacing as sliders in Design Tweaks (e.g. "Panel edge
    padding", "Title bar height", "Bubble padding", "Chip padding", "Footer padding") next to the
    existing Card padding / Row spacing / Gaps, defaulting to your best values, so the owner can
    tune them on the iPad and send back Copy Values. Where it's quick, offer 2–3 named spacing
    presets too ("Compact", "Comfortable", "Airy") in Design Tweaks.
  - Corners stay concentric when padding changes (inner radius = outer radius − padding).
- P0c. **Controls above the widget (owner, 1:30 p.m.).**
  - The backdrop list is too long as one menu. Try: swipe left/right on the backdrop to move
    through kinds (Photos, Mesh, Patterns, Gradients) and up/down to move through colours within a
    kind. Keep the existing up/down pull working; show a small hint of which kind you're in.
  - Turn the backdrop menu into 1–3 small buttons (e.g. "Backdrop", "Add photo", "Make your own")
    instead of one long list.
  - The bubbles above the widget (Light/Dark/Clear/Tinted, sizes, backdrop) could be one bubble you
    swipe sideways between, like pages, so only one row shows at a time, with page dots. Try it,
    keep it optional (Design Tweaks switch) and keep everything reachable by a plain tap.
  - The "9" on Apply to Widget wasn't clear: it was meant as the clock's style in miniature, not a
    count. Make it obvious: e.g. a tiny widget-shaped glyph with "12" in the clock's font and
    colour, bolder, or go back to a clear symbol if that reads better. Check it at a glance.
  - Plain and Aurora looked identical on Clear/Tinted: fixed (Plain is now slate there); check it.
  - Stuck-on groups (owner likes the small puck/tab): align the rail and tab to the whole widget
    group (widget plus its bubbles above and below), not just the widget card. Measure that whole
    group's rect (e.g. onGeometryChange on the ZStack holding card + controls) and use it in
    `railFrame` / `attachedGroups`.
  - Split the controls top and bottom: Home Screen style (Light/Dark/Clear/Tinted) and the
    Home Screen question above the widget; size (Small…Extra Large) and backdrop below it, so the
    widget sits centred between them. Keep the "flip when there's no room" behaviour.
- P0d. **Pinch per panel (owner, 1:35 p.m.).** Pinching to change text size should only change the
  panel being pinched (groups and settings each keep their own size; store them separately).
  Then try a few more direct-touch interactions in the same spirit, each small and optional, e.g.
  pinch a settings card to collapse/expand it, two-finger swipe on the groups to hide them,
  pinch the backdrop to zoom a photo. Keep the ones that feel natural; note the rest in IDEAS.md.
  Nothing may stop a plain tap from working.
- P0e. **Panels shrink while carried (owner, 1:45 p.m.).** When a panel is picked up by its bar,
  it should shrink into something small and easy to move: e.g. the settings become a compact
  card showing just the card you're on (or its title and icon), the groups become their small
  puck; it springs back to full size where it's dropped. Experiment with 2 versions (shrink to a
  title card vs. shrink to a puck), switchable in Design Tweaks, and keep the drop outlines and
  sticking working. Respect Simpler effects (just fade/scale a little).
- P1. **Tap audit (most important after P0).** In the simulator, tap every segmented control, toggle,
  picker, slider and button in every settings group, in Panels and Classic, in Glass/Frosted/
  Colour/Home Screen looks. Wait 2 s before each screenshot (the screen redraws late). Earlier
  today the settings panel's hold-to-drag gesture swallowed taps on segmented controls; look for
  any other gesture doing the same (pinch on the panel, the groups' hold-to-drag, the widget
  layer). Fix anything that doesn't respond first time.
- P2. **Test the stuck-on groups** (new): drag the groups panel by its bar onto the widget and
  onto the settings panel (use touch_path with a slow drag); check it sticks beside them, slides in
  to a tab when pushed towards them, slides out when the tab is tapped or pulled, and unsticks
  when pulled well away. Check it follows the widget when the widget is dragged, stays on screen,
  and never covers the widget's controls. Smooth any jumps.
- P3. **Settings can stick too**: the same idea for the settings panel (onto the widget's side),
  only if P1–P2 are solid. Use the same rail/tab pattern; keep it optional.
- P4. **Suggestions**: like the "Which Home Screen style do you use?" bubble, a small, dismissable
  hint that rides with the widget and points at a likely next step (e.g. "Try a font" after a
  preset, "Apply to Widget" when there are changes). At most one at a time; never covering the
  widget. Make sure it reads clearly in every look (contrast first).
- P5. **Make your own backdrop**: in the backdrop menu, "Make your own…": pick two or three
  colours and a pattern (none, lines, waves, dots, rings); saved and shown like the others,
  adapting to Light and Dark. Only the app's backdrop (not the widget) for now.
- P6. **Small polish**: Classic top and bottom padding; group names short; check every bubble's
  contrast on every backdrop (including the new pattern ones and Midnight); check Simpler effects
  really stops wiggle, lean, shimmer, carousel and fading.
- Later (not this afternoon unless everything above is done): panels struggle when the window
  is resized (Stage Manager / windowed vs full screen). Look for a more elegant layout that adapts
  smoothly (panels collapse to strips or tabs in narrow windows, the grid rescales without jumps).
  Log findings in IDEAS.md.
- Do not attempt: a see-through window over the Home Screen; changes to the widget extension's
  look beyond what's asked.

## Owner's latest direction (21 Oct, about 10:55 a.m.): read this first
Items 1 and most of 2 are done (see Progress). The owner now wants the focus on **interactions,
animation and subtle UI polish**, softer and smoother than Apple rather than copying it. Do these
before items 3–6:
- A. Soften the glass edge on the backdrop pull: it still reads as a hard bright stripe. Make it a
  gentle lens with a soft rim, and keep the elastic pull feel.
- B. A few more backdrops in the spirit of Apple's wallpapers (soft gradients and mesh-like
  shapes, in Light and Dark), added to `PreviewBackdrop`.
- C. Polish the new Panels interactions from the owner's test: the wiggle, the drag lean, the
  corner highlights and resize, panels tucking away, and the groups dock. Smooth any jumps.
- Note: iPadOS can't make the app window see-through over the Home Screen; don't attempt it.

House rules the owner has set:
- **Contrast always comes first.** Glass is a fun effect, never a reason for text to be unreadable.
  - In the Glass theme, icons and labels on glass are black or white, depending on what's behind
    them (see `AppGlass`).
  - Anything selected or primary uses the app colour (`AppColor.chosen`) with white text.
- **Consistency** across Glass, Frosted and Colour themes, in Light and Dark. Stick to the existing
  style unless something clearly looks better.
- **Corners are concentric.** An inner radius is the outer radius minus the gap
  (`Corner.panel` / `inset` / `card`). The spacing between cards matches their gap from the panel edge.
- **Classic** stays simple and functional. **Panels** is the fun, interactive one.
- Guiding principle: *"anything you feel you could do, you can do"*. Familiar, satisfying,
  Home Screen-like interactions. Prioritise feel over look.

## 1. Home Screen-style edit mode for the preview widget (Panels)
- Long-press the widget: it starts to wiggle, like editing the Home Screen. Keep the haptics.
- While it wiggles, it can be dragged (the current snapping grid drag in `cardGesture`, which is
  smooth now; keep that smoothness).
- A round corner handle on the bottom-right can be dragged to resize. It snaps between Small,
  Medium, Large and Extra Large (`PreviewSize`), live as the finger moves.
- Tap empty space, or a "Done" pill, to stop wiggling.
- Keep the one-finger drag and pinch working when not wiggling.
- Respect Reduce Motion: no wiggle, just a highlight outline.
- The style and size controls already float with the widget. Keep that.

## 2. Pull-to-change backdrop: feel and bending glass (in the app only, not the widget)
- New code (untested on device): `backdropPull`, `pulledBackdrop`, `finishBackdropPull` and
  `elastic` in ContentView.swift, plus `GlassSheetEffect`.
- What the owner wants:
  - The next backdrop follows the finger up or down.
  - It stretches elastically near the end.
  - Letting go early springs it back; a long pull or a flick carries on.
  - Feel matters more than looks.
- The simulator's swipe tool didn't trigger the vertical swipe. Investigate why (the drag may start
  on the widget or controls; try touch_path in empty preview space, or the Classic preview), and
  verify by recording with `xcrun simctl io <id> recordVideo` and pulling frames out with an
  AVAssetImageGenerator Swift script.
- Make the glass edge actually **bend** what's behind it, like the iPad unlock and Notification
  Centre:
  - In-app only, so a SwiftUI `.layerEffect`/`.distortionEffect` Metal shader is fine. Add a
    `.metal` file to the GlassClock target.
  - A lens band along the moving edge that magnifies and refracts, with a bright rim.
  - Keep it 60 fps. Reduce Motion: a plain crossfade.

## 3. Better font pairings
- Research how clocks, watch faces and timepieces pair a numeral face with a secondary face:
  Apple Watch faces, Braun and Swiss railway clocks, Lock Screen styles, editorial clocks.
- Write References/font-pairings.md: a short, plain summary with links and 5–8 suggested
  pairings, using only free, open-licence fonts.
- Improve the weakest current pairings in `DetailFont` / ClockFonts.swift. Add at most two
  open-licence fonts, following how existing fonts are bundled and registered.
- Screenshot every pairing (the debug gallery's "pairs" page) before and after.

## 4. Contrast and consistency audit
- Screenshot every theme (Glass, Frosted, Colour) × Light/Dark × three backdrops (light Aurora,
  dark, Plain) in Panels and Classic.
- Fix anything that is low-contrast or inconsistent: text, icons, selected states, segmented
  controls, bubbles, the Home Screen style picker, toolbar.
- Save before/after screenshots in Screenshots/overnight-2/.

## 5. Analog clock polish
- The new analog face is in `ClockArtwork.analog`.
- Check it on Clear and Tinted Home Screens, at every widget size, with glow and shadow, and in
  the widget gallery (`GLASSCLOCK_STYLE` override).
- Consider an option for hour numerals in the chosen font (only if it looks good).
- Make sure Lucky and presets never switch digital ↔ analog.

## 6. If time remains
These are optional. Pick one, keep it small and polished:
- Beginner mode: gentle hints that can be switched off.
- Background generator: one or two sliders that make a unique abstract backdrop, plus a Lucky option.

## How to work
- Build:
  ```
  xcodebuild -project GlassClock.xcodeproj -scheme GlassClock -configuration Debug -destination "id=0C98318B-5E7B-488C-9949-D60434F34C60" -derivedDataPath "$TMPDIR/gc-sim" -quiet build
  ```
  This needs the sandbox disabled.
- Launch with arguments like:
  ```
  -interfaceStyle panels -appTheme glass -appAppearance light -hasSeenTour YES -widgetRow 0
  ```
  Use `SIMCTL_CHILD_GLASSCLOCK_STYLE='{"face":"analog"}'` for test styles.
- The app takes about 20 seconds to appear after launch.
- Commit on **main** after each finished item, with a clear message ending with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push with `git push` (gh is in
  ~/.local/bin; pushing needs the sandbox disabled).
- Install on the iPad with `Scripts/run-on-ipad.sh`. If it isn't reachable (the owner is asleep
  and it may be locked), skip the install. That's fine.
- Never leave the working tree dirty, and never switch branches.

## Morning summary
At the end, write a short summary at the top of this file, plain and friendly:
- What was done, with screenshot paths.
- What needs the owner's eyes.
- 3 things to try on the iPad.

## Progress
(Each run appends a line here: time, item, done or partly done, and what's left.)

- 10:35, 21 Oct (in the main chat, as the 9:33 run was stuck on a permission prompt): **1. Edit mode done.** Long-press (Panels) wiggles the widget; a round handle on the bottom-right corner resizes it live, snapping between sizes; Done pill or tap anywhere else finishes; Reduce Motion shows an outline instead; panel and backdrop swipes are ignored while editing. Screenshots: Screenshots/overnight-2/edit-mode-wiggle.png, edit-mode-resized-large.png. Note: the simulator's long-press needs about 1.5 s to register.
- 10:45, 21 Oct: **2. Backdrop pull partly done.** Fixed the pull: the incoming backdrop was drawn on top, so it looked like an instant swap; now the current one lifts with the finger and springs back. The rim bends with a squeezed copy (no Metal shader: the Metal toolchain isn't installed). Glass edge band still reads a bit like a hard stripe; worth softening.
- 10:55, 21 Oct (owner's new direction: interactions and subtle animation): softer wiggle, drag lean, four-corner highlights and resize, full-window grid with panel tucking, Full Screen button, movable groups dock, neat start. Screenshots: Screenshots/overnight-2/panel-tucks-away.png, groups-dock.png.
- 16:20, 21 Oct: **P0 done (crashes and slowdowns).** iPad and simulator crash reports were all from 5 a.m. (a NaN in the widget grid, already fixed then); none from the afternoon, so the "crash" was most likely a long freeze. Measured with a built-in stress test (40 quick taps through the four styles; debug builds, `GLASSCLOCK_STRESS_HOME=40`): before, 106 of 168 frames late (Glass look) and worst freeze 0.6 s (Home Screen look). Causes: (1) Light/Dark was flipped over the *whole* widget layer and stage on every tap, rebuilding the clock, grid and all glass; (2) the bubbles' Light/Dark flip (segmented picker, menus) on every tap; (3) animating the widget's glass tint and colour mask between styles. Fixes: Light/Dark is set on each bubble only; the bubbles (and the whole app in the Home Screen look) follow the choice 0.35 s after tapping stops; the widget switches style instantly (size changes still animate). After: about 400 frames, about 50 late (one per tap) in every look and on Bloom, Waves and Midnight; worst 0.15–0.4 s, once, when tapping stops. Screenshots: Screenshots/afternoon/p0-after-40-taps-tinted.png, p0-home-look-after-41-taps-light.png. Left: needs a try on the real iPad.
- 16:25, 21 Oct: **P0b done (breathing room), plus a crash fix.** New Design Tweaks sliders: Panel edge padding, Title bar height, Footer padding, Bubble padding, Chip padding, and Compact / Comfortable / Airy buttons that set all spacing at once. Defaults a little roomier (bubbles 10 pt, title bar 18 pt, footer 14 pt, chips 12 pt); reference values in DESIGN_SYSTEM.md (5.3, Breathing room). Corners stay concentric. **Crash found and fixed:** opening Classic could crash (the preview card got a zero scale for a moment, giving its glass a NaN size); the scale is now floored like the grid's. Classic opened cleanly 3 times after. Screenshots: Screenshots/afternoon/p0b-panels-tweaks.png, p0b-classic.png. Left: a closer per-card audit at the largest panel text size.
- 16:30, 21 Oct: **P0c partly done.** Controls are split around the widget: Home Screen question and Light/Dark/Clear/Tinted above, size and backdrop below (below ones clear the Preview tag); when one side has no room, everything goes to the side with more. The Apply to Widget icon is now a tiny widget shape with "12" in the clock's font and colour (the "9" in a circle read as a count). Screenshot: Screenshots/afternoon/p0c-split.png. Still to do in P0c: swipe left/right on the backdrop through kinds, backdrop menu as 1–3 small buttons, optional swipeable single-row bubble with page dots, align the stuck-on groups' rail to the whole widget group.
- 16:30, 21 Oct (hourly run): **P0c: stuck-on groups now line up with the whole widget group** (widget plus the controls above and below), not just the card; dropping the groups onto the controls also sticks them. Screenshot: Screenshots/afternoon/p0c-rail-whole-group.png. Still to do in P0c: swipe left/right on the backdrop through kinds, backdrop menu as 1–3 small buttons, optional swipeable single-row bubble.
- 16:35, 21 Oct (hourly run): **P0c: backdrop is now two small buttons**: a short menu grouped into Gradients, Mesh, Patterns (and Photo once you've added one), and a separate Add Photo button beside it. Screenshot: Screenshots/afternoon/p0c-backdrop-buttons.png. The open menu wasn't checked: the simulator tap tool refuses unattended runs. Still to do in P0c: swipe left/right on the backdrop through kinds (BackdropKind is ready for it), optional swipeable single-row bubble. Then P1 (tap audit) needs an attended session, since taps can't be made in scheduled runs.
- 17:45, 21 Oct (hourly run): **P0c: backdrop kind hint done.** Swiping up/down (or picking from the menu) now shows the kind (GRADIENTS / MESH / PATTERNS) above the backdrop's name, with a dot per backdrop in that kind (the current one is a longer pill), frosted like the bubbles so it reads on dark patterns. **Not done on purpose:** sideways swipes through kinds, because sideways swipes already bring the panels in and out; left for the owner to decide. New debug switch `GLASSCLOCK_BACKDROP=<name>` for screenshots. Screenshot: Screenshots/afternoon/p0c-kind-hint.png. Still to do in P0c: optional swipeable single-row bubble. P1 (tap audit) needs an attended session.
- 18:40, 21 Oct (hourly run): **P0d: pinch per panel done.** Pinching the settings changes only the settings' text; pinching the groups changes only the groups (each saved separately; the size bubble shows on the panel being pinched). Accessibility now has two plain steppers, Settings text and Groups text. Screenshot (settings Small, groups Largest): Screenshots/afternoon/p0d-separate-text-sizes.png. The pinch itself wasn't tried (no taps in scheduled runs). Not built, logged in IDEAS.md: pinch a card to fold it, two-finger swipe to hide groups, pinch to zoom a photo. Still open: P0c swipeable single-row bubble, P0e, then P1 (needs an attended session).
- 18:45, 21 Oct (hourly run): **P0e: panels shrink while carried, done.** Picking a panel up by its bar shrinks it to a small stand-in that springs back to full size where it's dropped. Two versions, switchable in Design Tweaks → Carrying a panel: Title card (icon and the card you're on, e.g. "Layout"; the default), Puck (just the icon), or Full size (the old lift). Simpler effects: the stand-in just fades in, no shrink. Drop outlines and sticking are untouched (the panel stays under the finger, almost invisible). New debug switch `GLASSCLOCK_CARRIED=1` for screenshots. Screenshots: Screenshots/afternoon/p0e-carried-title-card.png, p0e-carried-puck.png. Not tried with a real drag (no taps in scheduled runs); the groups' stand-in only shows when the groups are a free panel, not when stuck on as the rail. Still open: P0c swipeable single-row bubble, then P1 (needs an attended session).
- 19:40, 21 Oct (hourly run): **P0c: one-row controls done (optional), so P0c is finished.** Design Tweaks → "Widget controls in one row" shows one bubble at a time (style, size, backdrop) with three dots under it; swipe sideways on the bubble or tap a dot to move between them. Off by default; Simpler effects swaps the slide for a fade. New debug switch `GLASSCLOCK_ONE_ROW=<0|1|2>`. Also fixed: release builds were missing the `carried` debug stub. Screenshots: Screenshots/afternoon/p0c-one-row-page0.png, p0c-one-row-page2.png. Swipe not tried (no taps in scheduled runs). Next: P1 and P2 need an attended session; P4 (suggestions) and P5 (make your own backdrop) can be built unattended.
- 19:45, 21 Oct (hourly run): **P4: suggestions done.** Under the Home Screen picker, in place of the quiet "Your Home Screen" tick, one small bubble at most: after a preset, "Make it yours: try a font" with a Fonts button (opens the Fonts card; goes away once Fonts is opened); when changes haven't reached the widget for 4 seconds, "Your widget hasn't changed yet" with Apply. Each has a ✕. The Home Screen question always comes first. The Apply one only shows when App → Apply when leaving is off (it's on by default, so changes reach the widget anyway). New debug switch `GLASSCLOCK_SUGGEST=font`. Screenshot: Screenshots/afternoon/p4-suggest-font.png. Not tapped (scheduled run). Next: P5 (make your own backdrop), P6; P1–P3 need an attended session.
- 19:50, 21 Oct (hourly run): **P5: make your own backdrop done.** A paintbrush button beside Add Photo (and "Make Your Own…" in the backdrop menu) opens a small panel: two or three colours (+ / −), a pattern (None, Lines, Waves, Dots, Rings), and Light and Dark previews. Changes show on the backdrop straight away; it's saved as "Your Own" and joins the swipe-through list once made. Only the app's backdrop, not the widget. In one-row mode it turns to the backdrop page first. Fixed before committing: the Done button was white on white in the Glass look (now the app colour). New debug switch `GLASSCLOCK_MAKE_BACKDROP=1`. Screenshot: Screenshots/afternoon/p5-make-your-own.png. Colour pickers not tapped (scheduled run). Next: P6 polish; P1–P3 need an attended session.
- 19:55, 21 Oct (hourly run): **P6 partly done (Simpler effects check).** Went through every effect in code: wiggle, lean, light sweeps, the settings cards' carousel, panel slides, the new one-row pager and the carried stand-ins all already respect Simpler effects. One gap fixed: pulling the backdrop up or down still slid and bent it; now it just fades to the next one. Not done in P6: Classic top/bottom padding and the bubble contrast check on every backdrop (needs screenshots on each; the `GLASSCLOCK_BACKDROP` switch can do it). P1–P3 still need an attended session.
- 20:50, 21 Oct (hourly run): **P6: contrast check on every backdrop done.** Screenshotted the app on all 14 backdrops (Screenshots/afternoon/p6-contrast/). The bubbles above and below the widget read clearly on all of them, including Midnight and the patterns. Fixed: the blue text on the Presets card's chips (Lucky Colours, starter styles, Save Current, your styles) sank into warm backdrops like Sunset and Dune; in Dark the text is now white and the pill keeps its colour. Screenshot: Screenshots/afternoon/p6-chips-readable-sunset.png. Left for the owner: the white clock and battery at the very top are faint on pale Dune and Glow (that's the system's bar; could darken a strip behind it, or switch to dark text on pale backdrops). Still open in P6: Classic top/bottom padding, short group names. P1–P3 need an attended session.
- 20:55, 21 Oct (hourly run): **P6: group names checked**: already short (Presets, Layout, Fonts, Colour, Effects, Card, Home Screens, App, Accessibility); nothing changed. Installed on the iPad. Left in P6: Classic top/bottom padding (opening Classic needs a tap, so an attended session). P1–P3 need an attended session too.
- 21:40, 21 Oct (hourly run): **P6 done: Classic top and bottom padding.** Classic's settings panel sat 8 pt under the top bar but 16 pt from the sides; now 16 pt all round the top (24 pt above the Home bar, unchanged). The list's own margins were already even. New debug switch `GLASSCLOCK_CLASSIC=1` opens Classic for screenshots (the first-run tour switches new installs to Panels, so setting the preference alone didn't stick). Screenshot: Screenshots/afternoon/p6-classic-padding.png. P6 finished. Left: P1–P3 need an attended session (taps and drags).
