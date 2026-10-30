import SwiftUI

// The playground's layer over the app: idle scenes, Pip's speech bubble and Pib's nag card.
// The host adds it to its root view with one line:
//
//     RootView().playground()
//
// Everything in it ignores touches except Pib's card, so the app underneath works as normal.
// Delete that line and the app is exactly as it was.

extension View {
    /// Adds Pip's Playground on top of this view, and notices touches (without taking them)
    /// so Idle Life knows when someone's there.
    func playground() -> some View {
        simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in IdleLife.shared.touched() })
            .overlay { PlaygroundOverlay() }
    }
}

struct PlaygroundOverlay: View {
    @State private var playground = Playground.shared
    @State private var pib = Pib.shared
    @State private var bubble: String?
    @State private var bubbleID = 0
    @State private var listening = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            IdleScenesView()

            VStack {
                Spacer()
                if let bubble {
                    SpeechBubble(text: bubble)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
                        .id(bubbleID)
                        .allowsHitTesting(false)
                }
                if pib.nagging {
                    PibNag().transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 28)
            .padding(.horizontal, 16)
            .animation(.spring(duration: 0.4), value: bubbleID)
            .animation(.spring(duration: 0.4), value: pib.nagging)
        }
        .onAppear {
            Playground.boot(reduceMotion: reduceMotion)
            guard !listening else { return }
            listening = true
            Playground.shared.listen { event in
                if case .say(let text) = event { show(text) }
            }
        }
        .onChange(of: reduceMotion) { _, new in IdleLife.shared.reduceMotion = new }
    }

    private func show(_ text: String) {
        bubbleID += 1
        let mine = bubbleID
        bubble = text
        AccessibilityNotification.Announcement(text).post()
        Task {
            try? await Task.sleep(for: .seconds(max(3, Double(text.count) / 14)))
            if bubbleID == mine { bubble = nil }
        }
    }
}

/// A small glass bubble with Pip's words in it.
struct SpeechBubble: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("🫧").font(.title2).accessibilityHidden(true)
            Text(text).font(.callout.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .accessibilityLabel("Pip says: \(text)")
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.indigo, .teal], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        Text("10:41").font(.system(size: 120, weight: .bold)).foregroundStyle(.white)
    }
    .playground()
}
