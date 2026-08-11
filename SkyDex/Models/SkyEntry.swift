import Foundation
import SwiftData
import UIKit

/// One collected sky.
///
/// Nothing here judges the photo. A capture is written the moment it is taken
/// and it fills the slot its clock time falls in — no tolerance, no rejection,
/// no way to aim at an easier slot.
///
/// `minuteOfDay` and `slotID` are both stored even though either could be
/// derived from `capturedAt`, because `@Query` can only sort and group on
/// stored properties.
@Model
final class SkyEntry {
    var uuid: UUID = UUID()
    var capturedAt: Date = Date()
    var minuteOfDay: Int = 0
    var slotID: Int = 0
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
        self.slotID = SkyBoard.slot(forMinute: minute).id
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

    /// Rows written before the board have no `slotID` and, from the version
    /// before that, no `minuteOfDay` or `uuid` either — lightweight migration
    /// hands them the schema defaults, which would file every old capture in
    /// the first slot of the day. Runs once per schema change.
    static func repairLegacyRows(in context: ModelContext) {
        let flag = "skydex.repairedForBoard"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        guard let all = try? context.fetch(FetchDescriptor<SkyEntry>()) else { return }
        var seen = Set<UUID>()
        for entry in all {
            let minute = minuteOfDay(of: entry.capturedAt)
            if entry.minuteOfDay != minute { entry.minuteOfDay = minute }
            let slot = SkyBoard.slot(forMinute: minute).id
            if entry.slotID != slot { entry.slotID = slot }
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
    var slot: SkySlot { SkyBoard.slot(id: slotID) }

    var thumbnail: UIImage? {
        guard let thumbnailData else { return nil }
        return ThumbnailCache.image(id: uuid.uuidString, data: thumbnailData)
    }

    var photo: UIImage? {
        guard let photoData else { return nil }
        return UIImage(data: photoData)
    }
}
