//
//  SkyPlan.swift
//  SkyDex
//
//  하늘색의 세 칸(무료 · Plus · Pro)과 그것을 파는 자리.
//
//   · 무료: 찍기 · 사진에서 고르기, 하루 48칸 판과 빈 칸 길잡이, 색 이름, 한 마디, 기록(시간순),
//           사진 저장 · 공유 · 지우기. **판은 끝까지 무료다.**
//   · Plus: 팔레트(갈래별로 모아 보기), 되풀이(같은 시각, 다른 날), 다른 날의 하늘로.
//   · Pro:  Plus 전부 + iCloud에 함께 보관 · 이어 쓰기, 위젯 두 개.
//
//  ⚠️ 절대 잠그지 않는 것: 접근성, 이미 모은 하늘 보기 · 지우기(기록), 사진 저장 · 공유,
//     저장소를 못 열었다는 알림. 백업 금고(LeeoVault)도 그대로 무료다 — 동기화가 아니라 지키는 일이다.
//
//  상품 로드 · 구매 · 복원 · 거래 리스너(다른 기기, 가족 공유, 환불, 구독 만료) · 팁은 전부 `LeeoStore` 안에 있다.
//  이 클래스는 그 값을 SwiftUI `@Observable` 로 옮겨 적고, 칸 하나로 줄여 줄 뿐이다.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
import WidgetKit
import LeeoKit

/// 칸. 값이 클수록 더 많이 연다. Pro 는 Plus 를 전부 포함한다.
enum SkyTier: Int, Comparable, CaseIterable {
    case free, plus, pro

    static func < (a: SkyTier, b: SkyTier) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .free: String(localized: "무료")
        case .plus: String(localized: "하늘색 Plus")
        case .pro:  String(localized: "하늘색 Pro")
        }
    }
}

/// 값을 받고 여는 것. 페이월 · 설정 · 잠금 자리가 모두 이 목록만 읽는다.
enum SkyFeature: String, CaseIterable, Identifiable {
    case palette
    case repeats
    case recolor
    case cloud
    case widgets

    var id: String { rawValue }

    /// 이 기능을 여는 가장 낮은 칸.
    var tier: SkyTier {
        switch self {
        case .palette, .repeats, .recolor: .plus
        case .cloud, .widgets:             .pro
        }
    }

    static func opened(by tier: SkyTier) -> [SkyFeature] { allCases.filter { $0.tier == tier } }

    var title: String {
        switch self {
        case .palette: String(localized: "팔레트")
        case .repeats: String(localized: "되풀이")
        case .recolor: String(localized: "다른 날의 하늘로")
        case .cloud:   String(localized: "iCloud에 함께 보관")
        case .widgets: String(localized: "위젯 두 개")
        }
    }

    var note: String {
        switch self {
        case .palette: String(localized: "모은 색을 파랑 · 회색 · 노을빛 갈래별로 펼쳐 봐요.")
        case .repeats: String(localized: "같은 시각, 다른 날의 하늘을 나란히 견줘요.")
        case .recolor: String(localized: "사진에 다른 날의 색을 입혀 보고 그대로 공유해요.")
        case .cloud:   String(localized: "폰을 바꿔도 모은 하늘이 그대로 이어져요.")
        case .widgets: String(localized: "오늘의 하늘과 오늘의 판을 홈 화면 · 잠금 화면에서 봐요.")
        }
    }

    var systemImage: String {
        switch self {
        case .palette: "square.grid.3x3.fill"
        case .repeats: "arrow.trianglehead.2.clockwise"
        case .recolor: "paintpalette"
        case .cloud:   "icloud"
        case .widgets: "apps.iphone"
        }
    }
}

enum SkyProducts {

    // MARK: - 상품 ID
    //
    // ⚠️ App Store Connect · Products.storekit 과 글자 하나까지 같아야 한다.
    //    주 · 월 · 연 구독 여섯은 한 구독 그룹("하늘색")에 넣고, Pro 를 위 단계로 둔다.

    private static let base = "com.leeo.SkyDex"

    static let plusWeeklyID   = base + ".plus.weekly"
    static let plusMonthlyID  = base + ".plus.monthly"
    static let plusYearlyID   = base + ".plus.yearly"
    static let plusLifetimeID = base + ".plus.lifetime"
    static let proWeeklyID    = base + ".pro.weekly"
    static let proMonthlyID   = base + ".pro.monthly"
    static let proYearlyID    = base + ".pro.yearly"
    static let proLifetimeID  = base + ".pro.lifetime"
    /// Plus 평생을 산 사람이 Pro 평생으로 올리는 값.
    static let upgradeID      = base + ".pro.upgrade"
    /// 구독 중인 사람의 졸업가 Pro 평생 (→ LeeoGraduation).
    static let graduateID     = base + ".pro.graduate"

