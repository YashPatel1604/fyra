//
//  BaselineService.swift
//  Fyra
//

import Foundation
import SwiftData

/// Enforces a single baseline check-in; stored in UserSettings.
enum BaselineService {
    /// Set baseline to this check-in ID; clears any previous baseline.
    static func setBaseline(_ checkInID: UUID?, settings: UserSettings) {
        settings.baselineCheckInID = checkInID
    }

    /// Get the baseline check-in from the list, or nil.
    static func getBaseline(checkIns: [CheckIn], settings: UserSettings?) -> CheckIn? {
        guard let id = settings?.baselineCheckInID else { return nil }
        return checkIns.first { $0.id == id }
    }

    /// Returns true if the given check-in is the baseline.
    static func isBaseline(_ checkIn: CheckIn, settings: UserSettings?) -> Bool {
        settings?.baselineCheckInID == checkIn.id
    }
}
