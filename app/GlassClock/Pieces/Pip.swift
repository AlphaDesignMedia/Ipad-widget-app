import SwiftUI

// Pip, the companion from the web sandbox (pip.js, engine.js), as one piece: grab and flick,
// blinks, taps, bumps. New for the app: the first meeting, where Pip falls in as a twinkle,
// lands asleep, and is woken by your tap. Switched off with Settings > Accessibility > Pip.

// MARK: Data

enum PipLines {
    static let wake = "Oh! Hello."                                        // persona "pip".wake
    static let hi = ["Hello!", "Yes?", "Hi again!", "That tickles."]      // persona "pip".hi
    // New for the app's first meeting.
    static let wakeHint = "Tap to wake"
    static let invite = "Grab me and flick me!"
    static let firstFlick = "Wheee! Again?"
}

enum PipPhysics {
    static let damping = 0.97            // per frame at 60 fps (engine.js)
    static let bounce = 0.78             // off an edge, when Pip isn't grounded
    static let squashMax = 0.32, squashSpeed = 2600.0
    static let dizzySpeed = 1150.0, dizzySeconds = 1.3
    static let restSpeed = 8.0
    static let maxSpeed = 3200.0
    static let blinkEvery = 2.6...5.8, blinkSeconds = 0.13
}

/// Trailing a point, like the web's pen-follow (engine.js, state "follow").
enum PipFollow {
    static let offset = CGSize(width: 30, height: 34)   // above and to the left of the point, times Pip's size
    static let pull = 16.0, settle = 4.2                // spring towards it, and how fast that eases (low = overshoots)
    static let lingers = 1.5                            // seconds after the point stops coming
    static let lean = 22.0, leanPer = 45.0              // most degrees Pip tips into a move, and pt/s per degree
}

enum PipArrival {
    static let delay = 0.9, fall = 1.8, burst = 0.8
    static let flickSpeed = 500.0        // the first flick that counts
}

private enum PipKeys {
    static let met = "pipMet", flicked = "pipFlicked", x = "pipX", y = "pipY"
}

// MARK: Logic

@MainActor @Observable
final class PipModel {
    struct Burst: Identifiable { let id = UUID(); let at: CGPoint; let start: Date }

    var pos = CGPoint.zero
    var shown = false
    var pop = 1.0
    var asleep = false
    var held = false
    var happy = false
    var mood: PipFace?               // a reaction for a moment (surprised, curious, shy, sleepy)
    @ObservationIgnored private var moodTask: Task<Void, Never>?
    var dizzy = false
    var blinking = false
    var squash = 0.0
    var squashAcross = true
    var hop = 0.0
    /// Degrees Pip tips into a move; wobbles back to 0 when it stops.
    var lean = 0.0
    var glow = 0.0
    var halo: Color?                 // the halo's colour for a moment (a blush); nil: Pip's own
    var look = CGSize.zero           // where Pip's eyes point, -1...1 each way; zero: straight ahead
    @ObservationIgnored private var lookTurn = 0
    var bubble: String?
    var twinkle: (from: CGPoint, to: CGPoint, start: Date)?
    var bursts: [Burst] = []
    var simpler = false
    /// Pip's size, 0.75 to 3 times the sandbox's 24 pt. Pinch Pip to change it.
    var scale = UserDefaults.standard.object(forKey: "pipScale") as? Double ?? 1
    var radius: CGFloat { PipLook.size / 2 * scale }
    @ObservationIgnored var pinching = false
    /// True while a flick carries Pip, so a touch catches it straight away.
    @ObservationIgnored private(set) var flying = false
    /// Tells the plugin host what Pip is doing (PluginHost.swift).
    @ObservationIgnored var onEvent: (PipEvent) -> Void = { _ in }

    var face: PipFace {
        if asleep { .asleep } else if held { .held } else if dizzy { .dizzy }
        else if let mood { mood } else if happy { .happy } else if blinking { .blink } else { .awake }
    }
    var sparkling: Bool { twinkle != nil || !bursts.isEmpty }

