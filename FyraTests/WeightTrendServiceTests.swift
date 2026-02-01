//
//  WeightTrendServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class WeightTrendServiceTests: XCTestCase {
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
    }

    func testTrendSingleEntry() {
        let d = calendar.startOfDay(for: Date())
        let c = CheckIn(date: d, weight: 70.0)
        let service = WeightTrendService(checkIns: [c], unit: .kg)
        XCTAssertEqual(service.latestTrend, 70.0)
        XCTAssertEqual(service.trend(atIndex: 0), 70.0)
    }

    func testTrendMovingAverage() {
        let base = calendar.startOfDay(for: Date())
        var checkIns: [CheckIn] = []
        for i in 0..<7 {
            let d = calendar.date(byAdding: .day, value: -6 + i, to: base)!
            checkIns.append(CheckIn(date: d, weight: 70.0 + Double(i)))
        }
        let service = WeightTrendService(checkIns: checkIns, unit: .kg)
        // Trend at last index = average of last 7 = 70+1+2+3+4+5+6 = 73
        XCTAssertEqual(service.latestTrend, 73.0)
        XCTAssertEqual(service.trend(atIndex: 6), 73.0)
    }

    func testWeeklyRate() {
        let base = calendar.startOfDay(for: Date())
        var checkIns: [CheckIn] = []
        for i in 0..<10 {
            let d = calendar.date(byAdding: .day, value: -9 + i, to: base)!
            checkIns.append(CheckIn(date: d, weight: 70.0 + Double(i) * 0.1))
        }
        let service = WeightTrendService(checkIns: checkIns, unit: .kg)
        let rate = service.weeklyRatePerWeek(unit: .kg)
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate?.fromTrend, true)
        // Roughly (latest - ~7 days ago) / days * 7; trend values smooth so rate should be positive
        XCTAssert(rate!.value > 0)
    }

    func testIndexForDay() {
        let d1 = calendar.startOfDay(for: Date())
        let d2 = calendar.date(byAdding: .day, value: 1, to: d1)!
        let c1 = CheckIn(date: d1, weight: 70)
        let c2 = CheckIn(date: d2, weight: 71)
        let service = WeightTrendService(checkIns: [c1, c2], unit: .kg)
        XCTAssertEqual(service.index(forDay: d1), 0)
        XCTAssertEqual(service.index(forDay: d2), 1)
        XCTAssertNil(service.index(forDay: calendar.date(byAdding: .day, value: 5, to: d1)!))
    }

    func testFormatWeeklyRate() {
        let s = WeightTrendService.formatWeeklyRate(-0.4, unit: .lb)
        XCTAssertTrue(s.contains("↓"))
        XCTAssertTrue(s.contains("0.4"))
        XCTAssertTrue(s.contains("lb/week"))
        let s2 = WeightTrendService.formatWeeklyRate(0.2, unit: .kg)
        XCTAssertTrue(s2.contains("↑"))
        XCTAssertTrue(s2.contains("kg/week"))
    }
}
