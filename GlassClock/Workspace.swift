import SwiftUI
import UIKit

/// How the preview and the settings share the window.
enum WorkspaceLayout: String, CaseIterable, Identifiable {
    case automatic, sideBySide, stacked, previewOnly
    var id: Self { self }

    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .sideBySide: "Side by Side"
        case .stacked: "Stacked"
        case .previewOnly: "Preview Only"
        }
    }

    var symbol: String {
        switch self {
        case .automatic: "rectangle.3.group"
        case .sideBySide: "rectangle.split.2x1"
        case .stacked: "rectangle.split.1x2"
        case .previewOnly: "rectangle"
        }
    }

    /// Automatic picks side by side when there's room (a full-screen iPad in landscape) and
    /// stacked in portrait and narrower Split View or Stage Manager windows.
    func resolved(width: CGFloat) -> WorkspaceLayout {
        guard self == .automatic else { return self }
        return width >= 1000 ? .sideBySide : .stacked
    }
}

/// The backdrops in small families, so the list reads as a few short groups rather than one
/// long menu (owner feedback, 2026-10-21).
enum BackdropKind: String, CaseIterable, Identifiable {
    case gradients, mesh, patterns
    var id: Self { self }

    var title: String {
        switch self {
        case .gradients: "Gradients"
        case .mesh: "Mesh"
        case .patterns: "Patterns"
        }
    }

    var backdrops: [PreviewBackdrop] {
        switch self {
        case .gradients: [.plain, .aurora, .sunset, .ocean, .graphite]
        case .mesh: [.bloom, .dune, .lagoon, .midnight, .glow]
        case .patterns: [.lines, .waves, .dots, .rings]
        }
    }
}

extension PreviewBackdrop {
    /// The family this backdrop belongs to, for the small "which kind" hint when swiping.
    /// Your Photo has none.
    var kind: BackdropKind? { BackdropKind.allCases.first { $0.backdrops.contains(self) } }
}

/// What's behind the preview card. Apps can't see the Home Screen wallpaper, so the closest
/// thing is a photo the person picks, such as a screenshot of their own Home Screen.
enum PreviewBackdrop: String, CaseIterable, Identifiable {
    case plain, aurora, sunset, ocean, graphite, bloom, dune, lagoon, midnight, glow, lines, waves, dots, rings, custom, photo
    var id: Self { self }

    var label: String {
        switch self {
        case .plain: "Plain"
        case .aurora: "Aurora"
        case .sunset: "Sunset"
        case .ocean: "Ocean"
        case .graphite: "Graphite"
        case .bloom: "Bloom"
        case .dune: "Dune"
        case .lagoon: "Lagoon"
        case .midnight: "Midnight"
        case .glow: "Glow"
        case .lines: "Lines"
        case .waves: "Waves"
        case .dots: "Dots"
        case .rings: "Rings"
        case .custom: "Your Own"
        case .photo: "Your Photo"
        }
    }

    var colors: [Color] {
        switch self {
        case .plain, .photo: [.indigo, .teal, .orange]
        case .custom: CustomBackdrop.decode(UserDefaults.standard.string(forKey: CustomBackdrop.key) ?? "")?.colors
            ?? CustomBackdrop().colors
        case .aurora: [.indigo, .teal, .orange]
        case .sunset: [.purple, .pink, .orange]
        case .ocean: [Color(red: 0.02, green: 0.1, blue: 0.35), .blue, .teal]
        case .graphite: [Color(white: 0.12), Color(white: 0.3), Color(white: 0.18)]
        case .bloom, .dune, .lagoon, .midnight, .glow: mesh ?? []
        case .lines: [Color(red: 0.36, green: 0.44, blue: 0.86), Color(red: 0.62, green: 0.40, blue: 0.86)]
        case .waves: [Color(red: 0.10, green: 0.56, blue: 0.70), Color(red: 0.18, green: 0.32, blue: 0.66)]
        case .dots: [Color(red: 0.94, green: 0.56, blue: 0.48), Color(red: 0.80, green: 0.36, blue: 0.56)]
        case .rings: [Color(red: 0.30, green: 0.66, blue: 0.52), Color(red: 0.16, green: 0.40, blue: 0.56)]
        }
    }

    /// The simple drawn patterns (owner request, 2026-10-21: lines and patterns as ideas
    /// for backdrops). They follow Light and Dark, see `PatternBackdrop`.
    var isPattern: Bool { [.lines, .waves, .dots, .rings, .custom].contains(self) }

