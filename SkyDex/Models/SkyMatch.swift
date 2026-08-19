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
/// With one exception, and it is the one case where there is a better answer
/// than colour: a sky taken **today** fills the slot it was taken in, whatever
/// colour it came out. See `claims(_:slot:on:calendar:)`.
///
/// **A sky fills one bead and no more.** The day's curve is smooth, so
/// neighbouring beads sit a couple of units apart and one photograph used to
/// land inside four or five circles at once — and on a board that draws each
/// filled bead in the colour it holds, that is the same colour and the same
/// sentence printed several times across the grid. Worse where the curve doubles
/// back: morning and evening pass through the same grey, so one overcast
/// Tuesday turned up at both ends of the day. A board of forty-eight beads
/// showing the same three photographs is not a picture of a day.
///
/// So each sky takes the bead it is nearest to, and the beads it also fitted are
/// left for whatever else the collection has. What the board counts is how much
/// of today you can show **with different skies**, which is the harder and more
/// honest question of the two.
enum SkyMatch {

    /// How near counts as the same colour, in CIEDE2000. Neighbouring beads sit
    /// about three apart on a median day, so this is roughly "your colour covers
    /// itself and its immediate neighbours" — tight enough that a sunset does not
    /// fill a noon, loose enough that a photo taken under today's sky lands.
    ///
    /// It is one number on purpose. It is the dial for how hard this is to fill.
    static let radius: Double = 3.5

    /// Whether a capture speaks for a slot outright, colour or no colour.
    ///
    /// A bead's colour is a forecast: what the sky over this place is *expected*
    /// to look like in that half hour. A photo taken today in that half hour is
    /// what it actually looked like. When the two disagree, the forecast is the
    /// one that was guessing — so the photo takes the slot and the bead is drawn
    /// in the colour that was really there.
    ///
    /// Only today's captures get this. Yesterday's three o'clock was a different
    /// sky under different cloud, and the only honest thing it can say about
    /// today's three o'clock is that the colours happen to match — which is the
    /// question `map` already asks of it.
    static func claims(
        _ entry: SkyEntry,
        slot: SkySlot,
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(entry.capturedAt, inSameDayAs: date)
            && SkyBoard.slot(forMinute: entry.minuteOfDay).id == slot.id
    }

    /// Slot id → the collected sky standing in for it, for the board of `date`.
    ///
    /// Two passes, and no sky comes out of them twice. Today's own captures go
    /// first, each in the slot it was taken in — they were there, so they
    /// outrank anything that merely looks right, and they are spent by the time
    /// colour is asked about. Then colour, nearest pairing first across the
    /// whole grid rather than best-for-this-bead one bead at a time.
    static func map(
        targets: [Lab],
        entries: [SkyEntry],
        on date: Date,
        radius: Double = SkyMatch.radius,
        calendar: Calendar = .current
    ) -> [Int: SkyEntry] {
        guard !entries.isEmpty else { return [:] }

        // The clock goes first, because its answer cannot be argued with and it
        // decides which skies are still going spare. Shot today, so it owns its
        // half hour; where two captures share one the newer takes it — shooting
        // the same stretch again replaces the bead rather than being locked out
        // by a first attempt you did not like.
        var result: [Int: SkyEntry] = [:]
        for entry in entries
        where calendar.isDate(entry.capturedAt, inSameDayAs: date) {
            let id = SkyBoard.slot(forMinute: entry.minuteOfDay).id
            if let sitting = result[id], sitting.capturedAt > entry.capturedAt { continue }
            result[id] = entry
        }
        var spoken = Set(result.values.map(\.uuid))

        // Then colour, nearest pairing first. Going bead by bead and taking the
        // best photo for each would hand the same photo to every bead it fitted;
        // going pairing by pairing means the closest call in the whole grid is
        // settled first, and a bead that has just lost its best answer is still
        // free to take its second.
        var pairings: [(slot: Int, entry: Int, distance: Double)] = []
        for (id, target) in targets.enumerated() where result[id] == nil {
            for index in entries.indices where !spoken.contains(entries[index].uuid) {
                let distance = deltaE2000(target, entries[index].lab)
                if distance <= radius { pairings.append((id, index, distance)) }
            }
        }

        // Ties go to the newer sky, because the board draws age; then to the
        // earlier bead, so the answer does not depend on dictionary order.
        pairings.sort { left, right in
            if left.distance != right.distance { return left.distance < right.distance }
            let a = entries[left.entry], b = entries[right.entry]
            if a.capturedAt != b.capturedAt { return a.capturedAt > b.capturedAt }
            return left.slot < right.slot
        }

        for pairing in pairings {
            guard result[pairing.slot] == nil else { continue }
            let entry = entries[pairing.entry]
            guard spoken.insert(entry.uuid).inserted else { continue }
            result[pairing.slot] = entry
        }

        return result
    }

    /// Everything in the collection that would fill this one bead, newest first.
    ///
    /// Given a slot, that includes today's captures from its stretch of the
    /// clock even when their colour is nowhere near — the same rule that filled
    /// the bead has to be the rule that says what is behind it.
    static func all(
        near target: Lab,
        in entries: [SkyEntry],
        filling slot: SkySlot? = nil,
        on date: Date = .now,
        radius: Double = SkyMatch.radius,
        calendar: Calendar = .current
    ) -> [SkyEntry] {
        entries
            .filter { entry in
                if deltaE2000(target, entry.lab) <= radius { return true }
                guard let slot else { return false }
                return claims(entry, slot: slot, on: date, calendar: calendar)
            }
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
/// Which slot a capture was taken in does not move within a day either, so the
/// second pass rides along on the same key.
///
/// Deliberately not observable. It publishes nothing and exists only so the
/// board can ask the same question repeatedly without paying for it.
final class SkyMatchCache {
    private var key: String?
    private var value: [Int: SkyEntry] = [:]

    func map(targets: [Lab], entries: [SkyEntry], on date: Date, key: String) -> [Int: SkyEntry] {
        if key == self.key { return value }
        value = SkyMatch.map(targets: targets, entries: entries, on: date)
        self.key = key
        return value
    }
}
