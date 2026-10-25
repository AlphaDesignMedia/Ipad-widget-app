# Ideas

Every idea you've shared across our chats, with where each one stands. I keep this up to date
and bring up the open ones when they fit what we're working on.

**Status:** ✅ done · 🟡 started or partly done · ⬜ not started · 💤 parked by you

_Last updated 21 Oct 2026._

## In focus now

- [ ] **Theme colour on the widget's outlines** (owner, 25 Oct 2026, message cut off mid-sentence): the backdrop's colour carried into the edges of the bubbles around the widget (only those), in Light and maybe Dark. Small: tint the new hairline edge with the backdrop's colour. Waiting until after the friend test.
- [ ] **Your own two-tone theme** (owner, 25 Oct 2026): pastels in Light and deeps in Dark now mirror each other automatically; next, let people pick their own colour pair, like Google's one-colour and two-colour themes.
- [ ] **"Your colour" as a headline feature** (owner, 25 Oct 2026). One plan, four parts:
  1. The tour asks for your favourite colour and sets it up.
  2. One clear switch: "Use my colour everywhere" (panels, glass tint, backdrops, buttons).
  3. A clear on/off for the glass override (colour and gradients on glass), shown as a feature, not hidden.
  4. Any colour allowed: "Adjust for contrast" (now in App look, on by default) plus Outline everything as the escape hatch for out-of-range picks. Next: suggest an outline automatically when a pick is low-contrast.
- [ ] **Preview vs real widget, shadows and Tinted** (owner, 25 Oct 2026): improve the shadows in the preview and the widget, and match the preview to reality, especially on Tinted. Either warn when a setting goes past what Tinted can show, or cap it there. Needs side-by-side iPad screenshots first.

| Idea | Status | Notes |
|---|---|---|
| Glass theme: every box is its own layer of glass on top of the panel | 🟡 | First version is on the iPad. Needs your eye. |
| Corners that line up: inner boxes rounded to fit inside the panel's curve | 🟡 | Panel 34, gap 12, cards 22. Tweak after seeing it. |
| Spacing and padding pass across the whole app | 🟡 | You'd like to push things around yourself. See "Design tools" below. |
| Glass amount slider (Frosted ↔ Clear) | ✅ | Widget section → App look, only in the Glass theme. |
| Pills for section titles, effects and card chips | ✅ | |
| Keep contrast and readability while going "super glassy" | 🟡 | Keep checking in Light and Dark. |

## Design and look

| Idea | Status | Notes |
|---|---|---|
| Liquid Glass on the clock text itself, plus a gradient option | ✅ | |
| Taller font options; free variable fonts with pairings | ✅ | |
| Expand the fonts a little and think more about theming | ⬜ | |
| Your favourite font, AM/PM style and effect as defaults | ✅ | |
| App themes (Glass, Frosted, Colour), app colour, Light/Dark | ✅ | |
| **Glass transitions** like unlocking the iPad or pulling down Notification Centre (blur and refraction sweeping across) | 🟡 | First version on backdrop changes, 21 Oct: the old backdrop lifts off with a glass edge. Check the feel on the iPad. Your idea, 21 Oct. Lean into glass. Ask you to confirm a reference first. |
| Change the app's overall font slightly | ⬜ | Ask which feel you want (rounded, condensed, serif headings). |
| Section titles tucked inside their boxes; a more spacious layout | ✅ | 21 Oct. Keep refining with references. |
| Light/Dark/Clear/Tinted options with tiny icons | ✅ | Our own drawing. A proper logo may come later. |
| **Contrast always comes first**: glass is a fun effect, never unreadable | 🟡 | Contrast wash behind the glass, lighter tints in Dark. 21 Oct: checked the bubbles on all 14 backdrops (fine); preset chips now white text in Dark. Open: white status bar on pale Dune/Glow. |
| Style and size controls float with the widget as you move it | ✅ | 21 Oct, Panels only. Bigger style icons too. |
| Glass that bends the clock and text around its edges, or moves with motion | ⬜ | You liked a glimpse of this. Shimmer was ruled out (it would freeze the widget). |
| **Background generator**: one or two sliders make a unique abstract glass backdrop, plus Lucky | ⬜ | Your idea from 21 Oct. Doable with shaders. A good next big feature. |
| Preset photo backdrops in the spirit of Apple's wallpapers | 🟡 | Gradient backdrops exist. Real photos not yet (the Earth photo needs the file). |
| Apple-style mesh backdrops | ✅ | 21 Oct: Bloom, Dune, Lagoon, Midnight, Glow. |
| Themed I'm Feeling Lucky presets that feel more curated | 🟡 | Split into Lucky Colours and Lucky Style. More theming could help. |

