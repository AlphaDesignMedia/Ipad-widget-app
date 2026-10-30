import SwiftUI

// HELPER DIAL · plugin v1 (On trial). Pip as a helper: now and then Pip shares a tip about building apps with
// AI agents, automation, design or just fun. One control instead of a row of sliders: drag a dot inside a
// circle. The angle picks the mix of topics; the distance from the centre picks how often Pip speaks
// (centre = silent). A ring around the dial shows which topics' tips you've seen and liked.
// Where: the dial button in the plugin bar.

struct HelperDial: SandboxPlugin {
    let info = PluginInfo(id: "helper", name: "Helper Dial", version: "v1", shelf: .trial,
                          icon: "dial.medium", what: "Pip shares tips now and then. One dial sets the topics and how often.")

    // MARK: Data

    enum Topic: Int, CaseIterable, Identifiable {
        case agents, design, servers, fun
        var id: Int { rawValue }
        var name: String { ["Agents", "Design", "Servers", "Fun"][rawValue] }
        var icon: String { ["cpu", "paintbrush", "server.rack", "sparkles"][rawValue] }
        /// Where the topic sits on the dial, in radians (0 = top, clockwise).
        var angle: Double { Double(rawValue) * .pi / 2 }
    }

    /// Tips: short, plain, one idea each. Aaron edits these freely.
    static let tips: [Topic: [String]] = [
        .agents: [
            "Start each agent chat with one clear job. Small asks, better answers.",
            "Agents talk best through a notes file, like AGENT-NOTES.md.",
            "Ask an agent what it couldn't test. That's where bugs hide.",
            "Let GitHub build every push. A robot catches mistakes while you sleep.",
            "Big idea? Say IDEA: and park it. Build it when you say GO.",
            "Give each agent one branch. No tripping over each other.",
        ],
        .design: [
            "One 2D control can replace four sliders.",
            "Calm by default. Let people turn it up.",
            "If it doesn't make you smile in five seconds, park it.",
            "Test on the real iPad. The Simulator lies about glass.",
            "Reduce Motion means fade, not freeze.",
        ],
        .servers: [
            "A server is a computer that never sleeps. Useful for inboxes and timed jobs.",
            "iPad apps build on Macs. A Linux server can't do that part.",
            "Start with one tiny service, not a whole platform.",
            "Anything you put online needs updates and backups. Budget the time.",
            "Tester data is personal data. Collect less than you think you need.",
        ],
        .fun: [
            "Have you tried tilting Liquid Time? Go on.",
            "Fun fact: I'm mostly glass and optimism.",
            "Drink some water. I'm made of the stuff, I'd know.",
            "Stretch! I'd do it with you but I'm a sphere.",
        ],
    ]

    enum Lines {
        static let liked = "Noted. More like that."
        static let quiet = "Quiet mode. I'll keep my tips to myself."
    }

    @MainActor final class Session {
        var running = false
        var lastTip: Topic?
    }
    private let session = Session()

    // MARK: Logic

    /// How much of each topic, from the dot's position: topics near the dot's angle weigh more.
    nonisolated static func weights(x: Double, y: Double) -> [Double] {
        let radius = min(hypot(x, y), 1)
        guard radius > 0.05 else { return [1, 1, 1, 1] }
        let angle = atan2(x, -y)                      // 0 = top, clockwise
        return Topic.allCases.map { t in
            var d = abs(angle - t.angle).truncatingRemainder(dividingBy: 2 * .pi)
            if d > .pi { d = 2 * .pi - d }
            // Near the centre the mix stays even; out at the rim it focuses on the nearest topic.
            return max(0.05, 1 - radius + radius * max(0, cos(d)))
        }
    }

    /// Minutes between tips, from the dot's distance. The centre means never.
    nonisolated static func gap(x: Double, y: Double) -> Double? {
        let r = min(hypot(x, y), 1)
        return r < 0.12 ? nil : 30 - 27 * r            // 30 minutes … 3 minutes
    }

    static func pick(x: Double, y: Double) -> (Topic, String)? {
        let w = weights(x: x, y: y)
        var roll = Double.random(in: 0..<w.reduce(0, +))
        for t in Topic.allCases {
            roll -= w[t.rawValue]
            if roll <= 0, let tip = tips[t]?.randomElement() { return (t, tip) }
        }
        return nil
    }

    static func dot(_ host: PipHost) -> CGPoint {
        CGPoint(x: host.value("helper", "x") ?? 0.0, y: host.value("helper", "y") ?? -0.4)
    }

    func start(_ host: PipHost) throws {
        guard !session.running else { return }
        session.running = true
        schedule(host)
    }

    /// Waits for the dial's gap, then says a tip if Pip is here and awake. Never stacks up.
    private func schedule(_ host: PipHost) {
        let d = Self.dot(host)
        let minutes = Self.gap(x: d.x, y: d.y) ?? 5      // silent: check again in 5 minutes
        host.later(minutes * 60) {
            if host.isOn("helper") { tip(host, quiet: true) }
            schedule(host)
        }
    }

