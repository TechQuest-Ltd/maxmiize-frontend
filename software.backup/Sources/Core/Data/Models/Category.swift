//
//  Category.swift
//  maxmiize-v1
//
//  Represents a moment category - used to organize and classify moments
//

import Foundation
import SwiftUI

/// Represents a moment category stored in the database
struct Category: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var color: String  // Hex color without #
    var sortOrder: Int  // For ordering categories in UI
    let createdAt: Date
    var modifiedAt: Date?

    init(
        id: String = UUID().uuidString,
        name: String,
        color: String,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Default categories
struct DefaultCategories {
    static let offense = Category(
        name: "Offense",
        color: "5adc8c",  // Green
        sortOrder: 0
    )

    static let defense = Category(
        name: "Defense",
        color: "ff5252",  // Red
        sortOrder: 1
    )

    static let all: [Category] = [offense, defense]
}
