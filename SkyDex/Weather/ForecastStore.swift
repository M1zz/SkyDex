import CoreLocation
import Foundation
import Observation
import WeatherKit

/// Tomorrow's sky, fetched from WeatherKit for the coordinate the user already
/// set for the solar clock.
///
/// No location permission is involved and none is asked for. The two numbers
/// behind the dial are the same two numbers sent to WeatherKit, which keeps the
/// promise the rest of the app makes: the app never learns where you are, you
/// tell it once, roughly, and nothing is attached to a capture.
@MainActor
@Observable
final class ForecastStore {
    private(set) var days: [SkyForecast] = []
    /// Set when WeatherKit refuses — no entitlement, no network, no service in
    /// this region. The strip simply disappears rather than showing an error;
    /// a forecast is a courtesy, and a broken courtesy should be silent.
    private(set) var isUnavailable = false

    private var lastFetch: Date?
    private var lastPlace: String?

    /// Weather that is three hours stale is still true enough for "should I
    /// look up tomorrow", and the free WeatherKit tier is a call budget.
    private static let staleAfter: TimeInterval = 3 * 3600
    private static let daysAhead = 5

    private static let cacheKey = "forecast.cache"
    private static let cacheStampKey = "forecast.cache.stamp"
    private static let cachePlaceKey = "forecast.cache.place"

    init() { loadCache() }

    var today: SkyForecast? {
        days.first { Calendar.current.isDateInToday($0.date) }
    }

    var tomorrow: SkyForecast? {
        days.first { Calendar.current.isDateInTomorrow($0.date) }
    }

    /// The day the user can still act on. Once today's light is gone, the only
    /// useful forecast is the next one.
    func actionable(clock: SolarClock, now: Date = .now) -> (SkyForecast, SkyForecast.DayReference)? {
        if let events = clock.events(on: now),
           SolarClock.decimalHour(of: now) < events.sunset - 0.5,
           let today {
            return (today, .today)
        }
        if let tomorrow { return (tomorrow, .tomorrow) }
        return nil
    }

    func refresh(latitude: Double, longitude: Double, force: Bool = false) async {
        let place = Self.placeKey(latitude: latitude, longitude: longitude)
        if !force, place == lastPlace, let lastFetch,
           Date.now.timeIntervalSince(lastFetch) < Self.staleAfter, !days.isEmpty {
            return
        }

        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let (daily, hourly) = try await WeatherService.shared.weather(
                for: location, including: .daily, .hourly
            )
            let clock = SolarClock(latitude: latitude, longitude: longitude)
            days = Self.assemble(daily: daily, hourly: hourly, clock: clock)
            isUnavailable = days.isEmpty
            lastFetch = .now
            lastPlace = place
            saveCache(place: place)
        } catch {
            // Keep whatever was cached; an old forecast beats a blank strip.
            isUnavailable = days.isEmpty
        }
    }

    // MARK: - Shaping

    private static func assemble(
        daily: Forecast<DayWeather>, hourly: Forecast<HourWeather>, clock: SolarClock
    ) -> [SkyForecast] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return daily.compactMap { day -> SkyForecast? in
            let start = calendar.startOfDay(for: day.date)
            guard let ahead = calendar.dateComponents([.day], from: today, to: start).day,
                  ahead >= 0, ahead < daysAhead else { return nil }

            let hours = hourly.filter { calendar.isDate($0.date, inSameDayAs: day.date) }
            guard let events = clock.events(on: day.date) else { return nil }

            let lit = hours.filter {
                let hour = SolarClock.decimalHour(of: $0.date)
                return hour >= events.sunrise && hour <= events.sunset
            }
            let dusk = hours.filter {
                abs(SolarClock.decimalHour(of: $0.date) - events.sunset) <= 1
            }

            // Without hourly cover there is nothing to average, and guessing a
            // number here would put a confident sentence on no evidence.
            guard !lit.isEmpty else { return nil }

            return SkyForecast(
                date: start,
                symbolName: day.symbolName,
                daylightCloudCover: lit.map(\.cloudCover).reduce(0, +) / Double(lit.count),
                sunsetCloudCover: dusk.isEmpty
                    ? nil
                    : dusk.map(\.cloudCover).reduce(0, +) / Double(dusk.count),
                precipitationChance: day.precipitationChance
            )
        }
    }

    // MARK: - Cache

    /// Half a degree is finer than the forecast varies and coarser than the
    /// slider's own step, so nudging latitude does not spend a call.
    private static func placeKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.1f,%.1f", (latitude * 2).rounded() / 2, (longitude * 2).rounded() / 2)
    }

    private func loadCache() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode([SkyForecast].self, from: data)
        else { return }
        let calendar = Calendar.current
        days = cached.filter { calendar.startOfDay(for: $0.date) >= calendar.startOfDay(for: .now) }
        lastPlace = defaults.string(forKey: Self.cachePlaceKey)
        if let stamp = defaults.object(forKey: Self.cacheStampKey) as? Date { lastFetch = stamp }
    }

    private func saveCache(place: String) {
        let defaults = UserDefaults.standard
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: Self.cacheKey)
        defaults.set(Date.now, forKey: Self.cacheStampKey)
        defaults.set(place, forKey: Self.cachePlaceKey)
    }
}
