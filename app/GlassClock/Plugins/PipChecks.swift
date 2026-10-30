import SwiftUI

// PIP CHECKS THEMSELVES · plugin v1 (On trial). After an update, Pip looks at which plugins are new or changed and
// asks "Still feel like me?". "Feels like me" keeps one; "Not me" switches it off. Nothing is deleted: Settings
// brings it back. Pip asks at most 3 times ever, then the card just quietly lists what's new.
// Works the same with Pip off: the card is the whole thing, Pip only points at it.
// Where: its button in the plugin bar.

struct PipChecks: SandboxPlugin {
    let info = PluginInfo(id: "pipchecks", name: "Pip checks themselves", version: "v1", shelf: .trial,
                          icon: "checkmark.seal", what: "After an update, Pip asks if the new bits still feel like them.")

    // MARK: Data

    enum Tune {
        static let askAfter = 8.0       // seconds after launch before Pip mentions it
        static let askFor = 3.2         // how long the line stays up
        static let asksEver = 3         // Pip offers 3 times, then stops
    }

    static let pipLine = "Something new arrived in me. Still feel like me? It's in my card."
    static let allChecked = "Nothing new to check. Still feels like Pip."
    static let note = "Switched off, never deleted: Settings brings it back."
    static let waitingKey = "plug.pipchecks.waiting"

    // MARK: Logic

    /// Every plugin's version by id, so a new plugin or a new version shows up as a change.
    static func stamps(_ host: PipHost) -> [String: String] {
        Dictionary(host.plugins.map { ($0.info.id, $0.info.version) }, uniquingKeysWith: { a, _ in a })
    }

    static func encode(_ stamps: [String: String]) -> String {
        stamps.keys.sorted().map { "\($0)=\(stamps[$0]!)" }.joined(separator: "\n")
    }

    static func decode(_ text: String) -> [String: String] {
        var out: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let part = line.split(separator: "=", maxSplits: 1).map(String.init)
            if part.count == 2 { out[part[0]] = part[1] }
        }
        return out
    }

    static func ids(_ text: String) -> Set<String> { Set(text.split(separator: "\n").map(String.init)) }
    static func text(_ ids: Set<String>) -> String { ids.sorted().joined(separator: "\n") }

    func start(_ host: PipHost) throws {
        let now = Self.stamps(host)
        defer { host.setValue(Self.encode(now), info.id, "seen") }
        // The first time, everything is "new": just remember it and ask nothing.
        guard let seenText = host.value(info.id, "seen") as String? else { return }
        let seen = Self.decode(seenText)
        let fresh = now.keys.filter { $0 != info.id && seen[$0] != now[$0] && host.isOn($0) }
        guard !fresh.isEmpty else { return }
        var waiting = Self.ids(host.value(info.id, "waiting") as String? ?? "")
        waiting.formUnion(fresh)
        host.setValue(Self.text(waiting), info.id, "waiting")
        mind.ask(host)
    }

    /// Pip mentions it once a session, and only the first 3 times ever.
    @MainActor final class Mind {
        private var asked = false

        func ask(_ host: PipHost) {
            guard !asked, (host.value("pipchecks", "asks") as Int? ?? 0) < Tune.asksEver else { return }
            host.later(Tune.askAfter) {
                guard !self.asked, PipTalkTurns.floorFree(host) else { return }
                if host.say(PipChecks.pipLine, for: Tune.askFor) {
                    self.asked = true
                    PipTalkTurns.takeFloor(host, for: Tune.askFor)
                    host.setValue((host.value("pipchecks", "asks") as Int? ?? 0) + 1, "pipchecks", "asks")
                }
            }
        }
    }

    private let mind = Mind()

    // MARK: Views

    func card(_ host: PipHost) -> some View { Checks(host: host) }

    struct Checks: View {
        let host: PipHost
        @AppStorage(PipChecks.waitingKey) private var waitingText = ""

        var body: some View {
            let waiting = PipChecks.ids(waitingText)
            let new = host.plugins.map(\.info).filter { waiting.contains($0.id) }
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                if new.isEmpty {
                    Text(PipChecks.allChecked)
                } else {
                    Text("New or changed since last time.").foregroundStyle(.secondary)
                    ForEach(new, id: \.id) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("\(p.name) \(p.version)", systemImage: p.icon)
                                Text(p.what).font(.caption).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            HStack {
                                Button("Feels like me") { settle(p.id, keep: true) }
                                    .buttonStyle(PluginCardButton())
                                    .accessibilityLabel("\(p.name) feels like Pip. Keep it.")
                                Button("Not me") { settle(p.id, keep: false) }
                                    .buttonStyle(PluginCardButton())
                                    .accessibilityLabel("\(p.name) doesn't feel like Pip. Switch it off.")
                            }
                        }
                    }
                    Text(PipChecks.note).font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        private func settle(_ id: String, keep: Bool) {
            var waiting = PipChecks.ids(waitingText)
            waiting.remove(id)
            waitingText = PipChecks.text(waiting)
            if keep { host.cheer() } else { host.setOn(id, false) }
        }
    }
}
