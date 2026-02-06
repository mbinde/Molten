//
//  ShoppingListViewModelProtocol.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol defining the Shopping List view's presentation logic for testability
//
//  ⚠️ DEPRECATED: This protocol is superseded by UnifiedGlassViewModel.swift
//  When ENABLE_UNIFIED_GLASS_VIEW is true, this protocol is not used.
//  TODO: Delete this file once UnifiedGlassView is stable in production.
//

import Foundation
import SwiftUI

/// Protocol defining the shopping list view's presentation logic
///
/// This protocol enables:
/// - Unit testing of presentation logic with mocks
/// - Dependency injection for views
/// - Easy creation of previews with different states
@MainActor
protocol ShoppingListViewModelProtocol {

    // MARK: - Data State

    /// Shopping lists by ID
    var shoppingLists: [String: DetailedShoppingListModel] { get }

    /// Filtered items based on current filters
    var filteredItems: [DetailedShoppingListItemModel] { get }

    // MARK: - Loading State

    /// Whether data is currently being loaded
    var isLoading: Bool { get }

    /// Error message if operation failed
    var errorMessage: String? { get }

    // MARK: - Search & Filter State

    /// Current search text
    var searchText: String { get set }

    /// Whether to search only titles
    var searchTitlesOnly: Bool { get set }

    /// Selected tags for filtering
    var selectedTags: Set<String> { get set }

    /// Selected COEs for filtering
    var selectedCOEs: Set<Int32> { get set }

    /// Selected manufacturers for filtering
    var selectedManufacturers: Set<String> { get set }

    /// Selected store for filtering
    var selectedStore: String? { get set }

    // MARK: - Sort State

    /// Current sort option
    var sortOption: ShoppingListSortOption { get set }

    // MARK: - Shopping Mode State

    /// Whether shopping mode is active
    var isShoppingModeActive: Bool { get }

    /// Items checked during shopping (using ShoppingListItemModel.id: String)
    var checkedItems: Set<String> { get set }

    // MARK: - Computed Properties

    /// Whether any lists have been loaded
    var hasData: Bool { get }

    /// Whether an error occurred
    var hasError: Bool { get }

    /// Total number of items across all lists
    var totalItemsCount: Int { get }

    /// Number of items needing restocking
    var itemsNeedingRestockCount: Int { get }

    /// All available tags from items
    var availableTags: [String] { get }

    /// All available COEs from items
    var availableCOEs: [Int32] { get }

    /// All available manufacturers from items
    var availableManufacturers: [String] { get }

    /// All available stores from items
    var availableStores: [String] { get }

    // MARK: - Data Loading

    /// Load shopping lists
    func loadShoppingLists() async

    /// Refresh shopping lists
    func refreshShoppingLists() async

    // MARK: - Search & Filter

    /// Update search text and apply filters
    func searchItems(text: String)

    /// Clear all filters
    func clearFilters()

    // MARK: - Shopping Mode

    /// Start shopping mode
    func startShoppingMode()

    /// Cancel shopping mode
    func cancelShoppingMode()

    /// Toggle item checked status in shopping mode
    func toggleItemChecked(_ itemId: String)

    /// Complete checkout
    func performCheckout() async throws
}

/// Sort options for shopping list
enum ShoppingListSortOption: String, CaseIterable {
    case neededQuantity = "Needed Quantity"
    case itemName = "Item Name"
    case store = "Store"
    case manufacturer = "Manufacturer"

    var icon: String {
        switch self {
        case .neededQuantity: return "exclamationmark.triangle.fill"
        case .itemName: return "textformat.abc"
        case .store: return "building.2"
        case .manufacturer: return "building.columns"
        }
    }
}
