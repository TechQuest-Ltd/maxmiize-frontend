//
//  Note.swift
//  maxmiize-v1
//
//  Note model for attaching notes to moments, layers, and players
//

import Foundation

struct Note: Identifiable, Codable {
    let id: String
    let momentId: String  // The moment this note belongs to
    let gameId: String
    let content: String
    let attachedTo: [NoteAttachment]  // What this note is attached to
    let playerId: String?  // Optional player this note is about
    let createdAt: Date
    var modifiedAt: Date?

    init(
        id: String = UUID().uuidString,
        momentId: String,
        gameId: String,
        content: String,
        attachedTo: [NoteAttachment] = [],
        playerId: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.momentId = momentId
        self.gameId = gameId
        self.content = content
        self.attachedTo = attachedTo
        self.playerId = playerId
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// What a note can be attached to
enum NoteAttachmentType: String, Codable {
    case moment = "moment"
    case layer = "layer"
    case player = "player"
}

struct NoteAttachment: Codable, Equatable {
    let type: NoteAttachmentType
    let id: String  // moment_id, layer_id, or player_id

    init(type: NoteAttachmentType, id: String) {
        self.type = type
        self.id = id
    }
}

extension Moment {
    /// Get all notes for this moment
    func getNotes(gameId: String) -> [Note] {
        return DatabaseManager.shared.getNotes(momentId: self.id, gameId: gameId)
    }
}
