import SwiftData
import SwiftUI

/// The same skies in the order they were actually taken.
///
/// The board deliberately loses the calendar — it is one day, drawn out of
/// many. This is where the calendar lives, and where captures that landed in
/// an already-filled slot are still visible.
struct ArchiveView: View {
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var entries: [SkyEntry]
    @Environment(\.modelContext) private var context

    @State private var selected: SkyEntry?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "아직 모은 하늘이 없어요",
                        systemImage: "list.bullet",
                        description: Text("밖을 한 번 올려다보는 것으로 시작합니다.")
                    )
                } else {
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
                }
            }
            .navigationTitle("기록")
            .sheet(item: $selected) { entry in
                PhotoDetailView(entry: entry)
            }
        }
    }

    private var grouped: [(key: String, value: [SkyEntry])] {
        Dictionary(grouping: entries, by: \.seasonKey)
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value) }
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
                Text(entry.note.isEmpty ? entry.slot.timeLabel : entry.note)
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
            ThumbnailCache.forget(id: entry.uuid.uuidString)
            context.delete(entry)
        }
    }
}
