import SwiftUI

/// Moods (owner, 22 Oct 2026): each starting style on a backdrop that suits it, as small
/// pictures of the widget. A tap applies both, keeping locked parts; "Not in the mood" goes back
/// to the default style on Plain, locks or not.
///
/// The first version was slow to use: every tile was a live widget with a ticking clock and a
/// shimmer, drawn as part of the whole settings screen, so any change there redrew all of them.
/// This row is its own view that redraws only when its inputs change, and the pictures are still.
struct MoodRow: View, Equatable {
    var style: ClockStyle
    var locked: Set<StylePart>
    var backdrop: PreviewBackdrop
    var homeScreen: HomeScreenStyle
    var liftsBackdrops: Bool
    var apply: (ClockStyle, PreviewBackdrop) -> Void

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.style == b.style && a.locked == b.locked && a.backdrop == b.backdrop
            && a.homeScreen == b.homeScreen && a.liftsBackdrops == b.liftsBackdrops
    }

    private static let scenes: [String: PreviewBackdrop] = [
        "Bold glass": .aurora, "Lock Screen": .ocean, "Neon": .midnight, "Minimal": .dune, "Stacked serif": .sunset,
    ]
    static let moods = ClockStyle.presets.map { (name: $0.name, style: $0.style, scene: scenes[$0.name] ?? .aurora) }
        + [(name: "Not in the mood", style: ClockStyle(), scene: .plain)]
    /// The pictures show 10:09 rather than the time, so they never need redrawing to tick.
    private static let shownTime = Calendar.current.date(bySettingHour: 10, minute: 9, second: 0, of: .now) ?? .now

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Self.moods, id: \.name) { mood in
                    let resets = mood.scene == .plain
                    // What a tap would give, locks and all, so the picture matches the result.
                    let result = style.taking(Set(StylePart.allCases).subtracting(resets ? [] : locked), from: mood.style)
                    let chosen = style == result && backdrop == mood.scene
                    Button { apply(result, mood.scene) } label: {
                        VStack(spacing: 6) {
                            picture(result, on: mood.scene)
                                .overlay(alignment: .topTrailing) {
                                    if resets {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.caption.weight(.bold))
                                            .padding(6)
                                            .background(.ultraThinMaterial, in: .circle)
                                            .padding(6)
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(.primary.opacity(chosen ? 0.6 : 0.2), lineWidth: chosen ? 2.5 : 1)
                                }
                                .scaleEffect(chosen ? 1 : 0.96)
                            Text(mood.name)
                                .font(.footnote.weight(chosen ? .semibold : .regular))
                                .foregroundStyle(chosen ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(resets ? "Not in the mood: the default style on Plain" : mood.name + " mood")
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                    .animation(.snappy(duration: 0.3), value: chosen)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: backdrop)
    }

    /// The backdrop with a small widget in that style on it, drawn at full size and scaled down
    /// so its proportions match the real widget.
    private func picture(_ mood: ClockStyle, on scene: PreviewBackdrop) -> some View {
        BackdropFill(backdrop: scene, homeScreen: homeScreen, lifted: liftsBackdrops)
            .frame(width: 104, height: 104)
            .overlay {
                ClockFace(date: Self.shownTime, style: mood, simulatedAccent: homeScreen.accent,
                          simulatesClear: !homeScreen.showsKeptColours)
                    .padding(14)
                    .frame(width: 150, height: 150)
                    .modifier(ClockCard(style: mood, shape: .rect(cornerRadius: 26), homeScreen: homeScreen))
                    .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
                    .scaleEffect(0.5)
                    .frame(width: 75, height: 75)
            }
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)
    }
}
