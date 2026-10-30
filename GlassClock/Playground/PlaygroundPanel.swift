import SwiftUI

// The playground's control room:
// - the Grounded / Playground switch;
// - the Joy Slider and Pip's personality;
// - every plugin with its switch and a menu to move it between shelves;
// - "Try it now" buttons, so nothing needs a fifteen-minute wait to test.
// The host app shows this as a sheet or panel wherever it likes.

struct PlaygroundPanel: View {
    @State private var playground = Playground.shared
    @State private var idle = IdleLife.shared
    @State private var persona = PipPersona.saved
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mode", selection: $playground.mode) {
                        Text("🏛️ Grounded").tag(PlaygroundMode.grounded)
                        Text("🎪 Playground").tag(PlaygroundMode.playground)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(playground.mode == .grounded
                         ? "The real app, plus only what you've moved to Grounded."
                         : "Everything you're trying is running. Switch back to Grounded any time.")
                }

                Section { JoySliderView() }

                Section("Personality") {
                    Picker("Pip is", selection: $persona) {
                        ForEach(PipPersona.allCases) { p in
                            Text("\(p.name) · \(p.vibe)").tag(p)
                        }
                    }
                    .onChange(of: persona) { _, new in
                        PipPersona.saved = new
                        if let line = PipLines.line(.back, new) { playground.emit(.say(line)) }
                    }
                }

                ForEach(playground.byShelf) { group in
                    Section {
                        ForEach(group.plugins) { plugin in
                            PluginRow(plugin: plugin)
                        }
                    } header: {
                        Text("\(group.shelf.emoji) \(group.shelf.name)")
                    } footer: {
                        if group.shelf < .grounded && playground.mode == .grounded {
                            Text("Paused in Grounded mode.")
                        }
                    }
                }

                PibDeleteRow()

                if playground.mode == .playground {
                    Section("Try it now") {
                        LabeledContent("Idle stage", value: idle.stage.name)
                        HStack {
                            ForEach([1, 3, 15], id: \.self) { minutes in
                                let label = "\(minutes) min"
                                Button("Idle \(label)") { idle.pretend(idleFor: Double(minutes * 60)) }
                                    .buttonStyle(.bordered)
                                    .accessibilityHint("Acts as if nobody touched the screen for \(label).")
                            }
                        }
                        HStack {
                            ForEach(IdleScene.allCases, id: \.self) { scene in
                                Button(sceneIcon(scene)) { IdleScenes.shared.play(scene) }
                                    .buttonStyle(.bordered)
                                    .accessibilityLabel("Play \(scene.rawValue)")
                            }
                        }
                        Button("Say something") {
                            if let line = PipLines.line(.moan) { playground.emit(.say(line)) }
                        }
                    }
                }
            }
            .navigationTitle("Pip's Playground")
        }
    }

    private func sceneIcon(_ scene: IdleScene) -> String {
        switch scene {
        case .fish: "🐟"
        case .bubbles: "🫧"
        case .plane: "✈️"
        case .bounce: "📀"
        case .stars: "✨"
        }
    }
}

/// One plugin: its switch, and a menu to move it to another shelf.
private struct PluginRow: View {
    let plugin: PlaygroundPlugin
    @State private var playground = Playground.shared

    var body: some View {
        Toggle(isOn: Binding(
            get: { playground.isSwitchedOn(plugin.id) },
            set: { on in
                playground.setOn(plugin.id, on)
                if plugin.id == Pib.plugin.id && !on { Pib.shared.switchedOff() }
            })
        ) {
            Label {
                VStack(alignment: .leading) {
                    Text(plugin.name)
                    Text(plugin.blurb).font(.footnote).foregroundStyle(.secondary)
                }
            } icon: {
                Text(plugin.icon).accessibilityHidden(true)
            }
        }
        .contextMenu {
            ForEach(PlaygroundShelf.allCases, id: \.self) { shelf in
                Button("Move to \(shelf.emoji) \(shelf.name)") { playground.move(plugin, to: shelf) }
                    .disabled(playground.shelf(of: plugin) == shelf)
            }
        }
        .accessibilityHint("Touch and hold to move it to another shelf.")
    }
}

#Preview { PlaygroundPanel() }
