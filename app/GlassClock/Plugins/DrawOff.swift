import SwiftUI

// THE DRAW-OFF · plugin v1 (Dream). The crew's team-building game. Pip calls a word, Bob and Dot both draw it, and
// you pick the winner. Bob is neat and slow (and grumbles gently about team building); Dot is quick and wobbly and
// sometimes sticks on a star. Optional third lane, "You": draw your own (finger or Pencil) for a kind verdict.
// Everyone is kind. The score stays on the device. Pip off: still playable, with no Pip lines.
// Joy 0: Pip says nothing. Simpler motion: no bounce, the winner's frame fades in.
// Pip never offers the game on their own: it starts when you press Start.
// Where: a folded section of the Sketch panel (it had its own panel until 31 Oct 2026).

struct DrawOff: SandboxPlugin {
    let info = PluginInfo(id: "drawoff", name: "The Draw-off", version: "v1", shelf: .dream,
                          icon: "paintbrush.pointed",
                          what: "Bob and Dot both draw Pip's word. You pick the winner, or draw your own.")

    // MARK: Tune

    enum Tune {
        static let bobPer = 0.07            // seconds per point: Bob is slow and steady
        static let dotPer = 0.025           // Dot is quick
        static let bobWobble = 0.004        // shake, as a fraction of the drawing box
        static let dotWobble = 0.016
        static let step = 0.04              // points are filled in this far apart so strokes appear smoothly
        static let stickerChance = 0.4      // how often Dot adds a sticker star
        static let ink = 2.4
        static let canvasHeight: CGFloat = 150
        static let maxYouStrokes = 40
        static let maxYouPoints = 4000
    }

    // MARK: Data (hand-made point lists; flat x, y pairs in a 0...1 box, y down)

    struct Stroke: Sendable {
        let pts: [CGPoint]
        let star: Bool
    }

    struct Subject: Sendable {
        let phrase: String          // "a house"
        let bob: [Stroke]
        let dot: [Stroke]
        let sticker: [Stroke]
    }

    enum Table {
        static let all: [Subject] = [house, face, cat, tea, roll, moon]

        static let house = Subject(phrase: "a house",
            bob: bobPen([[0.2, 0.5, 0.2, 0.85, 0.8, 0.85, 0.8, 0.5],
                         [0.12, 0.52, 0.5, 0.18, 0.88, 0.52, 0.12, 0.52],
                         [0.44, 0.85, 0.44, 0.64, 0.58, 0.64, 0.58, 0.85],
                         [0.7, 0.34, 0.7, 0.2, 0.78, 0.2, 0.78, 0.42]]),
            dot: dotPen([[0.22, 0.52, 0.19, 0.86, 0.83, 0.82, 0.78, 0.5],
                         [0.1, 0.55, 0.46, 0.15, 0.9, 0.5],
                         [0.4, 0.84, 0.42, 0.62, 0.6, 0.66, 0.58, 0.84],
                         arc(0.86, 0.14, 0.06, 0.06, 0, 360)]),
            sticker: sticker())

        static let face = Subject(phrase: "a face",
            bob: bobPen([arc(0.5, 0.5, 0.38, 0.38, 0, 360),
                         arc(0.37, 0.42, 0.04, 0.04, 0, 360),
                         arc(0.63, 0.42, 0.04, 0.04, 0, 360),
                         [0.5, 0.48, 0.47, 0.6, 0.53, 0.6],
                         arc(0.5, 0.58, 0.2, 0.18, 20, 160)]),
            dot: dotPen([arc(0.48, 0.5, 0.36, 0.4, -20, 350),
                         arc(0.35, 0.4, 0.06, 0.04, 0, 360),
                         arc(0.65, 0.44, 0.03, 0.05, 0, 360),
                         [0.3, 0.68, 0.5, 0.8, 0.72, 0.66],
                         [0.4, 0.1, 0.44, 0.02, 0.5, 0.1, 0.56, 0.03]]),
            sticker: sticker())

