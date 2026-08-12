import Foundation

/// Which of today's colours the collection already has.
///
/// The board is today. Its forty-eight beads are the colours today's sky is
/// expected to run through, and a bead is filled when something already
/// collected lands **inside its circle** — near enough that an eye would call it
/// the same colour. So the same collection fills a different board tomorrow, and
/// a board can be nearly full one day and nearly empty the next. That is the
/// point: it says how much of *today* you can already show.
///
/// Nothing is filed anywhere. A photo does not belong to a slot and never did
/// under this model — matching is a question asked of the whole collection every
/// time the board is drawn.
///
/// One colour can fill several beads, because the day's curve is smooth and
/// neighbouring beads are often within a couple of units of each other. That is
/// not a bug to hide: owning a blue really does cover a stretch of the
/// afternoon.
enum SkyMatch {

    /// How near counts as the same colour, in CIEDE2000. Neighbouring beads sit
    /// about three apart on a median day, so this is roughly "your colour covers
    /// itself and its immediate neighbours" — tight enough that a sunset does not
    /// fill a noon, loose enough that a photo taken under today's sky lands.
    ///
    /// It is one number on purpose. It is the dial for how hard this is to fill.
    static let radius: Double = 3.5

    /// Slot id → the collected sky standing in for it. Nearest colour wins; when
    /// two are equally near, the newer one does, because the board draws age.
    static func map(
        targets: [Lab],
        entries: [SkyEntry],
        radius: Double = SkyMatch.radius
    ) -> [Int: SkyEntry] {
        guard !entries.isEmpty else { return [:] }
        let labs = entries.map(\.lab)

        var result: [Int: SkyEntry] = [:]
        for (id, target) in targets.enumerated() {
            var bestIndex: Int?
            var bestDistance = Double.greatestFiniteMagnitude
            for index in entries.indices {
                let distance = deltaE2000(target, labs[index])
                guard distance <= radius else { continue }
                if distance < bestDistance
                    || (distance == bestDistance
                        && entries[index].capturedAt > entries[bestIndex ?? index].capturedAt) {
                    bestDistance = distance
                    bestIndex = index
                }
            }
            if let bestIndex { result[id] = entries[bestIndex] }
        }
        return result
    }

    /// Everything in the collection that would fill this one bead, newest first.
    static func all(
        near target: Lab,
        in entries: [SkyEntry],
        radius: Double = SkyMatch.radius
    ) -> [SkyEntry] {
        entries
            .filter { deltaE2000(target, $0.lab) <= radius }
            .sorted { $0.capturedAt > $1.capturedAt }
    }
}

/// A read-through cache for the board.
///
/// The forty-eight targets only move when the date, the place or the forecast
/// does — never within a day and never with the minute. Matching every photo
/// against all of them is cheap once and wasteful sixty times a second, which is
/// what a finger dragging across the board would otherwise cost.
///
/// Deliberately not observable. It publishes nothing and exists only so the
/// board can ask the same question repeatedly without paying for it.
final class SkyMatchCache {
    private var key: String?
    private var value: [Int: SkyEntry] = [:]

    func map(targets: [Lab], entries: [SkyEntry], key: String) -> [Int: SkyEntry] {
        if key == self.key { return value }
        value = SkyMatch.map(targets: targets, entries: entries)
        self.key = key
        return value
    }
}
