//
//  CameraAngle.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import Foundation

/// Standard camera angles for sports video analysis
enum CameraAngle: String, CaseIterable, Codable {
    case baseline = "Baseline"
    case sideline = "Sideline"
    case elevated = "Elevated"
    case broadcast = "Broadcast"
    case bench = "Bench"
    case endzone = "Endzone"
    case tacticalHigh = "Tactical High"
    case tacticalWide = "Tactical Wide"

    /// Display name for UI
    var displayName: String {
        return rawValue
    }

    /// Database value (lowercase for consistency with existing data)
    var databaseValue: String {
        switch self {
        case .baseline:
            return "baseline"
        case .sideline:
            return "sideline"
        case .elevated:
            return "elevated"
        case .broadcast:
            return "broadcast"
        case .bench:
            return "bench"
        case .endzone:
            return "endzone"
        case .tacticalHigh:
            return "tactical_high"
        case .tacticalWide:
            return "tactical_wide"
        }
    }

    /// Initialize from database value
    init?(databaseValue: String) {
        switch databaseValue.lowercased() {
        case "baseline":
            self = .baseline
        case "sideline":
            self = .sideline
        case "elevated":
            self = .elevated
        case "broadcast":
            self = .broadcast
        case "bench":
            self = .bench
        case "endzone":
            self = .endzone
        case "tactical_high", "tactical high":
            self = .tacticalHigh
        case "tactical_wide", "tactical wide":
            self = .tacticalWide
        default:
            return nil
        }
    }
}
