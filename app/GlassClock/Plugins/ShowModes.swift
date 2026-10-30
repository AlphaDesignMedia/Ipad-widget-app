import SwiftUI

// SHOW MODES · plugin v1 (On trial). One tap for how the Sandbox shows itself.
// Grounded: eases people in after they've seen the real Glass Clock. Only the Grounded-shelf plugins stay on,
// Joy goes calm, and the dev tools (the dashboard, crew rundown, plugin desk and so on, all On trial) are switched off.
// Dream: everything on and Joy up a little, for showing off.
// "Put back how it was" restores exactly the plugins and Joy you had before the first tap, however many times you switch.
// Works through what the host already offers (switching plugins on and off, and Joy). This plugin never switches itself off.
// Works the same with Pip off; with Pip here they say one short line.
// Where: the circle button in the plugin bar.

struct ShowModes: SandboxPlugin {
    let info = PluginInfo(id: "modes", name: "Show Modes", version: "v1", shelf: .trial,
                          icon: "circle.lefthalf.filled", what: "One tap for Grounded (calm, like the real app) or Dream (everything on, to show off).")

    // MARK: Data

    enum Mode: String, CaseIterable {
        case grounded, dream
        var title: String { self == .grounded ? "Grounded" : "Dream" }
        var icon: String { self == .grounded ? "leaf" : "sparkles" }
        var blurb: String {
            self == .grounded ? "Calm, like the real app. Dev tools tucked away." : "Everything on. For showing off."
        }
        /// Joy for the mode: calm, or a playful notch up (host.joy still caps it when motion is simpler).
        var joy: Int { self == .grounded ? 1 : 3 }
        var line: String { self == .grounded ? "Nice and gentle." : "Right, everything's on!" }
    }

    static let restoredLine = "Back how it was."
    /// This plugin's own id: it's never switched by a mode, so the card stays put.
    static let selfID = "modes"
    static let snapOffKey = "snapOff"      // under "plug.modes.": ids that were off before the first tap
    static let snapJoyKey = "snapJoy"      // and the Joy setting

    // MARK: Logic

    /// The plugins a mode puts on: Dream is everyone, Grounded is the Grounded shelf.
    static func wanted(_ mode: Mode, _ p: any SandboxPlugin) -> Bool {
        mode == .dream || p.info.shelf == .grounded
    }

    /// Which mode the plugins are in right now, or nil when it's a mix (your own choices in Settings).
    @MainActor static func current(_ host: PipHost) -> Mode? {
        let others = host.plugins.filter { $0.info.id != selfID }
        for mode in [Mode.grounded, .dream] {
            let match = others.allSatisfy { p in
                // A plugin the host switched off for breaking can't be on, so it doesn't count either way.
                host.broken[p.info.id] != nil || host.isOn(p.info.id) == wanted(mode, p)
            }
            if match { return mode }
        }
        return nil
    }

    /// True once there's a saved "how it was" to go back to.
    @MainActor static func canPutBack(_ host: PipHost) -> Bool {
        let saved: [String]? = host.value(selfID, snapOffKey)
        return saved != nil
    }

    /// Keeps how things were, but only the first time, so Grounded then Dream then Put back still lands on the start.
    @MainActor static func saveStart(_ host: PipHost) {
        guard !canPutBack(host) else { return }
        host.setValue(Array(host.off), selfID, snapOffKey)
        host.setValue(host.joySetting, selfID, snapJoyKey)
    }

    @MainActor static func apply(_ mode: Mode, _ host: PipHost) {
        saveStart(host)
        for p in host.plugins where p.info.id != selfID {
            let want = wanted(mode, p)
            if host.isOn(p.info.id) != want, !(want && host.broken[p.info.id] != nil) {
                host.setOn(p.info.id, want)
            }
        }
        host.joySetting = mode.joy
        say(mode.line, host)
    }

    @MainActor static func putBack(_ host: PipHost) {
        guard let was: [String] = host.value(selfID, snapOffKey) else { return }
        for p in host.plugins where p.info.id != selfID {
            let want = !was.contains(p.info.id)
            if host.isOn(p.info.id) != want, !(want && host.broken[p.info.id] != nil) {
                host.setOn(p.info.id, want)
            }
        }
        if let joy: Int = host.value(selfID, snapJoyKey) { host.joySetting = joy }
        host.setValue(nil, selfID, snapOffKey)
        host.setValue(nil, selfID, snapJoyKey)
        say(restoredLine, host)
    }

    /// One short line, only if Pip's here, Joy isn't zero and nobody else is mid-sentence.
    @MainActor static func say(_ line: String, _ host: PipHost) {
        guard host.joy > 0, PipTalkTurns.floorFree(host) else { return }
        host.say(line, for: 2)
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { ModesCard(host: host) }

    struct ModesCard: View {
        let host: PipHost
        /// Whether there's a "how it was" to go back to (kept in storage, so it's looked up when the card opens and after each tap).
        @State private var canPutBack = false

        var body: some View {
            let mode = ShowModes.current(host)
            let total = host.plugins.count
            let onCount = host.plugins.filter { host.isOn($0.info.id) }.count
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button {
                        ShowModes.apply(m, host)
                        canPutBack = ShowModes.canPutBack(host)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: m.icon).font(.system(size: 18)).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).font(.system(size: 15, weight: .semibold))
                                Text(m.blurb).font(.system(size: 12)).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    }
                    .buttonStyle(PluginCardButton(on: mode == m))
                    .accessibilityLabel("\(m.title) mode")
                    .accessibilityHint(m.blurb)
                    .accessibilityAddTraits(mode == m ? .isSelected : [])
                }
                Text(mode.map { "\($0.title) is on. \(onCount) of \(total) plugins running." }
                     ?? "A mix of your own choices. \(onCount) of \(total) plugins running.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if canPutBack {
                    Button {
                        ShowModes.putBack(host)
                        canPutBack = ShowModes.canPutBack(host)
                    } label: {
                        Label("Put back how it was", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(PluginCardButton())
                    .accessibilityLabel("Put back how it was")
                    .accessibilityHint("Switches your plugins and Joy back to how they were before you chose a mode.")
                }
            }
            .font(.system(size: 13.5))
            .onAppear { canPutBack = ShowModes.canPutBack(host) }
        }
    }
}
