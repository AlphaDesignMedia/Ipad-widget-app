import SwiftUI
import AVFoundation

// The little wonders. Each is small on purpose: one native trick, shown plainly.

// MARK: Pip Sees Your Pencil

/// Pip's eyes follow a hovering Pencil (or a trackpad pointer, or a finger). A squeeze on
/// Pencil Pro, or a double tap anywhere, makes Pip jump.
struct PencilWonder: View {
    @State private var look: CGPoint?
    @State private var jumps = 0
    @State private var line = "Hover your Pencil over the screen."
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 24) {
                    ZStack {
                        Text("🫧").font(.system(size: 160))
                        HStack(spacing: 34) { eye(from: centre, offset: -34); eye(from: centre, offset: 34) }
                            .offset(y: -6)
                    }
                    .offset(y: jumps.isMultiple(of: 2) ? 0 : -90)
                    .animation(reduceMotion ? .none : .spring(duration: 0.35, bounce: 0.6), value: jumps)
                    Text(line).font(.title3.weight(.medium)).foregroundStyle(.white)
                }
            }
            .contentShape(.rect)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    look = point
                    line = "I see it. I see the pointy thing."
                case .ended:
                    look = nil
                    line = "Where'd it go?"
                }
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { look = $0.location }
                .onEnded { _ in look = nil })
            .onTapGesture(count: 2) { jump() }
            .onPencilSqueeze { phase in
                if case .ended = phase { jump() }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement()
        .accessibilityLabel("Pip watches your Pencil. Double tap to make Pip jump.")
        .accessibilityAction { jump() }
    }

    private func jump() {
        jumps += 1
        line = ["Wheee!", "Do it again!", "I'm a good jumper. For glass."].randomElement()!
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            jumps += 1
        }
    }

    /// One eye: a white circle with a pupil that leans toward the pointer.
    private func eye(from centre: CGPoint, offset: CGFloat) -> some View {
        let target = look ?? CGPoint(x: centre.x + offset, y: centre.y)
        let dx = target.x - (centre.x + offset), dy = target.y - centre.y
        let distance = max(hypot(dx, dy), 1)
        let reach = min(distance, 9)
        return Circle().fill(.white).frame(width: 30, height: 30)
            .overlay(Circle().fill(.black).frame(width: 14, height: 14)
                .offset(x: dx / distance * reach, y: dy / distance * reach))
    }
}

// MARK: The Speaking Clock

/// Says the time in a British voice, then plays the six pips: five short, one long.
final class SpeakingClock: NSObject, AVSpeechSynthesizerDelegate {
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

    /// Five 0.1 s pips a second apart, then a 0.5 s one. 1 kHz, like the radio.
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
            // A short fade at each end stops clicks.
            let edge = min(into, length - into) / 0.005
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
        switch minute {
        case 0: return "\(h) o'clock"
        case 1..<10: return "\(h) oh \(spell.string(from: minute as NSNumber) ?? "\(minute)")"
        default: return "\(h) \(spell.string(from: minute as NSNumber) ?? "\(minute)")"
        }
    }
}

struct SpeakingClockWonder: View {
    @State private var clock = SpeakingClock()
    @State private var speaking = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.15, green: 0.1, blue: 0.05)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 28) {
                Text("📞").font(.system(size: 110)).accessibilityHidden(true)
                Text("Hello, you've reached the clock.")
                    .font(.title2.weight(.semibold)).foregroundStyle(.white)
                Button(speaking ? "Listening…" : "What's the time, Pip?") {
                    speaking = true
                    clock.onFinish = { speaking = false }
                    clock.speak()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(speaking)
                Text("Turn the sound up.").font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: Pip Feels the Battery

struct BatteryWonder: View {
    @State private var level: Float = -1
    @State private var state: UIDevice.BatteryState = .unknown

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.15, blue: 0.1), .black], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 24) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 36).stroke(.white.opacity(0.6), lineWidth: 6)
                        .frame(width: 180, height: 320)
                    RoundedRectangle(cornerRadius: 28).fill(fillColour.gradient)
                        .frame(width: 164, height: max(20, 304 * CGFloat(max(level, 0))))
                        .padding(.bottom, 8)
                        .animation(.spring, value: level)
                    Text("🫧").font(.system(size: 64))
                        .offset(y: -max(20, 304 * CGFloat(max(level, 0))) - 10)
                }
                Text(percent).font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(line).font(.title3).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            }
            .padding()
        }
        .ignoresSafeArea()
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
    private var fillColour: Color { level < 0.2 ? .red : level < 0.5 ? .yellow : .green }

    private var line: String {
        if level < 0 { return "No battery here. Are we in the Simulator? Spooky." }
        switch state {
        case .charging: return "Ooh, snacks. I'm floating up."
        case .full: return "Full! I've never felt more buoyant."
        default:
            if level < 0.2 { return "Running low. I'll keep things calm to save power." }
            if level < 0.5 { return "Half full. Or half empty. I'm a glass, I'd know." }
            return "Plenty of charge. Let's do something silly."
        }
    }
}

// MARK: Pip Postcard

/// A little card of the clock and Pip, rendered to an image and shared with the system sheet.
struct PostcardWonder: View {
    @State private var image: Image?
    @State private var line = PipLines.line(.moan) ?? "Wish you were here."

    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 28) {
                card.frame(width: 360, height: 240)
                    .shadow(radius: 20, y: 10)
                HStack(spacing: 14) {
                    Button("New line") {
                        line = PipLines.line(.moan) ?? line
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
        .ignoresSafeArea()
        .onAppear(perform: render)
    }

    private var card: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.teal, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("“\(line)”").font(.headline).foregroundStyle(.white.opacity(0.9))
                Text("— Pip, Glass Clock").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
            Text("🫧").font(.system(size: 54)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(16)
        }
        .clipShape(.rect(cornerRadius: 28))
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: card.frame(width: 360, height: 240))
        renderer.scale = 3
        if let ui = renderer.uiImage { image = Image(uiImage: ui) }
    }
}
