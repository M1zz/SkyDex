#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// App Store screenshots, without a camera.
///
/// The simulator has no camera, and filling a board by picking two dozen
/// pictures from Photos in every language is a morning of tapping. So a debug
/// build launched with `-SkyDexDemo` opens an in-memory store with a day of skies
/// already in it, and `-SkyDexDemoScreen <name>` opens one screen on top of it:
///
///   board    the board as it opens
///   reading  one sky laid under the board, with its line and its name
///   card     that sky's card
///   palette  the archive, on the palette
///   empty    the sheet for an empty slot
///
/// Nothing here exists in a release build, and nothing here touches the real
/// store: the container is memory-only and goes away with the process.
@MainActor
enum ScreenshotDemo {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isOn: Bool { arguments.contains("-SkyDexDemo") }

    static var screen: String? {
        guard let index = arguments.firstIndex(of: "-SkyDexDemoScreen"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// The slot the screenshots read and the half hour whose empty sheet they open.
    static let notedSlot = 20
    static let emptySlot = 7

    /// Slots filled, in board order, and the colour each came out. Taken from a
    /// real board so the day runs night → dawn → blue → sunset → night.
    private static let fills: [(slot: Int, hex: String)] = [
        (2, "#26272C"), (4, "#303D60"), (6, "#4C648A"), (8, "#6C6461"), (10, "#8396BB"),
        (13, "#ACB9CC"), (14, "#9FC0D6"), (15, "#3D8FD0"), (17, "#2E7BC1"), (18, "#3266BA"),
        (20, "#BED8E6"), (22, "#7E9179"), (25, "#EEAEB9"), (27, "#A6857A"), (29, "#EEE2D4"),
        (31, "#D7C092"), (33, "#F0B64B"), (35, "#E9875A"), (37, "#E1855B"), (39, "#D04631"),
        (42, "#C75C6C"), (44, "#5D4F5A"), (46, "#47395F")
    ]

    static func makeContainer() -> ModelContainer {
        let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SkyEntry.self, configurations: memoryOnly)
        seed(container.mainContext)
        return container
    }

    private static func seed(_ context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        for fill in fills {
            let slot = SkyBoard.slots[fill.slot]
            // 13:27 for the sky the screenshots read; otherwise a few minutes in.
            let minute = fill.slot == notedSlot ? 13 * 60 + 27 : slot.startMinute + 7
            let date = today.addingTimeInterval(TimeInterval(minute * 60))
            let rgb = RGB(hex: fill.hex) ?? RGB(r: 0.5, g: 0.5, b: 0.5)
            let prepared = picture(of: rgb, seed: fill.slot).flatMap { SkyImage.prepare(data: $0) }
            let entry = SkyEntry(
                capturedAt: date,
                rgb: rgb,
                lab: Lab(rgb),
                photoData: prepared?.photo,
                thumbnailData: prepared?.thumbnail,
                note: fill.slot == notedSlot ? note : ""
            )
            context.insert(entry)
        }
        try? context.save()
    }

    /// A sky over a few roofs: the colour, a little lighter toward the top, and
    /// a dark skyline along the bottom third.
    private static func picture(of rgb: RGB, seed: Int) -> Data? {
        let side: CGFloat = 1280
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { context in
            let cg = context.cgContext
            let base = UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
            let top = UIColor(
                red: min(1, rgb.r * 1.06 + 0.03),
                green: min(1, rgb.g * 1.06 + 0.03),
                blue: min(1, rgb.b * 1.06 + 0.03),
                alpha: 1
            )
            let colours = [top.cgColor, base.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: side), options: [])
            }
            UIColor(red: 0.2, green: 0.22, blue: 0.24, alpha: 1).setFill()
            var x: CGFloat = 0
            var step = seed
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: side))
            while x < side {
                step = (step &* 1103515245 &+ 12345) & 0x7fffffff
                let width = CGFloat(120 + step % 220)
                let height = CGFloat(260 + (step / 7) % 360)
                path.addLine(to: CGPoint(x: x, y: side - height))
                path.addLine(to: CGPoint(x: x + width, y: side - height))
                x += width
            }
            path.addLine(to: CGPoint(x: side, y: side))
            path.close()
            path.fill()
        }
        return image.jpegData(compressionQuality: 0.9)
    }

    /// The line written on the sky the screenshots read, in the language the
    /// app is running in.
    private static var note: String {
        let language = Locale.preferredLanguages.first ?? "ko"
        let match = notes.keys
            .filter { language.hasPrefix($0) }
            .max { $0.count < $1.count }
        return match.flatMap { notes[$0] } ?? notes["ko"]!
    }

    private static let notes: [String: String] = [
        "ko": "점심 먹고 나오는 길, 하늘이 유난히 옅었다",
        "en": "Walking back from lunch, the sky was so pale today",
        "en-GB": "Walking back from lunch, the sky was ever so pale",
        "ja": "お昼の帰り道、空がやけに淡かった",
        "zh-Hans": "吃完午饭出来，天空格外淡",
        "zh-Hant": "吃完午餐出來，天空格外淡",
        "ru": "Шла с обеда, а небо было удивительно бледным",
        "es": "Saliendo de comer, el cielo estaba pálido como nunca",
        "de": "Auf dem Rückweg vom Mittagessen war der Himmel so blass",
        "fr": "En sortant déjeuner, le ciel était d’un pâle étonnant",
        "it": "Uscendo dal pranzo, il cielo era stranamente pallido",
        "pt": "Voltando do almoço, o céu estava pálido demais",
        "th": "เดินออกมาหลังมื้อเที่ยง ท้องฟ้าซีดจางเป็นพิเศษ",
        "vi": "Ăn trưa xong bước ra, bầu trời nhạt lạ thường",
        "cs": "Cestou z oběda bylo nebe nezvykle bledé",
        "da": "På vej hjem fra frokost var himlen helt bleg",
        "el": "Γυρνώντας από το μεσημεριανό, ο ουρανός ήταν πολύ χλωμός",
        "fi": "Lounaalta palatessa taivas oli oudon vaalea",
        "id": "Pulang makan siang, langitnya pucat sekali",
        "nb": "På vei fra lunsj var himmelen uvanlig blek",
        "nl": "Op weg terug van de lunch was de lucht zo bleek",
        "pl": "Kiedy wracałam z obiadu, niebo było wyjątkowo blade",
        "sv": "På väg från lunchen var himlen ovanligt blek",
        "tr": "Öğle yemeğinden dönerken gökyüzü bir tuhaf solgundu"
    ]

    static func notedEntry(in entries: [SkyEntry]) -> SkyEntry? {
        entries.first { !$0.note.isEmpty }
    }
}
#endif
