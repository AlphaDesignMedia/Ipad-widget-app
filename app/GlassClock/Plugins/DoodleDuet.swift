import SwiftUI

// DOODLE DUET · plugin v1 (Dream). A temporary play canvas where Pip draws with you. Its own layer, so the
// real Sketch drawing is never touched. Turn it on from the card, draw with a finger or the Pencil:
// - Copycat: Pip draws a wobbly copy of your line beside it.
// - Finisher: a circle gets a face, a line gets a flag, a box gets a roof.
// - Doodler: now and then Pip adds a star or a heart.
// - Eraser: ink stays until Pip eats it. When the page gets busy, or you pause, Pip flies to the oldest line
//   and munches it.
// Pip reads the room: draw quickly and steadily and Pip backs off to a corner to watch; pause and Pip comes back.
// Each behaviour has a switch. Under simpler motion, lines appear and go with a fade.
// Where: the pencil-and-sparkles button in the plugin bar; "Done" closes the canvas.

struct DoodleDuet: SandboxPlugin {
    let info = PluginInfo(id: "duet", name: "Doodle Duet", version: "v1", shelf: .dream,
                          icon: "pencil.and.scribble", what: "A play canvas where Pip copies, finishes, doodles and eats your lines.")

    // MARK: Data

    enum Habit: String, CaseIterable {
        case copycat, finisher, doodler, eraser
        var label: String { rawValue.capitalized }
        var what: String {
            switch self {
            case .copycat: "Draws a wobbly copy of your line"
            case .finisher: "Faces on circles, flags on lines, roofs on boxes"
            case .doodler: "Adds a star or a heart now and then"
            case .eraser: "Eats old lines when it's busy or you pause"
            }
        }
    }

    enum Lines {
        static let open = ["Ooh, a blank page. Your move.", "Duet time. You lead."]
        static let copy = ["Like this?", "Mine's better. Don't tell anyone.", "Copying. It's flattery."]
        static let face = ["It's me!", "A face! Hello, face."]
        static let flag = ["I claim this line.", "Planted!"]
        static let roof = ["Now it's a house.", "A house! Can I live in it?"]
        static let eat = ["Nom.", "Crunchy.", "Tastes like graphite."]
        static let backOff = ["You're in the zone. I'll watch.", "Quiet. Artist at work."]
        static let back = "Can I join in again?"
        static let done = "Lovely. I'll finish my snack."
    }

    enum Look {
        static let yourWidth: CGFloat = 5, pipWidth: CGFloat = 4
        static let drawSeconds = 0.9                  // how long Pip takes to draw a line
        static let eatSeconds = 0.6
        static let busyPage = 10                      // lines before Pip starts eating
        static let pauseToEat = 6.0, pauseToReturn = 4.0
    }

    // MARK: Logic

    struct Line: Identifiable {
        let id = UUID()
        var points: [CGPoint]
        var byPip: Bool
        var born = Date.now
        var eaten: Date?
    }

    @MainActor @Observable final class Page {
        var on = false
        var lines: [Line] = []
        var live: [CGPoint] = []
        var backedOff = false
        @ObservationIgnored var strokeTimes: [Date] = []
        @ObservationIgnored var lastStroke = Date.distantPast
        @ObservationIgnored var looking = false
    }
    private let page = Page()

    static func habitOn(_ h: Habit, _ host: PipHost) -> Bool { host.value("duet", h.rawValue) ?? true }

    func open(_ host: PipHost) {
        page.on = true
        host.say(Lines.open.randomElement()!, for: 2)
        watch(host)
    }

    func close(_ host: PipHost) {
        page.on = false
        page.live = []
        host.say(Lines.done, for: 1.8)
    }

