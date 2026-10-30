import SwiftUI
import CoreMotion
import AVFoundation
import UIKit

// NATIVE WONDERS · plugin v1 (Dream). Things the iPad can do now the sandbox is a native app, which the web
// couldn't. One big wow, Liquid Time: the clock's digits fill with water that sloshes as you tilt the iPad,
// with Pip floating on top. Plus little wonders: Pip in 3D (a detail dial from flat to full), Pip watching a
// hovering Pencil, the Speaking Clock and its six pips, Pip feeling the battery, and a Pip postcard to send.
// Each has a "How it works" note naming the Apple framework, so it doubles as a lesson.
// Where: the sparkles button in the plugin bar. Each wonder opens full screen, with a close button.
// Colours: only PipLook's. Full-screen backdrops are a proposed look (see AGENT-NOTES.md).

struct NativeWonders: SandboxPlugin {
    let info = PluginInfo(id: "wonders", name: "Native Wonders", version: "v1", shelf: .dream,
                          icon: "sparkles", what: "What the iPad can do natively. Start with Liquid Time and tilt.")

    func card(_ host: PipHost) -> some View { NWCard(host: host) }
}

// MARK: Data

enum NWWonder: String, CaseIterable, Identifiable {
    case liquidTime, pipIn3D, pencil, speakingClock, battery, postcard

    var id: String { rawValue }

    var name: String {
        switch self {
        case .liquidTime: "Liquid Time"
        case .pipIn3D: "Pip in 3D"
        case .pencil: "Pip Sees Your Pencil"
        case .speakingClock: "The Speaking Clock"
        case .battery: "Pip Feels the Battery"
        case .postcard: "Pip Postcard"
        }
    }
    var icon: String {
        switch self {
        case .liquidTime: "drop.fill"
        case .pipIn3D: "cube.transparent"
        case .pencil: "pencil.tip"
        case .speakingClock: "speaker.wave.2.fill"
        case .battery: "battery.75percent"
        case .postcard: "envelope.fill"
        }
    }
    var what: String {
        switch self {
        case .liquidTime: "The clock fills with water. Tilt the iPad and it sloshes. Pip floats."
        case .pipIn3D: "Pip turns to look at your finger. A dial goes from flat to full 3D."
        case .pencil: "Hover your Pencil and Pip follows it. Squeeze to make Pip jump."
        case .speakingClock: "Pip reads the time out loud, then the six pips."
        case .battery: "Pip floats on your charge and has opinions about it."
        case .postcard: "The clock and a Pip quote as a picture to send."
        }
    }
    /// The lesson: which native framework does it, in plain words.
    var howItWorks: String {
        switch self {
        case .liquidTime: "CoreMotion reads gravity 60 times a second. A soft spring makes the water lag and overshoot, and Canvas draws it each frame, bright inside the digits (the time is a mask) and faint everywhere else. Browsers block motion; native apps don't."
        case .pipIn3D: "Layers at different depths slide by different amounts (parallax), and rotation3DEffect turns Pip. A slow spring makes the turn feel alive. It's the video-game trick: the cheapest thing that reads as 3D."
        case .pencil: "onContinuousHover tracks a Pencil hovering above the screen; onPencilSqueeze hears a squeeze on Pencil Pro."
        case .speakingClock: "AVSpeechSynthesizer speaks in a British voice. AVAudioEngine makes the pips from a pure sine wave, so there are no sound files."
        case .battery: "UIDevice reports the battery level and charging state. On-device, no permission needed."
        case .postcard: "ImageRenderer turns any SwiftUI view into a picture, and ShareLink opens the share sheet: AirDrop, Messages and the rest."
        }
    }
}

enum NWLines {
    static let opened = ["Ooh, a wonder.", "Native! Fancy.", "Watch this."]
    static let jump = ["Wheee!", "Do it again!", "I'm a good jumper. For glass."]
    static let pencilSeen = "I see it. I see the pointy thing."
    static let pencilGone = "Where'd it go?"
    static let postcard = ["Wish you were here.", "Having a lovely time. The time is lovely.",
                           "The view from the clock is great.", "Sending glass and kisses."]
}

