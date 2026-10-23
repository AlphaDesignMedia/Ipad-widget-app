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

    /// One download, then WidgetKit asks again in about 20 minutes (72 reloads a day at most,
    /// and iPadOS spaces them out to fit its daily budget). Offline, it tries again sooner.
    /// The same numbers are repeated every 5 minutes so "Updated X ago" keeps counting.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        Task {
            let result = await StatusFeed.load()
            let minutes = result.fresh ? 20 : 10
            let entries = stride(from: 0, to: minutes, by: 5).map { offset in
                DashboardEntry(date: .now.addingTimeInterval(Double(offset * 60)),
                               status: result.status, fresh: result.fresh)
            }
            completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(Double(minutes * 60)))))
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
                    MediumFace(status: status, fresh: entry.fresh, now: entry.date)
                } else {
                    SmallFace(status: status)
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
