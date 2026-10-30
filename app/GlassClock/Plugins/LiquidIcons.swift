import SwiftUI

// LIQUID ICONS · plugin v1 (Dream). The plugin bar's icons become drops of liquid glass: each icon its own
// drop, squishing when pressed (interactive glass). Drops close together run into each other like liquid.
// An open card's drop grows a little and brightens, with a wobble (a fade under simpler motion).
// How runny is a setting. "Whole app" turns the settings rail (icons only) and top buttons into drops too.
// Uses the host's `barLook`, so it touches no other file.
// Where: the drop button in the plugin bar.

struct LiquidIcons: SandboxPlugin {
    let info = PluginInfo(id: "liquid", name: "Liquid Icons", version: "v1", shelf: .dream,
                          icon: "drop", what: "The plugin bar's icons become drops of liquid glass.")

    // MARK: Data

    enum Runny: String, CaseIterable {
        case drops, puddle, blob
        var label: String { rawValue.capitalized }
        /// Gap between drops, and how near they must be to run together (GlassEffectContainer spacing).
        var gap: CGFloat { ["drops": 10, "puddle": 6, "blob": 2][rawValue] ?? 10 }
        var merge: CGFloat { ["drops": 6, "puddle": 18, "blob": 30][rawValue] ?? 6 }
    }

    static let key = "plug.liquid.runny"
    static let wholeKey = "plug.liquid.whole"   // the settings rail goes liquid too
    static let grow = 1.1                 // an open card's drop
    static let shine = 0.22               // its brightening

    // MARK: Logic

    func start(_ host: PipHost) throws { Self.apply(host) }

    /// Hands the host the bar's look; again whenever the setting changes.
    static func apply(_ host: PipHost) {
        let runny = Runny(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .drops
        let whole = UserDefaults.standard.object(forKey: wholeKey) as? Bool ?? true
        host.barLook = BarLook(owner: "liquid", gap: runny.gap, merge: runny.merge, wholeApp: whole,
            bar: { buttons in
                AnyView(GlassEffectContainer(spacing: runny.merge) { buttons }.padding(4))
            },
            button: { icon, open in
                AnyView(Drop(icon: icon, open: open, simpler: host.simpler))
            })
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { RunnyCard(host: host) }

    struct Drop: View {
        let icon: AnyView
        let open: Bool
        let simpler: Bool

        var body: some View {
            icon
                .glassEffect(.regular.tint(open ? .white.opacity(LiquidIcons.shine) : .clear).interactive(), in: .circle)
                .scaleEffect(open && !simpler ? LiquidIcons.grow : 1)
                .animation(simpler ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.55), value: open)
                .contentShape(.circle)
        }
    }

    struct RunnyCard: View {
        let host: PipHost
        @AppStorage(LiquidIcons.key) private var runny = Runny.drops.rawValue
        @AppStorage(LiquidIcons.wholeKey) private var whole = true

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("How runny").bold()
                HStack(spacing: 6) {
                    ForEach(Runny.allCases, id: \.self) { r in
                        Button(r.label) {
                            withAnimation(host.simpler ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.4)) {
                                runny = r.rawValue
                                LiquidIcons.apply(host)
                            }
                        }
                        .buttonStyle(PluginCardButton(on: runny == r.rawValue))
                        .accessibilityAddTraits(runny == r.rawValue ? .isSelected : [])
                    }
                }
                Toggle("Whole app", isOn: $whole)
                    .onChange(of: whole) { withAnimation(.easeOut(duration: 0.25)) { LiquidIcons.apply(host) } }
                Text("Press a drop to squish it.").foregroundStyle(.secondary)
            }
            .font(.system(size: 13.5))
        }
    }
}
