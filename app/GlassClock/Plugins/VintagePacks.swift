import SwiftUI

// VINTAGE PACKS · plugin v1 (Dream). Pack 01, "The Tin": the clock as a pressed British biscuit tin.
// Burnt orange enamel, a black diamond cartouche, a cream keyline, a slow shine and a few honest scuffs.
//
// HOMAGE ONLY. This is the genre, not anybody's tin: the shapes and colours of 1960s British packaging,
// with our own words on it. No real brand, mark or slogan goes in here, ever. If a pack starts looking
// like a real product, change the words until it doesn't.
//
// CHEAP ON PURPOSE. Not one image file. Everything is a gradient, a path or a piece of type, and the clock
// ticks once a second rather than every frame. A whole pack costs about as much as a label.
//
// GROWING THIS. Add to `packs` below and nothing else. Each pack is just colours and words.

struct VintagePacks: SandboxPlugin {
    let info = PluginInfo(id: "vintage", name: "Vintage packs", version: "v1", shelf: .dream,
                          icon: "shippingbox",
                          what: "The clock as old packaging. Pack 01 is a pressed biscuit tin.")

    enum Tune {
        static let lidRatio = 0.62        // height against width
        static let corner = 22.0
        static let keylineInset = 9.0
        static let diamondWidth = 0.72    // of the lid's width
        static let diamondHeight = 0.42   // of the lid's height
        static let shineSeconds = 7.0     // one sweep across the lid
        static let shineWidth = 0.22      // of the lid's width
        static let wordSize = 0.17        // of the lid's width
        static let timeSize = 0.13
        static let scuffOpacity = 0.14
    }

    /// A pack is colours and words. Nothing else, so new ones are cheap to add.
    struct Pack: Identifiable {
        let id: String, name: String
        let ground: Color, deep: Color, ink: Color, keyline: Color
        let word: String, subtitle: String, left: String, right: String, est: String
    }

    static let packs: [Pack] = [
        Pack(id: "tin", name: "The Tin",
             ground: Color(red: 214 / 255, green: 126 / 255, blue: 34 / 255),
             deep: Color(red: 150 / 255, green: 77 / 255, blue: 12 / 255),
             ink: Color(red: 24 / 255, green: 20 / 255, blue: 16 / 255),
             keyline: Color(red: 244 / 255, green: 232 / 255, blue: 206 / 255),
             word: "PIP'S", subtitle: "SANDBOX BISCUITS",
             left: "Crisp", right: "and Calm", est: "EST. 2026"),
    ]

    func start(_ host: PipHost) throws {}
    func on(_ event: PipEvent, _ host: PipHost) {}
    func card(_ host: PipHost) -> some View { PackCard(host: host) }
}

// MARK: The panel

private struct PackCard: View {
    let host: PipHost
    @State private var chosen = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vintage packs").font(.system(size: 20, weight: .semibold))
            Text("The clock as old packaging. Drawn, not photographed.")
                .font(.system(size: 13)).foregroundStyle(.secondary)

            TinLid(pack: VintagePacks.packs[chosen], simpler: host.simpler, quiet: host.joy == 0)
                .padding(.vertical, 4)

