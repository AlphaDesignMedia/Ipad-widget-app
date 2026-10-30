import SwiftUI

// TEA BREAK · plugin v1 (Dream). When Pip has worked hard (Busy Pip's rounds, long flights that tire
// them out, lots of flicks and bumps), they ask for a cuppa. Tap Pip, or "Put the kettle on", and they sip,
// sigh and perk up. Ignored, Pip makes their own, very slowly, and sulks a tiny bit.
// Where: the mug button in the plugin bar. At most 3 asks a session; rare at Joy 1; never with Joy 0.

struct TeaBreak: SandboxPlugin {
    let info = PluginInfo(id: "teabreak", name: "Tea Break", version: "v1", shelf: .dream,
                          icon: "mug", what: "Pip asks for a cuppa after working hard.")

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        static let tick = 30.0              // seconds between checks
        static let activeMinute = 1.0       // work per active minute with Pip awake
        static let flick = 0.5              // work per flick or hard bump
        static let tired = 6.0              // work when Weight says Pip is worn out
        static let round = 8.0              // work for each Busy Pip round
        static let maxAsks = 3              // per session, then Pip stops asking
        static let answerWindow = 25.0      // seconds to say yes before Pip makes their own
        static let hardBump = 1150.0
        /// Work needed before Pip asks, by Joy level (0 never asks).
        static func need(joy: Int) -> Double { [Double.infinity, 60, 45, 32, 22, 14][min(max(joy, 0), 5)] }
        /// Shortest gap between asks, in minutes, by Joy level.
        static func gap(joy: Int) -> Double { [Double.infinity, 25, 18, 12, 8, 5][min(max(joy, 0), 5)] }
    }

    // MARK: Data

    enum Lines {
        static func ask(checked: Int?) -> String {
            if let checked, checked > 1 { return "I've checked \(Lines.count(checked)) plugins. Is the kettle on?" }
            return ["All that flapping… is the kettle on?",
                    "Tea? Just a small one. Tap me.",
                    "My wings could do with a cuppa."].randomElement()!
        }
        static let sip = ["Ahh. Perfect.", "Just how I like it.", "Lovely. Right, back to it!"]
        static let own = "Fine. I'll make my own."
        static let ownDone = "…It's a bit weak. But it's mine."
        static func count(_ n: Int) -> String {
            let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                         "eleven", "twelve"]
            return n < words.count ? words[n] : "\(n)"
        }
    }

    /// What's happening this session. The plugin is a struct made once, so this lives in a class.
    @MainActor @Observable final class Session {
        var steaming = false
        var steamAt = CGPoint.zero
        @ObservationIgnored var work = 0.0
        @ObservationIgnored var asks = 0
        @ObservationIgnored var lastAsk = Date.distantPast
        @ObservationIgnored var waiting = false
        @ObservationIgnored var lastRound = ""
        @ObservationIgnored var loop: Task<Void, Never>?
    }
    private let session = Session()

    // MARK: Logic

    private func enabled(_ host: PipHost) -> Bool {
        let asks: Bool = host.value("teabreak", "asks") ?? true
        return host.isOn("teabreak") && asks && host.pipHere && !host.pipAsleep
    }

    func start(_ host: PipHost) throws { wake(host) }

    /// Runs the 30-second check only while Tea Break is on and "Pip asks for tea" is on; it ends itself when
    /// either goes off. Switching the plugin on calls `start`, and the card's switch calls this again.
    fileprivate func wake(_ host: PipHost) {
        guard session.loop == nil, running(host) else { return }
        session.loop = Task { @MainActor in
            while !Task.isCancelled, running(host) {
                try? await Task.sleep(for: .seconds(Tune.tick))
                tick(host)
            }
            session.loop = nil
        }
    }

    private func running(_ host: PipHost) -> Bool {
        host.isOn("teabreak") && ((host.value("teabreak", "asks") as Bool?) ?? true)
    }

    private func tick(_ host: PipHost) {
        guard enabled(host) else { return }
        session.work += Tune.activeMinute * Tune.tick / 60
        // A finished Busy Pip round counts as proper work.
        let round: String = host.value("busypip", "reportAt") ?? ""
        if !round.isEmpty, round != session.lastRound {
            if !session.lastRound.isEmpty { session.work += Tune.round }
            session.lastRound = round
        }
        maybeAsk(host)
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .custom("weight.tired"): session.work += Tune.tired
        case .flick: session.work += Tune.flick
        case .bump(let speed) where speed > Tune.hardBump: session.work += Tune.flick
        case .tap where session.waiting: serve(host)
        case .custom("feelings.wantsTea"): offerAfterSulk(host)
        default: break
        }
    }

    /// Pip's Feelings has just said "a cuppa would help" after a sulk: wait for a tap to serve it, as after
    /// an ask. Counts as one of the 3 asks; never at Joy 0; Pip makes their own if nobody taps.
    private func offerAfterSulk(_ host: PipHost) {
        guard enabled(host), host.joy > 0, !session.waiting, session.asks < Tune.maxAsks else { return }
        PipTalkTurns.takeFloor(host, for: Tune.answerWindow + 1)
        session.asks += 1
        session.lastAsk = .now
        session.waiting = true
        host.later(Tune.answerWindow) {
            guard session.waiting else { return }
            session.waiting = false
            makeOwn(host)
        }
    }

    private func maybeAsk(_ host: PipHost) {
        let joy = host.joy
        guard !session.waiting, session.asks < Tune.maxAsks,
              session.work >= Tune.need(joy: joy),
              Date.now.timeIntervalSince(session.lastAsk) >= Tune.gap(joy: joy) * 60,
              PipTalkTurns.floorFree(host) else { return }
        let report: String = host.value("busypip", "report") ?? ""
        let checked = report.isEmpty ? nil : report.split(separator: "\n").count
        guard host.say(Lines.ask(checked: checked), for: 4) else { return }
        PipTalkTurns.takeFloor(host, for: Tune.answerWindow + 1)   // held until Pip makes their own
        host.react(.curious, for: 1.6)
        session.asks += 1
        session.lastAsk = .now
        session.waiting = true
        host.later(Tune.answerWindow) {
            guard session.waiting else { return }
            session.waiting = false
            makeOwn(host)
        }
    }

    /// Put the kettle on: Pip sips, sighs and perks up. A wisp of steam rises (fades only under simpler motion).
    func serve(_ host: PipHost) {
        session.waiting = false
        session.work = 0
        TeaBreak.addCup()
        guard host.pipHere else { return }
        PipTalkTurns.takeFloor(host, for: 3.2)
        session.steamAt = host.pipPosition
        withAnimation(.easeOut(duration: 0.4)) { session.steaming = true }
        host.say(Lines.sip.randomElement()!, for: 2.4)
        host.later(1.2) { host.cheer() }
        host.later(3.2) { withAnimation(.easeInOut(duration: 0.8)) { session.steaming = false } }
    }

    /// Ignored: Pip makes their own, very slowly, and sulks a tiny bit. No guilt, and it still counts as a rest.
    private func makeOwn(_ host: PipHost) {
        session.work = 0
        guard host.say(Lines.own, for: 2.2) else { return }
        PipTalkTurns.takeFloor(host, for: 12)                        // the slow cup, until "ownDone" is said
        host.react(.sleepy, for: 2)
        host.later(9) {
            guard host.pipHere else { return }
            session.steamAt = host.pipPosition
            withAnimation(.easeOut(duration: 0.6)) { session.steaming = true }
            host.say(Lines.ownDone, for: 2.6)
            host.later(3.4) { withAnimation(.easeInOut(duration: 0.8)) { session.steaming = false } }
        }
    }

    static func addCup() {
        let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        let store = UserDefaults.standard
        if store.double(forKey: "plug.teabreak.day") != day {
            store.set(day, forKey: "plug.teabreak.day")
            store.set(0, forKey: "plug.teabreak.cups")
        }
        store.set(store.integer(forKey: "plug.teabreak.cups") + 1, forKey: "plug.teabreak.cups")
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Steam(session: session, host: host) }

    /// The wonder: three soft wisps rising just above Pip, then gone.
    struct Steam: View {
        let session: Session
        let host: PipHost
        @State private var rise = false

        var body: some View {
            ZStack(alignment: .topLeading) {
                if session.steaming, host.pipHere {
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(PipLook.glow.opacity(0.5))
                                .frame(width: 3, height: 12)
                                .rotationEffect(.degrees(i == 1 ? 0 : (i == 0 ? -12 : 12)))
                                .offset(y: rise && !host.simpler ? -14 - Double(i % 2) * 6 : 0)
                                .opacity(rise ? 0 : 0.8)
                                .animation(.easeOut(duration: 2.4).delay(Double(i) * 0.25), value: rise)
                        }
                    }
                    .position(x: session.steamAt.x, y: session.steamAt.y - 34)
                    .transition(.opacity)
                    .onAppear { rise = false; DispatchQueue.main.async { rise = true } }
                    .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    func card(_ host: PipHost) -> some View { TeaCard(plugin: self, host: host) }

    struct TeaCard: View {
        let plugin: TeaBreak
        let host: PipHost
        @AppStorage("plug.teabreak.asks") private var asks = true
        @AppStorage("plug.teabreak.cups") private var cups = 0
        @AppStorage("plug.teabreak.day") private var day = 0.0

        var body: some View {
            let today = day == Calendar.current.startOfDay(for: .now).timeIntervalSince1970 ? cups : 0
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Toggle("Pip asks for tea", isOn: $asks)
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let Pip ask for tea after working hard")
                    .onChange(of: asks) { if asks { plugin.wake(host) } }
                Button("Put the kettle on") { plugin.serve(host) }
                    .buttonStyle(PluginCardButton())
                    .disabled(!host.pipHere)
                    .accessibilityLabel("Put the kettle on for Pip")
                Text(today == 0 ? "No cups yet today." : "Cups today: \(today)")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
                Text("Pip asks 3 times at most, and only after real work. Tap Pip to say yes. Joy 0 means no asking.")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
            }
        }
    }
}
