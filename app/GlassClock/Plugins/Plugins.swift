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
        // LiquidIcons(),   // parked: ~40 live glass drops cost up to half a core at idle (sim), ticket 31 Oct
        PipsNews(),
        LooksTimeMachine(),
        PipNotices(),
        PipsWeight(),
        Dashboard(),
        // StableSwitch(),  // parked: Everything loses the full set after One at a time; crash clue never shows, ticket 31 Oct
        PipPeek(),          // Jules: Aaron's Pip peeks round open panels; drawn only while one is open
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
        PipManners(),
        DrawOff(),
        PipLooks(),         // Bob: Classic or Drop look; Drop shows in its card until the core look hook lands
        // All on for Aaron's show-off build (30 Oct). Comment a line out to park it again.
        // PARKED 31 Oct, Aaron's call, after the evening build ran badly. Uncomment to bring either back.
        // GlassCleaner(),  // Bob: the only plugin that starts itself when you stop touching the screen.
        //                  //      Wakes every 3s and loops a shine. Suspect two.
        PipChecks(),        // Greg: speaks 8s after launch, not hand-tested
        RobVisits(),        // Rob: pops in unprompted at joy 2+, not hand-tested
        VintagePacks(),     // Rob: passive
        // GlassMemory(),   // Dot: up to 60 separately blurred layers over the whole app, saved to disk, so it
        //                  //      got heavier every session. Suspect one. (Its marks are off by default as of
        //                  //      249bbe5, so it may be safe to bring back; the frosted ink look goes with it.)
        DirectorsCall(),    // Dot: tap Action! and Pip performs a scene. Starts only on tap; never unprompted
        PipFlags(),         // Rob: new. No loop, does nothing until opened. Park it if you'd rather.
    ]
}
