import SwiftUI

/// "Updated 12 min ago", counted from when the dashboard was last published, and marked
/// offline when the download failed and these are the last known numbers. `now` is the
/// widget entry's date, so each entry in the timeline shows its own age.
struct UpdatedLine: View {
    var status: DashboardStatus
    var fresh: Bool
    var now: Date = .now

    var body: some View {
        if let date = status.updatedDate {
            Text("\(fresh ? "" : "Offline · ")Updated \(Self.age(of: date, at: now))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    static func age(of date: Date, at now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
