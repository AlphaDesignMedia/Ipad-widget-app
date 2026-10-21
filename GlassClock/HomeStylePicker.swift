import SwiftUI

/// Light, Dark, Clear and Tinted, each with a tiny app icon drawn in that style, so the
/// choice reads at a glance (owner request, 2026-10-21). Our own drawing, in the spirit of
/// the Home Screen's Customise menu. The selection slides between options.
struct HomeStylePicker: View {
    @Binding var selection: HomeScreenStyle
    @Namespace private var selectionSpace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HomeScreenStyle.allCases) { style in
                let selected = style == selection
                Button {
                    withAnimation(.snappy) { selection = style }
                } label: {
                    // A big icon over its name, like the Home Screen's Customise menu.
                    VStack(spacing: 5) {
                        HomeStyleIcon(style: style, size: 34)
                        Text(style.rawValue)
                            .font(.footnote.weight(selected ? .semibold : .regular))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if selected {
                            // Bright glass with a light rim, like every other selection in
                            // the app (owner direction, 2026-10-21), rather than a solid tile.
                            Capsule()
                                .fill(.background.opacity(0.6))
                                .overlay(Capsule()
                                    .strokeBorder(.white.opacity(Tweak.rim.value), lineWidth: 1))
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                                .matchedGeometryEffect(id: "selection", in: selectionSpace)
                        }
                    }
                    .shimmer(trigger: selected, in: Capsule())
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.rawValue)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Home Screen style")
    }
}

/// A tiny app icon in one Home Screen style: a rounded square with a clock face on it.
struct HomeStyleIcon: View {
    var style: HomeScreenStyle
    var size: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        ZStack {
            switch style {
            case .light:
                shape.fill(.white)
                shape.strokeBorder(.black.opacity(0.25), lineWidth: 0.75)
            case .dark:
                shape.fill(Color(white: 0.12))
                shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.75)
            case .clear:
                shape.fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.12)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.strokeBorder(.primary.opacity(0.55), lineWidth: 0.75)
            case .tinted:
                shape.fill(LinearGradient(colors: [Color(red: 0.35, green: 0.5, blue: 0.95),
                                                   Color(red: 0.15, green: 0.25, blue: 0.7)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Image(systemName: "clock")
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(glyph)
        }
        .frame(width: size, height: size)
        // A soft shadow keeps each icon apart from a background of the same colour.
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        .accessibilityHidden(true)
    }

    private var glyph: Color {
        switch style {
        case .light: .black.opacity(0.8)
        case .dark, .tinted: .white
        case .clear: .primary
        }
    }
}
