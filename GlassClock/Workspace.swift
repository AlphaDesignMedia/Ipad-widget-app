import SwiftUI
import UIKit

/// The groups of settings listed in the sidebar. The selected one opens in the inspector.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case presets, font, text, details, glow, shadow, card, clearAndTinted, applying
    var id: Self { self }

    var title: String {
        switch self {
        case .presets: "Presets"
        case .font: "Font"
        case .text: "Text"
        case .details: "AM/PM and Date"
        case .glow: "Glow"
        case .shadow: "Shadow"
        case .card: "Card"
        case .clearAndTinted: "Clear and Tinted"
        case .applying: "Applying Changes"
        }
    }

    var symbol: String {
        switch self {
        case .presets: "sparkles"
        case .font: "textformat"
        case .text: "paintbrush"
        case .details: "calendar"
        case .glow: "sun.max"
        case .shadow: "shadow"
        case .card: "rectangle.on.rectangle"
        case .clearAndTinted: "circle.lefthalf.filled"
        case .applying: "arrow.down.circle"
        }
    }

    var footer: String? {
        switch self {
        case .presets: "Save up to \(StyleLibrary.maxCustomPresets) of your own. Long-press one to update, rename or delete it."
        case .details: "Size, gap and letter spacing shape the line under (or beside) the time."
        case .shadow: "Automatic is black. Pick white for a light shadow."
        case .card: "When your Home Screen uses the Clear or Tinted style, iPadOS supplies the card and colour. Liquid Glass text keeps its glass look."
        case .clearAndTinted: "iPadOS normally redraws widgets in its own glass and colour on these Home Screens. Turn these on to bring your colours forward instead. Needs iPadOS 27 for Clear Home Screens; iPadOS 26 applies its own glass there regardless."
        case .applying: "Your changes are kept in the app as you go. They reach the widget when you tap Apply to Widget, or when you leave the app if this is on."
        default: nil
        }
    }

    /// Sidebar groups, two levels at most (HIG: Sidebars).
    static let groups: [(title: String, items: [SettingsCategory])] = [
        ("Clock", [.presets, .font, .text, .details]),
        ("Effects", [.glow, .shadow, .card]),
        ("Widget", [.clearAndTinted, .applying]),
    ]
}

/// What's behind the preview card. Apps can't see the Home Screen wallpaper, so the closest
/// thing is a photo the person picks, such as a screenshot of their own Home Screen.
enum PreviewBackdrop: String, CaseIterable, Identifiable {
    case plain, aurora, sunset, ocean, graphite, photo
    var id: Self { self }

    var label: String {
        switch self {
        case .plain: "Plain"
        case .aurora: "Aurora"
        case .sunset: "Sunset"
        case .ocean: "Ocean"
        case .graphite: "Graphite"
        case .photo: "Your Photo"
        }
    }

    var colors: [Color] {
        switch self {
        case .plain, .photo: [.indigo, .teal, .orange]
        case .aurora: [.indigo, .teal, .orange]
        case .sunset: [.purple, .pink, .orange]
        case .ocean: [Color(red: 0.02, green: 0.1, blue: 0.35), .blue, .teal]
        case .graphite: [Color(white: 0.12), Color(white: 0.3), Color(white: 0.18)]
        }
    }
}

/// The photo chosen as a backdrop, kept in the app's own storage.
enum BackdropPhoto {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "backdrop.jpg")
    }

    static func load() -> UIImage? {
        (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
    }

    /// Stores a picked photo, scaled down to at most 2400 pt on its long side.
    static func save(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 2400 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? resized.jpegData(compressionQuality: 0.85)?.write(to: url)
        return resized
    }
}
