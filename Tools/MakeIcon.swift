// Renders the app icon: one donut, one day.
//
// The day curve closes on itself at midnight, so it wants to be a circle. The
// board's bead shape is a ring. Put those together and the icon is the app's own
// structure rather than a picture of a sky: midnight at the top, clockwise
// through dawn on the right, noon at the bottom, sunset on the left.
//
// The colours come off the same anchors and the same CIELAB interpolation the
// board uses, so the icon is sampling the app's day and not an approximation
// of it.
//
//   swift MakeIcon.swift <out-dir>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Colour

struct Lab { var l, a, b: Double }

func linearize(_ c: Double) -> Double {
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
}

func gamma(_ c: Double) -> Double {
    let c = min(max(c, 0), 1)
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
}

func lab(fromHex hex: String) -> Lab {
    var value: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
    let r = linearize(Double((value >> 16) & 0xFF) / 255)
    let g = linearize(Double((value >> 8) & 0xFF) / 255)
    let b = linearize(Double(value & 0xFF) / 255)

    let x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
    let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    let z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883
    func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116.0 }
    return Lab(l: 116 * f(y) - 16, a: 500 * (f(x) - f(y)), b: 200 * (f(y) - f(z)))
}

func rgb(_ lab: Lab) -> (Double, Double, Double) {
    let fy = (lab.l + 16) / 116
    let fx = fy + lab.a / 500
    let fz = fy - lab.b / 200
    func inverse(_ t: Double) -> Double {
        let cubed = t * t * t
        return cubed > 0.008856 ? cubed : (t - 16.0 / 116.0) / 7.787
    }
    let x = inverse(fx) * 0.95047, y = inverse(fy), z = inverse(fz) * 1.08883
    return (
        gamma(x * 3.2404542 + y * -1.5371385 + z * -0.4985314),
        gamma(x * -0.9692660 + y * 1.8760108 + z * 0.0415560),
        gamma(x * 0.0556434 + y * -0.2040259 + z * 1.0572252)
    )
}

/// The board's anchors, unchanged.
let anchors: [(minute: Int, hex: String)] = [
    (0, "#080D18"), (200, "#0B1120"), (290, "#141D33"), (330, "#2B3856"),
    (365, "#4E5F8C"), (395, "#7E90B6"), (420, "#A2AFCA"), (470, "#7FA4CE"),
    (540, "#5590C6"), (660, "#2F7BBE"), (750, "#1C6DB4"), (870, "#2A76B8"),
    (960, "#4C8AC4"), (1020, "#7FA6CD"), (1075, "#C1A07E"), (1110, "#D68F55"),
    (1140, "#B85A34"), (1170, "#8E4340"), (1200, "#5E3A54"), (1240, "#33304C"),
    (1300, "#161C31"), (1380, "#0A101E"), (1440, "#080D18")
]

let curve = anchors.map { (minute: $0.minute, lab: lab(fromHex: $0.hex)) }

func dayLab(atMinute minute: Double) -> Lab {
    let m = minute.truncatingRemainder(dividingBy: 1440)
    for index in 0..<(curve.count - 1) {
        let (m0, l0) = curve[index]
        let (m1, l1) = curve[index + 1]
        guard m >= Double(m0), m <= Double(m1) else { continue }
        let raw = m1 == m0 ? 0 : (m - Double(m0)) / Double(m1 - m0)
        let t = raw * raw * (3 - 2 * raw)
        return Lab(
            l: l0.l + (l1.l - l0.l) * t,
            a: l0.a + (l1.a - l0.a) * t,
            b: l0.b + (l1.b - l0.b) * t
        )
    }
    return curve[curve.count - 1].lab
}

// MARK: - The board's forty-eight

/// The bands, unchanged. The board does not divide the day evenly — sunset gets
/// twelve beads for three hours and midday twelve for eight — so the ring is
/// walked by slot, not by clock. Going round by minutes instead would shrink the
/// warm quarter of the board to a sliver and stop being a picture of the board.
let bands: [(start: Int, end: Int, slots: Int)] = [
    (0, 300, 6), (300, 480, 6), (480, 960, 12),
    (960, 1080, 6), (1080, 1260, 12), (1260, 1440, 6)
]

let slotLabs: [Lab] = bands.flatMap { band in
    (0..<band.slots).map { index in
        let width = Double(band.end - band.start) / Double(band.slots)
        return dayLab(atMinute: Double(band.start) + width * (Double(index) + 0.5))
    }
}

/// Position round the ring, 0 at midnight, to a colour — smooth between slot
/// centres so the result is a gradient rather than forty-eight bands.
func ringLab(at fraction: Double) -> Lab {
    let count = Double(slotLabs.count)
    let p = fraction * count - 0.5
    let index = Int(floor(p) + count) % slotLabs.count
    let next = (index + 1) % slotLabs.count
    let t = p - floor(p)
    let (a, b) = (slotLabs[index], slotLabs[next])
    return Lab(l: a.l + (b.l - a.l) * t, a: a.a + (b.a - a.a) * t, b: a.b + (b.b - a.b) * t)
}

// MARK: - Drawing

let side = 1024.0

/// - Parameters:
///   - ground: the two ends of the background's vertical ramp.
///   - lift: pushed into the ring's lightness. Zero on light paper, where a
///     midnight sky is the strongest mark on the icon. On a night ground the
///     same colour is invisible, so the sweep is lifted toward the middle of
///     the range to keep the ring whole.
func icon(ground: (String, String), lift: Double) -> CGImage {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil, width: Int(side), height: Int(side),
        bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // Background. A flat field would be fine; the slight ramp gives the ring
    // something to sit in and answers the ask for a gradient twice.
    let top = rgb(lab(fromHex: ground.0)), bottom = rgb(lab(fromHex: ground.1))
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: top.0, green: top.1, blue: top.2, alpha: 1),
            CGColor(red: bottom.0, green: bottom.1, blue: bottom.2, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: side),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // The ring, as one arc per segment. There is no conic gradient in
    // CoreGraphics, and a few hundred slightly overlapping arcs is
    // indistinguishable from one at this size.
    let centre = CGPoint(x: side / 2, y: side / 2)
    let radius = side * 0.313
    let width = side * 0.125
    let segments = 900
    context.setLineWidth(width)
    context.setLineCap(.butt)

    for index in 0..<segments {
        let from = Double(index) / Double(segments)
        let to = Double(index + 1) / Double(segments)
        // Midnight at the top, running clockwise, so the icon reads as a
        // twenty-four hour clock of sky.
        let start = .pi / 2 - from * 2 * .pi
        let end = .pi / 2 - (to * 2 * .pi + 0.004)

        var colour = ringLab(at: (from + to) / 2)
        // Lifting lightness alone turns midnight grey — it had little chroma to
        // begin with. Scale the chroma by the same lift and the night arc stays
        // a night sky.
        colour.l += (58 - colour.l) * lift
        colour.a *= 1 + lift
        colour.b *= 1 + lift
        let (r, g, b) = rgb(colour)
        context.setStrokeColor(CGColor(red: r, green: g, blue: b, alpha: 1))

        context.beginPath()
        context.addArc(
            center: centre, radius: radius,
            startAngle: start, endAngle: end, clockwise: true
        )
        context.strokePath()
    }

    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    print("wrote \(url.lastPathComponent)")
}

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
write(icon(ground: ("#F7F8FA", "#E7EBF2"), lift: 0), to: out.appending(path: "AppIcon.png"))
write(icon(ground: ("#182236", "#080C15"), lift: 0.34), to: out.appending(path: "AppIcon-Dark.png"))
