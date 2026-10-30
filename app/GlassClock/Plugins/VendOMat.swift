import SwiftUI
import UIKit
import AudioToolbox

// VEND-O-MAT · plugin v1 (Dream). A chunky glass vending machine and a plain office bin.
// Four buttons: Moorside Brew (tea), Kettlecroft Roast (coffee), Rubbish (can, crumpled note or banana skin)
// and Mystery. Things drop into the tray with a thunk. PINCH a bit of rubbish to crush it, then FLICK it
// at the bin. A hit gives the bin a little "clonk" and wobble; three hits in a row make it do a tiny dance.
// A miss bounces on the floor and lies there.
// Pip (only if they're on): tea cheers up a sulking Pip, coffee makes them zippy for a minute (Joy 3 and up),
// and they rarely say "Shot!" (3 times a session at most at calm, and only when it's their turn).
// Pip off: everything still works, there are just no Pip reactions. Simpler motion: fades, no movement.
// Where: the "Vend-O-Mat" button in the plugin bar.

struct VendOMat: SandboxPlugin {
    let info = PluginInfo(id: "vendomat", name: "Vend-O-Mat", version: "v1", shelf: .dream,
                          icon: "takeoutbag.and.cup.and.straw",
                          what: "A glass vending machine and a bin. Crush the rubbish, flick it in.")

    // MARK: Tune (feel numbers, in one place so they can be dialled in)

    enum Tune {
        // The scene, in its own points. y runs down.
        static let width = 320.0
        static let height = 280.0
        static let floorY = 272.0
        static let itemR = 13.0                    // an item's radius
        static let trayY = 240.0                   // where a dropped item comes to rest in the tray
        static let chute = CGPoint(x: 76, y: 150)  // where items start falling
        static let binLeft = 230.0
        static let binRight = 298.0
        static let binTop = 186.0
        static let binMouth = 240.0...288.0        // the open top, between the rims
        // Physics
        static let gravity = 1500.0
        static let maxThrow = 2400.0               // fastest flick, points per second
        static let tooSlow = 150.0                 // a slower let-go is a drop, not a shot
        static let floorLimit = 6                  // litter on the floor; the oldest fades
        static let streakForDance = 3
        // Pip
        static let zippySeconds = 60.0
        static let zippyJoy = 3
        static let wantsTeaWindow = 300.0          // seconds Pip's "a cuppa would help" stays true
        static func shotChance(joy: Int) -> Double { [0, 0.08, 0.2, 0.35, 0.5, 0.65][min(max(joy, 0), 5)] }
        static func maxShots(joy: Int) -> Int { joy <= 2 ? 3 : 8 }
        static let shakeFromJoy = 4
        static func danceTilt(joy: Int) -> Double { 4 + Double(min(max(joy, 0), 5)) }
    }

    // MARK: Data

    enum Lines {
        static let shot = ["Shot!", "Nice shot!", "Swish. Well, clonk."]
        static let sulkTea = ["…Oh. A cuppa. Thank you.", "…Alright. You're forgiven."]
        static let sip = ["Mm. Lovely.", "Just right.", "Ahh."]
        static let zippy = "Ooh. Zippy!"
        static let zippyEnd = "…and that's the zip gone."
        static let roll = ["Sausage roll! Flaky.", "Mm. Pastry."]
        static let dance = "Dance, bin, dance!"
    }

    enum Kind: Equatable {
        case can, note, skin, roll, tea, coffee
        var isJunk: Bool { self == .can || self == .note || self == .skin }
        func label(crushed: Bool) -> String {
            switch self {
            case .can: crushed ? "Crushed can" : "Can"
            case .note: "Crumpled note"
            case .skin: "Banana skin"
            case .roll: "Crumbleys sausage roll"
            case .tea: "Cup of Moorside Brew"
            case .coffee: "Cup of Kettlecroft Roast"
            }
        }
    }

    enum Choice { case tea, coffee, rubbish, mystery }
    enum Phase { case dropping, tray, held, flying, floor, binned }

    struct Item: Identifiable {
        let id: Int
        var kind: Kind
        var pos: CGPoint
        var vel = CGVector.zero
        var rot = 0.0                 // degrees
        var spin = 0.0                // degrees per second
        var crushed = false
        var phase = Phase.dropping
        var thrown = false            // let go fast: it counts as a shot
        var thunked = false
        var age = 0.0                 // time spent falling into the bin
    }

    struct Pop: Identifiable { let id: Int; let text: String }

    /// The machine's state this session. The plugin is a struct made once, so this lives in a class.
    @MainActor @Observable final class Machine {
        var items: [Item] = []
        var pops: [Pop] = []
        var lamp = 0                  // 1...4: the lit button on the machine
        var jolt = false
        var binTilt = 0.0
        var binHop = 0.0
        var binGlow = 0.0
        var shake = CGSize.zero
        @ObservationIgnored var host: PipHost?
        @ObservationIgnored var nextID = 0
        @ObservationIgnored var streak = 0
        @ObservationIgnored var talked = 0
        @ObservationIgnored var wantsTeaUntil = Date.distantPast
        @ObservationIgnored var zippyUntil = Date.distantPast
        @ObservationIgnored var loop: Task<Void, Never>?
        @ObservationIgnored var zippyLoop: Task<Void, Never>?
        @ObservationIgnored var dancing = false
    }
    let machine = Machine()

