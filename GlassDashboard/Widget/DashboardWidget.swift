import SwiftUI
import WidgetKit

struct DashboardEntry: TimelineEntry {
    let date: Date
    let status: DashboardStatus?
    /// False when the download failed and this is the last known status.
    let fresh: Bool
}

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: .now, status: .sample, fresh: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        if context.isPreview {
            completion(DashboardEntry(date: .now, status: StatusFeed.cached ?? .sample, fresh: true))
            return
        }
        Task {
            let result = await StatusFeed.load()
            completion(DashboardEntry(date: .now, status: result.status, fresh: result.fresh))
        }
    }

    /// One entry, then WidgetKit asks again in about 20 minutes (72 reloads a day at most,
    /// and iPadOS spaces them out to fit its daily budget). Offline, it tries again sooner.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        Task {
            let result = await StatusFeed.load()
            let entry = DashboardEntry(date: .now, status: result.status, fresh: result.fresh)
            let next = Date.now.addingTimeInterval(result.fresh ? 20 * 60 : 10 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct DashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DashboardEntry

    var body: some View {
        Group {
            if let status = entry.status {
                if family == .systemMedium {
                    medium(status)
                } else {
                    small(status)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Glass Dashboard").font(.headline)
                    Text("Waiting for the first update. Check the iPad is online.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(StatusFeed.dashboard)
        .containerBackground(for: .widget) {
            // Removed by iPadOS in the Clear and Tinted Home Screens, which draw real Liquid
            // Glass instead (DESIGN_SYSTEM.md §1). Widgets can't sample the wallpaper.
            DashboardBackground()
        }
    }

    private func small(_ status: DashboardStatus) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NeedYou(count: status.needYou)
            Spacer(minLength: 4)
            BuildLine(status: status)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ status: DashboardStatus) -> some View {
        HStack(alignment: .top, spacing: 16) {
            small(status)
            VStack(alignment: .leading, spacing: 8) {
                Link(destination: StatusFeed.dashboard) {
                    CountRow(label: "To try on the iPad", count: status.toTry)
                }
                Link(destination: StatusFeed.dashboard) {
                    CountRow(label: "Up next", count: status.upNext)
                }
                Spacer(minLength: 2)
                Text(status.latestUpdate)
                    .font(.footnote.weight(.medium))
                    .lineLimit(2)
                UpdatedLine(status: status, fresh: entry.fresh)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// The headline number: how many questions on the dashboard are waiting for an answer.
private struct NeedYou: View {
    var count: Int

    var body: some View {
        Link(destination: StatusFeed.dashboard) {
            VStack(alignment: .leading, spacing: 0) {
                Text("NEED YOU")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(count, format: .number)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(count > 0 ? Color.orange : Color.primary)
                    .widgetAccentable()
                    .contentTransition(.numericText())
            }
        }
    }
}

private struct BuildLine: View {
    var status: DashboardStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(status.ipadBuild.isEmpty ? "No build yet" : status.ipadBuild)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            if let date = status.buildDate {
                Text("On iPad · \(date, format: .dateTime.weekday(.abbreviated).hour().minute())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct CountRow: View {
    var label: String
    var count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(count, format: .number)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .widgetAccentable()
        }
    }
}

/// A light frosted wash with a bright rim, in the spirit of Glass Clock's GlassCardBackground.
struct DashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            LinearGradient(colors: [Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.10), .clear],
                           startPoint: .topLeading, endPoint: .center)
            ContainerRelativeShape()
                .strokeBorder(LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.25 : 0.7), .clear,
                                                      .white.opacity(colorScheme == .dark ? 0.12 : 0.4)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 1)
        }
    }
}

struct DashboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GlassDashboard", provider: DashboardProvider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Glass Dashboard")
        .description("See what needs you and what's on your iPad, from your progress dashboard.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct GlassDashboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        DashboardWidget()
    }
}

#Preview(as: .systemMedium) {
    DashboardWidget()
} timeline: {
    DashboardEntry(date: .now, status: .sample, fresh: true)
    DashboardEntry(date: .now, status: .sample, fresh: false)
}
