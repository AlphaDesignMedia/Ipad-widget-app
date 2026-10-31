# 🗄 The Everything Drawer: plugin inventory and proposal

Jules, 31 Oct 2026, evening. From Chappie's creative review. **This is a proposal: nothing has moved.** Aaron decides each line.
Sources: every file in `app/GlassClock/Plugins/`, Rob's `TICKETS.md` and Tess's run. Not hand-tested on the iPad tonight.

## The idea in one picture

```
 TODAY: one long bar, 47 icons            PROPOSED: three homes
 ┌───────────────────────────────┐        🏠 Everyday bar      what Pip *is*        (~11)
 │ ◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉◉… │   →    🛠 Developer bar     Aaron's tools (job I) (~11)
 └───────────────────────────────┘        🗄 Everything Drawer  off, kept, rediscoverable (~25)
```

The drawer is **not a bin**. Nothing is deleted, code and notes stay, any line can be switched back on in one tap.

## Chappie's test for the drawer

| question | if yes → |
|---|---|
| Does Pip talk or pop in **without being asked**? | drawer ("if you don't bother Pip, Pip doesn't bother you") |
| Does another plugin do the same job? | keep the stronger one, drawer the other |
| Unfinished, or hard to explain in one line? | drawer |
| Heavy (on a ticket for slowness)? | drawer, parked |
| A tool for building, not for using? | 🛠 developer bar |

## Every plugin, sorted (proposal)

### 🏠 Everyday bar: Pip and making things (11)

| plugin | why it stays |
|---|---|
| ✏️ Sketch | the drawing layer, home for the drawing add-ons |
| ✏️ Pencil Wonders | Pip follows the Pencil ⭐ Aaron loves it. Fold into Native Wonders (already planned) |
| ✨ Native Wonders | Pip's little extras, Liquid Time, tilt |
| 🎨 Pip's sketchbook | Pip as artist: watches you draw and guesses ⭐ |
| 💡 Pip, design partner | new tonight, checked by Rob ✅ |
| 💜 Pip's Bond | follows your finger once you're mates ⭐ (15 late frames, mild) |
| 😵 Pip's Feelings | dizzy, sulks, likes a pat: personality through movement |
| 🪶 Pip's Weight | tires, rests on ledges, likes being carried: movement again |
| 👗 Pip Looks | Classic orb or Drop. ⚠️ ticket: 850 ms freeze on open (Jules, next) |
| 📒 Pip Remembers | greets you back (Grounded shelf) |
| 🤫 Pip's Manners | keeps Pip quiet, follows Joy (Grounded shelf) |

### 🛠 Developer bar: Aaron's tools, Developer mode only (11)

Plugin Desk · Pip's flags · Professor Pip · Show Modes · Keyboard Kit · Crew rundown · Dashboard · Next action ·
Dashboard queue · Busy Pip · Pip checks themselves

```
 overlap to tidy later:  Dashboard ─┬─ Next action    (adds to it)
                                    ├─ Dashboard queue ← also overlaps design partner's 👍 APPROVED
                                    └─ Busy Pip report
```

### 🗄 Everything Drawer: off, kept, waiting (25)

| group | plugins | why the drawer |
|---|---|---|
| 💬 Pip chats on their own | Helper Dial · Pip Notices · Pip's News · Pip Doesn't Like Change · Tea Break · Guest Takeover · Rob pops in · Pip's Playground | all speak unprompted; Manners already holds them back |
| 🎨 draw-with-Pip doubles | Doodle Duet · The Draw-off | same job as Sketchbook; worth one "Pip's studio" later, if Aaron wants |
| 🎭 shows and surprises | Opening Night · Director's Call · Twenty Past · The Stationery Cupboard · Tidy Pip · Vend-O-Mat | fun to rediscover, not everyday |
| 🕰 looks | Looks Time Machine · Vintage packs | nostalgia research ⭐ ("small world that tells time") |
| 🪟 glass (parked, heavy) | Liquid Icons · Glass Memory · Window Cleaner Pip | 📌 **research for V2**: Pip living in the glass. Code kept, too heavy as built |

Plus the old **Jeremy Jig Everything** idea (glass breaking and sweeping up) as a 🌱 seed in the drawer, not built.

## Not found (so not built twice, but not built either)

- 🖼 **Pip's gallery**, and passing Aaron's artwork to Pip: there's no gallery yet. Sketchbook is the nearest. It goes in the
  Idea garden as 🌱 SPARK, then through the new workflow.

## How the drawer would work (needs Robyn, core)

```
 Settings ▸ Plugins
 ├ 🏠 Everyday      [on]  [on]  [on] …
 ├ 🛠 Developer     (Developer mode only)
 └ 🗄 Everything Drawer        ← new shelf, starts OFF, not in the bar
     🪟 Glass Memory  [off]  "too heavy as built, V2 research"   💬 Ask Chappie
```

Core changes (small, one file each): a 4th shelf `drawer` in `PluginShelf`; drawer plugins start off and stay out of the bar;
Settings shows the drawer with each plugin's note. Then each plugin moves with **one word** in its own file (`shelf: .drawer`).
The "💬 Ask Chappie" button copies a FOR CHAPPIE paste about that plugin (plugin side, Jules).
Written up as **job J** in `AGENT-NOTES.md` once Aaron says yes.
