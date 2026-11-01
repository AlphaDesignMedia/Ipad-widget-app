import SwiftUI
import simd

// PIP LOOKS · Blobby (V2), Aaron 1 Nov 2026 ("maybe v2 is blobby pip"). Part of Pip Looks, in its own file so that
// one stays short.
// Vectors in a pretend 3D space, like the old games (Aaron, 1 Nov: "drawing him in vectors and adding the effects over
// the vectors … keeping the lighting as a mock effect"; "the glass effect is impossible on a 3D object", not on this
// character). Each frame, Aaron's pipeline:
//   1. his skeleton in 3D (Aaron's final settings): a head, ten trailing circles, two leaf wings;
//   2. flattened into a soft black-and-white silhouette: body, front wing, back wing (BlobbyGlass.metal reads it);
//   3. the glass shader: roundness, a rim of light (the inner glow), a highlight from the top left that never moves,
//      a warm bounce, the tail fading out like a shadow; Apple's own glass under his body bends what's behind;
//   4. a glass emoji inside him (less colour, bent by the ball), his face painted on top, sinking into the emoji.
// He swings round on a spring, faces the way he's moving, his tail lags and wags, his flap takes effort when he
// climbs (each down-stroke lifts him). Vectors, not pictures, so later he can morph (Aaron's skeuomorphism idea).
// The web model, for tuning: app/design/pip-vector.html (public page "Pip · vector (2.5D)"). Keep the two in step.
// Made up by Jules (Aaron to judge): the spring, the painted colours, the tilt when climbing or diving.

// MARK: Data

enum BlobbyPicks {
    static let circles = 10
    static let length = 2.65, curl = 0.3, taper = 1.2, slope = 0.32         // Aaron's final settings, 1 Nov
    /// The two leaves, as drawn over the side view: side, angle above the back line (degrees), length (head-radii).
    static let wings: [(side: Double, deg: Double, len: Double)] = [(1, 62, 2.8), (-1, 44, 3.3)]
    static let leafStops: [Double] = [0, 0.25, 0.5, 0.76, 1]
    static let leafWidths: [Double] = [0.07, 0.34, 0.4, 0.26, 0.03]
    static let restTurn = 45.0, flyTurn = 70.0      // degrees round from facing you: at rest (three-quarter), flying
    static let camera = 8.0                         // head-radii away: how strong the perspective is

    /// The emoji the Looks card offers (Pip's Emotes favourites plus a heart). Any emoji works.
    static let emoji = ["⭐", "❤️", "💙", "✨", "😊", "😂", "💤"]

    /// A face emoji: he turns to look at you while it's in.
    static func isFace(_ e: String) -> Bool {
        guard let v = e.unicodeScalars.first?.value else { return false }
        return v == 0x263A || (0x1F600...0x1F644).contains(v) || (0x1F910...0x1F92F).contains(v)
            || (0x1F970...0x1F97A).contains(v) || v == 0x1F9D0 || (0x1FAE0...0x1FAE8).contains(v)
    }

    /// The emoji moment: comes in (0.3 s, a little overshoot), stays 2.5 s, goes (0.6 s). nil `at`: it stays.
    static func moment(at: Double?, time: Double, simpler: Bool) -> (vis: Double, pop: Double) {
        guard let at else { return (1, 1) }
        let since = time - at
        if since < 0 { return (0, 1) }
        if since < 0.3 { let v = since / 0.3; return (v, simpler ? 1 : 0.6 + 0.4 * sin(v * Double.pi / 2) * 1.08) }
        if since < 2.8 { return (1, 1) }
        if since < 3.4 { return (1 - (since - 2.8) / 0.6, 1) }
        return (0, 1)
    }
}

/// Pip's latest emote (from the `pip.emote` channel: Pip's Emotes or any plugin), shown inside Blobby for a moment.
@MainActor enum BlobbyEmote {
    static var last: (emoji: String, at: Double)? = nil
    private static var token: NSObjectProtocol? = nil

    static func listen() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = NotificationCenter.default.addObserver(forName: PipEmotes.channel, object: nil, queue: .main) { note in
            guard let e = note.object as? String, !e.isEmpty else { return }
            let now = Date().timeIntervalSinceReferenceDate
            MainActor.assumeIsolated { last = (e, now) }
        }
    }
}

// MARK: Logic (the skeleton in 3D, flattened each frame)

typealias BV3 = SIMD3<Double>

