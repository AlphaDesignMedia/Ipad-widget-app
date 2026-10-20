import SwiftUI
import WidgetKit
import CoreText

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
    /// `unit` is the digits' on-screen height divided by 100, so the lit edges keep the same
    /// proportions in every widget size.
    func textStyle(in colorScheme: ColorScheme, accented: Bool = false, unit: CGFloat = 1) -> AnyShapeStyle {
        let k = max(0.6, unit)
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
            // bends light away, and a soft glow inside. A shadow underneath is the Shadow light
            // effect (see `LightLayer`).
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
                    .shadow(.inner(color: .white, radius: 0.5 * k, x: 1.5 * k, y: 1.5 * k))
                    .shadow(.inner(color: .white.opacity(0.6), radius: 6 * k, x: -3 * k, y: -3 * k))
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
                .shadow(.inner(color: .white, radius: 0.5 * k, x: 1.5 * k, y: 1.5 * k))
                .shadow(.inner(color: .black.opacity(light ? 0.45 : 0.35), radius: 1 * k, x: -1.5 * k, y: -2 * k))
                .shadow(.inner(color: .white.opacity(0.6), radius: 6 * k, x: -3 * k, y: -3 * k))
            )
        }
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

/// The time and its detail line (AM/PM, date) as outlines, laid out and fitted together into
/// the space available. The group is centred on its visible ink rather than on the text's line
/// box, which has room for descenders the digits don't have, so the clock sits in the optical
/// middle of the card.
struct ClockArtwork {
    var time = Path()
    var detail = Path()
    /// The digits' on-screen height divided by 100, for scaling lines, blurs and offsets.
    var unit: CGFloat = 1

    init(date: Date, style: ClockStyle, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let font = style.font.font(size: 100, weight: style.fontWeight, width: style.fontWidth, roundness: style.roundness)
        let text = style.timeText(date)
        let line = GlyphLine(text, font: font, tracking: style.spacing, centersColons: true)

        // Sized from tabular zeros, the widest digits, so the clock keeps its size as the
        // minutes change, and only the centring moves.
        let template = GlyphLine(
            String(text.map { $0.isNumber ? "0" : $0 }),
            font: Self.tabular(font), tracking: style.spacing, centersColons: true
        )
        let digitHeight = template.bounds.height
        guard digitHeight > 0 else { return }

        // Stretch, then move the ink's top-left corner to 0,0.
        let ink = line.bounds
        var stretch = CGAffineTransform(translationX: -ink.minX, y: 0)
            .scaledBy(x: 1, y: style.height)
            .translatedBy(x: 0, y: -ink.minY)
        var time = Path(line.path.copy(using: &stretch) ?? line.path)
        let timeSize = CGSize(width: ink.width, height: ink.height * style.height)
        let sizingWidth = max(timeSize.width, template.bounds.width)

        var detail = Path()
        let detailFont = style.font.font(
            size: 100,
            weight: 0.55 + (style.fontWeight - 0.5) * 0.4,
            width: 0.5,
            roundness: style.roundness
        )
        let capHeight = CTFontGetCapHeight(detailFont)
        let ampm = style.ampmText(date)

        /// Places `string` scaled to `cap` cap height with its baseline at `baseline`.
        func place(_ string: String, cap: CGFloat, tracking: CGFloat = 0, x: (CGFloat) -> CGFloat, baseline: CGFloat) {
            let glyphs = GlyphLine(string, font: detailFont, tracking: tracking)
            let k = cap / capHeight
            let width = glyphs.bounds.width * k
            var t = CGAffineTransform(translationX: x(width) - glyphs.bounds.minX * k, y: baseline)
                .scaledBy(x: k, y: k)
            if let placed = glyphs.path.copy(using: &t) { detail.addPath(Path(placed)) }
        }

        // Beside the time: small and lined up with the top of the digits, or as two letters
        // stacked to the full height of the digits.
        let gap = 0.08 * digitHeight
        let letters = ampm.map { Array($0.uppercased().filter(\.isLetter)) } ?? []
        if style.ampm == .stacked, letters.count == 2 {
            let cap = (timeSize.height - 0.12 * timeSize.height) / 2
            for (i, letter) in letters.enumerated() {
                place(String(letter), cap: cap,
                      x: { timeSize.width + gap + (cap * 0.9 - $0) / 2 },
                      baseline: i == 0 ? cap : timeSize.height)
            }
        } else if let ampm, style.ampm == .beside || style.ampm == .stacked {
            let cap = 0.24 * digitHeight
            place(ampm.uppercased(), cap: cap, tracking: 0.04, x: { _ in timeSize.width + gap }, baseline: cap)
        }

        // A line underneath, letter-spaced like the Lock Screen's date.
        let below = [style.ampm == .below ? ampm : nil, style.showDate ? style.dateText(date) : nil]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
        if !below.isEmpty {
            let cap = 0.15 * digitHeight
            place(below.uppercased(), cap: cap, tracking: 0.12,
                  x: { timeSize.width / 2 - $0 / 2 },
                  baseline: timeSize.height + 0.16 * digitHeight + cap)
        }

        // Fit the sizing box with a little breathing room, centre the actual ink.
        let timeBox = CGRect(origin: .zero, size: timeSize)
        let actual = detail.isEmpty ? timeBox : timeBox.union(detail.boundingRect)
        let sizing = actual.union(timeBox.insetBy(dx: (timeSize.width - sizingWidth) / 2, dy: 0))
        let scale = 0.92 * min(size.width / sizing.width, size.height / sizing.height)
        let fit = CGAffineTransform(
            translationX: size.width / 2 - actual.midX * scale,
            y: size.height / 2 - actual.midY * scale
        ).scaledBy(x: scale, y: scale)
        time = time.applying(fit)
        self.time = time
        self.detail = detail.applying(fit)
        unit = digitHeight * scale / 100
    }

