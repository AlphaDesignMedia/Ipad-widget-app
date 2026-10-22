import SwiftUI
import WidgetKit

@main
struct GlassDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardHome()
        }
    }
}

/// The app is mostly a home for the widget: today's numbers, a way into the dashboard,
/// and how to put the widget on the Home Screen.
struct DashboardHome: View {
    @Environment(\.openURL) private var openURL
    @State private var status = StatusFeed.cached
    @State private var fresh = true
    @State private var loading = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.85), Color(red: 0.86, green: 0.9, blue: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Glass Dashboard")
                        .font(.largeTitle.weight(.bold))
                    numbers
                    actions
                    howTo
                }
                .padding(22)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Color(white: 0.12))
        .task { await refresh() }
        // A tap on the widget opens this app with the dashboard's address; pass it on to Safari.
        .onOpenURL { url in openURL(url) }
        .refreshable { await refresh() }
    }

    @ViewBuilder private var numbers: some View {
        if let status {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        Tile(label: "Need you", count: status.needYou, highlight: status.needYou > 0)
                        Tile(label: "To try on the iPad", count: status.toTry)
                        Tile(label: "Up next", count: status.upNext)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("On the iPad: \(status.ipadBuild)").font(.headline)
                        if let date = status.buildDate {
                            Text(date, format: .dateTime.weekday(.wide).hour().minute())
                                .foregroundStyle(.secondary)
                        }
                        Divider().padding(.vertical, 4)
                        Text("Latest: \(status.latestUpdate)")
                        UpdatedLine(status: status, fresh: fresh)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
                }
            }
        } else {
            Text(loading ? "Loading…" : "Couldn't reach the dashboard yet. Check the iPad is online, then pull down to try again.")
                .padding(22)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Link(destination: StatusFeed.dashboard) {
                Label("Open the dashboard", systemImage: "safari")
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)
            Button {
                Task { await refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .disabled(loading)
        }
        .controlSize(.large)
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add the widget").font(.headline)
            Text("1. Touch and hold an empty part of the Home Screen until the icons jiggle.")
            Text("2. Tap Edit at the top left, then Add Widget.")
            Text("3. Search for Glass Dashboard, pick small or medium, and tap Add Widget.")
            Text("It checks for new numbers every 20 minutes or so. Tap a number to open the dashboard in Safari.")
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func refresh() async {
        loading = true
        let result = await StatusFeed.load()
        status = result.status
        fresh = result.fresh
        loading = false
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct Tile: View {
    var label: String
    var count: Int
    var highlight = false

    var body: some View {
        Link(destination: StatusFeed.dashboard) {
            VStack(alignment: .leading, spacing: 4) {
                Text(count, format: .number)
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(highlight ? Color.orange : Color(white: 0.12))
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardHome()
}
