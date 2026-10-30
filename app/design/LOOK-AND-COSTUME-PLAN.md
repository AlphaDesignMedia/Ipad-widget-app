# Looks and costumes: the plan (Jules, 30 Oct 2026, for Aaron and Greg)

Goal: one way to change how Pip and the glass look, in small modular parts that can be swapped later, so the year-long 3D UI idea grows from here. **Defaults never change**: Classic Pip, today's glass. Every new look is one tap away and one tap back.

## What already exists (core)
- `PipLook`: Pip's colours, size and wing numbers. `PipBody`: draws Pip (orb, 2 pairs of wings, two eyes, `PipFace`: awake, dizzy, sleepy and so on).
- `BarLook` plus `host.activeBarLook`: a plugin can already restyle the plugin bar (gap, merge). `LiquidIcons` uses it.
- `host.lookAt(_:)`: Pip's eyes follow a point.

## Three small core hooks (Greg), generic and off by default
1. **Pip body style:** `host.pipStyle: PipStyle?`, where a plugin supplies `func body(face:look:flap:) -> some View` drawn in Pip's own space (moves, squashes and flips with Pip). With nil, `PipBody` is drawn as today. This also covers the long-asked **costume slot** (Busy Pip's clipboard).
2. **Pip depth:** `host.pipDepth(scale:dim:behindPanels:)`. Pip can shrink, dim and sit under panels so they can peek through. This answers Aaron's "smallest mode: mostly behind panels, peeping through" and Bob's Window Cleaner ask.
3. **App look:** a `Look` value (radius, blur, tint, spacing, pressGrow, merge = off) read by `AppGlass` (Workspace.swift ~648) and the bar, and supplied by at most one plugin. With nil, today's glass.

## Plugins that then build on them (the crew)
| Plugin | Uses | First version |
|---|---|---|
| **Pip Looks** | 1 | A picker: Classic (default) · Drop (Aaron's 30 Oct picks, `pip-drop-picks.json`) · later, Aaron's sketches. The 3D maths is in `PIP-DROP-3D.md`. |
| **Window Cleaner v1.1** | 2 | Pip really behind the panel, smaller, wiping |
| **Peekaboo** | 2 | At the smallest size, Pip rests behind panels and peeks out of the edge, growing and shrinking to exaggerate |
| **Glass Kit** | 3 | "Still Water", the first new glass style. Press-to-grow and melting together are settings, off by default. Era looks (Vista or XP-style homage) come later as more Looks. |
| **Costumes** | 1 | Busy Pip's clipboard, Tea Break's mug |

## Order
1. Pip depth (smallest, unblocks two plugins).
2. Pip body style.
3. App look.

One hook per build, simulator first, each with a note.

## Terminal step (for Aaron to paste into Claude Code on the Mac)
> Read app/design/LOOK-AND-COSTUME-PLAN.md on pip-plugins. Please add the three core hooks one at a time, in its order (Pip depth, then Pip body style, then App look). Each one is small, generic and off by default, so with no plugin using it nothing looks different. Build in the simulator before each push, and leave a note in AGENT-NOTES.md after each.