    private var bounds = CGRect.zero
    private var grabOffset = CGSize.zero
    private var vel = CGVector.zero
    private var glide: Task<Void, Never>?
    private var trailing: Task<Void, Never>?
    private var trail = CGPoint.zero
    private var trailSeen = Date.distantPast
    private var bubbleTask: Task<Void, Never>?
    private var happyTask: Task<Void, Never>?
    private var dizzyTask: Task<Void, Never>?
    private var started = false
    private var celebrating = false
    private let store = UserDefaults.standard

    // Where Pip lands the first time: middle of the screen, a little above centre.
    private var rest: CGPoint { CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.42) }

    func start(in rect: CGRect) {
        bounds = rect
        guard !started else { place(); return }
        started = true
        Task { await blinkLoop() }
        if store.bool(forKey: PipKeys.met) {
            place()
            withAnimation(.easeOut(duration: 0.4)) { shown = true }
            onEvent(.appear)
        } else {
            Task { await arrive() }
        }
    }

    /// Back where it was left, kept inside the screen (also after the iPad turns).
    func place() {
        guard store.object(forKey: PipKeys.x) != nil else { pos = clamp(shown ? pos : rest); return }
        pos = clamp(CGPoint(x: bounds.minX + store.double(forKey: PipKeys.x) * bounds.width,
                            y: bounds.minY + store.double(forKey: PipKeys.y) * bounds.height))
    }

    private func arrive() async {
        // Not over the app's own Welcome card: Pip waits until it's closed (ContentView's hasSeenTour).
        while !store.bool(forKey: "hasSeenTour") { try? await Task.sleep(for: .seconds(0.4)) }
        try? await Task.sleep(for: .seconds(PipArrival.delay))
        pos = rest
        asleep = true
        if simpler {
            withAnimation(.easeIn(duration: 0.6)) { shown = true }
        } else {
            twinkle = (CGPoint(x: bounds.maxX - 70, y: bounds.minY - 20), rest, .now)
            try? await Task.sleep(for: .seconds(PipArrival.fall))
            twinkle = nil
            burst(at: rest)
            pop = 0.2
            shown = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { pop = 1 }
        }
        onEvent(.appear)
        try? await Task.sleep(for: .seconds(0.8))
        if asleep { say(PipLines.wakeHint, for: nil) }
    }

    // Touch

    func dragChanged(from start: CGPoint, to location: CGPoint) {
        guard shown else { return }
        if !held {
            glide?.cancel()
            trailing?.cancel()
            held = true
            grabOffset = CGSize(width: pos.x - start.x, height: pos.y - start.y)
        }
        if hypot(location.x - start.x, location.y - start.y) > 6 {
            pos = clamp(CGPoint(x: location.x + grabOffset.width, y: location.y + grabOffset.height))
        }
    }

    func dragEnded(from start: CGPoint, to location: CGPoint, velocity: CGVector) {
        guard held else { return }
        held = false
        // Letting go after a pinch isn't a flick.
        if pinching { pinching = false; save(); return }
        if hypot(location.x - start.x, location.y - start.y) <= 6 { tap(); return }
        if asleep { wake() }
        let speed = hypot(velocity.dx, velocity.dy)
        if speed >= 60 { onEvent(.flick(speed: speed)) }
        let firstFlick = !store.bool(forKey: PipKeys.flicked) && speed > PipArrival.flickSpeed
        if simpler || speed < 60 {
            save()
            if firstFlick { celebrate() }
            return
        }
        let k = min(1, PipPhysics.maxSpeed / speed)
        vel = CGVector(dx: velocity.dx * k, dy: velocity.dy * k)
        celebrating = firstFlick
        glide = Task { await glideLoop() }
    }

    /// The touch was taken away (a call, a system gesture): Pip stays where it is.
    func dragCancelled() {
        guard held else { return }
        held = false
        pinching = false
        save()
    }

    func tap() {
        if asleep { wake(); return }
        onEvent(.tap)
        beHappy(0.8)
        bounceUp()
        if Double.random(in: 0...1) < 0.55 { say(PipLines.hi.randomElement()!, for: 1.2) }
    }

    func wake() {
        asleep = false
        store.set(true, forKey: PipKeys.met)
        beHappy(1.4)
        bounceUp()
        if !simpler {
            glow = 1
            withAnimation(.easeOut(duration: 0.9)) { glow = 0 }
        }
        say(PipLines.wake, for: 1.8)
        onEvent(.wake)
        guard !store.bool(forKey: PipKeys.flicked) else { return }
        Task {
            try? await Task.sleep(for: .seconds(2.1))
            if !held, !store.bool(forKey: PipKeys.flicked) { say(PipLines.invite, for: 4) }
        }
    }

    // Motion

    private func glideLoop() async {
        flying = true
        defer { flying = false }
        var last = Date.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(8))
            let now = Date.now, dt = min(now.timeIntervalSince(last), 1 / 30)
            last = now
            if !step(dt) { break }
        }
        guard !Task.isCancelled else { return }
        save()
        onEvent(.rest)
        if celebrating { celebrate() }
    }

    /// One frame of the glide: the sandbox's damping and edge bounce. False once Pip settles.
    private func step(_ dt: Double) -> Bool {
        pos.x += vel.dx * dt
        pos.y += vel.dy * dt
        let k = pow(PipPhysics.damping, dt * 60)
        vel.dx *= k; vel.dy *= k
        let r = radius
        let box = bounds.insetBy(dx: r, dy: r)
        if pos.x < box.minX || pos.x > box.maxX {
            let at = CGPoint(x: pos.x < box.minX ? bounds.minX : bounds.maxX, y: pos.y)
            pos.x = min(max(pos.x, box.minX), box.maxX)
            hit(speed: abs(vel.dx), across: true, at: at)
            vel.dx *= -PipPhysics.bounce
            vel.dx *= PipPhysics.damping; vel.dy *= PipPhysics.damping
        }
        if pos.y < box.minY || pos.y > box.maxY {
            let at = CGPoint(x: pos.x, y: pos.y < box.minY ? bounds.minY : bounds.maxY)
            pos.y = min(max(pos.y, box.minY), box.maxY)
            hit(speed: abs(vel.dy), across: false, at: at)
            vel.dy *= -PipPhysics.bounce
            vel.dx *= PipPhysics.damping; vel.dy *= PipPhysics.damping
        }
        return hypot(vel.dx, vel.dy) > PipPhysics.restSpeed
    }

    private func hit(speed: Double, across: Bool, at: CGPoint) {
        squashAcross = across
        squash = min(PipPhysics.squashMax, speed / PipPhysics.squashSpeed)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { squash = 0 }
        if celebrating, speed > 300 { burst(at: at) }
        onEvent(.bump(speed: speed))
        if speed > PipPhysics.dizzySpeed {
            dizzy = true
            dizzyTask?.cancel()
            dizzyTask = Task {
                try? await Task.sleep(for: .seconds(PipPhysics.dizzySeconds))
                if !Task.isCancelled { dizzy = false }
            }
        }
    }

    private func celebrate() {
        celebrating = false
        store.set(true, forKey: PipKeys.flicked)
        beHappy(1.4)
        bounceUp()
        if !simpler { burst(at: pos) }
        say(PipLines.firstFlick, for: 2.4)
    }

    func resize(_ s: Double) {
        scale = min(max(s, 0.75), 3)
        store.set(scale, forKey: "pipScale")
        pos = clamp(pos)
    }

    /// For plugins: Pip's eyes turn towards a point, further the further it is, then drift back.
    func lookAt(_ point: CGPoint) {
        let dx = point.x - pos.x, dy = point.y - pos.y
        let d = max(hypot(dx, dy), 1), reach = min(d / 120, 1)
        let to = CGSize(width: dx / d * reach, height: dy / d * reach)
        withAnimation(simpler ? .easeOut(duration: 0.15) : .spring(response: 0.22, dampingFraction: 0.65)) { look = to }
        lookTurn += 1
        let mine = lookTurn
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard lookTurn == mine else { return }
            withAnimation(.easeInOut(duration: 0.5)) { look = .zero }
        }
    }

    /// For plugins: a reaction face for a moment.
    func react(_ face: PipFace, for seconds: Double) {
        withAnimation(.easeOut(duration: 0.12)) { mood = face }
        moodTask?.cancel()
        moodTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { mood = nil } }
        }
    }

    /// For plugins: happy eyes and a hop.
    func cheer() {
        beHappy(1)
        bounceUp()
    }

    /// For plugins: glide to a point, or fade there when motion is simpler.
    func go(to point: CGPoint) {
        glide?.cancel()
        trailing?.cancel()
        if simpler {
            withAnimation(.easeOut(duration: 0.2)) { shown = false } completion: {
                self.pos = self.clamp(point)
                withAnimation(.easeIn(duration: 0.3)) { self.shown = true }
                self.save()
            }
        } else {
            let to = clamp(point)
            lean = min(max((to.x - pos.x) / 6, -PipFollow.lean), PipFollow.lean)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) { pos = to }
            settleLean(after: 0.25)
            save()
        }
    }

    /// Lean back upright with a wobble.
    private func settleLean(after delay: Double = 0) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.3).delay(delay)) { lean = 0 }
    }

    /// For plugins: trail a point (see `PipFollow`). Call it as the point moves; Pip settles by itself.
    func follow(_ point: CGPoint) {
        guard shown, !asleep, !held, !pinching, !simpler else { return }
        trail = point
        trailSeen = .now
        guard trailing == nil else { return }
        glide?.cancel()
        vel = .zero
        trailing = Task { await trailLoop() }
    }

    private func trailLoop() async {
        var last = Date.now
        while !Task.isCancelled, Date.now.timeIntervalSince(trailSeen) < PipFollow.lingers {
            try? await Task.sleep(for: .milliseconds(8))
            guard !Task.isCancelled, !held else { break }
            let now = Date.now, dt = min(now.timeIntervalSince(last), 1 / 30)
            last = now
            let k = max(1, scale)
            let to = clamp(CGPoint(x: trail.x - PipFollow.offset.width * k, y: trail.y - PipFollow.offset.height * k))
            vel.dx += (to.x - pos.x) * PipFollow.pull * dt
            vel.dy += (to.y - pos.y) * PipFollow.pull * dt
            let ease = exp(-PipFollow.settle * dt)
            vel.dx *= ease; vel.dy *= ease
            pos = clamp(CGPoint(x: pos.x + vel.dx * dt, y: pos.y + vel.dy * dt))
            let tip = min(max(vel.dx / PipFollow.leanPer, -PipFollow.lean), PipFollow.lean)
            lean += (tip - lean) * min(1, 12 * dt)
        }
        trailing = nil
        settleLean()
        if !held { vel = .zero; save() }
    }

    private func bounceUp() {
        guard !simpler else { return }
        withAnimation(.easeOut(duration: 0.14)) { hop = -9 } completion: {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { self.hop = 0 }
        }
    }

    private func burst(at p: CGPoint) {
        guard !simpler else { return }
        let b = Burst(at: p, start: .now)
        bursts.append(b)
        Task {
            try? await Task.sleep(for: .seconds(PipArrival.burst))
            bursts.removeAll { $0.id == b.id }
        }
    }

    private func blinkLoop() async {
        while true {
            try? await Task.sleep(for: .seconds(Double.random(in: PipPhysics.blinkEvery)))
            guard !asleep else { continue }
            blinking = true
            try? await Task.sleep(for: .seconds(PipPhysics.blinkSeconds))
            blinking = false
        }
    }

    // Words

    /// Shows a line by Pip and reads it out with VoiceOver. `for: nil` keeps it until the next line.
    func say(_ line: String, for seconds: Double?) {
        withAnimation(.easeOut(duration: 0.2)) { bubble = line }
        AccessibilityNotification.Announcement(line).post()
        bubbleTask?.cancel()
        guard let seconds else { return }
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { withAnimation(.easeIn(duration: 0.2)) { bubble = nil } }
        }
    }

    private func beHappy(_ seconds: Double) {
        happy = true
        happyTask?.cancel()
        happyTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { happy = false }
        }
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        let box = bounds.insetBy(dx: radius, dy: radius)
        return CGPoint(x: min(max(p.x, box.minX), box.maxX), y: min(max(p.y, box.minY), box.maxY))
    }

    private func save() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        store.set((pos.x - bounds.minX) / bounds.width, forKey: PipKeys.x)
        store.set((pos.y - bounds.minY) / bounds.height, forKey: PipKeys.y)
    }
}

