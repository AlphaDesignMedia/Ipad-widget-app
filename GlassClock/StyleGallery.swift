import SwiftUI

// Debug-only tools for comparing clock styles side by side in the simulator:
//   -gallery fonts|ampm|glass|light   shows a page of labelled variations
//   -style '<ClockStyle JSON>'        opens the app with that style

#if DEBUG
extension ClockStyle {
    static var launchOverride: ClockStyle? {
        guard let json = UserDefaults.standard.string(forKey: "style") else { return nil }
        return try? JSONDecoder().decode(ClockStyle.self, from: Data(json.utf8))
    }

    fileprivate func with(_ change: (inout ClockStyle) -> Void) -> ClockStyle {
        var copy = self
        change(&copy)
        return copy
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
        let colourful = ClockStyle().with { $0.color = .yellow; $0.effect = .glow; $0.textFill = .solid }
        let keepText = colourful.with { $0.keepsTimeColours = true; $0.keepsDetailColours = true }
        let keepAll = keepText.with { $0.keepsCardColours = true; $0.background = .solid; $0.backgroundColor = .purple }
        return [
            ("Clear, system colours", colourful, .clear),
            ("Clear, keep text colours", keepText, .clear),
            ("Tinted, system colours", colourful, .tinted),
            ("Tinted, keep text + card", keepAll, .tinted),
            ("Glass default, Clear", ClockStyle(), .clear),
            ("Glass default, keep time", ClockStyle().with { $0.keepsTimeColours = true }, .clear),
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
                ("Glass + shadow", glass.with { $0.effect = .shadow; $0.effectStrength = 0.5 }),
                ("Glass + glow", glass.with { $0.effect = .glow; $0.effectColor = .blue; $0.effectStrength = 0.6 }),
                ("Glass + inner colour", glass.with { $0.innerColor = .orange }),
                ("Glass, SF Rounded", glass.with { $0.font = .sfRounded }),
                ("Glass, Google Sans Flex", glass.with { $0.font = .googleSansFlex; $0.fontWidth = 0.35 }),
            ]
        case "light":
            return [
                ("Dark shadow", base.with { $0.effect = .shadow }),
                ("Light shadow (white)", base.with { $0.color = .black; $0.effect = .shadow; $0.effectColor = .white; $0.effectStrength = 1 }),
                ("Glow, text colour", base.with { $0.color = .yellow; $0.effect = .glow }),
                ("Glow, own colour", base.with { $0.effect = .glow; $0.effectColor = .purple; $0.effectSize = 0.7 }),
                ("Inner colour only", base.with { $0.innerColor = .red; $0.innerStrength = 0.8 }),
                ("Inner colour + glow", base.with { $0.innerColor = .mint; $0.effect = .glow; $0.effectColor = .mint }),
            ]
        case "lock":
            // Settings that get close to the iPadOS Lock Screen clock.
            let lock = base.with { $0.textFill = .glass; $0.fontWeight = 0.95; $0.height = 1.3; $0.effect = .shadow; $0.effectStrength = 0.35; $0.ampm = .hidden }
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
        if page == "default" { sizes } else if page == "accent" { accentGrid } else { grid }
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

    private var accentGrid: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            LazyVGrid(columns: [GridItem(.fixed(378.5), spacing: 40), GridItem(.fixed(378.5))], spacing: 36) {
                ForEach(accentVariants, id: \.0) { name, style, home in
                    VStack(spacing: 10) {
                        ClockFace(date: date, style: style, simulatedAccent: home.accent)
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
#else
extension ClockStyle {
    static var launchOverride: ClockStyle? { nil }
}
#endif
