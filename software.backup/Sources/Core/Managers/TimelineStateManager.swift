//
//  TimelineStateManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 22/12/2025.
//

import Foundation
import Combine

@MainActor
class TimelineStateManager: ObservableObject {
    static let shared = TimelineStateManager()

    // Timeline zoom and scroll state - shared across all views
    @Published var zoomLevel: Double = 0.0 // 0 = fully zoomed out, 1 = max zoom
    @Published var scrollOffset: Double = 0 // Scroll position in seconds
    @Published var selectedClipId: String? = nil // Currently selected clip

    private init() {}

    func selectClip(clipId: String) {
        selectedClipId = clipId
        print("📌 TimelineStateManager: Selected clip \(clipId)")
    }

    func clearSelection() {
        selectedClipId = nil
    }
}
