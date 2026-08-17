import SwiftData
import SwiftUI

/// One collected sky, as a card you write on.
///
/// This used to be a photo with a form under it: a field, a divider, a hex code.
/// A field is a thing you fill in when something requires it, and nothing here
/// requires it — so the line went unwritten.
///
/// So the photo and the line are one object now. The sky is the top of the card
/// and the writing sits on the same surface directly beneath it, close enough
/// that the empty space belongs to the picture rather than to a form. The prompt
/// asks a question instead of naming a field: "한 줄" tells you what to type,
/// "이 하늘을 보면서 들었던 생각" tells you what to say.
///
/// The way out doubles as the confirmation. With nothing written it is "닫기";
/// the moment there is a line it becomes a green tick, and pressing it writes the
/// store to disk rather than trusting the autosave timer. A note left through a
/// button that says "close" does not feel like it was kept.
///
/// An empty card opens with the keyboard already up. Nothing else here is waiting
/// for input, so there is no cost to guessing, and a note you have to go looking
/// for is a note that never gets written. A card that already has a line on it
/// does not steal focus — you came back to read it.
///
/// What the app worked out — the hour, the part of the day, the colour — sits
/// below the card in small type. It is the least interesting thing about the day
/// you took the photo.
///
/// The one exception is the name. `#BEA3C9` is small type because it is a
/// serial number; 담자색 is not, because it is the answer to what this sky was.
/// So the nearest name sits directly under the card at a size you read rather
/// than check, with where it comes from and one line saying what it means — a
/// name you do not recognise is not yet a name. Whether it says *this* colour or
/// merely the *closest* one is stated, not blurred: the table has sixty names and
/// the sky has all of them in between.
struct PhotoDetailView: View {
    @Bindable var entry: SkyEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var confirmingDelete = false
    @State private var saves = 0
    @FocusState private var writing: Bool

    private var written: Bool { !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    card
                    naming
                    details
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard entry.note.isEmpty else { return }
                // A beat, so focus lands after the screen has finished arriving
                // rather than fighting it.
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
                    // Once there is a line on the card, the way out stops being
                    // "닫기" and becomes a green tick. Leaving a note through a
                    // button labelled "close" felt like walking away from it;
                    // this says the card took it.
                    Button {
                        writing = false
                        // And it really is saved, not just labelled that way.
                        // The context autosaves, but a tick that means "kept"
                        // should not be waiting on a timer to become true.
                        try? context.save()
                        saves += 1
                        dismiss()
                    } label: {
                        if written {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .green)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        } else {
                            Text("닫기")
                                .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.65), value: written)
                    .accessibilityLabel(written ? "저장" : "닫기")
                }
            }
            .sensoryFeedback(.success, trigger: saves)
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

    /// The card: sky on top, your line underneath, one surface.
    private var card: some View {
        VStack(spacing: 0) {
            photo
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

            ZStack(alignment: .topLeading) {
                // The invitation is drawn rather than handed to the field: a
                // `TextField` prompt is one line and truncates, and half a
                // question is not a question.
                if entry.note.isEmpty {
                    Text("이 하늘을 보면서 들었던 생각,\n하고 싶은 한 마디")
                        .foregroundStyle(.tertiary)
                        .allowsHitTesting(false)
                }

                TextField("", text: $entry.note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($writing)
                    // The caret takes the colour of the sky it is written under.
                    .tint(Color(entry.rgb))
            }
            .font(.title3)
            .lineSpacing(5)
            .lineLimit(2...6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
            // The whole lower half of the card is the writing surface, not just
            // the line of text sitting in it.
            .contentShape(Rectangle())
            .onTapGesture { writing = true }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private var photo: some View {
        if let image = entry.photo {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color(entry.rgb)
        }
    }

    /// The name of this sky, or the nearest one to it.
    ///
    /// The heading is the honest part. Inside five units of CIEDE2000 the colour
    /// and the name are the same colour to look at, so it says "이 하늘의 이름";
    /// past that it says "가장 가까운 이름" and means it. Sixty names cannot land
    /// on every sky, and a card that rounds the difference away would be putting
    /// words in the sky's mouth.
    private var naming: some View {
        let match = SkyNames.nearest(to: entry.lab)
        return VStack(alignment: .leading, spacing: 5) {
            Text(match.isClose ? "이 하늘의 이름" : "가장 가까운 이름")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(match.name.name)
                    .font(.title3.weight(.semibold))
                Text(match.name.origin.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }

            Text(match.name.gloss)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// Underneath and quiet: when it was, what part of the day, what colour.
    private var details: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(entry.rgb))
                .frame(width: 11, height: 11)

            Text(entry.capturedAt, format: .dateTime.year().month().day().weekday().hour().minute())
            Text("·")
            Text(entry.band)

            Spacer()

            Text(entry.hex)
                .monospaced()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private func delete() {
        entry.forgetImages()
        context.delete(entry)
        dismiss()
    }
}