    @MainActor fileprivate func tip(_ host: PipHost, quiet: Bool) {
        let d = Self.dot(host)
        if quiet && Self.gap(x: d.x, y: d.y) == nil { return }
        guard !host.pipAsleep, let picked = Self.pick(x: d.x, y: d.y) else { return }
        let (topic, line) = picked
        if host.say(line, for: max(3, Double(line.count) / 14)) {
            session.lastTip = topic
            let seen: Int = host.value("helper", "seen.\(topic.rawValue)") ?? 0
            host.setValue(seen + 1, "helper", "seen.\(topic.rawValue)")
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { DialCard(plugin: self, host: host) }

    struct DialCard: View {
        let plugin: HelperDial
        let host: PipHost
        @State private var dot = CGPoint(x: 0, y: -0.4)
        @State private var tick = 0          // redraws the ring after a tip or a like

        var body: some View {
            let gap = HelperDial.gap(x: dot.x, y: dot.y)
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Dial(dot: $dot, host: host, tick: tick)
                    .frame(width: 220, height: 220)
                    .frame(maxWidth: .infinity)
                Text(gap.map { "A tip about every \(Int($0.rounded())) minutes." } ?? "Quiet. No tips.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Tip now") {
                        plugin.tip(host, quiet: false)
                        tick += 1
                    }
                    .buttonStyle(PluginCardButton())
                    .disabled(!host.pipHere)
                    Button {
                        if let t = plugin.session.lastTip {
                            let liked: Int = host.value("helper", "liked.\(t.rawValue)") ?? 0
                            host.setValue(liked + 1, "helper", "liked.\(t.rawValue)")
                            host.say(Lines.liked, for: 1.6)
                            tick += 1
                        }
                    } label: {
                        Label("Useful", systemImage: "hand.thumbsup")
                    }
                    .buttonStyle(PluginCardButton())
                    .accessibilityHint("Tells Pip the last tip was useful.")
                }
                if !host.pipHere {
                    Text("Pip is switched off, so tips wait until Pip's back.").foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13.5))
            .onAppear { dot = HelperDial.dot(host) }
            .onChange(of: dot) { _, d in
                host.setValue(Double(d.x), "helper", "x")
                host.setValue(Double(d.y), "helper", "y")
                if HelperDial.gap(x: d.x, y: d.y) == nil, hypot(d.x, d.y) < 0.12 { host.say(Lines.quiet, for: 1.4) }
            }
        }
    }

    /// The dial: four topics around a circle, a draggable dot, and a ring of seen (faint) and liked (solid) tips.
    struct Dial: View {
        @Binding var dot: CGPoint
        let host: PipHost
        let tick: Int

        var body: some View {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let r = side / 2 - 26
                let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    ring(radius: r + 12, centre: centre)
                    Circle().fill(Color.primary.opacity(0.06)).frame(width: r * 2, height: r * 2)
                    Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1).frame(width: r * 0.24, height: r * 0.24)
                    ForEach(Topic.allCases) { t in
                        Image(systemName: t.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .position(x: centre.x + sin(t.angle) * (r - 16), y: centre.y - cos(t.angle) * (r - 16))
                            .accessibilityHidden(true)
                    }
                    Circle().fill(PipLook.accent)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: PipLook.accent.opacity(0.5), radius: 6)
                        .position(x: centre.x + dot.x * r, y: centre.y + dot.y * r)
                }
                .contentShape(.circle)
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    var v = CGPoint(x: (g.location.x - centre.x) / r, y: (g.location.y - centre.y) / r)
                    let len = hypot(v.x, v.y)
                    if len > 1 { v = CGPoint(x: v.x / len, y: v.y / len) }
                    dot = v
                })
            }
            .accessibilityElement()
            .accessibilityLabel("Helper dial")
            .accessibilityValue(summary)
            .accessibilityAdjustableAction { direction in
                // Swipe up or down: more or fewer tips, keeping the same topics.
                let len = hypot(dot.x, dot.y), step = 0.2
                let next = min(max(len + (direction == .increment ? step : -step), 0), 1)
                let dir = len > 0.01 ? CGPoint(x: dot.x / len, y: dot.y / len) : CGPoint(x: 0, y: -1)
                dot = CGPoint(x: dir.x * next, y: dir.y * next)
            }
        }

        private var summary: String {
            guard let gap = HelperDial.gap(x: dot.x, y: dot.y) else { return "Quiet" }
            let w = HelperDial.weights(x: dot.x, y: dot.y)
            let top = Topic.allCases.max { w[$0.rawValue] < w[$1.rawValue] }?.name ?? ""
            return "Mostly \(top), a tip about every \(Int(gap.rounded())) minutes"
        }

        /// Four arcs, one per topic: faint for tips seen, solid for tips liked.
        private func ring(radius: CGFloat, centre: CGPoint) -> some View {
            let _ = tick
            let seen = Topic.allCases.map { Double(host.value("helper", "seen.\($0.rawValue)") ?? 0) }
            let liked = Topic.allCases.map { Double(host.value("helper", "liked.\($0.rawValue)") ?? 0) }
            let most = max(seen.max() ?? 0, 1)
            return ZStack {
                ForEach(Topic.allCases) { t in
                    let start = t.angle - .pi / 4 + 0.08, end = t.angle + .pi / 4 - 0.08
                    let s = seen[t.rawValue] / most, l = min(liked[t.rawValue] / most, 1)
                    arc(start, start + (end - start) * max(s, 0.02), radius, centre).stroke(PipLook.accent.opacity(0.3), style: .init(lineWidth: 6, lineCap: .round))
                    if l > 0 {
                        arc(start, start + (end - start) * l, radius, centre).stroke(PipLook.accent, style: .init(lineWidth: 6, lineCap: .round))
                    }
                }
            }
        }

        private func arc(_ from: Double, _ to: Double, _ radius: CGFloat, _ centre: CGPoint) -> Path {
            Path { p in
                // 0 = top, clockwise; Path's angles start at 3 o'clock.
                p.addArc(center: centre, radius: radius, startAngle: .radians(from - .pi / 2),
                         endAngle: .radians(to - .pi / 2), clockwise: false)
            }
        }
    }
}
