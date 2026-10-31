import SwiftUI

// GLASS MEMORY · plugin v1 (Dream). The glass remembers. Two small ideas in one plugin:
// 1. Pip trails: when Pip is flicked or bumps an edge, they leave a very faint, soft smudge or two where they flew.
//    The marks appear softly, stay on the device (capped at 24, the oldest go first) and grow a little stronger over
//    a few days, like a ghost sketch layer. They never take a touch. Joy 0: none. Joy 1: barely there.
//    OFF BY DEFAULT since 31 Oct: Aaron reported "dark marks on the screen" and that was these. A blurred
//    Color.primary blob is black in Light mode, and they were building up and darkening with age. Now they're
//    an opt-in, at well under half the old strength. Turn them on in this card. (Rob)
//    "Clean the glass" wipes them; so does Window Cleaner Pip when it finishes (it posts "glass.cleaned").
// 2. Glass ink: how Sketch's drawings look. Normal (as ever), Soft (see-through) or Frosted glass (blurred edge, a
//    glassy glint). Works with Pip off. Sketch reads the choice (see `Layer` in Sketch.swift); Normal changes nothing.
// Light: all the marks are one Canvas with one blur, and nothing is drawn while there are none (31 Oct, Jules).
// Simpler motion: marks just appear, no shimmer. Pip off: no new trails.
// Where: the dashed-square button in the plugin bar.

struct GlassMemory: SandboxPlugin {
    let info = PluginInfo(id: "glassmemory", name: "Glass Memory", version: "v1", shelf: .dream,
                          icon: "square.dashed", what: "The glass remembers where Pip flew, and drawings can look like frosted glass.")

    // MARK: Data

    enum Tune {
        static let cap = 24                     // marks kept, at most
        static let step = 0.1                   // seconds between looks at Pip while they fly
        static let maxTicks = 30                // a flight is followed for 3 seconds at most
        static let gap: CGFloat = 46            // how far Pip travels between marks
        static let perFlight = 5                // marks per flight, at most
        static let blur: CGFloat = 6            // one soft blur for all the marks together
        static let growDays = 5.0               // days for a mark to reach full strength
        static let newborn = 0.6                // how strong a brand-new mark is, as a share of full
        static let shortest = 26.0
        static let longest = 90.0
        /// How strong a mark can get, by Joy (0: none).
        /// Halved on 31 Oct: at the old numbers a blurred Color.primary blob reads as a dark mark on the
        /// screen in Light mode, not a faint smudge on glass. Aaron reported them as a bug, and he was right.
        static func strength(joy: Int) -> Double { [0, 0.04, 0.06, 0.08, 0.1, 0.13][min(max(joy, 0), 5)] }
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

        /// A mark grows from `newborn` to full strength over a few days.
        func strength(_ m: Mark) -> Double {
            let days = max(0, Date.now.timeIntervalSince1970 - m.made) / 86400
            return min(1, Tune.newborn + (1 - Tune.newborn) * days / Tune.growDays)
        }
    }
    fileprivate let mem = Memory()

    private func marksWanted(_ host: PipHost) -> Bool { (host.value("glassmemory", "marks2") as Bool?) ?? false }
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

    /// The marks, under Pip and the bar, touching nothing. Lightened 31 Oct (Jules): one Canvas with one blur for
    /// every mark (it was a blurred view each, so up to 24 offscreen passes on every frame of the whole app), soft
    /// white like a smudge on glass (it was Color.primary, black in Light mode), and nothing at all when there's
    /// nothing to show. Marks now simply appear at their strength; no fade-in to animate.
    struct Smudges: View {
        let mem: Memory
        let host: PipHost
        @AppStorage("plug.glassmemory.marks2") private var marksOn = false

        var body: some View {
            let top = Tune.strength(joy: host.joy)
            if marksOn, top > 0, !mem.marks.isEmpty {
                let marks = mem.marks.map { ($0, top * mem.strength($0)) }
                Canvas { ctx, _ in
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: Tune.blur))
                        for (m, opacity) in marks {
                            let shape = Path(roundedRect: CGRect(x: -m.len / 2, y: -m.w / 2, width: m.len, height: m.w),
                                             cornerRadius: m.w / 2)
                            let place = CGAffineTransform(translationX: m.x, y: m.y).rotated(by: m.angle)
                            layer.fill(shape.applying(place), with: .color(.white.opacity(opacity)))
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    struct MemoryCard: View {
        let mem: Memory
        let host: PipHost
        @AppStorage("plug.glassmemory.marks2") private var marksOn = false
        @AppStorage("plug.glassmemory.ink") private var inkName = "normal"

        var body: some View {
            let look = InkLook(rawValue: inkName) ?? .normal
            let count = mem.marks.count
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Toggle("Pip leaves marks", isOn: $marksOn)
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let Pip leave faint marks on the glass where they fly")
                if !marksOn {
                    Text("Off by default. Switched on, Pip leaves very faint smudges where they fly.")
                        .font(.system(size: 12)).foregroundStyle(.tertiary)
                }
                Text(count == 0 ? "The glass is clean." : "\(count) faint \(count == 1 ? "mark" : "marks") on the glass. They show at Joy 1 or more.")
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
