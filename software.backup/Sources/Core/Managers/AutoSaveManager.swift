//
//  AutoSaveManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import Foundation
import Combine

@MainActor
class AutoSaveManager: ObservableObject {
    static let shared = AutoSaveManager()

    @Published var lastSavedDate: Date?
    @Published var isAutoSaveEnabled: Bool = true
    @Published var autoSaveInterval: TimeInterval = 30.0 // 30 seconds

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var lastSavedText: String {
        guard let lastSaved = lastSavedDate else {
            return "Not saved yet"
        }

        let elapsed = Date().timeIntervalSince(lastSaved)

        if elapsed < 60 {
            return "00:\(String(format: "%02d", Int(elapsed))) ago"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
            return "\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds)) ago"
        } else {
            let hours = Int(elapsed / 3600)
            let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m ago"
        }
    }

    private init() {
        startAutoSave()
    }

    // MARK: - Auto-Save Control

    /// Starts the auto-save timer
    func startAutoSave() {
        guard isAutoSaveEnabled else { return }

        stopAutoSave() // Stop existing timer if any

        print("🔄 Starting auto-save with \(Int(autoSaveInterval))s interval")

        timer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performAutoSave()
            }
        }
    }

    /// Stops the auto-save timer
    func stopAutoSave() {
        timer?.invalidate()
        timer = nil
        print("⏸️ Auto-save stopped")
    }

    /// Manually triggers a save
    func saveNow() {
        performAutoSave()
    }

    // MARK: - Save Logic

    private func performAutoSave() {
        guard let project = ProjectManager.shared.currentProject else {
            print("⚠️ No project open - skipping auto-save")
            return
        }

        print("💾 Auto-saving project: \(project.name)")

        // Save annotations
        AnnotationManager.shared.saveAnnotations(projectId: project.projectId)

        // Update project modified timestamp in database
        let result = DatabaseManager.shared.updateProjectModifiedDate(projectId: project.projectId)

        switch result {
        case .success:
            lastSavedDate = Date()
            print("✅ Auto-save completed at \(lastSavedDate!)")

            // Post notification for UI updates
            NotificationCenter.default.post(name: .projectAutoSaved, object: nil)

        case .failure(let error):
            print("❌ Auto-save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Settings

    /// Updates the auto-save interval and restarts the timer
    func setAutoSaveInterval(_ interval: TimeInterval) {
        autoSaveInterval = interval
        if isAutoSaveEnabled {
            startAutoSave()
        }
    }

    /// Enables or disables auto-save
    func setAutoSaveEnabled(_ enabled: Bool) {
        isAutoSaveEnabled = enabled
        if enabled {
            startAutoSave()
        } else {
            stopAutoSave()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let projectAutoSaved = Notification.Name("projectAutoSaved")
}
