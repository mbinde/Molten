//
//  UsageBanner.swift
//  Molten
//
//  Usage indicator banner for subscription limits
//

import SwiftUI

/// Banner showing current usage against subscription limit
struct UsageBanner: View {
    let featureName: String
    let currentCount: Int
    let limit: Int?  // nil means unlimited (premium)
    let filteredCount: Int?  // Optional: number of items shown after filtering
    let hasSettingsFilters: Bool  // Whether Settings filters (COE/Manufacturer) are active
    let onUpgradeTap: () -> Void

    init(
        featureName: String,
        currentCount: Int,
        limit: Int?,
        filteredCount: Int? = nil,
        hasSettingsFilters: Bool = false,
        onUpgradeTap: @escaping () -> Void
    ) {
        self.featureName = featureName
        self.currentCount = currentCount
        self.limit = limit
        self.filteredCount = filteredCount
        self.hasSettingsFilters = hasSettingsFilters
        self.onUpgradeTap = onUpgradeTap
    }

    var body: some View {
        if let limit = limit {
            // Free tier with limit
            HStack(spacing: 12) {
                Image(systemName: usageIcon)
                    .font(.title3)
                    .foregroundColor(usageColor)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(currentCount) / \(limit)")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(featureName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }

                    // Contextual message about Settings filters
                    if let filteredCount = filteredCount, hasSettingsFilters, filteredCount < currentCount {
                        Text("\(filteredCount) shown with Settings filters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if shouldShowUpgradeButton {
                    Button(action: onUpgradeTap) {
                        Text("Upgrade")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                    .accessibilityIdentifier("usage_banner_upgrade")
                }
            }
            .padding(12)
            .background(backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(usageColor.opacity(0.3), lineWidth: 1)
            )
        } else {
            // Premium tier - show badge
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Unlimited \(featureName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Computed Properties

    private var usagePercentage: CGFloat {
        guard let limit = limit, limit > 0 else { return 0 }
        return min(CGFloat(currentCount) / CGFloat(limit), 1.0)
    }

    private var usageColor: Color {
        let percentage = usagePercentage
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    private var usageIcon: String {
        let percentage = usagePercentage
        if percentage >= 1.0 {
            return "exclamationmark.circle.fill"
        } else if percentage >= 0.8 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var backgroundColor: Color {
        let percentage = usagePercentage
        if percentage >= 1.0 {
            return Color.red.opacity(0.1)
        } else if percentage >= 0.8 {
            return Color.orange.opacity(0.1)
        } else {
            return Color.green.opacity(0.05)
        }
    }

    private var shouldShowUpgradeButton: Bool {
        usagePercentage >= 0.8
    }
}

#Preview("Low Usage") {
    VStack(spacing: 16) {
        UsageBanner(
            featureName: "inventory items",
            currentCount: 15,
            limit: 50,
            onUpgradeTap: {}
        )
        .padding()
    }
}

#Preview("High Usage") {
    VStack(spacing: 16) {
        UsageBanner(
            featureName: "shopping items",
            currentCount: 13,
            limit: 15,
            onUpgradeTap: {}
        )
        .padding()
    }
}

#Preview("At Limit") {
    VStack(spacing: 16) {
        UsageBanner(
            featureName: "projects",
            currentCount: 5,
            limit: 5,
            onUpgradeTap: {}
        )
        .padding()
    }
}

#Preview("Premium") {
    VStack(spacing: 16) {
        UsageBanner(
            featureName: "inventory items",
            currentCount: 150,
            limit: nil,
            onUpgradeTap: {}
        )
        .padding()
    }
}
