import Foundation

/// A day's sky, described in the terms this app cares about.
///
/// A weather app answers "will I get wet". This one answers "is there anything
/// up there worth looking at", which is a different question: an overcast
/// afternoon that breaks at dusk is a bad day for laundry and a good day for
/// this app.
struct SkyForecast: Codable, Equatable, Identifiable {
    /// Local start of the day being described.
    let date: Date
    /// Apple's symbol for the day's overall condition.
    let symbolName: String
    /// Mean cloud, 0 to 1, over the hours the sun is actually up. The whole
    /// 24-hour mean would be dragged around by a cloudy night nobody sees.
    let daylightCloudCover: Double
    /// Cloud over the hour around sunset, kept separate because it answers a
    /// different question from the day's average.
    let sunsetCloudCover: Double?
    let precipitationChance: Double

    var id: Date { date }

    /// What the day is worth, as a small closed set the phrasing can switch on.
    enum Tone: String, Codable {
        /// Open sky for most of the day.
        case clear
        /// Grey by day, but the lid comes off in time for sunset.
        case breaking
        /// Cloud coming and going — the day a palette runs its full six.
        case mixed
        /// Shut all day.
        case dull
        case wet
    }

    var tone: Tone {
        if precipitationChance >= 0.5 { return .wet }
        if daylightCloudCover <= 0.25 { return .clear }
        if let dusk = sunsetCloudCover, dusk <= 0.3 { return .breaking }
        if daylightCloudCover <= 0.65 { return .mixed }
        return .dull
    }

    /// Whether the day is worth putting a notification behind. Grey days are
    /// still shown in the app; they are just never pushed at anyone.
    var isWorthTelling: Bool { tone == .clear || tone == .breaking }
}

extension SkyForecast {
    /// A fact about the sky, phrased as an opening rather than an instruction.
    ///
    /// The rule the rest of the app follows applies here too: say what the
    /// world is doing, never what the user has failed to do. "It will be clear
    /// tomorrow" is an invitation; "you haven't shot in three days" is a
    /// reprimand, and the difference decides whether the app gets deleted.
    func invitation(for day: DayReference) -> String {
        switch tone {
        case .clear:
            return "\(day.subject) 하늘이 트입니다. 한 번 올려다보세요."
        case .breaking:
            return "\(day.subject) 낮은 흐리지만 노을 무렵 걷혀요."
        case .mixed:
            return "\(day.subject) 구름이 오갑니다. 색이 여러 겹으로 나오는 날이에요."
        case .dull:
            return "\(day.subject) 온종일 흐려요. 단색에 가까운 하늘입니다."
        case .wet:
            return "\(day.subject) 비 소식이 있어요."
        }
    }

    enum DayReference {
        case today
        case tomorrow

        var subject: String {
            switch self {
            case .today: return "오늘은"
            case .tomorrow: return "내일은"
            }
        }
    }

    /// Stand-ins for previews, and for checking the strip on a simulator, where
    /// WeatherKit has no entitlement to answer with.
    static func sample(tone: Tone) -> SkyForecast {
        switch tone {
        case .clear:
            return SkyForecast(
                date: .now, symbolName: "sun.max.fill",
                daylightCloudCover: 0.08, sunsetCloudCover: 0.05, precipitationChance: 0
            )
        case .breaking:
            return SkyForecast(
                date: .now, symbolName: "cloud.sun.fill",
                daylightCloudCover: 0.72, sunsetCloudCover: 0.18, precipitationChance: 0.1
            )
        case .mixed:
            return SkyForecast(
                date: .now, symbolName: "cloud.sun.fill",
                daylightCloudCover: 0.5, sunsetCloudCover: 0.55, precipitationChance: 0.1
            )
        case .dull:
            return SkyForecast(
                date: .now, symbolName: "cloud.fill",
                daylightCloudCover: 0.92, sunsetCloudCover: 0.9, precipitationChance: 0.2
            )
        case .wet:
            return SkyForecast(
                date: .now, symbolName: "cloud.rain.fill",
                daylightCloudCover: 0.95, sunsetCloudCover: 0.95, precipitationChance: 0.8
            )
        }
    }
}
