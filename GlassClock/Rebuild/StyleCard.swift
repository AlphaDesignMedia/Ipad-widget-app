import SwiftUI

/// One group of settings as a card of clear glass (PLAN.md, rebuild step 3): its title across
/// the top, its rows split by thin lines, and an optional note at the bottom. A wash inside the
/// glass keeps the text readable over any backdrop. With Reduce Transparency (or the app's
/// Reduce glass switch) it's a plain solid card instead.
struct StyleCard<Content: View>: View {
    var group: SettingsSection
    /// A short note at the bottom of the card.
    var footer: String?
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @AppStorage("reduceGlass") private var reducesGlass = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Corner.card, style: .continuous)
        let glassy = !systemReducesTransparency && !reducesGlass
        VStack(alignment: .leading, spacing: 0) {
            Label(group.title, systemImage: group.icon)
                .font(.title3.weight(.bold))
                .labelStyle(TintedIconLabel())
                .padding(.top, Theme.Padding.titleBar)
                .padding(.bottom, Theme.Space.small)
                .accessibilityAddTraits(.isHeader)
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    row.padding(.vertical, Theme.Padding.row)
                    if row.id != rows.last?.id { Divider() }
                }
            }
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Space.small)
                    .padding(.bottom, Theme.Padding.footer)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.Padding.card)
        .padding(.bottom, footer == nil ? Theme.Space.small : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if glassy {
                shape.fill(colorScheme == .dark ? Color.black : .white)
                    .opacity(colorScheme == .dark ? Theme.Glass.washDark : Theme.Glass.washLight)
            } else {
                shape.fill(.background.secondary)
            }
        }
        .modifier(ClearGlass(on: glassy, shape: shape))
        // A soft shadow, so a light card still stands off a white backdrop (Simulator, 22 Oct).
        .shadow(color: .black.opacity(0.1), radius: 14, y: 5)
    }
}

/// The card's title: the icon in the app colour, the words in the text colour.
private struct TintedIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.small) {
            configuration.icon.foregroundStyle(.tint)
            configuration.title
        }
    }
}

private struct ClearGlass<S: Shape>: ViewModifier {
    var on: Bool
    var shape: S

    func body(content: Content) -> some View {
        if on { content.glassEffect(.clear, in: shape) } else { content }
    }
}

// MARK: - Rows used inside the cards

/// A small heading that starts a set of rows inside a card.
struct GroupLabel: View {
    var title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A menu picker with its name on the left and the choice on the right.
struct PickerRow<T: Hashable, Options: View>: View {
    var title: String
    @Binding var selection: T
    @ViewBuilder var options: Options

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: Theme.Space.small)
            Picker(title, selection: $selection) { options }
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// A slider with its name above and words at each end, so it reads without numbers.
struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var low: String
    var high: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Slider(value: $value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Text(low).font(.caption).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(high).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Colour swatches that wrap onto more rows when the card is narrow, then a colour wheel for
/// any colour at all. `includesAutomatic` adds the "A" swatch that follows the clock.
struct SwatchRow: View {
    @Binding var selection: ClockColor
    var includesAutomatic = true

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Size.tapTarget, maximum: Theme.Size.tapTarget), spacing: 4)],
                  alignment: .leading, spacing: 4) {
            ForEach(ClockColor.allCases.filter { includesAutomatic || $0 != .auto }) { swatch($0) }
            if selection.isCustom { swatch(selection) }
            ColorPicker("Any colour", selection: Binding(
                get: { selection.color },
                set: { picked in
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    UIColor(picked).getRed(&r, green: &g, blue: &b, alpha: &a)
                    selection = ClockColor(red: r, green: g, blue: b)
                }), supportsOpacity: false)
                .labelsHidden()
                .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
        }
    }

    private func swatch(_ option: ClockColor) -> some View {
        let chosen = selection == option
        return Button {
            selection = option
        } label: {
            Circle()
                .fill(option == .auto ? AnyShapeStyle(.primary.opacity(0.15)) : AnyShapeStyle(option.color))
                .overlay {
                    if option == .auto { Text("A").font(.caption.bold()) }
                }
                .overlay { Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1) }
                .overlay { Circle().strokeBorder(.tint, lineWidth: chosen ? 3 : 0) }
                .frame(width: Theme.Size.swatch, height: Theme.Size.swatch)
                .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option == .auto ? "Automatic colour" : option.name)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
