import SwiftUI
import UIKit
import Security

/// Storage the app and the widget can both see.
/// Normally an App Group. Free (Personal Team) signing doesn't allow App Groups, so those
/// builds share a keychain access group instead; see Config/FreeTeam.entitlements.
enum SharedStore {
    static let appGroupID = "group.com.aarondennel.glassclock"

    private static var appGroup: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
        else { return nil }
        return UserDefaults(suiteName: appGroupID)
    }

    static func data(forKey key: String) -> Data? {
        if let appGroup { return appGroup.data(forKey: key) }
        var query = keychainQuery(key)
        query[kSecReturnData] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func set(_ data: Data, forKey key: String) {
        if let appGroup { return appGroup.set(data, forKey: key) }
        let query = keychainQuery(key)
        let update = [kSecValueData: data] as CFDictionary
        if SecItemUpdate(query as CFDictionary, update) == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            // Readable while the iPad is locked, so the widget can still redraw.
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    /// No access group is named: the keychain uses the first one in the entitlements,
    /// which is the same for the app and the widget.
    private static func keychainQuery(_ key: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: appGroupID,
         kSecAttrAccount: key]
    }
}

enum TimeFormat: String, Codable, CaseIterable, Identifiable {
    case system, twelve, twentyFour
    var id: Self { self }

    var label: String {
        switch self {
        case .system: "Automatic"
        case .twelve: "12-hour"
        case .twentyFour: "24-hour"
        }
    }
}

enum CardBackground: String, Codable, CaseIterable, Identifiable {
    case glass, solid
    var id: Self { self }

    var label: String {
        switch self {
        case .glass: "Liquid Glass"
        case .solid: "Solid"
        }
    }
}

/// Digits, or a dial with hands. Both are drawn as outlines, so every fill, light and
/// Home Screen option works the same on either.
enum ClockFaceKind: String, Codable, CaseIterable, Identifiable {
    case digital, analog
    var id: Self { self }

    var label: String {
        switch self {
        case .digital: "Digital"
        case .analog: "Analog"
        }
    }
}

enum TextFill: String, Codable, CaseIterable, Identifiable {
    case solid, gradient, glass
    var id: Self { self }

    var label: String {
        switch self {
        case .solid: "Solid"
        case .gradient: "Gradient"
        case .glass: "Liquid Glass"
        }
    }
}

