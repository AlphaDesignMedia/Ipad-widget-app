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
    @State private var homeScreen = HomeScreenStyle.light
    @State private var reloadTask: Task<Void, Never>?
    @State private var justApplied = false

    /// Spacing on an 8-point grid (HIG: Layout).
    private enum Space {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                // Side by side when there's room (a full-screen iPad in landscape); stacked in
                // portrait and in narrower Split View or Stage Manager windows.
                if geometry.size.width >= 1000 {
                    HStack(spacing: 0) {
                        // Settings get at least 600 pt, so a row of colour swatches fits on one line.
                        preview
                            .frame(width: min(geometry.size.width * 0.5, geometry.size.width - 600))
                        Divider()
                            .ignoresSafeArea()
                        settings
                    }
                } else {
                    VStack(spacing: 0) {
                        preview
                            .frame(height: min(500, max(340, geometry.size.height * 0.45)))
                        settings
                    }
                }
            }
            .navigationTitle("Glass Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: apply) {
                        HStack(spacing: 6) {
                            Image(systemName: justApplied ? "checkmark.circle.fill" : "arrow.down.circle")
                            Text(justApplied ? "Applied" : "Apply to Widget")
                        }
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .sensoryFeedback(.success, trigger: justApplied) { _, applied in applied }
                }
            }
        }
        .onAppear {
            // A style passed in for testing (debug builds only) is saved, so the widget shows it too.
            if ClockStyle.launchOverride != nil {
                style.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onChange(of: style) {
            style.save()
            justApplied = false
            // Wait for the slider to settle before asking widgets to redraw.
            reloadTask?.cancel()
            reloadTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Changes already reach the widget on their own; this sends them straight away and says so.
    private func apply() {
        reloadTask?.cancel()
        style.save()
        WidgetCenter.shared.reloadAllTimelines()
        withAnimation(.snappy) { justApplied = true }
    }

    private var preview: some View {
        ZStack {
            // Plain white, so the card looks the same as it will on the Home Screen. Clear
            // and Tinted get a wallpaper, since their white or tinted content needs one to show up.
            if homeScreen.accent == nil {
                (homeScreen == .dark ? Color.black : Color.white)
                    .ignoresSafeArea(edges: [.bottom, .horizontal])
            } else {
                LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea(edges: [.bottom, .horizontal])
            }

            VStack(spacing: Space.large) {
                Spacer(minLength: 0)
                // Labelled so the preview isn't mistaken for a working widget (HIG: Widgets).
                Text("Preview")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                // The card is drawn at the real widget size and scaled down to fit narrow windows,
                // so what you see is exactly what the widget draws.
                GeometryReader { space in
                    let card = previewSize.size
                    let scale = min(1, space.size.width / card.width, space.size.height / card.height)
                    TimelineView(.everyMinute) { context in
                        ClockFace(date: context.date, style: style, simulatedAccent: homeScreen.accent,
                                  simulatesClear: !homeScreen.showsKeptColours)
                            .padding(16)
                            .frame(width: card.width, height: card.height)
                            .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28), homeScreen: homeScreen))
                            .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
                    }
                    .scaleEffect(scale)
                    .frame(width: space.size.width, height: space.size.height)
                }
                // No taller than the card itself, so the controls stay close to it.
                .frame(maxHeight: previewSize.size.height)
                .animation(.smooth, value: previewSize)

                previewControls
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.large)
            .padding(.top, Space.medium)
            .padding(.bottom, Space.large)
        }
        // The labels and pickers follow the backdrop, so they stay readable when the iPad is
        // in dark mode but the Light preview is on.
        .environment(\.colorScheme, homeScreen == .light ? .light : .dark)
    }

    /// Side by side when they fit, otherwise stacked.
    private var previewControls: some View {
        let homePicker = labelled("Home Screen") {
            Picker("Home Screen style", selection: $homeScreen) {
                ForEach(HomeScreenStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        let sizePicker = labelled("Widget size") {
            Picker("Widget size", selection: $previewSize) {
                ForEach(PreviewSize.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Space.large) {
                homePicker.frame(minWidth: 300)
                sizePicker.frame(minWidth: 340)
            }
            VStack(spacing: Space.medium) {
                homePicker
                sizePicker
            }
            .frame(maxWidth: 440)
        }
    }

    private func labelled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.small) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var settings: some View {
        Form {
            Section("Presets") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.smooth) { style = .lucky(from: style) }
                        } label: {
                            Label("I'm Feeling Lucky", systemImage: "dice")
                        }
                        .buttonStyle(.borderedProminent)
                        ForEach(ClockStyle.presets, id: \.name) { preset in
                            Button(preset.name) { style = preset.style }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("Font") {
                Picker("Font", selection: $style.font) {
                    ForEach(ClockFont.allCases) { Text($0.label).tag($0) }
                }
                slider("Weight", value: $style.fontWeight, in: 0...1, low: "Thin", high: "Heavy")
                if style.font.hasWidth {
                    slider("Width", value: $style.fontWidth, in: 0...1, low: "Narrow", high: "Wide")
                }
                if style.font.hasRoundness {
                    slider("Roundness", value: $style.roundness, in: 0...1, low: "Sharp", high: "Round")
                }
                slider("Height", value: $style.height, in: ClockStyle.heightRange, low: "Normal", high: "Tall")
                Toggle("Stretch to fill square widgets", isOn: $style.fillsCard)
                Toggle("Bolder in small widgets", isOn: $style.adaptsToSize)
                slider("Spacing", value: $style.spacing, in: ClockStyle.spacingRange, low: "Tight", high: "Loose")
                slider("Corners", value: $style.softness, in: 0...1, low: "Sharp", high: "Soft")
            }

            Section("Text") {
                Picker("Style", selection: $style.textFill) {
                    ForEach(TextFill.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                swatchRow(selection: $style.color)
                if style.textFill == .gradient {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fades to")
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inner colour")
                    swatchGrid {
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
                if style.showDate {
                    Toggle("Date above the time", isOn: $style.dateAbove)
                }
            }

            Section {
                Toggle("Keep time colours", isOn: $style.keepsTimeColours)
                Toggle("Keep AM/PM and date colours", isOn: $style.keepsDetailColours)
                Toggle("Keep card colours", isOn: $style.keepsCardColours)
            } header: {
                Text("Clear and Tinted Home Screens")
            } footer: {
                Text("iPadOS normally redraws widgets in its own glass and colour on these Home Screens. Turn these on to bring your colours forward instead. Needs iPadOS 27 for Clear Home Screens; iPadOS 26 applies its own glass there regardless.")
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

    /// Swatches wrap onto more rows when the window is narrow.
    private func swatchRow(selection: Binding<ClockColor>) -> some View {
        swatchGrid {
            ForEach(ClockColor.allCases) { option in
                colorSwatch(option, selection: selection)
            }
        }
    }

    private func swatchGrid(@ViewBuilder content: () -> some View) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 44), spacing: 4)], alignment: .leading, spacing: 4) {
            content()
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
