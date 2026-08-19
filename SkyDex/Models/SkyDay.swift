import Foundation

/// One day's sky, as a curve of colour over the clock.
///
/// The anchors are not clock times any more. They are moments — civil dawn,
/// sunrise, solar noon, sunset, afterglow — and each one is resolved against
/// where the sun actually is at this place on this date. The same anchor colour
/// lands at 07:47 in January and 05:14 in July, which is what a Seoul winter
/// morning and a Seoul summer morning actually look like.
///
/// The board's forty-eight slots do not move. A slot is a stretch of the clock,
/// because a photo has to be filed by the time it was taken and that has to mean
/// the same thing every day. It is the colours that shift underneath.
///
/// Today's forecast, if there is one, shifts them again. A clear sky is a guess
/// like any other, and on a wet afternoon it is a bad one — the board should not
/// hold up a deep blue as what four o'clock looks like while it is raining.
struct SkyDay {

    /// The palette on its own — no sun, no forecast, no clock. The order a day
    /// runs in *colour*, which is what the board's spectrum is laid out along.
    static var palette: [Lab] { anchors.compactMap { RGB(hex: $0.hex).map(Lab.init) } }

    /// Where an anchor sits: a solar moment plus an offset in minutes. Anchors
    /// tied to `.midnight` are the only fixed ones, and they have to be — the
    /// board begins and ends there.
    private enum Moment {
        case midnight
        case civilDawn
        case sunrise
        case solarNoon
        case sunset
        case civilDusk
        case nextMidnight
    }

    /// The palette. Same colours the board has always used; what changed is that
    /// the left-hand column is now a description of the sun instead of a number
    /// on a clock.
    private static let anchors: [(moment: Moment, offset: Double, hex: String)] = [
        (.midnight,    0,    "#080D18"),
        (.civilDawn,  -90,   "#0B1120"),
        (.civilDawn,  -20,   "#141D33"),
        (.civilDawn,   10,   "#2B3856"),
        (.sunrise,    -20,   "#4E5F8C"),
        (.sunrise,     5,    "#7E90B6"),
        (.sunrise,     35,   "#A2AFCA"),
        (.sunrise,     85,   "#7FA4CE"),
        (.solarNoon,  -195,  "#5590C6"),
        (.solarNoon,  -75,   "#2F7BBE"),
        (.solarNoon,   15,   "#1C6DB4"),
        (.solarNoon,   135,  "#2A76B8"),
        (.sunset,     -155,  "#4C8AC4"),
        (.sunset,     -95,   "#7FA6CD"),
        (.sunset,     -40,   "#C1A07E"),
        (.sunset,     -5,    "#D68F55"),
        (.sunset,      25,   "#B85A34"),
        (.sunset,      55,   "#8E4340"),
        (.civilDusk,   25,   "#5E3A54"),
        (.civilDusk,   65,   "#33304C"),
        (.civilDusk,   125,  "#161C31"),
        (.nextMidnight, -60, "#0A101E"),
        (.nextMidnight, 0,   "#080D18")
    ]

    /// Resolved for this day: minute of day → Lab, strictly increasing.
    private let curve: [(minute: Double, lab: Lab)]

    let sun: SunTimes

    /// Nil until a forecast arrives, and nil forever if none can. Then the curve
    /// is a clear day, which is what it always was.
    let forecast: SkyForecast?

    init(
        date: Date,
        latitude: Double,
        longitude: Double,
        forecast: SkyForecast? = nil,
        calendar: Calendar = .current
    ) {
        self.forecast = forecast
        let sun = SunTimes(date: date, latitude: latitude, longitude: longitude, calendar: calendar)
        self.sun = sun

        func minute(of moment: Moment) -> Double? {
            switch moment {
            case .midnight: return 0
            case .civilDawn: return sun.civilDawn
            case .sunrise: return sun.sunrise
            case .solarNoon: return sun.solarNoon
            case .sunset: return sun.sunset
            case .civilDusk: return sun.civilDusk
            case .nextMidnight: return 1440
            }
        }

        // Inside the polar circles there is no sunrise to hang an anchor on, and
        // above the Arctic Circle in June there is no dusk either. Rather than
        // invent one, fall back to the fixed table the app shipped with: wrong
        // for that place, but a ramp rather than a pile-up.
        var resolved: [(minute: Double, lab: Lab)] = []
        if sun.hasRiseAndSet, sun.civilDawn != nil, sun.civilDusk != nil {
            for anchor in SkyDay.anchors {
                guard let base = minute(of: anchor.moment) else { continue }
                resolved.append((
                    minute: base + anchor.offset,
                    lab: Lab(RGB(hex: anchor.hex) ?? RGB(r: 0, g: 0, b: 0))
                ))
            }
            // A short winter day squeezes the anchors together and a long summer
            // one can push dusk past midnight, either of which would leave the
            // list out of order. Nudging each one past the last keeps the ramp
            // monotonic, which is all the interpolation needs.
            for index in resolved.indices {
                if index == 0 {
                    resolved[index].minute = 0
                } else {
                    resolved[index].minute = max(
                        resolved[index].minute, resolved[index - 1].minute + 1
                    )
                }
            }
            if let last = resolved.last?.minute, last > 1440 {
                resolved = []
            } else {
                resolved[resolved.count - 1].minute = 1440
            }
        }

        self.curve = resolved.isEmpty ? SkyDay.fixedCurve : resolved
    }