/// A colour for part of the clock: one of the named colours, or any colour at all from the
/// colour wheel (owner, 22 Oct 2026: "give as many options as the person wants"), saved as
/// "#RRGGBB". Saved as a plain string either way, so styles saved before still open.
struct ClockColor: RawRepresentable, Codable, Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }

    static let auto = ClockColor(named: "auto"), white = ClockColor(named: "white")
    static let black = ClockColor(named: "black"), red = ClockColor(named: "red")
    static let orange = ClockColor(named: "orange"), yellow = ClockColor(named: "yellow")
    static let green = ClockColor(named: "green"), mint = ClockColor(named: "mint")
    static let blue = ClockColor(named: "blue"), purple = ClockColor(named: "purple")
    /// The named colours, in the order the swatches show them.
    static let allCases: [ClockColor] = [.auto, .white, .black, .red, .orange, .yellow, .green, .mint, .blue, .purple]

    private init(named: String) { rawValue = named }

    init?(rawValue: String) {
        guard Self.allCases.contains(where: { $0.rawValue == rawValue }) || Self.rgb(rawValue) != nil else { return nil }
        self.rawValue = rawValue
    }

    /// Any colour, from its red, green and blue (0…1).
    init(red: Double, green: Double, blue: Double) {
        func byte(_ v: Double) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        rawValue = String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ClockColor(rawValue: raw) ?? .auto
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Whether this came from the colour wheel rather than the named swatches.
    var isCustom: Bool { rawValue.hasPrefix("#") }

    /// Whether it reads as a dark colour (by its brightness to the eye); nil for Automatic,
    /// which is dark or light with the Home Screen.
    var isDark: Bool? {
        guard self != .auto else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
        return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.4
    }

    /// A name for VoiceOver.
    var name: String { isCustom ? "Custom colour" : rawValue.capitalized }

    var color: Color {
        if let rgb = Self.rgb(rawValue) { return Color(red: rgb.0, green: rgb.1, blue: rgb.2) }
        switch rawValue {
        case "white": return .white
        case "black": return .black
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "blue": return .blue
        case "purple": return .purple
        default: return .primary
        }
    }

    private static func rgb(_ raw: String) -> (Double, Double, Double)? {
        guard raw.hasPrefix("#"), raw.count == 7, let value = Int(raw.dropFirst(), radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }
}

/// The Home Screen styles iPadOS offers, for previewing the widget in each.
enum HomeScreenStyle: String, CaseIterable, Identifiable {
    case light = "Light", dark = "Dark", clear = "Clear", tinted = "Tinted"
    var id: Self { self }

    /// The colour the system draws content in: white in both Clear and Tinted
    /// (observed in the iPadOS 26.5 simulator, References/simulator/08 and 09).
    var accent: Color? {
        self == .clear || self == .tinted ? .white : nil
    }

    /// Whether parts drawn as full-colour images keep their colours here. iPadOS 26 puts its
    /// glass over every image on a Clear Home Screen anyway (observed in the 26.5 simulator,
    /// 2026-10-20, even with a plain bundled red image); iPadOS 27 shows them in colour
    /// (red test images confirmed on the iPad, 2026-10-20).
    var showsKeptColours: Bool {
        self != .clear || ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

    /// The colour of the system's glass card in Tinted mode (an example tint).
    var cardTint: Color? {
        self == .tinted ? Color(red: 0.2, green: 0.35, blue: 0.85) : nil
    }
}

/// Where AM/PM goes, in 12-hour time.
enum AMPMPlacement: String, Codable, CaseIterable, Identifiable {
    case hidden, below, beside, stacked
    var id: Self { self }

    var label: String {
        switch self {
        case .hidden: "Hidden"
        case .below: "Below"
        case .beside: "Beside"
        case .stacked: "Stacked"
        }
    }
}

/// Everything the user can customise. Font weight, width and roundness are 0–1 positions
/// along the chosen font's own variable axes (0.5 is regular weight and normal width).
struct ClockStyle: Codable, Equatable {
    /// Digital or analog. Like the time format, it's the person's own choice, so presets and
    /// Lucky leave it alone.
    var face: ClockFaceKind = .digital
    var font: ClockFont = .robotoFlex
    var fontWeight: Double = 0.85
    var fontWidth: Double = 0.3
    var roundness: Double = 1
    /// The font for the AM/PM and date line.
    var detailFont: DetailFont = .paired
    /// Extra space between digits, as a fraction of the font size. Negative tightens.
    var spacing: Double = 0
    /// Vertical stretch of the time: 1 is normal, 2 is twice as tall.
    var height: Double = 1
    /// Stretches the digits taller in square cards so they fill the space.
    var fillsCard = true
    /// Makes the digits a little heavier and wider in small widgets, where thin strokes get
    /// hard to read, the way optical sizes do in type design.
    var adaptsToSize = true
    /// Rounds the digits' outer corners, 0–1.
    var softness: Double = 0
    var color: ClockColor = .auto
    var timeFormat: TimeFormat = .system
    var showDate = false
    /// The date above the time, as on the Lock Screen, instead of in the line below.
    var dateAbove = false
    var ampm: AMPMPlacement = .below
    var background: CardBackground = .glass
    var backgroundColor: ClockColor = .auto
    var textFill: TextFill = .glass
    var gradientColor: ClockColor = .purple
    /// 1 is fully opaque.
    var textOpacity: Double = 1
    var cardOpacity: Double = 1

    /// A glow of colour around the text. Glow and shadow are separate, so both can be on.
    var glow = false
    /// Automatic: the text colour.
    var glowColor: ClockColor = .auto
    /// How far the glow spreads, 0–1.
    var glowSize: Double = 0.4
    var glowStrength: Double = 0.7

    /// A shadow cast onto the card.
    var shadow = true
    /// Automatic: black.
    var shadowColor: ClockColor = .auto
    /// How soft the shadow is, 0–1.
    var shadowSize: Double = 0.4
    var shadowStrength: Double = 0.5
    /// How far the shadow falls from the text, 0–1.
    var shadowDistance: Double = 0.4
    /// The direction the shadow falls, in degrees: 90 is straight down, 0 is to the right.
    var shadowAngle: Double = 90
    static let shadowAngleRange = 45.0...135.0
    static let shadowStrengthRange = 0.15...0.65

    /// The AM/PM and date line: its size and gap to the time (1 is the standard) and its
    /// letter spacing (added to the font's own).
    var detailSize: Double = 1
    var detailGap: Double = 1
    var detailTracking: Double = 0

    /// Colour glowing inside the digits from their edges, on its own rather than as a
    /// side effect of the outer glow. Nil is off.
    var innerColor: ClockColor?
    var innerStrength: Double = 0.6

    /// On Clear and Tinted Home Screens, keep these parts in the person's own colours instead
    /// of letting iPadOS recolour them.
    var keepsTimeColours = false
    var keepsDetailColours = false
    var keepsCardColours = false

    init() {}

    /// Missing keys fall back to defaults, so adding a setting never wipes saved styles.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClockStyle()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        face = try value(.face, d.face)
        font = try value(.font, d.font)
        fontWeight = try value(.fontWeight, d.fontWeight)
        fontWidth = try value(.fontWidth, d.fontWidth)
        roundness = try value(.roundness, d.roundness)
        detailFont = try value(.detailFont, d.detailFont)
        spacing = try value(.spacing, d.spacing)
        height = try value(.height, d.height)
        fillsCard = try value(.fillsCard, d.fillsCard)
        adaptsToSize = try value(.adaptsToSize, d.adaptsToSize)
        softness = try value(.softness, d.softness)
        dateAbove = try value(.dateAbove, d.dateAbove)
        color = try value(.color, d.color)
        timeFormat = try value(.timeFormat, d.timeFormat)
        showDate = try value(.showDate, d.showDate)
        ampm = try value(.ampm, d.ampm)
        background = try value(.background, d.background)
        backgroundColor = try value(.backgroundColor, d.backgroundColor)
        textFill = try value(.textFill, d.textFill)
        gradientColor = try value(.gradientColor, d.gradientColor)
        textOpacity = try value(.textOpacity, d.textOpacity)
        cardOpacity = try value(.cardOpacity, d.cardOpacity)
        glow = try value(.glow, d.glow)
        glowColor = try value(.glowColor, d.glowColor)
        glowSize = try value(.glowSize, d.glowSize)
        glowStrength = try value(.glowStrength, d.glowStrength)
        shadow = try value(.shadow, d.shadow)
        shadowColor = try value(.shadowColor, d.shadowColor)
        shadowSize = try value(.shadowSize, d.shadowSize)
        shadowStrength = try value(.shadowStrength, d.shadowStrength)
        shadowDistance = try value(.shadowDistance, d.shadowDistance)
        shadowAngle = try value(.shadowAngle, d.shadowAngle)
        detailSize = try value(.detailSize, d.detailSize)
        detailGap = try value(.detailGap, d.detailGap)
        detailTracking = try value(.detailTracking, d.detailTracking)
        // Styles saved before glow and shadow were separate had one "effect".
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        if !c.contains(.glow), let effect = try legacy.decodeIfPresent(String.self, forKey: .effect) {
            let color = try legacy.decodeIfPresent(ClockColor.self, forKey: .effectColor) ?? .auto
            let size = try legacy.decodeIfPresent(Double.self, forKey: .effectSize) ?? 0.4
            let strength = try legacy.decodeIfPresent(Double.self, forKey: .effectStrength) ?? 0.5
            glow = effect == "glow"
            shadow = effect == "shadow"
            if glow { (glowColor, glowSize, glowStrength) = (color, size, strength) }
            if shadow {
                (shadowColor, shadowSize, shadowStrength) = (color, size, strength)
                shadowDistance = try legacy.decodeIfPresent(Double.self, forKey: .effectDistance) ?? 0.4
            }
        }
        innerColor = try c.decodeIfPresent(ClockColor.self, forKey: .innerColor)
        innerStrength = try value(.innerStrength, d.innerStrength)
        keepsTimeColours = try value(.keepsTimeColours, d.keepsTimeColours)
        keepsDetailColours = try value(.keepsDetailColours, d.keepsDetailColours)
        keepsCardColours = try value(.keepsCardColours, d.keepsCardColours)
    }

    private enum LegacyKeys: String, CodingKey {
        case effect, effectColor, effectSize, effectStrength, effectDistance
    }

    /// Starting points people can pick and then adjust.
    static let presets: [(name: String, style: ClockStyle)] = [
        ("Bold glass", ClockStyle()),
        // Matched to the iPadOS 26 Lock Screen clock (References/simulator/11).
        ("Lock Screen", ClockStyle().with {
            $0.font = .sf; $0.fontWeight = 0.8; $0.fontWidth = 0.5; $0.spacing = -0.015
            $0.softness = 0.5; $0.fillsCard = false
            $0.textFill = .glass; $0.shadow = false
            $0.ampm = .hidden; $0.showDate = true; $0.dateAbove = true
        }),
        ("Neon", ClockStyle().with {
            $0.font = .googleSansFlex; $0.fontWeight = 0.6; $0.fontWidth = 0.45; $0.roundness = 1
            $0.textFill = .solid; $0.color = .white; $0.innerColor = .purple; $0.innerStrength = 0.7
            $0.glow = true; $0.glowColor = .purple; $0.glowSize = 0.6; $0.glowStrength = 0.9; $0.shadow = false
            $0.ampm = .beside
        }),
        ("Minimal", ClockStyle().with {
            $0.font = .robotoFlex; $0.fontWeight = 0.25; $0.fontWidth = 0.5; $0.spacing = 0.04
            $0.textFill = .solid; $0.shadow = false; $0.fillsCard = false
            $0.ampm = .below; $0.showDate = true
        }),
        ("Stacked serif", ClockStyle().with {
            $0.font = .newYork; $0.fontWeight = 0.7; $0.textFill = .gradient; $0.color = .white
            $0.gradientColor = .orange; $0.shadowStrength = 0.4
            $0.ampm = .stacked; $0.fillsCard = false
        }),
    ]

    /// A random style that still looks deliberate: colours come from combinations chosen to
    /// work together, and every setting stays in a range that reads well. Settings that aren't
    /// about looks (time format, kept colours) are carried over from `base`.
    static func lucky(from base: ClockStyle) -> ClockStyle {
        // Text, its glow or accent, a card tint (nil: plain glass), a colour to fade to.
        let palettes: [(text: ClockColor, accent: ClockColor, card: ClockColor?, fade: ClockColor)] = [
            (.white, .purple, .purple, .blue),
            (.white, .blue, nil, .mint),
            (.yellow, .orange, nil, .orange),
            (.mint, .blue, .blue, .white),
            (.orange, .red, nil, .yellow),
            (.white, .mint, .green, .mint),
            (.auto, .purple, nil, .purple),
            (.white, .red, .red, .orange),
            (.yellow, .purple, .purple, .orange),
            (.auto, .blue, nil, .blue),
        ]
        let palette = palettes.randomElement()!
        var style = ClockStyle()
        style.timeFormat = base.timeFormat
        style.keepsTimeColours = base.keepsTimeColours
        style.keepsDetailColours = base.keepsDetailColours
        style.keepsCardColours = base.keepsCardColours

        style.font = ClockFont.allCases.randomElement()!
        // Mostly bold, now and then a deliberate thin, minimal look.
        let minimal = Double.random(in: 0...1) < 0.15
        style.fontWeight = minimal ? .random(in: 0.2...0.35) : .random(in: 0.6...0.95)
        style.fontWidth = .random(in: 0.3...0.6)
        style.roundness = .random(in: 0.4...1)
        style.spacing = minimal ? .random(in: 0.02...0.06) : .random(in: -0.03...0.02)
        style.height = Bool.random() ? 1 : .random(in: 1...1.3)
        style.softness = Double.random(in: 0...1) < 0.3 ? .random(in: 0.3...0.6) : 0

        style.color = palette.text
        style.gradientColor = palette.fade
        style.textFill = minimal ? .solid : [.glass, .glass, .solid, .solid, .gradient].randomElement()!
        if let card = palette.card, Bool.random() { style.backgroundColor = card }

        // Glass reads best with a shadow; solid text suits a glow. Sometimes both.
        let glass = style.textFill == .glass
        style.glow = !minimal && Double.random(in: 0...1) < (glass ? 0.25 : 0.6)
        style.shadow = !minimal && Double.random(in: 0...1) < (glass ? 0.7 : 0.4)
        style.glowColor = palette.accent
        style.glowSize = .random(in: 0.3...0.7)
        style.glowStrength = .random(in: 0.5...0.9)
        style.shadowSize = .random(in: 0.3...0.6)
        style.shadowStrength = .random(in: 0.3...0.6)
        style.shadowDistance = .random(in: 0.2...0.6)
        if !minimal && Double.random(in: 0...1) < 0.25 {
            style.innerColor = palette.accent
            style.innerStrength = .random(in: 0.4...0.8)
        }

        style.ampm = AMPMPlacement.allCases.randomElement()!
        style.showDate = Double.random(in: 0...1) < 0.4
        style.dateAbove = Bool.random()
        return style
    }

    /// This style with the given parts taken from `other` and everything else kept.
    func taking(_ parts: Set<StylePart>, from other: ClockStyle) -> ClockStyle {
        var result = self
        for part in parts { part.copy(from: other, into: &result) }
        return result
    }

    /// A copy with some settings changed.
    func with(_ change: (inout ClockStyle) -> Void) -> ClockStyle {
        var copy = self
        change(&copy)
        return copy
    }

    /// The actual font for the AM/PM and date line: nil means the time's own font.
    var resolvedDetailFont: DetailFont? {
        switch detailFont {
        case .paired: font.pairing
        case .sameAsTime: nil
        default: detailFont
        }
    }

    var resolvedGlowColor: Color { glowColor == .auto ? color.color : glowColor.color }
    /// Automatic follows the text: dark text gets a soft light glow under it, light text a
    /// dark shadow (owner, 25 Oct 2026: black under black text in Light read as blurry text).
    /// A colour picked for the shadow stays. `darkScheme` is how the Automatic text colour shows.
    func resolvedShadowColor(darkScheme: Bool) -> Color {
        guard shadowColor == .auto else { return shadowColor.color }
        let darkText = color.isDark ?? !darkScheme
        return darkText ? .white : .black
    }

    // The shadow is held to a soft, natural range so every combination looks good (owner
    // feedback, 2026-10-20): it always keeps some blur, falls a modest distance, softens as it
    // falls further (like a real shadow), only points downwards (45°–135°), and never goes
    // darker than 65%. `u` is the digits' height / 100, in points.

    /// Where the shadow falls.
    func shadowOffset(unit u: CGFloat) -> CGSize {
        let distance = u * (2 + 10 * min(max(shadowDistance, 0), 1))
        let radians = min(max(shadowAngle, 45), 135) * .pi / 180
        return CGSize(width: distance * cos(radians), height: distance * sin(radians))
    }

    /// How soft the shadow is: at least 4 units, more for Softness and for Distance.
    func shadowBlur(unit u: CGFloat) -> CGFloat {
        u * (4 + 10 * min(max(shadowSize, 0), 1) + 6 * min(max(shadowDistance, 0), 1))
    }

    var shadowOpacity: Double { min(max(shadowStrength, 0.1), 0.65) }

    /// The card colour, or nil for the system default (plain glass, or the system background).
    var cardTint: Color? {
        backgroundColor == .auto ? nil : backgroundColor.color
    }

    static let heightRange = 1.0...2.0
    static let spacingRange = -0.08...0.2
    /// Text never goes fully invisible; the card can.
    static let textOpacityRange = 0.15...1.0
    static let cardOpacityRange = 0.0...1.0

    private static let key = "clockStyle"

    static func load() -> ClockStyle {
        guard let data = SharedStore.data(forKey: key),
              let style = try? JSONDecoder().decode(ClockStyle.self, from: data)
        else { return ClockStyle() }
        return style
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            SharedStore.set(data, forKey: Self.key)
        }
    }

    var uses12Hour: Bool {
        switch timeFormat {
        case .twelve: true
        case .twentyFour: false
        case .system:
            DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? false
        }
    }

    /// Worked out from the hour and minute rather than a date format: with the iPad set to
    /// 12-hour time, iOS quietly turned the "H" (0–23) format back into 1–12, so 24-hour clocks
    /// showed the wrong hour (owner, 22 Oct 2026).
    func timeText(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour24 = parts.hour ?? 0, minute = parts.minute ?? 0
        let hour = uses12Hour ? (hour24 % 12 == 0 ? 12 : hour24 % 12) : hour24
        // 24-hour shows two digits for the hour, like the Lock Screen (09:41); 12-hour doesn't (9:41).
        return String(format: uses12Hour ? "%d:%02d" : "%02d:%02d", hour, minute)
    }

    func ampmText(_ date: Date) -> String? {
        guard uses12Hour && ampm != .hidden else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }

    func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter.string(from: date)
    }
}