    /// 개발자 응원 팁 (소모성 셋, 작은 것부터). 아무것도 열지 않는다 — `productIDs` 에 넣지 않는다.
    static let tipProductIDs = [base + ".tip.small", base + ".tip.medium", base + ".tip.large"]

    /// **상품마다 여는 칸.** 구독은 같은 칸의 평생과 같은 권한, 올리기 · 졸업은 Pro 평생이다.
    static let tierByProduct: [String: SkyTier] = [
        plusWeeklyID: .plus, plusMonthlyID: .plus, plusYearlyID: .plus, plusLifetimeID: .plus,
        proWeeklyID: .pro, proMonthlyID: .pro, proYearlyID: .pro, proLifetimeID: .pro,
        upgradeID: .pro, graduateID: .pro,
    ]

    /// 페이월이 불러올 상품이자 칸을 여는 상품. 스토어에 아직 없는 상품은 불러와지지 않고, 그 단추는 서지 않는다.
    static let productIDs = [
        plusWeeklyID, plusMonthlyID, plusYearlyID, plusLifetimeID,
        proWeeklyID, proMonthlyID, proYearlyID, proLifetimeID,
        upgradeID, graduateID,
    ]

    /// 자동 갱신 구독 (구독 졸업을 제안할 대상).
    static let subscriptionIDs: Set<String> = [
        plusWeeklyID, plusMonthlyID, plusYearlyID, proWeeklyID, proMonthlyID, proYearlyID,
    ]

    /// 끝나지 않는 것.
    static let lifetimeIDs: Set<String> = [plusLifetimeID, proLifetimeID, upgradeID, graduateID]

    static func tier(owning ids: Set<String>) -> SkyTier {
        ids.compactMap { tierByProduct[$0] }.max() ?? .free
    }

    // MARK: - 먼저 모은 사람

    /// 페이월이 생기기 전 마지막 빌드(1.0.4 빌드 8). 그때까지 받은 사람은 Pro 평생처럼 쓴다 —
    /// iCloud 보관과 위젯이 원래 무료였고, 거의 모든 하늘이 이미 iCloud에 있다.
    /// ⚠️ 페이월이 든 빌드의 번호는 이보다 커야 한다(Config/Version.xcconfig).
    static let lastBuildBeforePaywall = 8

    /// App Store 에서 처음 받은 빌드가 페이월 전인가.
    /// `originalAppVersion` 은 iOS 에서 빌드 번호다. 샌드박스 · Xcode 는 늘 "1.0" 을 돌려주므로 실제 App Store 만 본다.
    static func isEarlySky() async -> Bool {
        guard case .verified(let app)? = try? await AppTransaction.shared,
              app.environment == .production,
              let build = Int(app.originalAppVersion.split(separator: ".").first ?? "") else { return false }
        return build <= lastBuildBeforePaywall
    }
}

/// 무료로도 써 보고 알 만큼 여는 것.
enum SkyFreeTaste {
    /// 팔레트 미리보기 위에 Plus 카드를 앞세우기 시작하는 하늘 수. 그 전에는 흐린 미리보기와 한 줄만.
    static let paletteCardAfter = 10

    /// 되풀이는 처음 한 번 그대로 보여 준다. 그 한 번을 이미 봤는가.
    private static let repeatSeenKey = "skydex.free.repeatSeen"
    static var hasSeenRepeat: Bool { UserDefaults.standard.bool(forKey: repeatSeenKey) }
    static func markRepeatSeen() { UserDefaults.standard.set(true, forKey: repeatSeenKey) }
}

@MainActor
@Observable
final class SkyStore {

    static let shared = SkyStore()

    @ObservationIgnored let store: LeeoStore

    /// 산 것(과 먼저 쓴 사람)이 여는 칸. 화면은 이것 말고 `allows` 를 본다.
    private(set) var tier: SkyTier = .free

    /// **유료 칸을 실제로 팔고 있는가.** 스토어에서 칸 상품을 한 번이라도 불러온 기기만 true.
    ///
    /// ⚠️ 상품을 App Store Connect 에 세우기 전에 이 빌드가 나가면, 아무도 살 수 없는 자물쇠만 선다.
    ///    그래서 상품을 한 번도 못 본 기기는 막지 않고 열어 둔다. 네트워크가 잠깐 끊겨 못 불러온 것과
    ///    헷갈리지 않게, 한 번 본 기기는 그 뒤로 계속 판다고 본다.
    private(set) var sellsPlans: Bool = UserDefaults.standard.bool(forKey: SkyStore.sellsPlansKey)

