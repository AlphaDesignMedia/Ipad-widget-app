import SwiftUI

// PIP LOOKS · Blobby (V2), Aaron 1 Nov 2026 ("maybe v2 is blobby pip"). Part of Pip Looks, in its own file so that
// one stays short.
// Aaron's drawings first, in his simple shapes: a head circle with ten trailing circles joined by tangent lines (his
// baseline: tip 3.4 head-radii long, taper 1.9, curl -0.7, the back sloping down, Sheets A and B), two leaf wings from
// the top of the head (his overlay: 62° and 44°), tall low eyes, a small smile.
// Made of Apple's own Liquid Glass, so the system does the bending; body and wings sit in one glass container so they
// melt together (his blobby neck). Cheap on purpose (Aaron: "lets not make him super expensive to run"): the shapes
// are worked out once per size and kept; no shaders.
// Inside him, a real emoji (Apple's) under the glass: it floats in the middle of his head and faces you; a face emoji
// is his face instead, and his eyes step aside (Aaron, 1 Nov: one treatment for every emoji).
// Made up by Jules (Aaron to judge): the wings' flutter, the glow, how he turns round.
// The browser version, for tuning: app/design/pip-3d.html (public page "Pip 3D · trailing circles").

// MARK: Data

enum BlobbyPicks {
    static let circles = 10
    static let length = 3.4, taper = 1.9, curl = -0.7, slope = 0.32
    /// The two leaves, as drawn over the side view: angle above the back line (degrees), length (head-radii).
    static let wings: [(deg: Double, len: Double)] = [(62, 2.8), (44, 3.3)]
    static let leafStops: [Double] = [0, 0.25, 0.5, 0.76, 1]
    static let leafWidths: [Double] = [0.07, 0.34, 0.4, 0.26, 0.03]
    /// Where the wings start, in head-radii, facing right (y down).
    static let crown = CGPoint(x: -0.12, y: -0.93)
    /// The emoji the Looks card offers (Pip's Emotes favourites plus a heart). Any emoji works.
    static let emoji = ["❤️", "💙", "✨", "⭐", "😊", "😂", "💤"]

    /// A face emoji becomes his face; anything else floats in the middle of his head.
    static func isFace(_ e: String) -> Bool {
        guard let v = e.unicodeScalars.first?.value else { return false }
        return v == 0x263A || (0x1F600...0x1F644).contains(v) || (0x1F910...0x1F92F).contains(v)
            || (0x1F970...0x1F97A).contains(v) || v == 0x1F9D0 || (0x1FAE0...0x1FAE8).contains(v)
    }
}

// MARK: Logic (shapes, worked out once per size)

/// Pip's outline in Pip's own space (head centre at 0,0, facing right, y down), from circles joined by tangent lines.
struct BlobbyShapes {
    let body: Path
    let wings: [Path]

    @MainActor private static var kept: [CGFloat: BlobbyShapes] = [:]

    @MainActor static func at(_ r: CGFloat) -> BlobbyShapes {
        if let s = kept[r] { return s }
        let s = BlobbyShapes(body: makeBody(r), wings: BlobbyPicks.wings.map { makeWing(r, deg: $0.deg, len: $0.len) })
        kept[r] = s
        return s
    }

    /// Two circles joined by their outer tangent lines (Aaron's hull of circles).
    static func hull(_ a: CGPoint, _ ra: CGFloat, _ b: CGPoint, _ rb: CGFloat) -> Path {
        let ca = Path(ellipseIn: CGRect(x: a.x - ra, y: a.y - ra, width: ra * 2, height: ra * 2))
        let cb = Path(ellipseIn: CGRect(x: b.x - rb, y: b.y - rb, width: rb * 2, height: rb * 2))
        let both = ca.union(cb)
        let dx: CGFloat = b.x - a.x, dy: CGFloat = b.y - a.y
        let d: CGFloat = (dx * dx + dy * dy).squareRoot()
        guard d > abs(ra - rb) + 0.001 else { return both }
        let ux: CGFloat = dx / d, uy: CGFloat = dy / d
        let c: CGFloat = (ra - rb) / d
        let s: CGFloat = max(0, 1 - c * c).squareRoot()
        let n1 = CGPoint(x: ux * c - uy * s, y: uy * c + ux * s)
        let n2 = CGPoint(x: ux * c + uy * s, y: uy * c - ux * s)
        var q = Path()
        q.move(to: CGPoint(x: a.x + n1.x * ra, y: a.y + n1.y * ra))
        q.addLine(to: CGPoint(x: b.x + n1.x * rb, y: b.y + n1.y * rb))
        q.addLine(to: CGPoint(x: b.x + n2.x * rb, y: b.y + n2.y * rb))
        q.addLine(to: CGPoint(x: a.x + n2.x * ra, y: a.y + n2.y * ra))
        q.closeSubpath()
        return both.union(q)
    }

