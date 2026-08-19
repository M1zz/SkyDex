import Foundation

#if canImport(UIKit)
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
#endif

/// One sky's colour, moved onto another sky's photograph.
///
/// This is the app's one filter, and it is not a tint. Laying a colour over the
/// frame at some opacity produces a photograph with cellophane on it: the
/// buildings go blue too, the clouds lose their edges, and the result says
/// "filtered" rather than "that evening". What is wanted instead is the picture
/// you took, standing under a sky you collected on some other day.
///
/// So the move is made in Lab, on the colours that were sky to begin with, and
/// it is a **shift rather than a fill**. Every pixel near the photograph's own
/// sky colour is carried by the same vector — the one that takes this sky's
/// colour to that one's — which keeps the gradient the sky already had. Filling
/// those pixels with the target colour instead would flatten a dusk that ran
/// from orange at the roofline to violet overhead into one even wash, and a sky
/// with no gradient left in it stops reading as sky at all.
///
/// Nothing here is spatial. There is no segmentation model and no "upper part of
/// the frame" rule: a pixel is sky to the extent that its colour is near the
/// colour this photograph was filed under, which the app has already worked out
/// once with `SkyColorExtractor` and stored on the entry. That is cheap, it is
/// deterministic, and it is honest about what it can do — a blue coat under a
/// blue sky will move with the sky. The framing this app asks for ("하늘이
/// 정사각형을 채우도록") is what makes that an acceptable trade.
///
/// The whole transform is baked into a colour cube so it costs the same whatever
/// it is applied to. That matters less for one still photograph than it will for
/// a viewfinder running at sixty frames a second, which is the next thing this
/// is for.
enum SkyRecolor {

    /// 33 is the size colour grading has settled on: fine enough that a smooth
    /// sky gradient crossing the mask's edge does not band, small enough that
    /// building the table is not something you wait for.
    static let cubeSide = 33

    /// Below this distance a colour is simply the sky and moves the whole way.
    static let near = 9.0

    /// Beyond this it is something else in the frame and is left alone. The gap
    /// between the two is where the mask feathers, and it is wide on purpose: a
    /// hard edge on a colour mask crawls along the roofline like a cut-out.
    static let far = 34.0

    /// How much a difference in lightness counts for when deciding what is sky
    /// — generous upward, strict downward.
    ///
    /// Brighter than the sky's own colour is usually still sky: a cloud, the
    /// haze over the roofline, the glare around the sun. Those have to come
    /// along, or the photograph comes back with its blue moved and its clouds
    /// still sitting in yesterday's light. So upward, lightness counts for a
    /// third.
    ///
    /// Darker than the sky is usually a thing in front of it. Buildings, road,
    /// the shaded side of everything — all of them nearly grey, all of them near
    /// enough in *hue* to a grey-blue sky to be swept up by a mask that only
    /// asked about colour. The first version of this took the sunset's warmth
    /// down the front of every building in the frame, which is precisely the
    /// "filter" look this is meant to avoid. So downward, lightness counts for
    /// slightly more than everything else, and the skyline stays where it was.
    ///
    /// This is the one place the filter knows anything about the world rather
    /// than about colour, and it costs nothing: it is still a question asked of
    /// one pixel, with no notion of where in the frame that pixel is.
    static let lightnessToleranceAbove = 3.0
    static let lightnessToleranceBelow = 0.8

    /// How much of the difference in lightness travels with the colour.
    ///
    /// None of it, and a noon sky wearing a midnight blue stays as bright as
    /// noon — the hue says night while the exposure says lunchtime, and the eye
    /// believes the exposure. All of it, and the same move drops sixty units of
    /// L on a fully lit frame and takes the clouds down into black with it.
    /// Two thirds keeps the direction of the change while leaving the picture a
    /// picture.
    static let lightnessTransfer = 0.65

