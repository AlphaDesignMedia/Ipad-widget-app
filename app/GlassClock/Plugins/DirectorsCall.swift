import SwiftUI
import UIKit

// DIRECTOR'S CALL · plugin v1 (Dream). Aaron is the director in real life; here he directs Pip.
// Pick a scene, tap "Action!": a clapper snaps (with a tap in your hand) and Pip performs it with looks, a few
// short lines and small steps, under a soft spotlight that follows them. "Cut!" stops it at once.
// Takes are counted. Now and then Pip fluffs a line and asks "From the top?" (kind, funny).
// Starts only when you tap Action!: never on its own, so it spends nothing from Pip's talk budget.
// Joy 0: no lines, just the clapper and the light. Simpler motion: no steps, fades only.
// Pip off: the clapperboard still works, with a little paper-cut star as the actor.
// Where: the clapperboard button in the plugin bar.

struct DirectorsCall: SandboxPlugin {
    let info = PluginInfo(id: "director", name: "Director's Call", version: "v1", shelf: .dream,
                          icon: "movieclapper",
                          what: "Pick a scene, say Action, and Pip performs it. Cut stops it.")

    // MARK: Data

    /// One thing that happens in a scene.
    enum Act {
        case line(String, Double)           // Pip says it, for this many seconds
        case look(Double, Double)           // eyes towards a point this far from Pip (x, y)
        case face(PipFace)
        case step(Double, Double)           // Pip glides this far (not under simpler motion)
        case light(Double)                  // the spotlight, 0...1
        case cheer
        case star(Double, Double)           // the paper star: place across the stage (0...1) and size
    }

    struct Beat {
        let wait: Double                    // pause before this happens
        let act: Act
    }

    enum Shot: Int, CaseIterable, Identifiable {
        case entrance, reveal, sadExit, pause, bow
        var id: Int { rawValue }

        var name: String { ["Entrance", "Big reveal", "Sad exit", "Dramatic pause", "Take a bow"][rawValue] }
        var symbol: String { ["door.left.hand.open", "sparkles", "cloud.rain", "ellipsis", "hands.clap"][rawValue] }

        var beats: [Beat] {
            switch self {
            case .entrance:
                return [Beat(wait: 0, act: .light(1)), Beat(wait: 0, act: .star(0.1, 0.8)),
                        Beat(wait: 0.5, act: .look(-220, 0)), Beat(wait: 0.4, act: .step(-90, 0)),
                        Beat(wait: 0.9, act: .star(0.5, 1)), Beat(wait: 0, act: .step(90, 0)),
                        Beat(wait: 0.8, act: .face(.happy)),
                        Beat(wait: 0.2, act: .line("Ta-daa. I have arrived.", 2.2)),
                        Beat(wait: 1.8, act: .cheer), Beat(wait: 1.2, act: .light(0))]
            case .reveal:
                return [Beat(wait: 0, act: .light(0.25)), Beat(wait: 0, act: .star(0.5, 0.5)),
                        Beat(wait: 0.4, act: .face(.curious)), Beat(wait: 0.2, act: .look(0, -160)),
                        Beat(wait: 0.4, act: .line("And now... the big reveal.", 2.4)),
                        Beat(wait: 2.2, act: .light(1)), Beat(wait: 0, act: .star(0.5, 1.2)),
                        Beat(wait: 0.5, act: .cheer),
                        Beat(wait: 0.2, act: .line("Me. Surprise!", 1.8)),
                        Beat(wait: 2.2, act: .light(0))]
            case .sadExit:
                return [Beat(wait: 0, act: .light(0.6)), Beat(wait: 0, act: .star(0.5, 0.9)),
                        Beat(wait: 0.3, act: .face(.sleepy)),
                        Beat(wait: 0.3, act: .line("Nobody believes in me.", 2.4)),
                        Beat(wait: 2.4, act: .look(-260, 80)), Beat(wait: 0.3, act: .step(-80, 30)),
                        Beat(wait: 0.1, act: .star(0.05, 0.6)),
                        Beat(wait: 0.4, act: .line("Farewell, cruel desk.", 2.2)),
                        Beat(wait: 1.8, act: .step(80, -30)), Beat(wait: 0.5, act: .light(0))]
            case .pause:
                return [Beat(wait: 0, act: .light(0.7)), Beat(wait: 0, act: .star(0.5, 1)),
                        Beat(wait: 0.4, act: .face(.curious)), Beat(wait: 0.2, act: .look(200, -20)),
                        Beat(wait: 2.2, act: .line("...", 1.6)),
                        Beat(wait: 2.4, act: .look(-200, -20)),
                        Beat(wait: 1.4, act: .line("Right. Where was I?", 2.2)),
                        Beat(wait: 2.0, act: .light(0))]
            case .bow:
                return [Beat(wait: 0, act: .light(1)), Beat(wait: 0, act: .star(0.5, 1)),
                        Beat(wait: 0.3, act: .face(.happy)), Beat(wait: 0.2, act: .step(0, 36)),
                        Beat(wait: 0.2, act: .star(0.5, 0.8)),
                        Beat(wait: 0.4, act: .line("Thank you, thank you. Tea's in the kitchen.", 2.8)),
                        Beat(wait: 0.8, act: .step(0, -36)), Beat(wait: 0, act: .star(0.5, 1.1)),
                        Beat(wait: 0.2, act: .cheer),
                        Beat(wait: 2.6, act: .light(0))]
            }
        }
    }

