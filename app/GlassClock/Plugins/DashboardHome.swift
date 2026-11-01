import SwiftUI
import UIKit

// DASHBOARD HOME · part of the Dashboard plugin (Jules, 1 Nov). Aaron: "make them more like widgets… i need to lay it
// out like my home screen" and "i want them to work like widgets and be re sizable".
// The Dashboard tab's stage is now a Home Screen of widgets, one per dashboard part (Progress, Needs you, Up next,
// For Rob, Ideas). Each is the clock widget's own card (`ClockCard` + `ClockStyle.load()`), at the iPad's own widget
// sizes on `HomeGrid` (Small 170 pt, Medium 378.5 pt, gap 38.5 pt) using the app's `PreviewSize` spans, packed in
// order like the Home Screen packs them. Tap a widget → its full card glides in on the column. Hold a widget →
// Small · Medium · Large, like the Home Screen. Sizes are kept on this iPad. The groups pill and column are unchanged.
// No network, no timers, nothing moves on its own. Simpler motion: sizes swap with no animation. Pip says nothing here.
// Private: Aaron's mission control. It lives in the Sandbox and never moves to Glass Clock.

extension Dashboard {

    // MARK: Data

    /// One widget per dashboard part, in Home Screen order.
    enum HomeKind: String, CaseIterable, Identifiable {
        case progress, needs, forrob, upnext, ideas
        var id: Self { self }

        var title: String {
            switch self {
            case .progress: "Progress"
            case .needs: "Needs you"
            case .forrob: "For Rob"
            case .upnext: "Up next"
            case .ideas: "Ideas"
            }
        }

        var icon: String {
            switch self {
            case .progress: "location"
            case .needs: DashGroup.needs.icon
            case .forrob: DashGroup.forrob.icon
            case .upnext: DashGroup.upnext.icon
            case .ideas: DashGroup.ideas.icon
            }
        }

        /// The full card a tap jumps to.
        var group: DashGroup {
            switch self {
            case .progress: .glance
            case .needs: .needs
            case .forrob: .forrob
            case .upnext: .upnext
            case .ideas: .ideas
            }
        }

        /// The sizes it comes in. Progress needs room for its headline, so it has no Small.
        var sizes: [PreviewSize] {
            switch self {
            case .progress: [.medium, .large]
            default: [.small, .medium, .large]
            }
        }

        /// The starting layout: Progress · Needs you / For Rob · Up next (large) / Ideas.
        var standard: PreviewSize {
            switch self {
            case .progress: .medium
            case .upnext: .large
            default: .small
            }
        }
    }

    /// What a widget shows: a count (Small and up) and a few lines (Medium shows one, Large up to five).
    struct HomeGlance {
        var count: Int
        var countLabel: String
        var lines: [String]
        var mono = false
        var empty: String
    }

    static let sizesKey = "plug.dashboard.widgetSizes"

