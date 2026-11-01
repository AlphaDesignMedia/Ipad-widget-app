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
        if let phase = UserDefaults.standard.string(forKey: "checkM") { Task { await MCheck.run(phase) } }
        if let phase = UserDefaults.standard.string(forKey: "checkO") { Task { await OCheck.run(phase) } }
        if let phase = UserDefaults.standard.string(forKey: "checkP") { Task { await PCheck.run(phase) } }
        if let phase = UserDefaults.standard.string(forKey: "checkQ") { Task { await QCheck.run(phase) } }
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
            note("Open the dashboard: \(activate { $0 == "Open the dashboard" })")
            await pause(2.2)
            note("  full screen shown: \(presented() != nil) · open: \(meter())")
            // 1 Nov: the sidebar sections became fold-up widgets (sheet P). Fold and unfold each once, so it ends as it began.
            for title in ["At a glance", "Builds", "Needs you", "Live feed", "Up next", "Ideas", "Reminders", "How we work"] {
                watch.reset()
                let r1 = activate { $0 == title || $0.hasPrefix("\(title), ") }
                await pause(0.8)
                let r2 = activate { $0 == title || $0.hasPrefix("\(title), ") }
                await pause(0.8)
                note("  \(title) fold + unfold: \(r1)/\(r2) · \(meter())")
            }
            if turn == "first" {
                // Needs you (starts open): answer one, the count drops, Copy lights up; then take the answer back.
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
        note("Dashboard off: in the bar: \(bar.contains("dashboard")) · card opens anyway: \(find { l, _ in l == "Open the dashboard" }) · app still running: yes")
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
/// `-checkM peek|peekoff|hello|clue2`: job sheet M (Rob, 31 Oct 2026). Pip Peek: peek, tap, tuck away, mirror, pop-up card,
/// Version 1, Pause all, the card's tiny check and "Show me now", the hello on launch; frames with Peek on and off. `clue2` is
/// L's crash clue after Jules's fix. Lines go to Documents/Diagnostics/m-<phase>.txt, pictures to m-<name>.png.
@MainActor enum MCheck {
    static func run(_ phase: String) async {
        let host = PipHost.shared
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "m-\(phase).txt")
        var out: [String] = []
        func note(_ s: String) { out.append(s); try? out.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        func peeking() -> Bool { KLCheck.find { l, _ in l == "Pip, peeking" } }
        let watch = FrameWatch()
        watch.start()
        func meter() -> String { "\(watch.hitches) late · worst \(watch.worstMs) ms" }
        let tag = "Pip on: \(host.pipOn) · simpler: \(host.simpler) · peek on: \(host.chosen("peek")) · hello setting: \(host.value("peek", "hello") ?? true)"

        if phase == "hello" {
            await pause(2.8)
            note("start · hello · \(tag)")
            note("2.8 s after opening · Pip peeking in: \(peeking())")
            snap("hello-\(host.value("peek", "hello") ?? true ? "on" : "off")")
            await pause(4.5)
            note("7.3 s after opening · still there: \(peeking())")
            note("DONE")
            return
        }
        await pause(6)
        note("start · \(phase) · \(tag) · paused: \(host.paused) · safe mode: \(host.safeMode) · suspect: \(StableSwitch.crashSuspect(host) ?? "none")")
        if host.paused { host.setPaused(false) }

        switch phase {
        case "peek", "peekoff":
            for id in ["sketch", "dashboard", "ideainbox"] {
                watch.reset()
                withAnimation(.easeOut(duration: 0.2)) { host.openCard = id }
                await pause(2.2)
                note("\(id) open · peeking: \(peeking()) · \(meter())")
                snap("\(phase)-\(id)-\(host.pipOn ? "pip" : "nopip")\(host.simpler ? "-calm" : "")")
                if id == "sketch", peeking(), phase == "peek" {
                    note("  tap Pip: \(KLCheck.activate { $0 == "Pip, peeking" })")
                    await pause(0.7)
                    snap("peek-tapped\(host.simpler ? "-calm" : "")")
                    await pause(3.2)
                    snap("peek-back")
                    await pause(10.5)
                    snap("peek-tucked")
                    note("  tapped, back, and 10 s later tucked: see m-peek-tapped / -back / -tucked")
                }
                withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
                await pause(1)
            }
            guard phase == "peek", host.pipOn, !host.simpler else { break }
            // The panel on the other side: Pip mirrored.
            let side = UserDefaults.standard.object(forKey: "plugPanelLeading")
            UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "plugPanelLeading"), forKey: "plugPanelLeading")
            host.openCard = "sketch"; await pause(2.2)
            note("panel on the other side · peeking: \(peeking())"); snap("peek-mirrored")
            host.openCard = nil; await pause(1)
            UserDefaults.standard.set(side, forKey: "plugPanelLeading")
            // A pop-up card.
            host.openCard = "desk"; await pause(2.2)
            note("pop-up card (Plugin Desk) · width \(Int(host.cardFrame.width)) · peeking: \(peeking())"); snap("peek-desk")
            host.openCard = nil; await pause(1)
            // Version 1.
            UserDefaults.standard.set(1, forKey: "plug.peek.version")
            host.openCard = "sketch"; await pause(2.2)
            note("Version 1 · peeking: \(peeking()) (should be false)")
            host.openCard = nil; await pause(1)
            UserDefaults.standard.set(2, forKey: "plug.peek.version")
            host.openCard = "sketch"; await pause(2.2)
            note("Version 2 again · peeking: \(peeking())")
            host.openCard = nil; await pause(1)
            // Pause all.
            host.setPaused(true); await pause(1)
            host.openCard = "sketch"; await pause(2.2)
            note("Pause all · peeking: \(peeking()) (should be false)")
            host.openCard = nil; host.setPaused(false); await pause(1.5)
            // The card: tiny check, Show me now.
            host.openCard = "peek"; await pause(1.5)
            snap("peek-card")
            note("card: \(KLCheck.find { l, _ in l.hasPrefix("Aaron's Pip, large") } ? "tiny check shown" : "tiny check missing") · Show me now: \(KLCheck.activate { $0 == "Show me now" })")
            await pause(2.0)
            note("  hello showing: \(peeking())"); snap("peek-showmenow")
            await pause(4.5)
            note("  hello gone after 4 s: \(!peeking())")
        case "clue2":
            func log() -> [String] { host.value("stable", "log") ?? [] }
            // run() already turned plugins on above, the same as tapping "Turn on".
            await pause(1.5)
            host.openCard = "stable"; await pause(1.8)
            note("after Turn on · suspect: \(StableSwitch.crashSuspect(host) ?? "none") · card “The app stopped last time”: \(KLCheck.find { l, _ in l == "The app stopped last time" }) · text: \(KLCheck.label { $0.hasPrefix("Last one brought back") } ?? "missing")")
            note("  log top: \(log().first ?? "")")
            snap("clue-card")
            note("  Not this one: \(KLCheck.activate { $0 == "Not this one" }) · suspect now: \(StableSwitch.crashSuspect(host) ?? "none")")
            host.openCard = nil; await pause(1)
            let lines = log().count
            host.setPaused(true); await pause(1.2); host.setPaused(false); await pause(1.5)
            note("Pause all → un-pause, same session · suspect: \(StableSwitch.crashSuspect(host) ?? "none") · new ⚠️ lines: \(log().prefix(max(0, log().count - lines)).filter { $0.contains("⚠️") }.count)")
        default: note("unknown phase")
        }
        note("DONE")
    }

    /// A picture of the app as it is now, into Diagnostics.
    static func snap(_ name: String) {
        guard let w = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return }
        let img = UIGraphicsImageRenderer(bounds: w.bounds).image { _ in w.drawHierarchy(in: w.bounds, afterScreenUpdates: true) }
        try? img.pngData()?.write(to: URL.documentsDirectory.appending(path: "Diagnostics/m-\(name).png"))
    }
}
/// `-checkO live`: job sheet O+ (Rob, 1 Nov 2026). Dashboard live feed: footer wording, the Live board card's
/// four numbers, then "Follow the live dashboard" off and back on. Lines go to Documents/Diagnostics/o-live.txt,
/// pictures to m-o-<name>.png.
@MainActor enum OCheck {
    static func run(_ phase: String) async {
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "o-\(phase).txt")
        var out: [String] = []
        func note(_ s: String) { out.append(s); try? out.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        func footer() -> String {
            KLCheck.label { ["Live ·", "Checking", "Couldn't reach", "Updated", "Snapshot"].contains(where: $0.contains) } ?? "no footer found"
        }
        func numbers() -> String {
            let hits = KLCheck.elements().map(\.1).filter { l in ["Need you", "To try", "Up next", "Done"].contains(where: l.contains) }
            return hits.isEmpty ? "no Live board numbers" : hits.prefix(6).joined(separator: " | ")
        }
        let host = PipHost.shared
        await pause(6)
        if host.paused { host.setPaused(false) }
        note("start · live switch: \(Dashboard.Feed.shared.on)")
        host.openCard = "dashboard"; await pause(6)
        note("open · footer: \(footer())")
        note("  live board: \(numbers())")
        note("  headline: \(Dashboard.Feed.shared.data.status?.headline?.prefix(80) ?? "none")")
        note("  board from: \(Dashboard.Feed.shared.data.syncedAt ?? "?") · source: \(Dashboard.Feed.shared.data.source ?? "?")")
        MCheck.snap("o-on")
        note("switch off: \(KLCheck.activate { $0.hasPrefix("Follow the live dashboard") })"); await pause(1.5)
        note("  live switch: \(Dashboard.Feed.shared.on) · footer: \(footer())")
        MCheck.snap("o-off")
        note("switch on: \(KLCheck.activate { $0.hasPrefix("Follow the live dashboard") })"); await pause(5)
        note("  live switch: \(Dashboard.Feed.shared.on) · footer: \(footer())")
        if !Dashboard.Feed.shared.on { Dashboard.Feed.shared.on = true }
        host.openCard = nil
        note("DONE")
    }
}
/// `-checkP grid`: job sheet P (Rob, 1 Nov 2026). The one dashboard: columns in landscape and portrait, cards follow the
/// clock colour, fold / unfold, live feed off → footer says off, headline from the private board, 2-vs-5 need you.
/// Lines go to Documents/Diagnostics/p-grid.txt, pictures to m-p-<name>.png. Never logs the private board's address.
@MainActor enum PCheck {
    static func run(_ phase: String) async {
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "p-\(phase).txt")
        var out: [String] = []
        func note(_ s: String) { out.append(s); try? out.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        let feed = Dashboard.Feed.shared
        let host = PipHost.shared
        func footer() -> String {
            KLCheck.label { ["Live ·", "Checking", "Couldn't reach", "Updated", "Snapshot", "live feed off"].contains(where: $0.contains) } ?? "no footer found"
        }
        /// The three column titles and where they sit: 3 different x = 3 columns, same x = 1 column.
        func columns() -> String {
            let heads = KLCheck.elements().filter { ["STATUS", "ACTIONS", "DIRECTION"].contains($0.1) }
            let xs = Set(heads.map { Int(($0.0 as? UIView)?.accessibilityFrame.minX ?? $0.0.accessibilityFrame.minX) })
            let width = Int(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.width ?? 0)
            return "\(xs.count) column\(xs.count == 1 ? "" : "s") (\(heads.count) titles found, screen \(width) pt wide)"
        }
        func widget(_ title: String) -> (NSObject, String)? {
            KLCheck.elements().first { $0.1 == title || $0.1.hasPrefix(title + ", ") }.map { ($0.0, $0.0.accessibilityValue ?? "?") }
        }
        func rotate(_ o: UIInterfaceOrientationMask) async -> String {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return "no scene" }
            var err = "ok"
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: o)) { e in err = "FAIL \(e.localizedDescription)" }
            await pause(2.5)
            return err
        }

        await pause(6)
        if host.paused { host.setPaused(false) }
        if !feed.on { feed.on = true }
        note("start · private board file packed in: \(Dashboard.Feed.boardBase != nil ? "yes" : "NO") (address not logged)")
        feed.refresh(force: true); await pause(7)
        let d = feed.data
        note("feed · source: \(d.source ?? "?") · board from: \(d.syncedAt ?? "?")")
        note("  headline: \(d.status?.headline?.prefix(90) ?? "none")")
        let asks = d.needsYou ?? []
        let waiting = asks.filter { Dashboard.answer($0.q, host) == nil }.count
        note("  need you: live board \(d.live?.needYou.map(String.init) ?? "–") · board.json questions \(asks.count) · unanswered on this iPad \(waiting)")

        host.openCard = "dashboard"; await pause(4)
        note("side card · footer: \(footer())")
        MCheck.snap("p-side")
        note("open the dashboard: \(KLCheck.activate { $0 == "Open the dashboard" })"); await pause(3)
        note("  full screen up: \(KLCheck.presented() != nil)")
        note("  footer: \(footer())")
        note("landscape: \(await rotate(.landscapeRight)) · \(columns())")
        MCheck.snap("p-landscape")
        note("portrait: \(await rotate(.portrait)) · \(columns())")
        MCheck.snap("p-portrait")
        note("back to landscape: \(await rotate(.landscapeRight)) · \(columns())")

        // Fold / unfold, on Builds (starts folded).
        if let (_, v) = widget("Builds") {
            note("fold · Builds starts: \(v)")
            note("  tap: \(KLCheck.activate { $0 == "Builds" || $0.hasPrefix("Builds, ") })"); await pause(1)
            note("  now: \(widget("Builds")?.1 ?? "gone") · content shown: \(KLCheck.find { l, _ in l.contains("Build") && !l.hasPrefix("Builds") })")
            note("  tap again: \(KLCheck.activate { $0 == "Builds" || $0.hasPrefix("Builds, ") })"); await pause(1)
            note("  now: \(widget("Builds")?.1 ?? "gone")")
        } else { note("fold · FAIL no Builds widget") }

        // Live feed off → footer.
        let wasOpen = widget("Live feed")?.1 == "open"
        if !wasOpen { _ = KLCheck.activate { $0.hasPrefix("Live feed") }; await pause(1) }
        note("live feed off: \(KLCheck.activate { $0.hasPrefix("Follow the live dashboard") })"); await pause(1.5)
        note("  switch: \(feed.on) · widget: \(widget("Live feed")?.0.accessibilityLabel ?? "?") · footer: \(footer())")
        MCheck.snap("p-off")
        note("live feed on: \(KLCheck.activate { $0.hasPrefix("Follow the live dashboard") })"); await pause(6)
        note("  switch: \(feed.on) · footer: \(footer())")
        if !feed.on { feed.on = true }
        if !wasOpen { _ = KLCheck.activate { $0.hasPrefix("Live feed") }; await pause(1) }

        // Clock colour → cards follow on the next open.
        let saved = ClockStyle.load()
        var red = saved; red.color = .red; red.save()
        note("clock colour: \(saved.color.rawValue) → red; close and reopen")
        _ = KLCheck.activate { $0 == "Close the dashboard" }; await pause(2)
        _ = KLCheck.activate { $0 == "Open the dashboard" }; await pause(3)
        MCheck.snap("p-red")
        saved.save()
        note("  pictured (m-p-red.png); colour put back to \(ClockStyle.load().color.rawValue)")
        _ = KLCheck.activate { $0 == "Close the dashboard" }; await pause(2)
        _ = KLCheck.activate { $0 == "Open the dashboard" }; await pause(3)
        MCheck.snap("p-back")
        _ = KLCheck.activate { $0 == "Close the dashboard" }; await pause(2)
        host.openCard = nil
        note("DONE")
    }
}

