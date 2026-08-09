import CoreGraphics
import Foundation

/// Where a colour sits on the dial.
///
/// Two axes, both physical. The angle is where the sun stood — sunrise on the
/// left, noon at the top, sunset on the right, with twilight hanging just below
/// the horizon at each end. The radius is how bright the sky was. Nothing is
/// assigned a slot, so a dot never moves once placed and a colour found between
/// two others lands between them.
enum DialGeometry {

    /// Fixed angular allowance for each twilight, beyond the 180° of daylight.
    ///
    /// Not a fudge: nautical twilight runs 7.6% of the day at the equinoxes and
    /// 10.4% at the winter solstice, so a strictly proportional share would be
    /// 14° to 19°. Eighteen sits inside that range all year.
    static let twilightSpan = 18.0

    /// The whole shootable arc, from first light to last.
    static var arcStart: Double { 180 - twilightSpan }
    static var arcEnd: Double { 360 + twilightSpan }

    /// Trimmed to what a sky between first and last light actually does. The
    /// reference palette runs L 3.9 to 86.2; the headroom catches captures that
    /// fall outside it.
    static let minLightness = 10.0
    static let maxLightness = 96.0

    static let innerFraction: CGFloat = 0.20
    static let outerFraction: CGFloat = 1.0

    static func radius(for lab: Lab, unit: CGFloat) -> CGFloat {
        let clamped = min(max(lab.l, minLightness), maxLightness)
        let t = CGFloat((clamped - minLightness) / (maxLightness - minLightness))
        return unit * (innerFraction + (outerFraction - innerFraction) * t)
    }

    static func point(angle: Double, lab: Lab, center: CGPoint, unit: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        let r = radius(for: lab, unit: unit)
        return CGPoint(x: center.x + cos(radians) * r, y: center.y + sin(radians) * r)
    }

    static func point(on circle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let radians = circle * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius, y: center.y + sin(radians) * radius)
    }
}
