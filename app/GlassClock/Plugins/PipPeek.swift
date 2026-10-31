import SwiftUI
import UIKit

// PIP PEEK · plugin v1 (On trial). Aaron's own Pip (his Procreate drawing over Sheet A, 31 Oct), peeking round the
// edge of whatever panel or card is open: hidden (just an ear tip), peeking (head out, eyes on you), emerging (tap:
// out a little further, a small "o", then back). Left alone for 10 seconds, they tuck away. From the browser
// prototype (app/design/pip-peek-prototype.html) and the trace (app/design/pip-v2-trace.html): same numbers.
// Also a small hello when you open the app: Pip peeks in from the left edge for a moment. Easy to switch off.
// Version 1 / Version 2 in the card: V1 is the original (no peeking), V2 is Aaron's Pip. Nothing is replaced: the
// fairy Pip stays as they are. A full costume swap needs the core's costume slot (Robyn), not this plugin.
// Light: drawn only while a panel is open or the hello is on, a small view clipped at the panel's edge, no timers
// running in between. Pip off: nothing shows. Simpler motion: fades, doesn't move.

struct PipPeek: SandboxPlugin {
    let info = PluginInfo(id: "peek", name: "Pip Peek", version: "v1", shelf: .trial,
                          icon: "eyes", what: "Aaron's Pip peeks round the edge of open panels, and says hello when you open the app.")

    // MARK: Tune

    enum Tune {
        static let size: CGFloat = 120          // Pip's box, points
        static let strip: CGFloat = 200         // how far out from the edge Pip can be seen
        static let settle = 0.9                 // seconds after a panel opens before Pip peeks
        static let idle = 10.0                  // seconds alone before Pip tucks away
        static let helloFor = 4.0               // seconds the hello lasts
        // Where Pip's left edge sits, measured from the panel's edge (negative = behind it), and the lean.
        static let hiddenOut: CGFloat = -82, hiddenLean = -8.0
        static let peekOut: CGFloat = -58, peekLean = 6.0
        static let emergeOut: CGFloat = -14, emergeLean = 0.0
    }

    enum Pose { case hidden, peeking, emerging }

    // MARK: Data: Aaron's Pip, in a 100-wide box, facing right (pip-v2-trace.html)

    enum Geo {
        static let head = (x: 64.0, y: 50.0, r: 19.0)
        static let body = (x: 44.0, y: 62.0, r: 18.0)
        static let tail = (x: 12.0, y: 66.0, r: 10.0)
        static let earUp = (base: CGPoint(x: 60, y: 34), tip: CGPoint(x: 72, y: 2), width: 8.0)
        static let earBack = (base: CGPoint(x: 50, y: 44), tip: CGPoint(x: 18, y: 33), width: 8.0)
        static let eyes = [CGPoint(x: 58, y: 48), CGPoint(x: 69, y: 46)]
        static let mouth = CGPoint(x: 67, y: 60)
    }

    // MARK: State

    @MainActor @Observable final class Session {
        var hello = false
        @ObservationIgnored var watching = false
    }
    private let session = Session()

