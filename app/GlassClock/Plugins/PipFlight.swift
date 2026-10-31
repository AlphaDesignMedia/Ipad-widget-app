import SwiftUI

// PIP FLIGHT · plugin v1 (On trial). Drawing sheet F made playable (Chappie's flying brief, 31 Oct). Aaron's own Pip
// (the same head, body and two leaf ears as Pip Peek), only posed, never redesigned: the ears ARE the wings, and when
// Pip flies the body tips sideways with the point trailing behind.
// The card: "Take off" plays hanging → wakes → squash → spring → away (the squash is held a beat: it may become
// Pip's signature move), then the ears flap for a moment. The slider scrubs through the frames by hand. Faces: auto,
// o, excited, concentrating, cheeky. "Fly across" sends Pip once across the screen, ears flapping, then they're gone.
// Light: the card animates only while playing; the overlay exists only during the 3-second flight. Nothing starts on
// its own. Pip off: "Fly across" is off. Simpler motion: no flight across the screen; the card steps instead of moving.

struct PipFlight: SandboxPlugin {
    let info = PluginInfo(id: "flight", name: "Pip Flight", version: "v1", shelf: .trial,
                          icon: "wind", what: "Sheet F made playable: Aaron's Pip takes off, flaps their ears and flies.")

    // MARK: Data

    enum Face: String, CaseIterable { case auto, shut, normal, o, excited, focus, cheeky
        var label: String {
            switch self {
            case .auto: "Auto"
            case .shut: "Asleep"
            case .normal: "Calm"
            case .o: "o!"
            case .excited: "Excited"
            case .focus: "Concentrating"
            case .cheeky: "Cheeky"
            }
        }
    }
    enum Mouth { case none, o, smile, flat, side }

    /// One pose, in Pip's 100-wide box (body space, before the turn). Ears: angle in degrees and length.
    struct Pose {
        var turn: Double
        var tail: (x: Double, y: Double, r: Double)
        var body: (x: Double, y: Double, r: Double)
        var upEar: (angle: Double, length: Double)
        var backEar: (angle: Double, length: Double)
        var face: Face
        var mouth: Mouth

        static func mix(_ a: Pose, _ b: Pose, _ t: Double) -> Pose {
            func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
            return Pose(turn: m(a.turn, b.turn),
                        tail: (m(a.tail.x, b.tail.x), m(a.tail.y, b.tail.y), m(a.tail.r, b.tail.r)),
                        body: (m(a.body.x, b.body.x), m(a.body.y, b.body.y), m(a.body.r, b.body.r)),
                        upEar: (m(a.upEar.angle, b.upEar.angle), m(a.upEar.length, b.upEar.length)),
                        backEar: (m(a.backEar.angle, b.backEar.angle), m(a.backEar.length, b.backEar.length)),
                        face: t < 0.5 ? a.face : b.face, mouth: t < 0.5 ? a.mouth : b.mouth)
        }
    }

    /// Sheet F's take-off, frame by frame.
    static let frames: [(name: String, pose: Pose)] = [
        ("hanging", Pose(turn: 90, tail: (12, 66, 10), body: (44, 62, 18), upEar: (-20, 26), backEar: (150, 26), face: .shut, mouth: .none)),
        ("wakes", Pose(turn: 55, tail: (12, 66, 10), body: (44, 62, 18), upEar: (-80, 34), backEar: (200, 34), face: .normal, mouth: .none)),
        ("squash", Pose(turn: 10, tail: (28, 66, 13), body: (46, 64, 18), upEar: (-95, 40), backEar: (230, 36), face: .focus, mouth: .flat)),
        ("spring!", Pose(turn: -20, tail: (-6, 70, 8), body: (44, 62, 18), upEar: (-170, 44), backEar: (160, 44), face: .excited, mouth: .o)),
        ("away", Pose(turn: -8, tail: (12, 66, 10), body: (44, 62, 18), upEar: (-150, 46), backEar: (170, 46), face: .o, mouth: .o)),
    ]

    /// Seconds each step of the take-off takes: the squash is held, the spring is quick.
    static let timing: [Double] = [0.55, 0.45, 0.6, 0.22, 0.4]
    static let flapFor = 1.6
    static let flightFor = 3.2

    // MARK: Logic

    /// The pose at a point on the slider (0 = hanging … 4 = away), eased between frames.
    static func pose(at t: Double) -> Pose {
        let c = min(max(t, 0), Double(frames.count - 1))
        let i = min(Int(c), frames.count - 2), f = c - Double(i)
        let eased = f * f * (3 - 2 * f)
        return Pose.mix(frames[i].pose, frames[i + 1].pose, eased)
    }