    /// Soft, blended mesh backdrops in the spirit of the iPad's own wallpapers (owner request,
    /// 2026-10-21): nine colours on a 3×3 grid, top-left to bottom-right.
    var mesh: [Color]? {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        return switch self {
        case .bloom: [c(0.98, 0.78, 0.86), c(0.86, 0.62, 0.95), c(0.62, 0.66, 0.98),
                      c(0.99, 0.62, 0.70), c(0.80, 0.50, 0.92), c(0.48, 0.56, 0.96),
                      c(1.00, 0.80, 0.66), c(0.94, 0.56, 0.74), c(0.56, 0.72, 0.98)]
        case .dune: [c(0.99, 0.91, 0.78), c(0.97, 0.82, 0.62), c(0.93, 0.70, 0.52),
                     c(0.96, 0.80, 0.62), c(0.90, 0.64, 0.46), c(0.80, 0.52, 0.40),
                     c(0.86, 0.62, 0.48), c(0.72, 0.46, 0.38), c(0.56, 0.36, 0.34)]
        case .lagoon: [c(0.62, 0.92, 0.88), c(0.36, 0.80, 0.86), c(0.20, 0.58, 0.86),
                       c(0.40, 0.84, 0.74), c(0.16, 0.64, 0.74), c(0.10, 0.40, 0.72),
                       c(0.20, 0.66, 0.56), c(0.08, 0.46, 0.56), c(0.06, 0.26, 0.52)]
        case .midnight: [c(0.10, 0.10, 0.26), c(0.18, 0.12, 0.38), c(0.08, 0.16, 0.36),
                         c(0.14, 0.08, 0.30), c(0.30, 0.16, 0.50), c(0.10, 0.22, 0.46),
                         c(0.04, 0.04, 0.14), c(0.12, 0.08, 0.26), c(0.04, 0.10, 0.24)]
        case .glow: [c(1.00, 0.86, 0.50), c(1.00, 0.66, 0.36), c(0.98, 0.44, 0.34),
                     c(1.00, 0.62, 0.30), c(0.96, 0.40, 0.30), c(0.86, 0.24, 0.36),
                     c(0.94, 0.36, 0.28), c(0.78, 0.20, 0.34), c(0.52, 0.12, 0.36)]
        default: nil
        }
    }
}

/// A drawn backdrop: a soft gradient with fine lines, waves, dots or rings over it. Pale with
/// darker marks in Light, deep with lighter marks in Dark.
struct PatternBackdrop: View {
    var kind: PreviewBackdrop
    /// For Your Own: its colours and pattern, passed in so it redraws as they change.
    var custom: CustomBackdrop? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let base = custom?.colors ?? kind.colors
        let marks = kind == .custom ? custom?.pattern.drawn : kind
        ZStack {
            LinearGradient(colors: base, startPoint: .topLeading, endPoint: .bottomTrailing)
            // Light: washed towards white; Dark: towards black.
            (dark ? Color.black : Color.white).opacity(dark ? 0.45 : 0.55)
            Canvas { context, size in
                let ink = GraphicsContext.Shading.color(dark ? .white.opacity(0.16) : base[0].opacity(0.35))
                switch marks {
                case .lines:
                    var path = Path()
                    let gap: CGFloat = 26
                    var x = -size.height
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        x += gap
                    }
                    context.stroke(path, with: ink, lineWidth: 1.2)
                case .waves:
                    let gap: CGFloat = 34
                    var y: CGFloat = 0
                    var row = 0.0
                    while y < size.height + gap {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        for x in stride(from: 0, through: size.width, by: 8) {
                            path.addLine(to: CGPoint(x: x, y: y + 12 * sin(x / 90 + row * 0.5)))
                        }
                        context.stroke(path, with: ink, lineWidth: 1.4)
                        y += gap
                        row += 1
                    }
                case .dots:
                    let gap: CGFloat = 24
                    for x in stride(from: gap / 2, through: size.width, by: gap) {
                        for y in stride(from: gap / 2, through: size.height, by: gap) {
                            context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: ink)
                        }
                    }
                case .rings:
                    let centre = CGPoint(x: size.width * 0.15, y: size.height * 0.85)
                    let reach = hypot(size.width, size.height)
                    for radius in stride(from: CGFloat(40), through: reach, by: 38) {
                        context.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                                              width: radius * 2, height: radius * 2)),
                                       with: ink, lineWidth: 1.4)
                    }
                default:
                    break
                }
            }
        }
    }
}

/// The photo chosen as a backdrop, kept in the app's own storage.
enum BackdropPhoto {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "backdrop.jpg")
    }

    static func load() -> UIImage? {
        (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
    }

    /// Stores a picked photo, scaled down to at most 2400 pt on its long side.
    static func save(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 2400 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? resized.jpegData(compressionQuality: 0.85)?.write(to: url)
        return resized
    }
}

/// The overall arrangement of the app.
enum InterfaceStyle: String, CaseIterable, Identifiable {
    /// The preview and one scrolling list of settings, side by side or stacked.
    case classic
    /// A glass sidebar of settings groups, the preview filling the window, and the chosen
    /// group's controls in an inspector on the right (like Keynote or Freeform). From the
    /// panels-prototype research, References/panel-layout-proposal.md on that branch.
    case panels
    var id: Self { self }

    var label: String {
        switch self {
        case .classic: "Classic"
        case .panels: "Panels"
        }
    }

    var symbol: String {
        switch self {
        case .classic: "rectangle.split.2x1"
        case .panels: "rectangle.split.3x1"
        }
    }
}

/// The groups of settings, in the order a clock is designed: what it shows, how it looks, then
/// how the app behaves. The Classic interface shows them as collapsible sections; Panels lists
/// them in the sidebar.
enum SettingsSection: String, CaseIterable, Identifiable {
    case presets, layout, fonts, colour, effects, card, homeScreens, widget, accessibility
    var id: Self { self }

    /// The groups Classic shows; Panels has them all.
    static let classic: [SettingsSection] = [.presets, .fonts, .colour]

    var title: String {
        switch self {
        case .presets: "Presets"
        case .layout: "Layout"
        case .fonts: "Fonts"
        case .colour: "Colour"
        case .effects: "Effects"
        case .card: "Card"
        case .homeScreens: "Home Screens"
        case .widget: "App"
        case .accessibility: "Accessibility"
        }
    }

