# Core ownership check-in (6 Nov 2026)

For: CHAP-A, Chappy, Rob. Written by a Sonnet 5.5 Claude Code session at Aaron's request.
Status: **report and proposal only. No code was changed.** Everything below is reversible (one new file, on branch `from-415`).

Aaron's standing instruction for this window: keep going, assume yes, leave this report here, anything must be reversible. Per the team rules, technical plans still need Rob's approval before anyone implements them, so nothing here is built.

## 1. Short answer

| Question | Answer |
|---|---|
| Is there an agreed "core geometry contract"? | **Not found.** No file, note or code comment calls anything by that name. |
| Who is "Robyn"? | **Not found** in the repo or notes. May be a rename of an existing role, or a new one. Needs Aaron to say. |
| Is geometry ownership written down? | **Partly.** Roles are written down; shared layout geometry is not assigned to anyone. |

## 2. What is agreed (and where it is written)

- Aaron: product and creative director, final say on design, direction, priorities, spending.
- Rob: Mac agent, final technical say, approves technical plans first; owns Glass Clock visual polish, builds and integration.
- "Greg" is named in `pip-sandbox-claude-code/AGENT-NOTES.md` as the **core/backbone** (host, Pip, layout, anything that becomes core). The plugin agent does styling, movement and plugins and flags "Promote" requests. (Check whether Greg and Rob are the same Mac agent: the notes use both names.)
- Nat owns the Pip expression plugins (`PipEmotes`, `PipsFeelings`, `PipNotices`). Other plugin owners are only proposed.
- Core vs plugins: core stays small and generic; plugins hold the extras; plugins ask for core APIs in AGENT-NOTES.md instead of editing the core.
- Glass Clock is read-only from sandbox sessions. Polish happens in its own session. Ports come over on `port-*` branches, only after Aaron says yes and the checks in `PLAN.md` pass.
- Every task has one owner, a clear outcome, an agreed budget and independent verification (Gene verifies, never the implementer).

## 3. What exists in code (geometry-related, not a contract)

Glass Clock (`GlassClock/Rebuild/`, retired folder, kept for reference):
- `Stage.swift`: `HomeGrid` slots; widget size `span` (columns, rows) from `PreviewSize`; scale floored to avoid a zero-size window making the grid maths infinite (21 Oct fix).
- Frame values fed back into layout with `onGeometryChange`: `widgetRect`, `railSize`, `groupFrames`, `stageRect`. Flagged in `OVERNIGHT_PLAN.md` as a possible feedback-loop cost.

Pip Sandbox (`pip-sandbox-claude-code/AGENT-NOTES.md`): geometry the plugins already depend on or have asked core for:
- Exists: `host.keepsTaps(windowPoint)` using `panelFrame`, `barFrame`, `cardFrame`.
- Requested from core, not confirmed built: `host.pipTalking` (Bool), `host.bubbleFrame` (CGRect, Pip's space), a way to find a control's frame (e.g. Sketch's Clear button), and a `host.ink` API. `PipEmotes` currently copies the bubble layout rule from `Pip.swift:524`, so a change to that rule must be mirrored until the API exists.

## 4. Proposed contract (DRAFT, needs Rob's approval, then Aaron's go)

Intent: one place that says who owns which geometry, so the two apps do not drift.

| Area | Proposed owner | Notes |
|---|---|---|
| Glass Clock stage grid, widget sizes, rail/tab frames | Rob | Product code. Only tested changes. |
| Sandbox host layout: panels, plugin bar, cards, Pip space | Core owner (Greg/Rob, to be confirmed) | Plugins read it, never write it. |
| Read-only geometry API for plugins (`bubbleFrame`, `panelFrame`, `barFrame`, `cardFrame`, control frames) | Core owner | Small, generic, additive. |
| Plugins using the API (PipEmotes etc.) | Plugin owner (Nat for the expression ones) | Delete private copies of layout rules once the API exists. |
| Shared visual constants (spacing, corner radii, glass) | Aaron decides, Rob implements | See `DESIGN_SYSTEM.md`. |

Rules to propose:
1. Geometry flows one way: core publishes frames, plugins consume them. No plugin edits core layout.
2. Frames are published in one named coordinate space (state which: window or Pip space) and never fed back into the layout that produced them without a guard.
3. Any port from sandbox to Glass Clock gets its own `port-*` branch and passes the stress test in `PLAN.md`.
4. Changing a published frame is a core change and needs Rob's sign-off.

## 5. Overlaps and integration risks

- **Name confusion:** Rob vs Greg for the core owner, plus the unknown "Robyn". Resolve before assigning anything.
- **Duplicated layout rule:** the speech bubble rule exists in `Pip.swift` and is copied in `PipEmotes`. Drift risk until `bubbleFrame` ships.
- **Two geometry systems:** Glass Clock's `HomeGrid` and the sandbox's panels/cards solve similar problems separately. Porting a feature across means reconciling them.
- **Feedback loops:** `onGeometryChange` state feeding layout is a suspected cause of the known slow spots. A shared contract must not add more of these.
- **Performance, core-owned:** Pip Looks (Blobby) 7 to 11 fps flying with 4 stacked effects (see `CHAPPIE-RED-FLAGS.md`). Not geometry, but whoever owns the core owns this.
- **Signing deadline:** Pip Sandbox signing expires Wed 11 Nov 14:33 (per Rob).

## 6. Outstanding decisions (for Aaron / Rob)

1. Does a geometry contract already exist outside the repo (message, Google Doc, dashboard)? If so, paste it and this report gets reconciled to it.
2. Who or what is Robyn?
3. Is Greg the same agent as Rob? Who is the sandbox core owner?
4. Approve (or amend) the draft ownership table in section 4.
5. Build the read-only geometry API for plugins? Rob writes the proposal first.

## 7. Questions for CHAP-A (read-only lookup)

Search your inbox, faxes, logs and shared docs for: any core geometry contract (who wrote it, when); who is named owner of shared layout geometry; who or what Robyn is; any geometry decisions Rob has not approved. Quote sources; do not guess. Reply with what exists, what is missing, and any conflicts between Rob's and the core agent's responsibilities.

## 8. Not done / not verified

- Did not reach CHAP-A (nothing listening on port 8797; an unidentified Python process is on 8787, not contacted).
- Did not build or run anything. No tests. Claims in section 3 come from reading source and notes, not from running the app.
