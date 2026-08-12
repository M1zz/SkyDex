import Foundation

/// The one useful thing today's forecast has to say.
///
/// The board already spends the forecast on colour — every empty ring is drawn
/// at what that hour is expected to look like. But the app is holding cloud and
/// rain for twenty-four hours and the sun's own schedule, and none of that told
/// you the thing you would actually want to know: when to step outside.
///
/// One sentence, not a weather screen. Whichever of these is true first wins,
/// because the first true one is the most useful:
///
/// 1. Rain is coming and it is dry now — go before it starts.
/// 2. It is raining and it stops later — go then.
/// 3. It is overcast all day — say so, so a grey board reads as weather rather
///    than as something being wrong.
/// 4. Otherwise — the clearest hour still ahead, and what the sunset will be
///    doing.
///
/// Hours already past are never mentioned. A tip about this morning is not a tip.
struct SkyInsight {
    let symbol: String
    let headline: String
    let detail: String

    static func today(
        forecast: SkyForecast,
        sun: SunTimes,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SkyInsight? {
        let hour = calendar.component(.hour, from: now)
        let ahead = Array((hour + 1)...23).filter { $0 < 24 }
        // Late enough that there is nothing left to plan.
        guard ahead.count >= 2 else { return nil }

        func cloud(_ h: Int) -> Double { forecast.cloud(atMinute: Double(h * 60 + 30)) }
        func rain(_ h: Int) -> Double { forecast.rain(atMinute: Double(h * 60 + 30)) }
        func percent(_ value: Double) -> Int { Int((value * 100).rounded()) }
        func clearest(_ hours: [Int]) -> Int? {
            hours.min { cloud($0) < cloud($1) }
        }

        /// The sunset line, when the sunset is still ahead. It is the one moment
        /// of the day the board gives twelve slots to.
        let sunsetNote: String? = {
            guard let sunset = sun.sunset, sunset > Double(hour * 60 + 30) else { return nil }
            let h = Int(sunset) / 60, m = Int(sunset) % 60
            return String(format: "일몰은 %02d:%02d, 그때 구름 %d%%.", h, m, percent(cloud(h)))
        }()

        func detail(_ lead: String) -> String {
            [lead, sunsetNote].compactMap { $0 }.joined(separator: " ")
        }

        let raining = rain(hour) > 0.15

        // 1. Dry now, wet later.
        if !raining, let first = ahead.first(where: { rain($0) > 0.15 }) {
            let dry = ahead.filter { $0 < first }
            if let best = clearest(dry) {
                return SkyInsight(
                    symbol: "cloud.rain.fill",
                    headline: "비 오기 전에 한 장",
                    detail: detail("\(first)시부터 비 예보. 그 전에는 \(best)시가 가장 맑아요(구름 \(percent(cloud(best)))%).")
                )
            }
            return SkyInsight(
                symbol: "cloud.rain.fill",
                headline: "곧 비가 옵니다",
                detail: detail("\(first)시부터 비 예보.")
            )
        }

        // 2. Wet now, clearing later.
        if raining {
            if let clears = ahead.first(where: { rain($0) <= 0.05 }) {
                return SkyInsight(
                    symbol: "cloud.sun.fill",
                    headline: "\(clears)시부터 갭니다",
                    detail: detail("지금은 비. 그치고 나서가 오늘의 기회예요.")
                )
            }
            return SkyInsight(
                symbol: "cloud.rain.fill",
                headline: "오늘은 종일 비",
                detail: detail("비 오는 하늘도 하늘입니다. 회색은 오늘만의 색이에요.")
            )
        }

        // 3. Grey from here to midnight.
        if ahead.allSatisfy({ cloud($0) >= 0.8 }) {
            return SkyInsight(
                symbol: "cloud.fill",
                headline: "오늘은 종일 흐려요",
                detail: detail("판의 오늘 색이 회색으로 눌려 있는 것도 그래서입니다.")
            )
        }

        // 4. The clearest hour left.
        guard let best = clearest(ahead) else { return nil }
        return SkyInsight(
            symbol: cloud(best) < 0.25 ? "sun.max.fill" : "cloud.sun.fill",
            headline: "\(best)시가 가장 맑아요",
            detail: detail("구름 \(percent(cloud(best)))%.")
        )
    }
}
