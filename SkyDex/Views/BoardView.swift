import PhotosUI
import SwiftData
import SwiftUI

/// The board.
///
/// Every slot is drawn from the first launch as an open ring, faded to a hint
/// of the colour that time of day usually is. Capturing fills one in with the
/// colour you actually got, at full strength. So the shape of the day is there
/// from the start — where the dawn blues sit, where the sunset band begins —
/// and collecting is the act of bringing it up to strength.
///
/// The hint is doing one job: placing a colour. It is faded far enough that it
/// could never be mistaken for a sky someone went out and got, which is what a
/// board of ghosts and a board of photographs have to keep straight between
/// them.
///
/// Filling every slot does not end it and does not make the board finer. It
/// stays forty-eight. What changes instead is age: a slot fades as its photo
/// gets old, so a full board is something kept rather than something finished,
/// and one photo brings its slot back to full.
///
/// There is no text on it. Band names, clock ranges and a running count were
/// all saying what the colours already say — the top is night, it lightens
/// downward into day and darkens again at the bottom. Reading that off the
/// grid takes no words, and the words were competing with the only thing worth
/// looking at.
///
/// Which bead a sky fills is answered two ways, and the clock has the last
/// word. Anything in the collection fills a bead whose colour it is near enough
/// to — that is what makes the board a question about today. But a sky taken
/// today fills the bead for the half hour it was taken in no matter what colour
/// it came out, because the bead's colour was only ever a forecast and the
/// photo was actually there. An overcast four o'clock that the forecast had as
/// blue is not a miss; it is what four o'clock looked like, and the board says
/// so in the colour you got.
///
/// A slot is chosen by the clock, never by the user, and no photo is ever
/// turned away — the only thing a capture has to do is exist.
struct BoardView: View {
    /// The slot a capture just landed in, for one pulse. Owned by the shell,
    /// because the shell owns the camera.
    let landed: Int?

    /// Only ever read to work out when the sun rises and sets here.
    let place: Place

    /// Today's cloud and rain, when there is an answer.
    let weather: SkyWeather

    /// Set once, by the opening reveal. Owned by the shell so coming back from
    /// the archive does not replay it.
    @Binding var revealed: Bool

    /// Ascending, so building the map leaves the most recent capture in each
    /// slot: shooting the same half-hour again replaces the bead rather than
    /// being locked out by a first attempt you did not like.
    @Query(sort: \SkyEntry.capturedAt, order: .forward) private var entries: [SkyEntry]

    @State private var tappedEmpty: SkySlot?
    @State private var openedSlot: SkySlot?

    /// The bead under the finger right now. One gesture covers the whole board
    /// rather than a tap per bead, so a press can be dragged across the grid and
    /// the choice is made where the finger lifts.
    @State private var pressed: SkySlot?

    /// Bumped on every lift that opens something, only so the haptic has a value
    /// to fire on.
    @State private var opens = 0

    /// Matching every photo against today's forty-eight is done once per day,
    /// not once per frame. The cache is state so it survives the redraws.
    @State private var cache = SkyMatchCache()

    private let sidePadding: CGFloat = 16
    private let gap: CGFloat = 10

    /// Today's colour for one slot. Rebuilt rather than passed down, because a
    /// sheet outlives the frame that opened it.
    private func target(of slot: SkySlot) -> Lab {
        Lab(SkyDay(
            date: .now,
            latitude: place.latitude,
            longitude: place.longitude,
            forecast: weather.forecast
        ).colour(of: slot))
    }

