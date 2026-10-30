import SwiftUI

// PIP'S SKETCHBOOK · plugin v1 (Dream). Pip loves watching you draw and wishes they were better at it.
// Pip thinks everything is either a house or a face. A little pad with its own canvas (finger or Pencil, never
// Sketch's page). Lift and pause for about 1.5 s and Pip has a guess:
// - Sure enough: "Is that a house?" with "Yes!" and "No, it's a…" (type a word). Not sure: "Is it… a house? Or a face?"
// - Pip learns: each drawing you teach is kept on the device (a few per word), so they slowly know more words.
//   Pip: "Ooh. A {thing}. I'll remember that."
// - Trace: Pip draws a wobbly version of something they know, for you to trace over. The wobble shrinks as Pip
//   is taught: wobble = max(0.2, 1 - taught / 20).
// How Pip guesses: your strokes are squashed onto a 32 x 32 grid (blurred a touch) and compared with stored
// examples by cosine similarity. No network, nothing leaves the device.
// Pip off: a plain sketch pad with a "What is it?" button that shows the best guess as text.
// Joy 0: text only (Pip says nothing aloud, the trace just appears). Simpler motion: fades only.
// Pip offers to guess or trace on their own at most 3 times a session, then only when asked.
// Where: the pencil-and-scribble button in the plugin bar (opens as a panel).

