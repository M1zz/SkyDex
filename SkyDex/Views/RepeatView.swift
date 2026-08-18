import SwiftData
import SwiftUI

/// The one thing the collection can prove.
///
/// A life is built out of repeats. The same alarm, the same walk to the same
/// station, the same window at the same desk — a week is a shape that happens
/// again, and so is a month. The sky over all of it is the part that never
/// takes the same value twice, and nobody notices because nobody writes it
/// down.
///
/// This screen is that argument, made with the person's own photographs and
/// nothing else. Every row is one half hour of the day that they have stood in
/// more than once: same time, same routine, the repeating part. Along the row
/// are the skies they actually got, in the order the days came. The row is the
/// repetition and the colours are the refusal, and the two are drawn on the same
/// line so that no sentence is needed to connect them.
///
/// The number at the bottom is the claim stated exactly. Of every pair of skies
/// taken at the same time of day, the closest two still differ by some CIEDE2000
/// distance, and it is printed — under one it would be fair to call a repeat, and
/// the app would have to say so. It has never happened yet, and saying "never"
/// with the smallest measured distance next to it is the difference between a
/// slogan and a finding.
///
/// Retakes inside one day are folded to the last one first. Shooting the same
/// half hour twice this afternoon is not the day repeating, it is one day, and
/// counting it would be counting the same sky as evidence against itself.
struct RepeatView: View {
    let entries: [SkyEntry]

    /// Open one, the same way everything else in the archive opens.
    let onSelect: (SkyEntry) -> Void

    private var rows: [SlotRun] { RepeatView.runs(of: entries) }

    /// The two most alike skies ever taken at the same time of day.
    private var closest: Pair? { RepeatView.closestPair(in: rows) }

    var body: some View {
        Group {
            if rows.isEmpty {
                ContentUnavailableView(
                    "아직 되풀이가 없어요",
                    systemImage: "arrow.trianglehead.2.clockwise",
                    description: Text("같은 시각의 하늘을 다른 날에 한 번 더 찍으면, 그 둘이 여기에서 나란히 섭니다.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        preamble
                        ForEach(rows) { row in
                            run(row)
                        }
                        if let closest {
                            finding(closest)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    // The shutter floats over the bottom of every screen, and
                    // the last row of a scroll has to be able to get out from
                    // under it.
                    .padding(.bottom, 96)
                }
            }
        }
    }

    /// Said once, at the top, in the smallest type that can still be read. The
    /// rows underneath are the actual argument; this only says what to look at.
    private var preamble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("같은 시각, 같은 하루")
                .font(.subheadline.weight(.medium))
            Text("일주일도 한 달도 같은 모양으로 돌아옵니다. 그 시각의 하늘만 한 번도 같지 않았습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    /// One half hour, and every sky ever collected in it.
    ///
    /// The swatches share the width equally and sit three points apart, the same
    /// way the palette is drawn — a row read left to right is a sequence of days,
    /// and the eye should cross it without being asked to stop at each one. The
    /// date under each is what makes it days rather than colours.
    private func run(_ row: SlotRun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.slot.timeLabel)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                Text(row.slot.band)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(row.entries.count)일")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 3) {
                ForEach(row.entries) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(entry.rgb))
                                .frame(height: 58)
                            Text(entry.capturedAt, format: .dateTime.month(.defaultDigits).day())
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// The claim, with the number that keeps it honest.
    private func finding(_ pair: Pair) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // The rows above are the evidence and this is the reading of it, so
            // there is a line between them.
            Divider()
                .padding(.bottom, 8)

            Text("가장 비슷했던 두 하늘")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                swatch(pair.a)
                swatch(pair.b)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "ΔE %.1f", pair.distance))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    // Under one, two colours are the same colour to look at. The
                    // sentence has to change if that ever happens, so it is
                    // written from the number rather than around it.
                    Text(pair.distance < 1 ? "눈으로는 같은 색입니다." : "그래도 다른 색입니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(pair.slot.timeLabel) · \(RepeatView.day(pair.a.capturedAt))과 \(RepeatView.day(pair.b.capturedAt))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 6)
    }

    private func swatch(_ entry: SkyEntry) -> some View {
        Button {
            onSelect(entry)
        } label: {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(entry.rgb))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
    }

    private static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }

    // MARK: - The arithmetic

    struct SlotRun: Identifiable {
        let slot: SkySlot
        /// One per day, oldest first.
        let entries: [SkyEntry]
        var id: Int { slot.id }
    }

    struct Pair {
        let slot: SkySlot
        let a: SkyEntry
        let b: SkyEntry
        let distance: Double
    }

    /// Every half hour that has been stood in on more than one day.
    ///
    /// Same-day retakes collapse to the last one, because a day cannot repeat
    /// itself; the board treats a second shot in the same half hour as replacing
    /// the first and this has to agree with it.
    static func runs(of entries: [SkyEntry]) -> [SlotRun] {
        let bySlot = Dictionary(grouping: entries) { SkyBoard.slot(forMinute: $0.minuteOfDay).id }
        return SkyBoard.slots.compactMap { slot in
            guard let inSlot = bySlot[slot.id] else { return nil }
            let byDay = Dictionary(grouping: inSlot) {
                Calendar.current.startOfDay(for: $0.capturedAt)
            }
            let oneEach = byDay
                .compactMap { _, sameDay in sameDay.max { $0.capturedAt < $1.capturedAt } }
                .sorted { $0.capturedAt < $1.capturedAt }
            guard oneEach.count > 1 else { return nil }
            return SlotRun(slot: slot, entries: oneEach)
        }
    }

    /// The nearest two skies taken at the same time of day, across every row.
    static func closestPair(in rows: [SlotRun]) -> Pair? {
        var best: Pair?
        for row in rows {
            for i in row.entries.indices {
                for j in row.entries.index(after: i)..<row.entries.endIndex {
                    let distance = deltaE2000(row.entries[i].lab, row.entries[j].lab)
                    if distance < (best?.distance ?? .greatestFiniteMagnitude) {
                        best = Pair(
                            slot: row.slot,
                            a: row.entries[i],
                            b: row.entries[j],
                            distance: distance
                        )
                    }
                }
            }
        }
        return best
    }
}
