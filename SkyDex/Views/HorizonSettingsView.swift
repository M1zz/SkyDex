import SwiftUI

/// One-time setup for the solar clock.
///
/// This is a preference, not location access: two numbers in UserDefaults, no
/// permission prompt, and nothing attached to any capture. The point is simply
/// that the app knows when the sun rises and sets where the user lives, so the
/// top of the dial is really solar noon.
///
/// Rather than explain latitude and longitude, the sheet shows today's computed
/// sunrise and sunset and lets the user nudge until it matches what they know.
struct HorizonSettingsView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var alerts: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var deniedAlerts = false

    private var clock: SolarClock { SolarClock(latitude: latitude, longitude: longitude) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("오늘")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let events = clock.events(on: .now) {
                            HStack(spacing: 24) {
                                labelled("일출", SolarClock.clockString(events.sunrise))
                                labelled("일몰", SolarClock.clockString(events.sunset))
                                labelled("낮 길이", String(format: "%.1f시간", events.sunset - events.sunrise))
                            }
                        } else {
                            Text("이 위도에서는 오늘 해가 뜨거나 지지 않아요.")
                                .font(.subheadline)
                        }
                    }

                    slider("위도", value: $latitude, range: -66...66, unit: "°N", step: 0.5)
                    slider("경도", value: $longitude, range: -180...180, unit: "°E", step: 0.5)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("빠른 설정")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            preset("포항", 36.03, 129.36)
                            preset("서울", 37.57, 126.98)
                            preset("제주", 33.50, 126.53)
                        }
                    }

                    Divider()

                    alertSection

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
            .navigationTitle("지평선 맞추기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    /// The one notification the app is willing to send, and it is opt-in.
    ///
    /// The label names the condition rather than the schedule, because what a
    /// person is agreeing to is "tell me when the sky is worth it", not "send
    /// me something at eight". Everything else the old copy explained is either
    /// visible in the app or not worth a paragraph.
    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("맑은 날 미리 알기", isOn: $alerts)
                .font(.subheadline)
                .onChange(of: alerts) { _, isOn in
                    guard isOn else { return }
                    Task {
                        if await ClearSkyNotifier.requestAuthorization() == false {
                            alerts = false
                            deniedAlerts = true
                        }
                    }
                }

            if deniedAlerts {
                Text("설정 앱에서 알림을 허용해주세요")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func slider(
        _ title: String, value: Binding<Double>,
        range: ClosedRange<Double>, unit: String, step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue) + unit)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func preset(_ name: String, _ lat: Double, _ lon: Double) -> some View {
        Button(name) {
            latitude = lat
            longitude = lon
        }
        .buttonStyle(.bordered)
        .font(.footnote)
    }
}
