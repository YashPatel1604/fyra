//
//  HealthSyncService.swift
//  Fyra
//

import Foundation
import HealthKit

enum HealthSyncService {
    struct ImportedWorkout {
        let healthKitUUID: String
        let date: Date
        let activityName: String
        let durationMinutes: Double
        let activeEnergyKcal: Double?
        let sourceName: String
    }

    private static let store = HKHealthStore()
    @MainActor private static var workoutObserverQuery: HKObserverQuery?
    @MainActor private static var isWorkoutObserverActive = false

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
            && HKQuantityType.quantityType(forIdentifier: .bodyMass) != nil
    }

    static var isWorkoutImportAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static func requestWriteAccess() async -> Bool {
        guard isAvailable, let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return false
        }

        let status = store.authorizationStatus(for: bodyMass)
        if status == .sharingAuthorized {
            return true
        }
        if status == .sharingDenied {
            return false
        }

        return await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: [bodyMass], read: [bodyMass]) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    static func requestWorkoutReadAccess() async -> Bool {
        guard isWorkoutImportAvailable else { return false }
        let workoutType = HKObjectType.workoutType()

        // Verify actual read access first; this avoids false negatives from
        // relying on authorizationStatus for read-only workout imports.
        if await canReadWorkouts() {
            return true
        }

        let requested = await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: [], read: [workoutType]) { success, _ in
                continuation.resume(returning: success)
            }
        }

        guard requested else { return false }
        return await canReadWorkouts()
    }

    static func fetchWorkouts(since startDate: Date?) async -> [ImportedWorkout] {
        guard isWorkoutImportAvailable else { return [] }
        guard await requestWorkoutReadAccess() else { return [] }

        let endDate = Date()
        let initialStart = Calendar.current.date(byAdding: .day, value: -180, to: endDate)
        let effectiveStart = startDate ?? initialStart
        let predicate = effectiveStart.map {
            HKQuery.predicateForSamples(withStart: $0, end: endDate, options: .strictStartDate)
        }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 5_000,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let mapped = workouts.map { workout in
                    ImportedWorkout(
                        healthKitUUID: workout.uuid.uuidString,
                        date: workout.startDate,
                        activityName: activityName(for: workout),
                        durationMinutes: workout.duration / 60.0,
                        activeEnergyKcal: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        sourceName: workout.sourceRevision.source.name
                    )
                }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }

    @MainActor
    static func startWorkoutObserver(
        onWorkoutChange: @escaping @MainActor () async -> Void
    ) async -> Bool {
        guard isWorkoutImportAvailable else { return false }
        guard await requestWorkoutReadAccess() else { return false }
        guard !isWorkoutObserverActive else { return true }

        let workoutType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completion, error in
            guard error == nil else {
                completion()
                return
            }
            Task { @MainActor in
                await onWorkoutChange()
                completion()
            }
        }

        workoutObserverQuery = query
        isWorkoutObserverActive = true
        store.execute(query)
        store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
        return true
    }

    @MainActor
    static func stopWorkoutObserver() {
        if let query = workoutObserverQuery {
            store.stop(query)
        }
        let workoutType = HKObjectType.workoutType()
        store.disableBackgroundDelivery(for: workoutType) { _, _ in }
        workoutObserverQuery = nil
        isWorkoutObserverActive = false
    }

    @MainActor
    static func syncWeightIfNeeded(
        checkIn: CheckIn,
        settings: UserSettings?
    ) async -> Bool {
        guard let settings, settings.appleHealthSyncEnabled else { return false }
        guard isAvailable, let weight = checkIn.weight else { return false }
        if let lastSynced = checkIn.lastHealthSyncedWeight, abs(lastSynced - weight) < 0.0001 {
            return true
        }
        guard await requestWriteAccess() else { return false }
        guard let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return false }

        let hkUnit: HKUnit = settings.weightUnit == .kg ? .gramUnit(with: .kilo) : .pound()
        let quantity = HKQuantity(unit: hkUnit, doubleValue: weight)
        let metadata: [String: Any] = [HKMetadataKeyExternalUUID: checkIn.id.uuidString]
        let sample = HKQuantitySample(
            type: bodyMass,
            quantity: quantity,
            start: checkIn.date,
            end: checkIn.date,
            metadata: metadata
        )

        let saved = await withCheckedContinuation { continuation in
            store.save(sample) { success, _ in
                continuation.resume(returning: success)
            }
        }
        if saved {
            checkIn.lastHealthSyncedWeight = weight
        }
        return saved
    }

    private static func activityName(for workout: HKWorkout) -> String {
        let type = primaryActivityType(for: workout)
        let typeName = activityName(for: type)
        let metadataName = preferredMetadataActivityName(
            metadata: workout.metadata,
            activityMetadata: workout.workoutActivities.compactMap(\.metadata),
            sourceName: workout.sourceRevision.source.name
        )

        guard let metadataName else { return typeName }
        if isGenericActivityName(typeName) {
            return metadataName
        }
        if metadataName.caseInsensitiveCompare(typeName) == .orderedSame {
            return typeName
        }
        return metadataName
    }

    private static func primaryActivityType(for workout: HKWorkout) -> HKWorkoutActivityType {
        let primaryType = workout.workoutActivityType
        if primaryType != .other && primaryType != .transition {
            return primaryType
        }

        let candidates = workout.workoutActivities
            .filter { activity in
                let type = activity.workoutConfiguration.activityType
                return type != .other && type != .transition
            }
            .sorted { $0.duration > $1.duration }

        if let strongest = candidates.first {
            return strongest.workoutConfiguration.activityType
        }
        return primaryType
    }

    private static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .americanFootball: return "American Football"
        case .archery: return "Archery"
        case .australianFootball: return "Australian Football"
        case .badminton: return "Badminton"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .bowling: return "Bowling"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .cricket: return "Cricket"
        case .crossTraining: return "Cross Training"
        case .curling: return "Curling"
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .dance: return "Dance"
        case .danceInspiredTraining: return "Dance"
        case .equestrianSports: return "Equestrian Sports"
        case .fencing: return "Fencing"
        case .fishing: return "Fishing"
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining: return "Functional Strength"
        case .golf: return "Golf"
        case .gymnastics: return "Gymnastics"
        case .handball: return "Handball"
        case .hockey: return "Hockey"
        case .hunting: return "Hunting"
        case .lacrosse: return "Lacrosse"
        case .martialArts: return "Martial Arts"
        case .mindAndBody: return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Cardio"
        case .paddleSports: return "Paddle Sports"
        case .play: return "Play"
        case .preparationAndRecovery: return "Recovery"
        case .racquetball: return "Racquetball"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .rugby: return "Rugby"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating Sports"
        case .snowSports: return "Snow Sports"
        case .soccer: return "Soccer"
        case .softball: return "Softball"
        case .squash: return "Squash"
        case .hiking: return "Hiking"
        case .stairClimbing: return "Stair Climbing"
        case .surfingSports: return "Surfing Sports"
        case .tableTennis: return "Table Tennis"
        case .tennis: return "Tennis"
        case .trackAndField: return "Track and Field"
        case .volleyball: return "Volleyball"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports"
        case .wrestling: return "Wrestling"
        case .barre: return "Barre"
        case .coreTraining: return "Core Training"
        case .crossCountrySkiing: return "Cross Country Skiing"
        case .downhillSkiing: return "Downhill Skiing"
        case .flexibility: return "Flexibility"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .pilates: return "Pilates"
        case .snowboarding: return "Snowboarding"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .wheelchairWalkPace: return "Wheelchair Walk Pace"
        case .wheelchairRunPace: return "Wheelchair Run Pace"
        case .taiChi: return "Tai Chi"
        case .mixedCardio: return "Mixed Cardio"
        case .handCycling: return "Hand Cycling"
        case .discSports: return "Disc Sports"
        case .fitnessGaming: return "Fitness Gaming"
        case .cardioDance: return "Cardio Dance"
        case .socialDance: return "Social Dance"
        case .pickleball: return "Pickleball"
        case .cooldown: return "Cooldown"
        case .swimBikeRun: return "Swim Bike Run"
        case .transition: return "Transition"
        case .underwaterDiving: return "Underwater Diving"
        case .elliptical: return "Elliptical"
        case .other: return "Workout"
        default:
            return humanizedActivityName(from: String(describing: type))
        }
    }

    private static func preferredMetadataActivityName(
        metadata: [String: Any]?,
        activityMetadata: [[String: Any]],
        sourceName: String
    ) -> String? {
        let prioritizedKeys = [
            "HKWorkoutActivityName",
            "WorkoutActivityName",
            "workout_activity_name",
            "activity_name",
            "sport_name",
            "workout_name",
            "name",
            "title",
            "type"
        ]

        var candidates: [String] = []
        var allMetadata: [[String: Any]] = []
        if let metadata {
            allMetadata.append(metadata)
        }
        allMetadata.append(contentsOf: activityMetadata)

        func appendCandidate(_ value: Any, key: String) {
            if let stringValue = value as? String,
               let normalized = normalizeMetadataName(stringValue),
               isUsefulMetadataName(normalized, key: key, sourceName: sourceName) {
                candidates.append(normalized)
            }

            if let numberValue = value as? NSNumber {
                let intValue = numberValue.intValue
                if intValue > 0 {
                    let mapped = activityName(for: HKWorkoutActivityType(rawValue: UInt(intValue)) ?? .other)
                    if !isGenericActivityName(mapped) {
                        candidates.append(mapped)
                    }
                }
            }
        }

        for metadataSet in allMetadata {
            for key in prioritizedKeys {
                if let value = metadataSet[key] {
                    appendCandidate(value, key: key)
                }
            }
        }

        for metadataSet in allMetadata {
            for (key, value) in metadataSet {
                let lowered = key.lowercased()
                if lowered.contains("activity")
                    || lowered.contains("workout")
                    || lowered.contains("sport")
                    || lowered.contains("name")
                    || lowered.contains("type") {
                    appendCandidate(value, key: key)
                }
            }
        }

        if candidates.isEmpty { return nil }
        return candidates.max(by: { $0.count < $1.count })
    }

    private static func normalizeMetadataName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let components = trimmed.split(whereSeparator: \.isWhitespace)
        return components.joined(separator: " ")
    }

    private static func isUsefulMetadataName(_ name: String, key: String, sourceName: String) -> Bool {
        if name.caseInsensitiveCompare(sourceName) == .orderedSame {
            return false
        }
        if name.count < 3 || name.count > 60 {
            return false
        }

        let lowered = name.lowercased()
        if lowered.contains("rawvalue") {
            return false
        }
        if isGenericActivityName(name) {
            return false
        }

        // Metadata keys that include name/title/activity are usually user-visible labels.
        let keyLowered = key.lowercased()
        return keyLowered.contains("name")
            || keyLowered.contains("title")
            || keyLowered.contains("activity")
            || keyLowered.contains("workout")
            || keyLowered.contains("sport")
            || keyLowered.contains("type")
    }

    private static func isGenericActivityName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return lowered == "workout"
            || lowered == "activity"
            || lowered == "exercise"
            || lowered == "training"
            || lowered == "session"
    }

    private static func humanizedActivityName(from rawIdentifier: String) -> String {
        var cleaned = rawIdentifier
            .replacingOccurrences(of: "HKWorkoutActivityType", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.lowercased().contains("rawvalue") {
            return "Workout"
        }
        if cleaned.isEmpty {
            return "Workout"
        }

        if cleaned == cleaned.lowercased() {
            return cleaned.capitalized
        }

        var withSpaces = ""
        for char in cleaned {
            if char.isUppercase, let last = withSpaces.last, last.isLetter || last.isNumber {
                withSpaces.append(" ")
            }
            withSpaces.append(char)
        }

        cleaned = withSpaces.replacingOccurrences(of: "_", with: " ")
        return cleaned.capitalized
    }

    private static func canReadWorkouts() async -> Bool {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil,
                limit: 1,
                sortDescriptors: nil
            ) { _, _, error in
                continuation.resume(returning: error == nil)
            }
            store.execute(query)
        }
    }
}
