import SwiftData
import SwiftUI

/// Everything collected, two ways.
///
/// The board only ever shows today: forty-eight colours today's sky is expected
/// to run through, filled by whatever in the collection is near enough. Which
/// means a sky can be missing from the board through no fault of its own — a
/// January dusk simply is not one of today's colours in July.
///
/// So nothing is only on the board. **기록** is the calendar: every capture in the
/// order it happened. **팔레트** is the collection itself, every colour ever
/// collected laid out as one long day, whether today's sky wants it or not.
struct ArchiveView: View {
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var entries: [SkyEntry]
    @Environment(\.modelContext) private var context

    @State private var selected: SkyEntry?
    @State private var showing: Showing = .list

    private enum Showing: String, CaseIterable, Identifiable {
        case list = "기록"
        case palette = "팔레트"

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
                        .frame(width: 190)
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

    /// The collection as one long day: every colour ever collected, in the order
    /// the sky wears them rather than the order they were taken.
    ///
    /// Sorted by where each colour sits on the canonical curve, which is fixed —
    /// a palette that reshuffles itself every morning is not a palette. Two
    /// photos of the same blue sit next to each other even if they are months
    /// apart, which is the whole point of collecting colours.
    private var palette: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 54, maximum: 84), spacing: 10)],
                spacing: 10
            ) {
                ForEach(spectrum) { entry in
                    Button {
                        selected = entry
                    } label: {
                        Circle()
                            .fill(Color(entry.rgb))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .sensoryFeedback(.selection, trigger: selected?.uuid)
    }

    private var spectrum: [SkyEntry] {
        entries
            .map { (entry: $0, position: SkyDay.spectrumPosition(of: $0.lab)) }
            .sorted { $0.position < $1.position }
            .map(\.entry)
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