/// Pip in 3D's detail dial, like a game's graphics setting.
enum NWDetail: Int, CaseIterable, Identifiable {
    case flat, layers, full
    var id: Int { rawValue }
    var name: String { ["Flat", "Layers", "Full"][rawValue] }
    var what: String {
        switch self {
        case .flat: "One picture. Pip turns, nothing else moves."
        case .layers: "Glow, body and shine at different depths. Cheap 3D."
        case .full: "A real 3D turn, a moving shine, a floor shadow and breathing."
        }
    }
}

// MARK: Logic

/// Gravity in screen directions (x right, y down), from CoreMotion. Read each frame, not observed.
/// Without a motion sensor (the Simulator) it sways gently, and dragging can tilt by hand.
final class NWMotion {
    private let manager = CMMotionManager()
    private var raw = CMAcceleration(x: 0, y: -1, z: 0)
    var orientation: UIInterfaceOrientation = .portrait
    var manual: CGVector?
    var hasSensor: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            if let g = motion?.gravity { self?.raw = g }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }

    func gravity(at time: Double) -> CGVector {
        if let manual { return manual }
        guard hasSensor else { return CGVector(dx: sin(time * 0.5) * 0.35, dy: 1) }
        let g = raw
        switch orientation {
        case .portraitUpsideDown: return CGVector(dx: -g.x, dy: g.y)
        case .landscapeLeft: return CGVector(dx: g.y, dy: g.x)
        case .landscapeRight: return CGVector(dx: -g.y, dy: -g.x)
        default: return CGVector(dx: g.x, dy: -g.y)
        }
    }

    @MainActor static func currentOrientation() -> UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.effectiveGeometry.interfaceOrientation ?? .portrait
    }
}

/// The water between frames: its surface angle chases gravity's angle through a soft spring,
/// which is what makes it lag, overshoot and settle like liquid.
final class NWLiquid {
    private(set) var angle = 0.0
    private(set) var spin = 0.0
    var splash = 0.0
    private var last: Double?

    func step(time: Double, gravity: CGVector, calm: Bool) {
        let target = atan2(-gravity.dx, gravity.dy)
        guard let last else { self.last = time; angle = target; return }
        let dt = min(max(time - last, 0), 1 / 30)
        guard dt > 0 else { return }
        self.last = time
        if calm {
            angle = target
            spin = 0
        } else {
            var diff = target - angle
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            spin += (diff * 26 - spin * 3.0) * dt
            angle += spin * dt
        }
        splash *= exp(-dt * 1.4)
    }

    /// A snapshot for drawing, so Canvas only reads plain numbers.
    var wave: NWWave { NWWave(spin: spin, splash: splash) }
}

struct NWWave {
    let spin: Double
    let splash: Double
    func height(_ x: Double, _ time: Double, calm: Bool) -> Double {
        if calm { return 0 }
        let amp = 5 + min(46, abs(spin) * 34) + splash
        return amp * sin(x * 0.011 + time * 2.1) + amp * 0.45 * sin(x * 0.027 - time * 3.3)
    }
}

/// Where Pip in 3D is looking: a slow spring toward the finger, or idle glances.
final class NWLook {
    private(set) var at = CGPoint.zero
    private var idle = CGPoint.zero
    private var nextGlance = 0.0
    private var last: Double?

    func step(time: Double, target: CGPoint?, calm: Bool) {
        let dt = min(max(time - (last ?? time), 0), 1 / 30)
        last = time
        if time > nextGlance {
            idle = Int.random(in: 0..<4) == 0 ? .zero : CGPoint(x: .random(in: -0.9...0.9), y: .random(in: -0.5...0.6))
            nextGlance = time + .random(in: 1.2...3.2)
        }
        let goal = target ?? idle
        if calm { at = goal; return }
        let k = 1 - exp(-5 * dt)
        at = CGPoint(x: at.x + (goal.x - at.x) * k, y: at.y + (goal.y - at.y) * k)
    }
}

/// Says the time in a British voice, then the six pips: five short, one long, 1 kHz.
final class NWSpeakingClock: NSObject, AVSpeechSynthesizerDelegate {
    private let voice = AVSpeechSynthesizer()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    var onFinish: (() -> Void)?

