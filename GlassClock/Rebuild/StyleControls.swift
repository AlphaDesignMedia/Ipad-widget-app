import SwiftUI

// The rows of each settings card (PLAN.md, rebuild step 3), the same controls as the old app
// with one version of each. Each card is its own small view, so a change to one setting
// redraws the cards and the widget, never the whole screen.

/// What the clock shows: digital or analog, the time format and the date.
struct LayoutRows: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        GlassPicker("Clock", selection: $model.style.face, options: ClockFaceKind.allCases) { $0.label }
        // The analog face has no digits, so the digit settings step aside for it.
        if model.style.face == .digital {
            PickerRow(title: "Time format", selection: $model.style.timeFormat) {
                ForEach(TimeFormat.allCases) { Text($0.label).tag($0) }
            }
            PickerRow(title: "AM/PM", selection: $model.style.ampm) {
                ForEach(AMPMPlacement.allCases) { Text($0.label).tag($0) }
            }
            .disabled(!model.style.uses12Hour)
        }
        Toggle("Show date", isOn: $model.style.showDate)
        if model.style.face == .digital {
            if model.style.showDate {
                Toggle("Date above the time", isOn: $model.style.dateAbove)
            }
            SliderRow(title: "Gap", value: $model.style.detailGap, range: 0.3...2.5, low: "Close", high: "Far")
            Toggle("Stretch to fill square widgets", isOn: $model.style.fillsCard)
        }
    }
}

/// The time's typeface, then the AM/PM and date line's.
struct FontRows: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let font = model.style.font
        GroupLabel("Time")
        PickerRow(title: "Font", selection: $model.style.font) {
            ForEach(ClockFont.allCases) { Text($0.label).tag($0) }
        }
        SliderRow(title: "Weight", value: $model.style.fontWeight, range: 0...1, low: "Thin", high: "Heavy")
        if font.hasWidth {
            SliderRow(title: "Width", value: $model.style.fontWidth, range: 0...1, low: "Narrow", high: "Wide")
        }
        if font.hasRoundness {
            SliderRow(title: "Roundness", value: $model.style.roundness, range: 0...1, low: "Sharp", high: "Round")
        }
        SliderRow(title: "Height", value: $model.style.height, range: ClockStyle.heightRange, low: "Normal", high: "Tall")
        SliderRow(title: "Spacing", value: $model.style.spacing, range: ClockStyle.spacingRange, low: "Tight", high: "Loose")
        SliderRow(title: "Corners", value: $model.style.softness, range: 0...1, low: "Sharp", high: "Soft")
        Toggle("Bolder in small widgets", isOn: $model.style.adaptsToSize)

        GroupLabel("AM/PM and date")
        PickerRow(title: "Font", selection: $model.style.detailFont) {
            ForEach(DetailFont.allCases) { option in
                Text(option == .paired ? "Matched: \(font.pairing.label)" : option.label).tag(option)
            }
        }
        SliderRow(title: "Size", value: $model.style.detailSize, range: 0.7...1.6, low: "Small", high: "Large")
        SliderRow(title: "Letter spacing", value: $model.style.detailTracking, range: -0.06...0.25, low: "Tight", high: "Wide")
    }
}

/// The colour of the time: glass, a solid colour or a gradient.
struct ColourRows: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        GlassPicker("Style", selection: $model.style.textFill, options: TextFill.allCases) { $0.label }
        SwatchRow(selection: $model.style.color)
        if model.style.textFill == .gradient {
            VStack(alignment: .leading, spacing: Theme.Space.small) {
                Text("Fades to")
                SwatchRow(selection: $model.style.gradientColor)
            }
        }
        SliderRow(title: "Transparency", value: $model.style.textOpacity, range: ClockStyle.textOpacityRange,
                  low: "Faint", high: "Solid")
    }
}

/// Inner colour, glow and shadow. Each shows its controls only when it's switched on.
struct EffectRows: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Toggle("Inner colour", isOn: Binding(
            get: { model.style.innerColor != nil },
            set: { model.style.innerColor = $0 ? (model.style.innerColor ?? .orange) : nil }
        ))
        if model.style.innerColor != nil {
            SwatchRow(selection: Binding(
                get: { model.style.innerColor ?? .orange },
                set: { model.style.innerColor = $0 }
            ), includesAutomatic: false)
            SliderRow(title: "Strength", value: $model.style.innerStrength, range: 0.1...1, low: "Subtle", high: "Strong")
        }

        Toggle("Glow", isOn: $model.style.glow)
        if model.style.glow {
            SwatchRow(selection: $model.style.glowColor)
            SliderRow(title: "Size", value: $model.style.glowSize, range: 0...1, low: "Tight", high: "Wide")
            SliderRow(title: "Strength", value: $model.style.glowStrength, range: 0.1...1, low: "Soft", high: "Strong")
        }

        Toggle("Shadow", isOn: $model.style.shadow)
        if model.style.shadow {
            SwatchRow(selection: $model.style.shadowColor)
            SliderRow(title: "Direction", value: $model.style.shadowAngle, range: ClockStyle.shadowAngleRange,
                      low: "Right", high: "Left")
            SliderRow(title: "Distance", value: $model.style.shadowDistance, range: 0...1, low: "Close", high: "Far")
            SliderRow(title: "Softness", value: $model.style.shadowSize, range: 0...1, low: "Crisp", high: "Soft")
            SliderRow(title: "Strength", value: $model.style.shadowStrength, range: ClockStyle.shadowStrengthRange,
                      low: "Light", high: "Dark")
        }
    }
}

/// The widget's card behind the clock.
struct CardRows: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        GlassPicker("Style", selection: $model.style.background, options: CardBackground.allCases) { $0.label }
        SwatchRow(selection: $model.style.backgroundColor)
        SliderRow(title: "Transparency", value: $model.style.cardOpacity, range: ClockStyle.cardOpacityRange,
                  low: "Clear", high: "Solid")
    }
}

/// On Clear and Tinted Home Screens, which parts keep their own colours.
struct HomeScreenRows: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Toggle("Keep time colours", isOn: $model.style.keepsTimeColours)
        Toggle("Keep AM/PM and date colours", isOn: $model.style.keepsDetailColours)
        Toggle("Keep card colours", isOn: $model.style.keepsCardColours)
    }
}

/// Plain versions of the app's effects, for anyone who finds them too much.
struct AccessibilityRows: View {
    @AppStorage("simpleMotion") private var simpleMotion = false
    @AppStorage("reduceGlass") private var reducesGlass = false

    var body: some View {
        Toggle("Simpler effects", isOn: $simpleMotion)
        Toggle("Reduce glass", isOn: $reducesGlass)
    }
}
