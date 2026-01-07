//
//  PlaylistManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 04/01/2026.
//

import Foundation
import Combine
import SwiftUI

/// Manages playlist creation, filtering, and curation
class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()

    @Published var playlists: [Playlist] = []
    @Published var currentPlaylist: Playlist?
    @Published var enrichedClips: [PlaylistClipWithMetadata] = []
    @Published var presentationMode: PlaylistPresentationMode = PlaylistPresentationMode()

    private init() {}

    // MARK: - Playlist CRUD

    func loadPlaylists(projectId: String) {
        playlists = DatabaseManager.shared.getPlaylists(projectId: projectId)
    }

    func createPlaylist(
        projectId: String,
        name: String,
        purpose: PlaylistPurpose,
        description: String? = nil,
        filterCriteria: PlaylistFilters? = nil
    ) -> Playlist? {
        let result = DatabaseManager.shared.createPlaylist(
            projectId: projectId,
            name: name,
            purpose: purpose,
            description: description,
            filterCriteria: filterCriteria,
            clipIds: []
        )

        switch result {
        case .success(let playlist):
            playlists.append(playlist)
            currentPlaylist = playlist
            return playlist
        case .failure(let error):
            print("❌ PlaylistManager: Failed to create playlist: \(error.localizedDescription)")
            return nil
        }
    }

    func updatePlaylist(_ playlist: Playlist) {
        let result = DatabaseManager.shared.updatePlaylist(playlist)

        switch result {
        case .success:
            if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[index] = playlist
            }
            if currentPlaylist?.id == playlist.id {
                currentPlaylist = playlist
            }
        case .failure(let error):
            print("❌ PlaylistManager: Failed to update playlist: \(error.localizedDescription)")
        }
    }

    func deletePlaylist(playlistId: String) {
        let result = DatabaseManager.shared.deletePlaylist(playlistId: playlistId)

        switch result {
        case .success:
            playlists.removeAll { $0.id == playlistId }
            if currentPlaylist?.id == playlistId {
                currentPlaylist = nil
                enrichedClips = []
            }
        case .failure(let error):
            print("❌ PlaylistManager: Failed to delete playlist: \(error.localizedDescription)")
        }
    }

    // MARK: - Filter-First Generation

    /// Generate clips based on filter criteria
    func generateClipsFromFilters(
        projectId: String,
        filters: PlaylistFilters
    ) -> [PlaylistClipWithMetadata] {
        print("🎬 PlaylistManager: Generating clips with filters: \(filters.description)")

        // Get all moments for the project
        let moments = DatabaseManager.shared.getMomentsForProject(projectId: projectId)

        var matchingClips: [PlaylistClipWithMetadata] = []

        // Filter moments based on criteria
        let filteredMoments = moments.filter { moment in
            // Filter by players (if specified)
            if let playerIds = filters.playerIds, !playerIds.isEmpty {
                guard DatabaseManager.shared.momentHasPlayers(momentId: moment.id, playerIds: playerIds) else {
                    return false
                }
            }

            // Filter by moment category (Offense/Defense)
            if let categories = filters.momentCategories, !categories.isEmpty {
                guard categories.contains(moment.momentCategory) else { return false }
            }

            // Filter by quarter
            if let quarters = filters.quarters, !quarters.isEmpty {
                let quarter = DatabaseManager.shared.estimateQuarter(timestampMs: moment.startTimestampMs)
                guard quarters.contains(quarter) else { return false }
            }

            // Check layers for event type and outcome filters
            if let layerTypes = filters.layerTypes, !layerTypes.isEmpty {
                let hasMatchingLayer = moment.layers.contains { layer in
                    layerTypes.contains(layer.layerType)
                }
                guard hasMatchingLayer else { return false }
            }

            if let outcomes = filters.outcomes, !outcomes.isEmpty {
                let hasMatchingOutcome = moment.layers.contains { layer in
                    outcomes.contains(layer.layerType)
                }
                guard hasMatchingOutcome else { return false }
            }

            return true
        }

        print("   ✅ Found \(filteredMoments.count) matching moments")

        // Convert matching moments to clips
        for moment in filteredMoments {
            guard let endTime = moment.endTimestampMs else { continue }

            // Check duration filters
            let duration = TimeInterval(endTime - moment.startTimestampMs) / 1000.0
            if let minDuration = filters.minDuration, duration < minDuration { continue }
            if let maxDuration = filters.maxDuration, duration > maxDuration { continue }

            // Create clip from moment
            let clipTitle = generateClipTitle(moment: moment)

            let clip = Clip(
                gameId: moment.gameId,
                startTimeMs: moment.startTimestampMs,
                endTimeMs: endTime,
                title: clipTitle,
                notes: moment.notes ?? "",
                tags: [moment.momentCategory]
            )

            // Extract metadata
            let outcome = moment.layers.first { ["Made", "Missed", "Turnover"].contains($0.layerType) }?.layerType
            let quarter = DatabaseManager.shared.estimateQuarter(timestampMs: moment.startTimestampMs)

            // Get players from database
            let players = DatabaseManager.shared.getPlayersForMoment(momentId: moment.id)

            let enrichedClip = PlaylistClipWithMetadata(
                clip: clip,
                moment: moment,
                layers: moment.layers,
                players: players,
                outcome: outcome,
                quarter: quarter,
                setName: nil
            )

            matchingClips.append(enrichedClip)
        }

        print("   🎯 Generated \(matchingClips.count) clips")
        return matchingClips
    }

    /// Generate a descriptive title for a clip based on moment and layers
    private func generateClipTitle(moment: Moment) -> String {
        let category = moment.momentCategory
        let layers = moment.layers

        // Get shot type
        let shotType = layers.first { ["1-Point", "2-Point", "3-Point"].contains($0.layerType) }?.layerType ?? "Play"

        // Get outcome
        let outcome = layers.first { ["Made", "Missed"].contains($0.layerType) }?.layerType ?? ""

        // Get special events
        let hasAssist = layers.contains { $0.layerType == "Assist" }
        let isTransition = layers.contains { $0.layerType == "Transition" }

        var titleParts: [String] = []

        if isTransition {
            titleParts.append("Transition")
        }

        titleParts.append(category)

        if !outcome.isEmpty {
            titleParts.append("\(shotType) \(outcome)")
        } else if shotType != "Play" {
            titleParts.append(shotType)
        }

        if hasAssist && outcome == "Made" {
            titleParts.append("(Assist)")
        }

        return titleParts.joined(separator: " - ")
    }

    // MARK: - Manual Curation

    /// Set the clips for the current playlist
    func setPlaylistClips(_ clips: [PlaylistClipWithMetadata]) {
        guard var playlist = currentPlaylist else { return }

        playlist.clipIds = clips.map { $0.clip.id }
        updatePlaylist(playlist)
        enrichedClips = clips
    }

    /// Reorder clips in the playlist
    func reorderClips(from source: IndexSet, to destination: Int) {
        // Convert IndexSet to array of indices
        let sourceIndices = Array(source).sorted(by: >)

        // Safety check: ensure we have items to move
        guard let firstSourceIndex = sourceIndices.first else { return }

        // Extract clips to move
        var clipsToMove: [PlaylistClipWithMetadata] = []
        for index in sourceIndices {
            clipsToMove.insert(enrichedClips[index], at: 0)
        }

        // Remove clips from original positions (in reverse order to maintain indices)
        for index in sourceIndices {
            enrichedClips.remove(at: index)
        }

        // Calculate adjusted destination
        let adjustedDestination = destination > firstSourceIndex ? destination - sourceIndices.count : destination

        // Insert at new position
        enrichedClips.insert(contentsOf: clipsToMove, at: adjustedDestination)

        guard var playlist = currentPlaylist else { return }
        playlist.clipIds = enrichedClips.map { $0.clip.id }
        updatePlaylist(playlist)
    }

    /// Remove clips from the playlist
    func removeClips(at offsets: IndexSet) {
        // Convert IndexSet to array and sort in reverse to maintain indices during removal
        let sortedOffsets = offsets.sorted(by: >)
        for offset in sortedOffsets {
            if offset < enrichedClips.count {
                enrichedClips.remove(at: offset)
            }
        }

        guard var playlist = currentPlaylist else { return }
        playlist.clipIds = enrichedClips.map { $0.clip.id }
        updatePlaylist(playlist)
    }

    /// Add a clip to the current playlist
    func addClip(_ clip: PlaylistClipWithMetadata) {
        enrichedClips.append(clip)

        guard var playlist = currentPlaylist else { return }
        playlist.clipIds = enrichedClips.map { $0.clip.id }
        updatePlaylist(playlist)
    }

    // MARK: - Presentation Mode

    func enterPresentationMode() {
        presentationMode.isEnabled = true
        presentationMode.currentClipIndex = 0
        presentationMode.isPlaying = false
    }

    func exitPresentationMode() {
        presentationMode.isEnabled = false
        presentationMode.isPlaying = false
    }

    func playNextClip() {
        let nextIndex = presentationMode.currentClipIndex + 1
        if nextIndex < enrichedClips.count {
            presentationMode.currentClipIndex = nextIndex
        } else if presentationMode.autoAdvance {
            // Loop back to start
            presentationMode.currentClipIndex = 0
        }
    }

    func playPreviousClip() {
        let prevIndex = presentationMode.currentClipIndex - 1
        if prevIndex >= 0 {
            presentationMode.currentClipIndex = prevIndex
        }
    }

    func setCurrentClipIndex(_ index: Int) {
        if index >= 0 && index < enrichedClips.count {
            presentationMode.currentClipIndex = index
        }
    }

    // MARK: - Load Enriched Clips

    func loadEnrichedClips(for playlist: Playlist) {
        currentPlaylist = playlist
        enrichedClips = DatabaseManager.shared.getClipsWithMetadata(
            clipIds: playlist.clipIds
        )
    }
}
