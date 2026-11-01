import SwiftUI
import WidgetKit

// DASHBOARD ON THE HOME SCREEN · part of the Dashboard plugin (Jules, 1 Nov). Aaron: "the dashboard with real widgets".
// Saves a small copy of the dashboard (Shared/DashboardSnapshot.swift) for the Pip Dashboard Home Screen widget
// (GlassClockWidget/PipDashboardWidget.swift), and asks just that widget to redraw when the copy changes.
// When: at launch, when the live board arrives, and on every answer. Unchanged copies aren't saved again,
// so it costs nothing while nothing changes. Nothing leaves the iPad.

extension Dashboard {

    /// The copy as the widget sees it: plain lines, cleaned, unanswered questions only.
    @MainActor static func homeScreenCopy(_ data: DashboardData, _ host: PipHost) -> DashboardSnapshot {
        let most = DashboardSnapshot.most
        func lines(_ list: [String]) -> [String] { Array(list.map(clean).filter { !$0.isEmpty }.prefix(most)) }
        return DashboardSnapshot(
            boardAt: data.syncedAt,
            headline: data.status?.headline.map(glance),
            needs: (data.needsYou ?? []).filter { answer($0.q, host) == nil }.prefix(most).map {
                DashboardSnapshot.Need(text: clean($0.q), key: stableKey($0.q), suggested: $0.suggested.map(clean))
            },
            upNext: lines((data.upNext ?? []).map(\.title)),
            forRob: lines((data.outboxForRob ?? []).filter { $0.done != true }.map(\.command)),
            ideas: lines((data.ideas ?? []).compactMap(\.title)),
            reminders: lines((data.reminders ?? []).map(\.title)))
    }

    /// Takes in answers given on the Home Screen widget (Yes / Not yet), as if you'd tapped them in the app, then
    /// refreshes the widget's copy. At launch and each time the app comes back to the front.
    @MainActor static func takeHomeAnswers(_ host: PipHost) {
        let inbox = DashboardSnapshot.homeAnswers()
        if !inbox.isEmpty {
            for (key, raw) in inbox where Answer(rawValue: raw) != nil { host.setValue(raw, "dashboard", key) }
            DashboardSnapshot.clearHomeAnswers()
            AnswerBook.shared.changes += 1
        }
        publish(host)
    }

    /// Listens for the app coming back to the front, once, however often the plugin is switched on.
    @MainActor private static var listening = false
    @MainActor static func listenForHomeAnswers(_ host: PipHost) {
        guard !listening else { return }
        listening = true
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Dashboard.takeHomeAnswers(host) }
        }
    }

    /// Saves the copy and redraws the widget, only if something changed.
    /// Takes the host (not `PipHost.shared`): at launch it runs while the host is still starting the plugins.
    @MainActor static func publish(_ host: PipHost) {
        if homeScreenCopy(Feed.shared.data, host).save() {
            WidgetCenter.shared.reloadTimelines(ofKind: DashboardSnapshot.widgetKind)
        }
    }
}