    private(set) var products: [Product] = []
    private(set) var ownedProductIDs: Set<String> = []
    /// 지금 살아 있는 구독. 있으면 설정에 '평생으로 바꾸기' 가 선다.
    private(set) var subscription: LeeoGraduation.Subscription?
    private(set) var isWorking = false
    /// 사다가 막혔을 때 그대로 보여 줄 말.
    private(set) var failureMessage: String?

    /// 페이월 전에 받은 사람이라 Pro 를 그대로 쓰는가.
    var isEarlySky: Bool { store.isGrandfathered }

    /// 이번 실행에서 영수증을 실제로 읽었는가. 읽기 전에는 위젯 쪽 거울에 쓰지 않는다 —
    /// 빈 권한을 먼저 적으면 처음 켠 구매자의 위젯이 잠긴다.
    @ObservationIgnored private var entitlementsChecked = false
    @ObservationIgnored private var observation: AnyCancellable?

    private static let sellsPlansKey = "skydex.plans.seen"

    private init() {
        guard let config = SkyDexSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다. SkyDexSpec.monetization 을 확인할 것")
        }
        store = LeeoStore(config: config, grandfather: { await SkyProducts.isEarlySky() })
        // objectWillChange 는 바뀌기 **직전**에 온다. 다음 차례로 미뤄 읽는다.
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.pull() }
        }
        pull()
    }

    /// 팁(응원). 기능을 열지 않는다.
    var tipJar: LeeoTipJar {
        guard let tipJar = store.tipJar else { preconditionFailure("계약에 팁이 없다") }
        return tipJar
    }

    /// 이 기능을 써도 되는가. 아직 팔지 않는 기기에서는 모두 열려 있다.
    func allows(_ feature: SkyFeature) -> Bool { !sellsPlans || tier >= feature.tier }

    func ownsLifetime(_ tier: SkyTier) -> Bool {
        ownedProductIDs.contains { SkyProducts.lifetimeIDs.contains($0) && SkyProducts.tierByProduct[$0] == tier }
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    // MARK: - 상태 맞추기

    /// 영수증을 다시 읽고 상품을 부른다. 앱이 켜질 때와 앞으로 나올 때마다.
    func refresh() async {
        await store.refreshEntitlements()
        entitlementsChecked = true
        await store.loadProducts()
        subscription = await LeeoGraduation.currentSubscription(among: SkyProducts.subscriptionIDs)
        pull()
    }

    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    /// 구독 졸업을 제안할 때인가. 6개월째와 갱신 7일 전에 한 번씩.
    var graduationIsDue: Bool {
        guard let subscription, product(SkyProducts.graduateID) != nil, !ownsLifetime(.pro) else { return false }
        return LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered())
    }

    func markGraduationOffered() { LeeoGraduation.markOffered() }

    // MARK: - 사기 / 되찾기

    /// ⚠️ `action` 은 화면의 `@Environment(\.purchase)` 다. 아이패드에서 결제 시트가 엉뚱한 창에 뜨지 않게.
    func purchase(_ product: Product, using action: PurchaseAction) async {
        _ = await store.purchase(product) { try await action($0) }
        entitlementsChecked = true
        subscription = await LeeoGraduation.currentSubscription(among: SkyProducts.subscriptionIDs)
        pull()
    }

    func restore() async {
        await store.restore()
        entitlementsChecked = true
        pull()
        if tier == .free, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 산 기록을 찾지 못했어요.")
        }
    }

    // MARK: -

    private func pull() {
        tier = store.isGrandfathered ? .pro : SkyProducts.tier(owning: store.purchasedProductIDs)
        products = store.products
        ownedProductIDs = store.purchasedProductIDs
        isWorking = store.purchasingProductID != nil || store.isRestoring
        failureMessage = store.lastError

        if !sellsPlans, !store.products.isEmpty {
            sellsPlans = true
            UserDefaults.standard.set(true, forKey: Self.sellsPlansKey)
        }
        // 먼저 모은 사람이 새 폰에 다시 받았으면, 원래 그랬듯 iCloud 에서 하늘을 되찾게 둔다.
        if store.isGrandfathered { SkyDexApp.preferCloudByDefault() }

        guard entitlementsChecked else { return }
        // 위젯은 결제를 볼 수 없다. 앱이 공유 컨테이너에 한 줄로 적어 두고, 바뀐 판에만 다시 그리게 한다.
        if SkySnapshot.setProOpen(allows(.widgets)) { WidgetCenter.shared.reloadAllTimelines() }
    }
}
