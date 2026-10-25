import Foundation
import MetricKit

/// Keeps the crash and hang reports iOS hands the app on its next launch, in the app's own
/// Documents/Diagnostics, so they can be copied off the iPad when the system's own crash log
/// is missing (owner, 25 Oct 2026: a crash on the rail card left no log). Copy them with
/// `xcrun devicectl device copy from --domain-type appDataContainer
/// --domain-identifier com.aarondennel.glassclock --source Documents/Diagnostics`.
final class CrashReports: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReports()

    func start() { MXMetricManager.shared.add(self) }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for payload in payloads {
            let stamp = ISO8601DateFormatter().string(from: payload.timeStampEnd).replacingOccurrences(of: ":", with: "-")
            try? payload.jsonRepresentation().write(to: folder.appending(path: "diagnostic-\(stamp)-\(UUID().uuidString.prefix(4)).json"))
        }
    }
}
