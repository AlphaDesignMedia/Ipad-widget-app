import SwiftUI
import UIKit

// DASHBOARD SHOT LIST · part of the Dashboard plugin (Jules, 1 Nov). Aaron: "I need to maybe get some places to go back
// and take some screenshots and stuff for the developers". Step 2 of nat/dashboard-studio-plan.md.
// A list of places to screenshot, in the Dashboard's "Shot list" group. Rob, Jules and the master chat add them through
// the board (`shots` in dashboard.json); you can add your own on the iPad. Tap Go: the app takes you there and a small
// bar shows what to capture, with Snap and Back. Snap takes a picture of the whole screen, ticks the shot off and opens
// the send sheet with the note filled in and set to whoever asked. Nothing leaves the iPad without your tap.
// Ticks and your own shots are kept on this iPad. No network, no timers. Pip says nothing here.
// Simpler motion: the bar fades in and out.

extension Dashboard {

    // MARK: Data

    static let shotsDoneKey = "plug.dashboard.shotsDone"
    static let myShotsKey = "plug.dashboard.myShots"

    /// A shot's lasting name, so its tick survives a new board. (Not `hashValue`: that changes every launch.)
    static func shotKey(_ s: DashboardData.Shot) -> String {
        var h: UInt64 = 5381
        for b in (s.what + "|" + (s.go ?? "")).utf8 { h = (h &* 33) &+ UInt64(b) }
        return "\(h)"
    }

    /// Where Go takes you, in plain words. Nil when it can't take you anywhere.
    @MainActor static func placeName(_ go: String?, _ host: PipHost) -> String? {
        guard let go else { return nil }
        let parts = go.split(separator: ":", maxSplits: 1).map(String.init)
        switch parts.first {
        case "tab":
            guard parts.count == 2 else { return nil }
            return (host.screenPlugins.first { $0.info.id == parts[1] }?.screenName ?? parts[1].capitalized) + " tab"
        case "card":
            guard parts.count == 2 else { return nil }
            return (host.plugins.first { $0.info.id == parts[1] }?.info.name ?? parts[1].capitalized) + " card"
        case "home": return "The app, everything closed"
        case "homescreen": return "The Home Screen: take an iPad screenshot (top button + volume up)"
        default: return nil
        }
    }

    /// The board's shots. The live board may not carry them yet, so the packed-in file's stand in until it does.
    static func boardShots(_ data: DashboardData) -> [DashboardData.Shot] {
        data.shots ?? Dashboard.feed.data.shots ?? []
    }

    static func canGo(_ go: String?) -> Bool {
        guard let go else { return false }
        return go == "home" || go.hasPrefix("tab:") || go.hasPrefix("card:")
    }

    /// Who asked, as a send choice.
    static func sender(_ from: String?) -> SendTo? {
        guard let from = from?.lowercased() else { return nil }
        return SendTo.allCases.first { from.hasPrefix($0.label.lowercased()) || from.hasPrefix($0.rawValue) }
    }

    // MARK: Logic

    /// Ticks and your own shots, kept on this iPad. Observed, so the list and the groups badge redraw on a change.
    @MainActor @Observable final class ShotBook {
        static let shared = ShotBook()
        private(set) var done: Set<String>
        private(set) var mine: [DashboardData.Shot]

        init() {
            done = Set(UserDefaults.standard.stringArray(forKey: Dashboard.shotsDoneKey) ?? [])
            mine = UserDefaults.standard.data(forKey: Dashboard.myShotsKey)
                .flatMap { try? JSONDecoder().decode([DashboardData.Shot].self, from: $0) } ?? []
        }

        func isDone(_ s: DashboardData.Shot) -> Bool { done.contains(Dashboard.shotKey(s)) }
        func isMine(_ s: DashboardData.Shot) -> Bool { mine.contains(s) }

        /// How many are still to take, the board's and yours.
        func waiting(_ board: [DashboardData.Shot]) -> Int { (board + mine).filter { !isDone($0) }.count }

        func setDone(_ s: DashboardData.Shot, _ on: Bool) {
            if on { done.insert(Dashboard.shotKey(s)) } else { done.remove(Dashboard.shotKey(s)) }
            UserDefaults.standard.set(Array(done), forKey: Dashboard.shotsDoneKey)
        }

        func add(_ what: String) {
            let what = what.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !what.isEmpty else { return }
            let today = Date().formatted(.iso8601.year().month().day())
            mine.append(DashboardData.Shot(what: what, go: nil, from: nil, date: today))
            keep()
        }

        func remove(_ s: DashboardData.Shot) {
            mine.removeAll { $0 == s }
            setDone(s, false)
            keep()
        }

        private func keep() {
            UserDefaults.standard.set(try? JSONEncoder().encode(mine), forKey: Dashboard.myShotsKey)
        }
    }

    /// The shot you're off taking, if any. The bar over the app shows while it's set.
    @MainActor @Observable final class ShotRun {
        static let shared = ShotRun()
        var current: DashboardData.Shot?
    }

