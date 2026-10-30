import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import QuartzCore

// BUSY PIP · plugin v1 (Dream). When you've been idle a while, Pip gets out a clipboard, tucks a pencil behind
// their ear and does rounds of the plugins. In Developer mode the rounds are real: which plugins are on, which you
// actually open, how smoothly the screen ran, and up to three proper questions a session. Otherwise it's pretend:
// confident nonsense and a clipboard of doodles. Opt-in (off by default), stops the moment you touch the screen,
// does nothing with Pip off, and only shows a clipboard line under simpler motion.
// Where: the clipboard button in the plugin bar. Real rounds file a report in the Dashboard ("Pip's rounds").

struct BusyPip: SandboxPlugin {
    let info = PluginInfo(id: "busypip", name: "Busy Pip", version: "v1", shelf: .dream,
                          icon: "list.clipboard", what: "When you're idle, Pip does rounds with a clipboard. Real checks in Developer mode, pretend ones otherwise.")

    // MARK: Data

    enum Tune {
        static let idle: Double = 45            // seconds without a touch before a round starts
        static let realGap: Double = 300        // a real round at most every 5 minutes
        static let pretendGap: Double = 600     // pretend rounds are rarer
        static let edge: CGFloat = 140          // stops stay this far inside the screen
        static let questionsPerSession = 3
        static let questionWait: Double = 20    // an unanswered question counts as "ask later"
        static let unusedDays: Double = 7
        static let watchedDays: Double = 2      // don't ask about a plugin until we've watched this long
        static let keepDays: Double = 30        // "Keep" means don't ask again for a month
        static let reportLines = 10
    }

    enum Lines {
        static let start = ["Right. Rounds.", "Clipboard out. Let's have a look.", "Quick check while you're away."]
        static let done = ["All done. The report's in the Dashboard.", "Rounds finished. Nothing on fire."]
        static let switchedOff = "Switched off. It's in Settings if you want it back."
        static let kept = "Keeping it. I won't ask again for a while."
        static let later = "Fair enough. I'll ask another time."
        static let pretend = [
            "Re-fluffing the tick buffers…", "Carrying the seven… done-ish.", "Polishing the seconds. They were sticky.",
            "Counting the glass. Still one.", "Defragging the sparkles. Very official.",
            "Recalibrating the wobble to 4.2 wobbles.", "Signing off the minutes. In triplicate.",
            "Checking the clock is still clocking. It is.",
        ]
        static let pretendNumbers = ["Efficiency: 112%.", "Sparkle pressure: nominal.", "Tick density: excellent.",
                                     "Wobble index 0.7. Fine. Probably."]
        static let pretendQuestions = ["Should the sprockets be pointier? …I'll decide.", "Is purple a speed? Don't answer.",
                                       "Do the minutes like me? Never mind."]
        static let pretendDone = ["All in order. Probably.", "Report filed. It's mostly doodles."]
    }

    struct Question: Equatable {
        let plugin: String
        let text: String
    }

    // MARK: Logic

    /// Session state. The plugin is a struct made once, so this lives in a class.
    @MainActor @Observable final class Rounds {
        var busy = false
        var checking = ""                   // the plugin name on the clipboard ("" shows doodles)
        var question: Question?
        @ObservationIgnored var lastTouch = Date.now
        @ObservationIgnored var lastRound = Date.distantPast
        @ObservationIgnored var lastOpen: String?
        @ObservationIgnored var asked = 0
        @ObservationIgnored var askLater: Set<String> = []
        @ObservationIgnored var watcher: BusyTouchWatch?
        @ObservationIgnored var loop: Task<Void, Never>?
        @ObservationIgnored var round: Task<Void, Never>?
    }
    private let state = Rounds()

    static var developer: Bool { UserDefaults.standard.bool(forKey: "developerMode") }
    private func enabled(_ host: PipHost) -> Bool { (host.value("busypip", "on") as Bool?) ?? false }

