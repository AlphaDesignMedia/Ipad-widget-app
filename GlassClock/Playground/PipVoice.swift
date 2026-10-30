import SwiftUI

// Pip's Voice: every line Pip says, written per personality, and the small brain that decides
// when to say one. It listens to Idle Life and sends `.say` events; `PlaygroundOverlay` (or
// Pip's own view) shows them as a bubble, and VoiceOver reads them out.
//
// How this works (Swift idea: dictionaries of arrays): lines are plain data, keyed by
// personality. Writing a new line never means touching the logic below.

/// The six personalities. The user picks one; Pip is the default.
enum PipPersona: String, CaseIterable, Identifiable {
    case pip, tock, lumen, glint, biscuit, bevel
    var id: String { rawValue }

    var name: String { rawValue.capitalized }
    var vibe: String {
        switch self {
        case .pip: "Playful"
        case .tock: "Calm"
        case .lumen: "Gentle"
        case .glint: "Cheeky"
        case .biscuit: "Sleepy"
        case .bevel: "Retro"
        }
    }

    private static let key = Playground.keyPrefix + "persona"
    static var saved: PipPersona {
        get { PipPersona(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .pip }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// When a line can be said.
enum VoiceMoment: String, CaseIterable {
    /// Idling with nothing to do.
    case moan
    /// Back after a few minutes away.
    case back
    /// Back after a long time away.
    case backLong
    /// The forgetful flaw.
    case forgetful
    /// Late at night.
    case night
    /// Early morning.
    case morning
    /// Asleep.
    case sleepTalk
}

enum PipLines {
    /// Lines by moment, then by personality. Anything missing falls back to `.pip`.
    /// Rules: under about 60 characters, British English, warm, never guilt.
    static let book: [VoiceMoment: [PipPersona: [String]]] = [
        .moan: [
            .pip: ["Why have you got me open? Not complaining. Just asking.",
                   "Are we… waiting for something?",
                   "I could do a trick. Want a trick? No? Okay.",
                   "Is this a staring contest? I'm winning.",
                   "I'll just be here. Being a clock. Clocking.",
                   "Go touch glass. Not me. Other glass."],
            .tock: ["Just us and the minutes. That's fine.",
                    "No rush.",
                    "You don't need a reason to be here."],
            .lumen: ["You can leave me open as long as you like.",
                     "Resting your eyes? I'll keep watch.",
                     "It's nice, this. Quiet."],
            .glint: ["Oi. You've just been staring.",
                     "Is this app open by accident?",
                     "Blink twice if you need help.",
                     "Bold of you to open a clock and not look at it."],
            .biscuit: ["Are we both just… sitting here?",
                       "If you're not doing anything, I'm napping.",
                       "This is my favourite kind of day. Nothing."],
            .bevel: ["It looks like you're doing nothing! Would you like help with that?",
                     "User inactive. Initiating screensaver.",
                     "Press any key to continue. Any key."],
        ],
        .back: [
            .pip: ["Oh! You're back.", "Hello again!", "brb ☕… oh, you already b'd."],
            .tock: ["Welcome back.", "There you are."],
            .lumen: ["Hello again. I kept your seat warm."],
            .glint: ["Look who it is.", "Missed me? Course you did."],
            .biscuit: ["Mm? Oh. Hi. I was… awake. Totally."],
            .bevel: ["Welcome back! You've got mail. (You haven't.)"],
        ],
        .backLong: [
            .pip: ["You were gone… ages? Two minutes? One of those.",
                   "You're back! I counted every second. Then I lost count."],
            .tock: ["A long while. The minutes and I got on fine."],
            .lumen: ["You were away a while. I hope it was a good while."],
            .glint: ["Oh, NOW you want a clock."],
            .biscuit: ["I had the best nap. Thanks for leaving."],
            .bevel: ["Session restored. Your session is very important to us."],
        ],
        .forgetful: [
            .pip: ["What time is it? …Oh. Right. I live here.",
                   "I came over here for something. No idea what.",
                   "Was I in the middle of something? Probably not."],
            .glint: ["Don't tell anyone I forgot the time. I'm a clock."],
            .biscuit: ["What day is it? Don't answer, I'll forget."],
        ],
        .night: [
            .pip: ["It's late. Are you using me as a night light?",
                   "You should probably be asleep. I'm a clock, I'd know."],
            .lumen: ["It's late. Rest when you're ready."],
            .bevel: ["It is now safe to turn off your computer."],
        ],
        .morning: [
            .pip: ["Waiting for the kettle?",
                   "Morning. Don't rush. The time'll still be here."],
            .tock: ["Morning. Plenty of time."],
        ],
        .sleepTalk: [
            .pip: ["…five more minutes…", "…no, the OTHER glass…", "zzz… tick… zzz…"],
            .biscuit: ["…biscuits…", "…mm, crumbs…"],
            .bevel: ["…blue screen… no… not the blue…"],
        ],
    ]

    static func line(_ moment: VoiceMoment, _ persona: PipPersona = .saved) -> String? {
        let pool = book[moment]?[persona] ?? book[moment]?[.pip] ?? []
        return pool.randomElement()
    }
}

/// Decides when Pip talks. Calm talks rarely; Unhinged barely stops.
@MainActor
final class PipVoice {
    static let shared = PipVoice()

    static let plugin = PlaygroundPlugin(
        id: "voice", name: "Pip's Voice", icon: "🗣️", shelf: .trial,
        blurb: "Pip comments on you idling, says hello when you're back, and forgets things.")

    private var started = false
    private var lastLine = Date.distantPast

    func start() {
        guard !started else { return }
        started = true
        Playground.shared.listen { [weak self] event in self?.hear(event) }
    }

    private var isOn: Bool { Playground.shared.isOn(Self.plugin.id) }

    private func hear(_ event: PlaygroundEvent) {
        guard isOn else { return }
        let joy = JoyLevel.effective(reduceMotion: IdleLife.shared.reduceMotion)
        guard joy != .still else { return }
        switch event {
        case .welcomeBack(let away):
            say(away > 600 ? .backLong : .back)
        case .idleAct(let act):
            // Chattier joy talks more often, but never more than once every 20 seconds.
            guard Date.now.timeIntervalSince(lastLine) > 20,
                  Double.random(in: 0...1) < chance(joy) else { return }
            say(moment(for: act))
        default:
            break
        }
    }

    private func moment(for act: IdleAct) -> VoiceMoment {
        if act == .sleepTalk || act == .doze { return .sleepTalk }
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 22 || hour < 3, Bool.random() { return .night }
        if (6..<9).contains(hour), Bool.random() { return .morning }
        return Double.random(in: 0...1) < 0.15 ? .forgetful : .moan
    }

    private func chance(_ joy: JoyLevel) -> Double {
        switch joy {
        case .still: 0
        case .calm: 0.15
        case .cosy: 0.3
        case .playful: 0.5
        case .giddy: 0.7
        case .unhinged: 1
        }
    }

    private func say(_ moment: VoiceMoment) {
        guard let text = PipLines.line(moment) else { return }
        lastLine = .now
        Playground.shared.emit(.say(text))
    }
}
