//
//  Player.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import Foundation

struct Player: Identifiable {
    let id: UUID
    let name: String
    let number: Int
    let position: String
    let height: String
    let weight: String
    let nationality: String
    let notes: String

    init(id: UUID = UUID(), name: String, number: Int, position: String, height: String = "", weight: String = "", nationality: String = "", notes: String = "") {
        self.id = id
        self.name = name
        self.number = number
        self.position = position
        self.height = height
        self.weight = weight
        self.nationality = nationality
        self.notes = notes
    }
}
