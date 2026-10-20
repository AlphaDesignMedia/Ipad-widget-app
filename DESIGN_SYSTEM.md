# Glass Clock Design System

**Purpose:** a single reference that keeps Glass Clock in line with Apple's Human Interface Guidelines (HIG) and makes sure its Liquid Glass is built the way Apple intends.
**Applies to:** iPadOS 26+, SwiftUI, WidgetKit · **Last checked against Apple docs:** 2026-10-20

Every rule here links back to an Apple source (§12). Code samples match what's in the repo; file names are linked.

---

## 1. The one thing to understand first

There are **two different "glasses"** in this project, and they work differently:

| Where | Who draws the glass | How |
|---|---|---|
| **The app** (preview card) | We do | SwiftUI `glassEffect(_:in:)` |
| **The widget** on the Home Screen | **iPadOS does** | When the person picks the *Clear* or *Tinted* Home Screen style, the system removes our background and replaces it with real Liquid Glass |

A widget **cannot** draw its own Liquid Glass. Widgets are rendered ahead of time and never see the wallpaper behind them, so there's nothing for the glass to blur or refract. Apple's docs say that in Clear/Tinted mode the system *"removes the background and replaces it with a themed glass or tinted color effect."*

So our job in the widget is to:
1. Put our background inside `containerBackground(for: .widget)` so the system can remove it.
2. Make the clock look right once the system tints everything white (the **accented** rendering mode).
3. Offer a good full-colour design for the Light and Dark Home Screen styles.

---

## 2. Liquid Glass: Apple's rules

From HIG → Materials and the SwiftUI docs:

1. **Glass is for the controls and navigation layer, not content.** It *"forms a distinct functional layer for controls and navigation elements… that floats above the content layer."* Content uses the standard materials (`.ultraThinMaterial`, `.regularMaterial`, …).
2. **Use it sparingly.** Limit it to *"the most important functional elements."* System controls (sliders, toggles, segmented pickers, toolbars) already pick it up automatically, so don't add it to them.
3. **Two variants:**
   - `.regular` blurs and adjusts luminosity to keep text legible. Use it by default and whenever there's text.
   - `.clear` is highly translucent. Use it *only* over rich media (photos or video), and add a **dimming layer** (about 35% black) behind it when the background is bright.
4. **Colour on glass sparingly.** `tint(_:)` gives a stained-glass look meant for emphasis, such as a primary action. *"Refrain from adding color to the background of multiple controls."*
5. **Group nearby glass** in a `GlassEffectContainer`. It renders faster, and shapes can blend and morph.
6. **Apply `glassEffect` last**, after the modifiers that affect appearance (padding, frame, font).
7. **Performance:** limit how many glass effects are on screen at once.
8. **Accessibility is automatic.** Glass adapts to *Reduce Transparency*, *Increase Contrast* and the person's chosen glass look. Don't fight it.

### The SwiftUI API in one place

```swift
// Default: regular glass in a capsule, drawn behind the view's content
Text("Hello").padding().glassEffect()

// Shape, tint, interactivity
.glassEffect(.regular, in: .rect(cornerRadius: 28))
.glassEffect(.regular.tint(.orange))
.glassEffect(.regular.tint(.orange).interactive())   // reacts to touch, for custom controls

// Clear glass needs a dimming layer over bright content
Label("Flag", systemImage: "flag.fill")
    .padding()
    .glassEffect(.clear)
    .background(.black.opacity(0.3))

// Turn glass off without restructuring the view
.glassEffect(.identity)

// Several glass shapes near each other
GlassEffectContainer(spacing: 20) {
    HStack(spacing: 20) {
        Image(systemName: "pencil").frame(width: 44, height: 44).glassEffect()
        Image(systemName: "eraser").frame(width: 44, height: 44).glassEffect()
    }
}

// System buttons
Button("Share") { }.buttonStyle(.glass)
Button("Done") { }.buttonStyle(.glassProminent)
```

---

## 3. Examples to study

**Apple's own (look at these on your iPad):**
- **Lock Screen clock.** The big time refracts the wallpaper and resizes to sit behind the photo's subject. It's our main inspiration, but third-party apps can't reproduce it (see §6).
- **Home Screen in Clear mode** (long-press → Edit → Customize → Clear). This is exactly what our widget will look like there. Compare Apple's Clock, Weather and Calendar widgets.
- **Control Center and the Dock.** Glass as the functional layer floating over content.
- **Music / Photos.** Toolbars and tab bars in glass over rich content. Note how little colour is used on the glass.

