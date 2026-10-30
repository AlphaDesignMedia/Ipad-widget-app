import SwiftUI
import UIKit

// PIP'S WEIGHT · plugin v1 (Dream). Pip has weight and has to work to stay up. Each wingbeat lifts them and
// they sink in between, more as they tire. Flying and big moves tire Pip out; when tired they drift down to
// a ledge (the top of an open panel, or the bottom of the screen), sit, puff, get their breath back, stretch
// and hop up again. Pick Pip up and they dangle and sway under your finger, and like it: being carried is a
// rest. Put them down gently for a contented sigh; fling them and they come out dizzy.
// One pad sets it all: Feather ↔ Heavy (how hard staying up is), Sleepy ↔ Bouncy (how fast Pip tires and
// how lively they come back). Extreme for now (Aaron, 30 Oct 2026), to be dialled back until it feels natural.
// Where: the weight (scales) button in the plugin bar.

struct PipsWeight: SandboxPlugin {
    let info = PluginInfo(id: "weight", name: "Pip's Weight", version: "v1", shelf: .dream,
                          icon: "scalemass", what: "Pip works to stay up, gets tired, rests on ledges and likes being carried.")

    // MARK: Data

    /// Where the knob starts: heavy and sleepy, near the corner. Extreme on purpose for now.
    static let startDot = CGPoint(x: 0.72, y: 0.72)
    static let flapCycle = PipLook.flapSeconds * 2      // one full wingbeat, matching Pip's own wings

    enum Lines {
        static let tired = ["Phew. Wings are heavy.", "Need. A. Sit.", "Hold on, landing.", "Staying up is hard work."]
        static let rested = ["Right! Up we go.", "Better. Much better.", "Wings: recharged."]
        static let carried = ["Ooh, a lift!", "Carry me forever.", "No flapping needed. Lovely."]
        static let gentle = ["Ahh. Just there. Perfect.", "Mmm. Thank you.", "Nice and gentle."]
        static let flung = ["Whoa… the room's spinning.", "Again? Maybe not again.", "Which way's up?"]
        static let heavier = "Oof. Heavier."
        static let lighter = "Light as a feather!"
        static let sleepier = "So… sleepy…"
        static let bouncier = "Boing! Full of beans."
        static let natural = "Just me. Normal me."
    }

    /// The pad, read as plain numbers. x: -1 feather … 1 heavy. y: -1 bouncy (top) … 1 sleepy (bottom).
    struct Feel {
        var x: Double
        var y: Double
        var strength: Double { min(1, hypot(x, y)) }
        var heavy: Double { (x + 1) / 2 }             // 0 feather … 1 heavy
        var bouncy: Double { (1 - y) / 2 }            // 0 sleepy … 1 bouncy

        /// How far Pip sinks and lifts each wingbeat, in points, before tiredness adds to it.
        var bob: Double { 1.5 + strength * (2 + heavy * 13) }
        /// Tiredness gained per second in the air.
        var tirePerSecond: Double { 0.004 + strength * (0.006 + (1 - bouncy) * 0.05 + heavy * 0.015) }
        /// Tiredness per 100 points travelled.
        var movePer100: Double { strength * (0.01 + heavy * 0.04) }
        /// Tiredness lost per second sitting.
        var recoverPerSecond: Double { 0.05 + bouncy * 0.25 }
        /// How far Pip droops below where they were when worn out, in points.
        var droop: Double { strength * heavy * 18 }
    }

    // MARK: Logic

    static func feel(_ host: PipHost) -> Feel {
        Feel(x: host.value("weight", "x") ?? Double(startDot.x), y: host.value("weight", "y") ?? Double(startDot.y))
    }

    /// The live one-liner under the pad.
    static func readout(_ f: Feel) -> String {
        if f.strength < 0.15 { return "Natural: a gentle bob and the odd rest." }
        let weight = f.x > 0.35 ? "Heavy" : f.x < -0.35 ? "Feather-light" : "Middling"
        let pep = f.y > 0.35 ? "sleepy" : f.y < -0.35 ? "bouncy" : "steady"
        let means: String
        switch (f.x > 0.35 ? 1 : f.x < -0.35 ? -1 : 0, f.y > 0.35 ? 1 : f.y < -0.35 ? -1 : 0) {
        case (1, 1): means = "needs lots of rests"
        case (1, -1): means = "works hard, bounces back fast"
        case (1, _): means = "a big bob, rests now and then"
        case (-1, 1): means = "floats easily, naps anyway"
        case (-1, -1): means = "hardly tires at all"
        case (-1, _): means = "drifts about with no effort"
        case (_, 1): means = "tires quickly, slow to get going"
        case (_, -1): means = "lively, quick to recover"
        default: means = "a bit of effort, the odd rest"
        }
        return "\(weight) and \(pep): \(means)."
    }

