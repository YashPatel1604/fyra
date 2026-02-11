//
//  WorkoutSession.swift
//  Fyra
//

import Foundation
import SwiftData

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
