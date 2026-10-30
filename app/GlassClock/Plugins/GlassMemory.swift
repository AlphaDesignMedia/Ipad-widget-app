import SwiftUI

// GLASS MEMORY · plugin v1 (Dream). The glass remembers. Two small ideas in one plugin:
// 1. Pip trails: when Pip is flicked or bumps an edge, they leave a very faint, soft smudge or two where they flew.
//    The marks fade in slowly, stay on the device (capped at 60, the oldest go first) and grow a little stronger over
//    a few days, like a ghost sketch layer. They never take a touch. Joy 0: none. Joy 1: barely there.
//    "Clean the glass" wipes them; so does Window Cleaner Pip when it finishes (it posts "glass.cleaned").
// 2. Glass ink: how Sketch's drawings look. Normal (as ever), Soft (see-through) or Frosted glass (blurred edge, a
//    glassy glint). Works with Pip off. Sketch reads the choice (see `Layer` in Sketch.swift); Normal changes nothing.
// Simpler motion: marks just appear, no fade, no shimmer. Pip off: no new trails.
// Where: the dashed-square button in the plugin bar.

struct GlassMemory: SandboxPlugin {
    let info = PluginInfo(id: "glassmemory", name: "Glass Memory", version: "v1", shelf: .dream,
                          icon: "square.dashed", what: "The glass remembers where Pip flew, and drawings can look like frosted glass.")

    // MARK: Data

    enum Tune {
        static let cap = 60                     // marks kept, at most
        static let step = 0.1                   // seconds between looks at Pip while they fly
        static let maxTicks = 30                // a flight is followed for 3 seconds at most
        static let gap: CGFloat = 46            // how far Pip travels between marks
        static let perFlight = 5                // marks per flight, at most
        static let fadeIn = 9.0                 // seconds for a new mark to appear
        static let growDays = 5.0               // days for a mark to reach full strength
        static let shortest = 26.0
        static let longest = 90.0
        /// How strong a mark can get, by Joy (0: none).
        static func strength(joy: Int) -> Double { [0, 0.09, 0.13, 0.18, 0.24, 0.3][min(max(joy, 0), 5)] }
    }

    /// One faint smudge: where, which way, how big, and when (so it can strengthen over days).
    struct Mark: Codable, Identifiable, Sendable {
        var id: Int
        var x: Double
        var y: Double
        var angle: Double       // radians
        var len: Double
        var w: Double
        var made: Double        // seconds since 1970
    }

    enum InkLook: String, CaseIterable {
        case normal, soft, frosted
        var label: String {
            switch self {
            case .normal: "Normal"
            case .soft: "Soft"
            case .frosted: "Frosted glass"
            }
        }
        var note: String {
            switch self {
            case .normal: "Drawings look as they always did."
            case .soft: "Drawings are see-through, so the app shows a little."
            case .frosted: "Drawings look like frosted glass: soft edge, a glint."
            }
        }
    }

    // MARK: Logic

    @MainActor @Observable final class Memory {
        var marks: [Mark] = []
        @ObservationIgnored var loaded = false
        @ObservationIgnored var nextID = 1
        @ObservationIgnored var saving: Task<Void, Never>?
        @ObservationIgnored var flight: Task<Void, Never>?

        static var file: URL { URL.applicationSupportDirectory.appending(path: "glassmemory.json") }

        func load() {
            guard !loaded else { return }
            loaded = true
            if let data = try? Data(contentsOf: Memory.file),
               let saved = try? JSONDecoder().decode([Mark].self, from: data) {
                marks = Array(saved.suffix(Tune.cap))
                nextID = (marks.map(\.id).max() ?? 0) + 1
            }
        }

        func add(from a: CGPoint, to b: CGPoint) {
            let dx = Double(b.x - a.x), dy = Double(b.y - a.y)
            let d = (dx * dx + dy * dy).squareRoot()
            push(at: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2),
                 angle: atan2(dy, dx), len: min(max(d * 0.9, Tune.shortest), Tune.longest))
        }

        func blot(at p: CGPoint) {
            push(at: p, angle: Double.random(in: 0..<Double.pi), len: Double.random(in: 24...40))
        }

        private func push(at p: CGPoint, angle: Double, len: Double) {
            let m = Mark(id: nextID, x: Double(p.x), y: Double(p.y), angle: angle, len: len,
                         w: Double.random(in: 9...17), made: Date.now.timeIntervalSince1970)
            nextID += 1
            marks.append(m)
            if marks.count > Tune.cap { marks.removeFirst(marks.count - Tune.cap) }
            save()
        }

        func clear() {
            flight?.cancel()
            flight = nil
            marks = []
            save()
        }

