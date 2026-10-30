import SwiftUI
import UIKit

// PIP'S WEIGHT · plugin v1.1 (Dream). Pip is a floating fairy: buoyancy carries their weight, and the wings are
// the effort for moving and climbing. Hovering costs almost nothing; a soft bob rides on it. Every change in
// height or tilt eases through a gentle spring, never a snap. Tiredness builds slowly: a little lower, a slower
// drift, the odd big wingbeat to catch themselves, then a rest on a ledge (the top of an open panel) or, if
// there's none nearby, on a little seat Pip brings, well away from the screen's corners and edges. They puff,
// get their breath back, stretch and float up again. Pick Pip up and they dangle and sway under your finger, and like it: being carried is a
// rest. Put them down gently for a contented sigh; fling them and they come out dizzy.
// One pad sets it all: Feather ↔ Heavy (how hard staying up is), Sleepy ↔ Bouncy (how fast Pip tires and
// how lively they come back). v1.1 (Aaron, 30 Oct 2026): natural in the middle is subtle (bob about 2.5 pt
// every 1.2 s, a tilt of about 1.5°); the far edge is about 2.5× that, no more.
// Where: the weight (scales) button in the plugin bar.

struct PipsWeight: SandboxPlugin {
    let info = PluginInfo(id: "weight", name: "Pip's Weight", version: "v1.1", shelf: .dream,
                          icon: "scalemass", what: "Pip works to stay up, gets tired, rests on ledges and likes being carried.")

    // MARK: Data

    /// Where the knob starts: natural, a touch toward Heavy.
    static let startDot = CGPoint(x: 0.25, y: 0.1)
    /// Settings are saved under new names in v1.1, so v1's extreme corner doesn't carry over.
    static let keyX = "x2", keyY = "y2"
    /// Pip's floating spring: a soft, slightly underdamped settle (seconds per swing, damping ratio).
    static let floatSpring = (period: 0.9, damping: 0.72)
    /// The dangle while carried: a little looser.
    static let dangleSpring = (period: 1.1, damping: 0.55)
    /// How far inside the safe area a landing spot must be, so Pip never ends up in a corner or under an edge.
    static let edgeMargin: CGFloat = 140
    static let seatLift: CGFloat = 170                // the seat's height above the bottom of the safe area

    enum Lines {
        static let tired = ["Phew. Time for a sit.", "Wings need a rest.", "Just going to perch a moment.", "A little sit, I think."]
        static let rested = ["Right. Up we float.", "Better. Much better.", "Wings: recharged."]
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

        /// The floating bob, in points either way: 2.5 natural, about 6 at the heavy edge.
        var bob: Double { 2.5 * (1 + strength * (0.4 + heavy * 1.1)) }
        /// Seconds per bob: 1.2 natural, a little slower when heavy.
        var period: Double { 1.2 * (1 + strength * heavy * 0.3) }
        /// The hovering tilt, in degrees either way: 1.5 natural, about 4 at the edge.
        var tilt: Double { 1.5 * (1 + strength * 1.6) }
        /// Tiredness gained per second in the air: about 7 minutes to tired at natural, under a minute at heavy + sleepy.
        var tirePerSecond: Double { 0.002 + strength * (0.002 + (1 - bouncy) * 0.012 + heavy * 0.006) }
        /// Tiredness per 100 points travelled: moving and climbing are where the wings work.
        var movePer100: Double { 0.003 + strength * heavy * 0.012 }
        /// Tiredness lost per second sitting.
        var recoverPerSecond: Double { 0.04 + bouncy * 0.12 }
        /// How far Pip sags when worn out, in points.
        var droop: Double { 3 + strength * heavy * 6 }
    }

    // MARK: Logic

    static func feel(_ host: PipHost) -> Feel {
        Feel(x: host.value("weight", keyX) ?? Double(startDot.x), y: host.value("weight", keyY) ?? Double(startDot.y))
    }