    enum Tune {
        static let fluffChance = 0.18           // per take, at Joy 1 or more, with Pip on
        static let fluffs = [
            "To be or not to... pancakes? Sorry. From the top?",
            "Um. What was my line? From the top?",
            "I said it with my whole glow. Shall we go again? From the top?",
        ]
        static let spotRadius: CGFloat = 150
        static let stageHeight: CGFloat = 60
    }

    /// True when Pip should fluff this take. Takes a roll so it can be tested.
    static func shouldFluff(roll: Double, joy: Int, pipHere: Bool, lastWasFluff: Bool) -> Bool {
        pipHere && joy >= 1 && !lastWasFluff && roll < Tune.fluffChance
    }

    // MARK: Logic

    let stage = DirectorStage()

    func start(_ host: PipHost) throws {}

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .flick(let speed):
            // Someone grabbed Pip and threw them: the scene is over.
            if speed > 1150, stage.running { stage.cut(host) }
        default:
            break
        }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { SpotlightLayer(stage: stage, host: host) }

    func card(_ host: PipHost) -> some View { DirectorCard(stage: stage, host: host) }
}

// MARK: The state and the running of a scene (one small class; the plugin itself is a struct)

@MainActor @Observable
final class DirectorStage {
    var chosen: DirectorsCall.Shot = .entrance
    var running = false
    var take = 0                    // takes started this session
    var light = 0.0                 // spotlight strength, 0...1
    var starX = 0.5
    var starScale = 1.0
    var caption = ""
    var fluffed = false             // the last take ended in a fluff: the button says "From the top"
    var snap = 0                    // goes up each Action!, so the clapper can react

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastWasFluff = false

    func action(_ host: PipHost) {
        task?.cancel()
        take += 1
        snap += 1
        caption = ""
        let fluff = DirectorsCall.shouldFluff(roll: Double.random(in: 0..<1), joy: host.joy,
                                              pipHere: host.pipHere && !host.pipAsleep, lastWasFluff: lastWasFluff)
        lastWasFluff = fluff
        fluffed = false
        running = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let shot = chosen
        let beats = shot.beats
        let total = beats.reduce(0) { $0 + $1.wait } + 3
        PipTalkTurns.takeFloor(host, for: total)
        task = Task { @MainActor [weak self, weak host] in
            guard let self, let host else { return }
            let origin = host.pipPosition
            var fluffPending = fluff
            try? await Task.sleep(for: .seconds(0.35))      // the clap, then the scene
            for beat in beats {
                if beat.wait > 0 { try? await Task.sleep(for: .seconds(beat.wait)) }
                if Task.isCancelled { return }
                guard host.isOn("director") else {      // switched off mid-scene: stop quietly
                    PipTalkTurns.takeFloor(host, for: 0)
                    self.finish()
                    return
                }
                if case .line(_, _) = beat.act, fluffPending {
                    fluffPending = false
                    self.fluff(host)
                    return
                }
                self.perform(beat.act, host)
            }
            if !host.simpler, host.pipHere {
                // Home again, if the steps wandered off.
                let now = host.pipPosition
                if abs(now.x - origin.x) > 4 || abs(now.y - origin.y) > 4 { host.move(to: origin) }
            }
            self.finish()
        }
    }

    /// Cut! Stops now: no more lines, the light goes out.
    func cut(_ host: PipHost) {
        task?.cancel()
        task = nil
        running = false
        caption = ""
        withAnimation(.easeOut(duration: 0.4)) { light = 0 }
        PipTalkTurns.takeFloor(host, for: 0)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func finish() {
        running = false
        task = nil
        withAnimation(.easeOut(duration: 0.6)) { light = 0 }
    }

    private func fluff(_ host: PipHost) {
        let line = DirectorsCall.Tune.fluffs.randomElement() ?? "From the top?"
        host.react(.shy, for: 1.6)
        host.say(line, for: 3)
        caption = line
        fluffed = true
        running = false
        task = nil
        host.later(3.2) { [weak self] in
            guard let self else { return }
            if !self.running { withAnimation(.easeOut(duration: 0.6)) { self.light = 0 } }
        }
    }

    private func perform(_ act: DirectorsCall.Act, _ host: PipHost) {
        switch act {
        case .line(let text, let seconds):
            guard host.joy > 0 else { return }
            host.say(text, for: seconds)
            caption = text
        case .look(let dx, let dy):
            let p = host.pipPosition
            host.lookAt(CGPoint(x: p.x + dx, y: p.y + dy))
        case .face(let face):
            if host.joy > 0 { host.react(face, for: 1.6) }
        case .step(let dx, let dy):
            guard !host.simpler, host.pipHere else { return }
            let p = host.pipPosition
            host.move(to: CGPoint(x: p.x + dx, y: p.y + dy))
        case .light(let level):
            withAnimation(.easeInOut(duration: 0.7)) { light = level }
        case .cheer:
            if host.joy > 0 { host.cheer() }
        case .star(let x, let size):
            if host.simpler {
                starX = 0.5
                withAnimation(.easeInOut(duration: 0.5)) { starScale = size }
            } else {
                withAnimation(.easeInOut(duration: 0.8)) { starX = x; starScale = size }
            }
        }
    }
}

// MARK: The spotlight, over the app

/// A soft pool of light on Pip. Never takes a touch. Shows only while it has some light, and fades out.
private struct SpotlightLayer: View {
    let stage: DirectorStage
    let host: PipHost

