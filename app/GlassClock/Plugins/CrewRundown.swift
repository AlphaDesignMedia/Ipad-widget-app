import SwiftUI

// CREW RUNDOWN · plugin v1 (On trial). Pip pops round the site, has a quick natter with the builders (Bob the
// foreman and Dot the apprentice) and gives Aaron a short, plain rundown: what's new, what's waiting on him,
// and what's waiting on the core. Data is a small list written into this file (from the pip-plugins history
// and AGENT-NOTES.md, 30 Oct 2026). No network. With Pip off: plain cards, no chat, just the list.
// Where: the speech-bubbles button in the plugin bar (opens as a panel).

struct CrewRundown: SandboxPlugin {
    let info = PluginInfo(id: "crew", name: "Crew rundown", version: "v1", shelf: .trial,
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

    enum Who: String, Sendable {
        case pip, bob, dot
        var name: String { ["pip": "Pip", "bob": "Bob", "dot": "Dot"][rawValue] ?? "Pip" }
        var symbol: String {
            switch self {
            case .pip: return "sparkle"
            case .bob: return "wrench.and.screwdriver"
            case .dot: return "paintbrush.pointed"
            }
        }
        var role: String {
            switch self {
            case .pip: return "Your guide"
            case .bob: return "Foreman. Steady. Flask of tea, a vape on breaks."
            case .dot: return "Apprentice. Keen, and wishes they were better."
            }
        }
    }

    enum Status: String, Sendable {
        case green, untested, core, doing
        var label: String {
            switch self {
            case .green: return "Built, CI green"
            case .untested: return "Not hand-tested"
            case .core: return "Waiting on core"
            case .doing: return "In progress"
            }
        }
    }

    struct Entry: Sendable {
        let when: String
        let who: Who
        let what: String
        let status: Status
    }

    struct Line: Sendable {
        let who: Who
        let text: String
    }

    /// What the crew has done, newest first. From the pip-plugins history and AGENT-NOTES.md, 30 Oct 2026.
    static let news: [Entry] = [
        Entry(when: "Fri 30 Oct", who: .dot, what: "Crew rundown: this panel.", status: .untested),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Three snag fixes for Busy Pip and Tidy Pip.", status: .doing),
        Entry(when: "Fri 30 Oct", who: .dot, what: "Guest Takeover: Tack and Fuse pop in, then leave.", status: .core),
        Entry(when: "Fri 30 Oct", who: .dot, what: "Tea Break: Pip asks for a cuppa after real work.", status: .green),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Tidy Pip: offers to tidy away open panels.", status: .green),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Dashboard queue: 13 ideas to move over.", status: .green),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Busy Pip: rounds with a clipboard while you're idle.", status: .green),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Idea inbox: jot ideas down on the iPad.", status: .green),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Next action: your next step, big and clear.", status: .green),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Dashboard: your progress board in a panel.", status: .green),
        Entry(when: "Fri 30 Oct", who: .bob, what: "Pip's Weight v1.1: floats, tires, rests on a seat.", status: .green),
    ]

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
        @ObservationIgnored var offers = 0
        @ObservationIgnored var played = false
        @ObservationIgnored var run = 0
    }
    private let session = Session()

    /// Panel opened: Pip says one line (3 times a session at most) and the chat plays once.
    func opened(_ host: PipHost) {
        if session.offers < Tune.maxOffers {
            let line = CrewRundown.pipLines[min(session.offers, CrewRundown.pipLines.count - 1)]
            host.later(Tune.greetDelay) {
                if host.say(line, for: 2.2) { session.offers += 1 }
            }
        }
        if !session.played { play(host) }
    }

    /// Shows the chat one line at a time (all at once at Joy 0). Under simpler motion the lines only fade.
    func play(_ host: PipHost) {
        session.played = true
        session.run += 1
        let run = session.run
        let gap = Tune.gap(joy: host.joy)
        session.shown = 0
        session.steaming = false
        guard gap > 0 else { session.shown = CrewRundown.chat.count; return }
        for i in CrewRundown.chat.indices {
            host.later(gap * Double(i + 1)) {
                guard session.run == run else { return }
                withAnimation(.easeOut(duration: 0.35)) { session.shown = i + 1 }
                if i == CrewRundown.flaskLine { steam(host, run: run) }
            }
        }
    }

    /// The wonder: a wisp of steam from Bob's flask.
    private func steam(_ host: PipHost, run: Int) {
        guard Tune.wisps(joy: host.joy) > 0 else { return }
        session.steaming = true
        host.later(Tune.steamFor) {
            guard session.run == run else { return }
            withAnimation(.easeInOut(duration: 0.8)) { session.steaming = false }
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View {
        Board(plugin: self, session: session, host: host)
            .onAppear { opened(host) }
    }

    struct Board: View {
        let plugin: CrewRundown
        let session: Session
        let host: PipHost

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
                    ForEach(CrewRundown.news.indices, id: \.self) { i in
                        EntryRow(entry: CrewRundown.news[i])
                    }
                }
                SettingsCard(title: "Waiting on you", icon: "person.crop.circle.badge.questionmark") {
                    ForEach(CrewRundown.forYou.indices, id: \.self) { i in
                        Text(CrewRundown.forYou[i])
                    }
                }
                SettingsCard(title: "Waiting on core", icon: "gearshape.2",
                             footer: "Asked for in the agent notes. The Mac agent builds these.") {
                    ForEach(CrewRundown.forCore.indices, id: \.self) { i in
                        Text(CrewRundown.forCore[i])
                    }
                }
                SettingsCard(title: "The crew", icon: "person.2") {
                    ForEach([Who.bob, Who.dot], id: \.self) { who in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(who.name, systemImage: who.symbol)
                            Text(who.role).font(.caption).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    struct EntryRow: View {
        let entry: Entry

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.what)
                Text("\(entry.who.name) · \(entry.when) · \(entry.status.label)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(entry.what) By \(entry.who.name), \(entry.when). \(entry.status.label).")
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
