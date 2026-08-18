import SwiftUI
import WidgetKit

/// The sky you got today, as you took it.
///
/// On the home screen it is the photograph, with what the colour is like written
/// on it — the same two things the app puts up when you press a bead, at the
/// size a widget has. If today has no sky yet, the face is the colour this half
/// hour usually is, drawn faint, and one line saying there is nothing yet.
/// Nothing counts up and nothing goes red.
///
/// On the lock screen it is words. Accessory widgets are rendered in a single
/// tint, which means a colour put there is not a colour any more — a sky is
/// whatever grey the wallpaper decided. So the lock screen gets the name and the
/// time instead, which survive the tint intact, and the colour stays where it
/// can be seen.
struct TodaySkyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SkyDexToday", provider: SkyProvider()) { entry in
            TodaySkyWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 하늘")
        .description("오늘 찍은 하늘과, 그 색이 어떤 색인지.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct TodaySkyWidgetView: View {
    let entry: SkyEntryTimeline

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            // The photograph is the background rather than something inside a
            // padded frame, so a sky reaches the corners of the widget the same
            // way it reaches the corners of the board.
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            if let today = entry.today {
                Text("오늘의 하늘 · \(today.likeness)")
            } else {
                Text("오늘의 하늘 · 아직")
            }
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    @ViewBuilder
    private var background: some View {
        if family == .systemSmall, let today = entry.today {
            if let data = SkySnapshot.photo(), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(RGB(hex: today.hex) ?? RGB(r: 0.5, g: 0.5, b: 0.5))
            }
        } else {
            Color(.systemBackground)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let today = entry.today {
                Text(today.isCloseLikeness ? "오늘의 하늘, 말로 하면" : "오늘의 하늘, 굳이 말하자면")
                    .font(.caption2)
                Text(today.likeness)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(today.capturedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
            } else {
                Text("오늘의 하늘")
                    .font(.caption2)
                Text("아직 없습니다")
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var small: some View {
        if let today = entry.today {
            face(today)
        } else {
            waiting
        }
    }

    /// The photograph itself when there is one, its colour when the thumbnail
    /// could not be read. A widget never shows a spinner or an empty frame: the
    /// colour is always known, so there is always something true to draw.
    private func face(_ today: SkySnapshot.Latest) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Spacer(minLength: 0)
            Text(today.likeness)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(today.capturedAt, format: .dateTime.hour().minute())
                .font(.caption2)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Nothing today. The face is this half hour's expected colour, faint — the
    /// same ghost the board draws in an empty slot — so the widget still says
    /// something true about the sky right now.
    private var waiting: some View {
        let ghost = entry.snapshot?.colour(of: entry.nowSlot).rgb
        return VStack(alignment: .leading, spacing: 3) {
            Spacer(minLength: 0)
            Circle()
                .strokeBorder(
                    Color(ghost ?? RGB(r: 0.6, g: 0.6, b: 0.6)),
                    lineWidth: 7
                )
                .frame(width: 40, height: 40)
            Spacer(minLength: 0)
            Text("오늘의 하늘")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("아직 없습니다")
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
