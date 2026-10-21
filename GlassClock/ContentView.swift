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
    @AppStorage("interfaceStyle") private var interface = InterfaceStyle.panels
    @State private var selectedSection: SettingsSection? = .presets
    @State private var showsInspector = true
    @State private var showsSidebar = true
    /// The window's width, for working out whether the sidebar fits beside the preview.
    @State private var windowWidth: CGFloat = 1200
    /// Counts jumps to a settings group, so jumping to the same group twice still scrolls.
    @State private var focusRequest = 0
    /// The group that's briefly lit up after a jump.
    @State private var highlighted: SettingsSection?
    /// The settings card in use: the one being scrolled past, or jumped to.
    @State private var focusedSection: SettingsSection?
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
    /// Like editing the Home Screen: a long press makes the widget wiggle, and a handle on its
    /// corner resizes it (owner idea, 2026-10-21).
    @State private var editingWidget = false
    /// The size the widget had when the corner handle was picked up.
    @State private var resizeStart: PreviewSize?
    /// How much the card gives with the finger between sizes while a corner is pulled, and
    /// which corner (the opposite one stays put).
    @State private var resizeStretch = CGSize(width: 1, height: 1)
    @State private var resizeCorner = WidgetCorner.bottomTrailing
    /// Where things are on screen, for the widget's grid over the whole window in Panels: the
    /// free space between the panels (where the widget starts out), the grid itself, and each
    /// panel, which tucks away when the widget is dropped under it (owner idea, 2026-10-21).
    @State private var stageRect = CGRect.zero
    @State private var layerRect = CGRect.zero
    @State private var sidebarRect = CGRect.zero
    @State private var inspectorRect = CGRect.zero
    /// Lifting the finger after the long press also counts as a tap; this stops that tap from
    /// finishing editing straight away.
    @State private var ignoresNextCardTap = false
    /// How the widget leans while it's dragged, from the finger's speed: -1…1 each way.
    @State private var cardLean = CGSize.zero
    // Design Tweaks, read here so the whole window redraws as the sliders move.
    @AppStorage(Tweak.panel.key) private var tweakPanel = Tweak.panel.standard
    @AppStorage(Tweak.gap.key) private var tweakGap = Tweak.gap.standard
    @AppStorage(Tweak.wiggle.key) private var tweakWiggle = Tweak.wiggle.standard
    @AppStorage(Tweak.lean.key) private var tweakLean = Tweak.lean.standard
    @State private var showsTweaks = false
    /// The Classic/Panels switch stands out at first, then settles back (owner idea, 2026-10-21).
    @State private var switchSettled = false
    @Namespace private var groupSelection
    @AppStorage(Tweak.frost.key) private var tweakFrost = Tweak.frost.standard
    @AppStorage(Tweak.focus.key) private var tweakFocus = Tweak.focus.standard
    @AppStorage(Tweak.rim.key) private var tweakRim = Tweak.rim.standard
    @AppStorage(Tweak.cardPadding.key) private var tweakCardPadding = Tweak.cardPadding.standard
    /// Which panel is being used: it comes forward and the other steps back a little, like the
    /// cards in the settings (owner direction, 2026-10-21: the focus effect everywhere).
    @State private var activePanel: ActivePanel?
    @State private var activePanelReset: Task<Void, Never>?
    @State private var appliedShine = false
    @AppStorage("matchesClockFont") private var matchesClockFont = true
    /// Where the widget is on screen, for the guided tour.
    @State private var widgetRect = CGRect.zero
    /// The groups panel's dock, while the panel is closed: which side it's on and how far down
    /// (0…1), remembered, and how far it's being dragged.
    @AppStorage("dockOnTrailing") private var dockOnTrailing = false
    @AppStorage("dockHeight") private var dockHeight = 0.35
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.4, dampingFraction: 0.75))) private var dockDrag = CGSize.zero
    /// Where the panels go (owner idea, 2026-10-21): the groups on the right instead of the
    /// left, the settings on the left instead of the right, and when both share a side, whether
    /// the groups sit below the settings. Drag a panel to put it somewhere else.
    @AppStorage("groupsTrailing") private var groupsTrailing = false
    @AppStorage("settingsLeading") private var settingsLeading = false
    @AppStorage("groupsBelow") private var groupsBelow = false
    @AppStorage("panelsMakeWay") private var panelsMakeWay = PanelsMakeWay.moveAside
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.45, dampingFraction: 0.82))) private var settingsMove = CGSize.zero
    @GestureState private var settingsHeld = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.4, dampingFraction: 0.8))) private var sidebarMove = CGSize.zero
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
    /// Pulling the next backdrop in with a finger: how far, -1…1 (negative is upwards), and
    /// which backdrop is coming (owner feedback, 2026-10-21: it should feel intentional, follow
    /// the finger, stretch a little, and cancel if let go early).
    @State private var backdropPull: CGFloat = 0
    @State private var pulledBackdrop: PreviewBackdrop?
    /// How far a finger travels to pull a backdrop all the way in: the window's height, so the
    /// backdrops move exactly with the finger.
    private var pullLength: CGFloat { max(400, windowHeight) }
    @State private var windowHeight: CGFloat = 1000
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
        themedInterface
        .photosPicker(isPresented: $choosingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            Task {
                guard let data = try? await photoItem?.loadTransferable(type: Data.self),
                      let image = BackdropPhoto.save(data) else { return }
                backdropPhoto = image
                backdrop = .photo
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: abs(backdropPull) > 0.4)
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
        // The guided tour, over the real app (owner idea, 2026-10-21).
        .overlay {
            if showsTour {
                GuidedTour(targets: tourTargets, finish: endTour) {
                    withAnimation(.smooth(duration: 0.45)) { interface = .classic }
                    endTour()
                }
                .tint(AppColor.chosen(appColor))
            }
        }
        .onChange(of: showsTour) { _, on in
            // The tour shows off Panels, with both panels out.
            guard on else { return }
            withAnimation(.smooth(duration: 0.45)) {
                interface = .panels
                showsSidebar = true
                showsInspector = true
                editingWidget = false
            }
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
            if !hasSeenTour && ClockStyle.launchOverride == nil {
                Task { try? await Task.sleep(for: .seconds(0.8)); showsTour = true }
            }
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
                            previewStage()
                            settingsPanel
                                .frame(width: min(480, max(340, besideRoom)))
                        }
                        .padding(.horizontal, Space.medium)
                        .padding(.top, Space.small)
                        .padding(.bottom, Space.large)
                    case .previewOnly:
                        previewStage()
                    default:
                        VStack(spacing: Space.medium) {
                            previewStage()
                                .frame(height: min(stageHeight, max(300, size.height - 280)))
                            settingsPanel
                        }
                        .padding(.horizontal, Space.medium)
                        .padding(.top, Space.small)
                        .padding(.bottom, Space.large)
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
                        previewStage(showsChrome: false)
                            .padding(.leading, panelInset(leading: true, settingsWidth: settingsWidth))
                            .padding(.trailing, panelInset(leading: false, settingsWidth: settingsWidth))
                            .offset(x: rubberBand(panelDrag))
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(panelSwipe)
                    // Double-tap the preview to clear both panels away, and again to bring them back.
                    .onTapGesture(count: 2, perform: toggleBothPanels)

                    widgetLayer
                        // Over the panels while it's being moved or edited, under them otherwise.
                        .zIndex(draggingCard || editingWidget ? 2 : 0)

                    // The stage's labels and buttons, over the widget so it never hides them.
                    previewStage(measures: false)
                        .padding(.leading, panelInset(leading: true, settingsWidth: settingsWidth))
                        .padding(.trailing, panelInset(leading: false, settingsWidth: settingsWidth))
                        .offset(x: rubberBand(panelDrag))
                        .zIndex(0.9)

                    // While a panel is carried, a soft outline shows where it will settle.
                    if let dropHint = panelDropHint(in: geometry.size, settingsWidth: settingsWidth) {
                        RoundedRectangle(cornerRadius: Corner.panel, style: .continuous)
                            .fill(.white.opacity(0.12))
                            .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                            .frame(width: dropHint.width, height: dropHint.height)
                            .position(x: dropHint.midX, y: dropHint.midY)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                            .animation(.snappy, value: dropHint)
                            .zIndex(0.5)
                    }

                    // The panels in two columns, each on whichever side it's been put; both can
                    // share a side, one above the other (owner idea, 2026-10-21).
                    HStack(alignment: .top, spacing: Space.medium) {
                        panelColumn(leading: true, area: geometry.size, settingsWidth: settingsWidth)
                        Spacer(minLength: 0)
                        panelColumn(leading: false, area: geometry.size, settingsWidth: settingsWidth)
                    }
                    // More room below than at the sides (owner feedback, 2026-10-21).
                    .padding(.horizontal, Space.medium)
                    .padding(.top, Space.small)
                    .padding(.bottom, Space.large)
                    // Kept to the top, so one panel stays put when the other tucks away.
                    .frame(maxHeight: .infinity, alignment: .top)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: panelLayoutKey)
                    .zIndex(1)
                }
                .overlay {
                    if !showsSidebar { groupsDock(in: geometry.size) }
                }
                // Design Tweaks floats over everything at the top, so the app stays in view
                // while the sliders move.
                .overlay(alignment: .top) {
                    if showsTweaks {
                        DesignTweaksPanel {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showsTweaks = false }
                        }
                        .background { GlassAmount.backing(glassAmount, in: .rect(cornerRadius: Corner.panel)) }
                        .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
                        .padding(.top, Space.small)
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                    }
                }
                .overlay(alignment: settingsLeading ? .leading : .trailing) {
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
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { windowHeight = $0 }
        // Opens set up neatly, with the widget in the free space between the panels; it can be
        // moved anywhere from there (owner direction, 2026-10-21).
        .onAppear { widgetColumn = -1; widgetRow = -1 }
        // When the panels are rearranged, the widget settles back in the middle of the space
        // left for it (owner direction, 2026-10-21).
        .onChange(of: panelLayoutKey) {
            withAnimation(Self.cardSettle) { widgetColumn = -1; widgetRow = -1 }
        }
        .onChange(of: windowWidth, initial: true) { fitSidebar() }
        .onChange(of: previewSize) { fitSidebar() }
    }

    /// The room the preview stage needs to show the widget at its real size, with its padding
    /// and the controls around it.
    /// In Panels, where the widget can be moved around, its style and size controls float with it.
    private var controlsFollowWidget: Bool { interface == .panels }

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
    private var groupsPanel: some View { groupsPanel(asStrip: false) }

    /// The groups as a list, or (sharing a side with the settings) a compact grid of icons
    /// across the top, so the settings keep most of the height.
    private func groupsPanel(asStrip: Bool) -> some View {
        let iconsOnly = groupsCollapsed || asStrip
        return ScrollView {
            if asStrip {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 4)], spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in groupButton(section, iconsOnly: true) }
                }
                .padding(Space.small + 2)
            } else {
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
                    ForEach(SettingsSection.allCases) { section in groupButton(section, iconsOnly: iconsOnly) }
                }
                .padding(Space.small + 2)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        // It all fits, and a drag moves the panel rather than scrolling it.
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        // Frosted like the cards, so its labels read on any backdrop (owner feedback,
        // 2026-10-21: clear glass looked lovely but wasn't readable).
        .background {
            if appTheme.isGlassy && !reducesGlass {
                GlassAmount.backing(GlassAmount.frosted(glassAmount, by: tweakFrost), in: .rect(cornerRadius: Corner.panel))
            }
        }
        .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
        .animation(.snappy, value: selectedSection)
    }

    private func groupButton(_ section: SettingsSection, iconsOnly: Bool) -> some View {
        let selected = selectedSection == section
        return Button {
            focus(section)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                if !iconsOnly {
                    Text(section == .homeScreens ? "Home Screens" : section.title)
                        .font(.body.weight(selected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, iconsOnly ? 10 : 14)
            .padding(.vertical, 11)
            // The group in use is a brighter piece of glass with a light rim, with a sweep of
            // light when it's picked, matching the focus on the cards (owner direction,
            // 2026-10-21) rather than a fill of colour.
            .background {
                if selected {
                    Capsule().fill(.background.opacity(0.6))
                        .overlay(Capsule().strokeBorder(.white.opacity(tweakRim), lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        .matchedGeometryEffect(id: "group selection", in: groupSelection)
                }
            }
            .shimmer(trigger: selected, in: Capsule())
            .scaleEffect(selected ? 1.04 : 1)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                                     highlighted: highlighted == section,
                                     focused: focusedSection == nil || focusedSection == section,
                                     footer: section.footer) {
                            sectionContent(section)
                        }
                        // The card crossing a line a third of the way down is the one in use.
                        .onGeometryChange(for: Bool.self) { proxy in
                            let frame = proxy.frame(in: .named("settingsList"))
                            let line = max(120, inspectorRect.height / 3)
                            return frame.minY <= line && frame.maxY >= line
                        } action: { onLine in
                            if onLine, focusedSection != section {
                                focusedSection = section
                                // The groups list follows along.
                                if selectedSection != section { selectedSection = section }
                            }
                        }
                        .settingsCardRow()
                        .id(section)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .coordinateSpace(name: "settingsList")
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
                withAnimation(.easeOut(duration: 0.25)) { highlighted = target; focusedSection = target }
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
                              tint: selectedSection == section ? AppColor.chosen(appColor).opacity(0.35) : nil)
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

    /// Which side each panel is on, and which is on top when they share a side.
    private var panelsStacked: Bool { groupsTrailing != settingsLeading }
    private var panelLayoutKey: String { "\(groupsTrailing)\(settingsLeading)\(groupsBelow)" }

    /// How much room the panels on one side take from the preview.
    private func panelInset(leading: Bool, settingsWidth: CGFloat) -> CGFloat {
        let groupsHere = showsSidebar && sidebarAlongside && groupsTrailing != leading
        let settingsHere = showsInspector && settingsLeading == leading
        if settingsHere { return settingsWidth + Space.medium }
        return groupsHere ? groupsWidth + Space.medium : 0
    }

    /// One side's panels: none, one, or both stacked (the groups at their own height, the
    /// settings taking the rest).
    @ViewBuilder
    private func panelColumn(leading: Bool, area: CGSize, settingsWidth: CGFloat) -> some View {
        let groupsHere = showsSidebar && groupsTrailing != leading
        let settingsHere = showsInspector && settingsLeading == leading
        if groupsHere || settingsHere {
            VStack(spacing: Space.medium) {
                if groupsHere && !groupsBelow { groupsColumnPanel(leading: leading, area: area, width: settingsHere ? settingsWidth : groupsWidth, strip: settingsHere) }
                if settingsHere { settingsColumnPanel(leading: leading, area: area, width: settingsWidth) }
                if groupsHere && groupsBelow { groupsColumnPanel(leading: leading, area: area, width: settingsHere ? settingsWidth : groupsWidth, strip: settingsHere) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func groupsColumnPanel(leading: Bool, area: CGSize, width: CGFloat, strip: Bool) -> some View {
        groupsPanel(asStrip: strip)
            .dynamicTypeSize(settingsTextSize)
            .frame(width: width)
            .scaleEffect(sidebarMove == .zero ? 1 : 1.02)
            .shadow(color: .black.opacity(sidebarMove == .zero ? 0 : 0.18), radius: 20, y: 10)
            .offset(sidebarMove)
            .zIndex(sidebarMove == .zero ? 0 : 1)
            .simultaneousGesture(sidebarMoveGesture(in: area))
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in markActive(.groups) })
            .modifier(PanelFocus(active: activePanel == nil || activePanel == .groups, strength: tweakFocus))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sidebarRect = $0 }
            .transition(panelTransition(leading ? .leading : .trailing))
    }

    private func settingsColumnPanel(leading: Bool, area: CGSize, width: CGFloat) -> some View {
        settingsList
            .dynamicTypeSize(settingsTextSize)
            .simultaneousGesture(settingsPinchGesture)
            .sensoryFeedback(.selection, trigger: settingsTextSize)
            .clipShape(.rect(cornerRadius: Corner.panel))
            // In the Glass theme there's no panel behind the cards: each card is its own window
            // of glass, apart from the others by the gap between them (owner direction, 2026-10-21).
            .modifier(PanelBacking(clear: appTheme.isGlassy && !reducesGlass))
            .overlay(alignment: .top) { textSizeOverlay }
            // A grabber along the top to pick the settings up and put them somewhere else; the
            // list itself still scrolls as normal.
            .overlay(alignment: .top) { panelGrabber(area: area) }
            // Or hold anywhere on the panel for a moment, then drag: a quick swipe still scrolls.
            .simultaneousGesture(settingsHoldAndDrag(area: area))
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in markActive(.settings) })
            .modifier(PanelFocus(active: activePanel == nil || activePanel == .settings, strength: tweakFocus))
            .sensoryFeedback(.impact(weight: .medium), trigger: settingsHeld) { _, held in held }
            .frame(width: width)
            // Lifts when it's picked up, like a widget on the Home Screen.
            .scaleEffect(settingsMove == .zero && !settingsHeld ? 1 : 1.025)
            .shadow(color: .black.opacity(settingsMove == .zero && !settingsHeld ? 0 : 0.2), radius: 22, y: 12)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: settingsHeld)
            .offset(settingsMove)
            .zIndex(settingsMove == .zero ? 0 : 1)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { inspectorRect = $0 }
            .transition(panelTransition(leading ? .leading : .trailing))
    }

    private func panelGrabber(area: CGSize) -> some View {
        Capsule()
            .fill(.primary.opacity(settingsMove == .zero ? 0.35 : 0.6))
            .frame(width: 44, height: 5)
            .padding(.vertical, 6)
            .frame(width: 140, height: 22)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .updating($settingsMove) { drag, state, _ in state = drag.translation }
                    .onEnded { drag in
                        placePanel(groups: false, at: CGPoint(x: inspectorRect.midX + drag.translation.width,
                                                              y: inspectorRect.minY + 40 + drag.translation.height), in: area)
                    }
            )
            .accessibilityLabel("Move settings")
            .accessibilityHint("Drag to the other side, or onto the groups to share a side")
    }

    private func settingsHoldAndDrag(area: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($settingsHeld) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .updating($settingsMove) { value, state, _ in
                if case .second(true, let drag?) = value { state = drag.translation }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                placePanel(groups: false, at: CGPoint(x: inspectorRect.midX + drag.translation.width,
                                                      y: inspectorRect.minY + 40 + drag.translation.height), in: area)
            }
    }

    /// Puts a panel down: on the side it's dropped, sharing that side if the other panel is
    /// already there (above or below it, by where it was dropped).
    private func placePanel(groups: Bool, at point: CGPoint, in area: CGSize) {
        let leading = point.x < area.width / 2
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            if groups { groupsTrailing = !leading } else { settingsLeading = leading }
            if panelsStacked {
                let other = groups ? inspectorRect : sidebarRect
                let above = point.y < (other == .zero ? area.height / 2 : other.midY)
                groupsBelow = groups ? !above : above
            }
        }
    }

    /// Where a carried panel would settle, as an outline (in the panels' space).
    private func panelDropHint(in area: CGSize, settingsWidth: CGFloat) -> CGRect? {
        let carryingGroups = sidebarMove != .zero
        guard carryingGroups || settingsMove != .zero else { return nil }
        let base = carryingGroups ? sidebarRect : inspectorRect
        let move = carryingGroups ? sidebarMove : settingsMove
        let leading = base.midX + move.width < area.width / 2
        let otherHere = carryingGroups ? (showsInspector && settingsLeading == leading) : (showsSidebar && groupsTrailing != leading)
        let width = otherHere || !carryingGroups ? settingsWidth : groupsWidth
        let x = leading ? Space.medium : area.width - Space.medium - width
        if otherHere {
            // Half of that side, above or below the panel that's there.
            let other = carryingGroups ? inspectorRect : sidebarRect
            let top = base.minY + move.height < other.midY
            let half = (area.height - Space.medium * 3) / 2
            return CGRect(x: x, y: top ? 0 : half + Space.medium, width: width, height: half)
        }
        return CGRect(x: x, y: 0, width: width, height: carryingGroups ? base.height : area.height - Space.medium)
    }

    /// The groups panel can be picked up and put on either side, or with the settings; it snaps
    /// into place. A hard flick sends it away to fold into its dock (owner direction, 2026-10-21).
    private func sidebarMoveGesture(in area: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating($sidebarMove) { drag, state, _ in state = drag.translation }
            .onEnded { drag in
                let flick = CGSize(width: drag.predictedEndTranslation.width - drag.translation.width,
                                   height: drag.predictedEndTranslation.height - drag.translation.height)
                let end = CGPoint(x: sidebarRect.midX + drag.translation.width,
                                  y: sidebarRect.midY + drag.translation.height)
                if hypot(flick.width, flick.height) > 600 {
                    // Flicked away: fold into the dock on the side it was flicked towards.
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                        dockOnTrailing = flick.width > 0 ? true : flick.width < 0 ? false : end.x > area.width / 2
                        dockHeight = min(0.9, max(0.1, end.y / max(area.height, 1)))
                        showsSidebar = false
                    }
                    return
                }
                placePanel(groups: true, at: end, in: area)
            }
    }

    /// The groups panel when it's closed: a small glass dock on the side of the window. Drag it
    /// anywhere and it settles against the nearer side; tap it, or flick it inwards, to open the
    /// panel again (owner idea, 2026-10-21).
    private func groupsDock(in area: CGSize) -> some View {
        let half: CGFloat = 26, tall: CGFloat = 52
        // On the right it sits just outside the settings panel, when that's open.
        let rightEdge: CGFloat = showsInspector && inspectorRect != .zero ? inspectorRect.minX - Space.small : area.width
        let side: CGFloat = dockOnTrailing ? rightEdge - half - Space.small : half + Space.small
        let y = min(area.height - tall / 2 - Space.medium, max(tall / 2 + Space.medium, dockHeight * area.height))
        let dragged = dockDrag
        let open = {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                if !sidebarFits(collapsed: groupsCollapsed) { groupsCollapsed = true }
                showsSidebar = true
            }
        }
        // Styled like a selected button in the panel it stands for: the app colour, white icon.
        return Button(action: open) {
            Image(systemName: "sidebar.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: half * 2, height: half * 2)
                .background(AppColor.chosen(appColor).gradient, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .scaleEffect(dragged == .zero ? 1 : 1.1)
        .shadow(color: .black.opacity(dragged == .zero ? 0.15 : 0.28), radius: dragged == .zero ? 8 : 16, y: dragged == .zero ? 3 : 8)
        .position(x: side + dragged.width, y: y + dragged.height)
        .simultaneousGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .global)
                .updating($dockDrag) { drag, state, _ in state = drag.translation }
                .onEnded { drag in
                    let inwards = dockOnTrailing ? -drag.predictedEndTranslation.width : drag.predictedEndTranslation.width
                    // A quick flick inwards opens the panel; anything else moves the dock.
                    if inwards > 260, abs(drag.translation.height) < 60 { open(); return }
                    let endX = side + drag.translation.width
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        dockOnTrailing = endX > area.width / 2
                        dockHeight = min(0.95, max(0.05, (y + drag.translation.height) / max(area.height, 1)))
                    }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: dockOnTrailing)
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
        .accessibilityLabel("Show groups")
        .accessibilityHint("Drag to move the dock")
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
        ToolbarItem(placement: .topBarLeading) { tourButton.tint(iconsOnGlass) }
        if interface == .panels {
            ToolbarItem(placement: .topBarLeading) { fullScreenButton.tint(iconsOnGlass) }
            ToolbarItem(placement: .topBarLeading) { arrangeMenu.tint(iconsOnGlass) }
            ToolbarItem(placement: .topBarLeading) {
                Button("Design Tweaks", systemImage: "slider.horizontal.3") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showsTweaks.toggle() }
                }
                .tint(iconsOnGlass)
            }
        }
        ToolbarItem(placement: .principal) { interfaceSwitch }
        ToolbarItem(placement: .primaryAction) { refreshButton.tint(iconsOnGlass) }
        ToolbarItem(placement: .primaryAction) { applyButton }
    }

    /// The panel arrangements in a menu, for anyone who'd rather pick than drag.
    private var arrangeMenu: some View {
        Menu {
            Button("Groups Left, Settings Right", systemImage: "rectangle.split.3x1") { arrange(groupsRight: false, settingsLeft: false) }
            Button("Settings Left, Groups Right", systemImage: "arrow.left.arrow.right") { arrange(groupsRight: true, settingsLeft: true) }
            Button("Both on the Left", systemImage: "rectangle.lefthalf.inset.filled") { arrange(groupsRight: false, settingsLeft: true) }
            Button("Both on the Right", systemImage: "rectangle.righthalf.inset.filled") { arrange(groupsRight: true, settingsLeft: false) }
        } label: {
            Label("Arrange Panels", systemImage: "rectangle.3.group")
        }
    }

    private func arrange(groupsRight: Bool, settingsLeft: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            groupsTrailing = groupsRight
            settingsLeading = settingsLeft
            groupsBelow = false
            showsSidebar = true
            showsInspector = true
        }
    }

    /// Clears both panels away for the whole Home Screen, or brings them back.
    private var fullScreenButton: some View {
        let clear = !showsSidebar && !showsInspector
        return Button(action: toggleBothPanels) {
            Label(clear ? "Show Panels" : "Full Screen",
                  systemImage: clear ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityHint("Hides or shows both panels")
    }

    /// Icons on the clear glass toolbar: black or white to suit the backdrop in the Glass theme
    /// (see `AppGlass`), so they never blend into a backdrop of the same colour.
    private var iconsOnGlass: Color? {
        appTheme.isGlassy && !reducesGlass ? .primary : nil
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
        .opacity(switchSettled ? 0.6 : 1)
        // Lined up over the widget's controls rather than the middle of the window.
        .offset(x: interface == .panels && stageRect != .zero
                // Kept clear of the buttons on either side.
                ? max(min(0, 330 - windowWidth / 2), min(max(0, windowWidth / 2 - 490), stageRect.midX - windowWidth / 2)) : 0)
        .animation(.smooth(duration: 0.5), value: stageRect.midX)
        .animation(.easeInOut(duration: 0.8), value: switchSettled)
        .task(id: interface) {
            switchSettled = false
            try? await Task.sleep(for: .seconds(5))
            switchSettled = true
        }
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
                markActive(.widget)
                if value.first == nil, let drag = value.second {
                    func lean(_ speed: CGFloat) -> CGFloat { max(-1, min(1, speed / 2400)) }
                    cardLean = CGSize(width: lean(drag.velocity.width), height: lean(drag.velocity.height))
                }
            }
            .onEnded { value in
                swipesPausedUntil = .now.addingTimeInterval(0.4)
                cardLean = .zero
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

    /// A corner handle: the widget snaps to whichever size is closest to where the finger has
    /// pulled that corner, live as the finger moves. Pulling a corner outwards grows it.
    private func resizeGesture(_ corner: WidgetCorner, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let start = resizeStart ?? previewSize
                if resizeStart == nil { resizeStart = start; resizeCorner = corner }
                let wanted = CGSize(width: start.size.width * scale + corner.x * value.translation.width,
                                    height: start.size.height * scale + corner.y * value.translation.height)
                let nearest = PreviewSize.allCases.min { a, b in
                    hypot(a.size.width * scale - wanted.width, a.size.height * scale - wanted.height)
                        < hypot(b.size.width * scale - wanted.width, b.size.height * scale - wanted.height)
                } ?? start
                if nearest != previewSize { withAnimation(Self.cardSettle) { previewSize = nearest } }
                // Between sizes the card gives a little with the finger, softly, so pulling
                // feels continuous rather than jumping from size to size.
                let now = CGSize(width: nearest.size.width * scale, height: nearest.size.height * scale)
                func give(_ wanted: CGFloat, _ actual: CGFloat) -> CGFloat {
                    let ratio = wanted / max(actual, 1)
                    return 1 + max(-0.12, min(0.12, (ratio - 1) * 0.3))
                }
                resizeStretch = CGSize(width: give(wanted.width, now.width), height: give(wanted.height, now.height))
            }
            .onEnded { _ in
                withAnimation(Self.cardSettle) { resizeStretch = CGSize(width: 1, height: 1) }
                resizeStart = nil
                swipesPausedUntil = .now.addingTimeInterval(0.4)
            }
    }

    /// Where a corner can be grabbed while the widget wiggles: an invisible target, bigger than
    /// the highlight drawn on the card (`cornerHighlights`), so it's easy to catch.
    private func cornerHandle(_ corner: WidgetCorner, scale: CGFloat) -> some View {
        Color.clear
            .frame(width: 64, height: 64)
            .contentShape(.rect)
            .gesture(resizeGesture(corner, scale: scale))
            .accessibilityLabel("Resize from the \(corner.name) corner")
            .accessibilityHint("Drag to change the widget size.")
    }

    /// The widget itself: the clock on its card, with how it reacts to being handled. It lifts
    /// while it's moved and leans a little into the movement, like something soft being pulled
    /// through water, then settles back (owner idea, 2026-10-21: a gentle, fabric-like push and pull).
    private func cardFace(card: CGSize, scale: CGFloat) -> some View {
        let lean: CGSize = reduceMotion ? .zero : cardLean
        let strength = CGFloat(tweakLean)
        let turn: Double = Double(lean.width * strength) * 7, tip: Double = Double(-lean.height * strength) * 7
        let stretchX: CGFloat = 1 + (abs(lean.width) * 0.035 - abs(lean.height) * 0.015) * strength
        let stretchY: CGFloat = 1 + (abs(lean.height) * 0.035 - abs(lean.width) * 0.015) * strength
        let lift: CGFloat = draggingCard && !reduceMotion ? 1.04 : 1
        let pinch: CGFloat = reduceMotion ? 1 : min(1.6, max(0.6, clockPinch))
        let face = TimelineView(.everyMinute) { context in
            ClockFace(date: context.date, style: style, simulatedAccent: homeScreen.accent,
                      simulatesClear: !homeScreen.showsKeptColours)
                .padding(16 * scale)
                .frame(width: card.width * scale, height: card.height * scale)
                .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28 * scale), homeScreen: homeScreen))
                .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
        }
        .overlay { if editingWidget { cornerHighlights(scale: scale) } }
        // A small glass tag on the bottom edge, so the preview isn't mistaken for the real
        // widget (HIG: Widgets), and it travels with it (owner feedback, 2026-10-21).
        .overlay(alignment: .bottom) {
            if controlsFollowWidget && !editingWidget {
                previewTag.offset(y: 11)
            }
        }
        .shimmer(trigger: appliedShine, in: .rect(cornerRadius: 28 * scale))
        return face
            // Lifts while it's being moved, like a widget on the Home Screen.
            .scaleEffect(lift)
            .shadow(color: .black.opacity(draggingCard ? 0.28 : 0), radius: 28, y: 14)
            // The lean: a soft tilt towards where it's going and a slight stretch along the way.
            .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(tip), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(x: stretchX, y: stretchY)
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.62), value: lean)
            .scaleEffect(x: resizeStretch.width, y: resizeStretch.height, anchor: resizeCorner.opposite)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: resizeStretch)
            // Grows and shrinks with the fingers while pinching, then settles on the nearest size.
            .scaleEffect(pinch)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { widgetRect = $0 }
        // With Reduce Motion there's no wiggle, just an outline.
        .overlay {
            if editingWidget && reduceMotion {
                RoundedRectangle(cornerRadius: 28 * scale)
                    .strokeBorder(AppColor.chosen(appColor), lineWidth: 3)
            }
        }
        .modifier(Wiggle(active: editingWidget && !draggingCard && resizeStart == nil && !reduceMotion && tweakWiggle > 0, degrees: tweakWiggle))
    }

    private var previewTag: some View {
        Text("Preview")
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background { bubbleBacking(.capsule) }
            .appGlass(.capsule)
            .environment(\.colorScheme, homeScreen == .light ? .light : .dark)
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    /// A soft highlight on each corner while editing, where it can be pulled to resize, like the
    /// Home Screen's resize corner but on all four.
    private func cornerHighlights(scale: CGFloat) -> some View {
        ZStack {
            ForEach(WidgetCorner.allCases) { corner in
                // A thin piece of glass along the corner with a soft bright line in it, rather
                // than solid white (owner feedback, 2026-10-21).
                Color.clear
                    .glassEffect(.clear, in: CornerArc(corner: corner, radius: 28 * scale)
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round)))
                    .overlay {
                        CornerArc(corner: corner, radius: 28 * scale)
                            .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .blur(radius: 0.6)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 4)
                    .padding(-4)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// The settings for the part of the widget that was tapped (owner idea, 2026-10-21): the
    /// card's edge goes to the card, the date or AM/PM line to the layout, the time to the fonts.
    private func section(at location: CGPoint) -> SettingsSection {
        guard widgetRect.width > 0 else { return .fonts }
        let x = (location.x - widgetRect.minX) / widgetRect.width
        let y = (location.y - widgetRect.minY) / widgetRect.height
        let edge = 0.1
        if x < edge || x > 1 - edge || y < edge || y > 1 - edge { return .card }
        let detailsBelow = (style.showDate && !style.dateAbove) || style.ampm == .below
        if detailsBelow && y > 0.7 { return .layout }
        if style.showDate && style.dateAbove && y < 0.3 { return .layout }
        return .fonts
    }

    /// Brings a panel forward while it's used; after a few quiet seconds everything evens out.
    private func markActive(_ panel: ActivePanel) {
        if activePanel != panel { withAnimation(.smooth(duration: 0.35)) { activePanel = panel } }
        activePanelReset?.cancel()
        activePanelReset = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.6)) { activePanel = nil }
        }
    }

    private func setEditingWidget(_ on: Bool) {
        withAnimation(.snappy) { editingWidget = on }
        ignoresNextCardTap = on
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

    /// Where the guided tour points, step by step.
    private var tourTargets: [GuideStep: CGRect] {
        var targets: [GuideStep: CGRect] = [:]
        if widgetRect != .zero { targets[.widget] = widgetRect }
        if showsInspector, inspectorRect != .zero { targets[.settings] = inspectorRect }
        if showsSidebar, sidebarRect != .zero { targets[.groups] = sidebarRect }
        if stageRect != .zero { targets[.backdrop] = stageRect.insetBy(dx: 20, dy: 40) }
        targets[.toolbar] = CGRect(x: 12, y: 28, width: max(200, windowWidth - 24), height: 52)
        return targets
    }

    private func endTour() {
        withAnimation(.smooth(duration: 0.35)) { showsTour = false }
        hasSeenTour = true
    }

    /// The interface in the app's look and colours.
    private var themedInterface: some View {
        Group {
            switch interface {
            case .classic: classicInterface.transition(interfaceTransition)
            case .panels: panelsInterface.transition(interfaceTransition)
            }
        }
        .tint(AppColor.resolve(appColor))
        .preferredColorScheme(appColorScheme)
        .environment(\.homeLook, appTheme == .home ? homeScreen : nil)
        .fontDesign(bodyDesign)
        .environment(\.headingDesign, matchesClockFont ? style.font.appDesign(roundness: style.roundness) : nil)
        .animation(.smooth, value: style.font)
        .animation(.smooth, value: appTheme)
        .animation(.smooth, value: homeScreen)
    }

    /// The app's body text when it matches the clock font: a serif clock font keeps body text
    /// plain and puts the serif in the headings only.
    private var bodyDesign: Font.Design? {
        guard matchesClockFont else { return nil }
        let design = style.font.appDesign(roundness: style.roundness)
        return design == .serif ? nil : design
    }

    /// The app's Light or Dark: from Appearance, or from the Home Screen being matched (Dark
    /// and Tinted Home Screens are dark; Clear follows Appearance).
    private var appColorScheme: ColorScheme? {
        guard appTheme == .home else { return appAppearance.colorScheme }
        switch homeScreen {
        case .light: return .light
        case .dark, .tinted: return .dark
        case .clear: return appAppearance.colorScheme
        }
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
                if applied {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    styleGlyph
                }
                Text(applied ? "Applied" : "Apply to Widget")
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.borderedProminent)
        .disabled(applied)
        .sensoryFeedback(.success, trigger: appliedStyle)
    }

    /// A tiny "9" in the clock's own font and colour, so the button shows the style it will
    /// send (owner idea, 2026-10-21).
    private var styleGlyph: some View {
        Text("9")
            .font(Font(style.font.font(size: 15, weight: style.fontWeight, width: style.fontWidth, roundness: style.roundness)))
            .foregroundStyle(style.color == .auto ? AnyShapeStyle(.white) : AnyShapeStyle(style.color.color))
            .frame(width: 22, height: 22)
            .background(.black.opacity(0.25), in: .circle)
            .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
            .contentTransition(.opacity)
            .animation(.smooth, value: style)
    }

    /// Sends the edited style to the widget.
    private func apply() {
        style.save()
        WidgetCenter.shared.reloadAllTimelines()
        withAnimation(.snappy) { appliedStyle = style }
        // Light sweeps across the widget as it's sent to the Home Screen.
        appliedShine = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            appliedShine = false
        }
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
                if !draggingCard, !editingWidget, clockPinch == 1, abs(drag.translation.width) > abs(drag.translation.height) { state = drag.translation.width }
            }
            .onChanged { drag in
                guard !draggingCard, !editingWidget, clockPinch == 1, !reduceMotion, Date.now > swipesPausedUntil else { return }
                let dx = drag.translation.width, dy = drag.translation.height
                // Up and down pull the next or previous backdrop in, following the finger.
                guard pulledBackdrop != nil || abs(dy) > abs(dx) * 1.5 else { return }
                let next = neighbourBackdrop(upward: dy < 0)
                if pulledBackdrop != next { pulledBackdrop = next }
                backdropPull = elastic(dy / pullLength)
            }
            .onEnded { drag in
                if pulledBackdrop != nil {
                    finishBackdropPull(predicted: drag.predictedEndTranslation.height / pullLength)
                    return
                }
                guard !draggingCard, !editingWidget, clockPinch == 1, Date.now > swipesPausedUntil else { return }
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
    /// The widget on its Home Screen-style grid: drag it to another slot and it snaps there,
    /// like moving a widget on the Home Screen. It's drawn at its size rather than scaled
    /// down: scaling turned the glass into a blurry picture (owner feedback, 2026-10-20).
    private var widgetGrid: some View {
        GeometryReader { space in
            let card = previewSize.size
            let scale = min(1, space.size.width / card.width, space.size.height / card.height)
            let grid = HomeGrid(area: space.size, scale: scale)
            let span = previewSize.span
            let slot = widgetColumn < 0 && interface == .panels && stageRect != .zero
                ? grid.nearest(to: CGPoint(x: stageRect.midX - layerRect.minX, y: stageRect.midY - layerRect.minY), span: span)
                : grid.clamped(column: widgetColumn, row: widgetRow, span: span)
            let home = grid.frame(column: slot.column, row: slot.row, span: span)
            let centre = CGPoint(x: home.midX + cardDrag.width, y: home.midY + cardDrag.height)
            let landing = grid.nearest(to: centre, span: span)
            // The floating controls sit above the widget (owner preference, 2026-10-21), unless
            // there isn't room there and there's more below.
            let controlsAbove = home.minY > 170 || home.minY > space.size.height - home.maxY
            ZStack(alignment: .topLeading) {
                // While it wiggles, tapping anywhere else finishes, as on the Home Screen.
                if editingWidget {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { setEditingWidget(false) }
                }
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
                cardFace(card: card, scale: scale)
                        .contentShape(.rect)
                        // Double-tap clears the panels away (as on the rest of the preview);
                        // a single tap in Panels goes straight to the fonts, or finishes
                        // editing while it wiggles.
                        .onTapGesture(count: 2) { if interface == .panels, !editingWidget { toggleBothPanels() } }
                        .onTapGesture(coordinateSpace: .global) { location in
                            if ignoresNextCardTap { ignoresNextCardTap = false }
                            else if editingWidget { setEditingWidget(false) }
                            else if interface == .panels {
                                markActive(.settings)
                                focus(section(at: location))
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            if interface == .panels, !editingWidget { setEditingWidget(true) }
                        } onPressingChanged: { pressing in
                            // The tap that comes with lifting the finger arrives straight
                            // away; after that, taps count again.
                            guard !pressing, ignoresNextCardTap else { return }
                            Task {
                                try? await Task.sleep(for: .milliseconds(300))
                                ignoresNextCardTap = false
                            }
                        }
                        .gesture(cardGesture(grid: grid, home: home, span: span))
                        .sensoryFeedback(.impact(weight: .medium), trigger: editingWidget) { _, on in on }
                        .accessibilityAction(named: editingWidget ? "Done editing" : "Edit widget") {
                            setEditingWidget(!editingWidget)
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: draggingCard)
                        .sensoryFeedback(.selection, trigger: landing.column * 100 + landing.row)
                        .accessibilityHint("Drag to move it on the Home Screen grid. Pinch to change the widget size.")
                        .accessibilityAction(named: "Move left") { moveWidget(-1, 0, grid: grid, slot: slot) }
                        .accessibilityAction(named: "Move right") { moveWidget(1, 0, grid: grid, slot: slot) }
                        .accessibilityAction(named: "Move up") { moveWidget(0, -1, grid: grid, slot: slot) }
                        .accessibilityAction(named: "Move down") { moveWidget(0, 1, grid: grid, slot: slot) }
                        // The style and size controls ride along with the widget as it's
                        // moved, so they're always next to it (owner request, 2026-10-21).
                        .overlay(alignment: controlsAbove ? .top : .bottom) {
                            if controlsFollowWidget {
                                VStack(spacing: Space.small) {
                                    if editingWidget {
                                        Button("Done") { setEditingWidget(false) }
                                            .font(.headline)
                                            .buttonStyle(.borderedProminent)
                                            .buttonBorderShape(.capsule)
                                            .tint(AppColor.chosen(appColor))
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    homeScreenBubble
                                    sizeBubble
                                    // The backdrop picker rides along too (owner, 2026-10-21).
                                    backdropBubble
                                }
                                .fixedSize()
                                // A zero-height frame on the card's edge, with the
                                // controls hanging off it away from the card.
                                .frame(height: 0, alignment: controlsAbove ? .bottom : .top)
                                .offset(y: controlsAbove ? -Space.medium : Space.medium)
                                .opacity(draggingCard ? 0.7 : 1)
                                .animation(.smooth, value: controlsAbove)
                            }
                        }
                .position(x: centre.x, y: centre.y)
                // The resize handle sits beside the widget rather than on it, so the
                // widget's own drag doesn't take its touches.
                if editingWidget && !draggingCard {
                    ForEach(WidgetCorner.allCases) { corner in
                        cornerHandle(corner, scale: scale)
                            .position(x: centre.x + corner.x * card.width * scale / 2,
                                      y: centre.y + corner.y * card.height * scale / 2)
                    }
                }
            }
            .frame(width: space.size.width, height: space.size.height)
            // Heading under a panel moves that panel out of the way.
            .onChange(of: landing.column * 100 + landing.row) {
                if draggingCard { makeRoom(for: grid.frame(column: landing.column, row: landing.row, span: span)) }
            }
            .onChange(of: previewSize) { makeRoom(for: home) }
        }
        // In Panels the preview is a Home Screen to move the widget around; in Classic
        // it's no taller than the card, so the controls stay close to it.
        .frame(maxHeight: interface == .panels ? .infinity : previewSize.size.height)
        .animation(.smooth, value: previewSize)
        .sensoryFeedback(.selection, trigger: previewSize)
        .zIndex(1)
    }

    /// Panels: the widget on a grid over the whole window, so it can go anywhere, like on the
    /// Home Screen. The panels float over it, and move out of the way when it's put under one.
    private var widgetLayer: some View {
        widgetGrid
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { layerRect = $0 }
            .padding(Space.medium)
            .environment(\.colorScheme, homeScreen == .light ? .light : .dark)
    }

    /// Tucks away any panel the widget would land under (`target` is in the grid's space).
    private func makeRoom(for target: CGRect) {
        guard interface == .panels, layerRect != .zero else { return }
        let onScreen = target.offsetBy(dx: layerRect.minX, dy: layerRect.minY).insetBy(dx: 8, dy: 8)
        // The same panel on the other side of the window.
        let mirrored = { (rect: CGRect) in
            CGRect(x: layerRect.minX + layerRect.maxX - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
        }
        let leftOfMiddle = { (rect: CGRect) in rect.midX < layerRect.midX }
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82)) {
            // Moves aside to the other side when the widget isn't there (owner idea,
            // 2026-10-21), or tucks away when there's no room either side.
            if showsSidebar, onScreen.intersects(sidebarRect) {
                if panelsMakeWay == .moveAside, !onScreen.intersects(mirrored(sidebarRect)) {
                    groupsTrailing = leftOfMiddle(sidebarRect)
                } else {
                    showsSidebar = false
                }
            }
            if showsInspector, onScreen.intersects(inspectorRect) {
                if panelsMakeWay == .moveAside, !onScreen.intersects(mirrored(inspectorRect)) {
                    settingsLeading = !leftOfMiddle(inspectorRect)
                } else {
                    showsInspector = false
                }
            }
        }
    }

    /// - Parameters:
    ///   - showsChrome: false lays the labels and buttons out without showing them.
    ///   - measures: false for a second copy that only draws them.
    /// In Panels the stage is drawn twice, so its labels and buttons sit above the widget,
    /// which can be moved anywhere, and are never hidden under it (owner feedback, 2026-10-21).
    private func previewStage(showsChrome: Bool = true, measures: Bool = true) -> some View {
            VStack(spacing: Space.large) {
                Spacer(minLength: 0)
                // In Panels the style and size controls float with the widget instead (below).
                if !controlsFollowWidget { homeScreenBubble }
                myHomeScreenNote
                    .modifier(StageChrome(shown: showsChrome))
                // Labelled so the preview isn't mistaken for a working widget (HIG: Widgets). In
                // Panels the label is a tag on the widget itself (`previewTag`).
                if !controlsFollowWidget {
                    Text("Preview")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .modifier(StageChrome(shown: showsChrome))
                }

                // The card keeps the real widget's size (shrunk only if the window is too small).
                // In Panels the widget lives on a grid over the whole window (`widgetLayer`), with
                // the panels floating over it; this space marks where it starts out.
                if interface == .panels {
                    Color.clear
                        .frame(maxHeight: .infinity)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if measures { stageRect = $0 } }
                } else {
                    widgetGrid
                }

                // Side by side when they fit, otherwise one above the other. (In Panels the
                // backdrop picker follows the widget instead.)
                if !controlsFollowWidget {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Space.medium) {
                        if !controlsFollowWidget { sizeBubble }
                        backdropBubble
                    }
                    VStack(spacing: Space.medium) {
                        if !controlsFollowWidget { sizeBubble }
                        backdropBubble
                    }
                }
                .modifier(StageChrome(shown: showsChrome))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, controlsFollowWidget ? Space.small : Space.large)
            .padding(.top, Space.medium)
            .padding(.bottom, Space.large)
            .overlay(alignment: .top) {
                if showsChrome, let backdropToast {
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
            // While a new backdrop is being pulled in, it waits underneath, settling from
            // slightly zoomed as the old one lifts away.
            // The stage the backdrops slide across, seen in the gap between them: a soft blur
            // of the backdrop itself, so there's never a hard black edge.
            backdropFill(backdrop)
                .blur(radius: 40)
                .scaleEffect(1.2)
                .zIndex(-2e12)
            // While a new backdrop is being pulled in, it slides in from the edge alongside the
            // current one, growing to full size, like the next card on a carousel.
            if let pulledBackdrop {
                backdropFill(pulledBackdrop)
                    .modifier(CarouselSlide(progress: 1 - min(1, abs(backdropPull)),
                                            edge: backdropPull <= 0 ? 1 : -1))
                    // Underneath everything, including the current backdrop's low zIndex below.
                    .zIndex(-1e12)
            }
            backdropFill(backdrop)
                .modifier(GlassSheetEffect(progress: abs(backdropPull), upward: backdropPull <= 0))
                .id(backdrop)
                // Each newer backdrop sits lower than the one before, so the leaving backdrop
                // (which keeps its last value while it animates away) stays on top and lifts off
                // like a sheet, rather than sliding unseen underneath.
                .zIndex(-ProcessInfo.processInfo.systemUptime)
                .transition(reduceMotion ? AnyTransition.opacity
                            : AnyTransition(GlassSheetTransition(upward: backdropTravel == .bottom)))
        }
        .animation(.smooth(duration: 0.7), value: backdrop)
        .clipped()
    }

    /// The backdrop after (upwards) or before this one, skipping Your Photo until there is one.
    private func neighbourBackdrop(upward: Bool) -> PreviewBackdrop {
        let options = PreviewBackdrop.allCases.filter { $0 != .photo || backdropPhoto != nil }
        let index = options.firstIndex(of: backdrop) ?? 0
        return options[(index + (upward ? 1 : options.count - 1)) % options.count]
    }

    /// Follows the finger one to one, then stretches: past most of the way it gets harder to pull.
    private func elastic(_ value: CGFloat) -> CGFloat {
        let a = abs(value), knee: CGFloat = 0.8
        let stretched = a < knee ? a : knee + (1 - knee) * (1 - exp(-(a - knee) * 3))
        return value < 0 ? -stretched : stretched
    }

    /// Let go: a pull that's far enough, or flicked, carries on and the new backdrop settles in;
    /// anything less springs back.
    private func finishBackdropPull(predicted: CGFloat) {
        guard let target = pulledBackdrop else { return }
        let commits = abs(predicted) > 0.3 && (predicted < 0) == (backdropPull < 0)
        if commits {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                backdropPull = backdropPull < 0 ? -1 : 1
            } completion: {
                var swap = Transaction()
                swap.disablesAnimations = true
                withTransaction(swap) {
                    backdrop = target
                    backdropPull = 0
                    pulledBackdrop = nil
                }
            }
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                backdropPull = 0
            } completion: {
                pulledBackdrop = nil
            }
        }
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
    private func backdropFill(_ backdrop: PreviewBackdrop) -> some View {
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

    /// A capsule of glass for a preview control (glass is for the controls layer, HIG: Materials).
    private func roundedBubble(cornerRadius: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(Space.small)
            .background { bubbleBacking(.rect(cornerRadius: cornerRadius, style: .continuous)) }
            .appGlass(.rect(cornerRadius: cornerRadius, style: .continuous))
    }

    private func bubble(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, Space.small)
            .padding(.vertical, Space.small)
            .background { bubbleBacking(.capsule) }
            .appGlass(.capsule)
    }

    /// In the Glass theme, the bubbles over the preview get the same frost as the settings
    /// cards, so every piece of glass in the app reads the same on any backdrop (owner
    /// feedback, 2026-10-21: consistency).
    @ViewBuilder
    private func bubbleBacking(_ shape: some Shape) -> some View {
        if appTheme.isGlassy && !reducesGlass {
            GlassAmount.backing(glassAmount, in: shape)
        }
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
                        // Black or white to suit the backdrop, never the app's blue on a blue
                        // backdrop (owner feedback, 2026-10-21).
                        .foregroundStyle(.primary)
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
        // Rounded to fit its taller icon buttons: 16 inside plus the 8 padding.
        roundedBubble(cornerRadius: 24) {
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
            } else if backdrop.isPattern {
                PatternBackdrop(kind: backdrop)
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
            facePicker
            // Digital-only settings are hidden for the analog face, which has no digits.
            if style.face == .digital {
                Picker("Time format", selection: $style.timeFormat) {
                    ForEach(TimeFormat.allCases) { Text($0.label).tag($0) }
                }
                Picker("AM/PM", selection: $style.ampm) {
                    ForEach(AMPMPlacement.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!style.uses12Hour)
            }
            Toggle("Show date", isOn: $style.showDate)
            if style.face == .digital {
                if style.showDate {
                    Toggle("Date above the time", isOn: $style.dateAbove)
                }
                slider("Gap", value: $style.detailGap, in: 0.3...2.5, low: "Close", high: "Far")
                Toggle("Stretch to fill square widgets", isOn: $style.fillsCard)
            }

        case .fonts where simple:
            facePicker
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
            if appTheme.isGlassy && !reducesGlass {
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
            groupLabel("Panels")
            Picker("When the widget is moved under a panel", selection: $panelsMakeWay) {
                ForEach(PanelsMakeWay.allCases) { Text($0.label).tag($0) }
            }
            groupLabel("Readability")
            Toggle("Reduce glass", isOn: $reducesGlass)
            // An experiment (owner idea, 2026-10-21): the app's own text takes on the clock's
            // style. Off keeps the standard system text, for anyone who finds that easier to read.
            Toggle("App text matches the clock font", isOn: $matchesClockFont)
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

    /// Digital or analog. Everything else (fonts aside) styles both the same way.
    private var facePicker: some View {
        Picker("Clock", selection: $style.face) {
            ForEach(ClockFaceKind.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    /// A small label that starts a group of settings inside a section.
    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .headingFont()
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
                    .background(locked ? AnyShapeStyle(AppColor.chosen(appColor)) : AnyShapeStyle(.quaternary), in: .capsule)
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

/// The Home Screen's edit-mode wiggle: a small, quick rock back and forth while `active`.
struct Wiggle: ViewModifier {
    var active: Bool
    var degrees: Double = 0.7

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([-degrees, degrees]) { view, angle in
                view.rotationEffect(.degrees(angle))
            } animation: { _ in
                .easeInOut(duration: 0.17)
            }
        } else {
            content
        }
    }
}

/// The widget's four corners, for resizing from any of them while editing.
enum WidgetCorner: CaseIterable, Identifiable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    var id: Self { self }
    /// -1 for the leading or top side, 1 for the trailing or bottom side.
    var x: CGFloat { self == .topLeading || self == .bottomLeading ? -1 : 1 }
    var y: CGFloat { self == .topLeading || self == .topTrailing ? -1 : 1 }
    /// The point across from this corner, which stays put while this one is pulled.
    var opposite: UnitPoint {
        switch self {
        case .topLeading: .bottomTrailing
        case .topTrailing: .bottomLeading
        case .bottomLeading: .topTrailing
        case .bottomTrailing: .topLeading
        }
    }
    var name: String {
        switch self {
        case .topLeading: "top left"
        case .topTrailing: "top right"
        case .bottomLeading: "bottom left"
        case .bottomTrailing: "bottom right"
        }
    }
}

/// The curve of one rounded corner, with a short run along each edge.
struct CornerArc: Shape {
    var corner: WidgetCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        let run = r * 0.35
        // Drawn for the bottom-right corner, then flipped into place.
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - r - run))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - r - run, y: rect.maxY))
        let flip = CGAffineTransform(translationX: corner.x < 0 ? rect.maxX + rect.minX : 0,
                                     y: corner.y < 0 ? rect.maxY + rect.minY : 0)
            .scaledBy(x: corner.x < 0 ? -1 : 1, y: corner.y < 0 ? -1 : 1)
        return path.applying(flip)
    }
}

