import Foundation

/// One place on the board.
///
/// A slot is a stretch of the day, not a colour to be matched. It knows when it
/// is and what part of the day it belongs to, and nothing about how it looks —
/// ask `SkyDay` for that, because the same half hour is a different sky in
/// January than in July.
///
/// `id` is the slot's index on the board, 0–47, running midnight to midnight.
struct SkySlot: Identifiable, Hashable {
    let id: Int
    let startMinute: Int
    let endMinute: Int
    let band: String

    var timeLabel: String {
        String(
            format: "%02d:%02d–%02d:%02d",
            startMinute / 60, startMinute % 60,
            (endMinute / 60) % 24, endMinute % 60
        )
    }
}