    /// A zone name for the pad, so Pip only comments when the knob crosses into a new one.
    static func zone(_ f: Feel) -> String {
        if f.strength < 0.15 { return "natural" }
        return abs(f.x) >= abs(f.y) ? (f.x > 0 ? "heavier" : "lighter") : (f.y > 0 ? "sleepier" : "bouncier")
    }

    static func emote(_ emoji: String) {
        NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: emoji)
    }

    @MainActor final class Body {
        enum State { case flying, landing, resting, carried }
        var state = State.flying
        var tired = 0.0
        var feel = Feel(x: Double(PipsWeight.startDot.x), y: Double(PipsWeight.startDot.y))
        var lastPos = CGPoint.zero
        var lastTick = Date.now
        var stateSince = Date.now
        var releasedAt = Date.distantPast
        var flungAt = Date.distantPast
        var lastLine = Date.distantPast
        var lastZone = ""
        var touched = false              // we've changed hop/lean/squash and owe Pip a reset
        var loop: Task<Void, Never>?
    }
    private let body = Body()

    func start(_ host: PipHost) throws {
        body.feel = Self.feel(host)
        body.lastZone = Self.zone(body.feel)
        body.lastPos = host.pipPosition
        guard body.loop == nil else { return }
        body.loop = Task { @MainActor in
            while !Task.isCancelled {
                let active = tick(host)
                try? await Task.sleep(for: .milliseconds(active ? 16 : 500))
            }
        }
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .flick(let speed) where Date.now.timeIntervalSince(body.releasedAt) < 0.4:
            if speed > 900 { body.flungAt = .now }
        default: break
        }
    }

    /// Called from the card as the knob moves: Pip feels it straight away.
    fileprivate func setFeel(_ f: Feel, _ host: PipHost) {
        body.feel = f
        host.setValue(f.x, "weight", "x")
        host.setValue(f.y, "weight", "y")
        let z = Self.zone(f)
        guard z != body.lastZone else { return }
        body.lastZone = z
        switch z {
        case "heavier": host.say(Lines.heavier, for: 1.2); host.react(.surprised, for: 0.5)
        case "lighter": host.say(Lines.lighter, for: 1.2); host.cheer()
        case "sleepier": host.say(Lines.sleepier, for: 1.2); host.react(.sleepy, for: 1.4)
        case "bouncier": host.say(Lines.bouncier, for: 1.2); host.cheer()
        default: host.say(Lines.natural, for: 1.2)
        }
    }

    fileprivate func tireOut(_ host: PipHost) { body.tired = 1 }

    fileprivate var statusLine: String {
        let left = Int(((1 - body.tired) * 100).rounded())
        switch body.state {
        case .resting, .landing: return "Pip is resting. Energy \(left)%."
        case .carried: return "Pip is being carried, and resting. Energy \(left)%."
        case .flying: return "Pip is flying. Energy \(left)%."
        }
    }

    /// One frame. Returns whether anything is moving, so the loop can slow down when it isn't.
    private func tick(_ host: PipHost) -> Bool {
        let pip = host.pip
        let now = Date.now
        let dt = min(now.timeIntervalSince(body.lastTick), 0.1)
        body.lastTick = now
        guard host.isOn("weight"), host.pipHere, !pip.asleep else {
            relax(pip)
            body.lastPos = host.pipPosition
            return false
        }
        let f = body.feel
        let t = now.timeIntervalSinceReferenceDate
        let pos = host.pipPosition
        let moved = Double(hypot(pos.x - body.lastPos.x, pos.y - body.lastPos.y))
        let vx = dt > 0 ? Double(pos.x - body.lastPos.x) / dt : 0
        body.lastPos = pos

        // Picked up and put down.
        if pip.held, body.state != .carried { pickedUp(host) }
        if !pip.held, body.state == .carried { putDown(host) }

        switch body.state {
        case .carried:
            body.tired = max(0, body.tired - f.recoverPerSecond * 0.5 * dt)
            guard !host.simpler else { return true }
            // Dangling: the body lags behind the finger, then swings back, with a lazy sway on top.
            let swing = min(max(-vx / 40, -28), 28) * (0.4 + f.heavy)
            let sway = sin(t * 2.4) * 10 * f.strength
            pip.lean += (swing + sway - pip.lean) * min(1, 8 * dt)
            pip.hop = 0
            body.touched = true

        case .landing:
            body.tired = max(0, body.tired - f.recoverPerSecond * 0.3 * dt)
            if !host.simpler {
                pip.hop *= max(0, 1 - 6 * dt)
                body.touched = true
            }
            if now.timeIntervalSince(body.stateSince) > 1.1 { set(.resting) }

        case .resting:
            body.tired = max(0, body.tired - f.recoverPerSecond * dt)
            if !host.simpler {
                // Puffing: a slow squash and stretch, quicker while still out of breath.
                pip.hop = 0
                pip.squashAcross = false
                pip.squash = (0.04 + 0.06 * body.tired) * (0.5 + 0.5 * sin(t * (2 + 4 * body.tired))) * (0.5 + f.strength)
                body.touched = true
            }
            if body.tired < 0.12 { takeOff(host) }

        case .flying:
            body.tired = min(1, body.tired + f.tirePerSecond * dt + moved / 100 * f.movePer100)
            if !host.simpler, !pip.happy {
                // Lift on the downstroke, sink between: fast up, slow down. Heavier when tired.
                let phase = (t / PipsWeight.flapCycle).truncatingRemainder(dividingBy: 1)
                let lift = phase < 0.3 ? phase / 0.3 : 1 - (phase - 0.3) / 0.7
                let shaped = lift * lift * (3 - 2 * lift)
                let amp = f.bob * (1 + body.tired * 1.5)
                pip.hop = amp * (0.5 - shaped) + f.droop * body.tired * body.tired
                body.touched = true
            }
            if body.tired > 0.85, now.timeIntervalSince(body.stateSince) > 2 { land(host) }
        }
        return true
    }

    private func set(_ s: Body.State) {
        body.state = s
        body.stateSince = .now
    }

    /// Hands Pip's pose back to Pip's own code.
    private func relax(_ pip: PipModel) {
        guard body.touched else { return }
        body.touched = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            pip.hop = 0
            pip.lean = 0
            pip.squash = 0
        }
        if body.state != .flying { set(.flying) }
    }

    private func line(_ lines: [String], _ host: PipHost, for seconds: Double = 1.8, gap: Double = 3) {
        guard Date.now.timeIntervalSince(body.lastLine) > gap, let l = lines.randomElement() else { return }
        body.lastLine = .now
        host.say(l, for: seconds)
    }

    private func land(_ host: PipHost) {
        set(.landing)
        line(Lines.tired, host, gap: 0)
        host.react(.sleepy, for: 2)
        Self.emote("😮‍💨")
        host.move(to: seat(below: host.pipPosition, host))
        host.post(.custom("weight.tired"))
    }

    private func takeOff(_ host: PipHost) {
        set(.flying)
        let pip = host.pip
        if !host.simpler {
            // A stretch: tall and thin for a moment, then back.
            pip.squashAcross = true
            withAnimation(.easeOut(duration: 0.35)) { pip.squash = 0.18 * (0.5 + body.feel.strength) } completion: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { pip.squash = 0 }
            }
        }
        host.later(0.45) {
            line(Lines.rested, host, gap: 0)
            host.cheer()
            let p = host.pipPosition
            host.move(to: CGPoint(x: p.x, y: p.y - 90 - 80 * body.feel.bouncy))
            host.post(.custom("weight.rested"))
        }
    }

    private func pickedUp(_ host: PipHost) {
        set(.carried)
        Self.emote("🥰")
        line(Lines.carried, host, for: 1.6)
    }

    private func putDown(_ host: PipHost) {
        body.releasedAt = .now
        set(.flying)
        let pip = host.pip
        withAnimation(.spring(response: 0.5, dampingFraction: 0.3)) { pip.lean = 0 }
        // Wait a moment to hear whether that was a fling.
        host.later(0.35) {
            if Date.now.timeIntervalSince(body.flungAt) < 1 {
                host.react(.dizzy, for: 1.6)
                Self.emote("😵‍💫")
                line(Lines.flung, host, gap: 0)
                body.tired = min(1, body.tired + 0.1)
                return
            }
            line(Lines.gentle, host, gap: 0)
            Self.emote("😌")
            let p = host.pipPosition, s = seat(below: p, host)
            if s.y - p.y < 40 {
                // Left right by a ledge: sit down on it.
                host.move(to: s)
                set(.landing)
            } else if !host.simpler {
                // Left in mid-air: a drop, then flap to steady.
                withAnimation(.easeIn(duration: 0.18)) { pip.hop = 10 + 10 * body.feel.heavy } completion: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { pip.hop = 0 }
                }
            }
        }
    }

    /// Somewhere to sit under a point: the top of an open panel if Pip is above it, otherwise the bottom of the screen.
    private func seat(below p: CGPoint, _ host: PipHost) -> CGPoint {
        let r = host.pip.radius
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return CGPoint(x: p.x, y: p.y + 120) }
        let inset = window.safeAreaInsets
        let floor = window.bounds.height - inset.top - inset.bottom - r * 0.9
        var y = floor
        let panel = host.panelFrame.offsetBy(dx: -inset.left, dy: -inset.top)
        if !panel.isNull, panel.width > 60, p.x > panel.minX + r, p.x < panel.maxX - r, panel.minY > p.y {
            y = min(y, panel.minY - r * 0.9)
        }
        return CGPoint(x: p.x, y: max(y, p.y))
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { WeightCard(plugin: self, host: host) }

    struct WeightCard: View {
        let plugin: PipsWeight
        let host: PipHost
        @State private var dot = PipsWeight.startDot
        @State private var status = ""

        var body: some View {
            let f = Feel(x: Double(dot.x), y: Double(dot.y))
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Pad(dot: $dot)
                    .frame(width: 220, height: 220)
                    .frame(maxWidth: .infinity)
                Text(PipsWeight.readout(f)).bold()
                    .accessibilityHidden(true)
                Text(status).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Back to natural") { dot = .zero }
                        .buttonStyle(PluginCardButton())
                        .accessibilityHint("Puts the knob in the middle: a gentle bob and the odd rest.")
                    Button("Tire Pip out") { plugin.tireOut(host) }
                        .buttonStyle(PluginCardButton())
                        .disabled(!host.pipHere)
                        .accessibilityHint("Pip uses up their energy and goes to find a ledge to rest on.")
                }
                Text("Drag Pip to pick them up. Let go gently by a ledge and they'll sit on it.")
                    .foregroundStyle(.secondary)
                if !host.pipHere {
                    Text("Pip is switched off, so nothing here changes anything.").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13.5))
            .onAppear {
                let f = PipsWeight.feel(host)
                dot = CGPoint(x: f.x, y: f.y)
                status = plugin.statusLine
            }
            .onChange(of: dot) { _, d in plugin.setFeel(Feel(x: Double(d.x), y: Double(d.y)), host) }
            .task {
                while !Task.isCancelled {
                    status = plugin.statusLine
                    try? await Task.sleep(for: .seconds(0.5))
                }
            }
        }
    }

    /// The pad: Helper Dial's round dial and knob, with a plain word at each edge.
    struct Pad: View {
        @Binding var dot: CGPoint

        var body: some View {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let r = side / 2 - 26
                let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    Circle().fill(Color.primary.opacity(0.06)).frame(width: r * 2, height: r * 2)
                    Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1).frame(width: r * 0.3, height: r * 0.3)
                    edge("Bouncy", at: CGPoint(x: centre.x, y: centre.y - r - 14))
                    edge("Sleepy", at: CGPoint(x: centre.x, y: centre.y + r + 14))
                    edge("Feather", at: CGPoint(x: centre.x - r + 30, y: centre.y))
                    edge("Heavy", at: CGPoint(x: centre.x + r - 26, y: centre.y))
                    Circle().fill(PipLook.accent)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: PipLook.accent.opacity(0.5), radius: 6)
                        .position(x: centre.x + dot.x * r, y: centre.y + dot.y * r)
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    var v = CGPoint(x: (g.location.x - centre.x) / r, y: (g.location.y - centre.y) / r)
                    let len = hypot(v.x, v.y)
                    if len > 1 { v = CGPoint(x: v.x / len, y: v.y / len) }
                    dot = v
                })
            }
            .accessibilityElement()
            .accessibilityLabel("Pip's weight pad")
            .accessibilityValue(PipsWeight.readout(Feel(x: Double(dot.x), y: Double(dot.y))))
            .accessibilityHint("Left is feather, right is heavy. Up is bouncy, down is sleepy. Use the actions to move it.")
            .accessibilityAction(named: "Heavier") { nudge(dx: 0.25, dy: 0) }
            .accessibilityAction(named: "Lighter") { nudge(dx: -0.25, dy: 0) }
            .accessibilityAction(named: "Bouncier") { nudge(dx: 0, dy: -0.25) }
            .accessibilityAction(named: "Sleepier") { nudge(dx: 0, dy: 0.25) }
        }

        private func edge(_ word: String, at p: CGPoint) -> some View {
            Text(word)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .position(p)
                .accessibilityHidden(true)
        }

        private func nudge(dx: Double, dy: Double) {
            var v = CGPoint(x: dot.x + dx, y: dot.y + dy)
            let len = hypot(v.x, v.y)
            if len > 1 { v = CGPoint(x: v.x / len, y: v.y / len) }
            dot = v
        }
    }
}
