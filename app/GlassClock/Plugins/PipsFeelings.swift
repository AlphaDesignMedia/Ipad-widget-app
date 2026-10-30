import SwiftUI

// PIP'S FEELINGS · plugin v1 (Dream). Pip has feelings about how they're handled (Aaron, 30 Oct 2026):
// - Flick them a few times in a row and they get dizzy: a wobble, little stars round their head, "room's spinning".
// - Throw them hard twice and that's rude: Pip goes quiet, looks away, dims a touch and sulks for a bit
//   (about 35 to 50 seconds at calm). Taps are ignored while they sulk, except a gentle pat. Then a cuppa would help
//   (Tea Break picks that up if it's on).
// - Two slow, gentle taps are a pat on the head: Pip glows warmer for a moment. A stand-in until the core has a
//   proper rub/stroke gesture.
// Pip slowly forgives (a few minutes), never guilts, keeps no streaks. Joy 0: words only, nothing moves.
// Simpler motion: fades only. Pip off: nothing at all. Pip talks only when it's their turn (PipTalkTurns),
// and at most 3 lines a minute from here.
// Where: the heart button in the plugin bar (a small card with how Pip's feeling and "Say sorry").

struct PipsFeelings: SandboxPlugin {
    let info = PluginInfo(id: "feelings", name: "Pip's Feelings", version: "v1", shelf: .dream,
                          icon: "heart", what: "Pip gets dizzy, sulks if thrown about, and likes a gentle pat.")

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        // Dizzy
        static let dizzyFlicks = 3                // flicks in the window that make Pip dizzy
        static let dizzyWindow = 4.0              // seconds
        static let dizzyRest = 8.0                // seconds before Pip can get dizzy again
        static func dizzySeconds(joy: Int) -> Double { 1.6 + 0.3 * Double(clamp(joy)) }
        static func wobble(joy: Int) -> Double { [0, 5, 7, 9, 11, 13][clamp(joy)] }     // degrees either way
        static func stars(joy: Int) -> Int { [0, 3, 3, 4, 5, 6][clamp(joy)] }
        static let wobbleHz = 2.6
        // Rude
        static let hardSpeed = 1150.0             // the core's hard bump, points per second
        static let sameThrow = 1.5                // a hard flick and the bumps after it are one throw
        static let rudeThrows = 2                 // hard throws in the window that make it rude
        static let rudeWindow = 8.0               // seconds
        static func sulkSeconds(joy: Int) -> Double { [30, 35, 40, 45, 50, 55][clamp(joy)] }
        static let grumpLonger = 0.5              // a fully grumpy Pip sulks this much longer (×1.5)
        static let sulkGlance = 3.0               // seconds between little "still looking away" nudges
        // Gentle
        static let patMin = 0.4                   // two taps closer than this are a rattle, not a pat
        static let patMax = 1.8                   // and further apart than this are two separate taps
        static let patAfterFlick = 1.5            // no pats straight after a flick
        // Mood memory
        static let grumpPerThrow = 0.3
        static let grumpPerPat = 0.4
        static let forgiveSeconds = 240.0         // grumpiness fades by about two thirds every 4 minutes
        // Talking
        static let maxLinesPerMinute = 3

