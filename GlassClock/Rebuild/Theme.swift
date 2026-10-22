import SwiftUI

/// Every design value of the rebuilt app in one place: the owner's Design Tweaks picks
/// (21–22 Oct 2026), fixed. Change a value here and it changes everywhere; nothing else in the
/// rebuild should carry a number of its own for spacing, corners, glass or motion.
enum Theme {
    /// Spacing on an 8-point grid (HIG: Layout).
    enum Space {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    /// Concentric corners, like the app icon tiles: each inner corner follows the one around it.
    /// Single-line bars are capsules.
    enum Corner {
        static let panel: CGFloat = 42
        /// The widget preview's card, as on the Home Screen.
        static let widget: CGFloat = 28
        /// A card inside a panel: the panel's corner less the padding between them.
        static let card: CGFloat = max(4, panel - Padding.panelEdge)
    }

    enum Padding {
        /// Between a panel's edge and its cards.
        static let panelEdge: CGFloat = 29
        /// Inside a card, around its rows.
        static let card: CGFloat = 29
        static let row: CGFloat = 14
        static let titleBar: CGFloat = 23
        static let footer: CGFloat = 18
        static let bubble: CGFloat = 13
        static let chip: CGFloat = 16
        /// Around the clock inside the widget's card.
        static let widget: CGFloat = 16
    }

    enum Gap {
        /// Between cards in a list.
        static let cards: CGFloat = 17
        /// Between panels, and between a panel and the window's edge.
        static let panels: CGFloat = Space.medium
    }

    enum Glass {
        /// How thick the frost behind text is (0 is clear glass).
        static let frost: Double = 1.75
        /// How far a panel or card not in use steps back.
        static let focus: Double = 2.0
        static let rim: Double = 0.9
        static let shimmer: Double = 1.0
        /// The wash inside a card's clear glass, so its text stands off the backdrop: white in
        /// Light, black in Dark (contrast first, owner 21 Oct).
        static let washLight: Double = 0.57
        static let washDark: Double = 0.62
    }

    enum Size {
        /// The settings column beside the stage, when the window has room for both.
        static let settingsColumn: CGFloat = 400
        /// The narrowest window that fits the stage and the settings side by side.
        static let sideBySide: CGFloat = 820
        /// A colour swatch, and the tap target around it (HIG minimum).
        static let swatch: CGFloat = 34
        static let tapTarget: CGFloat = 44
    }

    enum Motion {
        /// Things settling into place: panels dropped, layouts changing.
        static let settle = Animation.spring(response: 0.45, dampingFraction: 0.82)
        /// Something picked up: the lift and the shadow.
        static let lift = Animation.spring(response: 0.25, dampingFraction: 0.7)
        /// How long a panel is held before it lifts: short, so it feels instant, but longer
        /// than a tap.
        static let hold: Double = 0.22
        /// How much the widget leans into a drag.
        static let lean: CGFloat = 1.2
    }
}
