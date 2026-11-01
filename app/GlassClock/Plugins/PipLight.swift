import SwiftUI

// PIP'S LIGHT · plugin v1 (Dream) (Jules, 1 Nov). Pip glows, so the glass near them catches the light. Aaron: "the sun
// that's him lighting panels might have to be another plugin", "draw the lines and draw the idea of what the lighting
// will be, then create the core for the plugin agent that makes that light look beautiful", and "like the old games
// that only rendered what was in front of them: send out very basic rays to the closest panels, run them across the
// edges, and turn that into a slight fade on a line. For now."
// v1: old-game light. No shadows, no bounces, no blocking: only the panels within reach. Each edge that faces Pip is
// lit where Pip's reach crosses it, brightest at the nearest point and fading out along the edge. "Show the rays" in the
// card draws the rays too, to see the idea. The look (colour, bloom, glints) is for the next agent:
// nat/pip-light-brief.md. The maths (`PipLight.light`) is the core they build on; other plugins can call it.
// Where: the edges of the open panel, the open card and the plugin bar. Pip off or away: nothing. Nothing takes touches.
// Cost: a few lines in one Canvas, redrawn only when Pip moves. Simpler motion: the same (nothing animates by itself).

struct PipLight: SandboxPlugin {
    let info = PluginInfo(id: "piplight", name: "Pip's Light", version: "v1", shelf: .dream,
                          icon: "light.max", what: "Pip glows, so the edges of panels near them catch the light.")

    // MARK: Data

    /// One lit stretch of a panel's edge: from `a` to `b`, brightest at `peak`.
    struct Lit: Equatable {
        var a: CGPoint
        var b: CGPoint
        var peak: CGPoint
        /// 0…1: how strongly it's lit (nearer and more face-on is brighter).
        var strength: Double
    }

    /// How far Pip's light reaches, in Pip radii.
    static let reach: CGFloat = 9
    /// Warm white, like Blobby's glow.
    static let colour = Color(red: 1, green: 0.95, blue: 0.85)
    static let raysKey = "plug.piplight.rays"
    static let cornersKey = "plug.piplight.corners"

    /// Aaron's sliders (1 Nov: "lets experiment with sliders and values"). Each is name, key, range, start; the starts
    /// are v1's look. Saved when the finger lifts, so dragging doesn't write on every tick.
    struct Knob {
        let name: String
        let key: String
        let range: ClosedRange<Double>
        let start: Double
    }
    static let knobs: [Knob] = [
        Knob(name: "Reach", key: "plug.piplight.reach", range: 3...20, start: 9),          // in Pip radii
        Knob(name: "Strength", key: "plug.piplight.strength", range: 0...3, start: 1),
        Knob(name: "Spill width", key: "plug.piplight.spill", range: 0...14, start: 4),    // points
        Knob(name: "Edge width", key: "plug.piplight.edge", range: 0.5...4, start: 1.5),   // points
        Knob(name: "Falloff", key: "plug.piplight.falloff", range: 0.5...4, start: 2),     // 1 = even, higher = tighter
        Knob(name: "Warmth", key: "plug.piplight.warmth", range: 0...2, start: 1),         // 0 white, 1 v1, 2 golden
    ]

    /// White at 0, v1's warm white at 1, golden at 2.
    static func colour(warmth w: Double) -> Color {
        Color(red: 1, green: 1 - 0.05 * w, blue: 1 - 0.15 * w)
    }
    /// Rays drawn per lit edge when "Show the rays" is on.
    static let raysPerEdge = 5

    // MARK: Logic (the core)

