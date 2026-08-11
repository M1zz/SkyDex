import Foundation

/// One place on the board.
///
/// A slot is a stretch of the day, not a colour to be matched. Its `hex` is the
/// sky that time of day usually is — it shows through faintly while the slot is
/// empty, so the gradient you are filling in is visible before you fill it.
/// Nothing compares a photo against it.
struct SkySlot: Identifiable, Hashable {
    let id: Int
    let startMinute: Int
    let endMinute: Int
    let hex: String
    let band: String

    var rgb: RGB { RGB(hex: hex) ?? RGB(r: 0, g: 0, b: 0) }

    var timeLabel: String {
        String(
            format: "%02d:%02d–%02d:%02d",
            startMinute / 60, startMinute % 60,
            (endMinute / 60) % 24, endMinute % 60
        )
    }
}