/// The parts of a style, so Lucky can roll the dice on some, and the person can lock others so
/// presets and Lucky leave them alone (owner idea, 2026-10-21).
enum StylePart: String, CaseIterable, Identifiable {
    case font, colours, effects, layout, card, homeScreens
    var id: Self { self }

    var label: String {
        switch self {
        case .font: "Font"
        case .colours: "Colours"
        case .effects: "Effects"
        case .layout: "Layout"
        case .card: "Card"
        case .homeScreens: "Clear and Tinted"
        }
    }

    var icon: String {
        switch self {
        case .font: "textformat"
        case .colours: "paintpalette"
        case .effects: "sun.max"
        case .layout: "rectangle.3.group"
        case .card: "rectangle.on.rectangle"
        case .homeScreens: "circle.lefthalf.filled"
        }
    }

    /// What Lucky Colours rolls, and what Lucky Style rolls. Time format is never rolled.
    static let colourParts: Set<StylePart> = [.colours]
    static let styleParts: Set<StylePart> = [.font, .effects, .layout, .card]

    func copy(from source: ClockStyle, into target: inout ClockStyle) {
        switch self {
        case .font:
            target.font = source.font
            target.fontWeight = source.fontWeight
            target.fontWidth = source.fontWidth
            target.roundness = source.roundness
            target.detailFont = source.detailFont
            target.spacing = source.spacing
            target.height = source.height
            target.softness = source.softness
            target.adaptsToSize = source.adaptsToSize
            target.detailSize = source.detailSize
            target.detailTracking = source.detailTracking
        case .colours:
            target.color = source.color
            target.gradientColor = source.gradientColor
            target.textFill = source.textFill
            target.textOpacity = source.textOpacity
            target.glowColor = source.glowColor
            target.shadowColor = source.shadowColor
            target.backgroundColor = source.backgroundColor
            // Re-colours the inner glow without switching it on or off.
            if target.innerColor != nil, let inner = source.innerColor { target.innerColor = inner }
        case .effects:
            target.glow = source.glow
            target.glowSize = source.glowSize
            target.glowStrength = source.glowStrength
            target.shadow = source.shadow
            target.shadowSize = source.shadowSize
            target.shadowStrength = source.shadowStrength
            target.shadowDistance = source.shadowDistance
            target.shadowAngle = source.shadowAngle
            target.innerColor = source.innerColor
            target.innerStrength = source.innerStrength
        case .layout:
            target.showDate = source.showDate
            target.dateAbove = source.dateAbove
            target.ampm = source.ampm
            target.detailGap = source.detailGap
            target.fillsCard = source.fillsCard
        case .card:
            target.background = source.background
            target.cardOpacity = source.cardOpacity
        case .homeScreens:
            target.keepsTimeColours = source.keepsTimeColours
            target.keepsDetailColours = source.keepsDetailColours
            target.keepsCardColours = source.keepsCardColours
        }
    }
}
