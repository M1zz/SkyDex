import Foundation

/// The board.
///
/// One day is divided into forty-eight slots and laid out in a six-by-eight
/// grid. That is the whole board and it never gets finer — a day split past
/// this is a day measured, and the beads get too small to aim at. Filling it is
/// not the end of anything either: slots fade as their photos age, so a full
/// board is something you keep rather than something you finish.
///
/// A slot is a stretch of the clock and nothing else. It carries no colour of
/// its own, because what a given half hour looks like depends on the date and
/// the place — that belongs to `SkyDay`. What has to stay fixed is which slot a
/// photo falls into, so a capture filed this morning still means the same thing
/// in December.
enum SkyBoard {

    /// The sky does not change at an even rate, so the five hours after
    /// midnight get six slots and the three hours of sunset and afterglow get
    /// twelve.
    private static let bands: [(name: String, start: Int, end: Int, slots: Int)] = [
        ("한밤", 0, 300, 6),
        ("여명", 300, 480, 6),
        ("낮", 480, 960, 12),
        ("늦은 오후", 960, 1080, 6),
        ("노을", 1080, 1260, 12),
        ("밤", 1260, 1440, 6)
    ]

    static let slots: [SkySlot] = build()

    /// Six across, eight down. Wide enough that the beads stay big enough to
    /// aim at, and the whole board still fits on one screen without scrolling.
    static let columns = 6

    static func slot(forMinute minute: Int) -> SkySlot {
        let clamped = min(1439, max(0, minute))
        return slots.last { $0.startMinute <= clamped } ?? slots[0]
    }

    /// Which bead a point on the board belongs to.
    ///
    /// The grid is a fixed pitch, so this is division rather than a hit test
    /// against forty-eight views. The gutter between two beads counts as part of
    /// the one before it: a finger between beads should land somewhere rather
    /// than nowhere, and a board with dead strips in it is a board that ignores
    /// presses for no reason a person can see.
    ///
    /// Points outside the grid return nil, which is how lifting a finger off the
    /// board takes a press back.
    static func slot(at point: CGPoint, diameter: CGFloat, gap: CGFloat) -> SkySlot? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let pitch = diameter + gap
        let column = Int((point.x / pitch).rounded(.down))
        let row = Int((point.y / pitch).rounded(.down))
        guard column < columns else { return nil }
        let index = row * columns + column
        guard index < slots.count else { return nil }
        return slots[index]
    }

    static func band(forMinute minute: Int) -> String {
        let clamped = min(1439, max(0, minute))
        return bands.last { $0.start <= clamped }?.name ?? bands[0].name
    }

    // MARK: - How a colour is drawn

    /// The colour an empty slot is drawn in: the sky that time of day usually
    /// is, faded until it can only place a colour, never stand in for one.
    ///
    /// Fading by opacity would not survive both appearances. Over white a
    /// translucent midnight goes pale and legible; over black it goes to black
    /// and the top of the board disappears. So the fade happens in Lab instead,
    /// and in two moves.
    ///
    /// Lightness is pulled most of the way to the neutral `L*52` the board is
    /// built around, keeping only a third of the sky's own. Enough is left that
    /// night still reads as the dark end and midday as the bright one, but no
    /// ring ever gets close enough to either paper to vanish into it.
    ///
    /// Chroma is cut to a bit over a third. The hue is what does the placing —
    /// it says where the sunset band starts — while the paleness is what keeps a
    /// collected sky, drawn at full strength, unmistakably the real thing.
    static func ghost(of rgb: RGB) -> RGB {
        let lab = Lab(rgb)
        return RGB(Lab(
            l: 52 + (lab.l - 52) * 0.32,
            a: lab.a * 0.38,
            b: lab.b * 0.38
        ))
    }

    /// A collected sky drawn at its age: its own colour while it is current,
    /// and about three fifths of the way to its empty colour once it has gone
    /// stale.
    ///
    /// It never travels the whole way. A slot that was collected has to keep
    /// reading as collected even at its faintest, and shape should not be the
    /// only thing left saying so.
    static func faded(_ rgb: RGB, freshness: Double) -> RGB {
        guard freshness < 1 else { return rgb }
        return RGB(Lab(rgb).blended(toward: Lab(ghost(of: rgb)), by: (1 - freshness) * 0.62))
    }

    private static func build() -> [SkySlot] {
        var result: [SkySlot] = []
        for band in bands {
            let count = band.slots
            let width = Double(band.end - band.start) / Double(count)
            for index in 0..<count {
                let start = band.start + Int((width * Double(index)).rounded())
                let end = band.start + Int((width * Double(index + 1)).rounded())
                result.append(
                    SkySlot(
                        id: result.count,
                        startMinute: start,
                        endMinute: end,
                        band: band.name
                    )
                )
            }
        }
        return result
    }
}
