import SwiftUI

// CREW RUNDOWN · plugin v1.1 (On trial). Pip pops round the site, has a quick natter with the builders (Bob the
// foreman and Dot the apprentice) and gives Aaron a short, plain rundown: what's new, what's waiting on him,
// and what's waiting on the core. "What's new" fills itself from the crew's log book, CrewLog.swift (builders
// add one line per job), newest first, with "x new since you last looked" (kept on the device).
// No network. With Pip off: plain cards, no chat, just the list.
// Where: the speech-bubbles button in the plugin bar (opens as a panel).

struct CrewRundown: SandboxPlugin {
    let info = PluginInfo(id: "crew", name: "Crew rundown", version: "v1.1", shelf: .trial,
                          icon: "bubble.left.and.bubble.right",
                          what: "Pip pops round the site and tells you what the builders have done.",
                          panel: true)

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        static let maxOffers = 3            // Pip's spoken line, per session, then Pip stays quiet
        static let greetDelay = 0.4         // seconds after the panel opens before Pip speaks
        static let steamFor = 3.2           // seconds Bob's flask steams
        static let steamRise = 2.4          // seconds each wisp takes to rise and fade
        /// Seconds between chat lines, by Joy level (0 shows the chat all at once, no motion).
        static func gap(joy: Int) -> Double { [0, 1.1, 0.9, 0.7, 0.55, 0.4][min(max(joy, 0), 5)] }
        /// Wisps of steam from Bob's flask, by Joy level (0: none).
        static func wisps(joy: Int) -> Int { [0, 2, 3, 3, 4, 5][min(max(joy, 0), 5)] }
    }

    // MARK: Data

    /// The crew and the job statuses live in the log book (CrewLog.swift).
    typealias Who = CrewLog.Who
    typealias Status = CrewLog.Status
    typealias Entry = CrewLog.Entry

    struct Line: Sendable {
        let who: Who
        let text: String
    }

    /// Decisions only Aaron can make.
    static let forYou: [String] = [
        "Pip's little glass seat: yes or no to the look?",
        "Two builders or three?",
        "Re-sign the app on the iPad by Fri 6 Nov.",
    ]

    /// The shortlist of core asks from AGENT-NOTES.md.
    static let forCore: [String] = [
        "A shared \"Pip's busy talking\" flag, so asks wait their turn.",
        "Change and restore the backdrop, for Guest Takeover.",
        "A pose API for Weight: sit, dangle, flap harder.",
        "A new-build signal and change list, for First Look.",
        "A costume slot drawn on Pip, for Busy Pip's clipboard.",
    ]

    /// The site natter. Bob's line steams (his flask).
    static let chat: [Line] = [
        Line(who: .pip, text: "Just popping round the site. Want anything from the shop?"),
        Line(who: .bob, text: "A sausage roll and a strong tea, ta. Measure twice, push once."),
        Line(who: .dot, text: "Whatever you're having… and a sticker?"),
        Line(who: .pip, text: "Sticker it is. Right, here's the rundown."),
    ]
    static let flaskLine = 1

    static let pipLines = ["Popped round the site. Here's the rundown.",
                           "The crew says hello.",
                           "Same rundown. Nothing's fallen down."]

    static let footer = "Nothing here has been tested by hand on the iPad yet. Aaron has the final say."

    // MARK: Logic

    /// This session's chat and Pip's spoken lines. The plugin is a struct made once, so this lives in a class.
    @MainActor @Observable final class Session {
        var shown = 0
        var steaming = false
        /// The newest log date Aaron had seen before this session ("" means never). Read once, on first open.
        var since: String? = nil
        @ObservationIgnored var offers = 0
        @ObservationIgnored var played = false
        @ObservationIgnored var chat: Task<Void, Never>?
        @ObservationIgnored var steam: Task<Void, Never>?
    }
    private let session = Session()

    /// Panel opened: Pip says one line (3 times a session at most) and the chat plays once. With Pip off: neither.
    func opened(_ host: PipHost) {
        guard host.pipHere else { return }
        if session.offers < Tune.maxOffers {
            let line = CrewRundown.pipLines[min(session.offers, CrewRundown.pipLines.count - 1)]
            host.later(Tune.greetDelay) {
                if host.openCard == info.id, host.say(line, for: 2.2) { session.offers += 1 }
            }
        }
        if !session.played { play(host) }
    }

    /// Panel closed (or Pip gone): the chat and the steam stop. A chat cut short plays again next time.
    func closed() {
        session.chat?.cancel()
        session.steam?.cancel()
        session.chat = nil
        session.steam = nil
        session.steaming = false
        if session.shown < CrewRundown.chat.count { session.played = false }
    }

    /// Shows the chat one line at a time (all at once at Joy 0). Under simpler motion the lines only fade.
    /// Runs only while Pip is here and the panel is open.
    func play(_ host: PipHost) {
        closed()
        session.played = true
        session.shown = 0
        let gap = Tune.gap(joy: host.joy)
        guard gap > 0 else { session.shown = CrewRundown.chat.count; return }
        session.chat = Task { @MainActor in
            for i in CrewRundown.chat.indices {
                try? await Task.sleep(for: .seconds(gap))
                guard !Task.isCancelled else { return }
                guard host.pipHere else { closed(); return }
                withAnimation(.easeOut(duration: 0.35)) { session.shown = i + 1 }
                if i == CrewRundown.flaskLine { steam(host) }
            }
            session.chat = nil
        }
    }

    /// The wonder: a wisp of steam from Bob's flask.
    private func steam(_ host: PipHost) {
        guard Tune.wisps(joy: host.joy) > 0 else { return }
        session.steaming = true
        session.steam = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Tune.steamFor))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.8)) { session.steaming = false }
            session.steam = nil
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View {
        Board(plugin: self, session: session, host: host)
            .onAppear { opened(host) }
            .onDisappear { closed() }
    }

    struct Board: View {
        let plugin: CrewRundown
        let session: Session
        let host: PipHost
        /// The newest log date seen, saved on the device.
        @AppStorage("plug.crew.lastLooked") private var lastLooked = ""

        private var seen: String { session.since ?? lastLooked }

        private var newLine: String {
            let count = CrewLog.newCount(since: seen)
            if seen.isEmpty { return "All \(count) are new to you." }
            switch count {
            case 0: return "Nothing new since you last looked."
            default: return "\(count) new since you last looked."
            }
        }

        var body: some View {
            VStack(spacing: Corner.inset) {
                if host.pipHere {
                    SettingsCard(title: "On site", icon: "bubble.left.and.bubble.right") {
                        ForEach(0..<min(session.shown, CrewRundown.chat.count), id: \.self) { i in
                            ChatRow(line: CrewRundown.chat[i],
                                    steams: i == CrewRundown.flaskLine && session.steaming,
                                    wisps: Tune.wisps(joy: host.joy),
                                    simpler: host.simpler)
                                .transition(.opacity)
                        }
                        if session.shown >= CrewRundown.chat.count {
                            Button("Pop round again") { plugin.play(host) }
                                .buttonStyle(PluginCardButton())
                                .accessibilityLabel("Play Pip's chat with the crew again")
                        }
                    }
                }
                SettingsCard(title: "What's new", icon: "hammer", footer: CrewRundown.footer) {
                    // The summary stays visible while it's folded, so you can see if anything's new.
                    DevFold(id: "crew.new", title: "the list", summary: newLine) {
                        let news = CrewLog.newestFirst
                        ForEach(news.indices, id: \.self) { i in
                            EntryRow(entry: news[i], isNew: news[i].date > seen)
                        }
                    }
                }
                SettingsCard(title: "Waiting on you", icon: "person.crop.circle.badge.questionmark") {
                    DevFold(id: "crew.you", title: "the list", summary: "\(CrewRundown.forYou.count) things") {
                        ForEach(CrewRundown.forYou.indices, id: \.self) { i in
                            Text(CrewRundown.forYou[i])
                        }
                    }
                }
                SettingsCard(title: "Waiting on core", icon: "gearshape.2",
                             footer: "Asked for in the agent notes. The Mac agent builds these.") {
                    DevFold(id: "crew.core", title: "the list", summary: "\(CrewRundown.forCore.count) things") {
                        ForEach(CrewRundown.forCore.indices, id: \.self) { i in
                            Text(CrewRundown.forCore[i])
                        }
                    }
                }
                SettingsCard(title: "The crew", icon: "person.2") {
                    DevFold(id: "crew.crew", title: "the crew") {
                        ForEach([Who.bob, Who.dot, Who.rob], id: \.self) { who in
                            VStack(alignment: .leading, spacing: 2) {
                                Label(who.name, systemImage: who.symbol)
                                Text(who.role).font(.caption).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .onAppear(perform: looked)
        }

        /// Remember what was new before this look (once a session), then save that Aaron has now seen it all.
        private func looked() {
            if session.since == nil { session.since = lastLooked }
            lastLooked = CrewLog.newest
        }
    }

    struct EntryRow: View {
        let entry: Entry
        let isNew: Bool

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: PluginBarLook.cardGap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.what)
                    Text("\(entry.who.name) · \(entry.when) · \(entry.status.label)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isNew {
                    Text("New").font(.caption).foregroundStyle(PipLook.glow)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(isNew ? "New. " : "")\(entry.what) By \(entry.who.name), \(entry.when). \(entry.status.label).")
        }
    }

    struct ChatRow: View {
        let line: Line
        let steams: Bool
        let wisps: Int
        let simpler: Bool

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: PluginBarLook.cardGap) {
                Image(systemName: line.who.symbol)
                    .foregroundStyle(line.who == .pip ? PipLook.glow : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.who.name).font(.caption).foregroundStyle(.secondary)
                    Text(line.text)
                }
                Spacer(minLength: 0)
                if steams { Steam(count: wisps, simpler: simpler).transition(.opacity) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(line.who.name) says: \(line.text)")
        }
    }

    /// A few soft wisps rising from Bob's flask, then gone. Fade only under simpler motion.
    struct Steam: View {
        let count: Int
        let simpler: Bool
        @State private var rise = false

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(PipLook.glow.opacity(0.5))
                        .frame(width: 3, height: 10)
                        .rotationEffect(.degrees(i % 2 == 0 ? -10 : 10))
                        .offset(y: rise && !simpler ? -10 - Double(i % 2) * 5 : 0)
                        .opacity(rise ? 0 : 0.8)
                        .animation(.easeOut(duration: Tune.steamRise).delay(Double(i) * 0.25), value: rise)
                }
            }
            .onAppear { rise = false; DispatchQueue.main.async { rise = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