            if VintagePacks.packs.count > 1 {
                Picker("Pack", selection: $chosen) {
                    ForEach(VintagePacks.packs.indices, id: \.self) {
                        Text(VintagePacks.packs[$0].name).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
            } else {
                Text("Pack 01 of 01. More to come.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .padding(18)
    }
}

// MARK: The tin

private struct TinLid: View {
    let pack: VintagePacks.Pack
    let simpler: Bool
    let quiet: Bool
    @State private var sweep = false

    /// Scuffs are fixed, not random, so the tin wears the same way every time you open it.
    private let scuffs: [(x: Double, y: Double, w: Double, h: Double, a: Double)] = [
        (0.13, 0.22, 0.17, 0.03, 36), (0.78, 0.71, 0.21, 0.025, -18),
        (0.46, 0.12, 0.10, 0.02, 7),  (0.26, 0.86, 0.13, 0.022, -29),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = w * VintagePacks.Tune.lidRatio
            ZStack {
                // Pressed metal: brighter in the middle, rolling off to the edges.
                RoundedRectangle(cornerRadius: VintagePacks.Tune.corner, style: .continuous)
                    .fill(RadialGradient(colors: [pack.ground, pack.deep],
                                         center: .init(x: 0.42, y: 0.34),
                                         startRadius: w * 0.05, endRadius: w * 0.78))

                // Scuffs and a soft vignette: the tin has had a life.
                ForEach(scuffs.indices, id: \.self) { i in
                    let s = scuffs[i]
                    Capsule().fill(pack.keyline.opacity(VintagePacks.Tune.scuffOpacity))
                        .frame(width: w * s.w, height: h * s.h)
                        .rotationEffect(.degrees(s.a))
                        .position(x: w * s.x, y: h * s.y)
                }

                // The cream keyline, printed just inside the edge.
                RoundedRectangle(cornerRadius: VintagePacks.Tune.corner - 5, style: .continuous)
                    .strokeBorder(pack.keyline.opacity(0.85), lineWidth: 1.6)
                    .padding(VintagePacks.Tune.keylineInset)

                cartouche(w: w, h: h)
                stamped(w: w, h: h)

                // Enamel shine. One slow pass. Off under reduced motion and at joy 0.
                if !simpler && !quiet {
                    LinearGradient(colors: [.clear, .white.opacity(0.26), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(width: w * VintagePacks.Tune.shineWidth, height: h * 2)
                        .rotationEffect(.degrees(22))
                        .offset(x: sweep ? w * 0.75 : -w * 0.75)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: VintagePacks.Tune.corner, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
            .shadow(color: .black.opacity(0.12), radius: 16, y: 10)
            .onAppear {
                guard !simpler && !quiet else { return }
                withAnimation(.linear(duration: VintagePacks.Tune.shineSeconds).repeatForever(autoreverses: false)) {
                    sweep = true
                }
            }
        }
        .aspectRatio(1 / VintagePacks.Tune.lidRatio, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.name). A vintage tin lid reading \(pack.word), \(pack.subtitle), \(pack.est).")
    }

    /// The black diamond and its wordmark.
    @ViewBuilder private func cartouche(w: Double, h: Double) -> some View {
        let dw = w * VintagePacks.Tune.diamondWidth, dh = h * VintagePacks.Tune.diamondHeight
        ZStack {
            Diamond().fill(pack.ink)
                .frame(width: dw, height: dh)
            Diamond().stroke(pack.keyline.opacity(0.9), lineWidth: 1.4)
                .frame(width: dw - 11, height: dh - 11)

            HStack(spacing: 9) {
                Text(pack.left).font(.system(size: w * 0.035, weight: .regular, design: .serif)).italic()
                Text(pack.word)
                    .font(.system(size: w * VintagePacks.Tune.wordSize, weight: .heavy).width(.condensed))
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 1.5, y: 1.5)
                Text(pack.right).font(.system(size: w * 0.035, weight: .regular, design: .serif)).italic()
            }
            .foregroundStyle(pack.keyline)

            Text(pack.subtitle)
                .font(.system(size: w * 0.034, weight: .semibold).width(.condensed))
                .tracking(w * 0.006)
                .foregroundStyle(pack.keyline.opacity(0.9))
                .offset(y: dh * 0.23)

            Text(pack.est)
                .font(.system(size: w * 0.024, weight: .medium, design: .serif))
                .foregroundStyle(pack.keyline.opacity(0.75))
                .offset(y: -dh * 0.26)
        }
        .offset(y: -h * 0.06)
    }

    /// The time, pressed into the metal under the cartouche. Ticks once a second, not every frame.
    @ViewBuilder private func stamped(w: Double, h: Double) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            Text(tl.date.formatted(.dateTime.hour().minute()))
                .font(.system(size: w * VintagePacks.Tune.timeSize, weight: .bold, design: .serif))
                .foregroundStyle(pack.deep.opacity(0.95))
                .shadow(color: pack.keyline.opacity(0.35), radius: 0, x: 0, y: 1)
                .offset(y: h * 0.37)
        }
    }
}

/// A plain diamond: the cartouche shape on half the tins ever pressed.
private struct Diamond: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}
