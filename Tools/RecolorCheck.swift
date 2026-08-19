// 하늘색 필터(`SkyRecolor`)가 무엇을 옮기고 무엇을 그대로 두는지 확인합니다.
//
//   swiftc -O -o /tmp/recolorcheck Tools/RecolorCheck.swift \
//       SkyDex/ColorScience/RGB.swift SkyDex/ColorScience/Lab.swift \
//       SkyDex/ColorScience/DeltaE.swift SkyDex/ColorScience/SkyRecolor.swift \
//   && /tmp/recolorcheck
//
// 화면 없이 볼 수 있는 세 가지를 봅니다.
//   1. 마스크 — 하늘이 아닌 것(나뭇잎 · 벽돌 · 피부 · 아스팔트)이 얼마나 남는가.
//   2. 이동   — 하늘색이 실제로 목표 색 근처까지 가는가.
//   3. 비용   — 표 한 장 굽는 데 얼마나 걸리고, sRGB 밖으로 얼마나 튀는가.
//
// falloff 상수(near · far · lightnessTolerance · lightnessTransfer)를 만질 때마다
// 다시 돌릴 것. 시뮬레이터를 켜는 것보다 빠르고, 눈보다 정확합니다.

import Foundation

@main
struct RecolorCheck {

    /// 프레임 안에 실제로 같이 들어오는 것들.
    static let scene: [(String, String)] = [
        ("정오 하늘",      "#1C6DB4"),
        ("하늘 밝은 쪽",   "#5590C6"),
        ("지평선 근처",    "#A2AFCA"),
        ("흰 구름",        "#EDEFF2"),
        ("먹구름",         "#8A8F98"),
        ("나뭇잎",         "#3E6B34"),
        ("벽돌 건물",      "#9C5A45"),
        ("피부",           "#D8A98C"),
        ("아스팔트",       "#4A4A4C"),
        ("청바지 옷",      "#3B5A82"),
        ("흰 벽",          "#F2F0EA")
    ]

    /// 빌려 올 하늘 — 판의 하루 곡선 앵커에서.
    static let targets: [(String, String)] = [
        ("노을",   "#D68F55"),
        ("여명",   "#2B3856"),
        ("한밤",   "#080D18"),
        ("흐림",   "#A8ADB2")
    ]

    static func lab(_ hex: String) -> Lab { Lab(RGB(hex: hex)!) }

    static func main() {
        run(from: "정오 하늘", hex: scene[0].1)
        print("\n\n############ 흐린 하늘이 기준일 때 ############")
        run(from: "흐린 하늘", hex: "#AFB3B9")
    }

    static func run(from label: String, hex sourceHex: String) {
        let source = lab(sourceHex)

        print("=== 마스크 — \(label)(\(sourceHex))을 기준으로 ===")
        print("무엇                 hex        ΔE(kL=3)   하늘로 치는 정도")
        for (label, hex) in scene {
            let c = lab(hex)
            let d = deltaE2000(c, source, kL: (c.l >= source.l ? SkyRecolor.lightnessToleranceAbove : SkyRecolor.lightnessToleranceBelow))
            let w = SkyRecolor.weight(c, from: source)
            let bar = String(repeating: "█", count: Int((w * 20).rounded()))
            print(String(format: "%-18@ %@   %6.1f     %5.2f %@",
                         label as NSString, hex as NSString, d, w, bar as NSString))
        }

        print("\n=== 이동 — 그 하늘을 빌려 오면 각각 무슨 색이 되는가 ===")
        for (targetLabel, targetHex) in targets {
            let target = lab(targetHex)
            print("\n· \(targetLabel) \(targetHex) 로")
            for (label, hex) in scene {
                let c = lab(hex)
                let w = SkyRecolor.weight(c, from: source)
                let out = RGB(SkyRecolor.moved(c, from: source, to: target, by: w))
                let shift = deltaE2000(Lab(out), c)
                print(String(format: "   %-18@ %@ → %@   움직인 거리 %5.1f%@",
                             label as NSString, hex as NSString, out.hex as NSString, shift,
                             (w < 0.02 && shift > 1 ? "  <-- 안 움직여야 하는데" : "") as NSString))
            }
        }

        guard label == "정오 하늘" else { return }

        print("\n=== 표 굽기 ===")
        let started = Date()
        let data = SkyRecolor.cube(from: source, to: lab(targets[0].1), strength: 1)
        let elapsed = Date().timeIntervalSince(started)
        let cells = SkyRecolor.cubeSide * SkyRecolor.cubeSide * SkyRecolor.cubeSide
        print(String(format: "%d³ = %d칸, %d바이트, %.0fms (릴리스 빌드 기준)",
                     SkyRecolor.cubeSide, cells, data.count, elapsed * 1000))

        // 세기 0이면 표는 항등이어야 합니다. 아니면 마스크가 아니라 파이프라인이 색을
        // 건드리고 있다는 뜻입니다.
        let identity = SkyRecolor.cube(from: source, to: lab(targets[0].1), strength: 0)
        var worstIdentity = 0.0
        identity.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let floats = raw.bindMemory(to: Float.self)
            let side = SkyRecolor.cubeSide
            let step = 1.0 / Double(side - 1)
            var i = 0
            for b in 0..<side { for g in 0..<side { for r in 0..<side {
                worstIdentity = max(worstIdentity, abs(Double(floats[i]) - Double(r) * step))
                worstIdentity = max(worstIdentity, abs(Double(floats[i + 1]) - Double(g) * step))
                worstIdentity = max(worstIdentity, abs(Double(floats[i + 2]) - Double(b) * step))
                i += 4
            }}}
        }
        print(String(format: "세기 0에서 항등인가 — 최대 어긋남 %.5f", worstIdentity))

        // sRGB 밖으로 나간 색은 클램프되면서 의도한 색과 달라집니다. 얼마나 되는지.
        var clipped = 0, worstClip = 0.0
        let target = lab(targets[0].1)
        let side = SkyRecolor.cubeSide
        let step = 1.0 / Double(side - 1)
        for b in 0..<side { for g in 0..<side { for r in 0..<side {
            let c = Lab(RGB(r: Double(r) * step, g: Double(g) * step, b: Double(b) * step))
            let wanted = SkyRecolor.moved(c, from: source, to: target, by: SkyRecolor.weight(c, from: source))
            let got = Lab(RGB(wanted))
            let miss = deltaE2000(got, wanted)
            if miss > 1 { clipped += 1; worstClip = max(worstClip, miss) }
        }}}
        print(String(format: "sRGB 밖으로 튄 칸 %d / %d (%.1f%%), 최악 ΔE %.1f",
                     clipped, cells, Double(clipped) / Double(cells) * 100, worstClip))
    }
}
