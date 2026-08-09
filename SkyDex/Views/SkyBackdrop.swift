import SwiftUI

/// Today's weather as a wash behind the whole app.
///
/// The constraint that shapes every value here: a background is not allowed to
/// cost anything in legibility. So the presets vary in *hue*, never really in
/// brightness — in light mode every preset sits between 91% and 99% white, in
/// dark mode between 2% and 8%. Black text on the darkest light preset still
/// clears 15:1, well past the 4.5:1 that WCAG asks for body text, and the same
/// holds inverted. The weather is something you notice on the second look, not
/// something you have to read around on the first.
///
/// This is also why the sky is not painted literally. A real overcast sky is
/// mid-grey, and mid-grey is the one value that ruins contrast for dark and
/// light text alike; a rainy day here reads as a cool cast, not as actual
/// cloud.
struct SkyBackdrop: View {
    let tone: SkyForecast.Tone?
    /// After last light the wash cools and loses its warmth, whatever the
    /// forecast said, because that is what the sky itself does.
    var isNight: Bool = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: preset.map(Color.init),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.7), value: tone)
        .animation(.easeInOut(duration: 0.7), value: isNight)
    }

    private var preset: [Preset] {
        scheme == .dark ? Self.dark(tone, isNight) : Self.light(tone, isNight)
    }

    /// A colour as literal components, so the contrast figures above can be
    /// checked against the source rather than against a colour asset.
    struct Preset {
        let red: Double
        let green: Double
        let blue: Double
    }

    private static func light(_ tone: SkyForecast.Tone?, _ isNight: Bool) -> [Preset] {
        guard let tone else { return [.init(1, 1, 1), .init(1, 1, 1)] }
        if isNight { return [.init(0.898, 0.914, 0.945), .init(0.973, 0.976, 0.984)] }
        switch tone {
        case .clear:
            return [.init(0.851, 0.914, 0.976), .init(0.984, 0.992, 1.000)]
        case .breaking:
            return [.init(0.894, 0.906, 0.929), .init(0.996, 0.941, 0.886)]
        case .mixed:
            return [.init(0.902, 0.929, 0.960), .init(0.980, 0.988, 0.996)]
        case .dull:
            return [.init(0.918, 0.925, 0.933), .init(0.969, 0.973, 0.976)]
        case .wet:
            return [.init(0.871, 0.902, 0.929), .init(0.953, 0.965, 0.976)]
        }
    }

    private static func dark(_ tone: SkyForecast.Tone?, _ isNight: Bool) -> [Preset] {
        guard let tone else { return [.init(0, 0, 0), .init(0, 0, 0)] }
        if isNight { return [.init(0.031, 0.043, 0.071), .init(0.008, 0.012, 0.020)] }
        switch tone {
        case .clear:
            return [.init(0.039, 0.086, 0.149), .init(0.012, 0.024, 0.047)]
        case .breaking:
            return [.init(0.078, 0.086, 0.098), .init(0.106, 0.075, 0.055)]
        case .mixed:
            return [.init(0.055, 0.075, 0.098), .init(0.020, 0.027, 0.035)]
        case .dull:
            return [.init(0.071, 0.075, 0.082), .init(0.035, 0.039, 0.043)]
        case .wet:
            return [.init(0.047, 0.071, 0.094), .init(0.020, 0.031, 0.039)]
        }
    }
}

extension SkyBackdrop.Preset {
    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.init(red: red, green: green, blue: blue)
    }
}

extension Color {
    init(_ preset: SkyBackdrop.Preset) {
        self.init(red: preset.red, green: preset.green, blue: preset.blue)
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(
            [SkyForecast.Tone.clear, .breaking, .mixed, .dull, .wet], id: \.rawValue
        ) { tone in
            ZStack {
                SkyBackdrop(tone: tone)
                HStack {
                    Text(tone.rawValue)
                        .font(.headline)
                    Text("본문 크기의 글자가 이 위에서 읽히는지")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
