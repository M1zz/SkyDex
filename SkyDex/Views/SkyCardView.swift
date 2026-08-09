import SwiftUI

/// A colour card in Pantone's shape, with three faces instead of one.
///
/// Left is the palette pulled out of the photo, middle is the sky redrawn from
/// only those colours, right is the photograph. The seam between the middle and
/// the right is the interesting part: on a clear sky it nearly vanishes, and on
/// a complicated sunset it shows exactly what six colours could not hold.
struct SkyCardView: View {
    let entry: SkyEntry
    var height: CGFloat = 176
    var compact: Bool = true
    /// Photo takes the whole panel instead of a third.
    var photoExpanded: Bool = false

    private var palette: [Color] {
        let colors = entry.palette.map { Color($0) }
        return colors.isEmpty ? [Color(entry.anchor)] : colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            triptych
            caption
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
    }

    private var triptych: some View {
        GeometryReader { geo in
            let full = geo.size.width
            let third = full / 3
            HStack(spacing: 0) {
                // Hard bands: the palette exactly as extracted.
                VStack(spacing: 0) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                        color
                    }
                }
                .frame(width: photoExpanded ? 0 : third)
                .clipped()

                // The same colours interpolated back into a sky.
                LinearGradient(colors: palette, startPoint: .top, endPoint: .bottom)
                    .frame(width: photoExpanded ? 0 : third)
                    .clipped()

                ZStack(alignment: .topTrailing) {
                    if let photo = PhotoStore.load(entry.photoName) {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(entry.anchor)
                    }
                    // The little peeled corner of a Pantone sleeve.
                    Path { path in
                        path.move(to: CGPoint(x: 16, y: 0))
                        path.addLine(to: CGPoint(x: 16, y: 16))
                        path.addLine(to: CGPoint(x: 0, y: 0))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 16, height: 16)
                }
                .frame(width: photoExpanded ? full : third)
                .clipped()
            }
            .animation(.easeInOut(duration: 0.45), value: photoExpanded)
        }
        .frame(height: height)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SKYDEX")
                .font(.system(size: compact ? 17 : 23, weight: .heavy))
                .kerning(-0.6)
            Text(entry.code)
                .font(.system(size: compact ? 12 : 15))
                .monospacedDigit()
                .foregroundStyle(.primary.opacity(0.75))
                .padding(.top, compact ? 6 : 8)
            (Text(entry.displayName) + Text(" 하늘").foregroundColor(.secondary))
                .font(.system(size: compact ? 12.5 : 15))
                .lineLimit(compact ? 2 : nil)
                .frame(minHeight: compact ? 34 : 0, alignment: .top)
                .padding(.top, 3)
            Text(metaLine)
                .font(.system(size: compact ? 11 : 13))
                .monospacedDigit()
                .foregroundStyle(.primary.opacity(0.55))
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.top, compact ? 11 : 15)
        .padding(.bottom, compact ? 13 : 17)
    }

    private var metaLine: String {
        var parts = [entry.bandName, entry.capturedAt.formatted(.dateTime.year().month().day())]
        if !entry.paletteHexes.isEmpty { parts.append("\(entry.paletteHexes.count)색") }
        if entry.reconstructionError > 0 {
            parts.append("오차 ΔE \(String(format: "%.1f", entry.reconstructionError))")
        }
        return parts.joined(separator: " · ")
    }
}