    override init() {
        super.init()
        voice.delegate = self
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func speak(_ date: Date = .now) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: "At the third stroke, it will be \(Self.words(for: date)), precisely.")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.47
        voice.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        playPips()
    }

    private func playPips() {
        let rate = format.sampleRate
        let total = AVAudioFrameCount(rate * 5.6)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = total
        for i in 0..<Int(total) {
            let t = Double(i) / rate
            let second = Int(t)
            let into = t - Double(second)
            let length = second == 5 ? 0.5 : 0.1
            let on = second <= 5 && into < length
            let edge = min(into, length - into) / 0.005      // a short fade at each end stops clicks
            samples[i] = on ? Float(sin(2 * .pi * 1000 * t) * 0.35 * min(1, max(0, edge))) : 0
        }
        do {
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer) { [weak self] in
                DispatchQueue.main.async { self?.onFinish?() }
            }
            player.play()
        } catch {
            onFinish?()
        }
    }

    /// "ten forty-one", "four o'clock", "nine oh five".
    static func words(for date: Date) -> String {
        let spell = NumberFormatter()
        spell.numberStyle = .spellOut
        spell.locale = Locale(identifier: "en_GB")
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = (parts.hour ?? 0) % 12 == 0 ? 12 : (parts.hour ?? 0) % 12
        let minute = parts.minute ?? 0
        let h = spell.string(from: hour as NSNumber) ?? "\(hour)"
        let m = spell.string(from: minute as NSNumber) ?? "\(minute)"
        switch minute {
        case 0: return "\(h) o'clock"
        case 1..<10: return "\(h) oh \(m)"
        default: return "\(h) \(m)"
        }
    }
}

// MARK: Views

/// The plugin card: the big wow first, then the little ones. Each opens full screen.
private struct NWCard: View {
    let host: PipHost
    @State private var open: NWWonder?
    @State private var lesson: NWWonder?

    var body: some View {
        VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
            ForEach(NWWonder.allCases) { wonder in
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        open = wonder
                        if let line = NWLines.opened.randomElement() { host.say(line, for: 1.6) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: wonder.icon).frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(wonder.name).bold()
                                Text(wonder.what).foregroundStyle(.secondary).font(.system(size: 12))
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens it full screen.")
                    Button(lesson == wonder ? "Hide how it works" : "How it works") {
                        lesson = lesson == wonder ? nil : wonder
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(PipLook.accent)
                    if lesson == wonder {
                        Text(wonder.howItWorks).foregroundStyle(.secondary).font(.system(size: 12))
                    }
                }
            }
            Text("Best on the iPad itself. In the Simulator, drag to tilt.")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13.5))
        .fullScreenCover(item: $open) { wonder in
            NWScreen(wonder: wonder, host: host) { open = nil }
        }
    }
}

/// A wonder, full screen, with a close button that's always there.
private struct NWScreen: View {
    let wonder: NWWonder
    let host: PipHost
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch wonder {
            case .liquidTime: NWLiquidTime(simpler: host.simpler)
            case .pipIn3D: NWPipIn3D(simpler: host.simpler)
            case .pencil: NWPencil(simpler: host.simpler)
            case .speakingClock: NWSpeaking()
            case .battery: NWBattery()
            case .postcard: NWPostcard()
            }
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .padding(20)
            .accessibilityLabel("Close \(wonder.name)")
        }
    }
}