/// A settings panel's glass, or nothing at all when its cards are glass of their own.
struct PanelBacking: ViewModifier {
    var clear: Bool

    func body(content: Content) -> some View {
        if clear {
            content
        } else {
            content.appGlass(.rect(cornerRadius: Corner.panel), panel: true)
        }
    }
}

/// Shows a part of the preview stage, or keeps its place without showing it.
private struct StageChrome: ViewModifier {
    var shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
    }
}

enum ActivePanel { case groups, settings, widget }

/// A panel in use stays as it is; one that isn't steps back a little, never so far that its
/// text is hard to read.
struct PanelFocus: ViewModifier {
    var active: Bool
    var strength: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : max(0.75, 1 - 0.15 * strength))
            .scaleEffect(active || reduceMotion ? 1 : 1 - 0.012 * strength)
    }
}

extension ClockFont {
    /// The system text design closest to this clock font, for the app's own text when it
    /// matches the clock: rounded, serif, monospaced, or the standard design.
    func appDesign(roundness: Double) -> Font.Design {
        switch self {
        case .sfRounded: .rounded
        case .newYork: .serif
        case .sfMono: .monospaced
        case .googleSansFlex: roundness > 0.5 ? .rounded : .default
        case .sf, .robotoFlex: .default
        }
    }
}
