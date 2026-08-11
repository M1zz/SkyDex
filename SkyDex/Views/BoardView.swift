import PhotosUI
import SwiftData
import SwiftUI

/// The board.
///
/// All forty-eight slots are drawn from the first launch, each showing the sky
/// its time of day usually is at low opacity. Capturing paints one of them in
/// the colour you actually got. So the gradient is visible before you own any
/// of it, and filling it in is the collection.
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

    private let gap: CGFloat = 8
    private let bandGap: CGFloat = 10
    private let headerBlock: CGFloat = 20      // band label plus its gap to the grid
    private let chromeExtra: CGFloat = 42      // footer and outer padding

    /// The whole board has to be visible at once — a board you scroll is a
    /// feed. So the bead size comes from the height that is left after the
    /// labels, not from the width.
    private func beadDiameter(in size: CGSize) -> CGFloat {
        let rows = CGFloat(SkyBoard.slots.count / SkyBoard.columns)
        let intraBandGaps = CGFloat(SkyBoard.bands.filter { $0.slots.count > SkyBoard.columns }.count)
        let chrome = CGFloat(SkyBoard.bands.count) * headerBlock
            + CGFloat(SkyBoard.bands.count - 1) * bandGap
            + intraBandGaps * gap
            + chromeExtra
        let byHeight = (size.height - chrome) / rows
        let byWidth = (size.width - 28 - gap * CGFloat(SkyBoard.columns - 1)) / CGFloat(SkyBoard.columns)
        return max(28, min(byWidth, byHeight))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { area in
                let diameter = beadDiameter(in: area.size)
                VStack(alignment: .leading, spacing: bandGap) {
                    ForEach(SkyBoard.bands, id: \.name) { band in
                        section(band, diameter: diameter)
                    }
                    footer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 14)
                .padding(.top, 2)
            }
            .navigationTitle("하늘")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Board

    private func section(_ band: (name: String, slots: [SkySlot]), diameter: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(band.name)
                    .font(.caption2.weight(.semibold))
                Text(bandRange(band.slots))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(diameter), spacing: gap), count: SkyBoard.columns),
                spacing: gap
            ) {
                ForEach(band.slots) { slot in
                    Bead(
                        slot: slot,
                        entry: filled[slot.id],
                        isNew: landed == slot.id,
                        diameter: diameter
                    )
                    .onTapGesture { opened = slot }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func bandRange(_ slots: [SkySlot]) -> String {
        guard let first = slots.first, let last = slots.last else { return "" }
        return String(
            format: "%02d–%02d시",
            first.startMinute / 60,
            (last.endMinute / 60) % 24 == 0 && last.endMinute > 0 ? 24 : last.endMinute / 60
        )
    }

    private var footer: some View {
        Text("모은 하늘 \(filled.count)")
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
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
/// Empty is not blank: it carries its own colour at low opacity, so an unfilled
/// board still shows the shape of a day and a filled bead reads as that colour
/// arriving at full strength rather than as a box being ticked.
private struct Bead: View {
    let slot: SkySlot
    let entry: SkyEntry?
    let isNew: Bool
    let diameter: CGFloat

    var body: some View {
        Group {
            if let entry {
                Color(entry.rgb)
            } else {
                Color(slot.rgb).opacity(0.28)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            if entry == nil {
                Circle().strokeBorder(Color(slot.rgb).opacity(0.45), lineWidth: 1)
            }
        }
        .overlay {
            if isNew {
                Circle().strokeBorder(.white, lineWidth: 2.5)
            }
        }
        .scaleEffect(isNew ? 1.14 : 1)
        .zIndex(isNew ? 1 : 0)
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
                    .fill(Color(slot.rgb).opacity(0.28))
                    .overlay(Circle().strokeBorder(Color(slot.rgb).opacity(0.45), lineWidth: 1))
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
