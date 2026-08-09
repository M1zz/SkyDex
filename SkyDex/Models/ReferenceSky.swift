import Foundation

/// One colour in the reference palette — a ghost on the dial, not a target.
struct ReferenceSky: Identifiable, Hashable {
    let bandKey: String
    let index: Int
    let hex: String
    let countInBand: Int

    var id: String { "\(bandKey)-\(index)" }

    var rgb: RGB { RGB(hex: hex) ?? RGB(r: 0, g: 0, b: 0) }
    var lab: Lab { Lab(rgb) }

    var band: Band? { Palette.band(forKey: bandKey) }
    var bandName: String { band?.name ?? bandKey }

    /// Lightness within a band is cloud cover, so that is what the label says.
    var skyLabel: String {
        guard countInBand > 1 else { return "그때의" }
        if index == 0 { return "맑은" }
        if index == countInBand - 1 { return "흐린" }
        if countInBand == 4 && index == 1 { return "옅은 구름" }
        return "구름 낀"
    }
}
