import Foundation
import SwiftData
import UIKit

/// One collected sky.
///
/// Nothing here judges the photo. A capture is written the moment it is taken and
/// kept — no tolerance, no rejection, nothing to pass.
///
/// `minuteOfDay` is stored even though it could be derived from `capturedAt`,
/// because `@Query` can only sort on stored properties.
///
/// A photo does not belong to a slot. The board is a set of colours for one day,
/// and whether this sky fills one of them is a question about colour, asked fresh
/// every time the board is drawn — tomorrow's board asks it again and gets a
/// different answer. What is stored is what was true: when it was taken and what
/// colour it came out.
@Model
final class SkyEntry {
    var uuid: UUID = UUID()
    var capturedAt: Date = Date()
    var minuteOfDay: Int = 0
    var hex: String = "#000000"
    var labL: Double = 0
    var labA: Double = 0
    var labB: Double = 0
    var seasonKey: String = ""
    var note: String = ""

    /// Small enough that the board can decode every photo it might show.
    var thumbnailData: Data?

    /// External storage keeps the blob out of the row, so reading the board
    /// never faults a megabyte of JPEG it is not going to draw.
    @Attribute(.externalStorage) var photoData: Data?

    init(
        capturedAt: Date,
        rgb: RGB,
        lab: Lab,
        photoData: Data?,
        thumbnailData: Data?,
        note: String = ""
    ) {
        let minute = SkyEntry.minuteOfDay(of: capturedAt)
        self.uuid = UUID()
        self.capturedAt = capturedAt
        self.minuteOfDay = minute
        self.hex = rgb.hex
        self.labL = lab.l
        self.labA = lab.a
        self.labB = lab.b
        self.seasonKey = Season.key(for: capturedAt)
        self.note = note
        self.photoData = photoData
        self.thumbnailData = thumbnailData
    }

    static func minuteOfDay(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Rows written before the board have no `minuteOfDay` or `uuid` —
    /// lightweight migration hands them the schema defaults, which would file
    /// every old capture at midnight. Runs once.
    static func repairLegacyRows(in context: ModelContext) {
        let flag = "skydex.repairedForBoard"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        guard let all = try? context.fetch(FetchDescriptor<SkyEntry>()) else { return }
        var seen = Set<UUID>()
        for entry in all {
            let minute = minuteOfDay(of: entry.capturedAt)
            if entry.minuteOfDay != minute { entry.minuteOfDay = minute }
            if !seen.insert(entry.uuid).inserted {
                entry.uuid = UUID()
                seen.insert(entry.uuid)
            }
        }
        try? context.save()

        UserDefaults.standard.set(true, forKey: flag)
    }

    var rgb: RGB { RGB(hex: hex) ?? RGB(r: 0, g: 0, b: 0) }
    var lab: Lab { Lab(l: labL, a: labA, b: labB) }
    /// The part of the day this was taken in — a name that does not depend on
    /// how fine the board currently is.
    var band: String { SkyBoard.band(forMinute: minuteOfDay) }

    /// How current this capture still is, `1` down to `0`.
    ///
    /// A week at full, then eight weeks running down to nothing. The board draws
    /// a stale slot closer to its empty colour, so a board left alone slowly
    /// goes quiet and one photo brings its slot straight back.
    ///
    /// The point is not to punish a gap. Nothing is deleted, no count breaks,
    /// and a slot at zero is still visibly collected — it just stops looking
    /// like today. Fading is the one honest way for a board of skies to say that
    /// a sky was a while ago.
    func freshness(at now: Date) -> Double {
        let days = now.timeIntervalSince(capturedAt) / 86_400
        guard days > SkyEntry.freshDays else { return 1 }
        let fading = (days - SkyEntry.freshDays) / SkyEntry.fadingDays
        return max(0, 1 - min(1, fading))
    }

    static let freshDays: Double = 7
    static let fadingDays: Double = 56

    var thumbnail: UIImage? {
        guard let thumbnailData else { return nil }
        return ThumbnailCache.image(id: uuid.uuidString, data: thumbnailData)
    }

    var photo: UIImage? {
        guard let photoData else { return nil }
        return PhotoCache.image(id: uuid.uuidString, data: photoData)
    }

    /// Both caches, because both hold something keyed to this row.
    func forgetImages() {
        ThumbnailCache.forget(id: uuid.uuidString)
        PhotoCache.forget(id: uuid.uuidString)
    }
}
