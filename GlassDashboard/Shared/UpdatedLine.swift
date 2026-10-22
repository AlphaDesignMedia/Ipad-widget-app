import SwiftUI

/// "Updated 12 min ago", counted from when the dashboard was last published, and marked
/// offline when the download failed and these are the last known numbers.
struct UpdatedLine: View {
    var status: DashboardStatus
    var fresh: Bool

    var body: some View {
        if let date = status.updatedDate {
            Text("\(fresh ? "" : "Offline · ")Updated \(date, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
