//
//  ShoppingListEmptyStates.swift
//  Flameworker
//
//  Created by Assistant on 1/18/25.
//

import SwiftUI

struct ShoppingListEmptyStates {
    /// Standard empty state when there are no items in the shopping list
    static func standard(onAddItem: @escaping () -> Void) -> some View {
        CustomEmptyStateView(
            icon: "cart",
            title: "No items on your shopping list yet",
            description: "Set minimum quantities in the catalog to automatically generate shopping lists",
            actionButton: .init(
                title: "Add to Shopping List",
                action: onAddItem,
                style: .prominent
            )
        )
    }

    /// Empty state shown when search/filters return no results
    static func searchResults(
        searchTerm: String?,
        activeFilters: [String],
        onClearFilters: @escaping () -> Void
    ) -> some View {
        CustomEmptyStateView.searchResults(
            searchTerm: searchTerm,
            filters: activeFilters,
            onClearFilters: onClearFilters
        )
    }
}
