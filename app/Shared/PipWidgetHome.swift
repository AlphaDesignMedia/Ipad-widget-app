import Foundation
import UIKit

/// PIP ON THE HOME SCREEN (Jules, 1 Nov 2026). Aaron: "he will be floating around in widgets… he linked up from the
/// clock widget to one of my dashboard widgets… then he can float around between the dashboard's widgets".
/// Pip lives in one Home Screen widget at a time. Tap him there and he hops to the next widget you have (an old-game
/// trick: he moves between screens and you never see the journey). iOS keeps every widget in its own box, so he can't
/// fly across the Home Screen; he pops out of one and into the next.
/// The app saves a picture of Pip in his current look (the Pip on the Home Screen plugin) and where he is; the widgets
/// read both. No picture (Pip off, or the plugin off): no Pip in any widget.
enum PipWidgetHome {
    static let homeKey = "pip.widgetHome"
    static let pictureKey = "pip.widgetPicture"
    static let clockKind = "GlassClockWidget"
    /// His round: the clock first, then the dashboard's widgets (DashboardPart raw values).
    static let order = ["clock", "needs", "upnext", "progress", "ideas", "forrob", "overview"]

    /// Where he is now: "clock" or a dashboard part.
    static var home: String {
        get { SharedStore.data(forKey: homeKey).flatMap { String(data: $0, encoding: .utf8) } ?? "clock" }
        set { SharedStore.set(Data(newValue.utf8), forKey: homeKey) }
    }

    static var picture: UIImage? { SharedStore.data(forKey: pictureKey).flatMap { UIImage(data: $0) } }
    /// The app saves him (PNG), or nil to take him off the Home Screen.
    static func setPicture(_ png: Data?) { SharedStore.set(png ?? Data(), forKey: pictureKey) }

    /// The next widget on his round, among the ones on the Home Screen. Stays put if he's in the only one.
    static func next(after now: String, among homes: [String]) -> String {
        let present = order.filter { homes.contains($0) }
        guard !present.isEmpty else { return now }
        guard let i = present.firstIndex(of: now) else { return present[0] }
        return present[(i + 1) % present.count]
    }
}