    var icon: String {
        switch self {
        case .presets: "sparkles"
        case .layout: "rectangle.3.group"
        case .fonts: "textformat"
        case .colour: "paintpalette"
        case .effects: "sun.max"
        case .card: "rectangle.on.rectangle"
        case .homeScreens: "circle.lefthalf.filled"
        case .widget: "square.grid.2x2"
        case .accessibility: "accessibility"
        }
    }

    var footer: String? {
        switch self {
        case .presets:
            "Save up to \(StyleLibrary.maxCustomPresets) of your own. Long-press one to update, rename or delete it."
        case .effects:
            "A shadow's Automatic colour is black. Pick white for a light shadow."
        case .card:
            "When your Home Screen uses the Clear or Tinted style, iPadOS supplies the card and colour. Liquid Glass text keeps its glass look."
        case .homeScreens:
            "iPadOS normally redraws widgets in its own glass and colour on these Home Screens. Turn these on to bring your colours forward instead. Needs iPadOS 27 for Clear Home Screens; iPadOS 26 applies its own glass there regardless."
        case .widget:
            "Your changes are kept in the app as you go. They reach the widget when you tap Apply to Widget, or when you leave the app if that's on. App look sets the app's style: Glass, Frosted, Colour (tinted with the app colour), or Home, which follows your Home Screen. Appearance follows your iPad unless you pick Light or Dark. To add the clock: long-press your Home Screen, tap Edit, then Add Widget, and choose Glass Clock."
        case .accessibility:
            "Simpler effects turns off the wiggle, lean, light sweeps and carousel motion. Reduce glass swaps the glass for solid panels; it's also on when Reduce Transparency is on in the iPad's Settings."
        case .layout, .fonts, .colour:
            nil
        }
    }
}

/// Lays its children out in rows, wrapping to a new row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                // Placed at exactly the size it measured; an open proposal let buttons squash.
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width += spacing + size.width
                rows[rows.count - 1].height = max(last.height, size.height)
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}

/// The app's look. Glass leans all the way into glass: clear, see-through panels, with every
/// row of text on its own frosted backing so it stays readable (owner direction, 2026-10-21:
/// "super glassy… but really focus on contrast"). Frosted is the standard, more opaque Liquid
/// Glass; Colour tints it with the app colour.
enum AppTheme: String, CaseIterable, Identifiable {
    /// `home` matches the Home Screen style being previewed: Light and Dark set the app's
    /// appearance, Clear is clear glass, and Tinted tints the glass with the app colour (owner
    /// direction, 2026-10-21: the app should feel like your own Home Screen).
    case glass, frosted, colour, home
    var id: Self { self }

    var label: String {
        switch self {
        case .glass: "Glass"
        case .frosted: "Frosted"
        case .colour: "Colour"
        // Short, so it fits the four-way switch without being cut off (tap check, 2026-10-21).
        case .home: "Home"
        }
    }

    /// Clear glass with frosted cards: the Glass look, which My Home Screen builds on.
    var isGlassy: Bool { self == .glass || self == .home }
}

/// The Home Screen style the app's own glass follows, when the app look is My Home Screen.
extension EnvironmentValues {
    @Entry var homeLook: HomeScreenStyle?
    /// Moving the settings panel by holding a card's title bar.
    @Entry var panelCarry: PanelCarry?
    /// The design of headings when the app's text matches the clock font. A serif clock font
    /// pairs serif headings with plain body text, which reads better at small sizes (owner
    /// feedback, 2026-10-21).
    @Entry var headingDesign: Font.Design?
}

/// What the groups are stuck onto, if anything.
enum GroupsAttachment: String {
    case none, widget, settings
}

/// What the panels do when the widget is moved under one (owner idea, 2026-10-21).
enum PanelsMakeWay: String, CaseIterable, Identifiable {
    case moveAside, hide
    var id: Self { self }
    var label: String { self == .moveAside ? "Move aside" : "Tuck away" }
}

/// Light, Dark, or following the iPad.
enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic, light, dark
    var id: Self { self }

    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The app colour, for buttons, highlights and the Colour theme. Automatic is the system blue.
enum AppColor {
    static func resolve(_ raw: String) -> Color {
        ClockColor(rawValue: raw).flatMap { $0 == .auto ? nil : $0.color } ?? .accentColor
    }

    /// The app colour spelled out (blue for Automatic), for selected and primary things.
    /// `accentColor` would pick up the black-and-white tint the Glass theme gives icons on
    /// glass, and selected items should look the same everywhere (owner, 2026-10-21).
    static func chosen(_ raw: String) -> Color {
        ClockColor(rawValue: raw).flatMap { $0 == .auto ? nil : $0.color } ?? .blue
    }
}

/// The app's main buttons: the app colour with white text, always. With Automatic, the
/// inherited tint could be the Glass theme's black or white, which made some buttons white on
/// white (Show Mine, Copy Values; tap check, 2026-10-21).
struct ProminentButton: ViewModifier {
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue

    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .tint(AppColor.chosen(appColor))
            .foregroundStyle(.white)
    }
}

extension View {
    func prominentButton() -> some View { modifier(ProminentButton()) }
}

/// Bordered chips (Lucky Colours, starter styles…) with readable text. In Dark, the tint
/// coloured text on its own faint tint sank into warm backdrops like Sunset and Dune, so the
/// text goes white there and the pill keeps the colour (contrast first, 2026-10-21).
struct ReadableChip: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if scheme == .dark { content.foregroundStyle(.primary) } else { content }
    }
}

extension View {
    func readableChip() -> some View { modifier(ReadableChip()) }
}

