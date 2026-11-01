# Handover · Jules (plugin lead, cloud) → next agent · 1 Nov 2026, 07:05

Read `CLAUDE.md` first (house rules, Pip rules), then this, then the top of `AGENT-NOTES.md`.
Branch: `pip-plugins` only. Never push to `main` or `pip-playground`; never force-push. Glass Clock (`..`) is read-only.

## Aaron, how to talk to him
UK graphic designer and director, visual, neurodiverse. Pictures first, few words, British spelling. Confirm what you
think he means ("maybe just check if that's what I mean"). **His drawings are the authority**; AI images are ideas only;
flag anything you invent. Never a phallic or sperm-like silhouette. Pip is "they" by default (Aaron says "he").
Label pastes: 🖥 Terminal (for Rob) · 📠 FAX FOR CHAPPIE · FOR DASHBOARD.

## Where things are
- **Pip 3D page** (the tuning toy): `app/design/pip-3d.html`, published public as "Pip 3D · trailing circles"
  (slug c38a6722-0c1f-40ec-89f3-3f360c7d4a49, version 1793516601-f0cf; republish with `shared_live: "public"`,
  `artifact_title: "Pip 3D · trailing circles"`). Holds **Aaron's final baseline (1 Nov)**: n 10, len 2.65, curl +0.3,
  taper 1.2, turn 1, blend 0.2, fade 1, edge 0.8, blobby 0.5, smooth 0.6, liquid glass, one pair of leaf wings
  (his overlay: 62° and 44° from the crown), the emoji inside (⭐ default), opens on Sit · Glass Clock warm · Smile.
- **Blobby Pip (V2) in the app**: `app/GlassClock/Plugins/PipBlobbyLook.swift` + the third look in `PipLooks.swift`.
  His circles in Apple's Liquid Glass (`GlassEffectContainer` + `.glassEffect(.clear)`), a real Apple emoji under the
  glass, face emoji become his face, wings flap. Cheap: shapes made once per size, no shaders. CI green (390ed26).
  Only in the Looks card until **Robyn's look hook** lands (lines ready, commented, in `PipLooks.apply`).
- **Rob's next steps**: `nat/rob-next-1nov.md` (take-plugins, screenshot Blobby, iPad dashboard, collect Aaron's
  dashboard notes). There is **no written "dashboard improvements" task**: it comes from Rob's list of Aaron's notes.
- Renders: `nat/pip-3d-emoji-placement.png`, `nat/pip-3d-emoji-universal.png`.

## Aaron's emoji rules (1 Nov, settled)
- One treatment for every emoji: Apple's own emoji, a glass sheen on top (highlight + rim), floats in the **middle of
  his round head, a touch high** (his drawing over the render), follows him with a little lag, faces you, tilts a bit
  with his body, a soft breathing pulse. Used **sparingly**: it appears as he emotes, then goes.
- A **face emoji becomes his face** (his eyes step aside) and he looks at you; it should pop in nicely, then
  **morph back** to his normal face.
- It needs "an element of 3D, just a little". Refraction of the glass around it still isn't right: work it out in the app.
- Parked: glass tears for 😂 (he wants universal, not one-offs). The wings being "a bit polygony" is fine.

## Aaron's new ideas (1 Nov, 07:05, not started; experiments, ask before building)
1. **Pip becomes the glass behind UI**: when you move a slider (lots of them in the app), he slips behind it and becomes
   part of its glass. Must not annoy: he **asks first**, says he can, does it, and if you don't like it: "OK, you can
   turn it on if you want." Lives behind the Pip switch.
2. He **bumps into panels**, and keeps the **liquid way he moves through a panel** and the glow while he does (Aaron loves this).
3. The **emoji's colour tints him** (refraction gives him colour); the colours come from the emoji *you* use. Without an
   emoji his own colour is "nicer in some ways": keep both.
4. Use the **emoji we already have** (Pip's Emotes plugin posts `pip.emote`; `PipEmotes.reaction(to:)`): emotes should
   appear inside him instead of (or as well as) the bubble.
5. **Skeuomorphism**: the face morph and the glass must respect real-material rules. Aaron wants to play on this.
6. **Weight** mattered: Aaron added weight to him (Pip's Weight plugin) and it made a real difference.

## Also open
- Dashboard: real iPad widgets (WidgetKit) later; the outbox (A/B pending); the levels board. Private, never in the public app.
- The private board gist address must never go into the repo, notes or logs.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (no model IDs elsewhere).

## Vector Pip (1 Nov, late morning): the direction now
- Aaron: vectors, not pictures (so Pip can morph and skeuomorph later); "as clean and effortless as possible vector";
  smooth movement that ports to the app and improves over time. **Focus on the visual** for now.
- Model page: `app/design/pip-vector.html` (public "Pip · vector (2.5D)", slug 32d8b1a3-4d8e-442f-8eb3-c2ad2754447d).
  Aaron's pipeline: skeleton in 3D → flat silhouette (body red, front wing green, back wing blue) → softened → glass
  shader (roundness, bends what's behind and the emoji, rim, top-left highlight, warm bounce) → face on top.
  He likes: the subtle inner glow ("what sells it"), the wings, the tail reading as his shadow, the glass emoji.
- Emoji: fills his face, grows from the middle; his face sinks into it and comes back.
- Effort in the flap (weight): bigger, slower beats climbing; each down-stroke lifts him.
- The app still has the flipbook (c480115 … 3da99ce) behind the look hook (08cc85c). Port the vector page next, when
  Aaron says: SwiftUI Canvas silhouette + blur/alphaThreshold, a Metal layerEffect for the glass, Apple glass under it.
- Later (Aaron, parked): weight and rest *in the app*: he rests on or in panels, on walls, peeks; his little glass chair.
- Lookalikes (researched 1 Nov): Rayman's Lums (glowing ball + insect wings) are close to *Classic* Pip; Blobby stands
  apart (glass, tail, leaf wings from the crown, emoji inside). Keep the glow pale and cool, not yellow.
