import SwiftUI

// PIP LOOKS · plugin v1 (Dream). Pip's look list: Classic (the orb, the default) or Drop (Aaron's 3D liquid drop,
// from the Pip Drop Workshop, picks of 30 Oct 2026). One tap back to Classic.
// Where: the drop button in the plugin bar. The card shows both looks side by side; drag (or hover) in it and
// they turn to look at your finger.
// For now Drop shows only in the card. Pip wears it everywhere once the core adds the look hook (`host.pipStyle`,
// asked for in AGENT-NOTES.md). The two lines that switch it on are at the bottom of `apply`, ready.
// A port of app/design/pip-drop-workshop.html (see app/design/PIP-DROP-3D.md for how the 3D works).

struct PipLooks: SandboxPlugin {
    let info = PluginInfo(id: "looks", name: "Pip Looks", version: "v1", shelf: .dream,
                          icon: "drop", what: "Choose Pip's look: Classic (the orb) or Drop (a 3D liquid drop). One tap back.")

    // MARK: Data

    enum Look: String, CaseIterable {
        case classic, drop
        var title: String { self == .classic ? "Classic (default)" : "Drop" }
        var short: String { self == .classic ? "Classic" : "Drop" }
    }

    static let selfID = "looks"
    static let lookKey = "look"                       // "plug.looks.look": "classic" or "drop"
    static let waitingNote = "Drop shows here for now; Pip will wear it everywhere once the backbone adds the look hook."
    static let lines: [Look: String] = [.classic: "Back to my old self.", .drop: "Ooh, liquid."]

    // MARK: Logic

    @MainActor static func chosen(_ host: PipHost) -> Look {
        let raw: String? = host.value(selfID, lookKey)
        return raw.flatMap { Look(rawValue: $0) } ?? .classic
    }

    func start(_ host: PipHost) throws { PipLooks.apply(PipLooks.chosen(host), host, speak: false) }

    /// Saves the choice and (once the core hook exists) dresses Pip in it.
    @MainActor static func apply(_ look: Look, _ host: PipHost, speak: Bool = true) {
        host.setValue(look.rawValue, selfID, lookKey)
        if speak, host.joy > 0, PipTalkTurns.floorFree(host), let line = lines[look] { host.say(line, for: 2) }
        // Core hook, not there yet (AGENT-NOTES.md, Bob 30 Oct). When it lands, un-comment these two lines:
        // host.pipStyle = look == .drop ? PipStyle(owner: selfID, body: { ctx in
        //     PipLooks.dropView(face: ctx.face, look: ctx.look, time: ctx.time, size: ctx.size, simpler: ctx.simpler, flapping: ctx.flapping, spin: ctx.spin) }) : nil
    }

