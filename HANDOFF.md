# Glass Clock — handoff (paste into a new chat to update the dashboard)

_Updated 25 Oct 2026_

**On the iPad:** the rail card fade and the widget stepping aside (tag `ipad-25oct-1510`).

**Done today:**
- Hold and drag the folded rail to any edge. It lies flat at the top or bottom (portrait docking), feathers into its new place, and keeps its side when the iPad turns.
- Rail heading taps work again (42fd8c7).
- The screen around an open rail card holds still, so you can't drag the wallpaper by accident, and a tap there closes the card. In portrait the card is shorter, so it clears the other menus.
- Rail card: the white feather behind it is gone. A tall card fades to clear at the top and bottom like the side menu, and above a bottom rail it fades out before the rail. Looks nice on the iPad. The app crashed once while trying it; no crash log has come through yet.
- The widget steps aside for a rail card: it slides away from the card with the same spring, stays on screen, and comes back when the card closes. Not yet tried on the iPad.

**Ideas (💤 in IDEAS.md):**
- Rail card: wider, so it fits with the rest
- Grab the rail card and move it aside, as in Classic
- Crash reports for beta testers: nothing set up yet. TestFlight does it but needs the paid developer program
- Light mode: softer, feathered card shadows and readable text on light panels. Needs research first (black feather looks blurry, white is a known don't)
- Phone-size layout: parked until the iPad is settled
- Tinted mode: cards by the collapsed left menu lose their glass. The backed look could become an accessibility setting
- Anchor the group card to the clock widget
- Flick through group cards with an elastic snap
- Rail holds still while the iPad turns. **Parked**: costs too much for now

**Decisions:**
- Build what can be shown quickest first; park credit-heavy ideas with the reason
- The owner is the creative lead and tweaks the design system by hand in Figma
- "Suggest a quick fix" means go ahead and build it
- One batched message of feedback, then one build, then a break
- Dashboard updates come from this file, on request

**Next up (suggested):** try the widget stepping aside on the iPad (rail at the bottom, extra large widget, open Presets). If it crashes again, plug the iPad in so the crash log can be pulled. Then decide on the paid developer program for beta testing.
