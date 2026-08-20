import LeeoKit
import SwiftUI

/// The gear behind the archive.
///
/// This app has almost no settings and should keep it that way — the board is
/// not configurable, the colours are not adjustable, and a screen full of
/// switches would suggest otherwise. Three things earn a row: where the photos
/// are kept, how to say something to whoever wrote this, and the version.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    /// What the user asked for. What is actually running is
    /// `SkyDexApp.usesCloud`, decided when the store opened, and the two can
    /// disagree until the app is next launched.
    @AppStorage(SkyDexApp.cloudEnabledKey) private var wantsCloud = true

    /// LeeoKit's developer switch — seven taps on the version row. The same
    /// flag gates its feedback inbox, so the two developer rows appear together
    /// or not at all.
    @AppStorage("dev.masterMode") private var devMode = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("iCloud에 함께 보관", isOn: $wantsCloud)
                } header: {
                    Text("보관")
                } footer: {
                    // Two sentences at most: what is true now, and — only when
                    // it applies — what is waiting on a relaunch.
                    Text(storageFooter)
                }

                Section {
                    // 피드백 보내기 · 리뷰 남기기 · 개인정보 처리방침 · 지원 페이지 ·
                    // 버전(7번 탭하면 개발자 모드). 전부 LeeoKit이 준다.
                    LeeoSupportSection<SkyDexSpec>()
                } header: {
                    Text("지원")
                }

                if devMode {
                    Section {
                        NavigationLink {
                            LeeoUsageStatsView<SkyDexSpec>()
                        } label: {
                            Label("사용 통계", systemImage: "chart.bar")
                        }
                    } header: {
                        Text("개발자")
                    } footer: {
                        Text("설치 수와 버전 분포. 읽으려면 허브 컨테이너의 read 권한이 필요합니다.")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }

    private var storageFooter: String {
        let now = CloudSync.shared.line
        guard wantsCloud != SkyDexApp.usesCloud else { return now }
        return "\(now)\n바꾼 것은 앱을 다시 열 때 적용됩니다."
    }
}
