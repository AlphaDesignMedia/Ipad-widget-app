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
// v2 (Pip's Light agent, 1 Nov, each with its own switch in the card): Wrap the corners · sliders (Aaron: "experiment
// with sliders and values") · Bloom · Glints · Colour from Pip. Waiting on core: the app's own panels (Settings, Groups,
// the widget panel) aren't reported to the host yet (GitHub issue #3); add them to `panels` in `Light` when they are.
// Handover: nat/pip-light-handover.md.

struct PipLight: SandboxPlugin {
    let info = PluginInfo(id: "piplight", name: "Pip's Light", version: "v2", shelf: .dream,
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
        Knob(name: "Bloom depth", key: "plug.piplight.bloomDepth", range: 4...48, start: 16), // points into the panel
        Knob(name: "Glint size", key: "plug.piplight.glintSize", range: 1...12, start: 4),    // points
        Knob(name: "Mood tint", key: "plug.piplight.moodTint", range: 0...1, start: 0.6),     // 0 none, 1 full colour
    ]
    static let glintsKey = "plug.piplight.glints"
    static let moodKey = "plug.piplight.mood"

    /// "Colour from Pip": the light takes Pip's mood. A blush on Pip's halo wins; otherwise their face picks one. Nil:
    /// the plain light (Warmth). Soft, light colours only, so it stays light, never a stain.
    static func moodColour(_ pip: PipModel) -> Color? {
        if let blush = pip.halo { return blush }
        if pip.asleep { return Color(red: 0.75, green: 0.72, blue: 1) }             // lavender
        if pip.dizzy { return Color(red: 0.72, green: 1, blue: 0.82) }              // mint
        if pip.happy { return Color(red: 1, green: 0.84, blue: 0.5) }               // gold
        switch pip.mood {
        case .surprised: return .white
        case .curious: return Color(red: 0.62, green: 0.9, blue: 1)                 // sky
        case .shy: return Color(red: 1, green: 0.72, blue: 0.82)                    // pink
        case .sleepy: return Color(red: 0.75, green: 0.72, blue: 1)                 // lavender
        default: return nil
        }
    }
    static let bloomKey = "plug.piplight.bloom"
    /// Bloom is drawn as this many soft bands, deepest faintest: cheap, and an old-game stepped look.
    static let bloomBands = 4

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