    // MARK: Logic

    static func pick(_ c: Choice) -> Kind {
        func weighted(_ table: [(Kind, Double)]) -> Kind {
            var roll = Double.random(in: 0..<table.reduce(0) { $0 + $1.1 })
            for (k, w) in table { if roll < w { return k }; roll -= w }
            return table[0].0
        }
        switch c {
        case .tea: return .tea
        case .coffee: return .coffee
        case .rubbish: return weighted([(.can, 0.5), (.note, 0.25), (.skin, 0.25)])
        case .mystery: return weighted([(.roll, 0.3), (.can, 0.25), (.note, 0.2), (.skin, 0.25)])
        }
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .custom("feelings.wantsTea"):
            machine.wantsTeaUntil = Date.now.addingTimeInterval(Tune.wantsTeaWindow)
        default:
            break
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { VendCard(machine: machine, host: host) }

    struct VendCard: View {
        let machine: Machine
        let host: PipHost
        @AppStorage("plug.vendomat.on") private var on = true
        @AppStorage("plug.vendomat.sounds") private var sounds = true
        @AppStorage("plug.vendomat.haptics") private var haptics = true
        @AppStorage("plug.vendomat.shots") private var shots = 0
        @AppStorage("plug.vendomat.bin") private var bin = 0
        @State private var showSettings = false

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                if on {
                    SceneView(machine: machine, host: host)
                        .frame(width: Tune.width, height: Tune.height)
                        .frame(maxWidth: .infinity)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        vendButton("Moorside Brew", "mug", .tea, "Vend Moorside Brew, a cup of tea")
                        vendButton("Kettlecroft Roast", "cup.and.saucer", .coffee, "Vend Kettlecroft Roast, a cup of coffee")
                        vendButton("Rubbish", "trash", .rubbish, "Vend some rubbish")
                        vendButton("Mystery", "questionmark.circle", .mystery, "Vend a mystery item")
                    }
                    Text("Pinch rubbish to crush it. Flick it at the bin.")
                        .font(.system(size: 13.5)).foregroundStyle(.secondary)
                } else {
                    Text("The Vend-O-Mat is unplugged.")
                        .font(.system(size: 13.5)).foregroundStyle(.secondary)
                }
                Text(shots == 0 ? "No shots yet." : "Shots in the bin: \(shots)")
                    .font(.system(size: 13.5)).foregroundStyle(.secondary)
                    .accessibilityLabel(shots == 0 ? "No shots in the bin yet" : "\(shots) shots in the bin")
                DisclosureGroup("Settings", isExpanded: $showSettings) {
                    VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                        Toggle("Machine plugged in", isOn: $on)
                            .accessibilityLabel("Vend-O-Mat plugged in")
                            .onChange(of: on) { if !on { machine.clearAll() } }
                        Toggle("Sounds", isOn: $sounds).accessibilityLabel("Vend-O-Mat sounds")
                        Toggle("Haptics", isOn: $haptics).accessibilityLabel("Vend-O-Mat haptics")
                        Button("Empty the bin") { machine.emptyBin() }
                            .buttonStyle(PluginCardButton())
                            .accessibilityLabel("Empty the bin and sweep the floor")
                        Text(bin == 0 ? "The bin's empty." : "The bin has \(bin) things in it.")
                            .font(.system(size: 13.5)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
                .font(.system(size: 13.5))
            }
            .font(.system(size: 13.5))
        }

        private func vendButton(_ title: String, _ symbol: String, _ choice: Choice, _ label: String) -> some View {
            Button { machine.vend(choice, host) } label: {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                    Text(title).lineLimit(1).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PluginCardButton())
            .accessibilityLabel(label)
        }
    }

    /// The little room: machine, bin and everything in between.
    struct SceneView: View {
        let machine: Machine
        let host: PipHost
        @AppStorage("plug.vendomat.bin") private var bin = 0
        @AppStorage("plug.vendomat.shots") private var shots = 0

