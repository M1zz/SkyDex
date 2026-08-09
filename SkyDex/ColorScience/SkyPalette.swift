import Foundation

/// The colours pulled out of one sky, ordered from the top of the frame down to
/// the horizon so the swatches rebuild the gradient the user actually saw
/// rather than ranking by how much of it there was.
struct SkyPalette {
    let colors: [RGB]

    /// The dominant sky cluster. Placement on the dial and the novelty rule
    /// both key off this one, so the collection rule stays simple. The rest of
    /// the palette is description, not judgement — folding it into the rule
    /// would multiply the chances of any capture counting as new.
    let anchor: RGB
    let anchorLab: Lab

    /// Mean colour difference between every sampled pixel and its nearest
    /// palette entry. Below ΔE 2 the palette is indistinguishable from the
    /// photograph; a sunset that jumps to 4 is telling you the sky was too
    /// complicated for six colours, which is worth knowing.
    let reconstructionError: Double
}

extension Lab {
    /// A code in Pantone's shape, but every digit read off the colour:
    /// lightness, then hue angle in ten-degree steps, then chroma.
    ///
    /// Like Pantone, this identifies a colour rather than an instance — the
    /// same code twice means the same sky was met twice.
    var skyCode: String {
        let hue = (hueDegrees / 10).rounded()
        return String(
            format: "%02d-%02d%02d",
            Int(l.rounded()).clampedToCode,
            Int(hue) % 36,
            Int(chroma.rounded()).clampedToCode
        )
    }
}

private extension Int {
    var clampedToCode: Int { Swift.min(Swift.max(self, 0), 99) }
}
