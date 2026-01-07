//
//  ModalExamples.swift
//  maxmiize-v1
//
//  Example usage patterns for CustomModal component
//

import SwiftUI

/*
 EXAMPLE 1: Success Modal
 Use this when an operation completes successfully
 */
func showSuccessModal() {
    // In your view, define state:
    // @State private var showModal = false
    // @State private var modalType: ModalType = .success
    // @State private var modalTitle = ""
    // @State private var modalMessage = ""
    // @State private var modalButtons: [ModalButton] = []

    // Then configure and show:
    /*
    modalType = .success
    modalTitle = "Operation Successful"
    modalMessage = "Your changes have been saved successfully."
    modalButtons = [
        ModalButton(title: "OK", style: .primary) {
            showModal = false
        }
    ]
    showModal = true
    */
}

/*
 EXAMPLE 2: Error Modal
 Use this when an operation fails
 */
func showErrorModal() {
    /*
    modalType = .error
    modalTitle = "Error Occurred"
    modalMessage = "Failed to save your changes. Please try again."
    modalButtons = [
        ModalButton(title: "Retry", style: .primary) {
            // Retry logic here
            showModal = false
        },
        ModalButton(title: "Cancel", style: .secondary) {
            showModal = false
        }
    ]
    showModal = true
    */
}

/*
 EXAMPLE 3: Warning Modal with Confirmation
 Use this when user needs to confirm a potentially dangerous action
 */
func showWarningModal() {
    /*
    modalType = .warning
    modalTitle = "Are you sure?"
    modalMessage = "This action cannot be undone. All unsaved changes will be lost."
    modalButtons = [
        ModalButton(title: "Cancel", style: .secondary) {
            showModal = false
        },
        ModalButton(title: "Continue", style: .destructive) {
            // Perform dangerous action
            showModal = false
        }
    ]
    showModal = true
    */
}

/*
 EXAMPLE 4: Info Modal
 Use this to display informational messages
 */
func showInfoModal() {
    /*
    modalType = .info
    modalTitle = "Did you know?"
    modalMessage = "You can use keyboard shortcuts to speed up your workflow. Press ⌘K to see all shortcuts."
    modalButtons = [
        ModalButton(title: "Show Shortcuts", style: .primary) {
            showModal = false
            // Navigate to shortcuts
        },
        ModalButton(title: "Got it", style: .secondary) {
            showModal = false
        }
    ]
    showModal = true
    */
}

/*
 EXAMPLE 5: Delete Confirmation
 Common pattern for delete operations
 */
func showDeleteConfirmation() {
    /*
    modalType = .warning
    modalTitle = "Delete Analysis?"
    modalMessage = "This will permanently delete '\(projectName)' and all associated data."
    modalButtons = [
        ModalButton(title: "Cancel", style: .secondary) {
            showModal = false
        },
        ModalButton(title: "Delete", style: .destructive) {
            // Delete logic
            DatabaseManager.shared.deleteProject(id: projectId)
            showModal = false
        }
    ]
    showModal = true
    */
}

/*
 COMPLETE EXAMPLE VIEW:
 Here's how to integrate the modal into a SwiftUI view
 */

struct ExampleView: View {
    @State private var showModal = false
    @State private var modalType: ModalType = .success
    @State private var modalTitle = ""
    @State private var modalMessage = ""
    @State private var modalButtons: [ModalButton] = []

    var body: some View {
        ZStack {
            // Your main content
            VStack {
                Button("Show Success") {
                    modalType = .success
                    modalTitle = "Success!"
                    modalMessage = "Operation completed successfully."
                    modalButtons = [
                        ModalButton(title: "OK", style: .primary) {
                            showModal = false
                        }
                    ]
                    showModal = true
                }

                Button("Show Error") {
                    modalType = .error
                    modalTitle = "Error"
                    modalMessage = "Something went wrong."
                    modalButtons = [
                        ModalButton(title: "OK", style: .primary) {
                            showModal = false
                        }
                    ]
                    showModal = true
                }
            }

            // Modal overlay - ALWAYS at the end of ZStack
            CustomModal(
                isPresented: $showModal,
                type: modalType,
                title: modalTitle,
                message: modalMessage,
                buttons: modalButtons
            )
        }
    }
}
