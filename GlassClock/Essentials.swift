import Foundation

/// The Foundation build (owner, 22 Oct 2026): the app with its core features and feel, and
/// the playground experiments switched off, so it's calm to use and think with while the
/// rebuild goes on. What's off is the "Cut" list in PLAN.md: groups sticking onto the widget
/// or settings, the carousel squash, one-row controls, suggestion bubbles, the title card and
/// puck while carrying, and the wiggle.
/// Launch with `-playground YES` (`Scripts/run-on-ipad.sh --playground`) to bring them all back.
enum Essentials {
    /// Read once at launch: it's checked while scrolling, so it must cost nothing.
    static let on = !UserDefaults.standard.bool(forKey: "playground")
}
