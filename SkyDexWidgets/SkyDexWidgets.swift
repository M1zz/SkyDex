import SwiftUI
import WidgetKit

/// Two widgets, and neither of them is a notification.
///
/// The app's whole argument is that the sky is worth looking up at, so a widget
/// for it must not become the thing you look at instead. Both of these are
/// quiet: no counts, no streaks, nothing that goes red when a day is missed.
/// One shows the day as a board, the other shows the sky you got today, and if
/// you have not been out yet they say so plainly and leave it there.
@main
struct SkyDexWidgets: WidgetBundle {
    var body: some Widget {
        BoardWidget()
        TodaySkyWidget()
    }
}

/// One reading of the shared shelf, at one minute.
struct SkyEntryTimeline: TimelineEntry {
    let date: Date
    let snapshot: SkySnapshot?

    /// Which of the forty-eight this minute falls in. Worked out here rather
    /// than read from the file, because the file is written when the app is open
    /// and this has to be right at three in the morning.
    var nowSlot: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return SkyBoard.slot(forMinute: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)).id
    }

    /// Today's sky, or nothing. A snapshot left over from another day still
    /// draws a board — the sun moves a minute a day — but it cannot supply a
    /// photograph for a heading that says today.
    var today: SkySnapshot.Latest? {
        guard let snapshot, snapshot.isToday else { return nil }
        return snapshot.latest
    }
}

/// Reads the shelf and wakes at the top of each slot.
///
/// Nothing here fetches, decodes a library, or touches a store. The heaviest
/// thing it does is read a few hundred bytes of JSON that the app already wrote.
///
/// The refresh times are the board's own: the ring has to move when the slot
/// does, and there is no reason to wake in between. Forty-eight boundaries a day
/// is well inside what the system will give a widget, and the app reloads the
/// timeline itself whenever a new sky lands.
struct SkyProvider: TimelineProvider {
    func placeholder(in context: Context) -> SkyEntryTimeline {
        SkyEntryTimeline(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SkyEntryTimeline) -> Void) {
        completion(SkyEntryTimeline(date: .now, snapshot: SkySnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SkyEntryTimeline>) -> Void) {
        let snapshot = SkySnapshot.read()
        let now = Date.now
        var dates = [now]
        var cursor = now
        for _ in 0..<8 {
            guard let next = SkyProvider.nextBoundary(after: cursor) else { break }
            dates.append(next)
            cursor = next
        }
        let entries = dates.map { SkyEntryTimeline(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// When the board's current slot next changes.
    static func nextBoundary(after date: Date) -> Date? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let minute = Int(date.timeIntervalSince(start) / 60)
        if let slot = SkyBoard.slots.first(where: { $0.startMinute > minute }) {
            return calendar.date(byAdding: .minute, value: slot.startMinute, to: start)
        }
        // Past the last slot of the day, the next change is midnight.
        return calendar.date(byAdding: .day, value: 1, to: start)
    }
}