        static let cat = Subject(phrase: "a cat",
            bob: bobPen([arc(0.5, 0.55, 0.3, 0.27, 0, 360),
                         [0.24, 0.42, 0.22, 0.15, 0.42, 0.3],
                         [0.76, 0.42, 0.78, 0.15, 0.58, 0.3],
                         arc(0.4, 0.5, 0.03, 0.03, 0, 360),
                         arc(0.6, 0.5, 0.03, 0.03, 0, 360),
                         [0.46, 0.58, 0.54, 0.58, 0.5, 0.63, 0.46, 0.58],
                         [0.1, 0.55, 0.34, 0.6], [0.1, 0.68, 0.34, 0.64],
                         [0.9, 0.55, 0.66, 0.6], [0.9, 0.68, 0.66, 0.64]]),
            dot: dotPen([arc(0.5, 0.56, 0.32, 0.26, 10, 360),
                         [0.22, 0.44, 0.18, 0.1, 0.44, 0.3],
                         [0.78, 0.4, 0.84, 0.12, 0.58, 0.3],
                         arc(0.4, 0.5, 0.04, 0.05, 0, 360),
                         arc(0.62, 0.52, 0.03, 0.03, 0, 360),
                         [0.45, 0.6, 0.55, 0.6, 0.5, 0.66],
                         [0.06, 0.52, 0.32, 0.62], [0.94, 0.7, 0.68, 0.62]]),
            sticker: sticker())

        static let tea = Subject(phrase: "a cup of tea",
            bob: bobPen([arc(0.5, 0.4, 0.3, 0.06, 0, 360),
                         [0.2, 0.4, 0.27, 0.72],
                         arc(0.5, 0.72, 0.23, 0.12, 0, 180),
                         [0.8, 0.4, 0.73, 0.72],
                         arc(0.82, 0.52, 0.1, 0.1, -90, 90),
                         [0.4, 0.3, 0.36, 0.2, 0.42, 0.1],
                         [0.58, 0.3, 0.54, 0.2, 0.6, 0.1],
                         [0.12, 0.86, 0.88, 0.86]]),
            dot: dotPen([arc(0.5, 0.42, 0.3, 0.08, 0, 360),
                         [0.2, 0.42, 0.3, 0.74],
                         [0.3, 0.74, 0.5, 0.86, 0.72, 0.74],
                         [0.8, 0.42, 0.72, 0.74],
                         arc(0.84, 0.55, 0.12, 0.1, -80, 100),
                         [0.38, 0.32, 0.46, 0.22, 0.36, 0.14, 0.44, 0.04],
                         [0.6, 0.3, 0.52, 0.2, 0.62, 0.1]]),
            sticker: sticker())

        static let roll = Subject(phrase: "a sausage roll",
            bob: bobPen([[0.15, 0.38, 0.85, 0.38],
                         [0.15, 0.66, 0.85, 0.66],
                         arc(0.15, 0.52, 0.06, 0.14, 90, 270),
                         arc(0.85, 0.52, 0.06, 0.14, -90, 90),
                         [0.3, 0.44, 0.38, 0.52], [0.46, 0.44, 0.54, 0.52], [0.62, 0.44, 0.7, 0.52]]),
            dot: dotPen([[0.14, 0.36, 0.86, 0.4],
                         [0.16, 0.68, 0.84, 0.64],
                         arc(0.14, 0.52, 0.07, 0.16, 90, 270),
                         arc(0.86, 0.52, 0.05, 0.12, -90, 90),
                         [0.28, 0.46, 0.4, 0.55], [0.5, 0.44, 0.58, 0.56], [0.66, 0.46, 0.72, 0.52],
                         [0.3, 0.82, 0.31, 0.83], [0.5, 0.86, 0.51, 0.87]]),
            sticker: sticker())

