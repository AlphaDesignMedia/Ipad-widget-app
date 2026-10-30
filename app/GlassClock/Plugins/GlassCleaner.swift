import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// WINDOW CLEANER PIP · plugin v1 (Dream). Now and then, while a card or panel is open and you've stopped touching
// the screen, Pip drifts behind it and cleans the glass: you see them softly through it, wiping in little circles,
// a few dust motes puff and fall, then a shine sweeps across and Pip goes back where they were. Silent, bar the odd
// tiny "squeak". Any touch, or the Pencil coming near, stops it at once.
// How often follows Joy: never at 0, rare at 1 (about once every 10 idle minutes), often at 5.
// The clean team: if it's a mess (a card or panel open over lots of drawing), once a session Pip whistles and a tiny
// crew pops in for a few seconds: a little round robot with a mop, and Bendy, a cheerful bent-wire helper. They dust,
// wave and leave. Talk goes through PipTalkTurns.
// Simpler motion: just a shine that fades in and out, nothing moves. Pip off (or asleep): just a faint shine now and
// then; the glass gets cleaned, no Pip.
// Behind the glass is real for plugin cards and panels (the plugin bar draws over Pip). Pip can't be made smaller or
// dimmer from a plugin yet: asked of the core.
// Where: the bubbles button in the plugin bar.

