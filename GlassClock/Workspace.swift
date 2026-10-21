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

/// What's behind the preview card. Apps can't see the Home Screen wallpaper, so the closest
/// thing is a photo the person picks, such as a screenshot of their own Home Screen.
enum PreviewBackdrop: String, CaseIterable, Identifiable {
    case plain, aurora, sunset, ocean, graphite, photo
    var id: Self { self }

    var label: String {
        switch self {
        case .plain: "Plain"
        case .aurora: "Aurora"
        case .sunset: "Sunset"
        case .ocean: "Ocean"
        case .graphite: "Graphite"
        case .photo: "Your Photo"
        }
    }

    var colors: [Color] {
        switch self {
        case .plain, .photo: [.indigo, .teal, .orange]
        case .aurora: [.indigo, .teal, .orange]
        case .sunset: [.purple, .pink, .orange]
        case .ocean: [Color(red: 0.02, green: 0.1, blue: 0.35), .blue, .teal]
        case .graphite: [Color(white: 0.12), Color(white: 0.3), Color(white: 0.18)]
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
    case presets, layout, fonts, colour, effects, card, homeScreens, widget
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
        case .homeScreens: "Clear and Tinted Home Screens"
        case .widget: "App and Widget"
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
            "Your changes are kept in the app as you go. They reach the widget when you tap Apply to Widget, or when you leave the app if that's on. Theme sets the app's look: Glass, Crystal (more see-through) or Colour (tinted with the app colour). Appearance follows your iPad unless you pick Light or Dark. Reduce glass swaps the app's glass panels for solid ones; it's also automatic when Reduce Transparency is on in Settings. To add the clock: long-press your Home Screen, tap Edit, then Add Widget, and choose Glass Clock."
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
    case glass, frosted, colour
    var id: Self { self }

    var label: String {
        switch self {
        case .glass: "Glass"
        case .frosted: "Frosted"
        case .colour: "Colour"
        }
    }
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
}

/// The app's own glass for panels and controls, in the chosen theme. When Reduce Transparency
/// is on in iPadOS Settings, or the app's Reduce glass switch is, it's a calm solid surface
/// instead, so the design doesn't lean on glass (HIG: Accessibility, Materials).
struct AppGlass<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
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
            content.glassEffect(glass.interactive(interactive), in: shape)
        }
    }

    private var glass: Glass {
        if let tint { return .regular.tint(tint) }
        switch theme {
        // Clear all the way; readability comes from the frosted cards inside panels
        // (`SettingsCard`) rather than from tinting the glass.
        case .glass: return .clear
        case .frosted: return .regular
        case .colour: return .regular.tint(AppColor.resolve(appColor).opacity(panel ? 0.22 : 0.3))
        }
    }
}

/// Corner rounding, kept concentric (owner feedback 2026-10-21): a box inside a panel is
/// rounded by the panel's radius minus the gap between them, so their curves run parallel.
enum Corner {
    /// The floating panels.
    static let panel: CGFloat = 36
    /// The gap between a panel's edge and the cards inside it, and between cards, so the
    /// spacing reads as one even rhythm.
    static let inset: CGFloat = 16
    /// The cards of settings inside a panel.
    static let card: CGFloat = panel - inset
    /// Padding inside a card, around its rows.
    static let cardPadding: CGFloat = 18
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
    /// The group's title, tucked inside the top of the card (owner feedback, 2026-10-21).
    var title: String?
    var icon: String?
    var highlighted = false
    /// A short note at the bottom of the card.
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Corner.card, style: .continuous)
        let glassy = theme == .glass && !systemReducesTransparency && !reducesGlass
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Label {
                    Text(title).foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                } icon: {
                    if let icon { Image(systemName: icon).foregroundStyle(.tint) }
                }
                .font(.title3.weight(.semibold))
                .padding(.top, 16)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            }
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    row.padding(.vertical, 11)
                    if row.id != rows.last?.id { Divider() }
                }
            }
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 14)
            }
        }
        // Tinted text (buttons, values) is lightened in Dark so it stays readable on the glass.
        .tint(colorScheme == .dark ? tint.mix(with: .white, by: 0.35) : tint)
        .padding(.horizontal, Corner.cardPadding)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                if glassy {
                    GlassAmount.backing(glassAmount, in: shape)
                } else {
                    shape.fill(.background.secondary)
                }
                if highlighted { shape.fill(Color.accentColor.opacity(0.14)) }
            }
        }
        .modifier(CardGlass(on: glassy, shape: shape))
    }

    private var tint: Color { AppColor.resolve(appColor) }
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
        if theme == .glass && !systemReducesTransparency && !reducesGlass {
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
    var amount: Double
    var shape: S

    var body: some View {
        ZStack {
            shape.fill(colorScheme == .dark ? Color.black : .white)
                .opacity(0.22 + 0.2 * (1 - amount))
            shape.fill(.ultraThinMaterial)
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
