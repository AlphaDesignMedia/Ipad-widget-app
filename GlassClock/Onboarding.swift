import SwiftUI

/// A short, optional tour shown on first launch: four cards, skippable from any of them, and
/// available again from the Widget settings. The app is usable without it.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Card {
        var icon: String
        var title: String
        var text: String
    }

    private let cards = [
        Card(icon: "clock",
             title: "Welcome to Glass Clock",
             text: "Design a clock widget for your Home Screen. Every change shows in the preview straight away."),
        Card(icon: "dice",
             title: "Start from a preset",
             text: "Pick a preset, or tap I'm Feeling Lucky for a themed surprise. Save the ones you love to come back to."),
        Card(icon: "slider.horizontal.3",
             title: "Fine-tune anything",
             text: "Settings are grouped into Layout, Fonts, Colour, Effects and Card. Switch between the Classic and Panels layouts with the button at the top left."),
        Card(icon: "photo.on.rectangle",
             title: "See it in place",
             text: "Try it on a backdrop, or pick a screenshot of your own Home Screen. Then tap Apply to Widget."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Skip") { dismiss() }
                    .opacity(page < cards.count - 1 ? 1 : 0)
            }

            TabView(selection: $page) {
                ForEach(cards.indices, id: \.self) { index in
                    VStack(spacing: 16) {
                        Image(systemName: cards[index].icon)
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(.tint)
                            .frame(height: 72)
                            .accessibilityHidden(true)
                        Text(cards[index].title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(cards[index].text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < cards.count - 1 {
                    withAnimation(.snappy) { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page < cards.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(24)
        .frame(maxWidth: 480, maxHeight: 520)
        .presentationDetents([.height(520)])
        .presentationBackground(.regularMaterial)
    }
}
