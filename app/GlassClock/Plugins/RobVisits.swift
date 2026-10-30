import SwiftUI

// ROB POPS IN · plugin v1 (Dream). Rob is the crew's coder and he lives in a terminal, so that's all he gets:
// a small window, a blinking caret and a line of type. No body, no sprite, no new art. The wonder is meant to
// come from the timing and the writing, not the pixels, which is the cheapest trick there is.
// Where: the laptop button in the plugin bar. He also pops in unprompted, rarely, and only if you let him.
// Rob never takes a tap: the overlay ignores hit testing, so panels and the settings rail always win.
//
// GROWING ROB. He is sketched, not carved. To give him more, add to `Visits` below and nothing else.
// Keep him dry rather than zany, warm rather than clever, and let Pip be the funny one as often as he is.
// Two traits only, so far: he lives in the terminal, and he is quietly tired of being called Bob.

struct RobVisits: SandboxPlugin {
    let info = PluginInfo(id: "rob", name: "Rob pops in", version: "v1", shelf: .dream,
                          icon: "laptopcomputer",
                          what: "Rob, the crew's coder, leans in from a little terminal and has a word with Pip.")

    /// Every speed and timing for Rob, in one place.
    enum Tune {
        static let typeSpeed = 28.0       // characters a second
        static let readOpen = 1.1         // pause after Rob's line before Pip answers
        static let readPip = 2.6          // how long Pip's answer sits before Rob replies
        static let readClose = 2.8        // how long Rob's last line stays
        static let slideIn = 0.42         // seconds
        static let caretBlink = 0.53
        static let floorHeld = 9.0        // how long Rob holds the talking floor
        static let soonest = 240.0        // seconds before an unprompted visit is even possible
        static let chance = 0.18          // and then how likely, each check
        static let maxUnprompted = 2      // a session. Rob knows when he's outstayed his welcome.
        static let width = 300.0
    }

    /// One visit: Rob opens, Pip answers, Rob has the last word. `alone` is used when Pip isn't here.
    struct Visit {
        let open: String, pip: String, close: String, alone: String
    }

    static let visits: [Visit] = [
        Visit(open: "rob@sandbox:~$ just checking you're not on fire",
              pip: "I'm not on fire. I was asleep.",
              close: "that's the same thing in production",
              alone: "no answer. assuming no fire. logging it as a win"),
        Visit(open: "rob@sandbox:~$ morning. you've been running for a while",
              pip: "Is that bad?",
              close: "it's either very good or very bad. no middle",
              alone: "nobody in. I'll let myself out the way I came"),
        Visit(open: "rob@sandbox:~$ quick one. am I Bob",
              pip: "No. You're Rob.",
              close: "thank you. that's going in the commit message",
              alone: "asked an empty room if I was Bob. it said nothing. ominous"),
        Visit(open: "rob@sandbox:~$ I made your turn 12% less certain of itself",
              pip: "Why would you do that?",
              close: "because certainty looks fake on anyone. you're welcome",
              alone: "tuned something lovely. nobody saw. still counts"),
        Visit(open: "rob@sandbox:~$ do you ever think about how you're a sphere",
              pip: "Constantly. Do you ever think about how you're a font?",
              close: "…right. I'll see myself out",
              alone: "left a joke here for later. it'll keep"),
    ]

    @MainActor static let session = Session()

    @MainActor @Observable final class Session {
        var line: String?          // what Rob is showing. nil means he isn't here.
        var busy = false
        var unprompted = 0
        var since = Date.now
        func reset() { line = nil; busy = false; unprompted = 0; since = .now }
    }

    func start(_ host: PipHost) throws { Self.session.reset() }

    func on(_ event: PipEvent, _ host: PipHost) {
        // Rob only ever lets himself in when nothing else is happening, and never at joy 0 or 1.
        guard host.isOn("rob"), host.joy >= 2, Self.allowed(host) else { return }
        let s = Self.session
        guard !s.busy, s.unprompted < Tune.maxUnprompted else { return }
        guard Date.now.timeIntervalSince(s.since) > Tune.soonest else { return }
        guard Double.random(in: 0...1) < Tune.chance, PipTalkTurns.floorFree(host) else { return }
        s.unprompted += 1
        Self.pop(host)
    }

