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
    static let menus = ["desk", "dashboard", "crew", "ideainbox"]
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
        if UserDefaults.standard.bool(forKey: "checkIdeas") { Task { await IdeasCheck.run() } }
        if let phase = UserDefaults.standard.string(forKey: "checkKL") { Task { await KLCheck.run(phase) } }
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
/// `-checkIdeas YES`: walks Pip, design partner the way Aaron would (Rob's check for Jules, 31 Oct 2026). Opens 💡, types an idea,
/// saves it, moves it to EXPERIMENT, picks APPROVED (expects "Send to the dashboard?"), says yes, taps Copy for Chappie, closes.
/// Taps go through accessibility (as VoiceOver would), menus through their UIActions, the dialog through its action.
/// Each step's result goes to Documents/Diagnostics/ideas-check.txt; the ideas are put back as they were at the end.
@MainActor enum IdeasCheck {
    static func run() async {
        let host = PipHost.shared, store = UserDefaults.standard, key = "plug.ideainbox.ideas"
        let saved = store.string(forKey: key)
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "ideas-check.txt")
        var out: [String] = []
        func note(_ s: String) { out.append(s); try? out.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        func pause(_ s: Double = 1.2) async { try? await Task.sleep(for: .seconds(s)) }
        let watch = FrameWatch()
        watch.start()
        let text = "Tess check idea"
        func stage() -> String {
            let ideas = (try? JSONSerialization.jsonObject(with: Data((store.string(forKey: key) ?? "[]").utf8))) as? [[String: Any]] ?? []
            guard let i = ideas.first(where: { ($0["text"] as? String) == text }) else { return "missing" }
            return (i["stage"] as? String) ?? "spark"
        }

        await pause(6)
        if host.paused { host.setPaused(false) }
        store.set("[]", forKey: key)                    // start empty, so the only stage menu is the test idea's
        note("start · on: \(host.isOn("ideainbox"))")
        watch.reset()
        withAnimation(.easeOut(duration: 0.2)) { host.openCard = "ideainbox" }
        await pause(1.5)
        note("open · panel shown: \(!host.panelFrame.isNull) · \(watch.hitches) late · worst \(watch.worstMs) ms")

        // Type and save.
        let area = host.panelFrame
        let inPanel = { (v: UIView) in v.convert(v.bounds, to: nil).intersects(area) }
        if let field = views(UITextView.self).first(where: inPanel) {
            field.becomeFirstResponder(); field.insertText(text)
            await pause(0.5)
            note("typed: \(field.text ?? "")")
        } else if let field = views(UITextField.self).first(where: inPanel) {
            field.becomeFirstResponder(); field.insertText(text)
            await pause(0.5)
            note("typed (text field): \(field.text ?? "")")
        } else { note("FAIL no text box found") }
        note("save button: \(activate("Save idea"))")
        await pause()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        note("after save · stage: \(stage())")

        // Change stage to EXPERIMENT through the stage menu.
        note("experiment: \(await pick("✏️ EXPERIMENT"))")
        await pause()
        note("after experiment · stage: \(stage())")

        // APPROVED should ask first.
        UIPasteboard.general.string = ""
        note("approved picked: \(await pick("👍 APPROVED"))")
        await pause()
        note("stage before yes (should still be experiment): \(stage())")
        let alert = topAlert()
        note("dialog: \(alert.map { "“\($0.title ?? "")” · \($0.actions.map { $0.title ?? "?" })" } ?? "FAIL none shown")")
        if let alert, let yes = alert.actions.first(where: { $0.title == "Yes, it's approved" }) {
            typealias Handler = @convention(block) (UIAlertAction) -> Void
            let handler = yes.value(forKey: "handler").map { unsafeBitCast($0 as AnyObject, to: Handler.self) }
            alert.dismiss(animated: true) { handler?(yes) }
            for _ in 0..<20 where stage() != "approved" { await pause(0.5) }
        }
        note("after yes · stage: \(stage()) · pasteboard: \(UIPasteboard.general.string?.prefix(40) ?? "")")
        note("Pip perched and garden shows 👍 APPROVED: see screenshot")
        await pause(2)

        // Copy for Chappie.
        note("copy button: \(activate("Copy for Chappie"))")
        await pause()
        note("pasteboard: \(UIPasteboard.general.string?.replacingOccurrences(of: "\n", with: " ⏎ ").prefix(160) ?? "")")

        watch.reset()
        withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
        await pause(1.5)
        note("closed · \(watch.hitches) late · worst \(watch.worstMs) ms")
        store.set(saved, forKey: key)
        note("DONE")
    }

