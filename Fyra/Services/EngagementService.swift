//
//  EngagementService.swift
//  Fyra
//

import Foundation

/// Return banner (gap >= 14 days) and compare cooldown nudge. No guilt, no nagging.
enum EngagementService {
    static let returnBannerGapDays = 14
    static let compareNudgeOpenThreshold = 5

    private static var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Should show "Welcome back. Let's just log today." (no check-in in >= 14 days).
    static func shouldShowReturnBanner(
        lastCheckInDate: Date?,
        returnBannerDismissedAt: Date?
    ) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        guard let last = lastCheckInDate else { return true }
        let daysSinceLast = calendar.dateComponents([.day], from: last, to: now).day ?? 0
        guard daysSinceLast >= returnBannerGapDays else { return false }
        if let dismissed = returnBannerDismissedAt {
            let daysSinceDismissed = calendar.dateComponents([.day], from: dismissed, to: now).day ?? 0
            return daysSinceDismissed >= returnBannerGapDays
        }
        return true
    }

    /// Record that user opened Compare; returns updated count for today.
    static func recordCompareOpen(
        settings: UserSettings
    ) -> Int {
        let today = todayDateString
        if settings.compareOpensDateString != today {
            settings.compareOpensDateString = today
            settings.compareOpensCount = 0
        }
        settings.compareOpensCount += 1
        return settings.compareOpensCount
    }

    /// Should show "Progress shows best over weeks." (opened Compare > N times today).
    static func shouldShowCompareNudge(
        settings: UserSettings
    ) -> Bool {
        guard settings.compareOpensCount > compareNudgeOpenThreshold else { return false }
        return settings.compareNudgeDismissedDateString != todayDateString
    }

    /// Dismiss compare nudge for today.
    static func dismissCompareNudge(settings: UserSettings) {
        settings.compareNudgeDismissedDateString = todayDateString
    }
}
