//
//  CatalogEmptyStates.swift
//  Molten
//
//  Empty state components for CatalogView
//

import SwiftUI

// MARK: - Loading State

struct CatalogLoadingState: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
                .accessibilityLabel("Loading catalog")

            Text("Loading catalog...")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Empty Catalog State

struct CatalogEmptyState: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .accessibilityHidden(true)

            Text("No catalog items available")
                .font(DesignSystem.Typography.subSectionHeader)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Search Empty State

struct CatalogSearchEmptyState: View {
    let message: String
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .accessibilityHidden(true)

            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Padding.generous)

            Button("Clear Filters") {
                onClearSearch()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("catalog_clear_filters")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}
