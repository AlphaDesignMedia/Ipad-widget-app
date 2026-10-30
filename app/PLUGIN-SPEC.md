# Writing a plugin for the Pip Sandbox app

For Claude, a plugin-making agent, any other AI tool, or a person. Give this page plus the idea.
The result is **one Swift file** and **one line** in a list. (The web sandbox has its own spec: `../PLUGIN-SPEC.md`.)

## Where things go
- Your file: `app/GlassClock/Plugins/YourPlugin.swift`. Files in that folder join the app automatically.
- Your line: in `app/GlassClock/Plugins/Plugins.swift`, add `YourPlugin(),` to the list. The order of the list is the order of the plugin bar.
- Nothing else. Don't edit the host, Pip, Glass Clock's code in `app/`, or anything outside `app/GlassClock/Plugins/`. If you need something the host doesn't offer, say so in your reply instead.

## The shape
```swift
import SwiftUI

// NAME · plugin v1 (Dream). One line on what it does. Where: how to find it.

struct MyPlugin: SandboxPlugin {
    let info = PluginInfo(id: "myid", name: "My Plugin", version: "v1", shelf: .dream,
                          icon: "sparkles", what: "One line, shown in Settings.")

    // MARK: Data      lines, numbers, presets as plain values
    // MARK: Logic     small functions with no views in them
    // MARK: Views     last

    func start(_ host: PipHost) throws { }                  // optional: at launch and when switched on
    func on(_ event: PipEvent, _ host: PipHost) { }         // optional: Pip's events
    func overlay(_ host: PipHost) -> some View { ... }      // optional: drawn over the app, under Pip
    func card(_ host: PipHost) -> some View { ... }         // optional: gives you a button in the plugin bar
    var addsTo: String? { "sketch" }                        // optional: add a section to another plugin's panel...
    func addOn(_ host: PipHost) -> some View { ... }        // ...made of these rows
}
```
- `shelf`: `.dream` (wild), `.grounded` (could ship one day) or `.trial` (testing an idea).
- `icon`: an SF Symbol name.
- `id`: short and unique. It's also your storage prefix.
- Leave out what you don't need. With no `card`, there's no bar button. With no `overlay`, nothing is drawn.
- **State:** the plugin is a struct, made once. For state that lasts the session, keep a small `@MainActor final class` in a `let` (see `PipRemembers.swift`). Settings go in storage, below.
- **Worked examples:** `PipRemembers.swift` uses data, logic, events, storage, a card and Pip's voice. `Wonders.swift` answers another plugin's events and adds a section to its panel.

## What the host gives you (`host`)
- **Pip:**
  - `host.say(line, for: seconds)` makes Pip say something. It returns `false` and shows nothing if Pip is off or not on screen.
  - `host.wake()`, `host.cheer()` (happy eyes and a hop) and `host.move(to: CGPoint)`.
  - `host.follow(CGPoint)`: Pip trails just above and to the left of a point. Call it as the point moves; Pip settles 1.5 seconds after the last call. Nothing under simpler motion.
  - `host.pipHere`, `host.pipAsleep` and `host.pipPosition` tell you where Pip is and whether it's awake.
- **Events** (`on`): `.appear`, `.wake`, `.tap`, `.flick(speed:)`, `.bump(speed:)` and `.rest`. Speeds are in points per second; above 1150 counts as a hard bump.
  - `.ink(...)` comes from Sketch: `.pencil(point)` (where the Pencil hovers or draws), `.drew(InkMark)` (a finished stroke: its box, length, time, whether it's a loop, on Pip, or round Pip), `.erased` and `.cleared`.
  - `host.post(event)` sends an event to every plugin that's on. `.custom("myid.something")` is for trying ideas out; anything that sticks gets its own case (ask the Mac agent).
- **Motion:** `host.simpler` is true when the person wants less motion. Fade, don't move.
- **Joy:** `host.joy`, 0 (still) to 5 (unhinged), default 1 (calm), never above 2 under simpler motion. One setting for every plugin; read it to decide how lively to be.
- **Storage:**
  - `host.value("myid", "key")` and `host.setValue(x, "myid", "key")` read and save settings.
  - In views, `@AppStorage("plug.myid.key")` reads the same value.
  - `host.forget("myid")` wipes everything the plugin has kept.
- **Time:** `host.later(seconds) { ... }` runs something after a pause.
- **Plugin bar and cards:** the host draws the bar, the button, your card's title and its glass. You supply only what goes inside the card.
  - Card text: 13.5 pt, with secondary colour for notes.
  - Buttons: `.buttonStyle(PluginCardButton())`, or `PluginCardButton(on: true)` for a selected one.
  - Spacing: use `PluginBarLook.cardGap`.
- **Panels:** `PluginInfo(..., panel: true)` opens your card as a panel at the side instead (Sketch does). It looks and moves like the app's settings: it slides in, you carry it by a card's title bar to the other side, and a sideways flick on a title bar tucks it aside.
  - Build a panel's card from `SettingsCard(title:icon:footer:) { rows }`, one per group, in a `VStack(spacing: Corner.inset)`. Each row gets a line under it.
  - Other plugins add their own section with `addsTo` and `addOn`; it shows under your cards, titled with their name and icon.
  - While it's open, `host.panelFrame` says where it is (window space), so an overlay that takes touches can leave it alone.
- **Settings:** each plugin gets an on/off switch automatically, under Settings > Accessibility > Pip and plugins.

## Must
- Feel great with Pip switched off. Check `host.pipHere` before relying on Pip.
- Calm by default; louder only in your card's settings. No guilt, streaks, nags or selling. Pip never sells.
- Under `host.simpler`: fade, don't move. Give every control a VoiceOver label.
- Make-believe names only. No real brands, products, games or people, even ones you're paying homage to.
- Never block the app. Overlays use `.allowsHitTesting(false)` unless the small thing drawn is meant to be touched.
- Keep it light. Nothing should run every frame when nothing's moving. No network, camera, location or other permission without Aaron's yes.
- Pip's pronoun is the person's choice (default they). Use "Pip" in lines where you can.
- Don't invent new looks (corner radius, spacing, colour, motion) beyond what's here and in `PipLook`/`PluginBarLook`. If an idea needs one, ask.

## Safety net
If `start` throws, the host switches the plugin off and shows your error in Settings. If the app stops while your plugin is starting, it stays off on the next launch. The host can't catch a crash anywhere else, so test (below).

## Test before handing back
```
cd app && ./tools/check.sh          # builds for the iPad simulator, opens it, saves tools/shots/check.png
./tools/check.sh --build            # just the build
./tools/check.sh --fresh            # replays Pip's first meeting
```
Look at the screenshot. Say plainly what you checked and what you couldn't (touch, Pencil, VoiceOver). Only Aaron can say something works on the iPad.

## Hand back
List the file and the one line you added, what it does, and how to find it. Mark anything that's an estimate, and anything you couldn't test.
