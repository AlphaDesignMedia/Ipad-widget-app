import SwiftUI

// Pip in 3D: Pip looks around, with a detail dial like a game's graphics settings.
// The point is to find the cheapest trick that still feels 3D, then stop there.
//
// - Flat: one picture; only the eyes move. Almost free.
// - Layers: the parts sit at different depths and slide by different amounts (parallax).
//   This is the classic 2.5D trick: it reads as 3D at a fraction of the cost.
// - Full: Layers, plus a real 3D head turn, a shine that moves, a shadow on the floor,
//   breathing and blinking.
//
// How Pip moves (animation, not code): the eyes lead and the head follows. The eyes snap
// quickly to what Pip looks at; the head turns slowly after them. When nothing's happening,
// Pip picks somewhere new to look every couple of seconds (a "saccade"), like real eyes.
//
// How this works (Swift idea): `LookSim` keeps two springs, one fast for the eyes and one slow
// for the head, and TimelineView moves them on every frame.

enum PipDetail: Int, CaseIterable, Identifiable {
    case flat, layers, full
    var id: Int { rawValue }
    var name: String {
        switch self {
        case .flat: "Flat"
        case .layers: "Layers"
        case .full: "Full"
        }
    }
    var blurb: String {
        switch self {
        case .flat: "One picture. Only the eyes move."
        case .layers: "Parts at different depths slide past each other. Cheap 3D."
        case .full: "A real head turn, a moving shine, a shadow, breathing and blinking."
        }
    }
}

/// Where Pip is looking, as -1…1 in each direction, for the eyes and the head.
final class LookSim {
    private(set) var eyes = CGPoint.zero
    private(set) var head = CGPoint.zero
    private(set) var blink = 0.0
    private var idleTarget = CGPoint.zero
    private var nextGlance = 0.0
    private var nextBlink = 2.0
    private var last: Double?

    func step(time: Double, target: CGPoint?, calm: Bool) {
        let dt = min(max(time - (last ?? time), 0), 1 / 30)
        last = time
        // Nobody pointing: glance somewhere new every so often.
        if time > nextGlance {
            idleTarget = CGPoint(x: .random(in: -0.9...0.9), y: .random(in: -0.5...0.6))
            if Int.random(in: 0..<4) == 0 { idleTarget = .zero }
            nextGlance = time + .random(in: 1.2...3.2)
        }
        let goal = target ?? idleTarget
        if calm {
            eyes = goal
            head = CGPoint(x: goal.x * 0.5, y: goal.y * 0.5)
            blink = 0
            return
        }
        // Eyes: fast. Head: slow, and only turns about 60% of the way.
        eyes = approach(eyes, goal, rate: 16, dt)
        head = approach(head, CGPoint(x: goal.x * 0.6, y: goal.y * 0.6), rate: 4.5, dt)
        if time > nextBlink {
            blink = 1
            nextBlink = time + .random(in: 2.5...6)
        }
        blink = max(0, blink - dt * 7)
    }

    private func approach(_ a: CGPoint, _ b: CGPoint, rate: Double, _ dt: Double) -> CGPoint {
        let k = 1 - exp(-rate * dt)
        return CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
    }
}

struct PipLookWonder: View {
    @State private var detail: PipDetail = .full
    @State private var pointer: CGPoint?
    @State private var sim = LookSim()
    @State private var motion = MotionSource()
    @State private var useTilt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.42
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.45)
            ZStack {
                RadialGradient(colors: [Color(red: 0.2, green: 0.25, blue: 0.45), Color(red: 0.04, green: 0.05, blue: 0.12)],
                               center: .center, startRadius: 10, endRadius: geo.size.height * 0.8)

                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let target = lookTarget(centre: centre, size: geo.size, time: time)
                    let _ = sim.step(time: time, target: target, calm: reduceMotion)
                    let breathe = detail == .full && !reduceMotion ? sin(time * 1.6) * 0.015 : 0
                    PipFigure(detail: detail, eyes: sim.eyes, head: sim.head, blink: sim.blink, size: size)
                        .scaleEffect(1 + breathe)
                        .position(centre)
                }

                VStack(spacing: 14) {
                    Spacer()
                    Text(detail.blurb).font(.callout).foregroundStyle(.white.opacity(0.85))
                    Picker("Detail", selection: $detail) {
                        ForEach(PipDetail.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 360)
                    if motion.hasSensor {
                        Toggle("Look where I tilt", isOn: $useTilt).frame(maxWidth: 360).foregroundStyle(.white)
                    }
                    Text("Touch, hover a Pencil, or leave Pip to look around alone.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 40)
                .padding(.horizontal, 20)
            }
            .contentShape(.rect)
            .onContinuousHover { phase in
                if case .active(let p) = phase { pointer = p } else { pointer = nil }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { pointer = $0.location }
                .onEnded { _ in pointer = nil })
        }
        .ignoresSafeArea()
        .onChange(of: useTilt) { _, on in
            if on {
                motion.orientation = MotionSource.currentOrientation()
                motion.start()
            } else {
                motion.stop()
            }
        }
        .onDisappear { motion.stop() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pip in 3D. Pip looks around, and follows your finger.")
    }

    /// Where Pip should look, as -1…1: the finger or Pencil, else tilt, else nowhere (idle).
    private func lookTarget(centre: CGPoint, size: CGSize, time: Double) -> CGPoint? {
        if let pointer {
            return CGPoint(x: clamp((pointer.x - centre.x) / (size.width / 2)),
                           y: clamp((pointer.y - centre.y) / (size.height / 2)))
        }
        if useTilt {
            let g = motion.gravity(at: time)
            return CGPoint(x: clamp(g.dx * 2), y: clamp((g.dy - 0.7) * 2))
        }
        return nil
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(max(v, -1), 1) }
}

