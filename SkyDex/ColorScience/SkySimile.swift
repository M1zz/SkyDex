import Foundation

/// What the colour is like, in plain Korean.
///
/// `SkyName` answers what a colour is *called*: 담자색, 우스하나이로, 페인즈 그레이.
/// Every one of those is sourced, and none of them was invented — that table is a
/// record and it has to stay one. But a record is not a picture. "라이트 스틸
/// 블루" tells almost nobody what colour they are holding, and a name you cannot
/// see is not doing the job a name is for.
///
/// So this is the other half, and the rules here are the opposite ones. Nothing
/// in this table is a real colour name and nothing pretends to be. Each entry is
/// an everyday thing that happens to be that colour — 물에 젖은 청바지색, 쌀뜨물색,
/// 떡볶이 국물색 — chosen so that reading it puts the colour in front of you
/// without a swatch. They are inventions, which is exactly why they are kept in
/// a separate table from the names that are not.
///
/// The test for an entry is not whether it is poetic. It is whether someone who
/// has never seen the photograph can picture the colour from the words alone,
/// and whether, having seen both, they would agree. So the images are ordinary
/// on purpose: kitchen, laundry, stationery, weather, food. A simile that needs
/// explaining has already failed.
///
/// The table is dense where real skies actually are — pale blue-greys, muddy
/// blues, flat overcast greys, sand — and thin where they are not. A sky spends
/// far more of its life looking like washed-out denim than like cobalt.
struct SkySimile: Identifiable, Hashable {
    let name: String

    /// One line: where you have seen this, and when the sky does it.
    let note: String

    let hex: String

    var id: String { hex + name }
    var rgb: RGB { RGB(hex: hex) ?? RGB(r: 0, g: 0, b: 0) }
}

enum SkySimiles {

