import SwiftUI

// DASHBOARD · plugin v1 (On trial). Your Glass Clock Progress dashboard inside the Sandbox: where things are,
// what needs you and what's due. Read-only: nothing here changes the real dashboard. Other plugins add their
// sections to its panel (`addsTo: "dashboard"`), so the dashboard grows one small plugin at a time.
// Data: `dashboard.json` packed into the app at build (the web sandbox's data/dashboard.json shape), or, until
// that's packed in, the snapshot below. No network. Works the same with Pip off; Pip adds one line at most.
// Where: the dashboard button in the plugin bar.

struct Dashboard: SandboxPlugin {
    let info = PluginInfo(id: "dashboard", name: "Dashboard", version: "v1", shelf: .trial,
                          icon: "chart.bar.doc.horizontal", what: "Your progress dashboard, read-only, with room for more.",
                          panel: true)

    // MARK: Data

    /// The snapshot used until the build packs in a fresh `dashboard.json`: the web sandbox's
    /// data/dashboard.json, synced 29 Oct 2026. The make-believe name stands in for the homage one.
    static let snapshot = #"""
    {
     "syncedAt": "2026-10-29T19:45:00Z",
     "source": "Glass Clock Progress",
     "status": {
      "headline": "Tue 27 Oct, 7:15 pm: iPad app reinstalled and working (sign-in lasts to 3 Nov). Fresh widgets are at the top, widgets pack together (Float in Arrange), Figma button added, brand board started in Figma. Waiting for the Wednesday 2 pm reset: pricing research, Moods plan, in-app fairy.",
      "ipadBuild": "Clean reinstall · 7:05 pm",
      "ipadNote": "Same app, freshly signed. Your saved styles were reset by the reinstall. Free sign-in expires Tue 3 Nov.",
      "updatedAt": "Tue 27 Oct, 7:15 pm"
     },
     "needsYou": [
      { "q": "Where does Pip live on this board for now?", "suggested": "Brief only, no panel (suggested)" },
      { "q": "Should Pip be a little bit more present for unpaid users?", "suggested": "Same for everyone, tiny and switch-off-able (suggested)" },
      { "q": "Should the Wednesday Build list go ahead now?", "suggested": "Yes, send Build: when ready, list as saved (suggested)" }
     ],
     "upNext": [
      { "area": "Dashboard", "title": "Make the dashboard feel alive (small touches)" }
     ],
     "reminders": [
      { "title": "Check Canva trial and cancel", "due": "2026-11-03T09:00:00Z" }
     ]
    }
    """#

    static let pipLine = "Here's where Glass Clock is up to."

    // MARK: Logic

    /// Loaded once: the packed-in file if there is one, otherwise the snapshot.
    static let feed: (data: DashboardData, packed: Bool) = {
        if let url = Bundle.main.url(forResource: "dashboard", withExtension: "json"),
           let raw = try? Data(contentsOf: url),
           let data = try? JSONDecoder().decode(DashboardData.self, from: raw) {
            return (data, true)
        }
        let data = (try? JSONDecoder().decode(DashboardData.self, from: Data(snapshot.utf8))) ?? DashboardData()
        return (data, false)
    }()

    /// "Updated Thu 29 Oct, 7:45 pm", or "Snapshot, …" while no fresh file has been packed in.
    static var freshness: String {
        let when = date(feed.data.syncedAt) ?? "an unknown date"
        return feed.packed ? "Updated \(when)" : "Snapshot, \(when). Fresh numbers arrive with the next build."
    }

    /// An ISO date as "Thu 29 Oct, 7:45 pm".
    static func date(_ text: String?) -> String? {
        guard let text else { return nil }
        let iso = ISO8601DateFormatter()
        var parsed = iso.date(from: text)
        if parsed == nil {
            iso.formatOptions.insert(.withFractionalSeconds)
            parsed = iso.date(from: text)
        }
        guard let parsed else { return text }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_GB")
        out.dateFormat = "EEE d MMM, h:mm a"
        return out.string(from: parsed)
    }

    /// Keeps homage names out of what's shown.
    static func clean(_ text: String) -> String { text.replacingOccurrences(of: "Navi", with: "Pip") }

    /// Pip says one line, once a session, when the panel first opens.
    @MainActor final class Mind {
        private var said = false

        func greet(_ host: PipHost) {
            guard !said else { return }
            host.later(0.4) {
                if host.say(Dashboard.pipLine, for: 1.8) { self.said = true }
            }
        }
    }

    private let mind = Mind()

    // MARK: Views

    func card(_ host: PipHost) -> some View {
        Board(data: Dashboard.feed.data)
            .onAppear { mind.greet(host) }
    }

    struct Board: View {
        let data: DashboardData

        var body: some View {
            VStack(spacing: Corner.inset) {
                SettingsCard(title: "Where we are", icon: "location", footer: Dashboard.freshness) {
                    if let headline = data.status?.headline {
                        Text(Dashboard.clean(headline))
                    }
                    if let build = data.status?.ipadBuild {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("On the iPad: \(build)")
                            if let note = data.status?.ipadNote {
                                Text(Dashboard.clean(note)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if let asks = data.needsYou, !asks.isEmpty {
                    SettingsCard(title: "Needs you", icon: "questionmark.bubble") {
                        ForEach(asks.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Dashboard.clean(asks[i].q))
                                if let s = asks[i].suggested {
                                    Text(Dashboard.clean(s)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                if let due = data.reminders, !due.isEmpty {
                    SettingsCard(title: "Reminders", icon: "bell") {
                        ForEach(due.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Dashboard.clean(due[i].title))
                                if let when = Dashboard.date(due[i].due) {
                                    Text(when).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}

/// The dashboard's data, in the web sandbox's data/dashboard.json shape. Every part is optional, and
/// parts the app doesn't show yet (builds, usage, principles) are skipped.
struct DashboardData: Codable, Sendable {
    struct Status: Codable, Sendable {
        var headline: String?
        var ipadBuild: String?
        var ipadNote: String?
        var updatedAt: String?
    }

    struct Ask: Codable, Sendable {
        var q: String
        var suggested: String?
    }

    struct Step: Codable, Sendable {
        var area: String?
        var title: String
    }

    struct Reminder: Codable, Sendable {
        var title: String
        var due: String?
    }

    var syncedAt: String?
    var source: String?
    var status: Status?
    var needsYou: [Ask]?
    var upNext: [Step]?
    var reminders: [Reminder]?
}
