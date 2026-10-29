import Foundation
import LeeoKit

/// The LeeoKit contract — one place for everything the app has to have decided.
///
/// The point of the protocol is that "나중에 정하지" becomes a compile error:
/// there is no default for `legal` or `monetization`, so an app cannot ship
/// without having answered where its privacy policy lives and whether it sells
/// anything.
///
/// Feedback and usage go to the **shared hub container**, not to a container of
/// this app's own — the same one every other app here reports into, told apart
/// by `appIdentifier`. The collection's own iCloud is a different container
/// entirely (`SkyDexApp.cloudContainer`, private database): what the user
/// collected never mixes with what they wrote to the developer.
enum SkyDexSpec: LeeoAppSpec {

    /// The name on the phone, not the name of the target.
    static let appName = "하늘색"
    static let developerEmail = "leeo@kakao.com"
    /// 친구에게 소개하기·리뷰 남기기 링크에 쓴다.
    static let appStoreID: String? = "6802295390"

    /// Public database, shared with the other apps. `appIdentifier` is what
    /// separates this app's feedback from theirs in one inbox.
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.leeo.SkyDex"
    )

    /// `docs/` served by GitHub Pages from `main`. No accounts exist, so there
    /// is no account deletion page to point at — deleting a photo is done in
    /// the app and there is nothing else held.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/SkyDex/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/SkyDex/support.html")!,
        createsAccounts: false,
        marketingURL: URL(string: "https://m1zz.github.io/SkyDex/")!
    )

    /// Free, with no StoreKit anywhere in the target. Declaring it is what
    /// removes the paywall, restore and terms obligations.
    static let monetization = LeeoMonetization.free

    /// Turning this from the default no-op to a real sink is what switches
    /// usage reporting on — `LeeoKit.bootstrap` sends nothing for an app that
    /// has not asked for it.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: SkyDexSpec.self)

    /// Only what is actually in this repository. Anything not listed stays
    /// `.unknown`, which reads as "아직 안 봤다" — the honest answer, and better
    /// than a checklist that is full because it was filled in optimistically.
    static let capabilities = LeeoCapabilities(
        implemented: [
            .cloudSync,            // SwiftData + CloudKit private database
            .structuredStorage,    // SwiftData
            .schemaMigration,      // 경량 마이그레이션 + SkyEntry.repairLegacyRows
            .autosaveRecovery,     // 열리지 않는 저장소를 지우지 않고 옆으로 치운다
            .globalErrorHandling,  // makeContainer 네 단계 폴백
            .crashReporting,       // LeeoDiagnostics (MetricKit)
            .analytics,
            .feedbackChannel,
            .policyLinks,
            .supportPage,
            .emptyStates,
            .darkMode,
            .minimalPermissions,   // 카메라와 대략적 위치, 그 둘뿐
            .widgets
        ],
        notApplicable: [
            .accountDeletion: "계정이 없다. 로그인도 회원가입도 없고, 지울 것은 기기와 본인 iCloud에 있는 사진뿐이다.",
            .pushNotifications: "사용자에게 보내는 알림이 없다. 배경 모드는 CloudKit이 변경을 알리는 조용한 푸시에만 쓴다.",
            .purchaseReliability: "파는 것이 없다. 앱에 StoreKit 코드가 한 줄도 없다."
        ]
    )
}

extension SkyDexSpec {
    /// 무료 앱이라 LeeoStore 가 없다 — 팁만 혼자 받는다(앱을 열 때 `startStandalone()`, → RootView).
    /// 소모성 상품 셋, 작은 것부터. ⚠️ 기능을 여는 상품이 아니다.
    @MainActor static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.leeo.SkyDex.tip.small",
        "com.leeo.SkyDex.tip.medium",
        "com.leeo.SkyDex.tip.large",
    ]))
}

/// 팁을 부탁할 만한 순간 — 지금까지 모은 하늘 수. 한 장 찍을 때마다 하나씩 는다.
enum SkyDexTipMoments {
    /// 모은 하늘 수. 큰 것부터.
    static let collected = [100, 30, 10]

    /// 넘어선 순간, 인상적인 것부터.
    static func reached(collectedCount count: Int) -> [LeeoTipMoment] {
        collected.filter { count >= $0 }.map { threshold in
            LeeoTipMoment(id: "skies.\(threshold)",
                          message: String(localized: "지금까지 하늘 \(count)장을 모았어요",
                                          comment: "Tip ask card: how many skies the person has collected"))
        }
    }
}
