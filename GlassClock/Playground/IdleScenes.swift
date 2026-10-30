import SwiftUI

// Idle Scenes: little things that drift across the screen while you're away. A fish swims
// past, bubbles rise, a paper plane loops, Pip bounces corner to corner like an old DVD logo
// (and the screen cheers if it hits the corner exactly). Deep idle brings out the stars.
//
// How this works (Swift idea: TimelineView): the view redraws itself every frame from the
// time alone, so there's no animation state to keep in sync. Each scene is a pure function of
// "seconds since it started".

enum IdleScene: String, CaseIterable {
    case fish, bubbles, plane, bounce, stars

    /// How long the scene plays, in seconds.
    var length: Double {
        switch self {
        case .fish: 9
        case .bubbles: 7
        case .plane: 8
        case .bounce: 14
        case .stars: 20
        }
    }
    var caption: String {
        switch self {
        case .fish: "A fish swims past the clock."
        case .bubbles: "Bubbles rise up the screen."
        case .plane: "Pip throws a paper plane."
        case .bounce: "Pip bounces from corner to corner."
        case .stars: "The stars come out."
        }
    }
    /// Scenes that sweep across the screen. Reduce Motion only gets the calm ones.
    var sweeps: Bool { self != .stars }

    static let plugin = PlaygroundPlugin(
        id: "scenes", name: "Idle Scenes", icon: "🌙", shelf: .dream,
        blurb: "Fish, bubbles, paper planes and stars while you leave the app alone.")
}

@Observable @MainActor
final class IdleScenes {
    static let shared = IdleScenes()

    private(set) var playing: IdleScene?
    private(set) var startedAt = Date.now
    @ObservationIgnored private var started = false

    func start() {
        guard !started else { return }
        started = true
        Playground.shared.listen { [weak self] event in self?.hear(event) }
    }

    func play(_ scene: IdleScene) {
        playing = scene
        startedAt = .now
        AccessibilityNotification.Announcement(scene.caption).post()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(scene.length))
            if self?.playing == scene { self?.playing = nil }
        }
    }

    private func hear(_ event: PlaygroundEvent) {
        guard Playground.shared.isOn(IdleScene.plugin.id) else { return }
        let reduceMotion = IdleLife.shared.reduceMotion
        let joy = JoyLevel.effective(reduceMotion: reduceMotion)
        switch event {
        case .touched:
            playing = nil
        case .idleStage(.deepIdle):
            play(.stars)
        case .idleAct:
            guard playing == nil, IdleLife.shared.stage >= .wondering, joy.allowsSurprises || joy >= .cosy,
                  Double.random(in: 0...1) < (joy >= .giddy ? 0.6 : 0.3) else { return }
            let choices = IdleScene.allCases.filter { $0 != .stars && !(reduceMotion && $0.sweeps) }
            if let scene = choices.randomElement() { play(scene) }
        default:
            break
        }
    }
}

/// Draws the scene that's playing. Put it on top of everything; it never takes touches.
struct IdleScenesView: View {
    @State private var scenes = IdleScenes.shared

    var body: some View {
        GeometryReader { geo in
            if let scene = scenes.playing {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSince(scenes.startedAt)
                    let p = min(max(t / scene.length, 0), 1)
                    SceneFrame(scene: scene, t: t, p: p, size: geo.size)
                }
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.6), value: scenes.playing)
    }
}

/// One frame of a scene: where everything is at time `t` (seconds), `p` (0…1 through it).
private struct SceneFrame: View {
    let scene: IdleScene
    let t: Double
    let p: Double
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        // Fade in and out at the ends so nothing pops.
        let fade = min(1, min(p, 1 - p) * 8)
        ZStack {
            switch scene {
            case .fish:
                Text("🐟").font(.system(size: 54))
                    .scaleEffect(x: -1)
                    .position(x: -60 + (w + 120) * p, y: h * 0.72 + sin(t * 2.4) * 18)
                Text("🫧").font(.system(size: 16))
                    .position(x: -40 + (w + 120) * p, y: h * 0.66 - (t.truncatingRemainder(dividingBy: 1.5)) * 40)
            case .bubbles:
                ForEach(0..<14, id: \.self) { i in
                    let seed = Double(i) * 1.37
                    let rise = (t * (40 + seed.truncatingRemainder(dividingBy: 3) * 25) + seed * 90)
                        .truncatingRemainder(dividingBy: h + 80)
                    Text("🫧").font(.system(size: 14 + seed.truncatingRemainder(dividingBy: 4) * 8))
                        .position(x: w * (0.08 + (seed * 0.61).truncatingRemainder(dividingBy: 0.84)) + sin(t + seed) * 14,
                                  y: h + 40 - rise)
                }
            case .plane:
                let x = -60 + (w + 120) * p
                let y = h * 0.35 + sin(p * .pi * 2) * h * 0.18
                Text("✈️").font(.system(size: 40))
                    .rotationEffect(.degrees(cos(p * .pi * 2) * -25))
                    .position(x: x, y: y)
            case .bounce:
                let corner = bounce(t: t, w: w, h: h)
                Text("🫧").font(.system(size: 64))
                    .position(corner.point)
                if corner.hitCorner {
                    Text("🎉 CORNER!").font(.largeTitle.bold())
                        .position(x: w / 2, y: h / 2)
                }
            case .stars:
                ForEach(0..<40, id: \.self) { i in
                    let seed = Double(i) * 2.17
                    let twinkle = 0.3 + 0.7 * abs(sin(t * (0.6 + seed.truncatingRemainder(dividingBy: 1)) + seed))
                    Text(i % 7 == 0 ? "✨" : "·")
                        .font(.system(size: i % 7 == 0 ? 16 : 26))
                        .foregroundStyle(.white)
                        .opacity(twinkle)
                        .position(x: w * (seed * 0.37).truncatingRemainder(dividingBy: 1),
                                  y: h * 0.45 * (seed * 0.53).truncatingRemainder(dividingBy: 1))
                }
            }
        }
        .opacity(fade)
    }

    /// The DVD-logo bounce: straight lines, reflecting off each edge.
    private func bounce(t: Double, w: CGFloat, h: CGFloat) -> (point: CGPoint, hitCorner: Bool) {
        let r: Double = 36
        let spanX = max(Double(w) - r * 2, 1), spanY = max(Double(h) - r * 2, 1)
        let speed = 180.0
        func fold(_ d: Double, _ span: Double) -> Double {
            let m = d.truncatingRemainder(dividingBy: span * 2)
            return m < span ? m : span * 2 - m
        }
        let dx = t * speed, dy = t * speed * 0.77
        let x = fold(dx, spanX), y = fold(dy, spanY)
        let nearX = x < 6 || x > spanX - 6, nearY = y < 6 || y > spanY - 6
        return (CGPoint(x: x + r, y: y + r), nearX && nearY)
    }
}
