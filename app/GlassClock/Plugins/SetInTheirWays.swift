import SwiftUI

// PIP DOESN'T LIKE CHANGE · plugin v1 (Dream). Change a setting and Pip grumbles about it, saying what it was
// and what it is now, with a small "Change it back" chip. Change it back and Pip is suddenly delighted: it was
// the best choice all along, Pip always said so. Leave it and Pip slowly comes round ("It's growing on me").
// Watches only the app's own look settings, and grumbles at most once a minute, so it never nags.
// Where: the arrow-loop button in the plugin bar (which settings Pip cares about, and how grumpy).

struct SetInTheirWays: SandboxPlugin {
    let info = PluginInfo(id: "change", name: "Pip Doesn't Like Change", version: "v1", shelf: .dream,
                          icon: "arrow.uturn.backward.circle", what: "Pip grumbles when settings change. Change it back and Pip loves it.")

    // MARK: Data

    /// The app's settings Pip has opinions about: key, and a plain name for it.
    static let watched: [(key: String, name: String)] = [
        ("appColor", "the app colour"),
        ("appTheme", "the theme"),
        ("appAppearance", "light and dark"),
        ("glassAmount", "the glass"),
        ("interfaceStyle", "the layout"),
        ("previewBackdrop", "the backdrop"),
        ("workspaceLayout", "where things go"),
        ("pipJoy", "my joy level"),
    ]

    enum Lines {
        static func grumble(_ what: String, from old: String, to new: String) -> [String] {
            ["You changed \(what). From \(old) to \(new). I'm not upset. I'm just… processing.",
             "\(new.capitalized)? For \(what)? It was \(old). We were happy.",
             "Oh. Oh, we're doing \(new) now, are we. Lovely. Fine. Lovely.",
             "Nobody asked me about \(what). I'd have said \(old)."]
        }
        static let revert = ["YES. That's it. Perfect. Best choice. I always said so.",
                             "Oh, that's gorgeous. Who picked this? Genius.",
                             "See? Classic. Timeless. I knew you'd come round."]
        static let comeRound = ["It's growing on me. Don't tell anyone.", "Actually… I quite like it now.",
                                "Fine. It's nice. I was wrong. Once."]
    }

    enum Grumpiness: String, CaseIterable {
        case mild, proper
        var label: String { rawValue.capitalized }
        var gap: Double { self == .mild ? 120 : 45 }   // seconds between grumbles
    }

    // MARK: Logic

    @MainActor @Observable final class Watch {
        var offer: Offer?
        @ObservationIgnored var last: [String: String] = [:]
        @ObservationIgnored var lastRaw: [String: Any] = [:]
        @ObservationIgnored var lastGrumble = Date.distantPast
        @ObservationIgnored var listening = false
        @ObservationIgnored var restoring = false
    }

    struct Offer: Equatable {
        let key: String
        let old: Any?
        let oldText: String
        let id = UUID()
        static func == (a: Offer, b: Offer) -> Bool { a.id == b.id }
    }

    private let watch = Watch()

    static func text(_ value: Any?) -> String {
        switch value {
        case nil: "the default"
        case let s as String: s.isEmpty ? "the default" : s.replacingOccurrences(of: "#", with: "colour #")
        case let n as NSNumber: n.stringValue
        default: "\(value!)"
        }
    }

    static func rawSnapshot() -> [String: Any] {
        var out: [String: Any] = [:]
        for w in watched { if let v = UserDefaults.standard.object(forKey: w.key) { out[w.key] = v } }
        return out
    }

    static func snapshot() -> [String: String] {
        Dictionary(uniqueKeysWithValues: watched.map { ($0.key, text(UserDefaults.standard.object(forKey: $0.key))) })
    }

    func start(_ host: PipHost) throws {
        watch.last = Self.snapshot()
        watch.lastRaw = Self.rawSnapshot()
        guard !watch.listening else { return }
        watch.listening = true
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { changed(host) }
        }
    }

    private func changed(_ host: PipHost) {
        let now = Self.snapshot()
        let previousRaw = watch.lastRaw
        defer {
            watch.last = now
            watch.lastRaw = Self.rawSnapshot()
        }
        guard host.isOn("change"), !watch.restoring,
              let item = Self.watched.first(where: { now[$0.key] != watch.last[$0.key] }) else { return }
        let grumpy = Grumpiness(rawValue: host.value("change", "grumpiness") ?? "") ?? .mild
        guard Date.now.timeIntervalSince(watch.lastGrumble) > grumpy.gap else { return }
        let oldText = watch.last[item.key] ?? "the default"
        let newText = now[item.key] ?? "the default"
        watch.lastGrumble = .now
        host.say(Lines.grumble(item.name, from: oldText, to: newText).randomElement()!, for: 3.6)
        NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: "😤")
        watch.offer = Offer(key: item.key, old: previousRaw[item.key], oldText: oldText)
        host.later(8) {
            if watch.offer?.key == item.key { watch.offer = nil }
        }
        host.later(grumpy.gap * 3) {
            if UserDefaults.standard.object(forKey: item.key).map({ Self.text($0) }) == newText, Int.random(in: 0..<2) == 0 {
                host.say(Lines.comeRound.randomElement()!, for: 2.4)
            }
        }
    }

    fileprivate func changeBack(_ host: PipHost) {
        guard let offer = watch.offer else { return }
        watch.offer = nil
        watch.restoring = true
        if let old = offer.old {
            UserDefaults.standard.set(old, forKey: offer.key)
        } else {
            UserDefaults.standard.removeObject(forKey: offer.key)
        }
        watch.last = Self.snapshot()
        watch.lastRaw = Self.rawSnapshot()
        watch.restoring = false
        host.cheer()
        host.say(Lines.revert.randomElement()!, for: 3)
        NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: "😍")
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Chip(plugin: self, watch: watch, host: host) }

    func card(_ host: PipHost) -> some View { GrumpCard(host: host) }

    /// "Change it back", just under Pip, for a few seconds after a grumble. The only thing here that takes touches.
    struct Chip: View {
        let plugin: SetInTheirWays
        let watch: Watch
        let host: PipHost

        var body: some View {
            ZStack {
                if let offer = watch.offer, host.pipHere {
                    let p = host.pipPosition
                    Button {
                        plugin.changeBack(host)
                    } label: {
                        Label("Change it back", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(PluginCardButton(on: true))
                    .accessibilityHint("Puts \(offer.oldText) back.")
                    .position(x: p.x, y: p.y + 48)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(host.simpler ? nil : .snappy, value: watch.offer)
        }
    }

    struct GrumpCard: View {
        let host: PipHost
        @AppStorage("plug.change.grumpiness") private var grumpiness = Grumpiness.mild.rawValue

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("How grumpy").bold()
                HStack(spacing: 6) {
                    ForEach(Grumpiness.allCases, id: \.self) { g in
                        Button(g.label) { grumpiness = g.rawValue }
                            .buttonStyle(PluginCardButton(on: grumpiness == g.rawValue))
                            .accessibilityAddTraits(grumpiness == g.rawValue ? .isSelected : [])
                    }
                }
                Text("Pip has opinions about: " + SetInTheirWays.watched.map(\.name).joined(separator: ", ") + ".")
                    .foregroundStyle(.secondary)
                Text("Change something back and watch Pip's face.").foregroundStyle(.secondary)
            }
            .font(.system(size: 13.5))
        }
    }
}
