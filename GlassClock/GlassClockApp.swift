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
                    .overlay(alignment: .bottom) {
                        if UserDefaults.standard.bool(forKey: "frameMeter") { FrameMeter().padding(.bottom, 2) }
                    }
            }
            #else
            ContentView()
            #endif
        }
    }
}
