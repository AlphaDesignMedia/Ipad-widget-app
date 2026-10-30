import SwiftUI

// The Joy Slider: one master control for how lively the playground is. Every other plugin
// reads `JoyLevel.effective` and scales itself, so turning joy down calms everything at once.
//
// How this works (Swift idea: enums with properties): each level is a case, and the numbers
// other plugins need (how often, how much) are worked out from the case, in one place.

enum JoyLevel: Int, CaseIterable, Identifiable, Comparable {
    case still, calm, cosy, playful, giddy, unhinged

    static let plugin = PlaygroundPlugin(
        id: "joy", name: "Joy Slider", icon: "🎚️", shelf: .trial,
        blurb: "One slider for how lively everything is, from a still clock to total chaos.")

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .still: "Still"
        case .calm: "Calm"
        case .cosy: "Cosy"
        case .playful: "Playful"
        case .giddy: "Giddy"
        case .unhinged: "Unhinged"
        }
    }
    var emoji: String {
        switch self {
        case .still: "🧊"
        case .calm: "🍵"
        case .cosy: "🧸"
        case .playful: "🎈"
        case .giddy: "🎉"
        case .unhinged: "🌪️"
        }
    }
    var blurb: String {
        switch self {
        case .still: "A beautiful clock. Pip sleeps."
        case .calm: "Blinks, glances, the odd hum."
        case .cosy: "Small idle acts. Reacts to taps."
        case .playful: "Idle scenes, more lines, surprises."
        case .giddy: "Fish, juggling, wacky animations."
        case .unhinged: "Everything at once. You asked for this."
        }
    }

    /// How quickly idle life moves through its stages. 1 is normal; higher is sooner.
    var idlePace: Double {
        switch self {
        case .still: 0
        case .calm: 0.6
        case .cosy: 1
        case .playful: 1.5
        case .giddy: 2.5
        case .unhinged: 6
        }
    }
    /// Seconds between idle acts once Pip is bored.
    var actGap: ClosedRange<Double> {
        switch self {
        case .still: 3600...3600
        case .calm: 40...90
        case .cosy: 25...60
        case .playful: 15...35
        case .giddy: 8...20
        case .unhinged: 3...8
        }
    }
    var allowsSurprises: Bool { self >= .playful }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// Calm is the default: the app should feel great before anyone touches the slider.
    static let defaultLevel: JoyLevel = .calm
    /// Reduce Motion never goes above Cosy.
    static let reduceMotionCap: JoyLevel = .cosy

    private static let key = Playground.keyPrefix + "joy"

    @MainActor static var saved: JoyLevel {
        get {
            guard UserDefaults.standard.object(forKey: key) != nil else { return defaultLevel }
            return JoyLevel(rawValue: UserDefaults.standard.integer(forKey: key)) ?? defaultLevel
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            Playground.shared.emit(.joyChanged(newValue))
        }
    }

    /// The level plugins should actually use: the saved one, capped for Reduce Motion, and
    /// Calm whenever the Joy Slider plugin is switched off.
    @MainActor static func effective(reduceMotion: Bool) -> JoyLevel {
        let level = Playground.shared.isOn(plugin.id) ? saved : defaultLevel
        return reduceMotion ? min(level, reduceMotionCap) : level
    }
}

/// The slider itself: a big emoji, the level's name and what it means.
struct JoySliderView: View {
    @State private var level = JoyLevel.saved
    @State private var wobble = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Text(level.emoji)
                .font(.system(size: 56))
                .rotationEffect(.degrees(wobble ? 6 : -6))
                .animation(wobbles ? .easeInOut(duration: 0.12).repeatForever() : .default, value: wobble)
                .accessibilityHidden(true)
            Text(level.name).font(.title2.bold())
            Text(level.blurb).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Slider(
                value: Binding(
                    get: { Double(level.rawValue) },
                    set: { level = JoyLevel(rawValue: Int($0.rounded())) ?? .calm }),
                in: 0...Double(JoyLevel.unhinged.rawValue), step: 1
            ) {
                Text("Joy")
            } minimumValueLabel: {
                Text("🧊").accessibilityHidden(true)
            } maximumValueLabel: {
                Text("🌪️").accessibilityHidden(true)
            }
            .accessibilityValue("\(level.name). \(level.blurb)")
            if reduceMotion && level > JoyLevel.reduceMotionCap {
                Text("Reduce Motion is on, so it stays at Cosy.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        .onChange(of: level) { _, new in
            JoyLevel.saved = new
            wobble = wobbles
        }
        .onAppear { wobble = wobbles }
    }

    /// At Unhinged the slider can't keep still either.
    private var wobbles: Bool { level == .unhinged && !reduceMotion }
}

#Preview { JoySliderView() }
