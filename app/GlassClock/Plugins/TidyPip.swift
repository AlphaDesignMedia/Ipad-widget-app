import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// TIDY PIP · plugin v1.1 (Dream). Pip likes things tidy, but learns how lived-in you like your space. When a card or
// panel has sat open a while with no touches, Pip asks "Are you finished here?" (3 times a session at most):
// Tidy up, Leave it, or Never ask. Tidying closes it with a little sweep and a dust puff, and "Put it back" undoes it
// for 10 seconds. Every Leave it or Put it back nudges Pip's Tidiness towards Messy and cosy; every Tidy up towards
// Spotless. Very cosy and Pip stops asking. Simpler motion: fades only.
// Drawings come first: if there's Sketch ink, Pip asks even with nothing open, and Tidy up sweeps the strokes into
// a little dust puff by Pip before closing the card or panel. Put it back brings both back. Joy 0: gone at once.
// Pip shows how first: the first time for each bit (drawings, a panel, a card), Pip points and says how to do it
// yourself (Sketch's Clear, flick a panel's title bar, tap a card's bar button), with a soft glow on a panel's
// title bar. Do it and Pip says "There you go!" and won't show that bit again. Ignore it and Pip asks
// "Want me to do it?" (Tidy up as above). Showing and asking share the 3 offers a session, then Pip stops.
// Pip off: Pip never shows or asks, but the card's "Tidy up" still tidies plainly (a fade, no talk), with Put it back.
// Joy: sets the sweep and the size of the dust puff (0 = no puff). Wonder: the little puff of glitter-dust.
// Where: the broom button in the plugin bar (the Tidiness setting).

struct TidyPip: SandboxPlugin {
    let info = PluginInfo(id: "tidypip", name: "Tidy Pip", version: "v1.1", shelf: .dream,
                          icon: "wind", what: "Pip shows you how to tidy, then offers to: drawings first, then panels.")

    // MARK: Data

    enum Tune {
        static let asksPerSession = 3
        static let undoSeconds: Double = 10
        static let answerWait: Double = 15      // an unanswered ask quietly goes away (nothing nudged)
        static let step = 0.1                   // how far each answer nudges Tidiness
        static let quiet = 0.15                 // below this, Pip stops asking
        static let start = 0.5
        static let inkSweep: Double = 0.55      // drawings swept into the puff by Pip
        static let inkFade: Double = 0.35       // simpler motion, or the plain card button: just a fade
        static let guideWait: Double = 30       // how long Pip waits to see if you do it yourself
        static let titleBar: CGFloat = 46       // the glowing strip at the top of a panel
        /// How long something sits untouched before Pip asks: about 5 min at joy 1 and middling tidiness,
        /// sooner as joy rises, longer when cosy (1.5× at the cosy end, 0.5× when spotless). Joy 0 never asks.
        static func wait(_ tidiness: Double, joy: Int) -> Double {
            [Double.infinity, 300, 220, 160, 110, 75][min(max(joy, 0), 5)] * (1.5 - tidiness)
        }
    }

    enum Lines {
        static let ask = ["Are you finished here?", "All done with this? I could tidy up.", "Shall I put this away?"]
        static let tidy = ["Swish. All tidy.", "There we go. Neat.", "Tidied!"]
        static let leave = "Leaving it. It's your space."
        static let never = "I won't ask again. Promise."
        static let back = "Put back exactly where it was."
        static let cosy = "You like it lived-in. Me too, actually."
        static let spotless = "Spotless. I like your style."
        static let doIt = ["Want me to do it?", "Shall I do it for you?"]
        static let thereYouGo = ["There you go!", "Like that. Nice.", "You've got it."]
        static let showClear = "Tap Clear to wipe the page."
        static let showSketch = "Open Sketch and tap Clear to wipe the page."
        static let showTuck = "Flick the title bar to the edge to tuck it away."
        static let showClose = "Tap its button in the bar again to put it away."
    }

    /// The bits Pip can show you how to tidy yourself. Pip remembers which ones you know.
    enum Topic: String {
        case ink, panel, card
        var knowsKey: String { "knows." + rawValue }
    }