    static func turn(_ v: CGVector, _ a: Double) -> CGVector {
        let c = CGFloat(cos(a)), s = CGFloat(sin(a))
        return CGVector(dx: v.dx * c - v.dy * s, dy: v.dx * s + v.dy * c)
    }

    /// The head and its trailing circles: behind and sloping down, the tip turning up (curl), as drawn.
    static func makeBody(_ r: CGFloat) -> Path {
        let n = BlobbyPicks.circles
        let gap: CGFloat = r * CGFloat(BlobbyPicks.length) / CGFloat(n)
        let sl = CGFloat(BlobbyPicks.slope)
        let l: CGFloat = (1 + sl * sl).squareRoot()
        let back = CGVector(dx: -1 / l, dy: sl / l)
        var prev = CGPoint.zero
        var prevR = r
        var path = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        for i in 0..<n {
            let k = Double(i + 1) / Double(n)
            let dir = turn(back, -BlobbyPicks.curl * 0.9 * k)                 // − curl turns the tip up
            let p = CGPoint(x: prev.x + dir.dx * gap, y: prev.y + dir.dy * gap)
            let shrink = pow(1 - Double(i + 1) / Double(n + 1), BlobbyPicks.taper)
            let rr: CGFloat = r * CGFloat(max(0.06, shrink))
            path = path.union(hull(prev, prevR, p, rr))
            prev = p
            prevR = rr
        }
        return path
    }

    /// A leaf: five circles from the crown, joined by tangent lines, gently bowed, with a pointed tip.
    static func makeWing(_ r: CGFloat, deg: Double, len: Double) -> Path {
        let root = CGPoint(x: BlobbyPicks.crown.x * r, y: BlobbyPicks.crown.y * r)
        let a = deg * Double.pi / 180
        let dir = CGVector(dx: CGFloat(-cos(a)), dy: CGFloat(-sin(a)))       // up and back from the crown
        let stops = BlobbyPicks.leafStops, wide = BlobbyPicks.leafWidths
        var pts: [CGPoint] = [root]
        for j in 1..<stops.count {
            let seg = turn(dir, -(0.28 * stops[j] - 0.14))
            let step: CGFloat = r * CGFloat(len * (stops[j] - stops[j - 1]))
            let last = pts[j - 1]
            pts.append(CGPoint(x: last.x + seg.dx * step, y: last.y + seg.dy * step))
        }
        var path = Path()
        for j in 1..<pts.count {
            path = path.union(hull(pts[j - 1], r * CGFloat(wide[j - 1]), pts[j], r * CGFloat(wide[j])))
        }
        return path
    }
}

/// Which way he faces (1 right, -1 left), easing through 0 as he turns round, towards where he's looking.
final class BlobbyTurn {
    static let live = BlobbyTurn()          // the one the core's Pip uses
    private var facing: Double = 1
    private var last: Double = 0

    func step(look: CGSize, at t: Double, snap: Bool) -> Double {
        let target: Double = look.width < -0.15 ? -1 : (look.width > 0.15 ? 1 : (facing >= 0 ? 1 : -1))
        let dt: Double = last == 0 ? 0 : min(0.1, max(0, t - last))
        last = t
        if snap { facing = target } else { facing += (target - facing) * min(1, dt * 7) }
        return facing
    }
}

/// Draws a stored path, centred in whatever frame it's given.
struct BlobbyShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path.offsetBy(dx: rect.midX, dy: rect.midY) }
}

// MARK: Views

/// Pip in the Blobby look, centred in a frame 8 × the head radius (room for the tail, wings and glow).
/// Pure: same inputs, same picture.
struct PipBlobbyBody: View {
    var radius: CGFloat = 12
    var time: Double = 0
    var face: PipFace = .awake
    var look: CGSize = .zero
    var facing: Double = 1
    var emoji: String? = nil
    var simpler: Bool = false
    var flapping: Bool = false
    var halo: Color = PipLook.glow

