//
//  ProgressPeriodService.swift
//  Fyra
//

import Foundation
import SwiftData

/// Handles creation and transitions of goal-based progress periods.
enum ProgressPeriodService {
    static func activePeriod(settings: UserSettings?, periods: [ProgressPeriod]) -> ProgressPeriod? {
        if let id = settings?.activeProgressPeriodID,
           let match = periods.first(where: { $0.id == id }) {
            return match
        }
        return periods
            .filter { $0.endDate == nil }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    static func startNewPeriod(
        settings: UserSettings,
        periods: [ProgressPeriod],
        modelContext: ModelContext,
        now: Date = Date(),
        note: String? = nil,
        closeExisting: Bool = true
    ) -> ProgressPeriod {
        if closeExisting, let active = activePeriod(settings: settings, periods: periods) {
            active.endDate = now
        }
        let period = ProgressPeriod(
            startDate: now,
            endDate: nil,
            goalType: settings.goalType,
            targetRangeMin: settings.goalMinWeight,
            targetRangeMax: settings.goalMaxWeight,
            paceMinPerWeek: settings.paceMinPerWeek,
            paceMaxPerWeek: settings.paceMaxPerWeek,
            note: note,
            createdAt: now
        )
        modelContext.insert(period)
        settings.activeProgressPeriodID = period.id
        return period
    }

    /// If goal-defining settings changed, close active period and open a new one.
    @discardableResult
    static func handleGoalChange(
        settings: UserSettings,
        periods: [ProgressPeriod],
        modelContext: ModelContext,
        now: Date = Date()
    ) -> ProgressPeriod? {
        if let active = activePeriod(settings: settings, periods: periods),
           settingsMatch(period: active, settings: settings) {
            return nil
        }
        return startNewPeriod(settings: settings, periods: periods, modelContext: modelContext, now: now, closeExisting: true)
    }

    static func ensureActivePeriodIfNeeded(
        settings: UserSettings,
        periods: [ProgressPeriod],
        modelContext: ModelContext,
        now: Date = Date()
    ) -> ProgressPeriod? {
        if let active = activePeriod(settings: settings, periods: periods) {
            if settings.activeProgressPeriodID == nil {
                settings.activeProgressPeriodID = active.id
            }
            return active
        }
        let hasGoalContext = settings.goalType != .none
            || settings.goalMinWeight != nil
            || settings.goalMaxWeight != nil
            || settings.paceMinPerWeek != nil
            || settings.paceMaxPerWeek != nil
        guard hasGoalContext else { return nil }
        return startNewPeriod(settings: settings, periods: periods, modelContext: modelContext, now: now, closeExisting: false)
    }

    static func settingsMatch(period: ProgressPeriod, settings: UserSettings) -> Bool {
        period.goalType == settings.goalType
        && period.targetRangeMin == settings.goalMinWeight
        && period.targetRangeMax == settings.goalMaxWeight
        && period.paceMinPerWeek == settings.paceMinPerWeek
        && period.paceMaxPerWeek == settings.paceMaxPerWeek
    }
}
