import Foundation

/// 숫자와 달력을 화면 언어에 맞춘다. 앱과 위젯이 함께 쓴다.
///
/// 아랍어에서는 숫자를 0-9 로, 달력을 그레고리력으로 고정한다. 기기 지역(사우디 등)을 그대로
/// 따르면 `Text(date, format:)` 은 ١٢٣ 과 히즈라력으로, `String(format:)` 으로 만든 시각은 123 으로
/// 나와 한 화면에 섞인다. 계절도 히즈라력 달로 세면 틀린다. 다른 언어는 지금까지처럼 기기를 따른다
/// (태국어 불기 같은 것을 건드리지 않는다).
enum SkyLocale {
    /// 화면이 아랍어로 그려지는가. 기기 언어가 아니라 이 번들이 고른 번역을 본다.
    static var isArabic: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("ar") == true
    }

    /// 날짜 · 숫자를 그릴 로캘. SwiftUI 에는 `.environment(\.locale, SkyLocale.current)` 로 내린다.
    static var current: Locale {
        guard isArabic else { return .current }
        var components = Locale.Components(locale: .current)
        components.languageComponents = Locale.Language.Components(identifier: "ar")
        components.numberingSystem = "latn"
        components.calendar = .gregorian
        return Locale(components: components)
    }

    /// 계절과 해를 셀 달력.
    static var calendar: Calendar {
        guard isArabic else { return .current }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = current
        return calendar
    }

    /// 시각 · 날짜처럼 숫자로 된 토막을 왼쪽에서 오른쪽으로 묶는다(LRI … PDI).
    /// 오른쪽에서 왼쪽 문장 안에서 "07:30–08:00" 이 "08:00–07:30" 으로 뒤집히지 않게 한다.
    /// 보이지 않는 글자라 다른 언어에는 아무 영향이 없다.
    static func isolated(_ text: String) -> String {
        "\u{2066}\(text)\u{2069}"
    }
}
