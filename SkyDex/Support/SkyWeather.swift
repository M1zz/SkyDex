import CoreLocation
import Observation
import WeatherKit

/// Today's forecast, from Apple Weather.
///
/// The board's reference colours were a clear day, always. That is a bad guess
/// for a good part of the year: a rained-out afternoon is flat grey and nothing
/// like the blue the board was holding up as what that hour looks like.
///
/// Everything here degrades to nothing. No entitlement, no network, no answer —
/// `forecast` stays nil and the board draws the clear sky it always drew.
@Observable
@MainActor
final class SkyWeather {

    private(set) var forecast: SkyForecast?

    /// Apple requires the service to be named and its legal page reachable
    /// wherever its data is shown. Kept here so the one screen with words on it
    /// can carry the credit.
    private(set) var legalPageURL: URL?

    private var fetchedAt: Date?
    private var fetchedFor: CLLocation?

    /// Called when the board appears and whenever the place changes. Hourly at
    /// most and only when it would say something new — the forecast for a slot
    /// does not change faster than that, and the call budget is finite.
    func refresh(
        latitude: Double,
        longitude: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) async {
        let here = CLLocation(latitude: latitude, longitude: longitude)
        if let fetchedAt, let fetchedFor, forecast != nil {
            let sameHour = calendar.isDate(fetchedAt, equalTo: now, toGranularity: .hour)
            let sameDay = calendar.isDate(fetchedAt, inSameDayAs: now)
            let nearby = here.distance(from: fetchedFor) < 5_000
            if sameHour, sameDay, nearby { return }
        }

        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        do {
            let hours = try await WeatherService.shared.weather(
                for: here,
                including: .hourly(startDate: start, endDate: end)
            )

            var cloud = [Double?](repeating: nil, count: 24)
            var rain = [Double?](repeating: nil, count: 24)
            for hour in hours {
                let index = calendar.component(.hour, from: hour.date)
                guard index >= 0, index < 24 else { continue }
                cloud[index] = min(max(hour.cloudCover, 0), 1)
                // Millimetres in the hour. Four is already a downpour, and past
                // that it cannot get any greyer.
                let millimetres = hour.precipitationAmount.converted(to: .millimeters).value
                rain[index] = min(max(millimetres / 4, 0), 1)
            }

            // A handful of hours is not a day. Rather than filling the rest with
            // zeroes and calling it clear, keep the clear-sky reference.
            guard cloud.compactMap({ $0 }).count >= 12 else { return }

            forecast = SkyForecast(
                cloud: SkyWeather.filled(cloud),
                rain: SkyWeather.filled(rain)
            )
            fetchedAt = now
            fetchedFor = here
            legalPageURL = try? await WeatherService.shared.attribution.legalPageURL
        } catch {
            // Nothing to say and nothing to show. The board is already drawing
            // something reasonable.
        }
    }

    /// Gaps take the nearest hour that did answer, which is a better guess than
    /// zero — an hour missing from the middle of an overcast day is overcast.
    private static func filled(_ values: [Double?]) -> [Double] {
        var result = values
        var last: Double?
        for index in result.indices {
            if let value = result[index] { last = value } else { result[index] = last }
        }
        last = nil
        for index in result.indices.reversed() {
            if let value = result[index] { last = value } else { result[index] = last }
        }
        return result.map { $0 ?? 0 }
    }
}
