import SwiftData
import SwiftUI

/// Everything collected, three ways.
///
/// The board only ever shows today: forty-eight colours today's sky is expected
/// to run through, filled by whatever in the collection is near enough. Which
/// means a sky can be missing from the board through no fault of its own — a
/// January dusk simply is not one of today's colours in July.
///
/// So nothing is only on the board. **기록** is the calendar: every capture in the
/// order it happened. **팔레트** is the collection itself, every colour ever
/// collected laid out as one long day, whether today's sky wants it or not.
/// **되풀이** is the only argument the collection can make: the same half hour
/// stood in on many days, side by side, never once the same colour twice.
struct ArchiveView: View {
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var entries: [SkyEntry]
    @Environment(\.modelContext) private var context

    @State private var selected: SkyEntry?
    @State private var showing: Showing = .list
    @State private var groups: [PaletteGroup] = []

    private enum Showing: String, CaseIterable, Identifiable {
        case list = "기록"
        case palette = "팔레트"
        case repeats = "되풀이"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "아직 모은 하늘이 없어요",
                        systemImage: "list.bullet",
                        description: Text("밖을 한 번 올려다보는 것으로 시작합니다.")
                    )
                } else if showing == .palette {
                    palette
                } else if showing == .repeats {
                    // The same collection asked a different question: not what
                    // colours are in it, but whether any of them ever came back.
                    RepeatView(entries: entries) { selected = $0 }
                        .sensoryFeedback(.selection, trigger: selected?.uuid)
                } else {
                    // Same paper as the board. A list on its own grey while the
                    // board sits on white made the two screens look like two
                    // apps, and the bar between them had to pick a side.
                    List {
                        ForEach(grouped, id: \.key) { section in
                            Section(Season.label(forKey: section.key)) {
                                ForEach(section.value) { entry in
                                    Button {
                                        selected = entry
                                    } label: {
                                        row(entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { offsets in
                                    delete(offsets, in: section.value)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemBackground))
            // The switch is the title. Centred in the bar, `.principal` rather
            // than trailing — a segmented control shoved to one end reads as a
            // setting, and this is the name of what you are looking at. The large
            // title is gone with it: it was saying the same word twice.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !entries.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Picker("", selection: $showing) {
                            ForEach(Showing.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        // Left to itself a segmented control in a toolbar takes
                        // the whole width it is given.
                        .frame(width: 250)
                    }
                }
            }
            // The way back to the board is in the bar at the bottom, in the
            // same place on both screens. It used to be up here, which meant the
            // control you pressed to arrive and the one to leave were at
            // opposite ends of the screen.
            .fullScreenCover(item: $selected) { entry in
                PhotoDetailView(entry: entry)
            }
        }
    }

    private var grouped: [(key: String, value: [SkyEntry])] {
        Dictionary(grouping: entries, by: \.seasonKey)
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value) }
    }

    /// The collection as a swatch page.
    ///
    /// A grid of floating circles was a list of colours; a palette is a thing you
    /// hold up against something. So the colours are packed — three points apart,
    /// barely rounded, no borders — and grouped by the part of the day they belong
    /// to, with the count of each in small type. Structure and restraint do the
    /// work; nothing here is decorated.
    ///
    /// Grouped by the band each **colour** belongs to, not the hour it was taken
    /// in. A midnight blue photographed at noon under a storm is a midnight blue,
    /// and the axis of this app is colour.
    private var palette: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.band)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(group.entries.count)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 3)

                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 3),
                                count: ArchiveView.columns(for: group.entries.count)
                            ),
                            spacing: 3
                        ) {
                            ForEach(group.entries) { entry in
                                Button {
                                    selected = entry
                                } label: {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color(entry.rgb))
                                        // One height for every band, so a band
                                        // with two colours in it is a wide chip
                                        // rather than a pair of tiles twice
                                        // everything else's size. The page reads
                                        // as a stack of swatch bars.
                                        .frame(height: 64)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .task { regroup() }
        .onChange(of: entries.count) { _, _ in regroup() }
        .sensoryFeedback(.selection, trigger: selected?.uuid)
    }

    /// How many across a band of this size should run.
    ///
    /// A short band takes one row and the tiles share the width, which is what a
    /// paint chip card looks like. A long one is split so the last row is as full
    /// as it can be — a row of six with a single tile hanging under it reads as
    /// unfinished rather than as a swatch.
    private static func columns(for count: Int) -> Int {
        guard count > 8 else { return count }
        return (5...7).max { a, b in
            (lastRow(count, a), a) < (lastRow(count, b), b)
        } ?? 6
    }

    /// How full the last row would be, counting a clean fit as full.
    private static func lastRow(_ count: Int, _ columns: Int) -> Int {
        let remainder = count % columns
        return remainder == 0 ? columns : remainder
    }

    private struct PaletteGroup: Identifiable {
        let band: String
        let entries: [SkyEntry]
        var id: String { band }
    }

    /// Placing a colour on the day costs a scan of the curve, so it is done once
    /// per change rather than once per draw.
    private func regroup() {
        let placed = entries.map { (entry: $0, position: SkyDay.spectrumPosition(of: $0.lab)) }
        let byBand = Dictionary(grouping: placed) {
            SkyBoard.band(forMinute: Int($0.position))
        }
        groups = SkyBoard.bandNames.compactMap { band in
            guard let items = byBand[band], !items.isEmpty else { return nil }
            return PaletteGroup(
                band: band,
                entries: items.sorted { $0.position < $1.position }.map(\.entry)
            )
        }
    }

    private func row(_ entry: SkyEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                if let image = entry.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(entry.rgb)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.capturedAt, format: .dateTime.month().day().hour().minute())
                    .font(.subheadline)
                Text(entry.note.isEmpty ? entry.band : entry.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(entry.hex)
                .font(.caption2)
                .monospaced()
                .foregroundStyle(.secondary)
        }
    }

    private func delete(_ offsets: IndexSet, in list: [SkyEntry]) {
        for index in offsets {
            let entry = list[index]
            entry.forgetImages()
            context.delete(entry)
        }
    }
}
