import PhotosUI
import SwiftData
import SwiftUI

/// The board.
///
/// All forty-eight slots are drawn from the first launch as open rings in the
/// colour that time of day usually is. Capturing fills one of them in with the
/// colour you actually got. So the gradient is visible before you own any of
/// it, and filling it in is the collection.
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

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var opened: SkySlot?
    @State private var landed: Int?

    private var filled: [Int: SkyEntry] {
        var map: [Int: SkyEntry] = [:]
        for entry in entries { map[entry.slotID] = entry }
        return map
    }

    private let gap: CGFloat = 10
    private let sidePadding: CGFloat = 16

    /// The whole board has to be visible at once — a board you scroll is a
    /// feed — so the bead size is whichever of the two axes runs out first.
    private func beadDiameter(in size: CGSize) -> CGFloat {
        let columns = CGFloat(SkyBoard.columns)
        let rows = CGFloat(SkyBoard.slots.count / SkyBoard.columns)
        let byWidth = (size.width - sidePadding * 2 - gap * (columns - 1)) / columns
        let byHeight = (size.height - 24 - gap * (rows - 1)) / rows
        return max(24, min(byWidth, byHeight))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { area in
                let diameter = beadDiameter(in: area.size)
                // The marked slot has to move with the clock, not with whatever
                // happens to redraw the view.
                TimelineView(.periodic(from: .now, by: 60)) { clock in
                    let nowSlot = SkyBoard.slot(forMinute: SkyEntry.minuteOfDay(of: clock.date)).id
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(diameter), spacing: gap),
                            count: SkyBoard.columns
                        ),
                        spacing: gap
                    ) {
                        ForEach(SkyBoard.slots) { slot in
                            Bead(
                                slot: slot,
                                entry: filled[slot.id],
                                isNew: landed == slot.id,
                                isNow: slot.id == nowSlot,
                                diameter: diameter
                            )
                            .onTapGesture { opened = slot }
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
            .sheet(item: $opened) { slot in
                if let entry = filled[slot.id] {
                    PhotoDetailView(entry: entry)
                } else {
                    EmptySlotSheet(slot: slot)
                }
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

        let slot = entry.slotID
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
/// Collected and not collected are told apart by shape, not by colour: a
/// captured sky is a solid disc, an empty one is a ring with its middle open.
/// Shape survives what colour cannot — a pale overcast noon and the pale noon
/// reference are nearly the same blue, and no amount of opacity separates them
/// reliably. Diameter is deliberately not used, so the board stays an even grid.
///
/// The slot the clock is currently in wears a second ring outside itself, and
/// its own ring runs at full strength — that is the colour the sky is likely to
/// be right now, and where it would land.
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
            } else {
                Circle()
                    .strokeBorder(
                        Color(slot.rgb).opacity(isNow ? 1 : 0.5),
                        lineWidth: isNow ? ringWidth + 1 : ringWidth
                    )
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

/// What an empty slot says when tapped. It states the rule and stops — the one
/// thing it must not do is suggest the slot is overdue.
private struct EmptySlotSheet: View {
    let slot: SkySlot

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Circle()
                    .strokeBorder(Color(slot.rgb).opacity(0.55), lineWidth: 16)
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