struct GlassCleaner: SandboxPlugin {
    let info = PluginInfo(id: "glass", name: "Window Cleaner Pip", version: "v1", shelf: .dream,
                          icon: "bubbles.and.sparkles", what: "Now and then Pip cleans the glass behind your panels.")

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        static let tick = 3.0                   // seconds between checks
        static let wipeSeconds = 2.4            // how long Pip wipes in circles
        static let wipeStep = 0.05              // seconds between cloth points
        static let circle: CGFloat = 12         // the cloth circle's size
        static let shineSeconds = 0.9
        static let faint = 0.22                 // the shine with Pip off
        static let bright = 0.5                 // the shine with Pip
        static let floor = 7.0                  // seconds Pip is busy cleaning
        static let teamSeconds = 4.6            // how long the clean team stays
        static let teamWave = 2.8               // when they stop dusting and wave
        static let messInk = 10                 // strokes on screen, with something open, that count as a mess
        static let squeakChance = 0.3
        static let minWidth: CGFloat = 200      // a tucked-away panel is just its edge: leave it
        /// Idle seconds before a clean, by Joy level (0: never on its own).
        static func idle(joy: Int) -> Double { [Double.infinity, 600, 300, 170, 100, 50][min(max(joy, 0), 5)] }
        /// Dust motes in a puff, by Joy level.
        static func motes(joy: Int) -> Int { [3, 4, 5, 7, 9, 11][min(max(joy, 0), 5)] }
    }

    // MARK: Data

    enum Lines {
        static let tiny = ["squeak", "✨", "squeak squeak"]
        static let whistle = "♪ Fweet!"
        static let thanks = ["Thanks, team!", "Lovely. Sparkling.", "Cheers, both!"]
    }

    enum Often {
        static func label(joy: Int) -> String {
            ["Never on their own (Joy is at 0).",
             "Rarely: about once every 10 minutes you're idle.",
             "Now and then: about every 5 idle minutes.",
             "Every few idle minutes.",
             "Often: every couple of idle minutes.",
             "Very often: about every minute you're idle."][min(max(joy, 0), 5)]
        }
    }

    /// A little puff of dust that falls and fades.
    struct Puff: Identifiable { let id: Int; let at: CGPoint; let count: Int }

    // MARK: Logic

    @MainActor @Observable final class Wipe {
        var pane: CGRect?                       // the glass being cleaned (Pip's space)
        var wiping = false                      // Pip's cloth is out
        var shineID = 0                         // bumps to play the shine
        var shining = false
        var still = false                       // fade only
        var faint = false                       // no Pip: a faint shine
        var puffs: [Puff] = []
        var team: CGPoint?                      // where the clean team stands while they visit
        var waving = false
        @ObservationIgnored var puffID = 0
        @ObservationIgnored var lastTouch = Date.now
        @ObservationIgnored var lastClean = Date.now
        @ObservationIgnored var home: CGPoint?  // where Pip was before cleaning
        @ObservationIgnored var teamCame = false
        @ObservationIgnored var watcher: GlassTouchWatch?
        @ObservationIgnored var loop: Task<Void, Never>?
        @ObservationIgnored var job: Task<Void, Never>?
        var busy: Bool { job != nil }
    }
    private let wipe = Wipe()

    private func wanted(_ host: PipHost) -> Bool { (host.value("glass", "on") as Bool?) ?? true }
    private func teamWanted(_ host: PipHost) -> Bool { (host.value("glass", "team") as Bool?) ?? true }
    private func running(_ host: PipHost) -> Bool { host.isOn("glass") && wanted(host) }

    func start(_ host: PipHost) throws {
        wipe.lastClean = .now
        wake(host)
    }

    /// Runs the 3-second check only while the plugin and its card switch are on; it ends itself (and stops
    /// listening for touches) when either goes off. Switching on calls `start`, and the card's switch calls this.
    fileprivate func wake(_ host: PipHost) {
        guard wipe.loop == nil, running(host) else { return }
        wipe.loop = Task { @MainActor in
            while !Task.isCancelled, running(host) {
                install(host)
                tick(host)
                try? await Task.sleep(for: .seconds(Tune.tick))
            }
            stop(host)
            if let w = wipe.watcher { w.view?.removeGestureRecognizer(w) }
            wipe.watcher = nil
            wipe.loop = nil
        }
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        // The Pencil near the screen, or Pip picked up: hands off at once.
        switch event {
        case .ink(.pencil), .ink(.drew), .ink(.erased), .tap, .flick: touched(host)
        default: break
        }
    }

    private func touched(_ host: PipHost) {
        wipe.lastTouch = .now
        if wipe.busy { stop(host) }
    }

    private func tick(_ host: PipHost) {
        guard !wipe.busy, host.joy > 0, let pane = openPane(host) else { return }
        let now = Date.now
        let idle = min(now.timeIntervalSince(wipe.lastTouch), now.timeIntervalSince(wipe.lastClean))
        guard idle >= Tune.idle(joy: host.joy) else { return }
        if !wipe.teamCame, teamWanted(host), messy(host), pipFree(host), PipTalkTurns.floorFree(host) {
            callTeam(host, pane)
        } else {
            clean(host, pane, byHand: false)
        }
    }

    /// Pip is on screen, awake and free to move about.
    private func pipFree(_ host: PipHost) -> Bool { host.pipHere && !host.pipAsleep && !host.pip.held }

    /// A card or panel open over lots of drawing. (The host can only say one plugin card or panel is open.)
    private func messy(_ host: PipHost) -> Bool {
        host.openCard != nil && host.isOn("sketch") && Sketch.strokeCount >= Tune.messInk
    }

    /// Pip cleans the glass. With Pip away, asleep, at Joy 0 or under simpler motion: just the shine.
    fileprivate func clean(_ host: PipHost, _ pane: CGRect, byHand: Bool) {
        stop(host)
        wipe.lastClean = .now
        let withPip = pipFree(host) && !host.simpler && host.joy > 0 && (byHand || PipTalkTurns.floorFree(host))
        wipe.still = host.simpler
        wipe.faint = !host.pipHere
        withAnimation(.easeInOut(duration: 0.3)) { wipe.pane = pane }
        wipe.job = Task { @MainActor in
            // Glass Memory listens for this and wipes Pip's marks (only when a clean ran to the end).
            defer { if !Task.isCancelled { finish(host); host.post(.custom("glass.cleaned")) } }
            guard withPip else {
                shine()
                try? await Task.sleep(for: .seconds(Tune.shineSeconds + 0.6))
                return
            }
            PipTalkTurns.takeFloor(host, for: Tune.floor)
            wipe.home = host.pipPosition
            let from = CGPoint(x: pane.minX + pane.width * 0.3, y: pane.minY + min(pane.height * 0.35, 160))
            host.move(to: from)
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            // Little circles, drifting across the glass.
            withAnimation(.easeOut(duration: 0.2)) { wipe.wiping = true }
            let steps = Int(Tune.wipeSeconds / Tune.wipeStep)
            for i in 0..<steps {
                guard !Task.isCancelled else { return }
                let t = CGFloat(i) / CGFloat(steps)
                let a = Double(i) * 0.45
                host.follow(CGPoint(x: from.x + pane.width * 0.4 * t + CGFloat(cos(a)) * Tune.circle,
                                    y: from.y + CGFloat(sin(a)) * Tune.circle * 0.7))
                if i % 16 == 8 { puff(at: host.pipPosition, host) }
                try? await Task.sleep(for: .seconds(Tune.wipeStep))
            }
            withAnimation(.easeIn(duration: 0.2)) { wipe.wiping = false }
            shine()
            if Double.random(in: 0..<1) < Tune.squeakChance { host.say(Lines.tiny.randomElement()!, for: 1.1) }
            try? await Task.sleep(for: .seconds(Tune.shineSeconds + 0.4))
        }
    }

    /// Once a session, for a mess: Pip whistles, the clean team pops in, dusts, waves and leaves.
    fileprivate func callTeam(_ host: PipHost, _ pane: CGRect) {
        guard pipFree(host) else { return }
        stop(host)
        wipe.teamCame = true
        wipe.lastClean = .now
        wipe.still = host.simpler
        wipe.faint = false
        PipTalkTurns.takeFloor(host, for: Tune.teamSeconds + 3)
        host.say(Lines.whistle, for: 1.4)
        let spot = teamSpot(pane, host)
        wipe.job = Task { @MainActor in
            defer { if !Task.isCancelled { finish(host) } }
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            withAnimation(host.simpler ? .easeInOut(duration: 0.4) : .spring(duration: 0.5, bounce: 0.4)) {
                wipe.pane = pane
                wipe.team = spot
            }
            for i in 0..<3 {
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                puff(at: CGPoint(x: spot.x + CGFloat(i - 1) * 22, y: spot.y - 6), host)
            }
            try? await Task.sleep(for: .seconds(Tune.teamWave - 2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { wipe.waving = true }
            shine()
            try? await Task.sleep(for: .seconds(Tune.teamSeconds - Tune.teamWave))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) { wipe.team = nil; wipe.waving = false }
            try? await Task.sleep(for: .seconds(0.6))
            host.say(Lines.thanks.randomElement()!, for: 2)
            host.cheer()
            host.post(.custom("glass.cleaned"))
        }
    }

    /// Stops whatever's going on, at once: things fade, and Pip glides back where they were.
    fileprivate func stop(_ host: PipHost) {
        wipe.job?.cancel()
        finish(host)
    }

    private func finish(_ host: PipHost) {
        wipe.job = nil
        withAnimation(.easeOut(duration: 0.2)) {
            wipe.pane = nil
            wipe.wiping = false
            wipe.shining = false
            wipe.team = nil
            wipe.waving = false
        }
        if let home = wipe.home, host.pipHere, !host.pip.held { host.move(to: home) }
        wipe.home = nil
    }

    private func shine() {
        wipe.shineID += 1
        wipe.shining = true
    }

    private func puff(at p: CGPoint, _ host: PipHost) {
        wipe.puffID += 1
        let puff = Puff(id: wipe.puffID, at: p, count: Tune.motes(joy: host.joy))
        wipe.puffs.append(puff)
        host.later(1.6) { wipe.puffs.removeAll { $0.id == puff.id } }
    }

    /// The open panel, or else the open card, in Pip's space. Nil when nothing's open (or the panel's tucked aside).
    fileprivate func openPane(_ host: PipHost) -> CGRect? {
        guard host.openCard != nil, let window = keyWindow() else { return nil }
        let frame = host.panelFrame.isNull ? host.cardFrame : host.panelFrame
        guard !frame.isNull, frame.width >= Tune.minWidth else { return nil }
        return frame.offsetBy(dx: -window.safeAreaInsets.left, dy: -window.safeAreaInsets.top)
    }

    /// Just beside the glass, low down, on the side nearer the middle of the screen.
    private func teamSpot(_ pane: CGRect, _ host: PipHost) -> CGPoint {
        let width = keyWindow().map { $0.bounds.width - $0.safeAreaInsets.left - $0.safeAreaInsets.right } ?? 1180
        let x = pane.midX > width / 2 ? pane.minX - 70 : pane.maxX + 70
        return CGPoint(x: min(max(x, 70), width - 70), y: max(pane.maxY - 50, pane.minY + 60))
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
    }

    private func install(_ host: PipHost) {
        guard wipe.watcher == nil, let window = keyWindow() else { return }
        let watch = GlassTouchWatch()
        watch.onTouch = { touched(host) }
        window.addGestureRecognizer(watch)
        wipe.watcher = watch
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { GlassOverlay(wipe: wipe, host: host) }

    /// Drawn under the plugin bar's cards and panels, so it's all seen through the glass.
    struct GlassOverlay: View {
        let wipe: Wipe
        let host: PipHost

        var body: some View {
            ZStack(alignment: .topLeading) {
                if let pane = wipe.pane, wipe.shining {
                    Shine(still: wipe.still, strength: wipe.faint ? Tune.faint : Tune.bright)
                        .frame(width: pane.width, height: pane.height)
                        .clipShape(RoundedRectangle(cornerRadius: PluginBarLook.radius))
                        .position(x: pane.midX, y: pane.midY)
                        .id(wipe.shineID)
                        .accessibilityHidden(true)
                }
                if wipe.wiping, host.pipHere {
                    let p = host.pipPosition
                    Cloth()
                        .position(x: p.x + 10, y: p.y + 12)
                        .accessibilityHidden(true)
                }
                ForEach(wipe.puffs) { puff in
                    Motes(count: puff.count, still: host.simpler)
                        .position(puff.at)
                        .accessibilityHidden(true)
                }
                if let spot = wipe.team {
                    CleanTeam(waving: wipe.waving, still: host.simpler)
                        .position(spot)
                        .transition(host.simpler ? .opacity : .opacity.combined(with: .scale(scale: 0.4)))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("The clean team: a little round robot with a mop, and Bendy, a bent-wire helper, dusting the glass")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    /// A soft band of light that sweeps across the glass (simpler motion: it fades in and out where it is).
    struct Shine: View {
        let still: Bool
        let strength: Double
        @State private var on = false

        var body: some View {
            GeometryReader { g in
                let w = g.size.width
                LinearGradient(colors: [.white.opacity(0), .white.opacity(strength), .white.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: max(w * 0.35, 60), height: g.size.height * 1.6)
                    .rotationEffect(.degrees(18))
                    .position(x: still ? w / 2 : (on ? w * 1.3 : -w * 0.3), y: g.size.height / 2)
                    .opacity(still ? (on ? 1 : 0) : 1)
            }
            .onAppear {
                if still {
                    withAnimation(.easeInOut(duration: GlassCleaner.Tune.shineSeconds / 2).repeatCount(2, autoreverses: true)) { on = true }
                } else {
                    withAnimation(.easeInOut(duration: GlassCleaner.Tune.shineSeconds)) { on = true }
                }
            }
        }
    }

    /// Pip's cloth: a little soft square that goes round with Pip.
    struct Cloth: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 3)
                .fill(PipLook.orbLight.opacity(0.85))
                .frame(width: 11, height: 9)
                .rotationEffect(.degrees(12))
                .shadow(color: PipLook.glow, radius: 3)
        }
    }

    /// A few specks of dust that puff out, then fall and fade (simpler motion: they only fade).
    struct Motes: View {
        let count: Int
        let still: Bool
        @State private var out = false
        @State private var gone = false

        var body: some View {
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let spread = (CGFloat(i) / CGFloat(max(count - 1, 1)) - 0.5) * 2
                    Circle()
                        .fill(PipLook.glow)
                        .frame(width: i % 3 == 0 ? 4 : 2.5, height: i % 3 == 0 ? 4 : 2.5)
                        .offset(x: out && !still ? spread * 16 : 0,
                                y: out && !still ? 30 + CGFloat(i % 3) * 8 : 0)
                }
            }
            .opacity(gone ? 0 : 0.9)
            .onAppear {
                withAnimation(.easeIn(duration: 1.3)) { out = true }
                withAnimation(.easeIn(duration: 0.6).delay(0.8)) { gone = true }
            }
        }
    }

    /// The clean team: a little round robot with a mop, and Bendy, a bent bit of wire with a loop for a head.
    struct CleanTeam: View {
        let waving: Bool
        let still: Bool
        @State private var mop = false

        var body: some View {
            HStack(alignment: .bottom, spacing: 14) {
                MopBot()
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(still ? 0 : (mop ? 8 : -8)), anchor: .bottom)
                Bendy(waving: waving && !still)
                    .frame(width: 26, height: 42)
            }
            .onAppear {
                guard !still else { return }
                withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) { mop = true }
            }
        }
    }

    /// A round robot body, two dot eyes and a little antenna, with a mop held out to the side.
    struct MopBot: View {
        var body: some View {
            Canvas { ctx, size in
                let s = size.width
                let body = CGRect(x: s * 0.05, y: s * 0.3, width: s * 0.55, height: s * 0.55)
                // Antenna.
                var ant = Path()
                ant.move(to: CGPoint(x: body.midX, y: body.minY))
                ant.addLine(to: CGPoint(x: body.midX, y: body.minY - s * 0.12))
                ctx.stroke(ant, with: .color(PipLook.accent), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: body.midX - 2, y: body.minY - s * 0.12 - 3, width: 4, height: 4)),
                         with: .color(PipLook.glow))
                // Body and eyes.
                ctx.fill(Path(ellipseIn: body), with: .color(PipLook.orbLight))
                ctx.stroke(Path(ellipseIn: body), with: .color(PipLook.accent), lineWidth: 1.5)
                for dx in [CGFloat(-0.1), 0.1] {
                    ctx.fill(Path(ellipseIn: CGRect(x: body.midX + s * dx - 2, y: body.midY - 3, width: 4, height: 4)),
                             with: .color(PipLook.eye))
                }
                // Mop: a stick down to the floor, and a fringe.
                var stick = Path()
                stick.move(to: CGPoint(x: body.maxX - 2, y: body.midY))
                stick.addLine(to: CGPoint(x: s * 0.88, y: s * 0.92))
                ctx.stroke(stick, with: .color(PipLook.eye.opacity(0.7)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                var fringe = Path()
                for i in 0..<5 {
                    let x = s * 0.78 + CGFloat(i) * s * 0.05
                    fringe.move(to: CGPoint(x: s * 0.88, y: s * 0.9))
                    fringe.addLine(to: CGPoint(x: x, y: s))
                }
                ctx.stroke(fringe, with: .color(PipLook.glow), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }
    }

    /// Bendy: one cheerful bent wire. A round loop for a head with two dot eyes, a zig-zag body, little wire feet,
    /// and an arm that waves.
    struct Bendy: View {
        let waving: Bool
        @State private var up = false

        var body: some View {
            ZStack {
                Canvas { ctx, size in
                    let w = size.width, h = size.height
                    let wire = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    let head = CGRect(x: w * 0.25, y: 0, width: w * 0.5, height: w * 0.5)
                    ctx.stroke(Path(ellipseIn: head), with: .color(PipLook.accent), style: wire)
                    for dx in [CGFloat(-0.09), 0.09] {
                        ctx.fill(Path(ellipseIn: CGRect(x: head.midX + w * dx - 1.5, y: head.midY - 1.5, width: 3, height: 3)),
                                 with: .color(PipLook.eye))
                    }
                    var body = Path()
                    body.move(to: CGPoint(x: head.midX, y: head.maxY))
                    body.addLine(to: CGPoint(x: w * 0.35, y: h * 0.45))
                    body.addLine(to: CGPoint(x: w * 0.65, y: h * 0.58))
                    body.addLine(to: CGPoint(x: w * 0.35, y: h * 0.71))
                    body.addLine(to: CGPoint(x: w * 0.5, y: h * 0.82))
                    // Feet.
                    body.addLine(to: CGPoint(x: w * 0.3, y: h))
                    body.move(to: CGPoint(x: w * 0.5, y: h * 0.82))
                    body.addLine(to: CGPoint(x: w * 0.72, y: h))
                    ctx.stroke(body, with: .color(PipLook.accent), style: wire)
                }
                // The waving arm.
                Capsule()
                    .fill(PipLook.accent)
                    .frame(width: 2, height: 11)
                    .offset(y: -5.5)
                    .rotationEffect(.degrees(waving ? (up ? -55 : -15) : 35), anchor: .bottom)
                    .offset(x: 6, y: 1)
            }
            .onChange(of: waving) {
                guard waving else { up = false; return }
                withAnimation(.easeInOut(duration: 0.25).repeatCount(5, autoreverses: true)) { up = true }
            }
        }
    }

    func card(_ host: PipHost) -> some View { GlassCard(plugin: self, host: host) }

    struct GlassCard: View {
        let plugin: GlassCleaner
        let host: PipHost
        @AppStorage("plug.glass.on") private var on = true
        @AppStorage("plug.glass.team") private var team = true

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Toggle("Pip cleans the glass", isOn: $on)
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let Pip clean the glass now and then")
                    .onChange(of: on) { if on { plugin.wake(host) } else { plugin.stop(host) } }
                VStack(alignment: .leading, spacing: 2) {
                    Text("How often").font(.system(size: 13.5))
                    Text(Often.label(joy: host.joy)).font(.system(size: 13.5)).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint("This follows Pip's Joy setting.")
                Toggle("Clean team may visit", isOn: $team)
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let the clean team visit once if things get messy")
                HStack(spacing: PluginBarLook.cardGap) {
                    Button("Clean now") {
                        if let pane = plugin.openPane(host) { plugin.clean(host, pane, byHand: true) }
                    }
                    .buttonStyle(PluginCardButton(on: true))
                    .accessibilityLabel("Clean the glass now")
                    Button("Call the team") {
                        if let pane = plugin.openPane(host) { plugin.callTeam(host, pane) }
                    }
                    .buttonStyle(PluginCardButton())
                    .disabled(!host.pipHere || !team)
                    .accessibilityLabel("Call the clean team now")
                }
                Text("Only while you're not touching the screen; any touch stops it. Pip off: just a faint shine now and then.")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Hears every touch on the window and lets it through untouched. It never recognises, so it never gets in the way.
final class GlassTouchWatch: UIGestureRecognizer, UIGestureRecognizerDelegate {
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
