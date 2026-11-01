import SwiftUI

// DASHBOARD · plugin v1 (On trial). Your Glass Clock Progress dashboard inside the Sandbox: where things are,
// what needs you and what's due. Read-only: nothing here changes the real dashboard. Other plugins add their
// sections to its panel (`addsTo: "dashboard"`), so the dashboard grows one small plugin at a time.
// Data: `dashboard.json` in this folder (packed into the app at build; a copy of the web sandbox's
// data/dashboard.json, refreshed on the Mac by app/tools/sync-dashboard.sh, which can also add the live board's
// headline as `live`). If the file is missing, the snapshot below. Then the live feed (Feed, below) downloads the
// newest board when the dashboard opens, read-only, with an off switch. Works the same with Pip off; Pip adds one line at most.
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

    /// The packed-in file if there is one, otherwise the snapshot. The starting point before the live feed answers.
    static let feed: (data: DashboardData, packed: Bool) = {
        if let url = Bundle.main.url(forResource: "dashboard", withExtension: "json"),
           let raw = try? Data(contentsOf: url),
           let data = try? JSONDecoder().decode(DashboardData.self, from: raw) {
            return (data, true)
        }
        let data = (try? JSONDecoder().decode(DashboardData.self, from: Data(snapshot.utf8))) ?? DashboardData()
        return (data, false)
    }()

    /// What the footer says: live, last live copy, packed-in file, or snapshot.
    @MainActor static var freshness: String { Feed.shared.freshness }

    /// THE LIVE FEED (Aaron, 1 Nov: "it needs to plug into the live one, not just static").
    /// Read-only: it downloads two small files and never sends anything. Off switch in the card.
    ///   board.json   the whole board, from a secret gist whose address lives only on the Mac
    ///                (Private/board-feed.txt, ignored by git; Rob, 1 Nov). No file = no board.json, headline only.
    ///   status.json  the headline that already feeds the iPad widget
    /// Last good copy is kept, so offline still shows the newest board seen. Checks at most once a minute,
    /// and only when the dashboard is open.
    @MainActor @Observable final class Feed {
        static let shared = Feed()
        nonisolated static let base = "https://gist.githubusercontent.com/AlphaDesignMedia/1f2abb87c59f63844a9f7523f37da9f4/raw/"
        /// The private board's address, packed in from the Mac only. Never written into the repo, notes or logs.
        nonisolated static let boardBase: String? = Bundle.main.url(forResource: "board-feed", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        private static let cacheKey = "plug.dashboard.liveBoard"
        private static let switchKey = "plug.dashboard.liveOn"

        enum State: Equatable { case starting, checking, live(Date), offline }

        private(set) var data: DashboardData
        private(set) var state: State = .starting
        private var lastTry: Date?
        /// When the last good download landed. Kept across launches, so the footer can say how old the copy is.
        private(set) var lastGood: Date? = UserDefaults.standard.object(forKey: "plug.dashboard.lastGood") as? Date

        var on: Bool {
            get { access(keyPath: \.on); return UserDefaults.standard.object(forKey: Self.switchKey) as? Bool ?? true }
            set { withMutation(keyPath: \.on) { UserDefaults.standard.set(newValue, forKey: Self.switchKey) }
                  if newValue { refresh(force: true) } else { state = .starting } }
        }

        init() {
            if let raw = UserDefaults.standard.data(forKey: Self.cacheKey),
               let cached = try? JSONDecoder().decode(DashboardData.self, from: raw),
               (cached.syncedAt ?? "") >= (Dashboard.feed.data.syncedAt ?? "") {
                data = cached
            } else {
                data = Dashboard.feed.data
            }
        }

        /// e.g. "Couldn't reach the live board · last checked 3:23 am · board from Sun 1 Nov, 4:20 am".
        var freshness: String {
            let when = Dashboard.date(data.syncedAt) ?? "an unknown date"
            guard on else { return Dashboard.feed.packed ? "Updated \(when) · live feed off" : "Snapshot, \(when) · live feed off" }
            let checked = lastGood.map { "last checked \(Self.clock($0))" } ?? "never checked"
            switch state {
            case .live(let at): return "Live · checked \(Self.clock(at)) · board from \(when)"
            case .checking: return "Checking the live board… · \(checked) · board from \(when)"
            case .offline: return "Couldn't reach the live board · \(checked) · board from \(when)"
            case .starting: return "\(checked.prefix(1).uppercased() + checked.dropFirst()) · board from \(when)"
            }
        }

        /// "3:23 am" today, otherwise "Sat 31 Oct, 3:23 am".
        static func clock(_ d: Date) -> String {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_GB")
            f.dateFormat = Calendar.current.isDateInToday(d) ? "h:mm a" : "EEE d MMM, h:mm a"
            return f.string(from: d)
        }

        func refresh(force: Bool = false) {
            guard on else { state = .starting; return }
            if !force, let lastTry, Date().timeIntervalSince(lastTry) < 60 { return }
            lastTry = Date()
            state = .checking
            Task {
                async let board = Self.fetch(Self.boardBase, "board.json")
                async let head = Self.fetch(Self.base, "status.json")
                let (b, h) = await (board, head)
                var next = data
                if let b, let full = try? JSONDecoder().decode(DashboardData.self, from: b) {
                    next = full
                    UserDefaults.standard.set(b, forKey: Self.cacheKey)
                }
                if let h, let live = try? JSONDecoder().decode(DashboardData.Live.self, from: h) { next.live = live }
                if b != nil || h != nil {
                    data = next
                    Dashboard.publish(PipHost.shared)      // the Home Screen widget's copy (DashboardHomeScreen.swift)
                    let now = Date()
                    lastGood = now
                    UserDefaults.standard.set(now, forKey: "plug.dashboard.lastGood")
                    state = .live(now)
                } else {
                    state = .offline
                }
            }
        }

        nonisolated private static func fetch(_ base: String?, _ name: String) async -> Data? {
            guard let base, base.hasPrefix("https://"), let url = URL(string: base + name + "?t=\(Int(Date().timeIntervalSince1970))") else { return nil }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
            req.httpMethod = "GET"
            guard let (body, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return body
        }
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

    /// Fills the Home Screen widget's copy at launch, so it's ready before the dashboard is first opened.
    func start(_ host: PipHost) throws { Dashboard.publish(host) }

    // MARK: Views

    /// The dashboard as its own tab in the top switch: Classic · Panels · Dashboard (Aaron, 1 Nov).
    var screenName: String? { "Dashboard" }
    func screen(_ host: PipHost) -> some View { PanelsScreen(host: host).safeAreaPadding(.bottom, 90) }

    /// The Glass Clock-style tile on the canvas (DashboardWidget.swift).
    func overlay(_ host: PipHost) -> some View {
        ZStack {
            CanvasTile(host: host)
            ShotPill(host: host)      // the Shot list's "Snap · Back" bar while you're off taking a shot
        }
    }

    func card(_ host: PipHost) -> some View {
        // A glance and the way in. Everything else lives in the dashboard itself (DashboardPanels.swift).
        VStack(spacing: Corner.inset) {
            PanelsButton(host: host)
            LiveBody(host: host)
        }
        .onAppear { mind.greet(host); Feed.shared.refresh() }
    }

    /// The side card: just a glance and the way in (Aaron, 1 Nov: one dashboard, no doubling).
    struct LiveBody: View {
        let host: PipHost
        @Bindable private var feed = Feed.shared
        @AppStorage("plug.dashboard.tileShown") private var onCanvas = true

        var body: some View {
            let data = feed.data
            let waiting = (data.needsYou ?? []).filter { Dashboard.answer($0.q, host) == nil }.count
            GlassTile(data: data, waiting: waiting).frame(maxWidth: .infinity)
            SettingsCard(footer: Dashboard.freshness) {
                Toggle("On the canvas", isOn: $onCanvas)
                    .accessibilityHint("Shows this tile on the canvas, where you can drag it anywhere.")
            }
        }
    }
}

/// One of the live board's four numbers.
struct LiveNumber: View {
    let value: Int?
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value.map(String.init) ?? "–").font(.title2.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
    var live: Live?
    /// Commands for Rob from the master chat (Rob, 1 Nov), newest first. Shown read-only in the dashboard.
    var outboxForRob: [RobJob]?
    /// Places to screenshot for the developers (Aaron, 1 Nov). Shown in the Shot list (DashboardShots.swift).
    var shots: [Shot]?

    /// One place to screenshot. `go` is where the app jumps: "tab:<id>" (a top tab), "card:<plugin id>" (a plugin's
    /// card), "home" (the app with everything closed) or "homescreen" (outside the app: an iPad screenshot).
    /// `from` is who asked (Rob, Jules, Chappie, Master chat), so the snap goes back to them.
    struct Shot: Codable, Sendable, Hashable {
        var what: String
        var go: String?
        var from: String?
        var date: String?
    }

    struct RobJob: Codable, Sendable {
        var date: String?
        var done: Bool?
        var command: String
    }

    /// The live board's headline: the small file that feeds the iPad widget, fetched on the Mac by
    /// sync-dashboard.sh at build time (never by the app).
    struct Live: Codable, Sendable {
        var needYou: Int?
        var toTry: Int?
        var upNext: Int?
        var done: Int?
        var latestUpdate: String?
        var ipadBuild: String?
        var updatedAt: String?
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Reads each part on its own, so one part in an unexpected shape is skipped instead of losing the whole board.
extension DashboardData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        syncedAt = try? c.decodeIfPresent(String.self, forKey: .syncedAt)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        status = try? c.decodeIfPresent(Status.self, forKey: .status)
        needsYou = try? c.decodeIfPresent([Ask].self, forKey: .needsYou)
        upNext = try? c.decodeIfPresent([Step].self, forKey: .upNext)
        reminders = try? c.decodeIfPresent([Reminder].self, forKey: .reminders)
        builds = try? c.decodeIfPresent([Build].self, forKey: .builds)
        principles = try? c.decodeIfPresent([String].self, forKey: .principles)
        ideas = try? c.decodeIfPresent([Idea].self, forKey: .ideas)
        live = try? c.decodeIfPresent(Live.self, forKey: .live)
        outboxForRob = try? c.decodeIfPresent([RobJob].self, forKey: .outboxForRob)
        shots = try? c.decodeIfPresent([Shot].self, forKey: .shots)
    }
}