    /// The whole board has to be visible at once — a board you scroll is a
    /// feed — so the bead size is whichever of the two axes runs out first.
    private func beadDiameter(in size: CGSize) -> CGFloat {
        let columns = CGFloat(SkyBoard.columns)
        let rows = CGFloat(SkyBoard.slots.count / SkyBoard.columns)
        let byWidth = (size.width - sidePadding * 2 - gap * (columns - 1)) / columns
        let byHeight = (size.height - 24 - gap * (rows - 1)) / rows
        return max(18, min(byWidth, byHeight))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { area in
                let diameter = beadDiameter(in: area.size)
                // The marked slot has to move with the clock, and so does the
                // fading, rather than waiting for something else to redraw.
                TimelineView(.periodic(from: .now, by: 60)) { clock in
                    // Rebuilt on the minute along with everything else, so a
                    // board left open overnight is drawing tomorrow's sun by
                    // morning.
                    let day = SkyDay(
                        date: clock.date,
                        latitude: place.latitude,
                        longitude: place.longitude,
                        forecast: weather.forecast
                    )
                    // Which of today's colours the collection already covers,
                    // plus whatever was shot today in each stretch of the clock.
                    let filled = cache.map(
                        targets: day.targets,
                        entries: entries,
                        on: clock.date,
                        key: [
                            ISO8601DateFormatter.string(
                                from: Calendar.current.startOfDay(for: clock.date),
                                timeZone: .current,
                                formatOptions: [.withFullDate]
                            ),
                            String(format: "%.2f,%.2f", place.latitude, place.longitude),
                            weather.forecast == nil ? "clear" : "forecast",
                            "\(entries.count)",
                            entries.last?.uuid.uuidString ?? "none"
                        ].joined(separator: "|")
                    )

                    // The bead a photo taken right now would fill. It used to be
                    // whichever of today's colours this minute's sky is nearest,
                    // back when a capture could only land by colour. Now a
                    // capture lands in the stretch of clock it was taken in, so
                    // the mark follows the clock — the ring is on the bead that
                    // is about to change, which is the only thing it was ever
                    // for.
                    let nowSlot = SkyBoard.slot(
                        forMinute: SkyEntry.minuteOfDay(of: clock.date)
                    ).id
                    let columns = CGFloat(SkyBoard.columns)
                    let rows = CGFloat(SkyBoard.slots.count / SkyBoard.columns)
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(diameter), spacing: gap),
                            count: SkyBoard.columns
                        ),
                        spacing: gap
                    ) {
                        ForEach(SkyBoard.slots) { slot in
                            let entry = filled[slot.id]
                            Bead(
                                slot: slot,
                                day: day,
                                entry: entry,
                                freshness: entry?.freshness(at: clock.date) ?? 0,
                                isNew: landed == slot.id,
                                isNow: slot.id == nowSlot,
                                isPressed: pressed?.id == slot.id,
                                diameter: diameter
                            )
                            // The board assembles itself once, a row at a time
                            // rather than all at once, because forty-eight
                            // beads arriving together is a flash and forty-eight
                            // arriving in sequence is a board being laid out.
                            .opacity(revealed ? 1 : 0)
                            .scaleEffect(revealed ? 1 : 0.72)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.72)
                                    .delay(Double(slot.id) * 0.008),
                                value: revealed
                            )
                        }
                    }
                    // Sized exactly, so the gesture's own coordinates are the
                    // grid's and a point can be turned into a slot by arithmetic
                    // instead of by asking forty-eight views where they are.
                    .frame(
                        width: columns * diameter + (columns - 1) * gap,
                        height: rows * diameter + (rows - 1) * gap
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { pressed = SkyBoard.slot(at: $0.location, diameter: diameter, gap: gap) }
                            .onEnded { touch in
                                let landing = SkyBoard.slot(at: touch.location, diameter: diameter, gap: gap)
                                pressed = nil
                                // Lifting off the board chooses nothing, which is
                                // how a press is taken back.
                                guard let landing else { return }
                                if filled[landing.id] == nil {
                                    tappedEmpty = landing
                                } else {
                                    openedSlot = landing
                                }
                                opens += 1
                            }
                    )
                    // A tick as each bead is passed, the way a picker tells you
                    // it moved, and a knock on the one you keep.
                    .sensoryFeedback(trigger: pressed?.id) { _, new in
                        new == nil ? nil : .selection
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: opens)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                place.refresh()
                if !revealed { revealed = true }
                await weather.refresh(latitude: place.latitude, longitude: place.longitude)
            }
            // The first fix usually lands after the board is already up, and a
            // forecast for the wrong city is worth replacing.
            .onChange(of: place.latitude) { _, latitude in
                Task { await weather.refresh(latitude: latitude, longitude: place.longitude) }
            }
            // Full screen, not a sheet. A collected sky is the content of this
            // app, and content does not arrive as a card over the thing you were
            // doing.
            .fullScreenCover(item: $openedSlot) { slot in
                TimelineFeedView(slot: slot, target: target(of: slot))
            }
            // This one stays a sheet: it is a note about a slot, not a sky.
            .sheet(item: $tappedEmpty) { slot in
                EmptySlotSheet(slot: slot, place: place, weather: weather)
            }
        }
    }
}