    /// Pip's whole body in the Drop look, for the core to draw in place of `PipBody` (same centre, Pip's own space).
    /// `size` is the orb's diameter, like `PipBody.size`. `look` is the core's eye direction (-1...1); zero means idle sway.
    @MainActor static func dropView(face: PipFace, look: CGSize, time: Double, size: CGFloat,
                                    simpler: Bool, flapping: Bool, spin: Double = 0) -> AnyView {
        let aim: CGSize? = look == .zero ? nil : look
        let target = DropMath.target(aim, time: time, turn: DropPicks.aaron30Oct.turn, simpler: simpler)
        let pose = DropTurn.live.step(to: target, at: time, snap: simpler)
        return AnyView(PipDropBody(picks: .aaron30Oct, pose: pose, time: simpler ? 0 : time, face: face,
                                   radius: size / 2, simpler: simpler, flapping: flapping && !simpler, spin: spin))
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { LooksCard(host: host) }

    struct LooksCard: View {
        let host: PipHost
        @AppStorage("plug.looks.look") private var chosen: String = Look.classic.rawValue
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var finger: CGPoint? = nil
        @State private var turn = DropTurn()

        var body: some View {
            let look = Look(rawValue: chosen) ?? .classic
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                stage(look)
                Text("Pip look").font(.system(size: 13.5, weight: .semibold))
                HStack(spacing: 8) {
                    ForEach(Look.allCases, id: \.self) { l in
                        Button {
                            chosen = l.rawValue
                            PipLooks.apply(l, host)
                        } label: {
                            Text(l.title).lineLimit(2).multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(PluginCardButton(on: look == l))
                        .accessibilityLabel("Pip look: \(l.short)")
                        .accessibilityHint(l == .classic ? "The glowing orb. The default." : "A 3D liquid drop with wings.")
                        .accessibilityAddTraits(look == l ? .isSelected : [])
                    }
                }
                Text(PipLooks.waitingNote)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 13.5))
        }

        /// Both looks side by side. They turn to follow your finger (or Pencil hover) while it's in here.
        private func stage(_ look: Look) -> some View {
            let simpler = host.simpler || reduceMotion
            let dropRadius: CGFloat = 18
            return GeometryReader { geo in
                let w: CGFloat = geo.size.width, h: CGFloat = geo.size.height
                let classicAt = CGPoint(x: w * 0.25, y: h * 0.46)
                let dropAt = CGPoint(x: w * 0.71, y: h * 0.46)
                let aimClassic: CGSize? = DropMath.aim(finger, from: classicAt, in: geo.size)
                let aimDrop: CGSize? = DropMath.aim(finger, from: dropAt, in: geo.size)
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: simpler)) { tl in
                    let t: Double = simpler ? 0 : tl.date.timeIntervalSinceReferenceDate
                    let target = DropMath.target(aimDrop, time: t, turn: DropPicks.aaron30Oct.turn, simpler: simpler)
                    let pose = turn.step(to: target, at: t, snap: simpler)
                    let flap: Double = simpler ? 0 : 0.5 - 0.5 * cos(Double.pi * t / PipLook.flapSeconds)
                    let bob: CGFloat = simpler ? 0 : CGFloat(sin(t * 1.6) * 3)
                    let blink: Bool = DropMath.blinking(t)
                    ZStack {
                        PipBody(face: blink ? .blink : .awake, flap: flap, look: aimClassic ?? .zero, size: 44)
                            .position(x: classicAt.x, y: classicAt.y + bob)
                        PipDropBody(picks: .aaron30Oct, pose: pose, time: t, face: blink ? .blink : .awake, radius: dropRadius,
                                    simpler: simpler, flapping: !simpler)
                            .position(x: dropAt.x, y: dropAt.y + bob)
                        label("Classic", on: look == .classic).position(x: classicAt.x, y: h - 14)
                        label("Drop", on: look == .drop).position(x: dropAt.x, y: h - 14)
                    }
                    .frame(width: w, height: h)
                }
            }
            .frame(height: 190)
            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in finger = drag.location }
                .onEnded { _ in finger = nil })
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): finger = p
                case .ended: finger = nil
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Preview of Pip's two looks, Classic and Drop. \(look.short) is chosen.")
            .accessibilityHint("Drag here and both Pips turn to look at your finger.")
        }

        private func label(_ text: String, on: Bool) -> some View {
            Text(text)
                .font(.system(size: 12, weight: on ? .bold : .regular))
                .foregroundStyle(on ? Color.primary : Color.secondary)
        }
    }
}

// MARK: - The Drop look (data)

/// Aaron's picks from the Pip Drop Workshop (app/design/pip-drop-picks.json, 30 Oct 2026).
/// `size` is the workshop's radius at 640 wide; in the app the orb's radius comes from Pip's own size instead.
struct DropPicks: Equatable {
    var size: Double = 37
    var round: Double = 0.54        // how much the tip's edges bulge
    var tail: Double = 1.4          // extra tip length, × radius
    var tilt: Double = -161         // tip direction, degrees
    var curl: Double = -0.31        // bends the tip
    var hue: Double = 156
    var glow: Double = 1
    var w1: Double = 2.48           // first wing length, × radius
    var w2: Double = 0.78           // second wing, × the first
    var wide: Double = 0.51         // leaf width
    var fan: Double = 58            // spread between the wings, degrees
    var flap: Double = 4            // radians a second
    var depth: Double = 0.45        // flap size
    var lag: Double = 0.6           // second wing's delay
    var turn: Double = 0.35         // idle turning
    var boing: Double = 0.55        // squash (the core does Pip's own squash; kept for the record)
    var bob: Double = 0.5           // float
    var wingsFromBack: Bool = true
    var farWingsFaint: Bool = true

