//
//  HealthSyncService.swift
//  Fyra
//

import Foundation
import HealthKit

enum HealthSyncService {
    private static let store = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
            && HKQuantityType.quantityType(forIdentifier: .bodyMass) != nil
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
}
