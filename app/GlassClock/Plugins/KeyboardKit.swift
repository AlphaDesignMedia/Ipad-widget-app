import SwiftUI
import UIKit

// KEYBOARD KIT · plugin v1 (On trial). Small keyboard helpers, a first step down a big rabbit hole.
// - While the on-screen keyboard is up, a "hide keyboard" chip sits just above it. One tap and it's gone.
// - With a hardware keyboard: ⌘. hides the keyboard, ⌘⇧L toggles Professor Pip's lab mode, and ⌘⇧P makes Pip
//   say something. The card lists them.
// Where: the keyboard button in the plugin bar.

struct KeyboardKit: SandboxPlugin {
    let info = PluginInfo(id: "keys", name: "Keyboard Kit", version: "v1", shelf: .trial,
                          icon: "keyboard", what: "A hide-keyboard chip, and a few keyboard shortcuts.")

    // MARK: Data

    struct Shortcut: Identifiable {
        let id: String
        let keys: String
        let what: String
    }

    static let shortcuts = [
        Shortcut(id: "hide", keys: "⌘ .", what: "Hide the keyboard"),
        Shortcut(id: "lab", keys: "⌘ ⇧ L", what: "Professor Pip's lab mode on or off"),
        Shortcut(id: "say", keys: "⌘ ⇧ P", what: "Pip says something"),
    ]

    static let chatter = ["Typing! Very professional.", "Clack clack.", "I can hear the keys. Lovely sound."]

    // MARK: Logic

    @MainActor static func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Helpers(host: host) }

    func card(_ host: PipHost) -> some View { KeysCard() }

    /// The chip above the keyboard, plus invisible buttons that carry the shortcuts.
    struct Helpers: View {
        let host: PipHost
        @State private var keyboardTop: CGFloat?
        @AppStorage("plug.prof.lab") private var lab = false

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // The shortcuts: zero-size buttons, so they take no touches but hear the keys.
                    Group {
                        Button("Hide keyboard") { KeyboardKit.hideKeyboard() }
                            .keyboardShortcut(".", modifiers: .command)
                        Button("Lab mode") { lab.toggle() }
                            .keyboardShortcut("l", modifiers: [.command, .shift])
                        Button("Pip, say something") { host.say(KeyboardKit.chatter.randomElement()!, for: 1.8) }
                            .keyboardShortcut("p", modifiers: [.command, .shift])
                    }
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)

                    if let top = keyboardTop {
                        let frame = geo.frame(in: .global)
                        Button {
                            KeyboardKit.hideKeyboard()
                        } label: {
                            Label("Hide keyboard", systemImage: "keyboard.chevron.compact.down")
                        }
                        .buttonStyle(PluginCardButton(on: true))
                        .position(x: geo.size.width - 110, y: top - frame.minY - 30)
                        .transition(.opacity)
                    }
                }
            }
            .animation(host.simpler ? nil : .snappy, value: keyboardTop)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let screen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.effectiveGeometry.coordinateSpace.bounds.height ?? 0
                // A floating or hidden keyboard doesn't reach the bottom; only show the chip for a docked one.
                keyboardTop = end.minY < screen && end.maxY >= screen - 1 && end.height > 120 ? end.minY : nil
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardTop = nil
            }
        }
    }

    struct KeysCard: View {
        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("With a hardware keyboard").bold()
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    ForEach(KeyboardKit.shortcuts) { s in
                        GridRow {
                            Text(s.keys).monospaced().bold()
                            Text(s.what).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Text("The on-screen keyboard gets a hide button just above it.").foregroundStyle(.secondary)
                Button("Hide keyboard now") { KeyboardKit.hideKeyboard() }
                    .buttonStyle(PluginCardButton())
            }
            .font(.system(size: 13.5))
        }
    }
}