    /// How much the sky's own range of lightness is stretched, about the
    /// lightness the sky itself lands on.
    ///
    /// Without this the filter moves colour and nothing else, and on a flat
    /// overcast frame that is a disappointment you can see: the sky comes back
    /// the colour of a sunset and just as dull as it was, because everything
    /// interesting about a sunset photograph is the *range* — the cloud edges
    /// lit against a deeper sky. Pivoting on the sky's own lightness rather than
    /// on mid grey is what keeps this from being a contrast slider: the sky
    /// itself does not move, the cloud above it comes up and the deep part
    /// overhead goes down.
    ///
    /// How much is decided by the sky in front of the lens, because one number
    /// cannot serve both cases. Measured on the two scenes that matter:
    ///
    /// A **clear** sky already has range — deep blue overhead, white cloud, a
    /// pale band at the roofline — and stretching it is the fast way to ruin it.
    /// At 1.45 the clouds start coring out into flat white with an orange rim
    /// around them; at 1.7 they have lost their edges entirely. It wants
    /// almost nothing.
    ///
    /// A **flat overcast** sky is the opposite and it is the case this was asked
    /// for: colour alone leaves it exactly as dull as it was, because what makes
    /// a sunset photograph is the range and there is none to move. At 1.18
    /// nothing visible happens at all. It wants roughly what the clear sky
    /// cannot take.
    ///
    /// So the amount rides on how much colour the sky itself has, which is the
    /// closest thing to "how flat is this photograph" that a colour table can
    /// know: an overcast sky has two or three units of chroma and a clear one
    /// has forty.
    static let contrastFlat = 1.45
    static let contrastClear = 1.18

    /// And a little more colour with it, on the same slide.
    static let chromaBoostFlat = 1.25
    static let chromaBoostClear = 1.12

    /// The chroma at which a sky counts as fully coloured for the two above.
    static let adaptiveChroma = 30.0

    /// How much more colour than the sky a pixel may carry and still be taken
    /// for sky, and how far past that it fades out.
    ///
    /// Lightness needed a direction and so does chroma, for the same reason and
    /// with the same asymmetry. *Less* colour than the sky is still sky — that is
    /// a cloud, the haze at the horizon, the washed-out band around the sun.
    /// Much *more* colour than the sky is something in front of it.
    ///
    /// On a clear day this changes almost nothing: the sky is the most saturated
    /// thing in the frame already. It matters on an overcast one, which is most
    /// days. A grey sky has no hue to key on, so a mask that only measures
    /// distance has nothing to separate it from every other neutral-ish thing at
    /// the same brightness — measured, a face came out 0.56 sky and the lit
    /// windows of a building came out with it. Judged on chroma instead they are
    /// plainly not sky: the sky has two units of colour in it and a face has
    /// twenty.
    static let chromaHeadroom = 8.0
    static let chromaFade = 14.0

    /// Below this much chroma a sky has no hue worth rotating, and no chroma
    /// worth taking a ratio through.
    ///
    /// Three was too low. An overcast sky measured 3.3, scraped past the floor
    /// into the scaling branch, and every ratio through it came out enormous —
    /// the pale band over the roofline borrowed a muted dusk and came back a
    /// vivid blue, four times the chroma it started with.
    static let chromaFloor = 8.0

    /// A grey sky borrowing a vivid one must not multiply what little chroma the
    /// frame has by twelve.
    static let chromaCeiling = 2.5

    /// And nothing in the mask ends up much more saturated than the sky it is
    /// borrowing. That is true of skies as well as convenient: the sky's own
    /// colour is about the most saturated thing a sky has in it.
    static let resultCeiling = 1.5

    /// How much of this colour is sky, `0` to `1`.
    static func weight(_ lab: Lab, from source: Lab) -> Double {
        let tolerance = lab.l >= source.l ? lightnessToleranceAbove : lightnessToleranceBelow
        let distance = deltaE2000(lab, source, kL: tolerance)
        let t = min(max((far - distance) / (far - near), 0), 1)
        // Smoothstep, so the mask has no visible shoulder where it starts and
        // stops. A linear ramp shows as a band across an even sky.
        let near = t * t * (3 - 2 * t)

        let excess = (lab.a * lab.a + lab.b * lab.b).squareRoot()
            - (source.a * source.a + source.b * source.b).squareRoot()
        guard excess > chromaHeadroom else { return near }
        let e = min(max((chromaHeadroom + chromaFade - excess) / chromaFade, 0), 1)
        return near * e * e * (3 - 2 * e)
    }

