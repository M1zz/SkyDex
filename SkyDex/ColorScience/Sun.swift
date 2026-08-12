import Foundation

/// When the sun does what, on one day at one place.
///
/// The board's colours used to be pinned to fixed clock times — dawn at 05:30,
/// sunset at 18:30 — which is right for nowhere and for two weeks of the year.
/// In Seoul the sun sets at 17:23 on New Year's Day and 19:57 on Midsummer, so a
/// fixed table paints a January evening in daylight blue and calls a July
/// afternoon dusk.
///
/// This is the standard NOAA solar position calculation, good to about a minute,
/// and it runs on nothing but a date and a coordinate. No network, nothing to
/// ask a weather service for. Cloud is a different question and needs one.
struct SunTimes {

    /// All in minutes from local midnight, so they line up with the board's
    /// slots and with `SkyEntry.minuteOfDay`.
    let civilDawn: Double?
    let sunrise: Double?
    let solarNoon: Double
    let sunset: Double?
    let civilDusk: Double?

    /// The sun is up all day, never comes up, or the clock disagrees with the
    /// coordinate by more than half a day. All three leave the rise and set
    /// times nil, and all three mean the same thing to a caller: this place and
    /// this date have no usable sunrise, so do not draw one.
    var hasRiseAndSet: Bool { sunrise != nil && sunset != nil }

    init(date: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let julian = SunTimes.julianDay(
            year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1
        )
        let t = (julian - 2451545) / 36525

        func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

        let meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032))
            .truncatingRemainder(dividingBy: 360)
        let meanAnomaly = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let centre = sin(radians(meanAnomaly)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(radians(2 * meanAnomaly)) * (0.019993 - 0.000101 * t)
            + sin(radians(3 * meanAnomaly)) * 0.000289

        let trueLongitude = meanLongitude + centre
        let apparent = trueLongitude - 0.00569
            - 0.00478 * sin(radians(125.04 - 1934.136 * t))

        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = meanObliquity + 0.00256 * cos(radians(125.04 - 1934.136 * t))

        let declination = asin(sin(radians(obliquity)) * sin(radians(apparent)))

        // Equation of time, in minutes: how far ahead or behind the clock the
        // sun runs. Up to about a quarter of an hour either way.
        let y = pow(tan(radians(obliquity / 2)), 2)
        let equationOfTime = 4 * (
            y * sin(radians(2 * meanLongitude))
            - 2 * eccentricity * sin(radians(meanAnomaly))
            + 4 * eccentricity * y * sin(radians(meanAnomaly)) * cos(radians(2 * meanLongitude))
            - 0.5 * y * y * sin(radians(4 * meanLongitude))
            - 1.25 * eccentricity * eccentricity * sin(radians(2 * meanAnomaly))
        ) * 180 / .pi

        let offsetMinutes = Double(calendar.timeZone.secondsFromGMT(for: date)) / 60
        let noon = 720 - 4 * longitude - equationOfTime + offsetMinutes

        /// Minutes from noon to the moment the sun's centre reaches `zenith`.
        func halfDay(zenith: Double) -> Double? {
            let latitude = radians(latitude)
            let cosH = cos(radians(zenith)) / (cos(latitude) * cos(declination))
                - tan(latitude) * tan(declination)
            guard cosH >= -1, cosH <= 1 else { return nil }
            return 4 * acos(cosH) * 180 / .pi
        }

        // 90.833° accounts for refraction and the sun's radius — the standard
        // sunrise. 96° is civil twilight, when the brightest stars appear and
        // the sky stops holding colour.
        let toRise = halfDay(zenith: 90.833)
        let toDawn = halfDay(zenith: 96)

        // Everything here is minutes from local midnight, so anything outside
        // the day is not a time of day. That happens when the device's time zone
        // does not belong to the coordinate — a simulator pinned to Cupertino
        // while the clock is in Seoul, or a phone carried across the world with
        // its time zone set by hand. The maths is still right and the answer is
        // still useless, so it is dropped rather than shown: a sunset printed as
        // "36:07" is worse than no sunset at all.
        func withinDay(_ minute: Double?) -> Double? {
            guard let minute, minute >= 0, minute <= 1440 else { return nil }
            return minute
        }

        self.solarNoon = noon
        self.sunrise = withinDay(toRise.map { noon - $0 })
        self.sunset = withinDay(toRise.map { noon + $0 })
        self.civilDawn = withinDay(toDawn.map { noon - $0 })
        self.civilDusk = withinDay(toDawn.map { noon + $0 })
    }

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var year = year, month = month
        if month <= 2 {
            year -= 1
            month += 12
        }
        let a = floor(Double(year) / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * Double(year + 4716))
            + floor(30.6001 * Double(month + 1))
            + Double(day) + b - 1524.5
    }
}
