//
//  EngagementServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class EngagementServiceTests: XCTestCase {
    func testCompareOpenCounterResetsDaily() {
        let settings = UserSettings()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        settings.compareOpensDateString = formatter.string(from: Date())
        settings.compareOpensCount = 3
        _ = EngagementService.recordCompareOpen(settings: settings)
        XCTAssertEqual(settings.compareOpensCount, 4)
        settings.compareOpensDateString = "2000-01-01"
        _ = EngagementService.recordCompareOpen(settings: settings)
        XCTAssertEqual(settings.compareOpensCount, 1)
        XCTAssertEqual(settings.compareOpensDateString, formatter.string(from: Date()))
    }

    func testShouldShowCompareNudgeAfterThreshold() {
        let settings = UserSettings()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        settings.compareOpensDateString = formatter.string(from: Date())
        settings.compareOpensCount = EngagementService.compareNudgeOpenThreshold + 1
        settings.compareNudgeDismissedDateString = ""
        XCTAssertTrue(EngagementService.shouldShowCompareNudge(settings: settings))
        settings.compareNudgeDismissedDateString = formatter.string(from: Date())
        XCTAssertFalse(EngagementService.shouldShowCompareNudge(settings: settings))
    }
}
