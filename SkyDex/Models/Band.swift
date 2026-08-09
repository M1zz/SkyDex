import Foundation

/// A stretch of the shootable arc that colours are grouped into.
///
/// Bands are not equal in width, and they are not meant to be. Sunset moves
/// fast and deserves a narrow slice; midday drags on and gets a wide one. Since
/// the dial angle comes from the solar position, a band's angular width on
/// screen is its share of its phase.
struct Band: Identifiable, Hashable {
    let key: String
    let name: String
    let phase: SolarPhase
    let start: Double
    let end: Double
    let hexes: [String]

    var id: String { key }

    var midpoint: Double { (start + end) / 2 }

    func contains(_ position: SolarPosition) -> Bool {
        guard position.phase == phase else { return false }
        if end >= 1.0 { return position.progress >= start }
        return position.progress >= start && position.progress < end
    }

    var centreAngle: Double {
        SolarPosition(phase: phase, progress: midpoint).dialAngle ?? 270
    }
}