private func bNorm(_ v: BV3) -> BV3 { let l = simd_length(v); return l > 0 ? v / l : v }
private func bTurn(_ v: BV3, _ ax: BV3, _ a: Double) -> BV3 {
    let c = cos(a), s = sin(a)
    return v * c + simd_cross(ax, v) * s + ax * simd_dot(v, ax) * (1 - c)
}

/// One frame of Pip, flattened: everything in points, relative to the centre of his head (y down).
struct BlobbyFrame {
    struct Circle { var at: CGPoint; var r: CGFloat }
    struct Wing { var circles: [Circle]; var depth: Double; var back: Bool }
    var tail: [Circle] = []
    var wings: [Wing] = []
    /// Where his eyes and mouth are on the ball (x, y in head-radii, y down; z > 0: on the side facing you).
    var eyes: [BV3] = []
    var mouth: BV3 = .zero
    /// How far a wing beat lifts him this frame (points, up is negative).
    var lift: CGFloat = 0
}

/// Pip's body in motion: which way he faces (a soft spring, so he swings round with some weight), his tail (lags
/// behind as he moves) and his wing beat (effort). One per Pip on screen.
final class BlobbyRig {
    static let live = BlobbyRig()           // the one the core's Pip uses
    private(set) var yaw = BlobbyPicks.restTurn
    private var yawV = 0.0
    private var tail: [BV3] = []
    private var last: CGPoint? = nil
    private var lastT = 0.0
    private var vx = 0.0, vy = 0.0
    private var phase = 0.0, effort = 0.0

