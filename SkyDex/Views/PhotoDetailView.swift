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
/// The one exception is what the colour is. `#BEA3C9` is small type because it is
/// a serial number; 물에 젖은 청바지색 is not, because it is the answer to what this
/// sky was. So the plain-Korean likeness sits directly under the card at a size
/// you read rather than check, with one line saying where you have seen it, and
/// the sourced name — 담자색, 우스하나이로 — follows underneath in small type for
/// anyone who wants the real word. Whether either one says *this* colour or
/// merely the *closest* one is stated, not blurred.
struct PhotoDetailView: View {
    @Bindable var entry: SkyEntry

    /// The sky this was framed under in the viewfinder, if any. The card opens
    /// with it already picked, so the picture you were looking at when you
    /// pressed the shutter is the picture in front of you — the collection still
    /// keeps the sky as it was.
    var borrowed: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var confirmingDelete = false
    @State private var saves = 0
    @FocusState private var writing: Bool

    /// Every other sky in the collection, ready to be held up against this one.
    /// Read once rather than sorted on every keystroke in the note field.
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var collected: [SkyEntry]
    @State private var lenses: [SkyEntry] = []

    /// The sky currently being borrowed, and how much of it.
    @State private var lens: SkyEntry?
    @State private var strength: Double = 1
    @State private var lensed: UIImage?
    @State private var working = false

    private var written: Bool { !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    card
                    borrowing
                    naming
                    details
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: borrowKey) { await borrow() }
            .task {
                gatherLenses()
                if let borrowed { lens = lenses.first { $0.hex == borrowed } }
            }
            .onChange(of: collected.count) { _, _ in gatherLenses() }
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
        if let image = lensed ?? entry.photo {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color(entry.rgb)
        }
    }

    /// What this sky is like, and then what it is called.
    ///
    /// The picture leads. "우스하나이로" is the more precise answer and it is the
    /// one with a source behind it, but almost nobody can see a colour from it,
    /// and a name you cannot see is not doing a name's job. "물에 젖은 청바지색"
    /// puts the colour in front of you before you look back at the photograph.
    ///
    /// So the simile is the headline and the sourced name sits under it in small
    /// type, where it is still there for anyone who wants the real word. Both say
    /// how far off they are rather than rounding it away: a simile past ΔE 6 is
    /// introduced as a stretch, and a name past ΔE 5 as the nearest one rather
    /// than this sky's own.
    private var naming: some View {
        let like = SkySimiles.nearest(to: entry.lab)
        let named = SkyNames.nearest(to: entry.lab)
        return VStack(alignment: .leading, spacing: 5) {
            Text(like.isClose ? "말로 하면" : "굳이 말하자면")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(like.simile.name)
                .font(.title3.weight(.semibold))

            Text(like.simile.note)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(named.isClose ? "이름은" : "가장 가까운 이름은")
                Text(named.name.name)
                    .foregroundStyle(.secondary)
                Text(named.name.origin.rawValue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.fill.tertiary, in: Capsule())
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 3)
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

    /// The strip that lends this photograph another day's sky.
    ///
    /// It is a strip of chips rather than a list of named filters, because the
    /// filters here are not a set someone designed — they are the skies you
    /// already collected, and the only honest label for one of them is its
    /// colour. Picking one moves the sky in this photograph onto that colour and
    /// leaves everything else in the frame where it was.
    ///
    /// What is stored does not change. The hex under this card, the likeness,
    /// the bead on the board and the widget all go on saying what this sky
    /// actually was — borrowing another day is something you do while looking,
    /// not an edit to the record. So the strip is empty-handed when you leave:
    /// there is nothing to save, and what you wanted to keep goes out through
    /// the share sheet as a picture.
    @ViewBuilder
    private var borrowing: some View {
        if entry.photo != nil, !lenses.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("다른 날의 하늘로")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let lensed {
                        ShareLink(
                            item: Image(uiImage: lensed),
                            preview: SharePreview("하늘색", image: Image(uiImage: lensed))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .disabled(working)
                    }
                }
                .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        // The way back sits at the head of the strip rather than
                        // somewhere else on the screen, so putting a sky down is
                        // the same gesture as picking one up.
                        if lens != nil {
                            Button {
                                lens = nil
                            } label: {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.fill.tertiary)
                                    .frame(width: 46, height: 46)
                                    .overlay {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("원래 하늘로")
                        }

                        ForEach(lenses) { sky in
                            Button {
                                lens = lens?.uuid == sky.uuid ? nil : sky
                            } label: {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(sky.rgb))
                                    .frame(width: 46, height: 46)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(.primary, lineWidth: lens?.uuid == sky.uuid ? 2.5 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(sky.capturedAt, format: .dateTime.month().day().hour().minute()))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                // The strip is edge to edge; only the chrome around it is inset.
                .padding(.horizontal, -16)
                .safeAreaPadding(.horizontal, 16)

                if let lens {
                    HStack(spacing: 6) {
                        Text(lens.capturedAt, format: .dateTime.month().day().hour().minute())
                        Text("·")
                        Text(SkySimiles.nearest(to: lens.lab).simile.name)
                            .lineLimit(1)
                        Spacer()
                        if working {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)

                    // How far to go. All the way is the whole of that day's
                    // colour; short of it is this sky on the way there, which is
                    // often the truer picture — a noon blue does not become a
                    // midnight in one step without looking painted.
                    Slider(value: $strength, in: 0...1)
                        .tint(Color(lens.rgb))
                        .padding(.horizontal, 4)
                        .accessibilityLabel("빌려 온 하늘의 세기")
                }
            }
            .animation(.easeOut(duration: 0.22), value: lens?.uuid)
        }
    }

    /// Changes when there is new work to do, and cancels the render in flight.
    private var borrowKey: String {
        guard let lens else { return "none" }
        // Quantised, so a drag across the slider asks for a few dozen renders
        // rather than one per pixel of travel.
        return "\(lens.uuid)-\(Int((strength * 40).rounded()))"
    }

    private func borrow() async {
        guard let lens, let original = entry.photo else {
            lensed = nil
            working = false
            return
        }

        // A beat before starting, so a slider drag throws away its intermediate
        // positions instead of rendering every one of them.
        try? await Task.sleep(for: .milliseconds(90))
        guard !Task.isCancelled else { return }

        working = true
        let source = entry.lab
        let target = lens.lab
        let amount = strength
        let rendered = await Task.detached(priority: .userInitiated) {
            SkyRecolor.apply(to: original, from: source, to: target, strength: amount)
        }.value

        guard !Task.isCancelled else { return }
        lensed = rendered
        working = false
    }

    private func gatherLenses() {
        lenses = SkyEntry.palette(from: collected, excluding: entry)
    }

    private func delete() {
        entry.forgetImages()
        context.delete(entry)
        dismiss()
    }
}
