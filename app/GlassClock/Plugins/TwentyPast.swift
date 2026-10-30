import SwiftUI

// TWENTY PAST · plugin v1 (Dream). A secret: at twenty past four (am and pm) Pip goes very, very
// relaxed for a minute. Everything goes soft round the edges, Pip has thoughts, and a biscuit happens.
// Where: nowhere, until it happens. Switched off in Settings > Accessibility > Pip and plugins.
// Works with Pip off too: the thoughts show as a caption instead.
// To see it now: launch with `-plug.twentypast.test YES` and it starts 6 seconds in.

struct TwentyPast: SandboxPlugin {
    let info = PluginInfo(id: "twentypast", name: "Twenty Past", version: "v1", shelf: .dream,
                          icon: "clock", what: "Something happens at twenty past four. No peeking.")

    // MARK: Data

    enum Act { case say(String), drop, eat(String) }

    /// Seconds in, what happens, and whether it still happens at Joy 0 (calm keeps only the first and last).
    struct Beat { let at: Double; let act: Act; var calm = false }

    static let beats: [Beat] = [
        Beat(at: 0, act: .say("Oh. Oh, it's twenty past four."), calm: true),
        Beat(at: 6, act: .say("Is the clock… breathing? Is it meant to do that?")),
        Beat(at: 13, act: .say("Have you ever really looked at glass? Like, really, really looked at it?")),
        Beat(at: 21, act: .say("What if every widget is just a tiny window into a smaller widget.")),
        Beat(at: 29, act: .say("I could absolutely murder a biscuit right now.")),
        Beat(at: 32, act: .drop),
        Beat(at: 35.5, act: .eat("…this is the best day of my life.")),
        Beat(at: 43, act: .say("I'm not saying the background's melting. I'm just saying it's quite melty.")),
        Beat(at: 52, act: .say("Right. Yes. Very productive. As you were."), calm: true),
    ]
    static let length = 58.0
    static let biscuitFall = 3.5
    static let hour = 4, minute = 20

    @MainActor @Observable final class Show {
        var on = false
        var caption: String?
        var started = Date.distantPast
        var biscuitFrom: Date?
        @ObservationIgnored var waiting: Task<Void, Never>?
        @ObservationIgnored var lastSlot: Date?
    }
    private let show = Show()

    // MARK: Logic

    /// The twenty-past-four that's coming up, or the one happening right now.
    static func slot(around now: Date, _ cal: Calendar = .current) -> Date {
        let today = cal.startOfDay(for: now)
        let days = [today, cal.date(byAdding: .day, value: 1, to: today) ?? today]
        let slots = days.flatMap { day in
            [hour, hour + 12].compactMap { cal.date(bySettingHour: $0, minute: minute, second: 0, of: day) }
        }
        return slots.first { $0.addingTimeInterval(60) > now } ?? slots.last ?? now
    }

    func start(_ host: PipHost) throws {
        guard show.waiting == nil else { return }
        let test = UserDefaults.standard.bool(forKey: "plug.twentypast.test")
        show.waiting = Task { @MainActor in
            if test {
                try? await Task.sleep(for: .seconds(6))
                await play(host)
            }
            // Ends itself when Twenty Past is switched off; switching it on calls `start` again.
            while !Task.isCancelled, host.isOn(info.id) {
                let slot = Self.slot(around: .now)
                let wait = slot.timeIntervalSinceNow
                // Checks in once a minute at most, so a sleeping iPad or a changed clock can't make it miss.
                if wait > 0 { try? await Task.sleep(for: .seconds(min(wait, 60))); continue }
                if show.lastSlot != slot {
                    show.lastSlot = slot
                    await play(host)
                }
                try? await Task.sleep(for: .seconds(61))
            }
            show.waiting = nil
        }
    }