    /// The flying pose with the ears flapping: phase in seconds.
    static func flapping(_ phase: Double) -> Pose {
        var p = frames[frames.count - 1].pose
        let swing = sin(phase * 2 * .pi * 2.4) * 34
        p.upEar.angle += swing
        p.backEar.angle -= swing
        p.turn += sin(phase * 2 * .pi * 1.2) * 4
        return p
    }

    /// The mouth for a chosen face (Auto keeps the frame's own).
    static func mouth(for face: Face, _ pose: Pose) -> Mouth {
        switch face {
        case .auto: pose.mouth
        case .o: .o
        case .excited: .smile
        case .focus: .flat
        case .cheeky: .side
        case .shut, .normal: .none
        }
    }

    /// Playback time → slider position (follows `timing`), or nil once the take-off is done.
    static func position(after seconds: Double) -> Double? {
        var left = seconds
        for i in 0..<(frames.count - 1) {
            let d = timing[i]
            if left < d { return Double(i) + left / d }
            left -= d
        }
        return nil
    }

    // MARK: State

    @MainActor @Observable final class Session {
        var flying: Date?
    }
    private let session = Session()

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { FlightOverlay(host: host, session: session) }

    func card(_ host: PipHost) -> some View { FlightCard(host: host, session: session) }

    /// Only exists during a flight across the screen.
    struct FlightOverlay: View {
        let host: PipHost
        let session: Session