    /// This colour, as it would have been under that sky.
    ///
    /// The move itself is made in polar Lab — rotate the hue, scale the chroma,
    /// carry part of the lightness — and not by adding the vector between the
    /// two sky colours to everything in the mask. Adding it is the obvious thing
    /// and it is wrong in a way that only shows up on real photographs: a
    /// translation preserves signed differences, so a pixel that was *less blue*
    /// than the sky's own colour becomes *more orange* than the sunset it was
    /// moved to. The pale band over the roofline, the least coloured part of the
    /// sky, came out the most saturated thing in the frame, and an overcast grey
    /// turned the clouds yellow.
    ///
    /// Scaling fixes exactly that. Less chroma than the sky stays less chroma
    /// than the sky, whatever hue the sky is now, so the gradient the photograph
    /// had survives the move instead of being turned inside out. Neutrals — a
    /// white cloud, a grey road caught in the mask — have nothing to scale and
    /// stay neutral, which is also why nothing here needs to know where in the
    /// frame it is.
    ///
    /// Where a colour is only *partly* sky, what gets mixed is the **result**,
    /// not the amount of rotation. Turning a hue partway is the intuitive
    /// reading of a half-strength filter and it puts the half-lit pixels
    /// somewhere neither sky has ever been: going from blue to a sunset, two
    /// thirds of the way round the wheel is magenta, and the zenith of a clear
    /// sky — the one place the mask is not quite full, because it is furthest
    /// from the sky's average colour — came back as a band of red across the top
    /// of the frame. A straight line in Lab between the two answers passes
    /// through grey instead, so a mask edge fades rather than changing colour.
    static func moved(_ lab: Lab, from source: Lab, to target: Lab, by amount: Double) -> Lab {
        guard amount > 0 else { return lab }
        return fitted(lab.blended(toward: transferred(lab, from: source, to: target), by: amount))
    }

    /// The whole move, as if this colour were entirely sky.
    private static func transferred(_ lab: Lab, from source: Lab, to target: Lab) -> Lab {
        let sourceChroma = (source.a * source.a + source.b * source.b).squareRoot()
        let targetChroma = (target.a * target.a + target.b * target.b).squareRoot()

        // Flat skies get the stretch, coloured ones get left alone.
        let flatness = 1 - min(sourceChroma / adaptiveChroma, 1)
        let contrast = contrastClear + (contrastFlat - contrastClear) * flatness
        let chromaBoost = chromaBoostClear + (chromaBoostFlat - chromaBoostClear) * flatness

        // Where the sky itself ends up. Everything in the mask is stretched away
        // from this point, so the sky stays put and what sits above and below it
        // in the frame — cloud, haze, the deeper blue overhead — separates.
        let centre = source.l + (target.l - source.l) * lightnessTransfer
        let moved = lab.l + (target.l - source.l) * lightnessTransfer
        let lightness = min(max(centre + (moved - centre) * contrast, 0), 100)

        // A sky with no colour in it has no hue to rotate away from, and every
        // ratio through it is a division by nothing. An overcast day moves the
        // plain way.
        // A sky with no colour in it has no hue to rotate away from, and every
        // ratio through it is a division by nothing. So an overcast sky simply
        // takes the borrowed colour: by definition the frame's own chroma is
        // under three units here, so there is nothing in it worth keeping.
        //
        // Adding the difference between the two sky colours is the obvious move
        // and it overshoots — the pixel's own tint stacks on the target's, and
        // measured, the pale band over the roofline came back at twice the
        // saturation of the dusk it was borrowing.
        guard sourceChroma >= chromaFloor else {
            return Lab(l: lightness, a: target.a * chromaBoost, b: target.b * chromaBoost)
        }

        var turn = atan2(target.b, target.a) - atan2(source.b, source.a)
        // The short way round. Without this a rotation of ten degrees can be
        // taken as three hundred and fifty.
        if turn > .pi { turn -= 2 * .pi } else if turn < -.pi { turn += 2 * .pi }

        let hue = atan2(lab.b, lab.a) + turn
        let chroma = min(
            (lab.a * lab.a + lab.b * lab.b).squareRoot()
                * min(targetChroma / sourceChroma, chromaCeiling) * chromaBoost,
            targetChroma * resultCeiling
        )

        return Lab(l: lightness, a: chroma * cos(hue), b: chroma * sin(hue))
    }

