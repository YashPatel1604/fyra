//
//  WeightTrendService.swift
//  Fyra
//

import Foundation

/// Trend-first weight: 7-day moving average and weekly rate. Reduces scale anxiety.
struct WeightTrendService {
    static let windowCount = 7

    /// Entries with weight, sorted by date ascending (oldest first).
    private let weightedEntries: [(date: Date, weight: Double)]

    init(checkIns: [CheckIn], unit: WeightUnit) {
        weightedEntries = checkIns
            .compactMap { c -> (Date, Double)? in
                guard let w = c.weight else { return nil }
                return (c.date, w)
            }
            .sorted { $0.date < $1.date }
    }

    /// 7-day moving average at the given index (0 = oldest). Returns nil if not enough points.
    func trend(atIndex index: Int) -> Double? {
        let start = max(0, index - Self.windowCount + 1)
        let slice = weightedEntries[start...index]
        guard slice.count >= 1 else { return nil }
        let sum = slice.map(\.weight).reduce(0, +)
        return sum / Double(slice.count)
    }

    /// Trend for the most recent entry (today / latest).
    var latestTrend: Double? {
        guard !weightedEntries.isEmpty else { return nil }
        return trend(atIndex: weightedEntries.count - 1)
    }

    /// Weekly rate: (trend_now - trend_7_days_ago) / days_between * 7. Positive = gaining, negative = losing.
    /// Uses nearest available points if exact 7 days not available.
    func weeklyRatePerWeek(unit: WeightUnit) -> (value: Double, fromTrend: Bool)? {
        guard weightedEntries.count >= 2 else { return nil }
        let nowIdx = weightedEntries.count - 1
        let nowTrend = trend(atIndex: nowIdx)
        guard let nowTrend else { return nil }
        let nowDate = weightedEntries[nowIdx].date
        // Find point ~7 days ago (nearest with trend).
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: nowDate) ?? nowDate
        guard let pastIdx = nearestIndex(to: sevenDaysAgo),
              let pastTrend = trend(atIndex: pastIdx) else { return nil }
        let daysBetween = Calendar.current.dateComponents([.day], from: weightedEntries[pastIdx].date, to: nowDate).day ?? 7
        guard daysBetween > 0 else { return nil }
        let rate = (nowTrend - pastTrend) / Double(daysBetween) * 7.0
        return (rate, true)
    }

    /// Raw daily value at index (for "Show daily points").
    func rawWeight(atIndex index: Int) -> Double? {
        guard index >= 0, index < weightedEntries.count else { return nil }
        return weightedEntries[index].weight
    }

    var count: Int { weightedEntries.count }

    func date(atIndex index: Int) -> Date? {
        guard index >= 0, index < weightedEntries.count else { return nil }
        return weightedEntries[index].date
    }

    /// Index of the entry matching the given day (same calendar day), or nil.
    func index(forDay date: Date) -> Int? {
        let cal = Calendar.current
        let startOf = cal.startOfDay(for: date)
        return weightedEntries.firstIndex { cal.startOfDay(for: $0.date) == startOf }
    }

    private func nearestIndex(to date: Date) -> Int? {
        guard !weightedEntries.isEmpty else { return nil }
        var best = 0
        var bestDiff = abs(weightedEntries[0].date.timeIntervalSince(date))
        for i in 1..<weightedEntries.count {
            let d = abs(weightedEntries[i].date.timeIntervalSince(date))
            if d < bestDiff { bestDiff = d; best = i }
        }
        return best
    }
}

// MARK: - Formatting (neutral language)

extension WeightTrendService {
    /// e.g. "↓ 0.4 lb/week" or "↑ 0.2 kg/week"
    static func formatWeeklyRate(_ rate: Double, unit: WeightUnit) -> String {
        let absRate = abs(rate)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let num = formatter.string(from: NSNumber(value: absRate)) ?? "\(absRate)"
        let arrow = rate < 0 ? "↓" : "↑"
        return "\(arrow) \(num) \(unit.rawValue)/week"
    }

    static func formatTrend(_ value: Double, unit: WeightUnit) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + " \(unit.rawValue)"
    }
}