        var body: some View {
            let simpler = host.simpler
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.primary.opacity(0.12))
                    .frame(width: Tune.width - 16, height: 3)
                    .position(x: Tune.width / 2, y: Tune.floorY + 1)
                MachineArt(machine: machine, simpler: simpler)
                BinArt(machine: machine, bin: bin, front: false, simpler: simpler)
                ForEach(machine.items) { item in
                    ItemView(item: item, machine: machine, host: host, simpler: simpler)
                }
                BinArt(machine: machine, bin: bin, front: true, simpler: simpler)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Bin")
                    .accessibilityValue("\(bin) things inside, \(shots) shots")
                ForEach(machine.pops) { pop in
                    PopView(text: pop.text, simpler: simpler)
                }
            }
            .frame(width: Tune.width, height: Tune.height, alignment: .topLeading)
            .coordinateSpace(name: "vend")
            .offset(machine.shake)
        }
    }

    struct PopView: View {
        let text: String
        let simpler: Bool
        @State private var shown = false
        var body: some View {
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PipLook.accent)
                .position(x: (Tune.binLeft + Tune.binRight) / 2, y: Tune.binTop - 20)
                .offset(y: shown && !simpler ? -26 : 0)
                .opacity(shown ? 0 : 1)
                .onAppear { withAnimation(.easeOut(duration: 0.8)) { shown = true } }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Drawing: the machine

    struct MachineArt: View {
        let machine: Machine
        let simpler: Bool

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [PipLook.orbLight.opacity(0.75), PipLook.orbDeep.opacity(0.85)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5))
                // The sign
                Capsule().fill(Color.black.opacity(0.25)).frame(width: 118, height: 22).position(x: 75, y: 28)
                Text("VEND-O-MAT")
                    .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.2)
                    .foregroundStyle(.white).position(x: 75, y: 28)
                // The window, with shelves of tins
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.4)).frame(width: 90, height: 124).position(x: 62, y: 118)
                ForEach(0..<3, id: \.self) { row in
                    ForEach(0..<3, id: \.self) { col in
                        tin(row * 3 + col)
                            .position(x: 32 + Double(col) * 30, y: 82 + Double(row) * 38)
                    }
                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 80, height: 3)
                        .position(x: 62, y: 98 + Double(row) * 38)
                }
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .topLeading,
                                         endPoint: .center))
                    .frame(width: 90, height: 124).position(x: 62, y: 118)
                // The four lamps
                ForEach(1...4, id: \.self) { n in
                    Circle()
                        .fill(machine.lamp == n ? Color.yellow : Color.white.opacity(0.25))
                        .frame(width: 20, height: 20)
                        .overlay(Image(systemName: ["mug", "cup.and.saucer", "trash", "questionmark"][n - 1])
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(machine.lamp == n ? Color.black.opacity(0.7) : .white.opacity(0.8)))
                        .shadow(color: machine.lamp == n ? .yellow.opacity(0.8) : .clear, radius: 6)
                        .animation(.easeOut(duration: 0.2), value: machine.lamp)
                        .position(x: 128, y: 70 + Double(n - 1) * 30)
                }
                // The tray
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.45)).frame(width: 104, height: 46).position(x: 76, y: 224)
                Capsule().fill(Color.white.opacity(0.35)).frame(width: 96, height: 3).position(x: 76, y: 203)
            }
            .frame(width: 150, height: 254)
            .offset(x: 8, y: machine.jolt && !simpler ? 11 : 8)
            .animation(.spring(response: 0.15, dampingFraction: 0.35), value: machine.jolt)
            .accessibilityHidden(true)
        }

        private func tin(_ i: Int) -> some View {
            let colours: [Color] = [.orange, .brown, .gray, .purple, .orange, .gray, .brown, .purple, .gray]
            return RoundedRectangle(cornerRadius: 5).fill(colours[i].opacity(0.85)).frame(width: 18, height: 24)
        }
    }

    // MARK: Drawing: the bin (a plain open-top office bin)

    struct BinArt: View {
        let machine: Machine
        let bin: Int
        let front: Bool
        let simpler: Bool

        var body: some View {
            ZStack(alignment: .topLeading) {
                if front {
                    // Crumples peeking over the rim as the bin fills (five at most).
                    ForEach(0..<min(bin, 5), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill([Color.white, .yellow.opacity(0.8), .gray.opacity(0.8)][i % 3])
                            .frame(width: 13, height: 10)
                            .rotationEffect(.degrees(Double(i) * 37))
                            .position(x: 16 + Double(i) * 10, y: 5)
                    }
                    BinBody()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.5), PipLook.glow.opacity(0.4)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(BinBody().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                    ForEach(0..<3, id: \.self) { i in
                        Capsule().fill(Color.white.opacity(0.3)).frame(width: 40, height: 2)
                            .position(x: 36, y: 28 + Double(i) * 18)
                    }
                    Capsule().fill(Color.white.opacity(0.75)).frame(width: 72, height: 6).position(x: 36, y: 4)
                    BinBody().stroke(PipLook.accent, lineWidth: 3).opacity(machine.binGlow)
                } else {
                    Capsule().fill(Color.black.opacity(0.4)).frame(width: 60, height: 10).position(x: 36, y: 5)
                }
            }
            .frame(width: 72, height: 88, alignment: .topLeading)
            .rotationEffect(.degrees(simpler ? 0 : machine.binTilt), anchor: .bottom)
            .offset(x: Tune.binLeft - 2, y: Tune.binTop - 4 + (simpler ? 0 : machine.binHop))
        }
    }

    /// A tapered wastepaper bin, wider at the open top.
    struct BinBody: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 2, y: 4))
            p.addLine(to: CGPoint(x: 70, y: 4))
            p.addLine(to: CGPoint(x: 62, y: 84))
            p.addQuadCurve(to: CGPoint(x: 54, y: 87), control: CGPoint(x: 61, y: 87))
            p.addLine(to: CGPoint(x: 18, y: 87))
            p.addQuadCurve(to: CGPoint(x: 10, y: 84), control: CGPoint(x: 11, y: 87))
            p.closeSubpath()
            return p
        }
    }

    // MARK: Drawing: things

    struct ItemView: View {
        let item: Item
        let machine: Machine
        let host: PipHost
        let simpler: Bool
        @State private var ring = false

        var body: some View {
            let held = item.phase == .held
            let touchable = item.kind.isJunk && item.phase != .binned && item.phase != .dropping
            ZStack {
                if ring && !simpler {
                    Circle().stroke(PipLook.accent.opacity(0.7), lineWidth: 2).frame(width: 40, height: 40)
                        .transition(.opacity)
                }
                ItemArt(kind: item.kind, crushed: item.crushed, simpler: simpler)
                    .rotationEffect(.degrees(item.rot))
                    .scaleEffect(held ? 1.15 : 1)
                    .shadow(color: .black.opacity(held ? 0.3 : 0), radius: 6, y: 4)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: held)
            }
            .frame(width: 72, height: 72)
            .contentShape(Rectangle())
            .opacity(item.phase == .binned ? max(0, 1 - item.age / 0.5) : 1)
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("vend"))
                .onChanged { machine.grab(item.id, at: $0.location, host) }
                .onEnded { machine.release(item.id, velocity: $0.velocity, host) },
                     including: touchable ? .all : .none)
            .simultaneousGesture(MagnifyGesture()
                .onChanged { if $0.magnification < 0.8 { machine.crush(item.id, host) } },
                                 including: touchable ? .all : .none)
            .position(item.pos)
            .transition(.opacity)
            .allowsHitTesting(touchable)
            .onChange(of: item.crushed) {
                guard item.crushed else { return }
                withAnimation(.easeOut(duration: 0.3)) { ring = true }
                host.later(0.3) { withAnimation(.easeOut(duration: 0.2)) { ring = false } }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.kind.label(crushed: item.crushed))
            .accessibilityHidden(!touchable && !(item.phase == .tray))
            .accessibilityActions {
                if touchable {
                    if !item.crushed { Button("Crush can") { machine.crush(item.id, host) } }
                    Button("Throw into bin") { machine.aimedThrow(item.id, host) }
                }
            }
        }
    }

    struct ItemArt: View {
        let kind: Kind
        let crushed: Bool
        let simpler: Bool

        var body: some View {
            Group {
                switch kind {
                case .can: can
                case .note: note
                case .skin: skin
                case .roll: roll
                case .tea: cup(Color(red: 0.85, green: 0.55, blue: 0.25))
                case .coffee: cup(Color(red: 0.32, green: 0.2, blue: 0.14))
                }
            }
            .frame(width: 32, height: 32)
        }

        private var can: some View {
            ZStack {
                if simpler {
                    // Fade between the two looks.
                    if crushed { crushedCan.transition(.opacity) } else { tinCan.transition(.opacity) }
                } else {
                    tinCan
                        .scaleEffect(x: crushed ? 1.3 : 1, y: crushed ? 0.5 : 1)
                        .rotationEffect(.degrees(crushed ? 14 : 0))
                        .overlay {
                            if crushed {
                                Path { p in
                                    p.move(to: CGPoint(x: 4, y: 14)); p.addLine(to: CGPoint(x: 12, y: 18))
                                    p.addLine(to: CGPoint(x: 18, y: 12)); p.addLine(to: CGPoint(x: 28, y: 17))
                                }
                                .stroke(Color.black.opacity(0.35), lineWidth: 1.2)
                            }
                        }
                        .animation(.spring(response: 0.22, dampingFraction: 0.35), value: crushed)
                }
            }
            .animation(simpler ? .easeInOut(duration: 0.25) : nil, value: crushed)
        }

        private var tinCan: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.95), Color.gray.opacity(0.6)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 18, height: 26)
                Rectangle().fill(PipLook.accent).frame(width: 18, height: 9)
                Capsule().fill(Color.gray.opacity(0.8)).frame(width: 18, height: 3).offset(y: -12)
                Capsule().fill(Color.gray.opacity(0.8)).frame(width: 18, height: 3).offset(y: 12)
            }
        }

        private var crushedCan: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.8)).frame(width: 24, height: 13)
                Rectangle().fill(PipLook.accent.opacity(0.8)).frame(width: 8, height: 13).offset(x: -4)
            }
            .rotationEffect(.degrees(14))
        }

        private var note: some View {
            Path { p in
                let pts = [(6, 12), (11, 5), (18, 8), (26, 5), (28, 14), (25, 24), (17, 27), (9, 24)]
                p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
                for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
                p.closeSubpath()
            }
            .fill(Color(red: 0.93, green: 0.92, blue: 0.85))
            .overlay(Path { p in
                p.move(to: CGPoint(x: 11, y: 12)); p.addLine(to: CGPoint(x: 20, y: 16))
                p.move(to: CGPoint(x: 10, y: 19)); p.addLine(to: CGPoint(x: 21, y: 21))
            }.stroke(Color.gray.opacity(0.5), lineWidth: 1))
        }

        private var skin: some View {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(Color(red: 0.95, green: 0.8, blue: 0.2))
                        .frame(width: 9, height: 22)
                        .offset(y: -8)
                        .rotationEffect(.degrees(Double(i) * 120 + 20))
                }
                Circle().fill(Color(red: 0.55, green: 0.4, blue: 0.15)).frame(width: 6, height: 6)
            }
        }

        private var roll: some View {
            ZStack {
                Capsule().fill(Color(red: 0.88, green: 0.66, blue: 0.3)).frame(width: 30, height: 15)
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(Color(red: 0.7, green: 0.45, blue: 0.2).opacity(0.7))
                        .frame(width: 2, height: 10).offset(x: Double(i) * 6 - 9).rotationEffect(.degrees(20))
                }
            }
        }

        private func cup(_ drink: Color) -> some View {
            ZStack {
                Capsule().fill(Color.white.opacity(0.85)).frame(width: 30, height: 5).offset(y: 12)
                RoundedRectangle(cornerRadius: 5).fill(Color.white).frame(width: 18, height: 16).offset(y: 3)
                RoundedRectangle(cornerRadius: 2).fill(drink).frame(width: 14, height: 4).offset(y: -2)
                Circle().stroke(Color.white, lineWidth: 2.5).frame(width: 9, height: 9).offset(x: 12, y: 3)
            }
        }
    }
}

