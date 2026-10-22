# Glass Clock — The Plan

This is the one place to look. Older notes (OVERNIGHT_PLAN.md, IDEAS.md) are history and a backlog.
Ticks show what's done. Scheduled runs work top to bottom and tick things off here.

## The rebuild (decided 22 Oct) — start here

## Latest run (22 Oct, midday)
- Done: step 5 (Panels) is written. Switch to Panels: the groups are a glass pill of icons on one side and the settings a column of cards on the other. Hold a card's title (or the pill) briefly to pick it up and carry it; flick it to its edge to put it aside; double-tap the widget area to clear both away. Not ticked until it's tried on the iPad.
- Not installed on the iPad: it was paired but not connected again ("No connected iPad found"). Plug it in and run the command below.
- Try on the iPad (`Scripts/run-on-ipad.sh --rebuild`, then tap Panels):
  1. Tap an icon in the groups pill, then run your finger down the pill: the settings should scroll to each group as you go.
  2. Hold the "Presets" title until it lifts, drag it across to the left and let go: the settings should move to the left. Does the hold feel quick enough?
  3. Flick the settings towards the right edge: they should slide away and leave a tab. Tap the tab to bring them back. Then double-tap the widget area twice.

## Earlier run (22 Oct, 11 a.m.)
- Done: step 4 (Classic) is written. A Classic / Panels switch sits at the top. Classic shows just the basics (presets, the font and its weight, the colour) and a "More options in Panels" card at the end of the list; Panels shows every group (step 5 turns it into real panels). Your choice is remembered. Not ticked until it's tried on the iPad.
- Not installed on the iPad: it was paired but not connected again ("No connected iPad found"). Plug it in and run the command below.
- Try on the iPad (`Scripts/run-on-ipad.sh --rebuild`):
  1. Tap Classic, then Panels, at the top: the settings should swap smoothly and the widget shouldn't move.
  2. In Classic, scroll to the bottom and tap "More options in Panels": it should switch to Panels.
  3. Change the font in Classic, switch to Panels: the same font should show there, and Apply to Widget should still be lit.

