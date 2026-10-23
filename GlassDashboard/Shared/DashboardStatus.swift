import Foundation

/// The progress dashboard's numbers, as `Scripts/publish-status.sh` writes them to status.json.
/// The widget can't sign in to Claude, so it reads this small file from a secret GitHub Gist.
struct DashboardStatus: Codable, Equatable {
    var needYou: Int
    var toTry: Int
    var upNext: Int
    var done: Int
    var ipadBuild: String
    var ipadBuildAt: String
    var latestUpdate: String
    var updatedAt: String

    /// Shown in the widget gallery and before the first download.
    static let sample = DashboardStatus(
        needYou: 2, toTry: 13, upNext: 5, done: 14,
        ipadBuild: "Status bar wash", ipadBuildAt: "2026-10-22T18:15:00Z",
        latestUpdate: "Moods are on your iPad", updatedAt: "2026-10-22T19:00:00Z")

    var buildDate: Date? { Self.date(ipadBuildAt) }
    var updatedDate: Date? { Self.date(updatedAt) }

    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: text)
    }
}

enum StatusFeed {
    /// The dashboard page, opened in Safari when a number is tapped.
    static let dashboard = URL(string: "https://claude.ai/artifact/UQ9Yo6F6RBNdoUn8B9sqeW")!
    /// The gist's raw file. Without a commit in the address it always gives the newest version
    /// (GitHub caches it for about five minutes).
    static let url = URL(string: "https://gist.githubusercontent.com/AlphaDesignMedia/1f2abb87c59f63844a9f7523f37da9f4/raw/status.json")!

    private static let cacheKey = "lastStatus"

    /// The last status downloaded, kept so the widget still shows something when offline.
    /// Each process keeps its own copy: the free team can't share an App Group.
    static var cached: DashboardStatus? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(DashboardStatus.self, from: data)
    }

    /// Downloads the newest status, or falls back to the last one. `fresh` is false when offline.
    static func load() async -> (status: DashboardStatus?, fresh: Bool) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let status = try JSONDecoder().decode(DashboardStatus.self, from: data)
            UserDefaults.standard.set(data, forKey: cacheKey)
            return (status, true)
        } catch {
            return (cached, false)
        }
    }
}