    var combined: Path {
        var path = time
        path.addPath(detail)
        return path
    }

    private static func tabular(_ font: CTFont) -> CTFont {
        let features: [[CFString: Any]] = [[kCTFontOpenTypeFeatureTag: "tnum", kCTFontOpenTypeFeatureValue: 1]]
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFeatureSettingsAttribute: features] as CFDictionary)
        return CTFontCreateCopyWithAttributes(font, 0, nil, descriptor)
    }
}

/// A precomputed outline as a shape. `ClockArtwork` already fitted it to the view's size.
private struct OutlineShape: Shape {
    var path: Path
    func path(in rect: CGRect) -> Path { path }
}

/// The glow or shadow behind the text, drawn from blurred copies of the outline so it stays
/// strong even when the text itself is see-through.
private struct LightLayer: View {
    var artwork: ClockArtwork
    var style: ClockStyle

    var body: some View {
        let shape = OutlineShape(path: artwork.combined)
        let u = artwork.unit
        let color = style.resolvedEffectColor
        switch style.effect {
        case .none:
            EmptyView()
        case .glow:
            ZStack {
                shape.fill(color).blur(radius: u * (2 + 10 * style.effectSize))
                shape.fill(color).blur(radius: u * (8 + 40 * style.effectSize)).opacity(0.8)
            }
            .opacity(style.effectStrength)
        case .shadow:
            shape.fill(color)
                .blur(radius: u * (1 + 14 * style.effectSize))
                .offset(y: u * 24 * style.effectDistance)
                .opacity(style.effectStrength)
        }
    }
}

/// The clock itself. Used by both the widget and the in-app preview, so they always match.
struct ClockFace: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    var date: Date
    var style: ClockStyle

    var body: some View {
        GeometryReader { geometry in
            let artwork = ClockArtwork(date: date, style: style, size: geometry.size)
            // In Clear/Tinted mode the system keeps only transparency, so coloured light
            // would turn into a pale halo there.
            let accented = renderingMode == .accented
            ZStack {
                if !accented {
                    LightLayer(artwork: artwork, style: style)
                }
                lettering(artwork.time, unit: artwork.unit, accented: accented)
                    .widgetAccentable()
                lettering(artwork.detail, unit: artwork.unit, accented: accented)
                    .opacity(0.85)
            }
            .opacity(style.textOpacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date, style: .time))
    }

    private func lettering(_ path: Path, unit: CGFloat, accented: Bool) -> some View {
        let shape = OutlineShape(path: path)
        return shape
            .fill(style.textStyle(in: colorScheme, accented: accented, unit: unit))
            .overlay {
                // Colour glowing inward from the edges, on its own.
                if let inner = style.innerColor, !accented {
                    shape.stroke(inner.color, lineWidth: unit * 9)
                        .blur(radius: unit * 4)
                        .clipShape(shape)
                        .opacity(style.innerStrength)
                }
            }
            .overlay {
                // Glass gets a crisp rim of light: bright on the upper left, fading, then
                // catching again on the lower right. Only the inner half of the stroke shows.
                if style.textFill == .glass {
                    shape.stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.9), location: 0),
                                .init(color: .white.opacity(0.15), location: 0.45),
                                .init(color: .white.opacity(0.55), location: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, 1.6 * unit) * 2
                    )
                    .clipShape(shape)
                }
            }
    }
}
