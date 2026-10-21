import SwiftUI

// Debug-only tools for comparing clock styles side by side in the simulator:
//   -gallery fonts|ampm|glass|light   shows a page of labelled variations
//   GLASSCLOCK_STYLE='<ClockStyle JSON>' (environment; SIMCTL_CHILD_ prefix with simctl)
//                                    opens the app with that style and saves it for the widget

#if DEBUG
extension ClockStyle {
    static var launchOverride: ClockStyle? {
        guard let json = ProcessInfo.processInfo.environment["GLASSCLOCK_STYLE"] else { return nil }
        return try? JSONDecoder().decode(ClockStyle.self, from: Data(json.utf8))
    }
}

struct StyleGallery: View {
    var page: String

    /// 10:09, the classic watch-advert time: every digit shape shows.
    private let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 22, minute: 9))!

    private var base: ClockStyle {
        ClockStyle().with {
            $0.timeFormat = .twelve
            $0.color = .white
            $0.fontWeight = 0.8
        }
    }

    private var accentVariants: [(String, ClockStyle, HomeScreenStyle)] {
        let colourful = ClockStyle().with { $0.color = .yellow; $0.glow = true; $0.shadow = false; $0.textFill = .solid }
        let keepText = colourful.with { $0.keepsTimeColours = true; $0.keepsDetailColours = true }
        let keepAll = keepText.with { $0.keepsCardColours = true; $0.background = .solid; $0.backgroundColor = .purple }
        return [
            ("Clear, system colours", colourful, .clear),
            ("Clear, keep text colours", keepText, .clear),
            ("Tinted, system colours", colourful, .tinted),
            ("Tinted, keep text + card", keepAll, .tinted),
            ("Glass default, Clear", ClockStyle(), .clear),
            ("Yellow glass + inner, keep all", ClockStyle().with { $0.color = .yellow; $0.innerColor = .orange; $0.keepsTimeColours = true; $0.keepsDetailColours = true }, .tinted),
        ]
    }

    private var variants: [(String, ClockStyle)] {
        switch page {
        case "ampm":
            return AMPMPlacement.allCases.map { placement in
                ("AM/PM: \(placement.label)", base.with { $0.ampm = placement })
            } + [("Below, with date", base.with { $0.ampm = .below; $0.showDate = true })]
        case "glass":
            let glass = base.with { $0.textFill = .glass; $0.fontWeight = 0.9 }
            return [
                ("Glass", glass),
                ("Glass + shadow", glass.with { $0.shadow = true }),
                ("Glass + glow + shadow", glass.with { $0.glow = true; $0.glowColor = .blue; $0.glowStrength = 0.6 }),
                ("Glass + inner colour", glass.with { $0.innerColor = .orange }),
                ("Glass, SF Rounded", glass.with { $0.font = .sfRounded }),
                ("Glass, Google Sans Flex", glass.with { $0.font = .googleSansFlex; $0.fontWidth = 0.35 }),
            ]
        case "light":
            return [
                ("Dark shadow", base.with { $0.shadow = true }),
                ("Light shadow (white)", base.with { $0.color = .black; $0.shadowColor = .white; $0.shadowStrength = 1 }),
                ("Glow, text colour", base.with { $0.color = .yellow; $0.glow = true; $0.shadow = false }),
                ("Glow + shadow", base.with { $0.glow = true; $0.glowColor = .purple; $0.glowSize = 0.7 }),
                ("Inner colour only", base.with { $0.innerColor = .red; $0.innerStrength = 0.8 }),
                ("Inner colour + glow", base.with { $0.innerColor = .mint; $0.glow = true; $0.glowColor = .mint }),
            ]
        case "pairs":
            return ClockFont.allCases.map { font in
                ("\(font.label) + \(font.pairing.label)",
                 base.with { $0.font = font; $0.ampm = .below; $0.showDate = true; $0.textFill = .solid; $0.fontWeight = 0.75 })
            }
        case "presets":
            return ClockStyle.presets.map { ($0.name, $0.style.with { $0.timeFormat = .twelve }) }
        case "lock":
            // Settings that get close to the iPadOS Lock Screen clock.
            let lock = base.with { $0.textFill = .glass; $0.fontWeight = 0.95; $0.height = 1.3; $0.shadowStrength = 0.35; $0.ampm = .hidden }
            return [
                ("SF Pro, heavy, taller", lock.with { $0.font = .sf; $0.fontWidth = 0.4 }),
                ("SF Rounded, heavy, taller", lock.with { $0.font = .sfRounded }),
                ("Google Sans Flex, round", lock.with { $0.font = .googleSansFlex; $0.fontWidth = 0.4 }),
                ("New York", lock.with { $0.font = .newYork; $0.height = 1.1 }),
                ("SF Mono", lock.with { $0.font = .sfMono; $0.height = 1.1 }),
                ("Roboto Flex (your default)", ClockStyle()),
            ]
        default:
            return [
                ("SF Pro", base),
                ("SF Rounded", base.with { $0.font = .sfRounded }),
                ("Roboto Flex, narrow", base.with { $0.font = .robotoFlex; $0.fontWidth = 0.25 }),
                ("Roboto Flex, narrow + tall", base.with { $0.font = .robotoFlex; $0.fontWidth = 0.15; $0.height = 1.4; $0.fontWeight = 0.7 }),
                ("Google Sans Flex, round", base.with { $0.font = .googleSansFlex }),
                ("Google Sans Flex, thin + wide", base.with { $0.font = .googleSansFlex; $0.fontWeight = 0.3; $0.fontWidth = 0.8 }),
            ]
        }
    }

    var body: some View {
        if page == "default" { sizes } else if page == "accent" { accentGrid } else if page == "match" { match } else { grid }
    }

    /// The default style at every widget size.
    private var sizes: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 30) {
                HStack(spacing: 30) {
                    card(ClockStyle(), PreviewSize.small)
                    card(ClockStyle(), PreviewSize.medium)
                }
                card(ClockStyle(), PreviewSize.large)
                card(ClockStyle(), PreviewSize.extraLarge)
            }
        }
    }

    private func card(_ style: ClockStyle, _ preview: PreviewSize) -> some View {
        ClockFace(date: date, style: style)
            .padding(16)
            .frame(width: preview.size.width, height: preview.size.height)
            .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28)))
    }

    /// The Lock Screen preset, card off, at the Lock Screen screenshot's time and size,
    /// over a similar blue, to compare against References/simulator/11.
    private var match: some View {
        let time = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 15, minute: 41))!
        let style = ClockStyle.presets.first { $0.name == "Lock Screen" }!.style.with { $0.cardOpacity = 0 }
        return ZStack {
            LinearGradient(colors: [Color(red: 0.2, green: 0.35, blue: 0.85), Color(red: 0.45, green: 0.75, blue: 0.85)],
                           startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea()
            ClockFace(date: time, style: style)
                .frame(width: 560, height: 300)
        }
    }

    private var accentGrid: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            LazyVGrid(columns: [GridItem(.fixed(378.5), spacing: 40), GridItem(.fixed(378.5))], spacing: 36) {
                ForEach(accentVariants, id: \.0) { name, style, home in
                    VStack(spacing: 10) {
                        ClockFace(date: date, style: style, simulatedAccent: home.accent,
                                  simulatesClear: !home.showsKeptColours)
                            .padding(16)
                            .frame(width: 378.5, height: 170)
                            .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28), homeScreen: home))
                        Text(name).font(.headline).foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var grid: some View {
        ZStack {
            // A wallpaper-like backdrop, so glass and light effects read as they would on the Home Screen.
            LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            LazyVGrid(columns: [GridItem(.fixed(378.5), spacing: 40), GridItem(.fixed(378.5))], spacing: 36) {
                ForEach(variants, id: \.0) { name, style in
                    VStack(spacing: 10) {
                        ClockFace(date: date, style: style)
                            .padding(16)
                            .frame(width: 378.5, height: 170)
                            .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28)))
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

/// GLASSCLOCK_STRESS_HOME=<taps> (environment): taps through Light, Dark, Clear and Tinted by
/// itself, as fast as a person would, and prints how many frames were late. For checking the
/// Home Screen picker stays smooth (owner report, 2026-10-21: it stuttered and froze).
enum StressTest {
    static var homeTaps: Int? {
        ProcessInfo.processInfo.environment["GLASSCLOCK_STRESS_HOME"].flatMap(Int.init)
    }
    /// GLASSCLOCK_STRESS_IDLE=1: the same run without changing anything, for a baseline.
    static var idle: Bool { ProcessInfo.processInfo.environment["GLASSCLOCK_STRESS_IDLE"] != nil }
    /// GLASSCLOCK_STRESS_PLAIN=1: changes the style without an animation.
    static var plain: Bool { ProcessInfo.processInfo.environment["GLASSCLOCK_STRESS_PLAIN"] != nil }
}

/// Counts late frames: any gap between screen refreshes over 1.5 times the expected one.
@MainActor final class HitchMeter: NSObject {
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private(set) var frames = 0, late = 0
    private(set) var worst: CFTimeInterval = 0

    func start() {
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }

    func stop() -> String {
        link?.invalidate()
        return "frames \(frames), late \(late), worst \(Int(worst * 1000)) ms"
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { last = link.timestamp }
        guard last > 0 else { return }
        let gap = link.timestamp - last, expected = link.targetTimestamp - link.timestamp
        frames += 1
        worst = max(worst, gap)
        if gap > max(expected, 1.0 / 120) * 1.5 { late += 1 }
    }
}
#else
extension ClockStyle {
    static var launchOverride: ClockStyle? { nil }
}
enum StressTest {
    static var homeTaps: Int? { nil }
    static var idle: Bool { false }
    static var plain: Bool { false }
}
#endif
