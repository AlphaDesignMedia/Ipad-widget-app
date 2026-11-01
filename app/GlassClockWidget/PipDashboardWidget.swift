import SwiftUI
import WidgetKit
import AppIntents

// PIP DASHBOARD · Home Screen widget (Jules, 1 Nov). Aaron: "the dashboard with real widgets and really good" and
// "lean into these widgets… my way of exploring new widgets and new widget apps".
// Your dashboard on the real Home Screen, in all four sizes, in your clock's glass and colour. Hold it → Edit Widget →
// Show: Overview (a bit of everything) or one part (Progress, Needs you, Up next, For Rob, Ideas), so several can sit
// side by side like the Dashboard tab. Tap → the app opens on the Dashboard tab.
// Data: the small copy the app saves (Shared/DashboardSnapshot.swift). The widget never goes online and keeps no
// timer: it redraws when the app saves a new copy or you open the app. No Pip in it, so Pip off changes nothing.
// Private: Aaron's mission control. It lives in the Sandbox and never moves to Glass Clock.

// MARK: Data

/// What one widget shows. Overview is the starting choice.
enum DashboardPart: String, AppEnum {
    case overview, progress, needs, upnext, forrob, ideas

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Show" }
    static var caseDisplayRepresentations: [DashboardPart: DisplayRepresentation] {
        [.overview: "Overview", .progress: "Progress", .needs: "Needs you",
         .upnext: "Up next", .forrob: "For Rob", .ideas: "Ideas"]
    }

    var title: String {
        switch self {
        case .overview, .progress: "Progress"
        case .needs: "Needs you"
        case .upnext: "Up next"
        case .forrob: "For Rob"
        case .ideas: "Ideas"
        }
    }

    /// The same icons as the Dashboard tab's groups.
    var icon: String {
        switch self {
        case .overview, .progress: "location"
        case .needs: "questionmark.bubble"
        case .upnext: "list.bullet"
        case .forrob: "terminal"
        case .ideas: "lightbulb"
        }
    }

    func lines(_ s: DashboardSnapshot) -> [String] {
        switch self {
        case .overview, .progress: s.upNext
        case .needs: s.needs
        case .upnext: s.upNext
        case .forrob: s.forRob
        case .ideas: s.ideas
        }
    }

    /// "3 need you", "1 idea".
    func countLabel(_ n: Int) -> String {
        switch self {
        case .overview, .progress, .upnext: "up next"
        case .needs: n == 1 ? "needs you" : "need you"
        case .forrob: "for Rob"
        case .ideas: n == 1 ? "idea" : "ideas"
        }
    }

    var empty: String {
        switch self {
        case .overview, .progress, .upnext: "Nothing queued"
        case .needs: "Nothing needs you"
        case .forrob: "All done"
        case .ideas: "Shelf empty"
        }
    }
}

struct DashboardWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Dashboard" }
    static var description: IntentDescription { "Pick what this widget shows." }

    @Parameter(title: "Show", default: .overview)
    var part: DashboardPart

    init() {}
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has saved its first copy.
    let snap: DashboardSnapshot?
    let part: DashboardPart
    let style: ClockStyle
}

// MARK: Logic

struct DashboardProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: .now, snap: .sample, part: .overview, style: ClockStyle())
    }

    func snapshot(for configuration: DashboardWidgetIntent, in context: Context) async -> DashboardEntry {
        // The gallery shows make-believe lines until the app has saved a real copy.
        DashboardEntry(date: .now, snap: DashboardSnapshot.load() ?? (context.isPreview ? .sample : nil),
                       part: configuration.part, style: .load())
    }

    /// One entry, kept until the app saves a new copy (it asks for a redraw then) or you open the app.
    func timeline(for configuration: DashboardWidgetIntent, in context: Context) async -> Timeline<DashboardEntry> {
        let entry = DashboardEntry(date: .now, snap: DashboardSnapshot.load(), part: configuration.part, style: .load())
        return Timeline(entries: [entry], policy: .never)
    }
}

// MARK: Views

