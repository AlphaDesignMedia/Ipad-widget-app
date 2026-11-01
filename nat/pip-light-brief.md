# 💡 Pip's Light · brief for the next agent (Jules, Sun 1 Nov 2026)

Aaron: "the sun that's him lighting panels might have to be another plugin… draw the lines and the idea of what the
lighting will be, then create the core for the plugin agent that makes that light look beautiful and adds effects."
And: "like the old games that only rendered what was in front of them… send out very basic rays to the closest panels,
run them across the edges, turn that into a slight fade on a line. For now." And: "bring him forward with light… use
this to know when he wants attention."

## What's built (v1, `app/GlassClock/Plugins/PipLight.swift`)

```
        ·  ·  ·  rays (Show the rays)
   ( Pip ) ─ ─ ─ ─ ─ ─▶ ════════  ← lit stretch of the panel's edge:
            ╲               bright at the nearest point, fading both ways
             ╲─ ─ ─ ─▶ ║   other edges facing Pip, if within reach
```

- **The core:** `PipLight.light(from:panels:reach:) -> [Lit]`. For each panel within reach (9 Pip radii), each straight
  edge that faces Pip is lit where the reach crosses it. `Lit` = a, b (the stretch), peak (nearest point), strength 0…1.
  No shadows, no blocking, no bounces: old-game light. `PipLight.rays(_:count:)` gives where rays land.
- **Panels:** `host.panelFrame`, `host.cardFrame`, `host.barFrame` (core, Robyn).
- **Brightness:** Pip Looks → Light on panels (`BlobbyTune.panelLight`), × (1 + 0.8 × `BlobbyAttention.level`):
  brighter while Pip wants you (talking or emoting).
- **Look v1:** two strokes per stretch (4 pt spill, 1.5 pt edge), warm white, `plusLighter`. Card: "Show the rays".

## Make it beautiful (your job)

Ideas, Aaron chooses. Keep each one small and switchable:
1. The light **wraps the rounded corners** (v1 stops where the corner starts).
2. A soft **bloom** on the face of the panel just inside the lit edge (a thin gradient, not a blur over the panel).
3. **Glints**: a tiny bright point where the peak is, sliding as Pip moves.
4. **Colour from Pip**: tint by his emoji or mood.
5. **Falloff curve** options (linear, squared, old-game steps: 3 bands, like low-memory games).
6. Later: other lights (the clock, the sun in Weather) using the same core.

## Rules
- Cheap: one Canvas, redraws only when Pip moves. No timers, no full-screen blur. Check frame time with Rob.
- Light, not shadow (Aaron). Pip off or away: nothing. Reduce Motion: no glints that move by themselves.
- Don't touch Blobby's files (`PipBlobbyLook.swift`, `BlobbyGlass.metal`): Jules is in them. Ask in AGENT-NOTES.
