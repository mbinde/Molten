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
        iconSize: CGFloat = 60,
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
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(.secondary)

                // Title
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // Description
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Optional action button
                if let button = actionButton {
                    Button(action: button.action) {
                        Text(button.title)
                            .font(.headline)
                            .foregroundColor(buttonForegroundColor(for: button.style))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(buttonBackground(for: button.style))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Methods

    private func buttonForegroundColor(for style: ActionButton.ButtonStyle) -> Color {
        switch style {
        case .prominent:
            return .white
        case .secondary:
            return .primary
        }
    }

    private func buttonBackground(for style: ActionButton.ButtonStyle) -> Color {
        switch style {
        case .prominent:
            return .accentColor
        case .secondary:
            return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Convenience Initializers

extension CustomEmptyStateView {
    /// Empty state for search results with no matches
    static func searchResults(
        searchTerm: String? = nil,
        filters: [String] = []
    ) -> CustomEmptyStateView {
        var description = "No items match"
        if let term = searchTerm, !term.isEmpty {
            description += " '\(term)'"
        }
        if !filters.isEmpty {
            description += " with " + filters.joined(separator: " and ")
        }

        return CustomEmptyStateView(
            icon: "magnifyingglass",
            iconSize: 40,
            title: "No Results",
            description: description
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
