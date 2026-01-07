//
//  WizardState.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import Foundation
import Combine
import AVFoundation
import AppKit

enum ProjectSaveError: Error {
    case saveFailed(String)

    var localizedDescription: String {
        switch self {
        case .saveFailed(let message):
            return message
        }
    }
}

enum WizardStep: Int, CaseIterable {
    case analysisDetails = 1
    case importVideos = 2
    case templateRoster = 3

    var title: String {
        switch self {
        case .analysisDetails: return "Analysis Details"
        case .importVideos: return "Import Videos"
        case .templateRoster: return "Template & Roster"
        }
    }

    var subtitle: String {
        switch self {
        case .analysisDetails: return "Name, sport, competition"
        case .importVideos: return "Sources and angles"
        case .templateRoster: return "Structure and squad"
        }
    }
}

struct VideoFile: Identifiable {
    let id = UUID()
    let name: String
    let duration: String
    let url: URL
    let thumbnail: NSImage?
}

enum VideoImportMode: String, CaseIterable {
    case copy = "Copy"
    case move = "Move"

    var description: String {
        switch self {
        case .copy: return "Copy videos into project (original files remain)"
        case .move: return "Move videos into project (original files removed)"
        }
    }
}

class WizardState: ObservableObject {
    // Step 1: Analysis Details
    @Published var currentStep: WizardStep = .analysisDetails
    @Published var analysisName: String = ""
    @Published var sport: String = "Basketball"
    @Published var competition: String = ""
    @Published var saveLocation: URL?
    @Published var saveLocationName: String = "Default Location"

    // Step 2: Import Videos
    @Published var importedVideos: [VideoFile] = []
    @Published var angleAssignments: [String] = []
    @Published var videoImportMode: VideoImportMode = .copy // Copy or Move videos into project
    @Published var selectedMode: Int = 0 // 0 = Single Game, 1 = Multiple Games, 2 = Combine Games
    @Published var addToCombinedTimeline: Bool = false
    @Published var keepAsOwnTimeline: Bool = false
    @Published var placeGamesSequentially: Bool = false
    @Published var keepGamesSeparate: Bool = false
    @Published var mergeAllGames: Bool = false

    // Step 3: Template & Roster
    @Published var selectedTemplate: Int = 0 // 0 = Default, 1 = Scratch, 2 = Existing
    @Published var attachRoster: Bool = false

    func nextStep() {
        if let nextStep = WizardStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }

    func previousStep() {
        if let previousStep = WizardStep(rawValue: currentStep.rawValue - 1) {
            currentStep = previousStep
        }
    }

    func canGoNext() -> Bool {
        switch currentStep {
        case .analysisDetails:
            return !analysisName.isEmpty && !sport.isEmpty
        case .importVideos:
            return true // Can skip for now
        case .templateRoster:
            return false // Last step
        }
    }

    func resetWizard() {
        // Reset to first step
        currentStep = .analysisDetails

        // Reset Step 1: Analysis Details
        analysisName = ""
        sport = "Basketball"
        competition = ""
        saveLocation = nil
        saveLocationName = "Default Location"

        // Reset Step 2: Import Videos
        importedVideos = []
        angleAssignments = []
        selectedMode = 0
        addToCombinedTimeline = false
        keepAsOwnTimeline = false
        placeGamesSequentially = false
        keepGamesSeparate = false
        mergeAllGames = false

        // Reset Step 3: Template & Roster
        selectedTemplate = 0
        attachRoster = false
    }

    func addVideo(url: URL) {
        let fileName = url.lastPathComponent
        let duration = extractDuration(from: url)
        let thumbnail = extractThumbnail(from: url)
        let video = VideoFile(name: fileName, duration: duration, url: url, thumbnail: thumbnail)
        importedVideos.append(video)
        angleAssignments.append("") // Add empty angle assignment for new video
    }

    func removeVideo(id: UUID) {
        if let index = importedVideos.firstIndex(where: { $0.id == id }) {
            importedVideos.remove(at: index)
            // Also remove the corresponding angle assignment
            if index < angleAssignments.count {
                angleAssignments.remove(at: index)
            }
        }
    }

