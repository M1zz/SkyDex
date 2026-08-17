import Foundation

/// What to call a sky.
///
/// A hex code says exactly what a colour is and nothing about what it is like.
/// `#BEA3C9` is a fact; 담자색 is a thing a person can hold on to and go looking
/// for again. So every collected sky is handed the nearest name anyone has
/// already given that colour.
///
/// The names come from four traditions, kept in one table on purpose. None of
/// them covers a whole day alone — Korean traditional colour has a dense
/// blue-to-violet range and little for a low sun, the Japanese set is unusually
/// specific about times of day, the painter's pigments are the only ones with a
/// word for the flat grey of an overcast noon (Payne's grey was mixed for exactly
/// that), and the standard keyword set carries the pale blue-greys that a real
/// sky spends most of its time being.
///
/// That last group is where a real sky mostly lives, and it is the reason the
/// table is as large as it is. A first pass with sixty saturated names put
/// something plausible on every sky and something *close* on almost none: the
/// midday reference blue landed at ΔE 0.6 while sunrise landed at 13.9, because
/// nothing in the table was as dull as the sky at that hour. Skies are pale and
/// muddy far more often than they are vivid.
///
/// Pantone would have been the obvious standard to draw on — it is the one most
/// people have heard of — but its values are licensed rather than published, so
/// the standard names here are the CSS/X11 keywords instead, which are published
/// and cover the same ground.
///
/// Each entry carries where it came from and one line of plain Korean, because a
/// name nobody recognises is not a name yet. "루리이로" alone is a sound;
/// "루리이로 · 瑠璃色, 유리처럼 짙고 맑은 파랑" is a colour.
///
/// Nothing here is invented. Every value is the one its own tradition publishes
/// — see `sources` — and no name is stretched to fit a sky it was not used for.
struct SkyName: Identifiable, Hashable {

    /// Which tradition a name comes from. It is shown next to the name, so a
    /// reader can tell a Korean traditional colour from a tube of paint without
    /// having to know the word.
    enum Origin: String, Hashable {
        case korea = "전통색"
        case japan = "和色"
        case pigment = "안료"
        case standard = "표준색"
    }

    let name: String
    let origin: Origin

    /// One line, in plain Korean. For the Japanese names it opens with the
    /// original spelling, which is the part worth keeping.
    let gloss: String

    let hex: String

    var id: String { hex + name }
    var rgb: RGB { RGB(hex: hex) ?? RGB(r: 0, g: 0, b: 0) }
}

enum SkyNames {

    /// Where the numbers come from, and the reason there are three lists rather
    /// than one. Kept in the code because a colour table with no provenance is a
    /// colour table someone made up.
    ///
    /// - 전통색: 국립현대미술관 계열의 한국 전통색 색상표
    ///   (<https://eond.com/color/365805>)
    /// - 和色: 和色大辞典 (<https://www.colordic.org/w>)
    /// - 안료·염료: 각 안료의 위키백과 항목
    ///   (Prussian blue, Ultramarine, Cobalt blue, Cerulean, Payne's grey,
    ///   Davy's grey, Naples yellow, Cadmium orange, Vermilion, Mauve,
    ///   Indigo dye)
    /// - 표준색: CSS/X11 색 키워드 (<https://en.wikipedia.org/wiki/Web_colors>)
    static let sources = "전통색 · 和色大辞典 · 안료 문헌 · CSS 표준색"