## Layout and gestures

| Idea | Status | Notes |
|---|---|---|
| Move the folded rail anywhere (owner, 25 Oct 2026) | 💤 | Today it snaps to the nearest edge (top, bottom, left, right). Owner would like to place it freely, not only on an edge. Not urgent. |
| Rail cards that swap sides (owner, 25 Oct 2026) | 💤 | From trying the rail card: tapping on the other side sent the card into the other panel, which clashed a little but felt great. Worth an alternative layout where cards can live on either side. |
| Rail stays put when the iPad turns (owner, 25 Oct 2026) | ✅ | 25 Oct. Only the folded rail does it. It stays on its edge of the iPad; turned so that edge is the top or bottom, it lies flat with the names the right way up, and the group card opens above or below it. Not yet tried on the iPad. |
| Put the rail along the top or bottom by choice (owner, 25 Oct 2026) | ✅ 25 Oct | Not only when the iPad turns: drag or pick where the folded rail lives, top, bottom or either side. Uses the flat rail just built. |
| Anchor the group card to the clock widget (owner, 25 Oct 2026) | 💤 | The card a rail heading opens could sit on the widget instead of by the rail: under it, above it, maybe either side, as tried before. Idea first, details later. |
| Flick through the rail's group cards (owner, 25 Oct 2026) | 💤 | Push the open card up and the next group starts to show under it; let go and it springs elastically onto the next one, like flicking pages. Down goes back. A tall card scrolls first and only pages once you reach its end. |
| Rail truly holds still while the iPad turns (owner, 25 Oct 2026) | 💤 | Refines the rotation build: during the turn the rail shouldn't spin with the screen at all; it stays put, the rest turns round it, then its icons ease upright and the card pops out from its side (or wherever fits). Why it matters: someone turning the iPad to read the sideways names should feel it was made for them. Parked 25 Oct: the counter-rotation would cost a lot for now; revisit once the quicker layout ideas are in. |
| Proper portrait layout for Panels, like Classic (owner, 25 Oct 2026) | 🟡 25 Oct: hold the rail and drag it to any edge; at the top or bottom it lies flat and the preview moves clear of it. It feathers out and fades in at its new place. Not yet tried on the iPad; iPhone still to do. | In portrait with an extra large widget, the menu squeezes to the left and is too small. Instead, grab the folded rail and pull it anywhere; pulled to the bottom it docks flat under the widget, as in Classic. The same layout should suit iPhone. |
| Tinted mode: folded-left cards lose their glass (owner, 25 Oct 2026) | 💤 | In Glass mode the cards beside the collapsed left menu look right; in Tinted they get a plain background and lose the effects. Make them match, and maybe keep the backed version as an accessibility setting. Squash later. |
| Widget steps aside when a rail card pops out (owner, 25 Oct 2026) | 🟡 25 Oct: built; the widget slides away from the card's edge with the card's spring, kept on screen, and comes back when it closes. Its grid place doesn't change. Not yet tried on the iPad. | The pop-out card stays, and the widget slides out of its way with the same spring. So you can still see the widget: that's the point. Try it against sending the menu to the side like Classic in portrait. |
| Rail card: wider, and fits with the rest (owner, 25 Oct 2026) | 💤 | The Liquid Glass card looks lovely but feels narrow beside the rest of the layout. Work out a width that fits. |
| Grab the rail card and move it aside (owner, 25 Oct 2026) | 💤 | As the menu moves in Classic, you could just pick the open card up and put it to one side. Beautiful interactions within a simple app. |
| Light mode: shadows and text readability (owner, 25 Oct 2026) | 💤 | Card shadows look good but want a little feathering, like the widget's background, spilling out past the sides. Not white on panels. The real issue is readable text on light panels and light Home Screens (most people's), above all in full Glass. A pure black feather looks blurry and wrong; a pure white one is a known don't. Research how others keep glass text readable before building. Parked: looks only, nothing broken. |
| **Light-mode shadow in your favourite colour** (owner, 25 Oct 2026) | ⬜ | A soft glow tinted by the colour picked in the app, rather than grey. Claude's take: lovely as a light glow, but a strongly coloured shadow can make text look blurry, the problem we just fixed. So keep it pale, and keep it a choice, with neutral as the fallback. Fits the Figma tokens work (shadow colour becomes a token). |
| **Ask for a favourite colour when the app is first opened** (owner, 25 Oct 2026) | ⬜ | One friendly, skippable question in the first-run tour (Onboarding.swift). It sets the app colour, and the light-mode glow above if that's built. Do it after the stable build. |
| Phone-size layout (owner, 25 Oct 2026) | 💤 | Getting there but not right yet. Parked until the iPad layouts settle. |
| Classic (simple) and Panels (customisable) interfaces, quick switch | ✅ | Classic stays plain and functional. |
| Smooth animation between Classic and Panels: panels glide and reshape instead of jumping | ⬜ | For the future. |
| Left panel jumps to and highlights a group in the right list | ✅ | |
| Collapsible icon sidebar; double-tap hides both panels | ✅ | |
| Pinch the clock to change widget size | ✅ | |
| Pinch to change text size (with a bubble) | ✅ | |
| Drag the widget around a Home Screen grid | ✅ | |
| Lean further into gestures generally | 🟡 | Ongoing. |
| **Guiding principle:** "anything you feel you could do, you can do". Small, lovely interactions | 🟡 | Your direction, 21 Oct. Use it to judge every new feature. |
| Smooth, non-jittery pinch and drag of the widget | 🟡 | Fixed 21 Oct. Now leans softly into the drag (a gentle, fabric-like push and pull) and springs back. Check the feel. |
| Move the widget anywhere on the full screen, like a real Home Screen, not only inside the preview area | ✅ | 21 Oct, Panels. The grid covers the whole window; putting the widget under a panel tucks that panel away. Opens neatly between the panels each time. |
| Use the available space well, with nice padding | 🟡 | Part of the spacing pass. Classic's top gap evened to 16 pt (21 Oct). |
| Resizing feels a bit buggy | ⬜ | Low priority. |
| Remove icons that don't do anything | ✅ | |
| **Analog clock** with the same glass, colours and effects as the digital one | ✅ | 21 Oct. Layout → Digital/Analog. Weight sets how bold the hands are. |
| **Home Screen-style edit mode**: long-press makes the widget wiggle, then drag it or pull a corner handle to resize | ✅ | 21 Oct, Panels. Hold the widget, drag the round corner handle to resize, tap Done or anywhere else to finish. |
| **Pull to change backdrop**: the next backdrop follows your finger with a bending-glass edge and an elastic snap; let go early to cancel | 🟡 | In progress, 21 Oct. Feel matters more than look. |
| Better font pairings, researched from real clock and watch designs | ⬜ | Research and suggestions to come. |
| Softer, smoother wiggle and soft highlights on all four corners while editing; resize from any corner | ✅ | 21 Oct. Tell me if the lean or wiggle should be stronger or softer. |
| **Full Screen button**: hide both panels in one tap | ✅ | 21 Oct, top left in Panels. |
| **Groups panel dock**: swipe the left panel away; it becomes a small glass dock you can drag to either side; tap or flick it inwards to open | ✅ | 21 Oct. |
| Left panel movable in any state; flick it away to fold into the dock; dock styled as a pressed button | ✅ | 21 Oct. |
| Right panel clear in the Glass theme: each card its own glass window | ✅ | 21 Oct. |
| Glassy corner highlights; the card gives softly with the finger while resizing | ✅ | 21 Oct. |
| Style and size controls sit above the widget; bubbles share the cards' frost | ✅ | 21 Oct. |
| Settings cards stay clear until in use; the one you're scrolling past frosts over, comes forward slightly and reads more clearly; the groups list follows | ✅ | 21 Oct. Tell me if the change should be stronger. |
| **Arrange the panels yourself**: swap sides, stack both on one side (top and bottom halves), drag panels to snap into place | ✅ | 21 Oct. Drag the groups panel or the settings' top grabber; a dashed outline shows where it will land. Also an Arrange menu at the top left. |
| Buttons and labels over the preview always sit above the widget | ✅ | 21 Oct. |
| **Design tweaks panel**: live sliders on the iPad for corners, gaps, frost, focus strength, wiggle and lean, so you can tune the feel yourself and send me the numbers | ✅ | 21 Oct. Sliders button at the top left; Copy Values, then paste them to me. |
| Hold anywhere on the settings panel, then drag, to move it; widget re-centres when panels move; backdrop picker follows the widget; carousel-style cards with no blur; roomier card padding | ✅ | 21 Oct. |
| **Guided tour / beginner mode**: annotated first-run guide to every gesture, easy to skip, with a "Keep it simple" option that goes straight to Classic | ✅ | 21 Oct. Spotlight glides over the real app: widget, settings, groups, backdrop swipe, toolbar. Replay with the ? button. New users now start in Panels. |
| Your Design Tweaks picks are the defaults (corners 41, gaps 22, frost 1.85, focus 1.35, wiggle 1.65, lean 1.10) | ✅ | 21 Oct. |
| Readable frost everywhere: resting cards and the groups panel keep enough frost for text | ✅ | 21 Oct. |
| Focus effect across the UI: the panel in use comes forward, the other steps back; selected group is bright glass with a rim and a sweep of light; jumped-to cards get a rim and shimmer; the widget shines on Apply | ✅ | 21 Oct. |
| **Match my Home Screen**: the app's own glass follows your Home Screen style (Light, Dark, Clear, Tinted with your tint), so the whole app feels like your Home Screen and the preview is exact | ✅ | 21 Oct. App and Widget → App look → Home Screen. Tinted uses your App colour as the tint. |
| More Design Tweaks: card padding, row spacing, shimmer, highlight rim | ✅ | 21 Oct. Shimmer toned down by default. |
| Backdrop change as a carousel that follows the finger 1:1, rounded edges, soft blurred gap (no white or black edges) | ✅ | 21 Oct. |
| Settings cards ease back and drift together as they scroll, like a carousel (3D tilt tried and dropped: it tore the glass edges) | ✅ | 21 Oct. |
| Selected Home Screen style tile is bright glass with a rim and a shine; style icons have a soft shadow | ✅ | 21 Oct. |
| **App text matches the clock font** (rounded, serif or mono), with a switch to turn it off | ✅ | 21 Oct. App and Widget, under Reduce glass. An experiment: tell me if you keep it. |
| **Preset photo backdrops**: a few simple, basic images | ⬜ | 21 Oct. Send me some images and I'll add them. |
| The "Preview" label could look better | 🟡 | 21 Oct: now a small glass tag on the widget's bottom edge in Panels. See if you like it. |
| **Quick actions / view options**: a mini icon list like the left panel, with a text size slider, a preview scale slider, the Clear and Tinted options, and your own quick actions added like styles | ⬜ | Your idea, 21 Oct. |
| Grab, move and pinch stay the quick default; the wiggle mode is the familiar, traditional way | ✅ | Your direction, 21 Oct. |
| More backdrops in the spirit of Apple's wallpapers | ✅ | 21 Oct: five soft mesh backdrops. Photo presets still to come from your images. |
| See-through app window, so the widget floats over your real Home Screen | 💤 | Not possible: iPadOS doesn't let apps show or read the Home Screen wallpaper. Closest: pick a screenshot or photo of your wallpaper as the backdrop (Your Photo). |
| Soften the glass edge on the backdrop pull (still reads as a stripe) | ⬜ | 21 Oct. |

