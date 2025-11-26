//
//  LimitWarningBanner.swift
//  Molten
//
//  Compact banner shown when user approaches free tier limits
//

import SwiftUI

/// Compact banner warning users they're approaching their free tier limit
/// Shows at 75%+ usage with an upgrade CTA
struct LimitWarningBanner: View {
    let currentCount: Int
    let limit: Int
    let featureName: String  // "inventory items", "projects", etc.
    let onUpgradeTap: () -> Void

    private var usagePercentage: Double {
        guard limit > 0 else { return 0 }
        return Double(currentCount) / Double(limit)
    }

    private var shouldShow: Bool {
        usagePercentage >= 0.75
    }

    private var isAtLimit: Bool {
        currentCount >= limit
    }

    private var remainingCount: Int {
        max(0, limit - currentCount)
    }

    var body: some View {
        if shouldShow {
            Button(action: onUpgradeTap) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Warning icon
                    Image(systemName: isAtLimit ? "exclamationmark.circle.fill" : "info.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(isAtLimit ? .red : .orange)

                    // Message
                    if isAtLimit {
                        Text("Limit reached – ")
                            .font(.subheadline)
                        + Text("Upgrade to Pro")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("\(remainingCount) \(featureName) left – ")
                            .font(.subheadline)
                        + Text("Go Pro for unlimited")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(isAtLimit ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(DesignSystem.CornerRadius.small)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isAtLimit ? .red : .primary)
        }
    }
}

// MARK: - Convenience initializer with EntitlementService

extension LimitWarningBanner {
    /// Create a banner for inventory items
    static func forInventory(
        currentCount: Int,
        entitlementService: EntitlementService,
        onUpgradeTap: @escaping () -> Void
    ) -> LimitWarningBanner? {
        guard let limit = entitlementService.getInventoryLimit() else { return nil }
        return LimitWarningBanner(
            currentCount: currentCount,
            limit: limit,
            featureName: "items",
            onUpgradeTap: onUpgradeTap
        )
    }

    /// Create a banner for shopping list items
    static func forShoppingList(
        currentCount: Int,
        entitlementService: EntitlementService,
        onUpgradeTap: @escaping () -> Void
    ) -> LimitWarningBanner? {
        guard let limit = entitlementService.getShoppingListLimit() else { return nil }
        return LimitWarningBanner(
            currentCount: currentCount,
            limit: limit,
            featureName: "items",
            onUpgradeTap: onUpgradeTap
        )
    }

    /// Create a banner for projects
    static func forProjects(
        currentCount: Int,
        entitlementService: EntitlementService,
        onUpgradeTap: @escaping () -> Void
    ) -> LimitWarningBanner? {
        guard let limit = entitlementService.getProjectsLimit() else { return nil }
        return LimitWarningBanner(
            currentCount: currentCount,
            limit: limit,
            featureName: "projects",
            onUpgradeTap: onUpgradeTap
        )
    }

    /// Create a banner for logbook entries
    static func forLogbook(
        currentCount: Int,
        entitlementService: EntitlementService,
        onUpgradeTap: @escaping () -> Void
    ) -> LimitWarningBanner? {
        guard let limit = entitlementService.getLogbookEntriesLimit() else { return nil }
        return LimitWarningBanner(
            currentCount: currentCount,
            limit: limit,
            featureName: "entries",
            onUpgradeTap: onUpgradeTap
        )
    }
}

// MARK: - Previews

#Preview("75% Usage") {
    VStack {
        LimitWarningBanner(
            currentCount: 19,
            limit: 25,
            featureName: "items",
            onUpgradeTap: {}
        )
        .padding()

        Spacer()
    }
}

#Preview("90% Usage") {
    VStack {
        LimitWarningBanner(
            currentCount: 23,
            limit: 25,
            featureName: "items",
            onUpgradeTap: {}
        )
        .padding()

        Spacer()
    }
}

#Preview("At Limit") {
    VStack {
        LimitWarningBanner(
            currentCount: 25,
            limit: 25,
            featureName: "items",
            onUpgradeTap: {}
        )
        .padding()

        Spacer()
    }
}

#Preview("Under 75% - Hidden") {
    VStack {
        LimitWarningBanner(
            currentCount: 10,
            limit: 25,
            featureName: "items",
            onUpgradeTap: {}
        )
        .padding()

        Text("Banner should not be visible above")
            .foregroundStyle(.secondary)

        Spacer()
    }
}
