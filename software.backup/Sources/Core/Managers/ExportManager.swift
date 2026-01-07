//
//  ExportManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 04/01/2026.
//

import Foundation
import AVFoundation
import AppKit
import UniformTypeIdentifiers
import Combine

/// Export format options similar to Sportscode
enum VideoExportFormat: String, CaseIterable {
    case video = "Video Files"
    case xml = "XML Data"
    case csv = "CSV Spreadsheet"
    case json = "JSON Data"
    case pdf = "PDF Report"

    var fileExtension: String {
        switch self {
        case .video: return "mov"
        case .xml: return "xml"
        case .csv: return "csv"
        case .json: return "json"
        case .pdf: return "pdf"
        }
    }

    var icon: String {
        switch self {
        case .video: return "film"
        case .xml: return "doc.text"
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .pdf: return "doc.richtext"
        }
    }
}

/// What to export
enum ExportContent: String, CaseIterable {
    case selectedClips = "Selected Clips"
    case allClips = "All Clips"
    case currentMoments = "Current Moments"
    case allMoments = "All Moments"
    case timeline = "Timeline Data"
    case fullGame = "Full Game"

    var icon: String {
        switch self {
        case .selectedClips: return "checkmark.circle"
        case .allClips: return "film.stack"
        case .currentMoments: return "clock"
        case .allMoments: return "clock.fill"
        case .timeline: return "chart.bar.xaxis"
        case .fullGame: return "sportscourt"
        }
    }
}

/// Video export quality options
enum VideoQuality: String, CaseIterable {
    case high = "High (1080p)"
    case medium = "Medium (720p)"
    case low = "Low (480p)"
    case original = "Original Quality"

    var preset: String {
        switch self {
        case .high: return AVAssetExportPreset1920x1080
        case .medium: return AVAssetExportPreset1280x720
        case .low: return AVAssetExportPreset640x480
        case .original: return AVAssetExportPresetPassthrough
        }
    }
}

/// Video layout for multi-angle export
enum VideoLayout: String, CaseIterable {
    case singleAngle = "Single Angle"
    case sideBySide = "Side by Side (2 angles)"
    case quad = "Quad View (4 angles)"
    case stacked = "Stacked (All angles)"

    var icon: String {
        switch self {
        case .singleAngle: return "rectangle"
        case .sideBySide: return "rectangle.split.2x1"
        case .quad: return "square.grid.2x2"
        case .stacked: return "square.stack"
        }
    }
}

/// Export options configuration
struct ExportOptions {
    var format: VideoExportFormat = .video
    var content: ExportContent = .selectedClips
    var videoQuality: VideoQuality = .high
    var videoLayout: VideoLayout = .singleAngle
    var selectedAngles: [Int] = [0] // Which camera angles to include
    var includeOverlays: Bool = true
    var includeTimecodes: Bool = true
    var includeNotes: Bool = true
    var mergeClips: Bool = false // Merge all clips into one video
    var addTransitions: Bool = false
    var transitionDuration: Double = 0.5
}

/// Export progress tracking
struct ExportProgress {
    var currentItem: Int = 0
    var totalItems: Int = 0
    var currentPhase: String = ""
    var percentage: Double = 0.0
    var isComplete: Bool = false
    var error: Error?

    var description: String {
        if isComplete {
            return error == nil ? "Export Complete" : "Export Failed"
        }
        return "\(currentPhase) (\(currentItem)/\(totalItems))"
    }
}

/// Main export manager
class ExportManager: ObservableObject {
    static let shared = ExportManager()

    @Published var isExporting: Bool = false
    @Published var progress: ExportProgress = ExportProgress()
    @Published var showExportSheet: Bool = false

    private var exportSession: AVAssetExportSession?
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - Main Export Function

    func exportWithOptions(_ options: ExportOptions, clips: [Clip], moments: [Moment], projectId: String) {
        guard !isExporting else { return }

        isExporting = true
        progress = ExportProgress()

        Task {
            do {
                switch options.format {
                case .video:
                    try await exportVideo(options: options, clips: clips, projectId: projectId)
                case .xml:
                    try await exportXML(options: options, clips: clips, moments: moments, projectId: projectId)
                case .csv:
                    try await exportCSV(options: options, clips: clips, moments: moments, projectId: projectId)
                case .json:
                    try await exportJSON(options: options, clips: clips, moments: moments, projectId: projectId)
                case .pdf:
                    try await exportPDF(options: options, clips: clips, moments: moments, projectId: projectId)
                }

                await MainActor.run {
                    self.progress.isComplete = true
                    self.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.progress.error = error
                    self.progress.isComplete = true
                    self.isExporting = false
                }
            }
        }
    }

