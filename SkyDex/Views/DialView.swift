import SwiftUI
import SwiftData

/// The arc.
///
/// Sunrise on the left, noon at the top, sunset on the right, with twilight
/// hanging just below the horizon at each end. A full circle spent half its
/// area on a night sky that does not change colour, and on a phone it forced
/// the radius down to fit the height.
struct DialView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SkyEntry.capturedAt, order: .reverse) private var entries: [SkyEntry]

    @AppStorage("latitude") private var latitude = SolarClock.deviceDefault.latitude
    @AppStorage("longitude") private var longitude = SolarClock.deviceDefault.longitude

    @State private var showCapture = false
    @State private var showHorizon = false
    @State private var selectedEntry: SkyEntry?
    @State private var selectedReference: ReferenceSky?

    private var clock: SolarClock { SolarClock(latitude: latitude, longitude: longitude) }
    private var seasonKey: String { Season.key(for: .now) }

    private var seasonEntries: [SkyEntry] { entries.filter { $0.seasonKey == seasonKey } }
    private var dots: [SkyEntry] { seasonEntries.filter { $0.isNovel && $0.dialAngle != nil } }

    private var heldByBand: [String: [Lab]] {
        Dictionary(grouping: dots, by: \.bandKey).mapValues { $0.map(\.lab) }
    }

    private var reached: Set<String> {
        var result: Set<String> = []
        let held = heldByBand
        for reference in Palette.references {
            guard let labs = held[reference.bandKey] else { continue }
            if labs.contains(where: { deltaE2000($0, reference.lab) <= Palette.reachThreshold }) {
                result.insert(reference.id)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // The arc and its counts read as one object, so they are
                // centred together; a half-disc on a tall screen otherwise
                // leaves its slack in two unrelated gaps.
                GeometryReader { geo in
                    let layout = DialLayout(
                        size: CGSize(width: geo.size.width, height: geo.size.height - 104)
                    )
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)
                        arc(layout: layout, width: geo.size.width)
                            .frame(height: layout.height)
                        summary.padding(.horizontal, 20)
                        Spacer(minLength: 0)
                    }
                }

                Button {
                    showCapture = true
                } label: {
                    Label("하늘 찍기", systemImage: "camera.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationTitle(Season.label(forKey: seasonKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHorizon = true } label: { Image(systemName: "sun.horizon") }
                        .accessibilityLabel("지평선 맞추기")
                }
            }
            .sheet(isPresented: $showCapture) {
                CaptureSheet(held: heldByBand, clock: clock, seasonKey: seasonKey)
            }
            .sheet(isPresented: $showHorizon) {
                HorizonSettingsView(latitude: $latitude, longitude: $longitude)
            }
            .sheet(item: $selectedEntry) { EntryDetailView(entry: $0) }
            .sheet(item: $selectedReference) { reference in
                ReferenceDetailView(reference: reference, isReached: reached.contains(reference.id))
            }
        }
    }

    // MARK: - Arc

    private func arc(layout: DialLayout, width: CGFloat) -> some View {
        let unit = layout.unit
        let rim = layout.rim
        let center = CGPoint(x: width / 2, y: layout.noonRoom + rim)
        let tipY = center.y + layout.dip * rim
        // The arc runs nearly the full width, so the tip labels stop at the
        // margin instead of following the tip off the screen.
        let leftTipX = max(DialLayout.tipHalfWidth + 6, center.x - layout.spread * rim)
        let rightTipX = min(width - DialLayout.tipHalfWidth - 6, center.x + layout.spread * rim)
        let dotSize = max(11.0, unit * 0.082)
        let today = clock.events(on: .now)
        let now = clock.position(of: .now)

        return ZStack {
            ArcDisc(center: center, radius: rim)
                .fill(Color(red: 0.48, green: 0.65, blue: 0.83).opacity(0.13))

            ForEach([DialGeometry.innerFraction, 0.6, DialGeometry.outerFraction], id: \.self) {
                fraction in
                ArcDisc(center: center, radius: unit * fraction, closed: false)
                    .stroke(Color.secondary.opacity(0.13), lineWidth: 0.5)
            }

            Path { path in
                path.move(to: CGPoint(x: center.x - rim, y: center.y))
                path.addLine(to: CGPoint(x: center.x + rim, y: center.y))
            }
            .stroke(Color.secondary.opacity(0.35), lineWidth: 0.5)

            ClockTicks(center: center, unit: unit, clock: clock, date: .now)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)

            ForEach(Palette.references) { reference in
                ReferenceDotView(
                    reference: reference,
                    isReached: reached.contains(reference.id),
                    diameter: dotSize * 0.7
                )
                .position(
                    DialGeometry.point(
                        angle: reference.band?.centreAngle ?? 270,
                        lab: reference.lab, center: center, unit: unit
                    )
                )
                .onTapGesture { selectedReference = reference }
            }

            ForEach(dots) { entry in
                if let angle = entry.dialAngle {
                    Circle()
                        .fill(Color(entry.anchor))
                        .frame(width: dotSize, height: dotSize)
                        .contentShape(Circle())
                        .position(
                            DialGeometry.point(
                                angle: angle, lab: entry.lab, center: center, unit: unit
                            )
                        )
                        .onTapGesture { selectedEntry = entry }
                }
            }

            if let angle = now.dialAngle {
                Circle()
                    .fill(Color.orange.opacity(0.22))
                    .frame(width: 18, height: 18)
                    .position(DialGeometry.point(on: angle, radius: rim, center: center))
                Circle()
                    .fill(Color.orange)
                    .frame(width: 9, height: 9)
                    .position(DialGeometry.point(on: angle, radius: rim, center: center))
            }

            Image(systemName: "sun.max.fill")
                .font(.system(size: 19))
                .foregroundStyle(.secondary)
                .accessibilityLabel("정오")
                .position(x: center.x, y: center.y - rim - 18)

            tipLabel("sunrise.fill", today?.sunrise, name: "일출")
                .position(x: leftTipX, y: tipY + 26)
            tipLabel("sunset.fill", today?.sunset, name: "일몰")
                .position(x: rightTipX, y: tipY + 26)

            // The empty wedge under the horizon is the one place a first-time
            // reading of the arc can be handed over without crowding it.
            if dots.isEmpty {
                Text("해가 떠 있는 동안 하늘을 찍으면\n찍은 시각과 밝기 자리에 색이 남습니다")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: min(rim * 1.25, width - 80))
                    .position(x: center.x, y: center.y + 42)
            }
        }
        // The labels inside the arc are pinned to geometry, not to a stack that
        // can reflow, so they are held at a size the reserved room fits.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    /// Sunrise and sunset hang under the twilight tips, where the arc has
    /// already run out and nothing else competes for the space.
    ///
    /// A sun over the horizon says which end of the day this is faster than the
    /// word does, and it leaves the width to the time underneath — which is the
    /// part actually worth reading.
    private func tipLabel(_ symbol: String, _ hour: Double?, name: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 19))
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel(name)
            if let hour {
                Text(SolarClock.clockString(hour))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary.opacity(0.7))
            }
        }
        .foregroundStyle(.secondary)
        .fixedSize()
    }

    // MARK: - Summary

    /// Three counts on one line, below the arc rather than inside it: the arc
    /// stays a picture, and the numbers stay readable.
    private var summary: some View {
        HStack(spacing: 0) {
            stat("\(dots.count)", "모은 색")
            statDivider
            stat("\(reached.count) / \(Palette.references.count)", "참고 색")
            statDivider
            stat(status.value, status.label)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 0.5, height: 34)
    }

    /// A fact about the world, not a nudge about the user. "Four hours of light
    /// left" is an invitation; "you haven't shot in three days" is a reprimand.
    private var status: (value: String, label: String) {
        let fallback = ("\(seasonEntries.count)회", "이번 계절")
        guard let events = clock.events(on: .now) else { return fallback }
        let hour = SolarClock.decimalHour(of: .now)
        guard hour > events.sunrise, hour < events.sunset else {
            guard let next = clock.nextFirstLight(after: .now) else { return fallback }
            return (SolarClock.clockString(next), "다음 첫빛")
        }
        let minutes = Int(((events.sunset - hour) * 60).rounded())
        let value = minutes >= 60
            ? "\(minutes / 60)시간 \(minutes % 60)분"
            : "\(minutes)분"
        return (value, "남은 일광")
    }
}

