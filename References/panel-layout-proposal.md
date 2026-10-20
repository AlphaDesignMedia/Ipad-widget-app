# Panel layout proposal: sidebar, preview and inspector

**Date:** 2026-10-20 · **Status:** prototype on the `panels-prototype` branch, not in the app yet · **Screenshots:** [`panel-prototype/`](panel-prototype/)

You asked whether Glass Clock could use the kind of layout Files, Photos and Notes use on iPad, where glass panels slide out from the sides. Short answer: **yes. It suits Glass Clock well, and it is the layout Apple now recommends for apps like this.** Below is what I found, three ways to do it, and what I built.

---

## 1. What Apple says (in plain words)

### Glass is the "controls layer", and panels are part of it
- Apple's Materials guideline says Liquid Glass is a separate layer for "controls and navigation elements — like tab bars and sidebars" that **floats above the content**. Content shows through it as it scrolls. ([HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials))
- On iPad, **sidebars float above the content** as glass. Apple suggests letting the content run underneath them, either by scrolling or with a **background extension effect**, which mirrors and blurs the edge of the picture so it seems to carry on under the panel. ([HIG: Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout))
- The Layout page names **sidebars and inspectors** together as the panels a full-window background should run under. ([HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout))

### Sidebars
- Use them to move between the main areas of an app. Show **no more than two levels**, group items under short headings, and give each one a familiar SF Symbol. Let people hide the sidebar, but **don't hide it by default**, so people can find it. ([HIG: Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars))