// MARK: Feel: haptics and sounds, both switchable in the card

@MainActor
private enum VendFeel {
    private static func on(_ key: String) -> Bool {
        (UserDefaults.standard.object(forKey: "plug.vendomat." + key) as? Bool) ?? true
    }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1) {
        guard on("haptics") else { return }
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred(intensity: intensity)
    }

    static func success() {
        guard on("haptics") else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Plain system sounds: thunk 1104, crunch 1105, clonk 1103.
    static func sound(_ id: UInt32) {
        guard on("sounds") else { return }
        AudioServicesPlaySystemSound(id)
    }
}

// MARK: Machine logic

extension VendOMat.Machine {
    private typealias Tune = VendOMat.Tune
    private typealias Lines = VendOMat.Lines

    private var live: Bool { host?.isOn("vendomat") ?? false }
    private var simpler: Bool { host?.simpler ?? true }
    private var joy: Int { host?.joy ?? 0 }
    private func index(_ id: Int) -> Int? { items.firstIndex { $0.id == id } }

    /// Pip can react: on screen, awake and not set to still (Joy 0).
    private func pipReacts(_ host: PipHost) -> Bool { host.pipHere && !host.pipAsleep && host.joy > 0 }

    private func stamp(_ host: PipHost) { self.host = host }