/// The app's own glass for panels and controls, in the chosen theme. When Reduce Transparency
/// is on in iPadOS Settings, or the app's Reduce glass switch is, it's a calm solid surface
/// instead, so the design doesn't lean on glass (HIG: Accessibility, Materials).
struct AppGlass<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @Environment(\.homeLook) private var homeLook
    @AppStorage("reduceGlass") private var reducesGlass = false
    @AppStorage("appTheme") private var theme = AppTheme.glass
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue
    var shape: S
    var interactive = false
    var tint: Color?
    /// A big panel of settings rather than a small control: Crystal keeps a gentle tint behind
    /// these so their text stays readable.
    var panel = false

    func body(content: Content) -> some View {
        if systemReducesTransparency || reducesGlass {
            content
                .background {
                    shape.fill(.background.secondary)
                        .overlay { if let tint { shape.fill(tint.opacity(0.2)) } }
                        .overlay { shape.stroke(.separator, lineWidth: 1) }
                }
        } else {
            content
                // Contrast first (owner feedback, 2026-10-21): on clear glass a blue icon can
                // vanish against a blue backdrop. Liquid Glass keeps content readable by flipping
                // it between black and white to suit what's behind, which the primary colour
                // does, so in the Glass theme icons and labels on glass use it. Selected items
                // keep their colour on a solid fill, and the settings cards set their own tint.
                .tint(theme.isGlassy && tint == nil ? Color.primary : nil)
                .glassEffect(glass.interactive(interactive), in: shape)
        }
    }

    private var glass: Glass {
        if let tint { return .regular.tint(tint) }
        if theme == .home, homeLook == .tinted {
            return .clear.tint(AppColor.chosen(appColor).opacity(panel ? 0.3 : 0.38))
        }
        switch theme {
        // Clear all the way; readability comes from the frosted cards inside panels
        // (`SettingsCard`) rather than from tinting the glass.
        case .glass, .home: return .clear
        case .frosted: return .regular
        case .colour: return .regular.tint(AppColor.resolve(appColor).opacity(panel ? 0.22 : 0.3))
        }
    }
}

/// Corner rounding, kept concentric (owner feedback 2026-10-21): a box inside a panel is
/// rounded by the panel's radius minus the gap between them, so their curves run parallel.
enum Corner {
    /// The floating panels.
    /// (Panel corners and gaps can be tuned live in Design Tweaks.)
    static var panel: CGFloat { CGFloat(Tweak.panel.value) }
    /// The gap between cards (the panel's edge has its own padding, `edge`).
    static var inset: CGFloat { CGFloat(Tweak.gap.value) }
    /// The padding between a panel's edge and its cards.
    static var edge: CGFloat { CGFloat(Tweak.panelEdge.value) }
    /// The cards of settings inside a panel: concentric with the panel, like the app icon tiles
    /// (owner, 22 Oct 2026: every inner corner follows the one around it).
    static var card: CGFloat { max(4, panel - edge) }
    /// Padding inside a card, around its rows.
    static var cardPadding: CGFloat { CGFloat(Tweak.cardPadding.value) }
}