    /// Pip showing how, while they wait to see if you do it.
    struct Guide {
        var topic: Topic
        var about: String                       // what an ask after it is about (a card id, or "ink")
        var card: String?
        var at: Date
        var panelX: CGFloat?                    // where the panel sat, to notice it being tucked
    }

    // MARK: Logic

    @MainActor @Observable final class Tidy {
        var asking = false
        var undoFor: String?                    // the card Pip just tidied, while it can still be put back
        var inkKept = false                     // Pip just tidied the drawings, and they can still be put back
        var puff = 0                            // bumps to play the dust puff
        var sweepInk: [Sketch.Stroke] = []      // a copy of the drawings, shown only while they sweep away
        var sweepID = 0
        var sweepTo = CGPoint.zero
        var sweepStill = false
        var canPutBack: Bool { undoFor != nil || inkKept }
        var glow: CGRect?                       // a soft glow on the real control Pip's showing (Pip's space)
        @ObservationIgnored var guiding: Guide?
        @ObservationIgnored var guided: Set<String> = []
        @ObservationIgnored var plain = false   // tidied from the card: no talk, no nudge
        @ObservationIgnored var undoToken = 0
        @ObservationIgnored var lastTouch = Date.now
        @ObservationIgnored var asked = 0
        @ObservationIgnored var askedAbout: String?
        @ObservationIgnored var watcher: TidyTouchWatch?
        @ObservationIgnored var loop: Task<Void, Never>?
    }
    private let tidy = Tidy()

    private func tidiness(_ host: PipHost) -> Double { (host.value("tidypip", "tidiness") as Double?) ?? Tune.start }

    /// How many strokes Sketch has on screen (0 when Sketch is off).
    private func inkCount(_ host: PipHost) -> Int { host.isOn("sketch") ? Sketch.strokeCount : 0 }

    func start(_ host: PipHost) throws {
        guard tidy.loop == nil else { return }
        // Ends itself when Tidy Pip is switched off; switching it on calls `start` again.
        tidy.loop = Task { @MainActor in
            while !Task.isCancelled, host.isOn("tidypip") {
                tick(host)
                try? await Task.sleep(for: .seconds(2))
            }
            tidy.loop = nil
        }
    }

    private func tick(_ host: PipHost) {
        guard host.isOn("tidypip"), host.pipHere else { return }
        install()
        if let g = tidy.guiding { checkGuide(g, host); return }
        guard !tidy.asking, !tidy.canPutBack, tidy.sweepInk.isEmpty, tidy.asked < Tune.asksPerSession,
              (host.value("tidypip", "never") as Bool?) != true else { return }
        let open = host.openCard
        guard open != "tidypip", open != nil || inkCount(host) > 0 else { return }
        let about = open ?? "ink"
        guard about != tidy.askedAbout else { return }
        let t = tidiness(host)
        guard t >= Tune.quiet, Date.now.timeIntervalSince(tidy.lastTouch) >= Tune.wait(t, joy: host.joy),
              PipTalkTurns.spend(host) else { return }
        // Drawings first. A bit Aaron hasn't shown he knows, not shown yet this session: Pip shows how first.
        let topic: Topic = inkCount(host) > 0 ? .ink : (host.panelFrame.isNull ? .card : .panel)
        if (host.value("tidypip", topic.knowsKey) as Bool?) != true, !tidy.guided.contains(topic.rawValue) {
            guide(topic, about: about, card: open, host)
        } else {
            ask(about, Lines.ask, host)
        }
    }

