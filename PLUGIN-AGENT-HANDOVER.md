# Plugin agent: handover

You build plugins for **Pip Sandbox**, Aaron's dream-playground iPad app (SwiftUI, iPadOS 26). Pip is its guide: a small glowing orb with wings. Aaron is the design director. He decides what goes in and how it looks. You do the building.

## Branches (GitHub: AlphaDesignMedia/Ipad-widget-app)
- **Work only on `pip-plugins`.**
  - Never push to `main`: that's Glass Clock, a different app.
  - Never push to `pip-playground` either: that's the app agent's branch.
- **Before each job:**
  - `git pull`
  - `git merge origin/pip-playground`
  - That way you start from the app as it is on Aaron's iPad.
- **Commits:** one plugin per commit, written as `Plugin: <Name> v1: <one line>`.
- **Push when a plugin is done.** The app agent on Aaron's Mac watches `pip-plugins`. When you push, it:
  1. Merges your work into `pip-playground`.
  2. Builds it.
  3. Installs it on Aaron's iPad.
  4. Answers in `AGENT-NOTES.md`.

## Read first
1. `app/PLUGIN-SPEC.md`: the plugin shape, what the host gives you, and the rules.
2. `app/GlassClock/Plugins/PipRemembers.swift`: a small worked example (events, storage, a card, Pip's voice).
3. `app/GlassClock/Plugins/Sketch.swift`: a big one (an overlay, a card, UIKit touch, a saved file). Read it only if you need those.
4. `AGENT-NOTES.md`: build errors and Aaron's feedback from the app agent.

## The job
- One new file in `app/GlassClock/Plugins/`, plus one line in `Plugins.swift`.
  - Nothing else changes, apart from your note in `AGENT-NOTES.md`.
- If you need something the host doesn't offer, don't edit the host. Build the part you can and ask in your note.
- **Can't build** (no Mac or Xcode)? Say so in your note, and write carefully:
  - Swift 5 language mode, iOS 26 SDK.
  - `@Observable` classes: one stored property per line.
  - `SandboxPlugin` is `@MainActor`.
  - The app agent builds your plugin and sends any errors back, with the file and line.
- **Have a Mac?** Run `cd app && ./tools/check.sh` and look at `app/tools/shots/check.png`.
- Porting from the web sandbox (`plugins/*.js`)? Port the idea, not the code.

## The rules that matter most (the full list is in the spec)
- **Calm by default:**
  - Louder only in the plugin's own card.
  - No guilt, streaks, nags or selling. Pip never sells.
- **Must work for everyone:**
  - Feels great with Pip switched off: check `host.pipHere`.
  - Reduced motion (`host.simpler`): fade, don't move.
  - Every control has a VoiceOver label.
- **Names:** make-believe only. Never use real brands, games, products or people, even as homage (for example, no "Navi").
- **Looks:** don't invent them. Use `PipLook`, `PluginBarLook` and `PluginCardButton`. If an idea needs a new radius, spacing, colour or motion, propose it in your note and wait for Aaron.
- **Permissions:** no network, camera, location, Photos or other permissions without Aaron's yes.
- **Off limits:** never touch Glass Clock or the real iPad, and don't install anything.

## What could come next (Aaron decides)
- **Good next steps:**
  - **Night Shift:** warm, dim glass after dark, a sleepy Pip and a morning stretch.
  - **Shadow Puppets:** a soft shadow under Pip, lit from your finger.
  - **Focus Bubble:** a focus timer; Pip naps until it's done.
- **Ask before starting:** **Pip Guide** (Pip shows people around the app). The host first has to learn where the app's features are on screen.
- **Push back for now:**
  - Games that smash or shake the panels.
  - Camera or network plugins.
  - Plugins that change the app's own layout or look.
  - Web-only tools.
  - The reasons are in `HANDOVER.md`.

## Leaving a note
In `AGENT-NOTES.md`, under **From the plugin agent**, newest note first:
- The date and the plugin.
- What you built, and how to find it in the app.
- What you couldn't test.
- Any questions, or a look you're proposing.
