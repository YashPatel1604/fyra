//
//  InsightService.swift
//  Fyra
//

import Foundation

/// Nudge rules: fluctuation banner, measurement nudge, pace context. All neutral, no red.
struct InsightService {
    /// Threshold for "large daily change" banner: 2.0 lb or 1.0 kg.
    static func fluctuationThreshold(unit: WeightUnit) -> Double {
        unit == .kg ? 1.0 : 2.0
    }

    /// Should show fluctuation banner: |today_raw - last_raw| >= threshold and at least 2 raw points.
    static func shouldShowFluctuationBanner(
        todayRaw: Double?,
        lastRaw: Double?,
        unit: WeightUnit,
        dismissedDateString: String?
    ) -> Bool {
        guard let today = todayRaw, let last = lastRaw,
              dismissedDateString == nil else { return false }
        let threshold = fluctuationThreshold(unit: unit)
        return abs(today - last) >= threshold
    }

    /// Message for fluctuation banner (neutral).
    static func fluctuationBannerMessage(unit: WeightUnit) -> String {
        if unit == .kg {
            return "Daily weight can fluctuate ±0.5–1.5 kg due to water, food, stress, and sleep. Focus on the trend."
        } else {
            return "Daily weight can fluctuate ±1–3 lb due to water, food, stress, and sleep. Focus on the trend."
        }
    }

    /// If weight trend is flat over ~14–30 days but waist improved, show measurement nudge.
    static func measurementNudge(
        checkInsWithWaist: [(date: Date, waist: Double)],
        weightTrendService: WeightTrendService?,
        unit: WeightUnit
    ) -> String? {
        guard checkInsWithWaist.count >= 2,
              let first = checkInsWithWaist.first,
              let last = checkInsWithWaist.last else { return nil }
        let days = Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 0
        guard days >= 14 else { return nil }
        let waistChange = last.waist - first.waist
        let weightStable: Bool
        if let trend = weightTrendService?.latestTrend, let past = weightTrendService?.trend(atIndex: max(0, (weightTrendService?.count ?? 0) - 7)) {
            weightStable = abs(trend - past) < (unit == .kg ? 0.5 : 1.0)
        } else {
            weightStable = true
        }
        guard weightStable, waistChange < 0 else { return nil }
        let absWaist = abs(waistChange)
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        let num = formatter.string(from: NSNumber(value: absWaist)) ?? "\(absWaist)"
        return "Weight is stable, but waist is down \(num) in — progress can show up beyond the scale."
    }

    /// Gentle pace context for muscle gain: "Current pace: +1.5 lb/week (target was 0.5–1.0)." No alarms.
    static func paceContext(
        currentRatePerWeek: Double?,
        paceMin: Double?,
        paceMax: Double?,
        goalType: GoalType,
        unit: WeightUnit
    ) -> String? {
        guard goalType == .gainWeight || goalType == .gainMuscle,
              let rate = currentRatePerWeek,
              let minP = paceMin, let maxP = paceMax else { return nil }
        if rate >= minP && rate <= maxP { return nil }
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        let rateStr = formatter.string(from: NSNumber(value: rate)) ?? "\(rate)"
        let targetStr = "\(formatter.string(from: NSNumber(value: minP)) ?? "\(minP)")–\(formatter.string(from: NSNumber(value: maxP)) ?? "\(maxP)")"
        return "Current pace: \(rateStr) \(unit.rawValue)/week (target was \(targetStr))."
    }
}