    /// Sizes are kept as "needs=small,upnext=large", so one setting holds the whole Home Screen.
    static func size(_ kind: HomeKind, in raw: String) -> PreviewSize {
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, parts[0] == kind.rawValue,
               let s = PreviewSize(rawValue: String(parts[1])), kind.sizes.contains(s) {
                return s
            }
        }
        return kind.standard
    }

    static func setting(_ size: PreviewSize, for kind: HomeKind, in raw: String) -> String {
        var map: [String: String] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=")
            if parts.count == 2 { map[String(parts[0])] = String(parts[1]) }
        }
        map[kind.rawValue] = size.rawValue
        return map.keys.sorted().map { "\($0)=\(map[$0] ?? "")" }.joined(separator: ",")
    }

    @MainActor static func glance(_ kind: HomeKind, _ data: DashboardData, _ host: PipHost) -> HomeGlance {
        switch kind {
        case .progress:
            return HomeGlance(count: 0, countLabel: "", lines: (data.upNext ?? []).map { clean($0.title) }, empty: "")
        case .needs:
            let waiting = (data.needsYou ?? []).filter { answer($0.q, host) == nil }
            return HomeGlance(count: waiting.count, countLabel: waiting.count == 1 ? "needs you" : "need you",
                              lines: waiting.map { clean($0.q) }, empty: "Nothing needs you")
        case .forrob:
            let todo = (data.outboxForRob ?? []).filter { $0.done != true }
            return HomeGlance(count: todo.count, countLabel: "for Rob", lines: todo.map { clean($0.command) },
                              mono: true, empty: "All done")
        case .upnext:
            let steps = data.upNext ?? []
            return HomeGlance(count: steps.count, countLabel: "up next", lines: steps.map { clean($0.title) },
                              empty: "Nothing queued")
        case .ideas:
            let ideas = data.ideas ?? []
            return HomeGlance(count: ideas.count, countLabel: ideas.count == 1 ? "idea" : "ideas",
                              lines: ideas.map { clean($0.title ?? "") }, empty: "Shelf empty")
        }
    }

    // MARK: Logic

    /// Lays widgets out like the Home Screen: on `HomeGrid`'s own slots, each in the first free spot, row by row,
    /// so Smalls tuck in beside a Large. Too narrow for a Medium? The whole grid scales down a little to fit two
    /// columns. The grid sits centred, as the Home Screen's does.
    struct HomeLayout: Layout {
        struct Span: LayoutValueKey {
            static let defaultValue = PreviewSize.small
        }

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let width = Self.usable(proposal.width)
            return CGSize(width: width, height: Self.pack(width: width, spans: subviews.map { $0[Span.self] }).height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let packed = Self.pack(width: bounds.width, spans: subviews.map { $0[Span.self] })
            for (i, view) in subviews.enumerated() where i < packed.frames.count {
                let f = packed.frames[i]
                view.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), anchor: .topLeading,
                           proposal: ProposedViewSize(f.size))
            }
        }

        private static func usable(_ width: CGFloat?) -> CGFloat {
            guard let width, width.isFinite, width > 0 else { return HomeGrid.slot * 2 + HomeGrid.gap }
            return width
        }

        static func pack(width: CGFloat, spans: [PreviewSize]) -> (frames: [CGRect], height: CGFloat) {
            guard !spans.isEmpty else { return ([], 0) }
            let medium = HomeGrid.slot * 2 + HomeGrid.gap
            // The 1 pt keeps the column count from landing a hair under two.
            let scale = min(1, max(0.3, (width - 1) / medium))
            let columns = HomeGrid(area: CGSize(width: width, height: 1), scale: scale).columns
            var taken = Set<Int>()
            var spots: [(column: Int, row: Int, span: (columns: Int, rows: Int))] = []
            var rows = 0
            for size in spans {
                let span = (columns: min(size.span.columns, columns), rows: size.span.rows)
                func fits(_ column: Int, _ row: Int) -> Bool {
                    for r in row..<(row + span.rows) {
                        for c in column..<(column + span.columns) where taken.contains(r * columns + c) { return false }
                    }
                    return true
                }
                var row = 0
                var spot: (Int, Int)?
                while spot == nil {
                    for column in 0...(columns - span.columns) where fits(column, row) {
                        spot = (column, row)
                        break
                    }
                    if spot == nil { row += 1 }
                }
                let (c0, r0) = spot ?? (0, 0)
                for r in r0..<(r0 + span.rows) {
                    for c in c0..<(c0 + span.columns) { taken.insert(r * columns + c) }
                }
                spots.append((c0, r0, span))
                rows = max(rows, r0 + span.rows)
            }
            let step = (HomeGrid.slot + HomeGrid.gap) * scale
            let gap = HomeGrid.gap * scale
            let height = CGFloat(rows) * step - gap
            let grid = HomeGrid(area: CGSize(width: width, height: height + 1), scale: scale)
            let frames = spots.map { grid.frame(column: $0.column, row: $0.row, span: $0.span).offsetBy(dx: 0, dy: -grid.origin.y) }
            return (frames, height)
        }
    }

    // MARK: Views

    /// The Home Screen of dashboard widgets. `onOpen` jumps the column to a widget's full card.
    struct HomeBoard: View {
        let host: PipHost
        let data: DashboardData
        /// Bumped when a question is answered, so counts redraw.
        let taps: Int
        let onOpen: (DashGroup) -> Void
        @AppStorage(Dashboard.sizesKey) private var sizesRaw = ""
        @State private var style = ClockStyle.load()
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let _ = taps
            let kinds = HomeKind.allCases.filter { $0 != .forrob || !(data.outboxForRob ?? []).isEmpty }
            HomeLayout {
                ForEach(kinds) { kind in
                    let size = Dashboard.size(kind, in: sizesRaw)
                    Button { onOpen(kind.group) } label: {
                        HomeWidget(kind: kind, size: size, data: data, host: host, style: style)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Picker("Size", selection: Binding(get: { size }, set: { resize(kind, to: $0) })) {
                            ForEach(kind.sizes, id: \.self) { s in
                                Label(s.rawValue, systemImage: icon(s)).tag(s)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    .accessibilityHint("Shows the full card. Hold to change its size.")
                    .accessibilityActions {
                        ForEach(kind.sizes.filter { $0 != size }, id: \.self) { s in
                            Button("Make it \(s.rawValue)") { resize(kind, to: s) }
                        }
                    }
                    .layoutValue(key: HomeLayout.Span.self, value: size)
                }
            }
            .onAppear { style = ClockStyle.load() }
        }

        private func resize(_ kind: HomeKind, to size: PreviewSize) {
            let raw = Dashboard.setting(size, for: kind, in: sizesRaw)
            if reduceMotion || host.simpler { sizesRaw = raw } else {
                withAnimation(.snappy) { sizesRaw = raw }
            }
        }

        private func icon(_ s: PreviewSize) -> String {
            switch s {
            case .small: "square"
            case .medium: "rectangle"
            default: "square.grid.2x2"
            }
        }
    }

    /// One widget on the clock widget's own card. Small: the count. Medium: the count and the top line.
    /// Large: the count and up to five lines. Progress shows the headline instead of a count.
    struct HomeWidget: View {
        let kind: HomeKind
        let size: PreviewSize
        let data: DashboardData
        let host: PipHost
        let style: ClockStyle

        var body: some View {
            let g = Dashboard.glance(kind, data, host)
            VStack(alignment: .leading, spacing: 8) {
                header
                if kind == .progress { progress(g) } else { counted(g) }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(style.color == .auto ? AnyShapeStyle(.primary) : AnyShapeStyle(style.color.color))
            .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28)))
            .contentShape(.rect(cornerRadius: 28))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label(g))
        }

        private var header: some View {
            HStack(spacing: 6) {
                Image(systemName: kind.icon).font(.system(size: 11, weight: .semibold))
                Text(kind.title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.2).lineLimit(1)
                Spacer(minLength: 4)
                if kind == .progress, let when = Dashboard.date(data.syncedAt) {
                    Text(when).font(.system(size: 11)).lineLimit(1)
                }
            }
            .foregroundStyle(.secondary)
        }

        @ViewBuilder private func counted(_ g: HomeGlance) -> some View {
            if size == .small { Spacer(minLength: 0) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(g.count)").font(.system(size: size == .small ? 46 : 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if size != .small { Text(g.count == 0 ? g.empty : g.countLabel).font(.system(size: 15)) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            if size == .small {
                Text(g.count == 0 ? g.empty : g.countLabel).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            } else {
                lines(g.lines, max: size == .medium ? 1 : 5, mono: g.mono)
                Spacer(minLength: 0)
            }
        }

        @ViewBuilder private func progress(_ g: HomeGlance) -> some View {
            if let headline = data.status?.headline {
                Text(size == .large ? Dashboard.clean(headline) : Dashboard.glance(headline))
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(size == .large ? 6 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if size == .large { lines(g.lines, max: 3, mono: false) }
            Spacer(minLength: 0)
            let waiting = Dashboard.glance(.needs, data, host).count
            HStack(spacing: 8) {
                Chip(icon: "questionmark.bubble", text: waiting == 0 ? "Nothing needs you" : "\(waiting) need\(waiting == 1 ? "s" : "") you",
                     lit: waiting > 0)
                if let due = data.reminders, !due.isEmpty {
                    Chip(icon: "bell", text: "\(due.count) reminder\(due.count == 1 ? "" : "s")", lit: false)
                }
            }
            .lineLimit(1)
        }

        private func lines(_ all: [String], max: Int, mono: Bool) -> some View {
            let shown = Array(all.prefix(max))
            return VStack(alignment: .leading, spacing: 6) {
                ForEach(shown.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle().frame(width: 5, height: 5).opacity(0.5)
                        Text(shown[i])
                            .font(mono ? .system(size: 12.5, design: .monospaced) : .system(size: 14))
                            .lineLimit(2)
                    }
                }
            }
        }

        private func label(_ g: HomeGlance) -> String {
            let name = "\(kind.title), \(size.rawValue) widget"
            if kind == .progress {
                return "\(name): \(data.status?.headline.map { Dashboard.glance($0) } ?? "no headline yet")"
            }
            let top = g.lines.first.map { ". \($0)" } ?? ""
            return "\(name): \(g.count == 0 ? g.empty : "\(g.count) \(g.countLabel)")\(top)"
        }
    }
}