    static let aaron30Oct = DropPicks()
}

/// Where the head and body face. Pip faces +x in body space; yaw -π/2 faces you.
struct DropPose: Equatable {
    var headYaw: Double = -0.6
    var headPitch: Double = 0
    var bodyYaw: Double = -0.6
    var bodyPitch: Double = 0
}

/// Head leads, body follows: the head eases to its target (0.12 a frame at 60), the body to the head (0.045).
/// A plain class so the easing carries from frame to frame; one per drawn Pip.
final class DropTurn {
    static let live = DropTurn()        // the one the core's Pip uses
    private var pose = DropPose()
    private var last: Double? = nil

    func step(to target: (yaw: Double, pitch: Double), at t: Double, snap: Bool) -> DropPose {
        if snap {
            pose = DropPose(headYaw: target.yaw, headPitch: target.pitch, bodyYaw: target.yaw, bodyPitch: target.pitch * 0.5)
            last = t
            return pose
        }
        let dt: Double = last.map { min(max(t - $0, 0), 0.1) } ?? (1.0 / 60.0)
        last = t
        let frames: Double = dt * 60
        let kh: Double = 1 - pow(1 - 0.12, frames)
        let kb: Double = 1 - pow(1 - 0.045, frames)
        pose.headYaw += (target.yaw - pose.headYaw) * kh
        pose.headPitch += (target.pitch - pose.headPitch) * kh
        pose.bodyYaw += (pose.headYaw - pose.bodyYaw) * kb
        pose.bodyPitch += (pose.headPitch * 0.5 - pose.bodyPitch) * kb
        return pose
    }
}

// MARK: - The Drop look (logic: tiny 3D, no engine)

enum DropMath {
    struct V: Equatable {
        var x: Double, y: Double, z: Double
        init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
        var point: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
    }