    private static func windows() -> [UIWindow] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
    }

    private static func views<V: UIView>(_ kind: V.Type) -> [V] {
        var found: [V] = []
        func walk(_ v: UIView) { if let x = v as? V, !x.isHidden, x.window != nil { found.append(x) }; v.subviews.forEach(walk) }
        windows().forEach(walk)
        return found
    }

    /// Finds an accessibility element by label (SwiftUI exposes these to VoiceOver) and activates it, as a VoiceOver double tap does.
    private static func activate(_ label: String) -> String {
        var hit: NSObject?
        func walk(_ o: NSObject, _ depth: Int) {
            guard hit == nil, depth < 60 else { return }
            if o.accessibilityLabel == label { hit = o; return }
            if let v = o as? UIView { v.subviews.forEach { walk($0, depth + 1) } }
            for e in (o.accessibilityElements ?? []) { if let e = e as? NSObject { walk(e, depth + 1) } }
        }
        windows().forEach { walk($0, 0) }
        guard let hit else { return "FAIL “\(label)” not found" }
        return hit.accessibilityActivate() ? "ok" : "FAIL “\(label)” found but wouldn't activate"
    }

    /// The stage menu: first look for a UIKit button whose menu has the item and run its action; if SwiftUI hides it, open the menu
    /// through accessibility ("Stage: … Change stage") and activate the item's cell, as VoiceOver would.
    private static func pick(_ title: String) async -> String {
        func actions(_ els: [UIMenuElement]) -> [UIAction] {
            els.flatMap { e -> [UIAction] in
                if let a = e as? UIAction { return [a] }
                if let m = e as? UIMenu { return actions(m.children) }
                return []
            }
        }
        let menus = views(UIButton.self).filter { $0.menu != nil }
        for button in menus {
            if let action = actions(button.menu!.children).first(where: { $0.title == title }) {
                action.perform(NSSelectorFromString("performWithSender:target:"), with: button, with: nil)
                return "ok (menu action)"
            }
        }
        // SwiftUI fills the menu in only once it's opened, so open it the VoiceOver way, then run the item's action.
        let opened = activateWhere { ($0.accessibilityLabel ?? "").hasPrefix("Stage:") }
        try? await Task.sleep(for: .seconds(1))
        for button in views(UIButton.self) where button.menu != nil {
            if let action = actions(button.menu!.children).first(where: { $0.title == title }) {
                action.perform(NSSelectorFromString("performWithSender:target:"), with: button, with: nil)
                return "ok (opened: \(opened), then menu action)"
            }
        }
        return "FAIL menu opened (\(opened)) but no “\(title)” in it"
    }

    private static func activateWhere(_ match: (NSObject) -> Bool) -> String {
        var hit: NSObject?
        func walk(_ o: NSObject, _ depth: Int) {
            guard hit == nil, depth < 60 else { return }
            if match(o) { hit = o; return }
            if let v = o as? UIView { v.subviews.forEach { walk($0, depth + 1) } }
            for e in (o.accessibilityElements ?? []) { if let e = e as? NSObject { walk(e, depth + 1) } }
        }
        windows().forEach { walk($0, 0) }
        guard let hit else { return "not found" }
        return hit.accessibilityActivate() ? "ok (\(type(of: hit)))" : "found \(type(of: hit)) but wouldn't activate"
    }

    private static func topAlert() -> UIAlertController? {
        for w in windows() {
            var vc = w.rootViewController
            while let next = vc?.presentedViewController { vc = next }
            if let a = vc as? UIAlertController { return a }
        }
        return nil
    }
}
/// `-checkKL k|l|clue`: job sheets K (Dashboard as Panels) and L (Stable & Sandbox), done the way Aaron would tap them
/// (Rob, 31 Oct 2026). Taps go through accessibility, as VoiceOver's double tap does. One line per step goes to
/// Documents/Diagnostics/kl-<phase>.txt, ending in DONE. `l` ends by bringing one plugin back and writing KILL, so the
/// script can stop the app mid-session; `clue` is the relaunch after that.
@MainActor enum KLCheck {
    static func run(_ phase: String) async {
        let host = PipHost.shared
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "kl-\(phase).txt")
        var out: [String] = []
        func note(_ s: String) { out.append(s); try? out.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        func pause(_ s: Double = 1.0) async { try? await Task.sleep(for: .seconds(s)) }
        let watch = FrameWatch()
        watch.start()
        func meter() -> String { "\(watch.hitches) late · worst \(watch.worstMs) ms" }
        await pause(6)
        let orient = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.interfaceOrientation.isPortrait == true ? "portrait" : "landscape"
        note("start · \(phase) · \(orient) · Pip on: \(host.pipOn) · simpler: \(host.simpler) · paused: \(host.paused) · safe mode: \(host.safeMode)")

        switch phase {
        case "k": await k(host, note, pause, watch, meter)
        case "l": await l(host, note, pause, watch, meter)
        case "clue": await clue(host, note, pause)
        default: note("unknown phase")
        }
        note(phase == "l" ? "KILL" : "DONE")
    }

