import Foundation

/// The dial resets every season, so a full circle is a three-month commitment
/// rather than an open-ended grind. Four completed circles make a year.
enum Season: String, CaseIterable {
    case spring, summer, autumn, winter

    var korean: String {
        switch self {
        case .spring: return "봄"
        case .summer: return "여름"
        case .autumn: return "가을"
        case .winter: return "겨울"
        }
    }

    static func of(_ date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    /// Winter spans a year boundary, so January and February are filed under
    /// the preceding December's year — otherwise a circle would split in two.
    static func key(for date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        var year = calendar.component(.year, from: date)
        let season = of(date)
        if season == .winter && month <= 2 { year -= 1 }
        return "\(year)-\(season.rawValue)"
    }

    static func label(forKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let season = Season(rawValue: String(parts[1])) else { return key }
        return "\(parts[0])년 \(season.korean)"
    }
}