    static func rotY(_ v: V, _ a: Double) -> V {
        let c = cos(a), s = sin(a)
        return V(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
    }
    static func rotX(_ v: V, _ a: Double) -> V {
        let c = cos(a), s = sin(a)
        return V(v.x, v.y * c - v.z * s, v.y * s + v.z * c)
    }
    static func add(_ a: V, _ b: V, _ k: Double = 1) -> V { V(a.x + b.x * k, a.y + b.y * k, a.z + b.z * k) }
    static func times(_ a: V, _ k: Double) -> V { V(a.x * k, a.y * k, a.z * k) }
    static func norm(_ v: V) -> V {
        let l = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        let d = l > 0 ? l : 1
        return V(v.x / d, v.y / d, v.z / d)
    }
    static func cross(_ a: V, _ b: V) -> V {
        V(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

    /// A finger in the stage, as a -1...1 look from a point (the workshop's: ±1 at 30% of the width, 35% of the height).
    static func aim(_ finger: CGPoint?, from c: CGPoint, in size: CGSize) -> CGSize? {
        guard let f = finger, size.width > 0, size.height > 0 else { return nil }
        let dx = clamp(Double((f.x - c.x) / (size.width * 0.3)), -1, 1)
        let dy = clamp(Double((f.y - c.y) / (size.height * 0.35)), -1, 1)
        return CGSize(width: CGFloat(dx), height: CGFloat(dy))
    }

    /// Where the head wants to face: towards the look, or a slow idle sway scaled by `turn` (none under simpler motion).
    static func target(_ look: CGSize?, time t: Double, turn: Double, simpler: Bool) -> (yaw: Double, pitch: Double) {
        if let l = look {
            return (-Double.pi / 2 + Double(l.width) * (Double.pi / 2 - 0.25), -Double(l.height) * 0.55)
        }
        if simpler { return (-0.6, 0) }
        return (-0.6 + sin(t * 0.8) * turn * 1.1, sin(t * 0.6) * 0.14 * turn)
    }

    /// A quick blink now and then (every 4.3 s, for 0.12 s). Never under simpler motion, where time stands still at 0.
    static func blinking(_ t: Double) -> Bool {
        guard t > 0 else { return false }
        return t.truncatingRemainder(dividingBy: 4.3) < 0.12
    }

    /// The workshop's hsl(), as a SwiftUI colour. h in degrees, s and l 0...1.
    static func hsl(_ h: Double, _ s: Double, _ l: Double, _ a: Double = 1) -> Color {
        let hh = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        var r = 0.0, g = 0.0, b = 0.0
        switch Int(hh) {
        case 0: r = c; g = x
        case 1: r = x; g = c
        case 2: g = c; b = x
        case 3: g = x; b = c
        case 4: r = x; b = c
        default: r = c; b = x
        }
        return Color(red: r + m, green: g + m, blue: b + m, opacity: clamp(a, 0, 1))
    }

    /// One wing, in 3D: a leaf outline from `root` along d, widening along w, then turned with the body.
    struct Wing {
        var points: [CGPoint]
        var z: Double           // average depth: far wings are drawn before the body
        var root: CGPoint, tip: CGPoint, rib: CGPoint
        var face: Double        // |normal.z|: 1 flat to you, 0 edge-on
        var alpha: Double
    }

    static func wing(root: V, ang: Double, spreadZ: Double, twist: Double, len: Double, wid: Double,
                     alpha: Double, turn R: (V) -> V) -> Wing {
        let d = norm(V(cos(ang), sin(ang), spreadZ))
        var w = norm(cross(d, V(0, 0, 1)))
        let n0 = cross(d, w)
        w = norm(add(times(w, cos(twist)), n0, sin(twist)))
        let n = 18
        var pts: [V] = []
        for i in 0...n {
            let s = Double(i) / Double(n)
            let width = wid * len * pow(max(0, sin(Double.pi * s)), 0.85) * (1.15 - 0.55 * s)
            pts.append(add(add(root, d, len * s), w, width))
        }
        for i in stride(from: n - 1, to: 0, by: -1) {
            let s = Double(i) / Double(n)
            pts.append(add(add(root, d, len * s), w, -wid * len * 0.22 * sin(Double.pi * s)))
        }
        let turned = pts.map(R)
        let zSum = turned.reduce(0.0) { $0 + $1.z }
        let normal = norm(R(cross(d, w)))
        return Wing(points: turned.map { $0.point },
                    z: zSum / Double(max(turned.count, 1)),
                    root: R(root).point,
                    tip: R(add(root, d, len)).point,
                    rib: R(add(add(root, d, len * 0.55), w, wid * len * 0.35)).point,
                    face: abs(normal.z),
                    alpha: alpha)
    }
}

// MARK: - The Drop look (view)

/// Pip as a 3D liquid drop: a ball with a fixed light, a liquid tip from the turned 3D tail, four leaf wings
/// in 3D (far ones behind the body, near ones in front, thin and glassy edge-on), and two eyes on the ball's surface.
/// Drawn centred in its frame, which is 8 × the radius so the glow fits. Pure: same inputs, same picture.
struct PipDropBody: View {
    var picks: DropPicks = .aaron30Oct
    var pose: DropPose = DropPose()
    var time: Double = 0
    var face: PipFace = .awake
    var radius: CGFloat = 12
    var simpler: Bool = false
    var flapping: Bool = true
    var spin: Double = 0

    var body: some View {
        let side: CGFloat = radius * 8
        let p = picks, pz = pose, t = simpler ? 0 : time, fc = face
        let flaps = flapping && !simpler && face != .asleep
        let sp = spin, rad = Double(radius)
        return Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            PipDropBody.draw(in: &g, picks: p, pose: pz, time: t, face: fc, r: rad,
                             flapping: flaps, spin: sp)
        }
        .frame(width: side, height: side)
        .saturation(face == .asleep ? 0.7 : 1)
        .brightness(face == .asleep ? -0.08 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    nonisolated static func draw(in ctx: inout GraphicsContext, picks P: DropPicks, pose: DropPose, time t: Double,
                     face: PipFace, r: Double, flapping: Bool, spin: Double) {
        typealias M = DropMath
        let R: (M.V) -> M.V = { v in M.rotX(M.rotY(v, pose.bodyYaw), pose.bodyPitch) }
        let h = P.hue
        let k = CGFloat(max(r / 37, 0.45))        // line widths, in step with the workshop at its size

        // The tail in 3D, so it swings round as Pip turns.
        let a = P.tilt * Double.pi / 180
        let d = r * (1 + P.tail)
        let curlA = a + P.curl * 0.75 + sin(t * 1.3) * 0.06 * P.bob
        let tail3 = R(M.V(cos(curlA) * d, sin(curlA) * d, 0))
        let tip = CGPoint(x: CGFloat(tail3.x), y: CGFloat(tail3.y))
        let spineV = R(M.V(cos(a), sin(a), 0))
        let spineAng = atan2(spineV.y, spineV.x)

        // Wings.
        let flapA: Double = flapping ? sin(t * P.flap) * P.depth : 0
        let flap2: Double = flapping ? sin(t * P.flap - P.lag) * P.depth * 1.3 : 0
        let fromBack = P.wingsFromBack
        let fan = P.fan * Double.pi / 180
        let base = (fromBack ? a + 0.45 : a + Double.pi * 0.12) - fan / 2
        let L1 = r * P.w1, L2 = L1 * P.w2
        var wings: [M.Wing] = []
        for side in [1.0, -1.0] {
            let root = fromBack
                ? M.V(cos(a + 0.75) * r * 0.72, sin(a + 0.75) * r * 0.72, side * r * 0.35)
                : M.V(cos(curlA) * d, sin(curlA) * d, 0)
            let z1 = side * (0.45 + 0.75 * flapA), z2 = side * (0.6 + 0.9 * flap2)
            let alpha: Double = side > 0 ? 1 : (P.farWingsFaint ? 0.4 : 0.95)
            let ang1 = base - flapA * 0.45
            wings.append(M.wing(root: root, ang: ang1, spreadZ: z1, twist: flapA * 0.7 * side,
                                len: L1, wid: P.wide, alpha: alpha, turn: R))
            var root2 = root
            if !fromBack { root2 = M.add(root, M.norm(M.V(cos(ang1), sin(ang1), z1)), L1 * 0.88) }
            wings.append(M.wing(root: root2, ang: base + fan - flap2 * 0.45 + (fromBack ? 0.55 : 0), spreadZ: z2,
                                twist: flap2 * 0.7 * side, len: L2, wid: P.wide * 0.9, alpha: alpha * 0.92, turn: R))
        }
        wings.sort { $0.z < $1.z }
        for w in wings where w.z < 0 { paint(w, hue: h, k: k, in: &ctx) }

        // Glow.
        let glowR = CGFloat(r * (2.2 + P.glow * 1.6))
        ctx.fill(Path(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [M.hsl(h, 1, 0.75, 0.35 * P.glow), M.hsl(h, 1, 0.70, 0)]),
                                       center: .zero, startRadius: CGFloat(r * 0.2), endRadius: glowR))

        // The drop: a ball plus a liquid tip, its outline from the turned tail.
        let dd = Double(hypot(tip.x, tip.y))
        let ca = acos(min(0.999, r / max(dd, r * 1.001)))
        let ta = atan2(Double(tip.y), Double(tip.x))
        let p1 = CGPoint(x: CGFloat(cos(ta + ca) * r), y: CGFloat(sin(ta + ca) * r))
        let p2 = CGPoint(x: CGFloat(cos(ta - ca) * r), y: CGFloat(sin(ta - ca) * r))
        let bulge = P.round * r * 0.55
        let sl = min(dd, r + d) * 0.55
        let spine = CGPoint(x: CGFloat(cos(spineAng) * sl), y: CGFloat(sin(spineAng) * sl))
        func control(_ q: CGPoint) -> CGPoint {
            let mx = Double(q.x + spine.x) / 2, my = Double(q.y + spine.y) / 2
            let l0 = sqrt(mx * mx + my * my), l = l0 > 0 ? l0 : 1
            return CGPoint(x: CGFloat(mx + mx / l * bulge * 0.7), y: CGFloat(my + my / l * bulge * 0.7))
        }
        var drop = Path()
        drop.move(to: tip)
        drop.addQuadCurve(to: p1, control: control(p1))
        let from = ta + ca, to = ta - ca + Double.pi * 2      // the long way round, angles increasing
        let steps = 48
        for i in 1...steps {
            let an = from + (to - from) * Double(i) / Double(steps)
            drop.addLine(to: CGPoint(x: CGFloat(cos(an) * r), y: CGFloat(sin(an) * r)))
        }
        drop.addQuadCurve(to: tip, control: control(p2))
        drop.closeSubpath()

        // The light stays put while Pip turns: that's what makes a ball read as round.
        let hx = -r * 0.35, hy = -r * 0.4
        let shade = Gradient(stops: [
            .init(color: M.hsl(h, 1, 0.97), location: 0),
            .init(color: M.hsl(h, 0.95, 0.78), location: 0.35),
            .init(color: M.hsl(h + 15, 0.8, 0.52), location: 0.85),
            .init(color: M.hsl(h + 25, 0.7, 0.38), location: 1),
        ])
        var lit = ctx
        lit.addFilter(.shadow(color: M.hsl(h, 1, 0.7, P.glow), radius: CGFloat(r * 0.4)))
        lit.fill(drop, with: .radialGradient(shade, center: CGPoint(x: CGFloat(hx * 0.55), y: CGFloat(hy * 0.55)),
                                             startRadius: CGFloat(r * 0.06), endRadius: CGFloat(r * 1.45)))
        ctx.stroke(drop, with: .color(M.hsl(h, 1, 0.92, 0.5)), lineWidth: 1.5 * k)

        // Two eyes on the ball's surface: they slide round and squash as the head turns, and hide round the back.
        for zs in [-0.3, 0.3] {
            let e = M.rotX(M.rotY(M.norm(M.V(1, -0.12, zs)), pose.headYaw), pose.headPitch)
            guard e.z > -0.05 else { continue }
            let ex = e.x * r * 0.8, ey = e.y * r * 0.8
            let ang = atan2(ey, ex)
            let squash = M.clamp(e.z, 0.25, 1)
            let place = CGAffineTransform(rotationAngle: CGFloat(-ang))
                .concatenating(CGAffineTransform(scaleX: CGFloat(squash), y: 1))
                .concatenating(CGAffineTransform(rotationAngle: CGFloat(ang)))
                .concatenating(CGAffineTransform(translationX: CGFloat(ex), y: CGFloat(ey)))
            eye(face, r: r, k: k, spin: spin, hue: h, place: place, in: &ctx)
        }

        // The shine.
        let shine = Path(ellipseIn: CGRect(x: -r * 0.18, y: -r * 0.1, width: r * 0.36, height: r * 0.2))
            .applying(CGAffineTransform(rotationAngle: -0.6)
                .concatenating(CGAffineTransform(translationX: CGFloat(hx * 0.9), y: CGFloat(hy * 0.95))))
        ctx.fill(shine, with: .color(.white.opacity(0.85)))

        for w in wings where w.z >= 0 { paint(w, hue: h, k: k, in: &ctx) }
    }

    /// A wing: a glassy gradient from root to tip, an edge line, and a rib curve that sells the bend.
    nonisolated static func paint(_ w: DropMath.Wing, hue h: Double, k: CGFloat, in ctx: inout GraphicsContext) {
        guard let first = w.points.first else { return }
        var leaf = Path()
        leaf.move(to: first)
        for q in w.points.dropFirst() { leaf.addLine(to: q) }
        leaf.closeSubpath()
        let a = w.alpha * (0.45 + 0.55 * w.face)        // edge-on wings go thin and see-through, like glass turning
        ctx.fill(leaf, with: .linearGradient(Gradient(colors: [DropMath.hsl(h, 0.9, 0.8, 0.9 * a),
                                                               DropMath.hsl(h + 25, 0.95, 0.93, 0.28 * a)]),
                                             startPoint: w.root, endPoint: w.tip))
        ctx.stroke(leaf, with: .color(DropMath.hsl(h, 1, 0.96, (0.35 + 0.5 * (1 - w.face)) * w.alpha)), lineWidth: 1.3 * k)
        var rib = Path()
        rib.move(to: w.root)
        rib.addQuadCurve(to: w.tip, control: w.rib)
        ctx.stroke(rib, with: .color(DropMath.hsl(h, 1, 0.97, 0.4 * w.alpha)), lineWidth: k)
    }

    /// One eye, drawn upright and then placed on the ball (`place` squashes it towards the edge). Old-game swaps:
    /// asleep and blink are lines, happy is an arch, dizzy a spiral, surprised a round eye.
    nonisolated static func eye(_ face: PipFace, r: Double, k: CGFloat, spin: Double, hue h: Double,
                    place: CGAffineTransform, in ctx: inout GraphicsContext) {
        let ink = DropMath.hsl(h + 40, 0.45, 0.13)
        let ew = r * 0.1, eh = r * 0.15                 // half width and height of an open eye
        let line = CGFloat(max(1.2, r * 0.07))
        func oval(_ w: Double, _ hh: Double, dy: Double = 0) -> Path {
            Path(ellipseIn: CGRect(x: -w, y: -hh + dy, width: w * 2, height: hh * 2))
        }
        var shine = true
        switch face {
        case .asleep, .blink:
            ctx.fill(Path(roundedRect: CGRect(x: -ew, y: -Double(line) / 2, width: ew * 2, height: Double(line)),
                          cornerRadius: line / 2).applying(place), with: .color(ink))
            shine = false
        case .sleepy:
            ctx.fill(oval(ew, eh * 0.4, dy: eh * 0.3).applying(place), with: .color(ink))
            shine = false
        case .happy:
            var arch = Path()
            arch.move(to: CGPoint(x: -ew, y: eh * 0.35))
            arch.addQuadCurve(to: CGPoint(x: ew, y: eh * 0.35), control: CGPoint(x: 0, y: -eh * 0.9))
            ctx.stroke(arch.applying(place), with: .color(ink),
                       style: StrokeStyle(lineWidth: line, lineCap: .round))
            shine = false
        case .dizzy:
            var curl = Path()
            let turns = 2.0, n = 28
            for i in 0...n {
                let s = Double(i) / Double(n)
                let an = s * turns * Double.pi * 2 + spin * Double.pi * 2
                let rr = eh * s
                let q = CGPoint(x: cos(an) * rr, y: sin(an) * rr)
                if i == 0 { curl.move(to: q) } else { curl.addLine(to: q) }
            }
            ctx.stroke(curl.applying(place), with: .color(ink), style: StrokeStyle(lineWidth: line * 0.8, lineCap: .round))
            shine = false
        case .surprised:
            ctx.fill(oval(eh * 0.95, eh * 0.95).applying(place), with: .color(ink))
        case .held:
            ctx.fill(oval(ew * 1.15, eh * 1.1).applying(place), with: .color(ink))
        default:
            ctx.fill(oval(ew, eh).applying(place), with: .color(ink))
        }
        if shine {
            let s = ew * 0.55
            ctx.fill(Path(ellipseIn: CGRect(x: -ew * 0.35 - s / 2, y: -eh * 0.4 - s / 2, width: s, height: s)).applying(place),
                     with: .color(.white.opacity(0.95)))
        }
    }
}
