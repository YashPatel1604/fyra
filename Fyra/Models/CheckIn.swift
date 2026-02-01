//
//  CheckIn.swift
//  Fyra
//

import Foundation
import SwiftData

enum WeightUnit: String, Codable, CaseIterable {
    case lb
    case kg
}

enum AppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum Pose: String, Codable, CaseIterable {
    case front
    case side
    case back

    var displayName: String {
        rawValue.capitalized
    }
}

enum PhotoMode: String, Codable, CaseIterable {
    case single
    case threePose
}

enum GoalType: String, Codable, CaseIterable {
    case loseWeight
    case gainWeight
    case gainMuscle
    case recomposition
    case none

    var displayName: String {
        switch self {
        case .loseWeight: return "Lose weight"
        case .gainWeight: return "Gain weight"
        case .gainMuscle: return "Gain muscle"
        case .recomposition: return "Recomposition"
        case .none: return "No specific goal"
        }
    }
}

/// Predefined non-scale win tags (optional, no scoring).
enum CheckInTag: String, Codable, CaseIterable {
    case clothesFitBetter
    case veinsMoreVisible
    case moreDefinition
    case strengthUp
    case energyImproved
    case custom

    var displayName: String {
        switch self {
        case .clothesFitBetter: return "Clothes fit better"
        case .veinsMoreVisible: return "Veins more visible"
        case .moreDefinition: return "More definition"
        case .strengthUp: return "Strength up"
        case .energyImproved: return "Energy improved"
        case .custom: return "Other"
        }
    }
}

@Model
final class CheckIn: Identifiable {
    var id: UUID
    var date: Date
    var weight: Double?
    var frontPhotoPath: String?
    var sidePhotoPath: String?
    var backPhotoPath: String?
    var note: String?
    /// Optional tags (raw values + custom string); no scoring.
    var tagRawValues: [String] = []
    /// Optional waist measurement (e.g. inches or cm; unit follows settings).
    var waistMeasurement: Double?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double? = nil,
        frontPhotoPath: String? = nil,
        sidePhotoPath: String? = nil,
        backPhotoPath: String? = nil,
        note: String? = nil,
        tagRawValues: [String] = [],
        waistMeasurement: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.frontPhotoPath = frontPhotoPath
        self.sidePhotoPath = sidePhotoPath
        self.backPhotoPath = backPhotoPath
        self.note = note
        self.tagRawValues = tagRawValues
        self.waistMeasurement = waistMeasurement
    }

    func photoPath(for pose: Pose) -> String? {
        switch pose {
        case .front: return frontPhotoPath
        case .side: return sidePhotoPath
        case .back: return backPhotoPath
        }
    }

    func setPhotoPath(_ path: String?, for pose: Pose) {
        switch pose {
        case .front: frontPhotoPath = path
        case .side: sidePhotoPath = path
        case .back: backPhotoPath = path
        }
    }

    var hasAnyPhoto: Bool {
        frontPhotoPath != nil || sidePhotoPath != nil || backPhotoPath != nil
    }

    var primaryPhotoPath: String? {
        frontPhotoPath ?? sidePhotoPath ?? backPhotoPath
    }

    var hasAnyContent: Bool {
        weight != nil || hasAnyPhoto || !(note?.isEmpty ?? true) || !tagRawValues.isEmpty || waistMeasurement != nil
    }
}
