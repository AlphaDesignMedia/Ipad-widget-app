import SwiftUI

/// A short, optional tour shown on first launch. Each card is a little animated picture of the
/// app with a label pointing at the part it's about, so people see what to do rather than read
/// it. Skippable from any card, available again from the Widget settings, and the app is usable
/// without it. "I don't want a fancy layout" switches to Classic and ends the tour.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("interfaceStyle") private var interface = InterfaceStyle.classic
    @State private var page = 0

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("I don't want a fancy layout") {
                    interface = .classic
                    dismiss()
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.secondary)
                Spacer()
                Button("Skip") { dismiss() }
                    .opacity(page < TourStep.allCases.count - 1 ? 1 : 0)
            }

            TabView(selection: $page) {
                ForEach(TourStep.allCases) { step in
                    VStack(spacing: 16) {
                        TourScene(step: step)
                            .frame(height: 230)
                            .accessibilityHidden(true)
                        Text(step.title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(step.text)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 36)
                    .tag(step.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < TourStep.allCases.count - 1 {
                    withAnimation(.snappy) { page += 1 }
                } else {
                    // The tour shows off Panels, so finishing it lands there.
                    interface = .panels
                    dismiss()
                }
            } label: {
                Text(page < TourStep.allCases.count - 1 ? "Next" : "Let's Go")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .prominentButton()
            .buttonBorderShape(.capsule)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .presentationDetents([.height(640)])
        .presentationBackground(.regularMaterial)
    }
}

private enum TourStep: Int, CaseIterable, Identifiable {
    case welcome, lucky, jump, swipe, apply
    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: "Welcome to Pip Sandbox"
        case .lucky: "Start with a surprise"
        case .jump: "Jump straight there"
        case .swipe: "Swipe the panels in"
        case .apply: "Send it to your Home Screen"
        }
    }

    var text: String {
        switch self {
        case .welcome: "Design a clock widget. Every change shows in the preview straight away."
        case .lucky: "Pick a preset, or tap I'm Feeling Lucky for a themed surprise."
        case .jump: "Tap a group on the left and the settings glide to it."
        case .swipe: "Swipe across the preview to slide the panels in and out, or tap the glass tabs on the edges."
        case .apply: "Happy with it? Tap Apply to Widget. Your changes are kept in the app until then."
        }
    }
}

/// A miniature of the Panels screen: groups on the left, the preview in the middle, settings on
/// the right, with one part lit up and labelled, and a fingertip showing the gesture.
private struct TourScene: View {
    let step: TourStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PhaseAnimator(reduceMotion ? [true] : [false, true], content: { phase in
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                // On the swipe card the settings slide in as the fingertip pulls them across.
                let sidebarOut = true
                let settingsOut = step == .swipe ? phase : true
                ZStack(alignment: .topLeading) {
                    LinearGradient(colors: [.indigo, .teal, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)

                    // Groups
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(0..<6) { row in
                            Capsule()
                                .fill(.white.opacity(step == .jump && row == 2 && phase ? 0.95 : 0.45))
                                .frame(width: row == 2 ? 44 : 36 + CGFloat(row % 3) * 6, height: 7)
                        }
                    }
                    .padding(12)
                    .frame(width: w * 0.2, height: h, alignment: .topLeading)
                    .background(.ultraThinMaterial)
                    .overlay(highlight(step == .jump))
                    .offset(x: sidebarOut ? 0 : -w * 0.2)

                    // Preview card
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.35))
                        .overlay {
                            Text("12:38")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: w * 0.3, height: h * 0.3)
                        .scaleEffect(step == .welcome && phase ? 1.08 : 1)
                        .overlay(highlight(step == .welcome))
                        .position(x: w * (sidebarOut ? 0.47 : 0.37), y: h * 0.5)

                    // Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule()
                            .fill(step == .lucky && phase ? Color.accentColor : .white.opacity(0.5))
                            .frame(width: 58, height: 12)
                            .overlay(highlight(step == .lucky))
                        ForEach(0..<7) { row in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(step == .jump && phase && (3...4).contains(row) ? 0.95 : 0.4))
                                .frame(height: 8)
                        }
                    }
                    .padding(12)
                    .frame(width: w * 0.28, height: h, alignment: .topLeading)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .topTrailing) {
                        // Apply button
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 40, height: 12)
                            .padding(6)
                            .scaleEffect(step == .apply && phase ? 1.2 : 1)
                            .overlay(highlight(step == .apply))
                            .offset(y: -2)
                            .opacity(step == .apply ? 1 : 0.6)
                    }
                    .offset(x: settingsOut ? w * 0.72 : w)

                    finger(phase: phase, w: w, h: h)
                    annotation(w: w, h: h)
                }
                .clipShape(.rect(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.4)) }
            }
        }, animation: { _ in reduceMotion ? nil : .easeInOut(duration: 1.1).delay(0.5) })
    }

    /// A glowing outline around the part the card is about.
    private func highlight(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(.yellow, lineWidth: on ? 2.5 : 0)
            .padding(-3)
            .shadow(color: .yellow.opacity(on ? 0.8 : 0), radius: 6)
    }

    /// A fingertip that taps or swipes.
    @ViewBuilder
    private func finger(phase: Bool, w: CGFloat, h: CGFloat) -> some View {
        let point: CGPoint? = switch step {
        case .lucky: CGPoint(x: w * 0.82, y: 22)
        case .jump: CGPoint(x: w * 0.1, y: 36)
        case .swipe: CGPoint(x: phase ? w * 0.55 : w * 0.9, y: h * 0.78)
        case .apply: CGPoint(x: w * 0.93, y: 14)
        case .welcome: nil
        }
        if let point {
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 22, height: 22)
                .overlay { Circle().strokeBorder(.black.opacity(0.15)) }
                .shadow(radius: 4)
                .scaleEffect(step != .swipe && phase ? 0.75 : 1)
                .position(point)
        }
    }

    /// The label pointing at the highlighted part.
    private func annotation(w: CGFloat, h: CGFloat) -> some View {
        let (text, point): (String, CGPoint) = switch step {
        case .welcome: ("Your widget, live", CGPoint(x: w * 0.47, y: h * 0.25))
        case .lucky: ("I'm Feeling Lucky", CGPoint(x: w * 0.55, y: h * 0.2))
        case .jump: ("Tap a group…", CGPoint(x: w * 0.36, y: h * 0.82))
        case .swipe: ("← Swipe", CGPoint(x: w * 0.47, y: h * 0.25))
        case .apply: ("Apply to Widget", CGPoint(x: w * 0.55, y: h * 0.3))
        }
        return Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.yellow, in: .capsule)
            .shadow(radius: 3)
            .position(point)
    }
}