    // MARK: K · Dashboard as Panels

    static func k(_ host: PipHost, _ note: (String) -> Void, _ pause: (Double) async -> Void,
                  _ watch: FrameWatch, _ meter: () -> String) async {
        if host.paused { host.setPaused(false) }
        if !host.chosen("dashboard") { host.setOn("dashboard", true) }
        await pause(1)
        for turn in ["first", "second (other way round)"] {
            if turn != "first" {
                let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                let portrait = scene?.interfaceOrientation.isPortrait == true
                scene?.requestGeometryUpdate(.iOS(interfaceOrientations: portrait ? .landscapeLeft : .portrait))
                await pause(2.5)
                note("turned to \(scene?.interfaceOrientation.isPortrait == true ? "portrait" : "landscape")")
            }
            withAnimation(.easeOut(duration: 0.2)) { host.openCard = "dashboard" }
            await pause(1.5)
            watch.reset()
            note("Open as Panels: \(activate { $0 == "Open as Panels" })")
            await pause(2.2)
            note("  full screen shown: \(presented() != nil) · open: \(meter())")
            for s in Dashboard.PanelSection.allCases {
                watch.reset()
                let r = activate { $0 == s.title || $0.hasPrefix("\(s.title), ") }
                await pause(1.3)
                note("  \(s.title): \(r) · header shown: \(find { $0 == s.title && $1.contains(.header) } ? "yes" : "no") · \(meter())")
            }
            if turn == "first" {
                // Needs you: answer one, the count drops, Copy lights up; then take the answer back.
                _ = activate { $0.hasPrefix("Needs you") }
                await pause(1)
                let before = label { $0.hasPrefix("Needs you") } ?? "?"
                let first = Dashboard.Answer.allCases[0].label
                let tapped = activate { $0.hasPrefix("\(first): ") }
                await pause(1)
                let after = label { $0.hasPrefix("Needs you") } ?? "?"
                note("  answer “\(first)”: \(tapped) · sidebar \(before) → \(after)")
                UIPasteboard.general.string = ""
                note("  Copy for the dashboard: \(activate { $0 == "Copy for the dashboard" }) · pasteboard: \(UIPasteboard.general.string?.prefix(60).replacingOccurrences(of: "\n", with: " ⏎ ") ?? "")")
                await pause(0.6)
                _ = activate { $0.hasPrefix("\(first): ") }      // tap it again: answer taken back
                await pause(0.8)
                note("  answer taken back · sidebar \(label { $0.hasPrefix("Needs you") } ?? "?")")
            }
            watch.reset()
            note("  ✕ close: \(activate { $0 == "Close the dashboard" })")
            await pause(1.5)
            note("  full screen gone: \(presented() == nil) · close: \(meter())")
            withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
            await pause(1)
        }
        // Dashboard off: no tile, no button.
        host.setOn("dashboard", false)
        await pause(1.5)
        let bar = host.plugins.filter { $0.hasCard && host.isOn($0.info.id) }.map(\.info.id)
        host.openCard = "dashboard"
        await pause(1.2)
        note("Dashboard off: in the bar: \(bar.contains("dashboard")) · card opens anyway: \(find { l, _ in l == "Open as Panels" }) · app still running: yes")
        host.openCard = nil
        host.setOn("dashboard", true)
        await pause(1)
        note("Dashboard back on: \(host.isOn("dashboard"))")
    }

