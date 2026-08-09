import SwiftUI

/// The lit arc: daylight plus the twilight that hangs below the horizon at
/// each end.
///
/// A hairline alone was not enough to separate above from below. Filling the
/// arc the way a sun-path chart shades the sky lets the shape read as sky
/// rather than as a chart.
struct ArcDisc: Shape {
    let center: CGPoint
    let radius: CGFloat
    var start: Double = DialGeometry.arcStart
    var end: Double = DialGeometry.arcEnd
    /// Close back through the centre, so the fill is a wedge rather than a band.
    var closed: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 96
        for step in 0...steps {
            let degrees = start + (end - start) * Double(step) / Double(steps)
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if closed {
            path.addLine(to: center)
            path.closeSubpath()
        }
        return path
    }
}

/// Tick marks for whole clock hours, placed wherever the sun actually stands at
/// that hour today.
///
/// The solar labels stay put — noon is always the top — while these drift with
/// the season, which is the point. In June the arc carries ticks from 05 to 20;
/// by December it holds only 07 to 18, and the shorter day is visible in how
/// few marks fit.
struct ClockTicks: Shape {
    let center: CGPoint
    let unit: CGFloat
    let clock: SolarClock
    let date: Date
    /// Hours between marks. Every hour crowded the rim; every second hour still
    /// shows the day growing and shrinking without reading as hatching.
    var step: Int = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: date)

        for hour in stride(from: 0, to: 24, by: max(1, step)) {
            guard let moment = calendar.date(byAdding: .hour, value: hour, to: midnight),
                  let angle = clock.position(of: moment).dialAngle else { continue }
            let radians = angle * .pi / 180
            let cosine = CGFloat(cos(radians))
            let sine = CGFloat(sin(radians))
            let inner = unit + 4
            let outer = unit + 11
            path.move(to: CGPoint(
                x: center.x + cosine * inner, y: center.y + sine * inner
            ))
            path.addLine(to: CGPoint(
                x: center.x + cosine * outer, y: center.y + sine * outer
            ))
        }
        return path
    }
}
