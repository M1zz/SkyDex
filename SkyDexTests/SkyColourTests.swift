//
//  SkyColourTests.swift
//  하늘색
//
//  하늘색의 값은 "이 두 색이 같은 색인가" 한 질문에 달려 있다 —
//  색 거리(CIEDE2000) · Lab 변환 · 하루를 48칸으로 나누기 · 사진을 구슬에 앉히기.
//

import XCTest
@testable import SkyDex

final class SkyColourTests: XCTestCase {

    // MARK: - CIEDE2000

    /// Sharma, Wu, Dalal (2005) "The CIEDE2000 Color-Difference Formula" 의 검증 표에서.
    func testDeltaE2000MatchesPublishedReferencePairs() {
        let pairs: [(Lab, Lab, Double)] = [
            (Lab(l: 50, a: 2.6772, b: -79.7751), Lab(l: 50, a: 0, b: -82.7485), 2.0425),
            (Lab(l: 50, a: 0, b: 0), Lab(l: 50, a: -1, b: 2), 2.3669),
            (Lab(l: 50, a: 2.5, b: 0), Lab(l: 73, a: 25, b: -18), 27.1492),
            (Lab(l: 60.2574, a: -34.0099, b: 36.2677), Lab(l: 60.4626, a: -34.1751, b: 39.4387), 1.2644),
            (Lab(l: 50, a: 2.49, b: -0.001), Lab(l: 50, a: -2.49, b: 0.0011), 7.2195),
            (Lab(l: 2.0776, a: 0.0795, b: -1.1350), Lab(l: 0.9033, a: -0.0636, b: -0.5514), 0.9082)
        ]
        for (x, y, expected) in pairs {
            XCTAssertEqual(deltaE2000(x, y), expected, accuracy: 0.0001, "\(x) ↔ \(y)")
        }
    }

    func testDeltaE2000IsSymmetricAndZeroForSameColour() {
        let sky = Lab(l: 62, a: -8, b: -31)
        let dusk = Lab(l: 40, a: 22, b: -12)
        XCTAssertEqual(deltaE2000(sky, sky), 0, accuracy: 1e-9)
        XCTAssertEqual(deltaE2000(sky, dusk), deltaE2000(dusk, sky), accuracy: 1e-9)
    }

    // MARK: - Lab ↔ RGB

    func testWhiteAndBlackLandOnTheLightnessAxis() {
        let white = Lab(RGB(r: 1, g: 1, b: 1))
        XCTAssertEqual(white.l, 100, accuracy: 0.01)
        XCTAssertEqual(white.a, 0, accuracy: 0.01)
        XCTAssertEqual(white.b, 0, accuracy: 0.01)
        XCTAssertEqual(Lab(RGB(r: 0, g: 0, b: 0)).l, 0, accuracy: 0.01)
    }

    func testRGBLabRoundTrip() {
        for hex in ["#7FA7D9", "#F2B880", "#3C3357", "#C9D6DF"] {
            let rgb = RGB(hex: hex)!
            let back = RGB(Lab(rgb))
            XCTAssertEqual(back.r, rgb.r, accuracy: 0.002, hex)
            XCTAssertEqual(back.g, rgb.g, accuracy: 0.002, hex)
            XCTAssertEqual(back.b, rgb.b, accuracy: 0.002, hex)
            XCTAssertEqual(back.hex.uppercased(), hex.uppercased())
        }
    }

    func testHexParsingRejectsGarbage() {
        XCTAssertNil(RGB(hex: "not a colour"))
        XCTAssertNotNil(RGB(hex: "#000000"))
    }

    func testBlendIsLinearInLab() {
        let a = Lab(l: 0, a: 10, b: -20), b = Lab(l: 100, a: -10, b: 20)
        XCTAssertEqual(a.blended(toward: b, by: 0), a)
        XCTAssertEqual(a.blended(toward: b, by: 1), b)
        XCTAssertEqual(a.blended(toward: b, by: 0.5), Lab(l: 50, a: 0, b: 0))
    }

    // MARK: - 하루를 48칸으로

    func testBoardCoversTheWholeDayWithoutGapsOrOverlaps() {
        let slots = SkyBoard.slots
        XCTAssertEqual(slots.count, 48)
        XCTAssertEqual(slots.count % SkyBoard.columns, 0, "판은 줄이 꽉 찬다")
        XCTAssertEqual(slots.first?.startMinute, 0)
        XCTAssertEqual(slots.last?.endMinute, 1440)
        for (index, pair) in zip(slots, slots.dropFirst()).enumerated() {
            XCTAssertEqual(pair.0.endMinute, pair.1.startMinute, "칸 \(index) 다음이 이어진다")
            XCTAssertEqual(pair.0.id + 1, pair.1.id)
        }
    }

    func testSunsetGetsFinerSlotsThanTheNight() {
        let night = SkyBoard.slot(forMinute: 60)
        let sunset = SkyBoard.slot(forMinute: 1140)
        XCTAssertGreaterThan(night.endMinute - night.startMinute, sunset.endMinute - sunset.startMinute)
    }

    func testSlotForMinuteRespectsBoundariesAndClamps() {
        for slot in SkyBoard.slots {
            XCTAssertEqual(SkyBoard.slot(forMinute: slot.startMinute).id, slot.id)
            XCTAssertEqual(SkyBoard.slot(forMinute: slot.endMinute - 1).id, slot.id)
        }
        XCTAssertEqual(SkyBoard.slot(forMinute: -30).id, 0)
        XCTAssertEqual(SkyBoard.slot(forMinute: 5_000).id, 47)
    }

    func testMinuteOfDay() {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 27; parts.hour = 18; parts.minute = 42
        let date = Calendar.current.date(from: parts)!
        XCTAssertEqual(SkyEntry.minuteOfDay(of: date), 18 * 60 + 42)
    }

    // MARK: - 바래기

    func testCollectedSkyFadesAfterAWeekAndBottomsOut() {
        let now = Date()
        func entry(daysAgo: Double) -> SkyEntry {
            SkyEntry(capturedAt: now.addingTimeInterval(-daysAgo * 86_400),
                     rgb: RGB(r: 0.5, g: 0.6, b: 0.8), lab: Lab(l: 60, a: 0, b: -20),
                     photoData: nil, thumbnailData: nil)
        }
        XCTAssertEqual(entry(daysAgo: 3).freshness(at: now), 1)
        XCTAssertEqual(entry(daysAgo: 7 + 28).freshness(at: now), 0.5, accuracy: 0.001)
        XCTAssertEqual(entry(daysAgo: 400).freshness(at: now), 0)
    }

    func testFadedNeverReachesTheGhost() {
        let rgb = RGB(r: 0.2, g: 0.5, b: 0.9)
        XCTAssertEqual(SkyBoard.faded(rgb, freshness: 1), rgb)
        let faintest = SkyBoard.faded(rgb, freshness: 0)
        XCTAssertNotEqual(faintest, SkyBoard.ghost(of: rgb), "가장 바랜 구슬도 담긴 구슬로 읽혀야 한다")
    }

    // MARK: - 이름

    func testEverySimileIsItsOwnNearest() {
        for simile in SkySimiles.all {
            let match = SkySimiles.nearest(to: Lab(simile.rgb))
            XCTAssertEqual(match.distance, 0, accuracy: 1e-6, simile.name)
            XCTAssertTrue(match.isClose)
        }
    }
}