## Home Screen accuracy

| Idea | Status | Notes |
|---|---|---|
| The app knows your Home Screen style and shows it first, with a nudge | ✅ | "My Home Screen" setting. |
| Keep colours on Clear and Tinted | 🟡 | Text works on the iPad. Card colour still to confirm. |
| Unify the look across Light, Dark, Clear and Tinted | 🟡 | |
| Refresh Widget button | ✅ | |
| Changes go live on the iPad automatically | ✅ | Saves, pushes and installs after each change. |

## Onboarding and accessibility

| Idea | Status | Notes |
|---|---|---|
| Onboarding as annotations over the real app, not pop-ups | ✅ | 21 Oct: the guided tour. |
| **Beginner mode**: gentle hints that tell you what to try, switch off any time to learn it yourself (like Procreate) | ⬜ | Goes with the proper onboarding. |
| Reduce glass setting, following iPadOS | ✅ | |
| Accessibility simplifications | ⬜ | You said "later". |

## Workflow and tools

| Idea | Status | Notes |
|---|---|---|
| Export the design system to Figma so you can experiment | ⬜ | Asked on 20 Oct. See the suggestion below. |
| A bird's-eye plan you can control, kept with the code | 🟡 | This file, plus OVERNIGHT_PLAN.md and DESIGN_SYSTEM.md. |
| Overnight work while you sleep | 🟡 | Scheduled tasks have been used before. Set up again when needed. |
| Reminder: set up a keep-awake app (like Caffeine/Amphetamine) on your Mac | ⬜ | So overnight work isn't stopped by sleep. |
| You were listing settings you flick between often | ⬜ | The message got cut off. Tell me the rest when you can. |
| Crash reports from beta testers (owner, 25 Oct 2026) | ⬜ | Nothing is set up yet. Crashes on your iPad are kept by iPadOS and can be pulled over the cable (none from 25 Oct had appeared yet). For testers: TestFlight sends crash reports, and testers' notes, automatically, but needs the paid Apple Developer Program; the free team can't hand the app to anyone else anyway. On top, MetricKit could catch crashes and hangs in the app and offer a "Send report" on the next launch. Decide on the paid program first. |

