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
            // Automatic glass is dark on light backgrounds and white on dark ones, like text.
            let body = color == .auto ? (light ? Color(white: 0.15) : .white) : color.color
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

/// The card behind the clock in the in-app preview: Liquid Glass or a solid colour, or for a
/// Clear/Tinted Home Screen, the system's glass (unless the card keeps its colours).
struct ClockCard<S: Shape>: ViewModifier {
    var style: ClockStyle
    var shape: S
    var homeScreen: HomeScreenStyle = .light

    func body(content: Content) -> some View {
        if homeScreen.accent != nil {
            content.background {
                ZStack {
                    Color.clear.glassEffect(homeScreen.cardTint.map { .regular.tint($0.opacity(0.7)) } ?? .clear, in: shape)
                    if style.keepsCardColours && homeScreen.showsKeptColours {
                        GeometryReader { geometry in
                            Image(uiImage: ClockRaster.card(style: style, size: geometry.size, dark: false))
                                .resizable()
                        }
                        .clipShape(shape)
                    }
                }
            }
        } else {
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
}

/// The time and its detail line (AM/PM, date) as outlines, laid out and fitted together into
/// the space available. The group is centred on its visible ink rather than on the text's line
/// box, which has room for descenders the digits don't have, so the clock sits in the optical
/// middle of the card.
struct ClockArtwork {
    var time = Path()
    var detail = Path()
    /// The time's characters separately, in place. Kept-colour images are drawn per
    /// character so each digit's image can be reused every minute (see `ClockRaster`).
    var timeGlyphs: [(character: Character, path: Path)] = []
    /// The digits' on-screen height divided by 100, for scaling lines, blurs and offsets.
    var unit: CGFloat = 1

    init(date: Date, style: ClockStyle, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let font = style.font.font(size: 100, weight: style.fontWeight, width: style.fontWidth, roundness: style.roundness)
        let text = style.timeText(date)
        var line = GlyphLine(text, font: font, tracking: style.spacing, centersColons: true)

        // Sized from tabular zeros, the widest digits, so the clock keeps its size as the
        // minutes change, and only the centring moves.
        var template = GlyphLine(
            String(text.map { $0.isNumber ? "0" : $0 }),
            font: Self.tabular(font), tracking: style.spacing, centersColons: true
        )
        // Softened corners, like the Lock Screen's glass digits: the outline is grown by a
        // round-cornered stroke, which rounds every outer corner.
        if style.softness > 0 {
            let width = 8 * style.softness   // in font units, at size 100
            line.path = Self.soften(line.path, by: width)
            template.path = Self.soften(template.path, by: width)
        }
        let digitHeight = template.bounds.height
        let ink = line.bounds
        guard digitHeight > 0, !ink.isEmpty else { return }
        let sizingWidth = max(ink.width, template.bounds.width)

        let detailFont = style.font.font(
            size: 100,
            weight: 0.55 + (style.fontWeight - 0.5) * 0.4,
            width: 0.5,
            roundness: style.roundness
        )
        let capHeight = CTFontGetCapHeight(detailFont)
        let ampm = style.ampmText(date)
        let letters = ampm.map { Array($0.uppercased().filter(\.isLetter)) } ?? []
        let stacked = style.ampm == .stacked && letters.count == 2
        let beside = ampm != nil && !stacked && (style.ampm == .beside || style.ampm == .stacked)
        let below = [style.ampm == .below ? ampm : nil, style.showDate && !style.dateAbove ? style.dateText(date) : nil]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
        // Above the time, the date is written normally, as on the Lock Screen.
        let above = style.showDate && style.dateAbove ? style.dateText(date) : ""

        // In a squarer card than the clock, stretch the digits taller to fill it, up to 1.6×.
        // The Height slider sets the minimum.
        let belowRatio: CGFloat = 0.15, besideRatio: CGFloat = 0.24, belowGap: CGFloat = 0.16
        let aboveScale: CGFloat = 0.7, aboveGap: CGFloat = 0.1
        let detailHeight = (below.isEmpty ? 0 : (belowGap + belowRatio) * digitHeight)
            + (above.isEmpty ? 0 : (aboveGap + belowRatio * aboveScale * 1.3) * digitHeight)
        let filling = (size.height / size.width * sizingWidth - detailHeight) / ink.height
        let stretch = max(style.height, style.fillsCard ? min(filling, 1.6) : 0)
        let timeSize = CGSize(width: ink.width, height: ink.height * stretch)

        /// Lays out the time and its detail at the given detail sizes (fractions of the
        /// digit height) and fits the group to `size`.
        // Stretch, then move the ink's top-left corner to 0,0.
        let stretchTransform = CGAffineTransform(translationX: -ink.minX, y: 0)
            .scaledBy(x: 1, y: stretch)
            .translatedBy(x: 0, y: -ink.minY)

        func layout(belowCap: CGFloat, besideCap: CGFloat)
            -> (time: Path, detail: Path, scale: CGFloat, fit: CGAffineTransform) {
            let time = Path(line.path).applying(stretchTransform)
            var detail = Path()

            /// Places `string` scaled to `cap` cap height with its baseline at `baseline`.
            func place(_ string: String, cap: CGFloat, tracking: CGFloat = 0, x: (CGFloat) -> CGFloat, baseline: CGFloat) {
                let glyphs = GlyphLine(string, font: detailFont, tracking: tracking)
                let k = cap / capHeight
                let width = glyphs.bounds.width * k
                var t = CGAffineTransform(translationX: x(width) - glyphs.bounds.minX * k, y: baseline)
                    .scaledBy(x: k, y: k)
                if let placed = glyphs.path.copy(using: &t) { detail.addPath(Path(placed)) }
            }

            // Beside the time: two letters stacked to the full height of the digits, or
            // small and lined up with the top of the digits.
            let gap = 0.08 * digitHeight
            if stacked {
                let cap = (timeSize.height - 0.12 * timeSize.height) / 2
                for (i, letter) in letters.enumerated() {
                    place(String(letter), cap: cap,
                          x: { timeSize.width + gap + (cap * 0.9 - $0) / 2 },
                          baseline: i == 0 ? cap : timeSize.height)
                }
            } else if let ampm, beside {
                let cap = besideCap * digitHeight
                place(ampm.uppercased(), cap: cap, tracking: 0.04, x: { _ in timeSize.width + gap }, baseline: cap)
            }

            // A line underneath, letter-spaced like the Lock Screen's date.
            if !below.isEmpty {
                let cap = belowCap * digitHeight
                place(below.uppercased(), cap: cap, tracking: 0.12,
                      x: { timeSize.width / 2 - $0 / 2 },
                      baseline: timeSize.height + belowGap * digitHeight + cap)
            }

            if !above.isEmpty {
                let cap = belowCap * aboveScale * digitHeight
                place(above, cap: cap, tracking: 0.01,
                      x: { timeSize.width / 2 - $0 / 2 },
                      baseline: -aboveGap * digitHeight)
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
            return (time.applying(fit), detail.applying(fit), scale, fit)
        }

        var result = layout(belowCap: belowRatio, besideCap: besideRatio)
        // Keep the small text readable: capitals at least 8 pt tall, which is about 11 pt
        // type, the HIG minimum for widgets. Relaid out once at the larger size.
        let minimumCap: CGFloat = 8
        let belowBoost = minimumCap / (belowRatio * digitHeight * result.scale)
        let besideBoost = minimumCap / (besideRatio * digitHeight * result.scale)
        if (!(below.isEmpty && above.isEmpty) && belowBoost > 1) || (beside && besideBoost > 1) {
            result = layout(belowCap: belowRatio * max(1, belowBoost), besideCap: besideRatio * max(1, besideBoost))
        }
        time = result.time
        detail = result.detail
        unit = digitHeight * result.scale / 100
        timeGlyphs = line.pieces.map { piece in
            let outline = style.softness > 0 ? Self.soften(piece.path, by: 8 * style.softness) : piece.path
            return (piece.character, Path(outline).applying(stretchTransform).applying(result.fit))
        }
    }

    var combined: Path {
        var path = time
        path.addPath(detail)
        return path
    }

    private static func soften(_ path: CGPath, by width: CGFloat) -> CGPath {
        path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 1).union(path)
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
    @Environment(\.displayScale) private var displayScale
    var date: Date
    var style: ClockStyle
    /// Set by the app's preview to imitate a Clear (white) or Tinted Home Screen, where the
    /// system draws every part that isn't a full-colour image in this one colour.
    var simulatedAccent: Color?
    /// Set with `simulatedAccent` for a Clear Home Screen, which ignores kept colours.
    var simulatesClear = false

    var body: some View {
        GeometryReader { geometry in
            let artwork = ClockArtwork(date: date, style: style, size: geometry.size)
            // In Clear/Tinted mode the system keeps only transparency, so coloured light
            // would turn into a pale halo there.
            let accented = renderingMode == .accented || simulatedAccent != nil
            ZStack {
                if !accented {
                    LightLayer(artwork: artwork, style: style)
                    lettering(artwork.time, unit: artwork.unit, accented: false)
                    lettering(artwork.detail, unit: artwork.unit, accented: false, plain: true)
                        .opacity(0.85)
                } else {
                    // Marking a kept part as the accent group would let the system tint it after all.
                    accentedPart(.time, keep: style.keepsTimeColours, artwork: artwork, size: geometry.size) {
                        lettering(artwork.time, unit: artwork.unit, accented: true)
                            .opacity(style.textOpacity)
                    }
                    .widgetAccentable(!style.keepsTimeColours)
                    accentedPart(.detail, keep: style.keepsDetailColours, artwork: artwork, size: geometry.size) {
                        lettering(artwork.detail, unit: artwork.unit, accented: true, plain: true)
                            .opacity(0.85 * style.textOpacity)
                    }
                }
            }
            .opacity(accented ? 1 : style.textOpacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date, style: .time))
    }

    /// A part of the clock on a Clear/Tinted Home Screen: drawn as a full-colour image if the
    /// person chose to keep its colours, otherwise left for the system to recolour.
    @ViewBuilder
    private func accentedPart(_ part: ClockRaster.Part, keep: Bool, artwork: ClockArtwork, size: CGSize,
                              @ViewBuilder content: () -> some View) -> some View {
        if keep && !simulatesClear && part == .time {
            // One image per character (see `ClockRaster`). The glow or shadow is left out:
            // with it, an hour of these images went over iPadOS's widget size limit.
            let dark = colorScheme == .dark
            let glyphs = artwork.timeGlyphs.map {
                ClockRaster.glyph($0.path, character: $0.character, unit: artwork.unit, style: style,
                                  scale: displayScale, dark: dark, withLight: false)
            }
            ZStack {
                ForEach(glyphs.indices, id: \.self) { i in
                    placed(glyphs[i].body.image, in: glyphs[i].body.area)
                }
            }
        } else if keep && !simulatesClear {
            let area = ClockRaster.area(of: part, artwork: artwork, style: style, in: size)
            if !area.isEmpty {
                Image(uiImage: ClockRaster.image(part, artwork: artwork, style: style, area: area, size: size,
                                                 scale: displayScale, dark: colorScheme == .dark))
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .frame(width: area.width, height: area.height)
                    .position(x: area.midX, y: area.midY)
            }
        } else if let simulatedAccent {
            simulatedAccent.mask(content())
        } else {
            content()
        }
    }

    private func placed(_ image: UIImage, in area: CGRect) -> some View {
        Image(uiImage: image)
            .resizable()
            .widgetAccentedRenderingMode(.fullColor)
            .frame(width: area.width, height: area.height)
            .position(x: area.midX, y: area.midY)
    }

    /// `plain` is for the small detail text: glass edges are too fine to read at that size,
    /// so glass text gets a clean light fill there instead.
    private func lettering(_ path: Path, unit: CGFloat, accented: Bool, plain: Bool = false) -> some View {
        let shape = OutlineShape(path: path)
        let glassDetail = plain && style.textFill == .glass
        let fill = glassDetail
            ? AnyShapeStyle((accented ? Color.white
                : style.color == .auto ? (colorScheme == .light ? Color(white: 0.15) : .white)
                : style.color.color).opacity(0.9))
            : style.textStyle(in: colorScheme, accented: accented, unit: unit)
        return shape
            .fill(fill)
            .overlay {
                // Colour glowing inward from the edges, on its own.
                if let inner = style.innerColor, !accented, !plain {
                    shape.stroke(inner.color, lineWidth: unit * 9)
                        .blur(radius: unit * 4)
                        .clipShape(shape)
                        .opacity(style.innerStrength)
                }
            }
            .overlay {
                // Glass gets a crisp rim of light: bright on the upper left, fading, then
                // catching again on the lower right. Only the inner half of the stroke shows.
                if style.textFill == .glass && !plain {
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