**Third-party apps Apple has showcased:** Apple's Liquid Glass design gallery (updated April 2026) features AllTrails, Carrot Weather, Fantastical, Trello and others. 9to5Mac's roundups list more, including **Widgetsmith**, which is the closest comparison to Glass Clock.

**Code to read:** Apple's *Landmarks: Building an app with Liquid Glass* sample project, and the WWDC25 sessions *Meet Liquid Glass* (219), *Get to know the new design system* (356) and *What's new in widgets* (278).

---

## 4. Layer map: where glass goes in Glass Clock

```
┌─ App ──────────────────────────────────────────────┐
│  Preview area (content layer: colourful gradient)  │
│     "Preview" label                                │
│     ┌───────────────┐  ← Clock card: our glass     │
│     │  Tue 20 Oct   │    (.regular, optional tint) │
│     │    3:18       │    OR solid colour           │
│     └───────────────┘                              │
│     [Small|Medium|Large|XL] ← system segmented     │
│                              control (auto glass)  │
│  Settings Form (content layer: no custom glass)    │
│     sliders, swatches, toggles ← system controls   │
└────────────────────────────────────────────────────┘

┌─ Widget (Home Screen) ───────────────┐
│  containerBackground ← ours in Light/Dark;        │
│                        system glass in Clear/Tinted│
│  ClockFace (time = accent group)                  │
└──────────────────────────────────────┘
```

**Rule of thumb:** the clock card is the **only** custom glass in the app. Everything else is a standard control and gets glass from the system.

**Known deviation, and why it's acceptable:** the HIG says not to use glass in the content layer. The preview card is technically content, but it is a stand-in for the widget, which iPadOS really does render as glass in Clear mode. Showing it as glass previews that look accurately. It's a single element, so the "sparingly" rule holds.

---

## 5. Design tokens

### 5.1 Colour

| Token | Value | Used for | Rule |
|---|---|---|---|
| `text.auto` | `.primary` | Clock text by default | Adapts to light/dark automatically |
| `text.palette` | white, black, red, orange, yellow, green, mint, blue, purple | User text colour | System colours, so they adapt to Increase Contrast |
| `card.auto` | untinted `.regular` glass / `systemBackground` | Default card | — |
| `card.palette` | same palette | Glass tint or solid fill | One tinted element only |
| `widget.base` | `secondarySystemBackground` | Frosted widget base | Light in light mode, dark in dark mode (HIG: Widgets → Full-color) |
| `preview.backdrop` | plain white | Behind the preview | A neutral backdrop, so the card isn't coloured by what's behind it (changed 2026-10-20 from a rainbow gradient) |

Source: [ClockStyle.swift](Shared/ClockStyle.swift)

```swift
enum ClockColor: String, Codable, CaseIterable, Identifiable {
    case auto, white, black, red, orange, yellow, green, mint, blue, purple
    var color: Color {
        switch self {
        case .auto: .primary
        case .white: .white
        // … system colours only
        }
    }
}
```

### 5.2 Typography

| Token | Font | Notes |
|---|---|---|
| `clock.time` | SF Pro, SF Rounded, Roboto Flex or Google Sans Flex: variable **weight** and **width** (plus **roundness** for Google Sans Flex), all as 0–1 sliders where 0.5 is regular/normal. **Height** stretches vertically; **Spacing** tracks the digits | Drawn as outlines and fitted to the card (see §6.1). Sized from tabular zeros, so it doesn't grow and shrink as the minutes change |
| `clock.detail` | Same font, lighter, normal width, capitals, letter-spaced 0.12 em; cap height 15% of the digits | AM/PM and the date. Beside: 24% of the digit height, top-aligned. Stacked: two capitals filling the digit height |
| `ui.*` | System text styles (Form defaults) | Supports Dynamic Type automatically |

**Bundled fonts.** Roboto Flex and Google Sans Flex come from Google Fonts under the SIL Open Font License 1.1 (free to use and ship; the licence files sit next to the fonts in `Shared/Fonts`). Roboto Flex also has a figure-height axis, but its range is small (738 → 788 units), so the Height slider stretches instead. Google Sans Flex's Roundness axis gets closest to the Lock Screen numerals.

The HIG notes SF is a variable font that *"supports interpolation between styles to create intermediate ones."* That's what lets our sliders be continuous rather than stepped:

```swift
func font(size: CGFloat) -> Font {
    let uiFont = UIFont.systemFont(
        ofSize: size,
        weight: UIFont.Weight(CGFloat(weight)),   // any value in -0.8…0.62
        width: UIFont.Width(CGFloat(width))       // any value in compressed…expanded
    )
    return Font(uiFont)
}
```

