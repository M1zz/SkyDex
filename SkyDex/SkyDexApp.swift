import SwiftUI
import SwiftData

@main
struct SkyDexApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: SkyEntry.self)
    }
}