    private func play(_ host: PipHost) async {
        guard host.isOn(info.id), !show.on else { return }
        host.wake()
        show.started = .now
        withAnimation(.easeInOut(duration: host.simpler ? 1 : 3)) { show.on = true }
        var t = 0.0
        for beat in Self.beats where host.joy > 0 || beat.calm {
            try? await Task.sleep(for: .seconds(beat.at - t))
            t = beat.at
            guard host.isOn(info.id) else { break }
            switch beat.act {
            case .say(let line): say(line, host)
            case .drop: show.biscuitFrom = .now
            case .eat(let line):
                show.biscuitFrom = nil
                host.cheer()
                say(line, host)
            }
        }
        try? await Task.sleep(for: .seconds(max(0, Self.length - t)))
        withAnimation(.easeInOut(duration: host.simpler ? 1 : 3)) {
            show.on = false
            show.caption = nil
            show.biscuitFrom = nil
        }
    }

    /// Pip says it; with Pip off or away, it shows as a caption (and VoiceOver reads it).
    private func say(_ line: String, _ host: PipHost) {
        if host.say(line, for: 5.5) {
            show.caption = nil
        } else {
            withAnimation(.easeInOut(duration: 0.4)) { show.caption = line }
            UIAccessibility.post(notification: .announcement, argument: line)
        }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Haze(show: show, host: host) }

    /// Soft drifting colour over everything, the biscuit, and the caption. Draws nothing the rest of the day.
    struct Haze: View {
        let show: Show
        let host: PipHost

        var body: some View {
            GeometryReader { geo in
                if show.on {
                    ZStack {
                        TimelineView(.animation(minimumInterval: 1 / 30, paused: host.simpler)) { tl in
                            let t = tl.date.timeIntervalSince(show.started)
                            ZStack {
                                blob(.green, t: t, phase: 0, in: geo.size)
                                blob(PipLook.accent, t: t, phase: 2.1, in: geo.size)
                                blob(.purple, t: t, phase: 4.2, in: geo.size)
                                if let from = show.biscuitFrom {
                                    biscuit(tl.date.timeIntervalSince(from), in: geo.size)
                                }
                            }
                        }
                        if let caption = show.caption {
                            Text(caption)
                                .font(.system(size: 15, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 10).padding(.horizontal, 16)
                                .glassEffect(.regular, in: .capsule)
                                .frame(maxWidth: 420)
                                .position(x: geo.size.width / 2, y: 72)
                                .id(caption)
                                .transition(.opacity)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }

        private func blob(_ colour: Color, t: Double, phase: Double, in size: CGSize) -> some View {
            let d = max(size.width, size.height) * 0.6
            return Circle()
                .fill(colour.opacity(0.2))
                .frame(width: d, height: d)
                .blur(radius: 90)
                .position(x: size.width * (0.5 + 0.32 * sin(t * 0.13 + phase)),
                          y: size.height * (0.5 + 0.3 * cos(t * 0.11 + phase * 1.3)))
        }

        /// Falls from the top onto Pip (or the middle, with Pip off), rocking like a leaf. Fades in under simpler motion.
        private func biscuit(_ t: Double, in size: CGSize) -> some View {
            let to = host.pipHere ? CGPoint(x: host.pipPosition.x, y: host.pipPosition.y - 26)
                                  : CGPoint(x: size.width / 2, y: size.height / 2)
            let u = min(1, t / TwentyPast.biscuitFall)
            let eased = 1 - pow(1 - u, 2)
            let x = to.x + (host.simpler ? 0 : sin(t * 2.4) * 40 * (1 - u))
            let y = host.simpler ? to.y : -40 + (to.y + 40) * eased
            return Text("🍪")
                .font(.system(size: 34))
                .rotationEffect(.degrees(host.simpler ? 0 : sin(t * 2.4) * 25 * (1 - u)))
                .opacity(host.simpler ? min(1, t / 0.6) : 1)
                .position(x: x, y: y)
        }
    }
}
