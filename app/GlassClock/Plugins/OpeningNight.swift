import SwiftUI
import UIKit

// OPENING NIGHT · plugin v1 (Dream). The app's launch, made into a little show that plays along with Pip's
// real first meeting (falls in as a twinkle, lands asleep, wakes on your tap).
// - Opening night (once): when you first wake Pip, the lights dim, a spotlight finds Pip, and Pip breathes out
//   a stream of glass that builds the word "Hello!", holds, then bursts into sparkles. Pip takes a bow.
// - Previously on… (later launches): a TV-style recap built from Pip Remembers' notebook. Gently silly.
// - Time eggs: opening the app at certain times gets a one-off joke (04:04, 09:41, 10:09, 11:11, 12:34, midnight).
// Calm by default: the recap shows once a day; every launch is a setting. Under simpler motion, everything fades.
// Where: the theater-masks button in the plugin bar (replay buttons and settings).

struct OpeningNight: SandboxPlugin {
    let info = PluginInfo(id: "opening", name: "Opening Night", version: "v1", shelf: .dream,
                          icon: "theatermasks", what: "Pip's launch as a little show: a spotlight, glass that spells hello, and recaps.")

    // MARK: Data

    enum Often: String, CaseIterable {
        case never, daily, always
        var label: String { ["never": "Never", "daily": "Once a day", "always": "Every launch"][rawValue] ?? rawValue }
    }

    enum Lines {
        static let premiere = ["Wait. Is this… opening night?", "Is that a spotlight? On me?"]
        static let bow = ["Thank you, thank you. I'm here all week. Literally, I live here.",
                          "No flowers, please. Glass and water don't mix. Well, they do. That's the problem."]
        static let encore = ["Encore? Oh, go on then.", "From the top!", "Again! With feeling."]
        static let previously = "Previously on Pip Sandbox…"
        static func recap(_ m: PipRemembers.Memory, away: TimeInterval) -> [String] {
            var l: [String] = []
            if m.flicks > 0 { l.append("You flicked Pip \(m.flicks) time\(m.flicks == 1 ? "" : "s"). Pip has forgiven \(max(m.flicks - 1, 0)).") }
            if m.pokes > 2 { l.append("\(m.pokes) pokes. Pip counted every one. Pip always counts.") }
            if m.bumps > 0 { l.append("Pip hit the wall \(m.bumps) time\(m.bumps == 1 ? "" : "s"). The wall is fine. Pip is fine. Mostly.") }
            if away > 2 * 86_400 { l.append("You were away \(Int(away / 86_400)) days. Pip reorganised the pixels.") }
            else if away > 3_600 { l.append("You were away a while. Pip practised standing still.") }
            if m.visits > 1 { l.append("Visit number \(m.visits). Pip is keeping the ticket stubs.") }
            if l.isEmpty { l.append("Nothing happened. It was lovely.") }
            return l
        }
        /// One-off jokes for opening the app at a certain time, keyed "HH:mm".
        static let times: [String: String] = [
            "04:04": "Time not found. Try again later.",
            "09:41": "Ooh, product-photo o'clock. Smile for the keynote.",
            "10:09": "Ten past ten. The hands' favourite pose. Very flattering.",
            "11:11": "11:11. Make a wish. I wished for more glass.",
            "12:34": "12:34! The time is counting itself.",
            "00:00": "Midnight. I turn back into a pumpkin. A glass one.",
        ]
    }

    /// Timings of the opening-night show, in seconds from its start.
    enum Cue {
        static let dim = 0.0, gather = 0.9, hold = 3.1, burst = 4.4, lights = 5.6, end = 6.4
    }

    // MARK: Logic

    @MainActor @Observable final class Show {
        enum Kind { case premiere, recap }
        var kind: Kind?
        var started = Date.distantPast
        var from = CGPoint.zero
        var lines: [String] = []
        @ObservationIgnored var targets: [CGPoint] = []
        @ObservationIgnored var seeds: [Double] = []
    }
    private let show = Show()

    static func often(_ host: PipHost) -> Often { Often(rawValue: host.value("opening", "often") ?? "") ?? .daily }