    // MARK: L · Stable & Sandbox

    static func l(_ host: PipHost, _ note: (String) -> Void, _ pause: (Double) async -> Void,
                  _ watch: FrameWatch, _ meter: () -> String) async {
        if host.paused { host.setPaused(false) }
        func on() -> Int { StableSwitch.onNow(host).count }
        func log() -> [String] { host.value("stable", "log") ?? [] }
        let startOn = on(), total = StableSwitch.ids(host).count
        let missing = StableSwitch.everyday.filter { id in !host.plugins.contains { $0.info.id == id } }
        note("plugins on at start: \(startOn) of \(total) · everyday ids not in the app: \(missing.isEmpty ? "none" : missing.joined(separator: ", "))")
        withAnimation(.easeOut(duration: 0.2)) { host.openCard = "stable" }
        await pause(1.5)
        note("card open: \(!host.panelFrame.isNull || !host.cardFrame.isNull)")

        note("Stable: \(activate { $0 == "Stable" }) · on now \(on()) · footer: \(label { $0.contains("plugins on.") } ?? "?")")
        await pause(1)
        note("Everything: \(activate { $0 == "Everything" }) · on now \(on()) (started with \(startOn))")
        await pause(1)

        // Make this my Stable: one more on (as if from the Plugin Desk), save, Everything, Stable again.
        _ = activate { $0 == "Stable" }; await pause(0.8)
        let extra = StableSwitch.waiting(host).first ?? "?"
        host.setOn(extra, true); await pause(0.5)
        note("Make this my Stable (with \(extra) added): \(activate { $0 == "Make this my Stable" })")
        await pause(0.8)
        _ = activate { $0 == "Everything" }; await pause(0.8)
        _ = activate { $0 == "Stable" }; await pause(0.8)
        note("  Everything → Stable: \(extra) kept on: \(host.chosen(extra)) · on now \(on())")

        // One at a time, from Stable.
        let stableCount = on()
        for i in 1...3 {
            let r = activate { $0.hasPrefix("Bring back: ") }
            await pause(0.8)
            note("  bring back #\(i): \(r) · on now \(on())")
        }
        note("  log ➕ lines: \(log().prefix(3).filter { $0.contains("➕") }.count) of 3")
        let last: String = host.value("stable", "lastAdded") ?? "?"
        note("  “… made it worse”: \(activate { $0.hasSuffix(" made it worse") }) · \(last) now on: \(host.chosen(last)) · ✗ in log: \(log().first?.contains("✗") == true)")
        await pause(0.8)

        // Rob's worry: after One at a time, Stable then Everything should still bring back the full set.
        _ = activate { $0 == "Stable" }; await pause(0.8)
        _ = activate { $0 == "Everything" }; await pause(0.8)
        note("  after One at a time: Stable → Everything gives \(on()) on (the full set was \(startOn); Stable had \(stableCount))")

        UIPasteboard.general.string = ""
        note("Copy for Jules: \(activate { $0 == "Copy for Jules" })")
        await pause(0.5)
        let paste = UIPasteboard.general.string ?? ""
        try? paste.write(to: URL.documentsDirectory.appending(path: "Diagnostics/kl-paste.txt"), atomically: true, encoding: .utf8)
        note("  paste: \(paste.split(separator: "\n").count) lines, starts “\(paste.prefix(45))”")
        withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
        await pause(1)

        // Dashboard: the Sandbox section.
        UserDefaults.standard.set(true, forKey: "plug.devfold.panel.dashboard.stable")
        withAnimation(.easeOut(duration: 0.2)) { host.openCard = "dashboard" }
        await pause(1.5)
        for view in MenuStress.scrollers() { view.setContentOffset(CGPoint(x: 0, y: max(0, view.contentSize.height - view.bounds.height)), animated: false) }
        await pause(1)
        note("Dashboard → Sandbox section: title \(find { l, _ in l.contains("Sandbox") }) · Stable \(find { l, _ in l == "Stable" }) · Everything \(find { l, _ in l == "Everything" })")
        withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
        await pause(1)

        // Pause all: can the card still be reached to say "everything is paused"?
        host.setPaused(true)
        await pause(1)
        host.openCard = "stable"
        await pause(1.2)
        note("Pause all: plugin bar shows \(find { l, _ in l.hasPrefix("Plugins paused") } ? "the paused pill" : "?") · Stable card can open: \(find { l, _ in l == "Make this my Stable" }) · “everything is paused” line seen: \(find { l, _ in l.hasPrefix("Everything is paused") })")
        host.openCard = nil
        host.setPaused(false)
        await pause(1)

        // For step 4: bring one back, then the script stops the app while it's open.
        StableSwitch.goStable(host)
        if let next = StableSwitch.waiting(host).first { StableSwitch.bringBack(next, host); note("brought back for the crash clue: \(next)") }
        await pause(1)
    }

