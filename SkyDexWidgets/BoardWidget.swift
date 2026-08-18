import SwiftUI
import WidgetKit

/// The board, on the home screen.
///
/// The app's one picture: forty-eight half hours of one day, night at the top,
/// noon in the middle, night again at the bottom. Rings for the slots the
/// collection does not cover yet, discs for the ones it does, and a thin circle
/// around the half hour it is right now.
///
/// It carries no text at the large size, exactly as the board carries none. The
/// shape of a day is legible without labels — that is the whole point of drawing
/// it — and a widget is the last place to start explaining a picture that
/// explains itself.
///
/// The medium size is a different shape from a day, so it is not the same
/// picture squeezed. The board keeps its proportions on the left and the space
/// that is left over says what today's sky was called, which is the one thing
/// worth reading at a glance from across a room.
struct BoardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SkyDexBoard", provider: SkyProvider()) { entry in
            BoardWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("오늘의 판")
        .description("하루 마흔여덟 칸. 모은 하늘은 채워지고, 지금 시각에는 고리가 걸립니다.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct BoardWidgetView: View {
    let entry: SkyEntryTimeline

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemMedium {
            HStack(spacing: 14) {
                board
                    .aspectRatio(
                        CGFloat(SkyBoard.columns) / CGFloat(SkyBoard.slots.count / SkyBoard.columns),
                        contentMode: .fit
                    )
                beside
            }
        } else {
            board
        }
    }

    /// Six across, eight down, filling whatever it is given.
    private var board: some View {
        GeometryReader { area in
            let columns = CGFloat(SkyBoard.columns)
            let rows = CGFloat(SkyBoard.slots.count / SkyBoard.columns)
            let gap: CGFloat = max(2, min(area.size.width, area.size.height) * 0.022)
            let diameter = min(
                (area.size.width - gap * (columns - 1)) / columns,
                (area.size.height - gap * (rows - 1)) / rows
            )
            VStack(spacing: gap) {
                ForEach(0..<Int(rows), id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<SkyBoard.columns, id: \.self) { column in
                            bead(row * SkyBoard.columns + column, diameter: diameter)
                        }
                    }
                }
            }
            .frame(width: area.size.width, height: area.size.height)
        }
    }

    private func bead(_ slot: Int, diameter: CGFloat) -> some View {
        let colour = entry.snapshot?.colour(of: slot)
        return ZStack {
            if let colour, colour.isFilled {
                Circle().fill(Color(colour.rgb))
            } else if let colour {
                Circle()
                    .strokeBorder(Color(colour.rgb), lineWidth: max(1.5, diameter * 0.17))
            } else {
                // No snapshot at all — the app has never been open, or the
                // shared container is not there. An empty board is the honest
                // drawing of that, and it is also what the app looks like on the
                // first day.
                Circle()
                    .strokeBorder(.tertiary, lineWidth: max(1.5, diameter * 0.17))
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay {
            if slot == entry.nowSlot {
                Circle()
                    .strokeBorder(.primary.opacity(0.5), lineWidth: 1)
                    .frame(width: diameter + 5, height: diameter + 5)
            }
        }
    }

    /// The medium size's right-hand column.
    @ViewBuilder
    private var beside: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let today = entry.today {
                Text(today.isCloseLikeness ? "오늘의 하늘, 말로 하면" : "오늘의 하늘, 굳이 말하자면")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(RGB(hex: today.hex) ?? RGB(r: 0.5, g: 0.5, b: 0.5)))
                        .frame(width: 12, height: 12)
                    Text(today.likeness)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Text(today.capturedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !today.note.isEmpty {
                    Text(today.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            } else {
                Text("오늘의 하늘")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                // Said once, without a nudge attached. The board is already
                // showing what is missing; saying it twice would be nagging.
                Text("아직 없습니다")
                    .font(.headline)
                Text("밖을 한 번 올려다보면 이 시각 칸이 채워집니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