    /// Pip looks at the real control and says how to do it yourself. One of the 3 offers.
    private func guide(_ topic: Topic, about: String, card: String?, _ host: PipHost) {
        PipTalkTurns.takeFloor(host, for: 4)
        tidy.asked += 1
        tidy.guided.insert(topic.rawValue)
        var g = Guide(topic: topic, about: about, card: card, at: .now)
        let line: String
        switch topic {
        case .ink: line = card == "sketch" ? Lines.showClear : Lines.showSketch
        case .panel:
            line = Lines.showTuck
            g.panelX = host.panelFrame.minX
            if let bar = titleBar(host) {
                withAnimation(.easeInOut(duration: 0.4)) { tidy.glow = bar }
                host.lookAt(CGPoint(x: bar.midX, y: bar.midY))
            }
        case .card: line = Lines.showClose
        }
        tidy.guiding = g
        host.react(.curious, for: 1.4)
        host.say(line, for: 3.4)
    }

    /// Did Aaron do it? A small "There you go!", and Pip won't show that bit again. Ignored, with no touches since:
    /// Pip offers to do it. Busy elsewhere: Pip lets it be for now.
    private func checkGuide(_ g: Guide, _ host: PipHost) {
        let done: Bool
        switch g.topic {
        case .ink: done = inkCount(host) == 0
        case .panel:
            done = host.openCard != g.card
                || (g.panelX.map { abs(host.panelFrame.minX - $0) > PanelLook.width / 2 } ?? false)
        case .card: done = host.openCard != g.card
        }
        let late = Date.now.timeIntervalSince(g.at) >= Tune.guideWait
        guard done || late else { return }
        tidy.guiding = nil
        withAnimation(.easeInOut(duration: 0.3)) { tidy.glow = nil }
        if done, tidy.canPutBack || !tidy.sweepInk.isEmpty { return }      // Pip tidied it (the card button), not Aaron
        if done {
            host.setValue(true, "tidypip", g.topic.knowsKey)
            host.react(.happy, for: 1.4)
            host.later(1.2) {
                if PipTalkTurns.floorFree(host) {
                    PipTalkTurns.takeFloor(host, for: 2)
                    host.say(Lines.thereYouGo.randomElement()!, for: 1.8)
                }
            }
        } else if tidy.lastTouch <= g.at, !tidy.asking, (host.value("tidypip", "never") as Bool?) != true, !tidy.canPutBack, tidy.asked < Tune.asksPerSession,
                  host.openCard != "tidypip", PipTalkTurns.spend(host) {
            ask(g.about, Lines.doIt, host)
        }
    }

    /// "Are you finished here?" or "Want me to do it?", with Tidy up, Leave it and Never ask under Pip.
    private func ask(_ about: String, _ lines: [String], _ host: PipHost) {
        PipTalkTurns.takeFloor(host, for: Tune.answerWait)
        tidy.asked += 1
        tidy.askedAbout = about
        withAnimation(.easeInOut(duration: 0.3)) { tidy.asking = true }
        host.react(.curious, for: 1.4)
        host.say(lines.randomElement()!, for: 3)
        let round = tidy.asked
        host.later(Tune.answerWait) {
            guard tidy.asking, tidy.asked == round else { return }
            withAnimation(.easeInOut(duration: 0.3)) { tidy.asking = false }
        }
    }

    enum Answer { case tidy, leave, never }

    fileprivate func answer(_ a: Answer, _ host: PipHost) {
        withAnimation(.easeInOut(duration: 0.3)) { tidy.asking = false }
        PipTalkTurns.takeFloor(host, for: 3)
        switch a {
        case .tidy:
            let id = host.openCard
            guard id != nil || inkCount(host) > 0 else { return }
            PipTalkTurns.takeFloor(host, for: 4)
            nudge(+Tune.step, host)
            sweep(id, host)
        case .leave:
            nudge(-Tune.step, host)
            host.say(Lines.leave, for: 2)
        case .never:
            host.setValue(true, "tidypip", "never")
            host.say(Lines.never, for: 2)
        }
    }

    /// Pip flutters over and tidies: the drawings first (swept into a puff of dust by Pip), then the card or panel.
    /// "Put it back" brings both back for 10 seconds. With no drawings, it's just the card, as before.
    private func sweep(_ id: String?, _ host: PipHost) {
        if !host.simpler, host.joy > 0, let at = target(host) { host.move(to: at) }
        host.later(host.simpler ? 0.2 : 0.7) {
            tidy.plain = false
            let inkTime = tidyInk(host, still: host.simpler)
            if let t = inkTime, t > 0 {
                host.later(t) { finish(id, host, ink: true) }
            } else {
                finish(id, host, ink: inkTime != nil)
            }
        }
    }

