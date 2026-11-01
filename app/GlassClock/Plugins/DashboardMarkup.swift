import SwiftUI
import UIKit

// DASHBOARD MARK UP · part of the Dashboard plugin (Jules, 1 Nov). Aaron: "all the stuff we've done for drawing in the
// app, we can put that in the dashboard to send it off", step 1 of the plan in nat/dashboard-studio-plan.md.
// Tap Mark up (bottom right of the Dashboard tab) and draw straight on the dashboard with the Pencil or a finger:
// circle it, arrow it, cross it out. Snap takes a picture of the tab with your marks, then you add a line, pick who
// it's for (Master chat, Rob, Jules, Chappie) and share or copy it. Nothing leaves the iPad without your tap.
// While Mark up is on, the dashboard holds still (no taps or scrolling underneath) and Sketch steps aside.
// Done puts the pen away and clears the marks (a snap keeps them). No network, no timers. Pip says nothing here.
// Simpler motion: the tools fade in and out.

extension Dashboard {

    // MARK: Data

    /// Who a snap is for, and how its note starts, the same way the other pastes are labelled.
    enum SendTo: String, CaseIterable, Identifiable {
        case master, rob, jules, chappie
        var id: Self { self }

        var label: String {
            switch self {
            case .master: "Master chat"
            case .rob: "Rob"
            case .jules: "Jules"
            case .chappie: "Chappie"
            }
        }

        var heading: String {
            switch self {
            case .master: "FOR DASHBOARD · Aaron's note from the iPad"
            case .rob: "🖥 FOR ROB · from Aaron's iPad"
            case .jules: "FOR JULES · from Aaron's iPad"
            case .chappie: "📠 FAX FOR CHAPPIE · from Aaron's iPad"
            }
        }
    }

    /// Ink colours: red to point at things, blue for notes, and the text colour.
    static let markColours: [Color] = [Color(red: 1, green: 0.23, blue: 0.19), Color(red: 0.04, green: 0.52, blue: 1), .primary]
    static let markColourNames = ["Red", "Blue", "Ink"]
    static let markWidth: CGFloat = 4

    struct Mark {
        var points: [CGPoint]
        var colour: Int
    }

    struct Snap: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    /// The note as it's pasted: the heading, your line, and which board it was.
    @MainActor static func snapNote(_ to: SendTo, _ text: String) -> String {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let board = Dashboard.date(Feed.shared.data.syncedAt).map { "(Dashboard from \($0). Picture attached.)" } ?? "(Picture attached.)"
        return [to.heading, line.isEmpty ? nil : line, board].compactMap { $0 }.joined(separator: "\n")
    }

    // MARK: Logic

    /// A picture of what's on screen inside `rect` (window points; nil for the whole screen), Liquid Glass, Pip and
    /// Sketch's ink included.
    @MainActor static func capture(_ rect: CGRect?) -> UIImage? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let window else { return nil }
        let rect = rect ?? window.bounds
        guard rect.width > 1, rect.height > 1 else { return nil }
        return UIGraphicsImageRenderer(bounds: rect).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    // MARK: Views

    /// The Mark up button, the drawing layer and the snap sheet, over the whole Dashboard tab.
    struct MarkUp: ViewModifier {
        let host: PipHost
        @State private var on = false
        @State private var marks: [Mark] = []
        @State private var live: Mark?
        @State private var colour = 0
        @State private var hidingTools = false
        @State private var frame = CGRect.zero
        @State private var snap: Snap?

