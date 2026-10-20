import SwiftUI
import WidgetKit
import PhotosUI

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
    /// The style being edited. It's saved in the app as it changes, but only reaches the widget
    /// when applied, so half-finished changes never show on the Home Screen.
    @State private var style = ClockStyle.launchOverride ?? StyleLibrary.loadDraft() ?? ClockStyle.load()
    /// The style the widget shows.
    @State private var appliedStyle = ClockStyle.load()
    @AppStorage("applyWhenLeaving") private var applyWhenLeaving = true
    @AppStorage("openPanels") private var openPanelList = "Presets,Font,Text"
    private var openPanels: Set<String> {
        get { Set(openPanelList.split(separator: ",").map(String.init)) }
        nonmutating set { openPanelList = newValue.sorted().joined(separator: ",") }
    }
    @Environment(\.scenePhase) private var scenePhase
    @State private var customPresets = StyleLibrary.loadPresets()
    /// The saved preset being named: nil for a new one. Shown when `namingPreset` is true.
    @State private var presetIndex: Int?
    @State private var presetName = ""
    @State private var namingPreset = false
    @State private var previewSize = PreviewSize.medium
    @State private var homeScreen = HomeScreenStyle.light
    @AppStorage("workspaceLayout") private var layout = WorkspaceLayout.automatic
    /// The preview's share of the width (side by side) or height (stacked), set by dragging.
    @AppStorage("previewWidthShare") private var previewWidthShare = 0.42
    @AppStorage("previewHeightShare") private var previewHeightShare = 0.45
    @AppStorage("previewBackdrop") private var backdrop = PreviewBackdrop.plain
    @State private var backdropPhoto = BackdropPhoto.load()
    @State private var photoItem: PhotosPickerItem?
    @State private var choosingPhoto = false

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
                let size = geometry.size
                switch layout.resolved(width: size.width) {
                case .sideBySide:
                    // Settings keep at least 380 pt, so their controls never get cramped.
                    let widest = max(0.3, 1 - 380 / size.width)
                    HStack(spacing: 0) {
                        preview
                            .frame(width: size.width * min(previewWidthShare, widest))
                        SplitHandle(axis: .horizontal, fraction: $previewWidthShare,
                                    total: size.width, range: 0.25...widest)
                        settings
                    }
                case .previewOnly:
                    preview
                default:
                    VStack(spacing: 0) {
                        preview
                            .frame(height: size.height * previewHeightShare)
                        SplitHandle(axis: .vertical, fraction: $previewHeightShare,
                                    total: size.height, range: 0.25...0.8)
                        settings
                    }
                }
            }
            .animation(.smooth, value: layout)
            .navigationTitle("Glass Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Layout", selection: $layout) {
                            ForEach(WorkspaceLayout.allCases) { option in
                                Label(option.label, systemImage: option.symbol).tag(option)
                            }
                        }
                    } label: {
                        Label("Layout", systemImage: layout.symbol)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    let applied = style == appliedStyle
                    Button(action: apply) {
                        HStack(spacing: 6) {
                            Image(systemName: applied ? "checkmark.circle.fill" : "arrow.down.circle")
                            Text(applied ? "Applied" : "Apply to Widget")
                        }
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(applied)
                    .sensoryFeedback(.success, trigger: appliedStyle)
                }
            }
        }
        .photosPicker(isPresented: $choosingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            Task {
                guard let data = try? await photoItem?.loadTransferable(type: Data.self),
                      let image = BackdropPhoto.save(data) else { return }
                backdropPhoto = image
                backdrop = .photo
            }
        }
        .onChange(of: backdrop) {
            if backdrop == .photo && backdropPhoto == nil { choosingPhoto = true }
        }
        .alert(presetIndex == nil ? "Save Preset" : "Rename Preset", isPresented: $namingPreset) {
            TextField("Name", text: $presetName)
            Button("Save", action: savePreset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(presetIndex == nil ? "Saves the current style so you can come back to it." : "")
        }
        .onAppear {
            // A style passed in for testing (debug builds only) is applied, so the widget shows it too.
            if ClockStyle.launchOverride != nil { apply() }
        }
        .onChange(of: style) {
            StyleLibrary.saveDraft(style)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background && applyWhenLeaving && style != appliedStyle { apply() }
        }
    }

    /// Sends the edited style to the widget.
    private func apply() {
        style.save()
        WidgetCenter.shared.reloadAllTimelines()
        withAnimation(.snappy) { appliedStyle = style }
    }

    private func savePreset() {
        let name = presetName.trimmingCharacters(in: .whitespaces)
        if let presetIndex {
            customPresets[presetIndex].name = name.isEmpty ? customPresets[presetIndex].name : name
        } else {
            customPresets.append(CustomPreset(name: name.isEmpty ? "My Style" : name, style: style))
        }
        StyleLibrary.savePresets(customPresets)
    }

    private var preview: some View {
        ZStack {
            backdropView
                .ignoresSafeArea(edges: [.bottom, .horizontal])

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

    /// What's behind the card. Plain is white or black, so the card looks as it will on a
    /// plain Home Screen; Clear and Tinted need a wallpaper for their white content to show up.
    @ViewBuilder
    private var backdropView: some View {
        switch backdrop {
        case .plain where homeScreen.accent == nil:
            homeScreen == .dark ? Color.black : Color.white
        case .photo where backdropPhoto != nil:
            Color.clear.overlay {
                Image(uiImage: backdropPhoto!)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
        default:
            LinearGradient(colors: backdrop.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Side by side when they fit, otherwise stacked, on a glass panel so they stay readable
    /// over any backdrop (glass for the controls layer, HIG: Materials).
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
        let backdropMenu = labelled("Backdrop") {
            HStack(spacing: Space.small) {
                Picker("Backdrop", selection: $backdrop) {
                    ForEach(PreviewBackdrop.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                if backdrop == .photo {
                    Button("Change…") { choosingPhoto = true }
                }
            }
        }
        // Fills the width it's given: one row when everything fits, otherwise the two pickers
        // share a row and the backdrop sits below, otherwise one per row.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Space.large) {
                homePicker.frame(minWidth: 300, maxWidth: .infinity)
                sizePicker.frame(minWidth: 340, maxWidth: .infinity)
                backdropMenu.fixedSize()
            }
            VStack(alignment: .leading, spacing: Space.medium) {
                HStack(alignment: .top, spacing: Space.large) {
                    homePicker.frame(minWidth: 300, maxWidth: .infinity)
                    sizePicker.frame(minWidth: 340, maxWidth: .infinity)
                }
                backdropMenu
            }
            VStack(alignment: .leading, spacing: Space.medium) {
                homePicker.frame(maxWidth: .infinity)
                sizePicker.frame(maxWidth: .infinity)
                backdropMenu
            }
        }
        .padding(Space.large)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
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
            panel("Presets", icon: "sparkles",
                  footer: "Save up to \(StyleLibrary.maxCustomPresets) of your own. Long-press one to update, rename or delete it.") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.smooth) { style = .lucky(from: style) }
                        } label: {
                            Label("I'm Feeling Lucky", systemImage: "dice")
                        }
                        .buttonStyle(.borderedProminent)
                        ForEach(customPresets.indices, id: \.self) { index in
                            customPresetButton(index)
                        }
                        if customPresets.count < StyleLibrary.maxCustomPresets {
                            Button {
                                presetIndex = nil
                                presetName = "My Style \(customPresets.count + 1)"
                                namingPreset = true
                            } label: {
                                Label("Save Current", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                        ForEach(ClockStyle.presets, id: \.name) { preset in
                            Button(preset.name) { style = preset.style }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            panel("Font", icon: "textformat") {
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

            panel("Text", icon: "paintbrush") {
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
                slider("Transparency", value: $style.textOpacity, in: ClockStyle.textOpacityRange, low: "Faint", high: "Solid")
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

            panel("AM/PM and Date", icon: "calendar",
                  footer: "Size, gap and letter spacing shape the line under (or beside) the time.") {
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
                Picker("Font", selection: $style.detailFont) {
                    ForEach(DetailFont.allCases) { option in
                        Text(option == .paired ? "Matched: \(style.font.pairing.label)" : option.label).tag(option)
                    }
                }
                slider("Size", value: $style.detailSize, in: 0.7...1.6, low: "Small", high: "Large")
                slider("Gap", value: $style.detailGap, in: 0.3...2.5, low: "Close", high: "Far")
                slider("Letter spacing", value: $style.detailTracking, in: -0.06...0.25, low: "Tight", high: "Wide")
            }

            panel("Glow", icon: "sun.max") {
                Toggle("Glow", isOn: $style.glow)
                if style.glow {
                    swatchRow(selection: $style.glowColor)
                    slider("Size", value: $style.glowSize, in: 0...1, low: "Tight", high: "Wide")
                    slider("Strength", value: $style.glowStrength, in: 0.1...1, low: "Soft", high: "Strong")
                }
            }

            panel("Shadow", icon: "shadow", footer: "Automatic is black. Pick white for a light shadow.") {
                Toggle("Shadow", isOn: $style.shadow)
                if style.shadow {
                    swatchRow(selection: $style.shadowColor)
                    slider("Direction", value: $style.shadowAngle, in: 0...180, low: "Right", high: "Left")
                    slider("Distance", value: $style.shadowDistance, in: 0...1, low: "Close", high: "Far")
                    slider("Softness", value: $style.shadowSize, in: 0...1, low: "Sharp", high: "Soft")
                    slider("Strength", value: $style.shadowStrength, in: 0.1...1, low: "Light", high: "Dark")
                }
            }

            panel("Card", icon: "rectangle.on.rectangle",
                  footer: "When your Home Screen uses the Clear or Tinted style, iPadOS supplies the card and colour. Liquid Glass text keeps its glass look.") {
                Picker("Style", selection: $style.background) {
                    ForEach(CardBackground.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                swatchRow(selection: $style.backgroundColor)
                slider("Transparency", value: $style.cardOpacity, in: ClockStyle.cardOpacityRange, low: "Clear", high: "Solid")
            }

            panel("Clear and Tinted Home Screens", icon: "circle.lefthalf.filled",
                  footer: "iPadOS normally redraws widgets in its own glass and colour on these Home Screens. Turn these on to bring your colours forward instead. Needs iPadOS 27 for Clear Home Screens; iPadOS 26 applies its own glass there regardless.") {
                Toggle("Keep time colours", isOn: $style.keepsTimeColours)
                Toggle("Keep AM/PM and date colours", isOn: $style.keepsDetailColours)
                Toggle("Keep card colours", isOn: $style.keepsCardColours)
            }

            panel("Applying Changes", icon: "arrow.down.circle",
                  footer: "Your changes are kept in the app as you go. They reach the widget when you tap Apply to Widget, or when you leave the app if this is on.") {
                Toggle("Apply when leaving the app", isOn: $applyWhenLeaving)
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

    /// A settings section that opens and closes from its header. Which ones are open is
    /// remembered, so people can keep the parts they use most at hand.
    private func panel<Content: View>(_ title: String, icon: String, footer: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        let open = openPanels.contains(title)
        return Section {
            if open { content() }
        } header: {
            Button {
                withAnimation(.snappy) {
                    if open { openPanels.remove(title) } else { openPanels.insert(title) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(open ? "Closes this section" : "Opens this section")
        } footer: {
            if open, let footer { Text(footer) }
        }
    }

    private func customPresetButton(_ index: Int) -> some View {
        Button {
            style = customPresets[index].style
        } label: {
            Label(customPresets[index].name, systemImage: "star.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .contextMenu {
            Button("Update to Current Style", systemImage: "arrow.triangle.2.circlepath") {
                customPresets[index].style = style
                StyleLibrary.savePresets(customPresets)
            }
            Button("Rename…", systemImage: "pencil") {
                presetIndex = index
                presetName = customPresets[index].name
                namingPreset = true
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                customPresets.remove(at: index)
                StyleLibrary.savePresets(customPresets)
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
