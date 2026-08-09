import SwiftUI
import SwiftData

struct EntryDetailView: View {
    @Bindable var entry: SkyEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var all: [SkyEntry]

    @State private var photoExpanded = false

    private var matches: [SameSky.Match] { SameSky.matches(for: entry, in: all) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SkyCardView(entry: entry, height: 240, compact: false, photoExpanded: photoExpanded)
                        .onTapGesture { withAnimation { photoExpanded.toggle() } }
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)

                    naming
                    facts
                    if !matches.isEmpty { sameSky }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if entry.isStale {
                            Button("팔레트 다시 뽑기", systemImage: "arrow.clockwise") { recompute() }
                        }
                        Button("삭제", systemImage: "trash", role: .destructive) {
                            PhotoStore.delete(entry.photoName)
                            context.delete(entry)
                            dismiss()
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
    }

    private var naming: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("이름")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("무슨 하늘이었나요", text: $entry.name, axis: .vertical)
                    .font(.title3)
                    .lineLimit(1...3)
                Text("하늘")
                    .font(.title3)
                    .foregroundStyle(.primary.opacity(0.5))
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.primary.opacity(0.3)).frame(height: 1)
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("찍은 때", entry.capturedAt.formatted(.dateTime.month().day().weekday(.wide).hour().minute()))
            row("구간", entry.bandName)
            row("코드", entry.code)
            if entry.isNovel {
                if let distance = entry.noveltyDistance {
                    row("가장 가까운 색과", "ΔE " + String(format: "%.1f", distance))
                } else {
                    row("이 구간의", "첫 하늘")
                }
            } else if entry.phase == .night {
                row("다이얼", "해가 진 뒤")
            } else if let distance = entry.noveltyDistance {
                row("이미 가진 색과", "ΔE " + String(format: "%.1f", distance))
            }
            if !entry.paletteHexes.isEmpty {
                row("팔레트", "\(entry.paletteHexes.count)색 · 오차 ΔE " + String(format: "%.1f", entry.reconstructionError))
            }
            if entry.isStale {
                Label("다시 뽑을 수 있어요", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.7))
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).monospacedDigit()
        }
    }

    /// Colour as an index into memory: days a calendar would never put together.
    private var sameSky: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("같은 하늘이었던 날")
                .font(.subheadline.weight(.medium))
            ForEach(matches) { match in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(
                            colors: match.entry.palette.isEmpty
                                ? [Color(match.entry.anchor)]
                                : match.entry.palette.map { Color($0) },
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 46, height: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.entry.displayName + " 하늘")
                            .font(.subheadline)
                            .lineLimit(2)
                        Text(match.entry.capturedAt.formatted(.dateTime.year().month().day()))
                            .font(.footnote)
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                    Spacer()
                    Text("ΔE " + String(format: "%.1f", match.distance))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
        }
    }

    /// Only possible because the picture was kept. Without it every entry would
    /// stay frozen at whatever version of the extractor produced it.
    private func recompute() {
        guard let photo = PhotoStore.load(entry.photoName),
              let palette = SkyColorExtractor.extract(from: photo) else { return }
        entry.anchorHex = palette.anchor.hex
        entry.labL = palette.anchorLab.l
        entry.labA = palette.anchorLab.a
        entry.labB = palette.anchorLab.b
        entry.paletteHexes = palette.colors.map(\.hex)
        entry.reconstructionError = palette.reconstructionError
        entry.extractorVersion = SkyColorExtractor.version
    }
}
