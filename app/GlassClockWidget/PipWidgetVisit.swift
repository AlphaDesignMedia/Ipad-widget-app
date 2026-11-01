import SwiftUI
import WidgetKit
import AppIntents

// PIP IN THE WIDGETS (Jules, 1 Nov 2026): the widget side of Shared/PipWidgetHome.swift. Pip sits in a corner of the
// widget he's in; tap him and he hops to the next widget on the Home Screen (clock → Needs you → Up next → …).

/// Tapping Pip in a widget: he hops to the next widget you have.
struct PipHopIntent: AppIntent {
    static var title: LocalizedStringResource { "Send Pip to another widget" }
    static var isDiscoverable: Bool { false }

    init() {}

    func perform() async throws -> some IntentResult {
        let infos: [WidgetInfo] = await withCheckedContinuation { done in
            WidgetCenter.shared.getCurrentConfigurations { result in done.resume(returning: (try? result.get()) ?? []) }
        }
        var homes: [String] = []
        for info in infos {
            if info.kind == PipWidgetHome.clockKind {
                homes.append("clock")
            } else if info.kind == DashboardSnapshot.widgetKind,
                      let config = info.widgetConfigurationIntent(of: DashboardWidgetIntent.self) {
                homes.append(config.part.rawValue)
            }
        }
        PipWidgetHome.home = PipWidgetHome.next(after: PipWidgetHome.home, among: homes)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Pip in a widget's corner, if this is where he is. `spot`: "clock" or the dashboard part this widget shows.
struct PipInWidget: View {
    let spot: String

    var body: some View {
        if PipWidgetHome.home == spot, let picture = PipWidgetHome.picture {
            Button(intent: PipHopIntent()) {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .widgetAccentedRenderingMode(.fullColor)
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.3).combined(with: .opacity))       // he pops in (and out of the last one)
            .accessibilityLabel("Pip")
            .accessibilityHint("Sends Pip to another of your widgets.")
        }
    }
}
