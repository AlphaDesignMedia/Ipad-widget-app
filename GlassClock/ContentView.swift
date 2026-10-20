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
    @State private var style = ClockStyle.load()
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
                    ClockFace(date: context.date, style: style, family: previewSize.family)
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
                LabeledContent("Weight") {
                    Slider(value: $style.weight, in: ClockStyle.weightRange) {
                        Text("Weight")
                    } minimumValueLabel: {
                        Text("Thin").font(.caption)
                    } maximumValueLabel: {
                        Text("Bold").font(.caption)
                    }
                }
                LabeledContent("Width") {
                    Slider(value: $style.width, in: ClockStyle.widthRange) {
                        Text("Width")
                    } minimumValueLabel: {
                        Text("Narrow").font(.caption)
                    } maximumValueLabel: {
                        Text("Wide").font(.caption)
                    }
                }
                LabeledContent("Height") {
                    Slider(value: $style.height, in: ClockStyle.heightRange) {
                        Text("Height")
                    } minimumValueLabel: {
                        Text("Normal").font(.caption)
                    } maximumValueLabel: {
                        Text("Tall").font(.caption)
                    }
                }
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
                Toggle("Glow", isOn: $style.glow)
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
                Toggle("Show date", isOn: $style.showDate)
                Toggle("Show AM/PM", isOn: $style.showAMPM)
                    .disabled(!style.uses12Hour)
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