        func body(content: Content) -> some View {
            content
                .allowsHitTesting(!on)
                .overlay { if on { ink } }
                .overlay(alignment: .bottomTrailing) {
                    if !hidingTools {
                        tools.padding(16).transition(.opacity)
                    }
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
                .sheet(item: $snap) { SnapSheet(snap: $0) }
                .onDisappear { stop() }
        }

        private var ink: some View {
            Canvas { ctx, _ in
                for m in marks + (live.map { [$0] } ?? []) {
                    var path = Path()
                    path.addLines(m.points)
                    if m.points.count == 1, let p = m.points.first {
                        path = Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
                        ctx.fill(path, with: .color(Dashboard.markColours[m.colour]))
                    } else {
                        ctx.stroke(path, with: .color(Dashboard.markColours[m.colour]),
                                   style: StrokeStyle(lineWidth: Dashboard.markWidth, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if live == nil { live = Mark(points: [v.location], colour: colour) } else { live?.points.append(v.location) }
                    }
                    .onEnded { _ in
                        if let live { marks.append(live) }
                        live = nil
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Drawing area")
            .accessibilityHint("Draw on the dashboard with your Pencil or finger. Snap is in the tools, bottom right.")
        }

        @ViewBuilder private var tools: some View {
            if on {
                HStack(spacing: 14) {
                    ForEach(Dashboard.markColours.indices, id: \.self) { i in
                        Button { colour = i } label: {
                            Circle().fill(Dashboard.markColours[i]).frame(width: 22, height: 22)
                                .overlay { Circle().strokeBorder(.primary.opacity(colour == i ? 0.9 : 0), lineWidth: 2).padding(-4) }
                                .frame(width: 32, height: 32)
                                .contentShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Dashboard.markColourNames[i])
                        .accessibilityAddTraits(colour == i ? .isSelected : [])
                    }
                    Divider().frame(height: 22)
                    toolButton("Undo", "arrow.uturn.backward") { _ = marks.popLast() }
                        .disabled(marks.isEmpty)
                    toolButton("Clear", "trash") { marks = [] }
                        .disabled(marks.isEmpty)
                    Button(action: takeSnap) {
                        Label("Snap", systemImage: "camera.viewfinder").font(.body.weight(.semibold))
                    }
                    .buttonStyle(PluginCardButton(on: true))
                    .fixedSize()
                    .accessibilityHint("Takes a picture of the dashboard with your marks, ready to send.")
                    toolButton("Done", "checkmark") { stop() }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .appGlass(.capsule)
            } else {
                Button { start() } label: {
                    Label("Mark up", systemImage: "pencil.tip.crop.circle").font(.body.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .appGlass(.capsule, interactive: true)
                .accessibilityHint("Draw on the dashboard with your Pencil or finger, then snap it to send to the team.")
            }
        }

        private func toolButton(_ name: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: icon).font(.body.weight(.semibold)).frame(width: 32, height: 32).contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
        }

        private func start() {
            Sketch.shared?.standsAside = true
            withAnimation(host.simpler ? nil : .easeOut(duration: 0.2)) { on = true }
        }

        private func stop() {
            Sketch.shared?.standsAside = false
            withAnimation(host.simpler ? nil : .easeOut(duration: 0.2)) { on = false }
            marks = []
            live = nil
        }

        /// Hides the tools for a moment so they're not in the picture, then takes it.
        private func takeSnap() {
            hidingTools = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                let image = Dashboard.capture(frame)
                hidingTools = false
                if let image { snap = Snap(image: image) }
            }
        }
    }

    /// The picture, a line from you, who it's for, then share or copy.
    struct SnapSheet: View {
        let snap: Snap
        /// The Shot list fills in the note and who asked.
        var startNote = ""
        var sendTo: SendTo? = nil
        @State private var note = ""
        @AppStorage("plug.dashboard.snapTo") private var to = SendTo.master.rawValue
        @State private var copied: String?
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            let who = SendTo(rawValue: to) ?? .master
            let text = Dashboard.snapNote(who, note)
            let picture = Image(uiImage: snap.image)
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        picture.resizable().scaledToFit()
                            .clipShape(.rect(cornerRadius: 16))
                            .frame(maxHeight: 380)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Your snap of the dashboard")
                        TextField("What should they look at?", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                        Picker("For", selection: $to) {
                            ForEach(SendTo.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        ShareLink(item: picture, subject: Text(who.heading), message: Text(text),
                                  preview: SharePreview("Dashboard snap", image: picture)) {
                            Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PluginCardButton(on: true))
                        .accessibilityHint("AirDrop, Messages, Files and more. The note goes with the picture where the app allows.")
                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.image = snap.image
                                copied = "Picture copied."
                            } label: { Label("Copy picture", systemImage: "photo").frame(maxWidth: .infinity) }
                            .buttonStyle(PluginCardButton())
                            Button {
                                UIPasteboard.general.string = text
                                copied = "Note copied."
                            } label: { Label("Copy note", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }
                            .buttonStyle(PluginCardButton())
                        }
                        if let copied {
                            Text(copied).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(text).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .accessibilityLabel("The note as it'll be pasted: \(text)")
                    }
                    .padding(20)
                }
                .navigationTitle("Send a snap")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .presentationDetents([.large])
            .onAppear {
                if note.isEmpty { note = startNote }
                if let sendTo { to = sendTo.rawValue }
            }
        }
    }
}
