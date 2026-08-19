import Foundation

/// The forty-eight colours the board is made of.
///
/// The board used to draw the day's curve directly: what the sun and the
/// forecast say the sky will be at each half hour, straight onto the grid. That
/// is the truest thing a board of today could show and it had one flaw that
/// could not be argued away — **a day does not contain forty-eight different
/// colours.** Measured on the real curve, neighbouring beads sit a median of 3.2
/// apart and the whole day travels 226.7; keeping every pair beyond the reach of
/// a single photograph would need 329. And the curve doubles back: 07:30 and
/// 12:00 came out ΔE 0.1 apart, the same blue twice, because that is what those
/// two hours honestly look like.
///
/// So the grid stops being a continuous curve and becomes a **spectrum**: forty
/// eight colours chosen to be as far from each other as real skies allow, one
/// per bead, every one different. Nothing here is invented — they are picked
/// from `SkySimiles`, the table of colours the app already keeps because real
/// skies live in them, so every bead is a colour that has happened and has a
/// name in plain Korean. Chosen by farthest-point, forty eight of them come out
/// at least **ΔE 7.0** apart, which is exactly twice `SkyMatch.radius`: one
/// photograph can no longer land inside two circles.
///
/// The order is fixed, and that is the part worth being clear about. The first
/// attempt laid the spectrum along *today's* curve — nearest pairing first, so
/// the forecast would arrange the board even though it no longer painted it.
/// It does not work, and the measurement said so immediately: forty-eight
/// colours all have to go somewhere, and on an overcast day most of them are
/// nowhere near a curve made entirely of grey, so whatever is left over lands
/// in whatever bead is left over. Midnight came out **달걀노른자색** on a cloudy
/// day and **다림질한 흰 셔츠색** in the rain. A board that puts egg yolk at
/// midnight is worse than a board that repeats itself.
///
/// So the spectrum is ordered once, along the palette a day runs through
/// (`SkyDay.palette`), and stays there: midnight at the top left, dawn, the
/// blues, dusk, night again at the end. Every bead is a different colour every
/// day, because it is the *same* different colour every day.
///
/// What this costs is the board's claim on today. A bead used to be what the sky
/// over you is expected to look like at that hour; it is now one of the
/// forty-eight sky colours there are to collect, sitting at the hour it belongs
/// to. The forecast still knows what today looks like and still says so — under
/// an empty bead, next to the colour, rather than as the colour.
enum SkySpectrum {

    /// One per bead.
    static let size = 48

    /// The spectrum itself, as far apart as the table allows.
    static let colours: [SkySimile] = pick(size)

    /// The spectrum in board order: the day, in colour.
    ///
    /// Each colour is placed by where it sits on the palette a day runs through
    /// — walked finely enough that colours landing on the same anchor still come
    /// out in the right order relative to each other — and then they are read off
    /// in that order. Ties break on lightness and then on hex, so the board is
    /// the same board on every device and every launch.
    static let ordered: [SkySimile] = {
        let path = walk(SkyDay.palette, steps: 12)
        return colours
            .map { colour -> (colour: SkySimile, position: Int, lightness: Double) in
                let lab = Lab(colour.rgb)
                var best = 0
                var bestDistance = Double.greatestFiniteMagnitude
                for (index, point) in path.enumerated() {
                    let distance = deltaE2000(lab, point)
                    if distance < bestDistance { bestDistance = distance; best = index }
                }
                return (colour, best, lab.l)
            }
            .sorted {
                if $0.position != $1.position { return $0.position < $1.position }
                if $0.lightness != $1.lightness { return $0.lightness < $1.lightness }
                return $0.colour.hex < $1.colour.hex
            }
            .map(\.colour)
    }()

    /// The palette as a fine line rather than a handful of anchors, so two
    /// colours that both sit nearest the same anchor are still ordered by which
    /// of them the day reaches first.
    private static func walk(_ anchors: [Lab], steps: Int) -> [Lab] {
        guard anchors.count > 1 else { return anchors }
        var path: [Lab] = []
        for index in 0..<(anchors.count - 1) {
            for step in 0..<steps {
                path.append(anchors[index].blended(
                    toward: anchors[index + 1],
                    by: Double(step) / Double(steps)
                ))
            }
        }
        path.append(anchors[anchors.count - 1])
        return path
    }

    // MARK: - Choosing

    /// Farthest-point: start at the darkest colour in the table — midnight, the
    /// one end of the day nothing else is near — and repeatedly take whichever
    /// colour is furthest from everything chosen so far. Deterministic, so the
    /// same table always gives the same spectrum.
    private static func pick(_ count: Int) -> [SkySimile] {
        let table = SkySimiles.all
        guard table.count > count else { return table }
        let labs = table.map { Lab($0.rgb) }

        var chosen = [labs.indices.min { labs[$0].l < labs[$1].l }!]
        // Distance from each colour to the nearest chosen one, kept up to date
        // rather than recomputed: this is the difference between four thousand
        // comparisons and two hundred thousand.
        var nearest = labs.map { deltaE2000($0, labs[chosen[0]]) }

        while chosen.count < count {
            var best = 0
            for index in labs.indices where nearest[index] > nearest[best] { best = index }
            chosen.append(best)
            for index in labs.indices {
                nearest[index] = min(nearest[index], deltaE2000(labs[index], labs[best]))
            }
        }
        return chosen.map { table[$0] }
    }
}
