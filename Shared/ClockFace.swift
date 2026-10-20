import SwiftUI
import WidgetKit

extension ClockStyle {
    /// The preview card's Liquid Glass. Transparency moves from no card, through clear glass,
    /// to regular glass, instead of fading the glass with `opacity`. A chosen colour is a tint
    /// whose strength follows the slider, so the card stays glass rather than flat paint.
    var glass: Glass {
        guard cardOpacity > 0 else { return .identity }
        let base: Glass = usesClearGlass ? .clear : .regular
        guard let cardTint else { return base }
        return base.tint(cardTint.opacity(0.15 + 0.35 * cardOpacity))
    }

    /// Clear glass is for the see-through end of the slider. It needs a dimming layer (HIG: Materials).
    var usesClearGlass: Bool {
        cardOpacity > 0 && cardOpacity < 0.4
    }

    var solidFill: Color {
        cardTint ?? Color(.systemBackground)
    }

    /// The fill for the clock's text. Glass reads differently on light and dark glass behind it,
    /// and in Clear/Tinted (`accented`) mode, where the system keeps only transparency.
    func textStyle(in colorScheme: ColorScheme, accented: Bool = false) -> AnyShapeStyle {
        switch textFill {
        case .solid:
            return AnyShapeStyle(color.color)
        case .gradient:
            return AnyShapeStyle(LinearGradient(
                colors: [color.color, gradientColor.color],
                startPoint: .top,
                endPoint: .bottom
            ))
        case .glass:
            // Widgets can't apply real Liquid Glass to text, so this imitates the Lock Screen
            // numerals: a see-through body with a trace of the chosen colour, a crisp rim of
            // light on the upper-left edges, a darker edge on the lower right where the glass
            // bends light away, and a soft glow inside. The shadow underneath is its own layer
            // (see `ClockFace`), because a shadow drawn from a see-through fill is too faint.
            if accented {
                // Colour is replaced by the system's, so the glass is made of transparency
                // alone: a frosted body, a solid rim and a soft inner glow. A dark edge would
                // turn into a second light edge here, so it's left out.
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.22), .white.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .shadow(.inner(color: .white, radius: 0.5, x: 1.5, y: 1.5))
                    .shadow(.inner(color: .white.opacity(0.6), radius: 6, x: -3, y: -3))
                )
            }
            let light = colorScheme == .light
            let body = color == .auto ? Color.white : color.color
            return AnyShapeStyle(
                LinearGradient(
                    colors: [body.opacity(0.5), body.opacity(0.18), body.opacity(0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .shadow(.inner(color: .white, radius: 0.5, x: 1.5, y: 1.5))
                .shadow(.inner(color: .black.opacity(light ? 0.45 : 0.35), radius: 1, x: -1.5, y: -2))
                .shadow(.inner(color: .white.opacity(0.6), radius: 6, x: -3, y: -3))
            )
        }
    }
}

/// Adds the optional neon glow.
private struct TextEffects: ViewModifier {
    var style: ClockStyle

    func body(content: Content) -> some View {
        content
            .shadow(color: style.color.color.opacity(style.glow ? 0.9 : 0), radius: 6)
            .shadow(color: style.color.color.opacity(style.glow ? 0.6 : 0), radius: 18)
    }
}

/// Stretches its content vertically by `factor` while still fitting the space it's given:
/// the content is laid out at a fraction of the height, then scaled up to fill it.
private struct VerticalStretch: Layout {
    var factor: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let size = child.sizeThatFits(squashed(proposal))
        return CGSize(width: size.width, height: size.height * factor)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: squashed(proposal)
        )
    }

    private func squashed(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: proposal.width, height: proposal.height.map { $0 / factor })
    }
}

/// The card behind the clock in the in-app preview: Liquid Glass or a solid colour.
struct ClockCard<S: Shape>: ViewModifier {
    var style: ClockStyle
    var shape: S

    func body(content: Content) -> some View {
        switch style.background {
        case .glass:
            // Glass sits behind the text so the text keeps its exact colour.
            content.background {
                ZStack {
                    if style.usesClearGlass {
                        shape.fill(.black.opacity(0.2))
                    }
                    Color.clear.glassEffect(style.glass, in: shape)
                }
            }
        case .solid:
            content.background(style.solidFill.opacity(style.cardOpacity), in: shape)
        }
    }
}

/// The clock itself. Used by both the widget and the in-app preview, so they always match.
struct ClockFace: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    var date: Date
    var style: ClockStyle
    var family: WidgetFamily?

    private var dateFont: Font {
        switch family {
        case .systemSmall: .caption.weight(.semibold)
        case .systemMedium: .subheadline.weight(.semibold)
        case .systemLarge: .title3.weight(.semibold)
        default: .title2.weight(.semibold)
        }
    }

    var body: some View {
        face
            .foregroundStyle(style.textStyle(in: colorScheme, accented: renderingMode == .accented))
            .background {
                // Glass digits cast a soft shadow onto the card, which is what lifts them off it.
                // Left out in Clear/Tinted mode, where it would turn into a pale halo.
                if style.textFill == .glass && renderingMode != .accented {
                    face
                        .foregroundStyle(.black.opacity(colorScheme == .light ? 0.22 : 0.35))
                        .blur(radius: 4)
                        .offset(y: 3)
                }
            }
            .modifier(TextEffects(style: style))
            .opacity(style.textOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var face: some View {
        VStack(spacing: 0) {
            if style.showDate {
                Text(style.dateText(date))
                    .font(dateFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(0.85)
            }

            VerticalStretch(factor: style.height) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(style.timeText(date))
                        .font(style.font(size: 300))
                        .monospacedDigit()
                    if let ampm = style.ampmText(date) {
                        Text(ampm)
                            .font(dateFont)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.05)
                .scaleEffect(x: 1, y: style.height)
            }
            .widgetAccentable()
        }
    }
}
