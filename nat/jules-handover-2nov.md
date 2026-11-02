# Handover · Jules (plugin lead, cloud) → next agent · Mon 2 Nov 2026

Jules's own patch: **Blobby (Pip v2)** and the **Dashboard studio**. For the general plugin job, read
`nat/plugin-agent-quick-handover-2nov.md` first (Chappie's full one wins when it lands). Pip's Light is Rob's now
(`nat/pip-light-handover.md`).

Read, in order: `CLAUDE.md` → `PLUGIN-AGENT-HANDOVER.md` → the top of `AGENT-NOTES.md` → this.
Branch: **`pip-plugins` only.** Never `main`, never `pip-playground`, never force-push. Glass Clock (`..`) is read-only.
**The board.json gist address is secret.** Never write it anywhere.

## Talking to Aaron
UK graphic designer and director. Pictures first (ASCII, small tables), few words, British spelling. Shape his ideas,
don't add to them. His drawings win over AI images. Never a phallic or sperm-like silhouette. Pip is "they" by default
(Aaron says "he" for Blobby, which is fine). Every change ends with **What changed · What to test on the iPad · How to
undo**. Rob installs, so Aaron never needs to press Run.

## 1 · Blobby (Pip v2): yours now

```
 silhouette Canvas ──▶ layerEffect (BlobbyGlass.metal) ──▶ glass Pip
   R = body · G = near wing · B = back wing
 BlobbyRig.step (physics) ──▶ BlobbyFrame (pose, wings, ghosts, smear)
```

| File | What's in it |
|---|---|
| `Plugins/PipBlobbyLook.swift` | `BlobbyTune` (sliders, saved under `plug.looks.blobbyTune`), `BlobbyRig`, `BlobbyFrame`, `BlobbyAttention`, the glass layer, halo, emoji |
| `Plugins/BlobbyGlass.metal` | the glass: rim, shine, inner glow; wings take light only (no dark edge) |
| `Plugins/PipLooks.swift` | the Blobby rows in the Looks card; `blobbyView` works out `wants` and `attention` |

**Built and green (up to 367ebf3):**
- Aaron's settings as the defaults
- sharp edges, a softer ring of light, no shadow
- bigger emoji with more colour in the middle
- he comes forward with light when he wants you (talking or emoting)
- effortful flight: each down-stroke lifts him, he sinks between strokes
- feathered ghost wings on fast strokes
- a smear on the turn

**Aaron's notes since (1 Nov, 15:15–15:30), not started:**
1. ✏️ **Teardrop stretch** (his sketch: `nat/blobby-stretch-sketch.png`): "pull the circle so shading follows outline".
   Moving, he pulls into a drop (point behind), and the rim and shine follow the new shape. Snaps round at rest. Off
   under Reduce Motion.
2. **Wings shaded like the blob**: the same glass as his body.
3. **Eyes that track the whole screen** from where he is, not just nearby.
4. **Move more, naturally**: more wander and drift, not more jitter.
5. **"Shadows still problem"**: anything dark round him. Check `edge` (Dark edge) first. His newest settings have it at
   1.2.
6. **Keep**: "emojis look good bigger", "the wings feel more alive now".

**⚠️ Speed comes first: issue #4.** Blobby near panels runs at about 19 fps (Classic runs at 60), and a 514 ms tab showed up in
his screenshot. Measure before adding anything. Likely costs are the ghost-wing blur, the turn-smear blur and the size
of the glass patch. Thin lines across the screen now and then: not caught yet ("don't overthink it").

**His newest settings** (Copy settings, 15:25). His iPad keeps its own saved ones, so changing the defaults won't
reach him:
`{"edge":1.2,"effort":2,"emojiBend":0.4,"emojiColour":1,"emojiSize":1.2,"glass":0,"glow":1.5,"halo":0,"nearWing":1.8,"panelLight":1.5,"shine":1.5,"soft":0.0553,"tail":2.969,"turn":41.76,"warm":0.447,"wings":0.6}`

**Waiting on Robyn (issue #3):** the app's own panels reported to the host, which lets Pip bump into them and slip
behind them. Aaron: "that's what makes him real". Nothing for you until it lands.

## 2 · Dashboard studio: built, Rob testing

Plan and statuses: `nat/dashboard-studio-plan.md`. Aaron's private mission control, so it never ships.

| Step | Where | State |
|---|---|---|
| Pip Dashboard widget (4 sizes, Edit Widget picks the part, Yes / Not yet from the Home Screen) | `GlassClockWidget/PipDashboardWidget.swift`, `Shared/DashboardSnapshot.swift`, `Plugins/DashboardHomeScreen.swift` | ✅ |
| Mark up + Snap (draw on the tab, send to Master / Rob / Jules / Chappie) | `Plugins/DashboardMarkup.swift` | ✅ |
| Shot list (Go → the app takes you there → Snap) | `Plugins/DashboardShots.swift`, `shots` in `data/dashboard.json` | ✅ |
| Mood boards (photos, paste, sticky notes, send as one picture) | `Plugins/MoodBoard.swift` | ✅ |
| Pip Pictures widget (newest mood board or latest snap) | `GlassClockWidget/PipPicturesWidget.swift`, `Shared/PictureShelf.swift` | ✅ |
| Sketch: eraser, line eraser, undo/redo, little tool menu | `Plugins/Sketch.swift` (`MiniTools`) | ✅ |
| Note pad widget · Send (one outbox) · more Home Screen widgets | not started | 🌱 Aaron's go first |

**Gotchas:**
- The live board has no `shots` yet, so the packed file stands in (`boardShots`).
- On free signing, the widget's shared data may go through the keychain rather than the app group. If the widget
  shows the sample board on the iPad, start there.
- I made small core touches with Aaron's OK: the widget bundle lines and `onOpenURL` in `ContentView.swift`. Robyn
  hasn't reviewed them yet.
- Issues #9 (drawing undo), #12 (dashboard worksheets) and #13 (Pip in Home Screen widgets) touch this work: read them first.

## Next, in order
1. Read Rob's latest notes. Fix anything red from the Dashboard, Mood boards or Blobby first.
2. Issue #4: make Blobby fast. Measure, then cut.
3. Ask Aaron which of the Blobby notes (1–5) goes first. Recommend the teardrop stretch: it's his drawing.
4. Note pad and Send only on his go.

## Every change
Save point (commit) → push → GitHub Actions green (wait in the background, don't loop) → a note for Rob at the top
of `AGENT-NOTES.md` → three lines to Aaron. Fetch and rebase before you push, because other agents push too. Commits
carry no model names.

---

### Paste to start a new chat

> You're the plugin maker for Pip Sandbox (GitHub AlphaDesignMedia/Ipad-widget-app, branch `pip-plugins`), taking over
> Jules's patch: Blobby (Pip v2) and the Dashboard studio. Read `CLAUDE.md`, `PLUGIN-AGENT-HANDOVER.md`,
> `nat/plugin-agent-quick-handover-2nov.md`, the top of `AGENT-NOTES.md`, then `nat/jules-handover-2nov.md`. First
> job: Blobby's speed (issue #4). Then ask Aaron which of his Blobby notes goes next. Short, plain, British. Every
> change ends with What changed · What to test on the iPad · How to undo.