        static let moon = Subject(phrase: "the moon",
            bob: bobPen([arc(0.5, 0.5, 0.34, 0.34, 50, 310),
                         arc(0.62, 0.5, 0.278, 0.278, 69, 291),
                         [0.8, 0.2, 0.8, 0.28], [0.76, 0.24, 0.84, 0.24],
                         [0.86, 0.6, 0.86, 0.66], [0.83, 0.63, 0.89, 0.63]]),
            dot: dotPen([arc(0.5, 0.52, 0.35, 0.33, 45, 315),
                         arc(0.64, 0.5, 0.27, 0.3, 65, 295),
                         [0.82, 0.18, 0.82, 0.3], [0.76, 0.24, 0.88, 0.25]]),
            sticker: sticker())

        // Helpers

        /// Points round (part of) an ellipse, as flat x, y pairs. Angles are in degrees; y is down.
        static func arc(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ from: Double, _ to: Double) -> [Double] {
            let n = max(6, Int(abs(to - from) / 15))
            var out: [Double] = []
            for i in 0...n {
                let a = (from + (to - from) * Double(i) / Double(n)) * Double.pi / 180
                out.append(cx + rx * cos(a))
                out.append(cy + ry * sin(a))
            }
            return out
        }

        /// Dot's sticker: a little five-point star in the top corner.
        static func sticker() -> [Stroke] {
            var flat: [Double] = []
            for k in 0...5 {
                let a = (-90 + Double(k) * 144) * Double.pi / 180
                flat.append(0.86 + 0.08 * cos(a))
                flat.append(0.14 + 0.08 * sin(a))
            }
            return [pen(flat, wobble: Tune.dotWobble * 0.5, seed: 9, star: true)]
        }

        static func bobPen(_ strokes: [[Double]]) -> [Stroke] {
            strokes.enumerated().map { pen($0.element, wobble: Tune.bobWobble, seed: Double($0.offset)) }
        }

        static func dotPen(_ strokes: [[Double]]) -> [Stroke] {
            strokes.enumerated().map { pen($0.element, wobble: Tune.dotWobble, seed: Double($0.offset) + 3) }
        }

        /// Flat pairs in, a stroke out: points filled in along the lines, then shaken a little (the same shake every time).
        static func pen(_ flat: [Double], wobble: Double, seed: Double, star: Bool = false) -> Stroke {
            var raw: [CGPoint] = []
            var i = 0
            while i + 1 < flat.count {
                raw.append(CGPoint(x: flat[i], y: flat[i + 1]))
                i += 2
            }
            var dense: [CGPoint] = []
            for (k, p) in raw.enumerated() {
                if k == 0 {
                    dense.append(p)
                    continue
                }
                let q = raw[k - 1]
                let d = Double(hypot(p.x - q.x, p.y - q.y))
                let steps = max(1, Int((d / Tune.step).rounded(.up)))
                for s in 1...steps {
                    let t = CGFloat(s) / CGFloat(steps)
                    dense.append(CGPoint(x: q.x + (p.x - q.x) * t, y: q.y + (p.y - q.y) * t))
                }
            }
            var shaken: [CGPoint] = []
            for (k, p) in dense.enumerated() {
                let dx = wobble * sin(Double(k) * 0.9 + seed * 2.7)
                let dy = wobble * cos(Double(k) * 1.1 + seed * 1.9)
                shaken.append(CGPoint(x: p.x + CGFloat(dx), y: p.y + CGFloat(dy)))
            }
            return Stroke(pts: shaken, star: star)
        }
    }

    // MARK: Lines (everyone is kind)