    /// The live one-liner under the pad.
    static func readout(_ f: Feel) -> String {
        if f.strength < 0.15 { return "Natural: floats easily, a soft bob, the odd rest." }
        let weight = f.x > 0.35 ? "Heavy" : f.x < -0.35 ? "Feather-light" : "Middling"
        let pep = f.y > 0.35 ? "sleepy" : f.y < -0.35 ? "bouncy" : "steady"
        let means: String
        switch (f.x > 0.35 ? 1 : f.x < -0.35 ? -1 : 0, f.y > 0.35 ? 1 : f.y < -0.35 ? -1 : 0) {
        case (1, 1): means = "wings work harder, rests more often"
        case (1, -1): means = "works harder, bounces back fast"
        case (1, _): means = "a deeper bob, rests now and then"
        case (-1, 1): means = "floats easily, naps anyway"
        case (-1, -1): means = "hardly tires at all"
        case (-1, _): means = "drifts about with no effort"
        case (_, 1): means = "tires a little sooner, slow to get going"
        case (_, -1): means = "lively, quick to recover"
        default: means = "floats easily, the odd rest"
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

    /// A soft spring for one number. Steps in small slices so a slow frame can't make it jump.
    struct Spring {
        var x = 0.0
        var v = 0.0
        mutating func step(to target: Double, _ dt: Double, period: Double, damping: Double) {
            let w = 2 * Double.pi / period
            var left = dt
            while left > 0 {
                let h = min(left, 1.0 / 120)
                v += (w * w * (target - x) - 2 * damping * w * v) * h
                x += v * h
                left -= h
            }
        }
    }

    /// The little seat Pip brings when there's no ledge nearby. Drawn by the overlay.
    @MainActor @Observable final class Seat {
        var at = CGPoint.zero
        var shown = false
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
        var hop = Spring()
        var lean = Spring()
        var restAt = CGPoint.zero
        var nextCatch = Date.distantPast
        var noLandUntil = Date.distantPast
        var loop: Task<Void, Never>?
    }
    private let body = Body()
    private let seatState = Seat()

    func start(_ host: PipHost) throws {
        body.feel = Self.feel(host)
        body.lastZone = Self.zone(body.feel)
        body.lastPos = host.pipPosition
        guard body.loop == nil else { return }
        // Ends itself when Pip's Weight is switched off (Pip settles back first); switching it on calls `start` again.
        body.loop = Task { @MainActor in
            while !Task.isCancelled, host.isOn("weight") {
                let active = tick(host)
                try? await Task.sleep(for: .milliseconds(active ? 16 : 500))
            }
            relax(host.pip)
            body.loop = nil
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
        host.setValue(f.x, "weight", Self.keyX)
        host.setValue(f.y, "weight", Self.keyY)
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
    /// Everything Pip's body does goes through the two springs, so nothing ever snaps.
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
        let speed = dt > 0 ? moved / dt : 0
        body.lastPos = pos

        // Picked up and put down.
        if pip.held, body.state != .carried { pickedUp(host) }
        if !pip.held, body.state == .carried { putDown(host) }

        var hopTarget = 0.0
        var leanTarget = 0.0
        var spring = Self.floatSpring
        // Pip's own code tilts them into a move; while they're moving, the tilt is theirs.
        var ownsLean = speed < 30

        switch body.state {
        case .carried:
            body.tired = max(0, body.tired - f.recoverPerSecond * 0.5 * dt)
            // Dangling: the body trails the finger a little and sways lazily.
            spring = Self.dangleSpring
            leanTarget = min(max(-vx / 60, -10), 10) * (0.5 + f.heavy * 0.5) + sin(t * 1.8) * f.tilt
            ownsLean = true

        case .landing:
            body.tired = max(0, body.tired - f.recoverPerSecond * 0.3 * dt)
            if now.timeIntervalSince(body.stateSince) > 1.4 {
                set(.resting)
                body.restAt = pos
            }

        case .resting:
            body.tired = max(0, body.tired - f.recoverPerSecond * dt)
            if hypot(pos.x - body.restAt.x, pos.y - body.restAt.y) > 24 {
                // Something else moved Pip (a follow, a drag): let them go, don't fight it.
                set(.flying)
                body.noLandUntil = now.addingTimeInterval(8)
                hideSeat(host, after: 0.2)
            } else {
                if !host.simpler {
                    // Puffing: a slow, small breath, quicker while still out of breath.
                    pip.squashAcross = false
                    pip.squash = (0.02 + 0.03 * body.tired) * (0.5 + 0.5 * sin(t * (1.5 + 2 * body.tired)))
                    body.touched = true
                }
                if body.tired < 0.12 { takeOff(host) }
            }

        case .flying:
            body.tired = min(1, body.tired + f.tirePerSecond * dt + moved / 100 * f.movePer100)
            let weary = body.tired * body.tired
            // Floating: a gentle sine, a little deeper and slower as they tire, and a small sag.
            let period = f.period * (1 + 0.25 * body.tired)
            hopTarget = f.bob * (1 + 0.4 * body.tired) * sin(2 * .pi * t / period) + f.droop * weary
            leanTarget = sin(2 * .pi * t / (period * 2.3)) * f.tilt
            // Now and then, a big wingbeat to catch themselves.
            if body.tired > 0.5, now > body.nextCatch {
                body.hop.v -= 18 * (0.6 + f.heavy * 0.4)
                body.nextCatch = now.addingTimeInterval(Double.random(in: 4...8) / body.tired)
            }
            if body.tired > 0.85, now > body.noLandUntil, now.timeIntervalSince(body.stateSince) > 2 { land(host) }
        }

        guard !host.simpler, !pip.happy else {
            body.hop = Spring(x: pip.hop)
            body.lean = Spring(x: pip.lean)
            return true
        }
        body.hop.step(to: hopTarget, dt, period: spring.period, damping: spring.damping)
        pip.hop = body.hop.x
        if ownsLean {
            body.lean.step(to: leanTarget, dt, period: spring.period, damping: spring.damping)
            pip.lean = body.lean.x
        } else {
            body.lean = Spring(x: pip.lean)
        }
        body.touched = true
        return true
    }

    private func set(_ s: Body.State) {
        body.state = s
        body.stateSince = .now
    }

    /// Hands Pip's pose back to Pip's own code, gently.
    private func relax(_ pip: PipModel) {
        guard body.touched else { return }
        body.touched = false
        body.hop = Spring()
        body.lean = Spring()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            pip.hop = 0
            pip.lean = 0
            pip.squash = 0
        }
        seatState.shown = false
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
        host.move(to: seat(near: host.pipPosition, host, showing: true))
        host.post(.custom("weight.tired"))
    }

    private func takeOff(_ host: PipHost) {
        set(.flying)
        let pip = host.pip
        if !host.simpler {
            // A small stretch, eased in and out.
            pip.squashAcross = true
            withAnimation(.easeInOut(duration: 0.45)) { pip.squash = 0.06 * (0.5 + body.feel.strength) } completion: {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { pip.squash = 0 }
            }
        }
        host.later(0.5) {
            line(Lines.rested, host, gap: 0)
            host.cheer()
            let p = host.pipPosition
            host.move(to: CGPoint(x: p.x, y: p.y - 60 - 40 * body.feel.bouncy))
            host.post(.custom("weight.rested"))
        }
        hideSeat(host, after: 0.9)
    }

    private func pickedUp(_ host: PipHost) {
        set(.carried)
        seatState.shown = false
        Self.emote("🥰")
        line(Lines.carried, host, for: 1.6)
    }

    private func putDown(_ host: PipHost) {
        body.releasedAt = .now
        set(.flying)
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
            let p = host.pipPosition
            if let s = ledge(near: p, host), s.y - p.y < 40 {
                // Left right by a panel's top edge: sit down on it.
                host.move(to: s)
                set(.landing)
            } else {
                // Left in mid-air: a soft dip that the float spring settles.
                body.hop.v += 22 * (0.6 + body.feel.heavy * 0.4)
            }
        }
    }

    private func hideSeat(_ host: PipHost, after seconds: Double) {
        host.later(seconds) {
            withAnimation(.easeOut(duration: 0.6)) { seatState.shown = false }
        }
    }

    /// The safe area's size, in the same space as Pip's position.
    private func room() -> CGSize? {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return nil }
        let inset = window.safeAreaInsets
        return CGSize(width: window.bounds.width - inset.left - inset.right,
                      height: window.bounds.height - inset.top - inset.bottom)
    }

