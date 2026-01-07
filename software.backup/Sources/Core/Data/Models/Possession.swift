//
//  Possession.swift
//  maxmiize-v1
//
//  Created by TechQuest on 14/12/2025.
//

import Foundation

/// Represents a basketball possession - a continuous period where one team controls the ball
/// According to SRS: "A possession begins when a team gains control and ends with score/rebound/turnover"
struct Possession: Identifiable, Codable {
    let id: Int64
    let gameId: Int64
    let teamType: TeamType
    let startTimeMs: Int64
    let endTimeMs: Int64?
    let quarter: Int
    let startTrigger: PossessionTrigger
    let endTrigger: PossessionTrigger?
    let outcome: PossessionOutcome?
    let pointsScored: Int
    let tagCount: Int
    let notes: String
    let createdAt: Date

    enum TeamType: String, Codable {
        case offense = "Offense"
        case defense = "Defense"
    }

    enum PossessionTrigger: String, Codable {
        // Start triggers
        case gameStart = "Game Start"
        case quarterStart = "Quarter Start"
        case madeBasket = "Made Basket"
        case defensiveRebound = "Defensive Rebound"
        case steal = "Steal"
        case turnover = "Turnover Gained"
        case jumpBall = "Jump Ball"

        // End triggers
        case fieldGoalMade = "Field Goal Made"
        case offensiveRebound = "Offensive Rebound (Continuing)"
        case turnoverLost = "Turnover Lost"
        case foul = "Foul"
        case quarterEnd = "Quarter End"
        case gameEnd = "Game End"
    }

    enum PossessionOutcome: String, Codable {
        case score = "Score"
        case turnover = "Turnover"
        case defensiveRebound = "Defensive Rebound"
        case foul = "Foul"
        case endOfPeriod = "End of Period"

        var color: String {
            switch self {
            case .score: return "5adc8c"  // Green - successful
            case .turnover: return "ff5252"  // Red - unsuccessful
            case .defensiveRebound: return "ff9800"  // Orange - unsuccessful
            case .foul: return "ffd24c"  // Yellow - neutral
            case .endOfPeriod: return "9a9a9a"  // Gray - neutral
            }
        }
    }

    /// Duration of the possession in seconds
    var duration: TimeInterval? {
        guard let endTimeMs = endTimeMs else { return nil }
        return TimeInterval(endTimeMs - startTimeMs) / 1000.0
    }

    /// Whether this possession is still active (no end time)
    var isActive: Bool {
        return endTimeMs == nil
    }

    /// Efficiency rating (points per possession)
    var efficiency: Double? {
        guard let _ = endTimeMs else { return nil }
        return Double(pointsScored)
    }
}

/// Helper for possession detection logic
/// NOTE: This class is temporarily disabled during the Tag/Label architecture migration.
/// Possession detection will be rebuilt to work with the new Label-based system.
class PossessionDetector {
    // TODO: Rebuild possession detection using new Tag/Label architecture
    // - Tags represent time ranges (Offense, Defense)
    // - Labels provide event details (Shot, Made, Missed, etc.)
    // - Possession changes detected from tag activation/deactivation
}
