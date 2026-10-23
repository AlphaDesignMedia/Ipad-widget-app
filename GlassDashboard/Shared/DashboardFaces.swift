import SwiftUI
import WidgetKit

// The widget's two faces, shared so the app can show the same widget as a preview.

/// Small: the "need you" count, large, and the build on the iPad.
struct SmallFace: View {
    var status: DashboardStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NeedYou(count: status.needYou)
            Spacer(minLength: 4)
            BuildLine(status: status)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Medium: the small face plus "to try" and "up next", the newest update and its age.
struct MediumFace: View {
    var status: DashboardStatus
    var fresh: Bool
    var now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SmallFace(status: status)
            VStack(alignment: .leading, spacing: 8) {
                // Plain, so the rows keep their own colours rather than the blue of a link.
                Link(destination: StatusFeed.dashboard) {
                    CountRow(label: "To try on the iPad", count: status.toTry)
                }
                .buttonStyle(.plain)
                Link(destination: StatusFeed.dashboard) {
                    CountRow(label: "Up next", count: status.upNext)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 2)
                Text(status.latestUpdate)
                    .font(.footnote.weight(.medium))
                    .lineLimit(2)
                UpdatedLine(status: status, fresh: fresh, now: now)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// The headline number: how many questions on the dashboard are waiting for an answer.
private struct NeedYou: View {
    var count: Int

    var body: some View {
        Link(destination: StatusFeed.dashboard) {
            VStack(alignment: .leading, spacing: 0) {
                Text("NEED YOU")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(count, format: .number)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(count > 0 ? Color.orange : Color.primary)
                    .widgetAccentable()
                    .contentTransition(.numericText())
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BuildLine: View {
    var status: DashboardStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(status.ipadBuild.isEmpty ? "No build yet" : status.ipadBuild)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            if let date = status.buildDate {
                Text("On iPad · \(date, format: .dateTime.weekday(.abbreviated).hour().minute())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct CountRow: View {
    var label: String
    var count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(count, format: .number)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .widgetAccentable()
        }
    }
}

/// A light frosted wash with a bright rim, in the spirit of Glass Clock's GlassCardBackground.
struct DashboardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            LinearGradient(colors: [Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.10), .clear],
                           startPoint: .topLeading, endPoint: .center)
            ContainerRelativeShape()
                .strokeBorder(LinearGradient(colors: [.white.opacity(colorScheme == .dark ? 0.25 : 0.7), .clear,
                                                      .white.opacity(colorScheme == .dark ? 0.12 : 0.4)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 1)
        }
    }
}

