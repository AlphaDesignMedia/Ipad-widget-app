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
    func card(_ host: PipHost) -> some View { Card() }

    /// The light over the app: each lit stretch as a line that fades out from its brightest point.
    struct Light: View {
        let host: PipHost
        @AppStorage(PipLight.raysKey) private var showRays = false

        var body: some View {
            let p = host.pipPosition
            let r: CGFloat = host.pip.radius
            // "Light on panels" in Pip Looks, brighter while Pip wants you
            let brightness = BlobbyTune.current.panelLight * (1 + 0.8 * BlobbyAttention.level)
            let panels: [(frame: CGRect, corner: CGFloat)] = [(host.panelFrame, 26), (host.cardFrame, 22), (host.barFrame, 30)]
            let lit = PipLight.light(from: p, panels: panels, reach: r * PipLight.reach)
            return Canvas { ctx, _ in
                for l in lit {
                    let k = l.strength * brightness
                    let fade = GraphicsContext.Shading.linearGradient(
                        Gradient(stops: [
                            .init(color: PipLight.colour.opacity(0), location: 0),
                            .init(color: PipLight.colour.opacity(min(1, 0.9 * k)), location: Self.place(l)),
                            .init(color: PipLight.colour.opacity(0), location: 1),
                        ]),
                        startPoint: l.a, endPoint: l.b)
                    var line = Path()
                    line.move(to: l.a)
                    line.addLine(to: l.b)
                    ctx.stroke(line, with: fade, style: StrokeStyle(lineWidth: 4, lineCap: .round))     // the soft spill
                    ctx.stroke(line, with: fade, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))   // the bright edge
                    if showRays {
                        for hit in PipLight.rays(l, count: PipLight.raysPerEdge) {
                            var ray = Path()
                            ray.move(to: p)
                            ray.addLine(to: hit)
                            ctx.stroke(ray, with: .color(PipLight.colour.opacity(0.25 * l.strength)),
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

    struct Card: View {
        @AppStorage(PipLight.raysKey) private var showRays = false

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("Pip glows, so the edges of panels near them catch the light: brightest nearest Pip, fading along the edge.")
                Toggle("Show the rays", isOn: $showRays)
                    .accessibilityHint("Draws the lines Pip's light travels along, to see how it works.")
                Text("Brightness: Pip Looks → Light on panels. Version 1 is plain lines; the pretty version comes next.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .font(.system(size: 13.5))
        }
    }
}
