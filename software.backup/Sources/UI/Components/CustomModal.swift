//
//  CustomModal.swift
//  maxmiize-v1
//
//  Created by TechQuest on 12/12/2025.
//

import SwiftUI

enum ModalType {
    case success
    case error
    case warning
    case info

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var iconColor: String {
        switch self {
        case .success: return "27c46d"
        case .error: return "ff3b30"
        case .warning: return "ffcc00"
        case .info: return "2979ff"
        }
    }
}

struct ModalButton {
    let title: String
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case destructive

        var backgroundColor: String {
            switch self {
            case .primary: return "2979ff"
            case .secondary: return "111111"
            case .destructive: return "ff3b30"
            }
        }

        var borderColor: String {
            switch self {
            case .primary: return "2979ff"
            case .secondary: return "2a2a2a"
            case .destructive: return "ff3b30"
            }
        }
    }
}

struct CustomModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    let type: ModalType
    let title: String
    let message: String
    let buttons: [ModalButton]

    init(
        isPresented: Binding<Bool>,
        type: ModalType,
        title: String,
        message: String,
        buttons: [ModalButton] = []
    ) {
        self._isPresented = isPresented
        self.type = type
        self.title = title
        self.message = message
        self.buttons = buttons.isEmpty ? [
            ModalButton(title: "OK", style: .primary) {
                isPresented.wrappedValue = false
            }
        ] : buttons
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            if isPresented {
                // Backdrop
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Prevent closing on backdrop tap
                    }

                // Modal content
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: type.iconName)
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: type.iconColor))

                    // Title
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.center)

                    // Message
                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // Buttons
                    HStack(spacing: 12) {
                        ForEach(buttons.indices, id: \.self) { index in
                            Button(action: {
                                buttons[index].action()
                            }) {
                                Text(buttons[index].title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: buttons[index].style.backgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: buttons[index].style.borderColor), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(32)
                .frame(width: 400)
                .background(theme.surfaceBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.secondaryBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
}

// MARK: - Preview
struct CustomModal_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CustomModal(
                isPresented: .constant(true),
                type: .error,
                title: "Project Created Successfully",
                message: "Your analysis project has been created and saved to the database.",
                buttons: [
                    ModalButton(title: "Continue", style: .primary) {
                        print("Continue tapped")
                    }
                ]
            )
        }
        .frame(width: 1440, height: 910)
        .background(Color(hex: "1a1b1d"))
    }
}