    /// Takes you to the shot's place and shows the bar.
    @MainActor static func go(_ shot: DashboardData.Shot, _ host: PipHost) {
        let parts = (shot.go ?? "").split(separator: ":", maxSplits: 1).map(String.init)
        withAnimation(host.simpler ? nil : .easeOut(duration: 0.25)) {
            ShotRun.shared.current = shot
            switch parts.first {
            case "tab":
                host.openCard = nil
                host.openScreen = parts.count == 2 ? parts[1] : nil
            case "card":
                host.openScreen = nil
                host.openCard = parts.count == 2 ? parts[1] : nil
            default:
                host.openScreen = nil
                host.openCard = nil
            }
        }
    }

    // MARK: Views

    /// The Shot list group: what's still to take first, then what's done (greyed), then a line to add your own.
    struct ShotsPanel: View {
        let shots: [DashboardData.Shot]
        let host: PipHost
        @Bindable private var book = ShotBook.shared
        @State private var adding = ""

        init(shots: [DashboardData.Shot], host: PipHost) {
            self.shots = shots
            self.host = host
        }

        var body: some View {
            let all = shots + book.mine
            let ordered = all.filter { !book.isDone($0) } + all.filter { book.isDone($0) }
            SettingsCard(title: "Shot list", icon: "camera.viewfinder",
                         footer: "Tap Go and the app takes you there. Snap it, add a line, send it. Ticked when snapped.") {
                if all.isEmpty {
                    Text("Nothing to shoot yet. Add a place below; Rob and Jules add theirs through the board.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(ordered, id: \.self) { row($0) }
                HStack(spacing: 8) {
                    TextField("Add a place to shoot", text: $adding)
                        .onSubmit(add)
                        .submitLabel(.done)
                    Button("Add", action: add)
                        .buttonStyle(PluginCardButton())
                        .disabled(adding.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }

        private func add() {
            book.add(adding)
            adding = ""
        }

        private func row(_ shot: DashboardData.Shot) -> some View {
            let done = book.isDone(shot)
            let place = Dashboard.placeName(shot.go, host)
            let meta = [shot.from.map { "For \($0)" }, place].compactMap { $0 }.joined(separator: " · ")
            return HStack(alignment: .center, spacing: 10) {
                Button { book.setDone(shot, !done) } label: {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 18))
                        .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 30, height: 30).contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "Done. Tap to untick." : "Not taken yet. Tap to tick.")
                VStack(alignment: .leading, spacing: 2) {
                    Text(Dashboard.clean(shot.what)).font(.system(size: 13.5, weight: .medium))
                        .strikethrough(done)
                        .fixedSize(horizontal: false, vertical: true)
                    if !meta.isEmpty {
                        Text(meta).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                if Dashboard.canGo(shot.go) {
                    Button("Go") { Dashboard.go(shot, host) }
                        .buttonStyle(PluginCardButton(on: !done))
                        .accessibilityHint("Takes you there, with Snap and Back at the top.")
                }
                if book.isMine(shot) {
                    Button { book.remove(shot) } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                            .frame(width: 28, height: 28).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Remove this shot")
                }
            }
            .opacity(done ? 0.55 : 1)
        }
    }

    /// The bar at the top while you're off taking a shot: what to capture, Snap, Back. Hidden in the picture itself.
    struct ShotPill: View {
        let host: PipHost
        @Bindable private var run = ShotRun.shared
        @State private var hiding = false
        @State private var snap: Snap?

        init(host: PipHost) { self.host = host }

        var body: some View {
            ZStack(alignment: .top) {
                Color.clear.frame(width: 0, height: 0)
                if let shot = run.current, !hiding, snap == nil {
                    bar(shot)
                        .padding(.top, 64)
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .sheet(item: $snap, onDismiss: back) { s in
                SnapSheet(snap: s, startNote: "Shot list: \(Dashboard.clean(run.current?.what ?? ""))",
                          sendTo: Dashboard.sender(run.current?.from))
            }
        }

        private func bar(_ shot: DashboardData.Shot) -> some View {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder").font(.system(size: 18, weight: .semibold)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SHOT LIST").font(.system(size: 10.5, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                    Text(Dashboard.clean(shot.what)).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                }
                Spacer(minLength: 8)
                Button { take(shot) } label: { Label("Snap", systemImage: "camera") }
                    .buttonStyle(PluginCardButton(on: true))
                    .fixedSize()
                    .accessibilityHint("Takes a picture of the screen, without this bar, and ticks the shot off.")
                Button("Back", action: back)
                    .buttonStyle(PluginCardButton())
                    .fixedSize()
                    .accessibilityHint("Back to the Shot list, without a picture.")
            }
            .padding(.leading, 18).padding(.trailing, 10).padding(.vertical, 8)
            .frame(maxWidth: 620)
            .appGlass(.capsule)
            .accessibilityElement(children: .contain)
        }

        /// Hides the bar for a moment so it's not in the picture, then takes the whole screen.
        private func take(_ shot: DashboardData.Shot) {
            hiding = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                let image = Dashboard.capture(nil)
                hiding = false
                guard let image else { return }
                ShotBook.shared.setDone(shot, true)
                snap = Snap(image: image)
            }
        }

        /// Back to the Shot list.
        private func back() {
            withAnimation(host.simpler ? nil : .easeOut(duration: 0.25)) {
                run.current = nil
                host.openCard = nil
                host.openScreen = "dashboard"
            }
        }
    }
}