## Side projects (not Glass Clock)

| Idea | Status | Notes |
|---|---|---|
| Claude usage tracker and optimiser | 💤 | Shows what's used and what's left. Suggests ways to get more done with less: batch small requests, compact sooner, a cheaper model for simple jobs, big work overnight. |

## Design tools: suggestion

To push spacing around yourself, the quickest loop is a **Figma file of the settings panel**:
the panel, a card, a pill and a row, set up with the real sizes. You move things and I copy the
numbers back into the app. A Figma connector is available here, so I can build that file for
you. The other option is to send screenshots with scribbles on them, which works well too.

## Owner ideas, 21 Oct 2026 (afternoon)
- [x] Stick the groups onto the widget or the settings; slide in to a tab and out again, pull well away to unstick. (Settings sticking to things: not yet.)
- [x] Make-your-own backdrop for the app (21 Oct): two or three colours and None/Lines/Waves/Dots/Rings, pale in Light and deep in Dark (paintbrush button by the backdrop, or the backdrop menu).
- [ ] Make-your-own backgrounds for the widget itself (not started: the widget's look was kept as is).
- [ ] Try more "make way" options when the widget moves under a panel (shrink to a strip, slide down) alongside Move aside and Tuck away.
- [x] Panels move aside when the widget is moved under them (option: Tuck away instead).
- [x] Suggestions like the Home Screen question, elsewhere: "Try a font" after a preset, and Apply when changes wait (only if Apply when leaving is off). One at a time, with a ✕.
- [x] Accessibility group (Simpler effects, Reduce glass, clock-font text, panel text size); shorter group names (App, Home Screens).
- [x] Panels shrink while carried: done 21 Oct (Title card or Puck, in Design Tweaks). Try both.
- [x] Pinch to resize text per panel only: done 21 Oct (settings and groups keep their own size; both also in Accessibility as plain steppers).
- [ ] More direct-touch ideas, not built yet: pinch a settings card to fold it, two-finger swipe on the groups to hide them, pinch the backdrop to zoom a photo.
- [ ] Graceful window resizing (Stage Manager, windowed vs full screen): panels and grid adapt without struggling.
- [x] Smooth Light/Dark/Clear/Tinted switching: the widget changes at once, the app around it follows when tapping stops (fixes the stutter and freezes).
- [x] Breathing room: spacing sliders (panel edge, title bar, footer, bubble, chip) and Compact / Comfortable / Airy presets in Design Tweaks.
- [x] Controls split around the widget (style above, size and backdrop below); Apply icon is a mini widget with "12".
- [x] Backdrop menu as small buttons (a short menu grouped by kind, plus Add Photo).
- [x] Which kind you're in: swiping up/down shows the kind (Gradients, Mesh, Patterns) above the name, with a dot per backdrop in it.
- [ ] Swipe the backdrop sideways through kinds: on hold, as sideways swipes already bring the panels in and out. Owner to decide (e.g. two-finger sideways swipe for kinds?).
- [x] One swipeable bubble with page dots (optional: Design Tweaks → Widget controls in one row).

## Frost vs Liquid Glass: follow up (owner, 25 Oct 2026)
- Never mix the older iOS blur materials with the new Liquid Glass. Frost is now Liquid Glass's own "regular" glass with the Light/Dark wash (App look → Frosted glass, on by default).
- Tinted and Clear must look like the real system glass: they stay clear.
- Contrast is the person's choice through options (Adjust for contrast, outlines). Get the friend's feedback, then decide what goes in the menus. Stability first for now.

## Pricing and free tier (owner, 25 Oct 2026, not decided)
- Be generous: Classic and a lot of customising free; Panels free for a set time at first.
- Enthusiast tier for deep customising, at a reasonable price.
- Donations (even £1) unlock a reward, e.g. 6 months of the enthusiast tier. Maybe a review too. Note: Apple doesn't allow rewards for reviews, so that one is out; a donation reward is fine through in-app purchase.
- Keep in mind: most people use the app because they love the glass, even in Tinted. Also make it a really good app for people who don't like glass.

## Developer mode (built 25 Oct 2026)
- Switch at the bottom of App and Widget. Hides Design Tweaks unless on. Move other test tools behind it as they come up.

## Figma accessibility board (25 Oct 2026)
- Board on the Screens page of the design-system file: https://www.figma.com/design/O6eLeKQKkIxgYTAc2LmkyT/?node-id=9-4
- Contrast finding: with Adjust for contrast, every preset reaches 4.5:1 in Light. In Dark, Blue (4.2) and Purple (4.1) still fall just short, so the Dark lift target (0.18) should go up a little, to about 0.22. Done 25 Oct: lift raised to 0.24, and the wash behind text firmed up (more again with Increase Contrast on).
- New variables: tweak/* (Design Tweaks spacing), effect/* (Effects collection), a11y/outline-width, wash/*, outline/*, and dark/… partners. The app can read these from an export later (the Figma value list task).