    /// pos: where his head is (points, any fixed space); r: head radius (points); target: -1 left, 1 right, 0 no
    /// preference (he keeps his side); toYou: 0…1, how much he turns to look at you (a face emoji).
    func step(pos: CGPoint, r: CGFloat, time t: Double, target: Double, toYou: Double, simpler: Bool) -> BlobbyFrame {
        let dt: Double = lastT == 0 ? 1.0 / 60 : min(0.05, max(0, t - lastT))
        lastT = t
        if let q = last, dt > 0 {
            vx += ((pos.x - q.x) / dt - vx) * min(1, dt * 10)
            vy += ((pos.y - q.y) / dt - vy) * min(1, dt * 10)
        }
        last = pos
        let rr = Double(max(r, 1))
        // facing: towards the way he's moving, else the side asked for, else the side he's on
        let moving: Double = abs(vx) > 40 ? (vx > 0 ? 1 : -1) : 0
        let side: Double = moving != 0 ? moving : (target != 0 ? target : (yaw >= 0 ? 1 : -1))
        let want = side * (moving != 0 ? BlobbyPicks.flyTurn : BlobbyPicks.restTurn) * (1 - toYou)
        if simpler { yaw = want; yawV = 0 } else {
            yawV += ((want - yaw) * 60 - yawV * 11) * dt
            yaw += yawV * dt
        }
        // effort (Aaron: "weight and effort in his wing flap"): flying is work, climbing is hard work
        let speed2: Double = vx * vx + vy * vy
        let flying: Double = min(1, speed2.squareRoot() / 120)
        let climbing = max(0, min(1, -vy / 260))
        effort += (max(flying * 0.5, climbing) - effort) * min(1, dt * 4)
        let beat: Double = (4.5 + 4.5 * flying) * (1 - 0.35 * climbing)
        if !simpler { phase += beat * dt }
        let amp: Double = simpler ? 0 : 0.2 + 0.3 * flying + 0.3 * climbing
        var f = BlobbyFrame()
        let liftAmount: Double = rr * (0.03 + 0.09 * effort)
        f.lift = simpler ? 0 : CGFloat(-sin(phase) * liftAmount)

        let a = yaw * Double.pi / 180
        let tilt = simpler ? 0 : max(-0.35, min(0.35, vy / 1400))       // nose up climbing, down diving
        let faceY: Double = -0.05 - tilt
        let face = bNorm(BV3(sin(a), faceY, cos(a)))
        let sideV = bNorm(simd_cross(BV3(0, 1, 0), face)), up = bNorm(simd_cross(face, sideV))
        let head = BV3(Double(pos.x) / rr, -Double(pos.y) / rr, 0)
        let front = max(0, cos(a) - 0.5) * 2                              // 1 when he faces you

        // the tail: held behind and below, curled, lagging (liquid weight); facing you it peeks out with a tiny wag
        let n = BlobbyPicks.circles
        if tail.count != n {
            tail = (0..<n).map { (i: Int) -> BV3 in
                let k = Double(i + 1)
                let off = BV3(-0.26, -0.08, -0.1) * k
                return head + off
            }
        }
        let back = bNorm(BV3(-face.x, -face.y - BlobbyPicks.slope, -face.z))
        let gap = BlobbyPicks.length / Double(n)
        let lag: Double = simpler ? 0 : pow(0.1, dt * 60)
        var prev = head
        for i in 0..<n {
            let k = Double(i + 1) / Double(n)
            let wave: Double = sin(t * 2.4 - Double(i) * 0.5)
            let wag: Double = simpler ? 0 : front * wave * 0.12 * k
            let curled: BV3 = bTurn(back, sideV, -BlobbyPicks.curl * 0.9 * k)
            let rest = bNorm(curled + sideV * wag)
            let was: BV3 = bNorm(tail[i] - prev)
            let d = bNorm(was * 0.15 + rest * 0.85)
            let goal = prev + d * gap
            tail[i] += (goal - tail[i]) * (1 - lag)
            prev = tail[i]
        }

        // flatten: a simple camera, so further away is smaller
        func flat(_ p: BV3) -> (CGPoint, Double) {
            let s = BlobbyPicks.camera / (BlobbyPicks.camera - (p.z - head.z))
            return (CGPoint(x: (p.x - head.x) * rr * s, y: -(p.y - head.y) * rr * s), s)
        }
        for i in 0..<n {
            let (pt, s) = flat(tail[i])
            let rad = max(0.06, pow(1 - Double(i + 1) / Double(n + 1), BlobbyPicks.taper))
            f.tail.append(.init(at: pt, r: CGFloat(rad * rr * s)))
        }

        // the wings: two leaves from the crown, apart at the root and splayed so they never cross, flapping together
        let backV = -face
        let crown = head + up * 0.93 - face * 0.12
        let sweep = min(0.35, abs(vx) / rr * 0.02)
        let tall = 1 + 0.15 * max(0, cos(a))                              // a touch taller seen from the front
        for w in BlobbyPicks.wings {
            let root = crown + sideV * (w.side * 0.3)
            let pitch = w.deg * Double.pi / 180 - sweep
            let lean: BV3 = backV * cos(pitch) + up * sin(pitch)
            let dir = bNorm(lean + sideV * (w.side * 0.42))
            let nrm = bNorm(simd_cross(dir, backV))
            let thin = max(0.6, abs(nrm.z))                                  // keeps some width from the front (Aaron)
            var pts: [BV3] = [root]
            for j in 1..<BlobbyPicks.leafStops.count {
                let st = BlobbyPicks.leafStops[j]
                let lagBehind: Double = w.side > 0 ? 0 : 0.3
                let flutter: Double = amp * (sin(phase - st * 0.9 + lagBehind) * 0.8 + 0.2)
                var seg = bTurn(dir, nrm, 0.28 * st - 0.14)
                seg = bNorm(bTurn(seg, backV, w.side * flutter))
                let stepLen: Double = w.len * tall * (st - BlobbyPicks.leafStops[j - 1])
                pts.append(pts[j - 1] + seg * stepLen)
            }
            let circles: [BlobbyFrame.Circle] = pts.enumerated().map { j, p in
                let (pt, s) = flat(p)
                let wide: Double = max(0.6 / rr, BlobbyPicks.leafWidths[j] * thin)
                return .init(at: pt, r: CGFloat(wide * rr * s))
            }
            f.wings.append(.init(circles: circles, depth: pts[3].z - head.z, back: false))
        }
        if f.wings.count == 2 { f.wings[f.wings[0].depth < f.wings[1].depth ? 0 : 1].back = true }

        // the face, painted on the ball where it points
        func onHead(_ s: Double, _ u: Double) -> BV3 { let v = bNorm(face + sideV * s + up * u); return BV3(v.x, -v.y, v.z) }
        f.eyes = [onHead(-0.3, -0.32), onHead(0.3, -0.32)]
        f.mouth = onHead(0, -0.62)
        return f
    }
}

// MARK: Shapes (circles joined by tangent lines, all wound the same way, so the overlaps fill as one)

