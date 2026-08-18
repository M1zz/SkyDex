import PhotosUI
import SwiftData
import SwiftUI
import TipKit

/// Which of the two screens is showing.
enum Screen {
    case board
    case archive

    var other: Screen { self == .board ? .archive : .board }
}

/// The shell.
///
/// There is no tab bar. One bar sits at the bottom of both screens with the same
/// two controls in the same two places — take a sky, and go to the other screen
/// — so the button you press to switch is still under your thumb when you
/// arrive. A tab bar was saying the same thing twice: it named the screen you
/// were already looking at, while the bar above it already offered the only
/// other place to be.
///
/// Capture lives here rather than on the board, because the button that starts
/// it is now on both screens. A capture made from the archive still lands on the
/// board, which is the only place a slot exists.
struct RootView: View {
    @Environment(\.modelContext) private var context

    @State private var screen: Screen = .board
    @State private var place = Place()
    @State private var weather = SkyWeather()
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var pickerItem: PhotosPickerItem?

    /// The slot a capture just landed in, held long enough for one pulse.
    @State private var landed: Int?

    /// Today's forecast, boiled down to the one sentence worth saying. Nil when
    /// there is no forecast, or when the day has nothing left to plan.
    private var insight: SkyInsight? {
        guard let forecast = weather.forecast else { return nil }
        let day = SkyDay(
            date: .now,
            latitude: place.latitude,
            longitude: place.longitude,
            forecast: forecast
        )
        return SkyInsight.today(forecast: forecast, sun: day.sun)
    }

    /// The sky just taken, held while its card is open. A line about a sky is
    /// worth most while you are still standing under it, so the card comes to
    /// you rather than waiting to be found on the board.
    @State private var writingCard: SkyEntry?

    /// Whether the board has already done its one opening reveal. Held here
    /// rather than in `BoardView`, which is rebuilt every time you come back
    /// from the archive — a reveal that replays on every visit is a stutter.
    @State private var boardRevealed = false

    /// The sky currently laid under the board, if any. Held here rather than in
    /// `BoardView` because the bar draws over it and has to know whether it is
    /// standing on paper or on a photograph.
    @State private var reading: ReadingSky?

