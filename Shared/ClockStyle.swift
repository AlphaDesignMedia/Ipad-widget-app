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

/// Everything the user can customise. Weight and width are raw values on
/// San Francisco's variable axes, so any value in between is valid.
struct ClockStyle: Codable, Equatable {
    var weight: Double = Double(UIFont.Weight.semibold.rawValue)
    var width: Double = Double(UIFont.Width.standard.rawValue)
    var color: ClockColor = .auto
    var timeFormat: TimeFormat = .system
    var showDate = true
    var showAMPM = false
    var background: CardBackground = .glass
    var backgroundColor: ClockColor = .auto
    var textFill: TextFill = .solid
    var gradientColor: ClockColor = .purple
    /// Vertical stretch of the time: 1 is normal, 2 is twice as tall.
    var height: Double = 1
    var glow = false
    /// 1 is fully opaque.
    var textOpacity: Double = 1
    var cardOpacity: Double = 1

    init() {}

    /// Missing keys fall back to defaults, so adding a setting never wipes saved styles.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClockStyle()
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? d.weight
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? d.width
        color = try c.decodeIfPresent(ClockColor.self, forKey: .color) ?? d.color
        timeFormat = try c.decodeIfPresent(TimeFormat.self, forKey: .timeFormat) ?? d.timeFormat
        showDate = try c.decodeIfPresent(Bool.self, forKey: .showDate) ?? d.showDate
        showAMPM = try c.decodeIfPresent(Bool.self, forKey: .showAMPM) ?? d.showAMPM
        background = try c.decodeIfPresent(CardBackground.self, forKey: .background) ?? d.background
        backgroundColor = try c.decodeIfPresent(ClockColor.self, forKey: .backgroundColor) ?? d.backgroundColor
        textFill = try c.decodeIfPresent(TextFill.self, forKey: .textFill) ?? d.textFill
        gradientColor = try c.decodeIfPresent(ClockColor.self, forKey: .gradientColor) ?? d.gradientColor
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? d.height
        glow = try c.decodeIfPresent(Bool.self, forKey: .glow) ?? d.glow
        textOpacity = try c.decodeIfPresent(Double.self, forKey: .textOpacity) ?? d.textOpacity
        cardOpacity = try c.decodeIfPresent(Double.self, forKey: .cardOpacity) ?? d.cardOpacity
    }

    /// The card colour, or nil for the system default (plain glass, or the system background).
    var cardTint: Color? {
        backgroundColor == .auto ? nil : backgroundColor.color
    }

    static let heightRange = 1.0...2.0
    /// Text never goes fully invisible; the card can.
    static let textOpacityRange = 0.15...1.0
    static let cardOpacityRange = 0.0...1.0

    static let weightRange = Double(UIFont.Weight.ultraLight.rawValue)...Double(UIFont.Weight.black.rawValue)
    static let widthRange = Double(UIFont.Width.compressed.rawValue)...Double(UIFont.Width.expanded.rawValue)

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

    /// The variable system font at the chosen weight and width.
    func font(size: CGFloat) -> Font {
        let uiFont = UIFont.systemFont(
            ofSize: size,
            weight: UIFont.Weight(CGFloat(weight)),
            width: UIFont.Width(CGFloat(width))
        )
        return Font(uiFont)
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
        guard uses12Hour && showAMPM else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }

    func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: date)
    }
}
