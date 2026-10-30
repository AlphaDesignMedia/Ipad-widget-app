import SwiftUI

// WONDERS · plugin v1 (Dream). The little extras that make Pip feel alive, kept in one place you can find:
// the sparkles button in the plugin bar, and a Wonders section in the drawing panel.
// First wonders: Pip follows the Apple Pencil, hovering or drawing (the web sandbox's pen-follow, pip.js),
// and Pip answers what you draw (moved here from Sketch). Each wonder has its own switch, and all of them
// rest while Pip is switched off. Under simpler motion Pip stays put and only answers.
// New wonders go here: add a case to Wonder, then answer its event in on(_:_:).

struct Wonders: SandboxPlugin {
    let info = PluginInfo(id: "wonders", name: "Wonders", version: "v1", shelf: .dream,
                          icon: "sparkles", what: "Little wonders: Pip follows your Pencil and answers your drawings.")

    // MARK: Data

    enum Wonder: String, CaseIterable, Identifiable {
        case follow, answers
        var id: Self { self }
        var label: String {
            switch self {
            case .follow: "Pip follows the Pencil"
            case .answers: "Pip answers your drawings"
            }
        }
        var what: String {
            switch self {
            case .follow: "Pip trails just above the tip while you hover or draw."
            case .answers: "Draw on Pip, ring Pip, or just draw: now and then Pip says something."
            }
        }
        var key: String { "plug.wonders.\(rawValue)" }
    }

    /// The web's Sketch reactions (plugins/sketch.js), plus a line for a ring around Pip.
    enum Lines {
        static let onPip = ["Hey! That's me.", "Are you drawing on me?", "That tickles."]
        static let halo = ["A ring, just for me?", "Am I in the picture now?"]
        static let circle = ["A circle! Pretty round.", "Ooh, a loop.", "Is that the sun? Or me?"]
        static let speedy = ["Speedy!", "Whoosh."]
        static let lots = ["So many lines.", "I'm dizzy just watching."]
        static let dot = "A dot. Minimalist."
        static func milestone(_ n: Int) -> String { "\(n) strokes. It's really coming along." }
        static let any = ["Is it a cat?", "I like where this is going.", "Hmm. Modern.", "Keep going!", "Can I be in it?"]
        static let erased = ["Gone. Never happened.", "Erase with confidence."]
    }

    /// How often Pip answers (the web's): always when drawn on or ringed, otherwise 4 times in 10, never within 6 seconds.
    enum Pace {
        static let drawnOn = 2.0, quiet = 6.0, chance = 0.4
    }

    // MARK: Logic

    static func isOn(_ w: Wonder) -> Bool { UserDefaults.standard.object(forKey: w.key) as? Bool ?? true }

    /// Remembers when Pip last spoke, so a busy drawing doesn't make Pip chatter.
    @MainActor final class Mind {
        private var last = Date.distantPast
        private var followed = Date.distantPast
        private var strokes = 0

        func follow(_ at: CGPoint, _ host: PipHost) {
            host.follow(at)
            if host.pipHere, !host.pipAsleep, !host.simpler { followed = .now }
        }

        func answer(_ m: InkMark, _ host: PipHost) {
            strokes += 1
            guard host.pipHere, !host.pipAsleep else { return }
            let since = Date.now.timeIntervalSince(last)
            // Pip was trailing the Pencil, so the line passes where Pip ended up: that's not drawing on Pip.
            let chasing = Date.now.timeIntervalSince(followed) < 0.5
            if m.onPip, !chasing {
                if since > Pace.drawnOn { say(Lines.onPip.randomElement(), cheer: true, host) }
                return
            }
            if m.ringsPip, !chasing { say(Lines.halo.randomElement(), cheer: true, host); return }
            guard since > Pace.quiet, Double.random(in: 0..<1) < Pace.chance else { return }
            let line = m.closed ? Lines.circle.randomElement()
                : m.length > 1400 && m.seconds < 2 ? Lines.speedy.randomElement()
                : m.length > 2600 ? Lines.lots.randomElement()
                : hypot(m.box.width, m.box.height) < 10 ? Lines.dot
                : strokes % 10 == 0 ? Lines.milestone(strokes)
                : Lines.any.randomElement()
            say(line, cheer: false, host)
        }

        func erased(_ host: PipHost) {
            guard host.pipHere, !host.pipAsleep, Date.now.timeIntervalSince(last) > Pace.quiet,
                  Double.random(in: 0..<1) < Pace.chance else { return }
            say(Lines.erased.randomElement(), cheer: false, host)
        }

        private func say(_ line: String?, cheer: Bool, _ host: PipHost) {
            guard let line, host.say(line, for: 1.8) else { return }
            if cheer { host.cheer() }
            last = .now
        }
    }

    private let mind = Mind()

    #if DEBUG
    /// For the simulator check: `-followDemo YES` waits for Pip, wakes it, then walks a pretend Pencil
    /// across the screen for 2 seconds.
    func start(_ host: PipHost) throws {
        guard UserDefaults.standard.bool(forKey: "followDemo") else { return }
        Task { @MainActor in
            while !host.pipHere { try? await Task.sleep(for: .seconds(0.5)) }
            host.wake()
            try? await Task.sleep(for: .seconds(2))
            for i in 0...120 {
                host.post(.ink(.pencil(CGPoint(x: 300 + Double(i) * 4, y: 600 + 80 * sin(Double(i) / 12)))))
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
    #endif

    func on(_ event: PipEvent, _ host: PipHost) {
        guard case .ink(let ink) = event else { return }
        switch ink {
        case .pencil(let at): if Wonders.isOn(.follow) { mind.follow(at, host) }
        case .drew(let mark): if Wonders.isOn(.answers) { mind.answer(mark, host) }
        case .erased: if Wonders.isOn(.answers) { mind.erased(host) }
        case .cleared: break
        }
    }

    // MARK: Views

    /// Its own card in the plugin bar, and a section in Sketch's drawing panel.
    func card(_ host: PipHost) -> some View {
        VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
            Switches()
            if let note = note(host) {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    var addsTo: String? { "sketch" }
    func addOn(_ host: PipHost) -> some View { Switches() }

    private func note(_ host: PipHost) -> String? {
        if !host.pipOn { return "Pip is switched off (Settings > Accessibility), so the wonders are resting." }
        if host.simpler { return "Simpler motion is on, so Pip stays put and only answers." }
        return nil
    }

    /// One switch per wonder. Each is its own row, so the panel's card puts a line between them.
    struct Switches: View {
        var body: some View {
            ForEach(Wonder.allCases) { WonderSwitch(wonder: $0) }
        }
    }

    struct WonderSwitch: View {
        let wonder: Wonder
        @AppStorage private var on: Bool

        init(wonder: Wonder) {
            self.wonder = wonder
            _on = AppStorage(wrappedValue: true, wonder.key)
        }

        var body: some View {
            Toggle(isOn: $on) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(wonder.label)
                    Text(wonder.what).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
