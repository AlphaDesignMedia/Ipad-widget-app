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
        case .widget: "Widget"
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
            "Your changes are kept in the app as you go. They reach the widget when you tap Apply to Widget, or when you leave the app if that's on. Reduce glass swaps the app's glass panels for solid ones; it's also automatic when Reduce Transparency is on in Settings. To add the clock: long-press your Home Screen, tap Edit, then Add Widget, and choose Glass Clock."
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

/// The app's own glass for panels and controls: Liquid Glass normally. When Reduce Transparency
/// is on in iPadOS Settings, or the app's Reduce glass switch is, it's a calm solid surface
/// instead, so the design doesn't lean on glass (HIG: Accessibility, Materials).
struct AppGlass<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @AppStorage("reduceGlass") private var reducesGlass = false
    var shape: S
    var interactive = false
    var tint: Color?

    func body(content: Content) -> some View {
        if systemReducesTransparency || reducesGlass {
            content
                .background {
                    shape.fill(.background.secondary)
                        .overlay { if let tint { shape.fill(tint.opacity(0.2)) } }
                        .overlay { shape.stroke(.separator, lineWidth: 1) }
                }
        } else {
            content.glassEffect((tint.map { Glass.regular.tint($0) } ?? .regular).interactive(interactive), in: shape)
        }
    }
}

extension View {
    func appGlass<S: Shape>(_ shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(AppGlass(shape: shape, interactive: interactive, tint: tint))
    }
}