        /// Saved a moment after the last change, so a flight is one write.
        func save() {
            saving?.cancel()
            saving = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                let snapshot = marks
                try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
                if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: Memory.file, options: .atomic) }
            }
        }

        /// A mark grows from a quarter to full strength over a few days.
        func strength(_ m: Mark) -> Double {
            let days = max(0, Date.now.timeIntervalSince1970 - m.made) / 86400
            return min(1, 0.25 + 0.75 * days / Tune.growDays)
        }
    }
    fileprivate let mem = Memory()

    private func marksWanted(_ host: PipHost) -> Bool { (host.value("glassmemory", "marks") as Bool?) ?? true }
    /// New marks are made only with the plugin and the switch on, Pip on screen, and Joy above 0.
    private func marking(_ host: PipHost) -> Bool {
        host.isOn("glassmemory") && marksWanted(host) && host.pipHere && host.joy > 0
    }

    func start(_ host: PipHost) throws { mem.load() }

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .flick:
            fly(host)
        case .bump:
            if marking(host), !host.simpler { mem.blot(at: host.pipPosition) }
            fly(host)
        case .custom(let s):
            if s == "glass.cleaned" { withAnimation(.easeOut(duration: 0.6)) { mem.clear() } }
        default:
            break
        }
    }

    /// While Pip glides after a flick, drop a smudge every so often (a few at most), and stop once they settle.
    private func fly(_ host: PipHost) {
        guard marking(host), !host.simpler else { return }
        mem.flight?.cancel()
        mem.flight = Task { @MainActor in
            var last = host.pipPosition
            var dropped = 0
            var still = 0
            for _ in 0..<Tune.maxTicks {
                try? await Task.sleep(for: .seconds(Tune.step))
                guard !Task.isCancelled, marking(host) else { return }
                let p = host.pipPosition
                let d = hypot(p.x - last.x, p.y - last.y)
                if d < 2 {
                    still += 1
                    if still >= 3 { break }
                } else {
                    still = 0
                }
                if d >= Tune.gap {
                    mem.add(from: last, to: p)
                    last = p
                    dropped += 1
                    if dropped >= Tune.perFlight { break }
                }
            }
            mem.flight = nil
        }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Smudges(mem: mem, host: host) }
    func card(_ host: PipHost) -> some View { MemoryCard(mem: mem, host: host) }

    /// The marks, under Pip and the bar, touching nothing.
    struct Smudges: View {
        let mem: Memory
        let host: PipHost
        @AppStorage("plug.glassmemory.marks") private var marksOn = true

        var body: some View {
            let top = Tune.strength(joy: host.joy)
            ZStack(alignment: .topLeading) {
                if marksOn, top > 0 {
                    ForEach(mem.marks) { m in
                        Smudge(mark: m, opacity: top * mem.strength(m), still: host.simpler)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    struct Smudge: View {
        let mark: Mark
        let opacity: Double
        let still: Bool
        @State private var shown = false

        var body: some View {
            Capsule()
                .fill(Color.primary)
                .frame(width: mark.len, height: mark.w)
                .blur(radius: mark.w * 0.45)
                .rotationEffect(.radians(mark.angle))
                .position(x: mark.x, y: mark.y)
                .opacity(shown ? opacity : 0)
                .transition(.opacity)
                .onAppear {
                    if still { shown = true } else { withAnimation(.easeIn(duration: Tune.fadeIn)) { shown = true } }
                }
        }
    }

    struct MemoryCard: View {
        let mem: Memory
        let host: PipHost
        @AppStorage("plug.glassmemory.marks") private var marksOn = true
        @AppStorage("plug.glassmemory.ink") private var inkName = "normal"

        var body: some View {
            let look = InkLook(rawValue: inkName) ?? .normal
            let count = mem.marks.count
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Toggle("Pip leaves marks", isOn: $marksOn)
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let Pip leave faint marks on the glass where they fly")
                Text(count == 0 ? "The glass is clean." : "\(count) faint \(count == 1 ? "mark" : "marks") on the glass. They fade in slowly and show at Joy 1 or more.")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
                Button("Clean the glass") {
                    withAnimation(.easeOut(duration: 0.6)) { mem.clear() }
                }
                .buttonStyle(PluginCardButton(on: count > 0))
                .disabled(count == 0)
                .accessibilityLabel("Clean the glass: wipe all of Pip's marks away")
                Text("How drawings look").font(.system(size: 13.5))
                HStack(spacing: PluginBarLook.cardGap) {
                    ForEach(InkLook.allCases, id: \.self) { option in
                        Button(option.label) { inkName = option.rawValue }
                            .buttonStyle(PluginCardButton(on: option == look))
                            .accessibilityLabel("Drawing look: \(option.label)")
                            .accessibilityAddTraits(option == look ? .isSelected : [])
                    }
                }
                Text(look.note).font(.system(size: 13.5)).foregroundStyle(.secondary)
            }
        }
    }
}