### 5.3 Spacing, shape and size

| Token | Value | Source |
|---|---|---|
| `widget.margin` | 16 pt (system default content margins) | HIG: Widgets → *"standard margin width… 16 points"* |
| `widget.margin.tight` | 11 pt | HIG: allowed for grouped graphics |
| `widget.corner` | `ContainerRelativeShape()` | HIG: match the widget's own corner radius |
| `preview.corner` | 28 pt | Close match to the iPad widget corner |
| `preview.padding` | 16 pt | Mirrors `widget.margin` |
| `control.minTarget` | 44×44 pt (28×28 absolute minimum) | HIG: Accessibility |
| Swatch | 34 pt visible circle inside a 44×44 pt tap target | HIG: Accessibility |

**Widget sizes on the 13-inch iPad canvas** (HIG specifications, used by the preview):

| Small | Medium | Large | Extra large |
|---|---|---|---|
| 170×170 | 378.5×170 | 378.5×378.5 | 795×378.5 |

---

## 6. Components

### 6.1 `ClockFace`: shared by app and widget

[ClockFace.swift](Shared/ClockFace.swift). One view draws the clock everywhere, so the preview and the widget can't drift apart.

The time is **drawn as a shape, not `Text`**. `GlyphLine` turns the string into one vector outline with Core Text; `ClockArtwork` lays out the time and its detail line and fits them into the card together.

- **Why:** SwiftUI draws large text in tiles and works out inner shadows tile by tile, which left straight seams across the glass digits. *Reproduced 2026-10-20; the same style on an outline has none.*
- **Optical centring:** the group is centred on its visible ink, not the text's line box (which reserves room for descenders that digits don't have). Colons are moved to the vertical middle of the digits.
- **Breathing room:** the group fills 92% of the space inside the 16 pt margin.
- **Overlaps:** outlines are merged (`CGPath.normalized()`), so tight spacing never draws overlapping digits darker.
- **Light effects** are their own layers: *Glow* (blurred copies in the text colour or a chosen colour) or *Shadow* (a blurred copy pushed down; black by default, white for a light shadow). *Inner colour* is separate again: a colour glowing inward from the edges, which used to happen only as a side effect of the glow showing through glass.
- VoiceOver reads the time from `accessibilityLabel`, since the outline has no text.

**Why `widgetAccentable()` on the time only:** in accented mode the system treats views like template images (it ignores their colour and uses only their alpha) and tints the accent and primary groups separately. Making the time the accent group and the date the primary group keeps a visual hierarchy, even when everything turns white.

### 6.2 `ClockCard`: the app's preview card

```swift
struct ClockCard<S: Shape>: ViewModifier {
    var style: ClockStyle
    var shape: S

    func body(content: Content) -> some View {
        switch style.background {
        case .glass:
            // Glass sits behind the text so the text keeps its exact colour.
            content.background {
                ZStack {
                    if style.usesClearGlass { shape.fill(.black.opacity(0.2)) }   // dimming layer
                    Color.clear.glassEffect(style.glass, in: shape)
                }
            }
        case .solid:
            content.background(style.solidFill.opacity(style.cardOpacity), in: shape)
        }
    }
}

extension ClockStyle {
    var glass: Glass {
        guard cardOpacity > 0 else { return .identity }
        let base: Glass = usesClearGlass ? .clear : .regular      // clear below 40%
        guard let cardTint else { return base }
        return base.tint(cardTint.opacity(0.15 + 0.35 * cardOpacity))
    }
}
```

**Technical notes:**
- **The Transparency slider changes the glass itself, not its `opacity`.** 0 = no card (`.identity`), under 40% = `.clear` with a 20% black dimming layer (HIG: Materials), otherwise `.regular`. Fading a glass view with `.opacity()` isn't how Apple's API is meant to be used, and it loses the rim and refraction.
- **Tint tops out at 50%.** A full-strength tint (the old code) made the card look like flat paint. At 15–50% the gradient behind still shows through, which is the "stained glass" look Apple describes for `tint(_:)`. *Observed 2026-10-20 in the simulator.*
- **`.regular` for most of the range.** The card carries text, and `.regular` is what Apple specifies for that.
- **Glass goes in `.background`, not on the text.** Applying `glassEffect` directly to the text gives the text the glass's vibrant treatment, which washed out custom colours in testing (teal turned murky). Putting the glass in a background layer keeps the user's exact colour.
- **One glass element, so no `GlassEffectContainer` is needed.** Add one if more glass elements are ever placed next to the card.
- **Not `.interactive()`.** The card can't be tapped, and Apple reserves interactive glass for controls.