    /// Has Aaron left the door open for unprompted visits? Default yes, but joy has the last word.
    @MainActor static func allowed(_ host: PipHost) -> Bool {
        (host.value("rob", "unprompted") as Bool?) ?? true
    }

    /// Rob's whole visit, start to finish.
    @MainActor static func pop(_ host: PipHost) {
        let s = session
        guard !s.busy else { return }
        s.busy = true
        s.since = .now
        let v = visits.randomElement() ?? visits[0]
        let talking = host.pipHere && !host.pipAsleep
        PipTalkTurns.takeFloor(host, for: Tune.floorHeld)
        s.line = v.open

        host.later(Tune.readOpen) {
            if talking { host.say(v.pip, for: Tune.readPip) }
            host.later(talking ? Tune.readPip : 0.2) {
                s.line = talking ? v.close : v.alone
                host.later(Tune.readClose) {
                    s.line = nil
                    s.busy = false
                    PipTalkTurns.giveBack()
                }
            }
        }
    }

    func overlay(_ host: PipHost) -> some View {
        RobTerminal(session: Self.session, simpler: host.simpler, quiet: host.joy == 0)
            .allowsHitTesting(false)      // Rob never steals a tap. Panels and the rail always win.
    }

    func card(_ host: PipHost) -> some View { RobCard(host: host) }
}

// MARK: The terminal

/// Rob's whole body: a pane, a line of type and a caret. That's the lot.
private struct RobTerminal: View {
    let session: RobVisits.Session
    let simpler: Bool
    let quiet: Bool
    @State private var shown = 0
    @State private var caret = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                if let line = session.line {
                    pane(line)
                        .transition(simpler ? .opacity : .move(edge: .leading).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 20)
            .padding(.bottom, 28)
        }
        .animation(simpler ? .easeInOut(duration: 0.25) : .spring(duration: RobVisits.Tune.slideIn, bounce: 0.18),
                   value: session.line)
    }

    @ViewBuilder private func pane(_ line: String) -> some View {
        // Reduced motion and joy 0 both get the whole line at once: no typing, no blinking.
        let still = simpler || quiet
        let text = still ? line : String(line.prefix(shown))
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(PipLook.glow)
            if !still {
                Rectangle()
                    .fill(PipLook.accent)
                    .frame(width: 7, height: 14)
                    .opacity(caret ? 1 : 0)
            }
        }
        .frame(maxWidth: RobVisits.Tune.width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(PipLook.accent.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rob the coder says: \(line)")
        .task(id: line) {
            shown = 0
            guard !still else { return }
            let step = UInt64(1_000_000_000 / RobVisits.Tune.typeSpeed)
            for i in 1...line.count {
                try? await Task.sleep(nanoseconds: step)
                if Task.isCancelled { return }
                shown = i
            }
        }
        .task(id: still) {
            guard !still else { return }
            while !Task.isCancelled {
                caret.toggle()
                try? await Task.sleep(nanoseconds: UInt64(RobVisits.Tune.caretBlink * 1_000_000_000))
            }
        }
    }
}

// MARK: The panel

private struct RobCard: View {
    let host: PipHost
    @State private var unprompted = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rob").font(.system(size: 20, weight: .semibold))
            Text("Older brother. Codes. Not Bob, and never has been.")
                .font(.system(size: 14)).foregroundStyle(.secondary)

            Button {
                RobVisits.pop(host)
            } label: {
                Label("Have a word", systemImage: "laptopcomputer")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Rob leans in from his terminal and says something to Pip.")

            Toggle("Rob may pop in unprompted", isOn: $unprompted)
                .frame(minHeight: 44)
                .onChange(of: unprompted) { _, now in host.setValue(now, "rob", "unprompted") }

            Text(host.joy == 0 ? "At joy 0 Rob only comes when you ask, and he doesn't type."
                               : host.joy == 1 ? "At joy 1 Rob only comes when you ask."
                               : "Rob pops in now and then, at most twice a session.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(18)
        .onAppear { unprompted = RobVisits.allowed(host) }
    }
}
