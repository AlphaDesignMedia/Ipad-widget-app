import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// TIDY PIP · plugin v1 (Dream). Pip likes things tidy, but learns how lived-in you like your space. When a card or
// panel has sat open a while with no touches, Pip asks "Are you finished here?" (3 times a session at most):
// Tidy up, Leave it, or Never ask. Tidying closes it with a little sweep and a dust puff, and "Put it back" undoes it
// for 10 seconds. Every Leave it or Put it back nudges Pip's Tidiness towards Messy and cosy; every Tidy up towards
// Spotless. Very cosy and Pip stops asking. Pip off: nothing. Simpler motion: fades only.
// Joy: sets the sweep and the size of the dust puff (0 = no puff). Wonder: the little puff of glitter-dust.
// Where: the broom button in the plugin bar (the Tidiness setting).

struct TidyPip: SandboxPlugin {
    let info = PluginInfo(id: "tidypip", name: "Tidy Pip", version: "v1", shelf: .dream,
                          icon: "wind", what: "Pip offers to tidy away open panels, and learns how cosy you like it.")

    // MARK: Data

    enum Tune {
        static let asksPerSession = 3
        static let undoSeconds: Double = 10
        static let answerWait: Double = 15      // an unanswered ask quietly goes away (nothing nudged)
        static let step = 0.1                   // how far each answer nudges Tidiness
        static let quiet = 0.15                 // below this, Pip stops asking
        static let start = 0.5
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
    }

    // MARK: Logic

    @MainActor @Observable final class Tidy {
        var asking = false
        var undoFor: String?                    // the card Pip just tidied, while it can still be put back
        var puff = 0                            // bumps to play the dust puff
        @ObservationIgnored var lastTouch = Date.now
        @ObservationIgnored var asked = 0
        @ObservationIgnored var askedAbout: String?
        @ObservationIgnored var watcher: TidyTouchWatch?
        @ObservationIgnored var loop: Task<Void, Never>?
    }
    private let tidy = Tidy()

    private func tidiness(_ host: PipHost) -> Double { (host.value("tidypip", "tidiness") as Double?) ?? Tune.start }

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
        guard !tidy.asking, tidy.undoFor == nil, tidy.asked < Tune.asksPerSession,
              (host.value("tidypip", "never") as Bool?) != true,
              let open = host.openCard, open != "tidypip", open != tidy.askedAbout else { return }
        let t = tidiness(host)
        guard t >= Tune.quiet, Date.now.timeIntervalSince(tidy.lastTouch) >= Tune.wait(t, joy: host.joy),
              PipTalkTurns.floorFree(host) else { return }
        PipTalkTurns.takeFloor(host, for: Tune.answerWait)
        tidy.asked += 1
        tidy.askedAbout = open
        withAnimation(.easeInOut(duration: 0.3)) { tidy.asking = true }
        host.react(.curious, for: 1.4)
        host.say(Lines.ask.randomElement()!, for: 3)
        let ask = tidy.asked
        host.later(Tune.answerWait) {
            guard tidy.asking, tidy.asked == ask else { return }
            withAnimation(.easeInOut(duration: 0.3)) { tidy.asking = false }
        }
    }

    enum Answer { case tidy, leave, never }

    fileprivate func answer(_ a: Answer, _ host: PipHost) {
        withAnimation(.easeInOut(duration: 0.3)) { tidy.asking = false }
        PipTalkTurns.takeFloor(host, for: 3)
        switch a {
        case .tidy:
            guard let id = host.openCard else { return }
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

    /// Pip flutters over, a puff of dust, and the card or panel is put away. "Put it back" works for 10 seconds.
    private func sweep(_ id: String, _ host: PipHost) {
        if !host.simpler, host.joy > 0, let at = target(host) { host.move(to: at) }
        host.later(host.simpler ? 0.2 : 0.7) {
            if host.joy > 0 { tidy.puff += 1 }
            withAnimation(.easeOut(duration: 0.25)) {
                host.openCard = nil
                tidy.undoFor = id
            }
            if host.joy >= 2 { host.cheer() }
            host.say(Lines.tidy.randomElement()!, for: 1.6)
            host.later(Tune.undoSeconds) {
                if tidy.undoFor == id { withAnimation(.easeInOut(duration: 0.3)) { tidy.undoFor = nil } }
            }
        }
    }

    fileprivate func putBack(_ host: PipHost) {
        guard let id = tidy.undoFor else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            host.openCard = id
            tidy.undoFor = nil
        }
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

    /// Just beside the open panel or card, in Pip's space, well inside the screen.
    private func target(_ host: PipHost) -> CGPoint? {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return nil }
        let inset = window.safeAreaInsets
        let frame = host.panelFrame.isNull ? host.cardFrame : host.panelFrame
        guard !frame.isNull else { return nil }
        let f = frame.offsetBy(dx: -inset.left, dy: -inset.top)
        let width = window.bounds.width - inset.left - inset.right
        let x = f.midX > width / 2 ? f.minX - 50 : f.maxX + 50
        return CGPoint(x: min(max(x, 140), width - 140), y: max(f.minY + 80, 140))
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
                    } else if tidy.undoFor != nil {
                        choice(spacing: 6) {
                            Button("Put it back") { plugin.putBack(host) }
                                .buttonStyle(PluginCardButton(on: true))
                                .accessibilityLabel("Put it back as it was")
                        }
                        .position(x: p.x, y: p.y + 70)
                        .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        private func choice<C: View>(spacing: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
            HStack(spacing: spacing) { content() }
                .padding(PluginBarLook.cardPadding)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PluginBarLook.radius))
                .fixedSize()
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

    func card(_ host: PipHost) -> some View { TidyCard(host: host) }

    struct TidyCard: View {
        let host: PipHost
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
