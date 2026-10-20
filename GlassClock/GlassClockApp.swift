import SwiftUI

@main
struct GlassClockApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let page = UserDefaults.standard.string(forKey: "gallery") {
                StyleGallery(page: page)
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
