import SwiftUI

// GUEST TAKEOVER · plugin v1 (Dream). Now and then a made-up guest barges in and does Pip's job for a bit:
// Tack, an over-eager drawing pin, or Fuse, a dramatic tiny lamp. Pip watches from the side, then takes
// the job back. Guests only talk for now: plugins can't change the background yet (asked of the core).
// Where: the person-with-a-plus button in the plugin bar. Off until you switch it on; rare at Joy 1.

struct GuestTakeover: SandboxPlugin {
    let info = PluginInfo(id: "guests", name: "Guest Takeover", version: "v1", shelf: .dream,
                          icon: "person.badge.plus", what: "Now and then a guest barges in and does Pip's job.")

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        static let tick = 60.0              // seconds between checks
        static let firstVisit = 4.0         // minutes after launch before anyone may drop by
        static let lineGap = 2.8            // seconds between a guest's lines
        static let inset = 140.0            // guests stay this far inside the screen
        static let side = 96.0              // how far beside Pip a guest stands
        static let dim = 0.14               // how dark Fuse makes the room
        /// Minutes between visits at most, by Joy level (0: never drops by on their own).
        static func gap(joy: Int) -> Double { [Double.infinity, 45, 30, 20, 12, 6][min(max(joy, 0), 5)] }
        /// Chance a visit happens on a check once the gap has passed.
        static func chance(joy: Int) -> Double { [0, 0.25, 0.35, 0.5, 0.65, 0.8][min(max(joy, 0), 5)] }
    }

    // MARK: Data

    enum Guest: CaseIterable {
        case tack, fuse
        var name: String { self == .tack ? "Tack" : "Fuse" }
        var symbol: String { self == .tack ? "pin.fill" : "lightbulb.fill" }
        var lines: [String] {
            switch self {
            case .tack: ["Hi! I'm Tack! I'm helping!",
                         "Ooh, I like THIS background.",
                         "And this one. No, this one!",
                         "Have you thought about… more pins?",
                         "Right! Busy busy. Bye!"]
            case .fuse: ["Lights… lower… please.",
                         "This colour. It's breathtaking.",
                         "I simply cannot go on. It's too beautiful.",
                         "Goodnight, everyone."]
            }
        }
        var label: String { self == .tack ? "Tack, a drawing pin" : "Fuse, a tiny lamp" }
    }

    enum Lines {
        static let pipSees = ["Excuse me?", "Er… that's my job.", "Oh, here we go."]
        static func pipBack(_ guest: Guest) -> String { "Thank you, \(guest.name). I'll take it from here." }
    }

    @MainActor @Observable final class Visit {
        var guest: Guest?
        var line = ""
        var at = CGPoint.zero
        var dim = false
        @ObservationIgnored var last = Date.now
        @ObservationIgnored var bounds = CGSize(width: 1180, height: 820)   // the overlay's size, kept by GuestView
        @ObservationIgnored var loop: Task<Void, Never>?
    }
    private let visit = Visit()

    // MARK: Logic

    private func invited(_ host: PipHost) -> Bool {
        let on: Bool = host.value("guests", "on") ?? false
        return on && host.isOn("guests") && host.pipHere && !host.pipAsleep
    }

    func start(_ host: PipHost) throws {
        visit.last = .now.addingTimeInterval(-60 * (Tune.gap(joy: 1) - Tune.firstVisit))
        wake(host)
    }

    /// Runs the 60-second check only while Guest Takeover is on and "Guests may drop by" is on; it ends itself
    /// when either goes off. Switching the plugin on calls `start`, and the card's switch calls this again.
    fileprivate func wake(_ host: PipHost) {
        guard visit.loop == nil, running(host) else { return }
        visit.loop = Task { @MainActor in
            while !Task.isCancelled, running(host) {
                try? await Task.sleep(for: .seconds(Tune.tick))
                tick(host)
            }
            visit.loop = nil
        }
    }

    private func running(_ host: PipHost) -> Bool {
        host.isOn("guests") && ((host.value("guests", "on") as Bool?) ?? false)
    }

    private func tick(_ host: PipHost) {
        guard invited(host), visit.guest == nil else { return }
        let joy = host.joy
        guard Date.now.timeIntervalSince(visit.last) >= Tune.gap(joy: joy) * 60,
              Double.random(in: 0..<1) < Tune.chance(joy: joy),
              PipTalkTurns.floorFree(host) else { return }
        barge(host, Guest.allCases.randomElement()!)
    }

    /// A guest arrives beside Pip, says their lines, and leaves. Pip gets the last word.
    func barge(_ host: PipHost, _ guest: Guest) {
        guard host.pipHere, visit.guest == nil else { return }
        visit.last = .now
        // Hold the floor for the whole visit, including Pip's last word.
        PipTalkTurns.takeFloor(host, for: Tune.lineGap * Double(guest.lines.count) + 3)
        let pip = host.pipPosition
        let bounds = visit.bounds
        let left = pip.x > bounds.width / 2
        visit.at = CGPoint(x: min(max(pip.x + (left ? -Tune.side : Tune.side), Tune.inset), bounds.width - Tune.inset),
                           y: min(max(pip.y, Tune.inset), bounds.height - Tune.inset))
        withAnimation(host.simpler ? .easeInOut(duration: 0.5) : .spring(duration: 0.6, bounce: 0.35)) {
            visit.guest = guest
            visit.line = guest.lines[0]
            visit.dim = guest == .fuse
        }
        host.react(.surprised, for: 1.4)
        host.later(1.6) { host.say(Lines.pipSees.randomElement()!, for: 1.8) }
        for (i, line) in guest.lines.enumerated().dropFirst() {
            host.later(Tune.lineGap * Double(i)) {
                guard visit.guest == guest else { return }
                withAnimation(.easeInOut(duration: 0.3)) { visit.line = line }
            }
        }
        host.later(Tune.lineGap * Double(guest.lines.count)) { leave(host, guest) }
    }

    private func leave(_ host: PipHost, _ guest: Guest) {
        guard visit.guest == guest else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            visit.guest = nil
            visit.line = ""
            visit.dim = false        // the room always comes back as it was
        }
        host.later(0.6) {
            host.say(Lines.pipBack(guest), for: 2.4)
            host.cheer()
        }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { GuestView(visit: visit, host: host) }

    struct GuestView: View {
        let visit: Visit
        let host: PipHost
        @State private var wobble = false

        var body: some View {
            ZStack(alignment: .topLeading) {
                // Fuse's wonder: the room dims a touch while they're on stage.
                Color.black.opacity(visit.dim && host.pipHere ? Tune.dim : 0)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.2), value: visit.dim)
                if let guest = visit.guest, host.pipHere {
                    VStack(spacing: 6) {
                        Text(visit.line)
                            .font(.system(size: 13.5))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .glassEffect(.regular, in: Capsule())
                            .fixedSize()
                        Image(systemName: guest.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(PipLook.glow)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.tint(PipLook.accent.opacity(0.1)), in: Circle())
                            // Tack's wonder: a little boing on arrival (none under simpler motion).
                            .rotationEffect(.degrees(guest == .tack && wobble && !host.simpler ? 10 : 0))
                            .animation(guest == .tack ? .spring(duration: 0.5, bounce: 0.6).repeatCount(3, autoreverses: true) : .default,
                                       value: wobble)
                    }
                    .position(visit.at)
                    .transition(host.simpler ? .opacity : .opacity.combined(with: .scale(scale: 0.6)))
                    .onAppear { wobble = true }
                    .onDisappear { wobble = false }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(guest.label), says: \(visit.line)")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { GeometryReader { geo in Color.clear.onAppear { visit.bounds = geo.size }
                .onChange(of: geo.size) { _, size in visit.bounds = size } } }
            .allowsHitTesting(false)
        }
    }

    func card(_ host: PipHost) -> some View { GuestCard(plugin: self, host: host) }

    struct GuestCard: View {
        let plugin: GuestTakeover
        let host: PipHost
        @AppStorage("plug.guests.on") private var on = false

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Toggle("Guests may drop by", isOn: $on)
                    .font(.system(size: 13.5))
                    .accessibilityLabel("Let guests drop by now and then")
                    .onChange(of: on) { if on { plugin.wake(host) } }
                HStack(spacing: PluginBarLook.cardGap) {
                    ForEach(Guest.allCases, id: \.self) { guest in
                        Button("Invite \(guest.name)") {
                            host.openCard = nil
                            host.later(1) { plugin.barge(host, guest) }
                        }
                        .buttonStyle(PluginCardButton())
                        .disabled(!host.pipHere)
                        .accessibilityLabel("Invite \(guest.label) now")
                    }
                }
                Text("Tack is an over-eager drawing pin. Fuse is a dramatic tiny lamp. They visit rarely at Joy 1, never at Joy 0, and Pip always takes the job back.")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
            }
        }
    }
}
