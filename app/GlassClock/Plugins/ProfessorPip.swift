import SwiftUI
import UIKit
import os

// PROFESSOR PIP · plugin v1 (On trial). Debug mode, but make it nerdy. Switch on Lab mode and Pip puts on
// glasses and opens a tiny laptop, and a small readout shows the last thing Pip noticed. The card is the
// lab notebook: the device, the app, every plugin's state (and why any were switched off), Pip's recent
// events, and a bug report you write in plain words. "Send to the developer" bundles it all into one message
// for AirDrop, Messages or AGENT-NOTES.md. Everything stays on the device until you send it.
// Where: the laptop button in the plugin bar.

struct ProfessorPip: SandboxPlugin {
    let info = PluginInfo(id: "prof", name: "Professor Pip", version: "v1", shelf: .trial,
                          icon: "laptopcomputer", what: "Debug mode: Pip in glasses checks the app and helps you send a bug report.")

    // MARK: Data

    enum Severity: String, CaseIterable {
        case odd, annoying, broken, crash
        var label: String { rawValue.capitalized }
    }

    enum Lines {
        static let labOn = ["Lab mode. Don't touch anything. Except everything. Science.", "Glasses on. Laptop open. Let's science."]
        static let labOff = "Lab closed. I'll miss my laptop."
        static let diagnostics = ["Running diagnostics…", "Checking the plugins…", "Consulting the rubber duck…"]
        static let allGood = ["All systems nominal. I've always wanted to say that.", "Everything checks out. Suspicious, honestly."]
        static func trouble(_ n: Int) -> String { "Found \(n) plugin\(n == 1 ? "" : "s") switched off for misbehaving. It's in the notebook." }
        static let sent = ["Report sent. I attached the logs. All of them. You're welcome.", "Off it goes. The developer will love this."]
        static let duck = "Rubber duck mode: explain the bug to me. I'm round and patient."
        static let quips = ["Hypothesis: it's a cache thing. It's always a cache thing.",
                            "Have you tried turning it off and on again? I'm contractually obliged to ask.",
                            "It works on my machine. I am the machine.",
                            "Fascinating."]
    }

    /// A label and a value, for the notebook's lists.
    struct Fact: Hashable {
        let name: String
        let value: String
    }

    /// One thing Pip noticed, for the notebook.
    struct Entry: Identifiable {
        let id = UUID()
        let at: Date
        let what: String
    }

    // MARK: Logic

    @MainActor @Observable final class Lab {
        var entries: [Entry] = []
        var lastSeen = ""
        func note(_ what: String) {
            entries.insert(Entry(at: .now, what: what), at: 0)
            if entries.count > 40 { entries.removeLast() }
            lastSeen = what
        }
    }
    private let lab = Lab()

    static func labOn(_ host: PipHost) -> Bool { host.value("prof", "lab") ?? false }

    func start(_ host: PipHost) throws {
        lab.note("Professor Pip started")
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        lab.note(Self.describe(event))
    }

    nonisolated static func describe(_ event: PipEvent) -> String {
        switch event {
        case .appear: "Pip appeared"
        case .wake: "Pip woke up"
        case .tap: "Pip was tapped"
        case .flick(let speed): "Pip was flicked at \(Int(speed)) pt/s"
        case .bump(let speed): "Pip bumped an edge at \(Int(speed)) pt/s\(speed > 1150 ? " (dizzy)" : "")"
        case .rest: "Pip came to rest"
        }
    }

    /// The facts a developer asks for first.
    static func facts(_ host: PipHost) -> [Fact] {
        let device = UIDevice.current
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let size = scene?.coordinateSpace.bounds.size ?? .zero
        let free = Double(os_proc_available_memory()) / 1_048_576
        return [
            Fact(name: "App", value: "Pip Sandbox \(version) (\(build))"),
            Fact(name: "Device", value: "\(device.model), \(device.systemName) \(device.systemVersion)"),
            Fact(name: "Window", value: "\(Int(size.width)) × \(Int(size.height)) pt"),
            Fact(name: "Memory left", value: free > 0 ? "\(Int(free)) MB" : "unknown"),
            Fact(name: "Pip", value: host.pipOn ? (host.pipHere ? (host.pipAsleep ? "here, asleep" : "here, awake") : "on, not shown yet") : "switched off"),
            Fact(name: "Less motion", value: host.simpler ? "on" : "off"),
            Fact(name: "Plugins", value: "\(host.plugins.filter { host.isOn($0.info.id) }.count) of \(host.plugins.count) on"),
        ]
    }

    /// Plugins the host switched off, with its reason.
    static func troubles(_ host: PipHost) -> [Fact] {
        host.plugins.compactMap { p in host.broken[p.info.id].map { Fact(name: p.info.name, value: $0) } }
    }

