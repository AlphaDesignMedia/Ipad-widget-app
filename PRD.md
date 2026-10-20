# PRD: Glass Clock (working title)

**Status:** Draft v1 · **Date:** 2026-10-20 · **Platform:** iPadOS 26+ · **Price:** Free

## 1. Summary

Glass Clock is a free iPad app that adds a clock widget to the Home Screen. The widget uses iPadOS 26's Liquid Glass look and lets you change how the numbers look, much like the Lock Screen clock: drag a slider to make the digits thinner or bolder, narrower or wider.

The app does one thing. You open it, style your clock with a live preview, and add the widget to your Home Screen.

## 2. Goals

1. **Working prototype on a real iPad, at no cost.** Free Xcode plus a free Apple ID.
2. **Ship v1.0 to the App Store** once the prototype feels right.
3. **Keep it small.** One widget, one settings screen, no accounts, no data collection.

### Non-goals (not in v1.0)

- Lock Screen widgets, a full-screen desk clock mode, or iPhone/Mac versions
- Seconds, alarms, timers, world clocks or weather
- Payments, subscriptions or ads
- Older iPadOS versions (before 26)

## 3. Target user

An iPad owner who wants a clean, good-looking clock on their Home Screen that matches the Lock Screen style, which Apple doesn't offer as a widget.

## 4. User experience

### 4.1 First launch

1. The app opens on a single **Customize** screen: a large live preview of the clock, with controls below it.
2. A short line of help text: *"Long-press your Home Screen → Edit → Add Widget → Glass Clock."*

### 4.2 Customize screen

| Control | Type | Range / options | Default |
|---|---|---|---|
| Weight | Slider | Ultralight → Black (continuous) | Semibold |
| Width | Slider | Compressed → Expanded (continuous) | Standard |
| Text colour | Swatches (9) + "Auto" | Auto follows the system tint | Auto |
| Card style | Segmented | Liquid Glass / Solid | Liquid Glass |
| Card colour | Swatches (9) + "Auto" | Tints the glass, or fills the solid card | Auto |
| Time format | Toggle | 12-hour / 24-hour | Follows device setting |
| Show date | Toggle | On / Off | On |
| Show AM/PM | Toggle | Only in 12-hour mode | Off |

- The preview updates **live** as sliders move.
- Changes save automatically. Every Glass Clock widget on the Home Screen updates within a few seconds.
- A **Reset** button restores the defaults.

### 4.3 The widget

- **Sizes:** Small, Medium, Large and Extra Large (all four iPad Home Screen sizes). You resize it by dragging its corner on the Home Screen or picking a size in the widget gallery.
- **Layout:** The time fills the widget. The date, if shown, sits in smaller text underneath. Digits scale to fit each size.
- **Glass:**
  - **Clear / Tinted Home Screen modes:** iPadOS draws the Liquid Glass itself. The widget supplies the shapes and marks which parts take the tint.
  - **Default mode:** The widget uses a translucent system material background, so it still reads as glass.
- **Tap:** Opens the app on the Customize screen.
- **Updates:** The displayed time changes every minute. No seconds.

## 5. Requirements

### Must have (MVP)

- **R1** Home Screen widget in all four sizes, showing the current time (hours:minutes).
- **R2** Weight and width adjustable on continuous sliders, using the system variable font (San Francisco).
- **R3** Color, 12/24-hour, date and AM/PM settings, as in §4.2.
- **R4** Settings shared from the app to the widget; the widget refreshes when they change.
- **R5** Looks correct in all Home Screen appearances: Default, Dark, Clear and Tinted.
- **R6** Collects no user data, needs no network and no login.

### Nice to have (v1.1+, only if quick)

- 2–3 extra bundled open-licence variable fonts (e.g. Roboto Flex, Inter)
- Saved presets ("Bold Wide", "Thin Tall")
- Lock Screen widget
- A "Pro" tier with extra fonts and colours

## 6. Technical approach

Kept minimal so it can be built and maintained with Claude Code's help.

| Area | Choice | Why |
|---|---|---|
| Language / UI | Swift + SwiftUI | Apple's standard; least code |
| Widget | WidgetKit, `StaticConfiguration`, all 4 `system*` families | Simplest widget type |
| Variable font | `UIFont.systemFont(ofSize:weight:width:)` → SwiftUI `Font` | SF Pro is a variable font with weight and width axes, so sliders give smooth in-between values. Free, no licensing. Closest look to the Lock Screen clock. |
| Glass | `containerBackground(for: .widget)`, `widgetRenderingMode`, `.widgetAccentable()` | Lets the system apply Liquid Glass and tinting |
| Time updates | Timeline with one entry per minute for the next 60 minutes, refresh at end | Standard, reliable widget clock pattern |
| Settings sharing | App Group + shared `UserDefaults`; app calls `WidgetCenter.shared.reloadAllTimelines()` on change | Simplest way for app and widget to share settings |
| Project layout | One Xcode project: app target + widget extension + one shared `ClockStyle` file | Same code draws the preview and the widget, so they always match |

