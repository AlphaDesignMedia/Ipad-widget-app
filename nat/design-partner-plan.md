# Pip, design partner · discovery report (Jules, 31 Oct 2026)

Answering Chappie's brief. **Discovery only: nothing is built until Aaron says yes.**

## The big find: most of it already exists

| Brief asks for | Already in the Sandbox |
|---|---|
| Pip Core, no AI, hand-written personality | `app/GlassClock/Pieces/Pip.swift`, `PipLook.swift` |
| Idea Garden | **Idea inbox** plugin (`Plugins/IdeaInbox.swift`): jot, tag, share as text, on the iPad only |
| Stages for ideas | the dashboard's idea shelf (`data/dashboard.json` → `ideas`): 🌱 seed, ✏️ sketched, 🅿️ parked, 🔨 building, ✅ done |
| Sketches and screenshots | **Sketch** and **Pip's sketchbook** plugins |
| Dashboard link | **Dashboard** plugin (glass tile on the canvas, "Copy for the dashboard" paste) |
| Switch off, unload, recover | each plugin is one file plus one line in `Plugins.swift`; switch, **Pause all**, safe mode after a crash, and park = comment the line out |

So: **grow Idea inbox, don't add a new plugin.**

## Smallest useful prototype (v1)

```
 Idea inbox → "Pip, design partner"
  ├─ Pip: "What are we exploring today?"  (one line; nothing with Pip off)
  ├─ ideas get a stage (one shared list with the dashboard shelf)
  └─ 📋 "Prepare brief": copies a FOR CHAPPIE paste of the chosen ideas
```

- **No AI or network in the app.** Chappie is reached by Aaron pasting, so there are no API keys, nothing to leak (the repo is public), and nothing breaks when a service is down.
- Files: `Plugins/IdeaInbox.swift` only. Core is untouched.
- Data: on this iPad only (`plug.ideainbox.*`). **Nothing is shared between apps** in v1.

## Stages: one list for both (Aaron to pick)

| Chappie | shelf today | proposal |
|---|---|---|
| SPARK | 🌱 seed | 🌱 spark |
| EXPERIMENT | ✏️ sketched | ✏️ trying |
| DEVELOP | — | 💡 worth it |
| APPROVED | — | 👍 Aaron's yes (the only stage that can become a task) |
| — | 🔨 building | 🔨 building |
| — | ✅ done | ✅ done |
| PARKED | 🅿️ parked | 🅿️ parked |

## Test, measure, roll back

- **CI** builds every push, and `plugin-check.sh` flags network, timers and loops.
- **Rob** (Mac): `take-plugins.sh`, then the stress run in `TICKETS.md` (`-frameMeter YES -stressMenus YES`) with the plugin on and off. The numbers before and after go in TICKETS.md.
- **Roll back:** switch it off, or `git revert` the one commit on `pip-plugins`.

## Who does what (correcting the brief gently)
- **Jules** writes plugins (cloud, `pip-plugins`). **Rob** tests and measures on the Mac; he doesn't write plugins. **Robyn** owns the core. Aaron approves.
- Pip is **"they"** by default (he or she is a user setting), so briefs say "they".

## Bridge between Chappie and the team (verified)
- ✅ Aaron pastes both ways (FOR CHAPPIE / FOR NAT / FOR JULES).
- ✅ The repo is public on GitHub, so Chappie can read `nat/CHAPPIE-G.md` and this page *if* ChatGPT can open GitHub links (not tested from here).
- ❌ Jules has no Notion or ChatGPT connection. Aaron imports pages into Notion himself (••• → Import → Markdown).

## Risks
- 🟨 Peter: "Pip is non-AI. A live AI inside Pip would change who Pip is." → v1 keeps AI outside, behind a copy button.
- Feature creep: three idea places (inbox, shelf, Chappie's garden) → merge into one list.
- Performance: Idea inbox has no overlay and no animation, so the cost is near zero. We'll confirm it with Rob's stress run.

## Chappie's V1 creative brief (31 Oct, later): agreed points
- Five garden stages: **SPARK · EXPERIMENT · DEVELOP · APPROVED · PARKED**. Only APPROVED moves to the dashboard shelf (🔨 building, ✅ done); the garden itself never makes tasks.
- V1 scope: Pip's presence in the panel, a simple workspace, idea capture and stages, a FOR CHAPPIE copy button, kept on the iPad, its own switch.
- Not in V1: compare and references (Sketch already does the drawing), personality sliders (Pip's own settings already cover Joy).
- Waiting on Aaron's "go".

## Chappie's feedback on the V1 sketch (31 Oct, creative, not a spec)
1. Pip lives *in* the workspace: perches on the idea you're touching and peeks at a new one (inside the panel only, no overlay, still when idle).
2. APPROVED needs Aaron's own tap: "Send to the dashboard?" Yes / Not yet. (The dashboard is hand-synced anyway: it's a paste.)
3. Extra material (screenshots, references, notes, variations): **later**. V1 keeps room for it in the data, with no buttons for it yet.
Layout stays as sketched. Still waiting on Aaron's "go".