    func start(_ host: PipHost) throws {}

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .wake where !(host.value("opening", "premiered") ?? false):
            host.setValue(true, "opening", "premiered")
            host.later(1.4) { premiere(host) }
        case .appear:
            host.later(2.2) { launchTreats(host) }
        default:
            break
        }
    }

    /// The opening-night show: spotlight, "Hello!" in glass, burst, bow.
    @MainActor func premiere(_ host: PipHost, encore: Bool = false) {
        guard show.kind == nil else { return }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let bounds = scene?.coordinateSpace.bounds.size ?? CGSize(width: 1024, height: 768)
        show.targets = Self.points(spelling: "Hello!", width: min(bounds.width * 0.7, 640),
                                   centre: CGPoint(x: bounds.width / 2, y: bounds.height * 0.38))
        show.seeds = show.targets.indices.map { _ in Double.random(in: 0...1) }
        show.from = host.pipHere ? host.pipPosition : CGPoint(x: bounds.width / 2, y: bounds.height * 0.7)
        show.started = .now
        show.kind = .premiere
        host.say((encore ? Lines.encore : Lines.premiere).randomElement()!, for: 1.6)
        host.later(Cue.burst) { host.cheer() }
        host.later(Cue.lights) { host.say(Lines.bow.randomElement()!, for: 3.2) }
        host.later(Cue.end) { if show.kind == .premiere { show.kind = nil } }
    }

    /// Later launches: maybe a recap, maybe a time egg. Never both at once.
    @MainActor func launchTreats(_ host: PipHost, force: Bool = false) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        if !force, let egg = Lines.times[time], host.say(egg, for: 3.4) { return }
        guard host.value("opening", "premiered") ?? false else { return }
        let often = Self.often(host)
        let today = Date.now.formatted(date: .numeric, time: .omitted)
        guard force || often == .always || (often == .daily && host.value("opening", "recapDay") != today) else { return }
        guard show.kind == nil else { return }
        host.setValue(today, "opening", "recapDay")
        let memory = PipRemembers.load()
        let away = Date.now.timeIntervalSince(host.value("opening", "lastSeen") ?? Date.now)
        host.setValue(Date.now, "opening", "lastSeen")
        show.lines = Array(Lines.recap(memory, away: away).shuffled().prefix(2))
        show.started = .now
        show.kind = .recap
        host.later(6.5) { if show.kind == .recap { show.kind = nil } }
    }

    /// Points that fill the letters of `text`, sampled from a rendered image. About 500 of them.
    @MainActor static func points(spelling text: String, width: CGFloat, centre: CGPoint) -> [CGPoint] {
        let size = CGSize(width: width, height: width * 0.32)
        let renderer = ImageRenderer(content:
            Text(text).font(.system(size: size.height * 0.82, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: size.width, height: size.height))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return [] }
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        // Pick a step that gives roughly 500 points, however big the screen is.
        var filled = 0
        for i in stride(from: 3, to: pixels.count, by: 16) where pixels[i] > 128 { filled += 1 }
        let step = max(3, Int((Double(filled * 4) / 500).squareRoot()))
        var out: [CGPoint] = []
        for y in stride(from: 0, to: h, by: step) {
            for x in stride(from: (y / step) % 2 == 0 ? 0 : step / 2, to: w, by: step) where pixels[(y * w + x) * 4 + 3] > 128 {
                out.append(CGPoint(x: centre.x - size.width / 2 + CGFloat(x), y: centre.y - size.height / 2 + CGFloat(y)))
            }
        }
        return out
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Stage(show: show, simpler: host.simpler) }

    func card(_ host: PipHost) -> some View { Programme(plugin: self, host: host) }

    /// The show itself. Only exists while something is playing, so nothing runs otherwise.
    struct Stage: View {
        let show: Show
        let simpler: Bool

        var body: some View {
            ZStack {
                switch show.kind {
                case .premiere: Premiere(show: show, simpler: simpler)
                case .recap: Recap(lines: show.lines)
                case nil: EmptyView()
                }
            }
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.4), value: show.kind == nil)
        }
    }

    struct Premiere: View {
        let show: Show
        let simpler: Bool

        var body: some View {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(show.started)
                let targets = show.targets, seeds = show.seeds, from = show.from, simpler = simpler
                Canvas { ctx, size in
                    // Lights down, with a spotlight on Pip, then lights up at the end.
                    let dim = min(1, t / 0.6) * (t > Cue.lights ? max(0, 1 - (t - Cue.lights) / 0.8) : 1)
                    var room = Path(CGRect(origin: .zero, size: size))
                    let spot = 70 + 30 * sin(t * 2)
                    room.addEllipse(in: CGRect(x: from.x - spot, y: from.y - spot, width: spot * 2, height: spot * 2))
                    ctx.fill(room, with: .color(.black.opacity(0.55 * dim)), style: FillStyle(eoFill: true))

                    for (i, target) in targets.enumerated() {
                        let seed = seeds[i]
                        var p: CGPoint
                        var alpha = 1.0
                        var r = 3.2
                        if simpler {
                            // Fade the word in and out where it stands.
                            p = target
                            alpha = t < Cue.gather ? 0 : t < Cue.hold ? (t - Cue.gather) / (Cue.hold - Cue.gather)
                                : max(0, 1 - (t - Cue.burst) / 1)
                        } else if t < Cue.hold {
                            // Stream out of Pip, each piece a little later than the last, curving as it flies.
                            let k = min(max((t - Cue.gather - seed * 1.2) / 1.0, 0), 1)
                            let e = 1 - pow(1 - k, 3)
                            let lift = sin(k * .pi) * (60 + seed * 90)
                            p = CGPoint(x: from.x + (target.x - from.x) * e, y: from.y + (target.y - from.y) * e - lift)
                            alpha = k > 0 ? 1 : 0
                        } else if t < Cue.burst {
                            // Hold, with a shimmer running through the letters.
                            p = target
                            r += max(0, sin((Double(target.x) / 40) - (t - Cue.hold) * 9)) * 1.6
                        } else {
                            // Burst: fly outward with a little gravity, shrinking to sparkles.
                            let b = t - Cue.burst
                            let angle = seed * 2 * .pi
                            let speed = 160 + seed * 340
                            p = CGPoint(x: target.x + cos(angle) * speed * b, y: target.y + sin(angle) * speed * b + 260 * b * b)
                            alpha = max(0, 1 - b / 1.4)
                            r *= max(0.3, 1 - b)
                        }
                        guard alpha > 0 else { continue }
                        let dot = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: dot), with: .color(PipLook.glow.opacity(alpha)))
                        ctx.fill(Path(ellipseIn: dot.insetBy(dx: r * 0.55, dy: r * 0.55).offsetBy(dx: -r * 0.3, dy: -r * 0.3)),
                                 with: .color(.white.opacity(alpha * 0.9)))
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }

    /// "Previously on…", like the start of a TV episode.
    struct Recap: View {
        let lines: [String]
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(Lines.previously).font(.system(size: 13.5, weight: .bold)).italic()
                ForEach(lines, id: \.self) { Text($0).font(.system(size: 13.5)) }
            }
            .padding(PluginBarLook.cardPadding)
            .frame(maxWidth: PluginBarLook.cardWidth, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: PluginBarLook.radius))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        }
    }

    /// The card: how often the recap plays, and replay buttons.
    struct Programme: View {
        let plugin: OpeningNight
        let host: PipHost
        @State private var often = Often.daily

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("Previously on… plays").bold()
                HStack(spacing: 6) {
                    ForEach(Often.allCases, id: \.self) { o in
                        Button(o.label) {
                            often = o
                            host.setValue(o.rawValue, "opening", "often")
                        }
                        .buttonStyle(PluginCardButton(on: often == o))
                        .accessibilityAddTraits(often == o ? .isSelected : [])
                    }
                }
                HStack(spacing: 6) {
                    Button("Replay opening night") { plugin.premiere(host, encore: true) }
                        .buttonStyle(PluginCardButton())
                    Button("Previously on…") { plugin.launchTreats(host, force: true) }
                        .buttonStyle(PluginCardButton())
                }
                Text("Some times of day have a joke waiting. You'll know when you find one.")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13.5))
            .onAppear { often = OpeningNight.often(host) }
        }
    }
}
