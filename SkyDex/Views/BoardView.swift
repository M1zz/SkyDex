import PhotosUI
import SwiftData
import SwiftUI
import WidgetKit

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
/// There is no text on it until you ask for some. Band names, clock ranges and
/// a running count were all saying what the colours already say — the top is
/// night, it lightens downward into day and darkens again at the bottom.
/// Reading that off the grid takes no words, and the words were competing with
/// the only thing worth looking at.
///
/// Pressing a collected bead is the asking. The photograph goes under the whole
/// board, the rest of the beads go quiet, and the name of that colour — 담자색,
/// where the name comes from, one line of what it means — is written on it.
/// Nothing opens and nothing is covered; the same press again puts it away.
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

    /// Set once, by the opening reveal. Owned by the shell so coming back from
    /// the archive does not replay it.
    @Binding var revealed: Bool

    /// The sky being read right now — its photograph is under the board and its
    /// name is on it. Owned by the shell, because the bar at the bottom has to
    /// know whether it is standing on paper or on a photograph.
    @Binding var reading: ReadingSky?

    /// Ascending, so building the map leaves the most recent capture in each
    /// slot: shooting the same half-hour again replaces the bead rather than
    /// being locked out by a first attempt you did not like.
    @Query(sort: \SkyEntry.capturedAt, order: .forward) private var entries: [SkyEntry]

    @State private var tappedEmpty: SkySlot?
    @State private var openedSlot: SkySlot?

    /// The card for the sky being read, when it is asked for by name.
    @State private var writingCard: SkyEntry?

    /// The bead under the finger right now. One gesture covers the whole board
    /// rather than a tap per bead, so a press can be dragged across the grid and
    /// the choice is made where the finger lifts.
    @State private var pressed: SkySlot?

    /// Bumped on every lift that opens something, only so the haptic has a value
    /// to fire on.
    @State private var opens = 0

    /// Bumped every time the app comes back to the front, only so the timeline
    /// has a value to be rebuilt on.
    @State private var returns = 0

    @Environment(\.scenePhase) private var scenePhase

    /// What was last left out for the widgets, so an answer that has not changed
    /// is not written again and the home screen is not asked to redraw for
    /// nothing.
    @State private var published: String?

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
            longitude: place.longitude
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

    /// Put a sky up, or put it away.
    private func show(_ sky: ReadingSky?) {
        withAnimation(.easeOut(duration: sky == nil ? 0.25 : 0.34)) {
            reading = sky
        }
    }

    /// The photograph, laid under the board.
    ///
    /// Pressing a bead used to throw a full screen over the board, and the board
    /// is the picture of the day — covering it to look at one sky in it threw the
    /// day away, and the way back was a button labelled 닫기. So the sky comes up
    /// *behind* the beads instead. The rest of the board steps back to a fifth of
    /// its strength, the bead you pressed stays exactly where it is with a white
    /// ring on it, and you are still on the same screen. Anywhere you press next
    /// is either another sky or the way out.
    ///
    /// The dark over it is not decoration. Beads are drawn in the colours of the
    /// sky and the photograph underneath is a sky, so without it a pale bead on a
    /// pale cloud disappears; the words could not be white either.
    private func backdrop(_ sky: ReadingSky) -> some View {
        ZStack {
            Group {
                if let image = sky.entry.photo {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(sky.entry.rgb)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Color.black.opacity(0.24)

            // Words stand at both ends now — the line you wrote at the top, the
            // name of the colour at the bottom — so both ends are weighted and
            // the middle, where the board is, is left alone.
            LinearGradient(
                colors: [.black.opacity(0.5), .clear, .clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // The board's own gesture only covers the grid; this catches the rest.
        .onTapGesture { show(nil) }
        .transition(.opacity)
    }

    /// The line you wrote, at the top of the sky you wrote it about.
    ///
    /// It was on the card, behind two taps, in the same size as everything else
    /// on it. A sentence written while standing under a sky is the one thing on
    /// this screen that no measurement produced, so when that sky is up it is the
    /// first thing on it and the largest — above the board, on the photograph,
    /// in the reading size rather than the caption size.
    ///
    /// Nothing is drawn when nothing was written. An empty slot where a prompt
    /// could go would turn a board you look at into a form you have not finished.
    ///
    /// It arrives as a speech bubble that types itself out. The line is the one
    /// thing on this screen a person said rather than something the app worked
    /// out, and watching it come back a character at a time is the difference
    /// between reading a record and hearing it again — the sentence is being
    /// said to you, under the sky it was said about.
    @ViewBuilder
    private func written(_ sky: ReadingSky) -> some View {
        if !sky.entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            WrittenBubble(entry: sky.entry)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .contentShape(Rectangle())
                // Your own words are the way back to where you wrote them.
                .onTapGesture { writingCard = sky.entry }
                .transition(.opacity.combined(with: .offset(y: -10)))
        }
    }

    /// What this sky is called, on the board.
    ///
    /// It leads with what the colour is *like* — 물에 젖은 청바지색, 쌀뜨물색, 떡볶이
    /// 국물색 — because that is the part a person can see without a swatch in front
    /// of them. The sourced name follows in small type: more precise, less
    /// visible, and worth keeping for exactly that reason. Whether either is
    /// this sky's own or merely the nearest is said out loud rather than rounded
    /// away, the same as on the card.
    ///
    /// It is also the way in to the card itself, since the bead no longer opens
    /// anything: the block is a button, with the chevron to say so.
    private func caption(_ sky: ReadingSky) -> some View {
        let like = SkySimiles.nearest(to: sky.entry.lab)
        let named = SkyNames.nearest(to: sky.entry.lab)
        let sameColour = SkyMatch.all(
            near: target(of: sky.slot),
            in: entries,
            filling: sky.slot,
            on: .now
        ).count

        return VStack(alignment: .leading, spacing: 5) {
            Text(like.isClose ? "말로 하면" : "굳이 말하자면")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(like.simile.name)
                    .font(.title2.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .foregroundStyle(.white)

            Text(like.simile.note)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            // The word with a source behind it, kept but demoted. The picture
            // is what a person reads at a glance; the name is what they go
            // looking for later.
            HStack(spacing: 5) {
                Text(named.isClose ? "이름은" : "가장 가까운 이름은")
                Text(named.name.name)
                Text(named.name.origin.rawValue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.white.opacity(0.14), in: Capsule())
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.66))
            .padding(.top, 2)

            HStack(spacing: 6) {
                Text(sky.entry.capturedAt, format: .dateTime.month().day().hour().minute())
                Text("·")
                Text(sky.slot.band)
                Text("·")
                Text(sky.entry.hex)
                    .monospaced()
                if sameColour > 1 {
                    Text("·")
                    // The bead holds more than the one sky showing. The list is
                    // asked for by name rather than by pressing the bead, which
                    // now answers here.
                    Button("이 색 \(sameColour)장") { openedSlot = sky.slot }
                        .buttonStyle(.plain)
                        .underline()
                }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.62))
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        // The board runs under the bar, so words at the bottom have to stand
        // clear of the shutter rather than trust the layout to do it.
        .padding(.bottom, 88)
        // Ground for the words, drawn over the beads.
        //
        // The grid is six across and eight down, so on a phone it fills nearly
        // the whole screen and the "space below the board" these words were
        // meant to sit in is not there. They landed on top of the bottom three
        // rows instead, with rings running straight through the sentence and
        // the pressed bead — white, the loudest thing on the screen — sitting
        // beside the colour's name like a second control.
        //
        // The backdrop already fades to dark at the bottom, but that fade is
        // *under* the beads and cannot separate anything from them. This one is
        // over them: the rows behind the words step back into the dark, the
        // words are on a surface, and the block reads as one thing you can
        // press rather than several overlapping ones.
        .background {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.45), location: 0.35),
                    .init(color: .black.opacity(0.88), location: 0.62),
                    .init(color: .black.opacity(0.94), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Reaching above the words, so the rows fade out before the
            // sentence starts rather than at it. A fade that begins exactly
            // where the text begins draws a line across the board.
            .padding(.top, -90)
            // And past the bottom of the screen. The photograph behind runs
            // under the home indicator and under the bar, and this does not
            // unless it is told to — which left a bright strip of sky below the
            // dark, reading as a second picture cut off along the bottom edge.
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { writingCard = sky.entry }
        .accessibilityElement(children: .combine)
        .accessibilityHint("한 줄 쓰기")
        .transition(.opacity.combined(with: .offset(y: 10)))
    }

    /// Leave today's board where the widgets can read it.
    ///
    /// Everything a widget would have to be trusted with — the store, the
    /// photos, the place — is spent here instead, while the app is
    /// awake and allowed to. What crosses over is a list of colours and one
    /// thumbnail.
    ///
    /// Only the sky taken today goes across. The board is happy to draw a photo
    /// from March in a slot it fits, but a widget that says 오늘의 하늘 has made a
    /// claim about today, and an old photo under that heading is a lie however
    /// good the colour match is.
    private func publish() {
        let now = Date.now
        let today = Calendar.current.startOfDay(for: now)
        let last = entries.last { Calendar.current.isDateInToday($0.capturedAt) }

        // Cheap to compute, expensive to write: this is the whole reason to
        // check rather than publish on every redraw.
        let signature = [
            ISO8601DateFormatter.string(from: today, timeZone: .current, formatOptions: [.withFullDate]),
            String(format: "%.2f,%.2f", place.latitude, place.longitude),
            "\(entries.count)",
            last?.uuid.uuidString ?? "none",
            last?.note ?? ""
        ].joined(separator: "|")
        guard signature != published else { return }

        let day = SkyDay(
            date: now,
            latitude: place.latitude,
            longitude: place.longitude
        )
        let fills = SkyMatch.map(targets: day.targets, entries: entries, on: now)
            .map { slot, entry in
                SkySnapshot.Fill(
                    slot: slot,
                    hex: SkyBoard.faded(entry.rgb, freshness: entry.freshness(at: now)).hex
                )
            }
            .sorted { $0.slot < $1.slot }

        let latest = last.map { entry -> SkySnapshot.Latest in
            let like = SkySimiles.nearest(to: entry.lab)
            return SkySnapshot.Latest(
                hex: entry.hex,
                capturedAt: entry.capturedAt,
                slot: SkyBoard.slot(forMinute: entry.minuteOfDay).id,
                note: entry.note,
                likeness: like.simile.name,
                likenessNote: like.simile.note,
                isCloseLikeness: like.isClose,
                hasPhoto: entry.thumbnailData != nil
            )
        }

        SkySnapshot.write(
            SkySnapshot(
                day: today,
                targets: SkyBoard.slots.map { day.colour(of: $0).hex },
                filled: fills,
                latest: latest
            ),
            photo: last?.thumbnailData
        )
        published = signature
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some View {
        NavigationStack {
            GeometryReader { area in
                let diameter = beadDiameter(in: area.size)
                // The marked slot has to move with the clock, and so does the
                // fading, rather than waiting for something else to redraw.
                //
                // On the minute, not every sixty seconds. `.periodic(from: .now,
                // by: 60)` counts from whenever the board happened to open, so a
                // board opened at 21:00:47 updated at 21:01:47, 21:02:47, and
                // moved the ring to the 21:30 bead at 21:30:47 — up to a minute
                // after the slot it points at had ended. And `from: .now` is
                // read again every time this body runs, so a forecast arriving
                // or a capture landing re-anchored that offset to some new
                // arbitrary second. `.everyMinute` fires on the minute boundary
                // itself, which is where a clock changes.
                TimelineView(.everyMinute) { clock in
                    // Rebuilt on the minute along with everything else, so a
                    // board left open overnight is drawing tomorrow's sun by
                    // morning.
                    let day = SkyDay(
                        date: clock.date,
                        latitude: place.latitude,
                        longitude: place.longitude
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
                                isRead: reading?.slot.id == slot.id,
                                isDimmed: reading != nil && reading?.slot.id != slot.id,
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
                                if let entry = filled[landing.id] {
                                    // The same bead twice puts it away, which is
                                    // the only way out that needs no target.
                                    show(reading?.slot.id == landing.id
                                        ? nil
                                        : ReadingSky(slot: landing, entry: entry))
                                } else if reading != nil {
                                    // Anywhere else on the board is a way out.
                                    // Answering an empty slot with a sheet on top
                                    // of a photograph would be two things at once.
                                    show(nil)
                                } else {
                                    tappedEmpty = landing
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
                // A schedule does not run while the app is away, so the board
                // you come back to was drawn whenever you left. Coming back is
                // exactly when a person looks at the ring, so the timeline is
                // rebuilt then and reads the clock again on the spot rather than
                // waiting for its next minute to come round.
                .id(returns)
                // Behind the beads rather than over them, and it reaches past
                // every edge — under the status bar and under the shutter — so
                // it reads as the page the board is drawn on rather than as a
                // panel that opened.
                .background {
                    if let reading {
                        backdrop(reading)
                    }
                }
                // What you wrote is the top of the screen and the name of the
                // colour is the bottom of it. Both sit clear of the grid — the
                // board is square and the screen is not, so the space above and
                // below the beads is exactly where words can go without
                // covering one.
                .overlay(alignment: .top) {
                    if let reading {
                        written(reading)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let reading {
                        caption(reading)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                place.refresh()
                if !revealed { revealed = true }
                publish()
            }
            .onChange(of: entries.count) { _, _ in publish() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    returns += 1
                    // A day may have turned over while the app was away, and
                    // the widget is the only thing that was still on screen.
                    publish()
                } else {
                    // Leaving is the moment the widget starts mattering, so
                    // whatever was just written or taken goes across now rather
                    // than the next time the app is opened.
                    publish()
                }
            }
            // A line written on a card is part of what the widget shows, and it
            // is written after the photo already landed.
            .onChange(of: writingCard == nil) { _, closed in
                if closed { publish() }
            }
            // The first fix usually lands after the board is already up, and
            // the sun's schedule here is what the whole curve hangs on: until
            // it arrives the board is drawing the fallback city's day.
            .onChange(of: place.latitude) { _, _ in publish() }
            // Every sky this bead's colour holds, which is a list and is asked
            // for by name from the caption. The bead itself no longer opens it:
            // pressing a bead answers on the board now.
            .fullScreenCover(item: $openedSlot) { slot in
                TimelineFeedView(slot: slot, target: target(of: slot))
            }
            .fullScreenCover(item: $writingCard) { entry in
                PhotoDetailView(entry: entry)
            }
            // This one stays a sheet: it is a note about a slot, not a sky.
            .sheet(item: $tappedEmpty) { slot in
                EmptySlotSheet(slot: slot, place: place)
            }
        }
    }
}

/// One line, in a bubble, typed back out.
///
/// The typing is not decoration. A note is written in a moment that is already
/// gone by the time it is read again, and a sentence that appears whole reads
/// like a caption the app attached. Coming in a character at a time makes it a
/// person talking, which is what it is.
///
/// It is paced rather than fixed: about thirty milliseconds a character, and the
/// whole line is capped at a second and a half however long it runs. A long note
/// typed at a comfortable speed becomes a thing you have to wait out, and waiting
/// is exactly what a board you glance at cannot ask for. Anyone who does not want
/// to wait can tap it — the card opens with the whole line in it.
///
/// Reduce Motion gets the sentence whole, immediately. The animation is the
/// point of this view and it is still the first thing to go.
private struct WrittenBubble: View {
    let entry: SkyEntry

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How many characters are out so far.
    @State private var typed = 0

    private var characters: [Character] { Array(entry.note) }

    private var shown: String { String(characters.prefix(typed)) }

    private var isTyping: Bool { typed < characters.count }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            bubble
            // Never the full width. A bubble that reaches both edges is a
            // banner, and a banner is not something anybody said.
            Spacer(minLength: 44)
        }
        .task(id: entry.uuid) { await type() }
    }

    private var bubble: some View {
        Group {
            // The caret is part of the text rather than next to it, so it sits
            // wherever the last character landed and wraps with the line.
            Text(shown) + Text(isTyping ? "▏" : "").foregroundColor(.white.opacity(0.7))
        }
        .font(.title2.weight(.medium))
        .lineSpacing(4)
        .foregroundStyle(.white)
        .lineLimit(4)
        .fixedSize(horizontal: false, vertical: true)
        .frame(alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12 + WrittenBubble.tail.height)
        .background {
            SpeechBubble().fill(WrittenBubble.blue)
        }
        // The bubble grows as the line fills it, which is the other half of
        // watching something be written.
        .animation(.easeOut(duration: 0.14), value: typed)
    }

    static let tail = CGSize(width: 15, height: 9)

    /// The blue a sent message is.
    ///
    /// Fixed rather than `.systemBlue`, which is two different colours depending
    /// on the appearance the phone is in. This bubble is always on a photograph
    /// with white text in it, so it is always in the dark whatever the phone
    /// thinks, and a blue that shifts under it would be answering a question
    /// nobody asked.
    ///
    /// Opaque, with nothing over or under it. The glass it used to be — dark
    /// fill over a material, with a hairline to find its edge — existed to stay
    /// legible on a photograph without becoming the loudest thing on the screen.
    /// A blue bubble gives that up on purpose: it is the one thing on this
    /// screen a person said, and a message is allowed to look like a message.
    static let blue = Color(red: 0.11, green: 0.53, blue: 1)

    private func type() async {
        guard !characters.isEmpty else { return }
        guard !reduceMotion else {
            typed = characters.count
            return
        }
        typed = 0
        let step = min(30, max(8, 1_500 / characters.count))
        for index in characters.indices {
            try? await Task.sleep(for: .milliseconds(step))
            guard !Task.isCancelled else { return }
            typed = index + 1
        }
    }
}

/// A rounded rectangle with a tail on the bottom left.
///
/// The tail points down, at the board — the sentence belongs to the sky under
/// it, not to the app that is drawing it.
private struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let tail = WrittenBubble.tail
        let body = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - tail.height)
        let rounded = Path(roundedRect: body, cornerRadius: 20, style: .continuous)

        // Clear of the corner. A continuous corner of radius 20 is still curving
        // some thirty points in from the edge, and a tail rooted inside that
        // curve does not grow out of the bubble — its top corner hangs off the
        // outline with daylight behind it.
        let start = min(38, max(30, rect.width * 0.1))
        var point = Path()
        point.move(to: CGPoint(x: start, y: body.maxY - 6))
        point.addLine(to: CGPoint(x: start + tail.width, y: body.maxY - 6))
        point.addLine(to: CGPoint(x: start + 3, y: rect.maxY))
        point.closeSubpath()

        // One outline rather than two shapes stacked. Two subpaths fill as their
        // union, so the shape looked right — but the stroke draws every subpath
        // it is given, which put two hairlines across the mouth of the tail: the
        // body's own bottom edge, and the tail's top edge six points under it.
        // At half a point each on a dark bubble that reads as a seam rather than
        // as a mistake, which is exactly why it survived this long.
        return rounded.union(point)
    }
}

/// A sky held up: which bead was pressed, and what is behind it.
///
/// The slot comes along with the photo because the words under it are about the
/// place on the board as much as the sky — what time of day this is, and how
/// many other skies the same bead holds.
struct ReadingSky: Identifiable, Equatable {
    let slot: SkySlot
    let entry: SkyEntry

    var id: Int { slot.id }

    static func == (lhs: ReadingSky, rhs: ReadingSky) -> Bool {
        lhs.slot == rhs.slot && lhs.entry.uuid == rhs.entry.uuid
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

    /// This is the sky currently laid under the board.
    let isRead: Bool

    /// Some other bead is, and this one steps back — far enough that the
    /// photograph is what you are looking at, not so far that the board stops
    /// being there. The day still has to be readable behind one sky in it.
    let isDimmed: Bool

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
        .overlay { if isNew || isRead { Circle().strokeBorder(.white, lineWidth: 2.5) } }
        // A bead whose sky is up keeps its full colour and grows a little; every
        // other one goes quiet. The board is still there, just underneath.
        .opacity(isDimmed ? 0.45 : 1)
        .animation(.easeOut(duration: 0.3), value: isDimmed)
        // Grows under the finger so the thing being chosen is visible past the
        // thumb covering it.
        .scaleEffect(isPressed ? 1.3 : (isNew ? 1.14 : (isRead ? 1.22 : 1)))
        .zIndex(isPressed ? 4 : (isNew ? 3 : (isRead ? 2 : (isNow ? 1 : 0))))
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isNew)
        .animation(.spring(response: 0.34, dampingFraction: 0.7), value: isRead)
        .contentShape(Circle())
    }
}

/// What an empty slot says when tapped. It states the rule and stops — the one
/// thing it must not do is suggest the slot is overdue.
private struct EmptySlotSheet: View {
    let slot: SkySlot
    let place: Place

    @Environment(\.dismiss) private var dismiss

    /// Today's sky here. A sheet is open for a moment, so it does not need to
    /// follow the clock the way the board does.
    private var day: SkyDay {
        SkyDay(
            date: .now,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }

    /// What a clear sky here does to this half hour, in one sentence.
    ///
    /// The app has no weather in it, so this is not a claim about today. It is
    /// this place's sun on this date and nothing else, and it says so — dressing
    /// the curve up as a forecast would be inventing weather the app never had.
    ///
    /// The colour is named rather than printed. Nobody standing under a sky can
    /// check a hex code against it, and the app already keeps a table of colours
    /// in words for that reason. Whether the name is a fit or merely the nearest
    /// one is said out loud, the same way the rest of the app says it.
    private var clearSkyLine: String {
        let like = SkySimiles.nearest(to: Lab(day.clearSkyColour(of: slot)))
        let colour = like.isClose ? like.simile.name : "굳이 말하자면 \(like.simile.name)"
        return "구름 없는 날이라면 이 시각 하늘은 \(colour)입니다. 흐리거나 비가 오는 날은 이보다 회색에 가깝습니다."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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

                // The colour has a name whether or not anyone has photographed
                // it yet, and an empty slot is exactly where you would want to
                // know what you are going out to look for. The swatch is here
                // at full strength — the ring at the top of the sheet is faded
                // like the bead that was tapped, which is the wrong thing to
                // hold a name up against.
                //
                // No hex. A person standing under a sky cannot check a number
                // against it, and this app already keeps a table of colours in
                // words for exactly that reason. The hex belongs on a photograph
                // that has one, not on a colour somebody is going out to find.
                VStack(spacing: 10) {
                    let like = SkySimiles.nearest(to: Lab(day.colour(of: slot)))

                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(day.colour(of: slot)))
                            .frame(width: 22, height: 22)
                        Text(like.simile.name)
                            .font(.subheadline.weight(.medium))
                    }

                    Text(like.simile.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Why this colour is at this hour, which is the question an
                    // empty bead actually raises and the one the sheet used to
                    // answer with a hex code and nothing else. The board stopped
                    // painting itself in the forecast when it stopped repeating
                    // colours, so a bead no longer explains itself by being
                    // today's sky. The arrangement still has a reason, it is
                    // short enough to say, and an empty slot is exactly where
                    // somebody is standing when they wonder.
                    Text("판의 마흔여덟 색은 하루가 지나가는 색의 길을 따라 놓여 있습니다. 한밤에서 시작해 여명, 낮의 파랑, 노을, 다시 밤. 이 색은 그 길에서 \(slot.band)에 해당해 여기 앉아 있습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }

                Divider().padding(.horizontal, 40)

                // And then the curve itself, unrounded — the bead above is the
                // spectrum colour nearest this hour, and this is the hour. The
                // two are close but not the same, and an empty slot is where
                // the difference is worth showing.
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color(day.clearSkyColour(of: slot)))
                        .frame(width: 18, height: 18)

                    Text(clearSkyLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        // Taller than it was: the slot now explains itself rather than printing
        // two hex codes, and it scrolls so a larger type size does not clip it.
        .presentationDetents([.height(560), .large])
    }
}

#Preview {
    BoardView(
        landed: nil,
        place: Place(),
        revealed: .constant(true),
        reading: .constant(nil)
    )
        .modelContainer(for: SkyEntry.self, inMemory: true)
}

