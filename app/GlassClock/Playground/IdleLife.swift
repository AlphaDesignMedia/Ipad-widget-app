import SwiftUI

// Idle Life: the playground feels alive while you do nothing. The longer the screen goes
// untouched, the further Pip drifts from "ready to help" to "doing its own thing". It only
// decides *what* happens; Pip (or any plugin) listens for `.idleAct` and acts it out.
//
// How this works (Swift idea: async tasks): one small loop wakes now and then, works out how
// long it's been since the last touch, and sends an event. Touching resets it. Nothing runs
// while the slider is on Still.

/// How long it's been since anyone touched the screen, as a mood.
enum IdleStage: Int, CaseIterable, Comparable {
    case busy, settling, bored, wondering, ownBusiness, deepIdle

    /// Seconds untouched before this stage starts, at Cosy. Other joy levels scale these.
    var startsAfter: Double {
        switch self {
        case .busy: 0
        case .settling: 20
        case .bored: 60
        case .wondering: 180
        case .ownBusiness: 480
        case .deepIdle: 900
        }
    }
    var name: String {
        switch self {
        case .busy: "Busy"
        case .settling: "Settling"
        case .bored: "Bored"
        case .wondering: "Wondering"
        case .ownBusiness: "Own business"
        case .deepIdle: "Deep idle"
        }
    }
    /// What Pip might do at this stage.
    var acts: [IdleAct] {
        switch self {
        case .busy: []
        case .settling: [.look, .blink]
        case .bored: [.look, .yawn, .hum, .tap]
        case .wondering: [.hum, .spin, .peek, .knock, .minute]
        case .ownBusiness: [.lap, .spin, .peek, .hum, .minute]
        case .deepIdle: [.doze, .sleepTalk]
        }
    }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// One small thing Pip does while idling.
enum IdleAct: String, CaseIterable {
    case look, blink, yawn, hum, spin, lap, tap, minute, peek, knock, doze, sleepTalk

    /// Spoken by VoiceOver and shown in the debug panel.
    var caption: String {
        switch self {
        case .look: "Pip looks around."
        case .blink: "Pip blinks."
        case .yawn: "Pip yawns."
        case .hum: "Pip hums a little tune."
        case .spin: "Pip does a slow spin."
        case .lap: "Pip does a lap of the screen."
        case .tap: "Pip taps the glass."
        case .minute: "Pip watches the minute change."
        case .peek: "Pip peeks behind the clock."
        case .knock: "Pip knocks on the glass. Anyone there?"
        case .doze: "Pip dozes off."
        case .sleepTalk: "Pip mumbles in its sleep."
        }
    }
    /// Acts that move Pip around the screen. Reduce Motion skips these.
    var moves: Bool { [.spin, .lap, .peek].contains(self) }
}

@Observable @MainActor
final class IdleLife {
    static let shared = IdleLife()

    static let plugin = PlaygroundPlugin(
        id: "idle", name: "Idle Life", icon: "💤", shelf: .trial,
        blurb: "Pip gets up to things while you leave the app open.")

    private(set) var stage: IdleStage = .busy
    private(set) var lastAct: IdleAct?
    private(set) var lastTouch = Date.now
    /// Set from the view, which can read the system setting.
    var reduceMotion = false

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var nextActAt = Date.distantFuture

    private var joy: JoyLevel { JoyLevel.effective(reduceMotion: reduceMotion) }
    private var isOn: Bool { Playground.shared.isOn(Self.plugin.id) && joy != .still }

    /// Call on any touch. Coming back after a long time gets a hello.
    func touched() {
        let away = Int(Date.now.timeIntervalSince(lastTouch))
        let wasAway = stage >= .wondering
        lastTouch = .now
        setStage(.busy)
        Playground.shared.emit(.touched)
        if wasAway && isOn { Playground.shared.emit(.welcomeBack(awaySeconds: away)) }
    }

    /// For testing: act as if nobody has touched the screen for this long.
    func pretend(idleFor seconds: Double) {
        lastTouch = .now.addingTimeInterval(-seconds)
        nextActAt = .now
        tick()
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    private func tick() {
        guard isOn else { setStage(.busy); return }
        let idle = Date.now.timeIntervalSince(lastTouch) * joy.idlePace
        let now = IdleStage.allCases.last { idle >= $0.startsAfter } ?? .busy
        setStage(now)
        guard Date.now >= nextActAt else { return }
        scheduleNextAct()
        let choices = now.acts.filter { !(reduceMotion && $0.moves) }
        guard let act = choices.randomElement() else { return }
        lastAct = act
        Playground.shared.emit(.idleAct(act))
    }

    private func setStage(_ new: IdleStage) {
        guard new != stage else { return }
        stage = new
        if new == .busy { nextActAt = .distantFuture } else if nextActAt == .distantFuture { scheduleNextAct() }
        Playground.shared.emit(.idleStage(new))
    }

    private func scheduleNextAct() {
        nextActAt = .now.addingTimeInterval(.random(in: joy.actGap))
    }
}
