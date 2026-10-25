# Glass Clock — handoff (paste into a new chat to carry on)

_Updated 25 Oct 2026, afternoon_

**On the iPad:** 4b939f1 (tag `ipad-25oct-1530`). Working well; one crash today while trying the rail card (no log yet).

**Done today:**
- Hold and drag the folded rail to any edge. It lies flat at the top or bottom (portrait docking), feathers into its new place, and keeps its side when the iPad turns.
- Rail heading taps work again.
- The screen around an open rail card holds still; a tap there closes the card. In portrait the card is shorter, so it clears the other menus.
- Rail card fades to clear at the top and bottom like the side menu (the white feather is gone). Above a bottom rail it fades out before the rail. Owner: looks really nice.
- The widget steps aside for a rail card with the same spring, stays on screen, and comes back when the card closes. Going from one group to the next it now stays put (it wobbled before).

**Roles:** the owner is the designer and creative lead (tweaks the design system by hand in Figma). Claude is the development agent: sets the build order, suggests proactively, builds, and keeps this file and the dashboard current.

**Priority order (Claude's call, owner can reorder):**
1. **Stability:** pull today's crash log from the iPad when it appears and fix the cause. A crash beats any new feature.
2. **Light-mode text shadow (owner said "Yes, build it"):** Auto shadow is black under black text in Light mode (Shared/ClockStyle.swift, resolvedShadowColor). Auto follows the text: dark text gets a soft light glow; a shadow colour you pick stays. Small.
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

**Next up:** 1 and 2 together in one build, then 3.
