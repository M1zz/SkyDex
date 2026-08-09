import SwiftUI

/// One line above the capture button: what the sky is going to do, and Apple's
/// required attribution for having said so.
///
/// It sits under the dial rather than inside it. The arc is a record of what
/// the user has actually seen; a forecast is a claim about what they haven't,
/// and the two should not be drawn in the same picture.
struct ForecastStrip: View {
    let forecast: SkyForecast
    let day: SkyForecast.DayReference

    @Environment(\.skyTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: forecast.symbolName)
                .font(.system(size: 24))
                .symbolRenderingMode(.multicolor)
                .frame(width: 32)

            Text(forecast.invitation(for: day))
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottomTrailing) {
            // Required whenever WeatherKit data is shown.
            Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                HStack(spacing: 2) {
                    Image(systemName: "apple.logo")
                    Text("Weather")
                }
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
            .padding([.trailing, .bottom], 6)
        }
    }
}

#Preview {
    ZStack {
        SkyBackdrop(theme: .of(tone: .clear, phase: .day))
        VStack(spacing: 12) {
            ForecastStrip(forecast: .sample(tone: .clear), day: .tomorrow)
            ForecastStrip(forecast: .sample(tone: .breaking), day: .tomorrow)
            ForecastStrip(forecast: .sample(tone: .mixed), day: .today)
            ForecastStrip(forecast: .sample(tone: .dull), day: .today)
            ForecastStrip(forecast: .sample(tone: .wet), day: .tomorrow)
        }
        .padding(20)
    }
    .environment(\.skyTheme, .of(tone: .clear, phase: .day))
}