## Earlier run (22 Oct, 10 a.m.)
- Done: step 3 is written. Every group's settings (Presets, Layout, Fonts, Colour, Effects, Card, Home Screens, Accessibility) are now cards of clear glass in one scrolling list beside the widget, with Apply to Widget held at the bottom. On a narrow screen the list sits under the widget. Steps 1 to 3 stay unticked until they've been tried on the iPad.
- Not installed on the iPad: it was paired but not connected ("No connected iPad found"). Plug it in and run the command below.
- Try on the iPad (open it with `Scripts/run-on-ipad.sh --rebuild`):
  1. Scroll the settings and change a few things (a font, a colour, I'm Feeling Lucky): the widget should change at once, and the button at the bottom should turn from "Applied" to "Apply to Widget".
  2. Tap Apply to Widget: it should tap back, say "Applied", and your Home Screen widget should update.
  3. Turn on Reduce glass in the Accessibility card: the cards should become solid. Is the text easy to read on your backdrop in both Light and Dark?

**Why.** In one day the main screen grew from 914 lines to 3,483 lines, all in one file (`ContentView.swift`), with 113 pieces of state. Every change anywhere redraws that whole screen, which is where the lag comes from. Many features also have two or three versions behind switches, so every fix has to work in all of them, which is where most of the bugs come from. Patching this won't get the smoothness back, so we rebuild the app's screens and keep the parts that work.

**What it is (v1):** a glass clock widget you design on your iPad or iPhone and see at real size on a Home Screen before it goes on yours. Anything that doesn't serve that sentence waits for v1.1.

**Sizes and devices:** iPad (all sizes, both orientations, Split View) and iPhone. Panels is the layout when there's room (a full-width iPad). Classic is the layout when there isn't (iPhone, narrow iPad windows). That's why both stay: they're the same pieces in two arrangements, not two apps. The test iPad is an M1 iPad Pro 12.9-inch. Each step also gets a quick look on an iPhone and a small iPad in the Simulator.

**The look (owner, 22 Oct):** making it look really nice matters more than anything. Lean into Liquid Glass and good gestures. The window touches (title bars, bands, panels behaving like windows) went too far: fewer of them, more glass. The focus effect on the card in use should be a lot nicer and more thought out. That's the job of step 7.

**Principles (owner, 22 Oct):**
- **The app is about what it does:** design a clock and see it truly before it goes on your Home Screen. The UI serves that and gets out of the way.
- **Beautiful and easy to understand, for everyone.** Accessibility is part of the design from the start (VoiceOver, Dynamic Type, Reduce Motion, contrast), not a later pass.
- **Small, cheap animations that explain things.** For example, tapping the Preview tag lifts out the extra controls, and things float gently above the backdrop. They should look lovely and cost almost nothing.
- **Give yourself credit:** the core idea and feel already work. The job now is refining, not starting again.

**What you decided:**
- Rebuild the app's screens on a fresh branch. The widget, clock faces, fonts and backdrops stay as they are. The current app stays untouched until the new one is better.
- Keep both Classic and Panels, built from the same pieces.
- Day-to-day tweaks happen in Claude Code on the Mac, which builds and installs on the iPad after every reply. Cloud sessions are for planning and bigger chunks.
- The Simulator (the one Claude drives on the Mac) is for quick looks at layout. The iPad has the final say.

### The Foundation build (to use while the rebuild goes on)
The app as it is today, with every core feature and the feel you liked (Panels, the glass style, dragging, pinching, hold-to-resize, the groups pill), and the playground switched off: no groups sticking onto things, no carousel squash, no one-row controls, no suggestion bubbles, no title card or puck while carrying, and no wiggle. It's the default when the app opens. `Scripts/run-on-ipad.sh --playground` brings the experiments back (`GlassClock/Essentials.swift`).

### Why the Simulator doesn't match the iPad (and the fix)
The "emulator" is the iPad Simulator that Claude Code runs on the Mac and takes screenshots of. It differs from your iPad in five ways:
1. **Older iPadOS.** The Simulator has been on iPadOS 26.5, but the iPad runs iPadOS 27. Liquid Glass, widgets and Clear/Tinted all changed in 27. DESIGN_SYSTEM.md already records things that worked in the Simulator and broke on the iPad.
   *Fix:* in Xcode → Settings → Components, install the iPadOS 27 Simulator. `Scripts/run-in-simulator.sh` then always uses the newest iPadOS.
2. **Different iPad.** The Simulator uses whatever model was picked, and a different screen size moves everything around.
   *Fix:* the script picks the same model as your iPad. Set it once in the script (`SIM_MODEL`).
3. **Different saved settings.** The Simulator keeps its own copy of the app's settings (Design Tweaks, panel sides, theme, glass amount), so it can be showing a different app from the iPad.
   *Fix:* in the rebuild, design values live in `Theme.swift`, so both start the same. For checks, the script starts the app from a clean install (`--fresh`).
4. **Feel.** The Simulator is driven by a mouse and runs on the Mac's chip: pinches are fake, and there's no 120 Hz, no haptics, and nothing on frame rate. *Rule:* the Simulator is for layout and looks. Gestures, smoothness and glass over a real backdrop get checked on the iPad, always.
5. **Widgets.** Widget updates on the Home Screen behave differently (the timeline size limits in DESIGN_SYSTEM.md). *Rule:* widget changes are only done once they're seen on the iPad.

### The iPad itself is the test device
The Simulator can't run on the iPad, and doesn't need to: the iPad runs the real app. With the iPad plugged in (or on the same Wi-Fi once paired), every reply from Claude on the Mac installs the new build on it within about a minute (`Scripts/auto-sync.sh` → `Scripts/run-on-ipad.sh`). To show Claude what the iPad shows:
- **Screenshot:** take one on the iPad and AirDrop it, or use Xcode → Window → Devices and Simulators → your iPad → Take Screenshot.
- **Live on the Mac:** QuickTime Player → File → New Movie Recording → click the arrow next to the record button → choose the iPad. The iPad's screen then shows in a window on the Mac.

**Newest iPadOS first.** iPadOS 27 is the priority, and older versions get checked afterwards. The Simulator only has the iPadOS versions your Xcode includes: `xcodebuild -downloadPlatform iOS` (or Xcode → Settings → Components) gets the newest. `Scripts/run-in-simulator.sh` always picks the newest installed, and warns if it's older than 27.
*Decision for you:* the app currently supports iPadOS 26 and up. Making 27 the minimum would remove the "works differently on 26" cases (the Clear-mode colours, for one) and halve the testing. Only worth it if you don't need people on 26.

### Catching the iPad's glitches, not the Simulator's
The Simulator's stutter is mostly the Mac (it shares the Mac's chip with everything else that's open; a restart helps). So smoothness isn't judged by eye in the Simulator. It's measured the same way on both:
1. **Frame meter** (Debug builds): `Scripts/run-on-ipad.sh --meter`, or `Scripts/run-in-simulator.sh --meter`. A small pill along the bottom shows frames per second, how many frames came late, and the worst one. Tap it to reset. Do the thing that glitches, then send a screenshot of the pill. If a fix halves the hitches on the iPad, it worked, whatever the Simulator looks like.
2. **Instruments on the iPad** (for the stubborn ones): with the iPad plugged in, Claude on the Mac can record exactly where the time went while you repeat the glitch:
   `xcrun xctrace record --template "Animation Hitches" --device-name "<your iPad's name>" --attach GlassClock --time-limit 20s --output hitches.trace`
3. **Screen recordings**: record the glitch on the iPad (Control Centre → Screen Recording), AirDrop it to the Mac and give Claude the file. It can step through the frames.
4. **Layout glitches** (wrong place, wrong size, overlap) *should* show in the Simulator once it's on iPadOS 27 and the same model. If one doesn't, that's worth noting here.

### Rules for the new build
- No file over about 400 lines. One piece per file: widget stage, panels, settings cards, groups, controls, backdrop.
- One shared app model (`@Observable`) instead of 113 separate states, so a change only redraws the piece that uses it.
- One version of each feature. No "pick a style" switches. If we're unsure, we choose on the iPad and delete the other version.
- Design values (corners, gaps, frost) live in one `Theme.swift`. Design Tweaks stays only in Debug builds, for tuning, and the values you settle on get written into `Theme.swift`.
- Every step ends on the iPad: smooth at 120 fps with no hitches, nothing broken, then commit.

### Free and Pro (decided 22 Oct, see Studio/monetisation-notes.md)
Classic is free, and Pro (about £2, paid once) unlocks the full studio. Every Pro option can be tried in the preview; only applying it needs Pro. The rebuild keeps this in mind from step 1: one `isPro` on the app model, and every Pro control marked as Pro. The purchase itself (StoreKit) comes after step 7, once the paid developer account is set up.

### Build order (each step ends with an iPad check)
1. [ ] **Foundation.** App model and `Theme.swift`, with the Simulator on iPadOS 27 and the same model as your iPad.
   *Written 22 Oct, not yet built: `GlassClock/Rebuild/` (AppModel, Theme, StageBackdrop, WidgetCard, RebuildRoot). Open it with `Scripts/run-on-ipad.sh --rebuild`: the backdrop, the widget at real size and Apply. Tick this once it builds and runs on the iPad.* Move the widget, clock and backdrop code across unchanged.
   *22 Oct (scheduled run): builds and runs in the Simulator with `--rebuild`. Not ticked yet: the iPad was paired but not connected, so it couldn't be installed. Still for you: the Simulator is on iPadOS 26.5 (install iPadOS 27 in Xcode → Settings → Components).*
2. [ ] **The stage.** Backdrop, Home Screen grid and the widget at real size. Drag it to a slot and pinch to resize. Must feel as good as today.
   *First version written 22 Oct (`GlassClock/Rebuild/Stage.swift`): the widget sits on a Home Screen grid, drags to a slot (empty slots and a dashed landing outline show while carried, with a tap of feedback on each new slot) and pinches through the sizes. Its spot is remembered. The drag lives in the widget's own small view, so only the widget redraws while a finger moves. VoiceOver can move it and change its size. Checked in the Simulator for placement and sizes (Screenshots/oct22/rebuild-stage-*.png); drag and pinch need the iPad. Try: `Scripts/run-on-ipad.sh --rebuild`, drag the widget around, pinch it up and down.*
3. [ ] **Settings cards.** Every group's controls as cards in one scrolling list. Apply to Widget.
   *Written 22 Oct (scheduled run), not yet tried on the iPad: `GlassClock/Rebuild/SettingsList.swift`, `StyleCard.swift`, `StyleControls.swift`, `PresetRows.swift`. One card per group, one version of each control, saved presets and locks shared with the old app. Apply sits at the bottom of the list: bold while there are changes, quiet glass once applied. Checked in the Simulator in Light and Dark (Screenshots/oct22/rebuild-settings-*.png); the dark wash was made stronger and a soft shadow added so cards read on any backdrop. Taps weren't checked (the Simulator can't be driven on an unattended run). Left for later steps: the App card (app look, app colour, apply when leaving) and the focus effect (step 7).*
