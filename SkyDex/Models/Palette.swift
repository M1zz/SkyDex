import Foundation

/// The reference palette: what each stretch of the arc typically does.
///
/// These are not targets. Nothing is rejected for failing to match one. They
/// exist so the dial reads as a collection rather than a scatter — a faint
/// outline of the shape a season takes, drawn behind whatever the user finds.
///
/// Within a band, lightness doubles as cloud cover: the clearest sky is the
/// darkest and most saturated, heavy overcast the brightest and greyest. Every
/// neighbouring pair sits about ΔE 15 apart, which is why bands hold different
/// numbers of colours.
enum Palette {

    /// A reference colour counts as reached once a collected colour lands
    /// within this distance. Half the spacing between neighbours, so one
    /// capture can never tick off two at once.
    static let reachThreshold = 7.5

    static let bands: [Band] = [
        Band(key: "dawnDeep", name: "여명", phase: .morningTwilight, start: 0.00, end: 0.50,
             hexes: ["#080D1E", "#373E54"]),
        Band(key: "dawnCivil", name: "동틀 무렵", phase: .morningTwilight, start: 0.50, end: 1.00,
             hexes: ["#2E3E66", "#616682", "#8A8A99"]),

        Band(key: "sunrise", name: "일출", phase: .day, start: 0.00, end: 0.08,
             hexes: ["#6E6386", "#9489A0", "#C2B7C0"]),
        Band(key: "earlyMorning", name: "이른 아침", phase: .day, start: 0.08, end: 0.20,
             hexes: ["#5A7BAE", "#91A5C9", "#CED8E9"]),
        Band(key: "morning", name: "오전", phase: .day, start: 0.20, end: 0.36,
             hexes: ["#3B7EC0", "#84A7D6", "#C8D7EE"]),
        Band(key: "midday", name: "한낮", phase: .day, start: 0.36, end: 0.64,
             hexes: ["#175291", "#5B79AD", "#8EA4CA", "#CAD9ED"]),
        Band(key: "afternoon", name: "오후", phase: .day, start: 0.64, end: 0.80,
             hexes: ["#2E6BA8", "#6D8FBF", "#ABBEDB"]),
        Band(key: "evening", name: "이른 저녁", phase: .day, start: 0.80, end: 0.92,
             hexes: ["#4A6E9E", "#8092B3", "#B8BDCB"]),
        Band(key: "sunset", name: "일몰", phase: .day, start: 0.92, end: 1.00,
             hexes: ["#8E3A22", "#AF6847", "#D09770", "#F3CFA2"]),

        Band(key: "duskCivil", name: "해거름", phase: .eveningTwilight, start: 0.00, end: 0.50,
             hexes: ["#4A3A5A", "#796073", "#A28388"]),
        Band(key: "duskDeep", name: "박명", phase: .eveningTwilight, start: 0.50, end: 1.00,
             hexes: ["#0A1024", "#394059"])
    ]

    static let references: [ReferenceSky] = {
        var result: [ReferenceSky] = []
        for band in bands {
            for index in band.hexes.indices {
                result.append(
                    ReferenceSky(
                        bandKey: band.key,
                        index: index,
                        hex: band.hexes[index],
                        countInBand: band.hexes.count
                    )
                )
            }
        }
        return result
    }()

    static func band(forKey key: String) -> Band? {
        bands.first { $0.key == key }
    }

    /// Nil after nautical dusk, when there is no band to collect into.
    static func band(for position: SolarPosition) -> Band? {
        guard position.isCollectable else { return nil }
        return bands.first { $0.contains(position) }
    }

    static func references(inBand key: String) -> [ReferenceSky] {
        references.filter { $0.bandKey == key }
    }
}
