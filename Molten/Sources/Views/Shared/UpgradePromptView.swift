//
//  UpgradePromptView.swift
//  Molten
//
//  Upgrade prompt that presents RevenueCat paywall
//

import SwiftUI

struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss

    let feature: String  // "inventory", "shopping", "projects", etc.
    let currentCount: Int
    let limit: Int

    private let subscriptionService: SubscriptionServiceProtocol

    init(feature: String, currentCount: Int, limit: Int, subscriptionService: SubscriptionServiceProtocol = AppDependencies.shared.subscriptionService) {
        self.feature = feature
        self.currentCount = currentCount
        self.limit = limit
        self.subscriptionService = subscriptionService
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow, .orange.opacity(0.3))
                    .padding(.top, 40)

                // Title
                Text("Upgrade to Pro")
                    .font(.title.bold())

                // Message
                VStack(spacing: 12) {
                    Text("You've reached the free tier limit")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("\(currentCount) / \(limit) \(feature) items")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                }

                // Benefits list
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(icon: "infinity", text: "Unlimited \(feature) items")
                    BenefitRow(icon: "square.stack.3d.up.fill", text: "Unlimited projects & logbook entries")
                    BenefitRow(icon: "clock.arrow.circlepath", text: "Versioned cloud backups")
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            dismiss()
                            try? await subscriptionService.presentPaywall()
                        }
                    } label: {
                        Text("View Subscription Options")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .accessibilityIdentifier("upgrade_purchase_button")

                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityIdentifier("upgrade_dismiss_button")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("upgrade_close_button")
                }
            }
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color.accentColor)
                .frame(width: 32)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview("Inventory Limit") {
    UpgradePromptView(
        feature: "inventory",
        currentCount: 50,
        limit: 50
    )
}

#Preview("Projects Limit") {
    UpgradePromptView(
        feature: "projects",
        currentCount: 5,
        limit: 5
    )
}
