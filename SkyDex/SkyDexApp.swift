import SwiftData
import SwiftUI

@main
struct SkyDexApp: App {
    private let container: ModelContainer

    init() {
        let container = SkyDexApp.makeContainer()
        // Before any `@Query` is live, so the repair is not racing a view that
        // is already reading the rows it rewrites.
        SkyEntry.repairLegacyRows(in: container.mainContext)
        self.container = container
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }

    /// `.modelContainer(for:)` calls `fatalError` when the store will not open,
    /// which turns any schema problem into an app that cannot launch — and an
    /// app that cannot launch cannot be fixed from the inside. So the store is
    /// opened by hand, and a store that refuses is moved aside rather than
    /// deleted: the rows are still on disk if they turn out to be recoverable,
    /// and meanwhile the app starts.
    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: SkyEntry.self)
        } catch {
            archiveStore()
            if let fresh = try? ModelContainer(for: SkyEntry.self) { return fresh }
            // Last resort: run without persistence rather than not at all.
            let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: SkyEntry.self, configurations: memoryOnly)
        }
    }

    private static func archiveStore() {
        let base = URL.applicationSupportDirectory.appending(path: "default.store").path
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-shm", "-wal"] {
            let from = URL(fileURLWithPath: base + suffix)
            let to = URL(fileURLWithPath: "\(base)\(suffix).unreadable-\(stamp)")
            try? FileManager.default.moveItem(at: from, to: to)
        }
    }
}
