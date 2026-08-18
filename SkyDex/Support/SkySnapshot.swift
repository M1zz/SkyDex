import Foundation

/// What the widgets are allowed to know.
///
/// A widget is not the app. It gets a few tens of milliseconds and a few tens of
/// megabytes, it runs when nobody asked it to, and it must never be the reason a
/// photo library is opened. So it is not given the store: no SwiftData, no
/// photos, no forecast, no location. The app works everything out while it is
/// running — today's forty-eight colours, which of them the collection covers,
/// what the last sky looked like — and leaves the answer in the shared container
/// as a few hundred bytes of JSON and one thumbnail.
///
/// Which means a widget is always as fresh as the last time the app was open,
/// and says so rather than pretending. A board written yesterday still draws
/// today: the sun moves by about a minute a day, and the colours of the sky at
/// four o'clock are not a different sky because the date changed. What must not
/// be reused is a *photograph* — "오늘의 하늘" is a claim about today, so a
/// snapshot from another day reports no sky rather than the wrong one.
struct SkySnapshot: Codable {

    /// The container both sides use. It has to exist in the entitlements of the
    /// app and of the extension; when it does not, everything here fails quietly
    /// and the widget shows its empty face rather than crashing something that
    /// runs on the home screen.
    static let group = "group.com.leeo.SkyDex"

    /// The day these colours were worked out for.
    let day: Date

    /// Today's forty-eight, in board order, as hex. Written by the app because
    /// working them out needs the sun, the place and the forecast.
    let targets: [String]

    /// The slots the collection covers, already faded to the age of the photo
    /// that fills them — the widget draws, it does not decide.
    let filled: [Fill]

    /// The most recent sky of that day, if there was one.
    let latest: Latest?

    struct Fill: Codable {
        let slot: Int
        let hex: String
    }

    struct Latest: Codable {
        let hex: String
        let capturedAt: Date
        let slot: Int
        let note: String

        /// What the colour is like in plain Korean — 물에 젖은 청바지색 — and one
        /// line saying where you have seen it. The sourced name (담자색,
        /// 우스하나이로) stays in the app: a widget is read at a glance from
        /// across a room, and that is exactly the reading where a name nobody
        /// can picture is worth nothing.
        let likeness: String
        let likenessNote: String

        /// Whether the sky is that thing or merely nearest to it. The widget has
        /// to be able to say which, the same as everywhere else.
        let isCloseLikeness: Bool

        let hasPhoto: Bool
    }

    // MARK: - The shelf

    private static let fileName = "today.json"
    private static let photoName = "latest.jpg"

    private static var folder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    /// Leave today's answer where the widget can find it.
    ///
    /// Written whole or not at all: a widget that reads half a file draws a
    /// broken board on someone's home screen, and there is no way for it to know
    /// that is what happened.
    static func write(_ snapshot: SkySnapshot, photo: Data?) {
        guard let folder else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: folder.appending(path: fileName), options: .atomic)

        let photoURL = folder.appending(path: photoName)
        if let photo {
            try? photo.write(to: photoURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: photoURL)
        }
    }

    static func read() -> SkySnapshot? {
        guard let folder,
              let data = try? Data(contentsOf: folder.appending(path: fileName))
        else { return nil }
        return try? JSONDecoder().decode(SkySnapshot.self, from: data)
    }

    static func photo() -> Data? {
        guard let folder else { return nil }
        return try? Data(contentsOf: folder.appending(path: photoName))
    }

    /// The colour of one slot as the widget should draw it: what fills it, or
    /// the ghost of what that time of day usually looks like.
    func colour(of slot: Int) -> (rgb: RGB, isFilled: Bool) {
        if let fill = filled.first(where: { $0.slot == slot }), let rgb = RGB(hex: fill.hex) {
            return (rgb, true)
        }
        let target = slot < targets.count ? RGB(hex: targets[slot]) : nil
        return (SkyBoard.ghost(of: target ?? RGB(r: 0.5, g: 0.5, b: 0.5)), false)
    }

    /// Whether a sky in this snapshot can still be called today's.
    var isToday: Bool { Calendar.current.isDateInToday(day) }
}