**Note on the Lock Screen font:** Apple's Lock Screen clock uses a special system font that third-party apps can't use. SF Pro with weight and width sliders gets very close. A bundled font with a height axis (e.g. Roboto Flex) would be a v1.1 option for the tall "stretched" look.

## 7. Cost and accounts

| Stage | What you need | Cost |
|---|---|---|
| Build and test on your iPad | Mac with Xcode 26 (free from the Mac App Store) + your normal Apple ID + USB cable | **$0** |
| TestFlight and App Store | Apple Developer Program membership | **$99 / year** (no way around this) |
| Privacy policy page (required by App Store) | A simple free web page, e.g. GitHub Pages or Google Sites | $0 |

**Limits of the free option:** apps installed with a free Apple ID stop opening after **7 days**. Plug the iPad in and press Run again to reinstall. Developer Mode must be turned on on the iPad (Settings → Privacy & Security → Developer Mode). That's fine for a prototype. Join the paid programme only when you're ready to publish.

## 8. Milestones

| # | Milestone | Done when | Cost |
|---|---|---|---|
| M0 | **Setup** | Xcode 26 installed, signed in with your Apple ID, iPad in Developer Mode, sample app runs on iPad | $0 |
| M1 | **Clock widget prototype** | Widget shows the correct time in all 4 sizes on your iPad, with a glass look | $0 |
| M2 | **Customizer** | App screen with live preview; weight/width sliders and toggles change the widget | $0 |
| M3 | **Polish** | App icon, all Home Screen modes look right, edge cases handled (see §10) | $0 |
| M4 | **Publish** | Developer account, App Store Connect listing, screenshots, privacy policy, TestFlight, then submit for review | $99 |

M1 is the **working prototype** checkpoint. Stop there and decide if it feels right before going further.

## 9. App Store checklist (M4)

- [ ] Apple Developer Program enrolled (approval usually takes 1–2 days)
- [ ] Unique bundle ID and App Group ID registered
- [ ] App name checked for availability ("Glass Clock" may be taken. Have 2–3 backups.)
- [ ] App icon (1024×1024, light/dark/tinted versions for iPadOS 26)
- [ ] iPad screenshots (13-inch size required), showing the widget on a Home Screen
- [ ] Description, keywords, support URL, privacy policy URL
- [ ] App Privacy questionnaire: **Data Not Collected**
- [ ] Age rating: 4+
- [ ] TestFlight build tested on your iPad
- [ ] Submit for review (usually 1–3 days)

**App Review risk:** Apple sometimes rejects apps it sees as having "minimum functionality" (guideline 4.2). A polished customizer with live preview, several widget sizes and real customization is the defence. That's why M2 and M3 are in the MVP rather than shipping a bare clock.

## 10. Edge cases

- Device switches between 12/24-hour or changes time zone → widget follows on the next minute
- Very heavy and very wide settings in the Small widget → digits shrink to fit, never cut off
- Dark mode and the Clear/Tinted glass modes → text stays readable
- Widget added before the app was ever opened → shows the defaults

## 11. Risks and open questions

| Risk | Impact | Plan |
|---|---|---|
| Time ticks over a few seconds late now and then | Low | Normal for widgets. Accept it. |
| How much custom "glass" a widget can draw itself is limited by the system | Medium | Rely on the system's Liquid Glass in Clear/Tinted modes. Check the look on a real iPad at M1. |
| App Groups may not be available with a free Apple ID | Medium | Check at M1. Fallback: put the settings in the widget's own "Edit Widget" menu (preset choices rather than sliders) until the paid account exists. |
| Xcode isn't currently set up on this Mac (`xcodebuild` not found) | Blocks M0 | Install Xcode 26 from the Mac App Store, open it once to finish setup. |

## 12. Success criteria

- **Prototype:** you use the widget on your own iPad daily for a week and it always shows the right time.
- **Launch:** approved on the App Store on the first or second submission.
- **After launch:** ratings and reviews tell us whether v1.1 extras (fonts, presets, Lock Screen) are worth building.