/// `-checkQ tab`: job sheet Q (Rob, 1 Nov 2026). Dashboard as a tab: the top switch, Classic and Panels as before,
/// both ways in, off / Pause all / Safe mode fall back, the bottom widgets clear of the plugin bar, tab-switch frames.
/// Lines go to Documents/Diagnostics/q-tab.txt, pictures to m-q-<name>.png.
@MainActor enum QCheck {
    static func run(_ phase: String) async {
        let folder = URL.documentsDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "q-\(phase).txt")
        var out: [String] = []
        func note(_ s: String) { out.append(s); try? out.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8) }
        func pause(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        let host = PipHost.shared
        let watch = FrameWatch()
        func meter() -> String { "\(watch.hitches) late · worst \(watch.worstMs) ms" }
        let tabs = ["Classic", "Panels", "Dashboard"]
        func topBar() -> String {
            let found = KLCheck.elements().filter { tabs.contains($0.1) && $0.0.accessibilityFrame.minY < 120 }.map(\.1)
            return found.isEmpty ? "none found" : Array(Set(found)).sorted().joined(separator: " · ")
        }
        func pick(_ t: String) -> String { KLCheck.activate { $0 == t } }
        func screen() -> String { host.activeScreen?.info.id ?? "none" }
        /// Buttons along the top bar, to compare Classic/Panels before and after.
        func toolbar() -> [String] {
            KLCheck.elements().filter { $0.2.contains(.button) && $0.0.accessibilityFrame.minY < 100 && !tabs.contains($0.1) }
                .map(\.1).sorted()
        }
        let groupTitles = ["At a glance", "Builds", "Stable & Sandbox", "Busy Pip", "Needs you", "For Rob", "Dashboard queue",
                           "Next action", "Up next", "Ideas", "Reminders", "How we work"]
        func isGroup(_ l: String) -> Bool { groupTitles.contains { l == $0 || l.hasPrefix($0 + ", ") } }
        /// The group rows found (the pill), and which one wears the bead.
        func groups() -> (found: [String], chosen: String) {
            let rows = KLCheck.elements().filter { isGroup($0.1) && !$0.1.contains(" widget") && $0.2.contains(.button) }
            let chosen = rows.first { $0.2.contains(.selected) }?.1 ?? "none"
            return (rows.map(\.1), chosen)
        }
        func views(_ v: UIView) -> [UIView] { [v] + v.subviews.flatMap(views) }
        /// The settings-style column: the tallest scroller on screen.
        func column() -> UIScrollView? {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).flatMap { views($0) }
                .compactMap { $0 as? UIScrollView }.filter { $0.contentSize.height > $0.bounds.height + 50 }
                .max { $0.contentSize.height < $1.contentSize.height }
        }
        /// The Home Screen widgets on the stage: name, size and where they sit.
        func widgets() -> [(obj: NSObject, label: String, frame: CGRect)] {
            KLCheck.elements().filter { $0.1.contains(" widget") && ($0.0.accessibilityHint ?? "").hasPrefix("Shows the full card") }
                .map { ($0.0, $0.1, $0.0.accessibilityFrame) }
        }
        func describe(_ w: [(obj: NSObject, label: String, frame: CGRect)]) -> String {
            w.map { "\($0.label.components(separatedBy: ":").first ?? $0.label) @\(Int($0.frame.minX)),\(Int($0.frame.minY)) \(Int($0.frame.width))×\(Int($0.frame.height))" }
                .joined(separator: " | ")
        }
        /// Runs a widget's "Make it …" action, as VoiceOver would.
        func resize(_ name: String, to size: String) -> String {
            guard let w = widgets().first(where: { $0.label.hasPrefix(name + ", ") }) else { return "FAIL no \(name) widget" }
            guard let a = (w.obj.accessibilityCustomActions ?? []).first(where: { $0.name == "Make it \(size)" }) else {
                return "no “Make it \(size)” (actions: \((w.obj.accessibilityCustomActions ?? []).map(\.name).joined(separator: ", ")))"
            }
            return (a.actionHandler?(a) ?? false) ? "ok" : "handler said no"
        }
        await pause(6)
        if host.paused { host.setPaused(false) }
        if phase == "size" {
            host.openScreen = "dashboard"; await pause(3)
            note("after relaunch · sizes saved: \(UserDefaults.standard.string(forKey: Dashboard.sizesKey) ?? "none")")
            note("  widgets: \(describe(widgets()))")
            let orig = UserDefaults.standard.string(forKey: "rob.q.sizesBefore") ?? ""
            if orig.isEmpty { UserDefaults.standard.removeObject(forKey: Dashboard.sizesKey) } else { UserDefaults.standard.set(orig, forKey: Dashboard.sizesKey) }
            UserDefaults.standard.removeObject(forKey: "rob.q.sizesBefore")
            note("  sizes put back"); host.openScreen = nil
            note("DONE"); return
        }
        if !host.chosen("dashboard") { host.setOn("dashboard", true) }
        await pause(1)
        let startTab = UserDefaults.standard.string(forKey: "interfaceStyle") ?? "?"
        note("start · interface \(startTab) · top bar: \(topBar())")
        _ = pick("Panels"); await pause(2)
        let panelsBar = toolbar(); MCheck.snap("q-panels-before")
        _ = pick("Classic"); await pause(2)
        let classicBar = toolbar(); MCheck.snap("q-classic-before")
        note("toolbar · Classic: \(classicBar.joined(separator: ", "))")
        note("toolbar · Panels: \(panelsBar.joined(separator: ", "))")

        watch.reset(); note("tap Dashboard: \(pick("Dashboard"))"); await pause(2.5)
        let width = Int(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.width ?? 0)
        let g = groups()
        note("  screen: \(screen()) · \(meter()) · screen \(width) pt wide")
        note("  groups (\(g.found.count)): \(g.found.joined(separator: " · ")) · bead on: \(g.chosen)")
        note("  names shown: \(g.found.contains { !$0.isEmpty }) · stage widget: \(KLCheck.elements().contains { $0.0.accessibilityHint == "Shows what needs you" || $0.0.accessibilityHint == "Shows the glance" })")
        note("  footer: \(KLCheck.label { $0.contains("Live ·") || $0.contains("last checked") || $0.contains("Checking") } ?? "none")")
        note("  For Rob: \(KLCheck.label { $0.hasPrefix("To do, ") || $0.hasPrefix("Done, ") }?.prefix(70) ?? "not shown")")
        MCheck.snap("q-tab")
        // Home Screen widgets (ff78d22).
        let w0 = widgets()
        note("home · \(w0.count) widgets: \(describe(w0))")
        let xs = Set(w0.map { Int($0.frame.minX) }).sorted(), ws = Set(w0.map { Int($0.frame.width) }).sorted()
        note("  columns at x \(xs) · widths \(ws) (Small:Medium should be about 170:378.5)")
        for name in ["Needs you", "Up next", "Ideas"] {
            let hit = w0.first { $0.label.hasPrefix(name + ", ") }
            note("tap widget \(name): \(hit.map { $0.obj.accessibilityActivate() ? "ok" : "wouldn't tap" } ?? "not found")"); await pause(1.3)
            note("  bead on: \(groups().chosen)")
        }
        let before = UserDefaults.standard.string(forKey: Dashboard.sizesKey) ?? ""
        UserDefaults.standard.set(before, forKey: "rob.q.sizesBefore")
        let upSize = w0.first { $0.label.hasPrefix("Up next, ") }?.label.components(separatedBy: ", ").dropFirst().first ?? "?"
        let to = upSize.hasPrefix("Small") ? "Large" : "Small"
        watch.reset(); note("resize Up next (\(upSize)) → \(to): \(resize("Up next", to: to))"); await pause(1.5)
        note("  \(meter()) · now: \(describe(widgets()))")
        MCheck.snap("q-resized")
        // Needs you: answer one in the column → the widget's count drops; then take it back.
        let needs = { widgets().first { $0.label.hasPrefix("Needs you, ") }?.label.components(separatedBy: ". ").first ?? "?" }
        let n0 = needs()
        let first = Dashboard.Answer.allCases[0].label
        _ = KLCheck.activate { $0 == "Needs you" || ($0.hasPrefix("Needs you, ") && !$0.contains(" widget")) }; await pause(1.2)
        let tapped = KLCheck.activate { $0.hasPrefix("\(first): ") }; await pause(1)
        note("answer “\(first)”: \(tapped) · widget \(n0) → \(needs())")
        _ = KLCheck.activate { $0.hasPrefix("\(first): ") }; await pause(0.8)
        note("  taken back · widget \(needs())")

        // Tap a group → the column glides to it.
        let y0 = column()?.contentOffset.y ?? -1
        watch.reset(); note("tap group Up next: \(KLCheck.activate { $0 == "Up next" || $0.hasPrefix("Up next, ") })"); await pause(1.5)
        note("  column moved \(Int(y0)) → \(Int(column()?.contentOffset.y ?? -1)) · bead on: \(groups().chosen) · \(meter())")
        MCheck.snap("q-upnext")
        // Scroll → the bead follows.
        if let c = column() {
            c.setContentOffset(CGPoint(x: 0, y: max(0, c.contentSize.height - c.bounds.height)), animated: false); await pause(1.2)
            note("scroll column to the end · bead on: \(groups().chosen)")
            c.setContentOffset(.zero, animated: false); await pause(1.2)
            note("scroll column to the top · bead on: \(groups().chosen)")
        } else { note("scroll · FAIL no column scroller") }
        // Tap the stage widget → Needs you.
        let w = KLCheck.elements().first { $0.0.accessibilityHint == "Shows what needs you" || $0.0.accessibilityHint == "Shows the glance" }
        note("tap the widget: \(w.map { $0.0.accessibilityActivate() ? "ok" : "wouldn't tap" } ?? "not found")"); await pause(1.5)
        note("  bead on: \(groups().chosen)")
        // Reduce Transparency (the app's own switch) and the glass amount: pictures to compare.
        let glass = UserDefaults.standard.object(forKey: "glassAmount")
        UserDefaults.standard.set(true, forKey: "reduceGlass"); await pause(1.2); MCheck.snap("q-reduceglass")
        UserDefaults.standard.set(false, forKey: "reduceGlass")
        for amount in [0.0, 1.0] {
            UserDefaults.standard.set(amount, forKey: "glassAmount"); await pause(1.2); MCheck.snap("q-glass-\(Int(amount))")
        }
        if let glass { UserDefaults.standard.set(glass, forKey: "glassAmount") } else { UserDefaults.standard.removeObject(forKey: "glassAmount") }
        note("glass: pictured reduce-glass on, glass amount 0 and 1; put back")

        watch.reset(); _ = pick("Panels"); await pause(2)
        note("back to Panels: screen \(screen()) · \(meter()) · toolbar same: \(toolbar() == panelsBar)")
        MCheck.snap("q-panels-after")
        watch.reset(); _ = pick("Classic"); await pause(2)
        note("back to Classic: screen \(screen()) · \(meter()) · toolbar same: \(toolbar() == classicBar)")
        MCheck.snap("q-classic-after")

        // Ways in.
        host.openCard = "dashboard"; await pause(2)
        note("way in 1 · card → Open the dashboard: \(KLCheck.activate { $0 == "Open the dashboard" })"); await pause(2)
        note("  screen: \(screen()) · card still open: \(host.openCard ?? "no")")
        host.openScreen = nil; host.openCard = nil; await pause(1.5)
        let tile = KLCheck.elements().first { $0.1.hasPrefix("Progress dashboard") }
        note("way in 2 · canvas tile found: \(tile != nil) · tap: \(tile.map { $0.0.accessibilityActivate() ? "ok" : "wouldn't tap" } ?? "–")"); await pause(2)
        note("  screen: \(screen())")

        // Canvas tile: put away, then back (eec7060).
        host.openScreen = nil; _ = pick("Classic"); await pause(2)
        if let t = KLCheck.elements().first(where: { $0.1.hasPrefix("Progress dashboard") }) {
            let a = (t.0.accessibilityCustomActions ?? []).first { $0.name == "Put away" }
            note("tile · Put away: \(a.map { ($0.actionHandler?($0) ?? false) ? "ok" : "said no" } ?? "no action") ")
            await pause(1.2)
            note("  tile gone: \(!KLCheck.find { l, _ in l.hasPrefix("Progress dashboard") }) · saved: \(UserDefaults.standard.bool(forKey: "plug.dashboard.tileShown"))")
            MCheck.snap("q-tile-away")
            UserDefaults.standard.set(true, forKey: "plug.dashboard.tileShown"); await pause(1.2)
            note("  back with On the canvas: \(KLCheck.find { l, _ in l.hasPrefix("Progress dashboard") })")
        } else { note("tile · not on the canvas (On the canvas off?)") }

        // Fall backs.
        host.openScreen = "dashboard"; await pause(1.5)
        host.setOn("dashboard", false); await pause(2)
        note("Dashboard off: screen \(screen()) · top bar: \(topBar())")
        MCheck.snap("q-off")
        host.setOn("dashboard", true); await pause(1.5)
        host.openScreen = "dashboard"; await pause(1.5)
        host.setPaused(true); await pause(2)
        note("Pause all: screen \(screen()) · top bar: \(topBar())")
        host.setPaused(false); await pause(1.5)
        note("resume: screen \(screen()) (openScreen kept: \(host.openScreen ?? "nil")) · top bar: \(topBar())")
        host.openScreen = nil; await pause(1)

        // Tab-switch stress: 3 rounds of Classic → Dashboard → Panels → Dashboard.
        for r in 1...3 {
            var row: [String] = []
            for t in ["Dashboard", "Panels", "Dashboard", "Classic"] {
                watch.reset(); _ = pick(t); await pause(1.6); row.append("\(t) \(meter())")
            }
            note("switch round \(r): " + row.joined(separator: " | "))
        }
        _ = pick(startTab == "classic" ? "Classic" : "Panels")
        note("DONE")
    }
}

#endif
