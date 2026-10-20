# Liquid Glass reference study

Screenshots taken on 2026-10-20 in the iPadOS 26.5 simulator (iPad Pro 13-inch), plus Apple's official reference images from the Human Interface Guidelines. The Apple images are linked, not copied.

## 1. Observed in iPadOS 26.5 (`simulator/`)

| File | What it shows | What we learn |
|---|---|---|
| `01-home-default-light.png` | Home Screen, Default style | The **Dock** is Liquid Glass: a rounded pill that bends the wallpaper's blues, with a thin bright rim |
| `03-edit-menu-glass-popover-and-keyboard.png` | Long-press → Edit menu | The **popover menu** is regular glass. The Contacts icon underneath is visibly blurred and refracted. The keyboard is glass too. The Edit/Done buttons are small glass capsules |
| `04-widget-gallery.png` | Add Widget sheet | **Glass only on the navigation layer.** The sidebar floats as glass (the wallpaper's teal shows through its bottom) while the content area is solid. This is the HIG's "controls float above content" rule in practice |
| `05-gallery-glass-clock.png` | Our widget in the gallery | Our description and preview render correctly. Settings from the app reach the widget (App Group works) |
| `06-home-with-widget-light.png` | Our widget, Default style | Widget placed; the curved handle at its corner = drag to resize |
| `07-customise-panel.png` | Customise sheet | A large glass sheet. Big glass surfaces get more opaque so text on them stays readable |
| `08-home-clear-mode-widget.png` | **Clear** style | iPadOS replaces our background with real Liquid Glass. **Text goes white; our text and card colours are ignored; font weight/width are kept.** App icons also become clear glass |
| `09-home-tinted-mode-widget.png` | **Tinted** style | The widget takes the person's tint colour (deep blue here), with white text, matching the system icons |
| `10-home-dark-mode-widget.png` | **Dark** style, before the fix | ❌ The red card mixed with dark grey and came out **muddy brown** (it was peach in Light mode) |
| `12-home-widget-colour-fixed.png` | After the fix | ✅ The card colour now shows at full strength |
| `11-lock-screen-clock.png` | **Lock Screen clock** | The digits themselves are glass: each one refracts the wallpaper (the "3" shows blue, the "1" teal), with a bright edge highlight. Heavy, rounded numerals; date small above |
| `02-control-center.png` | Control Center | ⚠️ The simulator doesn't draw the Control Center controls. Check this on a real iPad |

## 2. Apple's official reference images (HIG)

View these directly; they're Apple's copyright, so they're not saved here.

| Image | Observation |
|---|---|
| [Regular glass over a light background](https://developer.apple.com/tutorials/images/com.apple.HIG/materials-ios-liquid-glass-over-light@2x.png) | Heavy blur and lightening: details become soft colour. A hairline bright rim, with slight bending at the edges. This is the variant to use behind text |
| [Regular glass over a dark background](https://developer.apple.com/tutorials/images/com.apple.HIG/materials-ios-liquid-glass-over-dark@2x.png) | The same material darkens over dark content. It adapts; it has no fixed colour |
| [Clear glass](https://developer.apple.com/tutorials/images/com.apple.HIG/materials-ios-liquid-glass-clear@2x.png) | Much lighter blur, so background detail stays readable. Only for rich media, and it needs a dimming layer when text sits on it |
| [Stocks widget, full colour](https://developer.apple.com/tutorials/images/com.apple.HIG/widgets-stocks-default@2x.png) | **Plain opaque background.** Apple doesn't fake glass in full-colour widgets |
| [Stocks widget, clear](https://developer.apple.com/tutorials/images/com.apple.HIG/widgets-stocks-clear@2x.png) | System glass, all content white, **secondary text dimmer** ("Apple Inc.") to keep hierarchy, and a large light-weight number. Very close to our clock's structure |
| [Stocks widget, tinted](https://developer.apple.com/tutorials/images/com.apple.HIG/widgets-stocks-tinted@2x.png) | Tint replaces the background; content is white |

## 3. Conclusions for Glass Clock

1. **Our widget behaves exactly as Apple intends.** Clear and Tinted modes look native with no extra code. ✅
2. **Full-colour mode should be bold and solid,** like Apple's Stocks widget, not a weak imitation of glass. Fixed: the card colour now renders at full strength, with only a soft top highlight. ✅
3. **Keep the date dimmer than the time** (we use 85% opacity). Apple's Stocks widget does the same, and it survives Clear mode. ✅
4. **The Lock Screen's glass digits can't be reproduced exactly in a widget**, because a widget can't bend the wallpaper behind it. Since 2026-10-20 we imitate them (lit edges, see-through body, shadow), and in Clear/Tinted mode build the glass from transparency alone, since the system replaces our colours there. (A full-colour image to keep our colours left the widget blank on iPadOS 27.) In the App Store description, "Lock Screen–style glass clock" is fair; claiming the digits refract the wallpaper is not.
5. **Idea for v1.1:** add a **Rounded** font option (SF Pro Rounded). The Lock Screen numerals are rounded, and it's a one-line change (`UIFontDescriptor.withDesign(.rounded)`).
6. **To check on a real iPad:** Control Center, plus how the widget's glass reacts when the iPad is tilted (the simulator can't show motion).