    var body: some View {
        let r = radius
        let box: CGFloat = r * 8
        let shapes = BlobbyShapes.at(r)
        let t: Double = simpler ? 0 : time
        let side = CGFloat(facing)
        let faceEmoji: Bool = emoji.map(BlobbyPicks.isFace) ?? false
        let anchor = UnitPoint(x: 0.5 + BlobbyPicks.crown.x * r / box, y: 0.5 + BlobbyPicks.crown.y * r / box)
        ZStack {
            // his glow, under everything
            BlobbyShape(path: shapes.body).fill(halo.opacity(0.35)).blur(radius: r * 0.45)
                .scaleEffect(x: side, y: 1)
            // the emoji, under the glass, so the glass bends it
            if let e = emoji { emojiView(e, isFace: faceEmoji, t: t, side: side) }
            // the glass: one container, so body and wings melt together
            GlassEffectContainer(spacing: r * 0.3) {
                ZStack {
                    Color.clear.glassEffect(.clear, in: BlobbyShape(path: shapes.body))
                    ForEach(0..<shapes.wings.count, id: \.self) { i in
                        Color.clear.glassEffect(.clear, in: BlobbyShape(path: shapes.wings[i]))
                            .rotationEffect(.radians(flutter(i, t)), anchor: anchor)
                    }
                }
            }
            .scaleEffect(x: side, y: 1)
            // a fine bright rim
            BlobbyShape(path: shapes.body).stroke(halo.opacity(0.55), lineWidth: max(0.6, r * 0.05))
                .scaleEffect(x: side, y: 1)
            if !faceEmoji { BlobbyFace(face: face, r: r, look: look).scaleEffect(x: side, y: 1) }
        }
        .frame(width: box, height: box)
        .accessibilityHidden(true)
    }

    /// Flutter, small: quicker when he flies.
    private func flutter(_ i: Int, _ t: Double) -> Double {
        if simpler { return 0 }
        let beat: Double = flapping ? 8 : 3, amp: Double = flapping ? 0.2 : 0.06
        return amp * sin(t * beat - Double(i) * 1.1)
    }

    /// Floats in the middle of his head, a touch high (Aaron's drawing, 1 Nov), facing you, breathing softly;
    /// a face emoji sits on the front of his head, as his face.
    private func emojiView(_ e: String, isFace: Bool, t: Double, side: CGFloat) -> some View {
        let r = radius
        let drift: CGFloat = isFace ? 0.3 : 1
        let dx = CGFloat(sin(t * 0.7) * 0.05) * r * drift
        let dy = CGFloat(sin(t * 1.1 + 1) * 0.06) * r * drift
        let spot = isFace ? CGPoint(x: 0.36 * r * side, y: 0.08 * r) : CGPoint(x: 0, y: -0.1 * r)
        let pulse = CGFloat(1 + 0.04 * (0.5 + 0.5 * sin(t * 2.2)))
        return Text(e)
            .font(.system(size: r * (isFace ? 0.95 : 0.9)))
            .scaleEffect(pulse)
            .rotationEffect(.radians(simpler ? 0 : sin(t * 0.8) * 0.06))
            .offset(x: spot.x + dx, y: spot.y + dy)
    }
}

/// Tall oval eyes, set close and a little low (the drawings), seen three-quarter; a small smile or an "o".
struct BlobbyFace: View {
    let face: PipFace
    let r: CGFloat
    let look: CGSize

    var body: some View {
        let closed: Bool = face == .blink || face == .asleep || face == .sleepy
        let lx: CGFloat = look.width * r * 0.06, ly: CGFloat = look.height * r * 0.06
        let eyeH: CGFloat = closed ? r * 0.06 : r * 0.31
        ZStack {
            Ellipse().fill(PipLook.eye).frame(width: r * 0.2, height: eyeH).offset(x: r * 0.5 + lx, y: r * 0.29 + ly)
            Ellipse().fill(PipLook.eye).frame(width: r * 0.12, height: eyeH).offset(x: r * 0.85 + lx, y: r * 0.29 + ly)
            mouth.offset(x: r * 0.66 + lx, y: r * 0.56 + ly)
        }
    }

    @ViewBuilder private var mouth: some View {
        switch face {
        case .awake, .happy, .held:
            SmileCurve().stroke(PipLook.eye, style: StrokeStyle(lineWidth: max(0.8, r * 0.055), lineCap: .round))
                .frame(width: r * 0.24, height: r * 0.09)
        case .surprised, .dizzy:
            Ellipse().stroke(PipLook.eye, lineWidth: max(0.8, r * 0.05)).frame(width: r * 0.12, height: r * 0.14)
        default:
            EmptyView()
        }
    }
}

struct SmileCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
        return p
    }
}
