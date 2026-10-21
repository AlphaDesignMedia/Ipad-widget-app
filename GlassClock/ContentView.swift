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
    /// Counts taps on Refresh Widget, to spin its arrow.
    @State private var refreshTurns = 0
    @AppStorage("applyWhenLeaving") private var applyWhenLeaving = true
    /// Swaps the app's glass panels for solid ones (also follows Reduce Transparency).
    @AppStorage("reduceGlass") private var reducesGlass = false
    @AppStorage("appTheme") private var appTheme = AppTheme.glass
    @AppStorage("glassAmount") private var glassAmount = GlassAmount.standard
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.automatic
    @Environment(\.scenePhase) private var scenePhase
    @State private var customPresets = StyleLibrary.loadPresets()
    /// Parts of the style that presets and Lucky leave alone. Clear and Tinted starts locked,
    /// since it's easy to undo by accident (owner feedback, 2026-10-21).
    @AppStorage("lockedParts") private var lockedPartList = StylePart.homeScreens.rawValue
    private var lockedParts: Set<StylePart> {
        get { Set(lockedPartList.split(separator: ",").compactMap { StylePart(rawValue: String($0)) }) }
        nonmutating set { lockedPartList = newValue.map(\.rawValue).sorted().joined(separator: ",") }
    }
    /// The saved preset being named: nil for a new one. Shown when `namingPreset` is true.
    @State private var presetIndex: Int?
    @State private var presetName = ""
    @State private var namingPreset = false
    @State private var previewSize = PreviewSize.medium
    @State private var homeScreen = HomeScreenStyle.light
    /// The Home Screen style the person actually uses; the preview opens on it.
    @AppStorage("myHomeScreen") private var myHomeScreen = MyHomeScreen.unknown
    /// The iPad's own appearance (the views below override theirs for the preview).
    @Environment(\.colorScheme) private var systemColorScheme
    private var mine: HomeScreenStyle? { myHomeScreen.style(in: systemColorScheme) }
    @AppStorage("workspaceLayout") private var layout = WorkspaceLayout.automatic
    @AppStorage("previewBackdrop") private var backdrop = PreviewBackdrop.plain
    @AppStorage("interfaceStyle") private var interface = InterfaceStyle.classic
    @State private var selectedSection: SettingsSection? = .presets
    @State private var showsInspector = true
    @State private var showsSidebar = true
    /// The window's width, for working out whether the sidebar fits beside the preview.
    @State private var windowWidth: CGFloat = 1200
    /// Counts jumps to a settings group, so jumping to the same group twice still scrolls.
    @State private var focusRequest = 0
    /// The group that's briefly lit up after a jump.
    @State private var highlighted: SettingsSection?
    @GestureState(resetTransaction: Transaction(animation: ContentView.cardSettle)) private var clockPinch: CGFloat = 1
    /// Where the widget sits on the preview's Home Screen grid (-1: the middle), remembered.
    @AppStorage("widgetColumn") private var widgetColumn = -1
    @AppStorage("widgetRow") private var widgetRow = -1
    /// How far the widget has been dragged from its slot, while it's being moved. It springs back
    /// to zero with the same spring that moves the widget to its new slot, so the two cancel out
    /// and the widget glides on from under the finger instead of jumping back first.
    @GestureState(resetTransaction: Transaction(animation: ContentView.cardSettle)) private var cardDrag: CGSize = .zero
    /// The spring the widget settles with after a drag or pinch.
    static let cardSettle = Animation.spring(response: 0.38, dampingFraction: 0.82)
    @State private var draggingCard = false
    /// Panel swipes are ignored for a moment after a widget drag, so moving the widget
    /// doesn't also open or close a panel.
    @State private var swipesPausedUntil = Date.distantPast
    /// How big the settings' text and rows are, as a step through `textSizes`. Pinch the
    /// settings to change it.
    @AppStorage("settingsTextSize") private var textSizeStep = 1
    @State private var pinchingTextStep: Int?
    /// The text-size bubble, shown while pinching and briefly after.
    @State private var showsTextSizeBubble = false
    @State private var hideTextSizeBubble: Task<Void, Never>?
    @GestureState(resetTransaction: Transaction(animation: .bouncy)) private var panelDrag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasSeenTour") private var hasSeenTour = false
    @State private var showsTour = false
    @State private var backdropPhoto = BackdropPhoto.load()
    @State private var photoItem: PhotosPickerItem?
    @State private var choosingPhoto = false
    /// Which way the next backdrop slides in: up from the bottom, or down from the top.
    @State private var backdropTravel = Edge.bottom
    /// The backdrop's name, shown briefly after it changes.
    @State private var backdropToast: String?

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
            case .classic: classicInterface.transition(interfaceTransition)
            case .panels: panelsInterface.transition(interfaceTransition)
            }
        }
        .tint(AppColor.resolve(appColor))
        .preferredColorScheme(appAppearance.colorScheme)
        .animation(.smooth, value: appTheme)
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
            showBackdropName()
        }
        .alert(presetIndex == nil ? "Save Preset" : "Rename Preset", isPresented: $namingPreset) {
            TextField("Name", text: $presetName)
            Button("Save", action: savePreset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(presetIndex == nil ? "Saves the current style so you can come back to it." : "")
        }
        .sheet(isPresented: $showsTour, onDismiss: { hasSeenTour = true }) {
            OnboardingView()
        }
        .onAppear {
            if let mine { homeScreen = mine }
        }
        .onChange(of: myHomeScreen) {
            if let mine { withAnimation(.snappy) { homeScreen = mine } }
        }
        .onChange(of: systemColorScheme) { old, _ in
            // Following the iPad between Light and Dark, unless another style is being tried.
            if myHomeScreen == .automatic, homeScreen == MyHomeScreen.automatic.style(in: old), let mine {
                withAnimation(.snappy) { homeScreen = mine }
            }
        }
        .onAppear {
            // A style passed in for testing (debug builds only) is applied, so the widget shows it too.
            if ClockStyle.launchOverride != nil { apply() }
            if !hasSeenTour && ClockStyle.launchOverride == nil { showsTour = true }
        }
        .onChange(of: style) {
            StyleLibrary.saveDraft(style)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background && applyWhenLeaving && style != appliedStyle { apply() }
            // Opening the app also nudges the widget, so it never stays out of date for long.
            if scenePhase == .active { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// The backdrop fills the window, with the preview on it and the settings in a fixed glass
    /// panel floating over it. The preview comes first: it gets the room the widget needs at
    /// its real size, and the settings take what's left, beside it when there's room and below
    /// when there isn't (owner direction, 2026-10-21: "the app goes around the widget's size").
    private var classicInterface: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = geometry.size
                let besideRoom = size.width - stageWidth - Space.medium * 3
                let arrangement = layout == .automatic
                    ? (besideRoom >= 340 ? WorkspaceLayout.sideBySide : .stacked) : layout
                ZStack {
                    backdropView
                        .ignoresSafeArea()
                    switch arrangement {
                    case .sideBySide:
                        HStack(spacing: Space.medium) {
                            previewStage
                            settingsPanel
                                .frame(width: min(480, max(340, besideRoom)))
                        }
                        .padding([.horizontal, .bottom], Space.medium)
                    case .previewOnly:
                        previewStage
                    default:
                        VStack(spacing: Space.medium) {
                            previewStage
                                .frame(height: min(stageHeight, max(300, size.height - 280)))
                            settingsPanel
                        }
                        .padding([.horizontal, .bottom], Space.medium)
                    }
                }
                .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: arrangement)
                .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: previewSize)
            }
            .animation(.smooth, value: layout)
            .navigationTitle("Glass Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
    }

    /// The settings on a glass panel, so the backdrop shows through around the rows.
    private var settingsPanel: some View {
        settings
            .dynamicTypeSize(settingsTextSize)
            .simultaneousGesture(settingsPinchGesture)
            .sensoryFeedback(.selection, trigger: settingsTextSize)
            .scrollContentBackground(.hidden)
            .clipShape(.rect(cornerRadius: Corner.panel))
            .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
            .overlay(alignment: .top) { textSizeOverlay }
    }

    /// Two floating glass panels over the full-window backdrop, like Classic's: a short list of
    /// groups on the left for jumping around, and every setting in one scrolling list on the
    /// right. Picking a group glides the list to it and lights it up. The panels slide in and out
    /// with a swipe across the preview or a tap on the glass tab at the edge; there are no
    /// sidebar buttons (owner feedback 2026-10-21: the system's edge-to-edge columns and toggle
    /// buttons on iPadOS 27 didn't look right).
    private var panelsInterface: some View {
        NavigationStack {
            GeometryReader { geometry in
                let besideRoom = geometry.size.width - stageWidth - Space.medium * 3
                    - (sidebarAlongside ? groupsWidth + Space.medium : 0)
                let settingsWidth = min(440, max(320, besideRoom))
                ZStack {
                    ZStack {
                        backdropView
                            .ignoresSafeArea()
                        previewStage
                            .padding(.leading, sidebarAlongside ? groupsWidth + Space.medium : 0)
                            .padding(.trailing, showsInspector ? settingsWidth + Space.medium : 0)
                            .offset(x: rubberBand(panelDrag))
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(panelSwipe)
                    // Double-tap the preview to clear both panels away, and again to bring them back.
                    .onTapGesture(count: 2, perform: toggleBothPanels)

                    HStack(alignment: .top, spacing: Space.medium) {
                        if showsSidebar {
                            groupsPanel
                                .dynamicTypeSize(settingsTextSize)
                                .frame(width: groupsWidth)
                                .transition(panelTransition(.leading))
                        }
                        Spacer(minLength: 0)
                        if showsInspector {
                            settingsList
                                .dynamicTypeSize(settingsTextSize)
                                .simultaneousGesture(settingsPinchGesture)
                                .sensoryFeedback(.selection, trigger: settingsTextSize)
                                .clipShape(.rect(cornerRadius: Corner.panel))
                                .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
                                .overlay(alignment: .top) { textSizeOverlay }
                                .frame(width: settingsWidth)
                                .transition(panelTransition(.trailing))
                        }
                    }
                    .padding([.horizontal, .bottom], Space.medium)
                }
                .overlay(alignment: .leading) {
                    if !showsSidebar {
                        edgeHandle("Show groups") { withAnimation(.snappy) { groupsCollapsed = true; showsSidebar = true } }
                    }
                }
                .overlay(alignment: .trailing) {
                    if !showsInspector {
                        edgeHandle("Show settings") { withAnimation(.snappy) { showsInspector = true } }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showsInspector)
            .sensoryFeedback(.impact(weight: .light), trigger: showsSidebar)
            .navigationTitle("Glass Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
        // The groups sit alongside in full when there's room beside the real-size preview and
        // the settings, fold to their icons when only that fits, and tuck away otherwise.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .onChange(of: windowWidth, initial: true) { fitSidebar() }
        .onChange(of: previewSize) { fitSidebar() }
    }

    /// The room the preview stage needs to show the widget at its real size, with its padding
    /// and the controls around it.
    private var stageWidth: CGFloat { max(previewSize.size.width, 420) + Space.large * 2 }
    private var stageHeight: CGFloat { previewSize.size.height + 220 }

    private func sidebarFits(collapsed: Bool) -> Bool {
        windowWidth >= stageWidth + (collapsed ? 68 : 230) + 340 + Space.medium * 4
    }

    /// Whether the sidebar is out and sits beside the preview (rather than over it).
    private var sidebarAlongside: Bool { showsSidebar && sidebarFits(collapsed: groupsCollapsed) }

    private func fitSidebar() {
        withAnimation(reduceMotion ? nil : .snappy) {
            if sidebarFits(collapsed: groupsCollapsed) {
                showsSidebar = true
            } else if sidebarFits(collapsed: true) {
                groupsCollapsed = true
                showsSidebar = true
            } else {
                showsSidebar = false
            }
        }
    }

    /// Moves the widget one slot (for VoiceOver's actions).
    private func moveWidget(_ dx: Int, _ dy: Int, grid: HomeGrid, slot: (column: Int, row: Int)) {
        let next = grid.clamped(column: slot.column + dx, row: slot.row + dy, span: previewSize.span)
        withAnimation(.snappy) { widgetColumn = next.column; widgetRow = next.row }
    }

    /// Clears both panels away for a full view of the clock, or brings them both back.
    private func toggleBothPanels() {
        withAnimation(reduceMotion ? nil : .snappy) {
            if showsSidebar || showsInspector {
                showsSidebar = false
                showsInspector = false
            } else {
                if !sidebarFits(collapsed: groupsCollapsed) { groupsCollapsed = true }
                showsSidebar = true
                showsInspector = true
            }
        }
    }

    /// The groups sidebar, full or folded down to its icons.
    @AppStorage("groupsCollapsed") private var groupsCollapsed = false
    private var groupsWidth: CGFloat { groupsCollapsed ? 68 : 230 }

    /// Switching between Classic and Panels cross-fades with a slight zoom, or just fades.
    private var interfaceTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97))
    }

    /// Panels slide in from their own edge, or fade when Reduce Motion is on.
    private func panelTransition(_ edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }

    /// The settings groups on a glass panel: a tap glides the settings to that group. It folds
    /// down to just its icons with the button at the top, to give the preview more room.
    private var groupsPanel: some View {
        ScrollView {
            VStack(spacing: 4) {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { groupsCollapsed.toggle() }
                } label: {
                    Image(systemName: groupsCollapsed ? "sidebar.right" : "sidebar.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: groupsCollapsed ? .center : .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(groupsCollapsed ? "Show group names" : "Show icons only")
                ForEach(SettingsSection.allCases) { section in
                    let selected = selectedSection == section
                    Button {
                        focus(section)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                                .frame(width: 24)
                            if !groupsCollapsed {
                                Text(section == .homeScreens ? "Home Screens" : section.title)
                                    .font(.body.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? .white : .primary)
                                    .lineLimit(1)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, groupsCollapsed ? 10 : 14)
                        .padding(.vertical, 11)
                        .background(selected ? Color.accentColor : .clear, in: .capsule)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(Space.small + 2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
        .animation(.snappy, value: selectedSection)
    }

    /// Every settings group, open, in one scrolling list. A jump from the sidebar (or the chips
    /// along the top when the sidebar is tucked away) glides to the group and lights it up.
    private var settingsList: some View {
        ScrollViewReader { proxy in
            Form {
                if !showsSidebar {
                    Section { jumpChips(proxy) }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                ForEach(SettingsSection.allCases) { section in
                    Section {
                        SettingsCard(title: section.title, icon: section.icon,
                                     highlighted: highlighted == section, footer: section.footer) {
                            sectionContent(section)
                        }
                        .settingsCardRow()
                        .id(section)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listSectionSpacing(Corner.inset)
            .contentMargins([.horizontal, .top], Corner.inset, for: .scrollContent)
            .contentMargins(.bottom, Space.extraLarge, for: .scrollContent)
            .task(id: focusRequest) {
                guard focusRequest > 0, let target = selectedSection else { return }
                // Lets a panel that's just opening settle before gliding.
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                withAnimation(.easeOut(duration: 0.25)) { highlighted = target }
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeInOut(duration: 0.6)) { highlighted = nil }
            }
        }
    }

    /// Small group buttons along the top of the settings, for when the sidebar is tucked away.
    private func jumpChips(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Space.small) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        focus(section)
                    } label: {
                        Label(section == .homeScreens ? "Home Screens" : section.title, systemImage: section.icon)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, Space.small)
                    }
                    .buttonStyle(.plain)
                    .appGlass(.capsule, interactive: true,
                              tint: selectedSection == section ? .accentColor.opacity(0.35) : nil)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    /// Opens the settings and glides them to a group.
    private func focus(_ section: SettingsSection) {
        selectedSection = section
        withAnimation(.snappy) { showsInspector = true }
        focusRequest += 1
    }

    /// A little glass tab on the edge of the preview, where a tucked-away panel lives. Tap it,
    /// or swipe in from that side.
    private func edgeHandle(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Capsule()
                .fill(.clear)
                .frame(width: 6, height: 64)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appGlass(.capsule, interactive: true)
        .padding(.horizontal, 6)
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
        .accessibilityLabel(label)
    }

    /// How far the preview leans while a swipe is under way: it follows the finger at first,
    /// then stiffens, so a swipe feels like pulling on something.
    private func rubberBand(_ x: CGFloat) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let limit: CGFloat = 36
        return limit * (1 - exp(-abs(x) / 120)) * (x < 0 ? -1 : 1)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if interface == .classic {
            ToolbarItem(placement: .topBarLeading) { layoutMenu }
        }
        ToolbarItem(placement: .topBarLeading) { tourButton }
        ToolbarItem(placement: .principal) { interfaceSwitch }
        ToolbarItem(placement: .primaryAction) { refreshButton }
        ToolbarItem(placement: .primaryAction) { applyButton }
    }

    /// Classic (simple) or Panels (everything), always one tap away in the middle of the top bar.
    private var interfaceSwitch: some View {
        Picker("Interface", selection: Binding(
            get: { interface },
            set: { next in withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { interface = next } }
        )) {
            // Words rather than icons: a segmented control shows only the icon of a Label.
            ForEach(InterfaceStyle.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
        .accessibilityHint("Classic keeps things simple; Panels has every setting")
    }

    /// Classic's arrangement of the preview and its settings.
    private var layoutMenu: some View {
        Menu {
            Picker("Arrangement", selection: $layout) {
                ForEach(WorkspaceLayout.allCases) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            }
        } label: {
            Label("Arrangement", systemImage: layout.symbol)
        }
    }

    /// Pinching the clock out steps up through the widget sizes, pinching in steps down.
    /// One gesture for the widget: two fingers pinch it to the next size up or down, one finger
    /// drags it to another slot on the grid. They're one gesture because a pinch moves too, and a
    /// separate drag would steal it.
    private func cardGesture(grid: HomeGrid, home: CGRect, span: (columns: Int, rows: Int)) -> some Gesture {
        MagnifyGesture()
            // Measured against the window, not the widget: the widget moves with the finger, so
            // measuring from it fed its own movement back in and made the drag jitter.
            .simultaneously(with: DragGesture(minimumDistance: 8, coordinateSpace: .global))
            .updating($clockPinch) { value, state, _ in
                if let pinch = value.first { state = pinch.magnification }
            }
            .updating($cardDrag) { value, state, _ in
                if value.first == nil, let drag = value.second { state = drag.translation }
            }
            .onChanged { value in
                if value.first == nil, value.second != nil, !draggingCard {
                    withAnimation(.snappy) { draggingCard = true }
                }
            }
            .onEnded { value in
                swipesPausedUntil = .now.addingTimeInterval(0.4)
                if let pinch = value.first {
                    let sizes = PreviewSize.allCases
                    guard let index = sizes.firstIndex(of: previewSize) else { return }
                    let m = pinch.magnification
                    let step = m > 1.15 ? (m > 1.9 ? 2 : 1) : m < 0.87 ? (m < 0.55 ? -2 : -1) : 0
                    let next = min(sizes.count - 1, max(0, index + step))
                    withAnimation(Self.cardSettle) { previewSize = sizes[next]; draggingCard = false }
                } else if let drag = value.second {
                    let end = CGPoint(x: home.midX + drag.translation.width, y: home.midY + drag.translation.height)
                    let target = grid.nearest(to: end, span: span)
                    withAnimation(reduceMotion ? nil : Self.cardSettle) {
                        widgetColumn = target.column
                        widgetRow = target.row
                        draggingCard = false
                    }
                } else {
                    withAnimation(Self.cardSettle) { draggingCard = false }
                }
            }
    }

    private let textSizes: [DynamicTypeSize] = [.medium, .large, .xLarge, .xxLarge, .xxxLarge]

    /// The settings' text size, following the fingers while a pinch is under way.
    private var settingsTextSize: DynamicTypeSize {
        textSizes[min(textSizes.count - 1, max(0, pinchingTextStep ?? textSizeStep))]
    }

    /// Pinching the settings makes their text and rows bigger or smaller, a step at a time.
    /// (An experiment, owner feedback 2026-10-21.)
    private var settingsPinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let steps = Int((log(value.magnification) / log(1.3)).rounded())
                let next = min(textSizes.count - 1, max(0, textSizeStep + steps))
                if next != pinchingTextStep { withAnimation(.snappy) { pinchingTextStep = next } }
                revealTextSizeBubble()
            }
            .onEnded { _ in
                if let pinchingTextStep { textSizeStep = pinchingTextStep }
                pinchingTextStep = nil
                revealTextSizeBubble()
            }
    }

    private let textSizeNames = ["Small", "Medium", "Large", "Extra Large", "Largest"]

    @ViewBuilder
    private var textSizeOverlay: some View {
        if showsTextSizeBubble {
            textSizeBubble
                .padding(.top, Space.medium)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.85)).combined(with: .move(edge: .top)))
        }
    }

    /// Shows the text-size bubble, and hides it again a moment after the last change.
    private func revealTextSizeBubble() {
        withAnimation(.snappy) { showsTextSizeBubble = true }
        hideTextSizeBubble?.cancel()
        hideTextSizeBubble = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { showsTextSizeBubble = false }
        }
    }

    /// Like the volume indicator: appears while pinching the settings, showing the text size,
    /// with − and + for fine-tuning while it's up.
    private var textSizeBubble: some View {
        let current = min(textSizes.count - 1, max(0, pinchingTextStep ?? textSizeStep))
        return VStack(spacing: Space.small) {
            HStack(spacing: Space.small) {
                Button {
                    textSizeStep = max(0, textSizeStep - 1)
                    revealTextSizeBubble()
                } label: {
                    Image(systemName: "textformat.size.smaller").frame(width: 32, height: 32)
                }
                .disabled(current == 0)
                .accessibilityLabel("Smaller text")
                HStack(spacing: 5) {
                    ForEach(textSizes.indices, id: \.self) { index in
                        Capsule()
                            .fill(index <= current ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.35)))
                            .frame(width: 22, height: 6)
                    }
                }
                Button {
                    textSizeStep = min(textSizes.count - 1, textSizeStep + 1)
                    revealTextSizeBubble()
                } label: {
                    Image(systemName: "textformat.size.larger").frame(width: 32, height: 32)
                }
                .disabled(current == textSizes.count - 1)
                .accessibilityLabel("Larger text")
            }
            .buttonStyle(.plain)
            .font(.body.weight(.semibold))
            Text(textSizeNames[current])
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Space.medium)
        .padding(.vertical, Space.small + 2)
        .appGlass(.capsule)
        // Its own fixed text size, so it doesn't grow while the settings do.
        .dynamicTypeSize(.large)
        .animation(.snappy, value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings text size: \(textSizeNames[current])")
    }

    /// Brings the tour back, for a refresher or to show someone.
    private var tourButton: some View {
        Button {
            showsTour = true
        } label: {
            Label("Show the Tour", systemImage: "questionmark.circle")
        }
    }

    /// Asks the widget to redraw now with the applied style, for when it looks out of date, for
    /// example after an install, or if iPadOS paused its updates. Unfinished edits aren't sent.
    private var refreshButton: some View {
        Button {
            WidgetCenter.shared.reloadAllTimelines()
            withAnimation(.smooth(duration: 0.6)) { refreshTurns += 1 }
        } label: {
            Label("Refresh Widget", systemImage: "arrow.clockwise")
                .rotationEffect(.degrees(360 * Double(refreshTurns)))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: refreshTurns)
        .accessibilityHint("Redraws the widget on your Home Screen")
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

    /// Horizontal swipes across the preview bring the panels in and out: a swipe right shows
    /// the groups list (or hides the settings), a swipe left shows the settings (or hides the list).
    private var panelSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .updating($panelDrag) { drag, state, _ in
                // Leans only for sideways drags, so scrolling up and down doesn't wobble, and not
                // while the widget itself is being moved or pinched.
                if !draggingCard, clockPinch == 1, abs(drag.translation.width) > abs(drag.translation.height) { state = drag.translation.width }
            }
            .onEnded { drag in
                guard !draggingCard, clockPinch == 1, Date.now > swipesPausedUntil else { return }
                let dx = drag.translation.width, dy = drag.translation.height
                // Up and down flick through the backdrops (not Your Photo, which opens a picker).
                if abs(dy) > 60, abs(dy) > abs(dx) * 1.5 {
                    let options = PreviewBackdrop.allCases.filter { $0 != .photo || backdropPhoto != nil }
                    let index = options.firstIndex(of: backdrop) ?? 0
                    backdropTravel = dy < 0 ? .bottom : .top
                    withAnimation(.smooth(duration: 0.55)) {
                        backdrop = options[(index + (dy < 0 ? 1 : options.count - 1)) % options.count]
                    }
                    return
                }
                guard abs(dx) > 60, abs(dx) > abs(drag.translation.height) * 1.5 else { return }
                withAnimation(.snappy) {
                    // A swipe right pulls the groups in from the left (their icons first, then the
                    // full list), or pushes the settings away. A swipe left pulls the settings in,
                    // or folds the groups to their icons, then tucks them away.
                    if dx > 0 {
                        if !showsSidebar {
                            groupsCollapsed = true
                            showsSidebar = true
                        } else if groupsCollapsed {
                            groupsCollapsed = false
                        } else {
                            showsInspector = false
                        }
                    } else {
                        if !showsInspector {
                            showsInspector = true
                        } else if showsSidebar && !groupsCollapsed {
                            groupsCollapsed = true
                        } else {
                            showsSidebar = false
                        }
                    }
                }
            }
    }

    /// The card with glass bubbles floating around it: the Home Screen style above, widget
    /// size and backdrop below.
    private var previewStage: some View {
            VStack(spacing: Space.large) {
                Spacer(minLength: 0)
                homeScreenBubble
                myHomeScreenNote
                // Labelled so the preview isn't mistaken for a working widget (HIG: Widgets).
                Text("Preview")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                // The card keeps the real widget's size (shrunk only if the window is too small),
                // on a Home Screen-style grid: drag it to another slot and it snaps there, like
                // moving a widget on the Home Screen. It's drawn at its size rather than scaled
                // down: scaling turned the glass into a blurry picture (owner feedback, 2026-10-20).
                GeometryReader { space in
                    let card = previewSize.size
                    let scale = min(1, space.size.width / card.width, space.size.height / card.height)
                    let grid = HomeGrid(area: space.size, scale: scale)
                    let span = previewSize.span
                    let slot = grid.clamped(column: widgetColumn, row: widgetRow, span: span)
                    let home = grid.frame(column: slot.column, row: slot.row, span: span)
                    let centre = CGPoint(x: home.midX + cardDrag.width, y: home.midY + cardDrag.height)
                    let landing = grid.nearest(to: centre, span: span)
                    ZStack(alignment: .topLeading) {
                        // While dragging: the empty slots, and where the widget will land.
                        if draggingCard {
                            ForEach(Array(grid.slotFrames.enumerated()), id: \.offset) { _, frame in
                                RoundedRectangle(cornerRadius: 22 * scale)
                                    .fill(.white.opacity(0.08))
                                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                            }
                            let target = grid.frame(column: landing.column, row: landing.row, span: span)
                            RoundedRectangle(cornerRadius: 28 * scale)
                                .fill(.white.opacity(0.18))
                                .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                                .frame(width: target.width, height: target.height)
                                .position(x: target.midX, y: target.midY)
                                .animation(.snappy, value: landing.column)
                                .animation(.snappy, value: landing.row)
                        }
                        TimelineView(.everyMinute) { context in
                            ClockFace(date: context.date, style: style, simulatedAccent: homeScreen.accent,
                                      simulatesClear: !homeScreen.showsKeptColours)
                                .padding(16 * scale)
                                .frame(width: card.width * scale, height: card.height * scale)
                                .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28 * scale), homeScreen: homeScreen))
                                .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
                                // Lifts while it's being moved, like a widget on the Home Screen.
                                .scaleEffect(draggingCard && !reduceMotion ? 1.04 : 1)
                                .shadow(color: .black.opacity(draggingCard ? 0.3 : 0), radius: 24, y: 12)
                                // Grows and shrinks with the fingers while pinching, then settles
                                // on the nearest widget size.
                                .scaleEffect(reduceMotion ? 1 : min(1.6, max(0.6, clockPinch)))
                                .contentShape(.rect)
                                // Double-tap clears the panels away (as on the rest of the preview);
                                // a single tap in Panels goes straight to the fonts.
                                .onTapGesture(count: 2) { if interface == .panels { toggleBothPanels() } }
                                .onTapGesture {
                                    if interface == .panels { focus(.fonts) }
                                }
                                .gesture(cardGesture(grid: grid, home: home, span: span))
                                .sensoryFeedback(.impact(weight: .light), trigger: draggingCard)
                                .sensoryFeedback(.selection, trigger: landing.column * 100 + landing.row)
                                .accessibilityHint("Drag to move it on the Home Screen grid. Pinch to change the widget size.")
                                .accessibilityAction(named: "Move left") { moveWidget(-1, 0, grid: grid, slot: slot) }
                                .accessibilityAction(named: "Move right") { moveWidget(1, 0, grid: grid, slot: slot) }
                                .accessibilityAction(named: "Move up") { moveWidget(0, -1, grid: grid, slot: slot) }
                                .accessibilityAction(named: "Move down") { moveWidget(0, 1, grid: grid, slot: slot) }
                        }
                        .position(x: centre.x, y: centre.y)
                    }
                    .frame(width: space.size.width, height: space.size.height)
                }
                // In Panels the preview is a Home Screen to move the widget around; in Classic
                // it's no taller than the card, so the controls stay close to it.
                .frame(maxHeight: interface == .panels ? .infinity : previewSize.size.height)
                .animation(.smooth, value: previewSize)
                .sensoryFeedback(.selection, trigger: previewSize)
                .zIndex(1)

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
            .overlay(alignment: .top) {
                if let backdropToast {
                    Text(backdropToast)
                        .font(.headline)
                        .padding(.horizontal, Space.medium)
                        .padding(.vertical, Space.small)
                        .appGlass(.capsule)
                        .padding(.top, Space.small)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8)))
                        .accessibilityHidden(true)
                }
            }
            // The labels and pickers follow the backdrop, so they stay readable when the iPad
            // is in dark mode but the Light preview is on.
            .environment(\.colorScheme, homeScreen == .light ? .light : .dark)
    }

    /// What's behind the card, sliding in when it changes: up for a swipe up or a pick from the
    /// menu, down for a swipe down. With Reduce Motion it fades instead.
    private var backdropView: some View {
        ZStack {
            backdropFill
                .id(backdrop)
                .transition(reduceMotion ? .opacity : .push(from: backdropTravel))
        }
        .animation(.smooth(duration: 0.55), value: backdrop)
        .clipped()
    }

    /// Briefly shows the new backdrop's name over the preview.
    private func showBackdropName() {
        let name = backdrop.label
        withAnimation(.snappy) { backdropToast = name }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            if backdropToast == name { withAnimation(.easeOut(duration: 0.4)) { backdropToast = nil } }
            backdropTravel = .bottom
        }
    }

    /// Plain is white or black, so the card looks as it will on a plain Home Screen; Clear and
    /// Tinted need a wallpaper for their white content to show up.
    @ViewBuilder
    private var backdropFill: some View {
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
            .appGlass(.capsule)
    }

    /// Under the Home Screen picker: a question until the person says which style they use,
    /// then a quiet confirmation, or a nudge when they're previewing a different style.
    @ViewBuilder
    private var myHomeScreenNote: some View {
        Group {
            if mine == nil {
                bubble {
                    myHomeScreenMenu {
                        HStack(spacing: Space.small) {
                            Image(systemName: "questionmark.circle.fill")
                            Text("Which Home Screen style do you use?")
                            Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, Space.small)
                        .padding(.vertical, 6)
                    }
                }
            } else if let mine, homeScreen != mine {
                VStack(spacing: 6) {
                    bubble {
                        HStack(spacing: Space.small) {
                            Image(systemName: "info.circle.fill").foregroundStyle(.tint)
                            Text("Previewing \(homeScreen.rawValue). Your Home Screen is \(mine.rawValue).")
                                .font(.subheadline)
                            Button("Show Mine") { withAnimation(.snappy) { homeScreen = mine } }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .padding(.leading, Space.small)
                    }
                    Text("To use \(homeScreen.rawValue) on your iPad: long-press the Home Screen, tap Edit, then Customise.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                bubble {
                    myHomeScreenMenu {
                        Label("Your Home Screen", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, Space.small)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.snappy, value: homeScreen)
        .animation(.snappy, value: myHomeScreen)
    }

    private func myHomeScreenMenu(@ViewBuilder label: () -> some View) -> some View {
        Menu {
            Picker("My Home Screen", selection: $myHomeScreen) {
                ForEach(MyHomeScreen.allCases.filter { $0 != .unknown }) { Text($0.label).tag($0) }
            }
        } label: {
            label()
        }
        .accessibilityLabel("My Home Screen style: \(myHomeScreen.label)")
    }

    private var homeScreenBubble: some View {
        bubble {
            HomeStylePicker(selection: $homeScreen)
                .frame(maxWidth: 440)
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

    /// Classic keeps to the basics: presets, the font and the colour. Everything else is in
    /// Panels, a tap away (owner direction, 2026-10-21: "keep Classic as simple as possible").
    private var settings: some View {
        Form {
            ForEach(SettingsSection.classic) { section in
                Section {
                    SettingsCard(title: section.title, icon: section.icon) { sectionContent(section, simple: true) }
                        .settingsCardRow()
                }
            }
            Section {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { interface = .panels }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: InterfaceStyle.panels.symbol)
                            .font(.body.weight(.semibold))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("More options in Panels")
                                .font(.headline)
                            Text("Layout, effects, the card, Home Screen colours and more")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .wrappedInSettingsCard()
            }
        }
        .listSectionSpacing(Corner.inset)
        .contentMargins([.horizontal, .top], Corner.inset, for: .scrollContent)
        .contentMargins(.bottom, Space.extraLarge, for: .scrollContent)
    }

    /// The controls for one settings group, shared by both interfaces. Bigger groups are split
    /// into small labelled parts.
    /// `simple` trims a group to its basics, for Classic.
    @ViewBuilder
    private func sectionContent(_ section: SettingsSection, simple: Bool = false) -> some View {
        switch section {
        case .presets:
            // In clear parts, each wrapping into rows so it reads well in narrow panels too. An
            // explicit icon and text in the buttons: a Label measured wrongly in the wrapping
            // layout and lost its text.
            groupLabel("Surprise me")
            FlowLayout(spacing: 10) {
                Button { roll(Set(StylePart.allCases)) } label: {
                    HStack(spacing: 6) { Image(systemName: "dice"); Text("I'm Feeling Lucky") }
                }
                .buttonStyle(.borderedProminent)
                .fixedSize()
                Button { roll(StylePart.colourParts) } label: {
                    HStack(spacing: 6) { Image(systemName: "paintpalette"); Text("Lucky Colours") }
                }
                .buttonStyle(.bordered)
                .fixedSize()
                Button { roll(StylePart.styleParts) } label: {
                    HStack(spacing: 6) { Image(systemName: "textformat"); Text("Lucky Style") }
                }
                .buttonStyle(.bordered)
                .fixedSize()
            }
            .padding(.vertical, 4)

            groupLabel("Your styles")
            FlowLayout(spacing: 10) {
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
            }
            .padding(.vertical, 4)

            groupLabel("Starter styles")
            FlowLayout(spacing: 10) {
                ForEach(ClockStyle.presets, id: \.name) { preset in
                    Button(preset.name) { use(preset.style) }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)

            lockChips

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

        case .fonts where simple:
            Picker("Font", selection: $style.font) {
                ForEach(ClockFont.allCases) { Text($0.label).tag($0) }
            }
            slider("Weight", value: $style.fontWeight, in: 0...1, low: "Thin", high: "Heavy")

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
            if !simple {
                slider("Transparency", value: $style.textOpacity, in: ClockStyle.textOpacityRange, low: "Faint", high: "Solid")
            }

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
            Picker("My Home Screen", selection: $myHomeScreen) {
                ForEach(MyHomeScreen.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Keep time colours", isOn: $style.keepsTimeColours)
            Toggle("Keep AM/PM and date colours", isOn: $style.keepsDetailColours)
            Toggle("Keep card colours", isOn: $style.keepsCardColours)

        case .widget:
            groupLabel("App look")
            Picker("Theme", selection: $appTheme) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(reducesGlass)
            if appTheme == .glass && !reducesGlass {
                slider("Glass", value: $glassAmount, in: 0...1, low: "Frosted", high: "Clear")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("App colour")
                swatchRow(selection: Binding(
                    get: { ClockColor(rawValue: appColor) ?? .auto },
                    set: { appColor = $0.rawValue }
                ))
            }
            Picker("Appearance", selection: $appAppearance) {
                ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Reduce glass", isOn: $reducesGlass)
            groupLabel("Widget")
            Toggle("Apply when leaving the app", isOn: $applyWhenLeaving)
            // Borderless, so each button answers only its own taps now the group is one card.
            Button("Show the tour") { showsTour = true }
                .buttonStyle(.borderless)
            Button("Reset to defaults", role: .destructive) {
                style = ClockStyle()
            }
            .buttonStyle(.borderless)
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

    /// Rolls the dice on `parts`, leaving locked parts alone.
    private func roll(_ parts: Set<StylePart>) {
        withAnimation(reduceMotion ? nil : .smooth) {
            style = style.taking(parts.subtracting(lockedParts), from: .lucky(from: style))
        }
    }

    /// Applies a preset, leaving locked parts alone.
    private func use(_ preset: ClockStyle) {
        withAnimation(reduceMotion ? nil : .smooth) {
            style = style.taking(Set(StylePart.allCases).subtracting(lockedParts), from: preset)
        }
    }

    /// Lock chips: a locked part keeps its settings when a preset or Lucky is used.
    private var lockChips: some View {
        VStack(alignment: .leading, spacing: Space.small) {
            Text("Locks: keep these when using styles or Lucky")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            FlowLayout(spacing: Space.small) {
                ForEach(StylePart.allCases) { part in
                    let locked = lockedParts.contains(part)
                    Button {
                        withAnimation(.snappy) {
                            if locked { lockedParts.remove(part) } else { lockedParts.insert(part) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: locked ? "lock.fill" : "lock.open")
                                .contentTransition(.symbolEffect(.replace))
                            Text(part.label)
                        }
                        .font(.subheadline.weight(locked ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(locked ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .background(locked ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary), in: .capsule)
                    .fixedSize()
                    .accessibilityLabel("\(part.label), \(locked ? "locked" : "unlocked")")
                    .accessibilityHint("Locked parts keep their settings when you use a preset or Lucky")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func customPresetButton(_ index: Int) -> some View {
        Button {
            use(customPresets[index].style)
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
