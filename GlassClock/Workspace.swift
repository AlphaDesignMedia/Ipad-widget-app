import SwiftUI
import UIKit

/// How the preview and the settings share the window.
enum WorkspaceLayout: String, CaseIterable, Identifiable {
    case automatic, sideBySide, stacked, previewOnly
    var id: Self { self }

    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .sideBySide: "Side by Side"
        case .stacked: "Stacked"
        case .previewOnly: "Preview Only"
        }
    }

    var symbol: String {
        switch self {
        case .automatic: "rectangle.3.group"
        case .sideBySide: "rectangle.split.2x1"
        case .stacked: "rectangle.split.1x2"
        case .previewOnly: "rectangle"
        }
    }

    /// Automatic picks side by side when there's room (a full-screen iPad in landscape) and
    /// stacked in portrait and narrower Split View or Stage Manager windows.
    func resolved(width: CGFloat) -> WorkspaceLayout {
        guard self == .automatic else { return self }
        return width >= 1000 ? .sideBySide : .stacked
    }
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

/// A divider with a grab handle. Dragging it moves `fraction`, the share of `total` the first
/// pane takes, within `range`.
struct SplitHandle: View {
    /// `.horizontal`: panes side by side, the handle drags left and right.
    var axis: Axis
    @Binding var fraction: Double
    var total: CGFloat
    var range: ClosedRange<Double>
    @State private var dragStart: Double?

    var body: some View {
        let sideBySide = axis == .horizontal
        ZStack {
            Rectangle()
                .fill(.separator)
                .frame(width: sideBySide ? 1 : nil, height: sideBySide ? nil : 1)
            Capsule()
                .fill(dragStart == nil ? Color.secondary.opacity(0.6) : Color.accentColor)
                .frame(width: sideBySide ? 6 : 48, height: sideBySide ? 48 : 6)
        }
        // A 24 pt strip, so the handle is easy to catch with a finger or the pointer.
        .frame(width: sideBySide ? 24 : nil, height: sideBySide ? nil : 24)
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = dragStart ?? fraction
                    dragStart = start
                    let moved = Double((sideBySide ? value.translation.width : value.translation.height) / total)
                    fraction = min(range.upperBound, max(range.lowerBound, start + moved))
                }
                .onEnded { _ in dragStart = nil }
        )
        .animation(.snappy, value: dragStart == nil)
        .accessibilityElement()
        .accessibilityLabel("Resize preview")
        .accessibilityValue("\(Int(fraction * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 0.05 : -0.05
            fraction = min(range.upperBound, max(range.lowerBound, fraction + step))
        }
    }
}
