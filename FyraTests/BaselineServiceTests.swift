//
//  BaselineServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class BaselineServiceTests: XCTestCase {
    func testSetBaselineEnforcesSingle() {
        let settings = UserSettings()
        let c1 = CheckIn(date: Date(), weight: 70)
        let c2 = CheckIn(date: Date().addingTimeInterval(86400), weight: 71)
        BaselineService.setBaseline(c1.id, settings: settings)
        XCTAssertEqual(settings.baselineCheckInID, c1.id)
        BaselineService.setBaseline(c2.id, settings: settings)
        XCTAssertEqual(settings.baselineCheckInID, c2.id)
        BaselineService.setBaseline(nil, settings: settings)
        XCTAssertNil(settings.baselineCheckInID)
    }

    func testGetBaselineReturnsCorrectCheckIn() {
        let settings = UserSettings()
        let c1 = CheckIn(date: Date(), weight: 70)
        let c2 = CheckIn(date: Date().addingTimeInterval(86400), weight: 71)
        let checkIns = [c1, c2]
        BaselineService.setBaseline(c1.id, settings: settings)
        let baseline = BaselineService.getBaseline(checkIns: checkIns, settings: settings)
        XCTAssertEqual(baseline?.id, c1.id)
        BaselineService.setBaseline(c2.id, settings: settings)
        let baseline2 = BaselineService.getBaseline(checkIns: checkIns, settings: settings)
        XCTAssertEqual(baseline2?.id, c2.id)
    }
}