/// One group of settings as a card on its panel, its rows split by thin lines. In the Glass
/// theme the card is its own layer of glass on top of the panel's glass (owner request,
/// 2026-10-21), with the Glass amount slider setting how much frost sits behind the text.
struct SettingsCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @AppStorage("reduceGlass") private var reducesGlass = false
    @AppStorage("appTheme") private var theme = AppTheme.glass
    @AppStorage("glassAmount") private var glassAmount = GlassAmount.standard
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue
    @Environment(\.colorScheme) private var colorScheme
    // Design Tweaks: read here so the cards redraw as the sliders move.
    @AppStorage(Tweak.panel.key) private var tweakPanel = Tweak.panel.standard
    @AppStorage(Tweak.gap.key) private var tweakGap = Tweak.gap.standard
    @AppStorage(Tweak.frost.key) private var frost = Tweak.frost.standard
    @AppStorage(Tweak.focus.key) private var focusStrength = Tweak.focus.standard
    @AppStorage(Tweak.cardPadding.key) private var tweakCardPadding = Tweak.cardPadding.standard
    @AppStorage(Tweak.rowSpacing.key) private var rowSpacing = Tweak.rowSpacing.standard
    @AppStorage(Tweak.rim.key) private var rim = Tweak.rim.standard
    @AppStorage(Tweak.panelEdge.key) private var tweakEdge = Tweak.panelEdge.standard
    @AppStorage(Tweak.titleBar.key) private var titleBar = Tweak.titleBar.standard
    @AppStorage(Tweak.footer.key) private var footerPadding = Tweak.footer.standard
    /// The group's title, tucked inside the top of the card (owner feedback, 2026-10-21).
    var title: String?
    var icon: String?
    var highlighted = false
    /// Whether this is the card being used. In the Glass theme the others go clearer and a
    /// little faded, and this one frosts over, comes forward and reads more clearly (owner
    /// idea, 2026-10-21).
    var focused = true
    /// A short note at the bottom of the card.
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Corner.card, style: .continuous)
        let glassy = theme.isGlassy && !systemReducesTransparency && !reducesGlass
        // Like a small window (owner idea, 2026-10-21): a title bar across the top and a
        // quieter strip along the bottom, each a shade apart from the rows between.
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Label {
                    Text(title).foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                } icon: {
                    if let icon { Image(systemName: icon).foregroundStyle(.tint) }
                }
                .font(.title3.weight(.bold))
                .headingFont()
                .padding(.horizontal, Corner.cardPadding)
                .padding(.top, titleBar)
                .padding(.bottom, max(4, titleBar - 4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(windowBand)
                .overlay(alignment: .bottom) { Divider().opacity(0.6) }
                // Hold the title bar, then drag, to move the whole panel (owner, 22 Oct 2026).
                // Only the title bar, so switches and sliders in the rows always answer taps.
                .contentShape(.rect)
                .gesture(titleHold)
                .simultaneousGesture(titleFlick)
                .accessibilityAddTraits(.isHeader)
            }
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    row.padding(.vertical, rowSpacing)
                    if row.id != rows.last?.id { Divider() }
                }
            }
            .padding(.horizontal, Corner.cardPadding)
            .padding(.top, title == nil ? 4 : 6)
            .padding(.bottom, footer == nil ? 10 : 6)
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Corner.cardPadding)
                    .padding(.vertical, footerPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(windowBand)
                    .overlay(alignment: .top) { Divider().opacity(0.6) }
            }
        }
        // The same app colour for every button and selection, in Light and Dark alike.
        .tint(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Overdone for now, to judge it (owner, 2026-10-21): resting cards fade back and soften.
        // Resting cards fade back a little, never so far that their text is hard to read.
        // (Resting cards no longer fade, owner 22 Oct 2026: the glass shows which is in use.)
        .background {
            ZStack {
                if glassy {
                    // Resting cards lean towards clear; the one in use gets the full frost.
                    // Frost (Design Tweaks) scales how thick the frost is: 0 is clear. Resting
                    // cards keep enough frost for their text to read (owner feedback,
                    // 2026-10-21: black text can't sit on clear glass); the one in use gets more.
                    // Clear towards the top and bottom of the list, frosted in the middle,
                    // changing smoothly as the cards scroll (owner, 22 Oct 2026). A clear layer
                    // always, with just enough frost to read, and a frosted one on top that fades
                    // in near the middle. Done on the GPU, so scrolling costs nothing extra.
                    GlassAmount.backing(GlassAmount.frosted(glassAmount + 0.4, by: frost), in: shape)
                        .opacity(min(1, frost))
                    GlassAmount.backing(GlassAmount.frosted(glassAmount - 0.2, by: frost), in: shape)
                        .opacity(min(1, frost))
                        .visualEffect { content, proxy in
                            let frame = proxy.frame(in: .scrollView)
                            let height = proxy.bounds(of: .scrollView)?.height ?? 800
                            // 0 in the middle of the list, 1 at its top or bottom edge.
                            let away = min(1, abs(frame.midY - height / 2) / max(1, height / 2))
                            let t = max(0, min(1, (away - 0.3) / 0.6))
                            return content.opacity(1 - t * t * (3 - 2 * t))
                        }
                } else {
                    shape.fill(.background.secondary)
                }
            }
        }
        // Jumped to from the groups: a bright rim and a sweep of light across the glass,
        // rather than a wash of colour (owner direction, 2026-10-21).
        // A glass rim rather than a flat line: bright where the light catches the top corner,
        // fading round the sides and catching again faintly at the bottom (owner, 22 Oct 2026).
        // Drawn just inside the edge, so the panel never cuts it off.
        .overlay {
            shape.inset(by: 0.75)
                .stroke(LinearGradient(colors: [.white.opacity(rim), .white.opacity(rim * 0.25), .white.opacity(rim * 0.55)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                .opacity(highlighted ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: highlighted)
        }
        .shimmer(trigger: highlighted, in: shape)
        .modifier(CardGlass(on: glassy, shape: shape))
        .shadow(color: .black.opacity(glassy && focused ? 0.16 * min(1, focusStrength) : 0), radius: 18, y: 8)
        // Like a carousel: cards grow as they near the middle of the list and shrink away
        // from it, smoothly as they scroll.
        // Like a carousel turning under the finger: cards ease back and drift together a little as
        // they move from the middle of the list, smoothly as they scroll. Done on the GPU, so it
        // costs nothing extra while scrolling.
        // (The squash as cards scroll is gone, owner 22 Oct 2026: one effect, the frosted focus.)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: focused)
    }

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }
    @Environment(\.panelCarry) private var panelCarry

    /// A quick sideways flick on the title bar pushes the panel aside (see `PanelCarry`).
    private var titleFlick: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .onEnded { drag in
                let dx = drag.predictedEndTranslation.width
                guard let panelCarry, abs(dx) > 240,
                      abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                panelCarry.flicked(dx < 0)
            }
    }

    private var titleHold: some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard let panelCarry, case .second(true, let drag) = value else { return }
                if let drag { panelCarry.grabbed(CarryGrab(point: drag.startLocation, title: title, icon: icon)) }
                panelCarry.moved(drag?.translation ?? .zero)
            }
            .onEnded { value in
                guard let panelCarry else { return }
                if case .second(true, let drag?) = value { panelCarry.ended(drag.translation) } else { panelCarry.ended(nil) }
            }
    }

    private var tint: Color { AppColor.chosen(appColor) }

    /// The title bar and bottom strip: a faint wash, lighter in Dark and darker in Light.
    private var windowBand: Color {
        colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.035)
    }
}

/// Headings in the heading design (serif when the clock font is serif, see `headingDesign`).
private struct HeadingFont: ViewModifier {
    @Environment(\.headingDesign) private var design

    func body(content: Content) -> some View {
        if let design { content.fontDesign(design) } else { content }
    }
}

extension View {
    func headingFont() -> some View { modifier(HeadingFont()) }
}

private struct CardGlass<S: Shape>: ViewModifier {
    var on: Bool
    var shape: S