        var body: some View {
            if let start = session.flying, host.pipOn {
                GeometryReader { geo in
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSince(start)
                        let p = min(max(t / PipFlight.flightFor, 0), 1)
                        let x = -90 + p * (geo.size.width + 180)
                        let y = geo.size.height * 0.36 + sin(p * .pi * 2) * 46 - sin(p * .pi) * 30
                        Figure(pose: PipFlight.flapping(t), face: .o)
                            .frame(width: 130, height: 130)
                            .position(x: x, y: y)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    struct FlightCard: View {
        let host: PipHost
        let session: Session
        @State private var t = 0.0
        @State private var playing: Date?
        @State private var face = Face.auto

        var body: some View {
            VStack(alignment: .leading, spacing: Corner.inset) {
                SettingsCard(title: "Take-off", icon: "wind",
                             footer: "Sheet F, playable. The ears are the wings; the point trails behind.") {
                    stage
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Pip, \(PipFlight.frames[min(Int(t.rounded()), PipFlight.frames.count - 1)].name)")
                    Slider(value: $t, in: 0...Double(PipFlight.frames.count - 1))
                        .disabled(playing != nil)
                        .accessibilityLabel("Take-off frame")
                    HStack {
                        ForEach(PipFlight.frames.indices, id: \.self) { i in
                            Text(PipFlight.frames[i].name)
                                .font(.system(size: 11, weight: Int(t.rounded()) == i ? .bold : .regular))
                                .foregroundStyle(Int(t.rounded()) == i ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityHidden(true)
                    HStack(spacing: PluginBarLook.cardGap) {
                        Button { play() } label: {
                            Label("Take off", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PluginCardButton(on: true))
                        .disabled(playing != nil)
                        Button {
                            session.flying = Date()
                            host.later(PipFlight.flightFor + 0.2) { session.flying = nil }
                        } label: {
                            Label("Fly across", systemImage: "paperplane").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PluginCardButton(on: false))
                        .disabled(!host.pipOn || host.simpler || session.flying != nil)
                        .accessibilityHint("Pip flies once across the screen.")
                    }
                    if !host.pipOn {
                        Text("Pip is switched off, so they won't fly across.").font(.caption).foregroundStyle(.secondary)
                    } else if host.simpler {
                        Text("Simpler motion is on, so no flying across the screen.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                SettingsCard(title: "Face", icon: "face.smiling") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PluginBarLook.cardGap) {
                            ForEach(Face.allCases, id: \.self) { f in
                                Button(f.label) { face = f }
                                    .buttonStyle(PluginCardButton(on: face == f))
                            }
                        }
                    }
                }
                SettingsCard(title: "Tiny check", icon: "magnifyingglass",
                             footer: "The flying silhouette at 16, 24, 32 and 48 points.") {
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach([16.0, 24.0, 32.0, 48.0], id: \.self) { px in
                            Figure(pose: PipFlight.frames[4].pose, face: .o, silhouette: true).frame(width: px * 1.3, height: px * 1.3)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            .font(.system(size: 13.5))
        }

        @ViewBuilder private var stage: some View {
            if let start = playing, !host.simpler {
                TimelineView(.animation) { tl in
                    let s = tl.date.timeIntervalSince(start)
                    if let pos = PipFlight.position(after: s) {
                        Figure(pose: PipFlight.pose(at: pos), face: face)
                    } else {
                        Figure(pose: PipFlight.flapping(s), face: face)
                    }
                }
            } else {
                Figure(pose: PipFlight.pose(at: t), face: face)
            }
        }

        private func play() {
            let total = PipFlight.timing.dropLast().reduce(0, +)
            if host.simpler {
                // Steps through the frames instead of moving.
                for i in PipFlight.frames.indices { host.later(Double(i) * 0.6) { t = Double(i) } }
                return
            }
            t = 0
            playing = Date()
            host.later(total + PipFlight.flapFor) {
                playing = nil
                t = Double(PipFlight.frames.count - 1)
            }
        }
    }

    /// Aaron's Pip in a pose: body behind, the back ear, the up ear, the head in front, the face.
    struct Figure: View {
        let pose: Pose
        var face: Face = .auto
        var silhouette = false

        var body: some View {
            Canvas { ctx, size in
                let s = size.width / 130
                ctx.translateBy(x: size.width / 2, y: size.height / 2)
                ctx.scaleBy(x: s, y: s)
                ctx.rotate(by: .degrees(pose.turn))
                ctx.translateBy(x: -50, y: -50)
                let ink = Color(red: 0.086, green: 0.094, blue: 0.122)
                let line = StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                func paint(_ path: Path) {
                    if silhouette {
                        ctx.fill(path, with: .color(ink))
                    } else {
                        ctx.fill(path, with: .color(.white))
                        ctx.stroke(path, with: .color(ink), style: line)
                    }
                }
                func ear(_ base: CGPoint, _ e: (angle: Double, length: Double)) -> Path {
                    let a = e.angle * .pi / 180
                    let tip = CGPoint(x: base.x + e.length * cos(a), y: base.y + e.length * sin(a))
                    return PipPeek.leaf(base, tip, 8 * min(1.4, e.length / 34))
                }
                paint(PipPeek.tube(pose.body, pose.tail))
                paint(ear(CGPoint(x: 50, y: 44), pose.backEar))
                paint(ear(CGPoint(x: 60, y: 34), pose.upEar))
                let h = PipPeek.Geo.head
                paint(Path(ellipseIn: CGRect(x: h.x - h.r, y: h.y - h.r, width: h.r * 2, height: h.r * 2)))

                let dark: Color = silhouette ? .white : ink
                let shown = face == .auto ? pose.face : face
                let eyes = [CGPoint(x: 58, y: 48), CGPoint(x: 69, y: 46)]
                func dot(_ c: CGPoint, big: Bool) {
                    let w = big ? 6.4 : 4.6, hgt = big ? 10.0 : 7.8
                    let eye = Path(ellipseIn: CGRect(x: -w / 2, y: -hgt / 2, width: w, height: hgt))
                        .applying(CGAffineTransform(rotationAngle: -0.21).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
                    ctx.fill(eye, with: .color(dark))
                    if big && !silhouette {
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 1.8, y: c.y - 3, width: 2, height: 2)), with: .color(.white))
                    }
                }
                func stroke(_ path: Path) { ctx.stroke(path, with: .color(dark), style: StrokeStyle(lineWidth: 2.3, lineCap: .round)) }
                func lid(_ c: CGPoint, up: Bool) {
                    var p = Path()
                    p.move(to: CGPoint(x: c.x - 3, y: c.y))
                    p.addQuadCurve(to: CGPoint(x: c.x + 3, y: c.y), control: CGPoint(x: c.x, y: c.y + (up ? -3 : 3)))
                    stroke(p)
                }
                switch shown {
                case .auto, .normal, .o: for c in eyes { dot(c, big: false) }
                case .excited: for c in eyes { dot(c, big: true) }
                case .shut: for c in eyes { lid(c, up: false) }
                case .cheeky: dot(eyes[0], big: false); lid(eyes[1], up: true)
                case .focus:
                    for c in eyes {
                        var p = Path()
                        p.move(to: CGPoint(x: c.x - 3, y: c.y - 1))
                        p.addLine(to: CGPoint(x: c.x + 3, y: c.y + 0.5))
                        stroke(p)
                    }
                }
                let mouth = PipFlight.mouth(for: face, pose)
                switch mouth {
                case .none: break
                case .o: ctx.fill(Path(ellipseIn: CGRect(x: 65.2, y: 57.4, width: 3.6, height: 5.2)), with: .color(dark))
                case .smile:
                    var p = Path(); p.move(to: CGPoint(x: 62, y: 58)); p.addQuadCurve(to: CGPoint(x: 72, y: 57), control: CGPoint(x: 67, y: 63)); stroke(p)
                case .flat:
                    var p = Path(); p.move(to: CGPoint(x: 64, y: 60)); p.addLine(to: CGPoint(x: 70, y: 59)); stroke(p)
                case .side:
                    var p = Path(); p.move(to: CGPoint(x: 63, y: 59)); p.addQuadCurve(to: CGPoint(x: 73, y: 55), control: CGPoint(x: 68, y: 61)); stroke(p)
                }
            }
        }
    }
}
