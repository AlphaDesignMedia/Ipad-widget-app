# Idea inbox

Aaron's big ideas, thought through properly but **not built**, so they don't muddy the work in progress.

**How it works:**
- Start a message with **IDEA:**. The agent crunches it here and replies in chat with five lines at most.
- Say **GO: <idea>** to turn it into work.

Every idea gets the same shape:

> **What** · **Why it helps you** · **Honest doubts** · **Cheapest test** · **Where it lives** (which app or agent) · **Verdict** (Now / Later / Park / Pass) · **Questions** (two at most)

---

## IDEA: A VPS server for the dashboard and AI agents (30 Oct 2026)

**What:**
- A small rented Linux computer that's always on: about £4–10 a month.
- It's attached to the Glass Clock dashboard and to the agents.
- Reselling VPS plans later is a **separate business**. It's parked, and flagged for other agents. It doesn't belong in Glass Clock or Pip.

**Why it helps you:**
- **An always-on inbox.** Testers' reports, Plugin Desk verdicts and crash notes go to one place, even while your Mac sleeps.
- **A real home for the dashboard's numbers.** It replaces the secret gist with a small endpoint that the dashboard and the apps both read.
- **Timed jobs for agents.** Nightly summaries, tidying reports and checking that the GitHub builds passed.
- **A relay for Pip Link and Postcards between devices** once you have testers, although Multipeer covers the "same room" case for free.
- **Learning.** Servers, SSH, logs and uptime are a big step up in developer skills, and it fits the "super app for learning" goal.

**Honest doubts:**
- **It can't build the iPad app.** iOS builds need macOS. GitHub Actions already does that for free, and is doing it now.
- **Some of it already exists.** Claude Code's cloud sessions and scheduled tasks cover "agents running while I'm away" without a server.
- **Upkeep.** A public server needs updates, SSH keys and backups, and it's a security responsibility.
- **Tester data is personal data** (UK GDPR). Keep it minimal and say what you collect.
- **The risk you named:** getting lost. A server is a whole new front.

**Cheapest test:**
1. Don't rent anything yet.
2. Send Plugin Desk's "Copy for the agents" into `AGENT-NOTES.md` by hand for two weeks.
3. If you keep wishing it happened by itself, rent the cheapest VPS and run **one** tiny service: the tester inbox.

**Where it lives:**
- The dashboard and a future "ops" agent. Not the iPad apps.
- The apps would only ever *send* to it, and only with a switch the user can see.

**Verdict:** **Later.** The trigger is the first outside testers, or the dashboard needing live data.

**Questions:**
1. Is the dashboard meant to show *live* numbers (needs a server) or *daily* numbers (a scheduled task is enough)?
2. Would testers' reports include anything personal, or only plugin names and verdicts?

### The companion side (a plugin idea from the same message)

**Companion Helper (Pip as a helper):**
- Pip shares tips now and then: about agents, automation, servers and the app.
- You steer it with **one control instead of many sliders**, the **Helper Dial**: a circle you drag a dot around in.
  - **The angle** picks the mix of topics: agents ↔ design ↔ servers ↔ fun.
  - **The distance from the centre** sets how much: centre = quiet, edge = chatty and deep.
  - One gesture sets about four values. That's the condensing rule: **one 2D control for related settings; sliders only for a single number.**
- **A ring chart** around the dial shows which tips you've seen and acted on.

**Plugin Desk, later: a map instead of a list:**
- Plot every plugin on a 2D chart: **how much you use it** (across) by **how much you love it** (up, from verdicts).
- Top-right = keep, bottom-left = scrap, top-left = hidden gem, bottom-right = habit but meh.
- Later, testers' data adds a dot per tester, so you see agreement at a glance.

**Verdict:** Helper Dial and the Desk map are **Now-able** as plugins. The tips content needs your OK on topics first.

---

## IDEA: Feng shui: every feature is one we have to look after (30 Oct 2026)

**What:**
- A "does it still spark joy?" habit for the app itself.
- A calm "tidy room" feeling *inside* the app.

**Why:** every plugin is a promise to maintain it. Fewer, better pieces make a calmer app and less work.

**How:**
1. **Plugin Desk becomes the feng shui room.** Each plugin shows **last used** and **joy** (your verdict). Anything unused for 3 weeks gets a gentle "still sparking joy?" card, never a nag. Scrap means it moves to a "loft" shelf (off, kept), not deleted.
2. **A clutter score** for the screen: how many things are on, open or moving right now. Pip sighs happily when it's low.
3. **A "tidy up" button**: Pip closes open cards and panels and tucks the bar away, like plumping cushions.

**Verdict:** Now-able. It's mostly Plugin Desk v2.

## IDEA: Pip *is* the menu (morphing, skeuomorphic, content-aware) (30 Oct 2026)

**What:**
- The menu already collapses into a ball. Make that ball **Pip**.
- Tap Pip and Pip unfolds into the menu. Close it and the menu folds back into Pip.
- Pip also morphs to match what you're doing, as the old paperclip-style helper did:
  - Sketch open: Pip becomes a little pencil-tipped Pip.
  - Typing: Pip wears headphones and taps along.
  - Changing colours: Pip turns into a paint palette.
  - Lab mode: glasses (done).
- A joke on top: Pip sometimes morphs into the *wrong* thing ("Is this a… stapler? No.").

**Cheapest test:**
- A "costume" layer: an SF Symbol prop near Pip that swaps with context, using the events we already have (`.ink`, keyboard, lab).
- The real menu ↔ Pip morph is core work, so it's the Mac agent's.

**Verdict:** Costumes **Now** (a plugin). The menu morph is **Later** (an ask for the core).

## IDEA: Pip finds an identity through you; flick-yes/no mini chats (30 Oct 2026)

**What:**
- Pip has no gender or fixed identity. They work it out over time from how you talk about them. There's the pronoun setting, and later Pip asks.
- Tiny chats, not an AI chat:
  - Pip asks a short question. **Flick left = yes, right = no.**
  - A soft arrow hint shows which way is which, and the answer is held for a second before it counts.
  - An **undo** chip covers a wrong flick.
  - Like a pocket pet, but **much shorter than the pet apps**: one line, one flick, done.

**Rules (because people skim these apps):**
- At most 6 words a question.
- Never more than one a day, unless you ask.
- Every answer *changes something visible* (a colour, a habit, a line). Otherwise why ask?

**Placeholder questions:**
- "Tea or coffee?"
- "Should I be quieter?"
- "Do you like it when I follow you?"
- "Morning person?"
- "Am I a they?" / "Am I a she?" / "Am I a he?" (only if you've picked "let Pip find out")
- "Is my glow too much?"
- "Can I have a hat?"
- "Was today a good day?"

**Verdict:** Now-able as a plugin once petting and flicks are solid. It needs a flick-direction event from the core (`.flick` has speed but no direction).
