import Foundation

/// The board, at whatever resolution it has earned.
///
/// One day is divided into slots and laid out in a grid. Fill every slot and
/// the board does not end — it halves, and the same day comes back finer. Level
/// 0 is forty-eight slots, level 1 ninety-six, level 2 a hundred and
/// ninety-two. Nothing resets and nothing is lost; the collection just gets
/// more exact about what time it was.
///
/// That is why the colours are not a table. They come off a curve — anchor
/// colours pinned to real moments of the day, interpolated in CIELAB — so any
/// resolution samples the same day. Interpolating in RGB instead would drag the
/// dawn blues through a muddy grey, which is exactly where the extra slots go.
enum SkyBoard {

    /// Past this the slots are minutes wide and the beads are too small to
    /// aim at. A board this fine is a distant edge, not a goal.
    static let maxLevel = 2

    // MARK: - The day curve

    /// Minute of day → the sky at that moment. Pinned to real events: civil
    /// twilight, sunrise, zenith, golden hour, sunset, afterglow. The last
    /// anchor repeats the first so midnight closes on itself.
    private static let anchors: [(minute: Int, hex: String)] = [
        (0,    "#080D18"), (200,  "#0B1120"), (290,  "#141D33"), (330,  "#2B3856"),
        (365,  "#4E5F8C"), (395,  "#7E90B6"), (420,  "#A2AFCA"), (470,  "#7FA4CE"),
        (540,  "#5590C6"), (660,  "#2F7BBE"), (750,  "#1C6DB4"), (870,  "#2A76B8"),
        (960,  "#4C8AC4"), (1020, "#7FA6CD"), (1075, "#C1A07E"), (1110, "#D68F55"),
        (1140, "#B85A34"), (1170, "#8E4340"), (1200, "#5E3A54"), (1240, "#33304C"),
        (1300, "#161C31"), (1380, "#0A101E"), (1440, "#080D18")
    ]

    private static let curve: [(minute: Int, lab: Lab)] = anchors.map {
        (minute: $0.minute, lab: Lab(RGB(hex: $0.hex) ?? RGB(r: 0, g: 0, b: 0)))
    }

    static func colour(atMinute minute: Int) -> RGB {
        let m = ((minute % 1440) + 1440) % 1440
        for index in 0..<(curve.count - 1) {
            let (m0, lab0) = curve[index]
            let (m1, lab1) = curve[index + 1]
            guard m >= m0, m <= m1 else { continue }
            let raw = m1 == m0 ? 0 : Double(m - m0) / Double(m1 - m0)
            // Smoothstep, so the anchors do not show up as creases in the ramp.
            let t = raw * raw * (3 - 2 * raw)
            return RGB(Lab(
                l: lab0.l + (lab1.l - lab0.l) * t,
                a: lab0.a + (lab1.a - lab0.a) * t,
                b: lab0.b + (lab1.b - lab0.b) * t
            ))
        }
        return RGB(curve[curve.count - 1].lab)
    }

    // MARK: - Slots

    /// Slot counts at level 0. The sky does not change at an even rate, so the
    /// five hours after midnight get six slots and the three hours of sunset
    /// and afterglow get twelve. Every level doubles these.
    private static let bands: [(name: String, start: Int, end: Int, slots: Int)] = [
        ("한밤", 0, 300, 6),
        ("여명", 300, 480, 6),
        ("낮", 480, 960, 12),
        ("늦은 오후", 960, 1080, 6),
        ("노을", 1080, 1260, 12),
        ("밤", 1260, 1440, 6)
    ]

    private static let boards: [[SkySlot]] = (0...maxLevel).map { build(level: $0) }

    static func slots(level: Int) -> [SkySlot] {
        boards[min(max(level, 0), maxLevel)]
    }

    /// Wider at level 0 so the beads stay large; more columns as the board
    /// gets finer, so it keeps roughly the shape of a screen and keeps fitting
    /// on one without scrolling.
    static func columns(level: Int) -> Int {
        [6, 8, 12][min(max(level, 0), maxLevel)]
    }

    static func slot(forMinute minute: Int, level: Int) -> SkySlot {
        let board = slots(level: level)
        let clamped = min(1439, max(0, minute))
        return board.last { $0.startMinute <= clamped } ?? board[0]
    }

    static func band(forMinute minute: Int) -> String {
        let clamped = min(1439, max(0, minute))
        return bands.last { $0.start <= clamped }?.name ?? bands[0].name
    }

    /// The finest board every slot of which has been filled. Derived rather
    /// than stored, so it can never disagree with the photos.
    static func level(forMinutes minutes: [Int]) -> Int {
        var level = 0
        while level < maxLevel {
            let board = slots(level: level)
            var covered = Set<Int>()
            for minute in minutes {
                covered.insert(slot(forMinute: minute, level: level).id)
            }
            guard covered.count >= board.count else { break }
            level += 1
        }
        return level
    }

    private static func build(level: Int) -> [SkySlot] {
        var result: [SkySlot] = []
        let factor = 1 << level
        for band in bands {
            let count = band.slots * factor
            let width = Double(band.end - band.start) / Double(count)
            for index in 0..<count {
                let start = band.start + Int((width * Double(index)).rounded())
                let end = band.start + Int((width * Double(index + 1)).rounded())
                result.append(
                    SkySlot(
                        id: result.count,
                        level: level,
                        startMinute: start,
                        endMinute: end,
                        rgb: colour(atMinute: (start + end) / 2),
                        band: band.name
                    )
                )
            }
        }
        return result
    }
}