    func start(_ host: PipHost) throws {
        if (host.value("busypip", "since") as Double?) == nil {
            host.setValue(Date.now.timeIntervalSince1970, "busypip", "since")
        }
        guard state.loop == nil else { return }
        state.loop = Task { @MainActor in
            while !Task.isCancelled {
                tick(host)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func tick(_ host: PipHost) {
        trackOpens(host)
        guard host.isOn("busypip") else {
            if state.busy { stop() }
            return
        }
        installWatch(host)
        guard enabled(host) else { return }
        guard !state.busy, host.pipHere, !host.pipAsleep else { return }
        let real = Self.developer
        guard Date.now.timeIntervalSince(state.lastTouch) >= Tune.idle,
              Date.now.timeIntervalSince(state.lastRound) >= (real ? Tune.realGap : Tune.pretendGap) else { return }
        begin(host, real: real)
    }

    /// Notes when each plugin's card or panel is opened, so real rounds know what you actually use.
    private func trackOpens(_ host: PipHost) {
        guard host.openCard != state.lastOpen else { return }
        state.lastOpen = host.openCard
        guard let id = host.openCard else { return }
        var opens = (host.value("busypip", "opens") as [String: Double]?) ?? [:]
        opens[id] = Date.now.timeIntervalSince1970
        host.setValue(opens, "busypip", "opens")
    }

    fileprivate func begin(_ host: PipHost, real: Bool) {
        guard !state.busy, host.pipHere else { return }
        state.busy = true
        state.lastRound = .now
        state.round = Task { @MainActor in
            if real { await realRound(host) } else { await pretendRound(host) }
            withAnimation(.easeInOut(duration: 0.5)) {
                state.busy = false
                state.checking = ""
            }
        }
    }

    private func stop() {
        state.round?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            state.busy = false
            state.checking = ""
            state.question = nil
        }
    }

    private func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }

    private func realRound(_ host: PipHost) async {
        let probe = Task { @MainActor in await Smoothness().measure(for: 4) }
        host.react(.curious, for: 1.5)
        host.say(Lines.start.randomElement()!, for: 2)
        var report: [String] = []
        let stops = roundStops(host)
        for (i, p) in picks(host).enumerated() {
            await pause(2)
            guard !Task.isCancelled else { probe.cancel(); return }
            if !host.simpler, !stops.isEmpty { host.move(to: stops[i % stops.count]) }
            withAnimation(.easeInOut(duration: 0.3)) { state.checking = p.info.name }
            await pause(1.6)
            let line = describe(p, host)
            report.append(line)
            host.say(line, for: 3)
        }
        let s = await probe.value
        guard !Task.isCancelled else { return }
        let screen = "Screen: \(s.fps) frames a second, \(s.late) late, while I was flying about."
        report.append(screen)
        await pause(2.6)
        host.say(screen, for: 3.2)
        await pause(3.4)
        guard !Task.isCancelled else { return }
        if let q = nextQuestion(host) {
            state.asked += 1
            withAnimation(.easeInOut(duration: 0.3)) { state.question = q }
            host.say(q.text, for: 4)
            let asked = Date.now
            while state.question == q, Date.now.timeIntervalSince(asked) < Tune.questionWait, !Task.isCancelled {
                await pause(0.5)
            }
            if state.question == q { answer(.later, host) }
        }
        guard !Task.isCancelled else { return }
        host.say(Lines.done.randomElement()!, for: 2.4)
        save(report, host)
    }

    private func pretendRound(_ host: PipHost) async {
        host.react(.curious, for: 1.5)
        let count = host.simpler ? 1 : 3
        let stops = roundStops(host)
        var lines = Lines.pretend.shuffled()
        for i in 0..<count {
            await pause(2)
            guard !Task.isCancelled else { return }
            if !host.simpler, !stops.isEmpty { host.move(to: stops[i % stops.count]) }
            await pause(1.4)
            host.say(lines.removeFirst(), for: 2.6)
            if i == 1 {
                await pause(3)
                host.say(Lines.pretendNumbers.randomElement()!, for: 2.2)
            }
        }
        if !host.simpler, Int.random(in: 0..<3) == 0 {
            await pause(3)
            host.say(Lines.pretendQuestions.randomElement()!, for: 3)
        }
        await pause(3.2)
        guard !Task.isCancelled else { return }
        host.say(Lines.pretendDone.randomElement()!, for: 2.2)
    }

    /// Up to three plugins to look at: ones you haven't opened in a while first, then a random few.
    private func picks(_ host: PipHost) -> [any SandboxPlugin] {
        let on = host.plugins.filter { host.isOn($0.info.id) && $0.info.id != "busypip" }
        let stale = on.filter { $0.hasCard && daysSinceOpened($0.info.id, host) ?? .infinity >= Tune.unusedDays }
        let rest = on.filter { p in !stale.contains { $0.info.id == p.info.id } }.shuffled()
        return Array((stale.shuffled() + rest).prefix(3))
    }

    private func daysSinceOpened(_ id: String, _ host: PipHost) -> Double? {
        guard let t = ((host.value("busypip", "opens") as [String: Double]?) ?? [:])[id] else { return nil }
        return (Date.now.timeIntervalSince1970 - t) / 86_400
    }

    private func watchedDays(_ host: PipHost) -> Double {
        let since = (host.value("busypip", "since") as Double?) ?? Date.now.timeIntervalSince1970
        return (Date.now.timeIntervalSince1970 - since) / 86_400
    }

    /// One plain, exact line about a plugin.
    private func describe(_ p: any SandboxPlugin, _ host: PipHost) -> String {
        let name = p.info.name
        guard p.hasCard else {
            return p.addsTo != nil ? "\(name): on, lives inside another panel." : "\(name): on, works in the background."
        }
        guard let days = daysSinceOpened(p.info.id, host) else {
            let watched = Int(watchedDays(host).rounded())
            return watched < 1 ? "\(name): on, not opened since I started watching today."
                               : "\(name): on, not opened in the \(watched) day\(watched == 1 ? "" : "s") I've been watching."
        }
        if days < 1 / 24 { return "\(name): on, opened in the last hour." }
        if days < 1 { return "\(name): on, opened \(Int(days * 24)) hour\(Int(days * 24) == 1 ? "" : "s") ago." }
        return "\(name): on, last opened \(Int(days)) day\(Int(days) == 1 ? "" : "s") ago."
    }

    /// A plugin you seem not to use, if there is one worth asking about.
    private func nextQuestion(_ host: PipHost) -> Question? {
        guard state.asked < Tune.questionsPerSession else { return nil }
        let kept = (host.value("busypip", "kept") as [String: Double]?) ?? [:]
        let now = Date.now.timeIntervalSince1970
        let candidate = host.plugins.first { p in
            let id = p.info.id
            guard id != "busypip", host.isOn(id), p.hasCard, !state.askLater.contains(id) else { return false }
            if let k = kept[id], (now - k) / 86_400 < Tune.keepDays { return false }
            if let d = daysSinceOpened(id, host) { return d >= Tune.unusedDays }
            return watchedDays(host) >= Tune.watchedDays
        }
        guard let p = candidate else { return nil }
        let when = daysSinceOpened(p.info.id, host).map { "in \(Int($0)) days" } ?? "since I started watching"
        return Question(plugin: p.info.id, text: "You haven't opened \(p.info.name) \(when). Keep it on?")
    }

    enum Answer { case keep, off, later }

    fileprivate func answer(_ a: Answer, _ host: PipHost) {
        guard let q = state.question else { return }
        withAnimation(.easeInOut(duration: 0.3)) { state.question = nil }
        let name = host.plugins.first { $0.info.id == q.plugin }?.info.name ?? q.plugin
        switch a {
        case .keep:
            var kept = (host.value("busypip", "kept") as [String: Double]?) ?? [:]
            kept[q.plugin] = Date.now.timeIntervalSince1970
            host.setValue(kept, "busypip", "kept")
            host.say(Lines.kept, for: 2)
            appendReport("You said keep \(name).", host)
        case .off:
            host.setOn(q.plugin, false)
            host.say(Lines.switchedOff, for: 2.4)
            appendReport("You switched off \(name).", host)
        case .later:
            state.askLater.insert(q.plugin)
            host.say(Lines.later, for: 2)
        }
    }

    private func save(_ lines: [String], _ host: PipHost) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM, HH:mm"
        host.setValue(f.string(from: .now), "busypip", "reportAt")
        host.setValue(Array(lines.prefix(Tune.reportLines)).joined(separator: "\n"), "busypip", "report")
    }