    /// The table. Ordered dark to light within each tradition only for reading;
    /// the lookup does not care.
    static let all: [SkyName] = [

        // MARK: 한국 전통색
        SkyName(name: "흑색", origin: .korea, gloss: "먹에 가까운 검정, 한밤의 하늘", hex: "#1D1E23"),
        SkyName(name: "숙람색", origin: .korea, gloss: "무르익은 쪽빛, 어두운 남청", hex: "#45436C"),
        SkyName(name: "군청색", origin: .korea, gloss: "깊고 차분한 청보라", hex: "#4F599F"),
        SkyName(name: "남색", origin: .korea, gloss: "쪽으로 물들인 짙은 청보라", hex: "#6A5BA8"),
        SkyName(name: "감색", origin: .korea, gloss: "물기 있는 진한 청색", hex: "#026892"),
        SkyName(name: "청색", origin: .korea, gloss: "오방색의 파랑, 한낮의 하늘", hex: "#0B6DB7"),
        SkyName(name: "흑청색", origin: .korea, gloss: "어둠이 도는 청록빛 파랑", hex: "#1583AF"),
        SkyName(name: "벽색", origin: .korea, gloss: "옥빛이 도는 맑은 하늘색", hex: "#00B5E3"),
        SkyName(name: "청벽색", origin: .korea, gloss: "벽색보다 환한 하늘빛", hex: "#18B4E9"),
        SkyName(name: "천청색", origin: .korea, gloss: "연한 하늘빛 청록", hex: "#5AC6D0"),
        SkyName(name: "담청색", origin: .korea, gloss: "묽게 풀어놓은 청록", hex: "#00A6A9"),
        SkyName(name: "옥색", origin: .korea, gloss: "옥처럼 연한 푸른 초록", hex: "#9ED6C0"),
        SkyName(name: "회색", origin: .korea, gloss: "구름이 덮은 날의 무채색", hex: "#A4AAA7"),
        SkyName(name: "담자색", origin: .korea, gloss: "연한 자주, 새벽의 보랏빛", hex: "#BEA3C9"),
        SkyName(name: "훈색", origin: .korea, gloss: "노을이 물든 살빛", hex: "#D97793"),
        SkyName(name: "연분홍색", origin: .korea, gloss: "해 뜰 무렵의 옅은 분홍", hex: "#E0709B"),
        SkyName(name: "홍색", origin: .korea, gloss: "선명하게 붉은빛", hex: "#F15B5B"),
        SkyName(name: "주홍색", origin: .korea, gloss: "해가 잠긴 뒤의 붉은 자주", hex: "#C23352"),
        SkyName(name: "적색", origin: .korea, gloss: "오방색의 붉음, 가장 진한 노을", hex: "#B82647"),
        SkyName(name: "진홍색", origin: .korea, gloss: "붉은기가 도는 짙은 자주", hex: "#BF2F7B"),
        SkyName(name: "자주색", origin: .korea, gloss: "붉음과 푸름이 섞인 자주", hex: "#89236A"),
        SkyName(name: "자색", origin: .korea, gloss: "어둡게 가라앉은 자주", hex: "#6D1B43"),
        SkyName(name: "흑홍색", origin: .korea, gloss: "먼지가 앉은 듯한 붉은 회색", hex: "#8E6F80"),
        SkyName(name: "치자색", origin: .korea, gloss: "치자로 물들인 부드러운 노랑", hex: "#F6CF7A"),
        SkyName(name: "황색", origin: .korea, gloss: "오방색의 노랑, 해가 낮게 걸린 빛", hex: "#F9D537"),
        SkyName(name: "백색", origin: .korea, gloss: "빛이 넘친 흰 하늘", hex: "#FFFFFF"),
        SkyName(name: "청현색", origin: .korea, gloss: "검푸르게 가라앉은 청색", hex: "#006494"),
        SkyName(name: "벽청색", origin: .korea, gloss: "벽색과 청색 사이, 한낮의 파랑", hex: "#448CCB"),
        SkyName(name: "삼청색", origin: .korea, gloss: "해 뜰 무렵의 부드러운 청보라", hex: "#5C6EB4"),
        SkyName(name: "청자색", origin: .korea, gloss: "짙은 청보라, 밤이 오는 색", hex: "#403F95"),
        SkyName(name: "연지회색", origin: .korea, gloss: "붉은기가 섞인 어두운 회색", hex: "#6F606E"),
        SkyName(name: "적자색", origin: .korea, gloss: "붉은 자주, 해가 진 직후", hex: "#BA4160"),
        SkyName(name: "소색", origin: .korea, gloss: "물들이지 않은 천의 빛, 모래빛", hex: "#D8C8B2"),
        SkyName(name: "담황색", origin: .korea, gloss: "아주 옅은 노랑", hex: "#F5F0C5"),
        SkyName(name: "설백색", origin: .korea, gloss: "눈빛 도는 흰색, 겨울의 흐린 하늘", hex: "#DDE7E7"),

        // MARK: 일본 전통색 (和色)
        SkyName(name: "코이아이", origin: .japan, gloss: "濃藍 · 검정에 닿은 쪽빛", hex: "#0F2350"),
        SkyName(name: "콘이로", origin: .japan, gloss: "紺色 · 밤이 완전히 내린 남색", hex: "#223A70"),
        SkyName(name: "루리이로", origin: .japan, gloss: "瑠璃色 · 유리처럼 짙고 맑은 파랑", hex: "#1E50A2"),
        SkyName(name: "군조이로", origin: .japan, gloss: "群青色 · 군청, 높고 마른 하늘", hex: "#4C6CB3"),
        SkyName(name: "아이이로", origin: .japan, gloss: "藍色 · 쪽빛, 물기 있는 파랑", hex: "#165E83"),
        SkyName(name: "키쿄이로", origin: .japan, gloss: "桔梗色 · 도라지꽃의 청보라", hex: "#5654A2"),
        SkyName(name: "스미레이로", origin: .japan, gloss: "菫色 · 제비꽃의 보라", hex: "#7058A3"),
        SkyName(name: "하토바이로", origin: .japan, gloss: "鳩羽色 · 비둘기 깃의 흐린 보라", hex: "#95859C"),
        SkyName(name: "후지이로", origin: .japan, gloss: "藤色 · 등꽃의 옅은 보라", hex: "#BBBCDE"),
        SkyName(name: "소라이로", origin: .japan, gloss: "空色 · 말 그대로 하늘색", hex: "#A0D8EF"),
        SkyName(name: "미즈이로", origin: .japan, gloss: "水色 · 물빛, 아주 옅은 파랑", hex: "#BCE2E8"),
        SkyName(name: "뱌쿠군", origin: .japan, gloss: "白群 · 흰 기가 도는 청록", hex: "#83CCD2"),
        SkyName(name: "아사기이로", origin: .japan, gloss: "浅葱色 · 대파의 옅은 청록", hex: "#00A3AF"),
        SkyName(name: "긴네즈", origin: .japan, gloss: "銀鼠 · 은빛 쥐색, 얇은 구름", hex: "#AFAFB0"),
        SkyName(name: "나마리이로", origin: .japan, gloss: "鉛色 · 납빛, 비 오기 전의 하늘", hex: "#7B7C7D"),
        SkyName(name: "시노노메이로", origin: .japan, gloss: "東雲色 · 동틀 무렵 구름의 색", hex: "#F19072"),
        SkyName(name: "야마부키이로", origin: .japan, gloss: "山吹色 · 황매화의 진한 노랑", hex: "#F8B500"),
        SkyName(name: "다이다이이로", origin: .japan, gloss: "橙色 · 등자나무 열매의 주황", hex: "#EE7800"),
        SkyName(name: "슈이로", origin: .japan, gloss: "朱色 · 주朱, 타오르는 주황", hex: "#EB6101"),
        SkyName(name: "아카네이로", origin: .japan, gloss: "茜色 · 꼭두서니로 물들인 저녁의 붉음", hex: "#B7282E"),
        SkyName(name: "아이스미차", origin: .japan, gloss: "藍墨茶 · 먹빛이 도는 남색, 밤의 회색", hex: "#474A4D"),
        SkyName(name: "케시즈미이로", origin: .japan, gloss: "消炭色 · 다 타고 남은 숯의 회색", hex: "#524E4D"),
        SkyName(name: "마스하나이로", origin: .japan, gloss: "舛花色 · 흐린 날 낮의 청회색", hex: "#5B7E91"),
        SkyName(name: "우스하나이로", origin: .japan, gloss: "薄花色 · 옅은 꽃빛, 무른 파랑", hex: "#698AAB"),
        SkyName(name: "미즈아사기", origin: .japan, gloss: "水浅葱 · 물빛이 섞인 옅은 청록", hex: "#80ABA9"),
        SkyName(name: "사비아사기", origin: .japan, gloss: "錆浅葱 · 녹슨 청록", hex: "#5C9291"),
        SkyName(name: "후카가와네즈", origin: .japan, gloss: "深川鼠 · 초록이 섞인 쥐색", hex: "#97A791"),
        SkyName(name: "리큐시로차", origin: .japan, gloss: "利休白茶 · 바랜 다갈색 회색", hex: "#B3ADA0"),
        SkyName(name: "하이아오", origin: .japan, gloss: "灰青 · 재를 섞은 옅은 파랑", hex: "#C0C6C9"),
        SkyName(name: "히소쿠", origin: .japan, gloss: "秘色色 · 청자에 어린 옅은 하늘빛", hex: "#ABCED8"),
        SkyName(name: "아마이로", origin: .japan, gloss: "天色 · 하늘 그 자체를 가리키는 이름", hex: "#2CA9E1"),
        SkyName(name: "아이지로", origin: .japan, gloss: "藍白 · 쪽빛이 거의 빠진 흰색", hex: "#EBF6F7"),
        SkyName(name: "시로네리", origin: .japan, gloss: "白練 · 누인 명주의 흰색", hex: "#F3F3F2"),
        SkyName(name: "스나이로", origin: .japan, gloss: "砂色 · 모래빛, 해가 기운 뒤의 탁한 밝음", hex: "#DCD3B2"),
        SkyName(name: "하시바미이로", origin: .japan, gloss: "榛色 · 개암빛, 노을이 시작되는 금갈색", hex: "#BFA46F"),
        SkyName(name: "시로차", origin: .japan, gloss: "白茶 · 흰기가 도는 밝은 다갈색", hex: "#DDBB99"),
        SkyName(name: "하이자쿠라", origin: .japan, gloss: "灰桜 · 재가 앉은 벚꽃빛", hex: "#E8D3D1"),
        SkyName(name: "산고이로", origin: .japan, gloss: "珊瑚色 · 산호의 연한 주홍", hex: "#F5B1AA"),
        SkyName(name: "테츠콘", origin: .japan, gloss: "鉄紺 · 쇠빛이 도는 검은 남색", hex: "#17184B"),
        SkyName(name: "아이테츠", origin: .japan, gloss: "藍鉄 · 쪽빛이 남은 검은 회색", hex: "#393F4C"),
        SkyName(name: "콘네즈", origin: .japan, gloss: "紺鼠 · 남색에 쥐색을 섞은 밤", hex: "#44617B"),
        SkyName(name: "시콘", origin: .japan, gloss: "紫紺 · 검게 가라앉은 자주", hex: "#460E44"),
        SkyName(name: "쿠와노미이로", origin: .japan, gloss: "桑実色 · 오디빛 짙은 보라", hex: "#55295B"),
        SkyName(name: "무라사키토비", origin: .japan, gloss: "紫鳶 · 자줏빛 도는 어두운 갈색", hex: "#5F414B"),
        SkyName(name: "부도네즈", origin: .japan, gloss: "葡萄鼠 · 포도빛 쥐색, 해가 진 뒤", hex: "#705B67"),
        SkyName(name: "후타아이", origin: .japan, gloss: "二藍 · 쪽에 홍을 겹친 박모의 보라", hex: "#915C8B"),
        SkyName(name: "후지무라사키", origin: .japan, gloss: "藤紫 · 등꽃의 밝은 보라", hex: "#A59ACA"),
        SkyName(name: "아즈키이로", origin: .japan, gloss: "小豆色 · 팥빛, 잔광이 식은 붉음", hex: "#96514D"),
        SkyName(name: "렌가이로", origin: .japan, gloss: "煉瓦色 · 벽돌빛, 해가 막 넘어간 색", hex: "#B55233"),
        SkyName(name: "에비차", origin: .japan, gloss: "海老茶 · 어두운 붉은 갈색", hex: "#773C30"),
        SkyName(name: "베니히와다", origin: .japan, gloss: "紅檜皮 · 붉은 편백 껍질빛", hex: "#7B4741"),
        SkyName(name: "코게차", origin: .japan, gloss: "焦茶 · 그을린 갈색", hex: "#6F4B3E"),
        SkyName(name: "우스즈미이로", origin: .japan, gloss: "薄墨色 · 옅은 먹빛 회색", hex: "#A3A3A2"),
        SkyName(name: "소쇼쿠", origin: .japan, gloss: "素色 · 아무것도 들이지 않은 흰빛", hex: "#EAE5E3"),
        SkyName(name: "시로스미레이로", origin: .japan, gloss: "白菫色 · 흰 제비꽃, 새벽의 흰 보라", hex: "#EAEDF7"),

        // MARK: 안료와 염료
        SkyName(name: "프러시안 블루", origin: .pigment, gloss: "Prussian blue · 검푸른 심해빛", hex: "#003153"),
        SkyName(name: "울트라마린", origin: .pigment, gloss: "Ultramarine · 청금석에서 온 진한 파랑", hex: "#120A8F"),
        SkyName(name: "코발트 블루", origin: .pigment, gloss: "Cobalt blue · 맑고 서늘한 파랑", hex: "#0047AB"),
        SkyName(name: "세룰리안 블루", origin: .pigment, gloss: "Cerulean blue · 하늘을 칠하려 만든 파랑", hex: "#2A52BE"),
        SkyName(name: "세룰리안", origin: .pigment, gloss: "Cerulean · 라틴어 caelum, 하늘에서 온 이름", hex: "#007BA7"),
        SkyName(name: "인디고", origin: .pigment, gloss: "Indigo dye · 쪽 염료의 어두운 청색", hex: "#00416A"),
        SkyName(name: "페인즈 그레이", origin: .pigment, gloss: "Payne's grey · 흐린 하늘을 위해 조합된 회색", hex: "#536878"),
        SkyName(name: "데이비스 그레이", origin: .pigment, gloss: "Davy's grey · 빛이 거의 없는 중간 회색", hex: "#555555"),
        SkyName(name: "모브", origin: .pigment, gloss: "Mauve · 최초의 합성 염료, 연한 보라", hex: "#E0B0FF"),
        SkyName(name: "네이플스 옐로", origin: .pigment, gloss: "Naples yellow · 낮게 걸린 해의 노랑", hex: "#FADA5E"),
        SkyName(name: "카드뮴 오렌지", origin: .pigment, gloss: "Cadmium orange · 짙고 불투명한 주황", hex: "#ED872D"),
        SkyName(name: "버밀리언", origin: .pigment, gloss: "Vermilion · 주朱, 가장 강한 붉은 주황", hex: "#FF4000"),

        // MARK: 표준색 (CSS/X11 키워드)
        SkyName(name: "미드나이트 블루", origin: .standard, gloss: "Midnight blue · 자정의 남색", hex: "#191970"),
        SkyName(name: "다크 슬레이트 블루", origin: .standard, gloss: "Dark slate blue · 어두운 청보라", hex: "#483D8B"),
        SkyName(name: "스틸 블루", origin: .standard, gloss: "Steel blue · 쇠빛이 도는 파랑", hex: "#4682B4"),
        SkyName(name: "카데트 블루", origin: .standard, gloss: "Cadet blue · 바랜 청록", hex: "#5F9EA0"),
        SkyName(name: "슬레이트 그레이", origin: .standard, gloss: "Slate gray · 점판암의 청회색", hex: "#708090"),
        SkyName(name: "라이트 슬레이트 그레이", origin: .standard, gloss: "Light slate gray · 밝은 청회색", hex: "#778899"),
        SkyName(name: "딤 그레이", origin: .standard, gloss: "Dim gray · 빛이 죽은 회색", hex: "#696969"),
        SkyName(name: "실버", origin: .standard, gloss: "Silver · 은빛 밝은 회색", hex: "#C0C0C0"),
        SkyName(name: "라이트 스틸 블루", origin: .standard, gloss: "Light steel blue · 아침의 옅은 청회색", hex: "#B0C4DE"),
        SkyName(name: "스카이 블루", origin: .standard, gloss: "Sky blue · 이름 그대로의 하늘색", hex: "#87CEEB"),
        SkyName(name: "파우더 블루", origin: .standard, gloss: "Powder blue · 먼지처럼 옅은 하늘빛", hex: "#B0E0E6"),
        SkyName(name: "라벤더", origin: .standard, gloss: "Lavender · 거의 흰 연보라", hex: "#E6E6FA"),
        SkyName(name: "시슬", origin: .standard, gloss: "Thistle · 엉겅퀴빛 연보라", hex: "#D8BFD8"),
        SkyName(name: "로지 브라운", origin: .standard, gloss: "Rosy brown · 장밋빛 도는 갈색", hex: "#BC8F8F"),
        SkyName(name: "인디언 레드", origin: .standard, gloss: "Indian red · 흙이 섞인 붉음", hex: "#CD5C5C"),
        SkyName(name: "탠", origin: .standard, gloss: "Tan · 햇빛에 그은 모래빛", hex: "#D2B48C"),
        SkyName(name: "벌리우드", origin: .standard, gloss: "Burlywood · 나무빛 금갈색", hex: "#DEB887"),
        SkyName(name: "샌디 브라운", origin: .standard, gloss: "Sandy brown · 모래 섞인 주황", hex: "#F4A460"),
        SkyName(name: "초콜릿", origin: .standard, gloss: "Chocolate · 짙게 구운 주황", hex: "#D2691E"),
        SkyName(name: "피치 퍼프", origin: .standard, gloss: "Peach puff · 복숭아빛 연주황", hex: "#FFDAB9")
    ]

    /// The table in Lab, built once. Naming happens on every card that opens, and
    /// converting sixty hex strings each time is work with a known answer.
    private static let labs: [Lab] = all.map { Lab($0.rgb) }

    /// The nearest name to a colour, and how far off it is in CIEDE2000.
    ///
    /// The distance is returned rather than hidden because it is the difference
    /// between "this is 소라이로" and "this is nearest to 소라이로", and a card
    /// that says the first when it means the second is lying about a sky someone
    /// went out and got. `SkyName.Match.isClose` draws that line.
    static func nearest(to lab: Lab) -> Match {
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for index in all.indices {
            let distance = deltaE2000(lab, labs[index])
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return Match(name: all[bestIndex], distance: bestDistance)
    }

    struct Match: Hashable {
        let name: SkyName
        let distance: Double

        /// Near enough to call it that colour outright.
        ///
        /// Five is about where a difference stops being something only a
        /// side-by-side comparison would show. Inside it the name is the sky's
        /// name; outside it the name is the closest thing anyone has called this
        /// colour, which is a weaker and truer claim.
        var isClose: Bool { distance <= 5 }
    }
}
