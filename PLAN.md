# Glass Clock — The Plan

This is the one place to look. Older notes (OVERNIGHT_PLAN.md, IDEAS.md) are history and a backlog.
Ticks show what's done. Scheduled runs work top to bottom and tick things off here.

## The rebuild (decided 22 Oct) — start here
**Why.** In one day the main screen grew from 914 lines to 3,483 lines, all in one file (`ContentView.swift`), with 113 pieces of state. Every change anywhere redraws that whole screen, which is where the lag comes from. Many features also have two or three versions behind switches, so every fix has to work in all of them, which is where most of the bugs come from. Patching this won't get the smoothness back, so we rebuild the app's screens and keep the parts that work.

**What it is (v1):** a glass clock widget you design on your iPad or iPhone and see at real size on a Home Screen before it goes on yours. Anything that doesn't serve that sentence waits for v1.1.

**Sizes and devices:** iPad (all sizes, both orientations, Split View) and iPhone. Panels is the layout when there's room (a full-width iPad). Classic is the layout when there isn't (iPhone, narrow iPad windows). That's why both stay: they're the same pieces in two arrangements, not two apps. The test iPad is an M1 iPad Pro 12.9-inch. Each step also gets a quick look on an iPhone and a small iPad in the Simulator.

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

### Build order (each step ends with an iPad check)
1. [ ] **Foundation.** App model and `Theme.swift`, with the Simulator on iPadOS 27 and the same model as your iPad.
   *Written 22 Oct, not yet built: `GlassClock/Rebuild/` (AppModel, Theme, StageBackdrop, WidgetCard, RebuildRoot). Open it with `Scripts/run-on-ipad.sh --rebuild`: the backdrop, the widget at real size and Apply. Tick this once it builds and runs on the iPad.* Move the widget, clock and backdrop code across unchanged.
2. [ ] **The stage.** Backdrop, Home Screen grid and the widget at real size. Drag it to a slot and pinch to resize. Must feel as good as today.
3. [ ] **Settings cards.** Every group's controls as cards in one scrolling list. Apply to Widget.
4. [ ] **Classic.** Stage plus the simple settings.
5. [ ] **Panels.** Settings and groups panels on either side: hold to move, flick aside, edge tab to bring back, double-tap to clear.
6. [ ] **Widget controls.** Home Screen style, size and backdrop around the widget.
7. [ ] **Polish pass.** Glass, focus and animation, one at a time, checked on the iPad.
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
| Suggestion bubbles under the picker | Cut | |
| App text matches the clock font | Keep | |
| Guided tour | Later (once the design is settled) | |
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
