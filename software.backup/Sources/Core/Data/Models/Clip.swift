//
//  Clip.swift
//  maxmiize-v1
//
//  Created by TechQuest on 14/12/2025.
//

import Foundation
import AppKit
import AVFoundation

/// Represents a clip from a game (applies to all camera angles)
struct Clip: Identifiable, Codable {
    let id: String
    let gameId: String
    let startTimeMs: Int64
    let endTimeMs: Int64
    let title: String
    let notes: String
    let tags: [String]
    let thumbnailPath: String?
    let createdAt: Date
    let modifiedAt: Date?

    init(
        id: String = UUID().uuidString,
        gameId: String,
        startTimeMs: Int64,
        endTimeMs: Int64,
        title: String,
        notes: String = "",
        tags: [String] = [],
        thumbnailPath: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.gameId = gameId
        self.startTimeMs = startTimeMs
        self.endTimeMs = endTimeMs
        self.title = title
        self.notes = notes
        self.tags = tags
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Duration of the clip in seconds
    var duration: TimeInterval {
        return TimeInterval(endTimeMs - startTimeMs) / 1000.0
    }

    /// Start time as CMTime for AVPlayer
    var startTime: CMTime {
        return CMTime(value: startTimeMs, timescale: 1000)
    }

    /// End time as CMTime for AVPlayer
    var endTime: CMTime {
        return CMTime(value: endTimeMs, timescale: 1000)
    }

    /// Formatted duration string (e.g., "0:15")
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted start time (e.g., "12:30")
    var formattedStartTime: String {
        let totalSeconds = Int(startTimeMs / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// In/Out point markers for clip creation
struct ClipMarker {
    var inPoint: CMTime?
    var outPoint: CMTime?

    var hasInPoint: Bool { inPoint != nil }
    var hasOutPoint: Bool { outPoint != nil }
    var hasBothPoints: Bool { inPoint != nil && outPoint != nil }

    /// Duration between in and out points
    var duration: TimeInterval? {
        guard let inPoint = inPoint, let outPoint = outPoint else { return nil }
        return CMTimeSubtract(outPoint, inPoint).seconds
    }

    mutating func clear() {
        inPoint = nil
        outPoint = nil
    }
}
