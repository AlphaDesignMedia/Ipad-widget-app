import SwiftUI

// PIP NOTICES · plugin v1 (Dream). Pip notices when you change things and says so: a new colour (and Pip's
// glow blushes that colour), theme, light or dark, layout, liquid look, calmer motion. A pet feels alive when
// it notices, so this comes before tricks.
// Old-game thrift: one small table of lines per setting, picked so the same line never comes twice running;
// a short wait so a flurry of changes gets one remark; and never more than one remark every few seconds.
// Unlocks at Friendly on the bond ladder; each remark is a small gift to the bond.
// Where: no button; switch it off in Settings with the other plugins.

struct PipNotices: SandboxPlugin {
    let info = PluginInfo(id: "notices", name: "Pip Notices", version: "v1", shelf: .dream,
                          icon: "eye", what: "Pip notices when you change things, and says so.")

    // MARK: Data

    static let watched = ["appColor", "appTheme", "appAppearance", "interfaceStyle",
                          "plug.liquid.whole", "plug.liquid.runny", "simpleMotion"]
    static let settle = 0.8         // seconds of stillness before Pip remarks
    static let quiet = 5.0          // seconds between remarks, at least

    /// Pip's lines for a setting's new value. `name` is the colour's name.
    static func lines(_ key: String, _ value: String, name: String) -> [String] {
        switch (key, value) {
        case ("appColor", "auto"): ["Back to blue. Classic.", "Good old blue."]
        case ("appColor", _) where value.hasPrefix("#"):
            ["A colour all of your own. Fancy!", "Ooh, did you mix that yourself?"]
        case ("appColor", _): ["Ooh, \(name.lowercased())!", "\(name)? Good choice.", "\(name) suits you."]
        case ("appTheme", "glass"): ["Crystal clear.", "I can see right through it!"]
        case ("appTheme", "frosted"): ["Brr. Frosty!", "Nice and misty."]
        case ("appTheme", "colour"): ["So colourful!", "Ooh, painted glass."]
        case ("appTheme", "home"): ["Just like home.", "Matching your Home Screen. Smart."]
        case ("appAppearance", "dark"): ["Lights off!", "Ooh, spooky."]
        case ("appAppearance", "light"): ["Ah, sunshine.", "Bright and breezy."]
        case ("appAppearance", _): ["Whatever the sky says."]
        case ("interfaceStyle", _): ["New layout! Let me look around.", "Rearranging? I love that."]
        case ("plug.liquid.whole", "1"), ("plug.liquid.runny", _): ["Drippy!", "Splish splash."]
        case ("plug.liquid.whole", _): ["All dry again."]
        case ("simpleMotion", "1"): ["Taking it easy. Me too."]
        case ("simpleMotion", _): ["Wheee, moving again!"]
        default: []
        }
    }

    // MARK: Logic

    @MainActor final class Watch {
        var seen: [String: String] = [:]
        var observer: NSObjectProtocol?
        var tick = 0
        var lastRemark = Date.distantPast
        var lastLine = ""
    }
    @MainActor private static let watch = Watch()

    static func now() -> [String: String] {
        let store = UserDefaults.standard
        var values: [String: String] = [:]
        for key in watched {
            switch store.object(forKey: key) {
            case let b as Bool: values[key] = b ? "1" : "0"
            case let v?: values[key] = "\(v)"
            case nil: break
            }
        }
        return values
    }

    func start(_ host: PipHost) throws {
        let watch = Self.watch
        watch.seen = Self.now()
        guard watch.observer == nil else { return }
        watch.observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Self.changed(host) }
        }
    }

    static func changed(_ host: PipHost) {
        let values = now()
        guard values != watch.seen else { return }
        let key = watched.last { values[$0] != watch.seen[$0] }
        watch.seen = values
        guard let key, let value = values[key], host.isOn("notices") else { return }
        watch.tick += 1
        let mine = watch.tick
        host.later(settle) { if watch.tick == mine { remark(key, value, host) } }
    }

    static func remark(_ key: String, _ value: String, _ host: PipHost) {
        guard host.pipHere, !host.pipAsleep, host.unlocked(.friendly), Date.now.timeIntervalSince(watch.lastRemark) > quiet else { return }
        let colour = ClockColor(rawValue: value)
        let options = lines(key, value, name: colour?.name ?? "That").filter { $0 != watch.lastLine }
        guard let line = options.randomElement(), host.say(line, for: 2.4) else { return }
        watch.lastLine = line
        watch.lastRemark = .now
        if key == "appColor" { host.blush(AppColor.resolve(value)) }
        host.react(.curious, for: 0.8)       // squints at the new thing, then cheers
        host.later(0.8) { host.cheer() }
        host.befriend(0.03)
    }
}