    func body(content: Content) -> some View {
        if on {
            content.glassEffect(.clear, in: shape)
        } else {
            content
        }
    }
}

/// Text that sits straight on a panel (section titles, notes) gets a small frosted backing in
/// the Glass theme, where the panel itself is clear: white titles over a bright backdrop were
/// hard to read in Dark (simulator, 2026-10-21).
struct PanelLabelBacking: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @AppStorage("reduceGlass") private var reducesGlass = false
    @AppStorage("appTheme") private var theme = AppTheme.glass
    @AppStorage("glassAmount") private var glassAmount = GlassAmount.standard

    func body(content: Content) -> some View {
        if theme.isGlassy && !systemReducesTransparency && !reducesGlass {
            // Pills, like the app's other small controls.
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background { GlassAmount.backing(glassAmount, in: Capsule()) }
                .glassEffect(.clear, in: Capsule())
        } else {
            content
        }
    }
}

/// How clear the Glass theme is (owner request, 2026-10-21): 0 is the frosted backing rows had
/// before, 1 is the clearest that still keeps text readable, a very thin frost over the glass.
enum GlassAmount {
    static let standard = 0.5

    /// A Glass amount made frostier by `frost` (Design Tweaks): 1 leaves it, 2 doubles the frost.
    static func frosted(_ amount: Double, by frost: Double) -> Double {
        min(1, max(0, 1 - (1 - min(1, max(0, amount))) * frost))
    }

    /// The frosted backing behind text: a thin frost always, plus a thicker one that fades out
    /// as the amount goes up.
    static func backing<S: Shape>(_ amount: Double, in shape: S) -> some View {
        GlassBacking(amount: amount, shape: shape)
    }
}

/// Contrast comes first (owner direction, 2026-10-21): glass is a fun effect, never a reason
/// text can't be read. So under the frost there's always a light wash in Light and a dark
/// wash in Dark, pushing the backdrop away from the text's colour, a little more as the
/// Glass amount slider moves towards Frosted.
private struct GlassBacking<S: Shape>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.homeLook) private var homeLook
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue
    var amount: Double
    var shape: S

    var body: some View {
        ZStack {
            shape.fill(colorScheme == .dark ? Color.black : .white)
                .opacity(0.16 + 0.26 * (1 - amount))
            // A Tinted Home Screen's glass carries the tint all through.
            if homeLook == .tinted {
                shape.fill(AppColor.chosen(appColor).opacity(0.32))
            }
            // Thins out towards the Clear end too, so Clear is properly see-through
            // (owner feedback, 2026-10-21), while still keeping a little frost behind text.
            shape.fill(.ultraThinMaterial).opacity(1 - 0.4 * amount)
            shape.fill(.regularMaterial).opacity(1 - amount)
        }
    }
}

extension View {
    func panelLabelBacking() -> some View { modifier(PanelLabelBacking()) }

    /// A settings card as a whole Form row: no system background, separators or insets, so
    /// the card draws its own.
    func settingsCardRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }

    func wrappedInSettingsCard() -> some View {
        SettingsCard { self }.settingsCardRow()
    }

    func appGlass<S: Shape>(_ shape: S, interactive: Bool = false, tint: Color? = nil, panel: Bool = false) -> some View {
        modifier(AppGlass(shape: shape, interactive: interactive, tint: tint, panel: panel))
    }
}

/// The Home Screen style the person uses. iPadOS doesn't tell apps (and a widget is pre-drawn
/// in every style, so it can't tell either), so the person says once and the preview opens on
/// it. Automatic is Light or Dark following the iPad's appearance.
enum MyHomeScreen: String, CaseIterable, Identifiable {
    case unknown, automatic, light, dark, clear, tinted
    var id: Self { self }

    var label: String {
        switch self {
        case .unknown: "Not set"
        case .automatic: "Light or Dark (Automatic)"
        case .light: "Light"
        case .dark: "Dark"
        case .clear: "Clear"
        case .tinted: "Tinted"
        }
    }

    /// The preview style that matches, for the iPad's current appearance. Nil until it's set.
    func style(in colorScheme: ColorScheme) -> HomeScreenStyle? {
        switch self {
        case .unknown: nil
        case .automatic: colorScheme == .dark ? .dark : .light
        case .light: .light
        case .dark: .dark
        case .clear: .clear
        case .tinted: .tinted
        }
    }
}

extension PreviewSize {
    /// How many Home Screen slots the widget covers, across and down. A slot is a Small widget.
    var span: (columns: Int, rows: Int) {
        switch self {
        case .small: (1, 1)
        case .medium: (2, 1)
        case .large: (2, 2)
        case .extraLarge: (4, 2)
        }
    }
}

/// A Home Screen-style grid of widget slots filling the preview area. The spacing is iPadOS's:
/// a Small widget is 170 pt and a Medium one 378.5 pt, which puts slots 208.5 pt apart with a
/// 38.5 pt gap (HIG widget sizes for the 13-inch iPad), so every size lines up exactly.
struct HomeGrid {
    static let slot: CGFloat = 170
    static let gap: CGFloat = 38.5

    let columns: Int
    let rows: Int
    let step: CGFloat
    let gap: CGFloat
    let origin: CGPoint