enum BlobbyPaths {
    /// A circle as four curves, wound the same way as the joins below.
    static func circle(_ p: inout Path, _ c: CGPoint, _ r: CGFloat) {
        let k: CGFloat = 0.5523 * r
        p.move(to: CGPoint(x: c.x + r, y: c.y))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + r), control1: CGPoint(x: c.x + r, y: c.y + k), control2: CGPoint(x: c.x + k, y: c.y + r))
        p.addCurve(to: CGPoint(x: c.x - r, y: c.y), control1: CGPoint(x: c.x - k, y: c.y + r), control2: CGPoint(x: c.x - r, y: c.y + k))
        p.addCurve(to: CGPoint(x: c.x, y: c.y - r), control1: CGPoint(x: c.x - r, y: c.y - k), control2: CGPoint(x: c.x - k, y: c.y - r))
        p.addCurve(to: CGPoint(x: c.x + r, y: c.y), control1: CGPoint(x: c.x + k, y: c.y - r), control2: CGPoint(x: c.x + r, y: c.y - k))
        p.closeSubpath()
    }

    /// Two circles joined by their outer tangent lines (Aaron's hull of circles).
    static func hull(_ p: inout Path, _ a: CGPoint, _ ra: CGFloat, _ b: CGPoint, _ rb: CGFloat) {
        circle(&p, a, ra)
        circle(&p, b, rb)
        let dx = b.x - a.x, dy = b.y - a.y
        let d = (dx * dx + dy * dy).squareRoot()
        guard d > abs(ra - rb) + 0.01 else { return }
        let ux = dx / d, uy = dy / d, c = (ra - rb) / d, s = max(0, 1 - c * c).squareRoot()
        let n1 = CGPoint(x: ux * c - uy * s, y: uy * c + ux * s), n2 = CGPoint(x: ux * c + uy * s, y: uy * c - ux * s)
        var q = [CGPoint(x: a.x + n1.x * ra, y: a.y + n1.y * ra), CGPoint(x: b.x + n1.x * rb, y: b.y + n1.y * rb),
                 CGPoint(x: b.x + n2.x * rb, y: b.y + n2.y * rb), CGPoint(x: a.x + n2.x * ra, y: a.y + n2.y * ra)]
        var area: CGFloat = 0                                                // same winding as the circles
        for i in 0..<4 { let u = q[i], v = q[(i + 1) % 4]; area += u.x * v.y - v.x * u.y }
        if area < 0 { q.reverse() }
        p.move(to: q[0]); p.addLine(to: q[1]); p.addLine(to: q[2]); p.addLine(to: q[3]); p.closeSubpath()
    }

    static func body(_ f: BlobbyFrame, r: CGFloat) -> Path {
        var p = Path()
        circle(&p, .zero, r)
        var prev = BlobbyFrame.Circle(at: .zero, r: r)
        for c in f.tail { hull(&p, prev.at, prev.r, c.at, c.r); prev = c }
        return p
    }

    static func wing(_ w: BlobbyFrame.Wing) -> Path {
        var p = Path()
        for j in 1..<w.circles.count { hull(&p, w.circles[j - 1].at, w.circles[j - 1].r, w.circles[j].at, w.circles[j].r) }
        return p
    }
}

/// A stored path, centred in whatever frame it's given (for Apple's glass).
struct BlobbyShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path.offsetBy(dx: rect.midX, dy: rect.midY) }
}

// MARK: Views

/// Pip in the Blobby look, centred on his head in a frame 8 × the head radius. Pure: same frame, same picture.
struct PipBlobbyBody: View {
    var radius: CGFloat = 12
    var frame: BlobbyFrame
    var time: Double = 0
    var face: PipFace = .awake
    var emoji: String? = nil
    var emojiAt: Double? = nil
    var simpler: Bool = false
    var halo: Color = PipLook.glow