/// The shared full-screen backdrop: Pip's deep colours. (A proposed look.)
private struct NWBackdrop: View {
    var body: some View {
        LinearGradient(colors: [PipLook.eye, PipLook.orbDeep.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// MARK: Liquid Time (the wow)

private struct NWLiquidTime: View {
    let simpler: Bool
    @State private var sim = NWLiquid()
    @State private var motion = NWMotion()
    @State private var hint = true

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let g = motion.gravity(at: time)
                let _ = sim.step(time: time, gravity: g, calm: simpler)
                let angle = sim.angle, wave = sim.wave
                let clock = timeline.date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                let fontSize = min(geo.size.width / CGFloat(max(clock.count, 4)) * 1.75, geo.size.height * 0.62)
                let digits = Text(clock).font(.system(size: fontSize, weight: .black, design: .rounded)).monospacedDigit()

                ZStack {
                    NWBackdrop()
                    NWWater(angle: angle, wave: wave, time: time, calm: simpler, bright: false).opacity(0.38)
                    NWWater(angle: angle, wave: wave, time: time, calm: simpler, bright: true).mask(digits)
                    digits.foregroundStyle(.white.opacity(0.08))
                    // A streak of light across the glass that slides as you tilt.
                    LinearGradient(stops: [.init(color: .clear, location: 0.35),
                                           .init(color: .white.opacity(0.7), location: 0.5),
                                           .init(color: .clear, location: 0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .offset(x: -g.dx * geo.size.width * 0.35, y: -(g.dy - 1) * geo.size.height * 0.35)
                        .blendMode(.plusLighter)
                        .mask(digits)
                    floatingPip(angle: angle, wave: wave, time: time, size: geo.size)
                }
            }
            .contentShape(.rect)
            .onTapGesture { sim.splash += 34 }
            .gesture(DragGesture(minimumDistance: 8)
                .onChanged { drag in
                    guard !motion.hasSensor else { return }
                    motion.manual = CGVector(dx: drag.translation.width / 260, dy: 1)
                }
                .onEnded { _ in motion.manual = nil })
            .overlay(alignment: .bottom) {
                if hint {
                    Text(motion.hasSensor ? "Tilt your iPad. Tap to splash." : "Drag to tilt. Tap to splash.")
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            motion.orientation = NWMotion.currentOrientation()
            motion.start()
            Task {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 1)) { hint = false }
            }
        }
        .onDisappear { motion.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            motion.orientation = NWMotion.currentOrientation()
        }
        .accessibilityElement()
        .accessibilityLabel("Liquid Time. The clock is filled with water that moves as you tilt the iPad. Tap to splash.")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Pip bobbing on the surface: the surface point, turned by the water's angle around the centre.
    private func floatingPip(angle: Double, wave: NWWave, time: Double, size: CGSize) -> some View {
        let x = Double(size.width) * 0.28
        let y = Double(size.height) * 0.04 + wave.height(x, time, calm: simpler) - 30
        let point = CGPoint(x: size.width / 2 + CGFloat(x * cos(angle) - y * sin(angle)),
                            y: size.height / 2 + CGFloat(x * sin(angle) + y * cos(angle)))
        let bob = simpler ? 0 : sin(time * 1.7) * 0.18 + wave.spin * 0.05
        let flap = simpler ? 0 : (sin(time * 5) + 1) / 2
        return PipBody(face: .happy, flap: flap, size: 30)
            .rotationEffect(.radians(angle + bob))
            .position(point)
            .allowsHitTesting(false)
    }
}

/// The water: a wavy surface, filled below, with bubbles rising through it.
private struct NWWater: View {
    let angle: Double
    let wave: NWWave
    let time: Double
    let calm: Bool
    let bright: Bool

    var body: some View {
        let angle = angle, wave = wave, time = time, calm = calm, bright = bright
        Canvas { ctx, size in
            let reach = hypot(size.width, size.height)
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: .radians(angle))
            let level = size.height * 0.04

            var surface = Path()
            var fill = Path()
            fill.move(to: CGPoint(x: -reach, y: reach))
            var first = true
            for x in stride(from: -reach, through: reach, by: 10) {
                let point = CGPoint(x: x, y: level + wave.height(Double(x), time, calm: calm))
                fill.addLine(to: point)
                if first { surface.move(to: point); first = false } else { surface.addLine(to: point) }
            }
            fill.addLine(to: CGPoint(x: reach, y: reach))
            fill.closeSubpath()

            let colours: [Color] = bright ? [PipLook.glow, PipLook.accent, PipLook.orbDeep] : [PipLook.accent, PipLook.orbDeep]
            ctx.fill(fill, with: .linearGradient(Gradient(colors: colours),
                                                 startPoint: CGPoint(x: 0, y: level - 40),
                                                 endPoint: CGPoint(x: 0, y: level + size.height * 0.6)))
            ctx.stroke(surface, with: .color(.white.opacity(bright ? 0.85 : 0.4)), lineWidth: bright ? 3 : 1.5)

            guard !calm else { return }
            for i in 0..<(bright ? 26 : 12) {
                let seed = Double(i) * 1.618
                let depth = Double(size.height) * 0.6
                let rise = (time * (30 + (seed * 13).truncatingRemainder(dividingBy: 40)) + seed * 97)
                    .truncatingRemainder(dividingBy: depth)
                let x = ((seed * 0.37).truncatingRemainder(dividingBy: 1) - 0.5) * Double(size.width) * 1.1 + sin(time * 1.3 + seed) * 8
                let y = Double(level) + depth - rise
                guard y > Double(level) + wave.height(x, time, calm: false) + 4 else { continue }
                let r = 2 + (seed * 3).truncatingRemainder(dividingBy: 5)
                ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color(.white.opacity(0.7)), lineWidth: 1.2)
            }
        }
    }
}

// MARK: Pip in 3D

private struct NWPipIn3D: View {
    let simpler: Bool
    @State private var detail = NWDetail.full
    @State private var pointer: CGPoint?
    @State private var look = NWLook()
    @State private var blinkUntil = 0.0
    @State private var nextBlink = 2.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.16
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
            ZStack {
                NWBackdrop()
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let target = pointer.map {
                        CGPoint(x: min(max(($0.x - centre.x) / (geo.size.width / 2), -1), 1),
                                y: min(max(($0.y - centre.y) / (geo.size.height / 2), -1), 1))
                    }
                    let _ = look.step(time: time, target: target, calm: simpler)
                    let at = look.at
                    let breathe = detail == .full && !simpler ? sin(time * 1.6) * 0.02 : 0
                    let blinking = !simpler && time.truncatingRemainder(dividingBy: 4.3) < 0.14
                    figure(at: at, size: size, face: pointer == nil ? (blinking ? .blink : .awake) : .happy,
                           flap: simpler ? 0 : (sin(time * 4) + 1) / 2)
                        .scaleEffect(1 + breathe)
                        .position(centre)
                }
                VStack(spacing: 12) {
                    Spacer()
                    Text(detail.what).font(.system(size: 15)).foregroundStyle(.white.opacity(0.85))
                    Picker("Detail", selection: $detail) {
                        ForEach(NWDetail.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 340)
                    Text("Touch or hover a Pencil. Leave Pip alone and they'll look around.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 40)
                .padding(.horizontal, 20)
            }
            .contentShape(.rect)
            .onContinuousHover { phase in
                if case .active(let p) = phase { pointer = p } else { pointer = nil }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { pointer = $0.location }
                .onEnded { _ in pointer = nil })
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pip in 3D. Pip turns to look at your finger.")
    }

    /// Pip at the chosen detail. Nearer layers slide further: that difference reads as depth.
    @ViewBuilder private func figure(at: CGPoint, size: CGFloat, face: PipFace, flap: Double) -> some View {
        let layered = detail != .flat
        ZStack {
            if detail == .full {
                Ellipse().fill(.black.opacity(0.35))
                    .frame(width: size * 2.2, height: size * 0.4)
                    .blur(radius: 10)
                    .offset(x: -at.x * size * 0.4, y: size * 2.1)
            }
            if layered {
                Circle().fill(PipLook.glow.opacity(0.35))
                    .frame(width: size * 3, height: size * 3)
                    .blur(radius: size * 0.4)
                    .offset(x: -at.x * size * 0.25, y: -at.y * size * 0.25)
            }
            PipBody(face: face, flap: flap, size: size)
                .offset(x: at.x * size * (layered ? 0.3 : 0.15), y: at.y * size * (layered ? 0.3 : 0.15))
                .rotation3DEffect(.degrees(detail == .full ? Double(at.x) * 30 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .rotation3DEffect(.degrees(detail == .full ? Double(-at.y) * 22 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            if layered {
                Capsule().fill(.white.opacity(0.7))
                    .frame(width: size * 0.5, height: size * 0.18)
                    .rotationEffect(.degrees(-35))
                    .blur(radius: 1)
                    .offset(x: -size * 0.35 + at.x * size * 0.55, y: -size * 0.45 + at.y * size * 0.55)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Pip Sees Your Pencil

private struct NWPencil: View {
    let simpler: Bool
    @State private var spot: CGPoint?
    @State private var hop = false
    @State private var line = "Hover your Pencil over the screen."

    var body: some View {
        GeometryReader { geo in
            let home = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // Pip leans toward the Pencil, but stays near home.
            let lean = spot.map { CGPoint(x: home.x + ($0.x - home.x) * 0.25, y: home.y + ($0.y - home.y) * 0.25) } ?? home
            ZStack {
                NWBackdrop()
                PipBody(face: spot == nil ? .awake : .happy, flap: hop ? 1 : 0, size: 56)
                    .position(lean)
                    .offset(y: hop ? -90 : 0)
                    .animation(simpler ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.5), value: hop)
                    .animation(simpler ? nil : .smooth(duration: 0.3), value: lean)
                Text(line).font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                    .position(x: home.x, y: geo.size.height * 0.78)
            }
            .contentShape(.rect)
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    spot = p
                    line = NWLines.pencilSeen
                case .ended:
                    spot = nil
                    line = NWLines.pencilGone
                }
            }
            .onTapGesture(count: 2) { jump() }
            .onPencilSqueeze { phase in
                if case .ended = phase { jump() }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("Pip follows your hovering Pencil. Double tap to make Pip jump.")
        .accessibilityAction { jump() }
    }

    private func jump() {
        hop = true
        line = NWLines.jump.randomElement() ?? line
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            hop = false
        }
    }
}

// MARK: The Speaking Clock

private struct NWSpeaking: View {
    @State private var clock = NWSpeakingClock()
    @State private var speaking = false

    var body: some View {
        ZStack {
            NWBackdrop()
            VStack(spacing: 28) {
                PipBody(face: speaking ? .happy : .awake, size: 60)
                Text("Hello, you've reached the clock.")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                Button(speaking ? "Listening…" : "What's the time, Pip?") {
                    speaking = true
                    clock.onFinish = { speaking = false }
                    clock.speak()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(speaking)
                Text("Turn the sound up.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: Pip Feels the Battery

private struct NWBattery: View {
    @State private var level: Float = -1
    @State private var state: UIDevice.BatteryState = .unknown

    var body: some View {
        let fill = 304 * CGFloat(max(level, 0.06))
        ZStack {
            NWBackdrop()
            VStack(spacing: 24) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 36).stroke(.white.opacity(0.6), lineWidth: 6)
                        .frame(width: 180, height: 320)
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(colors: [PipLook.glow, PipLook.accent], startPoint: .top, endPoint: .bottom))
                        .frame(width: 164, height: fill)
                        .padding(.bottom, 8)
                    PipBody(face: state == .charging ? .happy : .awake, size: 28)
                        .offset(y: -fill - 22)
                }
                .animation(.spring, value: level)
                Text(percent).font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(line).font(.system(size: 19)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            }
            .padding()
        }
        .onAppear(perform: read)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in read() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in read() }
        .accessibilityElement(children: .combine)
    }

    private func read() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        level = UIDevice.current.batteryLevel
        state = UIDevice.current.batteryState
    }

    private var percent: String { level < 0 ? "?" : "\(Int((level * 100).rounded()))%" }

    private var line: String {
        if level < 0 { return "No battery here. Are we in the Simulator? Spooky." }
        switch state {
        case .charging: return "Ooh, snacks. I'm floating up."
        case .full: return "Full! I've never felt more buoyant."
        default:
            if level < 0.2 { return "Running low. I'll keep things calm to save power." }
            if level < 0.5 { return "Half full. Or half empty. I'm glass, I'd know." }
            return "Plenty of charge. Let's do something silly."
        }
    }
}

// MARK: Pip Postcard

private struct NWPostcard: View {
    @State private var image: Image?
    @State private var line = NWLines.postcard[0]

    var body: some View {
        ZStack {
            NWBackdrop()
            VStack(spacing: 28) {
                card.frame(width: 360, height: 240).shadow(radius: 20, y: 10)
                HStack(spacing: 14) {
                    Button("New line") {
                        line = NWLines.postcard.filter { $0 != line }.randomElement() ?? line
                        render()
                    }
                    .buttonStyle(.glass)
                    if let image {
                        ShareLink(item: image, preview: SharePreview("A postcard from Pip", image: image)) {
                            Label("Send it", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .controlSize(.large)
            }
        }
        .onAppear(perform: render)
    }

    private var card: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [PipLook.accent, PipLook.orbDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("“\(line)”").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                Text("Pip, Pip Sandbox").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
            PipBody(face: .happy, size: 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(30)
        }
        .clipShape(.rect(cornerRadius: 28))
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.frame(width: 360, height: 240))
        renderer.scale = 3
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }
}