// MARK: View

/// Pip over the whole app. Only Pip itself takes touches; everything else passes through.
struct PipLayer: View {
    @AppStorage("pipOn") private var pipOn = true
    @AppStorage("simpleMotion") private var simpleMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private let host = PipHost.shared
    private var pip: PipModel { host.pip }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                PluginOverlays(host: host)
                if pipOn {
                    if pip.sparkling { sparkles }
                    if pip.shown { pipView }
                }
                PluginBar(host: host, size: geo.size)
                if pipOn, let line = pip.bubble, pip.shown { bubble(line, size: geo.size) }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background { if pipOn { PipTouches(pip: pip).allowsHitTesting(false) } }
            .coordinateSpace(.named("pip"))
            .onAppear {
                pip.simpler = systemReduceMotion || simpleMotion
                host.pipOn = pipOn
                host.launch()
                pip.start(in: CGRect(origin: .zero, size: geo.size))
            }
            .onChange(of: pipOn) { _, on in host.pipOn = on }
            .onChange(of: geo.size) { _, size in pip.start(in: CGRect(origin: .zero, size: size)) }
            .onChange(of: systemReduceMotion || simpleMotion) { _, on in pip.simpler = on }
        }
    }

    private var pipView: some View {
        let flaps = !pip.simpler && pip.face != .asleep
        return TimelineView(.animation(minimumInterval: 1 / 60, paused: pip.simpler)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let flap = flaps ? 0.5 - 0.5 * cos(.pi * t / PipLook.flapSeconds) : 0
            ZStack {
                PipBody(face: pip.face, flap: flap, spin: (t / 0.5).truncatingRemainder(dividingBy: 1), glow: pip.glow,
                        halo: pip.halo ?? PipLook.glow, look: pip.look, size: PipLook.size * pip.scale)
                if pip.face == .asleep { snore(t) }
            }
        }
        .scaleEffect(x: pip.squashAcross ? 1 - pip.squash : 1 + pip.squash * 0.5,
                     y: pip.squashAcross ? 1 + pip.squash * 0.5 : 1 - pip.squash)
        .scaleEffect(pip.pop)
        .rotationEffect(.degrees(pip.lean))
        .offset(y: pip.hop)
        .frame(width: PipLook.touch * max(1, pip.scale), height: PipLook.touch * max(1, pip.scale))
        // Touches come from PipTouches, so a tap on Pip also reaches the button underneath.
        .allowsHitTesting(false)
        .position(pip.pos)
        .transition(.opacity)
        .accessibilityElement()
        .accessibilityLabel("Pip")
        .accessibilityValue(pip.asleep ? "Asleep" : "Awake")
        .accessibilityHint(pip.asleep ? "Double-tap to wake Pip." : "Double-tap to say hello. Swipe up or down to change size.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { pip.tap() }
        .accessibilityAdjustableAction { direction in
            if direction == .increment { pip.resize(pip.scale + 0.25) }
            if direction == .decrement { pip.resize(pip.scale - 0.25) }
        }
    }

    /// The "z" from the sandbox: rises and fades every 2.6 seconds; still when motion is simpler.
    private func snore(_ t: Double) -> some View {
        let p = pip.simpler ? 0.5 : (t / 2.6).truncatingRemainder(dividingBy: 1)
        return Text("z")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .opacity(pip.simpler ? 0.7 : (p < 0.3 ? p / 0.3 * 0.9 : 0.9 * (1 - (p - 0.3) / 0.7)))
            .offset(x: 7 * pip.scale, y: -10 * pip.scale - p * 14)
            .accessibilityHidden(true)
    }

    private func bubble(_ line: String, size: CGSize) -> some View {
        let above = pip.pos.y > 68 + 12 * pip.scale
        let x = min(max(pip.pos.x, 125), size.width - 125)
        return Text(line)
            .font(.system(size: 14, weight: .medium))
            .lineSpacing(2)
            .padding(.vertical, 9).padding(.horizontal, 13)
            .glassEffect(.regular.tint(PipLook.accent.opacity(0.1)), in: .rect(cornerRadius: 15))
            .frame(maxWidth: 230)
            .position(x: x, y: pip.pos.y + pip.hop + (above ? -1 : 1) * (26 + 12 * pip.scale))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.opacity)
    }

    /// The falling twinkle with its trail, and the little bursts when Pip lands or bounces.
    private var sparkles: some View {
        TimelineView(.animation) { tl in
            Canvas { gc, _ in
                let now = tl.date
                if let tw = pip.twinkle {
                    let t = now.timeIntervalSince(tw.start) / PipArrival.fall
                    for n in stride(from: 12, through: 0, by: -1) {
                        let u = t - Double(n) * 0.035
                        guard u > 0 else { continue }
                        let p = fall(tw.from, tw.to, ease(min(u, 1)))
                        let fade = 1 - Double(n) / 13
                        let r = (n == 0 ? 10 + 1.5 * sin(t * 40) : 4 * fade + 1)
                        let wobble = n == 0 ? 0 : sin(Double(n) * 1.7) * 3
                        drawSparkle(gc, at: CGPoint(x: p.x + wobble, y: p.y), r: r, alpha: n == 0 ? 1 : fade * 0.8)
                    }
                }
                for b in pip.bursts {
                    let p = min(1, now.timeIntervalSince(b.start) / PipArrival.burst)
                    let out = 1 - pow(1 - p, 3)
                    let ring = 6 + 30 * out
                    gc.stroke(Path(ellipseIn: CGRect(x: b.at.x - ring, y: b.at.y - ring, width: ring * 2, height: ring * 2)),
                              with: .color(PipLook.accent.opacity(0.5 * (1 - p))), lineWidth: 1.5)
                    for i in 0..<9 {
                        let a = Double(i) / 9 * 2 * .pi + 0.3
                        let d = 8 + 34 * out
                        drawSparkle(gc, at: CGPoint(x: b.at.x + cos(a) * d, y: b.at.y + sin(a) * d),
                                    r: 3.5 * (1 - p) + 0.6, alpha: 1 - p)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawSparkle(_ gc: GraphicsContext, at p: CGPoint, r: Double, alpha: Double) {
        let glow = r * 2.6
        gc.fill(Path(ellipseIn: CGRect(x: p.x - glow, y: p.y - glow, width: glow * 2, height: glow * 2)),
                with: .radialGradient(Gradient(colors: [PipLook.accent.opacity(0.45 * alpha), PipLook.accent.opacity(0)]),
                                      center: p, startRadius: 0, endRadius: glow))
        // A white star with a Pip-blue edge, so it shows on light backgrounds as well as dark.
        let star = PipSparkle().path(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        gc.fill(star, with: .color(.white.opacity(alpha)))
        gc.stroke(star, with: .color(PipLook.accent.opacity(0.85 * alpha)), lineWidth: 1)
    }

    /// A swoop from the top right, curving out to the left before it settles.
    private func fall(_ a: CGPoint, _ b: CGPoint, _ u: Double) -> CGPoint {
        let c = CGPoint(x: b.x - (a.x - b.x) * 0.9, y: a.y + (b.y - a.y) * 0.35)
        let v = 1 - u
        return CGPoint(x: v * v * a.x + 2 * v * u * c.x + u * u * b.x, y: v * v * a.y + 2 * v * u * c.y + u * u * b.y)
    }

    private func ease(_ u: Double) -> Double { u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2 }
}

// MARK: Touches

/// Grab, flick, tap and pinch for Pip, heard from the window rather than from Pip's view. Pip's view
/// takes no touches, so a tap on Pip reaches whatever is underneath as well (and says hello). Only
/// a touch that starts on Pip and moves, or one that catches Pip mid-flick, is kept for Pip.
struct PipTouches: UIViewRepresentable {
    let pip: PipModel
    func makeUIView(context: Context) -> Hearing { Hearing(pip: pip) }
    func updateUIView(_ v: Hearing, context: Context) {}

    /// Fills Pip's layer, so touches read in Pip's coordinates. Takes no touches itself.
    final class Hearing: UIView, UIGestureRecognizerDelegate {
        private let grab: Grab
        private let pinch = UIPinchGestureRecognizer()
        private let pip: PipModel
        private var pinchFrom: Double?

        init(pip: PipModel) {
            self.pip = pip
            grab = Grab(pip: pip)
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            grab.space = self
            grab.delegate = self
            pinch.delegate = self
            pinch.cancelsTouchesInView = true
            pinch.addTarget(self, action: #selector(pinched))
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            for r in [grab, pinch] as [UIGestureRecognizer] {
                r.view?.removeGestureRecognizer(r)
                window?.addGestureRecognizer(r)
            }
        }

        override func removeFromSuperview() {
            for r in [grab, pinch] as [UIGestureRecognizer] { r.view?.removeGestureRecognizer(r) }
            super.removeFromSuperview()
        }

        @objc private func pinched(_ r: UIPinchGestureRecognizer) {
            switch r.state {
            case .began, .changed:
                if pinchFrom == nil { pinchFrom = pip.scale }
                pip.pinching = true
                pip.resize((pinchFrom ?? 1) * r.scale)
            default:
                pinchFrom = nil
                // Still held by one finger: that letting go ends the pinch, and isn't a flick.
                if !pip.held { pip.pinching = false }
            }
        }

        override func gestureRecognizerShouldBegin(_ r: UIGestureRecognizer) -> Bool {
            guard r === pinch else { return true }
            return Grab.onPip(r.location(in: self), pip, slack: 1.5)
        }

        func gestureRecognizer(_ r: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            (r === grab && other === pinch) || (r === pinch && other === grab)
        }
    }

    /// One finger on Pip. Waits for it to move before taking the touch; a tap is passed on.
    final class Grab: UIGestureRecognizer {
        let pip: PipModel
        weak var space: UIView?
        private var finger: UITouch?
        private var start = CGPoint.zero
        private var trail: [(at: CGPoint, time: TimeInterval)] = []

        init(pip: PipModel) {
            self.pip = pip
            super.init(target: nil, action: nil)
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        /// Pip's touch area: the old 48 pt circle, growing with Pip.
        static func onPip(_ p: CGPoint, _ pip: PipModel, slack: CGFloat = 1) -> Bool {
            guard pip.shown else { return false }
            let r = PipLook.touch * max(1, pip.scale) / 2 * slack
            return hypot(p.x - pip.pos.x, p.y - pip.pos.y) <= r
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            guard finger == nil, let t = touches.first, let space else { return }
            let p = t.location(in: space)
            guard Grab.onPip(p, pip) else { state = .failed; return }
            finger = t
            start = p
            trail = [(p, t.timestamp)]
            // Catching Pip mid-flick is clearly meant for Pip.
            if pip.flying { pip.dragChanged(from: start, to: p); state = .began }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let t = finger, touches.contains(t), let space else { return }
            let p = t.location(in: space)
            trail.append((p, t.timestamp))
            trail.removeAll { t.timestamp - $0.time > 0.1 }
            if state == .possible {
                guard hypot(p.x - start.x, p.y - start.y) > 6 else { return }
                state = .began
            } else {
                state = .changed
            }
            pip.dragChanged(from: start, to: p)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let t = finger, touches.contains(t), let space else { return }
            let p = t.location(in: space)
            if state == .possible {
                // A tap: Pip says hello, and the button underneath gets it too.
                pip.tap()
                state = .failed
                return
            }
            var v = CGVector.zero
            if let first = trail.first, t.timestamp - first.time > 0.005 {
                let dt = t.timestamp - first.time
                v = CGVector(dx: (p.x - first.at.x) / dt, dy: (p.y - first.at.y) / dt)
            }
            pip.dragEnded(from: start, to: p, velocity: v)
            state = .ended
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let t = finger, touches.contains(t) else { return }
            pip.dragCancelled()
            state = state == .possible ? .failed : .cancelled
        }

        override func reset() {
            finger = nil
            trail = []
        }
    }
}
