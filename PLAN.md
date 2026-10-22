# Glass Clock — The Plan

This is the one place to look. Older notes (OVERNIGHT_PLAN.md, IDEAS.md) are history and a backlog.
Ticks show what's done. Scheduled runs work top to bottom and tick things off here.

## Latest run (22 Oct, 1 a.m.)
- Done: the stuck-on groups now sit close beside the widget, on the side with more space, and stay still when the controls appear or tuck away. Everything in "Now" is ticked.
- Next up: "Quieter extras".
- Try on the iPad:
  1. Stick the groups onto the widget and check they look like part of the widget, not the settings.
  2. Tap the widget to bring up its controls: the groups shouldn't move.
  3. Drag the widget to the far left, then the far right: the groups should move to the roomier side.

## Direction (your words, 22 Oct)
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
- [ ] **Quieter extras.** Move "Your Home Screen", the notes and the labels away from the widget. Show them only when needed, but still let them be moved.

## Then — settings carousel
- [x] **A carousel instead of shrinking.** Cards squash as they leave the middle, as if tipping back. *A real 3D tilt gets cut off by the list, so it's done flat.*
- [x] **Tighter spacing** between cards.
- [x] **Glass decides the focus.** The card in the middle is frosted, and the cards around it are clear glass rather than faded.
- [x] **A glass outline.** A gradient rim drawn just inside the edge. Cards no longer move past their slot, which was cutting off titles and bottom edges.

- [x] **Consistent corners and pills.** Bars are pills, and cards are rounder in step with the panels.
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
