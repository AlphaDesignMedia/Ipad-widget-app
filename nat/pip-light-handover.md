# 💡 Pip's Light · handover to Rob (Sun 1 Nov 2026)

Aaron: "finish this project, hand over to Rob." The Pip's Light agent is done. Rob owns it from here.

## What's built (`app/GlassClock/Plugins/PipLight.swift`, v2)

Pip glows, so the edges of panels near them catch the light. Old-game light: only what's in front of Pip, no shadows.
Every step has its own switch in the Pip's Light card, so Aaron can compare.

| Step | Switch / slider | Start | What it does |
|---|---|---|---|
| v1 rays | Show the rays | off | dashed lines from Pip to where the light lands |
| Corners | Wrap the corners | on | light bends round rounded corners; fades by distance from Pip, no seam |
| Sliders | Reach · Strength · Spill width · Edge width · Falloff · Warmth | 9 · 1 · 4 · 1.5 · 2 · 1 | Aaron's "experiment with values"; saved when the finger lifts |
| Bloom | Bloom · Bloom depth | on · 16 pt | soft glow just inside the lit edge, 4 stepped bands |
| Glints | Glints · Glint size | on · 4 pt | four-point sparkle where each edge is nearest Pip |
| Colour | Colour from Pip · Mood tint | on · 0.6 | blush on Pip's halo wins; else happy gold, shy pink, sleepy/asleep lavender, curious sky, dizzy mint, surprised white |

Overall brightness = Pip Looks → Light on panels (Blobby's slider) × Strength × (brighter while Pip wants you).
Reset puts the sliders back. Pip off or away: nothing. Nothing moves by itself (Reduce Motion safe).

## The core (other plugins can use it)

- `PipLight.light(from:panels:reach:)`: v1's lit stretches (`Lit`).
- `PipLight.rim(from:frame:corner:reach:)`: the part of a rounded panel facing Pip, as one path.
- `PipLight.glint(from:frame:corner:)`: the nearest point on a rounded panel, and the way the edge runs there.
- `PipLight.moodColour(_:)`: Pip's mood as a soft colour (nil = plain).

## On Aaron's iPad

Up to glints (da0eb4c, Rob's 15:48 install). **Colour from Pip is new**: simulator build OK, GitHub on push, not yet
on the iPad.

## Open

1. 🔦 **The big one: the light can't see the app's own panels** (Settings, Groups, the widget panel); only the plugin
   bar, cards and side panel. GitHub **issue #3** (Robyn, Aaron approved). Pip's Light asked there for frame + corner
   radius, closed panels dropped. When it lands: add them to the `panels` list in `Light` (one line). Same data feeds
   Robyn's bump / slip behind panels.
2. **Panel corner radii are guesses** (panel 26, card 22, bar 30). If the light sits off the curve, match them to the
   real ones.
3. **Frame time** near a panel with everything on: not measured yet with bloom + glints. Turn steps off one by one if
   it's costly.
4. Ideas not built: "other lights" (the clock, the sun in Weather) using the same core; a live preview while dragging
   sliders (costs a write per tick).

## Test (Rob)

Open a plugin card, fly Pip beside it and round its corner: lit edge bends round, bloom inside, one glint per panel,
colour changes when Pip's happy / shy / asleep. Each switch off/on. Reset. Frame time.

Working folder used: `~/pip-light` (a git worktree on `light-plugins`, tracking `Ipad-widget-app` `pip-plugins`).
Safe to remove when done: `git worktree remove ~/pip-light`.