    func start(_ host: PipHost) throws {
        sayHello(host)
        guard !session.watching else { return }
        session.watching = true
        let s = session
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil,
                                               queue: .main) { _ in
            Task { @MainActor in PipPeek.hello(s, host) }
        }
    }

    private func sayHello(_ host: PipHost) { Self.hello(session, host) }

    @MainActor static func hello(_ s: Session, _ host: PipHost) {
        guard host.isOn("peek"), host.pipOn, (host.value("peek", "version") ?? 2) == 2,
              host.value("peek", "hello") ?? true, !s.hello else { return }
        host.later(1.2) {
            s.hello = true
            host.later(Tune.helloFor) { s.hello = false }
        }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { PeekOverlay(host: host, session: session) }

    func card(_ host: PipHost) -> some View { PeekCard(host: host, session: session) }

    struct PeekOverlay: View {
        let host: PipHost
        let session: Session
        @AppStorage("plug.peek.version") private var version = 2

        var body: some View {
            if version == 2, host.pipOn {
                if session.hello {
                    GeometryReader { geo in
                        PeekStrip(host: host, edgeX: 0, y: geo.size.height * 0.6, facingRight: true, hello: true)
                    }
                } else if let open = host.openCard {
                    PanelPeek(host: host).id(open)
                }
            }
        }
    }

    /// Finds the open panel (or card) a moment after it opens, then peeks from its inner edge.
    struct PanelPeek: View {
        let host: PipHost
        @State private var spot: (x: CGFloat, y: CGFloat, right: Bool)?

        var body: some View {
            GeometryReader { geo in
                if let spot {
                    PeekStrip(host: host, edgeX: spot.x, y: spot.y, facingRight: spot.right, hello: false)
                } else {
                    Color.clear.allowsHitTesting(false)
                        .onAppear { host.later(Tune.settle) { spot = PanelPeek.find(host, geo.size) } }
                }
            }
        }

        /// The panel's edge that faces the middle of the screen, in this view's space (inside the safe area).
        @MainActor static func find(_ host: PipHost, _ room: CGSize) -> (x: CGFloat, y: CGFloat, right: Bool)? {
            let raw = host.panelFrame.isNull ? host.cardFrame : host.panelFrame
            guard !raw.isNull, raw.width > 160, raw.width < room.width * 0.8 else { return nil }
            let inset = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows).first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
            let f = raw.offsetBy(dx: -inset.left, dy: -inset.top)
            let right = f.midX < room.width / 2
            let x = right ? f.maxX : f.minX
            let y = min(f.minY + max(f.height * 0.5, 120), room.height - 120)
            guard right ? x + Tune.strip < room.width + 40 : x - Tune.strip > -40 else { return nil }
            return (x, y, right)
        }
    }

    /// Pip in a strip that starts at the edge: anything "behind" the edge is clipped away.
    struct PeekStrip: View {
        let host: PipHost
        let edgeX: CGFloat
        let y: CGFloat
        let facingRight: Bool
        let hello: Bool
        @State private var pose = Pose.hidden
        @State private var mouth = false
        @State private var shown = false
        /// Bumped on every change, so an old "later" doesn't undo a newer one.
        @State private var turn = 0

        private var out: CGFloat {
            switch pose { case .hidden: Tune.hiddenOut; case .peeking: Tune.peekOut; case .emerging: Tune.emergeOut }
        }
        private var lean: Double {
            switch pose { case .hidden: Tune.hiddenLean; case .peeking: Tune.peekLean; case .emerging: Tune.emergeLean }
        }

        var body: some View {
            let calm = host.simpler
            let visible = max(0, min(Tune.strip, out + Tune.size * 0.92))
            ZStack(alignment: .leading) {
                PipV2(look: pose == .hidden ? 0 : 2.4, mouth: mouth)
                    .frame(width: Tune.size, height: Tune.size)
                    .rotationEffect(.degrees(lean), anchor: UnitPoint(x: 0.5, y: 0.85))
                    .offset(x: calm ? Tune.peekOut : out)
                    .opacity(calm ? (pose == .hidden ? 0 : 1) : (shown ? 1 : 0))
                    .allowsHitTesting(false)
                // Only the part you can see takes a tap.
                Color.clear
                    .frame(width: max(1, visible), height: Tune.size * 0.8)
                    .contentShape(.rect)
                    .onTapGesture { tapped() }
                    .accessibilityElement()
                    .accessibilityLabel("Pip, peeking")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Pip comes out to say hello.")
                    .allowsHitTesting(pose != .hidden || hello)
            }
            .frame(width: Tune.strip, height: Tune.size + 20, alignment: .leading)
            .clipped()
            .scaleEffect(x: facingRight ? 1 : -1, y: 1)
            .position(x: facingRight ? edgeX + Tune.strip / 2 : edgeX - Tune.strip / 2, y: y)
            .animation(calm ? .easeInOut(duration: 0.35) : .spring(response: 0.9, dampingFraction: 0.78), value: pose)
            .animation(.easeOut(duration: 0.3), value: shown)
            .onAppear { arrive() }
        }

        private func set(_ p: Pose) { pose = p; turn += 1 }

        private func arrive() {
            shown = true
            let mine = turn + 1
            set(.hidden)
            host.later(hello ? 0.3 : 0.4) {
                guard turn == mine else { return }
                set(.peeking)
                if hello {
                    let peek = turn
                    host.later(Tune.helloFor - 1.2) { if turn == peek { set(.hidden) } }
                } else {
                    tuckLater()
                }
            }
        }

        private func tuckLater() {
            let mine = turn
            host.later(Tune.idle) { if turn == mine { set(.hidden) } }
        }

        private func tapped() {
            set(.emerging)
            mouth = true
            host.later(0.9) { mouth = false }
            let mine = turn
            host.later(2.6) {
                guard turn == mine else { return }
                set(.peeking)
                tuckLater()
            }
        }
    }

    /// Aaron's Pip: body behind, two leaf ears, the round head in front, two eyes; a little "o" now and then.
    struct PipV2: View {
        var look: CGFloat = 0
        var mouth = false
        var silhouette = false

        var body: some View {
            Canvas { ctx, size in
                let s = size.width / 110
                ctx.scaleBy(x: s, y: s)
                ctx.translateBy(x: 5, y: 5)
                let ink = Color(red: 0.086, green: 0.094, blue: 0.122)
                let line = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                func paint(_ path: Path, _ light: Color, _ mid: Color, _ dark: Color, centre: CGPoint, radius: CGFloat) {
                    if silhouette {
                        ctx.fill(path, with: .color(ink))
                    } else {
                        ctx.fill(path, with: .radialGradient(Gradient(colors: [light, mid, dark]), center: centre,
                                                             startRadius: 0, endRadius: radius))
                        ctx.stroke(path, with: .color(ink), style: line)
                    }
                }
                let h = Geo.head, b = Geo.body, t = Geo.tail
                paint(PipPeek.tube(b, t), .white, Color(white: 0.91), Color(red: 0.65, green: 0.67, blue: 0.72),
                      centre: CGPoint(x: b.x - 6, y: b.y - 10), radius: 46)
                for ear in [Geo.earUp, Geo.earBack] {
                    paint(PipPeek.leaf(ear.base, ear.tip, ear.width), .white, Color(white: 0.94),
                          Color(red: 0.76, green: 0.78, blue: 0.81), centre: ear.base, radius: 36)
                }
                let headRect = CGRect(x: h.x - h.r, y: h.y - h.r, width: h.r * 2, height: h.r * 2)
                paint(Path(ellipseIn: headRect), .white, Color(white: 0.95), Color(red: 0.72, green: 0.74, blue: 0.78),
                      centre: CGPoint(x: h.x - h.r * 0.3, y: h.y - h.r * 0.4), radius: h.r * 1.6)
                if !silhouette {
                    let shine = CGRect(x: h.x - h.r * 0.62, y: h.y - h.r * 0.61, width: h.r * 0.64, height: h.r * 0.32)
                    ctx.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.9)))
                }
                let eyeColour: Color = silhouette ? .white : ink
                for e in Geo.eyes {
                    let c = CGPoint(x: e.x + look, y: e.y)
                    let eye = Path(ellipseIn: CGRect(x: -2.3, y: -3.9, width: 4.6, height: 7.8))
                        .applying(CGAffineTransform(rotationAngle: -0.21).concatenating(CGAffineTransform(translationX: c.x, y: c.y)))
                    ctx.fill(eye, with: .color(eyeColour))
                }
                if mouth {
                    let m = Geo.mouth
                    ctx.fill(Path(ellipseIn: CGRect(x: m.x + look - 1.5, y: m.y - 2.1, width: 3, height: 4.2)), with: .color(eyeColour))
                }
            }
        }
    }

    // MARK: Geometry

    /// A leaf: two smooth curves from base to tip, fattest a third of the way along.
    static func leaf(_ base: CGPoint, _ tip: CGPoint, _ w: Double) -> Path {
        let dx = tip.x - base.x, dy = tip.y - base.y, len = max(hypot(dx, dy), 1)
        let nx = -dy / len, ny = dx / len, mx = base.x + dx * 0.38, my = base.y + dy * 0.38
        var p = Path()
        p.move(to: base)
        p.addQuadCurve(to: tip, control: CGPoint(x: mx + nx * w * 1.3, y: my + ny * w * 1.3))
        p.addQuadCurve(to: base, control: CGPoint(x: mx - nx * w * 1.3, y: my - ny * w * 1.3))
        p.closeSubpath()
        return p
    }

    /// The body: two circles joined by their outer tangent lines (so it stays smooth).
    static func tube(_ a: (x: Double, y: Double, r: Double), _ b: (x: Double, y: Double, r: Double)) -> Path {
        let d = max(hypot(b.x - a.x, b.y - a.y), 0.001)
        let ang = atan2(b.y - a.y, b.x - a.x)
        let phi = acos(max(-1, min(1, (a.r - b.r) / d)))
        func on(_ c: (x: Double, y: Double, r: Double), _ t: Double) -> CGPoint { CGPoint(x: c.x + c.r * cos(t), y: c.y + c.r * sin(t)) }
        var p = Path()
        p.move(to: on(a, ang + phi))
        let steps = 24
        // round the far side of b, from ang + phi down to ang - phi
        for i in 0...steps { p.addLine(to: on(b, ang + phi - 2 * phi * Double(i) / Double(steps))) }
        // round the far side of a, from ang - phi down to ang + phi - 2π
        for i in 0...steps { p.addLine(to: on(a, ang - phi - (2 * .pi - 2 * phi) * Double(i) / Double(steps))) }
        p.closeSubpath()
        return p
    }

    // MARK: The card

    struct PeekCard: View {
        let host: PipHost
        let session: Session
        @AppStorage("plug.peek.version") private var version = 2
        @AppStorage("plug.peek.hello") private var helloOn = true

        var body: some View {
            VStack(alignment: .leading, spacing: Corner.inset) {
                SettingsCard(title: "Which Pip", icon: "person.2",
                             footer: "For showing how Pip grew. Nothing is replaced: switch back any time.") {
                    HStack(spacing: PluginBarLook.cardGap) {
                        Button { version = 1 } label: { Text("Version 1 · original").frame(maxWidth: .infinity) }
                            .buttonStyle(PluginCardButton(on: version == 1))
                        Button { version = 2 } label: { Text("Version 2 · Aaron's").frame(maxWidth: .infinity) }
                            .buttonStyle(PluginCardButton(on: version == 2))
                    }
                    HStack(spacing: 16) {
                        PipV2().frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tiny check").font(.caption).foregroundStyle(.secondary)
                            HStack(alignment: .bottom, spacing: 10) {
                                ForEach([16.0, 24.0, 32.0, 48.0], id: \.self) { px in
                                    PipV2(silhouette: true).frame(width: px, height: px)
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Aaron's Pip, large and at 16, 24, 32 and 48 points")
                }
                SettingsCard(title: "Hello when I open the app", icon: "hand.wave",
                             footer: "Pip peeks in from the left edge for a few seconds. Tap them, or just carry on.") {
                    Toggle("Say hello", isOn: $helloOn)
                    Button("Show me now") {
                        host.openCard = nil
                        host.later(0.3) {
                            session.hello = true
                            host.later(Tune.helloFor) { session.hello = false }
                        }
                    }
                    .buttonStyle(PluginCardButton(on: true))
                    .disabled(version != 2 || !host.pipOn)
                }
                if !host.pipOn {
                    Text("Pip is switched off, so nothing peeks.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13.5))
        }
    }
}
