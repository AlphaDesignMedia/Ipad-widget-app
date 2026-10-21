import SwiftUI
import UIKit

/// Live design settings for tuning how the app looks and feels on the iPad itself (owner idea,
/// 2026-10-21: a faster way to design together than describing changes back and forth). Each
/// is saved, and Copy Values puts them all on the clipboard to send over, to become the defaults.
enum Tweak: String, CaseIterable, Identifiable {
    case panel, gap, cardPadding, rowSpacing, frost, focus, shimmer, rim, wiggle, lean

    /// Spacing first, then the effects.
    var isSpacing: Bool { [.panel, .gap, .cardPadding, .rowSpacing].contains(self) }

    var id: Self { self }
    var key: String { "tweak.\(rawValue)" }

    var label: String {
        switch self {
        case .panel: "Panel corners"
        case .gap: "Gaps"
        case .cardPadding: "Card padding"
        case .rowSpacing: "Row spacing"
        case .shimmer: "Shimmer"
        case .rim: "Highlight rim"
        case .frost: "Frost"
        case .focus: "Focus strength"
        case .wiggle: "Wiggle"
        case .lean: "Drag lean"
        }
    }

    var standard: Double {
        switch self {
        // The owner's picks from Design Tweaks, 21 Oct 2026.
        case .panel: 41
        case .gap: 22
        case .cardPadding: 22
        case .rowSpacing: 11
        case .shimmer: 0.45
        case .rim: 0.7
        case .frost: 1.85
        case .focus: 1.35
        case .wiggle: 1.65
        case .lean: 1.1
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .panel: 12...56
        case .gap: 6...32
        case .cardPadding: 12...36
        case .rowSpacing: 4...20
        case .shimmer, .rim: 0...1
        case .frost, .focus, .lean: 0...2
        case .wiggle: 0...2.5
        }
    }

    var step: Double { isSpacing ? 1 : 0.05 }

    /// Ends of the slider, in words.
    var ends: (String, String) {
        switch self {
        case .panel: ("Square", "Round")
        case .gap, .cardPadding, .rowSpacing: ("Tight", "Airy")
        case .shimmer, .rim: ("None", "Bright")
        case .frost: ("Clear", "Frosted")
        case .focus, .lean: ("None", "Strong")
        case .wiggle: ("Still", "Lively")
        }
    }

    func formatted(_ value: Double) -> String {
        isSpacing ? "\(Int(value.rounded())) pt" : String(format: "%.2f", value)
    }

    /// The saved value, or the standard one.
    var value: Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? standard
    }
}

/// The tweaks as sliders, on a small floating panel so the app stays in view while they change.
struct DesignTweaksPanel: View {
    @AppStorage(Tweak.panel.key) private var panel = Tweak.panel.standard
    @AppStorage(Tweak.gap.key) private var gap = Tweak.gap.standard
    @AppStorage(Tweak.frost.key) private var frost = Tweak.frost.standard
    @AppStorage(Tweak.focus.key) private var focus = Tweak.focus.standard
    @AppStorage(Tweak.wiggle.key) private var wiggle = Tweak.wiggle.standard
    @AppStorage(Tweak.lean.key) private var lean = Tweak.lean.standard
    @AppStorage(Tweak.cardPadding.key) private var cardPadding = Tweak.cardPadding.standard
    @AppStorage(Tweak.rowSpacing.key) private var rowSpacing = Tweak.rowSpacing.standard
    @AppStorage(Tweak.shimmer.key) private var shimmer = Tweak.shimmer.standard
    @AppStorage(Tweak.rim.key) private var rim = Tweak.rim.standard
    @State private var copied = false
    var close: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Design Tweaks", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
            }
            Text("Changes show straight away. When it feels right, copy the values and send them to Claude.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach([true, false], id: \.self) { spacing in
                        Text(spacing ? "Spacing" : "Effects")
                            .font(.footnote.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .padding(.top, spacing ? 0 : 6)
                        ForEach(Tweak.allCases.filter { $0.isSpacing == spacing }) { tweak in
                            sliderRow(tweak)
                        }
                    }
                }
            }
            .frame(maxHeight: 460)
            HStack {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    withAnimation(.smooth) { for tweak in Tweak.allCases { binding(tweak).wrappedValue = tweak.standard } }
                }
                Spacer()
                Button(copied ? "Copied" : "Copy Values", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = "Glass Clock design tweaks: " + Tweak.allCases
                        .map { "\($0.label) \($0.formatted(binding($0).wrappedValue))" }
                        .joined(separator: ", ")
                    copied = true
                }
                .buttonStyle(.borderedProminent)
            }
            .sensoryFeedback(.success, trigger: copied)
        }
        .padding(20)
        .frame(width: 340)
        .onChange(of: [panel, gap, frost, focus, wiggle, lean, cardPadding, rowSpacing, shimmer, rim]) { copied = false }
    }

    private func sliderRow(_ tweak: Tweak) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(tweak.label)
                Spacer()
                Text(tweak.formatted(binding(tweak).wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(value: binding(tweak), in: tweak.range, step: tweak.step) {
                Text(tweak.label)
            } minimumValueLabel: {
                Text(tweak.ends.0).font(.caption2).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(tweak.ends.1).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func binding(_ tweak: Tweak) -> Binding<Double> {
        switch tweak {
        case .panel: $panel
        case .gap: $gap
        case .frost: $frost
        case .focus: $focus
        case .wiggle: $wiggle
        case .lean: $lean
        case .cardPadding: $cardPadding
        case .rowSpacing: $rowSpacing
        case .shimmer: $shimmer
        case .rim: $rim
        }
    }
}
