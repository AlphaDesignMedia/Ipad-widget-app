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
    @AppStorage(Outlines.key) private var outlines = false
    @AppStorage(Outlines.widthKey) private var outlineWidth = Outlines.standardWidth
    @AppStorage("appTheme") private var appTheme = AppTheme.home
    @AppStorage("glassAmount") private var glassAmount = GlassAmount.standard
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.automatic
    @AppStorage("railNames") private var railNames = true
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
    /// `homeScreen` once the picker has been still for a moment. The widget and the picker
    /// change at once; the app around them (the bubbles' Light or Dark, and the whole app in
    /// the Home Screen look) follows this instead. Flipping all of that on every tap made
    /// quick tapping through Light, Dark, Clear and Tinted stutter and freeze on the iPad
    /// (owner report, 2026-10-21); now it flips once, when the tapping stops.
    @State private var settledHomeScreen = HomeScreenStyle.light
    /// The Home Screen style the person actually uses; the preview opens on it.
    @AppStorage("myHomeScreen") private var myHomeScreen = MyHomeScreen.unknown
    /// The iPad's own appearance (the views below override theirs for the preview).
    @Environment(\.colorScheme) private var systemColorScheme
    private var mine: HomeScreenStyle? { myHomeScreen.style(in: systemColorScheme) }
    @AppStorage("workspaceLayout") private var layout = WorkspaceLayout.automatic
    @AppStorage("previewBackdrop") private var backdrop = PreviewBackdrop.plain
    @AppStorage("interfaceStyle") private var savedInterface = InterfaceStyle.panels
    /// iPhone opens in Classic: floating panels over a phone-sized screen get in the way (owner,
    /// 22 Oct 2026). Panels stay one tap away there, remembered apart from the iPad's choice.
    @AppStorage("phonePanels") private var phonePanels = false
    private var interface: InterfaceStyle {
        get { compact ? (phonePanels ? .panels : .classic) : savedInterface }
        nonmutating set { if compact { phonePanels = newValue == .panels } else { savedInterface = newValue } }
    }
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
    /// Live positions while a finger moves something (see `LiveMotion`).
    @State private var motion = LiveMotion()
    /// The controls around the widget, in Panels, rest out of sight so the widget is what you
    /// see (owner, 22 Oct 2026: "it's taking away too much from the widget"). They come up when
    /// the widget or the Preview pill is touched, and tuck away after a few quiet seconds.
    @AppStorage("quietControls") private var quietControls = true
    @State private var extrasShown = true
    @State private var extrasHide: Task<Void, Never>?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// An iPhone (or a narrow window): the preview gets most of the room and the extras go.
    private var compact: Bool { sizeClass == .compact }
    private var extrasVisible: Bool { (extrasShown || !quietControls || editingWidget || voiceOverOn) && !widgetMoving }
    /// Being dragged or pinched: everything around it steps away, so it's just the widget
    /// (owner, 22 Oct 2026: "remove all of the extra things when I'm moving it around").
    private var widgetMoving: Bool { draggingCard || pinchStartSize != nil }
    /// Where the widget sits on the preview's Home Screen grid (-1: the middle), remembered.
    @AppStorage("widgetColumn") private var widgetColumn = -1
    @AppStorage("widgetRow") private var widgetRow = -1
    /// The slot the widget would land in while it's dragged (column × 100 + row; -1 when not
    /// dragging). Only changes slot to slot, so the rest of the screen redraws rarely.
    @State private var landingKey = -1
    /// The size a pinch started from, while pinching.
    @State private var pinchStartSize: PreviewSize?
    /// The spring the widget settles with after a drag or pinch.
    /// Barely any bounce: things glide into place rather than pop (owner, 22 Oct 2026).
    static let cardSettle = Animation.spring(response: 0.38, dampingFraction: 0.94)
    /// The spring a dropped widget lands with: no overshoot, so it glides into its slot and
    /// stops, rather than passing it and pulling back (owner, 22 Oct 2026).
    static let cardLand = Animation.spring(response: 0.42, dampingFraction: 1)
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
    // Design Tweaks, read here so the whole window redraws as the sliders move.
    @AppStorage(Tweak.panel.key) private var tweakPanel = Tweak.panel.standard
    @AppStorage(Tweak.gap.key) private var tweakGap = Tweak.gap.standard
    @AppStorage(Tweak.panelEdge.key) private var tweakEdge = Tweak.panelEdge.standard
    @AppStorage(Tweak.bubble.key) private var tweakBubble = Tweak.bubble.standard
    @AppStorage(Tweak.chip.key) private var tweakChip = Tweak.chip.standard
    @AppStorage(Tweak.wiggle.key) private var tweakWiggle = Tweak.wiggle.standard
    @AppStorage(Tweak.lean.key) private var tweakLean = Tweak.lean.standard
    /// Opens at launch with `-showsTweaks` (for checking it in the simulator).
    @State private var showsTweaks = ProcessInfo.processInfo.arguments.contains("-showsTweaks")
    /// The Classic/Panels switch stands out at first, then settles back (owner idea, 2026-10-21).
    @State private var switchSettled = false
    @Namespace private var groupSelection
    @AppStorage(Tweak.frost.key) private var tweakFrost = Tweak.frost.standard
    @AppStorage(Tweak.cardPadding.key) private var tweakCardPadding = Tweak.cardPadding.standard
    /// Which panel is being used: it comes forward and the other steps back a little, like the
    /// cards in the settings (owner direction, 2026-10-21: the focus effect everywhere).
    @State private var activePanel: ActivePanel?
    @State private var activePanelReset: Task<Void, Never>?
    @State private var appliedShine = false
    @AppStorage("matchesClockFont") private var matchesClockFont = true
    /// Where the widget is on screen, for the guided tour.
    @State private var widgetRect = CGRect.zero
    /// How far the widget has stepped aside for a card opened from the rail; back to zero
    /// when the card closes. Its place on the grid doesn't change.
    @State private var widgetNudge = CGSize.zero
    /// False for a moment while Panels opens, so the widget appears in its place.
    @State private var widgetSettled = true
    /// Where the controls above and below the widget are, in the window, so the stuck-on groups
    /// line up with the whole widget group rather than just the card.
    @State private var controlsAboveRect = CGRect.zero
    @State private var controlsBelowRect = CGRect.zero
    /// The groups panel's dock, while the panel is closed: which side it's on and how far down
    /// (0…1), remembered, and how far it's being dragged.
    @AppStorage("dockOnTrailing") private var dockOnTrailing = false
    @AppStorage("dockHeight") private var dockHeight = 0.35
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.4, dampingFraction: 0.75))) private var dockDrag = CGSize.zero
    /// Where the panels go (owner idea, 2026-10-21): the groups on the right instead of the
    /// left, the settings on the left instead of the right, and when both share a side, whether
    /// the groups sit below the settings. Drag a panel to put it somewhere else.
    /// Which side the groups are on, how far down, and whether along the bottom: plain view
    /// state saved by hand, like `settingsLeading`, so a drop lands in the same frame.
    @State private var groupsTrailing = UserDefaults.standard.bool(forKey: "groupsTrailing")
    /// Which side the settings are on. Plain view state, saved by hand: @AppStorage's update
    /// reached the screen a frame late, so a panel put down on the other side drew once in its
    /// old column before swapping, and visibly slid back first (simulator frames, 22 Oct 2026).
    @State private var settingsLeading = UserDefaults.standard.bool(forKey: "settingsLeading")
    @AppStorage("groupsBelow") private var groupsBelow = false
    /// The groups pill on its own side sits where it was dropped, top to bottom, or lies along
    /// the bottom of the window (owner, 22 Oct 2026: "move this panel up and down… pull it to
    /// the bottom").
    @State private var groupsTop = UserDefaults.standard.double(forKey: "groupsTop")
    @State private var groupsAlongBottom = UserDefaults.standard.bool(forKey: "groupsAlongBottom")
    /// Or lying along the top, just under the top bar (owner idea, 22 Oct 2026).
    @State private var groupsAlongTop = UserDefaults.standard.bool(forKey: "groupsAlongTop")
    /// Lying flat along the top or the bottom, rather than standing on a side.
    private var groupsOnEdge: Bool { groupsAlongBottom || groupsAlongTop }
    @AppStorage("panelsMakeWay") private var panelsMakeWay = PanelsMakeWay.moveAside
    /// The settings being carried by a card's title bar (see `PanelCarry`).
    @State private var settingsCarried = false
    /// The groups were showing when the settings folded into the rail, so they come back with them.
    @State private var railHidGroups = false
    /// The group opened from the folded rail, shown in a card beside it.
    @State private var railBubble: SettingsSection?
    /// Quarter turns of the screen from upright portrait, clockwise.
    @State private var quarterTurns = 0
    /// The edge of the iPad itself (clockwise from the top in portrait) the folded rail is held
    /// to, so it stays put when the iPad turns and everything else moves round it. Only the
    /// rail does this; the full settings open where they always do (owner, 25 Oct 2026).
    @State private var railPin: Int?
    /// The edge of the iPad the rail was dragged to, when that's the top or bottom; it stays
    /// there until it's dragged back to a side. Down a side, `settingsLeading` says which.
    @State private var railHome: Int? = UserDefaults.standard.object(forKey: "railHome") as? Int

    /// Where the folded rail is on screen now.
    private var railEdge: Edge {
        guard let railPin = railPin ?? railHome else { return settingsLeading ? .leading : .trailing }
        return [Edge.top, .trailing, .bottom, .leading][(railPin + quarterTurns) % 4]
    }

    private static func currentQuarterTurns() -> Int {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .landscapeLeft: return 1
        case .portraitUpsideDown: return 2
        case .landscapeRight: return 3
        default: return 0
        }
    }

    private func reopenFromRail() {
        showsInspector = true
        if railHidGroups { showsSidebar = true; railHidGroups = false }
    }

    /// True for a moment after a panel is put down on the other side (see `panelTransition`).
    @State private var panelSwap = false
    /// The settings tucked aside: turned, mostly off the edge, still in view (see `Peek`).
    @State private var settingsPeeking = false
    @GestureState private var groupsHeld = false
    @State private var groupsCarried = false
    /// Where a carried panel would settle, while one is carried.
    @State private var carryTarget: CarryTarget?
    /// The card the settings were picked up by, while they're carried.
    @State private var settingsGrab: CarryGrab?
    /// The groups stuck onto the widget or the settings panel, rather than a panel of their own
    /// (owner idea, 2026-10-21), and whether they're slid in to a small tab.
    @AppStorage("groupsAttachment") private var groupsAttachment = GroupsAttachment.none
    @AppStorage("groupsTucked") private var groupsTucked = false
    @GestureState private var railHeld = false
    @State private var railCarried = false
    @State private var railSize = CGSize(width: 64, height: 400)
    @State private var panelsOrigin = CGPoint.zero
    /// Running a finger down the groups: where it is, and where each group's button is.
    @State private var scrubY: CGFloat?
    @State private var groupFrames: [SettingsSection: CGRect] = [:]
    /// Panel swipes are ignored for a moment after a widget drag, so moving the widget
    /// doesn't also open or close a panel.
    @State private var swipesPausedUntil = Date.distantPast
    /// How big the settings' text and rows are, as a step through `textSizes`. Pinch the
    /// settings to change it.
    @AppStorage("settingsTextSize") private var textSizeStep = 1
    /// The same for the groups. Each panel keeps its own size, so pinching one leaves the other
    /// alone (owner direction, 2026-10-21).
    @AppStorage("groupsTextSize") private var groupsTextStep = 1
    @AppStorage(CarryStyle.key) private var savedCarryStyle = CarryStyle.lift
    @AppStorage(OneRowControls.key) private var savedOneRowControls = false
    /// The Foundation build carries panels at full size and keeps the controls stacked
    /// (see `Essentials`).
    private var carryStyle: CarryStyle { Essentials.on ? .lift : savedCarryStyle }
    private var oneRowControls: Bool {
        get { savedOneRowControls && !Essentials.on }
        nonmutating set { savedOneRowControls = newValue }
    }
    /// Which bubble shows when the widget's controls are one row: 0 style, 1 size, 2 backdrop.
    @State private var controlsPage = 0
    @State private var controlsPageForward = true
    /// Set when a preset is used, so a "Try a font" suggestion can follow it.
    @State private var suggestsFont = false
    /// Your Own backdrop's colours and pattern, saved as JSON; empty until one is made.
    @AppStorage(CustomBackdrop.key) private var customBackdropRaw = ""
    @State private var makingBackdrop = false
    /// True once the style has been left alone for a few seconds, so the Apply suggestion
    /// doesn't flicker in while someone is still changing things.
    @State private var changesSettled = false
    @State private var dismissedApplyHint = false
    @State private var pinchingTextStep: Int?
    @State private var pinchingGroupsStep: Int?
    /// The text-size bubble, shown on the panel being pinched while pinching and briefly after.
    @State private var textSizeBubblePanel: TextPanel?
    @State private var hideTextSizeBubble: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// Simpler effects (Accessibility settings): no wiggle, lean, sweep or carousel.
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }
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
    /// True for the moment a backdrop picked from the menu slides in, so the blurred stage
    /// behind it is only drawn while it can be seen.
    @State private var backdropSettling = false
    /// A mood changes the backdrop with a plain cross-fade, no sheet and no blurred stage: quick
    /// taps between moods stacked several full-screen transitions at once and stalled the iPad
    /// (owner, 25 Oct 2026). Taps that land while one settles wait, and only the last is drawn.
    @State private var quietBackdrop = false
    @State private var moodSettling = false
    @State private var pendingMood: (style: ClockStyle, scene: PreviewBackdrop)?
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

    // AnyView boundaries here and below keep the full view type shallow enough to be worked
    // out at launch: it overflowed the stack on the iPad and in the simulator (2026-10-21).
    var body: some View {
        AnyView(themedInterface)
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
            // The tour shows off Panels, with both panels out (not on iPhone, which stays Classic).
            guard on else { return }
            withAnimation(.smooth(duration: 0.45)) {
                if !compact { interface = .panels }
                showsSidebar = true
                showsInspector = true
                editingWidget = false
            }
        }
        .onAppear {
            if let mine { homeScreen = mine; settledHomeScreen = mine }
        }
        .task(id: homeScreen) {
            guard settledHomeScreen != homeScreen else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { settledHomeScreen = homeScreen }
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
            #if DEBUG
            if let page = StressTest.oneRowPage {
                oneRowControls = true
                controlsPage = min(2, max(0, page))
            }
            if StressTest.classic {
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    interface = .classic
                }
            }
            if StressTest.makeBackdrop {
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    openBackdropMaker()
                }
            }
            if let hint = StressTest.suggestion {
                myHomeScreen = .automatic
                if let mine { homeScreen = mine }
                use(ClockStyle.presets[1].style)
                if hint != "font" { suggestsFont = false }
            }
            if let target = StressTest.backdrop {
                Task {
                    try? await Task.sleep(for: .seconds(12))
                    backdropTravel = .bottom
                    withAnimation(.smooth(duration: 0.55)) { backdrop = target }
                }
            }
            if let taps = StressTest.homeTaps {
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    let meter = HitchMeter()
                    meter.start()
                    for tap in 0..<taps {
                        if StressTest.plain {
                            homeScreen = HomeScreenStyle.allCases[tap % 4]
                        } else if !StressTest.idle {
                            withAnimation(.snappy) { homeScreen = HomeScreenStyle.allCases[tap % 4] }
                        }
                        try? await Task.sleep(for: .milliseconds(180))
                    }
                    try? await Task.sleep(for: .seconds(1))
                    print("STRESS home taps \(taps): \(meter.stop())")
                }
            }
            if let taps = StressTest.moodTaps {
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    let meter = HitchMeter()
                    meter.start()
                    for tap in 0..<taps {
                        if StressTest.idle {
                        } else if StressTest.drag {
                            style.fontWeight = 0.3 + Double(tap % 30) / 60
                        } else {
                            let mood = MoodRow.moods[tap % MoodRow.moods.count]
                            applyMood(mood.style, on: mood.scene)
                        }
                        try? await Task.sleep(for: .milliseconds(StressTest.drag ? 16 : 700))
                    }
                    try? await Task.sleep(for: .seconds(1))
                    print("STRESS moods \(taps)\(StressTest.drag ? " drag" : ""): \(meter.stop())")
                }
            }
            #endif
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
                    StatusScrim()
                    if arrangement == .previewOnly {
                        previewStage()
                    } else {
                        // Beside or below in one layout that changes shape, so the preview and the
                        // settings glide to their new places. Two separate stacks were two
                        // different views: a size change that moved the settings below (Extra
                        // Large) or back beside them faded the whole screen out and in, and taps
                        // in that moment were lost (simulator, 22 Oct 2026).
                        let stacked = arrangement != .sideBySide
                        let arrange = stacked ? AnyLayout(VStackLayout(spacing: Space.medium))
                                              : AnyLayout(HStackLayout(spacing: Space.medium))
                        arrange {
                            previewStage()
                                .frame(height: stacked ? (compact ? size.height * 0.58 : min(stageHeight, max(300, size.height - 280))) : nil)
                            settingsPanel
                                .frame(width: stacked ? nil : min(480, max(340, besideRoom)))
                        }
                        // The same gap under the top bar as at the sides, so the panel doesn't
                        // crowd the toolbar (owner, breathing room, 21 Oct).
                        .padding(.horizontal, Space.medium)
                        .padding(.top, Space.medium)
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
            .simultaneousGesture(textPinchGesture(.settings))
            .sensoryFeedback(.selection, trigger: settingsTextSize)
            .scrollContentBackground(.hidden)
            .clipShape(.rect(cornerRadius: Corner.panel))
            .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
            .overlay(alignment: .top) { textSizeOverlay(.settings) }
    }

    /// Two floating glass panels over the full-window backdrop, like Classic's: a short list of
    /// groups on the left for jumping around, and every setting in one scrolling list on the
    /// right. Picking a group glides the list to it and lights it up. The panels slide in and out
    /// with a swipe across the preview or a tap on the glass tab at the edge; there are no
    /// sidebar buttons (owner feedback 2026-10-21: the system's edge-to-edge columns and toggle
    /// buttons on iPadOS 27 didn't look right).
    /// (Big pieces are wrapped in AnyView: the full nested view type grew so deep that working
    /// it out at launch overflowed the stack on the iPad, 2026-10-21.)
    private var panelsInterface: some View {
        NavigationStack {
            GeometryReader { geometry in
                let besideRoom = geometry.size.width - stageWidth - Space.medium * 3
                    - (sidebarAlongside ? groupsWidth + Space.medium : 0)
                let settingsWidth = min(440, max(320, besideRoom))
                ZStack {
                    ZStack {
                        AnyView(backdropView)
                            .ignoresSafeArea()
                        StatusScrim()
                        AnyView(previewStage(showsChrome: false))
                            .padding(.leading, panelInset(leading: true, settingsWidth: settingsWidth))
                            .padding(.trailing, panelInset(leading: false, settingsWidth: settingsWidth))
                            .padding(.top, railInset(.top))
                            .padding(.bottom, railInset(.bottom))
                            .modifier(LivePull(motion: motion, still: reduceMotion))
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(panelSwipe)
                    // Double-tap the preview to clear both panels away, and again to bring them back.
                    .onTapGesture(count: 2, perform: toggleBothPanels)
                    // Trying out (owner, 22 Oct 2026): a single tap on empty space brings the
                    // widget's controls up, or puts them away.
                    .onTapGesture {
                        if editingWidget { setEditingWidget(false); return }
                        if extrasShown { extrasHide?.cancel(); extrasShown = false } else { showExtras(for: 8) }
                    }

                    AnyView(widgetLayer)
                        // Fades in once it has found its place, rather than showing for a moment
                        // under a panel while the layout settles (tap check, 2026-10-21).
                        .opacity(widgetSettled ? 1 : 0)
                        // Over the panels while it's being moved or edited, under them otherwise.
                        .zIndex(draggingCard || editingWidget ? 2 : 0)

                    // The stage's labels and buttons, over the widget so it never hides them.
                    // Only labels in Panels, so it lets taps through: it covered the top bar and
                    // swallowed taps on Classic (owner report, 22 Oct 2026).
                    AnyView(previewStage(measures: false)).allowsHitTesting(false)
                        .padding(.leading, panelInset(leading: true, settingsWidth: settingsWidth))
                        .padding(.trailing, panelInset(leading: false, settingsWidth: settingsWidth))
                        .padding(.top, railInset(.top))
                        .padding(.bottom, railInset(.bottom))
                        .modifier(LivePull(motion: motion, still: reduceMotion))
                        .zIndex(0.9)

                    // While a panel is carried, a soft outline shows where it will settle.
                    if let dropHint = panelDropHint(in: geometry.size, settingsWidth: settingsWidth) {
                        // Round-ended for the flat groups pill, so it's the pill's own shape.
                        RoundedRectangle(cornerRadius: min(Corner.panel, dropHint.height / 2), style: .continuous)
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
                        AnyView(panelColumn(leading: true, area: geometry.size, settingsWidth: settingsWidth))
                        Spacer(minLength: 0)
                        AnyView(panelColumn(leading: false, area: geometry.size, settingsWidth: settingsWidth))
                    }
                    // More room below than at the sides (owner feedback, 2026-10-21), and room for
                    // the groups when they lie along the bottom.
                    .padding(.horizontal, Space.medium)
                    .padding(.top, showsSidebar && groupsFree && groupsAlongTop ? 56 + Space.small * 2 : Space.small)
                    .padding(.bottom, showsSidebar && groupsFree && groupsAlongBottom ? 56 + Space.medium * 2 : Space.large)
                    // Kept to the top, so one panel stays put when the other tucks away.
                    .frame(maxHeight: .infinity, alignment: .top)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: panelLayoutKey)
                    .zIndex(1)
                }
                .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { panelsOrigin = $0 }
                // While the widget is held for editing, a tap anywhere finishes, as on the Home
                // Screen (owner, 22 Oct 2026: "you should be able to tap away").
                .simultaneousGesture(TapGesture().onEnded { if editingWidget { setEditingWidget(false) } }, isEnabled: editingWidget)
                .overlay {
                    // Not while the settings rail is up: the rail already lists every group.
                    if !showsSidebar && showsInspector { AnyView(groupsDock(in: geometry.size)) }
                }
                .overlay(alignment: .bottom) { AnyView(backdropNameOverlay) }
                // Dropped along the bottom: the same pill, lying flat.
                .overlay(alignment: .bottom) {
                    if showsSidebar && groupsFree && groupsAlongBottom {
                        AnyView(groupsColumnPanel(leading: true, area: geometry.size, width: geometry.size.width, strip: true))
                            .padding(.bottom, Space.medium)
                    }
                }
                // Or along the top, under the top bar, so nothing up there is covered.
                .overlay(alignment: .top) {
                    if showsSidebar && groupsFree && groupsAlongTop {
                        AnyView(groupsColumnPanel(leading: true, area: geometry.size, width: geometry.size.width, strip: true))
                            .padding(.top, Space.small)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if showsSidebar && !groupsFree { AnyView(attachedGroups(in: geometry.size)) }
                }
                // While a card is open from the rail, the rest of the screen holds still: a touch
                // there closes the card instead of dragging the wallpaper (owner, 25 Oct 2026).
                .overlay {
                    if railBubble != nil && !showsInspector {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onEnded { _ in
                                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { railBubble = nil }
                            })
                            .accessibilityHidden(true)
                    }
                }
                .overlay(alignment: railAlignment) { AnyView(railOverlay(in: geometry)) }
                // The folded rail keeps to its edge of the iPad as it turns.
                .onAppear { quarterTurns = Self.currentQuarterTurns() }
                .onChange(of: geometry.size) {
                    let turns = Self.currentQuarterTurns()
                    guard turns != quarterTurns else { return }
                    if railPin == nil, railHome == nil, !showsInspector {
                        railPin = ((settingsLeading ? 3 : 1) - quarterTurns + 4) % 4
                    }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { quarterTurns = turns }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showsInspector)
            .sensoryFeedback(.impact(weight: .light), trigger: showsSidebar)
            // A panel opened over the widget: the widget steps out to the free space, so it's
            // never hidden (owner, 22 Oct 2026: the widget is what you want to look at).
            .onChange(of: showsInspector) { _, shown in if shown { clearWidgetFromPanels(); railBubble = nil; railPin = nil } }
            .onChange(of: settingsLeading) { railPin = nil }
            // The rail and the groups list the same headings, so they're never on screen
            // together, however the settings were put away (owner, 25 Oct 2026). The groups
            // step aside for the rail and come back with the settings.
            .onChange(of: showsInspector) { _, shown in
                if !shown, showsSidebar { railHidGroups = true; showsSidebar = false }
            }
            .onChange(of: showsSidebar) { _, shown in
                if shown, !showsInspector { railBubble = nil; showsInspector = true }
            }
            // The widget comes back as the card closes, not once it has finished fading.
            .onChange(of: railBubble) { _, open in if open == nil { stepWidgetAside(from: nil) } }
            .modifier(SavesPanelPlaces(settingsLeading: settingsLeading, groupsTrailing: groupsTrailing,
                                       groupsTop: groupsTop, groupsAlongBottom: groupsAlongBottom, groupsAlongTop: groupsAlongTop))
            // Using a control keeps them up a while longer.
            .onChange(of: homeScreen) { showExtras() }
            .onChange(of: previewSize) { if extrasShown { showExtras() } }
            .onChange(of: backdrop) { showExtras() }
            .onChange(of: controlsPage) { showExtras() }
            .onChange(of: showsSidebar) { _, shown in if shown { clearWidgetFromPanels() } }
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
        .onAppear {
            widgetColumn = -1; widgetRow = -1
            widgetSettled = false
            // Shown for a moment on opening, so it's clear they're there.
            showExtras(for: 4)
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeOut(duration: 0.3)) { widgetSettled = true }
            }
        }
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
    private var sidebarAlongside: Bool { showsSidebar && groupsFree && sidebarFits(collapsed: groupsCollapsed) }

    /// The groups are a panel of their own: not stuck to anything, or stuck to the settings
    /// while those are put away.
    private var groupsFree: Bool {
        Essentials.on || groupsAttachment == .none || (groupsAttachment == .settings && !showsInspector)
    }

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

    /// A sideways swipe moves things the way the finger goes (owner, 22 Oct 2026: "aware of
    /// what side it's being swiped on"): a panel put away on the side it comes from slides back
    /// in; otherwise the panels on the side it heads towards slide out that edge. So a swipe is
    /// always undone by swiping back. Double-tap clears everything.
    private func swipePanels(right: Bool) {
        let groupsBehind = groupsFree && groupsTrailing != right
        let settingsBehind = settingsLeading == right
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
            if (groupsBehind && !showsSidebar) || (settingsBehind && !showsInspector) {
                if groupsBehind { showsSidebar = true }
                if settingsBehind { showsInspector = true }
            } else {
                if !groupsBehind { showsSidebar = false }
                if !settingsBehind { showsInspector = false }
            }
        }
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
        // A panel carried to the other side swaps columns without any transition: it's put
        // down exactly where the finger left it and glides home from there (`panelSwap`).
        if panelSwap { return .identity }
        return reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }

    /// The settings groups on a glass panel: a tap glides the settings to that group. It folds
    /// down to just its icons with the button at the top, to give the preview more room.
    private var groupsPanel: some View { groupsPanel(asStrip: false) }

    /// The groups as a list, or (sharing a side with the settings) a compact grid of icons
    /// across the top, so the settings keep most of the height.
    @ViewBuilder
    private func groupsPanel(asStrip: Bool) -> some View {
        if asStrip { groupsFlatRail } else if groupsCollapsed { groupsPill(upright: true) } else { groupsList }
    }

    /// The groups as one pill of glass with each icon in a circle (owner, 22 Oct 2026): upright
    /// on its own at the side, or lying across the top or bottom of the settings when they share
    /// a side. The same piece either way, so it never looks like a different app.
    private func groupsPill(upright: Bool) -> some View {
        let layout = upright ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        return layout {
            if upright {
                // Opens the full list with names.
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { groupsCollapsed = false }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show group names")
            }
            ForEach(SettingsSection.allCases) { section in
                groupButton(section, iconsOnly: true)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("groupsList")) } action: { groupFrames[section] = $0 }
            }
        }
        .coordinateSpace(name: "groupsList")
        // Run a finger down the upright pill to glide through the groups.
        .simultaneousGesture(groupsScrub, isEnabled: upright)
        .padding(6)
        .fixedSize()
        // Pure Liquid Glass, like the text-size bubble (owner, 22 Oct 2026: "that's the style I
        // really want"), with no frosted wash underneath.
        .appGlass(.capsule, panel: true)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: selectedSection)
    }

    /// The groups lying flat (along the top or bottom, or above or below the settings) in the
    /// folded rail's style: one bar of glass with each icon and its name, icons only when the
    /// names don't fit or are switched off (owner, 25 Oct 2026: the pill of circles along the
    /// top was the old style; "swap that completely over for the new style").
    private var groupsFlatRail: some View {
        ViewThatFits(in: .horizontal) {
            if railNames { groupsFlatRow(labelled: true) }
            groupsFlatRow(labelled: false)
        }
        .frame(height: SettingsRail.width)
        .appGlass(.capsule, interactive: true)
        .contentShape(.capsule)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: selectedSection)
    }

    private func groupsFlatRow(labelled: Bool) -> some View {
        HStack(spacing: labelled ? 8 : 2) {
            ForEach(SettingsSection.allCases) { section in
                let selected = selectedSection == section
                Button { focus(section) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.body.weight(.medium))
                        if labelled {
                            Text(section.title)
                                .font(.caption.weight(.semibold))
                                .fixedSize()
                        }
                    }
                    .padding(.horizontal, labelled ? 10 : 8)
                    .frame(height: SettingsRail.width - 8)
                    // The group in use: the same glossy bead as in the groups list.
                    .background {
                        if selected {
                            GlossyBead(shape: Capsule())
                                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                                .matchedGeometryEffect(id: "group selection", in: groupSelection)
                        }
                    }
                    .shimmer(trigger: selected, in: Capsule())
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("groupsList")) } action: { groupFrames[section] = $0 }
            }
        }
        .padding(.horizontal, 6)
        .coordinateSpace(name: "groupsList")
    }

    private var groupsList: some View {
        let iconsOnly = groupsCollapsed
        let asStrip = false
        return ScrollView {
            if asStrip {
                // Every group on one row, however many there are.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 34), spacing: 2), count: SettingsSection.allCases.count), spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in groupButton(section, iconsOnly: true) }
                }
                .padding(.horizontal, Space.small + 2)
                .padding(.top, 20)
                .padding(.bottom, Space.small + 2)
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
                    ForEach(SettingsSection.allCases) { section in
                        groupButton(section, iconsOnly: iconsOnly)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("groupsList")) } action: { groupFrames[section] = $0 }
                    }
                }
                .coordinateSpace(name: "groupsList")
                // Run a finger down the groups to glide through them, the one under it growing
                // like icons in the Dock (owner idea, 2026-10-21). Holding first moves the panel.
                .simultaneousGesture(groupsScrub)
                .padding(.horizontal, Space.small + 4)
                .padding(.top, 22)
                .padding(.bottom, Space.small + 4)
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
            // Icons alone sit in a circle; with names, a pill.
            .padding(.horizontal, iconsOnly ? 0 : 16)
            .padding(.vertical, iconsOnly ? 0 : 12)
            .frame(width: iconsOnly ? 44 : nil, height: iconsOnly ? 44 : nil)
            // The group in use is a brighter piece of glass with a light rim, with a sweep of
            // light when it's picked, matching the focus on the cards (owner direction,
            // 2026-10-21) rather than a fill of colour.
            .background {
                if selected {
                    // A glossy bead rather than an outline (owner, 22 Oct 2026): a soft fill
                    // lit from above, with an inner highlight and a gentle shadow under it.
                    GlossyBead(shape: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                        .matchedGeometryEffect(id: "group selection", in: groupSelection)
                }
            }
            .shimmer(trigger: selected, in: Capsule())
            .scaleEffect(scrubGrowth(section), anchor: iconsOnly ? .center : .leading)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.75), value: scrubY)
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
                        AnyView(SettingsCard(title: section.title, icon: section.icon,
                                             highlighted: highlighted == section,
                                             focused: focusedSection == nil || focusedSection == section,
                                             footer: section.footer) {
                            sectionContent(section)
                        })
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
            // Tighter than the gap between panels: the carousel draws cards together anyway
            // (owner, 22 Oct 2026: "a bit too much spacing").
            .listSectionSpacing(Corner.inset * 0.6)
            .contentMargins(.horizontal, Corner.edge, for: .scrollContent)
            .contentMargins(.top, Corner.edge, for: .scrollContent)
            // Some room below the last card, so Accessibility comes up out of the clear edge
            // (owner, 22 Oct 2026: not too far, the top stays as it was).
            .contentMargins(.bottom, max(Space.extraLarge, inspectorRect.height * 0.22), for: .scrollContent)
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
            // Switching the look (Reduce glass, the app look) redraws every card, which threw
            // the list back to the top (owner, 22 Oct 2026). It goes back to the card in use.
            .onChange(of: reducesGlass) { returnTo(.accessibility, anchor: .bottom, proxy) }
            // Text size changes by pinching anywhere too, so it goes back to the card in use.
            .onChange(of: textSizeStep) { returnTo(focusedSection ?? .accessibility, anchor: .center, proxy) }
            .onChange(of: appTheme) { returnTo(.widget, anchor: .top, proxy) }
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
    /// Back to the group whose setting was just changed, once the list has redrawn.
    private func returnTo(_ section: SettingsSection, anchor: UnitPoint, _ proxy: ScrollViewProxy) {
        // The rebuilt list replays its last jump to the selected group, so that points here too.
        selectedSection = section
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            proxy.scrollTo(section, anchor: anchor)
        }
    }

    private func focus(_ section: SettingsSection) {
        selectedSection = section
        // The groups and the settings work as one: picking a group always brings the settings
        // into view at it, even when they're tucked aside (owner, 22 Oct 2026).
        withAnimation(.snappy) { showsInspector = true; settingsPeeking = false }
        focusRequest += 1
    }

    private var railAlignment: Alignment {
        Alignment(horizontal: railEdge == .leading ? .leading : railEdge == .trailing ? .trailing : .center,
                  vertical: railEdge == .top ? .top : railEdge == .bottom ? .bottom : .center)
    }

    /// The folded settings rail on its edge, with the one group opened from it beside it.
    @ViewBuilder
    private func railOverlay(in geometry: GeometryProxy) -> some View {
        if !showsInspector {
            let rail = SettingsRail(edge: railEdge, sections: SettingsSection.allCases,
                         open: { withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { railBubble = nil; reopenFromRail() } },
                         // A heading opens just that group in a card beside the rail;
                         // tapping it again closes it.
                         go: { section in withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { railBubble = railBubble == section ? nil : section } },
                         moved: { point in dropRail(at: point, in: geometry.frame(in: .global)) })
            Group {
                switch railEdge {
                case .top:
                    VStack(spacing: Space.small) {
                        rail
                        if let railBubble { railBubbleCard(railBubble, height: geometry.size.height) }
                    }
                    .padding(.top, Space.small)
                case .bottom:
                    VStack(spacing: Space.small) {
                        if let railBubble { railBubbleCard(railBubble, height: geometry.size.height) }
                        rail
                    }
                    .padding(.bottom, Space.small)
                case .leading:
                    HStack(spacing: Space.small) {
                        rail
                        if let railBubble { railBubbleCard(railBubble, height: geometry.size.height) }
                    }
                    .padding(.horizontal, Space.small)
                case .trailing:
                    HStack(spacing: Space.small) {
                        if let railBubble { railBubbleCard(railBubble, height: geometry.size.height) }
                        rail
                    }
                    .padding(.horizontal, Space.small)
                }
            }
            // Moved to another edge, it feathers out where it was and fades in at
            // its new home, as the interfaces swap (owner, 25 Oct 2026: keep it
            // consistent with the other designs).
            .id(railEdge)
            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace).combined(with: .scale(scale: 0.97)))
        }
    }

    /// The rail let go after a hold-and-drag: it goes to the nearest edge of the screen. Down a
    /// side it's where the settings open too; along the top or bottom it lies flat, as the
    /// strip in Classic does, and keeps to that edge of the iPad as it turns.
    private func dropRail(at point: CGPoint, in frame: CGRect) {
        let gaps: [(Edge, CGFloat)] = [(.top, point.y - frame.minY), (.bottom, frame.maxY - point.y),
                                       (.leading, point.x - frame.minX), (.trailing, frame.maxX - point.x)]
        let edge = gaps.min { $0.1 < $1.1 }!.0
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            railBubble = nil
            railPin = nil
            switch edge {
            case .leading, .trailing:
                railHome = nil
                settingsLeading = edge == .leading
            case .top, .bottom:
                let screen = edge == .top ? 0 : 2
                railHome = (screen - quarterTurns + 4) % 4
            }
        }
        UserDefaults.standard.set(railHome, forKey: "railHome")
    }

    /// Room the flat rail takes along the top or bottom, so the preview sits clear of it.
    private func railInset(_ edge: Edge) -> CGFloat {
        !showsInspector && railEdge == edge ? SettingsRail.width + Space.small * 2 : 0
    }

    /// One group, opened from the folded rail, as a glass card beside it. The full settings and
    /// the groups stay away, so there's only ever one menu on screen (owner, 25 Oct 2026: "it
    /// could just be a bubble next to it").
    private func railBubbleCard(_ section: SettingsSection, height: CGFloat) -> some View {
        // The card is its own glass, as in Classic: no panel box around it, and the scroll
        // area doesn't clip its edges or shadow (owner, 25 Oct 2026: it looked boxed in).
        let card = AnyView(SettingsCard(title: section.title, icon: section.icon, footer: section.footer) {
            sectionContent(section)
        })
        // Too tall to fit, it scrolls and fades to clear at the top and bottom, as the side
        // menu does, so above a bottom rail it melts away before the rail rather than running
        // into it (owner, 25 Oct 2026: a white feather behind it wasn't right). The fade's
        // area reaches past the card's sides, so its edges and shadow aren't cut.
        let side: CGFloat = 24
        return ViewThatFits(in: .vertical) {
            card.frame(width: 360)
            ScrollView { card.frame(width: 360).padding(.horizontal, side) }
                .contentMargins(.vertical, 28, for: .scrollContent)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .modifier(ScrollEdges(fades: appTheme.isGlassy && !reducesGlass))
                .padding(.horizontal, -side)
        }
        .frame(width: 360)
        // Flat along the top or bottom in portrait, it leaves room for the rail and the
        // top bar, so it never runs into the other menus.
        .frame(maxHeight: railEdge == .top || railEdge == .bottom ? min(height * 0.6, 560) : min(height * 0.75, 640))
        .contentShape(Rectangle())
        // The widget steps out of its way, and comes back when it closes.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { stepWidgetAside(from: $0) }
        // Only once no card is open: going from one group to the next, the widget stays put
        // rather than sliding back and out again (owner, 25 Oct 2026: it wobbled).
        .onDisappear { if railBubble == nil { stepWidgetAside(from: nil) } }
        .transition(.scale(scale: 0.94, anchor: railEdge == .top ? .top : railEdge == .bottom ? .bottom : railEdge == .leading ? .leading : .trailing).combined(with: .opacity))
        .id(section)
    }

    /// Which side each panel is on, and which is on top when they share a side.
    private var panelsStacked: Bool { groupsTrailing != settingsLeading }
    private var panelLayoutKey: String { "\(groupsTrailing)\(settingsLeading)\(groupsBelow)\(groupsAlongBottom)\(groupsAlongTop)" }

    /// How much room the panels on one side take from the preview.
    private func panelInset(leading: Bool, settingsWidth: CGFloat) -> CGFloat {
        let groupsHere = showsSidebar && sidebarAlongside && !groupsOnEdge && groupsTrailing != leading
        let settingsHere = showsInspector && settingsLeading == leading
        if settingsHere { return settingsPeeking ? Peek.showing + Space.medium : settingsWidth + Space.medium }
        if !showsInspector && railEdge == (leading ? .leading : .trailing) { return SettingsRail.width + Space.small * 2 }
        return groupsHere ? groupsWidth + Space.medium : 0
    }

    /// One side's panels: none, one, or both stacked (the groups at their own height, the
    /// settings taking the rest).
    @ViewBuilder
    private func panelColumn(leading: Bool, area: CGSize, settingsWidth: CGFloat) -> some View {
        let groupsHere = showsSidebar && groupsFree && !groupsOnEdge && groupsTrailing != leading
        let settingsHere = showsInspector && settingsLeading == leading
        if groupsHere || settingsHere {
            VStack(spacing: Space.medium) {
                if groupsHere && !groupsBelow {
                    groupsColumnPanel(leading: leading, area: area, width: settingsHere ? settingsWidth : groupsWidth, strip: settingsHere)
                        // On its own side, at the height it was dropped, kept on screen.
                        .padding(.top, settingsHere ? 0 : max(0, min(groupsTop, area.height - sidebarRect.height - Space.large)))
                }
                if settingsHere { settingsColumnPanel(leading: leading, area: area, width: settingsWidth) }
                if groupsHere && groupsBelow { groupsColumnPanel(leading: leading, area: area, width: settingsHere ? settingsWidth : groupsWidth, strip: settingsHere) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func groupsColumnPanel(leading: Bool, area: CGSize, width: CGFloat, strip: Bool) -> some View {
        groupsPanel(asStrip: strip)
            .dynamicTypeSize(groupsTextSize)
            .simultaneousGesture(textPinchGesture(.groups))
            .sensoryFeedback(.selection, trigger: groupsTextSize)
            .frame(width: width)
            // Measured at rest, before the lift and the carry: measuring after them wrote new
            // state on every frame of a drag, redrawing the whole screen (owner: "feels slow").
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !groupsCarried { sidebarRect = $0 } }
            .modifier(CarriedShape(carried: groupsCarried || StressTest.carried, style: carryStyle, icon: "list.bullet", title: "Groups", simple: reduceMotion))
            .scaleEffect(groupsCarried || groupsHeld ? 1.025 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: groupsHeld || groupsCarried)
            .shadow(color: .black.opacity(groupsCarried || groupsHeld ? 0.18 : 0), radius: 20, y: 10)
            .modifier(LiveOffset(motion: motion, path: \.groupsMove))
            .zIndex(groupsCarried ? 1 : 0)
            // The same bar along the top as the settings panel: drag it to move the panel, or
            // hold anywhere for a moment, then drag (owner idea, 2026-10-21: one way for both).
            // (The grab bar is gone, owner 22 Oct 2026: hold anywhere on the groups, then drag.)
            .simultaneousGesture(groupsHoldAndDrag(area: area))
            .sensoryFeedback(.impact(weight: .medium), trigger: groupsHeld) { _, held in held }
            .overlay(alignment: .top) { textSizeOverlay(.groups) }
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in markActive(.groups) })
            .transition(panelTransition(leading ? .leading : .trailing))
    }

    private func settingsColumnPanel(leading: Bool, area: CGSize, width: CGFloat) -> some View {
        settingsList
            .dynamicTypeSize(settingsTextSize)
            .simultaneousGesture(textPinchGesture(.settings))
            .sensoryFeedback(.selection, trigger: settingsTextSize)
            // With no panel behind the cards (Glass), they fade out softly at the top and bottom
            // as they scroll, rather than being cut by a big rounded edge (owner, 22 Oct 2026).
            .modifier(ScrollEdges(fades: appTheme.isGlassy && !reducesGlass))
            // In the Glass theme there's no panel behind the cards: each card is its own window
            // of glass, apart from the others by the gap between them (owner direction, 2026-10-21).
            .modifier(PanelBacking(clear: appTheme.isGlassy && !reducesGlass))
            .overlay(alignment: .top) { textSizeOverlay(.settings) }
            // A grabber along the top to pick the settings up and put them somewhere else; the
            // list itself still scrolls as normal.
            // (No grab bar, owner 22 Oct 2026: hold a card's title bar, then drag; see PanelCarry.)
            // Or hold anywhere on the panel for a moment, then drag: a quick swipe still scrolls.
            // (Holding anywhere on the panel to move it stopped segmented controls inside from
            // answering taps, 2026-10-21: usability first, so it moves by its bar only.)
            // Scrolling marks it as the panel in use. (A touch-down gesture did too, but it
            // stopped segmented controls inside from answering taps, 2026-10-21.)
            .onScrollPhaseChange { _, phase in
                if phase != .idle { markActive(.settings) }
            }
            .scrollIndicators(.hidden)
            // (No scroll bar, owner 22 Oct 2026: it can't be grabbed, and the groups show where
            // you are.)
            .frame(width: width)
            // Measured at rest, before the lift and the carry (see the groups panel).
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !settingsCarried { inspectorRect = $0 } }
            .modifier(CarriedShape(carried: settingsCarried || StressTest.carried, style: carryStyle,
                                   icon: settingsGrab?.icon ?? selectedSection?.icon ?? "slider.horizontal.3",
                                   title: settingsGrab?.title ?? selectedSection?.title ?? "Settings", simple: reduceMotion,
                                   hold: settingsGrab.map { CGPoint(x: $0.point.x - inspectorRect.minX, y: $0.point.y - inspectorRect.minY) },
                                   size: inspectorRect.size))
            // Lifts when it's picked up, like a widget on the Home Screen.
            .scaleEffect(settingsCarried ? 1.025 : 1)
            .shadow(color: .black.opacity(settingsCarried ? 0.2 : 0), radius: 22, y: 12)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: settingsCarried)
            .modifier(LiveOffset(motion: motion, path: \.settingsMove))
            .modifier(Peek(on: settingsPeeking, towardsLeading: leading, width: width, simple: reduceMotion, wake: {
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { settingsPeeking = false }
            }, further: {
                // Pushed again: it folds into the rail of headings at the edge.
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                    settingsPeeking = false
                    showsInspector = false
                    // The rail lists the same headings as the groups, so the groups step away
                    // too: one menu on screen, never two saying the same thing (owner, 22 Oct 2026).
                    railHidGroups = showsSidebar
                    showsSidebar = false
                }
            }))
            // A sideways swipe on the panel itself, towards its edge, tucks it aside (owner,
            // 22 Oct 2026: "when your finger touches the panel itself and slides"). Up and down
            // still scroll.
            .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { drag in
                let dx = drag.predictedEndTranslation.width
                guard !settingsCarried, !settingsPeeking, abs(dx) > 140,
                      abs(drag.translation.width) > abs(drag.translation.height) * 1.6 else { return }
                if (dx < 0) == leading { flickSettings(towardsLeading: leading, in: area) }
            })
            .zIndex(settingsCarried ? 1 : 0)
            .environment(\.panelCarry, PanelCarry(
                grabbed: { grab in if settingsGrab == nil { settingsGrab = grab } },
                moved: { move in
                    if !settingsCarried { settingsCarried = true }
                    motion.settingsMove = move
                    track(carryTarget(groups: false, move: move, finger: settingsFinger(move), in: area), moved: move)
                },
                ended: { moved in
                    if let moved {
                        let finger = settingsFinger(moved)
                            ?? CGPoint(x: inspectorRect.midX + moved.width, y: inspectorRect.minY + 40 + moved.height)
                        let wasLeading = settingsLeading, before = inspectorRect
                        // Swapping sides moves the panel to the other column, which SwiftUI sees
                        // as a new panel: it faded out, slid in from the edge and the rest of the
                        // screen jumped (simulator frames, 22 Oct 2026). Instead it's put down in
                        // its new column exactly where the finger left it, with no transition,
                        // and glides home from there.
                        panelSwap = true
                        var still = Transaction()
                        still.disablesAnimations = true
                        withTransaction(still) {
                            placePanel(groups: false, at: finger, in: area, animated: false)
                            if settingsLeading != wasLeading {
                                let home = settingsLeading ? panelsOrigin.x + Space.medium
                                    : panelsOrigin.x + area.width - Space.medium - before.width
                                motion.settingsMove = CGSize(width: moved.width - (home - before.minX), height: moved.height)
                            }
                        }
                    }
                    settingsGrab = nil
                    carryTarget = nil
                    withAnimation(reduceMotion ? nil : Self.cardLand) {
                        motion.settingsMove = .zero
                        settingsCarried = false
                    }
                    // The widget steps out from under it as it lands, not half a second later.
                    clearWidgetFromPanels(after: 60)
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        panelSwap = false
                    }
                },
                flicked: { towardsLeading in flickSettings(towardsLeading: towardsLeading, in: area) }))
            .sensoryFeedback(.impact(weight: .medium), trigger: settingsCarried) { _, lifted in lifted }
            .transition(panelTransition(leading ? .leading : .trailing))
    }

    /// Where the finger carrying the settings is now, if it picked them up by a card.
    private func settingsFinger(_ move: CGSize) -> CGPoint? {
        settingsGrab.map { CGPoint(x: $0.point.x + move.width, y: $0.point.y + move.height) }
    }

    /// Puts a panel down: on the side it's dropped, sharing that side if the other panel is
    /// already there (above or below it, by where it was dropped).
    private func placePanel(groups: Bool, at point: CGPoint, in area: CGSize, animated: Bool = true) {
        let leading = point.x < area.width / 2
        withAnimation(reduceMotion || !animated ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            if groups { groupsTrailing = !leading } else { settingsLeading = leading }
            if panelsStacked {
                let other = groups ? inspectorRect : sidebarRect
                let above = point.y < (other == .zero ? area.height / 2 : other.midY)
                groupsBelow = groups ? !above : above
            }
        }
    }

    /// Where a carried panel would settle, worked out from where it's been carried to.
    private func carryTarget(groups: Bool, move: CGSize, finger: CGPoint?, in area: CGSize) -> CarryTarget {
        let base = groups ? sidebarRect : inspectorRect
        let other = groups ? inspectorRect : sidebarRect
        // The settings go by the finger when it's known, the same as where they're put down.
        let byFinger = groups ? nil : finger
        let x = byFinger?.x ?? base.midX + move.width
        let y = byFinger?.y ?? base.minY + (groups ? 0 : 40) + move.height
        // The groups go by the finger for lying flat and sticking on, as when they're let go.
        let landing = groups ? finger.flatMap { groupsLanding(at: $0, in: area) } : nil
        let stacked = if case .stacked? = landing { true } else { false }
        return CarryTarget(groups: groups,
                           leading: x < area.width / 2,
                           top: y < other.midY,
                           attach: groups && !stacked ? finger.flatMap { attachmentTarget(at: $0) } : nil,
                           landing: landing)
    }

    /// Keeps the carry target, only when it changes (so a drag redraws the screen rarely).
    private func track(_ target: CarryTarget, moved: CGSize) {
        // Only once it's actually being carried, not the moment it's held (owner, 22 Oct 2026:
        // an outline flashed up on a plain hold).
        guard hypot(moved.width, moved.height) > 14 else { return }
        if carryTarget != target { carryTarget = target }
    }

    /// Where a carried panel would settle, as an outline (in the panels' space).
    private func panelDropHint(in area: CGSize, settingsWidth: CGFloat) -> CGRect? {
        guard let target = carryTarget else { return nil }
        let carryingGroups = target.groups
        let base = carryingGroups ? sidebarRect : inspectorRect
        // Lying flat: the outline is the pill itself, where it will land (owner, 25 Oct 2026:
        // "an outline which is the shape of it and where it's going to land").
        if let landing = target.landing {
            let count = CGFloat(SettingsSection.allCases.count)
            let size = CGSize(width: min(count * 44 + 12, area.width - Space.medium * 2), height: SettingsRail.width)
            let column = settingsLeading ? Space.medium + settingsWidth / 2 : area.width - Space.medium - settingsWidth / 2
            let centre: CGPoint = switch landing {
            case .stacked(let above): CGPoint(x: column, y: above ? Space.small + size.height / 2 : area.height - Space.large - size.height / 2)
            case .alongTop: CGPoint(x: area.width / 2, y: Space.small + size.height / 2)
            case .alongBottom: CGPoint(x: area.width / 2, y: area.height - Space.medium - size.height / 2)
            }
            return CGRect(x: centre.x - size.width / 2, y: centre.y - size.height / 2, width: size.width, height: size.height)
        }
        // Over the widget or the settings: where it would stick on.
        if let attach = target.attach {
            let frame = railFrame(for: attach, size: railSize)
            if frame != .zero { return frame.offsetBy(dx: -panelsOrigin.x, dy: -panelsOrigin.y) }
        }
        let leading = target.leading
        let otherHere = carryingGroups ? (showsInspector && settingsLeading == leading) : (showsSidebar && groupsTrailing != leading)
        let width = otherHere || !carryingGroups ? settingsWidth : groupsWidth
        let x = leading ? Space.medium : area.width - Space.medium - width
        if otherHere {
            // Half of that side, above or below the panel that's there.
            let half = (area.height - Space.medium * 3) / 2
            return CGRect(x: x, y: target.top ? 0 : half + Space.medium, width: width, height: half)
        }
        return CGRect(x: x, y: 0, width: width, height: carryingGroups ? base.height : area.height - Space.medium)
    }

    /// A quick sideways flick on a settings card's title bar pushes the panel aside: towards its
    /// own edge it slides away to a tab, towards the other side it moves across (owner, 22 Oct
    /// 2026: "swipe it and it should feel like I'm pushing it aside").
    private func flickSettings(towardsLeading: Bool, in area: CGSize) {
        // Towards its edge it tucks aside, turned and still in view like Stage Manager; back the
        // other way it comes in again (owner, 22 Oct 2026: "push the menu to the side, but not
        // have it completely disappear").
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
            settingsPeeking = towardsLeading == settingsLeading
        }
    }

    /// Hold anywhere on the groups for a moment, then drag, to carry the panel.
    private func groupsHoldAndDrag(area: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($groupsHeld) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if !groupsCarried { groupsCarried = true }
                motion.groupsMove = drag.translation
                track(carryTarget(groups: true, move: drag.translation, finger: drag.location, in: area), moved: drag.translation)
            }
            .onEnded { value in
                if case .second(true, let drag?) = value { endSidebarMove(drag, in: area) }
                dropGroups()
            }
    }

    /// Lets go of the groups: they glide from under the finger to where they've settled.
    private func dropGroups() {
        carryTarget = nil
        withAnimation(reduceMotion ? nil : Self.cardLand) {
            motion.groupsMove = .zero
            groupsCarried = false
        }
    }

    private var groupsScrub: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("groupsList"))
            .onChanged { drag in
                guard !groupsHeld, !groupsCarried, !railHeld, !railCarried else { scrubY = nil; return }
                scrubY = drag.location.y
                let nearest = groupFrames.min { abs($0.value.midY - drag.location.y) < abs($1.value.midY - drag.location.y) }?.key
                if let nearest, nearest != selectedSection { focus(nearest) }
            }
            .onEnded { drag in
                scrubY = nil
                // A sideways swipe across the groups opens them out to their names, or folds them
                // back to icons (owner, 22 Oct 2026: "the swipe works on the panel itself").
                let dx = drag.predictedEndTranslation.width
                guard abs(dx) > 120, abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                guard groupsFree else { slideGroups(out: false); return }
                let outward = groupsTrailing ? dx > 0 : dx < 0
                withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                    groupsCollapsed = outward
                }
            }
    }

    /// How much a group's button grows while a finger runs down the list: most under the finger.
    private func scrubGrowth(_ section: SettingsSection) -> CGFloat {
        guard let scrubY, let frame = groupFrames[section], !reduceMotion else { return 1 }
        return 1 + 0.1 * max(0, 1 - abs(frame.midY - scrubY) / 80)
    }

    private func endSidebarMove(_ drag: DragGesture.Value, in area: CGSize) {
        let flick = CGSize(width: drag.predictedEndTranslation.width - drag.translation.width,
                           height: drag.predictedEndTranslation.height - drag.translation.height)
        let end = CGPoint(x: sidebarRect.midX + drag.translation.width,
                          y: sidebarRect.midY + drag.translation.height)
        // Sticking goes by where the finger is, not the panel's middle: the groups are tall, so
        // their middle missed the widget when the finger was right on it (hand test, 2026-10-21).
        let finger = drag.location
        if hypot(flick.width, flick.height) > 600 {
            // Flicked away: fold into the dock on the side it was flicked towards.
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                dockOnTrailing = flick.width > 0 ? true : flick.width < 0 ? false : end.x > area.width / 2
                dockHeight = min(0.9, max(0.1, end.y / max(area.height, 1)))
                showsSidebar = false
            }
            return
        }
        // Near the top or bottom of the settings, it lies flat above or below them, before
        // anything else: let go towards the bottom it went to the middle (owner, 25 Oct 2026).
        if case .stacked(let above)? = groupsLanding(at: finger, in: area) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
                groupsAttachment = .none
                groupsAlongBottom = false
                groupsAlongTop = false
                groupsTrailing = !settingsLeading
                groupsBelow = !above
            }
            return
        }
        // Dropped onto the widget or the settings: it sticks to them.
        if let target = attachmentTarget(at: finger) {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) {
                groupsAttachment = target
                groupsTucked = false
            }
            return
        }
        // Near the bottom of the window it lies along the bottom; anywhere else it goes to that
        // side, at the height it was dropped.
        let landing = groupsLanding(at: finger, in: area)
        let alongBottom = landing == .alongBottom
        let alongTop = landing == .alongTop
        if alongBottom || alongTop || groupsOnEdge {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
                groupsAlongBottom = alongBottom
                groupsAlongTop = alongTop
            }
            if !alongBottom && !alongTop { placePanel(groups: true, at: end, in: area) }
            return
        }
        // Put down where the finger let go, then glides home: the new place is set at once,
        // and the distance carried is swapped for what's left between there and here, so the
        // pill never jumps or slides in from an edge (as the settings panel, 22 Oct 2026).
        let before = sidebarRect
        panelSwap = true
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) {
            let top = max(0, min(Double(sidebarRect.minY - panelsOrigin.y + drag.translation.height - Space.small),
                                 Double(area.height - sidebarRect.height - Space.large)))
            groupsTop = top
            placePanel(groups: true, at: end, in: area, animated: false)
            let homeX = groupsTrailing ? panelsOrigin.x + area.width - Space.medium - before.width : panelsOrigin.x + Space.medium
            let homeY = panelsOrigin.y + Space.small + CGFloat(top)
            motion.groupsMove = CGSize(width: before.minX + drag.translation.width - homeX,
                                       height: before.minY + drag.translation.height - homeY)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            panelSwap = false
        }
    }

    /// Where the groups would lie flat if let go at `point` (in the window): above or below the
    /// settings when it's at their top or bottom (or just past them), otherwise along the top
    /// or bottom of the window when it's near there; nil anywhere else.
    private func groupsLanding(at point: CGPoint, in area: CGSize) -> GroupsLanding? {
        if showsInspector, interface == .panels, inspectorRect != .zero,
           point.x > inspectorRect.minX - 60, point.x < inspectorRect.maxX + 60 {
            if point.y < inspectorRect.minY + 120 { return .stacked(above: true) }
            if point.y > inspectorRect.maxY - 160 { return .stacked(above: false) }
        }
        let y = point.y - panelsOrigin.y
        if y > area.height - 160 { return .alongBottom }
        if y < 90 { return .alongTop }
        return nil
    }

    /// What the groups would stick to if let go at `point` (in the window).
    private func attachmentTarget(at point: CGPoint) -> GroupsAttachment? {
        guard interface == .panels, !Essentials.on else { return nil }
        if widgetGroupRect.insetBy(dx: -24, dy: -24).contains(point) { return .widget }
        if showsInspector, inspectorRect.contains(point) { return .settings }
        return nil
    }

    /// The widget together with the controls riding above and below it, in the window.
    private var widgetGroupRect: CGRect {
        guard widgetRect != .zero else { return .zero }
        let span = [controlsAboveRect, controlsBelowRect]
            .filter { $0 != .zero && controlsFollowWidget && extrasVisible }
            .reduce(widgetRect) { $0.union($1) }
        // Side to side, the card or the widest control, centred on the card (the controls'
        // measured position lagged behind and pushed the groups over the panels; their widths
        // are fine, tap check 2026-10-21).
        let widest = [controlsAboveRect, controlsBelowRect]
            .filter { $0 != .zero && controlsFollowWidget && extrasVisible }
            .map(\.width).max() ?? 0
        let half = max(widgetRect.width, min(widest, 560)) / 2 + 8
        return CGRect(x: widgetRect.midX - half, y: span.minY, width: half * 2, height: span.height)
    }

    /// Where the stuck-on groups sit, in the window. On the widget: hugging the card, centred on
    /// it (not on the controls, which come and go, so it never jumps when they do), on the side
    /// with more open room, so it reads as part of the widget rather than of the settings beside
    /// it (PLAN, 22 Oct). On the settings: beside the side that faces the middle.
    private func railFrame(for target: GroupsAttachment, size: CGSize) -> CGRect {
        let anchor = target == .widget ? widgetGroupRect : inspectorRect
        guard anchor != .zero else { return .zero }
        // The widget group already has a little margin round the card.
        let gap: CGFloat = target == .widget ? 4 : 10
        let y = target == .widget ? widgetRect.midY - size.height / 2 : anchor.minY + 24
        let left = CGRect(x: anchor.minX - gap - size.width, y: y, width: size.width, height: size.height)
        let right = CGRect(x: anchor.maxX + gap, y: y, width: size.width, height: size.height)
        let onLeft = target == .widget ? (railRoom(of: anchor) ?? railOnLeft(of: anchor)) : railOnLeft(of: anchor)
        let preferred = onLeft ? left : right
        let other = preferred == left ? right : left
        // Never over an open panel or off the window (tap check, 2026-10-21: the rail slid over
        // the settings when a wide note made the widget group wider); the other side, if it's free.
        let blocked = { (rect: CGRect) in
            (target == .widget && showsInspector && rect.intersects(inspectorRect))
                || rect.minX < 0 || rect.maxX > windowWidth
        }
        return blocked(preferred) && !blocked(other) ? other : preferred
    }

    /// The side of what it's stuck to that faces the middle of the window.
    private func railOnLeft(of anchor: CGRect) -> Bool { anchor.midX > windowWidth / 2 }

    /// Whether the left of the widget has clearly more open room than the right, counting an open
    /// settings panel as a wall; nil when they're about even.
    private func railRoom(of anchor: CGRect) -> Bool? {
        var leftWall: CGFloat = 0, rightWall = windowWidth
        if showsInspector, inspectorRect != .zero {
            if inspectorRect.midX < anchor.midX { leftWall = max(leftWall, inspectorRect.maxX) }
            else { rightWall = min(rightWall, inspectorRect.minX) }
        }
        let leftRoom = anchor.minX - leftWall, rightRoom = rightWall - anchor.maxX
        guard abs(leftRoom - rightRoom) > 12 else { return nil }
        return leftRoom > rightRoom
    }

    /// The groups stuck to the widget or the settings: a column of icons that rides along with
    /// them. Push it in and it slides away to a small tab against the edge; pull the tab and it
    /// slides back out, like Slide Over. Pull it well away and it comes off as its own panel.
    private func attachedGroups(in area: CGSize) -> some View {
        let anchor = groupsAttachment == .widget ? widgetGroupRect : inspectorRect
        let tab = CGSize(width: 14, height: 86)
        let size = groupsTucked ? tab : railSize
        let frame = railFrame(for: groupsAttachment, size: size)
        let onLeft = frame.midX < anchor.midX
        // In the panels' space, kept on screen.
        let x = min(area.width - size.width / 2 - 4, max(size.width / 2 + 4, frame.midX - panelsOrigin.x))
        let y = min(area.height - size.height / 2 - 4, max(size.height / 2 + 4, frame.midY - panelsOrigin.y))
        // Outward is away from what it's stuck to.
        let outward: CGFloat = onLeft ? -1 : 1
        return Group {
            if groupsTucked {
                Capsule()
                    .fill(.primary.opacity(0.45))
                    .frame(width: 5, height: 44)
                    .frame(width: tab.width + 16, height: tab.height)
                    .background { bubbleBacking(.capsule) }
                    .appGlass(.capsule)
                    .contentShape(.capsule)
                    .onTapGesture { slideGroups(out: true) }
                    .gesture(railGesture(outward: outward, area: area))
                    .accessibilityLabel("Show groups")
                    .accessibilityAddTraits(.isButton)
            } else {
                // No bar on top (owner, 22 Oct 2026): hold anywhere, then drag, to slide it in or
                // pull it off; a finger run straight down the icons glides through the groups.
                VStack(spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        groupButton(section, iconsOnly: true)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("groupsList")) } action: { groupFrames[section] = $0 }
                    }
                }
                .coordinateSpace(name: "groupsList")
                .simultaneousGesture(groupsScrub)
                .padding(Space.small)
                .fixedSize()
                // A pill, like every other bar, in pure glass (owner, 22 Oct 2026).
                .appGlass(.capsule, panel: true)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { railSize = $0 }
                .shadow(color: .black.opacity(railCarried || railHeld ? 0.2 : 0.08), radius: railCarried || railHeld ? 20 : 10, y: 8)
                .simultaneousGesture(railHoldAndDrag(outward: outward, area: area))
                .accessibilityAction(named: "Move groups") { detachGroups() }
            }
        }
        .scaleEffect(railCarried || railHeld ? 1.03 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: railCarried || railHeld)
        .sensoryFeedback(.impact(weight: .medium), trigger: railHeld) { _, held in held }
        .modifier(LiveOffset(motion: motion, path: \.railMove))
        // Rides along with the widget while it's dragged.
        .modifier(LiveOffset(motion: motion, path: groupsAttachment == .widget ? \.cardDrag : \.none))
        .position(x: x, y: y)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.8), value: groupsTucked)
        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: anchor)
        .sensoryFeedback(.impact(weight: .light), trigger: groupsTucked)
        .accessibilityAction(named: groupsTucked ? "Slide out" : "Slide in") { slideGroups(out: groupsTucked) }
        .accessibilityAction(named: "Unstick") { detachGroups() }
    }

    /// Drag the stuck-on groups' tab: towards what they're stuck to slides them in, away slides
    /// them out, and well away (or up and down a long way) pulls them off.
    private func railGesture(outward: CGFloat, area: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { drag in railFollow(drag.translation) }
            .onEnded { drag in railLetGo(drag.translation, at: drag.location, outward: outward, area: area) }
    }

    /// The same for the open rail, after holding it for a moment.
    private func railHoldAndDrag(outward: CGFloat, area: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($railHeld) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                railFollow(drag.translation)
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                railLetGo(drag.translation, at: drag.location, outward: outward, area: area)
            }
    }

    /// Stiff along the edge, so it feels stuck on until it's pulled hard.
    private func railFollow(_ translation: CGSize) {
        if !railCarried { railCarried = true }
        motion.railMove = CGSize(width: translation.width, height: translation.height * 0.35)
    }

    private func railLetGo(_ translation: CGSize, at point: CGPoint, outward: CGFloat, area: CGSize) {
        let out = translation.width * outward
        if out > 150 || abs(translation.height) > 220 {
            detachGroups(at: point, in: area)
        } else if out > 24 {
            slideGroups(out: true)
        } else if out < -24 {
            slideGroups(out: false)
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
            motion.railMove = .zero
            railCarried = false
        }
    }

    private func slideGroups(out: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.8)) { groupsTucked = !out }
    }

    /// Takes the groups off what they're stuck to, back to a panel of their own.
    private func detachGroups(at point: CGPoint? = nil, in area: CGSize? = nil) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            groupsAttachment = .none
            groupsTucked = false
            if let point, let area { placePanel(groups: true, at: point, in: area) }
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

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if interface == .classic {
            ToolbarItem(placement: .topBarLeading) { layoutMenu }
        }
        ToolbarItem(placement: .topBarLeading) { tourButton.tint(iconsOnGlass) }
        if interface == .panels {
            ToolbarItem(placement: .topBarLeading) { fullScreenButton.tint(iconsOnGlass) }
            ToolbarItem(placement: .topBarLeading) { arrangeMenu.tint(iconsOnGlass) }
        }
        ToolbarItem(placement: .principal) { interfaceSwitch }
        ToolbarItem(placement: .primaryAction) { refreshButton.tint(iconsOnGlass) }
        ToolbarItem(placement: .primaryAction) { applyButton }
    }

    /// The panel arrangements in a menu, for anyone who'd rather pick than drag.
    private var arrangeMenu: some View {
        Menu {
            // Ready-made layouts (owner, 25 Oct 2026: a few more options now there's more UI).
            Section {
                Button("Best for This Window", systemImage: "wand.and.sparkles", action: arrangeAutomatically)
                Button("Groups Along the Bottom", systemImage: "rectangle.bottomthird.inset.filled") { arrangeAlongBottom() }
                Button("Settings Only", systemImage: "sidebar.right") {
                    arrange(groupsRight: false, settingsLeft: false)
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) { showsSidebar = false }
                }
            }
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
            groupsAttachment = .none
            // Off the top or bottom edge too, or a pick from the menu left the pill lying there.
            groupsAlongBottom = false
            groupsAlongTop = false
            showsSidebar = true
            showsInspector = true
        }
    }

    /// Settings on the right with the groups lying along the bottom, leaving the widget the
    /// most room in a narrow window.
    private func arrangeAlongBottom() {
        arrange(groupsRight: false, settingsLeft: false)
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            groupsAlongBottom = true
        }
    }

    /// Side by side when the window is wide, the groups along the bottom when it isn't.
    private func arrangeAutomatically() {
        if windowWidth >= 1100 {
            arrange(groupsRight: false, settingsLeft: false)
        } else {
            arrangeAlongBottom()
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
        appTheme.isGlassy && !reducesGlass ? AppColor.chosen(appColor) : nil
    }

    /// Classic (simple) or Panels (everything), always one tap away in the middle of the top bar.
    private var interfaceSwitch: some View {
        GlassPicker("Interface", selection: Binding(
            get: { interface },
            set: { next in withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { interface = next } }
        ), options: InterfaceStyle.allCases) { $0.label }
        .frame(width: 220)
        .appGlass(.capsule)
        .opacity(switchSettled ? 0.75 : 1)
        // (It used to slide sideways to line up with the widget, but its tap area stayed behind,
        // so Classic couldn't be tapped; owner report, 22 Oct 2026. It stays in the middle.)
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
            // The live distance and pinch go to `motion`, which only the widget itself reads, so
            // the rest of the screen redraws just when the landing slot changes.
            .onChanged { value in
                if value.first == nil, value.second != nil, !draggingCard {
                    // Pins the widget to the slot it's in before anything moves. Until it's been
                    // placed it follows the space between the panels, so a panel making room
                    // mid-drag shifted that space and the widget leapt ahead of the finger
                    // (simulator frames, 22 Oct 2026).
                    if widgetColumn < 0 {
                        let here = grid.nearest(to: CGPoint(x: home.midX, y: home.midY), span: span)
                        widgetColumn = here.column
                        widgetRow = here.row
                    }
                    withAnimation(.snappy) { draggingCard = true }
                }
                if activePanel != .widget { markActive(.widget) }
                if let pinch = value.first {
                    // Resizes live, the way the corners do (owner, 22 Oct 2026: "exactly what I was
                    // looking for"): it snaps to the nearest size as the fingers spread or close,
                    // and gives a little with them in between, growing evenly from its middle.
                    let start = pinchStartSize ?? previewSize
                    if pinchStartSize == nil { pinchStartSize = start }
                    let next = pinchTarget(for: pinch.magnification, from: start)
                    if next != previewSize { withAnimation(Self.cardSettle) { previewSize = next } }
                    let ratio = pinch.magnification * sqrt(start.size.width * start.size.height / (next.size.width * next.size.height))
                    motion.clockPinch = 1 + max(-0.12, min(0.12, (ratio - 1) * 0.3))
                    // Two fingers move it as well as size it.
                    if let drag = value.second { motion.cardDrag = drag.translation }
                } else if let drag = value.second {
                    motion.cardDrag = drag.translation
                    func lean(_ speed: CGFloat) -> CGFloat { max(-1, min(1, speed / 2400)) }
                    motion.cardLean = CGSize(width: lean(drag.velocity.width), height: lean(drag.velocity.height))
                    let landing = grid.nearest(to: CGPoint(x: home.midX + drag.translation.width,
                                                           y: home.midY + drag.translation.height), span: span)
                    let key = landing.column * 100 + landing.row
                    if key != landingKey { landingKey = key }
                }
            }
            .onEnded { value in
                swipesPausedUntil = .now.addingTimeInterval(0.4)
                motion.cardLean = .zero
                landingKey = -1
                if value.first != nil {
                    let next = previewSize
                    pinchStartSize = nil
                    // Moved while pinching: it settles where the fingers took it, at its new size.
                    if let drag = value.second {
                        let end = CGPoint(x: home.midX + drag.translation.width, y: home.midY + drag.translation.height)
                        let target = grid.nearest(to: end, span: next.span)
                        withAnimation(Self.cardLand) {
                            widgetColumn = target.column
                            widgetRow = target.row
                        }
                        makeRoom(for: grid.frame(column: target.column, row: target.row, span: next.span))
                    }
                    withAnimation(Self.cardSettle) {
                        motion.clockPinch = 1
                        motion.cardDrag = .zero
                        draggingCard = false
                    }
                } else if let drag = value.second {
                    let end = CGPoint(x: home.midX + drag.translation.width, y: home.midY + drag.translation.height)
                    let target = grid.nearest(to: end, span: span)
                    // The distance springs back to zero with the same spring that moves the widget
                    // to its new slot, so the two cancel out and it glides on from under the finger.
                    withAnimation(reduceMotion ? nil : Self.cardLand) {
                        widgetColumn = target.column
                        widgetRow = target.row
                        motion.cardDrag = .zero
                        draggingCard = false
                    }
                    // A quick drag can change slot in the same moment it's let go, before the
                    // panels heard about it, so they make room here too (simulator, 22 Oct 2026:
                    // the widget landed under the settings).
                    makeRoom(for: grid.frame(column: target.column, row: target.row, span: span))
                } else {
                    withAnimation(Self.cardSettle) {
                        motion.clockPinch = 1
                        motion.cardDrag = .zero
                        draggingCard = false
                    }
                }
            }
    }

    /// The widget size a pinch would settle on: the one nearest in area to how big the fingers
    /// have made it.
    private func pinchTarget(for magnification: CGFloat, from start: PreviewSize) -> PreviewSize {
        let area = start.size.width * start.size.height * max(0.01, magnification * magnification)
        func distance(_ size: PreviewSize) -> CGFloat { abs(log(size.size.width * size.size.height / area)) }
        return PreviewSize.allCases.min { distance($0) < distance($1) } ?? previewSize
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
        let lift: CGFloat = draggingCard && !reduceMotion ? 1.04 : 1
        let face = TimelineView(.everyMinute) { context in
            // The clock fades from one size's layout to the next while the card reshapes around
            // it, as widgets do on the iPad's Home Screen (owner, 22 Oct 2026), rather than its
            // text jumping when the size snaps.
            ZStack {
                ClockFace(date: context.date, style: style, simulatedAccent: homeScreen.accent,
                          simulatesClear: !homeScreen.showsKeptColours)
                    .id(previewSize)
                    .transition(.opacity)
            }
                .padding(16 * scale)
                .frame(width: card.width * scale, height: card.height * scale)
                .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28 * scale), homeScreen: homeScreen))
                .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
                // Switches style at once rather than blending: animating the glass tint and the
                // colour mask between styles was the costliest part of a tap on the Home Screen
                // picker (2026-10-21). Size changes still animate.
                .transaction(value: homeScreen) { $0.animation = nil }
        }
        // (The glass corner highlights while editing are gone, owner 22 Oct 2026.)
        // A small glass tag on the bottom edge, so the preview isn't mistaken for the real
        // widget (HIG: Widgets), and it travels with it (owner feedback, 2026-10-21).
        .overlay(alignment: .bottom) {
            if controlsFollowWidget && !editingWidget && !widgetMoving {
                previewTag.offset(y: 14)
            }
        }
        .shimmer(trigger: appliedShine, in: .rect(cornerRadius: 28 * scale))
        return face
            // Lifts while it's being moved, like a widget on the Home Screen.
            .scaleEffect(lift)
            // The lifted shadow sits only outside the card: a plain shadow showed through the
            // clear glass and turned the whole widget dark while it was carried, and for a
            // moment after it landed (simulator frames, 22 Oct 2026).
            // Only drawn while carried, so a resting widget costs nothing extra.
            .background { if draggingCard { LiftShadow(radius: 28 * scale, shown: true).transition(.opacity) } }
            // The lean: a soft tilt towards where it's going and a slight stretch along the way.
            .modifier(LiveLean(motion: motion, strength: CGFloat(tweakLean), still: reduceMotion))
            .scaleEffect(x: resizeStretch.width, y: resizeStretch.height, anchor: resizeCorner.opposite)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: resizeStretch)
            // Grows and shrinks with the fingers while pinching, then settles on the nearest size.
            .modifier(LivePinch(motion: motion, still: reduceMotion))
        // With Reduce Motion there's no wiggle, just an outline.
        .overlay {
            if editingWidget && reduceMotion {
                RoundedRectangle(cornerRadius: 28 * scale)
                    .strokeBorder(AppColor.chosen(appColor), lineWidth: 3)
            }
        }
        .modifier(Wiggle(active: editingWidget && !draggingCard && resizeStart == nil && !reduceMotion && tweakWiggle > 0 && !Essentials.on, degrees: tweakWiggle))
        // Trying out instead of the wiggle (owner, 22 Oct 2026: "similar but different"): while
        // held for editing it breathes, swelling a touch and settling, slowly.
        .modifier(Breathe(active: editingWidget && !draggingCard && resizeStart == nil && !reduceMotion && Essentials.on))
    }

    /// The controls that ride with the widget, hanging off its top or bottom edge.
    /// - Parameters:
    ///   - top: the Home Screen part (Done, the question and Light/Dark/Clear/Tinted).
    ///   - all: everything in one stack, for when only one side has room.
    ///   - above: hangs above the widget rather than below it.
    private func floatingControls(top: Bool, all: Bool, above: Bool) -> some View {
        VStack(spacing: Space.small) {
            if top || all {
                if editingWidget {
                    // Clear at a glance (owner, 22 Oct 2026): bigger, with a tick, lifted off the
                    // backdrop by a shadow so it reads on any colour.
                    Button { setEditingWidget(false) } label: {
                        Label("Done", systemImage: "checkmark")
                            .font(.headline.weight(.semibold))
                            .padding(.horizontal, 6)
                    }
                    .prominentButton()
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .tint(AppColor.chosen(appColor))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                        .transition(.scale.combined(with: .opacity))
                }
                // The Home Screen question rides along too, so the widget never covers it
                // (owner feedback, 2026-10-21).
                myHomeScreenNote
                if all && oneRowControls {
                    controlsPager
                } else {
                    homeScreenBubble
                }
            }
            if (!top || all) && !oneRowControls {
                sizeBubble
                backdropBubble
            }
        }
        .fixedSize()
        // A zero-height frame on the card's edge, with the controls hanging off it away
        // from the card. Below, they clear the Preview tag on the card's bottom edge.
        .frame(height: 0, alignment: above ? .bottom : .top)
        .offset(y: above ? -Space.medium : Space.medium + 14)
        .opacity(extrasVisible ? 1 : 0)
        .scaleEffect(extrasVisible || reduceMotion ? 1 : 0.9, anchor: above ? .bottom : .top)
        .allowsHitTesting(extrasVisible)
        .accessibilityHidden(!extrasVisible)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85), value: extrasVisible)
    }

    /// Brings the widget's controls up, and tucks them away again after a few quiet seconds.
    private func showExtras(for seconds: Double = 5) {
        if !extrasShown { extrasShown = true }
        extrasHide?.cancel()
        extrasHide = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, !draggingCard else { return }
            extrasShown = false
        }
    }

    /// The widget's controls one bubble at a time: swipe sideways to move between style, size
    /// and backdrop, or tap a dot (owner idea, 2026-10-21). Switched on in Design Tweaks.
    private var controlsPager: some View {
        VStack(spacing: 6) {
            Group {
                switch controlsPage {
                case 0: homeScreenBubble
                case 1: sizeBubble
                default: backdropBubble
                }
            }
            .id(controlsPage)
            .transition(reduceMotion ? .opacity : .push(from: controlsPageForward ? .trailing : .leading))
            // Simultaneous, so taps on the picker inside still land first time.
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let width = value.translation.width
                        guard abs(width) > 40, abs(width) > abs(value.translation.height) else { return }
                        turnControlsPage(to: controlsPage + (width < 0 ? 1 : -1))
                    }
            )
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { page in
                    Button { turnControlsPage(to: page) } label: {
                        Capsule()
                            .fill(.primary.opacity(page == controlsPage ? 0.9 : 0.35))
                            .frame(width: page == controlsPage ? 16 : 7, height: 7)
                            .frame(width: 26, height: 22)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(["Style", "Size", "Backdrop"][page])
                    .accessibilityAddTraits(page == controlsPage ? .isSelected : [])
                }
            }
            .padding(.horizontal, 6)
            .background { bubbleBacking(.capsule) }
            .appGlass(.capsule)
            .environment(\.colorScheme, controlScheme)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Widget controls")
        }
        .sensoryFeedback(.selection, trigger: controlsPage)
    }

    private func turnControlsPage(to page: Int) {
        let page = min(2, max(0, page))
        guard page != controlsPage else { return }
        controlsPageForward = page > controlsPage
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy) { controlsPage = page }
    }

    /// The Preview pill on the widget's bottom edge. While the controls are tucked away it shows
    /// a small chevron, and a tap brings them up (or puts them away).
    private var previewTag: some View {
        Button {
            if extrasShown { extrasHide?.cancel(); extrasShown = false } else { showExtras(for: 8) }
        } label: {
            // Clearly a button (owner, 22 Oct 2026): full-strength text, a bigger chevron, and
            // glass that answers the touch.
            HStack(spacing: 5) {
                Text("Preview")
                if quietControls && !voiceOverOn {
                    Image(systemName: extrasShown ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { bubbleBacking(.capsule) }
            .appGlass(.capsule, interactive: true)
            .environment(\.colorScheme, controlScheme)
            // A bigger target than it looks.
            .padding(8)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .padding(-8)
        .allowsHitTesting(quietControls)
        .accessibilityLabel(extrasShown ? "Hide widget controls" : "Show widget controls")
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

    /// The panels whose text can be pinched bigger or smaller.
    private enum TextPanel { case settings, groups }

    private func textStep(_ panel: TextPanel) -> Int {
        panel == .settings ? textSizeStep : groupsTextStep
    }

    private func setTextStep(_ panel: TextPanel, _ step: Int) {
        let step = min(textSizes.count - 1, max(0, step))
        if panel == .settings { textSizeStep = step } else { groupsTextStep = step }
    }

    private func setPinchingStep(_ panel: TextPanel, _ step: Int?) {
        if panel == .settings { pinchingTextStep = step } else { pinchingGroupsStep = step }
    }

    /// A panel's text size step, following the fingers while a pinch is under way.
    private func currentTextStep(_ panel: TextPanel) -> Int {
        let pinching = panel == .settings ? pinchingTextStep : pinchingGroupsStep
        return min(textSizes.count - 1, max(0, pinching ?? textStep(panel)))
    }

    private var settingsTextSize: DynamicTypeSize { textSizes[currentTextStep(.settings)] }
    private var groupsTextSize: DynamicTypeSize { textSizes[currentTextStep(.groups)] }

    /// Pinching a panel makes its text and rows bigger or smaller, a step at a time.
    /// (An experiment, owner feedback 2026-10-21.)
    private func textPinchGesture(_ panel: TextPanel) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let steps = Int((log(value.magnification) / log(1.3)).rounded())
                let next = min(textSizes.count - 1, max(0, textStep(panel) + steps))
                let pinching = panel == .settings ? pinchingTextStep : pinchingGroupsStep
                if next != pinching { withAnimation(.snappy) { setPinchingStep(panel, next) } }
                revealTextSizeBubble(panel)
            }
            .onEnded { _ in
                setTextStep(panel, currentTextStep(panel))
                setPinchingStep(panel, nil)
                revealTextSizeBubble(panel)
            }
    }

    private let textSizeNames = ["Small", "Medium", "Large", "Extra Large", "Largest"]

    @ViewBuilder
    private func textSizeOverlay(_ panel: TextPanel) -> some View {
        if textSizeBubblePanel == panel {
            textSizeBubble(panel)
                .fixedSize()
                .padding(.top, Space.medium)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.85)).combined(with: .move(edge: .top)))
        }
    }

    /// Shows the text-size bubble on a panel, and hides it again a moment after the last change.
    private func revealTextSizeBubble(_ panel: TextPanel) {
        withAnimation(.snappy) { textSizeBubblePanel = panel }
        hideTextSizeBubble?.cancel()
        hideTextSizeBubble = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { textSizeBubblePanel = nil }
        }
    }

    /// Like the volume indicator: appears while pinching a panel, showing its text size,
    /// with − and + for fine-tuning while it's up.
    private func textSizeBubble(_ panel: TextPanel) -> some View {
        let current = currentTextStep(panel)
        return VStack(spacing: Space.small) {
            HStack(spacing: Space.small) {
                Button {
                    setTextStep(panel, textStep(panel) - 1)
                    revealTextSizeBubble(panel)
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
                    setTextStep(panel, textStep(panel) + 1)
                    revealTextSizeBubble(panel)
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
        .accessibilityLabel("\(panel == .settings ? "Settings" : "Groups") text size: \(textSizeNames[current])")
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
        // Design Tweaks floats over everything at the top, in Classic and Panels alike, so the
        // app stays in view while the sliders move. Opened from App settings.
        .overlay(alignment: .top) {
            if showsTweaks {
                DesignTweaksPanel {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showsTweaks = false }
                }
                .background { GlassAmount.backing(glassAmount, in: .rect(cornerRadius: Corner.panel)) }
                .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
                .padding(.top, 70)
                .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(appColorScheme)
        .environment(\.homeLook, appTheme == .home ? settledHomeScreen : nil)
        .fontDesign(bodyDesign)
        .environment(\.headingDesign, matchesClockFont ? style.font.appDesign(roundness: style.roundness) : nil)
        .animation(.smooth, value: style.font)
        .animation(.smooth, value: appTheme)
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
        // Automatic follows the widget in every theme, so the interface goes dark with it
        // (owner, 25 Oct 2026); only a chosen Light or Dark holds still.
        guard appTheme == .home || appAppearance == .automatic else { return appAppearance.colorScheme }
        switch settledHomeScreen {
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
        .prominentButton()
        .disabled(applied)
        .sensoryFeedback(.success, trigger: appliedStyle)
    }

    /// The widget in miniature: a small widget-shaped card with "12" in the clock's own font
    /// and colour, so the button shows the style it will send (owner idea, 2026-10-21). It
    /// was a "9" in a circle, which read as a count (owner feedback, 1:30 p.m.).
    private var styleGlyph: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return Text("12")
            .font(Font(style.font.font(size: 14, weight: max(style.fontWeight, 0.6), width: style.fontWidth, roundness: style.roundness)))
            .foregroundStyle(style.color == .auto ? AnyShapeStyle(.white) : AnyShapeStyle(style.color.color))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 32, height: 22)
            .background(.black.opacity(0.3), in: shape)
            .overlay { shape.strokeBorder(.white.opacity(0.6), lineWidth: 1) }
            .contentTransition(.opacity)
            .animation(.smooth, value: style)
            .accessibilityHidden(true)
    }

    /// Sends the edited style to the widget.
    private func apply() {
        style.save()
        WidgetCenter.shared.reloadAllTimelines()
        withAnimation(.snappy) {
            appliedStyle = style
            dismissedApplyHint = false
        }
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
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onChanged { drag in
                // A drag that starts on the widget moves the widget, never the backdrop: the
                // next backdrop was sliding in behind a widget being dragged down (simulator,
                // 22 Oct 2026).
                guard !startsOnWidget(drag) else { return }
                // Leans only for sideways drags, so scrolling up and down doesn't wobble, and not
                // while the widget itself is being moved or pinched.
                if !draggingCard, !editingWidget, motion.clockPinch == 1, abs(drag.translation.width) > abs(drag.translation.height) {
                    motion.panelPull = drag.translation.width
                }
                guard !draggingCard, !editingWidget, motion.clockPinch == 1, !reduceMotion, Date.now > swipesPausedUntil else { return }
                let dx = drag.translation.width, dy = drag.translation.height
                // Up and down pull the next or previous backdrop in, following the finger.
                guard pulledBackdrop != nil || abs(dy) > abs(dx) * 1.5 else { return }
                let next = neighbourBackdrop(upward: dy < 0)
                if pulledBackdrop != next { pulledBackdrop = next }
                backdropPull = elastic(dy / pullLength)
            }
            .onEnded { drag in
                if motion.panelPull != 0 { withAnimation(.bouncy) { motion.panelPull = 0 } }
                if startsOnWidget(drag) {
                    if pulledBackdrop != nil { finishBackdropPull(predicted: 0) }
                    return
                }
                if pulledBackdrop != nil {
                    finishBackdropPull(predicted: drag.predictedEndTranslation.height / pullLength)
                    return
                }
                guard !draggingCard, !editingWidget, motion.clockPinch == 1, Date.now > swipesPausedUntil else { return }
                let dx = drag.translation.width, dy = drag.translation.height
                // Up and down flick through the backdrops (not Your Photo, which opens a picker).
                if abs(dy) > 60, abs(dy) > abs(dx) * 1.5 {
                    let options = availableBackdrops
                    let index = options.firstIndex(of: backdrop) ?? 0
                    backdropTravel = dy < 0 ? .bottom : .top
                    withAnimation(.smooth(duration: 0.55)) {
                        backdrop = options[(index + (dy < 0 ? 1 : options.count - 1)) % options.count]
                    }
                    return
                }
                guard abs(dx) > 60, abs(dx) > abs(drag.translation.height) * 1.5 else { return }
                swipePanels(right: dx > 0)
            }
    }

    private func startsOnWidget(_ drag: DragGesture.Value) -> Bool {
        interface == .panels && widgetRect.insetBy(dx: -12, dy: -12).contains(drag.startLocation)
    }

    /// The card with glass bubbles floating around it: the Home Screen style above, widget
    /// size and backdrop below.
    /// The widget on its Home Screen-style grid: drag it to another slot and it snaps there,
    /// like moving a widget on the Home Screen. It's drawn at its size rather than scaled
    /// down: scaling turned the glass into a blurry picture (owner feedback, 2026-10-20).
    private var widgetGrid: some View {
        GeometryReader { space in
            let card = previewSize.size
            // Floored like the grid's: Classic lays this out at zero size for a moment, and a
            // zero scale gave the card's glass a NaN size, which crashed the app on opening
            // Classic (2026-10-21).
            let fit = min(1, space.size.width / card.width, space.size.height / card.height)
            let scale = fit.isFinite ? max(fit, 0.05) : 1
            let grid = HomeGrid(area: space.size, scale: scale)
            let span = previewSize.span
            let slot = widgetColumn < 0 && interface == .panels && stageRect != .zero
                ? grid.nearest(to: CGPoint(x: stageRect.midX - layerRect.minX, y: stageRect.midY - layerRect.minY), span: span)
                : grid.clamped(column: widgetColumn, row: widgetRow, span: span)
            let home = grid.frame(column: slot.column, row: slot.row, span: span)
            let centre = CGPoint(x: home.midX, y: home.midY)
            let landing = landingKey >= 0 ? (column: landingKey / 100, row: landingKey % 100) : slot
            // The floating controls are split around the widget (owner direction, 2026-10-21):
            // the Home Screen style above, size and backdrop below, so the widget sits centred
            // between them. Where one side hasn't room, they all go to the side that has more.
            let roomAbove = home.minY, roomBelow = space.size.height - home.maxY
            let controlsSplit = !oneRowControls && roomAbove >= 190 && roomBelow >= 150
            let controlsAbove = roomAbove > 170 || roomAbove > roomBelow
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
                    // The widget's own shape, a little larger all round, so it reads as an outline
                    // of where it'll land and small differences don't show (owner, 22 Oct 2026).
                    let ring: CGFloat = 8
                    RoundedRectangle(cornerRadius: 28 * scale + ring, style: .continuous)
                        .fill(.white.opacity(0.14))
                        .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .frame(width: card.width * scale + ring * 2, height: card.height * scale + ring * 2)
                        .position(x: target.midX, y: target.midY)
                        .animation(.snappy, value: landing.column)
                        .animation(.snappy, value: landing.row)
                }
                AnyView(cardFace(card: card, scale: scale))
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
                        // Hold it and it lifts with a gentle wiggle; then pinch or drag it. No
                        // corner handles or glass corners any more (owner, 22 Oct 2026).
                        .onLongPressGesture(minimumDuration: 0.3) {
                            if interface == .panels, !editingWidget { setEditingWidget(true) }
                            showExtras()
                        } onPressingChanged: { pressing in
                            guard !pressing, ignoresNextCardTap else { return }
                            Task {
                                try? await Task.sleep(for: .milliseconds(300))
                                ignoresNextCardTap = false
                            }
                        }
                        .gesture(cardGesture(grid: grid, home: home, span: span))
                        .sensoryFeedback(.impact(weight: .light), trigger: draggingCard)
                        .sensoryFeedback(.selection, trigger: landingKey) { _, key in key >= 0 }
                        // Measured where it rests, not while it's dragged, so a drag doesn't write
                        // new state on every frame (owner: "it just feels slow", 22 Oct 2026).
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !draggingCard { widgetRect = $0 } }
                        .accessibilityHint("Drag to move it on the Home Screen grid. Pinch to change the widget size.")
                        .accessibilityAction(named: "Move left") { moveWidget(-1, 0, grid: grid, slot: slot) }
                        .accessibilityAction(named: "Move right") { moveWidget(1, 0, grid: grid, slot: slot) }
                        .accessibilityAction(named: "Move up") { moveWidget(0, -1, grid: grid, slot: slot) }
                        .accessibilityAction(named: "Move down") { moveWidget(0, 1, grid: grid, slot: slot) }
                        // The style and size controls ride along with the widget as it's
                        // moved, so they're always next to it (owner request, 2026-10-21).
                        .overlay(alignment: .top) {
                            if controlsFollowWidget && (controlsSplit || controlsAbove) {
                                AnyView(floatingControls(top: true, all: !controlsSplit, above: true))
                                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !draggingCard { controlsAboveRect = $0 } }
                                    .onDisappear { controlsAboveRect = .zero }
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if controlsFollowWidget && (controlsSplit || !controlsAbove) {
                                AnyView(floatingControls(top: controlsSplit ? false : true, all: !controlsSplit, above: false))
                                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !draggingCard { controlsBelowRect = $0 } }
                                    .onDisappear { controlsBelowRect = .zero }
                            }
                        }
                        .animation(.smooth, value: controlsSplit)
                        .animation(.smooth, value: controlsAbove)
                .position(x: centre.x, y: centre.y)
                // The slot is saved with @AppStorage, whose changes can arrive without the
                // drop's animation: then the widget jumped to its new slot while the finger's
                // distance sprang back, so it shot past the slot and pulled back (owner, 22 Oct
                // 2026; seen frame by frame in the simulator). Animating the position itself with
                // the same spring keeps the two in step: one glide from the finger into the slot.
                .animation(reduceMotion ? nil : Self.cardLand, value: centre)
                .modifier(LiveOffset(motion: motion, path: \.cardDrag))
                // Out of the way of a card opened from the rail (see stepWidgetAside).
                .offset(widgetNudge)
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
            .onChange(of: landingKey) {
                if draggingCard, landingKey >= 0 { makeRoom(for: grid.frame(column: landing.column, row: landing.row, span: span)) }
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
    }

    /// Once a newly opened panel has settled, moves the widget back to the middle of the free
    /// space if the panel covers it.
    private func clearWidgetFromPanels(after delay: Int = 450) {
        Task {
            try? await Task.sleep(for: .milliseconds(delay))
            let card = widgetRect.insetBy(dx: 12, dy: 12)
            let covered = (showsInspector && card.intersects(inspectorRect))
                || (showsSidebar && groupsFree && card.intersects(sidebarRect))
            guard covered, !draggingCard else { return }
            withAnimation(Self.cardSettle) { widgetColumn = -1; widgetRow = -1 }
        }
    }

    /// A card open from the rail would cover the widget: the widget slides away from the
    /// card's edge with the card's own spring, just far enough to be seen, kept on screen
    /// (owner, 25 Oct 2026: "you want to see the changes you make"). Nil slides it back.
    private func stepWidgetAside(from card: CGRect?) {
        var nudge = CGSize.zero
        // Worked out from where the widget rests, not where it has stepped to: measured after
        // the step, the card no longer covered it, so it came back, was covered and stepped
        // out again on every frame of the card's opening, a loop that could hang the app.
        let widgetRect = widgetRect.offsetBy(dx: -widgetNudge.width, dy: -widgetNudge.height)
        if let card, self.widgetRect != .zero, card.intersects(widgetRect) {
            let gap = Space.medium
            switch railEdge {
            case .bottom: nudge.height = card.minY - gap - widgetRect.maxY
            case .top: nudge.height = card.maxY + gap - widgetRect.minY
            case .leading: nudge.width = card.maxX + gap - widgetRect.minX
            case .trailing: nudge.width = card.minX - gap - widgetRect.maxX
            }
            // Never pushed off the screen: where there isn't room it goes as far as it can.
            if layerRect != .zero {
                nudge.width = min(max(nudge.width, layerRect.minX - widgetRect.minX), layerRect.maxX - widgetRect.maxX)
                nudge.height = min(max(nudge.height, layerRect.minY - widgetRect.minY), layerRect.maxY - widgetRect.maxY)
            }
        }
        // Small changes as the card settles aren't worth a move.
        guard abs(nudge.width - widgetNudge.width) > 4 || abs(nudge.height - widgetNudge.height) > 4 || nudge == .zero,
              nudge != widgetNudge else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { widgetNudge = nudge }
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
            VStack(spacing: compact ? Space.small : Space.large) {
                Spacer(minLength: 0)
                // In Panels the style and size controls float with the widget instead (below).
                if !controlsFollowWidget { homeScreenBubble }
                // On iPhone the question and label give their room to the widget.
                if !controlsFollowWidget && !compact {
                    myHomeScreenNote
                        .modifier(StageChrome(shown: showsChrome))
                }
                // Labelled so the preview isn't mistaken for a working widget (HIG: Widgets). In
                // Panels the label is a tag on the widget itself (`previewTag`).
                if !controlsFollowWidget && !compact {
                    Text("Preview")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .environment(\.colorScheme, controlScheme)
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
            .padding(.horizontal, controlsFollowWidget || compact ? Space.small : Space.large)
            .padding(.top, compact ? Space.small : Space.medium)
            .padding(.bottom, compact ? Space.small : Space.large)
            // In Classic the backdrop's name shows over the preview; in Panels it sits at the
            // bottom middle of the window instead, where it's easy to find (`backdropNameOverlay`).
            .overlay(alignment: .top) {
                if showsChrome, interface == .classic, let backdropToast {
                    backdropNameCard(backdropToast)
                        .padding(.top, Space.small)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8)))
                        .accessibilityHidden(true)
                }
            }
    }

    /// What's behind the card, sliding in when it changes: up for a swipe up or a pick from the
    /// menu, down for a swipe down. With Reduce Motion it fades instead.
    private var backdropView: some View {
        ZStack {
            // While a new backdrop is being pulled in, it waits underneath, settling from
            // slightly zoomed as the old one lifts away.
            // The stage the backdrops slide across, seen in the gap between them: a soft blur
            // of the backdrop itself, so there's never a hard black edge. Only while a backdrop
            // moves: a full-screen blur left under a still backdrop kept the GPU busy for
            // nothing, and the iPad froze with Glass Clock open (SpringBoard hang, 25 Oct 2026).
            if pulledBackdrop != nil || (backdropSettling && !quietBackdrop) {
                backdropFill(backdrop)
                    .blur(radius: 40)
                    .scaleEffect(1.2)
                    .zIndex(-2e12)
            }
            // While a new backdrop is being pulled in, it slides in from the edge alongside the
            // current one, growing to full size, like the next card on a carousel.
            if let pulledBackdrop {
                backdropFill(pulledBackdrop)
                    // Simpler effects: no slide, the new backdrop just shows through as it's pulled.
                    .modifier(CarouselSlide(progress: reduceMotion ? 0 : 1 - min(1, abs(backdropPull)),
                                            edge: backdropPull <= 0 ? 1 : -1))
                    // Underneath everything, including the current backdrop's low zIndex below.
                    .zIndex(-1e12)
            }
            backdropFill(backdrop)
                .modifier(GlassSheetEffect(progress: reduceMotion ? 0 : abs(backdropPull), upward: backdropPull <= 0))
                .opacity(reduceMotion ? 1 - min(1, abs(backdropPull)) * 0.8 : 1)
                .id(backdrop)
                // Each newer backdrop sits lower than the one before, so the leaving backdrop
                // (which keeps its last value while it animates away) stays on top and lifts off
                // like a sheet, rather than sliding unseen underneath.
                .zIndex(-ProcessInfo.processInfo.systemUptime)
                .transition(reduceMotion || quietBackdrop ? AnyTransition.opacity
                            : AnyTransition(GlassSheetTransition(upward: backdropTravel == .bottom)))
        }
        .animation(quietBackdrop ? .easeOut(duration: 0.3) : .smooth(duration: 0.7), value: backdrop)
        .clipped()
        .onChange(of: backdrop) { backdropSettling = true }
        .task(id: backdrop) {
            try? await Task.sleep(for: .seconds(0.8))
            if !Task.isCancelled { backdropSettling = false }
        }
    }

    /// The backdrop after (upwards) or before this one, skipping Your Photo until there is one.
    private func neighbourBackdrop(upward: Bool) -> PreviewBackdrop {
        let options = availableBackdrops
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

    /// The backdrop's name, its kind above, and a dot for each backdrop of that kind.
    private func backdropNameCard(_ name: String) -> some View {
                    VStack(spacing: 4) {
                        // Which family the swipe has reached, with a dot per backdrop in it, so
                        // it's clear when the swipe moves from Gradients into Mesh and so on.
                        if let kind = backdrop.kind {
                            Text(kind.title.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(name)
                            .font(.headline)
                        if let kind = backdrop.kind {
                            HStack(spacing: 5) {
                                // The current one is a longer pill, so it reads by shape as
                                // well as by shade.
                                ForEach(kind.backdrops) { item in
                                    Capsule()
                                        .fill(item == backdrop ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                                        .frame(width: item == backdrop ? 16 : 6, height: 6)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, Space.medium)
                    .padding(.vertical, Space.small)
                    // Rounds to a capsule when it's one line (Your Photo), a soft card when three.
                    // Frosted like the bubbles, so it reads on dark patterns too.
                    .background { bubbleBacking(.rect(cornerRadius: 20)) }
                    .appGlass(.rect(cornerRadius: 20))
                    .environment(\.colorScheme, controlScheme)
    }

    /// Panels: the backdrop's name at the bottom middle, in line with the panels rather than
    /// floating over the widget (owner, 22 Oct 2026). Swipe across it for the next or previous
    /// backdrop, or tap a dot to jump to one; it stays up while it's being used.
    private var backdropNameOverlay: some View {
        Group {
            if let backdropToast {
                backdropNameCard(backdropToast)
                    .contentShape(.rect(cornerRadius: 20))
                    .gesture(DragGesture(minimumDistance: 12).onEnded { drag in
                        let dx = drag.translation.width
                        guard abs(dx) > 30, abs(dx) > abs(drag.translation.height) else { return }
                        stepBackdrop(forward: dx < 0)
                    })
                    .onTapGesture(coordinateSpace: .local) { _ in stepBackdrop(forward: true) }
                    .padding(.bottom, Space.large + (showsSidebar && groupsFree && groupsAlongBottom ? 64 : 0))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.85)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Backdrop: \(backdropToast)")
                    .accessibilityAdjustableAction { direction in stepBackdrop(forward: direction == .increment) }
            }
        }
    }

    /// The next or previous backdrop, sliding in the way a swipe on the preview does.
    private func stepBackdrop(forward: Bool) {
        let options = availableBackdrops
        let index = options.firstIndex(of: backdrop) ?? 0
        backdropTravel = forward ? .bottom : .top
        withAnimation(.smooth(duration: 0.55)) {
            backdrop = options[(index + (forward ? 1 : options.count - 1)) % options.count]
        }
    }

    /// Briefly shows the new backdrop's name over the preview.
    private func showBackdropName() {
        let name = backdrop.label
        withAnimation(.snappy) { backdropToast = name }
        Task {
            try? await Task.sleep(for: .seconds(interface == .panels ? 2.4 : 1.3))
            // Kept up for screenshots when a backdrop was passed in for testing.
            if backdropToast == name, StressTest.backdrop == nil { withAnimation(.easeOut(duration: 0.4)) { backdropToast = nil } }
            backdropTravel = .bottom
        }
    }

    /// Plain is white or black, so the card looks as it will on a plain Home Screen; Clear and
    /// Tinted need a wallpaper for their white content to show up.
    private func backdropFill(_ backdrop: PreviewBackdrop) -> some View {
        BackdropFill(backdrop: backdrop, homeScreen: homeScreen, tone: backdropTone, photo: backdropPhoto,
                     custom: backdrop == .custom ? customBackdrop.wrappedValue : nil)
    }

    /// Gradient and mesh backdrops turn pastel in Light and deep in Dark (see `BackdropFill`).
    private var backdropTone: BackdropTone {
        guard homeScreen.accent == nil else { return .natural }
        return (appColorScheme ?? systemColorScheme) == .light ? .pastel : .deep
    }

    /// A rounded piece of glass for a preview control (glass is for the controls layer, HIG: Materials).
    private func roundedBubble(cornerRadius: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(tweakBubble)
            .background { bubbleBacking(.rect(cornerRadius: cornerRadius, style: .continuous)) }
            .appGlass(.rect(cornerRadius: cornerRadius, style: .continuous))
            .environment(\.colorScheme, controlScheme)
    }

    private func bubble(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, tweakBubble)
            .padding(.vertical, tweakBubble * 0.8)
            .background { bubbleBacking(.capsule) }
            .appGlass(.capsule)
            .environment(\.colorScheme, controlScheme)
    }

    /// The labels and pickers over the preview follow the backdrop, so they stay readable when
    /// the iPad is in dark mode but the Light preview is on. Set on each bubble and label
    /// rather than on the whole preview: flipping it over the whole widget layer rebuilt the
    /// clock, the grid and every piece of glass on each tap of Light, Dark, Clear or Tinted,
    /// which stuttered and froze on the iPad (owner report, 2026-10-21).
    private var controlScheme: ColorScheme { settledHomeScreen == .light ? .light : .dark }

    /// In the Glass theme, the bubbles over the preview get the same frost as the settings
    /// cards, so every piece of glass in the app reads the same on any backdrop (owner
    /// feedback, 2026-10-21: consistency).
    @ViewBuilder
    private func bubbleBacking(_ shape: some Shape) -> some View {
        // Otherwise pure Liquid Glass, like the text-size bubble (owner, 22 Oct 2026). Over the
        // pastel backdrops in Light, clear glass looked blown out, so it gets a faint white body
        // and a hairline edge there: no blur, so it costs nothing (owner, 25 Oct 2026).
        if controlScheme == .light {
            ZStack {
                shape.fill(.white.opacity(0.4))
                shape.stroke(.black.opacity(0.1), lineWidth: 0.5)
            }
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
                                // Wrapped to a compact width, so the widget group stays narrow.
                                .frame(width: 190, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Show Mine") { withAnimation(.snappy) { homeScreen = mine } }
                                .prominentButton()
                                .controlSize(.small)
                                // The app colour with white text: over the widget the inherited
                                // tint was white, so the label vanished (tap check, 2026-10-21).
                                .tint(AppColor.chosen(appColor))
                                .foregroundStyle(.white)
                        }
                        .padding(.leading, Space.small)
                    }
                    Text("To use \(homeScreen.rawValue) on your iPad: long-press the Home Screen, tap Edit, then Customise.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 260)
                        .fixedSize(horizontal: false, vertical: true)
                        // On a frosted pill, so the small grey text reads on any backdrop.
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background { bubbleBacking(.capsule) }
                        .environment(\.colorScheme, controlScheme)
                }
            } else if let suggestion {
                suggestionBubble(suggestion)
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
        .animation(.snappy, value: suggestion)
        // The Apply suggestion waits until changes have stopped for a few seconds.
        .task(id: style) {
            changesSettled = false
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { changesSettled = true }
        }
        .onChange(of: selectedSection) { _, section in
            if section == .fonts { suggestsFont = false }
        }
    }

    /// A likely next step, shown under the Home Screen picker when nothing else is there:
    /// "Try a font" after a preset, or Apply when changes haven't reached the widget yet
    /// (owner idea, 2026-10-21). At most one at a time, and each can be dismissed.
    private enum Suggestion: Equatable {
        case tryFont, apply
    }

    private var suggestion: Suggestion? {
        if Essentials.on { return nil }
        if suggestsFont { return .tryFont }
        if style != appliedStyle && changesSettled && !dismissedApplyHint && !applyWhenLeaving { return .apply }
        return nil
    }

    private func suggestionBubble(_ suggestion: Suggestion) -> some View {
        bubble {
            HStack(spacing: Space.small) {
                Image(systemName: suggestion == .tryFont ? "textformat" : "sparkles")
                    .foregroundStyle(.primary)
                Text(suggestion == .tryFont ? "Make it yours: try a font" : "Your widget hasn't changed yet")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Button(suggestion == .tryFont ? "Fonts" : "Apply") {
                    if suggestion == .tryFont {
                        suggestsFont = false
                        focus(.fonts)
                    } else {
                        apply()
                    }
                }
                .prominentButton()
                .tint(AppColor.chosen(appColor))
                .controlSize(.small)
                Button {
                    withAnimation(.snappy) {
                        if suggestion == .tryFont { suggestsFont = false } else { dismissedApplyHint = true }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss suggestion")
            }
            .padding(.leading, Space.small)
        }
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
        // Concentric with its taller icon buttons: their 16 plus the bubble's padding.
        roundedBubble(cornerRadius: 16 + tweakBubble) {
            HomeStylePicker(selection: $homeScreen)
                // Its own width, not stretched to match a wider note above it.
                .fixedSize()
        }
    }

    private var sizeBubble: some View {
        bubble {
            GlassPicker("Widget size", selection: $previewSize, options: PreviewSize.allCases, large: true) { compact && $0 == .extraLarge ? "XL" : $0.rawValue }
            .fixedSize()
        }
    }

    /// The backdrop as two small buttons: a short menu grouped by kind, and Add Photo on its own
    /// (owner feedback, 2026-10-21: one long list was too much).
    private var backdropBubble: some View {
        bubble {
            HStack(spacing: Space.small) {
                Menu {
                    ForEach(BackdropKind.allCases) { kind in
                        Section(kind.title) {
                            ForEach(kind.backdrops) { option in backdropChoice(option) }
                        }
                    }
                    Section("Your Own") {
                        if !customBackdropRaw.isEmpty { backdropChoice(.custom) }
                        Button("Make Your Own…", systemImage: "paintbrush") { openBackdropMaker() }
                    }
                    if backdropPhoto != nil {
                        Section("Photo") { backdropChoice(.photo) }
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

                Divider().frame(height: 22)

                Button { choosingPhoto = true } label: {
                    Image(systemName: backdropPhoto == nil ? "photo.badge.plus" : "photo.on.rectangle")
                        .font(.body.weight(.medium))
                        .frame(width: 36, height: 36)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(backdropPhoto == nil ? "Add Photo" : "Choose Another Photo")

                Button { openBackdropMaker() } label: {
                    Image(systemName: "paintbrush")
                        .font(.body.weight(.medium))
                        .frame(width: 36, height: 36)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Make Your Own Backdrop")
                .popover(isPresented: $makingBackdrop) {
                    CustomBackdropEditor(backdrop: customBackdrop, tint: AppColor.chosen(appColor)) { makingBackdrop = false }
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }

    /// Every backdrop that can be shown: Your Photo once there is one, Your Own once it's made.
    private var availableBackdrops: [PreviewBackdrop] {
        PreviewBackdrop.allCases.filter {
            ($0 != .photo || backdropPhoto != nil) && ($0 != .custom || !customBackdropRaw.isEmpty)
        }
    }

    private var customBackdrop: Binding<CustomBackdrop> {
        Binding {
            CustomBackdrop.decode(customBackdropRaw) ?? CustomBackdrop()
        } set: {
            customBackdropRaw = $0.encoded
        }
    }

    /// Opens Make Your Own, showing Your Own behind it so changes are seen straight away.
    private func openBackdropMaker() {
        if customBackdropRaw.isEmpty { customBackdropRaw = CustomBackdrop().encoded }
        if backdrop != .custom {
            backdropTravel = .bottom
            withAnimation(.smooth(duration: 0.55)) { backdrop = .custom }
        }
        // In one row, the editor hangs off the backdrop page, so turn to it first.
        if oneRowControls && controlsPage != 2 {
            turnControlsPage(to: 2)
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                makingBackdrop = true
            }
        } else {
            makingBackdrop = true
        }
    }

    /// One backdrop in the menu, ticked when it's the current one.
    private func backdropChoice(_ option: PreviewBackdrop) -> some View {
        Button {
            backdrop = option
        } label: {
            if backdrop == option {
                Label(option.label, systemImage: "checkmark")
            } else {
                Text(option.label)
            }
        }
    }

    /// A small circle showing the current backdrop.
    private var backdropThumbnail: some View {
        backdropFill(backdrop)
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
                    AnyView(SettingsCard(title: section.title, icon: section.icon) { sectionContent(section, simple: true) })
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
        .contentMargins([.horizontal, .top], Corner.edge, for: .scrollContent)
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
                .prominentButton()
                .fixedSize()
                Button { roll(StylePart.colourParts) } label: {
                    HStack(spacing: 6) { Image(systemName: "paintpalette"); Text("Lucky Colours") }
                }
                .readableChip()
                .fixedSize()
                Button { roll(StylePart.styleParts) } label: {
                    HStack(spacing: 6) { Image(systemName: "textformat"); Text("Lucky Style") }
                }
                .readableChip()
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
                    .readableChip()
                    .fixedSize()
                }
            }
            .padding(.vertical, 4)

            groupLabel("Moods")
            Text("Experimental: Moods are still being tuned, so they may feel a little slow.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !StressTest.noMoods { MoodRow(style: style, locked: lockedParts, backdrop: backdrop, homeScreen: homeScreen,
                    tone: backdropTone, apply: applyMood)
            .equatable() }

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
            GlassPicker("Style", selection: $style.textFill, options: TextFill.allCases) { $0.label }
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
            GlassPicker("Style", selection: $style.background, options: CardBackground.allCases) { $0.label }
            swatchRow(selection: $style.backgroundColor)
            slider("Transparency", value: $style.cardOpacity, in: ClockStyle.cardOpacityRange, low: "Clear", high: "Solid")

        case .homeScreens:
            Picker("My Home Screen", selection: $myHomeScreen) {
                ForEach(MyHomeScreen.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Keep time colours", isOn: $style.keepsTimeColours)
            Toggle("Keep AM/PM and date colours", isOn: $style.keepsDetailColours)
            Toggle("Keep card colours", isOn: $style.keepsCardColours)

        case .accessibility:
            // Usability before flair (owner direction, 2026-10-21): each effect can be turned
            // down to something plain and standard.
            Toggle("Simpler effects", isOn: $simpleMotion)
            Toggle("Reduce glass", isOn: $reducesGlass)
            Toggle("Outline everything", isOn: $outlines)
            if outlines {
                slider("Outline width", value: $outlineWidth, in: 1...6, low: "Fine", high: "Bold")
            }
            // Off keeps the widget's controls showing all the time.
            Toggle("Tuck widget controls away", isOn: $quietControls)
            // An experiment (owner idea, 2026-10-21): the app's own text takes on the clock's
            // style. Off keeps the standard system text, for anyone who finds that easier to read.
            Toggle("App text matches the clock font", isOn: $matchesClockFont)
            // Pinching a panel changes its own size; these do the same with a plain tap.
            Stepper("Settings text: \(textSizeNames[textSizeStep])", value: $textSizeStep, in: 0...(textSizes.count - 1))
            Stepper("Groups text: \(textSizeNames[groupsTextStep])", value: $groupsTextStep, in: 0...(textSizes.count - 1))

        case .widget:
            groupLabel("App look")
            GlassPicker("Theme", selection: $appTheme, options: AppTheme.allCases) { $0.label }
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
            Toggle("Names on the folded rail", isOn: $railNames)
            Button("Design Tweaks…") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showsTweaks = true }
            }
            .buttonStyle(.borderless)
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
        GlassPicker("Clock", selection: $style.face, options: ClockFaceKind.allCases) { $0.label }
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

    /// A mood's style (already with locked parts kept) and its backdrop.
    private func applyMood(_ mood: ClockStyle, on scene: PreviewBackdrop) {
        // No "try a font" hint here: it popped up under the picker on every tap and pushed the
        // preview about, and a mood has already chosen the font.
        guard !moodSettling else { pendingMood = (mood, scene); return }
        moodSettling = true
        quietBackdrop = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { style = mood }
        backdrop = scene
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            moodSettling = false
            if let next = pendingMood {
                pendingMood = nil
                applyMood(next.style, on: next.scene)
            } else {
                quietBackdrop = false
            }
        }
    }

    /// Applies a preset, leaving locked parts alone.
    private func use(_ preset: ClockStyle) {
        withAnimation(reduceMotion ? nil : .smooth) {
            style = style.taking(Set(StylePart.allCases).subtracting(lockedParts), from: preset)
            if !lockedParts.contains(.font) { suggestsFont = true }
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
                        .padding(.horizontal, tweakChip)
                        .padding(.vertical, tweakChip / 2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(locked ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .modifier(ChipSurface(selected: locked))
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
        .readableChip()
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
    /// Colours in three labelled rows, so there's an easy default to pick (owner, 22 Oct 2026):
    /// the standard set, soft pastels and deep, rich shades, then the wheel for any colour.
    private func swatchRow(selection: Binding<ClockColor>) -> some View {
        let chosen = selection.wrappedValue
        let inPalette = ClockColor.allCases.contains(chosen) || ColourPalette.all.contains { $0.colour == chosen }
        return VStack(alignment: .leading, spacing: 6) {
            swatchLabel("Standard")
            swatchGrid {
                ForEach(ClockColor.allCases) { option in colorSwatch(option, selection: selection) }
            }
            swatchLabel("Pastel")
            swatchGrid {
                ForEach(ColourPalette.pastel) { item in colorSwatch(item.colour, name: item.name, selection: selection) }
            }
            swatchLabel("Deep")
            swatchGrid {
                ForEach(ColourPalette.deep) { item in colorSwatch(item.colour, name: item.name, selection: selection) }
                // A colour from the wheel shows as its own swatch, then the wheel itself.
                if chosen.isCustom && !inPalette { colorSwatch(chosen, selection: selection) }
                colourWheel(selection: selection)
            }
        }
    }

    private func swatchLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    /// The system colour picker, dressed as a spectrum with an eyedropper rather than its ring
    /// around a dot (owner, 22 Oct 2026). The picker sits underneath and takes the tap.
    private func colourWheel(selection: Binding<ClockColor>) -> some View {
        ColorPicker("Any colour", selection: Binding(
            get: { selection.wrappedValue.color },
            set: { picked in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(picked).getRed(&r, green: &g, blue: &b, alpha: &a)
                selection.wrappedValue = ClockColor(red: r, green: g, blue: b)
            }), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .mint, .blue, .purple, .pink, .red], center: .center))
                    .overlay { Image(systemName: "eyedropper.halffull").font(.footnote.weight(.bold)).foregroundStyle(.white).shadow(radius: 1.5) }
                    .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
                    .frame(width: 34, height: 34)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel("Any colour")
    }

    private func swatchGrid(@ViewBuilder content: () -> some View) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 44), spacing: 4)], alignment: .leading, spacing: 4) {
            content()
        }
        .padding(.vertical, 4)
    }

    private func colorSwatch(_ option: ClockColor, name: String? = nil, selection: Binding<ClockColor>) -> some View {
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
        .accessibilityLabel(option == .auto ? "Automatic colour" : name ?? option.name)
    }
}

/// The extra colour rows: soft pastels and deep, rich shades.
enum ColourPalette {
    struct Item: Identifiable {
        let name: String
        let colour: ClockColor
        var id: String { colour.rawValue }
        init(_ name: String, _ hex: String) { self.name = name; colour = ClockColor(rawValue: hex) ?? .auto }
    }

    static let pastel: [Item] = [
        Item("Blush", "#F6C1CC"), Item("Peach", "#FBD3B0"), Item("Butter", "#F7EBA8"),
        Item("Pistachio", "#CFE8C0"), Item("Seafoam", "#BDE7DF"), Item("Sky", "#BFDDF5"),
        Item("Periwinkle", "#C9CFF5"), Item("Lavender", "#DCCCF2"), Item("Rose", "#F2C6E4"),
    ]

    static let deep: [Item] = [
        Item("Crimson", "#A8132B"), Item("Rust", "#B5501C"), Item("Gold", "#C9971C"),
        Item("Olive", "#5F6B1F"), Item("Forest", "#1F6B45"), Item("Teal", "#0F7177"),
        Item("Navy", "#1C3A8A"), Item("Plum", "#6B2C7A"), Item("Espresso", "#4A3428"),
    ]

    static let all = pastel + deep
}

#Preview {
    ContentView()
}

/// The Home Screen's edit-mode wiggle: a small, quick rock back and forth while `active`.
/// A slow swell and settle, to show the widget is ready to be moved or resized.
struct Breathe: ViewModifier {
    var active: Bool

    func body(content: Content) -> some View {
        if active {
            content.phaseAnimator([1, 1.018]) { view, scale in
                view.scaleEffect(scale)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        } else {
            content
        }
    }
}

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

/// Where the settings list ends at the top and bottom: a soft fade when the cards float on
/// their own, or the panel's rounded edge when they sit on a panel.
struct ScrollEdges: ViewModifier {
    var fades: Bool

    func body(content: Content) -> some View {
        if fades {
            content.mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 28)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 36)
                }
            }
        } else {
            content.clipShape(.rect(cornerRadius: Corner.panel))
        }
    }
}

/// A panel tucked aside like a window in Stage Manager: turned away, slid mostly off its edge,
/// a sliver still showing. Tap it or swipe it back to bring it in.
struct Peek: ViewModifier {
    /// How much of a tucked panel stays on screen.
    static let showing: CGFloat = 72
    var on: Bool
    var towardsLeading: Bool
    var width: CGFloat
    var simple: Bool
    var wake: () -> Void
    /// Pushed towards the edge again: folds away into the rail.
    var further: () -> Void = {}

    func body(content: Content) -> some View {
        let away: CGFloat = towardsLeading ? -1 : 1
        content
            .allowsHitTesting(!on)
            // Squeezed narrower and a little shorter rather than turned in 3D: Liquid Glass in a
            // 3D turn can't see the backdrop and went solid black (simulator, 22 Oct 2026).
            // The squeeze still reads as a window turned away, like Stage Manager.
            .scaleEffect(x: on && !simple ? 0.8 : 1, y: on && !simple ? 0.9 : 1,
                         anchor: towardsLeading ? .trailing : .leading)
            .offset(x: on ? away * (width - Self.showing) : 0)
            .opacity(on && simple ? 0.6 : 1)
            .overlay {
                if on {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture(perform: wake)
                        .gesture(DragGesture(minimumDistance: 10).onEnded { drag in
                            if drag.translation.width * away < 0 { wake() } else if abs(drag.translation.width) > 30 { further() }
                        })
                        .offset(x: away * (width - Self.showing))
                        .accessibilityLabel("Bring the settings back")
                        .accessibilityAddTraits(.isButton)
                }
            }
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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// Simpler effects (Accessibility settings): no wiggle, lean, sweep or carousel.
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    func body(content: Content) -> some View {
        content
            .opacity(active || reduceMotion ? 1 : max(0.75, 1 - 0.15 * strength))
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
