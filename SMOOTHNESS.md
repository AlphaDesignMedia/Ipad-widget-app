# Smoothness while you're out (22 Oct, from 13:20)

Status: done (the slide idea waits for you). Last entry: 13:56

Nothing here goes on your iPad until you choose it. Each item is its own commit, so any one can be tried alone.

- [x] Widget lands in one smooth motion (no pull back up as it drops into a slot)
  - Found by recording drags in the simulator frame by frame. Four causes, all fixed:
    the slot change lost its animation (so it shot past the slot and pulled back); the widget
    leapt ahead of the finger when a panel moved aside mid-drag; the 3D tilt turned the glass
    dark while carried; a quick drag could land it under a panel.
  - Lands with no overshoot, and the tilt eases back without a wobble.
- [ ] Moving the widget to another slot: the old one slides out, the new one slides in
  - Waiting on you: I wasn't sure which moment you meant (see the note at the end).
- [x] Panels and the groups pill land as smoothly when carried
  - Settings panel carried to the other side: it used to fade, slide in from the edge, and the
    widget and groups jumped. Now it's put down where you let go and glides into place, and the
    widget steps out from under it straight away. Checked in the simulator.
  - Groups pill: same treatment. The simulator can't do its hold-and-drag, so this one needs
    your hands on the iPad.
- [x] Check it all stays light (no extra layers, nothing redrawing the whole screen per frame)
  - The new lifted shadow is only drawn while the widget is carried. The landing fixes add no
    layers; dragging still only redraws the widget, not the whole screen.

- [x] Extra: the Stage Manager-style tuck went solid black (same 3D-turn problem as the widget).
  Now it's a flat squeeze that keeps its clear glass.

## Try on the iPad
- Drag the widget quickly across the screen and let go: it should glide into the slot and stop, staying under your finger the whole way and clear, not dark.
- Hold a settings card's title and carry the panel to the other side: it should land where you let go and glide into place, with the widget stepping aside at once.
- Flick a settings title bar towards the edge: the tucked sliver should stay clear glass, not black.
- Hold the groups pill and move it up, down and across: same glide, no jump.

## A question for you
"The old widget slides out and the new one slides in": which moment did you mean?
1. Dragging it to another slot: a faint copy stays in the old spot and slides away as it lands.
2. Tapping through the sizes or Home Screen styles (left to right): the old look slides out
   one side and the new one slides in from the other, like turning pages.
