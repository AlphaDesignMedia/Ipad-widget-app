import SwiftUI
import UIKit

// STABLE & SANDBOX · plugin v1 (Grounded). Aaron, 31 Oct: "a quick way back to the known-good setup", and a calm
// place to bring plugins back one at a time and write down what happened.
// 1. One tap between 🟢 Stable (the known-good set of plugins) and ✨ Everything (your full set, remembered when you
//    leave it). Only plugin switches change: no other setting, nothing deleted. "Make this my Stable" saves the set
//    that's on now.
// 2. One at a time: from Stable, bring the others back one by one. Each step goes in the log with the time.
//    "That made it worse" switches the last one off again and marks it. Copy the log as a FOR JULES paste.
// 3. Crash clue: if the app stopped last time (the host opens in safe mode), the card names the last plugin brought
//    back as the first suspect. An app can't catch its own crash as it happens, so this is the next best thing.
// Also shows as a small section in the Dashboard. No timers, nothing drawn over the app, no network.
// Works the same with Pip off; Pip says nothing here. This plugin never switches itself off.

struct StableSwitch: SandboxPlugin {
    let info = PluginInfo(id: "stable", name: "Stable & Sandbox", version: "v1", shelf: .grounded,
                          icon: "lifepreserver", what: "One tap back to the known-good plugins, and a log to bring the rest back one at a time.")

    var addsTo: String? { "dashboard" }

    // MARK: Data

    /// The starting Stable set: the everyday plugins (nat/everything-drawer.md), the Dashboard, the Desk and this one.
    static let everyday = ["sketch", "pencil", "wonders", "sketchbook", "ideainbox", "bond", "feelings", "weight",
                           "looks", "remembers", "manners", "dashboard", "desk", "stable"]
    static let me = "stable"
    static let logLimit = 60

    enum Mode: String { case stable, everything, custom }

    // MARK: Logic

    @MainActor static func ids(_ host: PipHost) -> [String] { host.plugins.map(\.info.id) }
    @MainActor static func name(_ id: String, _ host: PipHost) -> String {
        host.plugins.first { $0.info.id == id }?.info.name ?? id
    }
    @MainActor static func onNow(_ host: PipHost) -> [String] { ids(host).filter { host.chosen($0) } }

    @MainActor static func stableSet(_ host: PipHost) -> [String] { host.value(me, "stableSet") ?? everyday }
    @MainActor static func fullSet(_ host: PipHost) -> [String] { host.value(me, "fullSet") ?? ids(host) }
    @MainActor static func mode(_ host: PipHost) -> Mode {
        (host.value(me, "mode") as String?).flatMap(Mode.init(rawValue:)) ?? .custom
    }

    /// Switches exactly this set on and everything else off (this plugin always stays on).
    @MainActor static func apply(_ set: [String], _ host: PipHost) {
        let keep = Set(set).union([me])
        for id in ids(host) where id != me {
            let want = keep.contains(id)
            if host.chosen(id) != want { host.setOn(id, want) }
        }
    }

    @MainActor static func goStable(_ host: PipHost) {
        if mode(host) != .stable { host.setValue(onNow(host), me, "fullSet") }
        apply(stableSet(host), host)
        host.setValue(Mode.stable.rawValue, me, "mode")
        host.setValue(nil, me, "lastAdded")
        log("🟢 Back to Stable (\(onNow(host).count) on)", host)
    }

    @MainActor static func goEverything(_ host: PipHost) {
        apply(fullSet(host), host)
        host.setValue(Mode.everything.rawValue, me, "mode")
        host.setValue(nil, me, "lastAdded")
        log("✨ Everything back (\(onNow(host).count) on)", host)
    }

    @MainActor static func saveStable(_ host: PipHost) {
        host.setValue(onNow(host), me, "stableSet")
        host.setValue(Mode.stable.rawValue, me, "mode")
        log("💾 Stable is now these \(onNow(host).count)", host)
    }

    /// The plugins that are off, in plugin-bar order: the queue for "one at a time".
    @MainActor static func waiting(_ host: PipHost) -> [String] {
        ids(host).filter { !host.chosen($0) && host.broken[$0] == nil }
    }

    @MainActor static func bringBack(_ id: String, _ host: PipHost) {
        host.setOn(id, true)
        host.setValue(id, me, "lastAdded")
        host.setValue(Date().timeIntervalSince1970, me, "lastAddedAt")
        host.setValue(Mode.custom.rawValue, me, "mode")
        log("➕ \(name(id, host))", host)
    }

    @MainActor static func madeItWorse(_ host: PipHost) {
        guard let id: String = host.value(me, "lastAdded") else { return }
        host.setOn(id, false)
        var marked: [String] = host.value(me, "suspects") ?? []
        if !marked.contains(id) { marked.append(id) }
        host.setValue(marked, me, "suspects")
        host.setValue(nil, me, "lastAdded")
        log("✗ \(name(id, host)) made it worse, switched off again", host)
    }

    /// After the app stopped while open: the last plugin brought back (within 6 hours) is the first suspect.
    @MainActor static func crashSuspect(_ host: PipHost) -> String? {
        guard host.safeMode, let id: String = host.value(me, "lastAdded"),
              let at: Double = host.value(me, "lastAddedAt"),
              Date().timeIntervalSince1970 - at < 6 * 3600 else { return nil }
        return id
    }