struct PipsSketchbook: SandboxPlugin {
    let info = PluginInfo(id: "sketchbook", name: "Pip's sketchbook", version: "v1", shelf: .dream,
                          icon: "pencil.and.scribble",
                          what: "Pip watches you draw and guesses: a house or a face. Teach them more.",
                          panel: true)

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        static let pause = 1.5                  // seconds after you lift before Pip guesses
        static let maxOffers = 3                // unprompted guesses or trace offers per session
        static let grid = 32                    // the recogniser's grid is grid x grid
        static let sure = 0.62                  // cosine score needed to say "Is that a house?" (an estimate; tune on the iPad)
        static let lead = 0.05                  // and it must beat the runner-up by this much
        static let keepPerLabel = 5             // taught examples kept for each word
        static let maxLabel = 24                // letters in a word
        static let maxPoints = 40               // points kept per stroke when saving
        static let maxStrokes = 30              // strokes kept per drawing when saving (keeps saved data small)
        static let maxWords = 24                // words Pip can be taught; past this they only add to words they know
        static let wobbleAmp = 0.04             // trace wobble at full wobble, as a fraction of the trace box
        static let wobbleLearn = 20.0           // taught drawings that bring the wobble down to its floor
        static let wobbleFloor = 0.2
        static let traceFit = 0.7               // the trace fills this much of the canvas
        static let traceSteps = 24              // Pip draws the trace in this many steps
        static let traceStep = 0.04             // seconds per step
        static let ink: CGFloat = 4
        static let canvasHeight: CGFloat = 260
        static func wobble(taught: Int) -> Double { max(wobbleFloor, 1 - Double(taught) / wobbleLearn) }
    }

    // MARK: Data

    typealias Drawing = [[CGPoint]]

    enum Say {
        static let idleOn = "Draw something, then pause. Pip will have a guess."
        static let idleOff = "Draw something, then tap What is it?"
        static let empty = "Draw something first and Pip will have a go."
        static let yes = "Ha. Knew it."
        static let known = "Ah, of course. Noted."
        static let offerTrace = "Want to trace one of mine?"
        static let askWord = "What is it, then?"
    }

    /// Pip's two starting words, each as two hand-made drawings (points on a 0...100 square).
    enum Seeds {
        static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> [CGPoint] {
            (0...24).map { i -> CGPoint in
                let a = Double(i) / 24 * 2 * Double.pi
                return CGPoint(x: cx + r * cos(a), y: cy + r * sin(a))
            }
        }

        static func smile(_ cx: Double, _ cy: Double, _ r: Double) -> [CGPoint] {
            (0...10).map { i -> CGPoint in
                let a = Double.pi * (0.15 + 0.7 * Double(i) / 10)
                return CGPoint(x: cx + r * cos(a), y: cy + r * 0.6 * sin(a))
            }
        }

        static func line(_ p: [(Double, Double)]) -> [CGPoint] { p.map { CGPoint(x: $0.0, y: $0.1) } }

        static let houseA: Drawing = [
            Seeds.line([(20, 45), (80, 45), (80, 90), (20, 90), (20, 45)]),
            Seeds.line([(12, 47), (50, 12), (88, 47)]),
            Seeds.line([(42, 90), (42, 65), (58, 65), (58, 90)]),
        ]
        static let houseB: Drawing = [
            Seeds.line([(15, 50), (85, 50), (85, 90), (15, 90), (15, 50)]),
            Seeds.line([(8, 52), (50, 15), (92, 52)]),
            Seeds.line([(68, 32), (68, 14), (78, 14), (78, 40)]),
            Seeds.line([(25, 60), (40, 60), (40, 74), (25, 74), (25, 60)]),
        ]
        static let faceA: Drawing = [
            Seeds.circle(50, 50, 40),
            Seeds.circle(36, 40, 4),
            Seeds.circle(64, 40, 4),
            Seeds.smile(50, 58, 22),
        ]
        static let faceB: Drawing = [
            Seeds.circle(50, 50, 38),
            Seeds.circle(35, 42, 5),
            Seeds.circle(65, 42, 5),
            Seeds.line([(50, 46), (46, 58), (54, 58)]),
            Seeds.line([(36, 70), (50, 74), (64, 70)]),
        ]

        static let all: [String: [Drawing]] = [
            "house": [houseA, houseB],
            "face": [faceA, faceB],
        ]
    }

    // MARK: Logic

    /// The recogniser and the shape helpers: plain numbers, no views.
    enum Eye {
        struct Guess {
            var label: String
            var score: Double
            var other: String
            var otherScore: Double
        }

        static func box(_ pts: [CGPoint]) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
            let xs = pts.map { Double($0.x) }
            let ys = pts.map { Double($0.y) }
            return (xs.min() ?? 0, xs.max() ?? 0, ys.min() ?? 0, ys.max() ?? 0)
        }

        /// Strokes squashed onto the grid, blurred a touch and scaled to length 1 (so a dot product is the cosine).
        static func grid(_ d: Drawing) -> [Double]? {
            let all = d.flatMap { $0 }
            guard all.count > 1 else { return nil }
            let b = box(all)
            let w = b.maxX - b.minX
            let h = b.maxY - b.minY
            let side = max(w, h, 1)
            let n = Tune.grid
            let scale = Double(n - 6) / side
            let ox = (Double(n) - w * scale) / 2 - b.minX * scale
            let oy = (Double(n) - h * scale) / 2 - b.minY * scale
            var g = [Double](repeating: 0, count: n * n)
            func plot(_ x: Double, _ y: Double) {
                let ix = Int((x * scale + ox).rounded())
                let iy = Int((y * scale + oy).rounded())
                if ix >= 0, ix < n, iy >= 0, iy < n { g[iy * n + ix] = 1 }
            }
            for s in d {
                guard let first = s.first else { continue }
                plot(Double(first.x), Double(first.y))
                var prev = first
                for q in s.dropFirst() {
                    let dx = Double(q.x - prev.x)
                    let dy = Double(q.y - prev.y)
                    let steps = max(1, Int(hypot(dx, dy) * scale * 2))
                    for k in 1...steps {
                        let t = Double(k) / Double(steps)
                        plot(Double(prev.x) + dx * t, Double(prev.y) + dy * t)
                    }
                    prev = q
                }
            }
            let weights = [0.25, 0.5, 0.25]
            var across = [Double](repeating: 0, count: n * n)
            for y in 0..<n {
                for x in 0..<n {
                    var sum = 0.0
                    for k in -1...1 where x + k >= 0 && x + k < n { sum += g[y * n + x + k] * weights[k + 1] }
                    across[y * n + x] = sum
                }
            }
            var down = [Double](repeating: 0, count: n * n)
            for y in 0..<n {
                for x in 0..<n {
                    var sum = 0.0
                    for k in -1...1 where y + k >= 0 && y + k < n { sum += across[(y + k) * n + x] * weights[k + 1] }
                    down[y * n + x] = sum
                }
            }
            let length = down.reduce(0.0) { $0 + $1 * $1 }.squareRoot()
            guard length > 0 else { return nil }
            return down.map { $0 / length }
        }

        static func dot(_ a: [Double], _ b: [Double]) -> Double {
            var sum = 0.0
            for i in 0..<min(a.count, b.count) { sum += a[i] * b[i] }
            return sum
        }

        /// The best and second-best word for a drawing, by cosine similarity to the closest example of each.
        static func guess(_ d: Drawing, _ library: [String: [Drawing]]) -> Guess? {
            guard let mine = grid(d) else { return nil }
            var scores: [(label: String, score: Double)] = []
            for (label, examples) in library {
                var best = 0.0
                for e in examples {
                    if let g = grid(e) { best = max(best, dot(mine, g)) }
                }
                scores.append((label: label, score: best))
            }
            scores.sort { $0.score > $1.score }
            guard let first = scores.first else { return nil }
            let second = scores.dropFirst().first
            return Guess(label: first.label, score: first.score,
                         other: second?.label ?? "", otherScore: second?.score ?? 0)
        }

        /// Every stroke pared to a few points, fitted to a 0...100 square and centred. Used to save a drawing.
        static func normalised(_ d: Drawing) -> Drawing {
            let kept = Array(d.filter { $0.count > 1 }.prefix(Tune.maxStrokes))
            let all = kept.flatMap { $0 }
            guard all.count > 1 else { return [] }
            let b = box(all)
            let w = b.maxX - b.minX
            let h = b.maxY - b.minY
            let k = 100 / max(w, h, 1)
            let ox = (100 - w * k) / 2
            let oy = (100 - h * k) / 2
            return kept.map { s in
                thin(s).map { p -> CGPoint in
                    let x = (Double(p.x) - b.minX) * k + ox
                    let y = (Double(p.y) - b.minY) * k + oy
                    return CGPoint(x: x, y: y)
                }
            }
        }

        static func thin(_ s: [CGPoint]) -> [CGPoint] {
            guard s.count > Tune.maxPoints else { return s }
            let step = Double(s.count - 1) / Double(Tune.maxPoints - 1)
            return (0..<Tune.maxPoints).map { s[Int((Double($0) * step).rounded())] }
        }

        static func encode(_ d: Drawing) -> [[Double]] {
            d.map { s in s.flatMap { [Double($0.x), Double($0.y)] } }
        }

        static func decode(_ raw: [[Double]]) -> Drawing {
            raw.map { flat in
                stride(from: 0, to: flat.count - 1, by: 2).map { CGPoint(x: flat[$0], y: flat[$0 + 1]) }
            }
        }

        /// Points every `step` along a line, so a wobble has something to bend.
        static func resample(_ p: [CGPoint], step: Double) -> [CGPoint] {
            guard var prev = p.first else { return [] }
            var out = [prev]
            for q in p.dropFirst() {
                let dx = Double(q.x - prev.x)
                let dy = Double(q.y - prev.y)
                let n = max(1, Int((hypot(dx, dy) / step).rounded(.up)))
                for k in 1...n {
                    let t = Double(k) / Double(n)
                    out.append(CGPoint(x: Double(prev.x) + dx * t, y: Double(prev.y) + dy * t))
                }
                prev = q
            }
            return out
        }

        /// A drawing as Pip would draw it: on a 0...1 square, bent by a smooth wobble of size `wobble` (0.2...1).
        static func wobbly(_ d: Drawing, wobble: Double) -> Drawing {
            let amp = Tune.wobbleAmp * wobble
            let p1 = Double.random(in: 0..<6.28)
            let p2 = Double.random(in: 0..<6.28)
            let p3 = Double.random(in: 0..<6.28)
            let p4 = Double.random(in: 0..<6.28)
            var t = 0.0
            return normalised(d).map { stroke in
                let unit = stroke.map { CGPoint(x: Double($0.x) / 100, y: Double($0.y) / 100) }
                return resample(unit, step: 0.02).map { p -> CGPoint in
                    t += 1
                    let wx = sin(t * 0.33 + p1) + 0.5 * sin(t * 0.9 + p2)
                    let wy = sin(t * 0.29 + p3) + 0.5 * sin(t * 0.8 + p4)
                    return CGPoint(x: Double(p.x) + amp * wx, y: Double(p.y) + amp * wy)
                }
            }
        }

        /// A word as typed: lower case, no "a"/"an"/"the" in front, not too long.
        static func clean(_ s: String) -> String {
            var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            for lead in ["a ", "an ", "the "] where t.hasPrefix(lead) {
                t = String(t.dropFirst(lead.count))
                break
            }
            t = t.trimmingCharacters(in: .whitespaces)
            return String(t.prefix(Tune.maxLabel))
        }

        static func article(_ label: String) -> String {
            let vowel = label.first.map { "aeiou".contains($0) } ?? false
            return (vowel ? "an " : "a ") + label
        }

        static func capital(_ s: String) -> String { String(s.prefix(1)).uppercased() + String(s.dropFirst()) }
    }

    /// Everything the pad remembers while the app runs. Taught drawings are also saved on the device.
    @MainActor @Observable final class Book {
        enum Phase: Equatable {
            case idle
            case guessed(String)
            case unsure(String, String)
            case teaching
            case learned
        }

        var strokes: Drawing = []
        var live: [CGPoint] = []
        var phase: Phase = .idle
        var line = ""
        var typed = ""
        var trace: Drawing = []
        var traceLabel = ""
        var reveal = 1.0
        var traceOpacity = 1.0
        var offers = 0
        var taught: [String: [Drawing]] = [:]
        var taughtCount = 0
        @ObservationIgnored var pause: Task<Void, Never>?
        @ObservationIgnored var drawIn: Task<Void, Never>?
        @ObservationIgnored var fresh = false
        @ObservationIgnored var loaded = false

        // Storage

        func load(_ host: PipHost) {
            guard !loaded else { return }
            loaded = true
            let raw: [String: [[[Double]]]]? = host.value("sketchbook", "taught")
            taught = (raw ?? [:]).mapValues { $0.map { Eye.decode($0) } }
            let count: Int? = host.value("sketchbook", "count")
            taughtCount = count ?? 0
        }

        func save(_ host: PipHost) {
            host.setValue(taught.mapValues { $0.map { Eye.encode($0) } }, "sketchbook", "taught")
            host.setValue(taughtCount, "sketchbook", "count")
        }

        /// Pip's two seed words plus everything taught.
        func library() -> [String: [Drawing]] {
            var all = Seeds.all
            for (label, examples) in taught { all[label, default: []] += examples }
            return all
        }

        func leave() {
            pause?.cancel()
            drawIn?.cancel()
        }

        // Drawing

        func strokeBegan() {
            pause?.cancel()
            if fresh {
                strokes = []
                trace = []
                fresh = false
            }
            if phase != .idle { phase = .idle }
            line = ""
        }

        func strokeEnded(_ host: PipHost) {
            if live.count > 1 { strokes.append(live) }
            live = []
            pause?.cancel()
            guard host.pipHere, offers < Tune.maxOffers, !strokes.isEmpty else { return }
            pause = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Tune.pause))
                guard !Task.isCancelled, let self else { return }
                self.autoGuess(host)
            }
        }

        func clear() {
            leave()
            strokes = []
            live = []
            trace = []
            phase = .idle
            line = ""
            typed = ""
            fresh = false
        }

        // Guessing

        private func autoGuess(_ host: PipHost) {
            guard host.pipHere, offers < Tune.maxOffers, phase == .idle, !strokes.isEmpty,
                  PipTalkTurns.floorFree(host) else { return }
            offers += 1
            runGuess(host)
        }

        /// The "What do you think?" and "What is it?" buttons.
        func ask(_ host: PipHost) {
            pause?.cancel()
            runGuess(host)
        }

        private func runGuess(_ host: PipHost) {
            guard let g = Eye.guess(strokes, library()) else {
                phase = .idle
                line = Say.empty
                return
            }
            let confident = g.score >= Tune.sure && g.score - g.otherScore >= Tune.lead
            guard host.pipHere else {
                phase = .idle
                line = confident ? "Best guess: \(Eye.article(g.label))."
                                 : "Best guess: \(Eye.article(g.label)), but not sure."
                return
            }
            if confident || g.other.isEmpty {
                phase = .guessed(g.label)
                line = "Is that \(Eye.article(g.label))?"
            } else {
                phase = .unsure(g.label, g.other)
                line = "Is it… \(Eye.article(g.label))? Or \(Eye.article(g.other))?"
            }
            speak(line, host)
        }

        // Teaching

        /// "Yes!" (Pip guessed right) or one of the two choices Pip offered.
        func confirm(_ label: String, pipGuessedIt: Bool, _ host: PipHost) {
            let free = PipTalkTurns.floorFree(host)
            learn(label, host)
            line = pipGuessedIt ? Say.yes : Say.known
            finish(host, free: free)
        }

        func teachTyped(_ host: PipHost) {
            let word = Eye.clean(typed)
            guard !word.isEmpty else { return }
            let free = PipTalkTurns.floorFree(host)
            learn(word, host)
            line = "Ooh. \(Eye.capital(Eye.article(word))). I'll remember that."
            typed = ""
            finish(host, free: free)
        }

        private func learn(_ label: String, _ host: PipHost) {
            let drawing = Eye.normalised(strokes)
            guard !drawing.isEmpty, taught[label] != nil || taught.count < Tune.maxWords else { return }
            var list = taught[label] ?? []
            list.append(drawing)
            if list.count > Tune.keepPerLabel { list.removeFirst(list.count - Tune.keepPerLabel) }
            taught[label] = list
            taughtCount += 1
            save(host)
        }

        private func finish(_ host: PipHost, free: Bool) {
            phase = .learned
            fresh = true
            speak(line, host)
            if host.joy > 0 { host.cheer() }
            guard host.pipHere, free, offers < Tune.maxOffers else { return }
            offers += 1
            host.later(3.4) { [weak self] in
                guard let self, self.phase == .learned, host.pipHere else { return }
                self.line += " " + Say.offerTrace
                self.speak(Say.offerTrace, host)
            }
        }

        // Tracing

        func startTrace(_ host: PipHost) {
            let lib = library()
            guard let label = lib.keys.randomElement(), let example = lib[label]?.randomElement() else { return }
            let wobble = Tune.wobble(taught: taughtCount)
            trace = Eye.wobbly(example, wobble: wobble)
            traceLabel = label
            fresh = false
            phase = .idle
            line = wobble > 0.6 ? "Trace my \(label). Fair warning: it's wobbly."
                                : "Trace my \(label). I've been practising."
            speak(line, host)
            playTrace(host)
        }

        private func playTrace(_ host: PipHost) {
            drawIn?.cancel()
            if host.joy >= 1, !host.simpler {
                reveal = 0
                traceOpacity = 1
                drawIn = Task { [weak self] in
                    for i in 1...Tune.traceSteps {
                        try? await Task.sleep(for: .seconds(Tune.traceStep))
                        guard !Task.isCancelled, let self else { return }
                        self.reveal = Double(i) / Double(Tune.traceSteps)
                    }
                }
            } else {
                reveal = 1
                traceOpacity = 0
                let anim: Animation? = host.joy == 0 ? nil : .easeIn(duration: 0.5)
                withAnimation(anim) { traceOpacity = 1 }
            }
        }

        // Pip's voice

        private func speak(_ text: String, _ host: PipHost, for seconds: Double = 3) {
            guard host.joy > 0, host.pipHere else { return }
            if host.say(text, for: seconds) { PipTalkTurns.takeFloor(host, for: seconds + 0.5) }
        }
    }
    private let book = Book()

    // MARK: Views

    func card(_ host: PipHost) -> some View {
        Pad(book: book, host: host)
            .onAppear { book.load(host) }
            .onDisappear { book.leave() }
    }

    struct Pad: View {
        let book: Book
        let host: PipHost

        private var footer: String {
            host.pipHere
                ? "Pip guesses when you pause. They only know a few things so far, and learn from what you teach."
                : "A plain sketch pad. Tap What is it? for a best guess."
        }

        var body: some View {
            VStack(spacing: Corner.inset) {
                SettingsCard(title: "Pip's sketchbook", icon: "pencil.and.scribble", footer: footer) {
                    InkPad(book: book, host: host)
                    Talk(book: book, host: host)
                }
            }
        }
    }

    /// The canvas: Pip's trace underneath, your ink on top.
    struct InkPad: View {
        let book: Book
        let host: PipHost

        private static func path(_ pts: [CGPoint]) -> Path {
            var p = Path()
            guard let first = pts.first else { return p }
            p.move(to: first)
            if pts.count == 1 { p.addLine(to: first) }
            for q in pts.dropFirst() { p.addLine(to: q) }
            return p
        }

        var body: some View {
            let strokes = book.strokes
            let live = book.live
            let trace = book.trace
            let reveal = book.reveal
            let opacity = book.traceOpacity
            Canvas { ctx, size in
                let side = min(size.width, size.height) * CGFloat(Tune.traceFit)
                let ox = (size.width - side) / 2
                let oy = (size.height - side) / 2
                var budget = Int(Double(trace.reduce(0) { $0 + $1.count }) * reveal)
                for s in trace {
                    guard budget > 1 else { break }
                    let pts = s.prefix(budget).map { CGPoint(x: ox + $0.x * side, y: oy + $0.y * side) }
                    budget -= s.count
                    ctx.stroke(InkPad.path(pts), with: .color(PipLook.accent.opacity(0.55 * opacity)),
                               style: StrokeStyle(lineWidth: Tune.ink, lineCap: .round, lineJoin: .round, dash: [6, 7]))
                }
                for s in strokes {
                    ctx.stroke(InkPad.path(s), with: .color(.primary),
                               style: StrokeStyle(lineWidth: Tune.ink, lineCap: .round, lineJoin: .round))
                }
                if live.count > 1 {
                    ctx.stroke(InkPad.path(live), with: .color(.primary),
                               style: StrokeStyle(lineWidth: Tune.ink, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Tune.canvasHeight)
            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if book.live.isEmpty { book.strokeBegan() }
                    book.live.append(v.location)
                }
                .onEnded { _ in book.strokeEnded(host) })
            .accessibilityElement()
            .accessibilityLabel("Sketch pad. Draw with a finger or the Pencil.")
            .accessibilityHint(host.pipHere ? "Pause, and Pip guesses what it is." : "Then use the What is it button.")
            .accessibilityAddTraits(.allowsDirectInteraction)
        }
    }

    /// Pip's words and the buttons under the canvas.
    struct Talk: View {
        let book: Book
        let host: PipHost

        private var typed: Binding<String> {
            Binding(get: { book.typed }, set: { book.typed = $0 })
        }

        @ViewBuilder private var answers: some View {
            switch book.phase {
            case .guessed(let label):
                HStack {
                    Button("Yes!") { book.confirm(label, pipGuessedIt: true, host) }
                        .buttonStyle(PluginCardButton(on: true))
                        .accessibilityHint("Pip remembers this drawing as \(label).")
                    Button("No, it's a…") { book.phase = .teaching }
                        .buttonStyle(PluginCardButton())
                }
            case .unsure(let a, let b):
                VStack(alignment: .leading, spacing: 8) {
                    Button("It's \(Eye.article(a))") { book.confirm(a, pipGuessedIt: false, host) }
                        .buttonStyle(PluginCardButton())
                    Button("It's \(Eye.article(b))") { book.confirm(b, pipGuessedIt: false, host) }
                        .buttonStyle(PluginCardButton())
                    Button("Something else…") { book.phase = .teaching }
                        .buttonStyle(PluginCardButton())
                }
            case .teaching:
                VStack(alignment: .leading, spacing: 8) {
                    Text(Say.askWord)
                    HStack {
                        TextField("a…", text: typed)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit { book.teachTyped(host) }
                            .accessibilityLabel("What the drawing is")
                        Button("Teach Pip") { book.teachTyped(host) }
                            .buttonStyle(PluginCardButton(on: true))
                            .disabled(Eye.clean(book.typed).isEmpty)
                    }
                }
            default:
                EmptyView()
            }
        }

        @ViewBuilder private var actions: some View {
            Button(host.pipHere ? "What do you think?" : "What is it?") { book.ask(host) }
                .buttonStyle(PluginCardButton())
                .disabled(book.strokes.isEmpty)
                .accessibilityHint("Shows the best guess for your drawing.")
            if host.pipHere {
                Button("Trace one of Pip's") { book.startTrace(host) }
                    .buttonStyle(PluginCardButton(on: !book.trace.isEmpty))
                    .accessibilityHint("Pip draws a wobbly picture for you to trace over.")
            }
            Button("Clear") { book.clear() }
                .buttonStyle(PluginCardButton())
                .disabled(book.strokes.isEmpty && book.trace.isEmpty)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(book.line.isEmpty ? (host.pipHere ? Say.idleOn : Say.idleOff) : book.line)
                    .opacity(book.line.isEmpty ? 0.6 : 1)
                answers
                ViewThatFits(in: .horizontal) {
                    HStack { actions }
                    VStack(alignment: .leading, spacing: 8) { actions }
                }
            }
            .font(.system(size: 13.5))
        }
    }
}
