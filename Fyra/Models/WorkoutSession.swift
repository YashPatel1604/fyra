//
//  WorkoutSession.swift
//  Fyra
//

import Foundation
import SwiftData

enum WorkoutFocus {
    case strength
    case cardio
    case recovery
    case mixed
}

@Model
final class WorkoutSession {
    var id: UUID
    /// Underlying HealthKit workout UUID for deduplication.
    var healthKitUUID: String
    var date: Date
    var activityName: String
    var durationMinutes: Double
    var activeEnergyKcal: Double?
    var sourceName: String

    init(
        id: UUID = UUID(),
        healthKitUUID: String,
        date: Date,
        activityName: String,
        durationMinutes: Double,
        activeEnergyKcal: Double? = nil,
        sourceName: String
    ) {
        self.id = id
        self.healthKitUUID = healthKitUUID
        self.date = date
        self.activityName = activityName
        self.durationMinutes = durationMinutes
        self.activeEnergyKcal = activeEnergyKcal
        self.sourceName = sourceName
    }
}

extension WorkoutSession {
    var focus: WorkoutFocus {
        Self.focus(for: activityName)
    }

    static func focus(for activityName: String) -> WorkoutFocus {
        let name = activityName.lowercased()

        let strengthKeywords = [
            "strength",
            "resistance",
            "weight training",
            "weightlifting",
            "powerlifting",
            "bodybuilding",
            "lifting"
        ]
        if strengthKeywords.contains(where: name.contains) {
            return .strength
        }

        let recoveryKeywords = [
            "yoga",
            "pilates",
            "stretch",
            "mobility",
            "tai chi",
            "mind and body"
        ]
        if recoveryKeywords.contains(where: name.contains) {
            return .recovery
        }

        let cardioKeywords = [
            "run",
            "walk",
            "hike",
            "cycle",
            "bike",
            "swim",
            "row",
            "elliptical",
            "stair",
            "cardio",
            "boxing",
            "dance",
            "soccer",
            "basketball",
            "tennis",
            "pickleball",
            "ski",
            "hiit"
        ]
        if cardioKeywords.contains(where: name.contains) {
            return .cardio
        }

        return .mixed
    }
}
