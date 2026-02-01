//
//  ComparePresetService.swift
//  Fyra
//

import Foundation

/// Preset selection for Compare: first vs latest, 30 days vs today, baseline vs today, month/week, best visual change.
struct ComparePresetService {
    let checkIns: [CheckIn]
    let calendar: Calendar
    let baselineCheckInID: UUID?

    init(checkIns: [CheckIn], calendar: Calendar = .current, baselineCheckInID: UUID? = nil) {
        self.checkIns = checkIns.sorted { $0.date < $1.date }
        self.calendar = calendar
        self.baselineCheckInID = baselineCheckInID
    }

    /// First vs Latest (by date).
    func firstVsLatest() -> (from: CheckIn, to: CheckIn)? {
        guard let first = checkIns.first, let last = checkIns.last, first.id != last.id else { return nil }
        return (first, last)
    }

    /// Today vs ~30 days ago (nearest check-in on or near 30 days ago).
    func todayVs30DaysAgo() -> (from: CheckIn, to: CheckIn)? {
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
        let to = checkIns.last(where: { $0.date <= today })
        let from = checkIns.last(where: { $0.date <= thirtyDaysAgo })
            ?? checkIns.first(where: { $0.date >= thirtyDaysAgo })
        guard let to = to, let from = from, from.id != to.id else { return nil }
        return (from, to)
    }

    /// This month start vs end (earliest and latest check-in in current month).
    func thisMonthStartVsEnd() -> (from: CheckIn, to: CheckIn)? {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
        let inMonth = checkIns.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
        guard let from = inMonth.first, let to = inMonth.last, from.id != to.id else { return nil }
        return (from, to)
    }

    /// This week start vs end (calendar week).
    func thisWeekStartVsEnd() -> (from: CheckIn, to: CheckIn)? {
        let now = Date()
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return nil }
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
        let inWeek = checkIns.filter { $0.date >= startOfWeek && $0.date <= endOfWeek }
        guard let from = inWeek.first, let to = inWeek.last, from.id != to.id else { return nil }
        return (from, to)
    }

    /// Best visual change this month: earliest and latest check-in in month that both have the selected pose; else earliest vs latest in month.
    func bestVisualChangeThisMonth(pose: Pose) -> (from: CheckIn, to: CheckIn)? {
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
        let inMonth = checkIns.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
        let withPose = inMonth.filter { $0.photoPath(for: pose) != nil }
        if withPose.count >= 2, let f = withPose.first, let t = withPose.last, f.id != t.id {
            return (f, t)
        }
        if let f = inMonth.first, let t = inMonth.last, f.id != t.id {
            return (f, t)
        }
        return nil
    }

    /// Baseline vs Today: baseline check-in vs latest (prefer same pose); fallback baseline vs latest overall.
    func baselineVsToday(pose: Pose) -> (from: CheckIn, to: CheckIn)? {
        guard let baselineID = baselineCheckInID,
              let baseline = checkIns.first(where: { $0.id == baselineID }),
              let latest = checkIns.last,
              baseline.id != latest.id else { return nil }
        let withPose = checkIns.filter { $0.photoPath(for: pose) != nil }
        let toCheckIn = withPose.isEmpty ? latest : withPose.last!
        guard toCheckIn.id != baseline.id else { return nil }
        return (baseline, toCheckIn)
    }
}
