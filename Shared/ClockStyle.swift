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

enum ClockColor: String, Codable, CaseIterable, Identifiable {
    case auto, white, black, red, orange, yellow, green, mint, blue, purple
    var id: Self { self }

    var color: Color {
        switch self {
        case .auto: .primary
        case .white: .white
        case .black: .black
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .blue: .blue
        case .purple: .purple
        }
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

/// Light around the text: a glow of colour, or a shadow cast onto the card.
enum LightEffect: String, Codable, CaseIterable, Identifiable {
    case none, glow, shadow
    var id: Self { self }

    var label: String {
        switch self {
        case .none: "None"
        case .glow: "Glow"
        case .shadow: "Shadow"
        }
    }
}

/// Everything the user can customise. Font weight, width and roundness are 0–1 positions
/// along the chosen font's own variable axes (0.5 is regular weight and normal width).
struct ClockStyle: Codable, Equatable {
    var font: ClockFont = .sf
    var fontWeight: Double = 0.75
    var fontWidth: Double = 0.5
    var roundness: Double = 1
    /// Extra space between digits, as a fraction of the font size. Negative tightens.
    var spacing: Double = 0
    /// Vertical stretch of the time: 1 is normal, 2 is twice as tall.
    var height: Double = 1
    var color: ClockColor = .auto
    var timeFormat: TimeFormat = .system
    var showDate = false
    var ampm: AMPMPlacement = .hidden
    var background: CardBackground = .glass
    var backgroundColor: ClockColor = .auto
    var textFill: TextFill = .solid
    var gradientColor: ClockColor = .purple
    /// 1 is fully opaque.
    var textOpacity: Double = 1
    var cardOpacity: Double = 1

    var effect: LightEffect = .none
    /// Automatic: the text colour for a glow, black for a shadow.
    var effectColor: ClockColor = .auto
    /// How far the light spreads, 0–1.
    var effectSize: Double = 0.4
    var effectStrength: Double = 0.7
    /// How far a shadow falls below the text, 0–1.
    var effectDistance: Double = 0.4

    /// Colour glowing inside the digits from their edges, on its own rather than as a
    /// side effect of the outer glow. Nil is off.
    var innerColor: ClockColor?
    var innerStrength: Double = 0.6

    init() {}

    /// Missing keys fall back to defaults, so adding a setting never wipes saved styles.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClockStyle()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        font = try value(.font, d.font)
        fontWeight = try value(.fontWeight, d.fontWeight)
        fontWidth = try value(.fontWidth, d.fontWidth)
        roundness = try value(.roundness, d.roundness)
        spacing = try value(.spacing, d.spacing)
        height = try value(.height, d.height)
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
        effect = try value(.effect, d.effect)
        effectColor = try value(.effectColor, d.effectColor)
        effectSize = try value(.effectSize, d.effectSize)
        effectStrength = try value(.effectStrength, d.effectStrength)
        effectDistance = try value(.effectDistance, d.effectDistance)
        innerColor = try c.decodeIfPresent(ClockColor.self, forKey: .innerColor)
        innerStrength = try value(.innerStrength, d.innerStrength)
    }

    /// The colour of the glow or shadow.
    var resolvedEffectColor: Color {
        guard effectColor == .auto else { return effectColor.color }
        return effect == .shadow ? .black : color.color
    }

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

    func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = uses12Hour ? "h:mm" : "H:mm"
        return formatter.string(from: date)
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
