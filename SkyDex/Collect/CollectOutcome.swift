import Foundation

enum CollectOutcome {
    case newColor(
        palette: SkyPalette,
        position: SolarPosition,
        band: Band,
        novelty: Double?,
        placement: Placement,
        reached: ReferenceSky?
    )

    /// Close to a colour already collected. Still recorded — the sky may repeat
    /// but the day does not, and the name written on it is always new.
    case alreadyHeld(palette: SkyPalette, position: SolarPosition, band: Band, distance: Double)

    /// Past nautical dusk. Recorded, but there is nothing on the dial for it.
    case afterDark(palette: SkyPalette, position: SolarPosition, nextFirstLight: Double?)

    case noSkyFound

    /// Where a new colour landed relative to what was already there. Sitting
    /// between two held colours is worth saying out loud — it is the moment the
    /// collection gets finer rather than wider.
    enum Placement {
        case first, between, darker, brighter, different
    }

    var palette: SkyPalette? {
        switch self {
        case .newColor(let palette, _, _, _, _, _): return palette
        case .alreadyHeld(let palette, _, _, _): return palette
        case .afterDark(let palette, _, _): return palette
        case .noSkyFound: return nil
        }
    }

    var headline: String {
        switch self {
        case .newColor(_, _, _, _, let placement, _):
            switch placement {
            case .first: return "이 시간대의 첫 하늘"
            case .between: return "사이의 하늘"
            case .darker: return "더 맑은 하늘"
            case .brighter: return "더 흐린 하늘"
            case .different: return "새로운 하늘"
            }
        case .alreadyHeld: return "이미 가진 색"
        case .afterDark: return "해가 진 뒤예요"
        case .noSkyFound: return "하늘을 찾지 못했어요"
        }
    }

    var detail: String {
        switch self {
        case .newColor(_, _, let band, let novelty, let placement, let reached):
            var lines: [String] = []
            switch placement {
            case .first: lines.append("‘\(band.name)’의 하늘을 처음 모았어요.")
            case .between: lines.append("이미 가진 두 하늘 사이에 들어갔어요.")
            case .darker: lines.append("가지고 있던 어떤 하늘보다 맑고 진해요.")
            case .brighter: lines.append("가지고 있던 어떤 하늘보다 흐리고 밝아요.")
            case .different: lines.append("색조가 가진 것들과 달라요.")
            }
            if let novelty {
                lines.append("가장 가까운 색과 ΔE \(String(format: "%.1f", novelty)).")
            }
            if let reached {
                lines.append("참고 팔레트의 ‘\(reached.skyLabel) 하늘’에도 닿았어요.")
            }
            return lines.joined(separator: " ")

        case .alreadyHeld(_, _, _, let distance):
            return "가진 색과 ΔE \(String(format: "%.1f", distance))밖에 차이가 없어요. 그래도 오늘의 이름은 오늘 것이니 기록에는 남습니다."

        case .afterDark(_, _, let nextFirstLight):
            var text = "해가 지면 하늘색이 거의 변하지 않아서, 다이얼은 첫빛부터 마지막 빛까지만 모읍니다. 이 하늘도 기록에는 남겼어요."
            if let nextFirstLight {
                text += " 다음 첫빛은 \(SolarClock.clockString(nextFirstLight))."
            }
            return text

        case .noSkyFound:
            return "사진 위쪽에 하늘이 충분히 담기지 않았어요. 조금 더 위를 향해 찍어보세요."
        }
    }
}