    var body: some View {
        ZStack {
            if stage.light > 0.01, host.pipHere {
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.42), Color.yellow.opacity(0.12), Color.clear],
                                         center: .center, startRadius: 4, endRadius: DirectorsCall.Tune.spotRadius))
                    .frame(width: DirectorsCall.Tune.spotRadius * 2, height: DirectorsCall.Tune.spotRadius * 2)
                    .opacity(stage.light)
                    .position(host.pipPosition)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: stage.light > 0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: The card

private struct DirectorCard: View {
    let stage: DirectorStage
    let host: PipHost
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
            board
            actorStrip
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(DirectorsCall.Shot.allCases) { shot in
                    Button { stage.chosen = shot } label: {
                        Label(shot.name, systemImage: shot.symbol)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PluginCardButton(on: stage.chosen == shot))
                    .accessibilityLabel("Scene: \(shot.name)")
                    .accessibilityAddTraits(stage.chosen == shot ? .isSelected : [])
                }
            }
            HStack(spacing: 8) {
                Button { action() } label: {
                    Text(stage.fluffed ? "From the top!" : "Action!").frame(maxWidth: .infinity)
                }
                .buttonStyle(PluginCardButton(on: true))
                .accessibilityLabel(stage.fluffed ? "From the top: start the scene again" : "Action: start the scene")
                Button { stage.cut(host) } label: {
                    Text("Cut!").frame(maxWidth: .infinity)
                }
                .buttonStyle(PluginCardButton())
                .disabled(!stage.running)
                .accessibilityLabel("Cut: stop the scene now")
            }
            Text(note).font(.system(size: 13.5)).foregroundStyle(.secondary)
        }
    }

    private var note: String {
        if !host.pipHere { return "Pip is away, so a paper star is standing in." }
        if host.joy == 0 { return "Joy is at 0, so it is only the clapper and the light." }
        return "Pip only performs when you say Action."
    }

    private func action() {
        if host.simpler {
            open = false
        } else {
            open = true
            withAnimation(.easeIn(duration: 0.12).delay(0.08)) { open = false }
        }
        stage.action(host)
    }

    // The clapperboard: sticks with stripes, a slate with the scene and the take.
    private var board: some View {
        VStack(spacing: 2) {
            sticks
                .rotationEffect(.degrees(open ? -24 : 0), anchor: .bottomLeading)
                .overlay {
                    if host.simpler {
                        Color.white.opacity(stage.snap > 0 && stage.running ? 0.25 : 0)
                            .animation(.easeOut(duration: 0.4), value: stage.snap)
                    }
                }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCENE").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    Text(stage.chosen.name).font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TAKE").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    Text("\(max(stage.take, 1))").font(.system(size: 15, weight: .semibold).monospacedDigit())
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 8))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clapperboard. Scene \(stage.chosen.name), take \(max(stage.take, 1))")
    }

    private var sticks: some View {
        HStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { i in
                Rectangle().fill(i % 2 == 0 ? Color.primary.opacity(0.8) : Color.primary.opacity(0.12))
            }
        }
        .frame(height: 16)
        .clipShape(.rect(cornerRadius: 4))
    }

    // Where the actor stands: Pip is on the real screen, so this is the paper star, or just the caption.
    private var actorStrip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05))
            if !host.pipHere {
                GeometryReader { geo in
                    ZStack {
                        Image(systemName: "star.fill").foregroundStyle(Color.black.opacity(0.18)).offset(x: 2, y: 3)
                        Image(systemName: "star.fill").foregroundStyle(Color.yellow)
                    }
                    .font(.system(size: 28))
                    .scaleEffect(stage.starScale)
                    .position(x: geo.size.width * stage.starX, y: geo.size.height / 2)
                    .opacity(stage.running || stage.light > 0.01 ? 1 : 0.5)
                    .shadow(color: Color.yellow.opacity(0.6 * stage.light), radius: 14)
                }
            }
            if !stage.caption.isEmpty && (host.pipHere == false) {
                Text(stage.caption)
                    .font(.system(size: 13.5)).multilineTextAlignment(.center).padding(.horizontal, 8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(height: DirectorsCall.Tune.stageHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage.caption.isEmpty ? "Stage" : stage.caption)
    }
}
