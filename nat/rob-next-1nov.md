# Rob · what's next (1 Nov, from Jules)

Short and in order. One step at a time. Tick each one off in AGENT-NOTES when it's done.

## 0. Leave alone

- The old `DASHBOARD-HANDOVER.md` in the Google Drive copy: don't commit it. That copy is out of date. GitHub is the real one.

## 1. Take the latest plugins

```
app/tools/take-plugins.sh
```

- This brings in **Blobby Pip** (a new look in Pip Looks) and Aaron's final Pip settings.
- If the build fails: stop and paste the error into AGENT-NOTES. Jules fixes it.

## 2. Look at Blobby Pip in the simulator

1. Turn on **Pip Looks** (the drop button in the plugin bar). Open its card.
2. You'll see three Pips. Blobby is the one on the right.
3. Tap **Blobby (V2)**, then tap a few emoji in the **Inside him** row (⭐ ❤️ 😊).
4. Take **one screenshot of the card** with ⭐, and one with 😊.
5. Write down the **frame time** with the card open (late frames, like you did for Drop).

Put the two pictures and the number in AGENT-NOTES, under "Rob → Jules · Blobby".
Just say what you see. Two questions to answer:
- Can you see the emoji **through** the glass (is it bent or blurred at the edges)?
- Do the wings move?

## 3. The dashboard on Aaron's iPad

Only if you haven't done this already from the 06:45 note:

1. Run `-checkQ tab|size` once more. The "answer" line should say `widget 5 → 4`.
2. If it does, put it on Aaron's iPad (`app/run-on-ipad.sh`).

## 4. Collect Aaron's dashboard notes (this is the "dashboard improvements" task)

There's no new dashboard task written yet. Aaron's notes from the iPad decide what it is.
While Aaron uses the dashboard on his iPad, write down **everything he says** about it, as a plain list:

- what he liked
- what's wrong or broken
- what he wants next

Add a picture if he points at something. Put the list in AGENT-NOTES, under "Rob → Jules · dashboard notes".
Jules turns that list into the next plugin work.

## Not yours

- Plugin code: Jules fixes plugins.
- Core files (host, tab switch, look hook): Robyn.
