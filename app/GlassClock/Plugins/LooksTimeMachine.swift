import SwiftUI

// LOOKS TIME MACHINE · plugin v1 (Dream). Two ways back:
// 1. Looks: slide through the app's looks as they were built (Glass, then Liquid bar, then Liquid rail),
//    to see how things were. Each new look gets a stop: add a line to `looks`.
// 2. My snapshots: save how you have things set (every setting, no code), and go back to it with one tap.
//    A few things (like which plugins are on) catch up at once; anything else on the next launch.
// Where: the clock-arrow button in the plugin bar.

struct LooksTimeMachine: SandboxPlugin {
    let info = PluginInfo(id: "timemachine", name: "Looks Time Machine", version: "v1", shelf: .dream,
                          icon: "clock.arrow.circlepath", what: "Slide back through the app's looks, and save how you had things.")

    // MARK: Data

    struct Look {
        let name: String
        let liquid: Bool        // Liquid Icons on
        let whole: Bool         // its "Whole app" switch
    }

    static let looks = [
        Look(name: "Glass", liquid: false, whole: false),
        Look(name: "Liquid bar", liquid: true, whole: false),
        Look(name: "Liquid rail + top", liquid: true, whole: true),
    ]
    static let most = 8                 // snapshots kept; the oldest goes first
    /// Never saved or put back: the snapshots themselves, Pip's News memory, and the host's crash guard.
    static let skip = ["plug.timemachine.", "plug.news.", "plugStarting"]

    // MARK: Logic

    static func lookNow(_ host: PipHost) -> Int {
        let whole = UserDefaults.standard.object(forKey: LiquidIcons.wholeKey) as? Bool ?? true
        return looks.lastIndex { $0.liquid == host.isOn("liquid") && (!$0.liquid || $0.whole == whole) } ?? 0
    }

    static func travel(to i: Int, _ host: PipHost) {
        let look = looks[i]
        UserDefaults.standard.set(look.whole, forKey: LiquidIcons.wholeKey)
        host.setOn("liquid", look.liquid)
        if look.liquid { LiquidIcons.apply(host) }
    }

    static func kept(_ key: String) -> Bool { !skip.contains { key.hasPrefix($0) } }

    /// The app's own settings (not the system's).
    static func settings() -> [String: Any] {
        guard let id = Bundle.main.bundleIdentifier else { return [:] }
        return (UserDefaults.standard.persistentDomain(forName: id) ?? [:]).filter { kept($0.key) }
    }

    static func snapshots(_ host: PipHost) -> [[String: Any]] { host.value("timemachine", "snaps") ?? [] }

    static func snap(_ host: PipHost) {
        let name = Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        let snaps = [["name": name, "settings": settings()]] + snapshots(host)
        host.setValue(Array(snaps.prefix(most)), "timemachine", "snaps")
    }

    static func goBack(to snap: [String: Any], _ host: PipHost) {
        guard let saved = snap["settings"] as? [String: Any] else { return }
        let store = UserDefaults.standard
        for key in settings().keys where saved[key] == nil { store.removeObject(forKey: key) }
        for (key, value) in saved { store.set(value, forKey: key) }
        // What the host keeps in memory catches up now.
        let off = Set(saved["plugsOff"] as? [String] ?? [])
        for p in host.plugins where p.info.id != "timemachine" && host.isOn(p.info.id) == off.contains(p.info.id) {
            host.setOn(p.info.id, !off.contains(p.info.id))
        }
        host.joySetting = saved["pipJoy"] as? Int ?? 1
        if host.isOn("liquid") { LiquidIcons.apply(host) }
        host.say("Back in time!", for: 1.6)
    }

    static func remove(at i: Int, _ host: PipHost) {
        var snaps = snapshots(host)
        guard snaps.indices.contains(i) else { return }
        snaps.remove(at: i)
        host.setValue(snaps, "timemachine", "snaps")
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { MachineCard(host: host) }

    struct MachineCard: View {
        let host: PipHost
        @State private var look = 0.0
        @State private var snaps: [[String: Any]] = []

        private var ease: Animation { host.simpler ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.35) }

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("Looks").bold()
                HStack {
                    Text(LooksTimeMachine.looks[Int(look)].name)
                    Spacer()
                    Text("\(Int(look) + 1) of \(LooksTimeMachine.looks.count)").foregroundStyle(.secondary)
                }
                Slider(value: $look, in: 0...Double(LooksTimeMachine.looks.count - 1), step: 1)
                    .onChange(of: look) { _, i in withAnimation(ease) { LooksTimeMachine.travel(to: Int(i), host) } }
                    .accessibilityLabel("Look")
                    .accessibilityValue(LooksTimeMachine.looks[Int(look)].name)

                Divider()
                HStack {
                    Text("My snapshots").bold()
                    Spacer()
                    Button("Save now") { LooksTimeMachine.snap(host); reload() }
                        .buttonStyle(PluginCardButton(on: true))
                }
                if snaps.isEmpty {
                    Text("Save how things are, and come back any time.").foregroundStyle(.secondary)
                }
                ForEach(snaps.indices, id: \.self) { i in
                    let name = snaps[i]["name"] as? String ?? "Snapshot"
                    HStack {
                        Text(name)
                        Spacer()
                        Button("Go back") {
                            withAnimation(ease) { LooksTimeMachine.goBack(to: snaps[i], host) }
                            look = Double(LooksTimeMachine.lookNow(host))
                        }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Go back to \(name)")
                        Button { LooksTimeMachine.remove(at: i, host); reload() } label: { Image(systemName: "xmark") }
                            .buttonStyle(PluginCardButton())
                            .accessibilityLabel("Delete \(name)")
                    }
                }
            }
            .font(.system(size: 13.5))
            .onAppear { look = Double(LooksTimeMachine.lookNow(host)); reload() }
        }

        private func reload() { snaps = LooksTimeMachine.snapshots(host) }
    }
}
