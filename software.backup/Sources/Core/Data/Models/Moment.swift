//
//  Moment.swift
//  maxmiize-v1
//
//  Renamed from Tag.swift
//  Represents a moment - a time-based event that creates a timeline row
//

import Foundation

/// Represents a moment - a time-based event that creates a timeline row
/// Moments are activated/deactivated and create time ranges on the timeline
/// Examples: "Offense" possession, "Defense" possession, "Player Minutes"
struct Moment: Identifiable, Codable {
    let id: String  // moment_id
    let gameId: String
    let momentCategory: String  // "Offense", "Defense", "Player Minutes", custom
    let startTimestampMs: Int64
    var endTimestampMs: Int64?  // nil if still active
    var durationMs: Int64?  // Calculated when ended
    var notes: String?
    let createdAt: Date
    var modifiedAt: Date?

    // Computed properties
    var isActive: Bool {
        return endTimestampMs == nil
    }

    var duration: TimeInterval? {
        guard let end = endTimestampMs else { return nil }
        return TimeInterval(end - startTimestampMs) / 1000.0
    }

    // Layers attached to this moment
    var layers: [Layer] = []

    init(
        id: String = UUID().uuidString,
        gameId: String,
        momentCategory: String,
        startTimestampMs: Int64,
        endTimestampMs: Int64? = nil,
        durationMs: Int64? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.gameId = gameId
        self.momentCategory = momentCategory
        self.startTimestampMs = startTimestampMs
        self.endTimestampMs = endTimestampMs
        self.durationMs = durationMs
        self.notes = notes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Represents a layer - descriptive metadata attached to a moment
/// Layers provide detail/context about what happened during a moment
/// Examples: "Transition", "Shot", "3-Point", "Made", "Assist"
struct Layer: Identifiable, Codable {
    let id: String  // layer_id
    let momentId: String  // Which moment this layer belongs to
    let layerType: String  // "Transition", "Shot", "3-Point", "Made", etc.
    var timestampMs: Int64?  // When during the moment (optional)
    var value: String?  // Optional value (e.g., player name)
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        momentId: String,
        layerType: String,
        timestampMs: Int64? = nil,
        value: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.momentId = momentId
        self.layerType = layerType
        self.timestampMs = timestampMs
        self.value = value
        self.createdAt = createdAt
    }
}

/// Duration type for moments
enum MomentDurationType: String, Codable {
    case auto           // Fixed duration (e.g., 5 seconds)
    case eventBased     // Based on activation/deactivation events
}

/// Event trigger for moment activation/deactivation
enum MomentEventTrigger: Codable, Equatable {
    case manual                         // Manual activation via hotkey/button
    case onMomentStart(String)         // When another moment starts (category name)
    case onMomentEnd(String)           // When another moment ends (category name)

    var isManual: Bool {
        if case .manual = self { return true }
        return false
    }
}

/// Moment button configuration (for UI)
struct MomentButton: Identifiable, Codable {
    let id: String
    var name: String  // Display name of the moment (e.g., "Pick and Roll", "Fast Break")
    var category: String  // Category folder it belongs to ("Offense", "Defense", etc.)
    let color: String  // Hex color
    let hotkey: String?  // Keyboard shortcut
    var isActive: Bool = false

    // Duration configuration
    let durationType: MomentDurationType
    let autoDurationSeconds: Int?  // Used when durationType is .auto (default: 5)

    // Event-based triggers (used when durationType is .eventBased)
    let activationTrigger: MomentEventTrigger
    let deactivationTrigger: MomentEventTrigger

    // Button linking
    let activationLinks: [String]?   // Moment categories to auto-activate when this starts
    let deactivationLinks: [String]?  // Moment categories to auto-deactivate when this starts
    let mutualExclusiveWith: [String]?  // Moments that are mutually exclusive (bidirectional)

    // Lead/Lag time configuration for clip creation
    let leadTimeSeconds: Int?   // Seconds to start clip BEFORE moment activation (default: 0)
    let lagTimeSeconds: Int?    // Seconds to end clip AFTER moment deactivation (default: 0)

    // Canvas position (for blueprint editor)
    var x: CGFloat?  // X position on canvas
    var y: CGFloat?  // Y position on canvas

    // Visual style
    var buttonShape: MomentButtonShape {
        return .sharp  // Moments use sharp corners
    }

    // Coding keys for backward compatibility
    enum CodingKeys: String, CodingKey {
        case id, name, category, color, hotkey, isActive
        case durationType, autoDurationSeconds
        case activationTrigger, deactivationTrigger
        case activationLinks, deactivationLinks, mutualExclusiveWith
        case leadTimeSeconds, lagTimeSeconds
        case x, y
    }

    // Custom decoder for backward compatibility (old blueprints don't have 'name')
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        // For backward compatibility: if 'name' doesn't exist, use 'category' as name
        if let name = try? container.decode(String.self, forKey: .name) {
            self.name = name
        } else {
            self.name = try container.decode(String.self, forKey: .category)
        }

