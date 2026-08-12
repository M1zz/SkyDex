import Foundation

/// What the sky is expected to be doing today, hour by hour.
///
/// Two numbers per hour is all the board can use. It does not draw weather; it
/// draws one colour per slot, and cloud and rain are the two things that decide
/// what colour a given hour of sky actually comes out.
struct SkyForecast {

    /// Twenty-four each, indexed by hour of the local day, 0…1.
    let cloud: [Double]
    let rain: [Double]

    func cloud(atMinute minute: Double) -> Double { SkyForecast.sample(cloud, at: minute) }
    func rain(atMinute minute: Double) -> Double { SkyForecast.sample(rain, at: minute) }

    /// Straight line between the two hours either side, so a slot that sits at
    /// 18:45 gets three quarters of the way from six o'clock's cloud to seven's
    /// rather than snapping to one of them.
    private static func sample(_ values: [Double], at minute: Double) -> Double {
        guard values.count == 24 else { return 0 }
        let hour = min(max(minute / 60, 0), 24)
        let low = Int(hour) % 24
        let high = (low + 1) % 24
        let t = hour - hour.rounded(.down)
        return values[low] + (values[high] - values[low]) * t
    }
}
