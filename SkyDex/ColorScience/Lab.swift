import Foundation

/// CIELAB (D65) coordinates.
///
/// Matching happens here rather than in RGB because human vision is far less
/// sensitive to hue differences in the blue region than RGB distance implies.
/// Two obviously different blues sit close together in RGB space; in Lab they
/// separate correctly.
struct Lab: Equatable, Hashable {
    var l: Double
    var a: Double
    var b: Double

    init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    init(_ rgb: RGB) {
        func linearize(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let r = linearize(rgb.r)
        let g = linearize(rgb.g)
        let b = linearize(rgb.b)

        let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

        let xn = 0.95047, yn = 1.00000, zn = 1.08883

        func f(_ t: Double) -> Double {
            t > 0.008856 ? cbrt(t) : (7.787 * t + 16.0 / 116.0)
        }

        let fx = f(x / xn)
        let fy = f(y / yn)
        let fz = f(z / zn)

        self.l = 116 * fy - 16
        self.a = 500 * (fx - fy)
        self.b = 200 * (fy - fz)
    }
}

extension RGB {

    /// The inverse of `Lab(_:)`, so a colour can be interpolated in Lab and
    /// brought back out. The board's whole palette is built this way: mixing
    /// two sky colours in RGB drags the midpoint through a muddy grey, and the
    /// dawn steps are where that shows worst.
    ///
    /// Out-of-gamut results are clamped by `init(r:g:b:)`. Every colour on the
    /// day curve is a real sky, so nothing lands far outside sRGB.
    init(_ lab: Lab) {
        let fy = (lab.l + 16) / 116
        let fx = fy + lab.a / 500
        let fz = fy - lab.b / 200

        func inverse(_ t: Double) -> Double {
            let cubed = t * t * t
            return cubed > 0.008856 ? cubed : (t - 16.0 / 116.0) / 7.787
        }

        let x = inverse(fx) * 0.95047
        let y = inverse(fy) * 1.00000
        let z = inverse(fz) * 1.08883

        let r = x *  3.2404542 + y * -1.5371385 + z * -0.4985314
        let g = x * -0.9692660 + y *  1.8760108 + z *  0.0415560
        let b = x *  0.0556434 + y * -0.2040259 + z *  1.0572252

        func gamma(_ c: Double) -> Double {
            c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
        }

        self.init(r: gamma(r), g: gamma(g), b: gamma(b))
    }
}
