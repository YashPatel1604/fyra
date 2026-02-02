//
//  UnitConversionService.swift
//  Fyra
//

import Foundation

/// Converts stored values when weight unit preference changes.
enum UnitConversionService {
    private static let poundsPerKilogram = 2.204_622_621_8
    private static let centimetersPerInch = 2.54

    private static func weightFactor(from: WeightUnit, to: WeightUnit) -> Double {
        if from == to { return 1 }
        return from == .lb ? (1 / poundsPerKilogram) : poundsPerKilogram
    }

    /// Waist follows weight setting in this app: lb -> in, kg -> cm.
    private static func waistFactor(from: WeightUnit, to: WeightUnit) -> Double {
        if from == to { return 1 }
        return from == .lb ? centimetersPerInch : (1 / centimetersPerInch)
    }

    private static func converted(_ value: Double?, factor: Double) -> Double? {
        guard let value else { return nil }
        let result = value * factor
        return result.isFinite ? result : nil
    }

    static func convertStoredValues(
        from oldUnit: WeightUnit,
        to newUnit: WeightUnit,
        checkIns: [CheckIn],
        settings: UserSettings,
        periods: [ProgressPeriod]
    ) {
        guard oldUnit != newUnit else { return }

        let weightScale = weightFactor(from: oldUnit, to: newUnit)
        let waistScale = waistFactor(from: oldUnit, to: newUnit)

        for checkIn in checkIns {
            checkIn.weight = converted(checkIn.weight, factor: weightScale)
            checkIn.lastHealthSyncedWeight = converted(checkIn.lastHealthSyncedWeight, factor: weightScale)
            checkIn.waistMeasurement = converted(checkIn.waistMeasurement, factor: waistScale)
        }

        settings.goalMinWeight = converted(settings.goalMinWeight, factor: weightScale)
        settings.goalMaxWeight = converted(settings.goalMaxWeight, factor: weightScale)
        settings.paceMinPerWeek = converted(settings.paceMinPerWeek, factor: weightScale)
        settings.paceMaxPerWeek = converted(settings.paceMaxPerWeek, factor: weightScale)
        settings.weightUnit = newUnit

        for period in periods {
            period.targetRangeMin = converted(period.targetRangeMin, factor: weightScale)
            period.targetRangeMax = converted(period.targetRangeMax, factor: weightScale)
            period.paceMinPerWeek = converted(period.paceMinPerWeek, factor: weightScale)
            period.paceMaxPerWeek = converted(period.paceMaxPerWeek, factor: weightScale)
        }
    }
}