    enum Say {
        static let start = [
            "Bob: \"Team building. In my day we just had a cuppa.\"",
            "Bob: \"Drawing. At work. Go on then, I'll humour you.\"",
            "Bob: \"Right. Flask down, pencil up. This is team building, apparently.\"",
        ]
        static let bobWon = [
            "Bob: \"Fair enough. Neat is neat. Don't tell the lads I liked this team building.\"",
            "Bob: \"Ha. Steady hand and a hot cuppa. That's all it takes.\"",
        ]
        static let dotWon = [
            "Dot: \"Me?! Honestly? I'm over the moon. Bob's was lovely too.\"",
            "Dot: \"Ooh! I'll put it on the fridge. Thank you!\"",
        ]
        static let bobSport = [
            "Bob: \"Fair play, Dot. That's got life in it.\"",
            "Bob: \"Good one, Dot. I'd pin that up.\"",
        ]
        static let dotSport = [
            "Dot: \"Bob's is lovely and tidy. Mine's more... lively.\"",
            "Dot: \"Good one, Bob! I'll get there.\"",
        ]
        static let youWon = [
            "Bob: \"Well, I never. A proper artist. Still say team building is daft, mind.\"\nDot: \"Brilliant! I'm learning loads from yours.\"",
        ]
        static let blank = "A blank page. Very brave. Draw a little something and have another go."
        static let small = "Dinky! Little drawings have charm."
        static let busy = "Loads of effort in that one. I can feel the enthusiasm."
        static let nice = "Lovely confident lines. I knew what it was straight away."

        static func reaction(_ side: Game.Side) -> String {
            switch side {
            case .bob: return [bobWon.randomElement() ?? "", dotSport.randomElement() ?? ""].joined(separator: "\n")
            case .dot: return [dotWon.randomElement() ?? "", bobSport.randomElement() ?? ""].joined(separator: "\n")
            case .you: return youWon.randomElement() ?? ""
            }
        }

        static func pipCall(_ side: Game.Side) -> String {
            switch side {
            case .bob: return "Point to Bob!"
            case .dot: return "Point to Dot!"
            case .you: return "Point to you!"
            }
        }
    }

    // MARK: Logic

    /// One game's state while the app runs. The score is also saved on the device.
    @MainActor @Observable final class Game {
        enum Phase { case idle, drawing, judging, done }
        enum Side { case bob, dot, you }

        var phase: Phase = .idle
        var subject: Subject?
        var bobStrokes: [Stroke] = []
        var dotStrokes: [Stroke] = []
        var bobShown = 0
        var dotShown = 0
        var winner: Side?
        var line = ""
        var verdict = ""
        var withYou = false
        var you: [[CGPoint]] = []
        var live: [CGPoint] = []
        var bobWins = 0
        var dotWins = 0
        var youWins = 0
        @ObservationIgnored var run: Task<Void, Never>?
        @ObservationIgnored var deck: [Int] = []
        @ObservationIgnored var last = -1
        @ObservationIgnored var loaded = false

        var bobTotal: Int { bobStrokes.reduce(0) { $0 + $1.pts.count } }
        var dotTotal: Int { dotStrokes.reduce(0) { $0 + $1.pts.count } }
        var hasSticker: Bool { dotStrokes.contains { $0.star } }
        var youActive: Bool { phase == .drawing || phase == .judging }

        func load(_ host: PipHost) {
            if !loaded {
                loaded = true
                bobWins = host.value("drawoff", "bob") ?? 0
                dotWins = host.value("drawoff", "dot") ?? 0
                youWins = host.value("drawoff", "you") ?? 0
                withYou = host.value("drawoff", "withYou") ?? false
            }
            // Closed halfway through a round: finish the drawings so the round can go on.
            if phase == .drawing {
                bobShown = bobTotal
                dotShown = dotTotal
                phase = .judging
            }
        }

        func save(_ host: PipHost) {
            host.setValue(bobWins, "drawoff", "bob")
            host.setValue(dotWins, "drawoff", "dot")
            host.setValue(youWins, "drawoff", "you")
            host.setValue(withYou, "drawoff", "withYou")
        }

        func leave() { run?.cancel() }

        func resetScore(_ host: PipHost) {
            bobWins = 0
            dotWins = 0
            youWins = 0
            save(host)
        }

