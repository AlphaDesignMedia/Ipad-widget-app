import SwiftUI
import WidgetKit

/// iPad widget sizes, used only to shape the in-app preview.
/// Canvas sizes for the 13-inch iPad (1024×1366 pt) from Apple's HIG widget specifications.
enum PreviewSize: String, CaseIterable, Identifiable {
    case small = "Small", medium = "Medium", large = "Large", extraLarge = "Extra Large"
    var id: Self { self }

    var size: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 378.5, height: 170)
        case .large: CGSize(width: 378.5, height: 378.5)
        case .extraLarge: CGSize(width: 795, height: 378.5)
        }
    }

    var family: WidgetFamily {
        switch self {
        case .small: .systemSmall
        case .medium: .systemMedium
        case .large: .systemLarge
        case .extraLarge: .systemExtraLarge
        }
    }
}

struct ContentView: View {
    @State private var style = ClockStyle.launchOverride ?? ClockStyle.load()
    @State private var previewSize = PreviewSize.medium
    @State private var reloadTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            preview
            settings
        }
        .onChange(of: style) {
            style.save()
            // Wait for the slider to settle before asking widgets to redraw.
            reloadTask?.cancel()
            reloadTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private var preview: some View {
        ZStack {
            // Plain white, so the card looks the same as it will on the Home Screen.
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Labelled so the preview isn't mistaken for a working widget (HIG: Widgets).
                Text("Preview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                TimelineView(.everyMinute) { context in
                    ClockFace(date: context.date, style: style)
                        .padding(16)
                        .frame(width: previewSize.size.width, height: previewSize.size.height)
                        .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28)))
                }
                .animation(.smooth, value: previewSize)

                Picker("Preview size", selection: $previewSize) {
                    ForEach(PreviewSize.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
            }
            .padding()
        }
        .frame(height: 520)
    }

    private var settings: some View {
        Form {
            Section("Font") {
                Picker("Font", selection: $style.font) {
                    ForEach(ClockFont.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                slider("Weight", value: $style.fontWeight, in: 0...1, low: "Thin", high: "Heavy")
                if style.font.hasWidth {
                    slider("Width", value: $style.fontWidth, in: 0...1, low: "Narrow", high: "Wide")
                }
                if style.font.hasRoundness {
                    slider("Roundness", value: $style.roundness, in: 0...1, low: "Sharp", high: "Round")
                }
                slider("Height", value: $style.height, in: ClockStyle.heightRange, low: "Normal", high: "Tall")
                slider("Spacing", value: $style.spacing, in: ClockStyle.spacingRange, low: "Tight", high: "Loose")
            }

            Section("Text") {
                Picker("Style", selection: $style.textFill) {
                    ForEach(TextFill.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                swatchRow(selection: $style.color)
                if style.textFill == .gradient {
                    LabeledContent("Fades to") {
                        swatchRow(selection: $style.gradientColor)
                    }
                }
                LabeledContent("Transparency") {
                    Slider(value: $style.textOpacity, in: ClockStyle.textOpacityRange) {
                        Text("Text transparency")
                    } minimumValueLabel: {
                        Text("Faint").font(.caption)
                    } maximumValueLabel: {
                        Text("Solid").font(.caption)
                    }
                }
                LabeledContent("Inner colour") {
                    HStack(spacing: 4) {
                        noneSwatch(isSelected: style.innerColor == nil) { style.innerColor = nil }
                        ForEach(ClockColor.allCases.filter { $0 != .auto }) { option in
                            colorSwatch(option, selection: Binding(
                                get: { style.innerColor ?? .auto },
                                set: { style.innerColor = $0 }
                            ))
                        }
                    }
                }
                if style.innerColor != nil {
                    slider("Inner strength", value: $style.innerStrength, in: 0.1...1, low: "Subtle", high: "Strong")
                }
            }

            Section("Glow and shadow") {
                Picker("Effect", selection: $style.effect) {
                    ForEach(LightEffect.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if style.effect != .none {
                    swatchRow(selection: $style.effectColor)
                    slider("Size", value: $style.effectSize, in: 0...1, low: "Tight", high: "Wide")
                    slider("Strength", value: $style.effectStrength, in: 0.1...1, low: "Soft", high: "Strong")
                    if style.effect == .shadow {
                        slider("Distance", value: $style.effectDistance, in: 0...1, low: "Close", high: "Far")
                    }
                }
            }

            Section {
                Picker("Style", selection: $style.background) {
                    ForEach(CardBackground.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                swatchRow(selection: $style.backgroundColor)
                LabeledContent("Transparency") {
                    Slider(value: $style.cardOpacity, in: ClockStyle.cardOpacityRange) {
                        Text("Card transparency")
                    } minimumValueLabel: {
                        Text("Clear").font(.caption)
                    } maximumValueLabel: {
                        Text("Solid").font(.caption)
                    }
                }
            } header: {
                Text("Card")
            } footer: {
                Text("When your Home Screen uses the Clear or Tinted style, iPadOS supplies the card and colour. Liquid Glass text keeps its glass look.")
            }

            Section("Display") {
                Picker("Time format", selection: $style.timeFormat) {
                    ForEach(TimeFormat.allCases) { Text($0.label).tag($0) }
                }
                Picker("AM/PM", selection: $style.ampm) {
                    ForEach(AMPMPlacement.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!style.uses12Hour)
                Toggle("Show date", isOn: $style.showDate)
            }

            Section {
                Button("Reset to defaults", role: .destructive) {
                    style = ClockStyle()
                }
            } footer: {
                Text("To add the clock: long-press your Home Screen, tap Edit, then Add Widget, and choose Glass Clock.")
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
                        low: String, high: String) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Text(low).font(.caption)
            } maximumValueLabel: {
                Text(high).font(.caption)
            }
        }
    }

    private func noneSwatch(isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .strokeBorder(.secondary.opacity(0.5), lineWidth: 1)
                .overlay { Image(systemName: "slash.circle").foregroundStyle(.secondary) }
                .overlay { Circle().strokeBorder(.tint, lineWidth: isSelected ? 3 : 0) }
                .frame(width: 34, height: 34)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No inner colour")
    }

    private func swatchRow(selection: Binding<ClockColor>) -> some View {
        HStack(spacing: 4) {
            ForEach(ClockColor.allCases) { option in
                colorSwatch(option, selection: selection)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorSwatch(_ option: ClockColor, selection: Binding<ClockColor>) -> some View {
        Button {
            selection.wrappedValue = option
        } label: {
            Circle()
                .fill(option == .auto ? AnyShapeStyle(.primary.opacity(0.15)) : AnyShapeStyle(option.color))
                .overlay {
                    if option == .auto {
                        Text("A").font(.caption.bold()).foregroundStyle(.primary)
                    }
                }
                .overlay {
                    Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                }
                .overlay {
                    Circle().strokeBorder(.tint, lineWidth: selection.wrappedValue == option ? 3 : 0)
                }
                .frame(width: 34, height: 34)
                .frame(width: 44, height: 44)   // HIG minimum tap target
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option == .auto ? "Automatic colour" : option.rawValue.capitalized)
    }
}

#Preview {
    ContentView()
}
