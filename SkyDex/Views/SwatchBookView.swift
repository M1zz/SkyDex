import SwiftUI
import SwiftData

/// The swatch book: every sky as a card.
///
/// Colours can repeat, so a card is not the same thing as a dot on the arc.
/// Every capture gets one, because the sky may come round again but the day
/// does not and the name written on it never will.
struct SwatchBookView: View {
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var entries: [SkyEntry]
    @Environment(\.modelContext) private var context

    @Environment(\.skyTheme) private var theme

    @State private var selected: SkyEntry?
    @State private var showPanorama = false

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 240), spacing: 16)]

    private var grouped: [(key: String, value: [SkyEntry])] {
        Dictionary(grouping: entries, by: \.seasonKey)
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "아직 이름 붙인 하늘이 없어요",
                        systemImage: "square.grid.2x2"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 26, pinnedViews: [.sectionHeaders]) {
                            ForEach(grouped, id: \.key) { section in
                                Section {
                                    LazyVGrid(columns: columns, spacing: 16) {
                                        ForEach(section.value) { entry in
                                            SkyCardView(entry: entry)
                                                .onTapGesture { selected = entry }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                } header: {
                                    Text(Season.label(forKey: section.key))
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.bar)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    // The wash has to show through the grid, which otherwise
                    // paints its own opaque background over it.
                    .scrollContentBackground(.hidden)
                }
            }
            .skyBackdrop(theme)
            .navigationTitle("팔레트")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPanorama = true } label: {
                        Image(systemName: "rectangle.split.3x1")
                    }
                    .accessibilityLabel("계절 파노라마")
                    .disabled(entries.isEmpty)
                }
            }
            .sheet(item: $selected) { EntryDetailView(entry: $0) }
            .sheet(isPresented: $showPanorama) {
                PanoramaView(entries: entries)
            }
        }
    }
}
