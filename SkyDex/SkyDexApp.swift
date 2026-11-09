import AppIntents
import LeeoKit
import SwiftData
import SwiftUI

@main
struct SkyDexApp: App {
    private let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 백업 금고 · 사용량 기록 · 분석 싱크 · 크래시 진단 · 사용현황 스냅샷. 전부 실패해도
        // 앱은 그대로 돈다 — 이 줄이 앱의 동작을 좌우해서는 안 된다.
        // 금고가 예약된 복원을 적용해야 하므로 저장소를 열기 전에 켠다.
        LeeoKit.bootstrap(SkyDexSpec.self)

        let container = SkyDexApp.makeContainer()
        CloudSync.shared.begin(syncing: SkyDexApp.usesCloud)
        // Before any `@Query` is live, so the repair is not racing a view that
        // is already reading the rows it rewrites.
        SkyEntry.repairLegacyRows(in: container.mainContext)
        self.container = container
        // Siri · Spotlight 인텐트가 같은 저장소를 읽게 한다 (→ Support/SkyIntents.swift).
        AppDependencyManager.shared.add(dependency: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // 개발자가 보낸 의견에 답장하면, 앱이 앞으로 올 때 답장을 시트로 보여 준다 (LeeoKit).
                .leeoFeedbackReplyNotice(SkyDexSpec.self)
                .storeFallbackNotice()
                // 창 크기로 접힘을 재서 아래로 흘린다. 시트 · 알림창도 접힌 선을 비킨다 (LeeoKit Fold).
                .foldAware()
                // Spotlight 에 싣는 하늘을 지금 것에 맞춘다. 열 때 한 번, 뒤로 보낼 때마다.
                .task { await SkyLibrary.reindex(container) }
                // 산 것 · 먼저 쓴 사람 · 파는 상품을 켤 때 한 번 읽는다 (→ Support/SkyPlan.swift).
                .task { await SkyStore.shared.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await SkyLibrary.reindex(container) } }
                    // 다른 기기에서 산 것 · 해지 · 환불을 앞으로 나올 때마다 다시 읽는다.
                    if phase == .active { Task { await SkyStore.shared.refresh() } }
                }
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
        #if DEBUG
        if ScreenshotDemo.isOn { return ScreenshotDemo.makeContainer() }
        #endif
        prepareStoreDirectory()
        settleCloudDefault()

        // 1. iCloud, unless it was turned off in the settings. Rows already on
        //    disk stay put and start uploading; a fresh install on a new phone
        //    pulls back whatever the account holds.
        if wantsCloud, proOpenAtLaunch,
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

        // 4. Last resort: run without persistence rather than not at all — and say so.
        return StoreFallback.memoryContainer(
            schema: Schema([SkyEntry.self]),
            after: CocoaError(.fileReadCorruptFile)
        )
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

    /// What the switch is when nobody has touched it.
    ///
    /// iCloud is Pro now. Before that it was on for everyone, and almost every
    /// sky collected so far is in someone's iCloud — so a phone that already has
    /// a collection on it keeps syncing, and so does someone who collected
    /// before the paywall and is installing again (`SkyStore`). A new phone with
    /// a new person on it starts with the switch off.
    private static let cloudDefaultKey = "skydex.cloud.defaultOn"

    static var wantsCloud: Bool {
        let defaults = UserDefaults.standard
        if let chosen = defaults.object(forKey: cloudEnabledKey) as? Bool { return chosen }
        return defaults.bool(forKey: cloudDefaultKey)
    }

    static func setWantsCloud(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: cloudEnabledKey)
    }

    /// Someone who collected before the paywall, back on a phone with nothing on it.
    static func preferCloudByDefault() {
        UserDefaults.standard.set(true, forKey: cloudDefaultKey)
    }

    /// Settled once, the first time this version opens: a collection already on
    /// disk means a person who had iCloud on without ever being asked.
    private static func settleCloudDefault() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: cloudDefaultKey) == nil else { return }
        let existing = FileManager.default.fileExists(atPath: storeDirectory.appending(path: "default.store").path)
        defaults.set(existing, forKey: cloudDefaultKey)
    }

    /// Whether Pro was open the last time the App Store was asked. Read before
    /// any of that can happen, so it is the last answer written down; nobody
    /// having asked yet is read as open, and the receipt check that follows
    /// corrects it from the next launch on. Losing Pro never touches a row —
    /// the store simply opens on this phone without syncing, as step 2 does.
    private static var proOpenAtLaunch: Bool { SkySnapshot.proOpen ?? true }

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

// MARK: - 저장소를 못 연 날
//
// 원래 저장소를 못 열면 이번 실행만 메모리에서 연다. 디스크의 기록은 건드리지 않는다.
// 예전에는 아무 말 없이 넘어가서, 사용자는 저장되는 줄 알고 계속 적었다 — 이제는 알린다.

enum StoreFallback {
    /// 이번 실행이 임시(메모리) 저장소로 열렸는가
    private(set) static var isActive = false

    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 메모리 저장소마저 안 되는 건 스키마 자체가 잘못된 것 — 개발 중에 바로 드러난다
            fatalError("메모리 저장소도 열지 못함: \(error)")
        }
    }
}

extension View {
    /// 임시 저장소로 열렸으면 한 번 알린다. 앱의 맨 바깥 화면에 붙인다.
    func storeFallbackNotice() -> some View {
        modifier(StoreFallbackNotice())
    }
}

private struct StoreFallbackNotice: ViewModifier {
    @State private var isPresented = StoreFallback.isActive

    func body(content: Content) -> some View {
        content.alert("기록을 열지 못했어요", isPresented: $isPresented) {
        } message: {
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
        }
    }
}
