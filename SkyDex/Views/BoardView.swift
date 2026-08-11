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
/// Filling all of them does not end it. The board halves — forty-eight slots
/// become ninety-six, then a hundred and ninety-two — and the same day comes
/// back finer. Nothing resets and no photo is lost; the collection just gets
/// more exact about what time it was. The level is latched at the highest ever
/// reached, so deleting one photo never coarsens a board you already earned.
///
/// There is no text on it. Band names, clock ranges and a running count were
/// all saying what the colours already say — the top is night, it lightens
/// downward into day and darkens again at the bottom. Reading that off the
/// grid takes no words, and the words were competing with the only thing worth
/// looking at.
///
/// A slot is chosen by the clock, never by the user, and no photo is ever
/// turned away — the only thing a capture has to do is exist.
struct BoardView: View {
    @Environment(\.modelContext) private var context

    /// Ascending, so building the map leaves the most recent capture in each
    /// slot: shooting the same half-hour again replaces the bead rather than
    /// being locked out by a first attempt you did not like.
    @Query(sort: \SkyEntry.capturedAt, order: .forward) private var entries: [SkyEntry]

    @AppStorage("skydex.boardLevel") private var earnedLevel = 0

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var presented: Presented?
    @State private var landed: Int?

    private var completedLevel: Int {
        SkyBoard.level(forMinutes: entries.map(\.minuteOfDay))
    }

    private var level: Int { max(earnedLevel, completedLevel) }

    private var slots: [SkySlot] { SkyBoard.slots(level: level) }

    /// One sheet handles both, because two `.sheet` modifiers on the same view
    /// race each other and only one ever wins.
    private enum Presented: Identifiable {
        case slot(SkySlot)
        case levelUp(Int)

        var id: String {
            switch self {
            case .slot(let slot): return "slot-\(slot.level)-\(slot.id)"
            case .levelUp(let level): return "level-\(level)"
            }
        }
    }

    private var filled: [Int: SkyEntry] {
        let level = self.level
        var map: [Int: SkyEntry] = [:]
        for entry in entries {
            map[SkyBoard.slot(forMinute: entry.minuteOfDay, level: level).id] = entry
        }
        return map
    }

    private let sidePadding: CGFloat = 16

    /// Tighter as the board gets finer, so the extra rows have somewhere to go.
    private var gap: CGFloat { [10, 7, 5][min(level, SkyBoard.maxLevel)] }