    /// The nearest colour sRGB can actually hold, reached by taking chroma off
    /// rather than by letting the conversion clamp each channel.
    ///
    /// Clamping is what happens by default and it moves the hue: the zenith of a
    /// clear sky is the most saturated thing in the frame, and rotated into a
    /// sunset it lands outside the gamut, where clamping red at the ceiling
    /// while green and blue keep falling turns orange into crimson. On a real
    /// photograph that showed as a band of red across the top of the sky with a
    /// visible edge — the picture said sunset everywhere except the one place
    /// you look first.
    ///
    /// Dropping chroma instead keeps the hue and the lightness and gives up only
    /// the saturation the display could not have shown anyway, which is the
    /// standard thing to give up and the only one nobody sees as an artefact.
    static func fitted(_ lab: Lab) -> Lab {
        guard escapes(lab) else { return lab }

        var inside = 0.0
        var outside = 1.0
        for _ in 0..<12 {
            let middle = (inside + outside) / 2
            if escapes(Lab(l: lab.l, a: lab.a * middle, b: lab.b * middle)) {
                outside = middle
            } else {
                inside = middle
            }
        }
        return Lab(l: lab.l, a: lab.a * inside, b: lab.b * inside)
    }

    /// Whether sRGB can hold this colour, asked by round trip. `RGB(r:g:b:)` is
    /// the only place that knows the shape of the gamut, so the question is put
    /// to it rather than answered again here.
    private static func escapes(_ lab: Lab) -> Bool {
        let back = Lab(RGB(lab))
        return abs(back.l - lab.l) > 0.4
            || abs(back.a - lab.a) > 0.4
            || abs(back.b - lab.b) > 0.4
    }

    /// The transform as a lookup table Core Image can apply in one pass.
    ///
    /// Laid out blue-slowest to red-fastest, RGBA floats, which is the order
    /// `CIColorCubeWithColorSpace` reads. Alpha is 1 throughout, so the
    /// premultiplication the filter expects is already done.
    static func cube(from source: Lab, to target: Lab, strength: Double = 1) -> Data {
        let side = cubeSide
        let step = 1.0 / Double(side - 1)
        var values = [Float](repeating: 1, count: side * side * side * 4)
        var index = 0

        for blue in 0..<side {
            for green in 0..<side {
                for red in 0..<side {
                    let rgb = RGB(
                        r: Double(red) * step,
                        g: Double(green) * step,
                        b: Double(blue) * step
                    )
                    let lab = Lab(rgb)
                    let amount = weight(lab, from: source) * strength
                    let out = RGB(moved(lab, from: source, to: target, by: amount))

                    values[index] = Float(out.r)
                    values[index + 1] = Float(out.g)
                    values[index + 2] = Float(out.b)
                    // values[index + 3] is already 1.
                    index += 4
                }
            }
        }

        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

#if canImport(UIKit)
extension SkyRecolor {

    /// One context for the whole app. Creating a `CIContext` compiles and caches
    /// a pipeline, which is far more than the render itself costs.
    private static let context = CIContext(options: [.name: "skydex.recolor"])

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)

    /// The photograph, with the sky in it moved onto `target`.
    ///
    /// Not cheap enough for the main thread: building the table walks thirty-five
    /// thousand colours through CIEDE2000. Call it from a background task.
    static func apply(
        to image: UIImage,
        from source: Lab,
        to target: Lab,
        strength: Double = 1
    ) -> UIImage? {
        guard let cgImage = image.cgImage, let sRGB else { return nil }

        let input = CIImage(cgImage: cgImage)
        let filter = CIFilter.colorCubeWithColorSpace()
        filter.inputImage = input
        filter.cubeDimension = Float(cubeSide)
        filter.cubeData = cube(from: source, to: target, strength: strength)
        // The table was built in sRGB, so the filter is told to convert into
        // sRGB before looking anything up. Without this the lookup happens in
        // Core Image's linear working space and every colour lands in the wrong
        // cell — the sky comes back washed out rather than moved.
        filter.colorSpace = sRGB

        guard let output = filter.outputImage,
              let rendered = context.createCGImage(
                output,
                from: input.extent,
                format: .RGBA8,
                colorSpace: sRGB
              )
        else { return nil }

        return UIImage(cgImage: rendered, scale: 1, orientation: .up)
    }
}
#endif
