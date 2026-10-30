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
        ShowModes(),
        // All on for Aaron's show-off build (30 Oct). Comment a line out to park it again.
        GlassCleaner(),     // Bob: back on for show-off (Aaron, 30 Oct); rare at calm, stops on touch
        PipChecks(),        // Greg: speaks 8s after launch, not hand-tested
        RobVisits(),        // Rob: pops in unprompted at joy 2+, not hand-tested
        VintagePacks(),     // Rob: passive
        PipFlags(),         // Rob: new. No loop, does nothing until opened. Park it if you'd rather.
    ]
}
