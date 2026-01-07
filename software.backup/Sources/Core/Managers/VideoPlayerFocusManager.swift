//
//  VideoPlayerFocusManager.swift
//  maxmiize-v1
//
//  Manages keyboard focus between multiple video players
//

import Foundation
import Combine

enum VideoPlayerType {
    case mainPlayer      // PlaybackView, MaxView, etc.
    case clipPopup       // ClipPlayerPopup
    case momentsPlayer   // MomentsView
}

/// Singleton that tracks which video player should respond to keyboard events
class VideoPlayerFocusManager: ObservableObject {
    static let shared = VideoPlayerFocusManager()

    @Published private(set) var focusedPlayer: VideoPlayerType = .mainPlayer

    private init() {}

    /// Set which player has keyboard focus
    func setFocus(_ player: VideoPlayerType) {
        focusedPlayer = player
        print("🎯 VideoPlayerFocus: \(player) now has keyboard focus")
    }

    /// Check if a specific player should handle keyboard events
    func shouldHandle(_ player: VideoPlayerType) -> Bool {
        return focusedPlayer == player
    }
}
