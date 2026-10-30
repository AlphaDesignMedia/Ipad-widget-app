// The plugin list: the twin of PLUGINS in the web sandbox's index.html.
// To add a plugin, put its file in this folder and add one line here. Order is the order in the plugin bar.

@MainActor
enum Plugins {
    static let all: [any SandboxPlugin] = [
        PipRemembers(),
        Sketch(),
        PencilWonders(),
        PlaygroundBridge(),
        PluginDesk(),
        NativeWonders(),
        HelperDial(),
        OpeningNight(),
        ProfessorPip(),
        PipBond(),
        PipEmotes(),
        DoodleDuet(),
        SetInTheirWays(),
        KeyboardKit(),
        TwentyPast(),
        LiquidIcons(),
        PipsNews(),
        LooksTimeMachine(),
        PipNotices(),
        PipsWeight(),
        Dashboard(),
        NextAction(),
        IdeaInbox(),
        BusyPip(),
        DashboardQueue(),
        TidyPip(),
        TeaBreak(),
        PipsFeelings(),
        GuestTakeover(),
        CrewRundown(),
        StationeryCupboard(),
        PipsSketchbook(),
        VendOMat(),
        // Parked for Aaron's stable show-and-tell build (30 Oct); un-comment to bring back.
        // GlassCleaner(),   // Bob: cleans the glass on its own when idle, not hand-tested
        // PipChecks(),      // Greg: speaks 8s after launch, not hand-tested
        // RobVisits(),      // Rob: pops in unprompted at joy 2+, not hand-tested
        // VintagePacks(),   // Rob: passive, parked only because the freeze says fixes only
    ]
}
