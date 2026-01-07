//
//  AnalysisProject.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import Foundation
import AppKit

struct AnalysisProject: Identifiable {
    let id: String
    let title: String
    let lastOpened: Date
    let duration: String
    let thumbnailName: String?
    let thumbnail: NSImage?

    init(id: String = UUID().uuidString, title: String, lastOpened: Date, duration: String, thumbnailName: String? = nil, thumbnail: NSImage? = nil) {
        self.id = id
        self.title = title
        self.lastOpened = lastOpened
        self.duration = duration
        self.thumbnailName = thumbnailName
        self.thumbnail = thumbnail
    }

    var formattedLastOpened: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(lastOpened) {
            return "Last opened today"
        } else if calendar.isDateInYesterday(lastOpened) {
            return "Last opened yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: lastOpened, to: now).day ?? 0
            if days == 2 {
                return "Last opened 2 days ago"
            } else if days < 7 {
                return "Last opened \(days) days ago"
            } else if days < 30 {
                let weeks = days / 7
                return weeks == 1 ? "Last opened 1 week ago" : "Last opened \(weeks) weeks ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return "Last opened \(formatter.string(from: lastOpened))"
            }
        }
    }
}
