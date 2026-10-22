import SwiftUI
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let style: ClockStyle
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: .now, style: ClockStyle())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: .now, style: .load()))
    }

    /// One entry per minute, then WidgetKit asks for more. An hour at a time, or less when parts
    /// keep their colours: their images make each entry much bigger, and iPadOS rejects a
    /// timeline archive over roughly 10 MB, which stops the clock (observed 2026-10-20).
    /// 40 minutes is 36 reloads a day and 30 is 48, inside the usual daily budget of 40–70.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let style = ClockStyle.load()
        let calendar = Calendar.current
        let startOfMinute = calendar.dateInterval(of: .minute, for: .now)?.start ?? .now
        // A kept-colour time is stored as a picture per minute, the biggest cost of all
        // (11 MB an hour with a glass style, rejected; observed 2026-10-20).
        // 30 minutes whenever anything keeps its colours, leaving headroom on the device.
        let minutes = style.keepsTimeColours || style.keepsDetailColours || style.keepsCardColours ? 30 : 60
        let entries = (0..<minutes).compactMap { offset in
            calendar.date(byAdding: .minute, value: offset, to: startOfMinute)
                .map { ClockEntry(date: $0, style: style) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct GlassClockWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    var entry: ClockEntry

    var body: some View {
        ZStack {
            // In Clear and Tinted mode the system replaces the container background below
            // with its own glass. To keep the card's colours there, it's drawn again as a
            // full-colour image filling the widget (content margins are off for this).
            if renderingMode == .accented && entry.style.keepsCardColours {
                GeometryReader { geometry in
                    Image(uiImage: ClockRaster.card(style: entry.style, size: geometry.size,
                                                    dark: colorScheme == .dark))
                        .resizable(capInsets: ClockRaster.cardInsets(entry.style))
                        .widgetAccentedRenderingMode(.fullColor)
                        // Cropped to the widget's shape, the same way the kept time is, which
                        // is what kept its colour on iPadOS 27 (2026-10-20).
                        .clipShape(ContainerRelativeShape())
                }
            }
            clock
                .padding(16)   // the system's standard margin, since content margins are off
        }
            .containerBackground(for: .widget) {
                // Only used in full-colour mode. In the Clear and Tinted Home Screen
                // appearances the system removes this and draws real Liquid Glass itself.
                // Widgets can't sample the wallpaper, so `glassEffect` isn't used here.
                Group {
                    switch entry.style.background {
                    case .glass:
                        GlassCardBackground(tint: entry.style.cardTint, strength: entry.style.cardOpacity)
                    case .solid:
                        entry.style.solidFill.opacity(entry.style.cardOpacity)
                    }
                }
            }
    }

    /// In Clear and Tinted modes the system draws the clock in its own colour and keeps only
    /// how see-through each part is. `ClockFace` builds its glass from transparency there, so
    /// the digits still read as glass. (Drawing the clock into a full-colour image to keep our
    /// colours left the widget blank on iPadOS 27, observed 2026-10-20.)
    private var clock: some View {
        ClockFace(date: entry.date, style: entry.style)
    }
}

/// Glass for full-colour mode, modelled on Apple's glass shapes: a nearly clear body
/// (the chosen colour as a light wash), a bright rim that catches light at the top-left
/// and bottom-right corners, and a soft glow just inside the edge.
struct GlassCardBackground: View {
    var tint: Color?
    /// 0 is no card; 1 is the strongest wash of colour.
    var strength: Double

    var body: some View {
        let shape = ContainerRelativeShape()
        ZStack {
            (tint ?? .white).opacity(0.05 + 0.2 * strength)
            // Light glowing just inside the edge, like the thickness of the glass.
            shape
                .strokeBorder(.white.opacity(0.2), lineWidth: 10)
                .blur(radius: 8)
                .clipShape(shape)
            // The rim: brightest where light would hit the corners.
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.95), location: 0),
                        .init(color: .white.opacity(0.2), location: 0.35),
                        .init(color: .white.opacity(0.15), location: 0.65),
                        .init(color: .white.opacity(0.8), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
        }
        .opacity(strength == 0 ? 0 : 1)
    }
}

struct GlassClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GlassClockWidget", provider: ClockProvider()) { entry in
            GlassClockWidgetView(entry: entry)
        }
        .configurationDisplayName("Glass Clock")
        .description("See the time in the style you design in the Glass Clock app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct GlassClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlassClockWidget()
    }
}
