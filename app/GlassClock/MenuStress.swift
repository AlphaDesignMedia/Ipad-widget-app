#if DEBUG
import SwiftUI
import UIKit
import os

/// Debug builds only: a hands-free run through the developer menus, for chasing stutters with numbers.
/// Launch with `-frameMeter YES -stressMenus YES`. After a few seconds it opens each menu (Plugin Desk, Dashboard,
/// Crew rundown), unfolds every section, scrolls it down and back, and flicks one plugin off and on six times,
/// measuring each step with the frame meter's counter. The numbers go to the log (category "stress") and to
/// Documents/Diagnostics/stress-<time>.txt. Everything it changes is put back. (Rob, 31 Oct 2026)
@MainActor enum MenuStress {
    static let menus = ["desk", "dashboard", "crew"]
    /// Every DevFold in the dev menus (grep `DevFold(id:`), plus the panels' "More" sections.
    static let folds = ["desk.list", "dash.where", "dash.needs", "dash.reminders", "crew.core", "crew.crew", "crew.new",
                        "crew.you", "ideas", "next", "queue"]
    static let toggled = "teabreak"

    private static let log = Logger(subsystem: "com.aarondennel.pipsandbox", category: "stress")

    static func runIfAsked() {
        // `-holdMenu dashboard`: just open that menu and leave it, for the Time Profiler.
        if let id = UserDefaults.standard.string(forKey: "holdMenu") {
            PipHost.shared.later(4) { PipHost.shared.setPaused(false); PipHost.shared.openCard = id }
        }
        // `-flipLoop teabreak`: switch that plugin off and on every half second, to sample what one switch costs.
        if let id = UserDefaults.standard.string(forKey: "flipLoop") {
            Task {
                try? await Task.sleep(for: .seconds(6))
                while true {
                    PipHost.shared.setOn(id, !PipHost.shared.chosen(id))
                    try? await Task.sleep(for: .seconds(0.5))
                }
            }
        }
        if UserDefaults.standard.bool(forKey: "tess") { Task { await Tess.run() } }
        guard UserDefaults.standard.bool(forKey: "stressMenus") else { return }
        Task { await run() }
    }

    static func run() async {
        let host = PipHost.shared
        let store = UserDefaults.standard
        let watch = FrameWatch()
        watch.start()
        let foldKeys = folds.map { "plug.devfold.\($0)" }
            + host.plugins.compactMap { p in p.addsTo.map { "plug.devfold.panel.\($0).\(p.info.id)" } }
        let savedFolds = foldKeys.map { store.object(forKey: $0) }
        let wasOn = host.chosen(toggled)
        var out = ["Menu stress · \(Date.now.formatted()) · \(UIDevice.current.model) · step: fps · late frames · worst ms"]

        func step(_ name: String, _ work: () async -> Void) async {
            watch.reset()
            await work()
            try? await Task.sleep(for: .seconds(2.2))   // the meter publishes once a second
            let line = "\(name): \(watch.fps) fps · \(watch.hitches) late · worst \(watch.worstMs) ms"
            log.notice("\(line, privacy: .public)")
            out.append(line)
        }

        try? await Task.sleep(for: .seconds(6))         // let launch settle
        if host.paused { host.setPaused(false) }
        for key in foldKeys { store.set(false, forKey: key) }
        await step("idle, nothing open") {}

        for id in menus where host.isOn(id) {
            await step("\(id) · open") { withAnimation(.easeOut(duration: 0.2)) { host.openCard = id } }
            await step("\(id) · unfold every section") {
                withAnimation(.snappy) { for key in foldKeys { store.set(true, forKey: key) } }
            }
            await step("\(id) · scroll down and back") {
                for view in scrollers() { view.setContentOffset(CGPoint(x: 0, y: view.contentSize.height - view.bounds.height), animated: true) }
                try? await Task.sleep(for: .seconds(0.8))
                for view in scrollers() { view.setContentOffset(.zero, animated: true) }
            }
            await step("\(id) · switch \(toggled) off and on ×6") {
                for _ in 0..<6 {
                    host.setOn(toggled, !host.chosen(toggled))
                    try? await Task.sleep(for: .seconds(0.15))
                }
            }
            await step("\(id) · close") {
                withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
                for key in foldKeys { store.set(false, forKey: key) }
            }
        }

        // Put back everything it touched.
        if host.chosen(toggled) != wasOn { host.setOn(toggled, wasOn) }
        for (key, value) in zip(foldKeys, savedFolds) { store.set(value, forKey: key) }
        out.append("Done.")
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date.now.ISO8601Format().replacingOccurrences(of: ":", with: "-")
        try? out.joined(separator: "\n").write(to: folder.appending(path: "stress-\(stamp).txt"), atomically: true, encoding: .utf8)
        log.notice("Menu stress done.")
    }

