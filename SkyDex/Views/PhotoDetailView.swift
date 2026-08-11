import SwiftData
import SwiftUI

/// One filled slot, opened.
///
/// The line the person wrote comes first, right under the date and set larger
/// than anything else here. The hex and the slot are what the app worked out;
/// they sit below, because they are the least interesting thing about the day
/// you took the photo.
///
/// An empty line opens with the keyboard already up. Nothing else on the sheet
/// is waiting for input, so there is no cost to guessing, and a note you have
/// to go looking for is a note that never gets written. A line that is already
/// there does not steal focus — you came back to read it.
struct PhotoDetailView: View {
    @Bindable var entry: SkyEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var confirmingDelete = false
    @FocusState private var writing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photo
                    details
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard entry.note.isEmpty else { return }
                // A beat, so focus lands after the sheet has finished its
                // presentation animation rather than fighting it.
                try? await Task.sleep(for: .milliseconds(450))
                writing = true
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { writing = false }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") {
                        writing = false
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "이 하늘을 지울까요?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("지우기", role: .destructive) { delete() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("사진과 색이 함께 사라집니다.")
            }
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image = entry.photo {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        } else {
            Color(entry.rgb)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.capturedAt, format: .dateTime.year().month().day().weekday(.wide).hour().minute())
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // The line sits directly under the date and is set larger than
                // anything else on the sheet. It is the only part of a capture
                // the person wrote themselves; the hex and the slot are just
                // what the app worked out.
                TextField("그때 무슨 생각을 했나요", text: $entry.note, axis: .vertical)
                    .font(.title3)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .focused($writing)
            }

            Divider()

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(entry.rgb))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.hex)
                        .font(.subheadline)
                        .monospaced()
                    Text(slotNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var slotNote: String {
        "\(entry.slot.timeLabel) · \(entry.slot.band)"
    }

    private func delete() {
        ThumbnailCache.forget(id: entry.uuid.uuidString)
        context.delete(entry)
        dismiss()
    }
}