    // MARK: Vending

    func vend(_ choice: VendOMat.Choice, _ host: PipHost) {
        stamp(host)
        guard live, !items.contains(where: { $0.phase == .dropping }) else { return }
        // Whatever is still in the tray gets nudged out onto the floor.
        if let i = items.firstIndex(where: { $0.phase == .tray }) {
            if items[i].kind.isJunk {
                items[i].phase = .flying
                items[i].vel = CGVector(dx: 70, dy: -160)
                items[i].spin = 120
                run(host)
            } else {
                items.remove(at: i)
            }
        }
        let n = [VendOMat.Choice.tea: 1, .coffee: 2, .rubbish: 3, .mystery: 4][choice] ?? 1
        let kind = VendOMat.pick(choice)
        lamp = n
        VendFeel.tap(.light)
        host.later(1.0) { if self.lamp == n { self.lamp = 0 } }
        host.later(simpler ? 0.25 : 0.45) { [self] in
            guard live else { return }
            nextID += 1
            let id = nextID
            if simpler {
                withAnimation(.easeIn(duration: 0.3)) {
                    items.append(.init(id: id, kind: kind, pos: CGPoint(x: Tune.chute.x, y: Tune.trayY), phase: .tray))
                }
                landed(id, host)
            } else {
                items.append(.init(id: id, kind: kind, pos: Tune.chute, rot: Double.random(in: -20...20)))
                run(host)
            }
        }
    }

    /// First touch of the tray: the thunk. Drinks and food get used by Pip (or just fade) a moment later.
    private func landed(_ id: Int, _ host: PipHost) {
        VendFeel.tap(.heavy)
        VendFeel.sound(1104)
        if !simpler {
            jolt = true
            host.later(0.12) { self.jolt = false }
        }
        guard let kind = items.first(where: { $0.id == id })?.kind, !kind.isJunk else { return }
        host.later(0.7) { [self] in served(kind, host) }
        host.later(4.0) { [self] in
            withAnimation(.easeOut(duration: 0.6)) { items.removeAll { $0.id == id } }
        }
    }

