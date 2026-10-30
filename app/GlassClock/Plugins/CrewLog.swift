import Foundation

// ==============================================================================================//  BUILDERS: add ONE line here when you finish a job.
// =====================================================================================================
//
//  This is the crew's log book. Crew Rundown (the speech-bubbles panel) reads it and shows Aaron
//  what's new, newest first, with "x new since you last looked".
//
//  How to add your line (copy one below and change it):
//      .init("2026-10-30 14:06", .dot, "What you did, in plain words.", .green),
//
//  - Date: "yyyy-MM-dd HH:mm" (UTC, like `git log`). It sorts the list, so get it right.
//  - Who:  .bob, .dot or .pip
//  - What: one short plain sentence Aaron can read on the iPad. No code words.
//  - Status: .green (built, CI green), .untested (not hand-tested), .core (waiting on core),
//            .doing (in progress)
//
//  Order in the list doesn't matter, but please add new lines at the top. Never delete a line.
//  This file is data only, not a plugin, so it needs no line in Plugins.swift.
// =====================================================================================================

enum CrewLog {
    static let entries: [Entry] = [
        .init("2026-10-30 14:26", .dot, "Pip's feelings: dizzy after flicks, sulks if thrown, likes a gentle pat.", .untested),
=======
        .init("2026-10-30 14:14", .bob, "Tea chat: Bob and Dot checked each other's work and fixed two small snags.", .green),
        .init("2026-10-30 14:14", .dot, "Tidy Pip's question now goes away if you leave it.", .green),
        .init("2026-10-30 14:07", .bob, "Pip's plugins take turns talking, so nobody talks over anyone.", .green),
        .init("2026-10-30 14:06", .dot, "Crew rundown fills itself from the crew's log book, and counts what's new.", .untested),
        .init("2026-10-30 14:01", .dot, "Crew rundown: this panel.", .untested),
        .init("2026-10-30 13:58", .bob, "Dashboard queue only offers when nobody else is talking.", .green),
        .init("2026-10-30 13:58", .bob, "Tidy Pip waits about 5 minutes at calm, and takes turns talking.", .green),
        .init("2026-10-30 13:58", .bob, "Busy Pip stops completely when it's switched off.", .green),
        .init("2026-10-30 13:53", .dot, "Guest Takeover: Tack and Fuse pop in, then leave.", .core),
        .init("2026-10-30 13:53", .dot, "Tea Break: Pip asks for a cuppa after real work.", .green),
        .init("2026-10-30 13:50", .bob, "Tidy Pip: offers to tidy away open panels.", .green),
        .init("2026-10-30 13:50", .bob, "Dashboard queue: 13 ideas to move over.", .green),
        .init("2026-10-30 13:47", .bob, "Busy Pip: rounds with a clipboard while you're idle.", .green),
        .init("2026-10-30 13:39", .bob, "Pip's Weight v1.1: floats, tires, rests on a seat.", .green),
        .init("2026-10-30 13:34", .bob, "Idea inbox: jot ideas down on the iPad.", .green),
        .init("2026-10-30 13:29", .bob, "Next action: your next step, big and clear.", .green),
        .init("2026-10-30 13:29", .bob, "Dashboard: your progress board in a panel.", .green),
    ]

    // MARK: Shape (builders: nothing to change below here)

    enum Who: String, Sendable, Hashable {
        case pip, bob, dot
        var name: String { ["pip": "Pip", "bob": "Bob", "dot": "Dot"][rawValue] ?? "Pip" }
        var symbol: String {
            switch self {
            case .pip: return "sparkle"
            case .bob: return "wrench.and.screwdriver"
            case .dot: return "paintbrush.pointed"
            }
        }
        var role: String {
            switch self {
            case .pip: return "Your guide"
            case .bob: return "Foreman. Steady. Flask of tea, a vape on breaks."
            case .dot: return "Apprentice. Keen, and wishes they were better."
            }
        }
    }

    enum Status: String, Sendable {
        case green, untested, core, doing
        var label: String {
            switch self {
            case .green: return "Built, CI green"
            case .untested: return "Not hand-tested"
            case .core: return "Waiting on core"
            case .doing: return "In progress"
            }
        }
    }

    struct Entry: Sendable {
        let date: String        // "yyyy-MM-dd HH:mm", sorts as text
        let who: Who
        let what: String
        let status: Status

        init(_ date: String, _ who: Who, _ what: String, _ status: Status) {
            self.date = date
            self.who = who
            self.what = what
            self.status = status
        }

        /// "Fri 30 Oct" for the card. Falls back to the raw text if the date is mistyped.
        var when: String {
            let read = DateFormatter()
            read.locale = Locale(identifier: "en_GB")
            read.timeZone = TimeZone(identifier: "UTC")
            read.dateFormat = "yyyy-MM-dd HH:mm"
            guard let day = read.date(from: date) else { return date }
            let show = DateFormatter()
            show.locale = Locale(identifier: "en_GB")
            show.dateFormat = "EEE d MMM"
            return show.string(from: day)
        }
    }

    /// Every entry, newest first. Same date keeps the order written (top first).
    static var newestFirst: [Entry] {
        entries.enumerated()
            .sorted { $0.element.date != $1.element.date ? $0.element.date > $1.element.date : $0.offset < $1.offset }
            .map(\.element)
    }

    /// The newest date in the log ("" if the log is empty).
    static var newest: String { entries.map(\.date).max() ?? "" }

    /// How many entries are newer than `seen` (a date saved from an earlier look; "" means never looked).
    static func newCount(since seen: String) -> Int {
        entries.filter { $0.date > seen }.count
    }
}