    // MARK: L step 4 · the relaunch after a stop

    static func clue(_ host: PipHost, _ note: (String) -> Void, _ pause: (Double) async -> Void) async {
        note("suspect the card would name: \(StableSwitch.crashSuspect(host) ?? "none")")
        note("plugin bar: \(find { l, _ in l.hasPrefix("Plugins paused after a stop") } ? "paused pill “Plugins paused after a stop. Turn on”" : "no paused pill")")
        host.openCard = "stable"
        await pause(1.2)
        note("open the Stable card while paused: \(find { l, _ in l == "The app stopped last time" } ? "clue card shown" : "nothing opens, so the clue can't be seen")")
        host.openCard = nil
        note("tap “Turn on”: \(activate { $0.hasPrefix("Plugins paused after a stop") })")
        await pause(1.2)
        host.openCard = "stable"
        await pause(1.5)
        note("after Turn on · safe mode: \(host.safeMode) · suspect now: \(StableSwitch.crashSuspect(host) ?? "none") · clue card shown: \(find { l, _ in l == "The app stopped last time" })")
        host.openCard = nil
    }

    // MARK: Helpers

    static func elements() -> [(NSObject, String, UIAccessibilityTraits)] {
        var found: [(NSObject, String, UIAccessibilityTraits)] = []
        func walk(_ o: NSObject, _ depth: Int) {
            guard depth < 70 else { return }
            if let v = o as? UIView, v.isHidden || v.alpha < 0.01 { return }
            if let l = o.accessibilityLabel, !l.isEmpty { found.append((o, l, o.accessibilityTraits)) }
            if let v = o as? UIView { v.subviews.forEach { walk($0, depth + 1) } }
            for e in (o.accessibilityElements ?? []) { if let e = e as? NSObject { walk(e, depth + 1) } }
        }
        // While a full-screen view is up, look only at it (the plugin card underneath has some of the same labels).
        if let top = presented()?.view { walk(top, 0) } else {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).forEach { walk($0, 0) }
        }
        return found
    }

    static func activate(_ match: (String) -> Bool) -> String {
        guard let hit = elements().first(where: { match($0.1) }) else { return "FAIL not found" }
        return hit.0.accessibilityActivate() ? "ok" : "FAIL found “\(hit.1)” but it wouldn't tap"
    }

    static func find(_ match: (String, UIAccessibilityTraits) -> Bool) -> Bool { elements().contains { match($0.1, $0.2) } }
    static func label(_ match: (String) -> Bool) -> String? { elements().first { match($0.1) }?.1 }

    static func presented() -> UIViewController? {
        for w in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows) {
            if let p = w.rootViewController?.presentedViewController { return p }
        }
        return nil
    }
}
#endif