    /// The menus' scroll views: anything narrow enough to be a card or panel that has more to show.
    static func scrollers() -> [UIScrollView] {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        var found: [UIScrollView] = []
        func walk(_ view: UIView) {
            if let s = view as? UIScrollView, s.bounds.width <= 420, s.contentSize.height > s.bounds.height + 1 { found.append(s) }
            view.subviews.forEach(walk)
        }
        windows.forEach(walk)
        return found
    }
}
/// Tess the Tester, the in-app half (the other half is `tools/tess.sh`). Launch with `-frameMeter YES -tess YES`.
/// For every plugin-bar button that's on: open it, wait a second, scroll its card or panel to the bottom, flip each switch in it
/// once and back, and close it, measuring late frames and the worst gap on the frame meter's counter. Then Pause all and resume.
/// One line per plugin goes to Documents/Diagnostics/tess-result.txt (tab-separated); `tess-now.txt` names the plugin being
/// tested, so if the app dies the script knows which one it was. Settings are put back as they were. (Rob, 31 Oct 2026)
@MainActor enum Tess {
    static func run() async {
        let host = PipHost.shared
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let now = folder.appending(path: "tess-now.txt"), result = folder.appending(path: "tess-result.txt")
        func mark(_ text: String) { try? text.write(to: now, atomically: true, encoding: .utf8) }
        var lines: [String] = []
        func save() { try? lines.joined(separator: "\n").write(to: result, atomically: true, encoding: .utf8) }
        let watch = FrameWatch()
        watch.start()
        try? await Task.sleep(for: .seconds(6))         // let launch settle
        if host.paused { host.setPaused(false) }
        try? await Task.sleep(for: .seconds(2))

        for p in host.plugins where p.hasCard && host.isOn(p.info.id) {
            let id = p.info.id
            mark(id)
            watch.reset()
            withAnimation(.easeOut(duration: 0.2)) { host.openCard = id }
            try? await Task.sleep(for: .seconds(1))
            let area = host.panelFrame.isNull ? host.cardFrame : host.panelFrame
            for view in inside(area, MenuStress.scrollers()) {
                view.setContentOffset(CGPoint(x: 0, y: max(0, view.contentSize.height - view.bounds.height)), animated: true)
            }
            try? await Task.sleep(for: .seconds(0.8))
            let switches = inside(area, allSwitches())
            for s in switches {
                s.setOn(!s.isOn, animated: true); s.sendActions(for: .valueChanged)
                try? await Task.sleep(for: .seconds(0.3))
                s.setOn(!s.isOn, animated: true); s.sendActions(for: .valueChanged)
                try? await Task.sleep(for: .seconds(0.3))
            }
            try? await Task.sleep(for: .seconds(1.2))   // the meter publishes once a second
            withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
            try? await Task.sleep(for: .seconds(0.6))
            lines.append([id, p.info.name, "\(watch.hitches)", "\(watch.worstMs)", "\(switches.count)"].joined(separator: "\t"))
            save()
        }

        mark("pause")
        watch.reset()
        withAnimation(.easeOut(duration: 0.2)) { host.setPaused(true) }
        try? await Task.sleep(for: .seconds(1.5))
        withAnimation(.easeOut(duration: 0.2)) { host.setPaused(false) }
        try? await Task.sleep(for: .seconds(2.2))
        lines.append(["pause", "Pause all, then resume", "\(watch.hitches)", "\(watch.worstMs)", "0"].joined(separator: "\t"))
        lines.append("DONE")
        save()
        mark("done")
    }

    /// Views of a kind whose frame (in window space) overlaps the open card or panel.
    private static func inside<V: UIView>(_ area: CGRect, _ views: [V]) -> [V] {
        guard !area.isNull else { return [] }
        return views.filter { $0.window != nil && $0.convert($0.bounds, to: nil).intersects(area) }
    }

    private static func allSwitches() -> [UISwitch] {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        var found: [UISwitch] = []
        func walk(_ view: UIView) {
            if let s = view as? UISwitch, !s.isHidden, s.isEnabled { found.append(s) }
            view.subviews.forEach(walk)
        }
        windows.forEach(walk)
        return found
    }
}
#endif
