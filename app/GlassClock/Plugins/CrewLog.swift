import Foundation

// =====================================================================================================
//  BUILDERS: add ONE line here when you finish a job.
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
        .init("2026-10-30 19:10", .bob, "Pip Looks: see Pip as a 3D liquid drop next to the classic orb. Pick Drop or go back to Classic in one tap.", .core),
        .init("2026-10-30 19:10", .dot, "Glass Memory: Pip leaves very faint marks where they fly, and drawings can look soft or frosted.", .untested),
        .init("2026-10-30 18:48", .bob, "Pip's Manners: all the plugins share one talk budget that follows Joy, so Pip never gets chatty. Shh for an hour in its card.", .untested),
        .init("2026-10-30 18:50", .dot, "The Draw-off: Pip calls a word, Bob and Dot both draw it, you pick the winner. Draw your own too if you fancy.", .untested),
        .init("2026-10-30 18:12", .rob, "Checked over Pip's new self-check, and brought in Rob and the first vintage tin.", .untested),
        .init("2026-10-30 18:05", .bob, "Window Cleaner Pip: now and then Pip cleans the glass behind your panels, and once a messy session the clean team pops in.", .untested),
        .init("2026-10-30 18:00", .dot, "Vend-O-Mat: a glass vending machine and a bin. Crush the rubbish, flick it in, three in a row and the bin dances.", .untested),
        .init("2026-10-30 17:35", .rob, "Tidy-up: every warning gone, reduced motion stops running flat out, and the cupboard door no longer swallows taps when it is open.", .untested),
        .init("2026-10-30 17:20", .dot, "Pip's sketchbook: draw and Pip guesses house or face. Teach them more words, or trace one of theirs.", .untested),
        .init("2026-10-30 16:05", .rob, "Pip in 3D turns in two beats now: the tilt trails the turn, and the look settles a touch past you. All the numbers live in one table.", .untested),
        .init("2026-10-30 14:48", .bob, "Tidy Pip shows you how first, then offers to do it: drawings first, then panels.", .untested),
        .init("2026-10-30 14:38", .dot, "Tidy-up: plugins switched off now rest completely, and the crew chat stops when you close it.", .untested),
        .init("2026-10-30 14:32", .bob, "The Stationery Cupboard: Pip's locked in. Three little locks let them out.", .green),
        .init("2026-10-30 14:26", .dot, "Pip's feelings: dizzy after flicks, sulks if thrown, likes a gentle pat.", .untested),
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
        case pip, bob, dot, rob
        var name: String { ["pip": "Pip", "bob": "Bob", "dot": "Dot", "rob": "Rob"][rawValue] ?? "Pip" }
        var symbol: String {
            switch self {
            case .pip: return "sparkle"
            case .bob: return "wrench.and.screwdriver"
            case .dot: return "paintbrush.pointed"
            case .rob: return "laptopcomputer"
            }
        }
        var role: String {
            switch self {
            case .pip: return "Your guide"
            case .bob: return "Foreman. Steady. Flask of tea, a vape on breaks."
            case .dot: return "Apprentice. Keen, and wishes they were better."
            case .rob: return "Older brother. Codes. Not Bob, and never has been."
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
            guard let day = Self.read.date(from: date) else { return date }
            return Self.show.string(from: day)
        }

        /// One shared pair of date formatters (making them is slow, and rows draw often).
        private static let read: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_GB")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd HH:mm"
            return f
        }()
        private static let show: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_GB")
            f.dateFormat = "EEE d MMM"
            return f
        }()
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
