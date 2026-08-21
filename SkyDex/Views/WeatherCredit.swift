import SwiftUI

/// Apple's mark, wherever Apple's forecast is.
///
/// One view rather than a line of text copied into each place the forecast is
/// used, so there is exactly one thing to get right and one place it is written.
/// It draws the combined  Weather mark Apple serves and links its legal page,
/// which is the whole of what WeatherKit asks for.
///
/// The mark is an image fetched over the network, so on a first run that fails
/// it is not there. The words " Weather" stand in — smaller than Apple's own
/// artwork and less handsome, still the trademark, still linked. Showing nothing
/// is the one option that is not available.
struct WeatherCredit: View {

    let credit: SkyCredit

    /// Whether it is sitting on something dark — a photograph laid under the
    /// board, rather than the page. The dark appearance is read from the
    /// environment; this is for the times the background is not the page.
    var onDark = false

    /// The mark's height. Everything else about it is Apple's.
    var height: CGFloat = 14

    @Environment(\.colorScheme) private var colorScheme

    private var dark: Bool { onDark || colorScheme == .dark }

    private var label: String { "\u{F8FF} Weather" }

    var body: some View {
        Link(destination: credit.legalPageURL) {
            Group {
                if let mark = credit.mark(onDark: dark) {
                    Image(uiImage: mark)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                } else {
                    // The words, when Apple's artwork could not be fetched.
                    //
                    // In a debug build this also has to answer a second
                    // question: whether the forecast behind it is real. Words
                    // alone cannot say — a real forecast whose mark images
                    // failed looks exactly like the placeholder — and telling
                    // those two apart is the whole point of running this on a
                    // device. So the placeholder says so, and only ever in a
                    // build that cannot ship.
                    Text(verbatim: label)
                        .font(.system(size: height - 1, weight: .medium))
                        .foregroundStyle(dark ? Color.white : Color.secondary)
                }
            }
            .frame(height: height)
            // Legible, and not the loudest thing on a screen whose subject is a
            // colour. Apple asks for the mark to be clear, not for it to win.
            .opacity(dark ? 0.85 : 0.65)
            // TEMPORARY — goes with the placeholder in `SkyWeather`. Says which
            // half is invented, next to whichever form the mark took.
            .modifier(PlaceholderNote(showing: credit.isPlaceholder))
        }
        .accessibilityLabel("Apple Weather")
        .accessibilityHint("날씨 정보의 출처와 법적 고지를 엽니다.")
    }
}

/// TEMPORARY — remove with `SkyWeather.installPlaceholder`.
private struct PlaceholderNote: ViewModifier {
    let showing: Bool

    func body(content: Content) -> some View {
        #if DEBUG
        if showing {
            HStack(spacing: 5) {
                content
                Text(verbatim: "(예보 가짜 · WeatherKit 실패)")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
