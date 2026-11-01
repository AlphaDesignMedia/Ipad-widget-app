import Foundation

/// THE DASHBOARD ON THE HOME SCREEN (Jules, 1 Nov). Aaron: "lean into these widgets… my way of exploring new widgets
/// while also making dashboard widgets that help me with my work".
/// A small copy of the dashboard, saved by the app (the Dashboard plugin, `Dashboard.publish`) into the store the app
/// and the widget share, and read by the Home Screen widget (GlassClockWidget/PipDashboardWidget.swift). Plain lines
/// only, already cleaned, so the widget needs nothing from the app. The widget never goes online.
/// Private: Aaron's mission control. It lives in the Sandbox and never moves to Glass Clock.
struct DashboardSnapshot: Codable, Equatable, Sendable {
    /// When the board was written (ISO), as the dashboard shows it.
    var boardAt: String?
    var headline: String?
    /// Questions not answered yet on this iPad.
    var needs: [Need] = []
    var upNext: [String] = []
    /// Rob's jobs not done yet.
    var forRob: [String] = []
    var ideas: [String] = []
    var reminders: [String] = []

    /// A question, with the key its answer is kept under in the app, so the widget can answer it.
    struct Need: Codable, Equatable, Sendable {
        var text: String
        var key: String
        var suggested: String?
    }

    static let key = "dashboard.snapshot"
    /// The widget's kind, so the app can ask for just this widget to redraw.
    static let widgetKind = "PipDashboardWidget"
    /// Tapping the widget opens the app on the Dashboard tab (ContentView's `onOpenURL`).
    static let link = URL(string: "pipsandbox://open/dashboard")!
    /// Lists are cut to this, so the copy stays tiny.
    static let most = 10

    static func load() -> DashboardSnapshot? {
        SharedStore.data(forKey: key).flatMap { try? JSONDecoder().decode(DashboardSnapshot.self, from: $0) }
    }

    /// Saves it if anything changed. True when it did, so the caller knows to redraw the widget.
    @discardableResult func save() -> Bool {
        guard self != Self.load(), let data = try? JSONEncoder().encode(self) else { return false }
        SharedStore.set(data, forKey: Self.key)
        return true
    }

    // MARK: Answering from the Home Screen

    /// Answers given on the widget, waiting for the app: answer key → "yes" or "notYet". The app takes them in when it
    /// opens (`Dashboard.takeHomeAnswers`), then empties this.
    static let inboxKey = "dashboard.homeAnswers"

    static func homeAnswers() -> [String: String] {
        SharedStore.data(forKey: inboxKey).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    static func clearHomeAnswers() {
        if let empty = try? JSONEncoder().encode([String: String]()) { SharedStore.set(empty, forKey: inboxKey) }
    }

    /// Called by the widget's Yes / Not yet: keeps the answer for the app, and takes the question off the widget now.
    static func answerFromHome(key: String, answer: String) {
        var inbox = homeAnswers()
        inbox[key] = answer
        if let data = try? JSONEncoder().encode(inbox) { SharedStore.set(data, forKey: inboxKey) }
        if var copy = load() {
            copy.needs.removeAll { $0.key == key }
            copy.save()
        }
    }

    /// The board's time as "7:20 am" today, otherwise "Sat 31 Oct".
    var boardTime: String? {
        guard let boardAt else { return nil }
        let iso = ISO8601DateFormatter()
        var date = iso.date(from: boardAt)
        if date == nil {
            iso.formatOptions.insert(.withFractionalSeconds)
            date = iso.date(from: boardAt)
        }
        guard let date else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = Calendar.current.isDateInToday(date) ? "h:mm a" : "EEE d MMM"
        return f.string(from: date).lowercased()
    }

    /// For the widget gallery and the placeholder: make-believe, so it never shows real work before the app fills it.
    static let sample = DashboardSnapshot(
        boardAt: nil,
        headline: "Blobby Pip is in the app, and the dashboard is on the iPad.",
        needs: [Need(text: "Blobby's wings: flutter or glide?", key: "sample.1", suggested: "Flutter, slowly"),
                Need(text: "Dashboard widgets on the Home Screen?", key: "sample.2", suggested: "Yes, all four sizes")],
        upNext: ["Looks card screenshots", "Pip look hook", "Answer from the Home Screen"],
        forRob: ["take-plugins, then the Looks card"],
        ideas: ["Pip as the glass behind sliders", "A weather widget Pip sits on"],
        reminders: ["Re-sign the iPad by 6 Nov"])
}