    @MainActor static func log(_ line: String, _ host: PipHost) {
        let time = Date().formatted(date: .omitted, time: .shortened)
        var lines: [String] = host.value(me, "log") ?? []
        lines.insert("\(time)  \(line)", at: 0)
        host.setValue(Array(lines.prefix(logLimit)), me, "log")
    }

    @MainActor static func paste(_ host: PipHost) -> String {
        let lines: [String] = host.value(me, "log") ?? []
        let marked: [String] = host.value(me, "suspects") ?? []
        var out = ["FOR JULES · Stable & Sandbox log from the iPad",
                   "Mode: \(mode(host).rawValue) · \(onNow(host).count) of \(ids(host).count) plugins on"]
        if !marked.isEmpty { out.append("Made it worse: " + marked.map { name($0, host) }.joined(separator: ", ")) }
        if !host.broken.isEmpty { out.append("Switched off by the host: " + host.broken.keys.sorted().map { name($0, host) }.joined(separator: ", ")) }
        out.append("")
        out.append(contentsOf: lines.reversed())
        return out.joined(separator: "\n")
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { Desk(host: host, full: true) }

    func addOn(_ host: PipHost) -> some View { Desk(host: host, full: false) }

    struct Desk: View {
        let host: PipHost
        /// false: the short version shown inside the Dashboard.
        let full: Bool
        /// Bumped after every tap, so what's read from storage redraws.
        @State private var taps = 0
        @State private var copied = false

        var body: some View {
            let _ = taps
            let mode = StableSwitch.mode(host)
            let on = StableSwitch.onNow(host).count
            let total = StableSwitch.ids(host).count
            VStack(alignment: .leading, spacing: Corner.inset) {
                if let suspect = StableSwitch.crashSuspect(host) {
                    SettingsCard(title: "The app stopped last time", icon: "exclamationmark.triangle",
                                 footer: "Plugins are paused for now. Un-pause in the plugin bar when you're ready.") {
                        Text("Last one brought back: \(StableSwitch.name(suspect, host)). It's the first suspect.")
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Switch it off and mark it") { StableSwitch.madeItWorse(host); taps += 1 }
                            .buttonStyle(PluginCardButton(on: true))
                    }
                }
                SettingsCard(title: full ? "Stable or everything" : "Sandbox",
                             icon: "lifepreserver",
                             footer: "\(on) of \(total) plugins on. Only plugin switches change; nothing is deleted.") {
                    HStack(spacing: PluginBarLook.cardGap) {
                        Button { StableSwitch.goStable(host); taps += 1 } label: {
                            Label("Stable", systemImage: "checkmark.shield").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PluginCardButton(on: mode == .stable))
                        .accessibilityHint("Switches to the known-good set of plugins.")
                        Button { StableSwitch.goEverything(host); taps += 1 } label: {
                            Label("Everything", systemImage: "sparkles").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PluginCardButton(on: mode == .everything))
                        .accessibilityHint("Brings back your full set of plugins.")
                    }
                    if host.paused {
                        Text("Everything is paused at the moment, so none of them are running.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if full {
                        Button("Make this my Stable") { StableSwitch.saveStable(host); taps += 1 }
                            .buttonStyle(PluginCardButton(on: false))
                            .accessibilityHint("Saves the plugins that are on now as your Stable set.")
                    }
                }
                if full { oneAtATime; logCard }
            }
        }

        private var oneAtATime: some View {
            let queue = StableSwitch.waiting(host)
            let last: String? = host.value(StableSwitch.me, "lastAdded")
            return SettingsCard(title: "One at a time", icon: "list.number",
                                footer: "Bring one back, use the app for a bit, then decide. Every step goes in the log.") {
                if let next = queue.first {
                    Button {
                        StableSwitch.bringBack(next, host); taps += 1
                    } label: {
                        Label("Bring back: \(StableSwitch.name(next, host))", systemImage: "plus.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PluginCardButton(on: true))
                    Text("\(queue.count) waiting").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Everything's back on.").foregroundStyle(.secondary)
                }
                if let last {
                    Button("\(StableSwitch.name(last, host)) made it worse") { StableSwitch.madeItWorse(host); taps += 1 }
                        .buttonStyle(PluginCardButton(on: false))
                        .accessibilityHint("Switches it off again and marks it in the log.")
                }
            }
        }

        private var logCard: some View {
            let lines: [String] = host.value(StableSwitch.me, "log") ?? []
            return SettingsCard(title: "Log", icon: "doc.text") {
                if lines.isEmpty {
                    Text("Nothing yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(lines.prefix(12).indices, id: \.self) { i in
                        Text(lines[i]).font(.system(size: 12.5, design: .monospaced))
                    }
                }
                HStack(spacing: PluginBarLook.cardGap) {
                    Button {
                        UIPasteboard.general.string = StableSwitch.paste(host)
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy for Jules", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(PluginCardButton(on: !lines.isEmpty))
                    .disabled(lines.isEmpty)
                    Button("Clear") {
                        host.setValue(nil, StableSwitch.me, "log")
                        host.setValue(nil, StableSwitch.me, "suspects")
                        copied = false
                        taps += 1
                    }
                    .buttonStyle(PluginCardButton(on: false))
                    .disabled(lines.isEmpty)
                }
            }
        }
    }
}