### Split views and inspectors
- An iPad split view can have two panes (like Mail) or three (like Keynote). Apple gives Keynote (on Mac) as an example of panes, including an **inspector**, arranged around a main canvas. Apps should **work at narrow, medium and wide window widths**. ([HIG: Split views](https://developer.apple.com/design/human-interface-guidelines/split-views))
- An inspector is a panel on the trailing (right) side that shows details or controls for the thing you've selected. In SwiftUI it is one line, `.inspector(isPresented:)`. On a big iPad it is a column; in a narrow window it automatically becomes a **sheet**. WWDC25's *Build a SwiftUI app with the new design* shows a sidebar on one side and an inspector on the other, and says "the new design makes inspectors shine". ([WWDC25 session 323](https://developer.apple.com/videos/play/wwdc2025/323/), [Create with Swift: presenting an inspector](https://createwithswift.com/presenting-an-inspector-with-swiftui))

### Toolbars
- **Trailing edge:** important buttons, **buttons that open inspectors**, and the main action. These stay visible at every window size. Keep to **three groups at most**. ([HIG: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars))
- In iPadOS 26+, toolbar items sit in small glass groups, which you can separate with `ToolbarSpacer`. ([WWDC25 session 323](https://developer.apple.com/videos/play/wwdc2025/323/))

### Windows (Stage Manager, Split View and the new windowing)
- On iPadOS 26+, people can resize app windows freely, and several can be on screen at once. ([HIG: Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [HIG: Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking))
- Every window gets **window controls at the top left of the toolbar** (the three dots), and leading toolbar buttons move over to make room. Don't fight them. ([HIG: Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [WWDC25 session 208 notes](https://wwdcnotes.com/documentation/wwdc25-208-elevate-the-design-of-your-ipad-app/))
- **Keep what the app can do the same at every size. Only change how much is visible at once.** ([HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout))
- WWDC25's *Elevate the design of your iPad app*: sidebars fold away in portrait and in smaller windows, layout changes should never lose your place, and content should run behind the sidebar, especially in floating windows. ([WWDC25 session 208](https://developer.apple.com/videos/play/wwdc2025/208), [notes](https://wwdcnotes.com/documentation/wwdc25-208-elevate-the-design-of-your-ipad-app/))

### What changed in iPadOS 27 (WWDC26)
- The glass is less see-through by default, and there is a new system slider that lets people choose between clearer and more frosted glass. **Sidebars got a refreshed look with new corners.** Apps built with the new tools pick this up automatically, without code changes. ([AppleInsider on iPadOS 27](https://appleinsider.com/articles/26/06/08/liquid-glass-customization-better-apple-intelligence-arrive-with-ipados-27), [WWDC26: What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/), [Wikipedia: Liquid Glass](https://en.wikipedia.org/wiki/Liquid_Glass))
- Inactive windows now dim their icons and text so you can tell which window is in use. That is free too. ([WWDC26: What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/))
- I found **nothing new about inspectors** in iPadOS 27.

### How Apple's own apps do it
- **Files, Notes, Mail, Music, Podcasts, Safari:** a floating glass sidebar on the left with grouped, icon-labelled items. Content runs to the edges behind it. It folds away in portrait and narrow windows, and comes back from a toolbar button or by swiping in from the left edge. Apple's iPadOS 26 feature list names Safari, Music and Podcasts as having the new Liquid Glass sidebars. ([Apple: All new features in iPadOS 26 (PDF)](https://www.apple.com/nz/os/pdf/All_New_Features_iPadOS_26_Sept_2025_NZ_Final.pdf))
- **Photos:** the photo is the star. Editing controls float around it as glass, and the photo fills the window.
- **Freeform, Keynote, Pages:** the canvas fills the window, and an **inspector on the right** shows formatting for whatever you've selected. It opens from a toolbar button on the right. This is the closest match to Glass Clock: Glass Clock is really an editor with one "document" (your clock).
- In the iPadOS 26 simulator, the widget gallery's sidebar is visibly glass over the wallpaper ([`simulator/04-widget-gallery.png`](simulator/04-widget-gallery.png)).
- **Third-party:** Apple's Liquid Glass gallery (updated April 2026) features apps like Fantastical and Trello ([MacRumors](https://macrumors.com/2026/04/06/apple-liquid-glass-design-gallery-update/)). Pro editors such as Pixelmator Pro and Procreate have long used a canvas with tool panels around it. *I couldn't check these apps' iPadOS 26/27 panels directly, so treat this point as background.*

> **Note on sources:** Apple doesn't have a separate HIG page for inspectors (that address gives "not found"). The inspector guidance above comes from the Split views, Layout and Toolbars pages and from the WWDC25 sessions. I couldn't find a hands-on review of how Files, Photos, Notes and Freeform behave in iPadOS 26/27, so those descriptions are based on Apple's own material, the simulator and general knowledge of the apps.

---

## 2. Three options for Glass Clock

Today the app has the preview and one long settings list side by side (or stacked), with a handle in between and a Layout menu.

### Option A: Sidebar + preview + inspector (the "Keynote / Freeform" layout) ⭐ recommended
- **Left:** a floating glass **sidebar** listing the settings groups: *Clock* (Presets, Font, Text, AM/PM and Date), *Effects* (Glow, Shadow, Card), *Widget* (Clear and Tinted, Applying Changes).
- **Middle:** the **preview** with its backdrop filling the whole window, running under both panels.
- **Right:** an **inspector** with the controls for the group you picked. Tap *Glow* in the sidebar and the Glow controls slide in.
- **Toolbar (top right):** *Apply to Widget*, then a separate button that shows or hides the inspector.

| Where | What happens |
|---|---|
| Full screen, landscape or portrait (13-inch) | All three panes visible |
| Medium windows (Stage Manager, narrower Split View), under 1000 pt | Preview + inspector. The sidebar tucks away, and its button swaps it in for the inspector |
| Narrow windows (compact width) | The sidebar becomes the first screen. Picking a group shows the preview, with settings in a **half-height sheet** so the clock stays visible above it |

**Apple rules it follows:** glass only on the controls layer (sidebar, inspector, toolbar), with no custom glass added; content runs under the panels using the background extension effect; two sidebar levels with headings and symbols; the inspector button on the toolbar's trailing edge; the same features at every size, only arranged differently; system components, so iPadOS 27's new glass, sidebar look and inactive-window dimming come for free.

**Trade-offs:** you see one settings group at a time instead of scrolling through everything. That is calmer, but it takes one more tap to jump between, say, Font and Glow.

### Option B: Preview + inspector only (the "Photos edit" layout)
- No sidebar. The preview fills the window, and an inspector on the right has a **row of icons at the top** (or a picker) to switch between groups.
- **Behaviour:** two panes in full screen and medium windows; a sheet when narrow.
- **Rules:** the same glass and toolbar rules, and simpler. But a row of 9 icons is cramped and harder to read than a labelled sidebar, and it skips the sidebar Apple recommends for moving between areas.
- **Good if** you'd rather keep the clock as big as possible at all times.

### Option C: Sidebar + preview, settings in a floating glass panel over the preview
- The sidebar picks the group; the controls appear on a **custom glass card floating over the preview** (like Photos' editing tools), not in an inspector column.
- **Rules:** this is the riskiest. It means drawing a large custom glass panel ourselves, and Apple asks to "use it sparingly". The panel also covers part of the preview, which defeats the point of a preview.
- **Looks** the most "Liquid Glass", but is more work and harder to keep readable over every backdrop.

---

## 3. Recommendation

**Option A.** It is exactly the pattern Apple describes for iPad in 2025–26 (floating sidebar, edge-to-edge content, inspector on the right). It is built only from standard parts, so it automatically picks up whatever Apple changes in the glass (as iPadOS 27 just did). And it replaces our home-made divider and Layout menu with behaviour people already know from Files, Notes and Keynote.

---

## 4. The prototype

Built on the branch **`panels-prototype`**. `main`, and the app on your iPad, are unchanged.

What changed in the code:
- `ContentView.swift`: the screen is now a `NavigationSplitView` (sidebar + preview) with `.inspector` for the settings. Each settings group's controls are unchanged, just shown one group at a time. The preview's backdrop uses `.backgroundExtensionEffect()` so it carries on under the glass panels. The presets row wraps instead of scrolling sideways.
- `Workspace.swift`: the settings groups (names, icons, footers, sidebar headings) live here. The old Layout menu and drag handle were removed, because the system's sidebar and inspector replace them.
- `GlassClockApp.swift`: a test-only switch (`-screenshotWindow 800x1100`, debug builds only) that draws the app at a smaller size for screenshots.

### Screenshots (iPad Pro 13-inch simulator, iPadOS 26.5)

| File | What it shows |
|---|---|
| [`1-full-screen-text.png`](panel-prototype/1-full-screen-text.png) | Full screen: glass sidebar, preview, inspector showing Text. The Aurora backdrop runs under both panels |
| [`2-full-screen-presets.png`](panel-prototype/2-full-screen-presets.png) | Presets in the inspector, wrapping into rows |
| [`3-full-screen-settings-hidden.png`](panel-prototype/3-full-screen-settings-hidden.png) | Inspector hidden: the preview and its controls widen to fill the space |
| [`4-medium-window-800-inspector.png`](panel-prototype/4-medium-window-800-inspector.png) | An 800 pt-wide window: the sidebar tucks away so the preview keeps its room; the sidebar button sits top left |
| [`5-medium-window-800-sidebar.png`](panel-prototype/5-medium-window-800-sidebar.png) | The same window with the sidebar brought back instead of the inspector |
| [`6-narrow-window-500.png`](panel-prototype/6-narrow-window-500.png) | A 500 pt-wide (narrow) window: settings in a half-height sheet below the clock |

**Honest limits of the screenshots:**
- The simulator wouldn't let me rotate it or resize the window from a script (macOS blocks that without extra permissions), so these are all portrait. Shots 4–6 are **stand-ins**: the app drawn inside a frame of that size on a black background, not a real Stage Manager window. In shot 6 the sheet sits off-centre only because of this; in a real narrow window it rises from the bottom of the window.
- I haven't tried it on your iPad (as asked), so iPadOS 27's new sidebar look isn't shown here.

### Known issues found while building
1. **iPadOS 26 bug:** when a split view has an inspector, the system's own "show sidebar" button disappears once the sidebar is hidden ([Apple Developer Forums thread](https://developer.apple.com/forums/thread/799794), Apple bug FB20061260). The prototype adds its own sidebar button to work around it. Check whether iPadOS 27 fixed this.
2. The split view ignores a request to hide the sidebar while it is first appearing, so the prototype makes that change a moment later. Harmless, but it's a workaround.
3. Swiping in from the left edge to bring the sidebar back should work (it is the system's), but I couldn't test gestures in this run.

### If you like it, next steps
1. Try it on the iPad: in full screen, in a Stage Manager window you drag to different sizes, and with the new glass slider in Settings at both ends.
2. Decide whether the sidebar should also show a small summary under each group (e.g. "Roboto Flex · Heavy").
3. Update `DESIGN_SYSTEM.md` §4 and §6.3b–c to describe the new layout, then merge the branch into `main`.