    /// The curve as it was before the sun came into it: anchors at the clock
    /// times of a temperate equinox. Only used where the sun gives no answer.
    fileprivate static let fixedCurve: [(minute: Double, lab: Lab)] = [
        (0, "#080D18"), (200, "#0B1120"), (290, "#141D33"), (330, "#2B3856"),
        (365, "#4E5F8C"), (395, "#7E90B6"), (420, "#A2AFCA"), (470, "#7FA4CE"),
        (540, "#5590C6"), (660, "#2F7BBE"), (750, "#1C6DB4"), (870, "#2A76B8"),
        (960, "#4C8AC4"), (1020, "#7FA6CD"), (1075, "#C1A07E"), (1110, "#D68F55"),
        (1140, "#B85A34"), (1170, "#8E4340"), (1200, "#5E3A54"), (1240, "#33304C"),
        (1300, "#161C31"), (1380, "#0A101E"), (1440, "#080D18")
    ].map { (minute: Double($0.0), lab: Lab(RGB(hex: $0.1) ?? RGB(r: 0, g: 0, b: 0))) }

    /// Minute of day → the sky at that moment, weather and all.
    func colour(atMinute minute: Double) -> RGB {
        let clear = clearSky(atMinute: minute)
        guard let forecast else { return RGB(clear) }
        return RGB(SkyDay.clouded(
            clear,
            cloud: forecast.cloud(atMinute: minute),
            rain: forecast.rain(atMinute: minute)
        ))
    }

    /// What cloud does to a sky, in Lab.
    ///
    /// Chroma goes first and goes almost entirely: an overcast noon has no blue
    /// left in it and an overcast sunset has no fire, which is why a rained-out
    /// evening is the flattest sky of the year.
    ///
    /// Lightness moves toward a bright grey, but only in proportion to how much
    /// daylight there was to flatten. Cloud over midnight is still midnight —
    /// pulling every hour toward the same grey would light up the top of the
    /// board on a rainy night, which is the opposite of true.
    ///
    /// Rain is cloud with a lid on it: darker again, and what little colour
    /// survived the cloud does not survive this.
    static func clouded(_ clear: Lab, cloud: Double, rain: Double) -> Lab {
        let cloud = min(max(cloud, 0), 1)
        let rain = min(max(rain, 0), 1)
        let daylight = min(max(clear.l / 60, 0), 1)

        var l = clear.l + (74 - clear.l) * 0.5 * cloud * daylight
        l -= 16 * rain * daylight

        let chroma = (1 - 0.85 * cloud) * (1 - 0.4 * rain)
        return Lab(l: l, a: clear.a * chroma, b: clear.b * chroma)
    }

    /// The curve with no weather in it: this place's sun on this date.
    private func clearSky(atMinute minute: Double) -> Lab {
        SkyDay.interpolate(curve, atMinute: minute)
    }

    fileprivate static func interpolate(
        _ curve: [(minute: Double, lab: Lab)],
        atMinute minute: Double
    ) -> Lab {
        let m = min(max(minute, 0), 1440)
        for index in 0..<(curve.count - 1) {
            let (m0, lab0) = curve[index]
            let (m1, lab1) = curve[index + 1]
            guard m >= m0, m <= m1 else { continue }
            let raw = m1 == m0 ? 0 : (m - m0) / (m1 - m0)
            // Smoothstep, so the anchors do not show up as creases in the ramp.
            let t = raw * raw * (3 - 2 * raw)
            return lab0.blended(toward: lab1, by: t)
        }
        return curve[curve.count - 1].lab
    }

    /// What a slot's sky usually is: the colour at the middle of its stretch.
    /// What this bead is, on today's board.
    ///
    /// Not the curve any more — the spectrum colour nearest to the curve at this
    /// hour. The curve still decides everything about the arrangement; it just
    /// no longer paints two beads the same blue because two hours of the day
    /// happen to look alike. See `SkySpectrum`.
    func colour(of slot: SkySlot) -> RGB {
        let spectrum = SkySpectrum.ordered
        return spectrum[min(slot.id, spectrum.count - 1)].rgb
    }

    /// The curve itself, unrounded. What the sky is actually expected to be at
    /// this minute, which is a different question from what the board is
    /// collecting.
    func forecastColour(of slot: SkySlot) -> RGB {
        colour(atMinute: Double(slot.startMinute + slot.endMinute) / 2)
    }



    /// What the slot is drawn in while it is empty.
    func ghost(of slot: SkySlot) -> RGB {
        SkyBoard.ghost(of: colour(of: slot))
    }

    /// Today's forty-eight colours, in board order. This is what the collection
    /// is matched against, and it changes with the date, the place and the
    /// forecast — never within the day.
    var targets: [Lab] {
        SkyBoard.slots.map { Lab(colour(of: $0)) }
    }

}
