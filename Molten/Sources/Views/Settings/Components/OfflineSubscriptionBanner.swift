//
//  OfflineSubscriptionBanner.swift
//  Molten
//
//  Banner shown when the subscription cache is expiring soon.
//  Prompts user to connect to the internet to verify their subscription.
//

import SwiftUI

/// Banner warning users that their offline subscription cache is expiring
struct OfflineSubscriptionBanner: View {
    let daysRemaining: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(DesignSystem.Colors.accentWarning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Connect to verify subscription")
                    .font(DesignSystem.Typography.listItemTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(warningMessage)
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.accentWarning.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.accentWarning.opacity(0.3), lineWidth: 1)
        )
    }

    private var warningMessage: String {
        if daysRemaining <= 1 {
            return "Pro features will be paused tomorrow until verified"
        } else {
            return "Pro features will pause in \(daysRemaining) days without internet"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        OfflineSubscriptionBanner(daysRemaining: 3)
        OfflineSubscriptionBanner(daysRemaining: 1)
    }
    .padding()
}
