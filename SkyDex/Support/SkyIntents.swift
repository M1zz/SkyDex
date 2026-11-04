//
//  SkyIntents.swift
//  SkyDex
//
//  "하늘색으로 하늘 찍어줘" — 하늘이 좋을 때 앱을 찾을 새 없이 카메라를 바로 연다.
//  모은 하늘은 Spotlight · Siri 가 찾는다 — 적어 둔 한 줄과 하늘 빛깔(분홍 · 노랑 …)로. 누르면 그 하늘 카드가 열린다.
//  색인(IndexedEntity)은 iOS 18 부터라 그 부분만 나눠 둔다.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

@MainActor @Observable
final class SkyRouter {
    static let shared = SkyRouter()
    /// 늘어날 때마다 첫 화면이 카메라를 연다.
    var cameraRequest = 0
    /// 열어 달라는 하늘(uuid). 첫 화면이 그 하늘 카드를 열고 비운다.
    var entryRequest: UUID?
}

struct CaptureSkyIntent: AppIntent {
    static let title = LocalizedStringResource("하늘 찍기", comment: "Siri: open the camera to capture the sky")
    static let description = IntentDescription(
        LocalizedStringResource("카메라를 바로 열어 지금 하늘을 찍습니다.", comment: "Siri: capture sky description")
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        SkyRouter.shared.cameraRequest &+= 1
        return .result()
    }
}

// MARK: - 모은 하늘

struct SkyEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("하늘", comment: "Siri/Spotlight: one collected sky photo")
    )
    static let defaultQuery = SkyQuery()

    let id: UUID
    let note: String
    /// 하늘 빛깔 이름(분홍, 옅은 파랑 …), 읽는 사람의 언어로.
    let color: String
    let capturedAt: Date
    let thumbnail: Data?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(note.isEmpty ? color : note)",
            subtitle: "\(capturedAt.formatted(date: .abbreviated, time: .shortened))",
            image: thumbnail.map { .init(data: $0) }
        )
    }

    init(_ entry: SkyEntry) {
        id = entry.uuid
        note = entry.note
        color = SkyFamily.of(entry.lab).title
        capturedAt = entry.capturedAt
        thumbnail = entry.thumbnailData
    }
}

@available(iOS 18.0, *)
extension SkyEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.textContent = note
        set.keywords = [color]
        set.thumbnailData = thumbnail
        set.contentCreationDate = capturedAt
        return set
    }
}

struct SkyQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    func entities(for identifiers: [UUID]) async throws -> [SkyEntity] {
        let wanted = Set(identifiers)
        return SkyLibrary.entries(in: container).filter { wanted.contains($0.uuid) }.map(SkyEntity.init)
    }

    func entities(matching string: String) async throws -> [SkyEntity] {
        SkyLibrary.search(string, in: container)
    }

    /// 가장 최근에 찍은 하늘부터.
    func suggestedEntities() async throws -> [SkyEntity] {
        SkyLibrary.entries(in: container).prefix(20).map(SkyEntity.init)
    }
}

/// 하늘 카드를 연다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenSkyIntent: OpenIntent {
    static let title = LocalizedStringResource("하늘 열기", comment: "Siri/Spotlight: open a collected sky")
    static let description = IntentDescription(
        LocalizedStringResource("모아 둔 하늘 사진 한 장을 카드로 엽니다.", comment: "Siri: open sky description")
    )

    @Parameter(title: LocalizedStringResource("하늘", comment: "Siri/Spotlight: one collected sky photo"),
               description: LocalizedStringResource("열어 볼 하늘", comment: "Siri: sky parameter description"))
    var target: SkyEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SkyRouter.shared.entryRequest = target.id
        return .result()
    }
}

enum SkyLibrary {
    /// 최근에 찍은 것부터.
    static func entries(in container: ModelContainer) -> [SkyEntry] {
        let descriptor = FetchDescriptor<SkyEntry>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        return (try? ModelContext(container).fetch(descriptor)) ?? []
    }

    /// 적어 둔 한 줄과 하늘 빛깔 이름에서 찾는다(대소문자 · 악센트 무시).
    static func search(_ raw: String, in container: ModelContainer) -> [SkyEntity] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        func matches(_ s: String) -> Bool { s.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return entries(in: container).map(SkyEntity.init).filter { matches($0.note) || matches($0.color) }
    }

    /// Spotlight 에 싣는 하늘을 지금 것에 맞춘다. 앱을 열 때와 뒤로 보낼 때 부른다.
    static func reindex(_ container: ModelContainer) async {
        guard #available(iOS 18.0, *) else { return }
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: SkyEntity.self)
        try? await index.indexAppEntities(entries(in: container).map(SkyEntity.init))
    }
}

// MARK: - Siri 문구

struct SkyDexShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureSkyIntent(),
            phrases: ["Capture the sky with \(.applicationName)", "\(.applicationName) camera"],
            shortTitle: "Capture the Sky",
            systemImageName: "camera"
        )
    }
}