    /// "Glints": the point on a panel's rounded outline nearest `p`, and the way the edge runs there (for the sparkle's
    /// streak). The nearest point of a rounded rectangle: pull `p` into the rectangle shrunk by the corner, then step back
    /// out by the corner radius towards `p`. Works the same on straight edges and round corners. Nil if Pip is inside.
    static func glint(from p: CGPoint, frame: CGRect, corner: CGFloat) -> (point: CGPoint, along: CGVector)? {
        guard !frame.isNull, !frame.isEmpty, !frame.contains(p) else { return nil }
        let c = min(corner, frame.width / 2, frame.height / 2)
        let core = frame.insetBy(dx: c, dy: c)
        let q = CGPoint(x: min(max(p.x, core.minX), core.maxX), y: min(max(p.y, core.minY), core.maxY))
        let dx = p.x - q.x, dy = p.y - q.y
        let len = hypot(dx, dy)
        guard len > c else { return nil }
        let nx = dx / len, ny = dy / len
        return (CGPoint(x: q.x + nx * c, y: q.y + ny * c), CGVector(dx: -ny, dy: nx))
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
        @AppStorage(PipLight.bloomKey) private var bloom = true
        @AppStorage("plug.piplight.bloomDepth") private var bloomDepth = 16.0
        @AppStorage(PipLight.glintsKey) private var glints = true
        @AppStorage("plug.piplight.glintSize") private var glintSize = 4.0
        @AppStorage(PipLight.moodKey) private var fromPip = true
        @AppStorage("plug.piplight.moodTint") private var moodTint = 0.6

        var body: some View {
            let p = host.pipPosition
            let r: CGFloat = host.pip.radius
            // "Light on panels" in Pip Looks × Strength here, brighter while Pip wants you
            let brightness = BlobbyTune.current.panelLight * strength * (1 + 0.8 * BlobbyAttention.level)
            let plain = PipLight.colour(warmth: warmth)
            let mood = fromPip ? PipLight.moodColour(host.pip) : nil
            let colour = mood.map { plain.mix(with: $0, by: moodTint) } ?? plain
            let panels: [(frame: CGRect, corner: CGFloat)] = [(host.panelFrame, 26), (host.cardFrame, 22), (host.barFrame, 30)]
            let reach = r * CGFloat(reachK)
            let lit = PipLight.light(from: p, panels: panels, reach: reach)
            let spillStyle = StrokeStyle(lineWidth: spill, lineCap: .round)                // the soft spill
            let edgeStyle = StrokeStyle(lineWidth: edge, lineCap: .round)                  // the bright edge
            // one round fade centred on Pip: brightest at Pip, nothing at the reach, shaped by Falloff
            let fade = { (scale: Double) in
                GraphicsContext.Shading.radialGradient(
                    Gradient(stops: (0...6).map { i -> Gradient.Stop in
                        let f = Double(i) / 6
                        return .init(color: colour.opacity(min(1, scale * brightness * pow(1 - f, falloff))), location: f)
                    }),
                    center: p, startRadius: 0, endRadius: reach)
            }
            return Canvas { ctx, _ in
                if bloom {
                    // the glow on the face of the panel, just inside the lit edge: wide strokes of the rim, clipped to the
                    // inside, stacked so it steps down in bands going in
                    let band = fade(0.12)
                    for (frame, corner) in panels {
                        let rim = PipLight.rim(from: p, frame: frame, corner: corner, reach: reach)
                        guard !rim.isEmpty else { continue }
                        var inside = ctx
                        inside.clip(to: Path(roundedRect: frame, cornerRadius: min(corner, frame.width / 2, frame.height / 2),
                                             style: .circular))   // the same round corners as rim()
                        for i in 0..<PipLight.bloomBands {
                            let depth = bloomDepth * Double(PipLight.bloomBands - i) / Double(PipLight.bloomBands)
                            inside.stroke(rim, with: band, style: StrokeStyle(lineWidth: 2 * depth, lineCap: .round))
                        }
                    }
                }
                if wrapCorners {
                    let fade = fade(0.9)
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
                if glints {
                    // a tiny four-point sparkle where each panel's edge is nearest Pip: long along the edge, short across
                    for (frame, corner) in panels {
                        guard let g = PipLight.glint(from: p, frame: frame, corner: corner) else { continue }
                        let d = hypot(p.x - g.point.x, p.y - g.point.y)
                        guard d < reach else { continue }
                        let k = min(1, brightness * pow(1 - Double(d / reach), falloff))
                        let s = CGFloat(glintSize)
                        let across = CGVector(dx: -g.along.dy, dy: g.along.dx)
                        ctx.fill(Path(ellipseIn: CGRect(x: g.point.x - 2 * s, y: g.point.y - 2 * s, width: 4 * s, height: 4 * s)),
                                 with: .radialGradient(Gradient(colors: [colour.opacity(0.5 * k), colour.opacity(0)]),
                                                       center: g.point, startRadius: 0, endRadius: 2 * s))
                        for (dir, length) in [(g.along, 3 * s), (across, 1.5 * s)] {
                            let a = CGPoint(x: g.point.x - dir.dx * length, y: g.point.y - dir.dy * length)
                            let b = CGPoint(x: g.point.x + dir.dx * length, y: g.point.y + dir.dy * length)
                            var streak = Path()
                            streak.move(to: a)
                            streak.addLine(to: b)
                            ctx.stroke(streak, with: .linearGradient(
                                Gradient(colors: [colour.opacity(0), .white.opacity(k), colour.opacity(0)]),
                                startPoint: a, endPoint: b), lineWidth: 1)
                        }
                        let dot = 0.35 * s
                        ctx.fill(Path(ellipseIn: CGRect(x: g.point.x - dot, y: g.point.y - dot, width: 2 * dot, height: 2 * dot)),
                                 with: .color(.white.opacity(k)))
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
        @AppStorage(PipLight.bloomKey) private var bloom = true
        @AppStorage(PipLight.glintsKey) private var glints = true
        @AppStorage(PipLight.moodKey) private var fromPip = true

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("Pip glows, so the edges of panels near them catch the light: brightest nearest Pip, fading along the edge.")
                Toggle("Wrap the corners", isOn: $wrapCorners)
                    .accessibilityHint("The light follows the rounded corners too, instead of stopping where they start.")
                Toggle("Bloom", isOn: $bloom)
                    .accessibilityHint("A soft glow on the panel, just inside the lit edge.")
                Toggle("Glints", isOn: $glints)
                    .accessibilityHint("A tiny sparkle where each panel's edge is nearest Pip. It only moves when Pip does.")
                Toggle("Colour from Pip", isOn: $fromPip)
                    .accessibilityHint("The light takes Pip's mood: gold when happy, pink when shy, lavender when sleepy.")
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
