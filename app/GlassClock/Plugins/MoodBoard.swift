import SwiftUI
import PhotosUI
import UIKit
import WidgetKit

// MOOD BOARDS · plugin v1 (Dream) (Jules, 1 Nov). Aaron: "mood boards on here too", step 4 of
// nat/dashboard-studio-plan.md. Pin boards of pictures and notes, in the Dashboard's "Mood boards" group.
// Open a board and it fills the screen: add photos (the system photo picker, so no photo permission is asked),
// paste a picture, pin a Snap from the send sheet, or add a sticky note. Drag to move, pinch to resize, hold for more.
// Send turns the whole board into one picture and opens the same send sheet as Snap (Master chat, Rob, Jules, Chappie).
// Several boards, each with a name. Kept on this iPad (Application Support/moodboards). The newest board is also
// drawn small for the Pip Pictures Home Screen widget. No network. Pip says nothing here; works the same with Pip off.
// Simpler motion: nothing animates. Private: Aaron's mission control, never moves to Glass Clock.

struct MoodBoard: SandboxPlugin {
    let info = PluginInfo(id: "moodboard", name: "Mood boards", version: "v1", shelf: .dream,
                          icon: "photo.on.rectangle.angled",
                          what: "Pin boards of pictures and notes in the Dashboard. Send a board as one picture.")

    // MARK: Data

    struct Item: Codable, Identifiable, Equatable {
        enum Kind: String, Codable { case picture, note }
        var id: UUID
        var kind: Kind
        /// The picture's file in the boards folder.
        var file: String?
        var text: String?
        var colour: Int
        /// Centre, as a share of the board's width and height, so a board looks the same at any size.
        var x: Double
        var y: Double
        /// Width as a share of the board's width; height is width × aspect.
        var w: Double
        var aspect: Double
        /// A slight tilt, in degrees, like pinned paper.
        var tilt: Double
    }

    struct Board: Codable, Identifiable, Equatable {
        var id: UUID
        var name: String
        var items: [Item]
    }

    /// Boards are 16 by 10.
    static let aspect = 10.0 / 16.0
    static let boardColour = Color(hex: "#ece6da")
    /// Sticky note colours: lemon, rose, sky, mint.
    static let noteColours = ["#fff1a8", "#ffd3dc", "#cfe8ff", "#d4f5d8"].map { Color(hex: $0) }
    static let longestSide: CGFloat = 1400
    static let currentKey = "plug.moodboard.current"

    // MARK: Logic

    /// All the boards and their pictures, kept on this iPad.
    @MainActor @Observable final class Store {
        static let shared = Store()
        private(set) var boards: [Board] = []
        private(set) var currentID: UUID?
        @ObservationIgnored private var cache: [String: UIImage] = [:]
        @ObservationIgnored private var coverTask: Task<Void, Never>?

        static var folder: URL { URL.applicationSupportDirectory.appending(path: "moodboards", directoryHint: .isDirectory) }
        static var file: URL { folder.appending(path: "boards.json") }

        init() {
            try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            if let data = try? Data(contentsOf: Self.file),
               let saved = try? JSONDecoder().decode([Board].self, from: data) { boards = saved }
            if boards.isEmpty { boards = [Board(id: UUID(), name: "First board", items: [])] }
            let kept = UserDefaults.standard.string(forKey: MoodBoard.currentKey).flatMap(UUID.init(uuidString:))
            currentID = boards.contains { $0.id == kept } ? kept : boards.first?.id
        }

        var current: Board? { boards.first { $0.id == currentID } }

        func pick(_ id: UUID) {
            currentID = id
            UserDefaults.standard.set(id.uuidString, forKey: MoodBoard.currentKey)
        }

        func newBoard(_ name: String) {
            let board = Board(id: UUID(), name: name.isEmpty ? "Board \(boards.count + 1)" : name, items: [])
            boards.append(board)
            pick(board.id)
            save()
        }

        func rename(_ name: String) {
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            change { $0.name = name }
        }

        func deleteCurrent() {
            guard let board = current else { return }
            for item in board.items { forget(item) }
            boards.removeAll { $0.id == board.id }
            if boards.isEmpty { boards = [Board(id: UUID(), name: "First board", items: [])] }
            pick(boards[boards.count - 1].id)
            save()
        }

        /// Changes the current board and keeps it.
        func change(_ edit: (inout Board) -> Void) {
            guard let i = boards.firstIndex(where: { $0.id == currentID }) else { return }
            edit(&boards[i])
            save()
        }

