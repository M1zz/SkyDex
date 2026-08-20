import CloudKit
import CoreData
import Foundation
import Observation

/// Whether the collection is being kept anywhere but this phone, and when it
/// last was.
///
/// Sync is the one feature whose whole value is a promise about the future —
/// that the photos will still be there after a phone goes into a river. A
/// promise with no way to check it is worth nothing, so the archive says out
/// loud what is actually true right now: on, off, working, or last agreed at
/// half past two.
///
/// It reports; it does not drive. SwiftData does the syncing. This asks CloudKit
/// whether there is an account, listens to the events Core Data posts
/// underneath, and keeps the last good one — written down, so a fresh launch
/// starts at "그때 맞췄습니다" rather than at nothing.
@Observable
@MainActor
final class CloudSync {

    static let shared = CloudSync()

    enum State: Equatable {
        /// The store opened without iCloud — no entitlement, or a build that
        /// never had one. Local, and honest about it.
        case local
        /// Syncing is on, but nobody is signed in to iCloud on this device.
        case noAccount
        /// On, and nothing has happened yet this launch.
        case idle
        /// A push or a pull is in flight.
        case working
        /// Last agreed with iCloud at this moment.
        case agreed(Date)
        /// Something failed. The rows are still on disk — which is the only part
        /// of this worth saying to anyone.
        case failed
    }

    private(set) var state: State = .local

    private var syncing = false
    private var hasAccount = false
    private var inFlight = 0
    private var observers: [NSObjectProtocol] = []

    private let defaults = UserDefaults.standard
    private static let lastAgreedKey = "skydex.cloud.lastAgreed"

    private init() {}

    /// Called once, from `SkyDexApp.init`, with whether the container that
    /// actually opened is the iCloud one.
    func begin(syncing: Bool) {
        guard !self.syncing, syncing else { return }
        self.syncing = true
        state = .idle

        observers.append(NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = note.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return }
            // Only the three facts, so nothing that is not `Sendable` crosses
            // over. An event has ended when it has an end date.
            let at = event.endDate
            let succeeded = event.succeeded
            Task { @MainActor [weak self] in
                self?.absorb(at: at, succeeded: succeeded)
            }
        })

        // Signing out mid-session is the one change that makes every other
        // answer here wrong.
        observers.append(NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.checkAccount() }
        })

        Task { await checkAccount() }
    }

    /// Asked of CloudKit rather than guessed at. `ubiquityIdentityToken` answers
    /// a question about iCloud Drive, which this app does not use, and answers
    /// it with `nil` for reasons that have nothing to do with whether the
    /// collection is syncing.
    ///
    /// Safe to call only because reaching here means the mirroring delegate is
    /// already talking to this very container.
    private func checkAccount() async {
        let status = try? await CKContainer(identifier: SkyDexApp.cloudContainer).accountStatus()
        hasAccount = status == .available
        if inFlight == 0 { state = settled() }
    }

    private func absorb(at: Date?, succeeded: Bool) {
        guard syncing else { return }

        guard let at else {
            inFlight += 1
            state = .working
            return
        }

        inFlight = max(0, inFlight - 1)

        guard succeeded else {
            // Failing for want of an account is the ordinary shape of being
            // signed out, not a fault to alarm anyone with.
            state = hasAccount ? .failed : .noAccount
            return
        }

        defaults.set(at, forKey: Self.lastAgreedKey)
        hasAccount = true
        state = inFlight > 0 ? .working : .agreed(at)
    }

    /// What to say when nothing is in flight.
    private func settled() -> State {
        guard syncing else { return .local }
        guard hasAccount else { return .noAccount }
        if let last = defaults.object(forKey: Self.lastAgreedKey) as? Date { return .agreed(last) }
        return .idle
    }

    /// One line, at the foot of the archive. Every branch says where the photos
    /// are before it says anything about iCloud, because that is the question
    /// being asked.
    var line: String {
        switch state {
        case .local:
            return "사진은 이 기기에 저장됩니다."
        case .noAccount:
            return "사진은 이 기기에 저장됩니다. iCloud에 로그인하면 기기를 바꿔도 남습니다."
        case .idle:
            return "iCloud에 함께 보관됩니다."
        case .working:
            return "iCloud와 맞추는 중입니다."
        case .agreed(let when):
            return "iCloud에 보관됨 · \(Self.stamp.string(from: when)) 맞춤"
        case .failed:
            return "iCloud와 맞추지 못했습니다. 사진은 이 기기에 그대로 있습니다."
        }
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.setLocalizedDateFormatFromTemplate("M월 d일 HH:mm")
        return formatter
    }()
}
