# Smoothness while you're out (22 Oct, from 13:20)

Status: in progress. Last entry: 13:36

Nothing here goes on your iPad until you choose it. Each item is its own commit, so any one can be tried alone.

- [x] Widget lands in one smooth motion (no pull back up as it drops into a slot)
  - Found by recording drags in the simulator frame by frame. Four causes, all fixed:
    the slot change lost its animation (so it shot past the slot and pulled back); the widget
    leapt ahead of the finger when a panel moved aside mid-drag; the 3D tilt turned the glass
    dark while carried; a quick drag could land it under a panel.
  - Lands with no overshoot, and the tilt eases back without a wobble.
- [ ] Moving the widget to another slot: the old one slides out, the new one slides in
- [ ] Panels and the groups pill land as smoothly when carried
- [ ] Check it all stays light (no extra layers, nothing redrawing the whole screen per frame)

## Try on the iPad
- Drag the widget quickly across the screen and let go: it should glide into the slot and stop, staying under your finger the whole way and clear, not dark.
