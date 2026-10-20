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

    /// One entry per minute for the next hour, then WidgetKit asks for more.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let style = ClockStyle.load()
        let calendar = Calendar.current
        let startOfMinute = calendar.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).compactMap { offset in
            calendar.date(byAdding: .minute, value: offset, to: startOfMinute)
                .map { ClockEntry(date: $0, style: style) }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct GlassClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ClockEntry

    var body: some View {
        clock
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
        ClockFace(date: entry.date, style: entry.style, family: family)
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
    }
}

@main
struct GlassClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlassClockWidget()
    }
}
