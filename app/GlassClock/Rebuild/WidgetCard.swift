import SwiftUI

/// The widget preview: the clock on its card at the widget's real size, drawn the way the
/// chosen Home Screen look draws it.
struct WidgetCard: View {
    var style: ClockStyle
    var size: PreviewSize
    var homeScreen: HomeScreenStyle

    var body: some View {
        TimelineView(.everyMinute) { context in
            ClockFace(date: context.date, style: style, simulatedAccent: homeScreen.accent,
                      simulatesClear: !homeScreen.showsKeptColours)
                .padding(Theme.Padding.widget)
                .frame(width: size.size.width, height: size.size.height)
                .modifier(ClockCard(style: style, shape: .rect(cornerRadius: Theme.Corner.widget), homeScreen: homeScreen))
                .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
                // Switches look at once rather than blending: animating the glass between looks
                // was the costliest part of a tap on the Home Screen picker (2026-10-21).
                .transaction(value: homeScreen) { $0.animation = nil }
        }
    }
}
