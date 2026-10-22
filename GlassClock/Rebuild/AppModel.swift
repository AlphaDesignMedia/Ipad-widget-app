import SwiftUI
import WidgetKit

/// Everything the rebuilt app's screens share, in one place. Views read only the parts they
/// use, so a change redraws just those views rather than the whole screen (the old
/// `ContentView` kept 113 separate states, and every change redrew all of it).
/// Saved settings use the same keys as the old app, so both open on the same style.
@Observable @MainActor
final class AppModel {
    /// The style being edited. Saved as it changes, but it reaches the widget only when applied.
    var style: ClockStyle {
        didSet { if persists && style != oldValue { StyleLibrary.saveDraft(style) } }
    }
    /// The style the widget shows.
    private(set) var appliedStyle: ClockStyle
    var previewSize: PreviewSize {
        didSet { save(previewSize.rawValue, as: Key.previewSize) }
    }
    /// The Home Screen look the preview imitates: Light, Dark, Clear or Tinted.
    var homeScreen: HomeScreenStyle {
        didSet { save(homeScreen.rawValue, as: Key.homeScreen) }
    }
    var backdrop: PreviewBackdrop {
        didSet { save(backdrop.rawValue, as: Key.backdrop) }
    }
    /// Which side each panel is on.
    var settingsLeading: Bool {
        didSet { save(settingsLeading, as: Key.settingsLeading) }
    }
    var groupsTrailing: Bool {
        didSet { save(groupsTrailing, as: Key.groupsTrailing) }
    }

    /// Where the widget sits on the stage's Home Screen grid; -1 (never placed) means the middle.
    var widgetColumn: Int {
        didSet { save(widgetColumn, as: Key.widgetColumn) }
    }
    var widgetRow: Int {
        didSet { save(widgetRow, as: Key.widgetRow) }
    }

    var isApplied: Bool { style == appliedStyle }

    @ObservationIgnored private let persists: Bool
    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let previewSize = "rebuild.previewSize"
        static let homeScreen = "rebuild.homeScreen"
        static let backdrop = "previewBackdrop"
        static let settingsLeading = "settingsLeading"
        static let groupsTrailing = "groupsTrailing"
        static let widgetColumn = "rebuild.widgetColumn"
        static let widgetRow = "rebuild.widgetRow"
    }

    /// The app as it was left.
    init(defaults: UserDefaults = .standard) {
        self.persists = true
        self.defaults = defaults
        style = ClockStyle.launchOverride ?? StyleLibrary.loadDraft() ?? ClockStyle.load()
        appliedStyle = ClockStyle.load()
        previewSize = defaults.string(forKey: Key.previewSize).flatMap(PreviewSize.init(rawValue:)) ?? .medium
        homeScreen = defaults.string(forKey: Key.homeScreen).flatMap(HomeScreenStyle.init(rawValue:)) ?? .light
        backdrop = defaults.string(forKey: Key.backdrop).flatMap(PreviewBackdrop.init(rawValue:)) ?? .plain
        settingsLeading = defaults.bool(forKey: Key.settingsLeading)
        groupsTrailing = defaults.bool(forKey: Key.groupsTrailing)
        // `integer(forKey:)` also reads a number given as text (a launch setting), but gives 0
        // when nothing's saved, which would mean the top-left slot rather than the middle.
        widgetColumn = defaults.object(forKey: Key.widgetColumn) == nil ? -1 : defaults.integer(forKey: Key.widgetColumn)
        widgetRow = defaults.object(forKey: Key.widgetRow) == nil ? -1 : defaults.integer(forKey: Key.widgetRow)
    }

    /// A fixed set-up that saves nothing, for Previews and checks: every run looks the same.
    init(sample style: ClockStyle, size: PreviewSize = .medium,
         homeScreen: HomeScreenStyle = .light, backdrop: PreviewBackdrop = .lagoon) {
        self.persists = false
        self.defaults = .standard
        self.style = style
        appliedStyle = style
        previewSize = size
        self.homeScreen = homeScreen
        self.backdrop = backdrop
        settingsLeading = false
        groupsTrailing = false
        widgetColumn = -1
        widgetRow = -1
    }

    /// Sends the edited style to the widget.
    func apply() {
        if persists {
            style.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        appliedStyle = style
    }

    private func save(_ value: Any, as key: String) {
        if persists { defaults.set(value, forKey: key) }
    }
}