    /// - Parameter scale: below 1 when the area is too small for the widget at its real size.
    init(area: CGSize, scale: CGFloat) {
        // Classic can lay the preview out at zero size for a moment, which made the scale and
        // step zero and the grid maths infinite, crashing the app on opening Classic
        // (owner, 2026-10-21). A tiny floor keeps every step finite.
        let scale = scale.isFinite ? max(scale, 0.05) : 1
        step = (Self.slot + Self.gap) * scale
        gap = Self.gap * scale
        columns = Self.count(area.width, gap: gap, step: step)
        rows = Self.count(area.height, gap: gap, step: step)
        let width = CGFloat(columns) * step - gap, height = CGFloat(rows) * step - gap
        origin = CGPoint(x: (area.width - width) / 2, y: (area.height - height) / 2)
    }

    private static func count(_ length: CGFloat, gap: CGFloat, step: CGFloat) -> Int {
        let value = (length + gap) / step
        return value.isFinite ? max(1, min(Int(value), 50)) : 1
    }

    /// The frame of a widget covering `span` slots from `column`, `row`.
    func frame(column: Int, row: Int, span: (columns: Int, rows: Int)) -> CGRect {
        CGRect(x: origin.x + CGFloat(column) * step, y: origin.y + CGFloat(row) * step,
               width: CGFloat(span.columns) * step - gap, height: CGFloat(span.rows) * step - gap)
    }

    /// The nearest position where a widget of `span` fits, for a widget centred at `point`.
    /// A widget too big for the grid sits at its centre (and spills over evenly).
    func nearest(to point: CGPoint, span: (columns: Int, rows: Int)) -> (column: Int, row: Int) {
        func axis(_ value: CGFloat, start: CGFloat, count: Int, size: Int) -> Int {
            guard count >= size else { return 0 }
            let leading = (value - start - (CGFloat(size) * step - gap) / 2) / step
            return min(count - size, max(0, Int(leading.rounded())))
        }
        return (axis(point.x, start: origin.x, count: columns, size: span.columns),
                axis(point.y, start: origin.y, count: rows, size: span.rows))
    }

    /// A stored position kept inside the grid; -1 (never placed) means the middle.
    func clamped(column: Int, row: Int, span: (columns: Int, rows: Int)) -> (column: Int, row: Int) {
        let maxColumn = max(0, columns - span.columns), maxRow = max(0, rows - span.rows)
        return (column < 0 ? maxColumn / 2 : min(column, maxColumn),
                row < 0 ? maxRow / 2 : min(row, maxRow))
    }

    /// Frames of every empty slot, for the outlines shown while dragging.
    var slotFrames: [CGRect] {
        (0..<rows).flatMap { row in
            (0..<columns).map { column in frame(column: column, row: row, span: (1, 1)) }
        }
    }
}

/// A single sweep of light across a piece of glass each time `trigger` changes, like light
/// catching it as it moves: used to mark what's just been picked or jumped to.
struct Shimmer<S: Shape>: ViewModifier {
    var trigger: Bool
    var shape: S
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }
    @Environment(\.colorScheme) private var colorScheme
    /// How bright the sweep is (Design Tweaks).
    @AppStorage(Tweak.shimmer.key) private var strength = Tweak.shimmer.standard

    /// A wide, soft wash of light (in Dark) or shade (in Light) that glides once across the
    /// whole shape (owner feedback, 2026-10-21: the narrow tilted band looked clipped at the
    /// edges). It fades in and out at the ends, so no edge of it is ever seen.
    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion && strength > 0 {
                let wash: Color = colorScheme == .dark ? .white : .black
                Color.clear
                    .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, x in
                        view.overlay {
                            LinearGradient(stops: [
                                .init(color: wash.opacity(0), location: 0),
                                .init(color: wash.opacity((colorScheme == .dark ? 0.32 : 0.12) * strength), location: 0.5),
                                .init(color: wash.opacity(0), location: 1),
                            ], startPoint: UnitPoint(x: x * 2.2 - 1.6, y: 0.2), endPoint: UnitPoint(x: x * 2.2 - 0.6, y: 0.8))
                            // Strongest mid-sweep, nothing at either end.
                            .opacity(sin(.pi * x))
                        }
                    } keyframes: { _ in
                        LinearKeyframe(0, duration: 0.01)
                        CubicKeyframe(1, duration: 1.1)
                    }
                    .clipShape(shape)
                    // Only when it turns on, not again as it fades.
                    .opacity(trigger ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func shimmer<S: Shape>(trigger: Bool, in shape: S) -> some View {
        modifier(Shimmer(trigger: trigger, shape: shape))
    }
}

/// While a panel is carried by its bar, it shrinks to a small stand-in (a title card or a
/// puck) that's easy to move, and springs back to full size where it's dropped. The panel
/// itself stays (all but invisible) under the finger so the drag carries on. With Simpler
/// effects the stand-in just fades in, without the shrink.
struct CarriedShape: ViewModifier {
    var carried: Bool
    var style: CarryStyle
    var icon: String
    var title: String
    var simple: Bool
    /// Where the finger picked it up, in the view's own space, and the view's size: it shrinks
    /// into the finger and the stand-in sits under it, rather than at the top of the panel
    /// (owner, 22 Oct 2026: it stuck above the Presets card when grabbed).
    var hold: CGPoint? = nil
    var size: CGSize = .zero

