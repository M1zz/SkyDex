import SwiftUI

/// The sky the app is standing under, painted behind everything.
///
/// The sun drives it and the weather only tints it. That order matters: the
/// solar clock always knows whether it is midday or midnight, while WeatherKit
/// can be unavailable, unprovisioned, or simply offline — and a backdrop that
/// disappears whenever the network does is not a backdrop, it is a bug that
/// happens to be white.
///
/// Legibility is not handled by keeping the colours timid. It is handled by
/// deciding, per preset, whether the sky is dark or light and then telling the
/// whole app to render in that scheme, so text goes white on a night sky and
/// black on a noon one. Every preset below is checked against that: the
/// darkest text-bearing colour clears 4.5:1 against its own text colour, which
/// is the WCAG floor for body copy.
struct SkyTheme {
    let top: Color
    let bottom: Color
    /// Whether text on this sky has to be light.
    let isDark: Bool

    var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// The dial is drawn in the sky's own light rather than in a fixed blue,
    /// which is what keeps the arc visible whether the backdrop is noon or
    /// midnight.
    var arcFill: Color { isDark ? .white.opacity(0.10) : .white.opacity(0.55) }
    var arcEdge: Color { isDark ? .white.opacity(0.34) : .black.opacity(0.20) }
    var hairline: Color { isDark ? .white.opacity(0.22) : .black.opacity(0.14) }
    /// Backing for the forecast strip: a pane of the sky, not a grey box.
    var panel: Color { isDark ? .white.opacity(0.12) : .white.opacity(0.55) }

    var colorScheme: ColorScheme { isDark ? .dark : .light }

    static let placeholder = SkyTheme.of(tone: nil, phase: .day)
}

extension SkyTheme {
    static func of(tone: SkyForecast.Tone?, phase: SolarPhase) -> SkyTheme {
        // With no forecast the sky is still a sky. Treating "unknown" as clear
        // is the honest default: the app then shows the time of day, which it
        // does know, instead of a blank page.
        let tone = tone ?? .clear

        switch phase {
        case .night:
            return SkyTheme(
                top: rgb(0.035, 0.078, 0.165),
                bottom: rgb(0.086, 0.133, 0.235),
                isDark: true
            )

        case .morningTwilight, .eveningTwilight:
            switch tone {
            case .clear, .breaking:
                return SkyTheme(
                    top: rgb(0.098, 0.153, 0.298),
                    bottom: rgb(0.557, 0.290, 0.180),
                    isDark: true
                )
            default:
                return SkyTheme(
                    top: rgb(0.094, 0.125, 0.192),
                    bottom: rgb(0.239, 0.263, 0.322),
                    isDark: true
                )
            }

        case .day:
            switch tone {
            case .clear:
                return SkyTheme(
                    top: rgb(0.306, 0.576, 0.839),
                    bottom: rgb(0.839, 0.910, 0.969),
                    isDark: false
                )
            case .breaking:
                return SkyTheme(
                    top: rgb(0.494, 0.576, 0.678),
                    bottom: rgb(0.941, 0.796, 0.651),
                    isDark: false
                )
            case .mixed:
                return SkyTheme(
                    top: rgb(0.498, 0.678, 0.847),
                    bottom: rgb(0.890, 0.929, 0.965),
                    isDark: false
                )
            case .dull:
                return SkyTheme(
                    top: rgb(0.663, 0.702, 0.741),
                    bottom: rgb(0.867, 0.886, 0.906),
                    isDark: false
                )
            case .wet:
                return SkyTheme(
                    top: rgb(0.522, 0.576, 0.631),
                    bottom: rgb(0.796, 0.827, 0.859),
                    isDark: false
                )
            }
        }
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }
}

// MARK: - Environment

private struct SkyThemeKey: EnvironmentKey {
    static let defaultValue = SkyTheme.placeholder
}

extension EnvironmentValues {
    var skyTheme: SkyTheme {
        get { self[SkyThemeKey.self] }
        set { self[SkyThemeKey.self] = newValue }
    }
}

// MARK: - Backdrop

struct SkyBackdrop: View {
    let theme: SkyTheme

    var body: some View {
        theme.gradient
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: theme.isDark)
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(
            [
                ("한낮 · 맑음", SkyTheme.of(tone: .clear, phase: .day)),
                ("한낮 · 흐림", SkyTheme.of(tone: .dull, phase: .day)),
                ("한낮 · 비", SkyTheme.of(tone: .wet, phase: .day)),
                ("노을", SkyTheme.of(tone: .clear, phase: .eveningTwilight)),
                ("밤", SkyTheme.of(tone: .clear, phase: .night)),
            ],
            id: \.0
        ) { name, theme in
            ZStack {
                SkyBackdrop(theme: theme)
                VStack(spacing: 2) {
                    Text(name).font(.headline)
                    Text("본문 크기의 글자가 이 위에서 읽히는지")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .environment(\.colorScheme, theme.colorScheme)
        }
    }
}
