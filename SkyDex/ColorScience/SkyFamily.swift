import Foundation

/// What kind of colour this is, in the only terms a palette should use.
///
/// The palette used to group by where a colour sits on the day: 여명, 낮, 노을,
/// 밤. That was wrong in a way that is hard to see and impossible to unsee once
/// you have. Those are *times*, and nothing about the grouping was a time — a
/// grey shot at eight in the morning landed under 노을 because grey is what the
/// sky is at dusk more often than at breakfast. The label said the sky was one
/// thing and the photograph said it was another, and the label was the one
/// people believed.
///
/// So the palette groups by colour and says so. 짙은 파랑, 푸른 회색, 모래빛,
/// 주황 — these claim nothing about when anything happened, which is right,
/// because the palette is the one screen in the app that is not about time. The
/// board is the day. The calendar is the order things happened. This is the
/// paint chips.
///
/// The families are cut in Lab, not in RGB. Chroma decides first — a sky is
/// grey or it is not, and most skies are — then hue, then lightness. That order
/// matters: sorting by hue first would scatter one flat overcast afternoon
/// across four families depending on which way its two units of chroma happened
/// to lean.
enum SkyFamily: String, CaseIterable, Identifiable {

    // Ordered as the page is read, dark to light and cool to warm, so the
    // palette still runs like a spectrum without any of the groups pretending
    // to be an hour.
    case nearBlack = "검정에 가까운"
    case deepBlue = "짙은 파랑"
    case blue = "파랑"
    case paleBlue = "옅은 파랑"
    case blueGrey = "푸른 회색"
    case green = "초록빛"
    case darkGrey = "어두운 회색"
    case grey = "회색"
    case lightGrey = "밝은 회색"
    case white = "흰빛"
    case warmGrey = "누런 회색"
    case sand = "모래빛"
    case yellow = "노랑"
    case apricot = "살구빛"
    case orange = "주황"
    case brick = "탁한 붉은빛"
    case red = "붉은빛"
    case pink = "분홍"
    case mauveGrey = "회보라"
    case violet = "보랏빛"

    var id: String { rawValue }

    /// Which family a colour belongs to.
    ///
    /// The thresholds are the ones the rest of the app already lives by: a sky
    /// under `L*18` is night whatever hue survives in it, and under seven units
    /// of chroma nobody would call a colour anything but grey.
    static func of(_ lab: Lab) -> SkyFamily {
        let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        let hue = {
            let degrees = atan2(lab.b, lab.a) * 180 / .pi
            return degrees < 0 ? degrees + 360 : degrees
        }()

        // Night first. A midnight blue is not a blue in the sense a palette
        // means; it is the bottom of the page.
        if lab.l < 18 { return .nearBlack }

        // Flat out grey.
        if chroma < 7 {
            switch lab.l {
            case ..<38: return .darkGrey
            case ..<62: return .grey
            case ..<84: return .lightGrey
            default: return .white
            }
        }

        // Blue is allowed in on less chroma than anything else, because it needs
        // less. Twelve units of blue in a pale sky still reads as a pale blue,
        // where twelve units of orange reads as beige.
        if (195..<300).contains(hue), chroma >= 12 {
            switch lab.l {
            case ..<38: return .deepBlue
            case ..<68: return .blue
            default: return .paleBlue
            }
        }

        // Barely coloured: the flat skies, which are most of them. They keep the
        // direction they lean without being called blue or orange.
        if chroma < 16 {
            switch hue {
            case 170..<300: return .blueGrey
            case 300..<345: return .mauveGrey
            case 130..<170: return .green
            case 40..<130: return .warmGrey
            default: return .brick
            }
        }

        switch hue {
        case 300..<345:
            return .violet
        case 130..<195:
            return .green
        case 70..<130:
            // Yellow needs real chroma to be yellow. Under it, the same hue is
            // sand — 미숫가루 and 달걀노른자 are the same direction and not the
            // same colour.
            return chroma >= 30 ? .yellow : .sand
        case 25..<70:
            if chroma < 22 { return lab.l < 62 ? .brick : .sand }
            if lab.l >= 76 { return .apricot }
            // A dark warm colour is usually a brick — but not if it is loud. The
            // difference between a wall and a sunset is mostly how much colour
            // is left in it.
            if lab.l < 52 { return chroma < 38 ? .brick : .red }
            return .orange
        default:
            // 345–360 and 0–25: the red end.
            if lab.l < 45 { return .brick }
            return lab.l >= 62 ? .pink : .red
        }
    }
}
