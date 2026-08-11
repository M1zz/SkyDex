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
