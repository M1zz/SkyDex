//
//  PaywallView.swift
//  SkyDex
//
//  하늘색의 세 칸(무료 · Plus · Pro)을 파는 한 장.
//  머리말 → (막힌 까닭) → 들어온 자리의 칸 → 다른 칸 → 무료 → 비교표 → 약관.
//
//  **판은 끝까지 무료라고 먼저 말한다.** 값을 받는 것은 모은 것을 다르게 보는 것(Plus)과
//  지키고 홈 화면에 꺼내는 것(Pro)뿐이다. 칸마다 연 구독과 평생을 먼저 보이고, 주 · 월은 펼쳐서 고른다.
//  첫 해 할인(App Store 첫 구독 할인)은 연 구독을 고르면 처음 보는 사람에게만 한 줄로 보인다.
//  스토어에서 불러오지 못한 상품의 단추는 서지 않는다.
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallView: View {
    /// 어디서 들어왔는가. 그 기능이 든 칸을 앞에 세우고, 막힌 까닭을 먼저 말한다.
    var highlight: SkyFeature?

    @State private var plans = SkyStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// 결제 시트를 이 페이월이 떠 있는 창에 띄운다 (→ SkyStore.purchase).
    @Environment(\.purchase) private var purchaseAction

    @State private var plusTerm: SkyPlanTerm = .yearly
    @State private var proTerm: SkyPlanTerm = .yearly
    @State private var loadingProducts = true
    @State private var redeemingCode = false

    /// 들어온 자리의 칸이 앞이다. 설정에서 들어오면 Plus 부터.
    private var order: [SkyTier] { highlight?.tier == .pro ? [.pro, .plus] : [.plus, .pro] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let highlight { reason(highlight) }
                    plansStatus
                    ForEach(order, id: \.self) { tierCard($0) }
                    freeCard
                    PlanComparisonTable()
                    if let message = plans.failureMessage, !plans.products.isEmpty {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.body)
                            .foregroundStyle(.orange)
                    }
                    legal
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // 세로로 서는 툴바(아이폰 듀오)에서는 아이콘 없는 아이템이 사라진다.
                    Button { dismiss() } label: { Label("나중에", systemImage: "xmark") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await plans.restore()
                            if plans.tier > .free { dismiss() }
                        }
                    } label: {
                        Label("구매 복원", systemImage: "arrow.clockwise")
                    }
                    .disabled(plans.isWorking)
                }
            }
            .offerCodeRedemption(isPresented: $redeemingCode) { _ in
                Task {
                    await plans.refresh()
                    if plans.tier > .free { dismiss() }
                }
            }
            .task {
                LeeoAnalyticsCenter.track(.paywallShown(reason: highlight?.rawValue ?? "settings"))
                await loadPlans()
            }
        }
    }

    // MARK: 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("하늘색 Plus · Pro")
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("모은 하늘을 더 깊이 보고, 오래 지켜요. 연 구독이나 평생 중에 고르세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 막힌 자리에서 들어왔을 때 첫 줄. 무엇이 막혔고, 이미 모은 것은 어떻게 되는지.
    private func reason(_ feature: SkyFeature) -> some View {
        let (title, note): (String, String) = switch feature {
        case .palette: (String(localized: "팔레트는 Plus에서 열려요"),
                        String(localized: "내 하늘이 어떤 색으로 모였는지, 갈래별로 또렷하게 펼쳐 봐요."))
        case .repeats: (String(localized: "되풀이는 Plus에서 열려요"),
                        String(localized: "같은 시각인데 날마다 이렇게 달라요. 처음 한 번은 그대로 보여 드렸어요."))
        case .recolor: (String(localized: "다른 날의 하늘로는 Plus에서 열려요"),
                        String(localized: "이 사진에 다른 날의 하늘색을 입혀 보고, 그대로 공유해요."))
        case .cloud:   (String(localized: "iCloud 보관은 Pro에서 열려요"),
                        String(localized: "지금 하늘은 이 기기에 그대로 있어요. Pro면 폰을 바꿔도 모은 하늘이 이어져요."))
        case .widgets: (String(localized: "위젯은 Pro에서 열려요"),
                        String(localized: "앱을 열지 않아도 오늘의 판과 빈 칸이 홈 화면에 보여요."))
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(note)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: 칸

    private func tierCard(_ tier: SkyTier) -> some View {
        card(highlighted: highlight?.tier == tier && plans.tier < tier) {
            cardTitle(tier.title, current: plans.tier == tier)
            tagline(tier == .plus
                    ? String(localized: "모은 색을 갈래별로 펼치고, 같은 시각의 하늘을 나란히.")
                    : String(localized: "폰을 바꿔도 하늘은 그대로, 홈 화면에서도 오늘의 판을."))
            row("checkmark.circle", tier == .plus ? String(localized: "무료의 모든 것") : String(localized: "Plus의 모든 것"))
            ForEach(features(in: tier)) { feature in
                row(feature.systemImage, feature.title, note: feature.note, highlighted: feature == highlight)
            }
            // 이미 이 칸 이상이면 살 것이 없다. 구독을 평생으로 바꾸는 길은 설정에 있다.
            if plans.tier < tier, hasAnyProduct(tier) {
                PlanTermPicker(term: term(tier), products: products(tier),
                               lifetimeTitle: upgrades(tier) ? String(localized: "Pro 평생으로 올리기") : nil)
                    .padding(.top, 4)
                buyButton(tier)
            }
        }
    }

    /// 그 칸에서 새로 열리는 것. 지금 누른 자리가 맨 위.
    private func features(in tier: SkyTier) -> [SkyFeature] {
        let opened = SkyFeature.opened(by: tier)
        guard let highlight, opened.contains(highlight) else { return opened }
        return [highlight] + opened.filter { $0 != highlight }
    }

    private var freeCard: some View {
        card(highlighted: false) {
            cardTitle(SkyTier.free.title, current: plans.tier == .free)
            tagline(String(localized: "하늘을 찍을 때마다 하루의 색 마흔여덟 칸이 채워져요. 판은 전부 무료."))
            row("camera", String(localized: "촬영 · 사진에서 고르기"))
            row("circle.grid.3x3", String(localized: "48칸 판 · 색 이름 · 한 마디"))
            row("list.bullet", String(localized: "기록 (모은 하늘 전부 시간순)"))
            row("square.and.arrow.up", String(localized: "사진 저장 · 공유 · 지우기"))
        }
    }

    private func term(_ tier: SkyTier) -> Binding<SkyPlanTerm> { tier == .plus ? $plusTerm : $proTerm }

    /// Plus 평생을 이미 산 사람에게는 Pro 평생 자리에 올리기 상품을 세운다. 같은 값을 두 번 내게 두지 않는다.
    private func upgrades(_ tier: SkyTier) -> Bool { tier == .pro && plans.ownsLifetime(.plus) }

    private func products(_ tier: SkyTier) -> PlanTermPicker.Products {
        typealias P = SkyProducts
        if tier == .plus {
            return .init(weekly: plans.product(P.plusWeeklyID), monthly: plans.product(P.plusMonthlyID),
                         yearly: plans.product(P.plusYearlyID), lifetime: plans.product(P.plusLifetimeID))
        }
        return .init(weekly: plans.product(P.proWeeklyID), monthly: plans.product(P.proMonthlyID),
                     yearly: plans.product(P.proYearlyID),
                     lifetime: plans.product(upgrades(tier) ? P.upgradeID : P.proLifetimeID))
    }

    private func hasAnyProduct(_ tier: SkyTier) -> Bool {
        SkyPlanTerm.allCases.contains { products(tier)[$0] != nil }
    }

    private func buyButton(_ tier: SkyTier) -> some View {
        let chosen = term(tier).wrappedValue
        let product = products(tier)[chosen]
        let title: String = switch chosen {
        case .weekly:   String(localized: "주 구독 시작")
        case .monthly:  String(localized: "월 구독 시작")
        case .yearly:   String(localized: "연 구독 시작")
        case .lifetime: upgrades(tier) ? String(localized: "Pro 평생으로 올리기") : String(localized: "평생으로 사기")
        }
        return Button {
            guard let product else { return }
            Task {
                await plans.purchase(product, using: purchaseAction)
                if plans.tier >= tier { dismiss() }
            }
        } label: {
            Group {
                if plans.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(plans.isWorking || product == nil)
        .accessibilityLabel(title)
    }

    // MARK: 요금제를 못 불러왔을 때

    @ViewBuilder
    private var plansStatus: some View {
        if plans.products.isEmpty && loadingProducts {
            HStack(spacing: 10) {
                ProgressView()
                Text("값을 불러오는 중…").font(.body).foregroundStyle(.secondary)
            }
        } else if plans.products.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("요금제를 불러오지 못했어요. 인터넷 연결을 확인하고 다시 불러와 주세요.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await loadPlans() }
                } label: {
                    Label("다시 불러오기", systemImage: "arrow.clockwise").font(.body)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// 첫 조회가 빈손이면 한 번 더 청한다. 샌드박스(심사 환경)는 첫 조회가 비어 오는 일이 잦다.
    private func loadPlans() async {
        loadingProducts = true
        await plans.loadProducts()
        if plans.products.isEmpty {
            try? await Task.sleep(for: .seconds(1.5))
            await plans.loadProducts()
        }
        loadingProducts = false
    }

    // MARK: 약관 (구독을 파는 앱의 심사 필수 항목)

    private var legal: some View {
        VStack(alignment: .leading, spacing: 10) {
            if plans.products.contains(where: { $0.subscription != nil }) {
                Text("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 요금으로 자동 갱신되며, Apple 계정으로 결제돼요. 연 구독을 처음 시작하면 첫 해는 할인된 값일 수 있고, 그 뒤에는 정가로 갱신돼요. 해지와 관리는 App Store 계정 설정에서 해요. 평생은 구독이 아니라 한 번 결제예요.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits {
                HStack(spacing: 18) { legalLinks }
                VStack(alignment: .leading, spacing: 10) { legalLinks }
            }
            .font(.body)
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        if let terms = SkyDexSpec.monetization.subscriptionTermsURL {
            Button("이용약관") { openURL(terms) }
        }
        Button("개인정보 처리방침") { openURL(SkyDexSpec.legal.privacyURL) }
        Button {
            redeemingCode = true
        } label: {
            Label("코드 사용", systemImage: "ticket")
        }
        .disabled(plans.isWorking)
    }

    // MARK: 부속

    private func card<Content: View>(highlighted: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Color(.secondarySystemBackground))
                shape.strokeBorder(highlighted ? Color.accentColor : .clear, lineWidth: 2)
            }
    }

    private func cardTitle(_ title: String, current: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            if current {
                Text("지금 쓰는 칸")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private func tagline(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ icon: String, _ title: String, note: String? = nil, highlighted: Bool = false) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                if let note {
                    Text(note).font(.body).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
        }
        .font(.body)
        .padding(.vertical, highlighted ? 6 : 0)
        .padding(.horizontal, highlighted ? 8 : 0)
        .background {
            if highlighted {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.08))
            }
        }
    }
}

// MARK: - 잠긴 자리에서 부르는 길

extension View {
    /// `feature` 가 켜지면 그 기능의 페이월을 낸다.
    func paywall(for feature: Binding<SkyFeature?>) -> some View {
        sheet(item: feature) { PaywallView(highlight: $0) }
    }
}

/// 잠긴 줄 옆에 붙는 작은 자물쇠. 눌러 보기 전에 잠긴 걸 알 수 있어야 한다.
struct PlanLockBadge: View {
    let feature: SkyFeature

    var body: some View {
        Label {
            Text(verbatim: feature.tier == .plus ? "Plus" : "Pro")
        } icon: {
            Image(systemName: "lock.fill")
        }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.fill.tertiary))
            .accessibilityLabel(Text("잠김, \(feature.tier.title) 필요", comment: "VoiceOver: locked, needs this tier"))
    }
}

// MARK: - 주 · 월 · 연 · 평생

enum SkyPlanTerm: CaseIterable {
    case weekly, monthly, yearly, lifetime
}

/// 칸 하나를 사는 길 고르기. 연 구독 · 평생을 먼저 보이고, 주 · 월은 펼쳐서 고른다.
struct PlanTermPicker: View {
    struct Products {
        var weekly, monthly, yearly, lifetime: Product?

        subscript(term: SkyPlanTerm) -> Product? {
            switch term {
            case .weekly: weekly
            case .monthly: monthly
            case .yearly: yearly
            case .lifetime: lifetime
            }
        }
    }

    @Binding var term: SkyPlanTerm
    let products: Products
    /// 평생 자리를 올리기로 팔 때의 이름.
    var lifetimeTitle: String?

    @State private var showsShortTerms = false
    @State private var introEligible = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            options(.yearly, .lifetime)
            if hasShortTerms {
                if showsShortTerms || term == .weekly || term == .monthly {
                    options(.weekly, .monthly)
                } else {
                    Button("주 · 월 구독도 보기") { showsShortTerms = true }
                        .font(.body)
                }
            }
            if let note {
                Text(note)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            // 연 구독을 못 불러왔으면 고를 수 있는 첫 길로 옮긴다.
            if products[term] == nil,
               let first = [SkyPlanTerm.yearly, .lifetime, .monthly, .weekly].first(where: { products[$0] != nil }) {
                term = first
            }
        }
        .task(id: products.yearly?.id) {
            introEligible = await products.yearly?.subscription?.isEligibleForIntroOffer ?? false
        }
    }

    private var hasShortTerms: Bool { products.weekly != nil || products.monthly != nil }

    /// 아주 큰 글자에서는 위아래로 세운다. 나란히 두면 가격이 몇 줄로 꺾인다.
    private func options(_ a: SkyPlanTerm, _ b: SkyPlanTerm) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            option(a)
            option(b)
        }
    }

    private var note: String? {
        switch term {
        case .yearly:
            guard introEligible, let offer = products.yearly?.subscription?.introductoryOffer,
                  offer.paymentMode == .payUpFront || offer.paymentMode == .payAsYouGo else { return nil }
            return String(format: LeeoLadderText.introFormat, offer.displayPrice)
        case .lifetime:
            guard lifetimeTitle == nil, let yearly = products.yearly?.price, let lifetime = products.lifetime?.price,
                  yearly > 0 else { return nil }
            let years = Int(NSDecimalNumber(decimal: lifetime / yearly).doubleValue.rounded(.down))
            return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
        case .weekly, .monthly:
            return nil
        }
    }

    private func title(_ term: SkyPlanTerm) -> String {
        switch term {
        case .weekly: String(localized: "주 구독")
        case .monthly: String(localized: "월 구독")
        case .yearly: LeeoLadderText.yearly
        case .lifetime: lifetimeTitle ?? LeeoLadderText.lifetime
        }
    }

    private func price(_ term: SkyPlanTerm) -> String? {
        guard let price = products[term]?.displayPrice else { return nil }
        switch term {
        case .weekly: return String(localized: "\(price) / 주", comment: "Weekly subscription price")
        case .monthly: return String(localized: "\(price) / 월", comment: "Monthly subscription price")
        case .yearly: return String(format: LeeoLadderText.perYearFormat, price)
        case .lifetime: return price
        }
    }

    @ViewBuilder
    private func option(_ value: SkyPlanTerm) -> some View {
        if let price = price(value) {
            let selected = term == value
            Button {
                term = value
            } label: {
                VStack(spacing: 2) {
                    Text(title(value)).font(.body.weight(.semibold))
                    Text(price).font(.body).monospacedDigit()
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 1.5 : 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

// MARK: - 비교표

/// 세 칸이 무엇을 주는지 한눈에. 아주 큰 글자에서는 기능마다 세 칸을 아래로 적는다.
struct PlanComparisonTable: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    /// 칸 하나에 적는 것.
    private enum Mark {
        case yes, no
        case partly(String)
    }

    private struct Line: Identifiable {
        let title: String
        let free: Mark
        let plus: Mark
        let pro: Mark
        var id: String { title }
    }

    private var lines: [Line] {[
        Line(title: String(localized: "촬영 · 사진에서 고르기"), free: .yes, plus: .yes, pro: .yes),
        Line(title: String(localized: "48칸 판 · 색 이름 · 한 마디"), free: .yes, plus: .yes, pro: .yes),
        Line(title: String(localized: "기록 (시간순)"), free: .yes, plus: .yes, pro: .yes),
        Line(title: String(localized: "사진 저장 · 공유 · 지우기"), free: .yes, plus: .yes, pro: .yes),
        Line(title: String(localized: "팔레트"), free: .partly(String(localized: "미리보기")), plus: .yes, pro: .yes),
        Line(title: String(localized: "되풀이"), free: .partly(String(localized: "첫 비교 한 번")), plus: .yes, pro: .yes),
        Line(title: String(localized: "다른 날의 하늘로"), free: .no, plus: .yes, pro: .yes),
        Line(title: String(localized: "iCloud 보관 · 이어 쓰기"), free: .no, plus: .no, pro: .yes),
        Line(title: String(localized: "위젯 2종"), free: .no, plus: .no, pro: .yes),
    ]}

    private let tiers: [(String, KeyPath<Line, Mark>)] = [
        (SkyTier.free.title, \.free), ("Plus", \.plus), ("Pro", \.pro),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("한눈에 비교")
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.title).font(.body.weight(.semibold))
                        ForEach(tiers, id: \.0) { name, path in
                            HStack { Text(name); Spacer(); mark(line[keyPath: path], in: name) }
                        }
                    }
                    .font(.body)
                    Divider()
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Color.clear.frame(height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                        ForEach(tiers, id: \.0) { name, _ in
                            Text(name).font(.body.weight(.semibold)).gridColumnAlignment(.center)
                        }
                    }
                    ForEach(lines) { line in
                        Divider()
                        GridRow {
                            Text(line.title).font(.body).fixedSize(horizontal: false, vertical: true)
                            ForEach(tiers, id: \.0) { name, path in mark(line[keyPath: path], in: name) }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// 칸 하나. VoiceOver 는 어느 칸인지 함께 읽는다 ("Pro: 포함").
    @ViewBuilder
    private func mark(_ mark: Mark, in tier: String) -> some View {
        switch mark {
        case .yes:
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.green)
                .accessibilityLabel(Text(verbatim: "\(tier): \(String(localized: "포함"))"))
        case .no:
            Image(systemName: "minus")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(verbatim: "\(tier): \(String(localized: "포함 안 됨"))"))
        case .partly(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(verbatim: "\(tier): \(text)"))
        }
    }
}
