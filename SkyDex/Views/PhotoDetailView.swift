import SwiftData
import SwiftUI

/// One filled slot, opened.
///
/// The line under the swatch names the slot this sky landed in and what that
/// time of day usually looks like. It is an observation, never a score — the
/// board has no notion of a capture being off-colour.
struct PhotoDetailView: View {
    @Bindable var entry: SkyEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photo
                    details
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.capturedAt, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.headline)
                Text(entry.capturedAt, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(entry.rgb))
                    .frame(width: 44, height: 44)
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

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("한 줄")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("그때 무슨 생각을 했나요", text: $entry.note, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
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
