# 💧 Pip character exploration plan

Jules, 31 Oct 2026, evening. From Chappie's creative review. **A plan, not a build.** Each step waits for Aaron's "go".

## The rule of the house

```
  material first ──▶ character second ──▶ the clock keeps it purposeful
  (glass, light)      (movement, not        (it's still a clock)
                       decoration)
```

## Two Pips, side by side

```
   🧚 THE FAIRY (original)          💧 THE TEARDROP (exploring)
      ◉ wings ◉                         ◉ ◉
     ( glow orb )                      (    )
      ◉       ◉                         \  /
                                         \/
   kept, special, always available   handmade by Aaron, may get its own name
   PipLook.swift (Classic)           browser prototype only, nothing in the app
```

- The fairy stays. Nothing replaces or deletes it.
- New characters are **drawn by Aaron**. Pip can *watch* and *join in* (that's design partner), but doesn't design them.
- Pip's personality is Aaron's. No AI service anywhere in Pip.

## What already exists (reuse, don't rebuild)

| piece | where | useful for |
|---|---|---|
| Pip's body and physics (flick, glide, bump, rest) | `Pieces/Pip.swift` | every movement test |
| The fairy look | `Pieces/PipLook.swift` | wings on vs off |
| Classic / Drop switch | `Plugins/PipLooks.swift` | trying a new body in the app |
| Teardrop prototype (dials) | `app/design/pip-blob-workshop.html` | shape and motion tests |
| Pencil following | Pencil Wonders, Pip's Bond | artist Pip |
| Pip watching you draw | Pip's sketchbook | artist Pip, the gallery later |

🎯 Chappie's "circle with a central point making two smooth curves" is **exactly** how the teardrop is drawn now:

```
       ( circle )
        \      /      two curves leave the circle where they touch it
         \    /       and meet at the point
          \  /
           •
```

## The experiments, one at a time

| # | experiment | how (cheap first) | status |
|---|---|---|---|
| 1 | 2D silhouette first | flat shape only, glass off: does it read as Pip? | ⏳ next, in the workshop page |
| 2 | silhouette behind a panel | a frosted panel over half of Pip: still recognisable? | ⏳ |
| 3 | rotation reacts to movement | body leans into turns, settles upright | ⏳ dial |
| 4 | the point reacts to direction | already in ✅ (point trails and bends) | done |
| 5 | wings on vs off | fairy wings on the teardrop, one switch | ⏳ |
| 6 | motion blur vs liquid stretch | two switches, side by side | ⏳ |
| 7 | fast move / "teleport" | squash, a streak, pop out the other side: effort you can see | ⏳ |

Each one is a dial or switch in the **same** workshop page, so Aaron can compare with one finger. Nothing goes into the app
until he's picked a direction.

## Quality levels (lightweight is the default)

```
  🌿 Light (default)     flat glass, no blur, 30 fps when settled
  ✨ Rich                 gradients, inner glow, highlight (the prototype now)
  🔬 Developer only       motion blur, reflections, glass that "tickles"
```

## 🌱 Inspiration board: shape-shifting Pip (31 Oct, AI images, NOT final designs)

Aaron shared two AI mood boards. They're for mood only: real designs are drawn by Aaron.

```
  💧 core ──▶ 🐦 pigeon ──▶ 📎 tool ──▶ ⚙️ settings      one Pip, many forms
  (glass)     (feathers)    (metal)     (machined)       the material changes with the form
```

- **The idea:** Pip keeps their eyes and personality and changes shape to fit where you are (clock, tools, settings, drawing).
- **Pigeon Park:** a theme idea. "Absolutely stays" on the board.
- **Materials:** glass, feathers, metal and machined, which fits "material first, character second".
- **Others on the board:** pencil, palette, envelope, folder, gamepad, heart, star, note, brush, pixel (8-bit), and menu morphing.
- ⚠️ **Homage check:** a paperclip with eyes reads as one famous office assistant. If it's used, Aaron makes it his own.
- **Status:** ✏️ EXPERIMENT (Chappie's morph brief, 31 Oct). One morph only: 💧 → 🐦.
  `app/design/pip-morph-workshop.html`: Pip and pigeon side by side, a pixel morph (dither / sweep / grow, optional
  smoothing) and a vector morph (12 shared dots that slide). Aaron drags the dots and double-taps for sharp corners.
  Tiny sizes are 16–48 px. Flat by default, no glass. Not in the app. The teardrop experiments 1–7 stay separate, in their order.
  Voxels (C): not tried, kept as a later thought.

## V2 later: Pip in the glass

Behind panels, partly through the glass, "That tickles!" when you touch a glass control. 📌 The parked glass plugins
(Glass Memory, Window Cleaner, Liquid Icons) are the research pile for this. Not started.

## Steps to the app (when Aaron says go)

1. Aaron picks a shape and motion in the workshop page → "Copy picks for the team".
2. Jules: the teardrop as a third look in Pip Looks (card only).
3. Robyn: the "costume slot" (`host.pipStyle`), so a look can be worn everywhere. Core, one job sheet.
4. Rob: measure it on the iPad, light and rich.
