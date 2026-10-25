import SwiftUI
import UIKit

/// Live design settings for tuning how the app looks and feels on the iPad itself (owner idea,
/// 2026-10-21: a faster way to design together than describing changes back and forth). Each
/// is saved, and Copy Values puts them all on the clipboard to send over, to become the defaults.
enum Tweak: String, CaseIterable, Identifiable {
    case panel, panelEdge, gap, cardPadding, rowSpacing, titleBar, footer, bubble, chip
    case frost, focus, shimmer, rim, wiggle, lean

    /// Spacing first, then the effects.
    var isSpacing: Bool {
        [.panel, .panelEdge, .gap, .cardPadding, .rowSpacing, .titleBar, .footer, .bubble, .chip].contains(self)
    }

    var id: Self { self }
    var key: String { "tweak.\(rawValue)" }

    var label: String {
        switch self {
        case .panel: "Panel corners"
        case .gap: "Gaps"
        case .cardPadding: "Card padding"
        case .rowSpacing: "Row spacing"
        case .panelEdge: "Panel edge padding"
        case .titleBar: "Title bar height"
        case .footer: "Footer padding"
        case .bubble: "Bubble padding"
        case .chip: "Chip padding"
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
        // The owner's picks from Design Tweaks, 21 Oct 2026 (evening).
        case .panel: 42
        case .gap: 29
        case .cardPadding: 29
        case .rowSpacing: 14
        // Breathing-room pass, 21 Oct 2026 (see DESIGN_SYSTEM.md, Spacing).
        case .panelEdge: 29
        case .titleBar: 23
        case .footer: 18
        case .bubble: 13
        case .chip: 16
        case .shimmer: 1.0
        case .rim: 0.9
        case .frost: 1.75
        case .focus: 2.0
        case .wiggle: 1.2
        case .lean: 1.2
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .panel: 12...56
        case .gap: 6...32
        case .cardPadding: 12...36
        case .rowSpacing: 4...20
        case .panelEdge: 8...36
        case .titleBar: 8...30
        case .footer: 6...24
        case .bubble: 4...20
        case .chip: 6...20
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
        case .gap, .cardPadding, .rowSpacing, .panelEdge, .titleBar, .footer, .bubble, .chip: ("Tight", "Airy")
        case .shimmer, .rim: ("None", "Bright")
        case .frost: ("Clear", "Frosted")
        case .focus, .lean: ("None", "Strong")
        case .wiggle: ("Still", "Lively")
        }
    }

    func formatted(_ value: Double) -> String {
        isSpacing ? "\(Int(value.rounded())) pt" : String(format: "%.2f", value)
    }

    /// Spacing values for the named presets in Design Tweaks. Comfortable is the standard.
    func preset(_ preset: SpacingPreset) -> Double {
        let scale: Double = switch preset {
        case .compact: 0.72
        case .comfortable: 1
        case .airy: 1.3
        }
        return min(range.upperBound, max(range.lowerBound, (standard * scale).rounded()))
    }

    /// The saved value, or the standard one.
    var value: Double {
        UserDefaults.standard.object(forKey: key) as? Double ?? standard
    }
}

/// Three ready-made sets of spacing, to start from before fine-tuning with the sliders.
enum SpacingPreset: String, CaseIterable, Identifiable {
    case compact = "Compact", comfortable = "Comfortable", airy = "Airy"
    var id: Self { self }
}

/// The tweaks as sliders, on a small floating panel so the app stays in view while they change.
/// How a panel looks while it's carried by its bar (owner idea, 2026-10-21: small and easy
/// to move, springing back to full size where it's dropped).
enum CarryStyle: String, CaseIterable, Identifiable {
    /// Stays full size, lifted a little.
    case lift
    /// Shrinks to a small card with the panel's icon and title.
    case card
    /// Shrinks to a round puck with just the icon.
    case puck

    static let key = "tweak.carry"
    var id: Self { self }
    var label: String {
        switch self {
        case .lift: "Full size"
        case .card: "Title card"
        case .puck: "Puck"
        }
    }
}

/// The widget's controls as one bubble at a time, swiped sideways like pages with a dot for
/// each (owner idea, 2026-10-21), instead of a stack of three. Off unless switched on.
enum OneRowControls {
    static let key = "tweak.oneRow"
}

struct DesignTweaksPanel: View {
    @AppStorage(CarryStyle.key) private var carry = CarryStyle.lift
    @AppStorage(OneRowControls.key) private var oneRow = false
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
    @AppStorage(Tweak.panelEdge.key) private var panelEdge = Tweak.panelEdge.standard
    @AppStorage(Tweak.titleBar.key) private var titleBar = Tweak.titleBar.standard
    @AppStorage(Tweak.footer.key) private var footer = Tweak.footer.standard
    @AppStorage(Tweak.bubble.key) private var bubble = Tweak.bubble.standard
    @AppStorage(Tweak.chip.key) private var chip = Tweak.chip.standard
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
                        if spacing { spacingPresets }
                        ForEach(Tweak.allCases.filter { $0.isSpacing == spacing }) { tweak in
                            sliderRow(tweak)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Carrying a panel").font(.subheadline)
                        GlassPicker("Carrying a panel", selection: $carry, options: CarryStyle.allCases) { $0.label }
                    }
                    Toggle(isOn: $oneRow) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Widget controls in one row").font(.subheadline)
                            Text("Swipe sideways, or tap a dot, to move between style, size and backdrop.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxHeight: 460)
            HStack {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    withAnimation(.smooth) {
                        for tweak in Tweak.allCases { binding(tweak).wrappedValue = tweak.standard }
                        carry = .card
                        oneRow = false
                    }
                }
                Spacer()
                Button(copied ? "Copied" : "Copy Values", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = "Glass Clock design tweaks: " + Tweak.allCases
                        .map { "\($0.label) \($0.formatted(binding($0).wrappedValue))" }
                        .joined(separator: ", ") + ", Carrying a panel \(carry.label), One row \(oneRow ? "on" : "off")"
                    copied = true
                }
                .prominentButton()
            }
            .sensoryFeedback(.success, trigger: copied)
        }
        .padding(20)
        .frame(width: 340)
        .onChange(of: [panel, gap, frost, focus, wiggle, lean, cardPadding, rowSpacing, shimmer, rim,
                       panelEdge, titleBar, footer, bubble, chip]) { copied = false }
    }

    /// Compact, Comfortable and Airy: set every spacing slider at once.
    private var spacingPresets: some View {
        HStack(spacing: 8) {
            ForEach(SpacingPreset.allCases) { preset in
                Button(preset.rawValue) {
                    withAnimation(.smooth) {
                        for tweak in Tweak.allCases where tweak.isSpacing && tweak != .panel {
                            binding(tweak).wrappedValue = tweak.preset(preset)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
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
        case .panelEdge: $panelEdge
        case .titleBar: $titleBar
        case .footer: $footer
        case .bubble: $bubble
        case .chip: $chip
        }
    }
}
