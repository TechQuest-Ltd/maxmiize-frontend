//
//  PlaybackControls.swift
//  maxmiize-v1
//
//  Created by TechQuest on 23/12/2025.
//

import SwiftUI
import AVFoundation

struct PlaybackControls: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var playerManager: SyncedVideoPlayerManager
    var showTimeline: Bool = true
    var inPoint: CMTime? = nil
    var outPoint: CMTime? = nil

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 8) {
            // Timeline scrubber (centered) - optional
            if showTimeline {
                HStack(spacing: 12) {
                    Text(formatTime(playerManager.currentTime))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            Rectangle()
                                .fill(theme.primaryBorder)
                                .frame(height: 4)
                                .cornerRadius(2)

                            // Progress track
                            let progress = CMTimeGetSeconds(playerManager.currentTime) / max(CMTimeGetSeconds(playerManager.duration), 1.0)
                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 4)
                                .cornerRadius(2)

                            // IN marker
                            if let inPoint = inPoint {
                                let inProgress = CMTimeGetSeconds(inPoint) / max(CMTimeGetSeconds(playerManager.duration), 1.0)
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(theme.accent)
                                        .frame(width: 2, height: 12)
                                    Text("IN")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(theme.accent)
                                }
                                .offset(x: geometry.size.width * CGFloat(inProgress) - 1, y: -8)
                            }

                            // OUT marker
                            if let outPoint = outPoint {
                                let outProgress = CMTimeGetSeconds(outPoint) / max(CMTimeGetSeconds(playerManager.duration), 1.0)
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(theme.error)
                                        .frame(width: 2, height: 12)
                                    Text("OUT")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(theme.error)
                                }
                                .offset(x: geometry.size.width * CGFloat(outProgress) - 1, y: -8)
                            }

                            // Range highlight between IN and OUT
                            if let inPoint = inPoint, let outPoint = outPoint {
                                let inProgress = CMTimeGetSeconds(inPoint) / max(CMTimeGetSeconds(playerManager.duration), 1.0)
                                let outProgress = CMTimeGetSeconds(outPoint) / max(CMTimeGetSeconds(playerManager.duration), 1.0)
                                let inPos = geometry.size.width * CGFloat(inProgress)
                                let outPos = geometry.size.width * CGFloat(outProgress)
                                Rectangle()
                                    .fill(theme.accent.opacity(0.2))
                                    .frame(width: abs(outPos - inPos), height: 4)
                                    .offset(x: min(inPos, outPos))
                            }

                            // Scrubber thumb
                            Circle()
                                .fill(theme.primaryText)
                                .frame(width: 12, height: 12)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .offset(x: geometry.size.width * CGFloat(progress) - 6)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    let targetTime = CMTimeGetSeconds(playerManager.duration) * progress
                                    let newTime = CMTime(seconds: targetTime, preferredTimescale: 600)
                                    playerManager.seek(to: newTime)
                                }
                        )
                    }
                    .frame(height: inPoint != nil || outPoint != nil ? 32 : 20)

                    Text(formatTime(playerManager.duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                        .frame(width: 80, alignment: .leading)
                }
            }

            // Control buttons
            HStack(spacing: 16) {
                // Play/Pause button
                Button(action: {
                    playerManager.togglePlayPause()
                }) {
                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.white)
                        .frame(width: 32, height: 32)
                        .background(theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                // Skip backward
                Button(action: {
                    let newTime = CMTimeSubtract(playerManager.currentTime, CMTime(seconds: 5, preferredTimescale: 600))
                    playerManager.seek(to: max(newTime, .zero))
                }) {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText)
                        .frame(width: 32, height: 32)
                        .background(theme.primaryBorder)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                // Skip forward
                Button(action: {
                    let newTime = CMTimeAdd(playerManager.currentTime, CMTime(seconds: 5, preferredTimescale: 600))
                    playerManager.seek(to: newTime)
                }) {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText)
                        .frame(width: 32, height: 32)
                        .background(theme.primaryBorder)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                // Speed control
                Menu {
                    Button("0.25x") { playerManager.setRate(0.25) }
                    Button("0.5x") { playerManager.setRate(0.5) }
                    Button("1x") { playerManager.setRate(1.0) }
                    Button("1.5x") { playerManager.setRate(1.5) }
                    Button("2x") { playerManager.setRate(2.0) }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(String(format: "%.2f", playerManager.playbackRate))x")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.primaryText)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
    }

    private func formatTime(_ time: CMTime) -> String {
        let totalSeconds = Int(CMTimeGetSeconds(time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((CMTimeGetSeconds(time).truncatingRemainder(dividingBy: 1)) * 100)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d:%02d", minutes, seconds, milliseconds)
        }
    }
}
