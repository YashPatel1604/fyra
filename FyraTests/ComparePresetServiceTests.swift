//
//  ComparePresetServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class ComparePresetServiceTests: XCTestCase {
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
    }

    func testFirstVsLatest() {
        let d1 = calendar.date(byAdding: .day, value: -10, to: Date())!
        let d2 = Date()
        let c1 = CheckIn(date: d1, weight: 70)
        let c2 = CheckIn(date: d2, weight: 72)
        let service = ComparePresetService(checkIns: [c1, c2])
        let result = service.firstVsLatest()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.from.id, c1.id)
        XCTAssertEqual(result?.to.id, c2.id)
    }

    func testFirstVsLatestSingleEntryReturnsNil() {
        let c = CheckIn(date: Date(), weight: 70)
        let service = ComparePresetService(checkIns: [c])
        XCTAssertNil(service.firstVsLatest())
    }

    func testThisMonthStartVsEnd() {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let midMonth = calendar.date(byAdding: .day, value: 10, to: startOfMonth)!
        let c1 = CheckIn(date: startOfMonth, weight: 70)
        let c2 = CheckIn(date: midMonth, weight: 71)
        let service = ComparePresetService(checkIns: [c1, c2])
        let result = service.thisMonthStartVsEnd()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.from.id, c1.id)
        XCTAssertEqual(result?.to.id, c2.id)
    }

    func testBestVisualChangeThisMonthUsesPose() {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let c1 = CheckIn(date: startOfMonth, weight: 70)
        let c2 = CheckIn(date: now, weight: 71)
        c1.frontPhotoPath = "path1"
        c2.frontPhotoPath = "path2"
        let service = ComparePresetService(checkIns: [c1, c2])
        let result = service.bestVisualChangeThisMonth(pose: .front)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.from.id, c1.id)
        XCTAssertEqual(result?.to.id, c2.id)
    }
}
