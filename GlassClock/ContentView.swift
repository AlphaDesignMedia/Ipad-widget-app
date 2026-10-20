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
    // A new key, so everyone starts with the new sections' defaults open.
    @AppStorage("openSections") private var openPanelList = "Fonts,Layout,Presets"
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
    /// Live positions while the divider is dragged; saved to the two values above when it's let go.
    @State private var draggingWidthShare: Double?
    @State private var draggingHeightShare: Double?
    @AppStorage("interfaceStyle") private var interface = InterfaceStyle.classic
    @State private var selectedSection: SettingsSection? = .presets
    @State private var showsInspector = true
    @State private var sidebarVisibility = NavigationSplitViewVisibility.all
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
        Group {
            switch interface {
            case .classic: classicInterface
            case .panels: panelsInterface
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

    /// The preview and one list of settings, side by side or stacked, with a divider to drag.
    private var classicInterface: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = geometry.size
                switch layout.resolved(width: size.width) {
                case .sideBySide:
                    // Settings keep at least 380 pt, so their controls never get cramped.
                    let widest = max(0.3, 1 - 380 / size.width)
                    let share = draggingWidthShare ?? previewWidthShare
                    HStack(spacing: 0) {
                        preview
                            .frame(width: size.width * min(share, widest))
                        SplitHandle(axis: .horizontal,
                                    fraction: Binding(get: { share }, set: { draggingWidthShare = $0 }),
                                    total: size.width, range: 0.25...widest) {
                            if let draggingWidthShare { previewWidthShare = draggingWidthShare }
                            draggingWidthShare = nil
                        }
                        settings
                    }
                case .previewOnly:
                    preview
                default:
                    let share = draggingHeightShare ?? previewHeightShare
                    VStack(spacing: 0) {
                        preview
                            .frame(height: size.height * share)
                        SplitHandle(axis: .vertical,
                                    fraction: Binding(get: { share }, set: { draggingHeightShare = $0 }),
                                    total: size.height, range: 0.25...0.8) {
                            if let draggingHeightShare { previewHeightShare = draggingHeightShare }
                            draggingHeightShare = nil
                        }
                        settings
                    }
                }
            }
            .animation(.smooth, value: layout)
            .navigationTitle("Glass Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { layoutMenu }
                ToolbarItem(placement: .primaryAction) { applyButton }
            }
        }
    }

    /// A glass sidebar of settings groups, the preview filling the window behind it, and the
    /// chosen group's controls in an inspector on the right. In narrow windows the system turns
    /// the inspector into a sheet.
    private var panelsInterface: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Glass Clock")
        } detail: {
            preview
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { layoutMenu }
                    ToolbarItem(placement: .primaryAction) { applyButton }
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.snappy) { showsInspector.toggle() }
                        } label: {
                            Label(showsInspector ? "Hide Settings" : "Show Settings", systemImage: "sidebar.trailing")
                        }
                    }
                }
                .inspector(isPresented: $showsInspector) {
                    let section = selectedSection ?? .presets
                    Form {
                        Section {
                            sectionContent(section)
                        } header: {
                            Label(section.title, systemImage: section.icon)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                        } footer: {
                            if let footer = section.footer { Text(footer) }
                        }
                    }
                    .inspectorColumnWidth(min: 340, ideal: 400, max: 520)
                    .presentationDetents([.medium, .large])
                }
        }
        .onChange(of: selectedSection) {
            if selectedSection != nil { showsInspector = true }
        }
    }

    /// Switches between the interfaces, and between the Classic interface's arrangements.
    private var layoutMenu: some View {
        Menu {
            Picker("Interface", selection: $interface) {
                ForEach(InterfaceStyle.allCases) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            }
            if interface == .classic {
                Section("Arrangement") {
                    Picker("Arrangement", selection: $layout) {
                        ForEach(WorkspaceLayout.allCases) { option in
                            Label(option.label, systemImage: option.symbol).tag(option)
                        }
                    }
                }
            }
        } label: {
            Label("Layout", systemImage: interface == .panels ? interface.symbol : layout.symbol)
        }
    }

    private var applyButton: some View {
        let applied = style == appliedStyle
        return Button(action: apply) {
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
                .backgroundExtensionEffect()
                .ignoresSafeArea(edges: [.bottom, .horizontal])

            // Separate glass bubbles float around the card: the Home Screen style above it,
            // widget size and backdrop below.
            VStack(spacing: Space.large) {
                Spacer(minLength: 0)
                homeScreenBubble
                // Labelled so the preview isn't mistaken for a working widget (HIG: Widgets).
                Text("Preview")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                // The card keeps the real widget's proportions, shrunk to fit narrow windows. It's
                // drawn at that size rather than drawn full size and scaled down: scaling turned
                // the glass into a blurry picture (owner feedback, 2026-10-20).
                GeometryReader { space in
                    let card = previewSize.size
                    let scale = min(1, space.size.width / card.width, space.size.height / card.height)
                    TimelineView(.everyMinute) { context in
                        ClockFace(date: context.date, style: style, simulatedAccent: homeScreen.accent,
                                  simulatesClear: !homeScreen.showsKeptColours)
                            .padding(16 * scale)
                            .frame(width: card.width * scale, height: card.height * scale)
                            .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28 * scale), homeScreen: homeScreen))
                            .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
                    }
                    .frame(width: space.size.width, height: space.size.height)
                }
                // No taller than the card itself, so the controls stay close to it.
                .frame(maxHeight: previewSize.size.height)
                .animation(.smooth, value: previewSize)

                // Side by side when they fit, otherwise one above the other.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Space.medium) {
                        sizeBubble
                        backdropBubble
                    }
                    VStack(spacing: Space.medium) {
                        sizeBubble
                        backdropBubble
                    }
                }
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

    /// A capsule of glass for a preview control (glass is for the controls layer, HIG: Materials).
    private func bubble(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, Space.small)
            .padding(.vertical, Space.small)
            .glassEffect(.regular, in: .capsule)
    }

    private var homeScreenBubble: some View {
        bubble {
            Picker("Home Screen style", selection: $homeScreen) {
                ForEach(HomeScreenStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        }
    }

    private var sizeBubble: some View {
        bubble {
            Picker("Widget size", selection: $previewSize) {
                ForEach(PreviewSize.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 380)
        }
    }

    private var backdropBubble: some View {
        bubble {
            Menu {
                Picker("Backdrop", selection: $backdrop) {
                    ForEach(PreviewBackdrop.allCases) { Text($0.label).tag($0) }
                }
                if backdrop == .photo {
                    Button("Choose Another Photo…", systemImage: "photo.on.rectangle") { choosingPhoto = true }
                }
            } label: {
                HStack(spacing: Space.small) {
                    backdropThumbnail
                    Text(backdrop.label)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, Space.small)
            }
            .fixedSize()
            .accessibilityLabel("Backdrop: \(backdrop.label)")
        }
    }

    /// A small circle showing the current backdrop.
    private var backdropThumbnail: some View {
        Group {
            if backdrop == .photo, let backdropPhoto {
                Image(uiImage: backdropPhoto).resizable().scaledToFill()
            } else if backdrop == .plain {
                homeScreen == .dark ? Color.black : Color.white
            } else {
                LinearGradient(colors: backdrop.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 1) }
    }

    /// Every settings group as a collapsible section, for the Classic interface.
    private var settings: some View {
        Form {
            ForEach(SettingsSection.allCases) { section in
                panel(section) { sectionContent(section) }
            }
        }
    }

    /// The controls for one settings group, shared by both interfaces. Bigger groups are split
    /// into small labelled parts.
    @ViewBuilder
    private func sectionContent(_ section: SettingsSection) -> some View {
        switch section {
        case .presets:
            // Wraps into rows, so it reads well in the narrower inspector too.
            FlowLayout(spacing: 10) {
                Button {
                    withAnimation(.smooth) { style = .lucky(from: style) }
                } label: {
                    // An explicit icon and text: a Label here measured wrongly in the wrapping
                    // layout and lost its text.
                    HStack(spacing: 6) { Image(systemName: "dice"); Text("I'm Feeling Lucky") }
                }
                .buttonStyle(.borderedProminent)
                .fixedSize()
                ForEach(customPresets.indices, id: \.self) { index in
                    customPresetButton(index)
                }
                if customPresets.count < StyleLibrary.maxCustomPresets {
                    Button {
                        presetIndex = nil
                        presetName = "My Style \(customPresets.count + 1)"
                        namingPreset = true
                    } label: {
                        HStack(spacing: 6) { Image(systemName: "plus"); Text("Save Current") }
                    }
                    .buttonStyle(.bordered)
                    .fixedSize()
                }
                ForEach(ClockStyle.presets, id: \.name) { preset in
                    Button(preset.name) { style = preset.style }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)

        case .layout:
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
            slider("Gap", value: $style.detailGap, in: 0.3...2.5, low: "Close", high: "Far")
            Toggle("Stretch to fill square widgets", isOn: $style.fillsCard)

        case .fonts:
            groupLabel("Time")
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
            slider("Spacing", value: $style.spacing, in: ClockStyle.spacingRange, low: "Tight", high: "Loose")
            slider("Corners", value: $style.softness, in: 0...1, low: "Sharp", high: "Soft")
            Toggle("Bolder in small widgets", isOn: $style.adaptsToSize)

            groupLabel("AM/PM and date")
            Picker("Font", selection: $style.detailFont) {
                ForEach(DetailFont.allCases) { option in
                    Text(option == .paired ? "Matched: \(style.font.pairing.label)" : option.label).tag(option)
                }
            }
            slider("Size", value: $style.detailSize, in: 0.7...1.6, low: "Small", high: "Large")
            slider("Letter spacing", value: $style.detailTracking, in: -0.06...0.25, low: "Tight", high: "Wide")

        case .colour:
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

        case .effects:
            groupLabel("Inner colour")
            Toggle("Inner colour", isOn: Binding(
                get: { style.innerColor != nil },
                set: { style.innerColor = $0 ? (style.innerColor ?? .orange) : nil }
            ))
            if style.innerColor != nil {
                swatchGrid {
                    ForEach(ClockColor.allCases.filter { $0 != .auto }) { option in
                        colorSwatch(option, selection: Binding(
                            get: { style.innerColor ?? .auto },
                            set: { style.innerColor = $0 }
                        ))
                    }
                }
                slider("Strength", value: $style.innerStrength, in: 0.1...1, low: "Subtle", high: "Strong")
            }

            groupLabel("Glow")
            Toggle("Glow", isOn: $style.glow)
            if style.glow {
                swatchRow(selection: $style.glowColor)
                slider("Size", value: $style.glowSize, in: 0...1, low: "Tight", high: "Wide")
                slider("Strength", value: $style.glowStrength, in: 0.1...1, low: "Soft", high: "Strong")
            }

            groupLabel("Shadow")
            Toggle("Shadow", isOn: $style.shadow)
            if style.shadow {
                swatchRow(selection: $style.shadowColor)
                slider("Direction", value: $style.shadowAngle, in: ClockStyle.shadowAngleRange, low: "Right", high: "Left")
                slider("Distance", value: $style.shadowDistance, in: 0...1, low: "Close", high: "Far")
                slider("Softness", value: $style.shadowSize, in: 0...1, low: "Crisp", high: "Soft")
                slider("Strength", value: $style.shadowStrength, in: ClockStyle.shadowStrengthRange, low: "Light", high: "Dark")
            }

        case .card:
            Picker("Style", selection: $style.background) {
                ForEach(CardBackground.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            swatchRow(selection: $style.backgroundColor)
            slider("Transparency", value: $style.cardOpacity, in: ClockStyle.cardOpacityRange, low: "Clear", high: "Solid")

        case .homeScreens:
            Toggle("Keep time colours", isOn: $style.keepsTimeColours)
            Toggle("Keep AM/PM and date colours", isOn: $style.keepsDetailColours)
            Toggle("Keep card colours", isOn: $style.keepsCardColours)

        case .widget:
            Toggle("Apply when leaving the app", isOn: $applyWhenLeaving)
            Button("Reset to defaults", role: .destructive) {
                style = ClockStyle()
            }
        }
    }

    /// A small label that starts a group of settings inside a section.
    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 4)
            .listRowSeparator(.hidden, edges: .top)
    }

    /// A settings section that opens and closes from its header. Which ones are open is
    /// remembered, so people can keep the parts they use most at hand.
    private func panel<Content: View>(_ section: SettingsSection,
                                      @ViewBuilder content: () -> Content) -> some View {
        let title = section.title, icon = section.icon, footer = section.footer
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
            HStack(spacing: 6) { Image(systemName: "star.fill"); Text(customPresets[index].name) }
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .fixedSize()
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
