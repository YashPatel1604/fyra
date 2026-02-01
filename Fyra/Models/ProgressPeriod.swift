//
//  ProgressPeriod.swift
//  Fyra
//

import Foundation
import SwiftData

/// A goal-consistent phase of progress. New periods start when goals change.
@Model
final class ProgressPeriod: Identifiable {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var goalType: GoalType
    var targetRangeMin: Double?
    var targetRangeMax: Double?
    var paceMinPerWeek: Double?
    var paceMaxPerWeek: Double?
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        goalType: GoalType,
        targetRangeMin: Double? = nil,
        targetRangeMax: Double? = nil,
        paceMinPerWeek: Double? = nil,
        paceMaxPerWeek: Double? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.goalType = goalType
        self.targetRangeMin = targetRangeMin
        self.targetRangeMax = targetRangeMax
        self.paceMinPerWeek = paceMinPerWeek
        self.paceMaxPerWeek = paceMaxPerWeek
        self.note = note
        self.createdAt = createdAt
    }

    var isActive: Bool { endDate == nil }
}