        category = try container.decode(String.self, forKey: .category)
        color = try container.decode(String.self, forKey: .color)
        hotkey = try? container.decode(String.self, forKey: .hotkey)
        isActive = (try? container.decode(Bool.self, forKey: .isActive)) ?? false
        durationType = (try? container.decode(MomentDurationType.self, forKey: .durationType)) ?? .auto
        autoDurationSeconds = try? container.decode(Int.self, forKey: .autoDurationSeconds)
        activationTrigger = (try? container.decode(MomentEventTrigger.self, forKey: .activationTrigger)) ?? .manual
        deactivationTrigger = (try? container.decode(MomentEventTrigger.self, forKey: .deactivationTrigger)) ?? .manual
        activationLinks = try? container.decode([String].self, forKey: .activationLinks)
        deactivationLinks = try? container.decode([String].self, forKey: .deactivationLinks)
        mutualExclusiveWith = try? container.decode([String].self, forKey: .mutualExclusiveWith)
        leadTimeSeconds = try? container.decode(Int.self, forKey: .leadTimeSeconds)
        lagTimeSeconds = try? container.decode(Int.self, forKey: .lagTimeSeconds)
        x = try? container.decode(CGFloat.self, forKey: .x)
        y = try? container.decode(CGFloat.self, forKey: .y)
    }

    init(
        id: String = UUID().uuidString,
        name: String? = nil,  // Optional for backward compatibility
        category: String,
        color: String,
        hotkey: String? = nil,
        isActive: Bool = false,
        durationType: MomentDurationType = .eventBased,
        autoDurationSeconds: Int? = nil,
        activationTrigger: MomentEventTrigger = .manual,
        deactivationTrigger: MomentEventTrigger = .manual,
        activationLinks: [String]? = nil,
        deactivationLinks: [String]? = nil,
        mutualExclusiveWith: [String]? = nil,
        leadTimeSeconds: Int? = nil,
        lagTimeSeconds: Int? = nil,
        x: CGFloat? = nil,
        y: CGFloat? = nil
    ) {
        self.id = id
        self.name = name ?? category  // Default to category if name not provided
        self.category = category
        self.color = color
        self.hotkey = hotkey
        self.isActive = isActive
        self.durationType = durationType
        self.autoDurationSeconds = autoDurationSeconds
        self.activationTrigger = activationTrigger
        self.deactivationTrigger = deactivationTrigger
        self.activationLinks = activationLinks
        self.deactivationLinks = deactivationLinks
        self.mutualExclusiveWith = mutualExclusiveWith
        self.leadTimeSeconds = leadTimeSeconds
        self.lagTimeSeconds = lagTimeSeconds
        self.x = x
        self.y = y
    }
}

/// Layer button configuration (for UI)
struct LayerButton: Identifiable, Codable {
    let id: String
    let layerType: String  // "Transition", "Shot", "3-Point", etc.
    let color: String
    let hotkey: String?
    let activates: [String]?  // Other layers to activate when this is clicked

    // Canvas position (for blueprint editor)
    var x: CGFloat?  // X position on canvas
    var y: CGFloat?  // Y position on canvas

    // Visual style
    var buttonShape: MomentButtonShape {
        return .rounded  // Layers use rounded corners
    }

    // Coding keys for backward compatibility
    enum CodingKeys: String, CodingKey {
        case id, layerType, color, hotkey, activates
        case x, y
    }

    init(
        id: String = UUID().uuidString,
        layerType: String,
        color: String,
        hotkey: String? = nil,
        activates: [String]? = nil,
        x: CGFloat? = nil,
        y: CGFloat? = nil
    ) {
        self.id = id
        self.layerType = layerType
        self.color = color
        self.hotkey = hotkey
        self.activates = activates
        self.x = x
        self.y = y
    }
}

/// Blueprint - A pre-configured set of moments and layers for a specific workflow
struct Blueprint: Identifiable, Codable {
    let id: String
    var name: String
    var moments: [MomentButton]
    var layers: [LayerButton]
    let createdAt: Date
    var modifiedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        moments: [MomentButton],
        layers: [LayerButton],
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.moments = moments
        self.layers = layers
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

enum MomentButtonShape {
    case sharp    // Rectangle (for moments)
    case rounded  // Rounded corners (for layers)
}

/// Default moment categories
struct DefaultMomentCategories {
    static let offense = MomentButton(
        category: "Offense",
        color: "5adc8c",  // Green
        hotkey: "1",
        mutualExclusiveWith: ["Defense"]
    )

    static let defense = MomentButton(
        category: "Defense",
        color: "ff5252",  // Red
        hotkey: "2",
        mutualExclusiveWith: ["Offense"]
    )

    static let all: [MomentButton] = [offense, defense]
}

/// Default layer types
struct DefaultLayerTypes {
    static let transition = LayerButton(
        layerType: "Transition",
        color: "ffd24c",  // Yellow
        hotkey: "T",
        activates: nil
    )

    static let shot = LayerButton(
        layerType: "Shot",
        color: "2979ff",  // Blue
        hotkey: "S",
        activates: nil
    )

    static let onePoint = LayerButton(
        layerType: "1-Point",
        color: "ff9800",  // Orange
        hotkey: "Q",
        activates: nil
    )

    static let twoPoint = LayerButton(
        layerType: "2-Point",
        color: "03a9f4",  // Light Blue
        hotkey: "W",
        activates: nil
    )

    static let threePoint = LayerButton(
        layerType: "3-Point",
        color: "9c27b0",  // Purple
        hotkey: "E",
        activates: nil
    )

    static let made = LayerButton(
        layerType: "Made",
        color: "5adc8c",  // Green
        hotkey: "M",
        activates: nil
    )

    static let missed = LayerButton(
        layerType: "Missed",
        color: "ff5252",  // Red
        hotkey: "X",
        activates: nil
    )

    static let assist = LayerButton(
        layerType: "Assist",
        color: "00bcd4",  // Cyan
        hotkey: "A",
        activates: nil
    )

    static let all: [LayerButton] = [
        transition, shot, onePoint, twoPoint, threePoint, made, missed, assist
    ]
}
