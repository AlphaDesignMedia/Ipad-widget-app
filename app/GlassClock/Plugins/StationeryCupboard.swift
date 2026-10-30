import SwiftUI

// THE STATIONERY CUPBOARD · plugin v1 (Dream). Pip's got themselves locked in the stationery cupboard and is
// tapping at the glass. Three little locks, no timer: find the light switch (a dot in the card's title bar),
// lift the mug off the shelf to find the key, then draw the key: a loop round the keyhole, with Pencil or finger.
// The door swings open and warm light spills out. Tap Pip in the cupboard for one gentle clue per lock.
// Progress is kept on the device. Pip off: the same quiet puzzle box, with a paper star and a note inside.
// Pip asks "Fancy getting me out?" 3 times a session at most, then stops. No network.
// Where: the cabinet button in the plugin bar (opens as a panel).

struct StationeryCupboard: SandboxPlugin {
    let info = PluginInfo(id: "cupboard", name: "The Stationery Cupboard", version: "v1", shelf: .dream,
                          icon: "cabinet",
                          what: "Pip's locked in the cupboard. Three little locks to let them out.",
                          panel: true)

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        static let maxAsks = 3                  // "Fancy getting me out?", per session, then Pip stops asking
        static let askDelay = 0.5               // seconds after the panel opens before Pip asks
        static let mugMove: CGFloat = 34        // points the mug must travel to count as off the shelf
        static let loopTurns = 0.75             // how far round the keyhole a stroke must go (1 = all the way)
        static let innerRadius: CGFloat = 4     // points of a stroke nearer the keyhole than this don't count
        static let outerRadius: CGFloat = 72    // nor further than this
        static let tapAfter = 3                 // tries before a plain tap on the keyhole works too
        static let tapSlop: CGFloat = 10        // a stroke shorter than this is a tap
        static let maxInk = 600                 // points kept in one stroke
        static let doorSeconds = 1.3            // the door swinging open
        static let fadeSeconds = 0.6            // lights, mug and fades
        static let warmth = 0.55                // how bright the light that spills out is
        /// Seconds between Pip's taps at the glass, by Joy level (0: still, no taps).
        static func tapGap(joy: Int) -> Double { [0, 6, 4.5, 3.5, 2.6, 1.8][min(max(joy, 0), 5)] }
        /// Points the door rattles when Pip taps, by Joy level (0 and 1: no rattle).
        static func rattle(joy: Int) -> CGFloat { [0, 0, 1, 1.8, 2.6, 3.6][min(max(joy, 0), 5)] }
    }

    // MARK: Data

    enum Lines {
        static let ask = ["Fancy getting me out?", "Still in here. Fancy getting me out?", "Fancy getting me out? No rush."]
        /// One gentle clue per lock, in Pip's voice.
        static let clue = ["It's ever so dark in here. Is there a switch up top?",
                           "I always leave the key under something. Something you drink from.",
                           "No key? Draw one. Go round and round the keyhole."]
        /// The same clues, plainly, for when Pip's off.
        static let plainClue = ["Dark? Look for a little switch up in the title bar.",
                                "Keys hide under things. Try lifting the mug.",
                                "Draw a loop round the keyhole, with a finger or Pencil."]
        static let lit = "Ooh. Light."
        static let found = "That's the shape of it."
        static let free = "Ta. Knew you would."
        static let tapToo = "Or just tap the keyhole."
        static let note = "Nice work."
    }

    /// Where things sit in the little cupboard picture, in its own points.
    enum Spot {
        static let size = CGSize(width: 240, height: 222)
        static let shelf = CGRect(x: 24, y: 40, width: 192, height: 4)
        static let mug = CGPoint(x: 78, y: 26)
        static let mugMoved = CGPoint(x: 194, y: 26)
        static let key = CGPoint(x: 78, y: 31)
        static let body = CGRect(x: 30, y: 54, width: 180, height: 160)
        static let door = CGRect(x: 40, y: 64, width: 160, height: 140)
        static let pip = CGPoint(x: 96, y: 134)
        static let keyhole = CGPoint(x: 180, y: 134)
        static let star = CGPoint(x: 120, y: 124)
        static let space = "cupboard"
    }

    // Saved on the device: plug.cupboard.stage (0 dark, 1 lit, 2 key found, 3 out) and plug.cupboard.tries.

    // MARK: Logic

    /// This session's state. The plugin is a struct made once, so this lives in a class. Stage and tries are saved.
    @MainActor @Observable final class Session {
        var stage = UserDefaults.standard.integer(forKey: "plug.cupboard.stage")
        var tries = UserDefaults.standard.integer(forKey: "plug.cupboard.tries")
        var ink: [CGPoint] = []
        var mugDrag = CGSize.zero
        var taps = 0
        var rattles = 0
        var note: String? = nil
        @ObservationIgnored var asks = 0
        @ObservationIgnored var loop: Task<Void, Never>?
    }
    private let session = Session()

    /// How far round a point a stroke went, in turns (1 = all the way round). Points too near or too far don't count.
    static func turns(_ points: [CGPoint], around c: CGPoint) -> Double {
        var total = 0.0
        var last: Double?
        for p in points {
            let dx = Double(p.x - c.x)
            let dy = Double(p.y - c.y)
            let r = CGFloat((dx * dx + dy * dy).squareRoot())
            guard r >= Tune.innerRadius, r <= Tune.outerRadius else { last = nil; continue }
            let a = atan2(dy, dx)
            if let l = last {
                var d = a - l
                if d > .pi { d -= 2 * .pi } else if d < -.pi { d += 2 * .pi }
                total += d
            }
            last = a
        }
        return abs(total) / (2 * .pi)
    }

    /// How long a stroke is, in points.
    static func length(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { sum, pair in
            let dx = pair.1.x - pair.0.x
            let dy = pair.1.y - pair.0.y
            return sum + (dx * dx + dy * dy).squareRoot()
        }
    }

    private func save(stage: Int, _ host: PipHost) {
        session.stage = stage
        host.setValue(stage, "cupboard", "stage")
    }

    private func save(tries: Int, _ host: PipHost) {
        session.tries = tries
        host.setValue(tries, "cupboard", "tries")
    }

    /// Pip says a line and holds the floor while they do. False when Pip's off or not on screen.
    @discardableResult private func speak(_ line: String, _ host: PipHost, for seconds: Double = 2.6) -> Bool {
        guard host.say(line, for: seconds) else { return false }
        PipTalkTurns.takeFloor(host, for: seconds)
        return true
    }

    /// Panel opened: while Pip's still in, they may ask (3 times a session at most, only when the floor's free).
    func opened(_ host: PipHost) {
        session.note = nil
        startTapping(host)
        guard session.stage < 3, session.asks < Tune.maxAsks, host.pipHere, PipTalkTurns.floorFree(host) else { return }
        host.later(Tune.askDelay) {
            guard session.stage < 3, session.asks < Tune.maxAsks, PipTalkTurns.floorFree(host) else { return }
            if speak(Lines.ask[min(session.asks, Lines.ask.count - 1)], host) { session.asks += 1 }
        }
    }

    func closed() {
        session.loop?.cancel()
        session.loop = nil
    }

    /// Pip taps at the glass now and then (never at Joy 0). Only while the panel's open and Pip's still in.
    private func startTapping(_ host: PipHost) {
        guard session.loop == nil else { return }
        session.loop = Task { @MainActor in
            while !Task.isCancelled {
                let gap = Tune.tapGap(joy: host.joy)
                try? await Task.sleep(for: .seconds(gap > 0 ? gap : 5))
                guard !Task.isCancelled, gap > 0, session.stage < 3, host.pipHere else { continue }
                session.taps += 1
                if !host.simpler, Tune.rattle(joy: host.joy) > 0 { session.rattles += 1 }
            }
        }
    }

    /// Lock 1: the light switch.
    func lights(_ host: PipHost) {
        guard session.stage == 0 else { return }
        withAnimation(.easeInOut(duration: Tune.fadeSeconds)) { save(stage: 1, host) }
        speak(Lines.lit, host, for: 1.8)
    }

    /// Lock 2: the mug, while it's being dragged and when it's let go.
    func dragMug(_ by: CGSize) {
        guard session.stage == 1 else { return }
        session.mugDrag = by
    }

    func dropMug(_ by: CGSize, _ host: PipHost) {
        guard session.stage == 1 else { return }
        let far = (by.width * by.width + by.height * by.height).squareRoot() >= Tune.mugMove
        withAnimation(host.simpler ? Animation.easeInOut(duration: Tune.fadeSeconds) : Animation.spring(duration: 0.4)) {
            session.mugDrag = .zero
            if far { save(stage: 2, host) }
        }
        if far { speak(Lines.found, host, for: 2) }
    }

    /// For VoiceOver and anyone who'd rather not drag: lift the mug in one go.
    func liftMug(_ host: PipHost) {
        guard session.stage == 1 else { return }
        dropMug(CGSize(width: Tune.mugMove, height: 0), host)
    }

    /// Lock 3: drawing the key, a point at a time.
    func ink(_ point: CGPoint) {
        guard session.stage == 2, session.ink.count < Tune.maxInk else { return }
        session.ink.append(point)
    }

    func lift(_ host: PipHost) {
        guard session.stage == 2 else { session.ink = []; return }
        let points = session.ink
        let length = Self.length(points)
        let tap = length < Tune.tapSlop
        if Self.turns(points, around: Spot.keyhole) >= Tune.loopTurns || (tap && session.tries >= Tune.tapAfter) {
            escape(host)
        } else if !tap {
            save(tries: session.tries + 1, host)
        }
        withAnimation(.easeOut(duration: 0.4)) { session.ink = [] }
    }

    /// The wonder: the door swings open (fades under simpler motion) and warm light spills out.
    func escape(_ host: PipHost) {
        guard session.stage < 3 else { return }
        session.ink = []
        withAnimation(Animation.easeInOut(duration: host.simpler ? Tune.fadeSeconds : Tune.doorSeconds)) {
            save(stage: 3, host)
        }
        host.later(Tune.doorSeconds * 0.6) {
            if speak(Lines.free, host, for: 3) { host.cheer() }
        }
    }

    /// "Lock me in again": back to the dark, tries forgotten.
    func reset(_ host: PipHost) {
        withAnimation(.easeInOut(duration: Tune.fadeSeconds)) {
            save(stage: 0, host)
            save(tries: 0, host)
            session.ink = []
            session.mugDrag = .zero
            session.note = nil
        }
    }

    /// One gentle clue for the lock you're on: Pip says it, or it shows plainly in the panel when Pip's off.
    func clue(_ host: PipHost) {
        let i = min(max(session.stage, 0), 2)
        if speak(Lines.clue[i], host, for: 3.4) {
            host.react(.curious, for: 1.4)
        } else {
            withAnimation(.easeInOut(duration: Tune.fadeSeconds)) { session.note = Lines.plainClue[i] }
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View {
        CupboardPanel(plugin: self, session: session, host: host)
            .onAppear { opened(host) }
            .onDisappear { closed() }
    }

    struct CupboardPanel: View {
        let plugin: StationeryCupboard
        let session: Session
        let host: PipHost

        private var status: String {
            switch session.stage {
            case 0: return "It's dark in there."
            case 1: return "One lock open. Two to go."
            case 2: return session.tries >= Tune.tapAfter ? "One lock left. \(Lines.tapToo)" : "One lock left."
            default: return host.pipHere ? "Pip's out." : "All three locks open."
            }
        }

        var body: some View {
            VStack(spacing: Corner.inset) {
                SettingsCard(title: "The cupboard", icon: "cabinet",
                             footer: "No timer. Your progress is kept on this iPad.") {
                    Box(plugin: plugin, session: session, host: host)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status)
                        if let note = session.note {
                            Text(note).foregroundStyle(.secondary).transition(.opacity)
                        }
                    }
                    .font(.system(size: 13.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    if !host.pipHere, session.stage < 3 {
                        Button("A clue") { plugin.clue(host) }
                            .buttonStyle(PluginCardButton())
                            .accessibilityLabel("Show a clue for this lock")
                    }
                    if session.stage >= 3 {
                        Button(host.pipHere ? "Lock me in again" : "Shut the cupboard again") { plugin.reset(host) }
                            .buttonStyle(PluginCardButton())
                            .accessibilityLabel(host.pipHere ? "Lock Pip in the cupboard again" : "Shut the cupboard and start again")
                    }
                }
                // Lock 1: the light switch, a little dot in the card's own title bar.
                .overlay(alignment: .topTrailing) {
                    LightSwitch(on: session.stage >= 1) { plugin.lights(host) }
                        .padding(.trailing, Corner.cardPadding - 12)
                        .padding(.top, 4)
                }
            }
        }
    }

    /// A small dot with a finger-sized tap area around it.
    struct LightSwitch: View {
        let on: Bool
        let flip: @MainActor () -> Void

        var body: some View {
            Button(action: flip) {
                Circle()
                    .fill(on ? AnyShapeStyle(PipLook.glow) : AnyShapeStyle(.secondary))
                    .frame(width: 9, height: 9)
                    .shadow(color: on ? PipLook.glow : .clear, radius: 4)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cupboard light switch")
            .accessibilityValue(on ? "On" : "Off")
            .accessibilityHint(on ? "" : "Turns the cupboard light on")
        }
    }

    /// The little cupboard: a shelf with a mug on top, a glass door with a keyhole, and Pip inside.
    struct Box: View {
        let plugin: StationeryCupboard
        let session: Session
        let host: PipHost

        var body: some View {
            let lit = session.stage >= 1
            let open = session.stage >= 3
            let simpler = host.simpler
            let amp = Double(Tune.rattle(joy: host.joy))
            let r = max(4, Corner.card - Corner.cardPadding)
            ZStack(alignment: .topLeading) {
                // The warm light, spilling out past the cupboard once the door's open.
                RadialGradient(colors: [Color.orange.opacity(Tune.warmth), Color.yellow.opacity(Tune.warmth * 0.4), .clear],
                               center: .center, startRadius: 0, endRadius: Spot.body.width * 0.85)
                    .frame(width: Spot.body.width * 1.7, height: Spot.body.height * 1.5)
                    .position(x: Spot.body.midX, y: Spot.body.midY)
                    .opacity(open ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                // The cupboard's body and its dark inside.
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(.secondary.opacity(0.22))
                    .frame(width: Spot.body.width, height: Spot.body.height)
                    .position(x: Spot.body.midX, y: Spot.body.midY)
                RoundedRectangle(cornerRadius: max(3, r - 4), style: .continuous)
                    .fill(open ? AnyShapeStyle(Color.orange.opacity(Tune.warmth * 0.5)) : AnyShapeStyle(Color.black.opacity(0.35)))
                    .frame(width: Spot.door.width, height: Spot.door.height)
                    .position(x: Spot.door.midX, y: Spot.door.midY)
                    .accessibilityHidden(true)
                // Pip off: what's inside is a tea-stained paper star and a note.
                if open, !host.pipHere {
                    PaperStar()
                        .position(Spot.star)
                        .transition(.opacity)
                }
                // The shelf, the key under the mug, and the mug.
                Capsule()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: Spot.shelf.width, height: Spot.shelf.height)
                    .position(x: Spot.shelf.midX, y: Spot.shelf.midY)
                    .accessibilityHidden(true)
                Image(systemName: "key.horizontal")
                    .font(.system(size: 12))
                    .foregroundStyle(PipLook.glow)
                    .position(Spot.key)
                    .opacity(session.stage >= 2 ? 1 : 0)
                    .accessibilityLabel("A key, drawn on the shelf")
                    .accessibilityHidden(session.stage < 2)
                Mug(plugin: plugin, session: session, host: host)
                // The glass door, with its keyhole. It swings open on its hinge (fades under simpler motion).
                Door(locked: session.stage < 3, ready: session.stage == 2, radius: max(3, r - 4))
                    .keyframeAnimator(initialValue: 0.0, trigger: session.rattles) { view, x in
                        view.offset(x: x)
                    } keyframes: { _ in
                        LinearKeyframe(amp, duration: 0.05)
                        LinearKeyframe(-amp, duration: 0.07)
                        LinearKeyframe(amp * 0.6, duration: 0.07)
                        LinearKeyframe(0, duration: 0.06)
                    }
                    .rotation3DEffect(.degrees(open && !simpler ? -108 : 0), axis: (x: 0, y: 1, z: 0),
                                      anchor: .leading, perspective: 0.5)
                    .opacity(open ? (simpler ? 0 : 0.5) : 1)
                    .position(x: Spot.door.midX, y: Spot.door.midY)
                // The dark, until the light's on. Pip glows through it.
                Rectangle()
                    .fill(.black.opacity(lit ? 0 : 0.78))
                    .frame(width: Spot.size.width, height: Spot.size.height)
                    .position(x: Spot.size.width / 2, y: Spot.size.height / 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                // Lock 3: where the key gets drawn, and the ink as it goes.
                if session.stage == 2 {
                    DrawZone(plugin: plugin, session: session, host: host)
                }
                if !session.ink.isEmpty {
                    Path { p in p.addLines(session.ink) }
                        .stroke(PipLook.glow, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                // Pip, locked in, tapping at the glass. Gone once they're out.
                if host.pipHere, !open {
                    LockedPip(plugin: plugin, session: session, host: host, lit: lit)
                        .position(Spot.pip)
                        .transition(.opacity)
                }
            }
            .frame(width: Spot.size.width, height: Spot.size.height)
            .coordinateSpace(.named(Spot.space))
        }
    }

    struct Door: View {
        let locked: Bool
        let ready: Bool
        let radius: CGFloat

        var body: some View {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1))
                // A soft streak of reflection, so it reads as glass.
                .overlay(alignment: .topLeading) {
                    Capsule().fill(.white.opacity(0.18)).frame(width: 3, height: 46)
                        .rotationEffect(.degrees(18)).offset(x: 22, y: 12)
                }
                .overlay(alignment: .topLeading) {
                    Keyhole(glow: ready)
                        .position(x: Spot.keyhole.x - Spot.door.minX, y: Spot.keyhole.y - Spot.door.minY)
                }
                .frame(width: Spot.door.width, height: Spot.door.height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(locked ? "Cupboard door, locked" : "Cupboard door, open")
        }
    }

    struct Keyhole: View {
        let glow: Bool

        var body: some View {
            VStack(spacing: -1) {
                Circle().frame(width: 7, height: 7)
                UnevenRoundedRectangle(topLeadingRadius: 0.5, bottomLeadingRadius: 1.5,
                                       bottomTrailingRadius: 1.5, topTrailingRadius: 0.5)
                    .frame(width: 4, height: 8)
            }
            .foregroundStyle(PipLook.eye.opacity(0.85))
            .shadow(color: glow ? PipLook.glow : .clear, radius: 5)
        }
    }

    /// Lock 2: drag the mug off the shelf. VoiceOver: one action lifts it.
    struct Mug: View {
        let plugin: StationeryCupboard
        let session: Session
        let host: PipHost

        var body: some View {
            let moved = session.stage >= 2
            let base = moved ? Spot.mugMoved : Spot.mug
            Image(systemName: "mug.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
                .position(x: base.x + session.mugDrag.width, y: base.y + session.mugDrag.height)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named(Spot.space))
                        .onChanged { v in plugin.dragMug(v.translation) }
                        .onEnded { v in plugin.dropMug(v.translation, host) },
                    including: session.stage == 1 ? .all : .subviews)
                .accessibilityLabel(moved ? "Mug, moved off the shelf" : "Mug on the shelf")
                .accessibilityHint(session.stage == 1 ? "Drag it off the shelf to look underneath" : "")
                .accessibilityAction(named: "Lift the mug") { plugin.liftMug(host) }
                .accessibilityHidden(session.stage == 0)
        }
    }

    /// Lock 3: a ring of space round the keyhole that takes a finger or Pencil. VoiceOver: one action unlocks.
    struct DrawZone: View {
        let plugin: StationeryCupboard
        let session: Session
        let host: PipHost

        var body: some View {
            let d = Tune.outerRadius * 1.3
            Circle()
                .fill(.clear)
                .frame(width: d, height: d)
                .contentShape(Circle())
                .position(Spot.keyhole)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Spot.space))
                        .onChanged { v in plugin.ink(v.location) }
                        .onEnded { _ in plugin.lift(host) })
                .accessibilityElement()
                .accessibilityLabel("Keyhole")
                .accessibilityHint("Draw a loop round it with a finger or Pencil to draw the key")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { plugin.escape(host) }
        }
    }

    /// Pip, behind the glass. Taps for a clue. At Joy 1 and up they tap at the glass now and then
    /// (a soft pulse of glow under simpler motion); at Joy 0 they keep still.
    struct LockedPip: View {
        let plugin: StationeryCupboard
        let session: Session
        let host: PipHost
        let lit: Bool

        var body: some View {
            let simpler = host.simpler
            Button { plugin.clue(host) } label: {
                PipBody(face: lit ? .curious : .awake, size: 20)
                    .opacity(lit ? 1 : 0.85)
                    .keyframeAnimator(initialValue: 0.0, trigger: session.taps) { view, t in
                        view.offset(x: simpler ? 0 : t * 4).opacity(simpler ? 1 - t * 0.35 : 1)
                    } keyframes: { _ in
                        LinearKeyframe(1, duration: 0.08)
                        LinearKeyframe(0, duration: 0.1)
                        LinearKeyframe(1, duration: 0.08)
                        LinearKeyframe(0, duration: 0.1)
                        LinearKeyframe(1, duration: 0.08)
                        LinearKeyframe(0, duration: 0.14)
                    }
                    .frame(width: 48, height: 48)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pip, locked in the cupboard")
            .accessibilityHint("Gives a clue for this lock")
        }
    }

    /// Pip off: a little paper star with a ring of tea on it, and a note.
    struct PaperStar: View {
        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(white: 0.95))
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .overlay(alignment: .bottomTrailing) {
                        Circle().strokeBorder(Color.brown.opacity(0.35), lineWidth: 2)
                            .frame(width: 16, height: 16).offset(x: -2, y: -4)
                    }
                Text(Lines.note)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("A tea-stained paper star, with a note: \(Lines.note)")
        }
    }
}
