//
//  UserSettings.swift
//  Fyra
//

import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var weightUnit: WeightUnit
    var photoMode: PhotoMode
    var preferredPoseSingle: Pose
    var reminderTime: Date?
    var goalType: GoalType
    var appearanceMode: AppearanceMode?
    /// When true, hide weight on Check-In main surface (use "Add weight" to log).
    var photoFirstMode: Bool = false
    /// When true, Compare view hides weight delta.
    var hideWeightDeltaInCompare: Bool = false
    /// Optional goal range (min/max); unit follows weightUnit for weight goals.
    var goalMinWeight: Double?
    var goalMaxWeight: Double?
    /// Optional pace range (per week): e.g. -1.0 to -0.25 lb/week or +0.25 to +0.75.
    var paceMinPerWeek: Double?
    var paceMaxPerWeek: Double?
    /// Private 1-sentence "Why I started"; shown only in Compare view.
    var whyStarted: String = ""
    /// Dates when fluctuation banner was dismissed (yyyy-MM-dd); no red, no nagging.
    var fluctuationBannerDismissedDateStrings: [String] = []
    /// One check-in marked as baseline (ID stored here; only one baseline).
    var baselineCheckInID: UUID?
    /// Active progress period (goal phase).
    var activeProgressPeriodID: UUID?
    /// Last time user exported data (optional display).
    var lastExportDate: Date?
    /// When return (welcome-back) banner was dismissed; show again after 14 days.
    var returnBannerDismissedAt: Date?
    /// Compare opens: date string (yyyy-MM-dd) for which count applies.
    var compareOpensDateString: String = ""
    /// Compare opens count for that day (resets daily).
    var compareOpensCount: Int = 0
    /// Date string when compare nudge was dismissed (per day).
    var compareNudgeDismissedDateString: String = ""

    init(
        id: UUID = UUID(),
        weightUnit: WeightUnit = .lb,
        photoMode: PhotoMode = .single,
        preferredPoseSingle: Pose = .front,
        reminderTime: Date? = nil,
        goalType: GoalType = .none,
        appearanceMode: AppearanceMode? = .system,
        photoFirstMode: Bool = false,
        hideWeightDeltaInCompare: Bool = false,
        goalMinWeight: Double? = nil,
        goalMaxWeight: Double? = nil,
        paceMinPerWeek: Double? = nil,
        paceMaxPerWeek: Double? = nil,
        whyStarted: String = "",
        fluctuationBannerDismissedDateStrings: [String] = [],
        baselineCheckInID: UUID? = nil,
        activeProgressPeriodID: UUID? = nil,
        lastExportDate: Date? = nil,
        returnBannerDismissedAt: Date? = nil,
        compareOpensDateString: String = "",
        compareOpensCount: Int = 0,
        compareNudgeDismissedDateString: String = ""
    ) {
        self.id = id
        self.weightUnit = weightUnit
        self.photoMode = photoMode
        self.preferredPoseSingle = preferredPoseSingle
        self.reminderTime = reminderTime
        self.goalType = goalType
        self.appearanceMode = appearanceMode
        self.photoFirstMode = photoFirstMode
        self.hideWeightDeltaInCompare = hideWeightDeltaInCompare
        self.goalMinWeight = goalMinWeight
        self.goalMaxWeight = goalMaxWeight
        self.paceMinPerWeek = paceMinPerWeek
        self.paceMaxPerWeek = paceMaxPerWeek
        self.whyStarted = whyStarted
        self.fluctuationBannerDismissedDateStrings = fluctuationBannerDismissedDateStrings
        self.baselineCheckInID = baselineCheckInID
        self.activeProgressPeriodID = activeProgressPeriodID
        self.lastExportDate = lastExportDate
        self.returnBannerDismissedAt = returnBannerDismissedAt
        self.compareOpensDateString = compareOpensDateString
        self.compareOpensCount = compareOpensCount
        self.compareNudgeDismissedDateString = compareNudgeDismissedDateString
    }
}
