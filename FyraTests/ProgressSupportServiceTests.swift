//
//  ProgressSupportServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class ProgressSupportServiceTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    }

    func testStreakStatsCurrentAndBest() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let days = [-6, -5, -4, -1]
        let checkIns = days.compactMap { offset -> CheckIn? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return CheckIn(date: date, weight: 170)
        }

        let stats = ProgressSupportService.streakStats(checkIns: checkIns, today: today, calendar: calendar)
        XCTAssertEqual(stats.current, 1)
        XCTAssertEqual(stats.best, 3)
    }

    func testSmartReminderForLongGap() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let last = calendar.date(byAdding: .day, value: -8, to: today)!
        let checkIns = [CheckIn(date: last, weight: 170)]

        let message = ProgressSupportService.smartReminderMessage(
            checkIns: checkIns,
            reminderTime: nil,
            now: today,
            calendar: calendar
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("8 days") == true)
    }

    func testSuggestedWinTagsReturnsLeastUsedFirst() {
        let date = calendar.startOfDay(for: Date())
        let one = CheckIn(date: date, weight: 170, tagRawValues: [CheckInTag.energyImproved.rawValue])
        let two = CheckIn(
            date: calendar.date(byAdding: .day, value: 1, to: date)!,
            weight: 171,
            tagRawValues: [CheckInTag.energyImproved.rawValue]
        )
        let suggestions = ProgressSupportService.suggestedWinTags(checkIns: [one, two], limit: 2)

        XCTAssertEqual(suggestions.count, 2)
        XCTAssertFalse(suggestions.contains(.energyImproved))
    }

    func testRecoveryPlanStatusTracksCompletion() {
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let day1 = CheckIn(date: start, weight: 170)
        let day2 = CheckIn(date: calendar.date(byAdding: .day, value: 1, to: start)!, weight: 171)

        let status = ProgressSupportService.recoveryPlanStatus(
            startDate: start,
            checkIns: [day1, day2],
            now: calendar.date(byAdding: .day, value: 1, to: start)!,
            calendar: calendar
        )

        XCTAssertNotNil(status)
        XCTAssertEqual(status?.completedDays, 2)
        XCTAssertEqual(status?.days.count, 3)
        XCTAssertFalse(status?.isComplete ?? true)
    }
}
