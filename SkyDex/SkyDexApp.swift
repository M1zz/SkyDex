import LeeoKit
import SwiftData
import SwiftUI
import TipKit

@main
struct SkyDexApp: App {
    private let container: ModelContainer

    init() {
        let container = SkyDexApp.makeContainer()
        CloudSync.shared.begin(syncing: SkyDexApp.usesCloud)

        // 사용량 기록 · 분석 싱크 · 크래시 진단 · 사용현황 스냅샷. 전부 실패해도
        // 앱은 그대로 돈다 — 이 줄이 앱의 동작을 좌우해서는 안 된다.
        LeeoKit.bootstrap(SkyDexSpec.self)
        // Before any `@Query` is live, so the repair is not racing a view that
        // is already reading the rows it rewrites.
        SkyEntry.repairLegacyRows(in: container.mainContext)
        self.container = container

        // Once a day at most. The forecast has something to say every morning
        // and that is exactly why it must not say it every time the app opens.
        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])
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
    ///
    /// Four attempts, in order of how much they cost the collection. The store
    /// on disk is the same file every time — only what is done with it changes.
    private static func makeContainer() -> ModelContainer {
        prepareStoreDirectory()

        // 1. iCloud, unless it was turned off in the settings. Rows already on
        //    disk stay put and start uploading; a fresh install on a new phone
        //    pulls back whatever the account holds.
        if wantsCloud,
           let synced = try? ModelContainer(for: SkyEntry.self, configurations: cloudConfiguration) {
            usesCloud = true
            return synced
        }

        // 2. The same file without sync. A missing entitlement, an unsigned
        //    build, a container that was never provisioned — every one of those
        //    is a reason not to sync and none of them is a reason to touch a
        //    photograph. This is what the app was before iCloud existed.
        if let local = try? ModelContainer(for: SkyEntry.self) { return local }

        // 3. Only now is the store itself the suspect.
        archiveStore()
        if let fresh = try? ModelContainer(for: SkyEntry.self) { return fresh }

        // 4. Last resort: run without persistence rather than not at all.
        let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: SkyEntry.self, configurations: memoryOnly)
    }

    /// The private database of the app's own container — the user's iCloud, not
    /// the developer's. Nothing here is readable by anyone else, and no server
    /// of ours is involved in holding it.
    ///
    /// Named rather than `.automatic` so a build signed with the wrong
    /// entitlement fails at step 1 and falls through to the local store, instead
    /// of quietly syncing somewhere unintended.
    private static let cloudConfiguration = ModelConfiguration(
        cloudKitDatabase: .private(cloudContainer)
    )

    /// Named in one place: the configuration opens it, and `CloudSync` asks it
    /// whether there is an account to sync with.
    static let cloudContainer = "iCloud.com.leeo.SkyDex"

    /// Set once, by `makeContainer`, before any view exists.
    private(set) static var usesCloud = false

    /// The switch in the settings screen. Read once, at launch: a store cannot
    /// change its mind about syncing while it is open, so the screen says the
    /// change waits for the next launch rather than pretending otherwise.
    static let cloudEnabledKey = "skydex.cloud.enabled"

    private static var wantsCloud: Bool {
        UserDefaults.standard.object(forKey: cloudEnabledKey) as? Bool ?? true
    }

    /// Where `default.store` actually is.
    ///
    /// `ModelConfiguration` picks up an app group on its own when the
    /// entitlements name one, so the store is not in the app's own Application
    /// Support — it is in the shared container, which is also why the widgets'
    /// entitlement has to keep naming the same group.
    private static var storeDirectory: URL {
        let shared = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SkySnapshot.group)?
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return shared ?? URL.applicationSupportDirectory
    }

    /// iOS creates the group container but nothing inside it. On a fresh
    /// install the folder the store wants does not exist yet, so the first
    /// `addPersistentStore` fails with a page of sandbox complaints before Core
    /// Data's own recovery makes the folder and retries. It does recover — but
    /// a launch that prints a stack of `error:` lines and works anyway is a
    /// launch nobody can read the real faults out of. One `mkdir` removes it.
    private static func prepareStoreDirectory() {
        try? FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func archiveStore() {
        let base = storeDirectory.appending(path: "default.store").path
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-shm", "-wal"] {
            let from = URL(fileURLWithPath: base + suffix)
            let to = URL(fileURLWithPath: "\(base)\(suffix).unreadable-\(stamp)")
            try? FileManager.default.moveItem(at: from, to: to)
        }
    }
}
