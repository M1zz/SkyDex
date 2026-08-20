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
                        // Where the photos are, at the foot of the list of
                        // photos. This is the screen where "did I lose any of
                        // it" gets asked, so this is where it is answered — and
                        // it answers with a fact, not a promise: what iCloud
                        // last agreed to, and when.
                        Section {
                            EmptyView()
                        } footer: {
                            Text(CloudSync.shared.line)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
    /// barely rounded, no borders — and grouped, with the count of each in small
    /// type. Structure and restraint do the work; nothing here is decorated.
    ///
    /// Grouped by **what kind of colour it is**: 짙은 파랑, 푸른 회색, 모래빛,
    /// 주황. It used to be grouped by where the colour sat on the day and
    /// labelled with the hours — 여명, 늦은 오후 — which read as when the photo
    /// was taken and was not that at all. A grey taken at breakfast landed under
    /// 노을 because dusk is where grey lives on the curve, and the label was
    /// believed over the photograph.
    ///
    /// The palette is the one screen here that is not about time. The board is
    /// the day, 기록 is the order things happened, and this is the paint chips.
    private var palette: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.family.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(group.entries.count)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 3)

                        // One chip size for the whole page, not one per group.
                        // Sharing the row out between however many colours a
                        // family happens to hold made a family of one into a
                        // slab the width of the screen and a family of nine into
                        // stamps — the size of a swatch was reading as how
                        // *important* it was. A chip card is a chip card: the
                        // chips are all the same, and a short family simply ends
                        // early.
                        LazyVGrid(
                            // Six across, the same as the board. A chip is the
                            // same size on every family and on every screen, so
                            // the page is a card of chips rather than a set of
                            // bars whose size means something it should not.
                            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 6),
                            spacing: 3
                        ) {
                            ForEach(group.entries) { entry in
                                Button {
                                    selected = entry
                                } label: {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color(entry.rgb))
                                        .frame(height: 52)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            // Clear of the shutter, which floats over every screen.
            .padding(.bottom, 96)
        }
        .task { regroup() }
        .onChange(of: entries.count) { _, _ in regroup() }
        .sensoryFeedback(.selection, trigger: selected?.uuid)
    }

    private struct PaletteGroup: Identifiable {
        let family: SkyFamily
        let entries: [SkyEntry]
        var id: String { family.rawValue }
    }

    /// Sorting every colour into its family is done once per change rather than
    /// once per draw.
    ///
    /// Inside a family the run goes dark to light, which is how a paint chip
    /// card is printed and the only ordering that does not need a caption to
    /// explain it.
    private func regroup() {
        let byFamily = Dictionary(grouping: entries) { SkyFamily.of($0.lab) }
        groups = SkyFamily.allCases.compactMap { family in
            guard let items = byFamily[family], !items.isEmpty else { return nil }
            return PaletteGroup(
                family: family,
                entries: items.sorted { $0.lab.l < $1.lab.l }
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