        func move(_ id: UUID, x: Double, y: Double, w: Double? = nil) {
            change { b in
                guard let i = b.items.firstIndex(where: { $0.id == id }) else { return }
                var item = b.items.remove(at: i)
                item.x = min(max(x, 0.03), 0.97)
                item.y = min(max(y, 0.04), 0.96)
                if let w { item.w = min(max(w, 0.08), 0.8) }
                b.items.append(item)        // what you touch comes to the front
            }
        }

        func remove(_ id: UUID) {
            guard let item = current?.items.first(where: { $0.id == id }) else { return }
            forget(item)
            change { $0.items.removeAll { $0.id == id } }
        }

        /// Pins a picture to the current board, scaled down and saved as a JPEG.
        func addPicture(_ image: UIImage) {
            let small = MoodBoard.shrink(image, to: MoodBoard.longestSide)
            guard let data = small.jpegData(compressionQuality: 0.82) else { return }
            let name = "\(UUID().uuidString).jpg"
            guard (try? data.write(to: Self.folder.appending(path: name), options: .atomic)) != nil else { return }
            cache[name] = small
            let spot = nextSpot()
            let aspect = small.size.width > 0 ? Double(small.size.height / small.size.width) : 1
            change {
                $0.items.append(Item(id: UUID(), kind: .picture, file: name, text: nil, colour: 0, x: spot.x, y: spot.y,
                                     w: aspect > 1.2 ? 0.17 : 0.24, aspect: aspect, tilt: Double.random(in: -4...4)))
            }
        }

        func addNote(_ text: String) {
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let spot = nextSpot()
            let colour = (current?.items.filter { $0.kind == .note }.count ?? 0) % MoodBoard.noteColours.count
            change {
                $0.items.append(Item(id: UUID(), kind: .note, file: nil, text: text, colour: colour, x: spot.x, y: spot.y,
                                     w: 0.17, aspect: 1, tilt: Double.random(in: -5...5)))
            }
        }

        func image(_ file: String?) -> UIImage? {
            guard let file else { return nil }
            if let hit = cache[file] { return hit }
            let loaded = UIImage(contentsOfFile: Self.folder.appending(path: file).path)
            cache[file] = loaded
            return loaded
        }

        /// New things land in a loose grid, then start again a little offset.
        private func nextSpot() -> (x: Double, y: Double) {
            let n = current?.items.count ?? 0
            let round = Double(n / 12) * 0.03
            return (0.15 + Double(n % 4) * 0.23 + round, 0.22 + Double((n / 4) % 3) * 0.28 + round)
        }

        private func forget(_ item: Item) {
            guard let file = item.file else { return }
            try? FileManager.default.removeItem(at: Self.folder.appending(path: file))
            cache[file] = nil
        }

