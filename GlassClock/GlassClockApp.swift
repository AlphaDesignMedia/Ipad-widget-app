import SwiftUI

@main
struct GlassClockApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let page = UserDefaults.standard.string(forKey: "gallery") {
                StyleGallery(page: page)
            } else if let window = UserDefaults.standard.string(forKey: "screenshotWindow") {
                // For screenshots of smaller windows, which the simulator can't make from a script:
                // `-screenshotWindow 700x1000` draws the app in a frame that size, compact below 700 pt.
                let size = window.split(separator: "x").compactMap { Double($0) }
                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()
                    ContentView()
                        .frame(width: size.first ?? 700, height: size.last ?? 1000)
                        .clipShape(.rect(cornerRadius: 24))
                        .environment(\.horizontalSizeClass, (size.first ?? 700) < 700 ? .compact : .regular)
                        .padding(24)
                }
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