**Liquid Glass text** (`TextFill.glass`, shared by the app and widget): widgets can't put real glass on text, so it's imitated, modelled on the iPadOS 26 Lock Screen clock:
- **Body:** a see-through gradient of the chosen colour (white for Automatic) at 18–50% opacity.
- **Edges:** `ShapeStyle.shadow(.inner(...))` gives a crisp white rim on the upper-left edges, a darker edge on the lower right where glass bends light away, and a soft glow inside.
- **Rim:** a stroke clipped to the inside of the outline, bright at the upper left and lower right.
- **Shadow:** now the optional Shadow light effect rather than built in. A `.drop` shadow on the fill itself is drawn from the fill's own low opacity, so it was nearly invisible (*observed 2026-10-20*); the effect is a separate blurred copy instead.
- **Light vs dark:** the dark edge and shadow are stronger on light glass, where a white rim alone disappears.
- Looks best at heavier weights, like the Lock Screen numerals.

### 6.3 Widget background

[GlassClockWidget.swift](GlassClockWidget/GlassClockWidget.swift)

```swift
clock   // ClockFace, or an image of it in Clear/Tinted mode (below)
    .containerBackground(for: .widget) {
        switch entry.style.background {
        case .glass: GlassCardBackground(tint: entry.style.cardTint, strength: entry.style.cardOpacity)
        case .solid: entry.style.solidFill.opacity(entry.style.cardOpacity)
        }
    }
```

`GlassCardBackground` is **mostly transparent**: a light wash of the card colour (5–25%), a bright rim that's strongest at the top-left and bottom-right corners, and a soft glow just inside the edge, modelled on Apple's glass shapes. It does *not* call `glassEffect`, because a widget has no wallpaper to sample (§1).

> **Observed 2026-10-20 (simulator):** when the widget background is see-through, iPadOS draws its own frosted glass behind it in the Light and Dark styles. So the card really is system glass in every Home Screen style, with our rim and wash on top.

**Glass text in Clear and Tinted mode.** In `accented` mode the system replaces every colour with its own and keeps only how see-through each part is. So `ClockFace` switches the glass text to a version built from transparency alone: a frosted body (22–50%), a solid rim and a soft inner glow. It leaves out the dark edge and the shadow layer, which would turn into extra pale edges and a halo. The digits still read as glass; the user's text colour doesn't carry over.

> **Observed 2026-10-20 on an iPad running iPadOS 27.0.1:** an earlier version drew the clock into a full-colour image (`ImageRenderer` + `.widgetAccentedRenderingMode(.fullColor)`) to keep our colours in these modes. It worked in the iPadOS 26.5 simulator, but left the widget completely blank on the real iPad. Don't reintroduce it without testing on a device.

**Rendering-mode behaviour:**

| Home Screen style | Rendering mode | What the person sees |
|---|---|---|
| Light | `fullColor` | System light glass + our rim/wash, our clock |
| Dark | `fullColor` | System dark glass + our rim/wash, our clock |
| Clear | `accented` | System clear glass; clock in white, glass text as frosted glass |
| Tinted | `accented` | System tint; clock in the tint, glass text as frosted glass |
| Lock Screen (not supported in v1) | `vibrant` | — |

If we ever need a different layout per mode:

```swift
@Environment(\.widgetRenderingMode) private var renderingMode
// switch renderingMode { case .fullColor: … case .accented: … default: … }
```

### 6.4 Settings controls

Use **standard** SwiftUI controls inside a `Form`: `Slider`, `Toggle`, `Picker(.segmented)` and plain `Button`s for the swatches. They get Liquid Glass when someone touches them, plus full accessibility behaviour, for free. **Don't** add `glassEffect` to them.

---

## 7. Copy

- **Widget gallery description** starts with a verb and doesn't say "this widget": *"See the time in the style you design in the Glass Clock app."* (HIG: Widgets → Previews)
- Sentence-style capitalisation everywhere.
- The in-app help explains that iPadOS takes over styling in Clear/Tinted mode, so people aren't surprised.

---

## 8. Accessibility

