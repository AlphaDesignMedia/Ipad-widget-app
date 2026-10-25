import SwiftUI

@main
struct GlassClockApp: App {
    init() { CrashReports.shared.start() }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            Group {
                if let page = UserDefaults.standard.string(forKey: "gallery") {
                    StyleGallery(page: page)
                } else if UserDefaults.standard.bool(forKey: "rebuild") {
                    // The rebuilt app, while it's being built (PLAN.md, "The rebuild").
                    RebuildRoot()
                } else {
                    ContentView()
                }
            }
            .overlay(alignment: .bottom) {
                if UserDefaults.standard.bool(forKey: "frameMeter") { FrameMeter().padding(.bottom, 2) }
            }
            #else
            ContentView()
            #endif
        }
    }
}
