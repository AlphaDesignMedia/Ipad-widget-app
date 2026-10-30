import SwiftUI

// Pib: the accidental plugin. A cheap knock-off of Pip that got shipped by mistake. It
// switches itself on, politely begs you to switch it off, and then won't uninstall: the
// progress bar sticks at 99% until Pip gives it a nudge. Once deleted, it's gone for good.
//
// How this works (Swift idea: a state machine): Pib is always in exactly one `PibState`,
// and every button just moves it to the next state.

enum PibState: String {
    /// Just arrived. Switched itself on.
    case arrived
    /// You've switched it off; now it wants deleting properly.
    case off
    /// The uninstaller is running.
    case uninstalling
    /// Gone for good.
    case gone
}

@Observable @MainActor
final class Pib {
    static let shared = Pib()

    static let plugin = PlaygroundPlugin(
        id: "pib", name: "untitled plugin (copy) (2) FINAL", icon: "🫠", shelf: .dream,
        blurb: "This shouldn't be here. Please switch it off.")

    private static let key = Playground.keyPrefix + "pib"

    var state: PibState {
        didSet { UserDefaults.standard.set(state.rawValue, forKey: Self.key) }
    }
    /// 0…1 through the uninstall.
    private(set) var progress = 0.0
    private(set) var status = ""
    private(set) var stuck = false

    init() {
        state = PibState(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .arrived
    }

    /// Pib arrives switched on, because of course it does.
    /// Never in Grounded mode: Pib only gatecrashes the Playground.
    func arrive() {
        guard state == .arrived, !Playground.shared.isSwitchedOn(Self.plugin.id) else { return }
        Playground.shared.setOn(Self.plugin.id, true)
    }

    var nagging: Bool { state == .arrived && Playground.shared.isOn(Self.plugin.id) }

    func switchedOff() {
        if state == .arrived { state = .off }
    }

    func uninstall() {
        state = .uninstalling
        progress = 0
        stuck = false
        Task {
            let steps: [(Double, String)] = [
                (0.2, "Removing Pib…"),
                (0.41, "Removing Pib's other files…"),
                (0.7, "Asking Pib to leave…"),
                (0.93, "Pib is pretending not to hear…"),
                (0.99, "99%. Pib is holding on to the progress bar."),
            ]
            for (to, text) in steps {
                status = text
                try? await Task.sleep(for: .seconds(1.1))
                progress = to
            }
            stuck = true
        }
    }

    /// Pip helps.
    func nudge() {
        progress = 1
        status = "Done. Pip did that."
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            Playground.shared.setOn(Self.plugin.id, false)
            state = .gone
            Playground.shared.unregister(Self.plugin.id)
            Playground.shared.emit(.say("It's gone. Well, mostly. Don't check the bin."))
        }
    }
}

/// The nag card Pib shows while it's switched on.
struct PibNag: View {
    @State private var pib = Pib.shared
    @State private var playground = Playground.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🫠").font(.system(size: 40)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Hi! I'm Pib.").font(.headline)
                Text("I'm not supposed to be here. Someone shipped me by accident. Could you switch me off? I'd do it myself but I'm not very good.")
                    .font(.callout)
                Button("Switch Pib off") {
                    playground.setOn(Pib.plugin.id, false)
                    pib.switchedOff()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pib, a knock-off of Pip, asks to be switched off")
    }
}

/// The row in the Playground panel once Pib is off: "Delete properly", then the uninstaller.
struct PibDeleteRow: View {
    @State private var pib = Pib.shared

    var body: some View {
        switch pib.state {
        case .arrived, .gone:
            EmptyView()
        case .off:
            Button("🗑 Delete Pib properly", role: .destructive) { pib.uninstall() }
        case .uninstalling:
            VStack(alignment: .leading, spacing: 8) {
                Text("Uninstalling Pib").font(.headline)
                ProgressView(value: pib.progress)
                    .animation(.easeInOut, value: pib.progress)
                Text(pib.status).font(.footnote).foregroundStyle(.secondary)
                if pib.stuck && pib.progress < 1 {
                    Button("Ask Pip to give it a nudge") { pib.nudge() }
                        .buttonStyle(.bordered)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}
