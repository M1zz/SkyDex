import SwiftData
import SwiftUI

/// One colour's history, newest first, full screen.
///
/// A bead is one of today's colours, and it is filled by anything in the
/// collection that falls inside its circle. This is that circle's contents: every
/// sky you have that would fill this bead, newest first. Usually the one on top
/// is the one the board is showing.
///
/// Which means the answer changes with the board. The same bead position tomorrow
/// is a different colour and holds different photos, because what it asks is
/// "what have I got that looks like this", not "what did I take at this hour".
///
/// Everything, in the order it happened, is what the archive is for.
///
/// Full screen rather than a sheet. A sheet is a card laid over the thing you
/// were doing, which is right for a note about a slot and wrong for the photos
/// themselves.
struct TimelineFeedView: View {
    let slot: SkySlot

    /// Today's colour for this bead. The circle is drawn around this.
    let target: Lab

    /// Everything, because "inside the circle" is a colour comparison and a
    /// store cannot be asked that. Forty-eight beads' worth of photos is a
    /// handful of thousands at most, and the filtering is arithmetic.
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var all: [SkyEntry]

    @Environment(\.dismiss) private var dismiss

    @State private var opened: SkyEntry?

    private var entries: [SkyEntry] { SkyMatch.all(near: target, in: all) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 32) {
                    ForEach(entries) { entry in
                        card(entry)
                            .onTapGesture { opened = entry }
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Which colour this is, and when today's sky is expected to
                    // wear it. The board says it with a position; here there is
                    // room for words.
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(RGB(target)))
                            .frame(width: 11, height: 11)
                        Text("\(slot.band) · \(slot.timeLabel)")
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .fullScreenCover(item: $opened) { entry in
                PhotoDetailView(entry: entry)
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "이 색은 아직 없어요",
                        systemImage: "camera",
                        description: Text("이 색에 가까운 하늘을 찍으면 여기에 쌓입니다.")
                    )
                }
            }
        }
    }

    private func card(_ entry: SkyEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let image = entry.photo {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(entry.rgb)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            // Inset and rounded, like everything else the app draws. Bleeding
            // to the edges would make each sky a wall rather than one of many.
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 6) {
                // The line the person wrote leads, the same way it does on the
                // photo itself. The date is what the app knows.
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                Text(entry.capturedAt, format: .dateTime.year().month().day().weekday().hour().minute())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    TimelineFeedView(slot: SkyBoard.slots[30], target: Lab(RGB(hex: "#D68F55")!))
        .modelContainer(for: SkyEntry.self, inMemory: true)
}
