# Glass Clock — The Plan

This is the one place to look. Older notes (OVERNIGHT_PLAN.md, IDEAS.md) are history and a backlog.
Ticks show what's done. Scheduled runs work top to bottom and tick things off here.

## Direction (your words, 22 Oct)
- The widget is the star. Everything else should support it and get out of its way.
- Smooth and fast before new features. No crashes, no jank.
- Glass first, with transparency used subtly and done well.
- Panels should feel like windows you can grab, push aside and pull back.
- Every gesture should feel like it belongs there. No swipes without a clear purpose.

## Now — make it feel fast (do first)
- [ ] **Panels and widget move smoothly.** Dragging redraws the whole screen on every frame. Measure panels at rest, not while moving, and keep the drag inside the panel itself.
- [ ] **Holding feels instant.** Make the hold before a drag shorter, and give a lift and a tap of feedback the moment it's held.
- [ ] **Stuck-on groups lose their top bar.** Hold anywhere to move them, like the other panels.
- [ ] **Stuck-on groups sit in the right place** beside the widget.

## Next — window feel and gestures
- [ ] **Swipe a panel sideways to push it aside.** It slides to the edge and condenses into a slim glass tab with its icons, like Slide Over.
- [ ] **Pull it back in** by grabbing the tab, so it follows your finger.
- [ ] **Quieter extras.** Move "Your Home Screen", the notes and the labels away from the widget. Show them only when needed, but still let them be moved.

## Then — settings carousel
- [ ] **A 3D carousel instead of shrinking.** Cards tilt away as they leave the middle.
- [ ] **Tighter spacing** between cards.
- [ ] **Glass decides the focus.** The card in the middle is frosted, and the cards around it are clear glass rather than faded.
- [ ] **A glass outline.** The rim should look like glass, not a flat white line. The bottom edges are still clipped on some cards.

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
