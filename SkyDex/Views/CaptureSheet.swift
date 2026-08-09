import SwiftUI
import SwiftData
import PhotosUI

struct CaptureSheet: View {
    let held: [String: [Lab]]
    let clock: SolarClock
    let seasonKey: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var outcome: CollectOutcome?
    @State private var saved: SkyEntry?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isWorking = false
    @State private var name = ""
    @FocusState private var naming: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let outcome { result(outcome) } else { prompt }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(saved == nil ? "닫기" : "완료") { commitName(); dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { evaluate($0) }.ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await loadFromLibrary(item) }
            }
        }
    }

    private var prompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("하늘이 화면 위쪽을 채우도록")
                    .font(.headline)
                Text("위쪽 3분의 1만 잘라 작게 보관합니다. 위치 정보는 지워집니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if CameraPicker.isAvailable {
                Button { showCamera = true } label: {
                    Label("카메라로 찍기", systemImage: "camera")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("사진에서 고르기", systemImage: "photo")
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.bordered)

            if isWorking { ProgressView() }
        }
    }

    private func result(_ outcome: CollectOutcome) -> some View {
        VStack(spacing: 18) {
            if let entry = saved {
                SkyCardView(entry: entry, height: 200, compact: false)
                    .frame(maxWidth: 340)
            }

            VStack(spacing: 6) {
                Text(outcome.headline).font(.title3.weight(.medium))
                Text(outcome.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if saved != nil { namingField }

            HStack(spacing: 12) {
                Button("한 번 더") { reset() }.buttonStyle(.bordered)
                Button("완료") { commitName(); dismiss() }.buttonStyle(.borderedProminent)
            }
        }
    }

    /// A blank asking "how was your day" is homework. A blank with 하늘 already
    /// printed at the end is a fill-in — no sentence to compose, just a
    /// modifier. Leaving it empty still saves.
    private var namingField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("오늘은 무슨 하늘인가요")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("면접에 떨어졌지만 기분이 후련한", text: $name, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($naming)
                Text("하늘")
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 0.5)
            }
            Text("비워두어도 저장됩니다 · 나중에 채워 넣을 수 있어요")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: 340)
    }

    // MARK: - Work

    private func loadFromLibrary(_ item: PhotosPickerItem) async {
        isWorking = true
        defer { isWorking = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            outcome = .noSkyFound
            return
        }
        evaluate(image)
    }

    private func evaluate(_ image: UIImage) {
        var lookup = held
        if let existing = saved, existing.isNovel {
            lookup[existing.bandKey, default: []].append(existing.lab)
        }
        let result = CollectEngine(held: lookup, clock: clock).attempt(image: image)
        outcome = result
        name = ""
        saved = persist(result, image: image)
    }

    /// Every readable sky is stored, and so is its picture. `isNovel` decides
    /// only whether it also becomes a dot.
    private func persist(_ outcome: CollectOutcome, image: UIImage) -> SkyEntry? {
        let palette: SkyPalette
        let position: SolarPosition
        var bandKey = ""
        var novel = false
        var distance: Double?

        switch outcome {
        case let .newColor(p, pos, band, novelty, _, _):
            palette = p; position = pos; bandKey = band.key; novel = true; distance = novelty
        case let .alreadyHeld(p, pos, band, gap):
            palette = p; position = pos; bandKey = band.key; distance = gap
        case let .afterDark(p, pos, _):
            palette = p; position = pos
        case .noSkyFound:
            return nil
        }

        let entry = SkyEntry(
            capturedAt: .now, palette: palette, position: position,
            bandKey: bandKey, seasonKey: seasonKey,
            isNovel: novel, noveltyDistance: distance,
            photoName: PhotoStore.save(image) ?? ""
        )
        context.insert(entry)
        return entry
    }

    private func commitName() {
        guard let saved else { return }
        saved.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func reset() {
        commitName()
        outcome = nil
        saved = nil
        name = ""
        pickerItem = nil
    }
}