    private func served(_ kind: VendOMat.Kind, _ host: PipHost) {
        guard live, pipReacts(host) else { return }
        let free = PipTalkTurns.floorFree(host)
        switch kind {
        case .tea:
            if Date.now < wantsTeaUntil {
                wantsTeaUntil = .distantPast
                if free { PipTalkTurns.takeFloor(host, for: 3); host.say(Lines.sulkTea.randomElement()!, for: 2.6) }
                host.react(.happy, for: 1.6)
                host.later(0.4) { host.cheer() }
            } else {
                host.react(.happy, for: 1.2)
                if host.joy >= 2, free, Bool.random() {
                    PipTalkTurns.takeFloor(host, for: 2.5)
                    host.say(Lines.sip.randomElement()!, for: 2)
                }
            }
        case .coffee:
            if host.joy >= Tune.zippyJoy, !host.simpler {
                if free { PipTalkTurns.takeFloor(host, for: 2.5); host.say(Lines.zippy, for: 2) }
                host.cheer()
                startZippy(host)
            } else {
                host.react(.happy, for: 1.2)     // just a sip
            }
        case .roll:
            host.react(.happy, for: 1.4)
            if host.joy >= 2, free {
                PipTalkTurns.takeFloor(host, for: 2.5)
                host.say(Lines.roll.randomElement()!, for: 2)
            }
        default:
            break
        }
    }

    /// Zippy for about a minute: a little hop every so often. Ends itself when the minute's up, Pip goes, or the
    /// plugin is switched off.
    private func startZippy(_ host: PipHost) {
        zippyUntil = Date.now.addingTimeInterval(Tune.zippySeconds)
        guard zippyLoop == nil else { return }
        zippyLoop = Task { @MainActor [self] in
            while !Task.isCancelled, live, Date.now < zippyUntil, host.pipHere, host.joy >= Tune.zippyJoy {
                try? await Task.sleep(for: .seconds(9))
                guard !Task.isCancelled, live, Date.now < zippyUntil, host.pipHere, !host.pipAsleep else { break }
                host.react(.surprised, for: 0.8)
                host.cheer()
            }
            if live, host.pipHere, Date.now >= zippyUntil, PipTalkTurns.floorFree(host) {
                PipTalkTurns.takeFloor(host, for: 2.5)
                host.say(Lines.zippyEnd, for: 2.2)
            }
            zippyLoop = nil
        }
    }

    // MARK: Touch

    func grab(_ id: Int, at p: CGPoint, _ host: PipHost) {
        stamp(host)
        guard live, let i = index(id), items[i].kind.isJunk, items[i].phase != .binned else { return }
        if items[i].phase != .held { VendFeel.tap(.light, intensity: 0.5) }
        items[i].phase = .held
        items[i].pos = p
        items[i].vel = .zero
        items[i].spin = 0
    }

    func release(_ id: Int, velocity: CGSize, _ host: PipHost) {
        stamp(host)
        guard let i = index(id), items[i].phase == .held else { return }
        var v = CGVector(dx: velocity.width, dy: velocity.height)
        let speed = hypot(v.dx, v.dy)
        if speed > Tune.maxThrow { v = CGVector(dx: v.dx * Tune.maxThrow / speed, dy: v.dy * Tune.maxThrow / speed) }
        items[i].vel = v
        items[i].spin = v.dx * 0.5
        items[i].thrown = speed >= Tune.tooSlow
        items[i].phase = .flying
        if items[i].thrown { VendFeel.tap(.soft, intensity: 0.7) }
        run(host)
    }

    /// The VoiceOver way to take a shot: an arc that always lands in the bin.
    func aimedThrow(_ id: Int, _ host: PipHost) {
        stamp(host)
        guard live, let i = index(id), items[i].kind.isJunk, items[i].phase != .binned else { return }
        let t = 0.9
        let target = CGPoint(x: (Tune.binMouth.lowerBound + Tune.binMouth.upperBound) / 2, y: Tune.binTop - 6)
        let p = items[i].pos
        items[i].vel = CGVector(dx: (target.x - p.x) / t,
                                dy: ((target.y - p.y) - 0.5 * Tune.gravity * t * t) / t)
        items[i].thrown = true
        items[i].phase = .flying
        run(host)
    }

    func crush(_ id: Int, _ host: PipHost) {
        stamp(host)
        guard live, let i = index(id), items[i].kind.isJunk, !items[i].crushed, items[i].phase != .binned else { return }
        items[i].crushed = true
        VendFeel.tap(.rigid)
        VendFeel.sound(1105)
        if host.joy >= Tune.shakeFromJoy, !host.simpler { shakeScene(host) }
    }

    private func shakeScene(_ host: PipHost) {
        Task { @MainActor [self] in
            for o in [CGSize(width: -3, height: 2), CGSize(width: 3, height: -2), CGSize(width: -2, height: 1), .zero] {
                withAnimation(.linear(duration: 0.04)) { shake = o }
                try? await Task.sleep(for: .milliseconds(45))
            }
        }
    }