    /// The card's own "Tidy up" (works with Pip off too): drawings fade, the card closes, no talk and no nudge.
    fileprivate func tidyNow(_ host: PipHost) {
        guard !tidy.canPutBack, tidy.sweepInk.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.3)) { tidy.asking = false }
        tidy.plain = true
        let id = host.openCard
        let inkTime = tidyInk(host, still: true)
        if let t = inkTime, t > 0 {
            host.later(t) { finish(id, host, ink: true) }
        } else {
            finish(id, host, ink: inkTime != nil)
        }
    }

    /// Takes the drawings away (Sketch keeps them for Put it back) and plays the sweep. Returns how long the sweep
    /// takes (0 at joy 0: gone at once), or nil when there was nothing drawn.
    private func tidyInk(_ host: PipHost, still: Bool) -> Double? {
        guard host.isOn("sketch"), let ink = Sketch.shared else { return nil }
        let kept = ink.tidy()
        guard !kept.isEmpty else { return nil }
        guard host.joy > 0 else { return 0 }
        let time = still ? Tune.inkFade : Tune.inkSweep
        tidy.sweepTo = host.pipHere ? host.pipPosition : .zero
        tidy.sweepStill = still || !host.pipHere
        tidy.sweepInk = kept
        tidy.sweepID += 1
        let run = tidy.sweepID
        host.later(time + 0.05) { if tidy.sweepID == run { tidy.sweepInk = [] } }
        return time
    }

    /// The card or panel goes away (if it's still the one open), then Put it back shows for 10 seconds.
    private func finish(_ id: String?, _ host: PipHost, ink: Bool) {
        let closing = id != nil && host.openCard == id
        guard closing || ink else { return }
        if !tidy.plain, host.joy > 0 { tidy.puff += 1 }
        withAnimation(.easeOut(duration: 0.25)) {
            if closing { host.openCard = nil }
            tidy.undoFor = closing ? id : nil
            tidy.inkKept = ink
        }
        if !tidy.plain {
            if host.joy >= 2 { host.cheer() }
            host.say(Lines.tidy.randomElement()!, for: 1.6)
        }
        tidy.undoToken += 1
        let token = tidy.undoToken
        host.later(Tune.undoSeconds) {
            guard tidy.undoToken == token else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                tidy.undoFor = nil
                tidy.inkKept = false
            }
        }
    }

    fileprivate func putBack(_ host: PipHost) {
        guard tidy.canPutBack else { return }
        let id = tidy.undoFor, ink = tidy.inkKept
        tidy.undoToken += 1
        tidy.sweepInk = []
        withAnimation(.easeOut(duration: 0.25)) {
            if ink, host.isOn("sketch") { Sketch.shared?.putBack() }
            if let id { host.openCard = id }
            tidy.undoFor = nil
            tidy.inkKept = false
        }
        guard !tidy.plain else { return }
        nudge(-Tune.step, host)
        host.say(Lines.back, for: 1.8)
    }

    /// Moves Tidiness, and Pip says something warm when they notice which way you lean.
    private func nudge(_ by: Double, _ host: PipHost) {
        let old = tidiness(host)
        let new = min(max(old + by, 0), 1)
        host.setValue(new, "tidypip", "tidiness")
        if old >= 0.3, new < 0.3 {
            host.later(2.4) { host.say(Lines.cosy, for: 2.6) }
        } else if old < 0.8, new >= 0.8 {
            host.later(2.4) { host.say(Lines.spotless, for: 2.2) }
        }
    }

    /// Just beside the open panel or card (or the drawings, when nothing's open), in Pip's space, inside the screen.
    private func target(_ host: PipHost) -> CGPoint? {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return nil }
        let inset = window.safeAreaInsets
        let frame = host.panelFrame.isNull ? host.cardFrame : host.panelFrame
        let f = frame.isNull ? inkBox(host) : frame.offsetBy(dx: -inset.left, dy: -inset.top)
        guard !f.isNull else { return nil }
        let width = window.bounds.width - inset.left - inset.right
        let x = f.midX > width / 2 ? f.minX - 50 : f.maxX + 50
        return CGPoint(x: min(max(x, 140), width - 140), y: max(f.minY + 80, 140))
    }

    /// The open panel's title bar strip, in Pip's space.
    private func titleBar(_ host: PipHost) -> CGRect? {
        guard !host.panelFrame.isNull,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else { return nil }
        let inset = window.safeAreaInsets
        let f = host.panelFrame.offsetBy(dx: -inset.left, dy: -inset.top)
        return CGRect(x: f.minX + 10, y: f.minY + 10, width: f.width - 20, height: Tune.titleBar)
    }

    /// Where the drawings are, already in Pip's space.
    private func inkBox(_ host: PipHost) -> CGRect {
        guard inkCount(host) > 0, let ink = Sketch.shared else { return .null }
        return ink.strokes.reduce(CGRect.null) { box, s in
            guard s.box.count == 4 else { return box }
            return box.union(CGRect(x: CGFloat(s.box[0]), y: CGFloat(s.box[1]),
                                    width: CGFloat(s.box[2] - s.box[0]), height: CGFloat(s.box[3] - s.box[1])))
        }
    }

    private func install() {
        guard tidy.watcher == nil,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        let watch = TidyTouchWatch()
        watch.onTouch = { [tidy] in tidy.lastTouch = .now }
        window.addGestureRecognizer(watch)
        tidy.watcher = watch
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { TidyOverlay(tidy: tidy, plugin: self, host: host) }

    struct TidyOverlay: View {
        let tidy: Tidy
        let plugin: TidyPip
        let host: PipHost

        var body: some View {
            ZStack(alignment: .topLeading) {
                if !tidy.sweepInk.isEmpty {
                    InkSweep(strokes: tidy.sweepInk, to: tidy.sweepTo, still: tidy.sweepStill)
                        .id(tidy.sweepID)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if host.pipHere, let g = tidy.glow {
                    Glow(still: host.simpler)
                        .frame(width: g.width, height: g.height)
                        .position(x: g.midX, y: g.midY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if host.pipHere {
                    let p = host.pipPosition
                    DustPuff(trigger: tidy.puff, joy: host.joy, still: host.simpler)
                        .position(x: p.x, y: p.y + 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    if tidy.asking {
                        choice(spacing: 6) {
                            Button("Tidy up") { plugin.answer(.tidy, host) }
                                .buttonStyle(PluginCardButton(on: true))
                                .accessibilityLabel("Tidy up: put this away")
                            Button("Leave it") { plugin.answer(.leave, host) }
                                .buttonStyle(PluginCardButton())
                                .accessibilityLabel("Leave it open")
                            Button("Never ask") { plugin.answer(.never, host) }
                                .buttonStyle(PluginCardButton())
                                .accessibilityLabel("Never ask about tidying")
                        }
                        .position(x: p.x, y: p.y + 70)
                        .transition(.opacity)
                    } else if tidy.canPutBack {
                        putBackButton
                            .position(x: p.x, y: p.y + 70)
                            .transition(.opacity)
                    }
                } else if tidy.canPutBack {
                    // Pip's away: Put it back sits low in the middle instead.
                    putBackButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 96)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        private var putBackButton: some View {
            choice(spacing: 6) {
                Button("Put it back") { plugin.putBack(host) }
                    .buttonStyle(PluginCardButton(on: true))
                    .accessibilityLabel("Put it back as it was")
            }
        }

        private func choice<C: View>(spacing: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
            HStack(spacing: spacing) { content() }
                .padding(PluginBarLook.cardPadding)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PluginBarLook.radius))
                .fixedSize()
        }
    }

    /// A soft Pip-coloured glow round the control Pip's showing. It breathes gently; simpler motion keeps it still.
    struct Glow: View {
        let still: Bool
        @State private var up = false

        var body: some View {
            RoundedRectangle(cornerRadius: PluginBarLook.radius)
                .stroke(PipLook.glow, lineWidth: 2)
                .shadow(color: PipLook.glow, radius: up ? 10 : 5)
                .opacity(up ? 0.9 : 0.55)
                .onAppear {
                    if still { up = true } else {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { up = true }
                    }
                }
        }
    }

    /// The drawings on their way out: they shrink into Pip as they fade (simpler motion or Pip away: a fade only).
    struct InkSweep: View {
        let strokes: [Sketch.Stroke]
        let to: CGPoint
        let still: Bool
        @State private var gone = false

        var body: some View {
            GeometryReader { g in
                Canvas { ctx, _ in for s in strokes { Sketch.draw(s, in: ctx) } }
                    .scaleEffect(gone && !still ? 0.04 : 1,
                                 anchor: UnitPoint(x: to.x / max(g.size.width, 1), y: to.y / max(g.size.height, 1)))
                    .opacity(gone ? 0 : 1)
            }
            .onAppear {
                withAnimation(still ? .easeOut(duration: TidyPip.Tune.inkFade) : .easeIn(duration: TidyPip.Tune.inkSweep)) {
                    gone = true
                }
            }
        }
    }

    /// The small wonder: a few specks of Pip-coloured dust that drift out and fade. More specks at higher joy;
    /// under simpler motion they only fade.
    struct DustPuff: View {
        let trigger: Int
        let joy: Int
        let still: Bool
        @State private var out = false
        @State private var shown = false

        var body: some View {
            let count = [0, 5, 7, 9, 12, 14][min(max(joy, 0), 5)]
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let a = Double(i) / Double(max(count, 1)) * 2 * .pi + 0.4
                    Circle()
                        .fill(PipLook.glow)
                        .frame(width: i % 3 == 0 ? 5 : 3, height: i % 3 == 0 ? 5 : 3)
                        .offset(x: out && !still ? cos(a) * 26 : 0, y: out && !still ? sin(a) * 18 - 6 : 0)
                }
            }
            .opacity(shown ? 1 : 0)
            .onChange(of: trigger) {
                out = false
                shown = true
                withAnimation(.easeOut(duration: 0.6)) { out = true }
                withAnimation(.easeIn(duration: 0.5).delay(0.4)) { shown = false }
            }
        }
    }

    func card(_ host: PipHost) -> some View { TidyCard(host: host, plugin: self) }

    struct TidyCard: View {
        let host: PipHost
        let plugin: TidyPip
        @AppStorage("plug.tidypip.tidiness") private var tidiness = TidyPip.Tune.start
        @AppStorage("plug.tidypip.never") private var never = false

        private var readout: String {
            switch tidiness {
            case ..<TidyPip.Tune.quiet: "Very cosy: Pip has stopped asking."
            case ..<0.4: "Lived-in: Pip waits a good while before asking (about 7 minutes at calm joy)."
            case ..<0.7: "In between: Pip asks after about 5 minutes at calm joy."
            default: "Spotless: Pip asks after about 3 minutes at calm joy."
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                HStack {
                    Text("Messy and cosy").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Spotless").font(.caption).foregroundStyle(.secondary)
                }
                Slider(value: $tidiness, in: 0...1)
                    .accessibilityLabel("Tidiness")
                    .accessibilityValue(readout)
                Text(readout).font(.system(size: 13.5))
                Text("It moves by itself: Leave it and Put it back nudge it cosier, Tidy up nudges it tidier.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Pip may ask to tidy", isOn: Binding(get: { !never }, set: { never = !$0 }))
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let Pip ask to tidy")
                Button("Tidy up") { plugin.tidyNow(host) }
                    .buttonStyle(PluginCardButton(on: true))
                    .accessibilityLabel("Tidy up now: put the drawings and this card away")
            }
        }
    }
}

/// Hears every touch on the window and lets it through untouched. It never recognises, so it never gets in the way.
final class TidyTouchWatch: UIGestureRecognizer, UIGestureRecognizerDelegate {
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
