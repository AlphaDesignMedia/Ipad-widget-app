# Handover to the master chat: Pip Sandbox, 30 Oct 2026

From the Mac agent (Claude Code on Aaron's Mac), to the master chat that owns the **Glass Clock Progress** dashboard (artifact `UQ9Yo6F6RBNdoUn8B9sqeW`).

**What Pip Sandbox is:** Aaron's playground, and it never ships. It feeds the dashboard's next steps. It does not replace the Glass Clock plans.

**Ground rules:**
- Nothing is lost or deleted.
- Glass Clock is untouched.
- No new plugins until the Glass Clock beta ships.
- No Credit Meter plugin.
- Nothing counts as tested unless Aaron says "Aaron tried it".

---

## 1. In one paragraph

Pip Sandbox is now a separate native iPad app with 32 plugins.
- **Who builds it:** the Mac agent (the core) and four cloud plugin agents (Builder 1, Builder 2, Bob and Dot).
- **How it reaches the iPad:** an auto-updater on the Mac merges the plugin agents' work, builds it and installs it. It uses no Claude credits.
- **What Aaron has tried by hand:** only Sketch. Everything else is built only.

---

## 2. Status of Aaron's five steps (from his last message)

| Step | Status |
|---|---|
| 1. Merge `dashboard-30oct.json` into `data/dashboard.json` (status, builds, needsYou only) | **Waiting.** The file isn't on the Mac yet. Aaron needs to save it into the `pip-sandbox-claude-code` folder. |
| 2. Scrub the old homage name from what's packed into the app | **Done, not built yet.** The two questions in `data/dashboard.json` now say "Pip". The Dashboard plugin's name filter no longer writes the old name out. |
| 3. One plain text file of ideas | **Done:** `IDEAS-FOR-DASHBOARD.txt`, also copied in section 8 below. Not added to the dashboard. |
| 4. Fix the two auto-update flaws | **Done, not run yet.** A build clash now retries in 2 minutes instead of counting as a failure. The report lists only what the plugin agents' merge brings in. |
| 5. Core asks that clash with keeping Glass Clock untouched | **None directly.** Watch two: the menu split ("used most" / "extras") and the restraint ladder ("Glass Clock opens as just the clock"). Both are Glass Clock decisions, so they stay sandbox-only until Aaron says yes. |

**Not yet committed or pushed:** steps 2–4, this file and `DASHBOARD-HANDOVER.md`.
- They still need a simulator build check.
- That check failed because macOS blocks Xcode's image tool from reading files in Google Drive. This is a Mac privacy setting, not a code bug.
- A build from a copy outside Google Drive was started and then stopped, because copying out of Drive stalled.
- **Next for the Mac agent:** build the change in the auto-updater's copy (`~/PipSandboxAutoUpdate`), then commit and push.

---

## 3. What's on the iPad

- **Installed:** the build from about 14:36 on 30 Oct.
- **Waiting:** a newer batch (Pip's Feelings, Stationery Cupboard, Pip's Sketchbook, Tidy Pip v1.1, loop tidy-ups). Its 15:03 build failed only because two builds ran on the Mac at once. The failure mark has been cleared, so the auto-updater is retrying it.
- **Install retries:** at 15:24 and 15:32 the iPad install also hit a busy Mac or an unreachable iPad, and it retries every 15 minutes. The iPad must be awake, unlocked and on the same Wi-Fi.
- **Re-sign deadlines:** Pip Sandbox's free signing runs out on **6 Nov**. Glass Clock's re-sign is due **3 Nov**.

**Tried by hand ("Aaron tried it"):**
- **Sketch:** "I love how Sketch is working". Since then its tools have moved into a panel, and the panel itself hasn't been tried.

**Built only:** everything else, including all 31 other plugins, the panels' carry and tuck, and Pencil follow.

**Known issue (Aaron's iPad photo):** the Sketch panel covered the settings rail. A "panels get taps first" fix is built only.

---

## 4. The app and its core

- **Identity:** a separate app called "Pip Sandbox" (`com.aarondennel.pipsandbox`), sitting next to Glass Clock on the iPad. It started as a copy of Glass Clock's Release app.
- **Pip:** the glowing orb with two pairs of wings. Grab, flick, tap and pinch.
- **The split** (Aaron's rule): the Mac agent owns the core and keeps it "strong and stable". Plugins hold every extra feature.
- **The core gives plugins:**
  - **Panels:** slide in, carry to either side, tuck aside.
  - **Sections:** one plugin can add a section to another's panel.
  - **Events:** ink, Pencil, flicks and custom messages.
  - **Pip follow.**
  - **Joy,** a 0–2 liveliness dial, capped under reduced motion.
  - **Taps first:** panels, the bar and cards always take taps first.
- **House rules for every plugin:**
  - Calm at joy 1, silent at joy 0, fade-only under reduced motion.
  - Works with Pip off, and has VoiceOver labels.
  - Pip asks at most about 3 times a session.
  - Feel numbers live in a `Tune` table.
  - One shared "Pip is talking" floor, so plugins never talk over each other.
  - Made-up names only (the "discombobulator" rule).

---

## 5. The 32 plugins (all built only except Sketch)

- **Drawing:**
  - Sketch (tried by hand, before the panel)
  - Pencil Wonders (Pip follows the Pencil)
  - Doodle Duet
  - Pip's Sketchbook
- **Pip's personality:**
  - Native Wonders
  - Pip's Bond
  - Pip's Emotes
  - Pip's Feelings
  - Pip's Weight
  - Set In Their Ways (Pip doesn't like change)
  - Tea Break
  - Guest Takeover (off by default)
  - Pip Remembers
- **Pip helping:**
  - Busy Pip
  - Tidy Pip v1.1
  - Helper Dial
  - Pip's Notices
  - Pip's News
  - Professor Pip
- **Dashboard and ideas:**
  - Dashboard (read-only panel)
  - Next Action
  - Dashboard Queue
  - Idea Inbox
- **The crew:**
  - Crew Rundown v1.1 (with the Crew Log)
  - Plugin Desk
- **Puzzles and surprises:**
  - The Stationery Cupboard
  - Opening Night
  - Twenty Past (a surprise for Aaron: don't describe it)
  - Looks Time Machine
- **Look and feel:**
  - Liquid Icons
  - Keyboard Kit
  - Playground Bridge

---

## 6. The team and how Aaron speaks to them

| Agent | Runs | Branch | Owns |
|---|---|---|---|
| Mac agent | Claude Code on the Mac | `pip-playground` | Core, builds, simulator check, iPad, merging, auto-updater |
| Builder 1, Builder 2 | Cloud | `pip-plugins` | Busy Pip, Dashboard Queue, Tidy Pip, Tea Break, Guest Takeover |
| Bob 🪖 | Cloud | `pip-plugins` | Talk turns, Stationery Cupboard, Tidy Pip v1.1 |
| Dot 🧢 | Cloud | `pip-plugins` | Crew Rundown, Crew Log, Pip's Feelings, Pip's Sketchbook |

**How Aaron reaches them:**
- **One agent:** open its chat.
- **Everyone at once:** a note at the top of `AGENT-NOTES.md`, signed "Aaron". Every agent reads it at the start of each session.
- **The crew's record:** `CrewLog.swift`, one line per finished job.

**Suggestion for the dashboard (needs Aaron's yes):**
- An **Agents** section: one row per agent, with its last note and what it's waiting on.
- A message box with "To: All / Mac / Bob / Dot / Builder 1 / Builder 2" and a copy button that makes a ready-to-paste note.
- Sending straight to GitHub would need a connection and Aaron's yes.

---

## 7. Open items

**Waiting on Aaron:**
1. Save `dashboard-30oct.json` to the Mac (step 1).
2. Try the new batch on the iPad once it's installed, and say which ones count as "Aaron tried it".
3. Tune Pip's Weight first (he asked for this).
4. Stationery Cupboard: is the system-orange light off-look?
5. Sketch: his queued feedback on a floating quick-tools strip (two-finger tap to undo, three-finger tap to redo) and a movable plugin bar that snaps to an edge.
6. Re-sign by 3 Nov (Glass Clock) and 6 Nov (Pip Sandbox).

**Waiting on the core:** the plugin agents' requests, all inside Pip Sandbox. These are core changes, not new plugins.
- A stroke-finished hook, then a pose API (yaw and spin), then a name setter, a costume slot and a new-build signal (Aaron's order).
- `host.talking`
- `host.ink` (count, bounds, tidy, put back), plus control positions so Pip can point at them
- `host.hidePip`
- A rub gesture on Pip
- A "Pip switched on" event
- Backdrop change and restore
- A plan for the menu split

**Paused by Aaron's rules:**
- New plugins wait for the Glass Clock beta.
- No Credit Meter.

---

## 8. Ideas list (also in `IDEAS-FOR-DASHBOARD.txt`; not on the dashboard)

[built only] = built as a plugin, not tried by hand.

```
Pip's Sketchbook [built only] - Pip wants to join in when you draw, guesses badly, and gets better as you teach them.
Pip's name drifts - Pip's vowel slowly follows their personality (Pep, Pop, Pap, Pup), so they become a mini you.
Circles over sliders - 2D pads with labelled edges replace rows of sliders: one gesture sets several related values.
Help Pip home - Pip's own tiny game: flap a tired Pip to a ledge, with no fail screen.
Pip's backstory - Pip was the star of a forgotten made-up arcade cabinet, which gives their flapping and resting a reason.
Pip's story unfolds - Chapters unlock with time and the Bond ladder, never money, and branch from how you use the app.
Android - No port for now; the web sandbox in Chrome on Android covers it for free.
Restraint ladder - Every feature climbs Play > Proven > Hidden > Gentle > Core, so Glass Clock opens as just the clock.
Busy Pip [built only] - When you're idle, Pip audits the plugins with a clipboard, and your answers set how calm Pip is.
Tea break [built only] - After real work Pip asks for a cuppa (3 times at most), then makes their own: charm without guilt.
Guest Takeover [built only] - Made-up guests barge in and do Pip's job, so you notice Pip when they take it back.
Pip checks themselves - After each update Pip tries what's new and asks "Still feel like me?"; a no switches that change off.
Feel rule - Every build must pass "Does this still feel like Pip?": smooth, fresh, one tap off.
VPS server (Later) - An always-on box for a tester inbox and the dashboard's numbers; wait for the first outside testers.
Helper Dial [built only] - Pip's tips steered by one circle (topic by angle, amount by distance) instead of many sliders.
Plugin Desk map - Plot plugins by use against love, so keep / scrap / hidden gem shows at a glance.
Feng shui for features - Every feature is upkeep: a gentle "still sparking joy?" card, and unused plugins go to a loft, never deleted.
Clutter score and tidy up - Pip sighs happily when little is open, and a button tidies cards and panels away (Tidy Pip covers part of it).
Pip is the menu - The collapsed menu ball becomes Pip, and Pip wears costumes for what you're doing (pencil in Sketch, glasses in lab).
Pip finds an identity - Tiny flick-yes/no questions (6 words max, one a day) where every answer visibly changes something.
Two drops (Parked) - Red drop: wild code-rain effects; blue drop: calm. One choice sets Joy and the look.
Search-era homage (For Eras) - A made-up early-web search look in the Time Machine, with Pip's wink: "I hope I never end up turning evil."
```

---

## 9. Where things live

The repo is github.com/AlphaDesignMedia/Ipad-widget-app.
- **`pip-playground`:** the app.
- **`pip-plugins`:** the plugin agents.
- **`main`:** Glass Clock. Never touched from here.

Files in the repo:
- `AGENT-NOTES.md`: all agents' notes, newest first.
- `AUTO-UPDATE.md`: the last auto-update result.
- `HANDOVER.md`: the Mac agent's handover.
- `PLUGIN-AGENT-HANDOVER.md`: the plugin agents' brief.
- `app/PLUGIN-SPEC.md`: how a plugin is built.
- `IDEA-INBOX.md`: the full idea write-ups.
- `data/dashboard.json`: the dashboard snapshot that gets packed into the app. It's still the 29 Oct version until step 1 is done.

On the Mac:
- `~/Library/Logs/PipSandboxAutoUpdate.log`: the auto-updater's log.
