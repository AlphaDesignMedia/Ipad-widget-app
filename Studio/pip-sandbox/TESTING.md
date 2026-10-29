# Pip Sandbox: test and report guide

For any AI agent or person testing the Pip Sandbox on any platform: the Claude iPad or iPhone app, claude.ai in a browser, Claude in Chrome, Codex, ChatGPT, Gemini, or someone holding the device. Read all of it before starting. It takes about 20 minutes.

## What it is

The Pip Sandbox is a playground web page with a glass clock, panels and a small helper character called **Pip**. It is Aaron's design playground for an iPad widget app (Glass Clock), and it never ships. Everything extra comes from **plugins**, shown as emoji buttons in the **plugin bar**. There are 30 plugins, and all of them are on by default.

- **Live page** (only Aaron's claude.ai account can open it, unless he shares it): https://claude.ai/artifact/Cft2LCVsnRsPFRVSkoD9hY
- **Source code** (public): https://github.com/AlphaDesignMedia/Ipad-widget-app/tree/from-415/Studio/pip-sandbox/src. This is a snapshot from 29 Oct 2026. The live page is the source of truth.

## Where it can run

| How it's opened | Saving (database) | Pip Link | Downloads | Notes |
|---|---|---|---|---|
| claude.ai artifact page (web or Claude app) | yes | yes | yes | The real thing. Test here if you can. |
| Local copy of `src/` (`python3 -m http.server --directory src`) | no | no | no | Fine for code, layout and speed checks. Saving, Link and download fail quietly by design. |

If a feature can't work on your platform, write **"not available here"** for it. That is not a bug.

## Rules while testing

- Don't uninstall plugins, and don't press **Turn it off** in the 🫠 nag. Switching a plugin off and back on in the Plugins panel is fine.
- Don't delete Pip's Brain notes or lessons, or other people's sketch pages.
- Start every note you save with `TEST`, so Claude can tidy them up later.
- Don't open developer tools on the live page to change things. Observe only.

## Checklist

Mark each item **Pass**, **Fail**, **Partial** or **Not available here**, and add one line on what you saw.

**A. Loads**
1. The page opens within about 5 s. The clock, Pip and the plugin bar all show.
2. Open the **Plugins** panel (in the rail). The count is 30 and none show an error.
3. Watch for 30 s without touching anything. Does Pip feel calm or too busy?

**B. Pip**
4. Tap Pip, then drag Pip somewhere and let go.
5. While Pip is busy (on a tour, or during 🎁), a **✋ Stop** chip follows Pip. Tap it, or press **Esc** on a keyboard. Pip should stop straight away and say "Okay, stopping."

**C. Panels**
6. Open a panel from the rail, drag it, then tap its **×**. It should smash into glass shards and stay closed.
7. 🫠 card: the smash switch turns this off, and **×** then closes the panel normally.

**D. 🩺 iPad Check** (works on any device despite the name)
8. Press **Run check**. Allow motion if asked, then tilt the device for 4 s.
9. The report saves to the database by itself and shows ✅/❌ rows. Press **Copy report** and paste it into your report.

**E. ✏️ Sketch**
10. Draw with a finger, mouse or Apple Pencil. Try pen, marker, highlighter, eraser and undo.
11. Use **+** to add a page, then switch pages with ‹ ›.
12. Press **📸**. A PNG should download or open a share sheet.
13. Switch to **🖋️ Ink layer**. With a Pencil, the pen draws over the app while a finger still works the panels underneath.
14. Does Pip react to your drawing (for example, a circle or a scribble)?

**F. 🧠 Pip's Brain**
15. Notes tab: type `TEST <your platform>: hello`. Reload the page, then check the note is still there.
16. Lessons tab: start a lesson, then stop it with ✋ halfway through.

**G. 📎 Clip On**
17. Press **Clip onto a panel**, then drag that panel. Pip should hang on and swing.
18. Press **Be Clippy**. Pip turns into a paperclip. Press it again to change back.

**H. 🎁 Surprise**
19. Press 🎁 two or three times, and press ✋ Stop during one. Afterwards nothing should be left moved, tilted or covered.

**I. 📡 Pip Link** (needs two devices, or two browsers signed into the same account)
20. Open the page on both. Each should see the other in 📡.
21. Send an emoji. It should fly off one screen and land on the other.
22. Set a mood on one. The other should show it.
23. Try a 3-emoji pair code on both.

**J. 🫧 Glips**
24. Open each tab (Story, Family, Personality, Morph, Settings). Try one morph. It should change back by itself.

**K. Speed**
25. Plugins panel: write down the ms per frame and the worst frame from the cost meter.
26. Drag a panel quickly for 5 s. Does it judder?

**L. Access** (optional)
27. Turn on Reduce Motion in the system settings and reload. Is it calmer?
28. With VoiceOver or a screen reader, do the plugin bar buttons read out sensible names?

## Known issues (don't report these again)

- Motion permission shows **denied** inside the Claude iPad app. The app's frame may block it, and Safari may behave differently.
- On the iPad, audio starts **suspended** until the first tap.
- In automated tests, synthetic touch events log a `setPointerCapture` warning. Real touches don't.

## How to report

Send all three of these if you can:

1. **🩺 iPad Check**: it saves itself. Paste the copied report into your write-up.
2. **Pip's Brain notes**: save up to three short notes (500 characters each) in 🧠 Notes, such as `TEST <platform> <date>: worst bug …`. Claude reads them from the database.
3. **Full report**: give it to Aaron in the format below. Aaron pastes it into his Claude Code chat. If you can write to the repo, save it as `Studio/pip-sandbox/reports/YYYY-MM-DD-<platform>.md` instead.

```markdown
# Pip Sandbox test: <platform/agent>, <date>
Device: <model, OS version>   App/browser: <Claude iPad app / Safari / Chrome …>
Opened as: <claude.ai artifact / local copy>   iPad Check id: <id, or none>

## Results
| # | Result | Note |
|---|---|---|
| 1 | Pass | loaded in about 2 s |
| … | | |

## Bugs (worst first)
1. <title>: steps → expected → what happened. How bad: blocks / annoying / cosmetic

## Feel
- Most fun:
- Most confusing:
- Too busy or just right:

## Ideas (optional, max 3)
```

Keep it factual: what you did, what you expected, what happened. Screenshots help. Name them by checklist number, like `13-ink-layer.png`.