struct PipDashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DashboardEntry

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(entry.style.color == .auto ? AnyShapeStyle(.primary) : AnyShapeStyle(entry.style.color.color))
            .containerBackground(for: .widget) {
                // Your clock's card. In the Clear and Tinted Home Screen looks the system draws its own glass instead.
                switch entry.style.background {
                case .glass: GlassCardBackground(tint: entry.style.cardTint, strength: entry.style.cardOpacity)
                case .solid: entry.style.solidFill.opacity(entry.style.cardOpacity)
                }
            }
            .widgetURL(DashboardSnapshot.link)
    }

    @ViewBuilder private var content: some View {
        if let s = entry.snap {
            if entry.part == .overview {
                switch family {
                case .systemSmall: part(.needs, s)
                case .systemMedium: overviewMedium(s)
                case .systemExtraLarge: overviewExtraLarge(s)
                default: overviewLarge(s)
                }
            } else {
                part(entry.part, s)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Head(icon: "location", title: "Dashboard")
                Spacer(minLength: 0)
                Text("Open the Dashboard tab once to fill this in.")
                    .font(.system(size: 15, weight: .semibold))
            }
        }
    }

    // Overview: a bit of everything, more with each size.

    private func overviewMedium(_ s: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Head(icon: "location", title: "Progress", trailing: s.boardTime)
            Headline(text: s.headline, lines: 2)
            Spacer(minLength: 0)
            if let next = s.upNext.first { NextRow(text: next) }
            Chips(s: s)
        }
    }

    private func overviewLarge(_ s: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Head(icon: "location", title: "Progress", trailing: s.boardTime)
            Headline(text: s.headline, lines: 3)
            Divider().opacity(0.5)
            PartSection(part: .needs, s: s, most: 3)
            PartSection(part: .upnext, s: s, most: 3)
            Spacer(minLength: 0)
            Chips(s: s)
        }
    }

    private func overviewExtraLarge(_ s: DashboardSnapshot) -> some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Head(icon: "location", title: "Progress", trailing: s.boardTime)
                Headline(text: s.headline, lines: 4)
                Divider().opacity(0.5)
                PartSection(part: .upnext, s: s, most: 5)
                Spacer(minLength: 0)
                Chips(s: s)
            }
            VStack(alignment: .leading, spacing: 12) {
                PartSection(part: .needs, s: s, most: 4)
                PartSection(part: .forrob, s: s, most: 3)
                PartSection(part: .ideas, s: s, most: 3)
                Spacer(minLength: 0)
            }
        }
    }

    // One part: a count when it's small, the list when there's room.

    @ViewBuilder private func part(_ p: DashboardPart, _ s: DashboardSnapshot) -> some View {
        let lines = p.lines(s)
        if p == .progress {
            VStack(alignment: .leading, spacing: 8) {
                Head(icon: p.icon, title: p.title, trailing: family == .systemSmall ? nil : s.boardTime)
                Headline(text: s.headline, lines: family == .systemSmall ? 4 : 3)
                Spacer(minLength: 0)
                if family != .systemSmall, let next = s.upNext.first { NextRow(text: next) }
            }
        } else if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                Head(icon: p.icon, title: p.title)
                Spacer(minLength: 0)
                if lines.isEmpty {
                    Text(p.empty).font(.system(size: 17, weight: .semibold))
                } else {
                    Count(n: lines.count, label: p.countLabel(lines.count))
                    Text(lines[0]).font(.system(size: 13)).lineLimit(2).foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Head(icon: p.icon, title: p.title, trailing: lines.isEmpty ? nil : "\(lines.count)")
                if lines.isEmpty {
                    Spacer(minLength: 0)
                    Text(p.empty).font(.system(size: 17, weight: .semibold))
                } else {
                    Bullets(lines: lines, most: family == .systemMedium ? 3 : family == .systemLarge ? 8 : 10,
                            mono: p == .forrob)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// "PROGRESS · 7:20 am", small and quiet, like the in-app widgets' headers.
private struct Head: View {
    let icon: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.2)
            Spacer(minLength: 4)
            if let trailing { Text(trailing).font(.system(size: 11)) }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .widgetAccentable()
    }
}

private struct Headline: View {
    let text: String?
    let lines: Int

    var body: some View {
        Text(text ?? "No headline yet.")
            .font(.system(size: 16, weight: .semibold))
            .lineLimit(lines)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct NextRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "arrow.right.circle").font(.system(size: 13))
            Text(text).font(.system(size: 14)).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next: \(text)")
    }
}

/// The big number on a Small widget.
private struct Count: View {
    let n: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(n)").font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
                .widgetAccentable()
            Text(label).font(.system(size: 13, weight: .semibold))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Bullets: View {
    let lines: [String]
    let most: Int
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.prefix(most).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•").foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(line).lineLimit(2)
                        .font(mono ? .system(size: 12, design: .monospaced) : .system(size: 13.5))
                }
            }
            if lines.count > most {
                Text("+\(lines.count - most) more").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13.5))
    }
}

/// A titled list inside the Overview.
private struct PartSection: View {
    let part: DashboardPart
    let s: DashboardSnapshot
    let most: Int

    var body: some View {
        let lines = part.lines(s)
        VStack(alignment: .leading, spacing: 6) {
            Head(icon: part.icon, title: part.title, trailing: lines.isEmpty ? nil : "\(lines.count)")
            if lines.isEmpty {
                Text(part.empty).font(.system(size: 13.5)).foregroundStyle(.secondary)
            } else {
                Bullets(lines: lines, most: most, mono: part == .forrob)
            }
        }
    }
}

/// "3 need you · 1 reminder", the dashboard tile's chips.
private struct Chips: View {
    let s: DashboardSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Chip(icon: "questionmark.bubble",
                 text: s.needs.isEmpty ? "Nothing needs you" : "\(s.needs.count) need\(s.needs.count == 1 ? "s" : "") you",
                 lit: !s.needs.isEmpty)
            if !s.reminders.isEmpty {
                Chip(icon: "bell", text: "\(s.reminders.count) reminder\(s.reminders.count == 1 ? "" : "s")", lit: false)
            }
        }
    }
}

private struct Chip: View {
    let icon: String
    let text: String
    let lit: Bool

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(lit ? 0.12 : 0.05)))
    }
}

struct PipDashboardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: DashboardSnapshot.widgetKind, intent: DashboardWidgetIntent.self,
                               provider: DashboardProvider()) { entry in
            PipDashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Pip Dashboard")
        .description("Your progress at a glance. Hold it and pick Edit Widget to choose what it shows.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}