4. [ ] **Classic.** Stage plus the simple settings.
   *Written 22 Oct (scheduled run), not yet tried on the iPad: a Classic / Panels switch at the top (`RebuildRoot.swift`), Classic's short list with a "More options in Panels" card (`SettingsList.swift`), and simple versions of the Fonts and Colour cards. Checked in the Simulator (Screenshots/oct22/rebuild-classic.png, rebuild-classic-panels.png); taps and the bottom card weren't checked (the Simulator can't be driven on an unattended run). On narrow screens both stay stacked under the widget.*
5. [ ] **Panels.** Settings and groups panels on either side: hold to move, flick aside, edge tab to bring back, double-tap to clear.
   *Written 22 Oct (scheduled run), not yet tried on the iPad: `GlassClock/Rebuild/Panels.swift` and `PanelLift.swift`. In Panels on a wide screen, the groups are a glass pill of icons (tap one, or run a finger along them, to scroll the settings to that group) and the settings are a column of cards. Hold a card's title, or anywhere on the pill, for about a fifth of a second: it lifts with a tap of feedback and follows your finger. Let go across the middle and it moves to that side; flick it towards its edge and it goes aside, leaving a tab you tap (or pull) to bring it back. Double-tap the stage to clear both panels, and again to bring them back. Nothing is measured while a panel moves, and only the moving panel redraws. VoiceOver has actions for all of it. Checked in the Simulator for layout (Screenshots/oct22/rebuild-panels.png); the gestures weren't (the Simulator can't be driven on an unattended run).*
6. [ ] **Widget controls.** Home Screen style, size and backdrop around the widget.
7. [ ] **Polish pass.** Glass, focus and animation, one at a time, checked on the iPad. Fewer window touches, more glass.
7b. [ ] **Guided tour.** A short tour of the gestures: drag, pinch, hold to resize, flick a panel aside.
8. [ ] **Swap.** When the new app beats the old one on the iPad, it becomes main. The old one stays on a branch as a record.

### Keep or cut: your call
Put a ✔ or ✘ in "Your call" (or change my pick). Anything cut goes to IDEAS.md for later, so nothing is lost.

| Feature | My pick | Your call |
|---|---|---|
| Widget at real size on a Home Screen grid; drag to a slot | Keep | |
| Pinch to resize, with outline and ticks | Keep | |
| Hold a corner to resize | Keep | |
| Home Screen style picker (Light / Dark / Clear / Tinted) | Keep | |
| Backdrops: gradients, mesh, patterns, your photo | Keep | |
| Swipe the backdrop to change it | Keep | |
| Make your own backdrop | Later | |
| Presets, Feeling Lucky, locks, save your own (2) | Keep | |
| Groups as a pill (you liked it docked on the left) | Keep | |
| Groups stuck onto the widget / settings | Cut for now (lots of bugs) | |
| Panels on either side, or both on one side | Keep | |
| Carrying a panel: full-size lift / title card / puck | Lift only | |
| Flick a panel aside, edge tab to pull it back | Keep | |
| Double-tap the preview to clear the panels | Keep | |
| Widget steps out of the way of panels | Keep (simple version) | |
| Settings carousel squash as cards scroll | Cut | |
| Focused card frosted, others clear | Keep | |
| Shimmer and rim sweep on a card you jump to | Keep, one effect | |
| Wiggle and lean while dragging the widget | Keep lean, cut wiggle | |
| Pinch a panel to change its text size | Later (steppers in Accessibility stay) | |
| One-row widget controls (swipe between pages) | Cut | |
| Controls tuck away after 5 s | Keep | |
| Tap the Preview tag to bring out the extra controls | Keep: a favourite | ✔ |
| App icon: a glass card showing the time (`Scripts/make-app-icon.py`) | Keep for now; final version in Icon Composer with light, dark and tinted variants | |
| Suggestion bubbles under the picker | Cut | |
| App text matches the clock font | Keep | |
| Guided tour | Keep: it shows off the gestures. Built last, once the design is settled (after step 7) | ✔ |
| Design Tweaks sliders | Debug builds only | |

### Working on the Mac
- Open the project folder in Claude Code on the Mac with the iPad plugged in. After each reply it commits, pushes and installs on the iPad (`Scripts/auto-sync.sh`). It now does this on the `rebuild` branch as well as `main`.
- Small tweak: say what you see ("the gap above the card is too big"), check the iPad, then say "good" or "undo".
- Bigger chunk or a new step: a cloud session, which pushes to a branch. Then on the Mac: `git pull`, then `Scripts/run-on-ipad.sh`.
- The first step on the Mac: `git checkout -b rebuild main`, then ask Claude to "start step 1 of the rebuild in PLAN.md".

---

## Before the rebuild: the old plan

## Latest run (22 Oct, 1 a.m.)
- Done: the stuck-on groups now sit close beside the widget, on the side with more space, and stay still when the controls appear or tuck away. Everything in "Now" is ticked.
- Next up: "Quieter extras".
- Try on the iPad:
  1. Stick the groups onto the widget and check they look like part of the widget, not the settings.
  2. Tap the widget to bring up its controls: the groups shouldn't move.
  3. Drag the widget to the far left, then the far right: the groups should move to the roomier side.

## Latest run (22 Oct, later)
- Done: picking up the settings by a card's title bar now carries that card, under your finger.
- Not checked in Xcode: this machine can't build. Build on the Mac before trying it.

## Handover (22 Oct, 1am) — start here in a new chat
**Core first (22 Oct, 2am):** the experimental extras are off by default behind App → "Try experiments": groups sticking to the widget, one-row controls, flicking panels aside, and the shrink-to-carry styles. Nothing is deleted. Next: make the core solid: preview, pinch, drag, panels and Classic.

**Your answers (22 Oct):**
- **Corners:** like the app icon tiles. Rounded rectangles where each inner corner follows the one around it. Not pills everywhere.
- **Groups strip across the top of the settings:** keep it, but make it the same pill as the side groups. Done; check it.
- **Settings scroll edges:** a soft fade, not a rounded cut. Done.
- **Priority:** polish what's there. No new behaviours until it feels finished.

**What you said feels good:** dragging, moving, pinching and hold-to-resize. You also like the pill when the groups are docked on the left.

**Open issues to check on the iPad:**
- [ ] Pinch down to Small paused or jittered on the iPad. The pinch has been reworked to follow the fingers freely, with an outline and ticks. Try it again.
- [x] Settings "sticking above" the Presets card when grabbed. *The stand-in now appears under your finger with the name of the card you picked up, and the panel shrinks into that spot instead of towards its top. Where it lands (left or right, above or below) follows your finger too. Try it with Design Tweaks → Carry set to the title or puck style.*
- [ ] The window menu docked at the bottom looks wrong. *I need a screenshot to see what's off: groups below the settings, or the round dock button?*
- [ ] Freer dropping of panels and the groups pill (later).
- [ ] Widget controls now tuck away after 5 s. Tap the Preview pill to bring them back. Check this feels right.


- The widget is the star. Everything else should support it and get out of its way.
- Smooth and fast before new features. No crashes, no jank.
- Glass first, with transparency used subtly and done well.
- Panels should feel like windows you can grab, push aside and pull back.
- Every gesture should feel like it belongs there. No swipes without a clear purpose.

## Now — make it feel fast (do first)
- [x] **Panels and widget move smoothly.** Dragging redraws the whole screen on every frame. Measure panels at rest, not while moving, and keep the drag inside the panel itself.
- [x] **Holding feels instant.** Make the hold before a drag shorter, and give a lift and a tap of feedback the moment it's held.
- [x] **Stuck-on groups lose their top bar.** Hold anywhere to move them, like the other panels.
- [x] **Stuck-on groups sit in the right place** beside the widget.
  *They now hug the card on whichever side has more open room (not squeezed against the settings), centred on the card so they don't jump when the controls show or hide. Try: stick the groups on, then move the widget across the screen and watch them swap sides. Screenshots: Screenshots/oct22/rail-before.png, rail-after.png.*

## Next — window feel and gestures
- [x] **Swipe a panel sideways to push it aside.** Flick a settings card's title bar, or flick across the groups. *Still to do: the tab doesn't show the panel's icons yet.*
- [x] **Pull it back in** by grabbing the tab. *It opens on release; it doesn't follow your finger yet.*
- [x] **Quieter extras.** Move "Your Home Screen", the notes and the labels away from the widget. Show them only when needed, but still let them be moved.

## Then — settings carousel
- [x] **A carousel instead of shrinking.** Cards squash as they leave the middle, as if tipping back. *A real 3D tilt gets cut off by the list, so it's done flat.*
- [x] **Tighter spacing** between cards.
- [x] **Glass decides the focus.** The card in the middle is frosted, and the cards around it are clear glass rather than faded.
- [x] **A glass outline.** A gradient rim drawn just inside the edge. Cards no longer move past their slot, which was cutting off titles and bottom edges.

- [x] **Consistent corners.** Concentric rounded rectangles like the app icon tiles. Single-line bars stay pills.
- [x] **The widget steps out of the way** when a panel opens over it.

## Later (lower priority)
- [ ] Tour spotlight highlights the right area every time.
- [ ] Grids match phone, tablet and orientation.
- [ ] Styles could be nicer.

## Done (recent)
- [x] Classic button works again.
- [x] Your Design Tweaks values are the defaults.
- [x] Panels carried at full size by holding them, with no grab bars on the main panels.
- [x] Gentler widget lift with no glass corners.
- [x] Cards no longer clip when in focus.
- [x] Design Tweaks moved into App settings.
