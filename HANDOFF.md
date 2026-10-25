# Glass Clock — handoff (paste into a new chat to carry on)

_Updated 25 Oct 2026, 3:35 pm_

**On the iPad:** aadac0f (tag `ipad-25oct-1535`).

**Done today:**
- Hold and drag the folded rail to any edge. It lies flat at the top or bottom (portrait docking), feathers into its new place, and keeps its side when the iPad turns.
- Rail heading taps work again.
- The screen around an open rail card holds still; a tap there closes the card. In portrait the card is shorter, so it clears the other menus.
- Rail card fades to clear at the top and bottom like the side menu (the white feather is gone). Above a bottom rail it fades out before the rail. Owner: looks really nice.
- The widget steps aside for a rail card with the same spring, stays on screen, and comes back when the card closes. Going from one group to the next it now stays put (it wobbled before).
- **Crash:** iOS saved no crash log for today's crash (newest Glass Clock log is 21 Oct). Likely cause found and fixed: the widget worked out its step aside from where it had already stepped to, so as the rail card opened it could flip back and forth every frame, a loop that can hang or crash SwiftUI. It now works from its resting place. The app also now keeps iOS's crash and hang reports itself (MetricKit, in its Documents/Diagnostics), so the next one leaves a report Claude can copy off the iPad.
- **Light-mode text shadow:** Automatic shadow follows the text colour: dark text gets a soft light glow, light text a dark shadow, in the app and the widget. A shadow colour you pick stays.

**Roles:** the owner is the designer and creative lead (tweaks the design system by hand in Figma). Claude is the development agent: sets the build order, suggests proactively, builds, and keeps this file and the dashboard current.

**Priority order (Claude's call, owner can reorder):**
1. **Stability:** if it crashes again, copy Documents/Diagnostics off the iPad (command in GlassClock/CrashReports.swift) and fix the cause. A crash beats any new feature.
2. **Check on the iPad (owner):** rail card open and switch groups (widget should step aside once, no flicker); Light mode with dark text and Automatic shadow (soft light glow).
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

**Next up:** 3 (rail card wider), then 4.