    private func appendReport(_ line: String, _ host: PipHost) {
        let old = (host.value("busypip", "report") as String?) ?? ""
        host.setValue(old.isEmpty ? line : old + "\n" + line, "busypip", "report")
    }

    /// Where Pip goes on a round: beside the open panel (never on it), above the plugin bar, and a spot or two
    /// in the open, all well inside the screen and in Pip's space.
    private func roundStops(_ host: PipHost) -> [CGPoint] {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return [] }
        let inset = window.safeAreaInsets
        let room = CGRect(x: 0, y: 0, width: window.bounds.width - inset.left - inset.right,
                          height: window.bounds.height - inset.top - inset.bottom)
        let safe = room.insetBy(dx: Tune.edge, dy: Tune.edge)
        guard safe.width > 0, safe.height > 0 else { return [] }
        func inside(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(max(p.x, safe.minX), safe.maxX), y: min(max(p.y, safe.minY), safe.maxY))
        }
        var out: [CGPoint] = []
        let panel = host.panelFrame
        if !panel.isNull {
            let p = panel.offsetBy(dx: -inset.left, dy: -inset.top)
            let x = p.midX > room.midX ? p.minX - 60 : p.maxX + 60
            out.append(inside(CGPoint(x: x, y: p.minY + 120)))
        }
        let bar = host.barFrame
        if !bar.isNull {
            let b = bar.offsetBy(dx: -inset.left, dy: -inset.top)
            out.append(inside(CGPoint(x: b.midX, y: b.minY - 80)))
        }
        out.append(inside(CGPoint(x: safe.minX + safe.width * 0.3, y: safe.minY + safe.height * 0.35)))
        out.append(inside(CGPoint(x: safe.minX + safe.width * 0.7, y: safe.minY + safe.height * 0.55)))
        return out
    }

    /// Watches every touch on the window without taking it. A touch stops a round (unless Pip's waiting on an answer).
    private func installWatch(_ host: PipHost) {
        guard state.watcher == nil else { return }
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        let watch = BusyTouchWatch()
        watch.onTouch = { [state] in
            state.lastTouch = .now
            if state.busy, state.question == nil { stop() }
        }
        window.addGestureRecognizer(watch)
        state.watcher = watch
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Clipboard(state: state, plugin: self, host: host) }

    /// The clipboard by Pip's side and the pencil behind their ear, plus a small question card when there is one.
    struct Clipboard: View {
        let state: Rounds
        let plugin: BusyPip
        let host: PipHost

        var body: some View {
            ZStack(alignment: .topLeading) {
                if state.busy, host.pipHere {
                    let p = host.pipPosition
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(-40))
                        .foregroundStyle(PipLook.orbDeep)
                        .position(x: p.x + 9, y: p.y - 15)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    HStack(spacing: 4) {
                        Image(systemName: "list.clipboard.fill")
                        if state.checking.isEmpty {
                            Image(systemName: "scribble.variable")
                        } else {
                            Text(state.checking).lineLimit(1)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PipLook.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: Capsule())
                    .fixedSize()
                    .position(x: p.x, y: p.y + 30)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(state.checking.isEmpty ? "Pip is doing pretend rounds" : "Pip is checking \(state.checking)")
                }
                if let q = state.question, host.pipHere {
                    question(q)
                        .position(x: host.pipPosition.x, y: host.pipPosition.y + 96)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        private func question(_ q: Question) -> some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text(q.text).font(.system(size: 13.5))
                HStack(spacing: 6) {
                    Button("Keep") { plugin.answer(.keep, host) }
                        .buttonStyle(PluginCardButton(on: true))
                        .accessibilityLabel("Keep it on")
                    Button("Switch off") { plugin.answer(.off, host) }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Switch it off")
                    Button("Ask later") { plugin.answer(.later, host) }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Ask me later")
                }
            }
            .padding(PluginBarLook.cardPadding)
            .frame(width: 280, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PluginBarLook.radius))
        }
    }

    func card(_ host: PipHost) -> some View { BusyCard(plugin: self, host: host) }

    struct BusyCard: View {
        let plugin: BusyPip
        let host: PipHost
        @AppStorage("plug.busypip.on") private var on = false
        @AppStorage("developerMode") private var developer = false

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Toggle("Pip does rounds when you're idle", isOn: $on)
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let Pip do rounds when you're idle")
                Text(developer
                     ? "Real rounds: Developer mode is on, so Pip checks your plugins properly and may ask up to 3 questions."
                     : "Pretend rounds: Pip looks very busy and talks nonsense. Turn on Developer mode for real checks.")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
                Button("Start a round now") {
                    host.later(2) { plugin.begin(host, real: developer) }
                }
                .buttonStyle(PluginCardButton())
                .disabled(!host.pipHere)
                .accessibilityLabel("Start a round in two seconds")
                Text("Starts in 2 seconds. Any touch stops it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    var addsTo: String? { "dashboard" }
    func addOn(_ host: PipHost) -> some View { Report() }

    /// "Pip's rounds" in the Dashboard: the last real round, line by line.
    struct Report: View {
        @AppStorage("plug.busypip.report") private var report = ""
        @AppStorage("plug.busypip.reportAt") private var at = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pip's rounds").bold()
                if report.isEmpty {
                    Text("No real rounds yet. Switch on Busy Pip and Developer mode, then leave the iPad alone for a minute.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Last round: \(at)").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(report.split(separator: "\n").enumerated()), id: \.offset) { _, line in
                        Text(String(line)).font(.system(size: 13.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Counts frames for a few seconds while Pip does a round, then stops: how smoothly the whole app is drawing.
/// (Per-plugin numbers need the core.)
@MainActor final class Smoothness: NSObject {
    private var link: CADisplayLink?
    private var began: CFTimeInterval = 0
    private var last: CFTimeInterval = 0
    private var frames = 0
    private var late = 0

    func measure(for seconds: Double) async -> (fps: Int, late: Int) {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        try? await Task.sleep(for: .seconds(seconds))
        link.invalidate()
        self.link = nil
        let span = max(last - began, 0.001)
        return (Int((Double(frames) / span).rounded()), late)
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        if began == 0 {
            began = now
        } else {
            let frame = max(l.targetTimestamp - l.timestamp, 1.0 / 120)
            if now - last > frame * 1.5 { late += 1 }
            frames += 1
        }
        last = now
    }
}

/// Hears every touch on the window and lets it through untouched. It never recognises, so it never gets in the way.
final class BusyTouchWatch: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTouch: (() -> Void)?

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { onTouch?() }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
