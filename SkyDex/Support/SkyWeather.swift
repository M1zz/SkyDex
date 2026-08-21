import CoreLocation
import Observation
import UIKit
import WeatherKit

/// What Apple's forecast has to be shown with.
///
/// WeatherKit is not open data with a citation as a courtesy. The terms are that
/// the Apple Weather trademark appears wherever the forecast is used to say
/// something, and that Apple's legal page is one tap from there. So the credit
/// is a value the views can draw rather than a URL somebody has to remember to
/// link, and the mark images are fetched once and kept — the mark has to still
/// be there on the day the network is not.
struct SkyCredit {

    /// Apple's page listing the sources behind the forecast.
    let legalPageURL: URL

    /// The combined mark, for a light background and for a dark one. Apple
    /// ships both because using the wrong one is how a mark ends up invisible.
    ///
    /// Nil only when the images themselves could not be fetched, in which case
    /// the words stand in. Either way the trademark is named.
    let lightMark: UIImage?
    let darkMark: UIImage?

    func mark(onDark: Bool) -> UIImage? { onDark ? darkMark : lightMark }
}

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

    /// The credit this forecast is shown under. Fetched before the forecast is,
    /// and never nil while `forecast` is not — see `refresh`.
    private(set) var credit: SkyCredit?

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

        // Attribution before data, and this is the only place the rule lives.
        //
        // Apple's mark and Apple's legal link travel with anything its forecast
        // is used to say, so this app treats the credit as part of the price of
        // the data: if it cannot be had, the forecast is not asked for, and the
        // board draws the clear sky it drew before any of this existed. Which is
        // what keeps the requirement from being an `if let` in a view somewhere —
        // there is no state in which a forecast exists and its credit does not,
        // so no screen can be built that shows the one without the other.
        if credit == nil { credit = await SkyWeather.fetchedCredit() }
        guard credit != nil else { return }

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
        } catch {
            // Nothing to say and nothing to show. The board is already drawing
            // something reasonable.
        }
    }

    /// Apple's mark and legal link, with the artwork already downloaded.
    ///
    /// The images are remote and the mark is drawn on a screen that may be
    /// offline later, so they are pulled now and held for the life of the
    /// launch. A failed image is not a failed credit: `WeatherCredit` falls back
    /// to the words, which still name the trademark.
    private static func fetchedCredit() async -> SkyCredit? {
        let attribution: WeatherAttribution
        do {
            attribution = try await WeatherService.shared.attribution
        } catch {
            return nil
        }
        async let light = SkyWeather.image(at: attribution.combinedMarkLightURL)
        async let dark = SkyWeather.image(at: attribution.combinedMarkDarkURL)
        return SkyCredit(
            legalPageURL: attribution.legalPageURL,
            lightMark: await light,
            darkMark: await dark
        )
    }

    private static func image(at url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
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
