//
//  FastTooltip.swift
//  maxmiize-v1
//
//  Custom tooltip with instant/fast display
//

import SwiftUI

struct FastTooltip: ViewModifier {
    let text: String
    let delay: Double // in seconds

    @State private var isHovering = false
    @State private var showTooltip = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if showTooltip {
                        Text(text)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.9))
                            .cornerRadius(4)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .position(
                                x: geometry.size.width / 2,
                                y: geometry.size.height + 12
                            )
                            .transition(.opacity)
                            .zIndex(1000)
                    }
                }
            )
            .onHover { hovering in
                isHovering = hovering

                if hovering {
                    // Show tooltip after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        if isHovering {
                            withAnimation(.easeIn(duration: 0.1)) {
                                showTooltip = true
                            }
                        }
                    }
                } else {
                    // Hide immediately
                    withAnimation(.easeOut(duration: 0.1)) {
                        showTooltip = false
                    }
                }
            }
    }
}

extension View {
    /// Shows a fast tooltip with customizable delay
    /// - Parameters:
    ///   - text: The tooltip text to display
    ///   - delay: Delay in seconds before showing (default: 0.2 seconds for instant feel)
    func fastTooltip(_ text: String, delay: Double = 0.2) -> some View {
        self.modifier(FastTooltip(text: text, delay: delay))
    }
}
