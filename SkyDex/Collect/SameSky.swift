import Foundation
import SwiftData

/// Colour as a search key.
///
/// Browsing by date only ever surfaces neighbours in time. Browsing by colour
/// puts today next to a day two years ago that happened to look the same — a
/// pairing a calendar can never produce. The distance function built for the
/// collection rule turns out to work just as well as an index into memory.
enum SameSky {

    /// Close enough that the two skies would read as the same colour.
    static let threshold = 8.0

    struct Match: Identifiable {
        let entry: SkyEntry
        let distance: Double
        var id: PersistentIdentifier { entry.persistentModelID }
    }

    static func matches(for entry: SkyEntry, in all: [SkyEntry], limit: Int = 6) -> [Match] {
        let calendar = Calendar.current
        return all
            .filter { $0 !== entry && !calendar.isDate($0.capturedAt, inSameDayAs: entry.capturedAt) }
            .map { Match(entry: $0, distance: deltaE2000($0.lab, entry.lab)) }
            .filter { $0.distance <= threshold }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }
}
