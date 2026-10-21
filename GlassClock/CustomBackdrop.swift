import SwiftUI

/// The marks drawn over a backdrop the person makes themselves.
enum BackdropPattern: String, Codable, CaseIterable, Identifiable {
    case none, lines, waves, dots, rings
    var id: Self { self }

    var label: String { rawValue.capitalized }

    /// The drawn backdrop with the same marks, for `PatternBackdrop`.
    var drawn: PreviewBackdrop? {
        switch self {
        case .none: nil
        case .lines: .lines
        case .waves: .waves
        case .dots: .dots
        case .rings: .rings
        }
    }
}

/// A backdrop the person makes: two or three colours and a pattern (owner idea, 2026-10-21).
/// Only the app's backdrop, not the widget. Like the drawn patterns, it's washed pale in Light
/// and deep in Dark, so the bubbles over it stay readable.
struct CustomBackdrop: Codable, Equatable {
    static let key = "customBackdrop"

    var colours: [String] = ["#5B6FDB", "#C76FA0", "#F2A65A"]
    var pattern = BackdropPattern.waves

    var colors: [Color] { colours.map { Color(hex: $0) } }

    static func decode(_ raw: String) -> CustomBackdrop? {
        raw.data(using: .utf8).flatMap { try? JSONDecoder().decode(CustomBackdrop.self, from: $0) }
    }

    var encoded: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

extension Color {
    /// A colour from "#RRGGBB"; grey if it can't be read.
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x808080
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    /// The colour as "#RRGGBB", for saving.
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}

/// Make Your Own: pick two or three colours and a pattern, with a preview in Light and Dark.
/// Changes show on the backdrop straight away.
struct CustomBackdropEditor: View {
    @Binding var backdrop: CustomBackdrop
    /// The app colour, so Done reads clearly (the Glass theme's own tint is white).
    var tint: Color = .blue
    var done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Make Your Own").font(.headline)
                Spacer()
                Button("Done", action: done)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(tint)
            }

            // A swatch in Light and one in Dark, as the backdrop follows the Home Screen style.
            HStack(spacing: 10) {
                ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                    PatternBackdrop(kind: .custom, custom: backdrop)
                        .environment(\.colorScheme, scheme)
                        .frame(height: 70)
                        .clipShape(.rect(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text(scheme == .light ? "Light" : "Dark")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(scheme == .light ? .black.opacity(0.7) : .white.opacity(0.85))
                                .padding(8)
                        }
                }
            }
            .accessibilityHidden(true)

            Text("Colours").font(.subheadline.weight(.semibold))
            HStack(spacing: 14) {
                ForEach(backdrop.colours.indices, id: \.self) { index in
                    ColorPicker("Colour \(index + 1)", selection: colour(index), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 44, height: 44)
                }
                if backdrop.colours.count < 3 {
                    Button("Add Colour", systemImage: "plus") {
                        backdrop.colours.append(backdrop.colours.last ?? "#808080")
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.primary)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                } else {
                    Button("Remove Colour", systemImage: "minus") {
                        backdrop.colours.removeLast()
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.primary)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }

            Text("Pattern").font(.subheadline.weight(.semibold))
            Picker("Pattern", selection: $backdrop.pattern) {
                ForEach(BackdropPattern.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .frame(width: 360)
    }

    private func colour(_ index: Int) -> Binding<Color> {
        Binding {
            backdrop.colours.indices.contains(index) ? Color(hex: backdrop.colours[index]) : .gray
        } set: { new in
            if backdrop.colours.indices.contains(index) { backdrop.colours[index] = new.hex }
        }
    }
}
