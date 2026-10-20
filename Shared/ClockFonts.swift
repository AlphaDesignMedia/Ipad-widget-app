import SwiftUI
import UIKit
import CoreText

/// Typefaces for the time. SF, New York and SF Mono ship with iPadOS (New York is also one of
/// the Lock Screen's clock fonts); Roboto Flex and Google Sans Flex are bundled
/// from Google Fonts (Shared/Fonts) under the SIL Open Font License, which allows using and
/// shipping them in an app for free. All four are variable fonts, so every slider position
/// between thin and heavy, or narrow and wide, is a real design rather than a stretched one.
enum ClockFont: String, Codable, CaseIterable, Identifiable {
    case sf, sfRounded, newYork, sfMono, robotoFlex, googleSansFlex
    var id: Self { self }

    var label: String {
        switch self {
        case .sf: "SF Pro"
        case .sfRounded: "SF Rounded"
        case .newYork: "New York"
        case .sfMono: "SF Mono"
        case .robotoFlex: "Roboto Flex"
        case .googleSansFlex: "Google Sans Flex"
        }
    }

    /// SF Rounded, New York and SF Mono come in one width only.
    var hasWidth: Bool { self == .sf || self == .robotoFlex || self == .googleSansFlex }
    var hasRoundness: Bool { self == .googleSansFlex }