    private func extractDuration(from url: URL) -> String {
        let asset = AVURLAsset(url: url)

        // Get duration synchronously using AVAsynchronousKeyValueLoading
        var error: NSError?
        let status = asset.statusOfValue(forKey: "duration", error: &error)

        let duration: CMTime
        if status == .loaded {
            duration = asset.duration
        } else {
            // Force synchronous load for local files
            asset.loadValuesAsynchronously(forKeys: ["duration"]) {}
            duration = asset.duration
        }

        let totalSeconds = CMTimeGetSeconds(duration)

        if totalSeconds.isNaN || totalSeconds.isInfinite {
            return "00:00:00"
        }

        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func extractThumbnail(from url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        // Extract frame at 1 second (or beginning if video is shorter)
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    func saveProject() -> Result<String, ProjectSaveError> {
        print("💾 Starting project save...")

        // Create project bundle using ProjectManager with custom location if specified
        let projectResult = ProjectManager.shared.createProject(
            name: analysisName,
            sport: sport,
            season: competition.isEmpty ? nil : competition,
            competition: competition.isEmpty ? nil : competition,
            customDirectory: saveLocation
        )

        guard case .success(let bundle) = projectResult else {
            if case .failure(let error) = projectResult {
                return .failure(.saveFailed(error.localizedDescription))
            }
            return .failure(.saveFailed("Unknown error creating project"))
        }

        let projectId = bundle.projectId
        print("✅ Project bundle created: \(projectId)")

        // Begin transaction for game and videos
        guard DatabaseManager.shared.beginTransaction() else {
            return .failure(.saveFailed("Failed to begin database transaction"))
        }

        // Create a game for this project (wizard assumes single game or combined timeline)
        let gameResult = DatabaseManager.shared.createGame(
            projectId: projectId,
            name: analysisName
        )

        guard case .success(let gameId) = gameResult else {
            DatabaseManager.shared.rollbackTransaction()
            if case .failure(let error) = gameResult {
                return .failure(.saveFailed(error.localizedDescription))
            }
            return .failure(.saveFailed("Unknown error creating game"))
        }

        // Import videos into project bundle
        print("🎬 Importing \(importedVideos.count) videos into bundle (\(videoImportMode.rawValue) mode)...")
        let videoUrls = importedVideos.map { $0.url }
        let importResult = ProjectManager.shared.importVideos(from: videoUrls, gameId: gameId, mode: videoImportMode)

        guard case .success(let videoIds) = importResult else {
            DatabaseManager.shared.rollbackTransaction()
            if case .failure(let error) = importResult {
                return .failure(.saveFailed(error.localizedDescription))
            }
            return .failure(.saveFailed("Failed to import videos"))
        }

        print("✅ Imported \(videoIds.count) videos")

        // Save additional video metadata (camera angles, thumbnails, etc.)
        for (index, video) in importedVideos.enumerated() {
            // Get camera angle from assignments or default to baseline
            let angleString = index < angleAssignments.count && !angleAssignments[index].isEmpty
                ? angleAssignments[index]
                : ""

            // Parse as CameraAngle enum for validation and normalization
            let angle = CameraAngle(databaseValue: angleString) ?? .baseline
            let cameraAngle = angle.databaseValue

            // Extract video metadata
            let asset = AVURLAsset(url: video.url)
            let durationMs = Int64(CMTimeGetSeconds(asset.duration) * 1000)

            // Get video track properties
            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                DatabaseManager.shared.rollbackTransaction()
                return .failure(.saveFailed("No video track found for '\(video.name)'. The file may be corrupted or in an unsupported format."))
            }

            let frameRate = Double(videoTrack.nominalFrameRate)
            let size = videoTrack.naturalSize
            let width = Int(size.width)
            let height = Int(size.height)

            // Get codec (simplified)
            let codec = "h264" // Default, could parse from format descriptions

            // Save thumbnail to bundle if available
            var thumbnailPath: String?
            if let thumbnail = video.thumbnail {
                let thumbnailFileName = "\(videoIds[index])_thumb.png"
                let thumbnailURL = bundle.thumbnailsPath.appendingPathComponent(thumbnailFileName)

                do {
                    if let tiffData = thumbnail.tiffRepresentation,
                       let bitmapImage = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                        try pngData.write(to: thumbnailURL)
                        thumbnailPath = "thumbnails/\(thumbnailFileName)"
                    }
                } catch {
                    DatabaseManager.shared.rollbackTransaction()
                    return .failure(.saveFailed("Failed to save thumbnail for '\(video.name)': \(error.localizedDescription)"))
                }
            }

            // Save video metadata to database (videos already copied by ProjectManager)
            let videoFilePath = "videos/\(video.url.lastPathComponent)"
            let videoResult = DatabaseManager.shared.saveVideo(
                gameId: gameId,
                filePath: videoFilePath,  // Relative path in bundle
                cameraAngle: cameraAngle,
                durationMs: durationMs,
                frameRate: frameRate,
                width: width,
                height: height,
                codec: codec,
                thumbnailPath: thumbnailPath
            )

            if case .failure(let error) = videoResult {
                DatabaseManager.shared.rollbackTransaction()
                return .failure(.saveFailed("Failed to save video '\(video.name)': \(error.localizedDescription)"))
            }
        }

        // Commit transaction - all operations succeeded
        guard DatabaseManager.shared.commitTransaction() else {
            DatabaseManager.shared.rollbackTransaction()
            return .failure(.saveFailed("Failed to commit database transaction"))
        }

        print("Successfully saved project with ID: \(projectId)")
        return .success(projectId)
    }
}
