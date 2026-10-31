# 🗂 Dashboard review · Jules · Sat 31 Oct 2026, late

From Aaron's team handover: review what exists before proposing anything, and separate unfinished work from new ideas.
**Nothing here is built or changed yet.** Each step waits for Aaron's pick.

## What the dashboard is today (in Pip Sandbox)

```
 🪟 Glass tile on the canvas ──tap──▶ 🗂 Dashboard card (side panel)
                                      ├ Open as Panels ▶ full screen: 7 sections
                                      ├ Needs you (Yes / Not yet / Let's talk → FOR DASHBOARD copy)
                                      ├ Where we are · Reminders
                                      └ sections other plugins add:
                                         Next action · Dashboard queue · Busy Pip report · Stable & Sandbox
 Nearby, separate: Crew rundown (own panel) · Pip, design partner (FOR DASHBOARD on approve) · Plugin Desk
```

| part | state |
|---|---|
| Glass tile, card, Needs you answers | ✅ built, on the iPad |
| Dashboard as Panels (7 sections) | ✅ built, Rob green, on the iPad |
| Next action, Dashboard queue, Busy Pip, Stable & Sandbox sections | ✅ built, only in the side panel |
| Rob's PerFrame fix | ✅ Dashboard scroll 6 → 60 fps |

## 🔧 Built, but unfinished

1. **The numbers go stale.** The board is a snapshot typed into the code (31 Oct, 3:15 pm). The card even says
   "fresh numbers arrive with the next build", but nothing packs `data/dashboard.json` into the app yet.
2. **Two dashboards.** The card and Panels show the same things twice (Where we are, Needs you).
3. **Panels is missing the sections.** Next action, the queue, Busy Pip and Stable & Sandbox only show in the side panel.
4. **Copies are scattered.** FOR DASHBOARD (answers, approvals), FOR JULES (Stable log), the queue walk: four places.
5. **The queue is from 30 Oct.** Some of its 13 items are done or out of date.
6. **A bump when sections unfold** (250–400 ms). Core, Robyn's ticket.

## 🧩 Exists, needs better integration

- Crew rundown and design partner are dashboard-ish but live in their own panels.
- `usage`, `principles`, `ideas` are in the data. Panels shows principles and ideas; usage isn't shown.

## 💬 Discussed, not built

- Dashboard tile in the top bar (waits on Robyn's hook).
- The restraint ladder (Play → Proven → Hidden → Gentle → Core).
- Feng shui for features / a clutter score. Plugin Desk map (use vs love).
- Live numbers from a server (later: wait for outside testers).

## ✨ New opportunity (only one)

- **A "levels" board:** every idea sorted into **Foundation · Update · Major release** (Aaron asked for help with this).
  It's the restraint ladder, made visible.

## Recommendation: three steps, smallest first

| | step | why | size |
|---|---|---|---|
| 1 | **Fresh numbers**: ship `dashboard.json` as a file in the app, so updating the board is a file swap, not code | everything else reads from it | small |
| 2 | **One dashboard**: Panels becomes *the* dashboard, with the add-on sections in its sidebar; the card becomes the tile + "Open" | removes the doubling | medium |
| 3 | **One outbox**: every "copy for…" in one sidebar section | one place to send things on | small |
| 4 | Later, Aaron's call: the levels board | needs Aaron's sorting | medium |

## First guess at the three levels (for Aaron to correct)

| 🧱 Foundation (day one) | 🔄 Updates | 🎉 Major releases |
|---|---|---|
| the clock and widgets | new looks and eras | Pip's design language (V2 Pip) |
| works perfectly with Pip off | plugins graduating from the drawer | a new material generation (neon, frost…) |
| Stable switch, accessibility, reduced motion | dashboard sections | community launch moments |
| the glass design system | small Pip moments (peek, hello) | |
