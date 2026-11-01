import SwiftUI
import UIKit
import WidgetKit

// PIP ON THE HOME SCREEN · plugin v1 (Dream), Jules 1 Nov 2026. Aaron: "he will be floating around in widgets soon…
// linked up from the clock widget to one of my dashboard widgets… float around between the dashboard's widgets".
// Pip lives in one of your Home Screen widgets (the clock, or a Pip Dashboard widget). Tap him there and he hops to the
// next one. iOS keeps each widget in its own box, so he pops out of one and into the next (an old-game screen hop).
// The app saves a picture of Pip in his current look (Classic, Drop or Blobby, from Pip Looks) whenever you leave the
// app, and the widgets show it. Pip switched off, or this plugin off: he leaves the Home Screen.
// Shared parts: Shared/PipWidgetHome.swift (where he is, his picture), GlassClockWidget/PipWidgetVisit.swift (the hop).

struct PipHomeScreen: SandboxPlugin {
    let info = PluginInfo(id: "homescreen", name: "Pip on the Home Screen", version: "v1", shelf: .dream,
                          icon: "square.grid.2x2", what: "Pip lives in one of your Home Screen widgets. Tap him there and he hops to the next.")

    // MARK: Logic

    func start(_ host: PipHost) throws {
        PipHomeScreen.listen(host)
        PipHomeScreen.publish(host)
    }

    @MainActor private static var listening = false

    /// Saves him each time you leave the app (that's when you'll see the Home Screen) and when you come back.
    @MainActor static func listen(_ host: PipHost) {
        guard !listening else { return }
        listening = true
        for name in [UIApplication.willResignActiveNotification, UIApplication.didBecomeActiveNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { PipHomeScreen.publish(host) }
            }
        }
    }

    /// Pip's picture for the widgets, in his current look; nothing when Pip or this plugin is off.
    @MainActor static func publish(_ host: PipHost) {
        guard host.pipOn, host.isOn("homescreen") else {
            PipWidgetHome.setPicture(nil)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        let renderer = ImageRenderer(content: portrait(host))
        renderer.scale = 3
        PipWidgetHome.setPicture(renderer.uiImage?.pngData())
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Pip at rest, three-quarter, as the widget shows him (about 60 pt).
    @MainActor static func portrait(_ host: PipHost) -> some View {
        let look: PipLooks.Look = host.isOn("looks") ? PipLooks.chosen(host) : .classic
        let r: CGFloat = 9
        return Group {
            switch look {
            case .blobby:
                let rig = BlobbyRig()
                let frame = (0..<90).map { i in rig.step(pos: .zero, r: r, time: 1 + Double(i) / 60, target: 1, toYou: 0, simpler: false) }.last
                    ?? BlobbyFrame()
                PipBlobbyBody(radius: r, frame: frame, time: 2.5)
            case .drop:
                PipLooks.dropView(face: .awake, look: .zero, time: 0, size: r * 2, simpler: true, flapping: false)
            case .classic:
                PipBody(face: .awake, flap: 0.5, look: .zero, size: r * 2.6)
            }
        }
        .frame(width: r * 8, height: r * 8)
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { HomeCard(host: host) }

    struct HomeCard: View {
        let host: PipHost
        @State private var here = PipWidgetHome.home

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("Pip lives in one of your Home Screen widgets: the clock, or a Pip Dashboard widget. Tap him there and he hops to the next one.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Now: \(name(here))").font(.system(size: 13.5, weight: .semibold))
                Button("Send Pip back to the clock") {
                    PipWidgetHome.home = "clock"
                    here = "clock"
                    PipHomeScreen.publish(host)
                }
                .buttonStyle(PluginCardButton(on: false))
                Text("He wears the look you chose in Pip Looks. Add widgets: hold the Home Screen → Edit → Add Widget → Pip Sandbox.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 13.5))
        }

        private func name(_ spot: String) -> String {
            ["clock": "the clock", "needs": "Needs you", "upnext": "Up next", "progress": "Progress", "ideas": "Ideas",
             "forrob": "For Rob", "overview": "the dashboard overview"][spot] ?? spot
        }
    }
}
