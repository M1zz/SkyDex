import Foundation
import SwiftData

/// One capture.
///
/// Every sky that was read gets an entry, whether or not it earned a dot.
/// Looking up is always a success; catching a colour you did not already own is
/// the rarer thing on top. `isNovel` is the only difference between them.
@Model
final class SkyEntry {
    var capturedAt: Date = Date()

    /// The dominant sky colour — the one the dial, the code and the novelty
    /// rule all use.
    var anchorHex: String = "#000000"
    var labL: Double = 0
    var labA: Double = 0
    var labB: Double = 0

    /// The whole palette, ordered top of frame to horizon.
    var paletteHexes: [String] = []
    var reconstructionError: Double = 0
    var extractorVersion: Int = 0

    /// Filename in `PhotoStore.directory`. Empty when the picture is gone.
    var photoName: String = ""

    var bandKey: String = "midday"
    var phaseRaw: String = SolarPhase.day.rawValue
    var solarProgress: Double = 0.5

    var seasonKey: String = ""
    var isNovel: Bool = false
    var noveltyDistance: Double?

    /// What the user called this sky. The app supplies the trailing "하늘".
    var name: String = ""

    init(
        capturedAt: Date,
        palette: SkyPalette,
        position: SolarPosition,
        bandKey: String,
        seasonKey: String,
        isNovel: Bool,
        noveltyDistance: Double?,
        photoName: String,
        name: String = ""
    ) {
        self.capturedAt = capturedAt
        self.anchorHex = palette.anchor.hex
        self.labL = palette.anchorLab.l
        self.labA = palette.anchorLab.a
        self.labB = palette.anchorLab.b
        self.paletteHexes = palette.colors.map(\.hex)
        self.reconstructionError = palette.reconstructionError
        self.extractorVersion = SkyColorExtractor.version
        self.photoName = photoName
        self.bandKey = bandKey
        self.phaseRaw = position.phase.rawValue
        self.solarProgress = position.progress
        self.seasonKey = seasonKey
        self.isNovel = isNovel
        self.noveltyDistance = noveltyDistance
        self.name = name
    }

    var anchor: RGB { RGB(hex: anchorHex) ?? RGB(r: 0, g: 0, b: 0) }
    var lab: Lab { Lab(l: labL, a: labA, b: labB) }
    var palette: [RGB] { paletteHexes.compactMap { RGB(hex: $0) } }
    var code: String { lab.skyCode }

    var phase: SolarPhase { SolarPhase(rawValue: phaseRaw) ?? .day }
    var position: SolarPosition { SolarPosition(phase: phase, progress: solarProgress) }
    var dialAngle: Double? { position.dialAngle }

    var bandName: String {
        guard phase != .night else { return "밤" }
        return Palette.band(forKey: bandKey)?.name ?? bandKey
    }

    var displayName: String { name.isEmpty ? "이름 없는" : name }
    var isStale: Bool { extractorVersion < SkyColorExtractor.version && !photoName.isEmpty }
}
