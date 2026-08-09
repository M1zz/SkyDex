import SwiftUI
import SwiftData

/// A season laid on its side.
///
/// One narrow vertical slice cut from each kept photograph, lined up in order.
/// Colour bars would have been easier, but the point is the cloud texture — a
/// rained-out week and a clear one look different, not just darker. This is the
/// one artefact worth sharing, and it is only possible because the pictures
/// were kept.
struct PanoramaView: View {
    let entries: [SkyEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var seasonKey: String = Season.key(for: .now)
    @State private var building = false

    private var seasons: [String] {
        Array(Set(entries.map(\.seasonKey))).sorted(by: >)
    }

    private var slice: [SkyEntry] {
        entries.filter { $0.seasonKey == seasonKey && !$0.photoName.isEmpty }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if seasons.count > 1 {
                    Picker("계절", selection: $seasonKey) {
                        ForEach(seasons, id: \.self) { Text(Season.label(forKey: $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                if building {
                    ProgressView().frame(maxHeight: .infinity)
                } else if let image {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(Season.label(forKey: seasonKey))
                        .font(.footnote).foregroundStyle(.secondary)
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview(Season.label(forKey: seasonKey), image: Image(uiImage: image))
                    ) {
                        Label("내보내기", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                } else {
                    ContentUnavailableView(
                        "사진이 남은 하늘이 아직 없어요",
                        systemImage: "rectangle.split.3x1",
                        description: Text("사진을 보관한 촬영부터 파노라마에 들어갑니다.")
                    )
                }
            }
            .padding(20)
            .navigationTitle("한 계절, 한 장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
            .task(id: seasonKey) { await build() }
        }
    }

    private func build() async {
        building = true
        defer { building = false }
        let sources = slice
        guard !sources.isEmpty else { image = nil; return }
        image = await Task.detached(priority: .userInitiated) {
            PanoramaBuilder.make(from: sources.map(\.photoName))
        }.value
    }
}

enum PanoramaBuilder {
    static let sliceWidth: CGFloat = 22
    static let height: CGFloat = 300

    static func make(from photoNames: [String]) -> UIImage? {
        let images = photoNames.compactMap { PhotoStore.load($0) }
        guard !images.isEmpty else { return nil }

        let size = CGSize(width: sliceWidth * CGFloat(images.count), height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            for (index, photo) in images.enumerated() {
                // Fill a slice-shaped window with the middle of the frame.
                let scale = max(sliceWidth / photo.size.width, height / photo.size.height)
                let drawn = CGSize(
                    width: photo.size.width * scale, height: photo.size.height * scale
                )
                let origin = CGPoint(
                    x: sliceWidth * CGFloat(index) - (drawn.width - sliceWidth) / 2,
                    y: -(drawn.height - height) / 2
                )
                UIGraphicsGetCurrentContext()?.saveGState()
                UIBezierPath(rect: CGRect(
                    x: sliceWidth * CGFloat(index), y: 0, width: sliceWidth, height: height
                )).addClip()
                photo.draw(in: CGRect(origin: origin, size: drawn))
                UIGraphicsGetCurrentContext()?.restoreGState()
            }
        }
    }
}
