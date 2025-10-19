//
//  ConfirmationDialog.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//  Reusable confirmation dialog component that appears centered on screen
//

import SwiftUI

/// Reusable confirmation dialog that appears centered on screen
/// Use this for destructive actions that require user confirmation
struct ConfirmationDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let confirmRole: ButtonRole
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmRole: ButtonRole = .destructive,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmRole = confirmRole
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            // Dialog card
            VStack(spacing: 0) {
                // Title
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                Divider()

                // Buttons
                HStack(spacing: 0) {
                    // Cancel button
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)

                    Divider()
                        .frame(height: 44)

                    // Confirm button
                    Button(action: {
                        onConfirm()
                    }) {
                        Text(confirmTitle)
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(confirmRole == .destructive ? .red : .blue)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? DesignSystem.Colors.backgroundInputLight : DesignSystem.Colors.background)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .frame(maxWidth: 320)
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

// MARK: - View Extension

extension View {
    /// Shows a centered confirmation dialog
    /// - Parameters:
    ///   - isPresented: Binding to control dialog visibility
    ///   - title: Dialog title
    ///   - message: Dialog message
    ///   - confirmTitle: Confirm button title (default: "Confirm")
    ///   - confirmRole: Button role (default: .destructive)
    ///   - onConfirm: Action to perform when confirmed
    func confirmationDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        confirmRole: ButtonRole = .destructive,
        onConfirm: @escaping () -> Void
    ) -> some View {
        ZStack {
            self

            if isPresented.wrappedValue {
                ConfirmationDialog(
                    title: title,
                    message: message,
                    confirmTitle: confirmTitle,
                    confirmRole: confirmRole,
                    onConfirm: {
                        onConfirm()
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented.wrappedValue = false
                        }
                    },
                    onCancel: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented.wrappedValue = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(999)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPresented.wrappedValue)
    }
}

// MARK: - Preview

#Preview("Delete Confirmation") {
    ZStack {
        // Background content
        VStack {
            Text("Main Content")
                .font(.title)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)

        // Dialog
        ConfirmationDialog(
            title: "Delete Note",
            message: "Are you sure you want to delete this note? This action cannot be undone.",
            confirmTitle: "Delete",
            confirmRole: .destructive,
            onConfirm: {
                print("Confirmed")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}

#Preview("Save Confirmation") {
    ZStack {
        DesignSystem.Colors.background

        ConfirmationDialog(
            title: "Save Changes",
            message: "Do you want to save your changes before leaving?",
            confirmTitle: "Save",
            confirmRole: .cancel,
            onConfirm: {
                print("Save confirmed")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}

#Preview("Long Message") {
    ZStack {
        DesignSystem.Colors.background

        ConfirmationDialog(
            title: "Delete Multiple Items",
            message: "You are about to delete 15 items from your inventory. This will permanently remove all associated data including notes, locations, and purchase history. This action cannot be undone.",
            confirmTitle: "Delete All",
            confirmRole: .destructive,
            onConfirm: {
                print("Delete confirmed")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}