    var body: some View {
        ZStack {
            // The archive lives to the right of the board, so it arrives from
            // the right and leaves the same way. Without that the two screens
            // just replace each other and there is nothing to tell you whether
            // you went somewhere or came back.
            switch screen {
            case .board:
                BoardView(
                    landed: landed,
                    place: place,
                    weather: weather,
                    revealed: $boardRevealed,
                    reading: $reading
                )
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .archive:
                ArchiveView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: screen)
        // A photograph laid under the board belongs to the board. Leaving it up
        // behind the archive, or waiting under it for the trip back, would make
        // it a mode rather than something you are looking at.
        .onChange(of: screen) { _, _ in reading = nil }
        // The bar sits outside the transition and does not move. It is the one
        // thing on screen that is in the same place before and after.
        .safeAreaInset(edge: .bottom) { bar }
        .fullScreenCover(isPresented: $showCamera) {
            SquareCameraView(
                onCapture: { data, date in save(data, at: date) },
                onPickFromLibrary: {
                    // Presenting a picker while the full-screen cover is still
                    // animating away silently does nothing.
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        showLibrary = true
                    }
                }
            )
        }
        .fullScreenCover(item: $writingCard) { entry in
            PhotoDetailView(entry: entry)
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadFromLibrary(item) }
        }
    }

    /// A shutter and a switch, on the same paper as the screen behind them.
    ///
    /// No material and no bar of its own. `.bar` was a holdover from having a tab
    /// bar underneath, and all it did once that left was draw a seam across a
    /// board that is meant to be one field of colour.
    ///
    /// The shutter is round and carries no label. "하늘 찍기" was explaining a
    /// camera glyph on the one screen where taking a photo is the only thing to
    /// do, and a circle is the shape this whole app is made of.
    private var bar: some View {
        Button {
            showCamera = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 25, weight: .medium))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(BarButton(prominent: true))
        .accessibilityLabel("하늘 찍기")
        // Points at the button it is about, and only when the forecast actually
        // has something to say.
        .popoverTip(ifPresent: insight.map(TodaysSkyTip.init))
        .frame(maxWidth: .infinity)
        // An overlay rather than a third item in a row, so the shutter stays on
        // the centre line and does not shift when the switch changes icon.
        .overlay(alignment: .trailing) {
            Button {
                screen = screen.other
            } label: {
                Image(systemName: screen == .board ? "list.bullet" : "circle.grid.3x3.fill")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(BarButton(prominent: false))
            .accessibilityLabel(screen == .board ? "기록" : "하늘")
            // The glyph changes at the moment the screens cross over, so it
            // turns over rather than blinking.
            .contentTransition(.symbolEffect(.replace))
        }
        // The shutter knocks, the switch ticks. Both are answers to a press
        // rather than decoration: the camera takes a moment to appear and the
        // screens cross over, and neither is instant enough to feel like a
        // button on its own.
        .sensoryFeedback(trigger: showCamera) { _, opening in
            opening ? .impact(weight: .medium) : nil
        }
        .sensoryFeedback(.selection, trigger: screen)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .background {
            // The page's own colour, faded upward. On the board this is
            // invisible — it is the same paper — and on the archive it stops
            // rows from sliding out from under the buttons as the list scrolls.
            // A material would do the same job, at the cost of drawing a seam
            // across a board that is meant to be one field of colour.
            LinearGradient(
                // With a sky laid under the board the page is a photograph, and
                // fading it into white at the bottom would draw the seam this
                // gradient exists to avoid. It fades into the dark instead.
                colors: reading == nil
                    ? [Color(.systemBackground).opacity(0), Color(.systemBackground)]
                    : [.black.opacity(0), .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Saving

    private func loadFromLibrary(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        save(data, at: .now)
    }

    private func save(_ data: Data, at date: Date) {
        let prepared = SkyImage.prepare(data: data)
        let grey = RGB(r: 0.5, g: 0.5, b: 0.5)
        let colour: (rgb: RGB, lab: Lab) = prepared
            .map { SkyColorExtractor.skyColor(from: $0.square) } ?? (grey, Lab(grey))

        let entry = SkyEntry(
            capturedAt: date,
            rgb: colour.rgb,
            lab: colour.lab,
            photoData: prepared?.photo,
            thumbnailData: prepared?.thumbnail
        )
        context.insert(entry)

        // A capture taken from the archive has no bead to pulse, so go and show
        // the board it just landed on.
        screen = .board
        // And it lands on the board itself, not under whatever was being read.
        reading = nil

        // The bead that lights up is the one this sky was taken in. It used to
        // be a colour question — whichever of today's colours this sky was
        // nearest, and nothing at all if none of them were near enough — which
        // meant a photo of a sky the forecast had got wrong went into the
        // collection with nowhere to pulse. A sky taken now is what now looks
        // like, so it fills its own half hour and there is always somewhere.
        //
        // Only for a sky taken today, which is every sky the app can take right
        // now. A photo brought in from an older day is still a colour question,
        // and pulsing a bead it did not fill would be a lie the moment library
        // imports start carrying their own date.
        let landing = Calendar.current.isDateInToday(date)
            ? SkyBoard.slot(forMinute: SkyEntry.minuteOfDay(of: date)).id
            : nil

        landed = landing
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if landed == landing {
                withAnimation(.easeOut(duration: 0.3)) { landed = nil }
            }
        }

        Task {
            // The camera is still animating away, and presenting into that does
            // nothing at all.
            try? await Task.sleep(for: .milliseconds(450))
            writingCard = entry
        }
    }
}

/// Round, and it gives when pressed.
///
/// `.borderedProminent` draws the right thing but says nothing back to a thumb,
/// and the shutter is the one action this app exists for. Both controls in the
/// bar use this so they answer the same way.
private struct BarButton: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(Color.accentColor))
            .background {
                Circle().fill(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary))
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

#Preview {
    RootView()
        .modelContainer(for: SkyEntry.self, inMemory: true)
}