/// The one place the arc's size is decided.
///
/// The view that reserves the space and the code that draws into it have to
/// agree, or labels drift off the edge — which is exactly how sunrise and
/// sunset used to end up half off the screen.
struct DialLayout {
    /// How far the twilight tips reach past the horizon: sideways, and down.
    let spread: CGFloat
    let dip: CGFloat
    let unit: CGFloat
    let rim: CGFloat

    /// Room for "정오" above the rim, and for the two-line tip labels below
    /// each end of the arc. Sized for the labels at their largest permitted
    /// rendering, so the arc gives up space rather than the text being cut.
    let noonRoom: CGFloat = 34
    let tipRoom: CGFloat = 56
    /// The symbol is narrower than the time under it, so the time sets this.
    static let tipHalfWidth: CGFloat = 29

    var height: CGFloat { noonRoom + rim * (1 + dip) + tipRoom }

    init(size: CGSize) {
        let radians = DialGeometry.arcStart * .pi / 180
        let spread = CGFloat(-cos(radians))
        let dip = CGFloat(sin(radians))
        self.spread = spread
        self.dip = dip

        let byWidth = size.width / 2 - 26
        let byHeight = (size.height - 34 - 56) / (1 + dip) - 16
        let unit = max(70, min(byWidth, byHeight))
        self.unit = unit
        self.rim = unit + 16
    }
}

/// A reference colour. Nearly invisible once reached, so the arc ends up
/// showing the user's own collection rather than the scaffold it hung on.
struct ReferenceDotView: View {
    let reference: ReferenceSky
    let isReached: Bool
    let diameter: CGFloat

    var body: some View {
        Circle()
            .strokeBorder(
                Color.secondary.opacity(isReached ? 0.12 : 0.3),
                style: StrokeStyle(lineWidth: 0.75, dash: isReached ? [] : [1.5, 2.5])
            )
            .background(Circle().fill(Color(reference.rgb).opacity(isReached ? 0.05 : 0.1)))
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
    }
}

#Preview {
    DialView().modelContainer(for: SkyEntry.self, inMemory: true)
}
