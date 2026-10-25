# Glass Clock — handoff (paste into a new chat to carry on)

_Updated 25 Oct 2026, 6:00 pm_

**Branch:** `from-415` (the stable base, owner's choice: build from today's branch). **On the iPad:** `friend-test-25oct-2` (6:45 pm), the build for the friend's test. GitHub opens on `main`, which is older: the friend should clone the `friend-test-25oct-2` tag (or branch `from-415`). It adds Outline everything (Accessibility, with a width slider) and a calm adaptive blue as the default app colour.

**6:40 pm update:** Moods cross-fade with no blur and queue fast taps (the likely cause of the tapping stalls), with an Experimental note. Panels Arrange menu: Best for This Window, Groups Along the Bottom, Settings Only. The tour lets you try each move and has "I'll explore myself". Light: subtler glow under dark text, and the bubbles around the widget are more defined. Dark: backdrops turn deep, mirroring Light's pastels. Not yet checked on the iPad: whether Moods still stall. Figma value list: plan agreed in chat, waiting for "go".

**Done this session:**
- **Freeze fix + stable build** `stable-ipad-25oct-1755` (on the iPad, pushed). The `on-ipad` tag still points at e94dfe9: moving it needs a force-push, which the safety check blocks, so ask the owner first.
- **Moods are back**, rebuilt lighter in GlassClock/Moods.swift: still pictures at 10:09, and the row only redraws when the style or backdrop changes. No "try a font" hint on every tap.
- **Light backdrops:** dark gradients and mesh (Midnight, Graphite, Ocean) turn pastel in Light (`Color.lifted` in Workspace.swift) rather than a grey wash.
- From main: status-bar wash and the Extra Large blank-screen fix. Code tidied for the developer review (no warnings, unused code removed).
- Test runs: GLASSCLOCK_STRESS_MOODS, GLASSCLOCK_STRESS_DRAG, GLASSCLOCK_NO_MOODS (StyleGallery.swift).

**What we found:**
- **Moods feel slow** because ContentView (about 4,200 lines) redraws in full on every change, not because of the Moods. Drag test: 166 of 224 frames late with Moods, 172 of 230 without. The simulator draws glass in software, so measure speed on the iPad (`run-on-ipad.sh --meter`).
- **Crashes (found, 25 Oct 5:50 pm):** not an app crash. iOS logged a SpringBoard hang at 5:13 pm: with Glass Clock open, the GPU stalled, the whole iPad froze for 60 s, then SpringBoard was killed (everything vanishes to the Lock/Home Screen). Chain: Glass Clock's SwiftUI renderer (RenderBox) → backboardd's display thread stuck in the GPU → SpringBoard. Likely trigger: a full-screen 40 pt blur of the backdrop kept under the backdrop at all times. Fixed: that blur is drawn only while a backdrop moves. Tagged `stable-ipad-25oct-1755`. Check for new `SpringBoard-*.ips` or `GlassClock-*.ips` with `xcrun devicectl device info files --device <id> --domain-type systemCrashLogs`.
- **For the developer review:** the huge ContentView, the unused GlassClock/Rebuild folder (1,675 lines), `main` and `from-415` have split apart, about 300 MB of images in git, no tests, 21 uses of `AnyView`, and the backdrop drawn twice.

**Bug reports from the owner:** AirDrop screenshots to the Mac and drag them into the chat with one line each. Claude can't watch video.

**Roles:** the owner is the designer and creative lead (tweaks the design system by hand in Figma). Claude is the development agent: sets the build order, suggests proactively, builds, and keeps this file and the dashboard current.

**Priority order (Claude's call, owner can reorder):**
1. **Crash check:** done (see above). If it freezes again, pull the newest SpringBoard/GlassClock .ips the same way.
2. **Stable build:** tagged `stable-ipad-25oct-1755`. If the owner reports no freezes, bring earlier features back one build at a time, each tested before it's tagged stable.
3. **Figma design rules:** a named list of every Design Tweaks value (shadow, radii, spacing) for Figma Variables. Then the app reads the exported token JSON, so new features follow the owner's rules.
4. **Speed:** split ContentView so a change redraws only its own part. Decide with the developer friend, and decide whether to finish or delete GlassClock/Rebuild.
5. **Owner ideas (IDEAS.md):** a Light-mode glow in the owner's favourite colour, asked for on first open.
6. The older list (rail card wider, grab the rail card, flick through cards, light panels, TestFlight, phone layout) waits until the build is stable.

**Dashboard widget:** `Scripts/publish-status.sh` is only on the `glass-dashboard` branch, so the widget's status gist wasn't refreshed this session.

**Parked:** the rail holds still while the iPad turns (costs too much for now). Dashboard split into small files (owner said yes; big one-off job, do it with the next dashboard Build).

**How we work:**
- Build what can be shown quickest first; park credit-heavy ideas with the reason
- "Suggest a quick fix" means go ahead and build it
- One batched message of feedback, then one build, then a break
- While the owner is away, carry on without asking for approval; commit, tag and put builds on the iPad
- Dashboard updates come from this file, on request
- A fresh chat per task or two: paste this file to start; compact when a chat gets long

## Current workspace understanding

The two main priorities are the **dashboard** and **Glass Clock**. This repository contains the Glass Clock app and notes; project notes describe the dashboard as a Claude artifact, not as a file in this repository.

The owner is moving work toward VS Code on the big computer and exploring the cloud app and VS Code on iPad. How these screens, files and chats connect is still being worked out. Do not assume changes sync between them, or that the old Claude commit/push/iPad-install routine applies to Copilot. When it matters, first establish which device or workspace is open and what action will affect it.

```text
Dashboard: interface + project overview    Glass Clock: app + code in this workspace
                  \                              /
                   \\---- shared priorities ----/

Big computer: current project workspace
iPad / cloud VS Code: access and workflow still being mapped
```

## VS Code quick guide (for the dashboard)

You are the creative lead. The AI helps turn your direction into a small next step; you review the result and decide what feels right.

```text
Your design intent → AI helps with one task → inspect the change → try it → decide what to keep
```

**A useful first prompt:**
> Read this handoff and tell me the single next task. Explain which files it touches and how I can check the result. Don't edit anything yet.

That prompt gives the assistant project context, asks for a manageable step, and lets you understand the plan before work begins. When ready, follow with: “Go ahead with that task. Keep the change focused and run the most relevant check.”

| VS Code area | Think of it as | Use it to |
|---|---|---|
| Explorer | Project folders on your desk | Find and open `HANDOFF.md`, Swift files, and design notes |
| Copilot Chat + Studio Guide | A project-aware AI conversation | Ask questions, plan a small task, or work through a change |
| Source Control | A change review table | See which files changed and inspect the before/after diff |
| Terminal | A command box | Run a build or script when you mean to; device scripts can install on the iPad |
| Problems | An error list | Find compiler and editor issues, often linked to the relevant line |

**Small learning loop:** ask what the next step is → make or review one change → check it → note what you learned. Experiments that do not work are still useful information; keep the next action small and return to the handoff whenever the thread gets crowded.

**Next up:** 3 (Figma value list). Update the dashboard once, at the end of each chunk.
