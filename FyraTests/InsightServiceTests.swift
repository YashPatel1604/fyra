//
//  InsightServiceTests.swift
//  FyraTests
//

import XCTest
@testable import Fyra

final class InsightServiceTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    }

    func testWorkoutContextHighlightsStrengthForMuscleGoal() {
        let now = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let workouts = [
            WorkoutSession(
                healthKitUUID: "lift-1",
                date: now,
                activityName: "Traditional Strength Training",
                durationMinutes: 60,
                sourceName: "Health"
            ),
            WorkoutSession(
                healthKitUUID: "lift-2",
                date: calendar.date(byAdding: .day, value: -2, to: now)!,
                activityName: "Strength Workout",
                durationMinutes: 55,
                sourceName: "Health"
            ),
            WorkoutSession(
                healthKitUUID: "lift-3",
                date: calendar.date(byAdding: .day, value: -4, to: now)!,
                activityName: "Resistance Training",
                durationMinutes: 50,
                sourceName: "Health"
            )
        ]

        let message = InsightService.workoutContext(
            workouts: workouts,
            goalType: .gainMuscle,
            now: now,
            calendar: calendar
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("3 strength sessions") == true)
    }

    func testWorkoutContextSuggestsMoreActivityForFatLossWhenMinutesAreLow() {
        let now = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let workouts = [
            WorkoutSession(
                healthKitUUID: "walk-1",
                date: now,
                activityName: "Outdoor Walk",
                durationMinutes: 35,
                sourceName: "Health"
            )
        ]

        let message = InsightService.workoutContext(
            workouts: workouts,
            goalType: .loseWeight,
            now: now,
            calendar: calendar
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("35 active minutes") == true)
    }
}