    static let all: [SkySimile] = [

        // MARK: 한밤 — almost no light left

        SkySimile(name: String(localized: "먹물색"), note: String(localized: "벼루에 갈아 놓은 먹. 가장 깊은 밤."), hex: "#0C1120"),
        SkySimile(name: String(localized: "밤바다색"), note: String(localized: "불빛 없는 데서 내려다본 물. 검정에 파랑이 한 겹."), hex: "#0A1424"),
        SkySimile(name: String(localized: "탄 냄비 바닥색"), note: String(localized: "태우고 남은 자국. 푸른 기 없는 검정."), hex: "#14151C"),
        SkySimile(name: String(localized: "마른 잉크색"), note: String(localized: "쓰다 만 만년필 자국. 푸른 기가 남은 검정."), hex: "#1A2036"),
        SkySimile(name: String(localized: "깊은 물색"), note: String(localized: "발이 닿지 않는 곳의 색. 어둡고 서늘한 남색."), hex: "#101B33"),
        SkySimile(name: String(localized: "새 청바지색"), note: String(localized: "아직 한 번도 안 빤 데님. 진한 남색."), hex: "#1E2C4E"),
        SkySimile(name: String(localized: "야간열차 유리창색"), note: String(localized: "불빛이 지나간 뒤의 유리. 남색에 가까운 회색."), hex: "#2F3A5E"),
        SkySimile(name: String(localized: "한밤 유리창색"), note: String(localized: "커튼을 걷었을 때의 바깥. 검정보다 조금 파랗다."), hex: "#232B45"),

        // MARK: 새벽 — the blue hour, before any sun

        SkySimile(name: String(localized: "물에 씻은 잉크색"), note: String(localized: "손에 묻은 잉크를 헹군 물. 흐린 남색."), hex: "#2B3856"),
        SkySimile(name: String(localized: "교복 남색"), note: String(localized: "몇 해 입은 재킷의 남색. 검지도 파랗지도 않다."), hex: "#33406B"),
        SkySimile(name: String(localized: "물에 젖은 청바지색"), note: String(localized: "빨래를 막 널었을 때. 짙고 탁한 파랑."), hex: "#4A6086"),
        SkySimile(name: String(localized: "고등어 등색"), note: String(localized: "은빛이 도는 청회색. 비 오기 전 하늘."), hex: "#46586B"),
        SkySimile(name: String(localized: "낡은 작업복색"), note: String(localized: "여러 해 입어 색이 죽은 파랑."), hex: "#6E8098"),
        SkySimile(name: String(localized: "바랜 남색 커튼색"), note: String(localized: "해를 오래 본 커튼. 힘이 빠진 남색."), hex: "#7E90B6"),
        SkySimile(name: String(localized: "창에 서린 김색"), note: String(localized: "안에서 밖을 보면 뿌옇다. 푸른 회색."), hex: "#B6BCC9"),
        SkySimile(name: String(localized: "아침 안개색"), note: String(localized: "건물 위쪽이 지워진 아침. 푸르스름한 밝은 회색."), hex: "#A6B2C6"),
        SkySimile(name: String(localized: "젖은 후드티색"), note: String(localized: "빗물이 배어 진해진 회색. 흐린 새벽."), hex: "#737688"),
        SkySimile(name: String(localized: "빛바랜 보라 스웨터색"), note: String(localized: "여러 번 빨아 색이 죽은 보라. 동트기 직전 서쪽."), hex: "#9B8AA8"),

        // MARK: 여명 — the first warm light

        SkySimile(name: String(localized: "복숭아 껍질색"), note: String(localized: "솜털 있는 쪽. 분홍과 주황 사이."), hex: "#E8AE94"),
        SkySimile(name: String(localized: "살구 우유색"), note: String(localized: "우유에 살구를 갈아 넣은 색. 아주 옅은 주황."), hex: "#E5C2AC"),
        SkySimile(name: String(localized: "햇살 든 흰 벽색"), note: String(localized: "아침에 벽이 잠깐 이 색이 된다."), hex: "#EFE2D2"),
        SkySimile(name: String(localized: "연어살색"), note: String(localized: "구우면 사라지는 그 분홍."), hex: "#E89A82"),
        SkySimile(name: String(localized: "딸기 우유색"), note: String(localized: "흔들어 섞은 뒤의 분홍."), hex: "#E6A8B4"),
        SkySimile(name: String(localized: "덜 익은 살구색"), note: String(localized: "노랑이 아직 이긴 주황."), hex: "#E8B478"),

        // MARK: 낮 — sun up, sky blue

        SkySimile(name: String(localized: "유리컵 물색"), note: String(localized: "빛이 통과한 옅은 파랑."), hex: "#A9C7DE"),
        SkySimile(name: String(localized: "차가운 수돗물색"), note: String(localized: "손 시린 색. 옅고 서늘한 파랑."), hex: "#9FC0D6"),
        SkySimile(name: String(localized: "살얼음색"), note: String(localized: "봄에 살짝 언 물 위. 아주 옅은 파랑."), hex: "#BFD8E6"),
        SkySimile(name: String(localized: "사기그릇색"), note: String(localized: "흰 그릇에 남은 푸른 기."), hex: "#C9D6E2"),
        SkySimile(name: String(localized: "다림질한 흰 셔츠색"), note: String(localized: "거의 흰데 파랑이 한 겹. 아주 맑은 정오."), hex: "#E4E9EF"),
        SkySimile(name: String(localized: "세제 거품색"), note: String(localized: "설거지통 위에 뜬 흰 거품."), hex: "#DCE6EE"),
        SkySimile(name: String(localized: "바랜 청바지색"), note: String(localized: "무릎이 하얘진 데님. 흐린 낮의 파랑."), hex: "#8AA3BE"),
        SkySimile(name: String(localized: "파란 크레파스색"), note: String(localized: "도화지에 세게 문질렀을 때 나오는 파랑."), hex: "#4A86C8"),
        SkySimile(name: String(localized: "수영장 타일색"), note: String(localized: "물을 통해 본 파랑. 맑은 날 한낮."), hex: "#3E8FCF"),
        SkySimile(name: String(localized: "파란 볼펜색"), note: String(localized: "종이에 그은 선의 파랑."), hex: "#2F62B4"),
        SkySimile(name: String(localized: "깊은 수영장 물색"), note: String(localized: "발이 안 닿는 쪽 물색. 한여름 정오의 꼭대기."), hex: "#1F5AA0"),
        SkySimile(name: String(localized: "파란 물감 푼 물색"), note: String(localized: "붓을 헹군 통 안. 맑은 날 오후의 파랑."), hex: "#2C77BC"),
        SkySimile(name: String(localized: "만년필 잉크색"), note: String(localized: "병 안에서는 검정에 가까운 파랑."), hex: "#22345F"),
        SkySimile(name: String(localized: "사이다 병색"), note: String(localized: "초록이 섞인 옅은 파랑."), hex: "#7FB8D8"),

        // MARK: 흐린 날 — cloud takes the colour out

        SkySimile(name: String(localized: "김 서린 거울색"), note: String(localized: "샤워 뒤의 거울. 밝고 푸른 회색."), hex: "#CBD2D6"),
        SkySimile(name: String(localized: "안개 낀 유리색"), note: String(localized: "건너편이 뭉개지는 정도의 뿌연 회색."), hex: "#B6C3CE"),
        SkySimile(name: String(localized: "지우개 가루색"), note: String(localized: "책상에 모인 흰 가루. 아주 옅은 회색."), hex: "#C8C6C1"),
        SkySimile(name: String(localized: "분필 가루색"), note: String(localized: "칠판을 지운 뒤 공기 중에 남는 흰빛."), hex: "#DEDCD8"),
        SkySimile(name: String(localized: "마른 시멘트색"), note: String(localized: "굳은 지 오래된 바닥. 평평한 밝은 회색."), hex: "#B4B7B8"),
        SkySimile(name: String(localized: "식은 재색"), note: String(localized: "다 타고 남은 것. 흐린 날 낮의 표준 회색."), hex: "#A3A6A8"),
        SkySimile(name: String(localized: "흐린 유리창색"), note: String(localized: "닦아도 그대로인 색. 푸른 기 도는 중간 회색."), hex: "#9CA1AB"),
        SkySimile(name: String(localized: "젖은 골판지색"), note: String(localized: "비 맞은 상자. 따뜻한 기가 도는 회색."), hex: "#8F8983"),
        SkySimile(name: String(localized: "꺼진 화면색"), note: String(localized: "전원을 끈 직후의 검은 회색."), hex: "#24262B"),
        SkySimile(name: String(localized: "다 탄 성냥색"), note: String(localized: "머리만 검게 남은 개비. 어두운 회보라."), hex: "#45414A"),
        SkySimile(name: String(localized: "설거지물색"), note: String(localized: "기름 뜬 미지근한 물. 탁한 회색."), hex: "#A8ADA9"),
        SkySimile(name: String(localized: "빨래 삶은 물색"), note: String(localized: "김이 올라오는 하얀 물. 밝은 회색."), hex: "#BFC2BE"),
        SkySimile(name: String(localized: "칼날색"), note: String(localized: "빛을 받은 쇠. 푸른 기가 도는 회색."), hex: "#8C9499"),
        SkySimile(name: String(localized: "낡은 함석지붕색"), note: String(localized: "오래된 창고 지붕. 비 오기 직전의 회청색."), hex: "#6E7E8E"),
        SkySimile(name: String(localized: "흐린 날 바다색"), note: String(localized: "하늘색을 그대로 받은 물. 어두운 청회색."), hex: "#7A8C9C"),
        SkySimile(name: String(localized: "젖은 시멘트색"), note: String(localized: "비 맞은 바닥. 어둡고 축축한 회색."), hex: "#7E8489"),
        SkySimile(name: String(localized: "연필심색"), note: String(localized: "심을 눕혀 칠한 진회색. 비 오는 날 오후."), hex: "#6A6E72"),
        SkySimile(name: String(localized: "젖은 아스팔트색"), note: String(localized: "밤에 비 온 도로. 거의 검정에 가까운 회색."), hex: "#4A4E52"),
        SkySimile(name: String(localized: "이끼 낀 담장색"), note: String(localized: "회색에 초록이 슬었다. 폭풍 직전에 가끔."), hex: "#7E8C7A"),
        SkySimile(name: String(localized: "오래된 동전색"), note: String(localized: "손때 묻은 쇠. 누런 기 도는 회색."), hex: "#8A9488"),

        // MARK: 모래·황사 — warm haze

        SkySimile(name: String(localized: "쌀뜨물색"), note: String(localized: "쌀 씻은 첫 물. 따뜻한 흰색."), hex: "#DCD9D1"),
        SkySimile(name: String(localized: "달걀 껍데기색"), note: String(localized: "완전한 흰색이 아닌 흰색."), hex: "#E6E0D4"),
        SkySimile(name: String(localized: "묵은 종이색"), note: String(localized: "오래된 책 속장. 누렇게 뜬 흰색."), hex: "#DED6C6"),
        SkySimile(name: String(localized: "오래된 신문지색"), note: String(localized: "볕에 바랜 종이. 회색과 누런색 사이."), hex: "#CFC6B0"),
        SkySimile(name: String(localized: "황사 낀 창문색"), note: String(localized: "닦고 싶어지는 뿌연 누런빛."), hex: "#C4B79A"),
        SkySimile(name: String(localized: "미숫가루 물색"), note: String(localized: "가라앉기 전의 탁한 베이지."), hex: "#BFA684"),
        SkySimile(name: String(localized: "누런 장판색"), note: String(localized: "오래 눌린 바닥. 탁한 노랑."), hex: "#C9B183"),
        SkySimile(name: String(localized: "삶은 밤 속살색"), note: String(localized: "껍질 벗긴 밤의 노란 속."), hex: "#D6BE93"),
        SkySimile(name: String(localized: "커피에 부은 우유색"), note: String(localized: "막 부어 아직 안 섞였을 때."), hex: "#C8AE90"),
        SkySimile(name: String(localized: "먼지 앉은 책장색"), note: String(localized: "손가락으로 밀면 자국이 나는 밝은 회갈색."), hex: "#B7ABA0"),
        SkySimile(name: String(localized: "마른 진흙색"), note: String(localized: "갈라지기 시작한 흙바닥. 옅은 갈색."), hex: "#BCA391"),
        SkySimile(name: String(localized: "식은 밀크티색"), note: String(localized: "덜 마시고 둔 잔. 탁한 분홍빛 갈색."), hex: "#A5837A"),
        SkySimile(name: String(localized: "젖은 마분지색"), note: String(localized: "비를 맞고 부푼 종이. 흐린 노을의 색."), hex: "#9A8C80"),
        SkySimile(name: String(localized: "비 맞은 나무 데크색"), note: String(localized: "물기를 머금어 어두워진 나무."), hex: "#7C726C"),
        SkySimile(name: String(localized: "재 묻은 벽돌색"), note: String(localized: "불을 쬔 자리. 어두운 붉은 회색."), hex: "#85706A"),
        SkySimile(name: String(localized: "커피 자국색"), note: String(localized: "컵을 들어낸 뒤 남은 동그란 얼룩."), hex: "#67605E"),
        SkySimile(name: String(localized: "삶은 팥 껍질색"), note: String(localized: "물에 오래 불린 팥. 어두운 자줏빛 회색."), hex: "#63535A"),
        SkySimile(name: String(localized: "인절미 고물색"), note: String(localized: "콩가루를 묻힌 면. 부드러운 갈색빛 베이지."), hex: "#C2A87E"),

        // MARK: 노을 — the twenty minutes the app exists for

        SkySimile(name: String(localized: "달걀노른자색"), note: String(localized: "터뜨리기 직전. 진한 노랑."), hex: "#E8B04A"),
        SkySimile(name: String(localized: "식빵 가장자리색"), note: String(localized: "노랑이 갈색으로 넘어가는 지점."), hex: "#C98B4F"),
        SkySimile(name: String(localized: "귤 껍질색"), note: String(localized: "까기 전의 그 주황."), hex: "#E88A3C"),
        SkySimile(name: String(localized: "구운 연어색"), note: String(localized: "겉면이 익은 분홍빛 주황."), hex: "#E08258"),
        SkySimile(name: String(localized: "곶감색"), note: String(localized: "겉에 분이 난 곶감. 탁한 주황."), hex: "#C97B3F"),
        SkySimile(name: String(localized: "장작 불씨색"), note: String(localized: "불꽃이 아니라 숯이 붉은 상태."), hex: "#C94B24"),
        SkySimile(name: String(localized: "홍시색"), note: String(localized: "물러 터지기 직전의 붉은 주황."), hex: "#D9603A"),
        SkySimile(name: String(localized: "떡볶이 국물색"), note: String(localized: "졸아든 뒤의 붉은색. 가장 진한 노을."), hex: "#C9432E"),
        SkySimile(name: String(localized: "수박 속살색"), note: String(localized: "가운데 가장 단 부분. 붉은 분홍."), hex: "#D9455A"),
        SkySimile(name: String(localized: "장미 잼색"), note: String(localized: "설탕에 절인 꽃잎. 탁한 분홍빛 빨강."), hex: "#C0596A"),
        SkySimile(name: String(localized: "붉은 벽돌색"), note: String(localized: "비를 여러 해 맞은 담벼락."), hex: "#9A5A48"),
        SkySimile(name: String(localized: "식은 숯불색"), note: String(localized: "재를 뒤집어쓴 불. 어두운 붉은 갈색."), hex: "#8A4A3C"),

        // MARK: 땅거미 — colour draining out of the west

        SkySimile(name: String(localized: "자두 겉면색"), note: String(localized: "붉은 보라에 흰 가루가 앉은 색."), hex: "#7A3F58"),
        SkySimile(name: String(localized: "팥죽색"), note: String(localized: "새알 넣기 전의 걸쭉한 붉은 갈색."), hex: "#6B3F4A"),
        SkySimile(name: String(localized: "남은 포도주색"), note: String(localized: "잔 바닥에 남은 검붉은 보라."), hex: "#5A3550"),
        SkySimile(name: String(localized: "지고 난 라일락색"), note: String(localized: "말라가는 꽃의 흐린 보라."), hex: "#6B5C86"),
        SkySimile(name: String(localized: "블루베리 우유색"), note: String(localized: "섞다 만 연보라."), hex: "#8A87B8"),
        SkySimile(name: String(localized: "포도 껍질색"), note: String(localized: "씻어서 물기가 있는 진보라."), hex: "#4A3A63"),
        SkySimile(name: String(localized: "가지 껍질색"), note: String(localized: "빛을 먹는 검보라. 하루의 마지막 색."), hex: "#3C3357")
    ]

    /// The table in Lab, built once — the same reason `SkyNames` does it.
    private static let labs: [Lab] = all.map { Lab($0.rgb) }

    /// The nearest image to a colour.
    ///
    /// A simile is an approximation by definition, so unlike a name it does not
    /// have to defend a claim of identity — but the distance is still returned,
    /// because a picture that is a long way off should be introduced as one.
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
        return Match(simile: all[bestIndex], distance: bestDistance)
    }

    struct Match: Hashable {
        let simile: SkySimile
        let distance: Double

        /// Close enough to say the sky *is* that thing rather than *nearest to* it.
        var isClose: Bool { distance <= 6 }
    }
}