/// Pip, drawn from simple shapes so each part can sit at its own depth.
private struct PipFigure: View {
    let detail: PipDetail
    let eyes: CGPoint
    let head: CGPoint
    let blink: Double
    let size: CGFloat

    var body: some View {
        // How far each layer slides for a full look, as a share of Pip's size. Nearer layers
        // slide further: that difference is what the eye reads as depth.
        let depth: (back: CGFloat, body: CGFloat, face: CGFloat, shine: CGFloat) =
            detail == .flat ? (0, 0, 0, 0) : (-0.04, 0.03, 0.12, -0.08)
        let look = detail == .flat ? CGPoint.zero : head

        ZStack {
            if detail == .full {
                // A soft shadow on the floor, sliding opposite the head.
                Ellipse().fill(.black.opacity(0.35))
                    .frame(width: size * 0.8, height: size * 0.16)
                    .blur(radius: 10)
                    .offset(x: -look.x * size * 0.08, y: size * 0.62)
            }

            Group {
                // The back rim: the far side of the glass.
                Circle().stroke(.white.opacity(0.25), lineWidth: size * 0.02)
                    .frame(width: size * 0.96, height: size * 0.96)
                    .offset(x: look.x * size * depth.back, y: look.y * size * depth.back)

                // The glass body.
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.75, green: 0.95, blue: 1).opacity(0.75),
                                                  Color(red: 0.35, green: 0.6, blue: 1).opacity(0.45),
                                                  Color(red: 0.4, green: 0.3, blue: 0.9).opacity(0.55)],
                                         center: UnitPoint(x: 0.35 - look.x * 0.1, y: 0.3 - look.y * 0.1),
                                         startRadius: 2, endRadius: size * 0.6))
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: size * 0.015))
                    .frame(width: size, height: size)
                    .offset(x: look.x * size * depth.body, y: look.y * size * depth.body)

                // The face: eyes, which also move inside their sockets.
                HStack(spacing: size * 0.18) {
                    eye; eye
                }
                .offset(x: look.x * size * depth.face + eyes.x * size * 0.05,
                        y: look.y * size * depth.face + eyes.y * size * 0.04 - size * 0.05)

                // The shine: a highlight on the front of the glass.
                if detail != .flat {
                    Capsule().fill(.white.opacity(0.75))
                        .frame(width: size * 0.26, height: size * 0.1)
                        .rotationEffect(.degrees(-35))
                        .blur(radius: size * 0.01)
                        .offset(x: -size * 0.22 + look.x * size * depth.shine,
                                y: -size * 0.28 + look.y * size * depth.shine)
                }
            }
            .rotation3DEffect(.degrees(detail == .full ? Double(look.x) * 28 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(detail == .full ? Double(-look.y) * 20 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        }
        .accessibilityHidden(true)
    }

    private var eye: some View {
        ZStack {
            Capsule().fill(.white)
                .frame(width: size * 0.14, height: size * 0.2 * (1 - blink * 0.9))
            Circle().fill(Color(red: 0.08, green: 0.1, blue: 0.2))
                .frame(width: size * 0.08, height: size * 0.08 * (1 - blink))
                .offset(x: eyes.x * size * 0.03, y: eyes.y * size * 0.04)
        }
    }
}

#Preview { PipLookWonder() }
