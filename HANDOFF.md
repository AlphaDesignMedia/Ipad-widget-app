# Glass Clock — handoff (paste into a new chat to carry on)

_Updated 25 Oct 2026, 3:45 pm_

**On the iPad:** fbd28ed (tag `ipad-25oct-1545`).

**Done today:**
- Hold and drag the folded rail to any edge. It lies flat at the top or bottom (portrait docking), feathers into its new place, and keeps its side when the iPad turns.
- Rail heading taps work again.
- The screen around an open rail card holds still; a tap there closes the card. In portrait the card is shorter, so it clears the other menus.
- Rail card fades to clear at the top and bottom like the side menu (the white feather is gone). Above a bottom rail it fades out before the rail. Owner: looks really nice.
- The widget steps aside for a rail card with the same spring, stays on screen, and comes back when the card closes. Going from one group to the next it now stays put (it wobbled before).
- **Crash:** iOS saved no crash log for today's crash (newest Glass Clock log is 21 Oct). Likely cause found and fixed: the widget worked out its step aside from where it had already stepped to, so as the rail card opened it could flip back and forth every frame, a loop that can hang or crash SwiftUI. It now works from its resting place. The app also now keeps iOS's crash and hang reports itself (MetricKit, in its Documents/Diagnostics), so the next one leaves a report Claude can copy off the iPad.
- **Groups landing:** dropped near the top or bottom of the settings (or just past them), the groups lie flat above or below them on that side, rather than going to the middle of the bottom. Dropping in the middle of the screen's bottom or top edge still lays them along it. While carrying, the outline is the pill's own shape, where it will land.
- **Groups lying flat use the new rail style:** along the top or bottom, or above or below the settings, the groups are one glass bar with icons and names (icons only when names don't fit, or when names are off in App > Panels), like the folded rail. The old pill of circles is gone. The group in use keeps its glossy bead.
- **Light-mode text shadow:** Automatic shadow follows the text colour: dark text gets a soft light glow, light text a dark shadow, in the app and the widget. A shadow colour you pick stays.

- **Moods are back** (they were lost when this branch went back to the 22 Oct 4:15 pm build), rebuilt lighter in GlassClock/Moods.swift: still pictures, and the row only redraws when the style or backdrop changes.
- **Light backdrops:** dark gradients and mesh (Midnight, Graphite, Ocean) turn pastel in Light rather than getting a grey white wash.
- From main: status-bar wash and the Extra Large blank-screen fix. Code tidied for the developer review (no warnings, unused code removed).

**Roles:** the owner is the designer and creative lead (tweaks the design system by hand in Figma). Claude is the development agent: sets the build order, suggests proactively, builds, and keeps this file and the dashboard current.

**Priority order (Claude's call, owner can reorder):**
1. **Stability:** if it crashes again, copy Documents/Diagnostics off the iPad (command in GlassClock/CrashReports.swift) and fix the cause. A crash beats any new feature.
2. **Check on the iPad (owner):** rail card open and switch groups (widget should step aside once, no flicker); Light mode with dark text and Automatic shadow (soft light glow); carry the groups to the bottom of the settings and watch the outline.
   Also: drop the groups along the top and check the new rail-style bar.
3. **Rail card wider** so it sits with the rest of the layout. Small.
4. **Grab the rail card and move it aside,** as in Classic. Medium; the signature interaction.
5. **Flick through group cards** with an elastic snap. Medium.
6. **Light panels: feathered shadows and readable text in full Glass.** Research first (black feather looks blurry, white is a known don't), then one build.
7. **Beta testing:** decide on the paid Apple Developer Program (about $99 a year). Then TestFlight, which sends crash reports automatically, plus MetricKit in the app.
8. **Tinted mode:** cards by the folded left menu lose their glass.
9. **Anchor the group card to the widget,** cards on either side.
10. **Phone-size layout,** once the iPad settles.

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

**Next up:** 3 (rail card wider), then 4.
