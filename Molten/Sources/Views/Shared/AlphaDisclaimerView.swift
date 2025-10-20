//
//  AlphaDisclaimerView.swift
//  Molten
//
//  Created by Assistant on 10/19/25.
//

import SwiftUI

struct AlphaDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                            .padding(.bottom, DesignSystem.Spacing.sm)

                        Text("Alpha Testing Version")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text("Thank you for helping test Molten")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, DesignSystem.Spacing.md)

                    Divider()

                    // Main content
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        disclaimerSection(
                            icon: "ant.fill",
                            title: "Finding Bugs & Crashes",
                            description: "This is an alpha version released for testing. We're actively looking for bugs, crashes, and areas that need improvement. Your feedback is invaluable."
                        )

                        disclaimerSection(
                            icon: "photo.on.rectangle",
                            title: "Manufacturer Permissions",
                            description: "We're still working on obtaining permission from manufacturers for product photos and descriptions. Some content may be incomplete or unavailable."
                        )

                        disclaimerSection(
                            icon: "wrench.and.screwdriver.fill",
                            title: "Features In Development",
                            description: "Purchases, Project Plans, and Project Logs are not yet functional. These features are still being developed and will be available in future releases."
                        )

                        disclaimerSection(
                            icon: "exclamationmark.arrow.circlepath",
                            title: "Data May Need Re-Entry",
                            description: "The app is changing rapidly. Your inventory and other data may need to be re-entered in future versions as we improve the data structure."
                        )
                    }

                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.sm)

                    // Acknowledgment button
                    Button(action: {
                        acknowledgeDisclaimer()
                        dismiss()
                    }) {
                        Text("Yes, I Understand")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .padding(.top, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Padding.standard)
            }
            .navigationTitle("Important Information")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .interactiveDismissDisabled(true)  // Prevent dismissal without acknowledgment
        }
    }

    private func disclaimerSection(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.accentPrimary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func acknowledgeDisclaimer() {
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedAlphaDisclaimer")
    }
}

#Preview {
    AlphaDisclaimerView()
}
