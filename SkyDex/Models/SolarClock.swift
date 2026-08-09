import Foundation

/// Which part of the shootable arc a moment belongs to.
enum SolarPhase: String, Codable {
    case morningTwilight
    case day
    case eveningTwilight
    /// Past nautical twilight, when the sky settles and stops offering colours.
    case night
}

/// Where the sun was when a photo was taken.
///
/// The dial used to key off clock time, which quietly broke across seasons: in
/// Pohang the sun sets at 17:12 in December and 19:42 in June, so an "18–20시"
/// slot meant sunset in summer and full darkness in winter. Anchoring to the
/// sun makes the top of the dial always solar noon and the ends always sunrise
/// and sunset, whatever the date.
///
/// This needs no location permission. Latitude and longitude are two numbers
/// the user sets once; nothing is tracked, and no coordinate is ever attached
/// to a capture.
struct SolarClock {
    var latitude: Double
    var longitude: Double

    /// Sun altitude thresholds, expressed as the zenith angles the NOAA
    /// solution takes. Sunrise allows for refraction and the solar disc;
    /// nautical twilight is the outer edge of a sky still worth photographing.
    private static let horizonZenith = 90.833
    private static let civilZenith = 96.0
    private static let nauticalZenith = 102.0

    /// Longitude guessed from the time zone, which lands within about a degree
    /// of a country's centre. Off by 22 minutes for Pohang under KST — a
    /// constant phase error the user can dial out in settings.
    static var deviceDefault: SolarClock {
        let hours = Double(TimeZone.current.secondsFromGMT()) / 3600
        return SolarClock(latitude: 36.0, longitude: hours * 15)
    }

    struct DayEvents {
        let sunrise: Double
        let sunset: Double
        /// Nautical twilight bounds — nil near the poles in midsummer, when the
        /// sky never gets that dark.
        let dawn: Double?
        let dusk: Double?
    }

    /// All of a day's boundaries as local decimal hours. NOAA's simplified
    /// solution, accurate to within a few minutes at mid latitudes.
    func events(on date: Date) -> DayEvents? {
        guard let sun = crossing(on: date, zenith: Self.horizonZenith) else { return nil }
        let nautical = crossing(on: date, zenith: Self.nauticalZenith)
        return DayEvents(
            sunrise: sun.rise,
            sunset: sun.set,
            dawn: nautical?.rise,
            dusk: nautical?.set
        )
    }

    private func crossing(on date: Date, zenith: Double) -> (rise: Double, set: Double)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else { return nil }
        let offset = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600

        let g = 2 * Double.pi / 365 * Double(dayOfYear - 1)
        let equationOfTime = 229.18 * (0.000075
            + 0.001868 * cos(g) - 0.032077 * sin(g)
            - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        let declination = 0.006918
            - 0.399912 * cos(g) + 0.070257 * sin(g)
            - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g)
            - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)

        let lat = latitude * .pi / 180
        let cosHourAngle = cos(zenith * .pi / 180) / (cos(lat) * cos(declination))
            - tan(lat) * tan(declination)
        guard cosHourAngle > -1, cosHourAngle < 1 else { return nil }
        let hourAngle = acos(cosHourAngle) * 180 / .pi

        let noonUTC = 720 - 4 * longitude - equationOfTime
        return ((noonUTC - 4 * hourAngle) / 60 + offset, (noonUTC + 4 * hourAngle) / 60 + offset)
    }

    func position(of date: Date) -> SolarPosition {
        let hour = Self.decimalHour(of: date)

        guard let today = events(on: date) else {
            // Polar day or night: fall back to a plain twelve-hour split so the
            // app still works rather than refusing the capture.
            guard hour >= 6, hour < 18 else { return SolarPosition(phase: .night, progress: 0) }
            return SolarPosition(phase: .day, progress: (hour - 6) / 12)
        }

        if hour >= today.sunrise && hour <= today.sunset {
            let span = max(0.01, today.sunset - today.sunrise)
            return SolarPosition(phase: .day, progress: (hour - today.sunrise) / span)
        }

        if let dusk = today.dusk, hour > today.sunset, hour <= dusk {
            let span = max(0.01, dusk - today.sunset)
            return SolarPosition(phase: .eveningTwilight, progress: (hour - today.sunset) / span)
        }

        if let dawn = today.dawn, hour >= dawn, hour < today.sunrise {
            let span = max(0.01, today.sunrise - dawn)
            return SolarPosition(phase: .morningTwilight, progress: (hour - dawn) / span)
        }

        return SolarPosition(phase: .night, progress: 0)
    }

    /// Local decimal hour when the arc opens again — first light rather than
    /// sunrise, since the dial starts collecting at nautical dawn.
    func nextFirstLight(after date: Date) -> Double? {
        let hour = Self.decimalHour(of: date)
        if let today = events(on: date), let dawn = today.dawn, hour < dawn { return dawn }
        return events(on: date.addingTimeInterval(86_400))?.dawn
    }

    static func decimalHour(of date: Date) -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return Double(parts.hour ?? 0)
            + Double(parts.minute ?? 0) / 60
            + Double(parts.second ?? 0) / 3600
    }

    static func clockString(_ decimalHour: Double) -> String {
        let wrapped = decimalHour.truncatingRemainder(dividingBy: 24)
        let normalized = wrapped < 0 ? wrapped + 24 : wrapped
        var hours = Int(normalized)
        var minutes = Int(((normalized - Double(hours)) * 60).rounded())
        if minutes == 60 { minutes = 0; hours = (hours + 1) % 24 }
        return String(format: "%02d:%02d", hours, minutes)
    }
}

/// A moment expressed as a fraction of the phase it falls in.
struct SolarPosition {
    let phase: SolarPhase
    let progress: Double

    init(phase: SolarPhase, progress: Double) {
        self.phase = phase
        self.progress = min(max(progress, 0), 1)
    }

    var isCollectable: Bool { phase != .night }

    /// Degrees, with -90 pointing up and 180 pointing left.
    ///
    /// Daylight takes the 180° from sunrise on the left through noon at the top
    /// to sunset on the right. Twilight gets a fixed 18° beyond each end, which
    /// dips below the horizon line exactly the way a sun-path chart does.
    ///
    /// Eighteen degrees is not a fudge: nautical twilight runs 7.6% of the day
    /// at the equinoxes and 10.4% at the winter solstice, so a strictly
    /// proportional share would be 14° to 19°. The fixed value sits inside that
    /// range all year.
    var dialAngle: Double? {
        switch phase {
        case .morningTwilight: return 180 - DialGeometry.twilightSpan * (1 - progress)
        case .day: return 180 + 180 * progress
        case .eveningTwilight: return 360 + DialGeometry.twilightSpan * progress
        case .night: return nil
        }
    }
}
