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
    /// data/dashboard.json, synced 31 Oct 2026 (3:15 pm). The make-believe name stands in for the homage one.
    static let snapshot = #"""
    {
     "syncedAt": "2026-10-31T15:15:00Z",
     "source": "Glass Clock Progress",
     "url": "https://claude.ai/artifact/UQ9Yo6F6RBNdoUn8B9sqeW",
     "status": {
      "headline": "Sat 31 Oct: slow and steady day. Pause all proved the stutters are plugins, not the app. Glass Memory and Window Cleaner made light and parked. Dashboard is now a Glass Clock tile on the canvas. Robyn and Rob have job sheets; Peter and Monty joined the team. The Brief: https://claude.ai/artifact/Crwy8KDwPoVGB4pp5Z1qKP",
      "ipadBuild": "Clean reinstall · 7:05 pm",
      "ipadNote": "Same app, freshly signed. Your saved styles were reset by the reinstall. Free sign-in expires Tue 3 Nov.",
      "updatedAt": "Sat 31 Oct, 3:15 pm"
     },
     "needsYou": [
      {
       "q": "Pick your tester circle (family and friends with iPads)?",
       "suggested": "Start with 3 to 5, including one 'Dad test' tester (suggested)"
      },
      {
       "q": "Keep a Pandora's Box page (every worry as a joke disaster, with its real guard)?",
       "suggested": "Yes, small and fun (suggested)"
      }
     ],
     "upNext": [
      {
       "area": "Launch",
       "title": "TestFlight beta for Glass Clock. North star: the Dad test (a 75-year-old adds a Glass Clock widget alone)"
      },
      {
       "area": "Launch",
       "title": "A one-page, big-text tester guide: install TestFlight, add a widget, tell Aaron how it felt"
      },
      {
       "area": "Stability",
       "title": "Rob: polite Mac, then hire Tess the Tester (simulator only)"
      },
      {
       "area": "Core",
       "title": "Robyn: buttons follow the theme, then plugins in the top bar"
      },
      {
       "area": "Core",
       "title": "Robyn: safety levels on Pause (Paused, Safe, Experimental, Everything)"
      },
      {
       "area": "Core",
       "title": "Robyn: one kind of panel, with a close button"
      },
      {
       "area": "Plugins",
       "title": "Plugin Kit: checker live on every push; next, shared parts and a starter template"
      },
      {
       "area": "Plugins",
       "title": "Mappy: families and the timeline, from the Plugin Map"
      },
      {
       "area": "Dashboard",
       "title": "Dashboard tile moves to the top bar once Robyn's hook lands"
      }
     ],
     "builds": [
      {
       "at": "2026-10-27T19:05:00Z",
       "title": "Clean reinstall after the sign-in expired",
       "changes": [
        "Xcode signed back in; app trusted on the iPad",
        "Widget updates again (it had frozen at 3:47 pm)",
        "Saved styles were reset by the reinstall"
       ]
      },
      {
       "at": "2026-10-25T18:45:00Z",
       "title": "Friend test build 2",
       "changes": [
        "Accessibility: Outline everything, with an Outline width slider",
        "Automatic app colour: a calm blue, deeper in Light, lighter in Dark"
       ]
      },
      {
       "at": "2026-10-25T18:37:00Z",
       "title": "Friend test build",
       "changes": [
        "Moods: quick cross-fade, fast taps queue",
        "Arrange menu: Best for This Window, Groups Along the Bottom, Settings Only"
       ]
      }
     ],
     "reminders": [
      {
       "title": "Check Canva trial and cancel",
       "due": "2026-11-03T09:00:00Z"
      }
     ],
     "principles": [
      "The default works every time",
      "Small, specific wins",
      "One job per feature",
      "Undo everything",
      "Contrast first, then glass",
      "Right first time, not final",
      "Design is his"
     ],
     "ideas": [
      {
       "title": "Pip, design partner (Chappie's brief): offline first, a 'FOR CHAPPIE' copy button, no AI inside Pip",
       "branch": "Pip",
       "status": "🌱 seed",
       "date": "2026-10-31"
      },
      {
       "title": "Plugin Kit: shared parts, rulebook, starter template",
       "branch": "Panels › lots of features",
       "status": "building",
       "date": "2026-10-31"
      },
      {
       "title": "Plugin keys: only allowed builders get the Kit",
       "branch": "Panels › lots of features",
       "status": "seed",
       "date": "2026-10-31"
      },
      {
       "title": "Friends build plugins, behind the Gate",
       "branch": "Panels › customise everything",
       "status": "seed",
       "date": "2026-10-31"
      },
      {
       "title": "Top bar: timeline, eras, moods, dashboard",
       "branch": "UI › clean",
       "status": "sketched",
       "date": "2026-10-31"
      },
      {
       "title": "Safety levels: Paused, Safe, Experimental, Everything",
       "branch": "UI › user friendly",
       "status": "sketched",
       "date": "2026-10-31"
      },
      {
       "title": "Panels with a close button that tuck while you draw",
       "branch": "UI › user friendly",
       "status": "sketched",
       "date": "2026-10-31"
      },
      {
       "title": "Dashboard as the mainframe (status here, not in chats)",
       "branch": "Moods › unintrusive reminders",
       "status": "building",
       "date": "2026-10-31"
      },
      {
       "title": "Dev diary with pictures",
       "branch": "(how it's made)",
       "status": "building",
       "date": "2026-10-31"
      },
      {
       "title": "Findings Book: what real testers did and said",
       "branch": "(how it's made)",
       "status": "seed",
       "date": "2026-10-31"
      },
      {
       "title": "The Dad test and the Pip test",
       "branch": "Classic › easy to understand",
       "status": "sketched",
       "date": "2026-10-31"
      },
      {
       "title": "Pandora's Box page (worries as joke disasters, with real guards)",
       "branch": "Be kind",
       "status": "seed",
       "date": "2026-10-31"
      },
      {
       "title": "Rebuild alphadesign.media with the new way of working",
       "branch": "(beyond the app)",
       "status": "parked",
       "date": "2026-10-31"
      },
      {
       "title": "The mind map in 3D, one day",
       "branch": "(for fun)",
       "status": "parked",
       "date": "2026-10-31"
      }
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
    /// Older boards still carry the homage name. We swap it for Pip without ever writing it out:
    /// the repo is public, and the rule is that the real name never appears in our source.
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: String("ivaN".reversed()), with: "Pip")
    }

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

    /// The Glass Clock-style tile on the canvas (DashboardWidget.swift).
    func overlay(_ host: PipHost) -> some View { CanvasTile(host: host) }

    func card(_ host: PipHost) -> some View {
        // The Glass Clock-style widget and the answerable questions first (DashboardWidget.swift), then the rest.
        VStack(spacing: Corner.inset) {
            PanelsButton(host: host)
            Front(data: Dashboard.feed.data, host: host)
            Board(data: Dashboard.feed.data)
        }
        .onAppear { mind.greet(host) }
    }

    struct Board: View {
        let data: DashboardData

        var body: some View {
            VStack(spacing: Corner.inset) {
                SettingsCard(title: "Where we are", icon: "location", footer: Dashboard.freshness) {
                    DevFold(id: "dash.where", title: "status") {
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
                }
                if let due = data.reminders, !due.isEmpty {
                    SettingsCard(title: "Reminders", icon: "bell") {
                        DevFold(id: "dash.reminders", title: "reminders", summary: "\(due.count) set") {
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
}

/// The dashboard's data, in the web sandbox's data/dashboard.json shape. Every part is optional, and
/// parts the app doesn't show yet (usage) are skipped.
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

    struct Build: Codable, Sendable {
        var at: String?
        var title: String?
        var changes: [String]?
    }

    struct Idea: Codable, Sendable {
        var title: String?
        var branch: String?
        var status: String?
        var date: String?
    }

    var syncedAt: String?
    var source: String?
    var status: Status?
    var needsYou: [Ask]?
    var upNext: [Step]?
    var reminders: [Reminder]?
    var builds: [Build]?
    var principles: [String]?
    var ideas: [Idea]?
}