    /// Somewhere to sit near a point, always well inside the screen: a panel's top edge if there is one, otherwise a little seat near the bottom middle. `showing` puts the seat out when it's used.
    private func seat(near p: CGPoint, _ host: PipHost, showing: Bool) -> CGPoint {
        if let s = ledge(near: p, host) { return s }
        let r = host.pip.radius
        guard let size = room() else { return p }
        // No ledge: Pip's own seat, toward the middle and lifted clear of the bottom edge and the plugin bar.
        let x = min(max(p.x, size.width * 0.3), size.width * 0.7)
        let y = max(size.height - Self.seatLift, size.height / 2)
        if showing {
            seatState.at = CGPoint(x: x, y: y + r + 3)
            withAnimation(.easeOut(duration: 0.5)) { seatState.shown = true }
        }
        return CGPoint(x: x, y: y)
    }

    /// The top of an open panel under Pip, kept well inside the screen, or nil.
    private func ledge(near p: CGPoint, _ host: PipHost) -> CGPoint? {
        let r = host.pip.radius
        guard let size = room() else { return nil }
        let m = min(Self.edgeMargin, size.width / 4)
        let inset = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
        let panel = host.panelFrame.offsetBy(dx: -inset.left, dy: -inset.top)
        if !panel.isNull, panel.width > 120, p.x > panel.minX, p.x < panel.maxX, panel.minY > p.y,
           panel.minY - r > m {
            let x = min(max(p.x, panel.minX + 40, m), min(panel.maxX - 40, size.width - m))
            return CGPoint(x: x, y: panel.minY - r * 0.9)
        }
        return nil
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { SeatView(seat: seatState, host: host) }

    /// The little seat: a short glass bar under Pip, in Pip's glow. It fades in as Pip lands and out after.
    struct SeatView: View {
        let seat: Seat
        let host: PipHost

        var body: some View {
            ZStack(alignment: .topLeading) {
                if seat.shown, host.pipHere {
                    Capsule()
                        .fill(PipLook.glow.opacity(0.35))
                        .frame(width: 44, height: 7)
                        .glassEffect(.regular.tint(PipLook.accent.opacity(0.1)), in: Capsule())
                        .position(seat.at)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }


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
