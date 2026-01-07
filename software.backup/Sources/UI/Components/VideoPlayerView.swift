//
//  VideoPlayerView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import SwiftUI
import AVFoundation
import AppKit

/// A reusable video player view that wraps AVPlayerLayer
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    init(player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.player = player
        self.videoGravity = videoGravity
    }

    func makeNSView(context: Context) -> PlayerNSView {
        let view = PlayerNSView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        return view
    }

    func updateNSView(_ nsView: PlayerNSView, context: Context) {
        nsView.playerLayer.player = player
        nsView.playerLayer.videoGravity = videoGravity
    }

    // Custom NSView that hosts AVPlayerLayer
    class PlayerNSView: NSView {
        let playerLayer: AVPlayerLayer

        override init(frame frameRect: NSRect) {
            playerLayer = AVPlayerLayer()
            playerLayer.backgroundColor = NSColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1.0).cgColor // #202020
            super.init(frame: frameRect)
            layer = playerLayer
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            playerLayer = AVPlayerLayer()
            playerLayer.backgroundColor = NSColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1.0).cgColor // #202020
            super.init(coder: coder)
            layer = playerLayer
            wantsLayer = true
        }

        override func layout() {
            super.layout()
            playerLayer.frame = bounds
        }
    }
}

// Helper extension for NSColor hex initialization
extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
