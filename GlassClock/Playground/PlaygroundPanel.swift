import SwiftUI

// The playground's control room: the Joy Slider, every plugin with its switch, and a few
// "pretend" buttons for testing idle life without waiting fifteen minutes.
// The host app shows this as a sheet or panel wherever it likes.

struct PlaygroundPanel: View {
    @State private var playground = Playground.shared
    @State private var idle = IdleLife.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            List {
                Section { JoySliderView() }

                ForEach(playground.byShelf) { group in
                    Section("\(group.shelf.emoji) \(group.shelf.name)") {
                        ForEach(group.plugins) { plugin in
                            Toggle(isOn: Binding(
                                get: { playground.isOn(plugin.id) },
                                set: { playground.setOn(plugin.id, $0) })
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
                        }
                    }
                }

                if playground.isOn(IdleLife.plugin.id) {
                    Section("Idle Life") {
                        LabeledContent("Stage", value: idle.stage.name)
                        LabeledContent("Last act", value: idle.lastAct?.caption ?? "Nothing yet")
                        HStack {
                            ForEach([1, 3, 15], id: \.self) { minutes in
                                let label = "\(minutes) min"
                                Button("Pretend \(label)") { idle.pretend(idleFor: Double(minutes * 60)) }
                                    .buttonStyle(.bordered)
                                    .accessibilityHint("Acts as if nobody touched the screen for \(label).")
                            }
                        }
                        Button("Touch (reset)") { idle.touched() }
                    }
                }
            }
            .navigationTitle("Pip's Playground")
        }
        .onAppear {
            idle.reduceMotion = reduceMotion
            idle.start()
        }
        .onChange(of: reduceMotion) { _, new in idle.reduceMotion = new }
    }
}

#Preview { PlaygroundPanel() }