    /// Weight, width and roundness are positions from 0 to 1 along each font's own range.
    /// 0.5 is always the font's regular weight and normal width.
    func font(size: CGFloat, weight: Double, width: Double, roundness: Double = 0) -> CTFont {
        switch self {
        case .sf, .sfRounded, .newYork, .sfMono:
            let font = UIFont.systemFont(
                ofSize: size,
                weight: UIFont.Weight(Self.blend(weight, -0.8, 0, 0.62)),
                width: UIFont.Width(Self.blend(
                    width,
                    Double(UIFont.Width.compressed.rawValue),
                    Double(UIFont.Width.standard.rawValue),
                    Double(UIFont.Width.expanded.rawValue)
                ))
            )
            let design: UIFontDescriptor.SystemDesign? = switch self {
            case .sfRounded: .rounded
            case .newYork: .serif
            case .sfMono: .monospaced
            default: nil
            }
            // On iPadOS, asking for these designs at an in-between weight fails and quietly
            // returns plain SF (observed 2026-10-20). So fetch the design at regular weight, then
            // set its weight axis to the value SF itself uses for this weight.
            guard let design,
                  let regular = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(design)
            else { return font as CTFont }
            let designed = UIFont(descriptor: regular, size: size) as CTFont
            let wght = NSNumber(value: Self.tag("wght"))
            guard let weightAxis = (CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber])?[wght]
            else { return designed }
            let varied = CTFontDescriptorCreateCopyWithAttributes(
                CTFontCopyFontDescriptor(designed),
                [kCTFontVariationAttribute: [wght: weightAxis]] as CFDictionary
            )
            return CTFontCreateWithFontDescriptor(varied, size, nil)
        case .robotoFlex:
            return Self.variable(Self.robotoFlexFile, size: size, axes: [
                "wght": Self.blend(weight, 100, 400, 1000),
                "wdth": Self.blend(width, 25, 100, 151),
                "opsz": 144,   // the display cut, drawn for large sizes
            ])
        case .googleSansFlex:
            return Self.variable(Self.googleSansFlexFile, size: size, axes: [
                "wght": Self.blend(weight, 100, 400, 1000),
                "wdth": Self.blend(width, 25, 100, 151),
                "opsz": 144,
                "ROND": 100 * roundness,
            ])
        }
    }

    /// 0 → low, 0.5 → middle, 1 → high, in a straight line either side of the middle.
    private static func blend(_ t: Double, _ low: Double, _ middle: Double, _ high: Double) -> Double {
        t < 0.5 ? low + (middle - low) * t * 2 : middle + (high - middle) * (t - 0.5) * 2
    }

    private static let robotoFlexFile = descriptor(named: "RobotoFlex")
    private static let googleSansFlexFile = descriptor(named: "GoogleSansFlex")

    private static func descriptor(named name: String) -> CTFontDescriptor? {
        let url = Bundle.main.url(forResource: name, withExtension: "ttf")
            ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
        guard let url else { return nil }
        return (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
    }

    private static func variable(_ descriptor: CTFontDescriptor?, size: CGFloat, axes: [String: Double]) -> CTFont {
        guard let descriptor else { return UIFont.systemFont(ofSize: size) as CTFont }
        let variation = Dictionary(uniqueKeysWithValues: axes.map { (NSNumber(value: tag($0.key)), NSNumber(value: $0.value)) })
        let varied = CTFontDescriptorCreateCopyWithAttributes(
            descriptor,
            [kCTFontVariationAttribute: variation] as CFDictionary
        )
        return CTFontCreateWithFontDescriptor(varied, size, nil)
    }

    /// An OpenType axis tag such as "wght" as the number Core Text expects.
    private static func tag(_ string: String) -> UInt32 {
        string.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
}

/// A line of text as one vector outline, y pointing down, with the left of the baseline at 0.
///
/// The clock is drawn as a shape rather than `Text` because SwiftUI draws large text in tiles
/// and works out inner shadows tile by tile, which left straight seams across the glass digits
/// (reproduced 2026-10-20). A shape also gives the exact outline of the digits, so the clock
/// can be centred on what you see rather than on the text's line box.
struct GlyphLine {
    var path: CGPath
    /// Each character's outline on its own, in place, for drawing digits separately.
    var pieces: [(character: Character, path: CGPath)] = []
    /// The outline's bounds: the ink, not the line box.
    var bounds: CGRect { path.boundingBoxOfPath }

    /// - Parameters:
    ///   - tracking: extra space between letters, as a fraction of the font size.
    ///   - centersColons: moves colons to the vertical middle of the digits, as the Lock Screen does.
    init(_ string: String, font: CTFont, tracking: CGFloat = 0, centersColons: Bool = false) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: string,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
        ))
        let space = tracking * CTFontGetSize(font)
        var glyphs: [(path: CGPath, character: Character)] = []
        let characters = Array(string.utf16)
        var index = 0

        for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
            let count = CTRunGetGlyphCount(run)
            var ids = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var stringIndices = [CFIndex](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(), &ids)
            CTRunGetPositions(run, CFRange(), &positions)
            CTRunGetStringIndices(run, CFRange(), &stringIndices)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName as String].map { $0 as! CTFont } ?? font

            for i in 0..<count {
                // Core Text's y points up; flip it so the outline matches SwiftUI.
                var transform = CGAffineTransform(
                    a: 1, b: 0, c: 0, d: -1,
                    tx: positions[i].x + space * CGFloat(index), ty: -positions[i].y
                )
                index += 1
                guard let glyph = CTFontCreatePathForGlyph(runFont, ids[i], &transform) else { continue }
                let unit = stringIndices[i] < characters.count ? characters[stringIndices[i]] : 0
                glyphs.append((glyph, Character(UnicodeScalar(unit) ?? " ")))
            }
        }

        let digits = glyphs.filter { $0.character != ":" }
            .reduce(CGRect.null) { $0.union($1.path.boundingBoxOfPath) }
        let combined = CGMutablePath()
        for glyph in glyphs {
            var piece = glyph.path
            if centersColons && glyph.character == ":" && !digits.isNull {
                var shift = CGAffineTransform(translationX: 0, y: digits.midY - glyph.path.boundingBoxOfPath.midY)
                piece = glyph.path.copy(using: &shift) ?? glyph.path
            }
            combined.addPath(piece)
            pieces.append((glyph.character, piece))
        }
        // Tight spacing makes neighbouring digits overlap. Merging the outlines stops the
        // overlap drawing twice (darker) in see-through styles.
        path = combined.normalized()
    }
}