        private func save() {
            if let data = try? JSONEncoder().encode(boards) { try? data.write(to: Self.file, options: .atomic) }
            // The Home Screen's copy, a moment after the last change, so dragging stays smooth.
            coverTask?.cancel()
            coverTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let board = self.current else { return }
                MoodBoard.publishCover(board)
            }
        }
    }

    /// Scales a picture down so its longest side is at most `side` points (at 1x).
    static func shrink(_ image: UIImage, to side: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > side else { return image }
        let k = side / longest
        let size = CGSize(width: (image.size.width * k).rounded(), height: (image.size.height * k).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// The whole board as one picture.
    @MainActor static func render(_ board: Board, width: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: BoardCanvas(board: board).frame(width: width, height: width * aspect))
        renderer.scale = 1
        return renderer.uiImage
    }

    /// The newest board, drawn small for the Pip Pictures Home Screen widget.
    @MainActor static func publishCover(_ board: Board) {
        guard let image = render(board, width: 900), let data = image.jpegData(compressionQuality: 0.75) else { return }
        PictureShelf.save(data, kind: .moodBoard, title: board.name)
        WidgetCenter.shared.reloadTimelines(ofKind: PictureShelf.widgetKind)
    }

    // MARK: Views

    var addsTo: String? { Dashboard.panelsSlot }    // a group in the Dashboard tab
    func addOn(_ host: PipHost) -> some View { Shelf(host: host) }

    /// In the Dashboard: the current board, small, and the way in.
    struct Shelf: View {
        let host: PipHost
        @Bindable private var store = Store.shared
        @State private var open = false

        init(host: PipHost) { self.host = host }

        var body: some View {
            if let board = store.current {
                Button { open = true } label: {
                    BoardCanvas(board: board)
                        .aspectRatio(1 / MoodBoard.aspect, contentMode: .fit)
                        .overlay {
                            if board.items.isEmpty {
                                Text("Empty board. Open it to pin photos, snaps and notes.")
                                    .font(.footnote).foregroundStyle(.black.opacity(0.55)).multilineTextAlignment(.center).padding()
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(board.name), \(board.items.count) things pinned")
                .accessibilityHint("Opens the board full screen.")
                HStack(spacing: 8) {
                    Menu {
                        ForEach(store.boards) { b in
                            Button { store.pick(b.id) } label: {
                                Label("\(b.name) (\(b.items.count))", systemImage: b.id == board.id ? "checkmark" : "rectangle.on.rectangle")
                            }
                        }
                    } label: {
                        Label(board.name, systemImage: "square.stack").lineLimit(1).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PluginCardButton())
                    .accessibilityLabel("Board: \(board.name). Pick another.")
                    Button { open = true } label: {
                        Label("Open", systemImage: "arrow.up.left.and.arrow.down.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PluginCardButton(on: true))
                }
                .fullScreenCover(isPresented: $open) { Editor(host: host) }
            }
        }
    }

    /// The board, full screen, with its tools along the top.
    struct Editor: View {
        let host: PipHost
        @Bindable private var store = Store.shared
        @Environment(\.dismiss) private var dismiss
        @State private var picks: [PhotosPickerItem] = []
        @State private var snap: Dashboard.Snap?
        @State private var writing = false
        @State private var noteText = ""
        @State private var naming = false
        @State private var nameText = ""
        @State private var newBoard = false
        @State private var deleting = false

        init(host: PipHost) { self.host = host }

        var body: some View {
            let board = store.current
            NavigationStack {
                ZStack {
                    Sketch.Paper()
                    if let board {
                        BoardCanvas(board: board, editable: true).padding(24)
                        if board.items.isEmpty {
                            Text("Add photos, paste a picture, or add a note.\nDrag to move, pinch to resize, hold for more.")
                                .font(.callout).foregroundStyle(.black.opacity(0.5)).multilineTextAlignment(.center)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .navigationTitle(board?.name ?? "Mood board")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { boardsMenu }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .images) {
                            Label("Add photos", systemImage: "photo.badge.plus")
                        }
                        Button { paste() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                        Button { noteText = ""; writing = true } label: { Label("Add note", systemImage: "note.text.badge.plus") }
                        Button { send() } label: { Label("Send", systemImage: "square.and.arrow.up") }
                            .disabled(board?.items.isEmpty ?? true)
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                }
                .onChange(of: picks) { _, chosen in load(chosen) }
                .alert("New note", isPresented: $writing) {
                    TextField("What's the note?", text: $noteText)
                    Button("Add") { store.addNote(noteText) }
                    Button("Cancel", role: .cancel) {}
                }
                .alert(newBoard ? "New board" : "Rename board", isPresented: $naming) {
                    TextField("Name", text: $nameText)
                    Button(newBoard ? "Make it" : "Rename") {
                        if newBoard { store.newBoard(nameText) } else { store.rename(nameText) }
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .confirmationDialog("Delete \(board?.name ?? "this board")?", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete board", role: .destructive) { store.deleteCurrent() }
                } message: {
                    Text("Its pictures and notes go too. This can't be undone.")
                }
                .sheet(item: $snap) { s in
                    Dashboard.SnapSheet(snap: s, startNote: "Mood board: \(board?.name ?? "")", pinnable: false)
                }
            }
        }

        private var boardsMenu: some View {
            Menu {
                ForEach(store.boards) { b in
                    Button { store.pick(b.id) } label: {
                        Label("\(b.name) (\(b.items.count))", systemImage: b.id == store.currentID ? "checkmark" : "rectangle.on.rectangle")
                    }
                }
                Divider()
                Button { newBoard = true; nameText = ""; naming = true } label: { Label("New board", systemImage: "plus") }
                Button { newBoard = false; nameText = store.current?.name ?? ""; naming = true } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) { deleting = true } label: { Label("Delete board", systemImage: "trash") }
            } label: {
                Label("Boards", systemImage: "square.stack")
            }
        }

        private func load(_ chosen: [PhotosPickerItem]) {
            guard !chosen.isEmpty else { return }
            Task { @MainActor in
                for item in chosen {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        store.addPicture(image)
                    }
                }
                picks = []
            }
        }

        private func paste() {
            if let image = UIPasteboard.general.image {
                store.addPicture(image)
            } else if let text = UIPasteboard.general.string {
                store.addNote(text)
            }
        }

        private func send() {
            guard let board = store.current, let image = MoodBoard.render(board, width: 1600) else { return }
            snap = Dashboard.Snap(image: image)
        }
    }

    /// The board itself: warm card, things pinned on it. Editable in the editor; still everywhere else.
    struct BoardCanvas: View {
        let board: Board
        var editable = false

        var body: some View {
            GeometryReader { geo in
                let width = min(geo.size.width, geo.size.height / MoodBoard.aspect)
                let size = CGSize(width: width, height: width * MoodBoard.aspect)
                ZStack {
                    MoodBoard.boardColour
                    ForEach(board.items) { item in
                        Pinned(item: item, size: size, editable: editable)
                            .allowsHitTesting(editable)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: max(6, width * 0.012)))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    /// One picture or note on a board.
    struct Pinned: View {
        let item: Item
        let size: CGSize
        let editable: Bool
        @GestureState private var drag = CGSize.zero
        @GestureState private var zoom = 1.0

        var body: some View {
            let width = item.w * size.width * zoom
            let edge = max(2, width * 0.035)
            face(width: width, edge: edge)
                .frame(width: width, height: width * item.aspect)
                .rotationEffect(.degrees(item.tilt))
                .shadow(color: .black.opacity(0.2), radius: max(2, width * 0.03), y: max(1, width * 0.015))
                .position(x: item.x * size.width + drag.width, y: item.y * size.height + drag.height)
                .gesture(moveAndZoom, including: editable ? .all : .none)
                .contextMenu {
                    if editable {
                        Button { Store.shared.move(item.id, x: item.x, y: item.y, w: item.w * 1.3) } label: {
                            Label("Bigger", systemImage: "plus.magnifyingglass")
                        }
                        Button { Store.shared.move(item.id, x: item.x, y: item.y, w: item.w / 1.3) } label: {
                            Label("Smaller", systemImage: "minus.magnifyingglass")
                        }
                        if item.kind == .picture, let image = Store.shared.image(item.file) {
                            Button { UIPasteboard.general.image = image } label: { Label("Copy picture", systemImage: "doc.on.doc") }
                        }
                        Button(role: .destructive) { Store.shared.remove(item.id) } label: { Label("Remove", systemImage: "trash") }
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(item.kind == .note ? "Note: \(item.text ?? "")" : "Picture")
                .accessibilityAction(named: "Bigger") { Store.shared.move(item.id, x: item.x, y: item.y, w: item.w * 1.3) }
                .accessibilityAction(named: "Smaller") { Store.shared.move(item.id, x: item.x, y: item.y, w: item.w / 1.3) }
                .accessibilityAction(named: "Remove") { Store.shared.remove(item.id) }
        }

        @ViewBuilder private func face(width: CGFloat, edge: CGFloat) -> some View {
            switch item.kind {
            case .picture:
                // A white edge, like a printed photo.
                ZStack {
                    Color.white
                    if let image = Store.shared.image(item.file) {
                        Image(uiImage: image).resizable().scaledToFill().padding(edge).clipped()
                    }
                }
            case .note:
                ZStack(alignment: .topLeading) {
                    MoodBoard.noteColours[item.colour % MoodBoard.noteColours.count]
                    Text(item.text ?? "")
                        .font(.system(size: max(8, width * 0.1), weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.8))
                        .minimumScaleFactor(0.4)
                        .padding(width * 0.09)
                }
            }
        }

        private var moveAndZoom: some Gesture {
            SimultaneousGesture(
                DragGesture()
                    .updating($drag) { v, state, _ in state = v.translation }
                    .onEnded { v in
                        Store.shared.move(item.id, x: item.x + v.translation.width / size.width,
                                          y: item.y + v.translation.height / size.height)
                    },
                MagnifyGesture()
                    .updating($zoom) { v, state, _ in state = v.magnification }
                    .onEnded { v in Store.shared.move(item.id, x: item.x, y: item.y, w: item.w * v.magnification) }
            )
        }
    }
}
