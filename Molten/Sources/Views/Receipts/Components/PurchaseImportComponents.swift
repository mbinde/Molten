//
//  PurchaseImportComponents.swift
//  Molten
//
//  Shared UI components for purchase import features
//  Used by both PurchaseListView and PurchaseImportSettingsView
//

import SwiftUI

// MARK: - Forwarding Address Row

/// Displays the forwarding email address with a copy button (no Section wrapper)
/// Use this inside an existing Section, or wrap with ForwardingAddressCard for standalone use
struct ForwardingAddressRow: View {
    let email: String
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forward order emails to:")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button {
                onCopy()
            } label: {
                HStack {
                    Text(email)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Forwarding Address Card

/// Displays the forwarding email address with a copy button in its own Section
struct ForwardingAddressCard: View {
    let email: String
    let footerText: String?
    let onCopy: () -> Void

    init(email: String, footerText: String? = nil, onCopy: @escaping () -> Void) {
        self.email = email
        self.footerText = footerText
        self.onCopy = onCopy
    }

    var body: some View {
        Section {
            ForwardingAddressRow(email: email, onCopy: onCopy)
        } footer: {
            if let footer = footerText {
                Text(footer)
            }
        }
    }
}

// MARK: - Setup Steps View

/// Shows the 3-step setup instructions for purchase import
struct PurchaseImportSetupSteps: View {
    var body: some View {
        Section("Next Steps") {
            SetupStepRow(
                number: "1",
                title: "Forward an order confirmation",
                description: "Send your glass order emails to the address above"
            )

            SetupStepRow(
                number: "2",
                title: "We'll parse your order",
                description: "Items, prices, and order details are extracted automatically"
            )

            SetupStepRow(
                number: "3",
                title: "Review and import",
                description: "Add items to your inventory with one tap"
            )
        }
    }
}

// MARK: - Setup Step Row

/// Single row in the setup steps list
struct SetupStepRow: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.moltenOrange)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supported Retailers Section

/// Shows the list of supported retailers
struct SupportedRetailersSection: View {
    var body: some View {
        Section {
            Text("ABR Imagery, Bullseye Glass, Glass Alchemy, Momka's Glass, Mountain Glass Arts, Frantz Art Glass, and more.")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        } header: {
            Text("Supported Retailers")
        }
    }
}

// MARK: - How It Works Section

/// Shows the how-it-works info rows (used in settings)
struct HowItWorksSection: View {
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HowItWorksRow(icon: "envelope.arrow.triangle.branch", text: "Forward order confirmation emails")
                HowItWorksRow(icon: "doc.text.viewfinder", text: "We parse items, prices, and order details")
                HowItWorksRow(icon: "checkmark.square", text: "Review and import items to your inventory")
                HowItWorksRow(icon: "lock.shield", text: "Your data stays private and secure")
            }
        } header: {
            Text("How It Works")
        }
    }
}

// MARK: - How It Works Row

/// Single info row with icon and text for how-it-works section
private struct HowItWorksRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Copied Feedback Overlay

/// Toast-style feedback shown when email is copied
struct CopiedFeedbackOverlay: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Email address copied")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Check for Orders Button

/// Teal button to check for forwarded orders
struct CheckForOrdersButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Section {
            Button {
                action()
            } label: {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "envelope.arrow.triangle.branch")
                        Text("Check for Forwarded Orders")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.accentSuccess)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }
}
