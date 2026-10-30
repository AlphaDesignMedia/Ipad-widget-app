import SwiftUI

// Liquid Time: the wow. The whole screen is a tank of water and the clock's digits are glass
// windows into it. Tilt the iPad and the water sloshes, lags, overshoots and settles. Pip
// floats on the surface, bubbles rise through the digits, and a streak of light slides
// across the glass. Tap to make a splash.
//
// How this works:
// - CoreMotion gives gravity (see `MotionSource`).
// - `LiquidSim` is a spring: the water's angle chases gravity's angle, but with lag and
//   wobble, which is what makes it feel like liquid.
// - TimelineView redraws every frame; Canvas draws the water as one shape: a wavy line,
//   then everything below it.
// - The same water is drawn twice: faint across the screen, and bright inside the digits
//   (using the time as a mask).

/// The water's state between frames. A plain class: it changes every frame, and nothing
/// else needs to know.
final class LiquidSim {
    /// The water surface's angle (radians) and how fast it's turning.
    private(set) var angle = 0.0
    private(set) var spin = 0.0
    /// Extra wave height from taps; fades away.
    var splash = 0.0
    private var last: Double?

    /// Moves the water on to `time`. Safe to call more than once per frame.
    func step(time: Double, gravity: CGVector, calm: Bool) {
        let target = atan2(-gravity.dx, gravity.dy)
        guard let last else { self.last = time; angle = target; return }
        let dt = min(max(time - last, 0), 1 / 30)
        guard dt > 0 else { return }
        self.last = time
        if calm {
            angle = target
            spin = 0
        } else {
            // A soft spring: stiffness pulls toward gravity, damping lets it wobble a little.
            var diff = target - angle
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            spin += (diff * 26 - spin * 3.0) * dt
            angle += spin * dt
        }
        splash *= exp(-dt * 1.4)
    }

    /// Wave height across the surface at `x`.
    func wave(_ x: Double, _ time: Double, calm: Bool) -> Double {
        if calm { return 0 }
        let amp = 5 + min(46, abs(spin) * 34) + splash
        return amp * sin(x * 0.011 + time * 2.1) + amp * 0.45 * sin(x * 0.027 - time * 3.3)
    }
}

struct LiquidTimeView: View {
    @State private var sim = LiquidSim()
    @State private var motion = MotionSource()
    @State private var showsHint = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let clock = timeline.date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                let fontSize = min(geo.size.width / CGFloat(max(clock.count, 4)) * 1.75, geo.size.height * 0.62)
                let digits = Text(clock)
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                let g = motion.gravity(at: time)

                ZStack {
                    LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.14), Color(red: 0.02, green: 0.12, blue: 0.2)],
                                   startPoint: .top, endPoint: .bottom)

                    // Faint water across the whole screen.
                    water(time: time, gravity: g, bright: false).opacity(0.38)

                    // Bright water inside the digits.
                    water(time: time, gravity: g, bright: true)
                        .mask(digits)

                    // The glass: a faint fill and a streak of light that slides as you tilt.
                    digits.foregroundStyle(.white.opacity(0.08))
                    LinearGradient(stops: [.init(color: .clear, location: 0.35),
                                           .init(color: .white.opacity(0.7), location: 0.5),
                                           .init(color: .clear, location: 0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .offset(x: -g.dx * geo.size.width * 0.35, y: -(g.dy - 1) * geo.size.height * 0.35)
                        .blendMode(.plusLighter)
                        .mask(digits)

                    // Pip, floating on top.
                    pip(time: time, gravity: g)
                }
            }
            .contentShape(.rect)
            .onTapGesture {
                sim.splash += 34
            }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { drag in
                        guard !motion.hasSensor else { return }
                        motion.manual = CGVector(dx: drag.translation.width / 260, dy: 1)
                    }
                    .onEnded { _ in motion.manual = nil }
            )
            .overlay(alignment: .bottom) {
                if showsHint {
                    Text(motion.hasSensor ? "Tilt your iPad. Tap to splash." : "Drag to tilt. Tap to splash.")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            motion.orientation = MotionSource.currentOrientation()
            motion.start()
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 1)) { showsHint = false }
            }
        }
        .onDisappear { motion.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            motion.orientation = MotionSource.currentOrientation()
        }
        .accessibilityElement()
        .accessibilityLabel("Liquid Time. The clock is filled with water that moves as you tilt the iPad.")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// The water: a wavy surface, filled below, with bubbles rising through it.
    private func water(time: Double, gravity: CGVector, bright: Bool) -> some View {
        Canvas { ctx, size in
            sim.step(time: time, gravity: gravity, calm: reduceMotion)
            let reach = hypot(size.width, size.height)
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: .radians(sim.angle))
            let level = size.height * 0.04

            var surface = Path()
            var fill = Path()
            fill.move(to: CGPoint(x: -reach, y: reach))
            for x in stride(from: -reach, through: reach, by: 10) {
                let point = CGPoint(x: x, y: level + sim.wave(x, time, calm: reduceMotion))
                fill.addLine(to: point)
                if x == -reach { surface.move(to: point) } else { surface.addLine(to: point) }
            }
            fill.addLine(to: CGPoint(x: reach, y: reach))
            fill.closeSubpath()

            let colors: [Color] = bright
                ? [Color(red: 0.45, green: 0.95, blue: 1), Color(red: 0.1, green: 0.45, blue: 1), Color(red: 0.25, green: 0.1, blue: 0.7)]
                : [Color(red: 0.2, green: 0.6, blue: 0.9), Color(red: 0.05, green: 0.2, blue: 0.5)]
            ctx.fill(fill, with: .linearGradient(Gradient(colors: colors),
                                                 startPoint: CGPoint(x: 0, y: level - 40),
                                                 endPoint: CGPoint(x: 0, y: level + size.height * 0.6)))
            ctx.stroke(surface, with: .color(.white.opacity(bright ? 0.85 : 0.4)), lineWidth: bright ? 3 : 1.5)

            // Bubbles rise against gravity and pop at the surface.
            guard !reduceMotion else { return }
            for i in 0..<(bright ? 26 : 12) {
                let seed = Double(i) * 1.618
                let depth = size.height * 0.6
                let rise = (time * (30 + (seed * 13).truncatingRemainder(dividingBy: 40)) + seed * 97)
                    .truncatingRemainder(dividingBy: depth)
                let x = ((seed * 0.37).truncatingRemainder(dividingBy: 1) - 0.5) * size.width * 1.1 + sin(time * 1.3 + seed) * 8
                let y = level + depth - rise
                guard y > level + sim.wave(x, time, calm: false) + 4 else { continue }
                let r = 2 + (seed * 3).truncatingRemainder(dividingBy: 5)
                ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color(.white.opacity(0.7)), lineWidth: 1.2)
            }
        }
    }

    /// Pip bobbing on the surface, tilted with the water.
    private func pip(time: Double, gravity: CGVector) -> some View {
        Canvas { ctx, size in
            sim.step(time: time, gravity: gravity, calm: reduceMotion)
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: .radians(sim.angle))
            let x = size.width * 0.28
            let y = size.height * 0.04 + sim.wave(x, time, calm: reduceMotion) - 24
            ctx.translateBy(x: x, y: y)
            ctx.rotate(by: .radians(reduceMotion ? 0 : sin(time * 1.7) * 0.18 + sim.spin * 0.05))
            ctx.draw(Text("🫧").font(.system(size: 60)), at: .zero)
        }
        .allowsHitTesting(false)
    }
}

#Preview { LiquidTimeView() }