    var body: some View {
        let r = radius
        let box: CGFloat = r * 8
        let mid = CGPoint(x: box / 2, y: box / 2)
        let bodyPath = BlobbyPaths.body(frame, r: r)
        let m = BlobbyPicks.moment(at: emojiAt, time: time, simpler: simpler)
        let shown: String? = m.vis > 0.01 ? emoji : nil
        let e = m.vis * m.vis * (3 - 2 * m.vis)                               // eased
        let tip = frame.tail.last?.at ?? .zero
        let k: CGFloat = max(1.5, r * 0.15)                                     // how far the shader looks for the slope
        ZStack {
            // the glow, on the room
            Circle()
                .fill(RadialGradient(colors: [halo.opacity(0.22), halo.opacity(0)], center: .center, startRadius: 0, endRadius: r * 2.3))
                .frame(width: r * 4.6, height: r * 4.6)
            // Apple's glass in his body's shape: what's behind him really bends
            Color.clear.glassEffect(.clear, in: BlobbyShape(path: bodyPath))
            // a glass emoji inside him: less colour, bent by the ball, arriving sharp from soft (Apple: materialise)
            if let em = shown {
                Text(em)
                    .font(.system(size: r * 1.0))
                    .scaleEffect(CGFloat((0.5 + 0.5 * e) * m.pop))
                    .saturation(0.6)
                    .opacity(min(1, m.vis * 1.5) * 0.85)
                    .blur(radius: simpler ? 0 : CGFloat(1 - e) * r * 0.25)
                    .offset(y: r * 0.08)
                    .frame(width: box, height: box)
                    .distortionEffect(ShaderLibrary.blobbyLens(.float2(mid), .float(r * 0.95), .float(0.25)),
                                      maxSampleOffset: CGSize(width: r, height: r))
                    .mask(Circle().frame(width: r * 1.92, height: r * 1.92))
            }
            // his silhouette, softened, through the glass shader
            Canvas { ctx, size in
                ctx.addFilter(.blur(radius: r * 0.12))
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.blendMode = .plusLighter
                ctx.fill(bodyPath, with: .color(Color(red: 1, green: 0, blue: 0)))
                for w in frame.wings {
                    ctx.fill(BlobbyPaths.wing(w), with: .color(w.back ? Color(red: 0, green: 0, blue: 1) : Color(red: 0, green: 1, blue: 0)))
                }
            }
            .frame(width: box, height: box)
            .layerEffect(ShaderLibrary.blobbyGlass(.float2(mid), .float(r),
                                                   .float2(CGPoint(x: mid.x + tip.x, y: mid.y + tip.y)), .float(k)),
                         maxSampleOffset: CGSize(width: k, height: k))
            // his face on top, sinking into the emoji while one is in
            Canvas { ctx, size in
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                paintFace(&ctx, sink: shown == nil ? 0 : e)
            }
            .frame(width: box, height: box)
        }
        .frame(width: box, height: box)
        .offset(y: frame.lift)
        .accessibilityHidden(true)
    }

    private func paintFace(_ ctx: inout GraphicsContext, sink e: Double) {
        let r = radius
        let alpha = 1 - e
        guard alpha > 0.02 else { return }
        let to = CGPoint(x: 0, y: r * 0.1)
        func at(_ v: BV3) -> CGPoint {
            let p = CGPoint(x: CGFloat(v.x) * r, y: CGFloat(v.y) * r)
            return CGPoint(x: p.x + (to.x - p.x) * CGFloat(e), y: p.y + (to.y - p.y) * CGFloat(e))
        }
        let shrink = CGFloat(1 - e * 0.7)
        let closed = face == .blink || face == .asleep || face == .sleepy
        for v in frame.eyes where v.z > 0.05 {
            ctx.drawLayer { l in
                l.opacity = alpha * min(1, v.z * 4)
                let p = at(v)
                l.translateBy(x: p.x, y: p.y)
                l.scaleBy(x: CGFloat(max(0.25, v.z)) * shrink, y: shrink)
                let h: CGFloat = closed ? r * 0.04 : r * 0.155
                l.fill(Path(ellipseIn: CGRect(x: -r * 0.1, y: -h, width: r * 0.2, height: h * 2)), with: .color(PipLook.eye))
            }
        }
        let mo = frame.mouth
        guard mo.z > 0.1 else { return }
        ctx.drawLayer { l in
            l.opacity = alpha * min(1, mo.z * 3)
            let p = at(mo)
            l.translateBy(x: p.x, y: p.y)
            l.scaleBy(x: CGFloat(max(0.3, mo.z)) * shrink, y: shrink)
            var path = Path()
            switch face {
            case .surprised, .dizzy:
                path.addEllipse(in: CGRect(x: -r * 0.06, y: -r * 0.07, width: r * 0.12, height: r * 0.14))
            case .asleep, .sleepy:
                break
            default:
                path.move(to: CGPoint(x: -r * 0.12, y: 0))
                path.addQuadCurve(to: CGPoint(x: r * 0.12, y: 0), control: CGPoint(x: 0, y: r * 0.1))
            }
            l.stroke(path, with: .color(PipLook.eye), style: StrokeStyle(lineWidth: max(0.8, r * 0.05), lineCap: .round))
        }
    }
}
