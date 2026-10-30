import SwiftUI

// NEXT ACTION · plugin v1 (On trial). The dashboard's next action, big and clear, and the two after it.
// Tick one off and it's put aside on this device (the real dashboard doesn't change). Works the same with
// Pip off; with Pip here, ticking one off gets a small cheer.
// Where: a section in the Dashboard panel (no button of its own).

struct NextAction: SandboxPlugin {
    let info = PluginInfo(id: "nextaction", name: "Next action", version: "v1", shelf: .trial,
                          icon: "flag", what: "The dashboard's next step, big and clear. Tick it off when it's done.")

    // MARK: Data

    static let doneKey = "plug.nextaction.done"
    static let allClear = "All clear. Nothing waiting."

    // MARK: Logic

    /// The steps not yet ticked off here, in the dashboard's order.
    static func open(_ done: Set<String>) -> [DashboardData.Step] {
        (Dashboard.feed.data.upNext ?? []).filter { !done.contains($0.title) }
    }

    static func ticked(_ text: String) -> Set<String> {
        Set(text.split(separator: "\n").map(String.init))
    }

    // MARK: Views

    var addsTo: String? { "dashboard" }
    func addOn(_ host: PipHost) -> some View { Steps(host: host) }

    /// Each part is its own row, so the panel's card puts a line between them.
    struct Steps: View {
        let host: PipHost
        @AppStorage(NextAction.doneKey) private var doneText = ""

        var body: some View {
            let done = NextAction.ticked(doneText)
            let steps = NextAction.open(done)
            if let first = steps.first {
                VStack(alignment: .leading, spacing: 6) {
                    if let area = first.area {
                        Text(area.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    Text(Dashboard.clean(first.title)).font(.title3.weight(.bold))
                    Button("Done") { tick(first.title) }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Mark \(Dashboard.clean(first.title)) as done")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(steps.dropFirst().prefix(2), id: \.title) { step in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Then").font(.caption).foregroundStyle(.secondary)
                        Text(Dashboard.clean(step.title))
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text(NextAction.allClear)
            }
            if !done.isEmpty {
                Button("Bring back ticked (\(done.count))") { doneText = "" }
                    .buttonStyle(PluginCardButton())
            }
        }

        private func tick(_ title: String) {
            var done = NextAction.ticked(doneText)
            done.insert(title)
            doneText = done.sorted().joined(separator: "\n")
            if host.pipHere { host.cheer() }
        }
    }
}