    /// Old-game lighting. For each panel (frame and corner radius) within `reach` of `p`, each straight edge that faces
    /// `p` is lit where the circle of reach crosses it. Corners are left out, so the light stays on the straight parts.
    static func light(from p: CGPoint, panels: [(frame: CGRect, corner: CGFloat)], reach: CGFloat) -> [Lit] {
        var out: [Lit] = []
        for (frame, corner) in panels where !frame.isNull && !frame.isEmpty {
            guard frame.insetBy(dx: -reach, dy: -reach).contains(p) else { continue }
            let c = min(corner, frame.width / 2, frame.height / 2)
            // each edge: two ends, and the outward direction it faces
            let edges: [(CGPoint, CGPoint, CGVector)] = [
                (CGPoint(x: frame.minX + c, y: frame.minY), CGPoint(x: frame.maxX - c, y: frame.minY), CGVector(dx: 0, dy: -1)),
                (CGPoint(x: frame.minX + c, y: frame.maxY), CGPoint(x: frame.maxX - c, y: frame.maxY), CGVector(dx: 0, dy: 1)),
                (CGPoint(x: frame.minX, y: frame.minY + c), CGPoint(x: frame.minX, y: frame.maxY - c), CGVector(dx: -1, dy: 0)),
                (CGPoint(x: frame.maxX, y: frame.minY + c), CGPoint(x: frame.maxX, y: frame.maxY - c), CGVector(dx: 1, dy: 0)),
            ]
            for (e0, e1, n) in edges {
                // faces Pip? (Pip on the outside of this edge)
                let side = (p.x - e0.x) * n.dx + (p.y - e0.y) * n.dy
                guard side > 0 else { continue }
                // nearest point on the edge, and how far along it the reach goes either way
                let len = hypot(e1.x - e0.x, e1.y - e0.y)
                guard len > 1 else { continue }
                let ux = (e1.x - e0.x) / len, uy = (e1.y - e0.y) / len
                let t = (p.x - e0.x) * ux + (p.y - e0.y) * uy
                let d = side                                                    // distance to the edge's line
                guard d < reach else { continue }
                let half = (reach * reach - d * d).squareRoot()
                let from = max(0, t - half), to = min(len, t + half)
                guard to - from > 1 else { continue }
                let peakT = min(max(t, from), to)
                let nearest = hypot(p.x - (e0.x + ux * peakT), p.y - (e0.y + uy * peakT))
                let k = max(0, 1 - nearest / reach)
                out.append(Lit(a: CGPoint(x: e0.x + ux * from, y: e0.y + uy * from),
                               b: CGPoint(x: e0.x + ux * to, y: e0.y + uy * to),
                               peak: CGPoint(x: e0.x + ux * peakT, y: e0.y + uy * peakT),
                               strength: k * k))
            }
        }
        return out
    }

    /// "Wrap the corners" (step 1 of the pretty version): the part of a panel's rounded outline that faces `p`, straight
    /// edges and corners together, as one path. Light fades by distance from Pip, so it carries on round the corners
    /// without a seam. Each straight edge faces Pip or not; each corner faces Pip between the two points where Pip's
    /// line of sight just touches it.
    static func rim(from p: CGPoint, frame: CGRect, corner: CGFloat, reach: CGFloat) -> Path {
        var path = Path()
        guard !frame.isNull, !frame.isEmpty, frame.insetBy(dx: -reach, dy: -reach).contains(p) else { return path }
        let c = min(corner, frame.width / 2, frame.height / 2)
        // straight edges: two ends, and the outward direction it faces
        let edges: [(CGPoint, CGPoint, CGVector)] = [
            (CGPoint(x: frame.minX + c, y: frame.minY), CGPoint(x: frame.maxX - c, y: frame.minY), CGVector(dx: 0, dy: -1)),
            (CGPoint(x: frame.minX + c, y: frame.maxY), CGPoint(x: frame.maxX - c, y: frame.maxY), CGVector(dx: 0, dy: 1)),
            (CGPoint(x: frame.minX, y: frame.minY + c), CGPoint(x: frame.minX, y: frame.maxY - c), CGVector(dx: -1, dy: 0)),
            (CGPoint(x: frame.maxX, y: frame.minY + c), CGPoint(x: frame.maxX, y: frame.maxY - c), CGVector(dx: 1, dy: 0)),
        ]
        for (e0, e1, n) in edges where (p.x - e0.x) * n.dx + (p.y - e0.y) * n.dy > 0 && hypot(e1.x - e0.x, e1.y - e0.y) > 1 {
            path.move(to: e0)
            path.addLine(to: e1)
        }
        guard c > 1 else { return path }
        // corners: centre, and the middle of the quarter circle it covers (screen angles, y down)
        let corners: [(CGPoint, Double)] = [
            (CGPoint(x: frame.minX + c, y: frame.minY + c), -0.75 * .pi),
            (CGPoint(x: frame.maxX - c, y: frame.minY + c), -0.25 * .pi),
            (CGPoint(x: frame.maxX - c, y: frame.maxY - c), 0.25 * .pi),
            (CGPoint(x: frame.minX + c, y: frame.maxY - c), 0.75 * .pi),
        ]
        for (centre, mid) in corners {
            let dist = hypot(p.x - centre.x, p.y - centre.y)
            guard dist > c else { continue }
            let toPip = atan2(Double(p.y - centre.y), Double(p.x - centre.x))
            let half = acos(Double(c / dist))                                     // the span facing Pip, either side
            let off = remainder(toPip - mid, 2 * .pi)
            let lo = max(off - half, -.pi / 4), hi = min(off + half, .pi / 4)
            guard hi > lo else { continue }
            let start = mid + lo
            path.move(to: CGPoint(x: centre.x + c * CGFloat(cos(start)), y: centre.y + c * CGFloat(sin(start))))
            path.addRelativeArc(center: centre, radius: c, startAngle: .radians(start), delta: .radians(hi - lo))
        }
        return path
    }

