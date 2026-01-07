//
//  ProjectManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import Foundation
import AppKit
import Combine

enum ProjectError: Error {
    case projectAlreadyExists
    case projectNotFound
    case invalidProjectBundle
    case videoImportFailed(String)
    case databaseError(String)

    var localizedDescription: String {
        switch self {
        case .projectAlreadyExists:
            return "A project with this name already exists"
        case .projectNotFound:
            return "Project file not found"
        case .invalidProjectBundle:
            return "Invalid or corrupted project bundle"
        case .videoImportFailed(let reason):
            return "Video import failed: \(reason)"
        case .databaseError(let reason):
            return "Database error: \(reason)"
        }
    }
}

struct ProjectBundle {
    let projectId: String
    let name: String
    let sport: String
    let season: String?
    let bundlePath: URL
    let databasePath: URL
    let videosPath: URL
    let thumbnailsPath: URL
    let exportsPath: URL
    let createdDate: Date
    let lastModifiedDate: Date
}

@MainActor
class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published var currentProject: ProjectBundle?
    @Published var isProjectOpen: Bool = false

    private let fileManager = FileManager.default
    private let projectsDirectory: URL
    private let projectRegistryPath: URL
    private var currentProjectURL: URL?
    private var isAccessingSecurityScopedResource: Bool = false

    private init() {
        // Get Application Support directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        projectsDirectory = appSupport.appendingPathComponent("com.maxmiize.maxmiize-v1/Projects", isDirectory: true)
        projectRegistryPath = appSupport.appendingPathComponent("com.maxmiize.maxmiize-v1/project_registry.json")

        // Create projects directory if it doesn't exist
        try? fileManager.createDirectory(at: projectsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Project Registry

    private struct ProjectRegistryEntry: Codable {
        let projectId: String
        let bundlePath: String
        let name: String
        let lastModified: Date
        let bookmarkData: Data?  // Security-scoped bookmark for custom locations
    }

    private func loadProjectRegistry() -> [ProjectRegistryEntry] {
        guard let data = try? Data(contentsOf: projectRegistryPath),
              let entries = try? JSONDecoder().decode([ProjectRegistryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveProjectRegistry(_ entries: [ProjectRegistryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: projectRegistryPath)
    }

    private func addToRegistry(projectId: String, bundlePath: URL, name: String) {
        var entries = loadProjectRegistry()

        // Remove existing entry if it exists
        entries.removeAll { $0.projectId == projectId }

        // Create security-scoped bookmark for custom locations
        var bookmarkData: Data?
        do {
            bookmarkData = try bundlePath.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            print("⚠️ Failed to create bookmark: \(error)")
        }

        // Add new entry
        entries.append(ProjectRegistryEntry(
            projectId: projectId,
            bundlePath: bundlePath.path,
            name: name,
            lastModified: Date(),
            bookmarkData: bookmarkData
        ))

        saveProjectRegistry(entries)
    }

    private func updateRegistryModifiedDate(projectId: String) {
        var entries = loadProjectRegistry()

        if let index = entries.firstIndex(where: { $0.projectId == projectId }) {
            entries[index] = ProjectRegistryEntry(
                projectId: entries[index].projectId,
                bundlePath: entries[index].bundlePath,
                name: entries[index].name,
                lastModified: Date(),
                bookmarkData: entries[index].bookmarkData
            )
            saveProjectRegistry(entries)
        }
    }

    // MARK: - Create Project

    /// Creates a new .proj bundle with all required folder structure
    func createProject(name: String, sport: String, season: String?, competition: String?, customDirectory: URL? = nil) -> Result<ProjectBundle, ProjectError> {
        print("📦 Creating project: \(name)")

        // Use custom directory if provided, otherwise use default
        let targetDirectory = customDirectory ?? projectsDirectory
        print("📁 Save location: \(targetDirectory.path)")

        // Start accessing security-scoped resource if using custom directory
        var shouldStopAccessing = false
        if let customDir = customDirectory {
            shouldStopAccessing = customDir.startAccessingSecurityScopedResource()
        }

        // Ensure we stop accessing when done
        defer {
            if shouldStopAccessing, let customDir = customDirectory {
                customDir.stopAccessingSecurityScopedResource()
            }
        }

        // Create project bundle folder name
        let bundleName = "\(name).proj"
        let bundlePath = targetDirectory.appendingPathComponent(bundleName, isDirectory: true)

        // Check if project already exists
        if fileManager.fileExists(atPath: bundlePath.path) {
            print("❌ Project already exists at: \(bundlePath.path)")
            return .failure(.projectAlreadyExists)
        }

        do {
            // Create main project bundle directory
            try fileManager.createDirectory(at: bundlePath, withIntermediateDirectories: true)
            print("✅ Created bundle directory: \(bundlePath.path)")

            // Create subdirectories
            let videosPath = bundlePath.appendingPathComponent("videos", isDirectory: true)
            let thumbnailsPath = bundlePath.appendingPathComponent("thumbnails", isDirectory: true)
            let exportsPath = bundlePath.appendingPathComponent("exports", isDirectory: true)
            let clipsPath = exportsPath.appendingPathComponent("clips", isDirectory: true)

            try fileManager.createDirectory(at: videosPath, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: thumbnailsPath, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: exportsPath, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: clipsPath, withIntermediateDirectories: true)

            print("✅ Created subdirectories")

            // Create SQLite database in bundle
            let databasePath = bundlePath.appendingPathComponent("project.db")
            let dbManager = DatabaseManager.shared

            // Initialize database with project
            dbManager.initializeDatabase(at: databasePath.path)

            // Create project record in database - this generates the project ID
            let projectResult = dbManager.createProject(
                name: name,
                sport: sport,
                competition: season
            )

            // Get the project ID from the database result
            guard case .success(let projectId) = projectResult else {
                // Clean up on database error
                try? fileManager.removeItem(at: bundlePath)
                if case .failure(let error) = projectResult {
                    return .failure(.databaseError(error.localizedDescription))
                }
                return .failure(.databaseError("Unknown database error"))
            }

            print("✅ Project ID from database: \(projectId)")

            // Create metadata.json
            let metadata: [String: Any] = [
                "project_id": projectId,
                "name": name,
                "sport": sport,
                "season": season ?? NSNull(),
                "version": "1.0",
                "created_date": ISO8601DateFormatter().string(from: Date()),
                "bundle_format": "folder"
            ]

            let metadataPath = bundlePath.appendingPathComponent("metadata.json")
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try jsonData.write(to: metadataPath)

            print("✅ Created metadata.json")

            // Create ProjectBundle object
            let bundle = ProjectBundle(
                projectId: projectId,
                name: name,
                sport: sport,
                season: season,
                bundlePath: bundlePath,
                databasePath: databasePath,
                videosPath: videosPath,
                thumbnailsPath: thumbnailsPath,
                exportsPath: exportsPath,
                createdDate: Date(),
                lastModifiedDate: Date()
            )

            // Set as current project
            self.currentProject = bundle
            self.isProjectOpen = true

            // Add to project registry for tracking
            addToRegistry(projectId: projectId, bundlePath: bundlePath, name: name)

            print("✅ Project created successfully: \(bundlePath.path)")
            return .success(bundle)

        } catch {
            print("❌ Error creating project: \(error)")
            // Clean up on error
            try? fileManager.removeItem(at: bundlePath)
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    // MARK: - Open Project

    /// Opens an existing .proj bundle
    func openProject(at url: URL) -> Result<ProjectBundle, ProjectError> {
        print("📂 Opening project at: \(url.path)")

        // Stop accessing previous project's security-scoped resource if any
        if isAccessingSecurityScopedResource, let previousURL = currentProjectURL {
            previousURL.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
            currentProjectURL = nil
        }

        // Start accessing security-scoped resource and keep it active
        let didStartAccessing = url.startAccessingSecurityScopedResource()

        // Verify bundle exists
        guard fileManager.fileExists(atPath: url.path) else {
            print("❌ Project bundle not found")
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            return .failure(.projectNotFound)
        }

        // Verify required files and folders
        let databasePath = url.appendingPathComponent("project.db")
        let metadataPath = url.appendingPathComponent("metadata.json")
        let videosPath = url.appendingPathComponent("videos", isDirectory: true)
        let thumbnailsPath = url.appendingPathComponent("thumbnails", isDirectory: true)
        let exportsPath = url.appendingPathComponent("exports", isDirectory: true)

        guard fileManager.fileExists(atPath: databasePath.path),
              fileManager.fileExists(atPath: metadataPath.path) else {
            print("❌ Invalid project bundle - missing required files")
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            return .failure(.invalidProjectBundle)
        }

        do {
            // Read metadata
            let metadataData = try Data(contentsOf: metadataPath)
            guard let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                  let projectId = metadata["project_id"] as? String,
                  let name = metadata["name"] as? String,
                  let sport = metadata["sport"] as? String else {
                print("❌ Invalid metadata format")
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
                return .failure(.invalidProjectBundle)
            }

            let season = metadata["season"] as? String

            // Initialize database connection
            DatabaseManager.shared.initializeDatabase(at: databasePath.path)

            // Get creation date from file attributes
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let createdDate = attributes[.creationDate] as? Date ?? Date()
            let modifiedDate = attributes[.modificationDate] as? Date ?? Date()

            // Create ProjectBundle object
            let bundle = ProjectBundle(
                projectId: projectId,
                name: name,
                sport: sport,
                season: season,
                bundlePath: url,
                databasePath: databasePath,
                videosPath: videosPath,
                thumbnailsPath: thumbnailsPath,
                exportsPath: exportsPath,
                createdDate: createdDate,
                lastModifiedDate: modifiedDate
            )

            // Set as current project and track security-scoped resource
            self.currentProject = bundle
            self.isProjectOpen = true
            self.currentProjectURL = url
            self.isAccessingSecurityScopedResource = didStartAccessing

            print("✅ Project opened successfully")
            return .success(bundle)

        } catch {
            print("❌ Error opening project: \(error)")
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    // MARK: - Import Videos

    /// Imports video files into the project bundle
    func importVideos(from urls: [URL], gameId: String, mode: VideoImportMode = .copy) -> Result<[String], ProjectError> {
        guard let project = currentProject else {
            return .failure(.projectNotFound)
        }

        print("🎬 Importing \(urls.count) videos into project (\(mode.rawValue) mode)")

        var importedVideoIds: [String] = []

        for (index, sourceUrl) in urls.enumerated() {
            do {
                // Generate video ID
                let videoId = UUID().uuidString

                // Create destination path in bundle
                let fileName = sourceUrl.lastPathComponent
                let destinationUrl = project.videosPath.appendingPathComponent(fileName)

                // Copy or Move video file into bundle based on mode
                switch mode {
                case .copy:
                    print("📋 Copying \(fileName)...")
                    try fileManager.copyItem(at: sourceUrl, to: destinationUrl)
                case .move:
                    print("🚚 Moving \(fileName)...")
                    try fileManager.moveItem(at: sourceUrl, to: destinationUrl)
                }

                // Get video file size
                let attributes = try fileManager.attributesOfItem(atPath: destinationUrl.path)
                let fileSize = attributes[.size] as? Int64 ?? 0

                // Create relative path for database (relative to bundle)
                let relativePath = "videos/\(fileName)"

                // Generate thumbnail (simplified for now)
                let thumbnailPath = try generateThumbnail(for: destinationUrl, videoId: videoId)

                // Save to database (simplified for now - will implement createVideo method)
                // TODO: Add createVideo method to DatabaseManager
                let result: Result<Void, DatabaseError> = .success(())

                if case .success = result {
                    importedVideoIds.append(videoId)
                    print("✅ Imported video: \(fileName)")
                } else {
                    print("⚠️ Database save failed for: \(fileName)")
                }

            } catch {
                print("❌ Failed to import video: \(error)")
                return .failure(.videoImportFailed(error.localizedDescription))
            }
        }

        print("✅ Successfully imported \(importedVideoIds.count) videos")
        return .success(importedVideoIds)
    }

    // MARK: - Helper Methods

    private func generateThumbnail(for videoUrl: URL, videoId: String) throws -> String {
        // Placeholder - in real implementation, extract frame from video
        // For now, just return a relative path
        return "thumbnails/\(videoId)_thumb.jpg"
    }

    // MARK: - Recent Projects

    /// Gets a list of recent project bundles sorted by modification date
    func getRecentProjects(limit: Int = 10) -> [AnalysisProject] {
        var projects: [AnalysisProject] = []

        // Load from registry (includes custom locations)
        let registryEntries = loadProjectRegistry()

        for entry in registryEntries {
            var bundleURL: URL?
            var shouldStopAccessing = false

            // Try to resolve bookmark first
            if let bookmarkData = entry.bookmarkData {
                do {
                    var isStale = false
                    bundleURL = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: [.withSecurityScope, .withoutUI],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    if let url = bundleURL {
                        shouldStopAccessing = url.startAccessingSecurityScopedResource()
                    }
                } catch {
                    print("⚠️ Failed to resolve bookmark for recent project: \(error)")
                }
            }

            // Fall back to file path
            if bundleURL == nil {
                bundleURL = URL(fileURLWithPath: entry.bundlePath)
            }

            guard let url = bundleURL else { continue }

            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Check if bundle still exists
            guard fileManager.fileExists(atPath: url.path) else {
                continue
            }

            // Get thumbnail from bundle
            let thumbnailsPath = url.appendingPathComponent("thumbnails", isDirectory: true)
            var thumbnailImage: NSImage?
            var thumbnailName: String?

            if let firstThumbnail = try? fileManager.contentsOfDirectory(at: thumbnailsPath, includingPropertiesForKeys: nil).first {
                thumbnailImage = NSImage(contentsOf: firstThumbnail)
                thumbnailName = "thumbnails/\(firstThumbnail.lastPathComponent)"
            }

            // Calculate total duration from project database
            let databasePath = url.appendingPathComponent("project.db")
            DatabaseManager.shared.initializeDatabase(at: databasePath.path)
            let duration = DatabaseManager.shared.calculateProjectDuration(projectId: entry.projectId)

            projects.append(AnalysisProject(
                id: entry.projectId,
                title: entry.name,
                lastOpened: entry.lastModified,
                duration: duration,
                thumbnailName: thumbnailName,
                thumbnail: thumbnailImage
            ))
        }

        // Sort by modification date (most recent first)
        projects.sort { $0.lastOpened > $1.lastOpened }

        // Limit results
        if projects.count > limit {
            projects = Array(projects.prefix(limit))
        }

        return projects
    }

    /// Finds the bundle path for a project by its ID
    func findProjectBundlePath(projectId: String) -> URL? {
        let entries = loadProjectRegistry()

        guard let entry = entries.first(where: { $0.projectId == projectId }) else {
            return nil
        }

        // Try to resolve security-scoped bookmark first
        if let bookmarkData = entry.bookmarkData {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    print("⚠️ Bookmark is stale for project: \(entry.name)")
                }

                // Verify the bundle still exists
                if fileManager.fileExists(atPath: url.path) {
                    return url
                }
            } catch {
                print("⚠️ Failed to resolve bookmark: \(error)")
            }
        }

        // Fall back to file path (for projects in default location)
        let url = URL(fileURLWithPath: entry.bundlePath)
        if fileManager.fileExists(atPath: url.path) {
            return url
        }

        return nil
    }

    /// Closes the current project
    func closeProject() {
        // Stop accessing security-scoped resource if active
        if isAccessingSecurityScopedResource, let url = currentProjectURL {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
            currentProjectURL = nil
        }

        currentProject = nil
        isProjectOpen = false
        print("📪 Project closed")
    }

    /// Gets the path to the current project bundle
    func getCurrentProjectPath() -> URL? {
        return currentProject?.bundlePath
    }

    // MARK: - Remove Project

    /// Removes a project from the registry and deletes its bundle folder
    func removeProject(projectId: String) -> Result<Void, ProjectError> {
        print("🗑️ Removing project: \(projectId)")

        // Load registry
        var entries = loadProjectRegistry()

        // Find entry
        guard let entry = entries.first(where: { $0.projectId == projectId }) else {
            print("❌ Project not found in registry")
            return .failure(.projectNotFound)
        }

        // Get bundle URL
        var bundleURL: URL?
        var shouldStopAccessing = false

        // Try to resolve bookmark first
        if let bookmarkData = entry.bookmarkData {
            do {
                var isStale = false
                bundleURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if let url = bundleURL {
                    shouldStopAccessing = url.startAccessingSecurityScopedResource()
                }
            } catch {
                print("⚠️ Failed to resolve bookmark: \(error)")
            }
        }

        // Fall back to file path
        if bundleURL == nil {
            bundleURL = URL(fileURLWithPath: entry.bundlePath)
        }

        // Close project if it's currently open
        if currentProject?.projectId == projectId {
            closeProject()
        }

        // Delete project folder
        if let url = bundleURL {
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    print("✅ Deleted project bundle at: \(url.path)")
                } catch {
                    print("❌ Failed to delete project bundle: \(error)")
                    return .failure(.databaseError("Failed to delete project: \(error.localizedDescription)"))
                }
            } else {
                print("⚠️ Project bundle not found at: \(url.path)")
            }
        }

        // Remove from registry
        entries.removeAll { $0.projectId == projectId }
        saveProjectRegistry(entries)
        print("✅ Removed project from registry")

        return .success(())
    }
}
