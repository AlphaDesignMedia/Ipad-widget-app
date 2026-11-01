import SwiftUI
import WidgetKit
import AppIntents
import UIKit

// PIP PICTURES · Home Screen widget (Jules, 1 Nov). Your newest mood board, or your latest Snap, on the Home Screen.
// Hold it → Edit Widget → Show: Mood board or Latest snap. Tap → the app opens on the Dashboard tab.
// Data: small JPEGs the app saves (Shared/PictureShelf.swift). No network, no timer: it redraws when the app saves a
// new picture. Private: Aaron's mission control, never moves to Glass Clock.

enum PictureChoice: String, AppEnum {
    case moodBoard, snap

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Show" }
    static var caseDisplayRepresentations: [PictureChoice: DisplayRepresentation] {
        [.moodBoard: "Mood board", .snap: "Latest snap"]
    }

    var kind: PictureShelf.Kind { self == .moodBoard ? .moodBoard : .snap }
}

struct PicturesWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Pictures" }
    static var description: IntentDescription { "Pick which picture this widget shows." }

    @Parameter(title: "Show", default: .moodBoard)
    var show: PictureChoice

    init() {}
}

struct PicturesEntry: TimelineEntry {
    let date: Date
    let choice: PictureChoice
    let image: UIImage?
    let title: String
}

struct PicturesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PicturesEntry {
        PicturesEntry(date: .now, choice: .moodBoard, image: nil, title: "Mood board")
    }

    func snapshot(for configuration: PicturesWidgetIntent, in context: Context) async -> PicturesEntry {
        entry(configuration.show, context)
    }

    func timeline(for configuration: PicturesWidgetIntent, in context: Context) async -> Timeline<PicturesEntry> {
        Timeline(entries: [entry(configuration.show, context)], policy: .never)
    }

    /// The picture cut to the widget's own size, so it stays inside the Home Screen's picture limits.
    private func entry(_ choice: PictureChoice, _ context: Context) -> PicturesEntry {
        guard let saved = PictureShelf.load(choice.kind), let full = UIImage(data: saved.jpeg) else {
            return PicturesEntry(date: .now, choice: choice, image: nil, title: choice.kind.label)
        }
        return PicturesEntry(date: .now, choice: choice, image: Self.fill(full, context.displaySize), title: saved.title)
    }

    static func fill(_ image: UIImage, _ size: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0, image.size.width > 0, image.size.height > 0 else { return image }
        let k = max(size.width / image.size.width, size.height / image.size.height)
        let drawn = CGSize(width: image.size.width * k, height: image.size.height * k)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
    }
}

struct PipPicturesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PicturesEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                    .accessibilityLabel(entry.choice == .moodBoard ? "Mood board: \(entry.title)" : "Latest snap: \(entry.title)")
                if family != .systemSmall {
                    Text(entry.title.uppercased())
                        .font(.system(size: 10.5, weight: .semibold)).tracking(1.1)
                        .lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: entry.choice == .moodBoard ? "photo.on.rectangle.angled" : "camera.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                    Text(entry.choice == .moodBoard ? "Pin something to a mood board in the Dashboard." : "Snap something in the Dashboard.")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .containerBackground(for: .widget) { Color(red: 0.93, green: 0.9, blue: 0.85) }
        .widgetURL(PictureShelf.link)
    }
}

struct PipPicturesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: PictureShelf.widgetKind, intent: PicturesWidgetIntent.self,
                               provider: PicturesProvider()) { entry in
            PipPicturesWidgetView(entry: entry)
        }
        .configurationDisplayName("Pip Pictures")
        .description("Your newest mood board or latest Snap. Hold it and pick Edit Widget to choose.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}
