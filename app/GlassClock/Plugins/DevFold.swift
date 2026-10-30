import SwiftUI

// DEV FOLD · a small shared helper for the plugins' "dev tools" (the dashboard, crew rundown, plugin desk and so on).
// Not a plugin: just a tidy disclosure row. Collapsed until you open it, and each one remembers its own state on the
// device ("plug.devfold.<id>"). Fades instead of sliding when motion is simpler. Gets a VoiceOver label and hint.
// Used as: `DevFold(id: "dash.needs", title: "Needs you") { ...rows... }`.

struct DevFold<Content: View>: View {
    let title: String
    let summary: String?
    let content: Content
    @AppStorage private var open: Bool

    init(id: String, title: String, summary: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.summary = summary
        self.content = content()
        _open = AppStorage(wrappedValue: false, "plug.devfold.\(id)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
            Button {
                if PipHost.shared.simpler {
                    open.toggle()
                } else {
                    withAnimation(.snappy) { open.toggle() }
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(open ? "Hide \(title)" : "Show \(title)").font(.system(size: 13.5, weight: .semibold))
                        if let summary, !open {
                            Text(summary).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(open ? "Open" : "Closed")
            .accessibilityHint(open ? "Closes it." : "Opens it.")
            if open {
                content.transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
