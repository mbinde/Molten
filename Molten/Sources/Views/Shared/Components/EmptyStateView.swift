//
//  EmptyStateView.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Generic empty state component for consistent empty states across the app
//

import SwiftUI

/// A reusable empty state view with icon, title, description, and optional action button
struct CustomEmptyStateView: View {
    let icon: String
    let iconSize: CGFloat
    let title: String
    let description: String
    let actionButton: ActionButton?

    /// Action button configuration
    struct ActionButton {
        let title: String
        let action: () -> Void
        let style: ButtonStyle

        enum ButtonStyle {
            case prominent  // Blue filled button
            case secondary  // Gray outlined button
        }
    }

    init(
        icon: String,
        iconSize: CGFloat = 80,  // Standardized to 80
        title: String,
        description: String,
        actionButton: ActionButton? = nil
    ) {
        self.icon = icon
        self.iconSize = iconSize
        self.title = title
        self.description = description
        self.actionButton = actionButton
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Icon - uses relative sizing that scales with Dynamic Type
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .regular))
                .imageScale(.large)  // Respects accessibility settings
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            // Title
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            // Description
            Text(description)
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Padding.generous)

            // Optional action button
            if let button = actionButton {
                Button(action: button.action) {
                    Text(button.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.accentSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityIdentifier("empty_state_action")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - Convenience Initializers

extension CustomEmptyStateView {
    /// Empty state for search results with no matches
    /// - Parameters:
    ///   - searchTerm: The search text that found no results
    ///   - filters: Active filter descriptions (e.g., ["COE 90", "tag 'transparent'"])
    ///   - onClearFilters: Optional action to clear all filters and search
    static func searchResults(
        searchTerm: String? = nil,
        filters: [String] = [],
        onClearFilters: (() -> Void)? = nil
    ) -> CustomEmptyStateView {
        var description = "No items match"
        if let term = searchTerm, !term.isEmpty {
            description += " '\(term)'"
        }
        if !filters.isEmpty {
            description += " with " + filters.joined(separator: " and ")
        }
        description += ". Try adjusting your search or filters."

        let actionButton: ActionButton? = if let clearAction = onClearFilters {
            .init(
                title: "Clear Filters",
                action: clearAction,
                style: .secondary
            )
        } else {
            nil
        }

        return CustomEmptyStateView(
            icon: "magnifyingglass",
            iconSize: 60,
            title: "No Results Found",
            description: description,
            actionButton: actionButton
        )
    }
}

// MARK: - Preview

#Preview("Basic Empty State") {
    CustomEmptyStateView(
        icon: "archivebox",
        title: "No Inventory Yet",
        description: "Start tracking your glass inventory by adding your first item",
        actionButton: .init(
            title: "Add Item",
            action: {},
            style: .prominent
        )
    )
}

#Preview("Search Results") {
    CustomEmptyStateView.searchResults(
        searchTerm: "blue",
        filters: ["COE 104", "tag 'transparent'"]
    )
}

#Preview("No Action Button") {
    CustomEmptyStateView(
        icon: "text.justify",
        iconSize: 80,
        title: "No Catalog Items",
        description: "Something is very wrong, we should always be able to load some catalog data."
    )
}