/// One slot.
///
/// Collected and not collected are told apart twice over: a captured sky is a
/// solid disc, an empty one an open ring, and the disc carries the colour at
/// full strength while the ring only hints at it. Shape has to be there —
/// a pale overcast noon and the pale noon reference are nearly the same blue,
/// and no amount of fading separates those reliably. Strength has to be there
/// too — a ring alone is easy to lose on a busy board. Diameter is deliberately
/// not used, so the board stays an even grid.
///
/// A bead under a finger grows. The board is a grid of small targets and a thumb
/// covers whichever one it is on, so the one being chosen has to be readable
/// around the thumb rather than under it.
///
/// The slot the clock is currently in wears a second ring outside itself, and
/// that is all it gets. It is the bead a photo taken this minute would fill, so
/// the ring is a pointer at the one thing on the board that is about to change.
/// It used to keep its colour undimmed as well, from back
/// when every other empty slot was grey and this was the only place a colour
/// could be read off the board. Now that every empty ring carries its own faded
/// sky, that treatment was saying a thing the neighbours already said, in the
/// one way guaranteed to be misread: a single saturated bead among faint ones
/// looks selected, not current.
///
/// So colour on the board means exactly two things now. Strong is collected,
/// faint is not yet. Where you are is a question of shape.
///
/// A collected bead is drawn at the age of its photo. Fresh for a week, then
/// slowly toward the colour the slot has when empty, though never all the way —
/// a stale slot has to keep saying it was collected. Nothing is lost when a bead
/// goes quiet, and shooting that time of day again brings it straight back.
private struct Bead: View {
    let slot: SkySlot
    let day: SkyDay
    let entry: SkyEntry?
    let freshness: Double
    let isNew: Bool
    let isNow: Bool
    let isPressed: Bool
    let diameter: CGFloat

    private var ringWidth: CGFloat { max(3, diameter * 0.17) }

    var body: some View {
        ZStack {
            if let entry {
                Circle()
                    .fill(Color(SkyBoard.faded(entry.rgb, freshness: freshness)))
                    // Grows out of the ring it replaces. A slot going from empty
                    // to collected is the only thing that happens on this
                    // screen, and it should look like something happening.
                    .transition(.scale(scale: 0.55).combined(with: .opacity))
            } else {
                Circle()
                    .strokeBorder(Color(day.ghost(of: slot)), lineWidth: ringWidth)
                    .transition(.opacity)
            }
        }
        .frame(width: diameter, height: diameter)
        // Keyed to what actually changed, so the minute tick that redraws the
        // whole board does not animate forty-eight beads that stayed put.
        .animation(.spring(response: 0.42, dampingFraction: 0.7), value: entry?.uuid)
        .overlay {
            // Sits outside the bead and laps over the gap into its neighbours,
            // so the current slot is findable at a glance on a full board.
            // It fades rather than jumping when the clock moves it along.
            if isNow {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                    .frame(width: diameter + 11, height: diameter + 11)
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            }
        }
        .overlay { if isNew { Circle().strokeBorder(.white, lineWidth: 2.5) } }
        // Grows under the finger so the thing being chosen is visible past the
        // thumb covering it.
        .scaleEffect(isPressed ? 1.3 : (isNew ? 1.14 : 1))
        .zIndex(isPressed ? 3 : (isNew ? 2 : (isNow ? 1 : 0)))
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isNew)
        .contentShape(Circle())
    }
}

/// What an empty slot says when tapped. It states the rule and stops — the one
/// thing it must not do is suggest the slot is overdue.
private struct EmptySlotSheet: View {
    let slot: SkySlot
    let place: Place
    let weather: SkyWeather

    @Environment(\.dismiss) private var dismiss

    /// Today's sky here. A sheet is open for a moment, so it does not need to
    /// follow the clock the way the board does.
    private var day: SkyDay {
        SkyDay(
            date: .now,
            latitude: place.latitude,
            longitude: place.longitude,
            forecast: weather.forecast
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Faded, like the bead that was tapped. Its full strength is
                // on the swatch further down, next to the hex.
                Circle()
                    .strokeBorder(Color(day.ghost(of: slot)), lineWidth: 16)
                    .frame(width: 96, height: 96)

                VStack(spacing: 6) {
                    Text(slot.timeLabel)
                        .font(.title3.weight(.medium))
                        .monospacedDigit()
                    Text("\(slot.band) · 아직 비어 있음")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("이 자리는 그 시간대에 찍은 하늘로 채워집니다. 어떤 사진이든 그대로 들어가고, 색이 맞아야 할 필요는 없습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(day.colour(of: slot)))
                        .frame(width: 22, height: 22)
                    // The wording has to match what the swatch is actually
                    // showing. With a forecast in hand this is today's sky, not
                    // the sky in general, and saying "보통" would be a lie.
                    Text(
                        weather.forecast == nil
                            ? "이 시각의 하늘은 보통 \(day.colour(of: slot).hex)"
                            : "오늘 이 시각은 대략 \(day.colour(of: slot).hex)"
                    )
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
                }

                // Apple's terms for using the forecast: name the service and
                // link its legal page wherever the data shows up. This sheet is
                // the only place in the app with words in it, so the credit
                // lives here rather than on the board.
                if let legal = weather.legalPageURL {
                    Link(destination: legal) {
                        Text("예상 하늘색 · Apple Weather")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(380)])
    }
}

#Preview {
    BoardView(
        landed: nil,
        place: Place(),
        weather: SkyWeather(),
        revealed: .constant(true)
    )
        .modelContainer(for: SkyEntry.self, inMemory: true)
}
