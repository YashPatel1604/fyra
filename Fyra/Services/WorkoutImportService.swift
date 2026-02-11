//
//  WorkoutImportService.swift
//  Fyra
//

import Foundation
import SwiftData

enum WorkoutImportResult {
    case imported(Int)
    case unavailable
    case unauthorized
}

@MainActor
enum WorkoutImportService {
    private static var activeImportTask: Task<WorkoutImportResult, Never>?

    @discardableResult
    static func importFromAppleHealth(
        modelContext: ModelContext,
        settings: UserSettings,
        forceFullRefresh: Bool = false
    ) async -> WorkoutImportResult {
        if let activeImportTask {
            return await activeImportTask.value
        }

        let task = Task<WorkoutImportResult, Never> { @MainActor in
            defer { activeImportTask = nil }
            return await performImportFromAppleHealth(
                modelContext: modelContext,
                settings: settings,
                forceFullRefresh: forceFullRefresh
            )
        }
        activeImportTask = task
        return await task.value
    }

    private static func performImportFromAppleHealth(
        modelContext: ModelContext,
        settings: UserSettings,
        forceFullRefresh: Bool
    ) async -> WorkoutImportResult {
        guard HealthSyncService.isWorkoutImportAvailable else { return .unavailable }
        guard await HealthSyncService.requestWorkoutReadAccess() else { return .unauthorized }

        let existingSessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let needsNameBackfill = existingSessions.contains { isGenericActivityName($0.activityName) }

        let since: Date?
        if forceFullRefresh || needsNameBackfill {
            since = nil
        } else if let lastImport = settings.lastWorkoutImportDate {
            // Overlap by 6h to avoid missing boundary samples between runs.
            since = lastImport.addingTimeInterval(-6 * 60 * 60)
        } else {
            since = nil
        }

        let imported = await HealthSyncService.fetchWorkouts(since: since)
        var existingByID: [String: WorkoutSession] = [:]
        var removedDuplicates = 0

        let sessionsByID = Dictionary(grouping: existingSessions, by: \.healthKitUUID)
        for (healthKitUUID, sessions) in sessionsByID {
            guard let keeper = sessions.max(by: { $0.date < $1.date }) else { continue }
            existingByID[healthKitUUID] = keeper
            for duplicate in sessions where duplicate.id != keeper.id {
                modelContext.delete(duplicate)
                removedDuplicates += 1
            }
        }

        var importedByID: [String: HealthSyncService.ImportedWorkout] = [:]
        for workout in imported {
            if let current = importedByID[workout.healthKitUUID] {
                if workout.date > current.date {
                    importedByID[workout.healthKitUUID] = workout
                }
            } else {
                importedByID[workout.healthKitUUID] = workout
            }
        }

        var inserted = 0
        for workout in importedByID.values {
            if let existing = existingByID[workout.healthKitUUID] {
                existing.activityName = workout.activityName
                existing.date = workout.date
                existing.durationMinutes = workout.durationMinutes
                existing.activeEnergyKcal = workout.activeEnergyKcal
                existing.sourceName = workout.sourceName
                continue
            }

            let session = WorkoutSession(
                healthKitUUID: workout.healthKitUUID,
                date: workout.date,
                activityName: workout.activityName,
                durationMinutes: workout.durationMinutes,
                activeEnergyKcal: workout.activeEnergyKcal,
                sourceName: workout.sourceName
            )
            modelContext.insert(session)
            existingByID[workout.healthKitUUID] = session
            inserted += 1
        }

        settings.lastWorkoutImportDate = Date()
        try? modelContext.save()
        return .imported(inserted)
    }

    private static func isGenericActivityName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered == "workout"
            || lowered == "activity"
            || lowered == "exercise"
            || lowered == "training"
            || lowered == "session"
            || lowered.contains("rawvalue")
    }
}