    func body(content: Content) -> some View {
        let shrinks = carried && style != .lift
        let anchor = hold.map { size.width > 0 && size.height > 0
            ? UnitPoint(x: $0.x / size.width, y: $0.y / size.height) : .top } ?? .top
        content
            .opacity(shrinks ? 0.02 : 1)
            .scaleEffect(shrinks && !simple ? 0.35 : 1, anchor: anchor)
            .overlay(alignment: .top) {
                if shrinks {
                    standIn
                        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
                        .transition(simple ? .opacity : .opacity.combined(with: .scale(scale: 2.2, anchor: .top)))
                        .allowsHitTesting(false)
                        .position(x: hold?.x ?? size.width / 2, y: hold?.y ?? 26)
                }
            }
            .animation(simple ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.78), value: shrinks)
    }

    @ViewBuilder
    private var standIn: some View {
        if style == .puck {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(width: 64, height: 64)
                .appGlass(.circle)
        } else {
            Label(title, systemImage: icon)
                .font(.headline)
                .padding(.horizontal, 20)
                .frame(height: 52)
                .fixedSize()
                .appGlass(.capsule)
        }
    }
}

/// What holding and dragging a card's title bar does: moves the panel it's in.
struct PanelCarry {
    /// Where the title bar was picked up (in the window) and which card it belongs to.
    var grabbed: (CarryGrab) -> Void = { _ in }
    var moved: (CGSize) -> Void
    /// The final distance, or nil if it was let go without moving.
    var ended: (CGSize?) -> Void
    /// A quick sideways flick, without holding first: true towards the leading side.
    var flicked: (Bool) -> Void = { _ in }
}

/// The card a panel was picked up by, and where (in the window).
struct CarryGrab: Equatable {
    var point: CGPoint
    var title: String?
    var icon: String?
}

/// Where things are while a finger moves them. Kept apart from the main screen's own state so
/// a drag only redraws the piece that moves, not the whole screen (owner, 22 Oct 2026: "it just
/// feels slow"). Each value is read only by the small modifiers below.
@Observable final class LiveMotion {
    var cardDrag = CGSize.zero
    var clockPinch: CGFloat = 1
    /// Where between the fingers the pinch started, so the widget grows from there.
    var pinchAnchor = UnitPoint.center
    var cardLean = CGSize.zero
    var groupsMove = CGSize.zero
    var settingsMove = CGSize.zero
    var railMove = CGSize.zero
    var panelPull: CGFloat = 0
    /// The settings list's scroll position (0 top … 1 bottom), how much of it shows, and whether
    /// it's moving, for the glass scroll bar.
    var scrollFraction: CGFloat = 0
    var scrollVisible: CGFloat = 1
    var scrolling = false
    /// No movement, for a view that only sometimes follows one of the others.
    let none = CGSize.zero
}

/// Moves a view by one of the live distances.
struct LiveOffset: ViewModifier {
    var motion: LiveMotion
    var path: KeyPath<LiveMotion, CGSize>

    func body(content: Content) -> some View {
        content.offset(motion[keyPath: path])
    }
}

/// The widget's lean while it's dragged: a soft tilt towards where it's going and a slight
/// stretch along the way.
struct LiveLean: ViewModifier {
    var motion: LiveMotion
    var strength: CGFloat
    var still: Bool

    func body(content: Content) -> some View {
        let lean = still ? .zero : motion.cardLean
        let turn = Double(lean.width * strength) * 7, tip = Double(-lean.height * strength) * 7
        let stretchX = 1 + (abs(lean.width) * 0.035 - abs(lean.height) * 0.015) * strength
        let stretchY = 1 + (abs(lean.height) * 0.035 - abs(lean.width) * 0.015) * strength
        content
            .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(tip), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(x: stretchX, y: stretchY)
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.62), value: lean)
    }
}

/// The widget grows and shrinks with the fingers while pinching.
struct LivePinch: ViewModifier {
    var motion: LiveMotion
    var still: Bool

    /// Follows the fingers freely, only stiffening past the smallest and largest sizes (owner,
    /// 22 Oct 2026: "it needs to follow the finger a little bit more freely").
    func body(content: Content) -> some View {
        let m = motion.clockPinch
        let free = m < 0.3 ? 0.3 - (0.3 - m) * 0.25 : m > 2.6 ? 2.6 + (m - 2.6) * 0.25 : m
        content.scaleEffect(still ? 1 : free, anchor: motion.pinchAnchor)
    }
}

/// How far the preview leans while a swipe is under way: it follows the finger at first,
/// then stiffens, so a swipe feels like pulling on something.
struct LivePull: ViewModifier {
    var motion: LiveMotion
    var still: Bool

    func body(content: Content) -> some View {
        let x = motion.panelPull, limit: CGFloat = 36
        content.offset(x: still ? 0 : limit * (1 - exp(-abs(x) / 120)) * (x < 0 ? -1 : 1))
    }
}

/// Where a carried panel would settle if let go now. It changes only a few times in a drag, so
/// the outline showing it costs little.
struct CarryTarget: Equatable {
    var groups: Bool
    var leading: Bool
    var top: Bool
    var attach: GroupsAttachment?
}

/// A scroll bar of Liquid Glass for the settings list (owner, 22 Oct 2026), in place of the
/// system's thin grey one: a small pill of glass that shows while the list moves, then fades.
/// It reads the live scroll position, so scrolling redraws only the bar.
struct GlassScrollBar: View {
    var motion: LiveMotion

    var body: some View {
        GeometryReader { track in
            let height = max(44, track.size.height * min(1, motion.scrollVisible))
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: motion.scrolling ? 8 : 6, height: height)
                .appGlass(.capsule)
                .offset(y: (track.size.height - height) * min(1, max(0, motion.scrollFraction)))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: 10)
        .opacity(motion.scrolling && motion.scrollVisible < 1 ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(motion.scrolling ? 0 : 0.9), value: motion.scrolling)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: motion.scrolling)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
