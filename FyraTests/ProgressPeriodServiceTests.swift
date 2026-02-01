//
//  ProgressPeriodServiceTests.swift
//  FyraTests
//

import XCTest
import SwiftData
@testable import Fyra

final class ProgressPeriodServiceTests: XCTestCase {
    func testHandleGoalChangeCreatesNewPeriod() throws {
        let schema = Schema([UserSettings.self, ProgressPeriod.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let settings = UserSettings(goalType: .loseWeight, goalMinWeight: 150, goalMaxWeight: 170)
        context.insert(settings)

        let start = Date(timeIntervalSince1970: 1000)
        let first = ProgressPeriodService.startNewPeriod(
            settings: settings,
            periods: [],
            modelContext: context,
            now: start,
            closeExisting: false
        )

        let changeDate = Date(timeIntervalSince1970: 2000)
        settings.goalType = .gainWeight
        let newPeriod = ProgressPeriodService.handleGoalChange(
            settings: settings,
            periods: [first],
            modelContext: context,
            now: changeDate
        )

        XCTAssertNotNil(newPeriod)
        XCTAssertEqual(first.endDate, changeDate)
        XCTAssertEqual(newPeriod?.startDate, changeDate)
        XCTAssertEqual(newPeriod?.goalType, .gainWeight)
        XCTAssertEqual(settings.activeProgressPeriodID, newPeriod?.id)
    }
}
