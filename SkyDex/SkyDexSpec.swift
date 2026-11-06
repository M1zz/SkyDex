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

    /// **판은 무료로 끝까지, 모은 것을 다르게 보는 것은 Plus, 지키고 홈 화면에 꺼내는 것은 Pro.**
    ///
    /// 무료 다운로드 + 무료 · Plus · Pro. 유료 칸마다 주 · 월 · 연 구독(한 구독 그룹)과 평생.
    /// 칸마다 무엇이 열리는지는 `SkyFeature.tier` 한 곳에 있다(→ Support/SkyPlan.swift).
    /// 1.0.4 빌드 8까지 받은 사람은 Pro 를 그대로 쓴다(`SkyProducts.isEarlySky`).
    ///
    /// ⚠️ 칸 상품을 스토어에서 한 번도 못 불러온 기기는 아무것도 잠그지 않는다(`SkyStore.sellsPlans`).
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: SkyProducts.productIDs,
            // 자체 약관이 없으므로 애플 표준 사용권 계약(EULA)을 건다. 구독을 파는 앱의 심사 필수 항목이다.
            termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            gate: LeeoGatePolicy(
                // 되풀이는 처음 한 번은 그대로 보여 준다(→ SkyFreeTaste). 팔레트는 흐린 미리보기.
                freeLimits: [SkyFeature.repeats.rawValue: 1],
                proOnly: Set(SkyFeature.allCases.filter { $0 != .repeats }.map(\.rawValue))),
            // 개발자 응원 팁. 아무것도 열지 않는다. 응원 부탁은 이미 Pro 인 사람에게만(→ ArchiveView).
            tipJar: LeeoTipJarConfig(productIDs: SkyProducts.tipProductIDs)))

    /// 금고가 위젯과 함께 쓰는 공유 컨테이너도 백업한다.
    static let appGroups = ["group.com.leeo.SkyDex"]

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
            .widgets,
            .purchaseReliability   // LeeoStore: 거래 리스너 · 서명 확인 · 복원 · 오프라인 캐시
        ],
        notApplicable: [
            .accountDeletion: "계정이 없다. 로그인도 회원가입도 없고, 지울 것은 기기와 본인 iCloud에 있는 사진뿐이다.",
            .pushNotifications: "사용자에게 보내는 알림이 없다. 배경 모드는 CloudKit이 변경을 알리는 조용한 푸시에만 쓴다."
        ]
    )
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
