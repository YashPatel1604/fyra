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
        guard checkInsWithWaist.count >= 2 else { return nil }
        let sorted = checkInsWithWaist.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return nil }
        let calendar = Calendar.current
        let minStart = calendar.date(byAdding: .day, value: -30, to: last.date) ?? last.date
        let maxStart = calendar.date(byAdding: .day, value: -14, to: last.date) ?? last.date
        let candidates = sorted.filter { $0.date >= minStart && $0.date <= maxStart }
        guard let first = candidates.first else { return nil }
        let waistChange = last.waist - first.waist
        let weightStable: Bool
        if let service = weightTrendService,
           let lastIdx = service.index(forDay: last.date),
           let firstIdx = service.index(forDay: first.date),
           let lastTrend = service.trend(atIndex: lastIdx),
           let firstTrend = service.trend(atIndex: firstIdx) {
            weightStable = abs(lastTrend - firstTrend) < (unit == .kg ? 0.5 : 1.0)
        } else if let trend = weightTrendService?.latestTrend,
                  let past = weightTrendService?.trend(atIndex: max(0, (weightTrendService?.count ?? 0) - 7)) {
            weightStable = abs(trend - past) < (unit == .kg ? 0.5 : 1.0)
        } else {
            weightStable = true
        }
        guard weightStable, waistChange < 0 else { return nil }
        let absWaist = abs(waistChange)
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        let num = formatter.string(from: NSNumber(value: absWaist)) ?? "\(absWaist)"
        return "Weight is stable, but waist is down \(num) \(unit.waistUnitSymbol) — progress can show up beyond the scale."
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

    static func workoutContext(
        workouts: [WorkoutSession],
        goalType: GoalType,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let summary = ProgressSupportService.recentWorkoutSummary(
            workouts: workouts,
            now: now,
            calendar: calendar
        )
        guard summary.count > 0 else { return nil }

        switch goalType {
        case .loseWeight:
            if summary.minutes >= 150 {
                return "Imported workouts show \(summary.minutes) active minutes this week. Activity looks consistent, so body-composition feedback will usually come more from intake and recovery than adding random extra sessions."
            }
            return "Imported workouts show \(summary.minutes) active minutes this week. If fat loss is the goal, 2-3 extra short sessions or walks could be the cleanest adjustment."
        case .gainWeight:
            if summary.strengthSessions >= 2 {
                return "You logged \(summary.strengthSessions) strength sessions this week. That gives weight gain a better chance to go toward performance instead of just scale gain."
            }
            return "Imported workouts show only \(summary.strengthSessions) strength-focused sessions this week. If you are trying to gain weight, get lifting consistent before pushing calories much harder."
        case .gainMuscle:
            if summary.strengthSessions >= 3 {
                return "You logged \(summary.strengthSessions) strength sessions this week. That supports muscle gain better than scale-only signals, so keep overload and recovery consistent."
            }
            if summary.cardioSessions > summary.strengthSessions {
                return "Imported workouts were mostly cardio this week. If muscle gain is the goal, anchor the week with 3+ strength sessions first."
            }
            return "Imported workouts show \(summary.strengthSessions) strength sessions this week. For muscle gain, moving that closer to 3-4 quality lifts usually improves the signal."
        case .recomposition:
            if summary.strengthSessions >= 2 {
                return "You logged \(summary.strengthSessions) strength sessions this week. For recomposition, that makes waist and photos more informative than scale changes alone."
            }
            return "Imported workouts show limited lifting this week. For recomposition, 2-4 strength sessions usually make the rest of the data easier to interpret."
        case .none:
            return "Imported workouts show \(summary.count) sessions across \(summary.days) days this week. Use that context alongside your check-ins before overreacting to short-term scale noise."
        }
    }
}