    // MARK: Physics (a loop that runs only while something is moving)

    private func run(_ host: PipHost) {
        stamp(host)
        guard loop == nil else { return }
        loop = Task { @MainActor [self] in
            var last = Date.now
            while !Task.isCancelled, live {
                try? await Task.sleep(for: .milliseconds(16))
                let now = Date.now
                let dt = min(0.033, now.timeIntervalSince(last))
                last = now
                if !step(dt, host) { break }
            }
            loop = nil
        }
    }

    /// One tick. Returns false when nothing is moving any more.
    private func step(_ dt: Double, _ host: PipHost) -> Bool {
        let r = Tune.itemR
        var active = false
        var landedIDs: [Int] = []
        var hits: [Int] = []
        var rimClonks = 0
        var quietFloor: [Int] = []
        for i in items.indices {
            var it = items[i]
            switch it.phase {
            case .dropping:
                active = true
                it.vel.dy += Tune.gravity * dt
                it.pos.y += it.vel.dy * dt
                it.rot += 40 * dt
                if it.pos.y >= Tune.trayY {
                    it.pos.y = Tune.trayY
                    if !it.thunked { it.thunked = true; landedIDs.append(it.id) }
                    if abs(it.vel.dy) > 140 { it.vel.dy = -it.vel.dy * 0.28 } else { it.vel = .zero; it.phase = .tray }
                }
            case .flying:
                active = true
                let prevY = it.pos.y
                it.vel.dy += Tune.gravity * dt
                it.pos.x += it.vel.dx * dt
                it.pos.y += it.vel.dy * dt
                it.rot += it.spin * dt
                if it.pos.x < r { it.pos.x = r; it.vel.dx = abs(it.vel.dx) * 0.5; it.spin *= 0.6 }
                if it.pos.x > Tune.width - r { it.pos.x = Tune.width - r; it.vel.dx = -abs(it.vel.dx) * 0.5; it.spin *= 0.6 }
                if it.pos.y < r { it.pos.y = r; it.vel.dy = abs(it.vel.dy) * 0.4 }
                // The bin: in through the open top, off the rim, or off the sides.
                let inMouth = Tune.binMouth.contains(it.pos.x)
                if it.vel.dy > 0, prevY < Tune.binTop, it.pos.y >= Tune.binTop {
                    if inMouth {
                        it.phase = .binned; it.age = 0
                        it.vel = CGVector(dx: it.vel.dx * 0.1, dy: max(it.vel.dy, 200) * 0.6)
                        hits.append(it.id)
                    } else if it.pos.x > Tune.binLeft - r * 0.4, it.pos.x < Tune.binRight + r * 0.4 {
                        it.pos.y = Tune.binTop - 1
                        it.vel.dy = -abs(it.vel.dy) * 0.45
                        it.vel.dx += it.pos.x < (Tune.binLeft + Tune.binRight) / 2 ? -90 : 90
                        rimClonks += 1
                    }
                } else if it.pos.y > Tune.binTop + 4, it.pos.y < Tune.floorY {
                    if inMouth {
                        it.phase = .binned; it.age = 0     // let go right over the bin
                        hits.append(it.id)
                    } else if it.vel.dx > 0, it.pos.x + r > Tune.binLeft, it.pos.x < Tune.binLeft + 10 {
                        it.pos.x = Tune.binLeft - r; it.vel.dx = -abs(it.vel.dx) * 0.4; rimClonks += 1
                    } else if it.vel.dx < 0, it.pos.x - r < Tune.binRight, it.pos.x > Tune.binRight - 10 {
                        it.pos.x = Tune.binRight + r; it.vel.dx = abs(it.vel.dx) * 0.4; rimClonks += 1
                    }
                }
                // The floor: a loose can bounces on, a crushed one thuds and slides.
                let rest = Tune.floorY - r
                if it.phase == .flying, it.pos.y >= rest {
                    it.pos.y = rest
                    let bounce = (it.kind == .can && !it.crushed) ? 0.55 : 0.28
                    if abs(it.vel.dy) > 90 {
                        if abs(it.vel.dy) > 300 { VendFeel.tap(.light, intensity: 0.6) }
                        it.vel.dy = -it.vel.dy * bounce
                        it.vel.dx *= 0.85
                        it.spin *= 0.7
                    } else {
                        it.vel.dy = 0
                        it.vel.dx *= max(0, 1 - 7 * dt)
                        it.spin *= max(0, 1 - 8 * dt)
                        if abs(it.vel.dx) < 10 {
                            it.vel = .zero; it.spin = 0; it.phase = .floor
                            if it.thrown { quietFloor.append(it.id) }
                        }
                    }
                }
            case .binned:
                active = true
                it.age += dt
                it.vel.dy += Tune.gravity * dt
                it.pos.x += it.vel.dx * dt
                it.pos.y = min(it.pos.y + it.vel.dy * dt, Tune.binTop + 46)
                it.rot += 90 * dt
            default:
                break
            }
            items[i] = it
        }
        for id in landedIDs { landed(id, host) }
        if rimClonks > 0 { clonk(host, loud: false) }
        for _ in hits { hit(host) }
        if !quietFloor.isEmpty {
            streak = 0                                        // a miss: it bounced and lay there
            // Keep the litter down: the oldest on the floor fades away.
            let floorIDs = items.filter { $0.phase == .floor }.map(\.id)
            if floorIDs.count > Tune.floorLimit {
                let drop = Set(floorIDs.prefix(floorIDs.count - Tune.floorLimit))
                withAnimation(.easeOut(duration: 0.5)) { items.removeAll { drop.contains($0.id) } }
            }
        }
        if items.contains(where: { $0.phase == .binned && $0.age >= 0.5 }) {
            items.removeAll { $0.phase == .binned && $0.age >= 0.5 }
        }
        return active
    }

