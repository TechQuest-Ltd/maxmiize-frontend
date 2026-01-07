//
//  Playlist.swift
//  maxmiize-v1
//
//  Created by TechQuest on 04/01/2026.
//

import Foundation

/// Purpose of a playlist - helps coaches understand intent at a glance
enum PlaylistPurpose: String, Codable, CaseIterable {
    case teaching = "Teaching"
    case development = "Development"
    case scouting = "Scouting"
    case situational = "Situational"

    var color: String {
        switch self {
        case .teaching: return "2979ff"      // Blue
        case .development: return "5adc8c"   // Green
        case .scouting: return "ff9800"      // Orange
        case .situational: return "9c27b0"   // Purple
        }
    }

    var icon: String {
        switch self {
        case .teaching: return "book.fill"
        case .development: return "arrow.up.right"
        case .scouting: return "magnifyingglass"
        case .situational: return "target"
        }
    }
}

/// A curated collection of clips for a specific coaching purpose
struct Playlist: Identifiable, Codable {
    let id: String
    let projectId: String
    var name: String
    var purpose: PlaylistPurpose
    var description: String?

    // Filter criteria used to generate this playlist
    var filterCriteria: PlaylistFilters?

    // Curated clips (ordered list of clip IDs with display order)
    var clipIds: [String]  // Order matters for presentation

    // Metadata
    let createdAt: Date
    var modifiedAt: Date?

    init(
        id: String = UUID().uuidString,
        projectId: String,
        name: String,
        purpose: PlaylistPurpose,
        description: String? = nil,
        filterCriteria: PlaylistFilters? = nil,
        clipIds: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.purpose = purpose
        self.description = description
        self.filterCriteria = filterCriteria
        self.clipIds = clipIds
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Total duration of all clips in the playlist
    func calculateDuration(clips: [PlaylistClipWithMetadata]) -> TimeInterval {
        return clips.reduce(0) { $0 + $1.clip.duration }
    }

    /// Formatted duration string
    func formattedDuration(clips: [PlaylistClipWithMetadata]) -> String {
        let totalSeconds = Int(calculateDuration(clips: clips))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Filter criteria for generating playlists
struct PlaylistFilters: Codable, Equatable {
    var playerIds: [String]?           // Filter by specific players
    var momentCategories: [String]?    // Filter by moment type (Offense, Defense)
    var layerTypes: [String]?          // Filter by event type (Shot, Made, Missed, etc.)
    var quarters: [Int]?               // Filter by quarter
    var outcomes: [String]?            // Filter by possession outcome
    var sets: [String]?                // Filter by set/play type (if tagged)
    var minDuration: TimeInterval?     // Minimum clip duration
    var maxDuration: TimeInterval?     // Maximum clip duration

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        return playerIds?.isEmpty == false ||
               momentCategories?.isEmpty == false ||
               layerTypes?.isEmpty == false ||
               quarters?.isEmpty == false ||
               outcomes?.isEmpty == false ||
               sets?.isEmpty == false ||
               minDuration != nil ||
               maxDuration != nil
    }

    /// User-friendly description of active filters
    var description: String {
        var parts: [String] = []

        if let playerIds = playerIds, !playerIds.isEmpty {
            parts.append("\(playerIds.count) player(s)")
        }
        if let categories = momentCategories, !categories.isEmpty {
            parts.append(categories.joined(separator: ", "))
        }
        if let layers = layerTypes, !layers.isEmpty {
            parts.append(layers.joined(separator: ", "))
        }
        if let quarters = quarters, !quarters.isEmpty {
            parts.append("Q\(quarters.map { String($0) }.joined(separator: ", Q"))")
        }
        if let outcomes = outcomes, !outcomes.isEmpty {
            parts.append(outcomes.joined(separator: ", "))
        }

        return parts.isEmpty ? "No filters" : parts.joined(separator: " · ")
    }
}

/// Clip with enriched metadata for playlist display
struct PlaylistClipWithMetadata: Identifiable {
    let clip: Clip
    var moment: Moment?           // The moment this clip is from
    var layers: [Layer]           // Events that happened during this clip
    var players: [Player]         // Players involved in this clip
    var outcome: String?          // What happened (Made, Missed, Turnover, etc.)
    var quarter: Int?             // Which quarter
    var setName: String?          // Set/play name if tagged

    var id: String { clip.id }

    /// Primary action label (e.g., "2-Point Made")
    var actionLabel: String {
        let shotType = layers.first { ["1-Point", "2-Point", "3-Point"].contains($0.layerType) }?.layerType ?? "Shot"
        let outcome = layers.first { ["Made", "Missed"].contains($0.layerType) }?.layerType ?? ""
        return outcome.isEmpty ? shotType : "\(shotType) \(outcome)"
    }

    /// Player names involved
    var playerNames: String {
        guard !players.isEmpty else { return "—" }
        return players.map { $0.name }.joined(separator: ", ")
    }

    /// Formatted quarter (e.g., "Q1", "Q2")
    var formattedQuarter: String {
        guard let q = quarter else { return "—" }
        return "Q\(q)"
    }
}

/// UI state for presentation mode
struct PlaylistPresentationMode {
    var isEnabled: Bool = false
    var currentClipIndex: Int = 0
    var isPlaying: Bool = false
    var playbackSpeed: Float = 1.0
    var autoAdvance: Bool = false
}
