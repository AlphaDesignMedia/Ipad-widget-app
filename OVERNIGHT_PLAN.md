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
