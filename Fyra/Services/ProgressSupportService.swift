//
//  ProgressSupportService.swift
//  Fyra
//

import Foundation

struct StreakStats {
    let current: Int
    let best: Int
}

struct WeeklySummary {
    let rangeStart: Date
    let rangeEnd: Date
    let loggedDays: Int
    let photoDays: Int
    let winsLogged: Int
    let trendChange: Double?
}

struct MilestoneStatus {
    let startWeight: Double
    let currentWeight: Double
    let nextMilestoneWeight: Double
    let targetWeight: Double
    let progress: Double
    let daysToNextMilestone: Int?
}

struct RecoveryPlanDay: Identifiable {
    let id: Int
    let date: Date
    let label: String
    let isComplete: Bool
}

struct RecoveryPlanStatus {
    let startDate: Date
    let days: [RecoveryPlanDay]
    let completedDays: Int
    let isComplete: Bool
}

/// Lightweight motivation and consistency helpers (streaks, reminders, milestones, recovery).
enum ProgressSupportService {
    static func streakStats(
        checkIns: [CheckIn],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakStats {
        let days = loggedDays(checkIns: checkIns, calendar: calendar)
        guard !days.isEmpty else { return StreakStats(current: 0, best: 0) }

        var best = 1
        var run = 1
        for index in 1..<days.count {
            let gap = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if gap == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }

        guard let latest = days.last else { return StreakStats(current: 0, best: best) }
        let startOfToday = calendar.startOfDay(for: today)
        let dayGap = calendar.dateComponents([.day], from: latest, to: startOfToday).day ?? .max
        guard dayGap <= 1 else { return StreakStats(current: 0, best: best) }

        var current = 1
        var cursor = days.count - 1
        while cursor > 0 {
            let gap = calendar.dateComponents([.day], from: days[cursor - 1], to: days[cursor]).day ?? 0
            guard gap == 1 else { break }
            current += 1
            cursor -= 1
        }
        return StreakStats(current: current, best: best)
    }

    static func daysSinceLastCheckIn(
        checkIns: [CheckIn],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard let last = loggedDays(checkIns: checkIns, calendar: calendar).last else { return nil }
        return calendar.dateComponents([.day], from: last, to: calendar.startOfDay(for: now)).day
    }

    static func smartReminderMessage(
        checkIns: [CheckIn],
        reminderTime: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let startOfToday = calendar.startOfDay(for: now)
        let days = loggedDays(checkIns: checkIns, calendar: calendar)
        if days.contains(startOfToday) { return nil }

        guard let missed = daysSinceLastCheckIn(checkIns: checkIns, now: now, calendar: calendar) else {
            return "Take your first check-in today. One photo is enough."
        }

        if missed >= 7 {
            return "You are \(missed) days from your last log. Restart with one photo today."
        }
        if missed >= 2 {
            return "Quick nudge: \(missed) days since your last check-in. A single photo keeps momentum."
        }
        if let reminderTime {
            var components = calendar.dateComponents([.hour, .minute], from: reminderTime)
            components.year = calendar.component(.year, from: now)
            components.month = calendar.component(.month, from: now)
            components.day = calendar.component(.day, from: now)
            if let scheduled = calendar.date(from: components), now >= scheduled {
                return "Friendly reminder: log today so your streak stays alive."
            }
        }
        return nil
    }

    static func suggestedWinTags(checkIns: [CheckIn], limit: Int = 3) -> [CheckInTag] {
        let baseTags = CheckInTag.allCases.filter { $0 != .custom }
        var counts: [String: Int] = baseTags.reduce(into: [:]) { partialResult, tag in
            partialResult[tag.rawValue] = 0
        }

        for checkIn in checkIns {
            for raw in checkIn.tagRawValues where !raw.hasPrefix("custom:") {
                counts[raw, default: 0] += 1
            }
        }

        let sorted = baseTags.sorted { lhs, rhs in
            let left = counts[lhs.rawValue, default: 0]
            let right = counts[rhs.rawValue, default: 0]
            if left == right { return lhs.rawValue < rhs.rawValue }
            return left < right
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    static func plateauMessage(
        checkIns: [CheckIn],
        goalType: GoalType,
        unit: WeightUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard goalType != .none else { return nil }
        let windowStart = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let weighted = checkIns
            .compactMap { checkIn -> (date: Date, weight: Double)? in
                guard let weight = checkIn.weight, checkIn.date >= windowStart else { return nil }
                return (checkIn.date, weight)
            }
            .sorted { $0.date < $1.date }

        guard weighted.count >= 6 else { return nil }
        let split = weighted.count / 2
        guard split >= 3 else { return nil }

        let firstHalf = weighted.prefix(split).map(\.weight)
        let secondHalf = weighted.suffix(weighted.count - split).map(\.weight)
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let drift = secondAvg - firstAvg
        let threshold = unit == .kg ? 0.4 : 0.8
        guard abs(drift) <= threshold else { return nil }

        let recentWindowStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let consistencyDays = Set(checkIns.filter { $0.hasAnyContent && $0.date >= recentWindowStart }
            .map { calendar.startOfDay(for: $0.date) }).count
        guard consistencyDays >= 4 else { return nil }

        switch goalType {
        case .loseWeight:
            return "Trend looks flat for ~2 weeks. Try one small shift this week: +1k daily steps or tighter weekend portions."
        case .gainWeight, .gainMuscle:
            return "Trend looks flat for ~2 weeks. Try adding ~150-200 calories and keep protein consistent."
        case .recomposition:
            return "Scale trend is flat. That can happen during recomposition - keep lifting and track waist/photos."
        case .none:
            return nil
        }
    }

    static func weeklySummary(
        checkIns: [CheckIn],
        unit: WeightUnit,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklySummary {
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let window = checkIns.filter { $0.date >= start && $0.date <= now && $0.hasAnyContent }
        let loggedDayCount = Set(window.map { calendar.startOfDay(for: $0.date) }).count
        let photoDayCount = Set(window.filter(\.hasAnyPhoto).map { calendar.startOfDay(for: $0.date) }).count
        let winsCount = window.reduce(0) { partialResult, checkIn in
            partialResult + checkIn.tagRawValues.count
        }

        let weighted = window.filter { $0.weight != nil }
        let trendService = WeightTrendService(checkIns: weighted, unit: unit)
        let trendChange = trendService.trendChange()

        return WeeklySummary(
            rangeStart: start,
            rangeEnd: now,
            loggedDays: loggedDayCount,
            photoDays: photoDayCount,
            winsLogged: winsCount,
            trendChange: trendChange
        )
    }

    static func milestoneStatus(
        checkIns: [CheckIn],
        settings: UserSettings,
        periodStartDate: Date?,
        unit: WeightUnit
    ) -> MilestoneStatus? {
        guard let target = targetWeight(for: settings) else { return nil }

        let weighted = checkIns
            .filter { checkIn in
                guard checkIn.weight != nil else { return false }
                guard let periodStartDate else { return true }
                return checkIn.date >= periodStartDate
            }
            .sorted { $0.date < $1.date }
        guard let firstWeight = weighted.first?.weight else { return nil }

        let trendService = WeightTrendService(checkIns: weighted, unit: unit)
        guard let currentWeight = trendService.latestTrend ?? weighted.last?.weight else { return nil }

        let totalDistance = abs(target - firstWeight)
        guard totalDistance > 0.01 else { return nil }
        let direction = target > firstWeight ? 1.0 : -1.0

        let completedDistance = max(0, (currentWeight - firstWeight) * direction)
        let progress = min(max(completedDistance / totalDistance, 0), 1)

        let step: Double = unit == .kg ? 0.5 : 1.0
        let stepsCompleted = floor(completedDistance / step)
        let nextDistance = min(totalDistance, (stepsCompleted + 1.0) * step)
        let nextMilestone = firstWeight + (nextDistance * direction)

        var daysToNext: Int?
        if let rate = trendService.weeklyRatePerWeek(unit: unit)?.value, abs(rate) > 0.01 {
            let directionalRate = rate * direction
            if directionalRate > 0 {
                let remaining = max(0, abs(nextMilestone - currentWeight))
                daysToNext = Int(ceil((remaining / abs(rate)) * 7.0))
            }
        }

        return MilestoneStatus(
            startWeight: firstWeight,
            currentWeight: currentWeight,
            nextMilestoneWeight: nextMilestone,
            targetWeight: target,
            progress: progress,
            daysToNextMilestone: daysToNext
        )
    }

    static func shouldStartRecoveryPlan(
        lastCheckInDate: Date?,
        existingStartDate: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard existingStartDate == nil, let lastCheckInDate else { return false }
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastCheckInDate), to: calendar.startOfDay(for: now)).day ?? 0
        return gap >= EngagementService.returnBannerGapDays
    }

    static func recoveryPlanStatus(
        startDate: Date?,
        checkIns: [CheckIn],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RecoveryPlanStatus? {
        guard let startDate else { return nil }
        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: now)
        let age = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        guard age <= 10 else { return nil }

        let logged = Set(loggedDays(checkIns: checkIns, calendar: calendar))
        let days = (0..<3).compactMap { offset -> RecoveryPlanDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return RecoveryPlanDay(
                id: offset,
                date: date,
                label: "Day \(offset + 1)",
                isComplete: logged.contains(calendar.startOfDay(for: date))
            )
        }
        let completed = days.filter(\.isComplete).count
        return RecoveryPlanStatus(
            startDate: start,
            days: days,
            completedDays: completed,
            isComplete: completed == days.count
        )
    }

    private static func loggedDays(checkIns: [CheckIn], calendar: Calendar) -> [Date] {
        let unique = Set(checkIns.filter(\.hasAnyContent).map { calendar.startOfDay(for: $0.date) })
        return unique.sorted()
    }

    private static func targetWeight(for settings: UserSettings) -> Double? {
        switch settings.goalType {
        case .loseWeight:
            if let low = settings.goalMinWeight, let high = settings.goalMaxWeight {
                return Swift.min(low, high)
            }
            return settings.goalMinWeight ?? settings.goalMaxWeight
        case .gainWeight, .gainMuscle:
            if let low = settings.goalMinWeight, let high = settings.goalMaxWeight {
                return Swift.max(low, high)
            }
            return settings.goalMaxWeight ?? settings.goalMinWeight
        case .recomposition, .none:
            return nil
        }
    }
}