    // MARK: - Video Export

    private func exportVideo(options: ExportOptions, clips: [Clip], projectId: String) async throws {
        await updateProgress(phase: "Preparing video export", current: 0, total: clips.count)

        // Get video URLs for the project
        guard let videoURLs = await getVideoURLs(for: projectId) else {
            throw ExportError.videoNotFound
        }

        // Show save panel on main thread
        let outputURL = try await MainActor.run { () -> URL? in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.movie]
            // Use safe filename format (no slashes)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            savePanel.nameFieldStringValue = "Export_\(dateFormatter.string(from: Date())).mov"
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            // Don't set directoryURL - let user choose (sandbox requirement)

            let response = savePanel.runModal()
            guard response == .OK, let url = savePanel.url else {
                return nil
            }
            return url
        }

        guard let url = outputURL else {
            throw ExportError.cancelled
        }

        if options.mergeClips {
            try await exportMergedClips(clips: clips, videoURLs: videoURLs, outputURL: url, options: options)
        } else {
            try await exportIndividualClips(clips: clips, videoURLs: videoURLs, outputURL: url, options: options)
        }
    }

    private func exportMergedClips(clips: [Clip], videoURLs: [URL], outputURL: URL, options: ExportOptions) async throws {
        let composition = AVMutableComposition()

        for (index, clip) in clips.enumerated() {
            await updateProgress(phase: "Adding clip \(index + 1)", current: index, total: clips.count)

            guard let videoURL = videoURLs.first else { continue }
            let asset = AVURLAsset(url: videoURL)

            let timeRange = CMTimeRange(start: clip.startTime, end: clip.endTime)

            try await Task {
                try composition.insertTimeRange(timeRange, of: asset, at: composition.duration)
            }.value

            // Add transition if enabled
            if options.addTransitions && index < clips.count - 1 {
                // Add fade transition
            }
        }

        try await export(composition: composition, to: outputURL, quality: options.videoQuality)
    }

    private func exportIndividualClips(clips: [Clip], videoURLs: [URL], outputURL: URL, options: ExportOptions) async throws {
        // Create folder for clips
        let folderURL = outputURL.deletingPathExtension()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        for (index, clip) in clips.enumerated() {
            await updateProgress(phase: "Exporting clip \(index + 1)", current: index, total: clips.count)

            guard let videoURL = videoURLs.first else { continue }
            let asset = AVURLAsset(url: videoURL)

            let timeRange = CMTimeRange(start: clip.startTime, end: clip.endTime)

            let clipFileName = "\(clip.title.sanitizedFilename())_\(clip.formattedStartTime).mov"
            let clipURL = folderURL.appendingPathComponent(clipFileName)

            try await exportTimeRange(timeRange, from: asset, to: clipURL, quality: options.videoQuality)
        }
    }

    private func export(composition: AVComposition, to url: URL, quality: VideoQuality) async throws {
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: quality.preset) else {
            throw ExportError.exportFailed
        }

        exportSession.outputURL = url
        exportSession.outputFileType = .mov

        await exportSession.export()

        if let error = exportSession.error {
            throw error
        }
    }

    private func exportTimeRange(_ timeRange: CMTimeRange, from asset: AVAsset, to url: URL, quality: VideoQuality) async throws {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: quality.preset) else {
            throw ExportError.exportFailed
        }

        exportSession.outputURL = url
        exportSession.outputFileType = .mov
        exportSession.timeRange = timeRange

        await exportSession.export()

        if let error = exportSession.error {
            throw error
        }
    }

    // MARK: - XML Export (Sportscode format)

    private func exportXML(options: ExportOptions, clips: [Clip], moments: [Moment], projectId: String) async throws {
        await updateProgress(phase: "Generating XML", current: 0, total: 1)

        // Show save panel on main thread
        let outputURL = try await MainActor.run { () -> URL? in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.xml]
            // Use safe filename format (no slashes)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            savePanel.nameFieldStringValue = "Export_\(dateFormatter.string(from: Date())).xml"
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            // Don't set directoryURL - let user choose (sandbox requirement)

            let response = savePanel.runModal()
            guard response == .OK, let url = savePanel.url else {
                return nil
            }
            return url
        }

        guard let outputURL else {
            throw ExportError.cancelled
        }

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <maxmiize_export version="1.0">
            <project id="\(projectId)">
                <clips count="\(clips.count)">

        """

        for clip in clips {
            xml += """
                    <clip id="\(clip.id)">
                        <title>\(clip.title.xmlEscaped())</title>
                        <start_ms>\(clip.startTimeMs)</start_ms>
                        <end_ms>\(clip.endTimeMs)</end_ms>
                        <duration>\(clip.formattedDuration)</duration>
                        <notes>\(clip.notes.xmlEscaped())</notes>
                        <tags>

            """

            for tag in clip.tags {
                xml += "                    <tag>\(tag.xmlEscaped())</tag>\n"
            }

            xml += """
                        </tags>
                    </clip>

            """
        }

        xml += """
                </clips>
                <moments count="\(moments.count)">

        """

        for moment in moments {
            xml += """
                    <moment id="\(moment.id)">
                        <category>\(moment.momentCategory.xmlEscaped())</category>
                        <start_ms>\(moment.startTimestampMs)</start_ms>
                        <end_ms>\(moment.endTimestampMs ?? 0)</end_ms>
                        <notes>\(moment.notes?.xmlEscaped() ?? "")</notes>
                    </moment>

            """
        }

        xml += """
                </moments>
            </project>
        </maxmiize_export>
        """

        try xml.write(to: outputURL, atomically: true, encoding: .utf8)
        await updateProgress(phase: "XML export complete", current: 1, total: 1)
    }

    // MARK: - CSV Export

    private func exportCSV(options: ExportOptions, clips: [Clip], moments: [Moment], projectId: String) async throws {
        await updateProgress(phase: "Generating CSV", current: 0, total: 1)

        // Show save panel on main thread
        let outputURL = try await MainActor.run { () -> URL? in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.commaSeparatedText]
            // Use safe filename format (no slashes)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            savePanel.nameFieldStringValue = "Export_\(dateFormatter.string(from: Date())).csv"
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            // Don't set directoryURL - let user choose (sandbox requirement)

            let response = savePanel.runModal()
            guard response == .OK, let url = savePanel.url else {
                return nil
            }
            return url
        }

        guard let outputURL else {
            throw ExportError.cancelled
        }

        var csv = "Type,ID,Title/Category,Start (ms),End (ms),Duration,Tags/Notes\n"

        for clip in clips {
            let tags = clip.tags.joined(separator: "; ")
            csv += "Clip,\(clip.id),\"\(clip.title.csvEscaped())\",\(clip.startTimeMs),\(clip.endTimeMs),\(clip.formattedDuration),\"\(tags)\"\n"
        }

        for moment in moments {
            let notes = moment.notes ?? ""
            csv += "Moment,\(moment.id),\"\(moment.momentCategory.csvEscaped())\",\(moment.startTimestampMs),\(moment.endTimestampMs ?? 0),,\"\(notes.csvEscaped())\"\n"
        }

        try csv.write(to: outputURL, atomically: true, encoding: .utf8)
        await updateProgress(phase: "CSV export complete", current: 1, total: 1)
    }

    // MARK: - JSON Export

    private func exportJSON(options: ExportOptions, clips: [Clip], moments: [Moment], projectId: String) async throws {
        await updateProgress(phase: "Generating JSON", current: 0, total: 1)

        // Show save panel on main thread
        let outputURL = try await MainActor.run { () -> URL? in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.json]
            // Use safe filename format (no slashes)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            savePanel.nameFieldStringValue = "Export_\(dateFormatter.string(from: Date())).json"
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            // Don't set directoryURL - let user choose (sandbox requirement)

            let response = savePanel.runModal()
            guard response == .OK, let url = savePanel.url else {
                return nil
            }
            return url
        }

        guard let outputURL else {
            throw ExportError.cancelled
        }

        let exportData: [String: Any] = [
            "project_id": projectId,
            "export_date": ISO8601DateFormatter().string(from: Date()),
            "clips": clips.map { clip in
                [
                    "id": clip.id,
                    "title": clip.title,
                    "start_ms": clip.startTimeMs,
                    "end_ms": clip.endTimeMs,
                    "duration": clip.formattedDuration,
                    "tags": clip.tags,
                    "notes": clip.notes
                ]
            },
            "moments": moments.map { moment in
                [
                    "id": moment.id,
                    "category": moment.momentCategory,
                    "start_ms": moment.startTimestampMs,
                    "end_ms": moment.endTimestampMs ?? 0,
                    "notes": moment.notes ?? ""
                ]
            }
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: outputURL)

        await updateProgress(phase: "JSON export complete", current: 1, total: 1)
    }

    // MARK: - PDF Export

    private func exportPDF(options: ExportOptions, clips: [Clip], moments: [Moment], projectId: String) async throws {
        await updateProgress(phase: "Generating PDF report", current: 0, total: 1)

        // Show save panel on main thread
        let outputURL = try await MainActor.run { () -> URL? in
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.pdf]
            // Use safe filename format (no slashes)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            savePanel.nameFieldStringValue = "Export_\(dateFormatter.string(from: Date())).pdf"
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            // Don't set directoryURL - let user choose (sandbox requirement)

            let response = savePanel.runModal()
            guard response == .OK, let url = savePanel.url else {
                return nil
            }
            return url
        }

        guard let outputURL else {
            throw ExportError.cancelled
        }

        // Create PDF context
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw ExportError.exportFailed
        }

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.exportFailed
        }

        // Start PDF
        context.beginPDFPage(nil)

        // Draw header
        let title = "Maxmiize Analysis Report"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: 50, y: 720))

        // Draw date
        let dateString = "Generated: \(Date().formatted(date: .long, time: .shortened))"
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.gray
        ]
        let dateAttr = NSAttributedString(string: dateString, attributes: dateAttributes)
        dateAttr.draw(at: CGPoint(x: 50, y: 695))

        // Draw clips section
        var yPosition: CGFloat = 650
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ]

        NSAttributedString(string: "Clips (\(clips.count))", attributes: sectionAttributes).draw(at: CGPoint(x: 50, y: yPosition))
        yPosition -= 25

        let itemAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black
        ]

        for clip in clips.prefix(20) { // Limit to first 20
            let clipText = "\(clip.title) - \(clip.formattedStartTime) (\(clip.formattedDuration))"
            NSAttributedString(string: clipText, attributes: itemAttributes).draw(at: CGPoint(x: 70, y: yPosition))
            yPosition -= 20

            if yPosition < 50 { break }
        }

        context.endPDFPage()
        context.closePDF()

        try pdfData.write(to: outputURL)
        await updateProgress(phase: "PDF export complete", current: 1, total: 1)
    }

    // MARK: - Helper Functions

    @MainActor
    private func updateProgress(phase: String, current: Int, total: Int) {
        progress.currentPhase = phase
        progress.currentItem = current
        progress.totalItems = total
        progress.percentage = total > 0 ? Double(current) / Double(total) : 0
    }

    @MainActor
    private func getVideoURLs(for projectId: String) -> [URL]? {
        // Get the current project bundle
        guard let bundle = ProjectManager.shared.currentProject else {
            print("❌ ExportManager: No current project")
            return nil
        }

        // Get videos from database
        let videos = DatabaseManager.shared.getVideos(projectId: projectId)

        guard !videos.isEmpty else {
            print("❌ ExportManager: No videos found in database")
            return nil
        }

        // Convert video file paths to URLs
        let videoURLs = videos.map { video -> URL in
            // Remove "videos/" prefix if it exists since bundle.videosPath already points to videos folder
            let fileName = video.filePath.replacingOccurrences(of: "videos/", with: "")
            return bundle.videosPath.appendingPathComponent(fileName)
        }

        // Verify at least one video file exists
        let existingVideos = videoURLs.filter { FileManager.default.fileExists(atPath: $0.path) }

        if existingVideos.isEmpty {
            print("❌ ExportManager: No video files exist at paths")
            for url in videoURLs {
                print("   - Missing: \(url.path)")
            }
            return nil
        }

        print("✅ ExportManager: Found \(existingVideos.count) video file(s)")
        return existingVideos
    }

    func cancel() {
        exportSession?.cancelExport()
        isExporting = false
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case cancelled
    case videoNotFound
    case exportFailed
    case noClipsSelected

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Export cancelled"
        case .videoNotFound: return "Video files not found"
        case .exportFailed: return "Export failed"
        case .noClipsSelected: return "No clips selected for export"
        }
    }
}

// MARK: - String Extensions

extension String {
    func xmlEscaped() -> String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    func csvEscaped() -> String {
        return self.replacingOccurrences(of: "\"", with: "\"\"")
    }

    func sanitizedFilename() -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

// MARK: - NSSavePanel Extension

extension NSSavePanel {
    @MainActor
    func beginSheet() async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            self.begin { response in
                continuation.resume(returning: response)
            }
        }
    }
}
