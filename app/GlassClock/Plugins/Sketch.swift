import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// SKETCH · plugin v1 (Dream). Ported from the web sandbox's plugins/sketch.js, then made native.
// The Apple Pencil draws over the whole app, any time: pressure and tilt shape the line, fingers keep using
// the app, and a Pencil tap still taps. Pen, marker, highlighter and a stroke eraser; the web's colours and
// sizes; undo, redo, clear. With the panel open, fingers can draw too, on the app or on paper.
// Pencil double-tap and squeeze follow the person's Pencil settings; hovering shows where the ink will land.
// Its tools are a panel that moves like the app's settings (PluginPanel); other plugins add sections to it.
// It tells other plugins what's drawn (PipEvent.ink): Pip's answers live in Wonders, not here.
// The drawing stays on this device (sketch.json).
// Other plugins can see and tidy the drawing through `Sketch.shared` (Tidy Pip uses `tidy()` and `putBack()`).
// Where: the scribble button in the plugin bar. Left out from the web for now: pages, sync, snapshots.

struct Sketch: SandboxPlugin {
    let info = PluginInfo(id: "sketch", name: "Sketch", version: "v1", shelf: .dream,
                          icon: "scribble.variable", what: "Draw over the app with Apple Pencil; fingers keep working.",
                          panel: true)

    // MARK: Data

