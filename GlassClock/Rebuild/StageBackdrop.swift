import SwiftUI

/// The backdrop behind the widget preview: a plain colour, a gradient, a mesh or a pattern.
/// (Your photo and Make your own arrive with the stage, step 2; until then they show Plain.)
struct StageBackdrop: View {
    var backdrop: PreviewBackdrop
    var homeScreen: HomeScreenStyle

    var body: some View {
        switch backdrop {
        case .plain, .photo, .custom:
            plain
        case _ where backdrop.isPattern:
            PatternBackdrop(kind: backdrop)
        default:
            if let mesh = backdrop.mesh {
                // The middle points sit off-centre, so the colours flow rather than form a grid.
                MeshGradient(width: 3, height: 3, points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.45], [0.62, 0.42], [1, 0.55],
                    [0, 1], [0.4, 1], [1, 1],
                ], colors: mesh, smoothsColors: true)
            } else {
                LinearGradient(colors: backdrop.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    /// White or black to match Light or Dark; a quiet slate on Clear and Tinted, which draw
    /// white text.
    @ViewBuilder private var plain: some View {
        if homeScreen.accent == nil {
            homeScreen == .dark ? Color.black : Color.white
        } else {
            LinearGradient(colors: [Color(white: 0.34), Color(white: 0.18)], startPoint: .top, endPoint: .bottom)
        }
    }
}
