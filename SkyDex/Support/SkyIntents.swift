//
//  SkyIntents.swift
//  SkyDex
//
//  "하늘색으로 하늘 찍어줘" — 하늘이 좋을 때 앱을 찾을 새 없이 카메라를 바로 연다.
//

import AppIntents
import Foundation

@MainActor @Observable
final class SkyRouter {
    static let shared = SkyRouter()
    /// 늘어날 때마다 첫 화면이 카메라를 연다.
    var cameraRequest = 0
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
