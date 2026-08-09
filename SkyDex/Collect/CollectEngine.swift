import UIKit

/// Decides whether a capture is a colour the user does not already own.
///
/// The rule is not "does this match something we picked in advance" but "is
/// this different from what you already have" — so a sky can never be wrong,
/// only already known. Someone holding a deep blue and a pale blue who catches
/// the shade between them has found something, and gets a dot that lands
/// between the two.
///
/// Only the anchor colour is judged. Comparing whole palettes would multiply
/// the chances of any capture counting as new and the collection would balloon.
struct CollectEngine {

    /// Well above the roughly ΔE 2-3 where a difference becomes visible at all,
    /// so every new dot is a colour anyone could see is different — and far
    /// below the ΔE 15 spacing of the reference palette, so the collection can
    /// grow much finer than the frame suggests.
    ///
    /// Tuned by simulating ninety days of shooting: about two-thirds of a first
    /// month's captures come back new, dropping to roughly a third by the third
    /// month.
    static let noveltyThreshold = 6.0

    /// Anchor colours already on the dial this season, grouped by band.
    let held: [String: [Lab]]
    let clock: SolarClock

    func attempt(image: UIImage, at date: Date = .now) -> CollectOutcome {
        guard let palette = SkyColorExtractor.extract(from: image) else {
            return .noSkyFound
        }

        let position = clock.position(of: date)
        guard let band = Palette.band(for: position) else {
            return .afterDark(
                palette: palette, position: position,
                nextFirstLight: clock.nextFirstLight(after: date)
            )
        }

        let prior = held[band.key] ?? []
        guard !prior.isEmpty else {
            return .newColor(
                palette: palette, position: position, band: band,
                novelty: nil, placement: .first,
                reached: nearestReference(to: palette.anchorLab, in: band, alreadyHeld: prior)
            )
        }

        var nearest = deltaE2000(prior[0], palette.anchorLab)
        for lab in prior.dropFirst() {
            nearest = min(nearest, deltaE2000(lab, palette.anchorLab))
        }

        guard nearest >= Self.noveltyThreshold else {
            return .alreadyHeld(
                palette: palette, position: position, band: band, distance: nearest
            )
        }

        return .newColor(
            palette: palette, position: position, band: band,
            novelty: nearest,
            placement: placement(of: palette.anchorLab, among: prior),
            reached: nearestReference(to: palette.anchorLab, in: band, alreadyHeld: prior)
        )
    }

    private func placement(of lab: Lab, among prior: [Lab]) -> CollectOutcome.Placement {
        let darker = prior.contains { $0.l < lab.l }
        let brighter = prior.contains { $0.l > lab.l }
        if darker && brighter { return .between }
        if brighter { return .darker }
        if darker { return .brighter }
        return .different
    }

    private func nearestReference(
        to lab: Lab, in band: Band, alreadyHeld prior: [Lab]
    ) -> ReferenceSky? {
        Palette.references(inBand: band.key)
            .filter { reference in
                !prior.contains { deltaE2000($0, reference.lab) <= Palette.reachThreshold }
                    && deltaE2000(reference.lab, lab) <= Palette.reachThreshold
            }
            .min { deltaE2000($0.lab, lab) < deltaE2000($1.lab, lab) }
    }
}
