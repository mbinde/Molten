//
//  UpgradePromptView.swift
//  Molten
//
//  Upgrade prompt that presents RevenueCat paywall directly
//  (Wrapper for CustomPaywallView to maintain backward compatibility)
//

import SwiftUI

struct UpgradePromptView: View {
    // These parameters are kept for API compatibility but no longer displayed
    // (CustomPaywallView shows its own feature list)
    let feature: String
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
        // Go directly to the paywall - no intermediate screen
        CustomPaywallView()
    }
}

// MARK: - Benefit Row (kept for any external usage)

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
