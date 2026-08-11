import Foundation

/// One place on the board.
///
/// A slot is a stretch of the day, not a colour to be matched. Its `rgb` is the
/// sky that time of day usually is; nothing ever compares a photo against it.
/// `ghost` is that same colour faded — what the slot is drawn in until it has
/// been collected, so an empty board still tells you where each colour goes.
///
/// `id` is an index within one board, so it only means anything alongside the
/// `level` it came from.
struct SkySlot: Identifiable, Hashable {
    let id: Int
    let level: Int
    let startMinute: Int
    let endMinute: Int
    let rgb: RGB
    let ghost: RGB
    let band: String

    var hex: String { rgb.hex }

    var timeLabel: String {
        String(
            format: "%02d:%02d–%02d:%02d",
            startMinute / 60, startMinute % 60,
            (endMinute / 60) % 24, endMinute % 60
        )
    }
}
