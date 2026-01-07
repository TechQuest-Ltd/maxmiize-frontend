//
//  ToastNotification.swift
//  maxmiize-v1
//
//  Created by TechQuest on 15/12/2025.
//

import SwiftUI
import Combine

struct ToastNotification: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    let icon: String
    let backgroundColor: String

    init(message: String, icon: String = "checkmark.circle.fill", backgroundColor: String = "2979ff") {
        self.message = message
        self.icon = icon
        self.backgroundColor = backgroundColor
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.white)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: backgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Toast Manager
@MainActor
class ToastManager: ObservableObject {
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    @Published var toastIcon: String = "checkmark.circle.fill"
    @Published var toastBackgroundColor: String = "2979ff"

    func show(message: String, icon: String = "checkmark.circle.fill", backgroundColor: String = "2979ff", duration: Double = 2.5) {
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastIcon = icon
            self.toastBackgroundColor = backgroundColor

            withAnimation(.easeInOut(duration: 0.3)) {
                self.showToast = true
            }

            // Auto-dismiss after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.showToast = false
                }
            }
        }
    }

    func showSuccess(_ message: String) {
        show(message: message, icon: "checkmark.circle.fill", backgroundColor: "2979ff")
    }

    func showError(_ message: String) {
        show(message: message, icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
    }

    func showWarning(_ message: String) {
        show(message: message, icon: "exclamationmark.triangle.fill", backgroundColor: "f5c14e")
    }

    func showInfo(_ message: String) {
        show(message: message, icon: "info.circle.fill", backgroundColor: "64d2ff")
    }
}

// MARK: - Toast Container ViewModifier
struct ToastContainer: ViewModifier {
    @ObservedObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        ZStack {
            content

            if toastManager.showToast {
                VStack {
                    Spacer()

                    ToastNotification(
                        message: toastManager.toastMessage,
                        icon: toastManager.toastIcon,
                        backgroundColor: toastManager.toastBackgroundColor
                    )
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func toast(manager: ToastManager) -> some View {
        modifier(ToastContainer(toastManager: manager))
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastNotification(message: "Shot - Three-Point marked at 00:18:47")
        ToastNotification(message: "Error: No video loaded", icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
        ToastNotification(message: "Warning: Low disk space", icon: "exclamationmark.triangle.fill", backgroundColor: "f5c14e")
        ToastNotification(message: "Info: Auto-save enabled", icon: "info.circle.fill", backgroundColor: "64d2ff")
    }
    .padding()
    .background(Color.black)
}
