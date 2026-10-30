import SwiftUI

// PIP REMEMBERS · plugin v1 (Grounded). Ported from the web sandbox's plugins/pip-remembers.js.
// Pip greets you when you come back, without guilt, and keeps a small notebook of your visits.
// Where: the notebook button in the plugin bar. Everything stays on this device; "Forget all of this" wipes it.
// The worked example in app/PLUGIN-SPEC.md: data, logic, then views.

struct PipRemembers: SandboxPlugin {
    let info = PluginInfo(id: "remembers", name: "Pip Remembers", version: "v1", shelf: .grounded,
                          icon: "book.closed", what: "Greets you when you come back, and keeps a notebook.")

    // MARK: Data

    struct Memory: Codable, Equatable {
        var visits = 0
        var last = Date.distantPast
        var pokes = 0
        var flicks = 0
        var bumps = 0
    }

    enum Lines {
        static let soon = "Back already? Lovely."                       // under 10 minutes away
        static let long = "Oh, hello again! I kept your clock warm."    // over 3 days away
        static let back = "Welcome back."
        static let forgot = "Forgotten. Fresh notebook."
    }

    static let key = "plug.remembers.memory"
    static let hardBump = 1150.0      // the speed at which Pip gets dizzy

    /// Session state lives in a small class, because the plugin itself is a struct made once.
    @MainActor final class Session { var greeting: String? }
    private let session = Session()

    // MARK: Logic

    static func greeting(after away: TimeInterval) -> String {
        away < 10 * 60 ? Lines.soon : away > 3 * 86_400 ? Lines.long : Lines.back
    }

    static func load() -> Memory {
        guard let data = UserDefaults.standard.data(forKey: key),
              let memory = try? JSONDecoder().decode(Memory.self, from: data) else { return Memory() }
        return memory
    }

    static func save(_ memory: Memory) {
        UserDefaults.standard.set(try? JSONEncoder().encode(memory), forKey: key)
    }

    static func change(_ edit: (inout Memory) -> Void) {
        var memory = load()
        edit(&memory)
        save(memory)
    }

    func start(_ host: PipHost) throws {
        var memory = Self.load()
        let away = Date.now.timeIntervalSince(memory.last)
        memory.visits += 1
        memory.last = .now
        Self.save(memory)
        if memory.visits > 1 { session.greeting = Self.greeting(after: away) }
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .appear, .wake: greet(host, after: 1.2)
        case .tap:
            Self.change { $0.pokes += 1 }
            greet(host, after: 1.6)
        case .flick: Self.change { $0.flicks += 1 }
        case .bump(let speed) where speed > Self.hardBump: Self.change { $0.bumps += 1 }
        default: break
        }
    }

    /// Once per launch, and only to an awake Pip: no greeting is better than waking Pip up for one.
    private func greet(_ host: PipHost, after seconds: Double) {
        guard let line = session.greeting else { return }
        host.later(seconds) {
            guard !host.pipAsleep, session.greeting != nil, host.say(line) else { return }
            session.greeting = nil
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { Notebook(host: host) }

    struct Notebook: View {
        let host: PipHost
        @AppStorage(PipRemembers.key) private var data = Data()   // redraws when the memory changes

        var body: some View {
            let memory = (try? JSONDecoder().decode(Memory.self, from: data)) ?? Memory()
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Grid(alignment: .leading, verticalSpacing: 4) {
                    row("Visits", memory.visits)
                    row("Pokes", memory.pokes)
                    row("Flicks", memory.flicks)
                    row("Hard bumps", memory.bumps)
                }
                .font(.system(size: 13.5))
                Text("Everything here stays on this device.")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
                Button("Forget all of this") {
                    PipRemembers.save(Memory(visits: 1, last: .now))
                    host.say(Lines.forgot, for: 1.6)
                }
                .buttonStyle(PluginCardButton())
            }
        }

        private func row(_ label: String, _ value: Int) -> some View {
            GridRow {
                Text(label).bold()
                Text("\(value)").monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }
}
