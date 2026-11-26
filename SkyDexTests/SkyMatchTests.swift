//
//  SkyMatchTests.swift
//  하늘색
//
//  오늘 판의 구슬에 어떤 하늘이 앉는가 — 시계가 먼저, 그다음 색. 한 하늘은 한 구슬만.
//

import XCTest
@testable import SkyDex

final class SkyMatchTests: XCTestCase {

    private let calendar = Calendar.current
    private var today: Date { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())! }

    private func at(_ hour: Int, _ minute: Int, daysAgo: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func sky(_ lab: Lab, at date: Date) -> SkyEntry {
        SkyEntry(capturedAt: date, rgb: RGB(lab), lab: lab, photoData: nil, thumbnailData: nil)
    }

    /// 48칸 모두 서로 멀리 떨어진 색 — 한 하늘이 두 칸 반경에 같이 들지 않게.
    private var spreadTargets: [Lab] {
        (0..<48).map { (index: Int) -> Lab in
            let a: Double = index % 2 == 0 ? 40 : -40
            return Lab(l: Double(20 + index), a: a, b: Double(index * 3 - 70))
        }
    }

    func testNothingCollectedFillsNothing() {
        XCTAssertTrue(SkyMatch.map(targets: spreadTargets, entries: [], on: today).isEmpty)
    }

    func testTodaysCaptureFillsTheSlotItWasTakenInWhateverItsColour() {
        let photo = sky(Lab(l: 5, a: 0, b: 0), at: at(7, 40))
        let slot = SkyBoard.slot(forMinute: 7 * 60 + 40).id
        let map = SkyMatch.map(targets: spreadTargets, entries: [photo], on: today)
        XCTAssertEqual(map.count, 1)
        XCTAssertTrue(map[slot] === photo)
    }

    func testNewerCaptureInTheSameStretchReplacesTheOlder() {
        let slot = SkyBoard.slot(forMinute: 13 * 60 + 5)
        let first = sky(Lab(l: 60, a: 0, b: -20), at: at(slot.startMinute / 60, slot.startMinute % 60))
        let again = sky(Lab(l: 61, a: 0, b: -21), at: first.capturedAt.addingTimeInterval(60))
        for order in [[first, again], [again, first]] {
            let map = SkyMatch.map(targets: spreadTargets, entries: order, on: today)
            XCTAssertTrue(map[slot.id] === again, "어느 순서로 와도 새로 찍은 쪽이 앉는다")
        }
    }

    func testOlderSkyLandsOnlyWhenItsColourIsInsideTheCircle() {
        var targets = spreadTargets
        targets[10] = Lab(l: 70, a: -5, b: -30)
        let near = sky(Lab(l: 70.5, a: -5, b: -31), at: at(9, 0, daysAgo: 3))
        let far = sky(Lab(l: 30, a: 60, b: 60), at: at(9, 0, daysAgo: 4))
        let map = SkyMatch.map(targets: targets, entries: [near, far], on: today)
        XCTAssertTrue(map[10] === near)
        XCTAssertFalse(map.values.contains { $0 === far }, "어느 구슬에도 가깝지 않은 지난 하늘은 앉지 않는다")
    }

    func testOneSkyFillsOneBeadEvenWhenItFitsSeveral() {
        var targets = spreadTargets
        let grey = Lab(l: 55, a: 0, b: -5)
        targets[3] = grey
        targets[4] = Lab(l: 55.5, a: 0, b: -5)
        targets[40] = Lab(l: 55.2, a: 0, b: -5)
        let photo = sky(grey, at: at(10, 0, daysAgo: 2))
        let map = SkyMatch.map(targets: targets, entries: [photo], on: today)
        XCTAssertEqual(map.count, 1)
        XCTAssertTrue(map[3] === photo, "가장 가까운 구슬 하나에만 앉는다")
    }

    func testNearestPairingIsSettledFirstAcrossTheGrid() {
        var targets = spreadTargets
        targets[0] = Lab(l: 50, a: 0, b: 0)
        targets[1] = Lab(l: 52, a: 0, b: 0)
        let exactForZero = sky(Lab(l: 50, a: 0, b: 0), at: at(9, 0, daysAgo: 1))
        let between = sky(Lab(l: 51, a: 0, b: 0), at: at(9, 0, daysAgo: 2))
        let map = SkyMatch.map(targets: targets, entries: [between, exactForZero], on: today)
        XCTAssertTrue(map[0] === exactForZero)
        XCTAssertTrue(map[1] === between, "자리를 뺏긴 하늘도 다음으로 가까운 구슬을 받는다")
    }

    func testTodaysCaptureIsSpentBeforeColourIsAsked() {
        var targets = spreadTargets
        let slot = SkyBoard.slot(forMinute: 15 * 60).id
        let other = (slot + 20) % 48
        let colour = Lab(l: 64, a: -3, b: -25)
        targets[other] = colour
        let photo = sky(colour, at: at(15, 0))
        let map = SkyMatch.map(targets: targets, entries: [photo], on: today)
        XCTAssertTrue(map[slot] === photo)
        XCTAssertNil(map[other], "오늘 찍은 하늘은 제 시간 칸에 쓰였으니 색으로 또 앉지 않는다")
    }

    func testTiesGoToTheNewerSky() {
        var targets = spreadTargets
        targets[20] = Lab(l: 45, a: 10, b: -10)
        let old = sky(Lab(l: 46, a: 10, b: -10), at: at(8, 0, daysAgo: 9))
        let newer = sky(Lab(l: 46, a: 10, b: -10), at: at(8, 0, daysAgo: 1))
        let map = SkyMatch.map(targets: targets, entries: [old, newer], on: today)
        XCTAssertTrue(map[20] === newer)
    }

    func testAllNearIncludesTodaysCapturesFromThatStretchNewestFirst() {
        let slot = SkyBoard.slot(forMinute: 11 * 60)
        let target = Lab(l: 70, a: -4, b: -28)
        let lookalike = sky(Lab(l: 70.4, a: -4, b: -28), at: at(16, 0, daysAgo: 5))
        let takenThen = sky(Lab(l: 20, a: 30, b: 30), at: at(slot.startMinute / 60, slot.startMinute % 60 + 1))
        let unrelated = sky(Lab(l: 20, a: 30, b: 30), at: at(11, 0, daysAgo: 1))
        let found = SkyMatch.all(near: target, in: [lookalike, takenThen, unrelated], filling: slot, on: today)
        XCTAssertEqual(found.count, 2)
        XCTAssertTrue(found.first === takenThen)
        XCTAssertTrue(found.last === lookalike)
    }

    // MARK: - 캐시

    func testCacheAnswersTheSameKeyWithoutMatchingAgain() {
        let cache = SkyMatchCache()
        let first = sky(Lab(l: 60, a: 0, b: -20), at: at(9, 0))
        let a = cache.map(targets: spreadTargets, entries: [first], on: today, key: "k")
        let b = cache.map(targets: spreadTargets, entries: [], on: today, key: "k")
        XCTAssertEqual(a.count, 1)
        XCTAssertEqual(b.count, 1, "같은 열쇠면 다시 셈하지 않는다")
        XCTAssertTrue(cache.map(targets: spreadTargets, entries: [], on: today, key: "k2").isEmpty)
    }

    func testCacheKeyMovesWithTheCollection() {
        let one = [sky(Lab(l: 60, a: 0, b: -20), at: at(9, 0))]
        let two = one + [sky(Lab(l: 40, a: 0, b: -20), at: at(10, 0))]
        let k1 = SkyMatchCache.key(on: today, latitude: 37.5, longitude: 127, entries: one)
        XCTAssertEqual(k1, SkyMatchCache.key(on: today.addingTimeInterval(3_600), latitude: 37.5, longitude: 127, entries: one),
                       "같은 날 안에서는 시간이 흘러도 열쇠가 같다")
        XCTAssertNotEqual(k1, SkyMatchCache.key(on: today, latitude: 37.5, longitude: 127, entries: two))
        XCTAssertNotEqual(k1, SkyMatchCache.key(on: today, latitude: 35.1, longitude: 129, entries: one))
        XCTAssertNotEqual(k1, SkyMatchCache.key(on: today.addingTimeInterval(86_400), latitude: 37.5, longitude: 127, entries: one))
    }

    func testCountNearIsCachedPerSlot() {
        let cache = SkyMatchCache()
        let slot = SkyBoard.slots[22]
        let target = Lab(l: 70, a: -4, b: -28)
        let entries = [sky(Lab(l: 70.2, a: -4, b: -28), at: at(9, 0, daysAgo: 2))]
        XCTAssertEqual(cache.countNear(target, slot: slot, entries: entries, on: today, key: "k"), 1)
        XCTAssertEqual(cache.countNear(target, slot: slot, entries: [], on: today, key: "k"), 1)
        XCTAssertEqual(cache.countNear(target, slot: SkyBoard.slots[23], entries: [], on: today, key: "k"), 0)
    }
}
