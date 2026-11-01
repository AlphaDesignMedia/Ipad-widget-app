import Foundation

/// PICTURES FOR THE HOME SCREEN (Jules, 1 Nov). The app saves a small JPEG of the newest mood board and the latest Snap
/// into the store the app and the widget share; the Pip Pictures widget (GlassClockWidget/PipPicturesWidget.swift) shows
/// them. Kept small (about 900 points wide) so they fit the shared store on free signing too.
enum PictureShelf {
    enum Kind: String, CaseIterable, Sendable {
        case moodBoard, snap
        var label: String {
            switch self {
            case .moodBoard: "Mood board"
            case .snap: "Latest snap"
            }
        }
    }

    static let widgetKind = "PipPicturesWidget"
    /// Tapping the widget opens the app on the Dashboard tab.
    static let link = URL(string: "pipsandbox://open/dashboard")!

    static func save(_ jpeg: Data, kind: Kind, title: String) {
        SharedStore.set(jpeg, forKey: "pictures.\(kind.rawValue)")
        SharedStore.set(Data(title.utf8), forKey: "pictures.\(kind.rawValue).title")
        SharedStore.set(Data(ISO8601DateFormatter().string(from: Date()).utf8), forKey: "pictures.\(kind.rawValue).at")
    }

    static func load(_ kind: Kind) -> (jpeg: Data, title: String, at: Date?)? {
        guard let jpeg = SharedStore.data(forKey: "pictures.\(kind.rawValue)") else { return nil }
        let title = SharedStore.data(forKey: "pictures.\(kind.rawValue).title").flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let at = SharedStore.data(forKey: "pictures.\(kind.rawValue).at")
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap { ISO8601DateFormatter().date(from: $0) }
        return (jpeg, title, at)
    }
}
