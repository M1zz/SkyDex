// 비유 이름 표(`SkySimile`)가 실제 하늘을 덮는지 확인합니다.
//
//   swiftc -O -o /tmp/similecheck Tools/SimileCheck.swift \
//       SkyDex/ColorScience/RGB.swift SkyDex/ColorScience/Lab.swift \
//       SkyDex/ColorScience/DeltaE.swift SkyDex/ColorScience/SkySimile.swift \
//   && /tmp/similecheck
//
// 앱의 하늘 곡선 앵커 22색을 맑음 · 흐림 · 비 세 상태로 돌려, 각각에 붙는 비유와
// CIEDE2000 거리를 찍습니다. 뷰가 없으므로 표를 고칠 때마다 다시 돌릴 수 있습니다.
// 중복 hex와 중복 이름도 함께 봅니다.
//
// 2026-08-18 기준: 표본 66개 전부 ΔE 6 이내, 최악 4.7, 이름 95개.

import Foundation

@main
struct SimileCheck {

    /// `SkyDay.fixedCurve` 그대로 — 앵커를 고치면 여기도 같이 고칠 것.
    static let anchors: [(String, String)] = [
        ("00:00 한밤", "#080D18"), ("03:20", "#0B1120"), ("04:50", "#141D33"), ("05:30 여명", "#2B3856"),
        ("06:05", "#4E5F8C"), ("06:35", "#7E90B6"), ("07:00", "#A2AFCA"), ("07:50", "#7FA4CE"),
        ("09:00", "#5590C6"), ("11:00", "#2F7BBE"), ("12:30 정오", "#1C6DB4"), ("14:30", "#2A76B8"),
        ("16:00", "#4C8AC4"), ("17:00", "#7FA6CD"), ("17:55 노을", "#C1A07E"), ("18:30", "#D68F55"),
        ("19:00", "#B85A34"), ("19:30", "#8E4340"), ("20:00", "#5E3A54"), ("20:40", "#33304C"),
        ("21:40", "#161C31"), ("23:00", "#0A101E")
    ]

    /// `SkyDay.clouded` 그대로.
    static func clouded(_ clear: Lab, cloud: Double, rain: Double) -> Lab {
        let daylight = min(max(clear.l / 60, 0), 1)
        var l = clear.l + (74 - clear.l) * 0.5 * cloud * daylight
        l -= 16 * rain * daylight
        let chroma = (1 - 0.85 * cloud) * (1 - 0.4 * rain)
        return Lab(l: l, a: clear.a * chroma, b: clear.b * chroma)
    }

    static var worst = 0.0
    static var over = 0
    static var rows = 0

    static func check(_ label: String, _ lab: Lab) {
        let match = SkySimiles.nearest(to: lab)
        rows += 1
        worst = max(worst, match.distance)
        if match.distance > 6 { over += 1 }
        print(String(
            format: "%-16@ %@  ΔE %5.1f  %@%@",
            label as NSString, RGB(lab).hex as NSString, match.distance,
            match.simile.name as NSString,
            (match.distance > 6 ? "  <-- 멀다" : "") as NSString
        ))
    }

    static func main() {
        print("=== 맑은 하늘 ===")
        for (label, hex) in anchors { check(label, Lab(RGB(hex: hex)!)) }

        print("\n=== 흐림 (cloud 0.8) ===")
        for (label, hex) in anchors { check(label, clouded(Lab(RGB(hex: hex)!), cloud: 0.8, rain: 0)) }

        print("\n=== 비 (cloud 1.0, rain 0.8) ===")
        for (label, hex) in anchors { check(label, clouded(Lab(RGB(hex: hex)!), cloud: 1, rain: 0.8)) }

        print("\n표본 \(rows)개 중 ΔE 6 초과 \(over)개, 최악 \(String(format: "%.1f", worst))")

        var seenHex: [String: String] = [:]
        var seenName = Set<String>()
        for simile in SkySimiles.all {
            if let other = seenHex[simile.hex] { print("중복 hex: \(simile.name) / \(other)") }
            seenHex[simile.hex] = simile.name
            if !seenName.insert(simile.name).inserted { print("중복 이름: \(simile.name)") }
        }
        print("이름 \(SkySimiles.all.count)개")
    }
}