    enum Tool: String, Codable, CaseIterable, Sendable {
        case pen, marker, highlighter, eraser
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .pen: "pencil.tip"
            case .marker: "paintbrush.pointed"
            case .highlighter: "highlighter"
            case .eraser: "eraser"
            }
        }
        /// Width and opacity from the web's TOOLS (k, a).
        var k: Double { switch self { case .pen: 1; case .marker: 2.6; case .highlighter: 5; case .eraser: 4 } }
        var alpha: Double { switch self { case .marker: 0.9; case .highlighter: 0.35; default: 1 } }
        /// How much pressure (or finger speed) changes the width. The highlighter is a flat chisel.
        var thinning: Double { switch self { case .pen: 1.1; case .marker: 0.5; default: 0 } }
    }

    /// The web sandbox's ink colours (COLORS in plugins/sketch.js), with names for VoiceOver.
    static let colours = ["#1d2026", "#e5484d", "#f5a524", "#30a46c", "#0091ff", "#8e4ec6", "#ffffff"]
    static let colourNames = ["Ink", "Red", "Amber", "Green", "Blue", "Purple", "White"]

    /// Ported from the web's .sk-bar, .sk.paper and .sk-hover. Marked "new" = not from the web yet: Aaron's call.
    enum Look {
        static let sizes: ClosedRange<Double> = 2...24, size = 6.0
        static let rowGap: CGFloat = 6                      // .plugcard .pr gap
        static let swatch: CGFloat = 26, swatchGap: CGFloat = 8
        static let swatchRing: CGFloat = 2, swatchEdge: CGFloat = 1
        static let pickedRing: CGFloat = 2.5, pickedGap: CGFloat = 2
        static let paper = "#fbfaf6", paperOpacity = 0.94
        static let dotGap: CGFloat = 22, dotRadius: CGFloat = 1.2, dotOpacity = 0.09
        static let hoverRing: CGFloat = 1.5
        static let hoverInk = 0.45                          // new: the brush preview under a hovering Pencil
        static let clearFade = 0.35                         // new: seconds
    }

    /// What Pip says about how Sketch works. Pip's answers to the drawing itself are in Wonders.
    enum Lines {
        static let pencil = "Pencil! I'll ignore your palm now."
        static let fingers = "Fingers draw now. The app waits underneath."
        static let fresh = "Fresh page."
    }

    /// One line of ink: x, y and width for each point, in the overlay's space (the same space as Pip).
    struct Stroke: Codable, Sendable {
        var tool: Tool
        var colour: String
        var pts: [Float] = []
        var box: [Float] = []           // minX, minY, maxX, maxY, widths included (for the eraser)

        var count: Int { pts.count / 3 }
        func point(_ i: Int) -> CGPoint { CGPoint(x: CGFloat(pts[i * 3]), y: CGFloat(pts[i * 3 + 1])) }
        func width(_ i: Int) -> CGFloat { CGFloat(pts[i * 3 + 2]) }

        mutating func add(_ p: CGPoint, _ w: Double) {
            let x = Float((p.x * 10).rounded() / 10), y = Float((p.y * 10).rounded() / 10)
            let r = Float(w / 2)
            pts += [x, y, Float((w * 10).rounded() / 10)]
            box = box.isEmpty ? [x - r, y - r, x + r, y + r]
                : [min(box[0], x - r), min(box[1], y - r), max(box[2], x + r), max(box[3], y + r)]
        }

        /// Fingers have no pressure, so their strokes get a soft end instead.
        mutating func taper() {
            for (n, f) in [0.85, 0.7, 0.55, 0.4].enumerated() {
                let i = count - 4 + n
                if i > 0 { pts[i * 3 + 2] *= Float(f) }
            }
        }
    }

    /// A moment of input, from the Pencil or a finger.
    struct Sample {
        var at: CGPoint
        var time: TimeInterval
        var force: Double?          // 0...1, Pencil only
        var altitude: Double?       // radians, Pencil only: π/2 upright, lower when tilted
    }

    // MARK: Logic

    /// Pressure thickens the line, a tilted Pencil shades wider, and with fingers, faster is thinner.
    nonisolated static func width(_ tool: Tool, size: Double, force: Double?, altitude: Double?, speed: Double) -> Double {
        let pressure = force.map { min(max($0, 0.05), 1) } ?? (0.65 - 0.3 * min(speed / 2000, 1))
        var w = size * tool.k * (1 - tool.thinning / 2 + tool.thinning * pressure)
        if tool != .highlighter, let a = altitude, a < 0.7 { w *= 1 + (0.7 - a) / 0.7 * 1.5 }
        return max(w, 0.6)
    }

    /// Length, size and whether the stroke closes on itself (the web's test for a circle).
    nonisolated static func shape(_ s: Stroke) -> (length: Double, diagonal: Double, closed: Bool) {
        guard s.count > 1 else { return (0, 0, false) }
        var length = 0.0
        for i in 1..<s.count { length += Double(hypot(s.point(i).x - s.point(i - 1).x, s.point(i).y - s.point(i - 1).y)) }
        let diagonal = Double(hypot(CGFloat(s.box[2] - s.box[0]), CGFloat(s.box[3] - s.box[1])))
        let a = s.point(0), b = s.point(s.count - 1)
        let closed = diagonal > 60 && Double(hypot(a.x - b.x, a.y - b.y)) < diagonal * 0.18 && length > diagonal * 2.2
        return (length, diagonal, closed)
    }

    /// Is the point inside the loop the stroke draws?
    nonisolated static func encloses(_ s: Stroke, _ p: CGPoint) -> Bool {
        var inside = false
        var j = s.count - 1
        for i in 0..<s.count {
            let a = s.point(i), b = s.point(j)
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    nonisolated static func touches(_ s: Stroke, _ p: CGPoint, within r: CGFloat) -> Bool {
        guard s.count > 0, CGFloat(s.box[0]) - r <= p.x, p.x <= CGFloat(s.box[2]) + r,
              CGFloat(s.box[1]) - r <= p.y, p.y <= CGFloat(s.box[3]) + r else { return false }
        return (0..<s.count).contains { hypot(s.point($0).x - p.x, s.point($0).y - p.y) < r + s.width($0) / 2 }
    }

    /// Draws a stroke as runs of equal width (round caps join them), smoothed through the midpoints.
    /// Inside its own layer, so a see-through marker stays even where it overlaps itself.
    nonisolated static func draw(_ s: Stroke, in context: GraphicsContext) {
        guard s.count > 0 else { return }
        var ctx = context
        ctx.opacity = s.tool.alpha
        if s.tool == .highlighter { ctx.blendMode = .multiply }
        let ink = GraphicsContext.Shading.color(Color(hex: s.colour))
        ctx.drawLayer { layer in
            layer.opacity = 1
            layer.blendMode = .normal
            if s.count == 1 {
                let p = s.point(0), w = s.width(0)
                layer.fill(Path(ellipseIn: CGRect(x: p.x - w / 2, y: p.y - w / 2, width: w, height: w)), with: ink)
                return
            }
            func step(_ w: CGFloat) -> CGFloat { max(0.5, (w * 2).rounded() / 2) }
            var a = 0
            while a < s.count - 1 {
                let w = step(s.width(a + 1))
                var b = a + 1
                while b + 1 < s.count, step(s.width(b + 1)) == w { b += 1 }
                var path = Path()
                path.move(to: s.point(a))
                for i in stride(from: a + 1, to: b, by: 1) {
                    let p = s.point(i), q = s.point(i + 1)
                    path.addQuadCurve(to: CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2), control: p)
                }
                path.addLine(to: s.point(b))
                layer.stroke(path, with: ink, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
                a = b
            }
        }
    }

    static var file: URL { URL.applicationSupportDirectory.appending(path: "sketch.json") }

    /// Everything the drawing needs while the app runs: the ink, the tools and undo.
    @MainActor @Observable final class Ink {
        var strokes: [Stroke] = []
        var live: Stroke?
        var cursor: CGPoint?
        var clearing = false
        var tool = Tool.pen
        var colour = Sketch.colours[0]
        var size = Look.size
        var finger = false
        var paper = false
        var anywhere = true
        var undos: [[Stroke]] = []
        var redos: [[Stroke]] = []

        @ObservationIgnored weak var host: PipHost?
        @ObservationIgnored private var previous = Tool.eraser
        @ObservationIgnored private var draft: Stroke?
        @ObservationIgnored private var before: [Stroke] = []
        @ObservationIgnored private var erasedTo = 0
        @ObservationIgnored private var erasedAny = false
        @ObservationIgnored private var byPencil = false
        @ObservationIgnored private var penSeen = false
        @ObservationIgnored private var lastAt = CGPoint.zero
        @ObservationIgnored private var lastRaw = CGPoint.zero
        @ObservationIgnored private var lastTime: TimeInterval = 0
        @ObservationIgnored private var startTime: TimeInterval = 0
        @ObservationIgnored private var lastWidth: Double?
        @ObservationIgnored private var loaded = false
        @ObservationIgnored private var saving: Task<Void, Never>?
        @ObservationIgnored private var tidied: [Stroke]?

        var open: Bool { host?.openCard == "sketch" }
        /// Only while the paper covers the app does the overlay take touches; Pip and the bar stay above it.
        /// Without paper the app's panels keep every tap, and a finger stroke takes over only once it moves.
        var blocking: Bool { open && paper }

        // Settings

        func load(_ host: PipHost) {
            self.host = host
            Sketch.shared = self
            if let t: String = host.value("sketch", "tool"), let t = Tool(rawValue: t) { tool = t }
            if let c: String = host.value("sketch", "colour") { colour = c }
            if let s: Double = host.value("sketch", "size") { size = s }
            if let p: Bool = host.value("sketch", "paper") { paper = p }
            if let a: Bool = host.value("sketch", "anywhere") { anywhere = a }
            guard !loaded else { return }
            loaded = true
            if let data = try? Data(contentsOf: Sketch.file),
               let saved = try? JSONDecoder().decode([Stroke].self, from: data) { strokes = saved }
        }

        func pick(_ t: Tool) {
            if t != tool { previous = tool }
            tool = t
            host?.setValue(t.rawValue, "sketch", "tool")
        }

        func pick(colour c: String) {
            colour = c
            host?.setValue(c, "sketch", "colour")
            if tool == .eraser { pick(previous == .eraser ? .pen : previous) }
        }

        func resize(_ s: Double) { size = s; host?.setValue(s, "sketch", "size") }
        func togglePaper() { paper.toggle(); host?.setValue(paper, "sketch", "paper") }
        func toggleAnywhere() { anywhere.toggle(); host?.setValue(anywhere, "sketch", "anywhere") }
        func toggleFinger() {
            finger.toggle()
            if finger { host?.say(Lines.fingers, for: 2.4) }
        }

        // Who may draw

        func accepts(_ type: UITouch.TouchType) -> Bool {
            switch type {
            case .pencil: anywhere || open
            case .direct: open && finger
            default: false
            }
        }

        /// The panel's own controls and Pip keep working: the Pencil (or a finger) can still slide and grab them.
        func keepsClear(window w: CGPoint, canvas c: CGPoint) -> Bool {
            guard let host else { return false }
            if host.keepsTaps(w) { return true }
            guard host.pipHere else { return false }
            let p = host.pipPosition
            return hypot(c.x - p.x, c.y - p.y) < PipLook.touch * max(1, host.pip.scale) / 2
        }

        func sawPencil() {
            guard !penSeen else { return }
            penSeen = true
            if finger {
                finger = false
                host?.say(Lines.pencil, for: 1.8)
            }
        }

        /// Pencil double-tap and squeeze, as set in the iPad's Apple Pencil settings.
        func pencil(_ action: UIPencilPreferredAction) {
            switch action {
            case .switchEraser: pick(tool == .eraser ? (previous == .eraser ? .pen : previous) : .eraser)
            case .switchPrevious: pick(previous)
            case .showColorPalette, .showInkAttributes, .showContextualPalette:
                guard let host else { return }
                withAnimation(.easeOut(duration: 0.2)) { host.openCard = open ? nil : "sketch" }
            default: break
            }
        }

        // Drawing

        func begin(_ s: Sample, pencil: Bool) {
            draft = Stroke(tool: tool, colour: colour)
            byPencil = pencil
            before = strokes
            erasedTo = 0
            erasedAny = false
            lastWidth = nil
            lastAt = s.at
            startTime = s.time
            lastTime = s.time
            append(s)
        }

        /// Ink shows once the gesture has begun, so a Pencil tap on a button never leaves a dot.
        func add(_ samples: [Sample], show: Bool) {
            samples.forEach(append)
            guard show, let d = draft else { return }
            if byPencil { host?.post(.ink(.pencil(lastRaw))) }
            if d.tool == .eraser {
                erase(along: d)
                cursor = d.point(d.count - 1)
            } else {
                live = d
            }
        }

        func end() {
            defer { draft = nil; live = nil; cursor = nil }
            guard var d = draft else { return }
            if d.tool == .eraser {
                erase(along: d)
                guard erasedAny else { return }
                remember(before)
                save()
                host?.post(.ink(.erased))
                return
            }
            if let w = lastWidth, hypot(lastRaw.x - lastAt.x, lastRaw.y - lastAt.y) > 0.75 { d.add(lastRaw, w) }
            if !byPencil { d.taper() }
            remember(strokes)
            strokes.append(d)
            save()
            host?.post(.ink(.drew(mark(d, seconds: lastTime - startTime))))
        }

        func cancel() {
            if draft?.tool == .eraser, erasedAny { strokes = before }
            draft = nil
            live = nil
            cursor = nil
        }

        private func append(_ s: Sample) {
            guard let d = draft else { return }
            lastRaw = s.at
            if d.tool == .eraser { draft?.add(s.at, size * Tool.eraser.k); return }
            let dt = max(s.time - lastTime, 0.001)
            let speed = Double(hypot(s.at.x - lastAt.x, s.at.y - lastAt.y)) / dt
            // Streamline: each point eases 60% of the way to the Pencil, which smooths the wobble.
            let p = d.count == 0 ? s.at : CGPoint(x: lastAt.x + (s.at.x - lastAt.x) * 0.6, y: lastAt.y + (s.at.y - lastAt.y) * 0.6)
            if d.count > 0, hypot(p.x - lastAt.x, p.y - lastAt.y) < 0.75 { return }
            var w = Sketch.width(d.tool, size: size, force: s.force, altitude: s.altitude, speed: speed)
            if let prev = lastWidth { w = prev + (w - prev) * 0.35 } else if s.force == nil { w *= 0.6 }
            lastWidth = w
            lastAt = p
            lastTime = s.time
            draft?.add(p, w)
        }

        private func erase(along d: Stroke) {
            let r = CGFloat(size * Tool.eraser.k / 2)
            while erasedTo < d.count {
                let p = d.point(erasedTo)
                if strokes.contains(where: { Sketch.touches($0, p, within: r) }) {
                    strokes.removeAll { Sketch.touches($0, p, within: r) }
                    erasedAny = true
                }
                erasedTo += 1
            }
        }

        // Undo, redo, clear

        private func remember(_ old: [Stroke]) {
            undos.append(old)
            if undos.count > 50 { undos.removeFirst() }
            redos = []
        }

        func undo() {
            guard let last = undos.popLast() else { return }
            tidied = nil
            redos.append(strokes)
            strokes = last
            save()
        }

        func redo() {
            guard let next = redos.popLast() else { return }
            tidied = nil
            undos.append(strokes)
            strokes = next
            save()
        }

        /// A soft fade, then a fresh page. Undo brings it back.
        func clear() {
            guard !strokes.isEmpty, !clearing else { return }
            remember(strokes)
            withAnimation(.easeOut(duration: Look.clearFade)) { clearing = true } completion: {
                self.strokes = []
                self.clearing = false
                self.save()
            }
            host?.say(Lines.fresh, for: 1.2)
            host?.post(.ink(.cleared))
        }

        // For other plugins (Tidy Pip). Small and generic: one day this could be a host.ink API.

        /// Clears the drawing at once and keeps it, so `putBack()` (or Undo) brings it back.
        /// Returns what was cleared, so the caller can animate it away; empty if there was nothing to tidy.
        @discardableResult func tidy() -> [Stroke] {
            guard !strokes.isEmpty, !clearing, draft == nil else { return [] }
            let kept = strokes
            remember(strokes)
            tidied = kept
            strokes = []
            save()
            host?.post(.ink(.cleared))
            return kept
        }

        /// Puts the last tidied drawing back, under anything drawn since. False if there's nothing to put back.
        @discardableResult func putBack() -> Bool {
            guard let kept = tidied else { return false }
            tidied = nil
            remember(strokes)
            strokes = kept + strokes
            save()
            return true
        }

        /// The Pencil hovering where it would draw: other plugins hear where it is (Wonders: Pip follows it).
        func hovering(_ at: CGPoint, window w: CGPoint) {
            if !keepsClear(window: w, canvas: at) { host?.post(.ink(.pencil(at))) }
        }

        /// Saved a second after the last change, so a busy drawing doesn't write on every stroke.
        private func save() {
            saving?.cancel()
            saving = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
                try? JSONEncoder().encode(strokes).write(to: Sketch.file, options: .atomic)
            }
        }

        /// The finished stroke, described for plugins that answer drawings (Wonders).
        private func mark(_ s: Stroke, seconds: Double) -> InkMark {
            let (length, _, closed) = Sketch.shape(s)
            let box = CGRect(x: CGFloat(s.box[0]), y: CGFloat(s.box[1]),
                             width: CGFloat(s.box[2] - s.box[0]), height: CGFloat(s.box[3] - s.box[1]))
            var onPip = false, ringsPip = false
            if let host, host.pipHere {
                let pip = host.pipPosition
                onPip = Sketch.touches(s, pip, within: host.pip.radius + 4)
                ringsPip = closed && Sketch.encloses(s, pip)
            }
            return InkMark(box: box, length: length, seconds: seconds, closed: closed, onPip: onPip, ringsPip: ringsPip)
        }
    }

    private let ink = Ink()

    /// The drawing, for other plugins to see and tidy (set once Sketch has started; check `host.isOn("sketch")`).
    @MainActor static weak var shared: Ink?
    @MainActor static var strokeCount: Int { shared?.strokes.count ?? 0 }

    func start(_ host: PipHost) throws {
        ink.load(host)
        #if DEBUG
        // For the simulator check: `-sketchDemo YES` shows sample ink (not saved) with the card open.
        if UserDefaults.standard.bool(forKey: "sketchDemo") {
            ink.strokes = Sketch.demo()
            host.openCard = "sketch"
        }
        #endif
    }

    #if DEBUG
    static func demo() -> [Stroke] {
        var wave = Stroke(tool: .pen, colour: colours[0]), loop = Stroke(tool: .marker, colour: colours[2])
        var band = Stroke(tool: .highlighter, colour: colours[2]), shade = Stroke(tool: .pen, colour: colours[5])
        for x in stride(from: 180.0, through: 760, by: 3) {
            let force = 0.25 + 0.6 * (0.5 + 0.5 * sin(x / 70))
            wave.add(CGPoint(x: x, y: 250 + 40 * sin(x / 45)), width(.pen, size: 6, force: force, altitude: 1.4, speed: 0))
            band.add(CGPoint(x: x, y: 760), width(.highlighter, size: 6, force: nil, altitude: nil, speed: 0))
        }
        for a in stride(from: 0.0, through: 2 * .pi + 0.2, by: 0.03) {
            loop.add(CGPoint(x: 470 + 120 * cos(a), y: 520 + 90 * sin(a)), width(.marker, size: 6, force: 0.5, altitude: 1.4, speed: 0))
        }
        for x in stride(from: 820.0, through: 1000, by: 2) {
            shade.add(CGPoint(x: x, y: 330 + 30 * sin(x / 9)), width(.pen, size: 6, force: 0.4, altitude: 0.3, speed: 0))
        }
        return [wave, loop, band, shade]
    }
    #endif

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Layer(ink: ink) }
    func card(_ host: PipHost) -> some View { Tools(ink: ink) }

    /// The ink over the app (and paper, while the card is open), plus the invisible view that hears the Pencil.
    struct Layer: View {
        let ink: Ink
        var body: some View {
            let strokes = ink.strokes
            ZStack {
                Canvas { ctx, _ in for s in strokes { Sketch.draw(s, in: ctx) } }
                    .opacity(ink.clearing ? 0 : 1)
                    .background { if ink.open && ink.paper { Paper().transition(.opacity) } }
                LiveInk(ink: ink)
                Tracker(ink: ink)
            }
            .contentShape(Rectangle())
            .allowsHitTesting(ink.blocking)
            .accessibilityHidden(true)
        }
    }

    /// The stroke being drawn, and the brush under a hovering Pencil. Only this redraws while you draw.
    struct LiveInk: View {
        let ink: Ink
        var body: some View {
            let live = ink.live, cursor = ink.cursor, tool = ink.tool
            let brush = tool == .eraser ? ink.size * Tool.eraser.k : max(8, Sketch.width(tool, size: ink.size, force: 0.5, altitude: nil, speed: 0))
            let colour = Color(hex: ink.colour)
            Canvas { ctx, _ in
                if let live { Sketch.draw(live, in: ctx) }
                if let c = cursor {
                    let ring = Path(ellipseIn: CGRect(x: c.x - brush / 2, y: c.y - brush / 2, width: brush, height: brush))
                    if tool == .eraser {
                        ctx.stroke(ring, with: .color(.secondary), lineWidth: Look.hoverRing)
                    } else {
                        ctx.fill(ring, with: .color(colour.opacity(Look.hoverInk)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// The web's whiteboard paper: warm white with a faint dot grid.
    struct Paper: View {
        var body: some View {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: Look.paper).opacity(Look.paperOpacity)))
                var dots = Path()
                let r = Look.dotRadius
                for x in stride(from: Look.dotGap / 2, to: size.width, by: Look.dotGap) {
                    for y in stride(from: Look.dotGap / 2, to: size.height, by: Look.dotGap) {
                        dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    }
                }
                ctx.fill(dots, with: .color(.black.opacity(Look.dotOpacity)))
            }
            .ignoresSafeArea()
        }
    }

    /// The panel's cards: what to draw with, and the page.
    struct Tools: View {
        let ink: Ink
        var body: some View {
            VStack(spacing: Corner.inset) {
                SettingsCard(title: "Draw", icon: "paintbrush.pointed") {
                    HStack(spacing: Look.rowGap) {
                        ForEach(Tool.allCases, id: \.self) { t in
                            Button { ink.pick(t) } label: { Label(t.label, systemImage: t.icon).labelStyle(.iconOnly) }
                                .buttonStyle(PluginCardButton(on: ink.tool == t))
                                .accessibilityAddTraits(ink.tool == t ? .isSelected : [])
                        }
                    }
                    HStack(spacing: Look.swatchGap) {
                        ForEach(Sketch.colours.indices, id: \.self) { i in swatch(i) }
                    }
                    .padding(.vertical, Look.pickedGap + Look.pickedRing)
                    Slider(value: Binding(get: { ink.size }, set: { ink.resize($0) }), in: Look.sizes, step: 1)
                        .accessibilityLabel("Size")
                        .accessibilityValue("\(Int(ink.size))")
                }
                SettingsCard(title: "Page", icon: "doc", footer: note) {
                    HStack(spacing: Look.rowGap) {
                        Button { ink.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward").labelStyle(.iconOnly) }
                            .disabled(ink.undos.isEmpty)
                        Button { ink.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward").labelStyle(.iconOnly) }
                            .disabled(ink.redos.isEmpty)
                        Button("Clear") { ink.clear() }
                            .disabled(ink.strokes.isEmpty)
                    }
                    .buttonStyle(PluginCardButton())
                    HStack(spacing: Look.rowGap) {
                        Button("Draw with finger") { ink.toggleFinger() }
                            .buttonStyle(PluginCardButton(on: ink.finger))
                            .accessibilityAddTraits(ink.finger ? .isSelected : [])
                        Button("Paper") { withAnimation(.easeOut(duration: 0.2)) { ink.togglePaper() } }
                            .buttonStyle(PluginCardButton(on: ink.paper))
                            .accessibilityAddTraits(ink.paper ? .isSelected : [])
                    }
                    Button("Pencil draws anywhere") { ink.toggleAnywhere() }
                        .buttonStyle(PluginCardButton(on: ink.anywhere))
                        .accessibilityAddTraits(ink.anywhere ? .isSelected : [])
                }
            }
        }

        private var note: String {
            if ink.finger { return "Fingers draw too. The app waits underneath until you close this panel." }
            if !ink.anywhere { return "The Pencil draws only while this panel is open." }
            return "Draw with Apple Pencil anywhere. Fingers keep using the app, and a Pencil tap still taps. Double-tap or squeeze the Pencil to switch tools. Flick a title bar sideways to tuck this panel away."
        }

        private func swatch(_ i: Int) -> some View {
            let c = Sketch.colours[i], picked = ink.colour == c && ink.tool != .eraser
            return Button { ink.pick(colour: c) } label: {
                Circle().fill(Color(hex: c))
                    .overlay(Circle().inset(by: Look.swatchRing / 2).stroke(.white.opacity(0.7), lineWidth: Look.swatchRing))
                    .overlay(Circle().inset(by: -Look.swatchEdge / 2).stroke(.black.opacity(0.15), lineWidth: Look.swatchEdge))
                    .overlay {
                        if picked {
                            Circle().inset(by: -(Look.pickedGap + Look.pickedRing / 2)).stroke(PipLook.accent, lineWidth: Look.pickedRing)
                        }
                    }
                    .frame(width: Look.swatch, height: Look.swatch)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Sketch.colourNames[i])
            .accessibilityAddTraits(picked ? .isSelected : [])
        }
    }

    // MARK: Pencil and touch (UIKit)

    /// Puts the ink gesture, the hover preview and Pencil double-tap/squeeze on the window, so the Pencil
    /// can draw over anything while the app keeps every finger touch. Leaves the window with the overlay.
    struct Tracker: UIViewRepresentable {
        let ink: Ink
        func makeUIView(context: Context) -> TrackerView {
            let v = TrackerView()
            v.ink = ink
            v.isUserInteractionEnabled = false
            v.backgroundColor = .clear
            return v
        }
        func updateUIView(_ v: TrackerView, context: Context) { v.ink = ink }
        static func dismantleUIView(_ v: TrackerView, coordinator: ()) { v.detach() }
    }

    final class TrackerView: UIView, UIPencilInteractionDelegate {
        weak var ink: Ink?
        private let gesture = InkGesture()
        private let hover = UIHoverGestureRecognizer()
        private let pencil = UIPencilInteraction()
        private weak var attached: UIWindow?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard let window else { return }
            gesture.canvas = self
            gesture.ink = ink
            hover.addTarget(self, action: #selector(hovered))
            pencil.delegate = self
            window.addGestureRecognizer(gesture)
            window.addGestureRecognizer(hover)
            window.addInteraction(pencil)
            attached = window
        }

        func detach() {
            guard let w = attached else { return }
            w.removeGestureRecognizer(gesture)
            w.removeGestureRecognizer(hover)
            w.removeInteraction(pencil)
            attached = nil
            ink?.cursor = nil
        }

        @objc private func hovered(_ g: UIHoverGestureRecognizer) {
            guard let ink, ink.live == nil else { return }
            let show = (g.state == .began || g.state == .changed) && g.zOffset > 0 && ink.accepts(.pencil)
            let at: CGPoint? = show ? g.location(in: self) : nil
            if ink.cursor != at { ink.cursor = at }
            if let at { ink.hovering(at, window: g.location(in: nil)) }
        }

        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
            ink?.pencil(UIPencilInteraction.preferredTapAction)
        }

        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            guard squeeze.phase == .ended else { return }
            ink?.pencil(UIPencilInteraction.preferredSqueezeAction)
        }
    }

    /// One stroke at a time. It waits for 3 points of movement (10 for a finger, which wobbles) before it takes the touch from the app,
    /// so taps (and every finger, unless the card says otherwise) go through untouched.
    final class InkGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {
        weak var ink: Ink?
        weak var canvas: UIView?
        private var touch: UITouch?
        private var from = CGPoint.zero
        private var done = false

        init() {
            super.init(target: nil, action: nil)
            delegate = self
            allowedTouchTypes = [UITouch.TouchType.pencil, .direct].map { NSNumber(value: $0.rawValue) }
            delaysTouchesEnded = false      // a tap reaches the app at once, never held back by the ink

        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive t: UITouch) -> Bool {
            guard let ink, let canvas, ink.accepts(t.type) else { return false }
            if t.type == .pencil { ink.sawPencil() }
            return !ink.keepsClear(window: t.location(in: nil), canvas: t.location(in: canvas))
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            guard touch == nil, let t = touches.first, let ink, let canvas else {
                touches.forEach { ignore($0, for: event) }
                return
            }
            touches.filter { $0 !== t }.forEach { ignore($0, for: event) }
            touch = t
            done = false
            from = t.location(in: canvas)
            ink.begin(sample(t), pencil: t.type == .pencil)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let t = touch, touches.contains(t), let ink, let canvas else { return }
            let at = t.location(in: canvas)
            if state == .possible {
                if hypot(at.x - from.x, at.y - from.y) > (t.type == .pencil ? 3 : 10) { state = .began }
            } else {
                state = .changed
            }
            ink.add((event.coalescedTouches(for: t) ?? [t]).map(sample), show: state != .possible)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let t = touch, touches.contains(t) else { return }
            done = true
            if state == .possible {
                ink?.cancel()
                state = .failed
            } else {
                ink?.end()
                state = .ended
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let t = touch, touches.contains(t) else { return }
            done = true
            ink?.cancel()
            state = state == .possible ? .failed : .cancelled
        }

        override func reset() {
            super.reset()
            if touch != nil, !done { ink?.cancel() }   // another gesture won the touch
            touch = nil
            done = false
        }

        private func sample(_ t: UITouch) -> Sample {
            let pencil = t.type == .pencil
            return Sample(at: t.preciseLocation(in: canvas), time: t.timestamp,
                          force: pencil && t.maximumPossibleForce > 0 ? Double(t.force / t.maximumPossibleForce) : nil,
                          altitude: pencil ? Double(t.altitudeAngle) : nil)
        }
    }
}
