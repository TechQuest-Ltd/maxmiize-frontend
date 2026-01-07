//
//  CustomToggleStyle.swift
//  maxmiize-v1
//
//  Custom toggle style for better visibility in light and dark modes
//

import SwiftUI

struct CustomToggleStyle: ToggleStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var theme: ThemeColors {
        themeManager.colors
    }
    
    // Off state color - darker for better visibility in light mode
    private var offStateColor: Color {
        themeManager.isLightMode ? Color(hex: "bdbdbd") : theme.secondaryBorder
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                // Track background - use darker color when off for better visibility
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? theme.accent : offStateColor)
                    .frame(width: 50, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(configuration.isOn ? Color.clear : theme.primaryBorder.opacity(0.5), lineWidth: 1)
                    )
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .padding(2)
                    .shadow(color: Color.black.opacity(themeManager.isLightMode ? 0.15 : 0.3), radius: 2, x: 0, y: 1)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

// MARK: - Switch Toggle Style Extension

extension ToggleStyle where Self == CustomToggleStyle {
    static var custom: CustomToggleStyle {
        CustomToggleStyle()
    }
}