    /// A finished stroke from you: maybe back off, else copy, finish or doodle.
    fileprivate func finished(_ points: [CGPoint], _ host: PipHost) {
        guard points.count > 1 else { return }
        page.lines.append(Line(points: points, byPip: false))
        let now = Date.now
        page.strokeTimes = page.strokeTimes.filter { now.timeIntervalSince($0) < 8 } + [now]
        page.lastStroke = now
        // Reading the room: four lines in eight seconds means "leave me be".
        if page.strokeTimes.count >= 4 {
            if !page.backedOff {
                page.backedOff = true
                host.say(Lines.backOff.randomElement()!, for: 2)
                if let corner = corner() { host.move(to: corner) }
            }
            return
        }
        guard !page.backedOff else { return }
        let shape = Self.shape(of: points)
        host.later(0.5) { respond(points, shape, host) }
    }

    private func respond(_ points: [CGPoint], _ shape: Drawn, _ host: PipHost) {
        guard page.on, !page.backedOff else { return }
        if Self.habitOn(.finisher, host), let extra = Self.finish(points, shape) {
            draw(extra.lines, host, near: extra.anchor)
            host.say(extra.line, for: 1.6)
        } else if Self.habitOn(.copycat, host), Bool.random() {
            draw([Self.wobblyCopy(of: points)], host, near: points.last ?? .zero)
            if Int.random(in: 0..<3) == 0 { host.say(Lines.copy.randomElement()!, for: 1.4) }
        } else if Self.habitOn(.doodler, host), Int.random(in: 0..<3) == 0, let end = points.last {
            let at = CGPoint(x: end.x + .random(in: -50...50), y: end.y - .random(in: 30...70))
            draw([Bool.random() ? Self.star(at: at, r: 14) : Self.heart(at: at, size: 22)], host, near: at)
            NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: "✨")
        }
    }

    /// Pip flies near the spot and draws the lines in.
    private func draw(_ lines: [[CGPoint]], _ host: PipHost, near spot: CGPoint) {
        host.move(to: CGPoint(x: spot.x + 30, y: spot.y - 30))
        for (i, pts) in lines.enumerated() where pts.count > 1 {
            host.later(Double(i) * 0.25) { page.lines.append(Line(points: pts, byPip: true)) }
        }
    }

    /// Every couple of seconds: come back after a pause, and eat a line when the page is busy or quiet.
    private func watch(_ host: PipHost) {
        guard !page.looking else { return }
        page.looking = true
        func tick() {
            host.later(2) {
                let quiet = Date.now.timeIntervalSince(page.lastStroke)
                if page.backedOff, quiet > Look.pauseToReturn, page.on {
                    page.backedOff = false
                    page.strokeTimes = []
                    host.say(Lines.back, for: 1.6)
                }
                let edible = page.lines.filter { $0.eaten == nil }
                if Self.habitOn(.eraser, host), !page.backedOff, let oldest = edible.first,
                   edible.count > Look.busyPage || (quiet > Look.pauseToEat && !page.on) || quiet > Look.pauseToEat * 2 {
                    eat(oldest.id, host)
                }
                page.lines.removeAll { $0.eaten.map { Date.now.timeIntervalSince($0) > Look.eatSeconds } ?? false }
                if page.on || !page.lines.isEmpty { tick() } else { page.looking = false }
            }
        }
        tick()
    }

    private func eat(_ id: UUID, _ host: PipHost) {
        guard let i = page.lines.firstIndex(where: { $0.id == id }) else { return }
        let middle = page.lines[i].points[page.lines[i].points.count / 2]
        host.move(to: middle)
        host.later(0.6) {
            if let j = page.lines.firstIndex(where: { $0.id == id }) { page.lines[j].eaten = .now }
            if Int.random(in: 0..<3) == 0 { host.say(Lines.eat.randomElement()!, for: 1) }
            NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: "😋")
        }
    }

    private func corner() -> CGPoint? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let size = scene?.effectiveGeometry.coordinateSpace.bounds.size else { return nil }
        return CGPoint(x: size.width - 60, y: 80)
    }

    // Shapes (plain geometry, no views)

    enum Drawn { case loop, line, box, scribble }

    nonisolated static func bounds(_ p: [CGPoint]) -> CGRect {
        let xs = p.map(\.x), ys = p.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    nonisolated static func shape(of p: [CGPoint]) -> Drawn {
        let box = bounds(p)
        let diagonal = hypot(box.width, box.height)
        guard diagonal > 40 else { return .scribble }
        var length: CGFloat = 0
        for i in 1..<p.count { length += hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y) }
        let gap = hypot(p[0].x - p[p.count - 1].x, p[0].y - p[p.count - 1].y)
        if length < diagonal * 1.25 { return .line }
        guard gap < diagonal * 0.25 else { return .scribble }
        // A box hugs its bounding rectangle; a loop cuts the corners.
        let hug = p.map { min(abs($0.x - box.minX), abs($0.x - box.maxX), abs($0.y - box.minY), abs($0.y - box.maxY)) }
        let average = hug.reduce(0, +) / CGFloat(hug.count)
        return average < diagonal * 0.05 ? .box : .loop
    }

    /// Pip's finishing touch for a shape: the lines to draw, where, and what Pip says.
    nonisolated static func finish(_ p: [CGPoint], _ shape: Drawn) -> (lines: [[CGPoint]], anchor: CGPoint, line: String)? {
        let b = bounds(p)
        switch shape {
        case .loop:
            let eyeY = b.minY + b.height * 0.38, r = max(3, b.width * 0.04)
            let leftEye = circle(at: CGPoint(x: b.minX + b.width * 0.35, y: eyeY), r: r)
            let rightEye = circle(at: CGPoint(x: b.minX + b.width * 0.65, y: eyeY), r: r)
            let smile = (0...12).map { i -> CGPoint in
                let a = Double.pi * (0.15 + 0.7 * Double(i) / 12)
                let x: CGFloat = b.midX + CGFloat(cos(a)) * b.width * 0.25
                let y: CGFloat = b.minY + b.height * 0.55 + CGFloat(sin(a)) * b.height * 0.18
                return CGPoint(x: x, y: y)
            }
            return ([leftEye, rightEye, smile], CGPoint(x: b.midX, y: b.minY), Lines.face.randomElement()!)
        case .line:
            let end = p.last!
            let pole = [end, CGPoint(x: end.x, y: end.y - 46)]
            let flag = [CGPoint(x: end.x, y: end.y - 46), CGPoint(x: end.x + 28, y: end.y - 38), CGPoint(x: end.x, y: end.y - 30)]
            return ([pole, flag], end, Lines.flag.randomElement()!)
        case .box:
            let roof = [CGPoint(x: b.minX - 8, y: b.minY), CGPoint(x: b.midX, y: b.minY - b.height * 0.55), CGPoint(x: b.maxX + 8, y: b.minY)]
            return ([roof], CGPoint(x: b.midX, y: b.minY), Lines.roof.randomElement()!)
        case .scribble:
            return nil
        }
    }

    nonisolated static func wobblyCopy(of p: [CGPoint]) -> [CGPoint] {
        let step = max(1, p.count / 40)
        return stride(from: 0, to: p.count, by: step).map { i -> CGPoint in
            let dx: CGFloat = 36 + CGFloat(sin(Double(i) * 0.7) * 3)
            let dy: CGFloat = 28 + CGFloat(cos(Double(i) * 0.5) * 3)
            return CGPoint(x: p[i].x + dx, y: p[i].y + dy)
        }
    }

    nonisolated static func circle(at c: CGPoint, r: CGFloat) -> [CGPoint] {
        (0...10).map { i in
            let a = Double(i) / 10 * 2 * .pi
            return CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
        }
    }

    nonisolated static func star(at c: CGPoint, r: CGFloat) -> [CGPoint] {
        (0...10).map { i in
            let a = Double(i) / 10 * 2 * .pi - .pi / 2
            let k = i % 2 == 0 ? r : r * 0.45
            return CGPoint(x: c.x + CGFloat(cos(a)) * k, y: c.y + CGFloat(sin(a)) * k)
        }
    }

    nonisolated static func heart(at c: CGPoint, size s: CGFloat) -> [CGPoint] {
        (0...24).map { i in
            let t = Double(i) / 24 * 2 * .pi
            let x: Double = 16 * pow(sin(t), 3)
            let y: Double = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return CGPoint(x: c.x + CGFloat(x / 32) * s, y: c.y - CGFloat(y / 32) * s)
        }
    }

    nonisolated static func path(_ p: [CGPoint], upTo fraction: Double = 1) -> Path {
        var path = Path()
        let n = max(2, Int(Double(p.count) * fraction))
        guard p.count > 1 else { return path }
        path.move(to: p[0])
        for i in 1..<min(n, p.count) {
            let a = p[i - 1], b = p[i]
            path.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: a)
        }
        path.addLine(to: p[min(n, p.count) - 1])
        return path
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Canvas2(plugin: self, page: page, host: host) }

    func card(_ host: PipHost) -> some View { DuetCard(plugin: self, page: page, host: host) }

    /// The play canvas. Takes touches only while the duet is on; otherwise it just shows lines Pip hasn't eaten yet.
    struct Canvas2: View {
        let plugin: DoodleDuet
        let page: Page
        let host: PipHost

        var body: some View {
            let lines = page.lines, live = page.live, simpler = host.simpler
            let busy = lines.contains { Date.now.timeIntervalSince($0.born) < Look.drawSeconds || $0.eaten != nil }
            ZStack(alignment: .topTrailing) {
                if page.on {
                    Color.clear.contentShape(.rect)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { page.live.append($0.location) }
                            .onEnded { _ in
                                let pts = page.live
                                page.live = []
                                plugin.finished(pts, host)
                            })
                        .accessibilityLabel("Drawing canvas for Doodle Duet")
                }
                TimelineView(.animation(paused: !busy)) { timeline in
                    let now = timeline.date
                    Canvas { ctx, _ in
                        for l in lines {
                            var reveal = 1.0, alpha = 1.0, width = l.byPip ? Look.pipWidth : Look.yourWidth
                            if l.byPip { reveal = min(1, now.timeIntervalSince(l.born) / Look.drawSeconds) }
                            if simpler { alpha = reveal; reveal = 1 }
                            if let eaten = l.eaten {
                                let k = min(1, now.timeIntervalSince(eaten) / Look.eatSeconds)
                                alpha *= 1 - k
                                width *= 1 - k * 0.8
                            }
                            ctx.stroke(DoodleDuet.path(l.points, upTo: reveal),
                                       with: .color((l.byPip ? PipLook.accent : Color.primary).opacity(alpha)),
                                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                        }
                        if live.count > 1 {
                            ctx.stroke(DoodleDuet.path(live), with: .color(.primary),
                                       style: StrokeStyle(lineWidth: Look.yourWidth, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                if page.on {
                    Button("Done") { plugin.close(host) }
                        .buttonStyle(PluginCardButton(on: true))
                        .padding(PluginBarLook.edge)
                        .accessibilityHint("Closes the play canvas. Pip finishes eating the lines.")
                }
            }
        }
    }

    struct DuetCard: View {
        let plugin: DoodleDuet
        let page: Page
        let host: PipHost
        @State private var habits: [String: Bool] = [:]

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Button(page.on ? "Drawing… tap Done to finish" : "Draw with Pip") {
                    if !page.on { plugin.open(host) }
                }
                .buttonStyle(PluginCardButton(on: page.on))
                .disabled(page.on)
                ForEach(Habit.allCases, id: \.self) { h in
                    Toggle(isOn: Binding(
                        get: { habits[h.rawValue] ?? true },
                        set: { v in
                            habits[h.rawValue] = v
                            host.setValue(v, "duet", h.rawValue)
                        })) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(h.label).bold()
                            Text(h.what).foregroundStyle(.secondary).font(.system(size: 12))
                        }
                    }
                }
                Text("Draw fast and Pip gives you space. Pause and Pip joins back in.")
                    .foregroundStyle(.secondary)
                if !page.lines.isEmpty {
                    Button("Clear the page") { page.lines.removeAll() }
                        .buttonStyle(PluginCardButton())
                }
            }
            .font(.system(size: 13.5))
            .onAppear {
                for h in Habit.allCases { habits[h.rawValue] = DoodleDuet.habitOn(h, host) }
            }
        }
    }
}
