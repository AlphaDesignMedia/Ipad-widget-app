# 📤 Outbox review · Jules · Sun 1 Nov 2026 (step 2, on paper only)

**Nothing built.** Step 2 waits until step 1 (one dashboard) is tested and the Dashboard tab is in.

## Every "copy for…" in the app today

| plugin | button | what it copies | for |
|---|---|---|---|
| Dashboard · Needs you | Copy for the dashboard | your Yes / Not yet / Let's talk answers | 📊 master chat |
| Idea Inbox | Approve (copies by itself) | the approved idea | 📊 master chat |
| Idea Inbox | Copy for Chappie | ideas to think through | 🎨 Chappie |
| Stable & Sandbox | Copy for Jules | the stability log | 🔧 Jules |
| Plugin Desk | Copy for the agents · Share | keep / tweak / scrap verdicts | 🔧 Jules + 🖥 Rob |
| Professor Pip | Copy · Send to the developer | a bug report | 🔧 Jules |
| Dashboard queue | 1. Copy (one idea at a time) | queued ideas, walked one by one | 📊 master chat |

**7 buttons · 5 plugins · 4 destinations.** Not counted: the Wonders postcard (a share, not a message).

## The idea

```
 any plugin ──"Add to outbox"──▶  📤 OUTBOX (a widget in the Dashboard's Actions column)
                                  📊 Dashboard   2   [Copy all]
                                  🎨 Chappie     1   [Copy all]
                                  🔧 Jules       1   [Copy all]
                                  🖥 Rob         0
                                  ── sent today: 3 ──
```

- **One tap copies everything for one person**, already labelled the way you paste them
  (FOR DASHBOARD · 📠 FAX FOR CHAPPIE · FOR JULES · 🖥 Terminal for Rob).
- **"Sent ✓"** clears that row and keeps a short list of what went today, so nothing gets sent twice.
- Nothing leaves the iPad by itself, and every copy is your own tap.
- Plugins use one shared helper (`Outbox.add(for:text:from:)`). No core changes.

## ❓ One choice for Aaron

| | buttons in the plugins | outbox |
|---|---|---|
| **A (my pick)** | become "Add to outbox" | does all the copying |
| B | stay as they are, and also add to the outbox | a second way to copy |

A is truly one outbox. B is gentler, but it doubles the buttons, which goes against "no duplication".

## Size
Small: one new plugin file (Outbox) and a one-line change in each of the 5 plugins.
