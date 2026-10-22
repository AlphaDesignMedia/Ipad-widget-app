import SwiftUI

/// The Presets card: roll the dice, your own saved styles, the starter styles, and locks that
/// keep parts of the style when a preset or Lucky is used. Saved presets and locks use the
/// old app's keys, so both apps share them.
struct PresetRows: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    /// Clear and Tinted starts locked, since it's easy to undo by accident (owner, 21 Oct).
    @AppStorage("lockedParts") private var lockedPartList = StylePart.homeScreens.rawValue
    @State private var saved = StyleLibrary.loadPresets()
    /// The saved preset being named: nil for a new one. Shown when `naming` is true.
    @State private var renaming: Int?
    @State private var name = ""
    @State private var naming = false

    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }
    private var locked: Set<StylePart> {
        Set(lockedPartList.split(separator: ",").compactMap { StylePart(rawValue: String($0)) })
    }

    var body: some View {
        // An icon and words in each button, rather than a Label, which measured wrongly in the
        // wrapping layout and lost its words.
        VStack(alignment: .leading, spacing: Theme.Space.small) {
            GroupLabel("Surprise me")
            FlowLayout(spacing: 10) {
                Button { roll(Set(StylePart.allCases)) } label: {
                    HStack(spacing: 6) { Image(systemName: "dice"); Text("I'm Feeling Lucky") }
                }
                .prominentButton()
                .fixedSize()
                chip("Lucky Colours", icon: "paintpalette") { roll(StylePart.colourParts) }
                chip("Lucky Style", icon: "textformat") { roll(StylePart.styleParts) }
            }
        }

        VStack(alignment: .leading, spacing: Theme.Space.small) {
            GroupLabel("Your styles")
            FlowLayout(spacing: 10) {
                ForEach(saved.indices, id: \.self) { savedButton($0) }
                if saved.count < StyleLibrary.maxCustomPresets {
                    chip("Save Current", icon: "plus") {
                        renaming = nil
                        name = "My Style \(saved.count + 1)"
                        naming = true
                    }
                }
            }
        }
        .alert(renaming == nil ? "Save Preset" : "Rename Preset", isPresented: $naming) {
            TextField("Name", text: $name)
            Button("Save", action: save)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(renaming == nil ? "Saves the current style so you can come back to it." : "")
        }

        VStack(alignment: .leading, spacing: Theme.Space.small) {
            GroupLabel("Starter styles")
            FlowLayout(spacing: 10) {
                ForEach(ClockStyle.presets, id: \.name) { preset in
                    Button(preset.name) { use(preset.style) }
                        .readableChip()
                }
            }
        }

        VStack(alignment: .leading, spacing: Theme.Space.small) {
            GroupLabel("Locks: keep these when using styles or Lucky")
            FlowLayout(spacing: Theme.Space.small) {
                ForEach(StylePart.allCases) { lockChip($0) }
            }
        }
    }

    private func chip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(title) }
        }
        .readableChip()
        .fixedSize()
    }

    private func savedButton(_ index: Int) -> some View {
        chip(saved[index].name, icon: "star.fill") { use(saved[index].style) }
            .contextMenu {
                Button("Update to Current Style", systemImage: "arrow.triangle.2.circlepath") {
                    saved[index].style = model.style
                    StyleLibrary.savePresets(saved)
                }
                Button("Rename…", systemImage: "pencil") {
                    renaming = index
                    name = saved[index].name
                    naming = true
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    saved.remove(at: index)
                    StyleLibrary.savePresets(saved)
                }
            }
            .accessibilityHint("Touch and hold to update, rename or delete it")
    }

    private func lockChip(_ part: StylePart) -> some View {
        let isLocked = locked.contains(part)
        return Button {
            var parts = locked
            if isLocked { parts.remove(part) } else { parts.insert(part) }
            withAnimation(reduceMotion ? nil : .snappy) {
                lockedPartList = parts.map(\.rawValue).sorted().joined(separator: ",")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .contentTransition(.symbolEffect(.replace))
                Text(part.label)
            }
            .font(.subheadline.weight(isLocked ? .semibold : .regular))
            .padding(.horizontal, Theme.Padding.chip)
            .padding(.vertical, Theme.Padding.chip / 2)
            .frame(minHeight: Theme.Size.tapTarget)
            .foregroundStyle(isLocked ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background(isLocked ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("\(part.label), \(isLocked ? "locked" : "unlocked")")
        .accessibilityHint("Locked parts keep their settings when you use a preset or Lucky")
    }

    /// Rolls the dice on `parts`, leaving locked parts alone.
    private func roll(_ parts: Set<StylePart>) {
        withAnimation(reduceMotion ? nil : .smooth) {
            model.style = model.style.taking(parts.subtracting(locked), from: .lucky(from: model.style))
        }
    }

    /// Uses a preset, leaving locked parts alone.
    private func use(_ preset: ClockStyle) {
        withAnimation(reduceMotion ? nil : .smooth) {
            model.style = model.style.taking(Set(StylePart.allCases).subtracting(locked), from: preset)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let renaming {
            if !trimmed.isEmpty { saved[renaming].name = trimmed }
        } else {
            saved.append(CustomPreset(name: trimmed.isEmpty ? "My Style" : trimmed, style: model.style))
        }
        StyleLibrary.savePresets(saved)
    }
}