    /// Where the rays land on a lit edge, evenly spread, for "Show the rays".
    static func rays(_ lit: Lit, count: Int) -> [CGPoint] {
        guard count > 1 else { return [lit.peak] }
        return (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(count - 1)
            return CGPoint(x: lit.a.x + (lit.b.x - lit.a.x) * t, y: lit.a.y + (lit.b.y - lit.a.y) * t)
        }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Light(host: host) }
    func card(_ host: PipHost) -> some View { LightCard() }

    /// The light over the app: each lit stretch as a line that fades out from its brightest point.
    struct Light: View {
        let host: PipHost
        @AppStorage(PipLight.raysKey) private var showRays = false
        @AppStorage(PipLight.cornersKey) private var wrapCorners = true
        @AppStorage("plug.piplight.reach") private var reachK = 9.0
        @AppStorage("plug.piplight.strength") private var strength = 1.0
        @AppStorage("plug.piplight.spill") private var spill = 4.0
        @AppStorage("plug.piplight.edge") private var edge = 1.5
        @AppStorage("plug.piplight.falloff") private var falloff = 2.0
        @AppStorage("plug.piplight.warmth") private var warmth = 1.0

        var body: some View {
            let p = host.pipPosition
            let r: CGFloat = host.pip.radius
            // "Light on panels" in Pip Looks × Strength here, brighter while Pip wants you
            let brightness = BlobbyTune.current.panelLight * strength * (1 + 0.8 * BlobbyAttention.level)
            let colour = PipLight.colour(warmth: warmth)
            let panels: [(frame: CGRect, corner: CGFloat)] = [(host.panelFrame, 26), (host.cardFrame, 22), (host.barFrame, 30)]
            let reach = r * CGFloat(reachK)
            let lit = PipLight.light(from: p, panels: panels, reach: reach)
            let spillStyle = StrokeStyle(lineWidth: spill, lineCap: .round)                // the soft spill
            let edgeStyle = StrokeStyle(lineWidth: edge, lineCap: .round)                  // the bright edge
            return Canvas { ctx, _ in
                if wrapCorners {
                    // one round fade centred on Pip: brightest at Pip, nothing at the reach, shaped by Falloff
                    let fade = GraphicsContext.Shading.radialGradient(
                        Gradient(stops: (0...6).map { i -> Gradient.Stop in
                            let f = Double(i) / 6
                            return .init(color: colour.opacity(min(1, 0.9 * brightness * pow(1 - f, falloff))), location: f)
                        }),
                        center: p, startRadius: 0, endRadius: reach)
                    for (frame, corner) in panels {
                        let rim = PipLight.rim(from: p, frame: frame, corner: corner, reach: reach)
                        guard !rim.isEmpty else { continue }
                        if spill > 0.1 { ctx.stroke(rim, with: fade, style: spillStyle) }
                        ctx.stroke(rim, with: fade, style: edgeStyle)
                    }
                }
                for l in lit {
                    if !wrapCorners {
                        // v1: a straight fade along the edge, from its brightest point (strength is k², so this is k^falloff)
                        let k = pow(l.strength, falloff / 2) * brightness
                        let fade = GraphicsContext.Shading.linearGradient(
                            Gradient(stops: [
                                .init(color: colour.opacity(0), location: 0),
                                .init(color: colour.opacity(min(1, 0.9 * k)), location: Self.place(l)),
                                .init(color: colour.opacity(0), location: 1),
                            ]),
                            startPoint: l.a, endPoint: l.b)
                        var line = Path()
                        line.move(to: l.a)
                        line.addLine(to: l.b)
                        if spill > 0.1 { ctx.stroke(line, with: fade, style: spillStyle) }
                        ctx.stroke(line, with: fade, style: edgeStyle)
                    }
                    if showRays {
                        for hit in PipLight.rays(l, count: PipLight.raysPerEdge) {
                            var ray = Path()
                            ray.move(to: p)
                            ray.addLine(to: hit)
                            ctx.stroke(ray, with: .color(colour.opacity(0.25 * l.strength)),
                                       style: StrokeStyle(lineWidth: 0.75, dash: [3, 4]))
                        }
                    }
                }
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .opacity(host.pipHere ? 1 : 0)
        }

        /// Where the brightest point sits along the line, 0…1.
        private static func place(_ l: Lit) -> CGFloat {
            let len = hypot(l.b.x - l.a.x, l.b.y - l.a.y)
            guard len > 0 else { return 0.5 }
            return min(0.999, max(0.001, hypot(l.peak.x - l.a.x, l.peak.y - l.a.y) / len))
        }
    }