    // MARK: The bin

    /// A shot goes in: score, clonk, and the dance on every third in a row.
    private func hit(_ host: PipHost) {
        let store = UserDefaults.standard
        store.set(store.integer(forKey: "plug.vendomat.shots") + 1, forKey: "plug.vendomat.shots")
        store.set(store.integer(forKey: "plug.vendomat.bin") + 1, forKey: "plug.vendomat.bin")
        VendFeel.success()
        clonk(host, loud: true)
        nextID += 1
        let pop = VendOMat.Pop(id: nextID, text: "+1")
        pops.append(pop)
        host.later(1.0) { self.pops.removeAll { $0.id == pop.id } }
        streak += 1
        if streak >= Tune.streakForDance {
            streak = 0
            dance(host)
        } else {
            maybeShout(host)
        }
    }

    /// The bin's "clonk": a small wobble (a quick glow instead under simpler motion).
    private func clonk(_ host: PipHost, loud: Bool) {
        VendFeel.sound(1103)
        if !loud { VendFeel.tap(.rigid, intensity: 0.6) }
        if host.simpler {
            binGlow = 1
            withAnimation(.easeOut(duration: 0.5)) { binGlow = 0 }
            return
        }
        let side = Bool.random() ? 1.0 : -1.0
        withAnimation(.spring(response: 0.14, dampingFraction: 0.3)) { binTilt = side * (loud ? 5 : 3) }
        host.later(0.12) { withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { self.binTilt = 0 } }
    }

    /// The wonder moment: three in a row and the bin does a tiny wobble dance.
    private func dance(_ host: PipHost) {
        guard !dancing else { return }
        dancing = true
        let tilt = VendOMat.Tune.danceTilt(joy: host.joy)
        if pipReacts(host) {
            host.cheer()
            if PipTalkTurns.floorFree(host), talked < Tune.maxShots(joy: host.joy), Double.random(in: 0..<1) < 0.5 {
                talked += 1
                PipTalkTurns.takeFloor(host, for: 3)
                host.say(Lines.dance, for: 2.4)
            }
        }
        Task { @MainActor [self] in
            for k in 0..<6 {
                guard live, !Task.isCancelled else { break }
                if host.simpler {
                    withAnimation(.easeInOut(duration: 0.2)) { binGlow = k % 2 == 0 ? 1 : 0 }
                    try? await Task.sleep(for: .milliseconds(240))
                } else {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                        binTilt = k % 2 == 0 ? tilt : -tilt
                        binHop = -7
                    }
                    try? await Task.sleep(for: .milliseconds(140))
                    withAnimation(.easeIn(duration: 0.1)) { binHop = 0 }
                    try? await Task.sleep(for: .milliseconds(110))
                }
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { binTilt = 0; binHop = 0 }
            withAnimation(.easeOut(duration: 0.3)) { binGlow = 0 }
            dancing = false
        }
    }

    /// Pip's "Shot!": rare at calm, only on their turn, 3 times a session at most (a few more when turned up).
    private func maybeShout(_ host: PipHost) {
        guard pipReacts(host), talked < Tune.maxShots(joy: host.joy),
              PipTalkTurns.floorFree(host),
              Double.random(in: 0..<1) < Tune.shotChance(joy: host.joy) else { return }
        talked += 1
        PipTalkTurns.takeFloor(host, for: 2.5)
        host.say(Lines.shot.randomElement()!, for: 1.8)
    }

    // MARK: Tidying

    /// The settings button: tips out the bin and sweeps the floor.
    func emptyBin() {
        UserDefaults.standard.set(0, forKey: "plug.vendomat.bin")
        withAnimation(.easeOut(duration: 0.4)) { items.removeAll { $0.phase == .floor || $0.phase == .binned } }
        streak = 0
    }

    /// Switched off in the card: everything stops.
    func clearAll() {
        loop?.cancel(); loop = nil
        zippyLoop?.cancel(); zippyLoop = nil
        items = []
        pops = []
        lamp = 0
        binTilt = 0; binHop = 0; binGlow = 0
        streak = 0
    }
}