    /// The whole board has to be visible at once — a board you scroll is a
    /// feed — so the bead size is whichever of the two axes runs out first.
    private func beadDiameter(in size: CGSize) -> CGFloat {
        let columns = CGFloat(SkyBoard.columns(level: level))
        let rows = CGFloat(slots.count / SkyBoard.columns(level: level))
        let byWidth = (size.width - sidePadding * 2 - gap * (columns - 1)) / columns
        let byHeight = (size.height - 24 - gap * (rows - 1)) / rows
        return max(18, min(byWidth, byHeight))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { area in
                let diameter = beadDiameter(in: area.size)
                // The marked slot has to move with the clock, not with whatever
                // happens to redraw the view.
                TimelineView(.periodic(from: .now, by: 60)) { clock in
                    let nowSlot = SkyBoard.slot(
                        forMinute: SkyEntry.minuteOfDay(of: clock.date),
                        level: level
                    ).id
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(diameter), spacing: gap),
                            count: SkyBoard.columns(level: level)
                        ),
                        spacing: gap
                    ) {
                        ForEach(slots) { slot in
                            Bead(
                                slot: slot,
                                entry: filled[slot.id],
                                isNew: landed == slot.id,
                                isNow: slot.id == nowSlot,
                                diameter: diameter
                            )
                            .onTapGesture { presented = .slot(slot) }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { captureBar }
            .fullScreenCover(isPresented: $showCamera) {
                SquareCameraView(
                    onCapture: { data, date in save(data, at: date) },
                    onPickFromLibrary: {
                        // Presenting a picker while the full-screen cover is
                        // still animating away silently does nothing.
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            showLibrary = true
                        }
                    }
                )
            }
            .sheet(item: $presented) { item in
                switch item {
                case .slot(let slot):
                    if let entry = filled[slot.id] {
                        PhotoDetailView(entry: entry)
                    } else {
                        EmptySlotSheet(slot: slot)
                    }
                case .levelUp(let reached):
                    BoardSplitSheet(level: reached)
                }
            }
            .onChange(of: completedLevel, initial: true) { _, reached in
                guard reached > earnedLevel else { return }
                earnedLevel = reached
                // Without this the board would quietly appear half empty the
                // moment it was finished, which reads as data loss.
                presented = .levelUp(reached)
            }
            .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await loadFromLibrary(item) }
            }
        }
    }

    private var captureBar: some View {
        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("하늘 찍기", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showLibrary = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
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

        let slot = SkyBoard.slot(forMinute: entry.minuteOfDay, level: level).id
        landed = slot
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if landed == slot {
                withAnimation(.easeOut(duration: 0.3)) { landed = nil }
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
/// The slot the clock is currently in wears a second ring outside itself and
/// takes its colour undimmed: that is the sky right now, and where a capture
/// would land.
private struct Bead: View {
    let slot: SkySlot
    let entry: SkyEntry?
    let isNew: Bool
    let isNow: Bool
    let diameter: CGFloat

    private var ringWidth: CGFloat { max(3, diameter * 0.17) }

    var body: some View {
        ZStack {
            if let entry {
                Circle().fill(Color(entry.rgb))
            } else if isNow {
                Circle().strokeBorder(Color(slot.rgb), lineWidth: ringWidth + 1)
            } else {
                Circle().strokeBorder(Color(slot.ghost), lineWidth: ringWidth)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay {
            // Sits outside the bead and laps over the gap into its neighbours,
            // so the current slot is findable at a glance on a full board.
            if isNow {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                    .frame(width: diameter + 11, height: diameter + 11)
            }
        }
        .overlay { if isNew { Circle().strokeBorder(.white, lineWidth: 2.5) } }
        .scaleEffect(isNew ? 1.14 : 1)
        .zIndex(isNew ? 2 : (isNow ? 1 : 0))
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: isNew)
        .contentShape(Circle())
    }
}

/// What the board says the one time it splits.
///
/// It has to say something. Finishing forty-eight slots and finding the board
/// suddenly half empty reads as data loss unless someone explains that it grew.
/// It should not say more than that — no score, no streak, no next target.
private struct BoardSplitSheet: View {
    let level: Int

    @Environment(\.dismiss) private var dismiss

    private var previous: Int { SkyBoard.slots(level: level - 1).count }
    private var current: Int { SkyBoard.slots(level: level).count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                HStack(spacing: 18) {
                    ring(count: 6, split: false)
                    Image(systemName: "arrow.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ring(count: 12, split: true)
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("하루를 다 모았어요")
                        .font(.title3.weight(.medium))
                    Text("\(previous)칸이 \(current)칸이 됩니다. 같은 하루가 더 촘촘해질 뿐, 지금까지 모은 건 그대로 있습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                Button("좋아요") { dismiss() }
                    .buttonStyle(.borderedProminent)
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
        .presentationDetents([.height(340)])
    }

    /// Six filled beads become twelve slots with the same six still filled —
    /// every other one. Drawing the wider board as all empty would illustrate
    /// exactly the loss this sheet exists to deny.
    private func ring(count: Int, split: Bool) -> some View {
        let size: CGFloat = count == 6 ? 15 : 9
        return HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                let colour = SkyBoard.colour(atMinute: 1080 + index * (180 / count))
                Group {
                    if split, !index.isMultiple(of: 2) {
                        Circle().strokeBorder(
                            Color(SkyBoard.ghost(of: colour)),
                            lineWidth: max(2, size * 0.3)
                        )
                    } else {
                        Circle().fill(Color(colour))
                    }
                }
                .frame(width: size, height: size)
            }
        }
    }
}

/// What an empty slot says when tapped. It states the rule and stops — the one
/// thing it must not do is suggest the slot is overdue.
private struct EmptySlotSheet: View {
    let slot: SkySlot

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Faded, like the bead that was tapped. Its full strength is
                // on the swatch further down, next to the hex.
                Circle()
                    .strokeBorder(Color(slot.ghost), lineWidth: 16)
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
                        .fill(Color(slot.rgb))
                        .frame(width: 22, height: 22)
                    Text("이 시각의 하늘은 보통 \(slot.hex)")
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(.secondary)
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
    BoardView()
        .modelContainer(for: SkyEntry.self, inMemory: true)
}