    struct LightCard: View {
        @AppStorage(PipLight.raysKey) private var showRays = false
        @AppStorage(PipLight.cornersKey) private var wrapCorners = true

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("Pip glows, so the edges of panels near them catch the light: brightest nearest Pip, fading along the edge.")
                Toggle("Wrap the corners", isOn: $wrapCorners)
                    .accessibilityHint("The light follows the rounded corners too, instead of stopping where they start.")
                Toggle("Show the rays", isOn: $showRays)
                    .accessibilityHint("Draws the lines Pip's light travels along, to see how it works.")
                ForEach(PipLight.knobs, id: \.key) { KnobRow(knob: $0) }
                Button("Reset") {
                    for k in PipLight.knobs { UserDefaults.standard.set(k.start, forKey: k.key) }
                }
                .accessibilityHint("Puts the light's sliders back to how they started.")
                Text("Brightness also follows Pip Looks → Light on panels. The light comes from Pip's middle.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .font(.system(size: 13.5))
        }
    }

    /// One slider. Shows the value while dragging, saves when the finger lifts (VoiceOver's swipe saves straight away).
    struct KnobRow: View {
        let knob: Knob
        @AppStorage private var value: Double
        @State private var draft: Double?
        @State private var dragging = false

        init(knob: Knob) {
            self.knob = knob
            _value = AppStorage(wrappedValue: knob.start, knob.key)
        }

        var body: some View {
            let shown = draft ?? value
            HStack(spacing: 8) {
                Text(knob.name).frame(width: 84, alignment: .leading)
                Slider(value: Binding(get: { shown }, set: { dragging ? (draft = $0) : (value = $0) }),
                       in: knob.range) { editing in
                    dragging = editing
                    if !editing, let d = draft { value = d; draft = nil }
                }
                .accessibilityLabel(knob.name)
                Text(String(format: "%.2f", shown))
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}