    /// The whole report as one message.
    static func report(_ host: PipHost, entries: [Entry], what: String, steps: String, severity: Severity) -> String {
        var l = ["## Bug report · \(Date.now.formatted(date: .abbreviated, time: .shortened)) · from Professor Pip", ""]
        l.append("**What happened (\(severity.label)):** \(what.isEmpty ? "(not written)" : what)")
        if !steps.isEmpty { l.append("**Steps:** \(steps)") }
        l.append("")
        l.append("**Facts:**")
        l += facts(host).map { "- \($0.name): \($0.value)" }
        let off = host.plugins.filter { !host.isOn($0.info.id) }.map(\.info.name)
        if !off.isEmpty { l.append("- Plugins off: \(off.joined(separator: ", "))") }
        let t = troubles(host)
        if !t.isEmpty {
            l.append("")
            l.append("**Switched off by the host:**")
            l += t.map { "- \($0.name): \($0.value)" }
        }
        l.append("")
        l.append("**Pip's last events (newest first):**")
        let time = Date.FormatStyle.dateTime.hour().minute().second()
        l += entries.prefix(12).map { "- \($0.at.formatted(time)) \($0.what)" }
        return l.joined(separator: "\n")
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Goggles(host: host, lab: lab) }

    func card(_ host: PipHost) -> some View { Notebook(plugin: self, host: host, lab: lab) }

    /// Glasses and a little laptop on Pip, and a readout of the last event, while Lab mode is on.
    struct Goggles: View {
        let host: PipHost
        let lab: Lab
        @AppStorage("plug.prof.lab") private var on = false

        var body: some View {
            if on {
                ZStack(alignment: .topLeading) {
                    if host.pipHere {
                        let p = host.pipPosition
                        HStack(spacing: 1.5) {
                            Circle().stroke(PipLook.eye, lineWidth: 1.6).frame(width: 9, height: 9)
                            Rectangle().fill(PipLook.eye).frame(width: 3, height: 1.4)
                            Circle().stroke(PipLook.eye, lineWidth: 1.6).frame(width: 9, height: 9)
                        }
                        .position(x: p.x, y: p.y - 2)
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PipLook.eye)
                            .position(x: p.x + 20, y: p.y + 16)
                    }
                    Label(lab.lastSeen.isEmpty ? "Lab mode" : lab.lastSeen, systemImage: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .semibold).monospaced())
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.leading, PluginBarLook.edge)
                        .padding(.top, 8)
                        .animation(host.simpler ? nil : .snappy, value: lab.lastSeen)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    struct Notebook: View {
        let plugin: ProfessorPip
        let host: PipHost
        let lab: Lab
        @AppStorage("plug.prof.lab") private var on = false
        @State private var what = ""
        @State private var steps = ""
        @State private var severity = Severity.annoying
        @State private var copied = false

        var body: some View {
            let report = ProfessorPip.report(host, entries: lab.entries, what: what, steps: steps, severity: severity)
            ScrollView {
                VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                    Toggle("Lab mode (glasses on)", isOn: $on)
                        .onChange(of: on) { _, v in host.say(v ? Lines.labOn.randomElement()! : Lines.labOff, for: 2.2) }

                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 3) {
                        ForEach(ProfessorPip.facts(host), id: \.self) { fact in
                            GridRow {
                                Text(fact.name).bold()
                                Text(fact.value).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    let troubles = ProfessorPip.troubles(host)
                    if !troubles.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Switched off for misbehaving", systemImage: "exclamationmark.triangle").bold()
                            ForEach(troubles, id: \.self) { t in Text("\(t.name): \(t.value)").foregroundStyle(.secondary) }
                        }
                    }

                    Button("Run diagnostics") { diagnose() }
                        .buttonStyle(PluginCardButton())
                        .disabled(!host.pipHere)

                    Text("Bug report").bold()
                    TextField("What went wrong?", text: $what, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.roundedBorder)
                        .onTapGesture { if what.isEmpty { host.say(Lines.duck, for: 2.6) } }
                    TextField("Steps to make it happen (optional)", text: $steps, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 6) {
                        ForEach(Severity.allCases, id: \.self) { s in
                            Button(s.label) { severity = s }
                                .buttonStyle(PluginCardButton(on: severity == s))
                                .accessibilityAddTraits(severity == s ? .isSelected : [])
                        }
                    }
                    HStack(spacing: 6) {
                        ShareLink(item: report) {
                            Label("Send to the developer", systemImage: "paperplane")
                        }
                        .buttonStyle(PluginCardButton(on: true))
                        .simultaneousGesture(TapGesture().onEnded { host.say(Lines.sent.randomElement()!, for: 2.4) })
                        Button(copied ? "Copied" : "Copy") {
                            UIPasteboard.general.string = report
                            copied = true
                            host.later(2) { copied = false }
                        }
                        .buttonStyle(PluginCardButton())
                    }

                    Text("Pip's recent events").bold()
                    ForEach(lab.entries.prefix(8)) { e in
                        Text("\(e.at.formatted(.dateTime.hour().minute().second()))  \(e.what)")
                            .font(.system(size: 12).monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Text("Nothing leaves this iPad until you send it.").foregroundStyle(.secondary)
                }
            }
            .frame(maxHeight: 460)
            .font(.system(size: 13.5))
        }

        /// Pip mutters through a check, then gives the verdict.
        private func diagnose() {
            for (i, line) in Lines.diagnostics.enumerated() {
                host.later(Double(i) * 1.5) { host.say(line, for: 1.3) }
            }
            host.later(Double(Lines.diagnostics.count) * 1.5) {
                let n = ProfessorPip.troubles(host).count
                host.say(n == 0 ? Lines.allGood.randomElement()! : Lines.trouble(n), for: 2.8)
                lab.note("Diagnostics: \(n) problem\(n == 1 ? "" : "s")")
                if n == 0, Bool.random() { host.later(3.2) { host.say(Lines.quips.randomElement()!, for: 2.8) } }
            }
        }
    }
}
