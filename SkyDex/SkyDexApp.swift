import SwiftUI
import SwiftData
import TipKit

@main
struct SkyDexApp: App {
    init() {
        try? Tips.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: SkyEntry.self)
    }
}
