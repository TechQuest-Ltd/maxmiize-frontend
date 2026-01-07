//
//  WindowAccessor.swift
//  maxmiize-v1
//
//  Window configuration helpers
//

import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Call immediately
        self.callback(view.window)
        // Also call async to ensure it's applied after window is fully set up
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        self.callback(nsView.window)
        DispatchQueue.main.async {
            self.callback(nsView.window)
        }
    }
}

extension View {
    /// Configures the window to hide the titlebar separator and match background
    func hideTitlebarSeparator(backgroundColor: Color = Color(hex: "0D0D0D")) -> some View {
        self.background(
            WindowAccessor { window in
                guard let window = window else { return }
                
                // Hide the titlebar separator completely
                window.titlebarSeparatorStyle = .none
                
                // Make titlebar transparent
                window.titlebarAppearsTransparent = true
                
                // Set background color to match
                if let nsColor = NSColor(backgroundColor) {
                    window.backgroundColor = nsColor
                }
                
                // Additional: ensure no shadow line
                window.hasShadow = true
                window.isOpaque = false
            }
        )
    }
}

extension NSColor {
    convenience init?(_ color: Color) {
        // Convert SwiftUI Color to NSColor
        let components = Mirror(reflecting: color).children
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1

        for child in components {
            if let provider = child.value as? any CustomStringConvertible {
                let description = provider.description
                if description.contains("red:") {
                    // Parse the color components from description
                    // This is a fallback - try direct conversion first
                }
            }
        }

        // Try to get NSColor from the Color
        // This works by creating a temporary view
        if #available(macOS 14.0, *) {
            if let resolved = try? color.resolve(in: EnvironmentValues()) {
                self.init(
                    red: Double(resolved.red),
                    green: Double(resolved.green),
                    blue: Double(resolved.blue),
                    alpha: Double(resolved.opacity)
                )
                return
            }
        }

        // Fallback: use a default dark color
        self.init(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0) // #0D0D0D
    }
}
