// 판의 마흔여덟 색(`SkySpectrum`)이 실제로 서로 다른지, 그리고 곡선에서 얼마나 벗어났는지.
//
//   swiftc -O -o /tmp/spectrumcheck Tools/SpectrumCheck.swift \
//       SkyDex/ColorScience/{RGB,Lab,DeltaE,SkySimile,SkySpectrum,Sun}.swift \
//       SkyDex/Models/{SkySlot,SkyBoard,SkyDay}.swift \
//   && /tmp/spectrumcheck
//
// 판은 이제 하루 곡선을 그대로 그리지 않고, 곡선에 가장 가까운 수집 가능한 색을 놓습니다.
// 그 대가가 얼마인지는 숫자로 보아야 합니다 — 칸 하나가 "이 시각의 하늘"에서 얼마나
// 떨어진 색을 들고 있는가. 표(`SkySimile`)를 고치면 다시 돌릴 것.

import Foundation

@main
struct SpectrumCheck {

    /// `SkyMatch.radius`의 두 배. 모델이 SwiftData를 끌고 오므로 여기서는 숫자로 적습니다.
    static let needed = 7.0

    static func main() {
        let spectrum = SkySpectrum.colours
        print("스펙트럼 \(spectrum.count)색 (표 \(SkySimiles.all.count)색에서 고름)")

        var worst = 999.0, worstPair = ("", "")
        for i in 0..<spectrum.count {
            for j in (i + 1)..<spectrum.count {
                let d = deltaE2000(Lab(spectrum[i].rgb), Lab(spectrum[j].rgb))
                if d < worst { worst = d; worstPair = (spectrum[i].name, spectrum[j].name) }
            }
        }
        print(String(format: "서로 가장 가까운 짝  %@ / %@  ΔE %.1f  %@",
                     worstPair.0, worstPair.1, worst,
                     worst >= needed ? "← 통과 (필요 \(Int(needed)))" : "← 실패"))

        // 판이 실제로 쓰는 것 — 고정된 순서.
        let ordered = SkySpectrum.ordered
        print("\n=== 판에 놓인 순서 ===")
        for (slot, colour) in ordered.enumerated() {
            let minute = slot * 30
            print(String(format: "  %02d:%02d  %@  L%3.0f  %@",
                         minute / 60, minute % 60, colour.hex as NSString,
                         Lab(colour.rgb).l, colour.name as NSString))
        }

        // 이웃끼리 얼마나 튀는지 — 판이 그림으로 읽히려면 급격한 도약이 적어야 합니다.
        var jumps: [Double] = []
        for i in 1..<ordered.count {
            jumps.append(deltaE2000(Lab(ordered[i - 1].rgb), Lab(ordered[i].rgb)))
        }
        let sortedJumps = jumps.sorted()
        print(String(format: "\n이웃 칸 사이  최소 %.1f  중앙 %.1f  최대 %.1f",
                     sortedJumps.first!, sortedJumps[sortedJumps.count / 2], sortedJumps.last!))

        // 판에 놓인 색과 그 시각 곡선 사이의 거리. 빈 칸 시트가 둘을 나란히 보여주므로
        // 알아 둘 값입니다.
        let day = SkyDay(date: Date(timeIntervalSince1970: 1_755_000_000),
                         latitude: 37.5, longitude: 127.0)
        let drifts = SkyBoard.slots.enumerated().map { index, slot in
            deltaE2000(Lab(day.clearSkyColour(of: slot)), Lab(ordered[index].rgb))
        }.sorted()
        print(String(format: "\n곡선과의 거리  중앙 %.1f  최대 %.1f",
                     drifts[drifts.count / 2], drifts.last!))
    }

}
