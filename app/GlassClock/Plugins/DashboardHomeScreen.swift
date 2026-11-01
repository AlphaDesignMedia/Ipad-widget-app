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
            needs: lines((data.needsYou ?? []).filter { answer($0.q, host) == nil }.map(\.q)),
            upNext: lines((data.upNext ?? []).map(\.title)),
            forRob: lines((data.outboxForRob ?? []).filter { $0.done != true }.map(\.command)),
            ideas: lines((data.ideas ?? []).compactMap(\.title)),
            reminders: lines((data.reminders ?? []).map(\.title)))
    }

    /// Saves the copy and redraws the widget, only if something changed.
    /// Takes the host (not `PipHost.shared`): at launch it runs while the host is still starting the plugins.
    @MainActor static func publish(_ host: PipHost) {
        if homeScreenCopy(Feed.shared.data, host).save() {
            WidgetCenter.shared.reloadTimelines(ofKind: DashboardSnapshot.widgetKind)
        }
    }
}
