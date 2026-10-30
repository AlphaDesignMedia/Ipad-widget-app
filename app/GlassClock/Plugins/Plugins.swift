// The plugin list: the twin of PLUGINS in the web sandbox's index.html.
// To add a plugin, put its file in this folder and add one line here. Order is the order in the plugin bar.

@MainActor
enum Plugins {
    static let all: [any SandboxPlugin] = [
        PipRemembers(),
        Sketch(),
        PlaygroundBridge(),
        PluginDesk(),
        NativeWonders(),
        HelperDial(),
        OpeningNight(),
        ProfessorPip(),
        PipBond(),
        PipEmotes(),
    ]
}
