import Foundation

/// A style the person saved under a name.
struct CustomPreset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var style: ClockStyle
}

/// The app's own storage: the style being edited, and saved presets. Only the app reads these.
/// The widget shows the applied style (`ClockStyle.load()`), which changes only when the
/// person applies their edits, so half-finished changes never reach the Home Screen.
enum StyleLibrary {
    static let maxCustomPresets = 2

    private static let draftKey = "draftStyle"
    private static let presetsKey = "customPresets"

    static func loadDraft() -> ClockStyle? {
        UserDefaults.standard.data(forKey: draftKey)
            .flatMap { try? JSONDecoder().decode(ClockStyle.self, from: $0) }
    }

    static func saveDraft(_ style: ClockStyle) {
        if let data = try? JSONEncoder().encode(style) {
            UserDefaults.standard.set(data, forKey: draftKey)
        }
    }

    static func loadPresets() -> [CustomPreset] {
        UserDefaults.standard.data(forKey: presetsKey)
            .flatMap { try? JSONDecoder().decode([CustomPreset].self, from: $0) } ?? []
    }

    static func savePresets(_ presets: [CustomPreset]) {
        if let data = try? JSONEncoder().encode(Array(presets.prefix(maxCustomPresets))) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }
}
