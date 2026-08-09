import Foundation

/// CIEDE2000 colour difference.
///
/// Roughly: below 2 is imperceptible, below 10 reads as "the same kind of
/// colour", above 30 is plainly a different colour. The collect thresholds in
/// `Palette` are tuned against this scale.
func deltaE2000(_ x: Lab, _ y: Lab, kL: Double = 1, kC: Double = 1, kH: Double = 1) -> Double {
    let deg = Double.pi / 180

    let c1 = sqrt(x.a * x.a + x.b * x.b)
    let c2 = sqrt(y.a * y.a + y.b * y.b)
    let cBar = (c1 + c2) / 2

    let cBar7 = pow(cBar, 7)
    let g = 0.5 * (1 - sqrt(cBar7 / (cBar7 + pow(25, 7))))

    let a1p = (1 + g) * x.a
    let a2p = (1 + g) * y.a

    let c1p = sqrt(a1p * a1p + x.b * x.b)
    let c2p = sqrt(a2p * a2p + y.b * y.b)

    func hue(_ a: Double, _ b: Double) -> Double {
        if a == 0 && b == 0 { return 0 }
        var h = atan2(b, a) / deg
        if h < 0 { h += 360 }
        return h
    }

    let h1p = hue(a1p, x.b)
    let h2p = hue(a2p, y.b)

    let dLp = y.l - x.l
    let dCp = c2p - c1p

    var dhp = 0.0
    if c1p * c2p != 0 {
        var d = h2p - h1p
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        dhp = d
    }
    let dHp = 2 * sqrt(c1p * c2p) * sin(dhp / 2 * deg)

    let lBarP = (x.l + y.l) / 2
    let cBarP = (c1p + c2p) / 2

    var hBarP = 0.0
    if c1p * c2p == 0 {
        hBarP = h1p + h2p
    } else if abs(h1p - h2p) <= 180 {
        hBarP = (h1p + h2p) / 2
    } else if h1p + h2p < 360 {
        hBarP = (h1p + h2p + 360) / 2
    } else {
        hBarP = (h1p + h2p - 360) / 2
    }

    let t = 1
        - 0.17 * cos((hBarP - 30) * deg)
        + 0.24 * cos(2 * hBarP * deg)
        + 0.32 * cos((3 * hBarP + 6) * deg)
        - 0.20 * cos((4 * hBarP - 63) * deg)

    let dTheta = 30 * exp(-pow((hBarP - 275) / 25, 2))
    let cBarP7 = pow(cBarP, 7)
    let rC = 2 * sqrt(cBarP7 / (cBarP7 + pow(25, 7)))

    let sL = 1 + (0.015 * pow(lBarP - 50, 2)) / sqrt(20 + pow(lBarP - 50, 2))
    let sC = 1 + 0.045 * cBarP
    let sH = 1 + 0.015 * cBarP * t
    let rT = -sin(2 * dTheta * deg) * rC

    let termL = dLp / (kL * sL)
    let termC = dCp / (kC * sC)
    let termH = dHp / (kH * sH)

    return sqrt(termL * termL + termC * termC + termH * termH + rT * termC * termH)
}
