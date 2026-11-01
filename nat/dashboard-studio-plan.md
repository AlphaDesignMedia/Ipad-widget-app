# ✏️ Dashboard studio · the plan (Jules, Sun 1 Nov 2026)

Aaron, 1 Nov: "a lot of the drawing and notes and stuff I had planned for the original dashboard can really come into
play now… put that in the dashboard to send it off", "mood boards on here too", "I need to get it updated with
development", "places to go back and take some screenshots and stuff for the developers", and "lean into these
widgets… my way of exploring new widgets and new widget apps".

**The idea:** the Dashboard becomes your studio. You see where things are, mark it up, collect pictures, and send
them to whoever needs them, all from the iPad. The widgets are where you try out new widget ideas too.

```
DASHBOARD TAB
┌──────────┐┌──────────┐┌─────────────────┐
│ Progress ││Needs you │ │ ✏️ NOTE PAD      │  Pencil or type, on a widget
└──────────┘└──────────┘│                  │
┌───────────────────────┐└─────────────────┘
│ Up next   (circled)   │┌─────────────────┐  ┌──────────────┐
│                       ││ 📤 SEND          │  │ 🖼 MOOD BOARD │
└───────────────────────┘│ Rob 2 · Jules 1 │  │ ▢ ▢ ▢ ▢      │
  [✎ Mark up]            └─────────────────┘  └──────────────┘
```

## Steps, in order (one at a time, each tested before the next)

| # | Step | What you do | Status |
|---|---|---|---|
| 0 | **Home Screen widget** | Pip Dashboard on the real Home Screen, 4 sizes; Edit Widget picks what it shows | ✅ built (65bd9da), Rob testing |
| 1 | **Mark up + Snap** | Draw on the Dashboard tab (Pencil or finger), Snap, add a line, pick who it's for, share or copy | ✅ built, Rob testing |
| 2 | **Shot list** | A list of places to go back to and screenshot for the developers. Each item says where to go (tab, card, setting) and what to show; tap it and the app takes you there, then Snap. Ticked when snapped. Rob and I add items through the board (`shots` in dashboard.json). | ✅ built (73b5f6d), Rob testing |
| 3 | **Note pad widget** | A sketch + note widget in the Dashboard tab. Notes stay on the iPad until you send them. | 🌱 |
| 4 | **Mood boards** | A widget of pictures: snaps, screenshots and photos you pick, arranged loosely like a pin board. A board can be sent as one picture. | 🌱 |
| 5 | **Send (one outbox)** | Every snap, note and board waits here, sorted by who it's for (Master chat, Rob, Jules, Chappie). One tap shares it. "Sent ✓" keeps a short list so nothing goes twice. Folds in the 7 "copy for…" buttons (`nat/outbox-review.md`). | 🌱 |
| 6 | **Home Screen, more** | "Latest snap" widget, a Send widget with counts, the shot list as a widget, answering Needs you straight from the Home Screen (✅ built, 4caf972) | 🌱 the rest |

## Keeping it up to date with development

- **Today:** the app reads the live board (the private gist, set up on the Mac) when the Dashboard opens, and the Home Screen
  widget follows within a moment. The board itself is updated by the master chat and Rob.
- **Gap:** what Rob and I finish doesn't reach the board on its own. Proposal: Rob's `take-plugins.sh` adds one line per
  install to the board ("Installed on the iPad: …"), and agents add shot-list items when they need a picture.
  Needs Rob (Mac) and the master chat; nothing in the app changes.

## Rules kept

- Nothing leaves the iPad without your tap. No new network, no accounts, no tracking.
- Works the same with Pip off; Pip says nothing in the studio unless you ask.
- Private: Aaron's mission control. It lives in the Sandbox and never moves to Glass Clock.
- Simpler motion: fades only. VoiceOver labels on every control.