        func setWithYou(_ on: Bool, _ host: PipHost) {
            withYou = on
            if !on {
                you = []
                live = []
                verdict = ""
            }
            save(host)
        }

        // A round

        func next(_ host: PipHost) {
            run?.cancel()
            if deck.isEmpty {
                deck = Array(Table.all.indices).shuffled()
                if deck.count > 1, deck.first == last { deck.swapAt(0, deck.count - 1) }
            }
            let i = deck.removeFirst()
            last = i
            let s = Table.all[i]
            subject = s
            bobStrokes = s.bob
            dotStrokes = s.dot + (Double.random(in: 0..<1) < Tune.stickerChance ? s.sticker : [])
            bobShown = 0
            dotShown = 0
            winner = nil
            verdict = ""
            you = []
            live = []
            phase = .drawing
            line = Say.start.randomElement() ?? ""
            speak("Draw \(s.phrase)!", host, for: 2.6)
            if host.simpler {
                bobShown = bobTotal
                dotShown = dotTotal
                finishDrawing(host)
                return
            }
            run = Task { [weak self] in
                var t = 0.0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(0.04))
                    guard let self, self.phase == .drawing else { return }
                    t += 0.04
                    self.bobShown = min(self.bobTotal, Int(t / Tune.bobPer))
                    self.dotShown = min(self.dotTotal, Int(t / Tune.dotPer))
                    if self.bobShown >= self.bobTotal, self.dotShown >= self.dotTotal {
                        self.finishDrawing(host)
                        return
                    }
                }
            }
        }

        private func finishDrawing(_ host: PipHost) {
            guard phase == .drawing else { return }
            phase = .judging
            line = hasSticker ? "Both done, and Dot added a star. Tap the one you like." : "Both done. Tap the one you like."
            speak("Done! Tap the one you like.", host, for: 2.6)
        }

        func pick(_ side: Side, _ host: PipHost) {
            guard phase == .judging else { return }
            phase = .done
            winner = side
            switch side {
            case .bob: bobWins += 1
            case .dot: dotWins += 1
            case .you: youWins += 1
            }
            save(host)
            line = Say.reaction(side)
            if host.joy > 0 { host.cheer() }
            speak(Say.pipCall(side), host, for: 2.4)
        }

        // Your lane

        func addPoint(_ p: CGPoint) {
            guard youActive, live.count < Tune.maxYouPoints else { return }
            live.append(p)
        }

        func strokeEnded() {
            if live.count > 1, you.count < Tune.maxYouStrokes { you.append(live) }
            live = []
        }

        func clearYou() {
            you = []
            live = []
            verdict = ""
        }

        func giveVerdict(_ host: PipHost) {
            guard !you.isEmpty else {
                verdict = Say.blank
                return
            }
            let all = you.flatMap { $0 }
            let xs = all.map { Double($0.x) }
            let ys = all.map { Double($0.y) }
            let w = (xs.max() ?? 0) - (xs.min() ?? 0)
            let h = (ys.max() ?? 0) - (ys.min() ?? 0)
            let span = max(w, h) / Double(Tune.canvasHeight)
            let text = span < 0.25 ? Say.small : (you.count >= 6 ? Say.busy : Say.nice)
            verdict = text
            speak(text, host, for: 3.4)
        }

        // Pip's voice: only when Pip is here, joy is above 0, and nobody else has the floor.
        private func speak(_ text: String, _ host: PipHost, for seconds: Double) {
            guard host.joy > 0, host.pipHere, PipTalkTurns.floorFree(host) else { return }
            if host.say(text, for: seconds) { PipTalkTurns.takeFloor(host, for: seconds + 0.5) }
        }
    }
    private let game = Game()

    // MARK: Views

    // A folded section of the Sketch panel, so every drawing menu lives in one panel (Aaron, 31 Oct 2026).
    var addsTo: String? { "sketch" }
    func addOn(_ host: PipHost) -> some View {
        Board(game: game, host: host)
            .onAppear { game.load(host) }
            .onDisappear { game.leave() }
    }

    struct Board: View {
        let game: Game
        let host: PipHost

        private var footer: String {
            "Bob draws neat and slow, Dot draws quick and wobbly. Tap the one you like. The score stays on this device."
        }

        var body: some View {
            // The panel gives the section its title and glass.
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Round(game: game, host: host)
                Text(footer).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    struct Round: View {
        let game: Game
        let host: PipHost

        private func tile(_ side: Game.Side, _ name: String, _ strokes: [Stroke], _ shown: Int, _ ink: Color) -> some View {
            Tile(name: name, word: game.subject?.phrase ?? "", strokes: strokes, shown: shown, ink: ink,
                 isWinner: game.winner == side,
                 isLoser: game.winner != nil && game.winner != side,
                 canPick: game.phase == .judging,
                 fade: host.simpler) { game.pick(side, host) }
        }

        private var showYouScore: Bool { game.withYou || game.youWins > 0 }

        private var score: String {
            var s = "Bob \(game.bobWins) · Dot \(game.dotWins)"
            if showYouScore { s += " · You \(game.youWins)" }
            return s
        }

        private var scoreSpoken: String {
            var s = "Score. Bob \(game.bobWins). Dot \(game.dotWins)."
            if showYouScore { s += " You \(game.youWins)." }
            return s
        }

        @ViewBuilder private var buttons: some View {
            Button(game.phase == .idle ? "Start" : "New word") { game.next(host) }
                .buttonStyle(PluginCardButton(on: game.phase == .idle || game.phase == .done))
                .accessibilityHint("A word for Bob and Dot to draw.")
            Button(game.withYou ? "You: on" : "You: off") { game.setWithYou(!game.withYou, host) }
                .buttonStyle(PluginCardButton(on: game.withYou))
                .accessibilityLabel("Your lane")
                .accessibilityValue(game.withYou ? "On" : "Off")
                .accessibilityHint("Turns on a canvas so you can draw the word too.")
            if game.bobWins + game.dotWins + game.youWins > 0 {
                Button("Reset score") { game.resetScore(host) }
                    .buttonStyle(PluginCardButton())
                    .accessibilityHint("Sets every score back to nothing.")
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if let s = game.subject, game.phase != .idle {
                    Text("Draw \(s.phrase)")
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                } else {
                    Text("Press Start for a word. Bob and Dot both draw it, and you pick the winner.")
                        .opacity(0.6)
                }
                HStack(spacing: 10) {
                    tile(.bob, "Bob", game.bobStrokes, game.bobShown, .primary)
                    tile(.dot, "Dot", game.dotStrokes, game.dotShown, PipLook.accent)
                }
                .opacity(game.phase == .idle ? 0.35 : 1)
                if !game.line.isEmpty {
                    Text(game.line)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if game.withYou {
                    YouPad(game: game, host: host)
                }
                ViewThatFits(in: .horizontal) {
                    HStack { buttons }
                    VStack(alignment: .leading, spacing: 8) { buttons }
                }
                Text(score)
                    .font(.system(size: 13.5, weight: .semibold))
                    .accessibilityLabel(scoreSpoken)
            }
            .font(.system(size: 13.5))
        }
    }

    /// One lane: the drawing as it appears, and a button to pick it.
    struct Tile: View {
        let name: String
        let word: String
        let strokes: [Stroke]
        let shown: Int
        let ink: Color
        let isWinner: Bool
        let isLoser: Bool
        let canPick: Bool
        let fade: Bool
        let action: () -> Void

        var body: some View {
            let anim: Animation = fade ? Animation.easeInOut(duration: 0.3) : Animation.spring(duration: 0.5, bounce: 0.4)
            Button(action: action) {
                VStack(spacing: 6) {
                    Canvas { ctx, size in
                        var budget = shown
                        let box = min(size.width, size.height) * 0.9
                        let ox = (size.width - box) / 2
                        let oy = (size.height - box) / 2
                        for s in strokes {
                            guard budget > 0 else { break }
                            let pts = s.pts.prefix(budget).map { CGPoint(x: ox + $0.x * box, y: oy + $0.y * box) }
                            budget -= s.pts.count
                            guard let first = pts.first else { continue }
                            var p = Path()
                            p.move(to: first)
                            if pts.count == 1 { p.addLine(to: first) }
                            for q in pts.dropFirst() { p.addLine(to: q) }
                            ctx.stroke(p, with: .color(s.star ? Color.orange : ink),
                                       style: StrokeStyle(lineWidth: Tune.ink, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(PipLook.accent, lineWidth: 2).opacity(isWinner ? 1 : 0))
                    Text(isWinner ? "\(name) wins" : name)
                        .font(.system(size: 13.5, weight: .semibold))
                }
                .scaleEffect(isWinner && !fade ? 1.04 : 1)
                .opacity(isLoser ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .disabled(!canPick)
            .animation(anim, value: isWinner)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(word.isEmpty ? "\(name)'s drawing" : "\(name)'s drawing of \(word)")
            .accessibilityValue(isWinner ? "Winner" : "")
            .accessibilityHint(canPick ? "Tap to pick \(name) as the winner." : "You can pick once both have finished drawing.")
        }
    }

    /// The optional third lane: your own canvas, finger or Pencil.
    struct YouPad: View {
        let game: Game
        let host: PipHost

        private static func path(_ pts: [CGPoint]) -> Path {
            var p = Path()
            guard let first = pts.first else { return p }
            p.move(to: first)
            if pts.count == 1 { p.addLine(to: first) }
            for q in pts.dropFirst() { p.addLine(to: q) }
            return p
        }

        @ViewBuilder private var buttons: some View {
            Button(host.pipHere ? "Pip's verdict" : "Verdict") { game.giveVerdict(host) }
                .buttonStyle(PluginCardButton())
                .disabled(game.phase == .idle)
                .accessibilityHint("A kind word about your drawing.")
            if game.phase == .judging, !game.you.isEmpty {
                Button("Pick mine") { game.pick(.you, host) }
                    .buttonStyle(PluginCardButton(on: true))
                    .accessibilityHint("Picks your own drawing as the winner.")
            }
            Button("Clear") { game.clearYou() }
                .buttonStyle(PluginCardButton())
                .disabled(game.you.isEmpty && game.live.isEmpty)
        }

        var body: some View {
            let strokes = game.you
            let live = game.live
            VStack(alignment: .leading, spacing: 8) {
                Text("You")
                    .font(.system(size: 13.5, weight: .semibold))
                Canvas { ctx, _ in
                    for s in strokes {
                        ctx.stroke(YouPad.path(s), with: .color(.primary),
                                   style: StrokeStyle(lineWidth: Tune.ink, lineCap: .round, lineJoin: .round))
                    }
                    if live.count > 1 {
                        ctx.stroke(YouPad.path(live), with: .color(.primary),
                                   style: StrokeStyle(lineWidth: Tune.ink, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: Tune.canvasHeight)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
                .contentShape(.rect)
                .allowsHitTesting(game.youActive)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in game.addPoint(v.location) }
                    .onEnded { _ in game.strokeEnded() })
                .accessibilityElement()
                .accessibilityLabel("Your drawing pad. Draw with a finger or the Pencil.")
                .accessibilityHint(game.youActive ? "Draw the word too." : "Press Start first.")
                .accessibilityAddTraits(.allowsDirectInteraction)
                if !game.verdict.isEmpty {
                    Text(game.verdict)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack { buttons }
                    VStack(alignment: .leading, spacing: 8) { buttons }
                }
            }
        }
    }
}