| Requirement | How we meet it | Status |
|---|---|---|
| Text contrast ≥ 4.5:1 (small text) or ≥ 3:1 (large or bold) | The large time passes with most combinations, but users can pick clashing colours (e.g. white on white) | ⚠️ To do: show a "low contrast" hint in the app |
| Reduce Transparency / Increase Contrast | System glass and system colours adapt automatically | ✅ |
| Dynamic Type | Date and UI use text styles. The time scales to fit by design | ✅ |
| VoiceOver | Real `Text` views (no rasterised text), swatches have labels | ✅ |
| Tap targets ≥ 44 pt | Form rows, segmented control, swatch row | ✅ |
| Meaning not conveyed by colour alone | Colour is decoration only | ✅ |

---

## 9. App icon

- Build it in **Icon Composer** (included with Xcode 26) from layered vector artwork. The system adds the glass highlights, refraction and shadows, so **don't** bake them in.
- Provide **default, dark and mono (tinted)** variants.
- A square, unmasked canvas. No text, no screenshots of the UI.
- Idea: a simple clock-hand or "colon" glyph on a coloured gradient background layer.

---

## 10. Compliance checklist

| # | Rule | Status |
|---|---|---|
| 1 | Widget background inside `containerBackground(for: .widget)` | ✅ |
| 2 | No `glassEffect` inside the widget | ✅ (fixed 2026-10-20; glass is faked with shapes and shadows) |
| 3 | Time marked `widgetAccentable()` | ✅ |
| 4 | Full-colour design adapts to light and dark | ✅ (system glass behind a see-through card; glass text adapts) |
| 5 | One custom glass element in the app; `.regular` variant | ✅ |
| 6 | Glass applied as a background, after layout modifiers | ✅ |
| 7 | Preview sizes match the HIG iPad specs | ✅ (fixed 2026-10-20) |
| 8 | Preview labelled so it isn't mistaken for a real widget | ✅ (added 2026-10-20) |
| 9 | Widget description follows HIG copy rules | ✅ (fixed 2026-10-20) |
| 10 | Text ≥ 11 pt in widgets | ✅ |
| 11 | Low-contrast colour warning | ⬜ To do |
| 12 | Check Clear and Tinted mode | ✅ Simulator, 2026-10-20 (see References/). ⚠️ Real iPad (iPadOS 27): Tinted blank with the image approach, fixed; recheck |
| 14 | Full-colour card colour shows true (not muddy) in Light and Dark | ✅ (fixed 2026-10-20) |
| 13 | App icon from Icon Composer with dark/mono variants | ⬜ To do (milestone M3) |

### Accepted deviations

- **Glass on the preview card (content layer).** It previews the system's Clear-mode look. See §4.
- **A per-minute timeline instead of a system-updating date `Text`.** The HIG prefers letting the system refresh times, but its built-in time style can't apply our 12/24-hour and AM/PM settings. One entry per minute is the standard workaround and is cheap.

---

## 11. Testing matrix (before each release)

For each widget size (S, M, L, XL), check: **Light**, **Dark**, **Clear**, **Tinted**, plus **Reduce Transparency** on, **Increase Contrast** on, and the heaviest/widest and thinnest/narrowest font settings.

---

## 12. Sources

- [HIG: Materials (Liquid Glass)](https://developer.apple.com/design/human-interface-guidelines/materials)
- [HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)
- [HIG: Color (Liquid Glass color)](https://developer.apple.com/design/human-interface-guidelines/color)
- [HIG: Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [HIG: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [Glass](https://developer.apple.com/documentation/swiftui/glass) · [Glass.clear](https://developer.apple.com/documentation/swiftui/glass/clear)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Optimizing your widget for accented rendering mode and Liquid Glass](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass)
- [Displaying the right widget background](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)
- [Preparing widgets for additional contexts and appearances](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances)
- [WidgetRenderingMode](https://developer.apple.com/documentation/widgetkit/widgetrenderingmode) · [widgetAccentable(_:)](https://developer.apple.com/documentation/swiftui/view/widgetaccentable(_:))
- WWDC25: [Meet Liquid Glass (219)](https://developer.apple.com/videos/play/wwdc2025/219) · [Get to know the new design system (356)](https://developer.apple.com/videos/play/wwdc2025/356) · [What's new in widgets (278)](https://developer.apple.com/videos/play/wwdc2025/278)
- Examples: [MacRumors on Apple's updated Liquid Glass gallery](https://macrumors.com/2026/04/06/apple-liquid-glass-design-gallery-update/) · [9to5Mac: apps with Liquid Glass designs](https://9to5mac.com/2025/09/26/these-30-apps-feature-a-new-liquid-glass-design-for-ios-26/)