        static func clamp(_ joy: Int) -> Int { min(max(joy, 0), 5) }
    }

    // MARK: Data

    enum Lines {
        static let dizzy = ["Whoa… room's spinning.", "Wheee… which way's up?", "Stars. I can see stars.",
                            "Round and round… ooh."]
        static let rude = ["…Rude.", "…That was rude.", "Hmph. Rude."]
        static let backFromSulk = "…Alright. A cuppa would help."
        static let pat = ["Mmm. Just there.", "Ooh, that's nice.", "Lovely. Thank you.", "Head pats. The best."]
        static let patWhileSulking = "…Hm. Fine. That's nice."
        static let sorry = ["Thanks. All forgotten.", "Water under the bridge.", "We're fine. Honest."]
    }

    enum Feeling { case fine, dizzy, sulking, content }

    /// What Pip is feeling this session. The plugin is a struct made once, so this lives in a class.
    @MainActor @Observable final class Mind {
        var feeling = Feeling.fine
        var stars = 0                                     // stars round Pip's head; 0 hides them
        var sulkEnds = Date.distantPast
        @ObservationIgnored var flicks: [Date] = []
        @ObservationIgnored var throwsAt: [Date] = []
        @ObservationIgnored var lastHard = Date.distantPast
        @ObservationIgnored var lastFlick = Date.distantPast
        @ObservationIgnored var lastTap = Date.distantPast
        @ObservationIgnored var dizzySince = Date.distantPast
        @ObservationIgnored var said: [Date] = []
        @ObservationIgnored var floorUntil = Date.distantPast
        @ObservationIgnored var sulkTurn = 0              // so an old sulk's timers don't end a new one
        @ObservationIgnored var lookSide = 1.0
        @ObservationIgnored var leaned = false
        @ObservationIgnored var wobble: Task<Void, Never>?
    }
    private let mind = Mind()

    // MARK: Logic

    /// Plain-words state for the card and VoiceOver.
    static func status(_ f: Feeling, sulkLeft: Double, pipHere: Bool) -> String {
        guard pipHere else { return "Pip is switched off, so Pip has no feelings to show." }
        switch f {
        case .fine: return "Pip's feeling fine."
        case .dizzy: return "Pip's a bit dizzy."
        case .sulking: return "Pip's sulking quietly. About \(max(5, Int((sulkLeft / 5).rounded()) * 5)) seconds to go."
        case .content: return "Pip's feeling content."
        }
    }

    /// How grumpy Pip still is, 0...1, faded by the time since it was saved. Never shown as a score.
    private func grump(_ host: PipHost) -> Double {
        let g: Double = host.value("feelings", "grump") ?? 0
        let at: Double = host.value("feelings", "grumpAt") ?? Date.now.timeIntervalSince1970
        let gone = max(0, Date.now.timeIntervalSince1970 - at)
        return min(1, max(0, g * exp(-gone / Tune.forgiveSeconds)))
    }

    private func setGrump(_ g: Double, _ host: PipHost) {
        host.setValue(min(1, max(0, g)), "feelings", "grump")
        host.setValue(Date.now.timeIntervalSince1970, "feelings", "grumpAt")
    }

    private func sulks(_ host: PipHost) -> Bool { host.value("feelings", "sulks") ?? true }
    private var sulking: Bool { mind.feeling == .sulking }

    func on(_ event: PipEvent, _ host: PipHost) {
        // Pip off, not on screen or asleep: nothing happens at all.
        guard host.pipHere, !host.pipAsleep else { return }
        let now = Date.now
        switch event {
        case .flick(let speed):
            mind.lastFlick = now
            if speed > Tune.hardSpeed { hardThrow(host) }
            guard !sulking else { return }
            mind.flicks = mind.flicks.filter { now.timeIntervalSince($0) < Tune.dizzyWindow } + [now]
            if mind.flicks.count >= Tune.dizzyFlicks, now.timeIntervalSince(mind.dizzySince) > Tune.dizzyRest {
                mind.flicks = []
                getDizzy(host)
            }
        case .bump(let speed) where speed > Tune.hardSpeed:
            hardThrow(host)
        case .tap:
            let gap = now.timeIntervalSince(mind.lastTap)
            mind.lastTap = now
            let gentle = gap >= Tune.patMin && gap <= Tune.patMax
                && now.timeIntervalSince(mind.lastFlick) > Tune.patAfterFlick
            if gentle {
                mind.lastTap = .distantPast             // a third tap starts a new pat
                pat(host)
            }
            // Any other tap while sulking is quietly ignored.
        default:
            break
        }
    }

    /// A hard flick or hard bump. The bumps that follow a hard flick are the same throw.
    private func hardThrow(_ host: PipHost) {
        let now = Date.now
        guard now.timeIntervalSince(mind.lastHard) > Tune.sameThrow else { mind.lastHard = now; return }
        mind.lastHard = now
        setGrump(grump(host) + Tune.grumpPerThrow, host)
        guard sulks(host), !sulking else { return }
        mind.throwsAt = mind.throwsAt.filter { now.timeIntervalSince($0) < Tune.rudeWindow } + [now]
        if mind.throwsAt.count >= Tune.rudeThrows {
            mind.throwsAt = []
            startSulk(host)
        }
    }

    // Dizzy

    private func getDizzy(_ host: PipHost) {
        let joy = host.joy
        let seconds = Tune.dizzySeconds(joy: joy)
        mind.dizzySince = .now
        mind.feeling = .dizzy
        say(Lines.dizzy.randomElement()!, host, for: 1.8)
        host.later(seconds) { if mind.feeling == .dizzy { mind.feeling = .fine } }
        guard joy > 0 else { return }                   // Joy 0: words only
        host.react(.dizzy, for: seconds)                // the spinning eyes
        withAnimation(.easeOut(duration: 0.3)) { mind.stars = Tune.stars(joy: joy) }
        host.later(seconds) { withAnimation(.easeInOut(duration: 0.6)) { mind.stars = 0 } }
        // A little wobble, unless motion is simpler or Pip's Weight is steering Pip's tilt (it owns the lean then).
        guard !host.simpler, !host.isOn("weight") else { return }
        wobble(host, degrees: Tune.wobble(joy: joy), seconds: seconds)
    }

    private func wobble(_ host: PipHost, degrees: Double, seconds: Double) {
        let pip = host.pip
        mind.wobble?.cancel()
        mind.wobble = Task { @MainActor in
            let start = Date.now
            while !Task.isCancelled {
                let t = Date.now.timeIntervalSince(start)
                guard t < seconds, !pip.held, host.pipHere else { break }
                let fade = 1 - t / seconds
                pip.lean = degrees * fade * sin(2 * .pi * Tune.wobbleHz * t)
                try? await Task.sleep(for: .milliseconds(16))
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { pip.lean = 0 }
        }
    }

    // Rude

    private func startSulk(_ host: PipHost) {
        let joy = host.joy
        let seconds = Tune.sulkSeconds(joy: joy) * (1 + Tune.grumpLonger * grump(host))
        mind.sulkTurn += 1
        let turn = mind.sulkTurn
        mind.feeling = .sulking
        mind.sulkEnds = Date.now.addingTimeInterval(seconds)
        mind.stars = 0
        say(Lines.rude.randomElement()!, host, for: 1.6)
        // Then Pip keeps the floor while sulking, so nobody else makes them chirpy. Quiet, not chatty.
        holdFloor(host, for: seconds)
        if joy > 0 {
            let pip = host.pip
            withAnimation(.easeInOut(duration: 1.2)) { pip.halo = PipLook.orbDeep.opacity(0.45) }   // dims a touch
            if !host.simpler {
                mind.lookSide = Bool.random() ? 1 : -1
                lookAway(pip)
                if joy >= 2, !host.isOn("weight") {
                    mind.leaned = true
                    withAnimation(.easeInOut(duration: 0.8)) { pip.lean = -4 * mind.lookSide }
                }
                glance(host, turn: turn)
            }
        }
        host.later(seconds) {
            guard mind.sulkTurn == turn, sulking else { return }
            endSulk(host, kindly: false)
        }
    }

    private func lookAway(_ pip: PipModel) {
        withAnimation(.easeInOut(duration: 0.6)) { pip.look = CGSize(width: 0.85 * mind.lookSide, height: 0.35) }
    }

    /// Every few seconds, eyes back to "not looking at you". Stops as soon as the sulk ends or Pip goes.
    private func glance(_ host: PipHost, turn: Int) {
        host.later(Tune.sulkGlance) {
            guard mind.sulkTurn == turn, sulking else { return }
            guard host.pipHere, host.isOn("feelings") else { endSulk(host, kindly: true); return }
            lookAway(host.pip)
            glance(host, turn: turn)
        }
    }

    /// The sulk is over. `kindly`: a pat or a sorry ended it, so no cuppa line (that's been said already).
    fileprivate func endSulk(_ host: PipHost, kindly: Bool) {
        guard sulking else { return }
        mind.sulkTurn += 1
        mind.feeling = kindly ? .content : .fine
        mind.sulkEnds = .distantPast
        let pip = host.pip
        withAnimation(.easeInOut(duration: 1.2)) { pip.halo = nil }
        withAnimation(.easeInOut(duration: 0.6)) { pip.look = .zero }
        if mind.leaned {
            mind.leaned = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { pip.lean = 0 }
        }
        releaseFloor(host)
        if kindly {
            host.later(4) { if mind.feeling == .content { mind.feeling = .fine } }
            return
        }
        guard host.pipHere, say(Lines.backFromSulk, host, for: 2.6) else { return }
        // Tea Break, if it's on, can take it from here (a tap then serves the cuppa).
        if host.isOn("teabreak") { host.post(.custom("feelings.wantsTea")) }
    }

    // Gentle

    private func pat(_ host: PipHost) {
        setGrump(grump(host) - Tune.grumpPerPat, host)
        if sulking {
            endSulk(host, kindly: true)
            say(Lines.patWhileSulking, host, for: 2)
        } else {
            mind.feeling = .content
            say(Lines.pat.randomElement()!, host, for: 1.8)
            host.later(4) { if mind.feeling == .content { mind.feeling = .fine } }
        }
        guard host.joy > 0 else { return }              // Joy 0: words only
        host.react(.happy, for: 1.4)
        host.blush(.pink, for: 2.2)                     // warmer, then back to Pip's own glow (a fade)
        guard !host.simpler else { return }
        let pip = host.pip
        withAnimation(.easeOut(duration: 0.5)) { pip.glow = 0.5 }
        host.later(0.6) { withAnimation(.easeInOut(duration: 1.4)) { pip.glow = 0 } }
    }

    /// The card's one-tap calm: always works, never asks anything back.
    fileprivate func sorry(_ host: PipHost) {
        setGrump(0, host)
        guard host.pipHere, sulking else { return }
        endSulk(host, kindly: true)
        say(Lines.sorry.randomElement()!, host, for: 2)
        if host.joy > 0 { host.cheer() }
    }

    // Talking: only on Pip's turn, at most 3 lines a minute.

    @discardableResult
    private func say(_ line: String, _ host: PipHost, for seconds: Double) -> Bool {
        let now = Date.now
        mind.said = mind.said.filter { now.timeIntervalSince($0) < 60 }
        guard mind.said.count < Tune.maxLinesPerMinute,
              PipTalkTurns.floorFree(host) || now < mind.floorUntil,     // free, or we're the ones holding it
              host.say(line, for: seconds) else { return false }
        mind.said.append(now)
        holdFloor(host, for: seconds + 0.3)
        return true
    }

    /// The floor's end as everyone sees it (seconds since 1970).
    private func floorEnd(_ host: PipHost) -> Double { host.value("pip", "askingUntil") ?? 0 }

    /// Hold the floor a while. Never shortens anyone else's turn.
    private func holdFloor(_ host: PipHost, for seconds: Double) {
        let until = max(mind.floorUntil, Date.now.addingTimeInterval(seconds))
        mind.floorUntil = until
        let end = max(until.timeIntervalSince1970, floorEnd(host))
        PipTalkTurns.takeFloor(host, for: end - Date.now.timeIntervalSince1970)
    }

    /// Give our turn back early, unless someone else has taken the floor since.
    private func releaseFloor(_ host: PipHost) {
        guard Date.now < mind.floorUntil else { return }
        let ours = floorEnd(host) <= mind.floorUntil.timeIntervalSince1970 + 0.01
        mind.floorUntil = .now
        if ours { PipTalkTurns.takeFloor(host, for: 0) }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Stars(mind: mind, host: host) }

    /// The wonder: little stars circling Pip's head while they're dizzy. Under simpler motion they just fade.
    struct Stars: View {
        let mind: Mind
        let host: PipHost

        var body: some View {
            ZStack(alignment: .topLeading) {
                if mind.stars > 0, host.pipHere {
                    TimelineView(.animation(paused: host.simpler)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        let p = host.pipPosition
                        let r = host.pip.radius
                        ZStack(alignment: .topLeading) {
                            ForEach(0..<mind.stars, id: \.self) { i in
                                let a = (host.simpler ? 0 : t * 4) + Double(i) * 2 * .pi / Double(mind.stars)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(PipLook.glow)
                                    .opacity(sin(a) < 0 ? 0.45 : 0.95)
                                    .position(x: p.x + cos(a) * r * 1.3, y: p.y - r - 6 + sin(a) * r * 0.4)
                            }
                        }
                    }
                    .transition(.opacity)
                    .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    func card(_ host: PipHost) -> some View { FeelingsCard(plugin: self, host: host) }

    struct FeelingsCard: View {
        let plugin: PipsFeelings
        let host: PipHost
        @AppStorage("plug.feelings.sulks") private var sulks = true

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    let left = max(0, plugin.mind.sulkEnds.timeIntervalSince(tl.date))
                    Text(PipsFeelings.status(plugin.mind.feeling, sulkLeft: left, pipHere: host.pipHere)).bold()
                }
                Toggle("Pip sulks when thrown about", isOn: $sulks)
                    .accessibilityLabel("Let Pip sulk for a bit after being thrown hard twice")
                Button("Say sorry") { plugin.sorry(host) }
                    .buttonStyle(PluginCardButton())
                    .disabled(!host.pipHere || plugin.mind.feeling != .sulking)
                    .accessibilityLabel("Say sorry to Pip")
                    .accessibilityHint("Ends Pip's sulk straight away.")
                Text("Flick Pip a few times and they get dizzy. Two slow taps are a head pat. Two hard throws are rude, but Pip soon forgets.")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13.5))
        }
    }
}
