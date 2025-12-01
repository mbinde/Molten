//
//  CatalogViewModelProtocol.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol defining the Catalog view's presentation logic for testability
//

import Foundation
import SwiftUI

/// Protocol defining the catalog view's presentation logic
///
/// This protocol enables:
/// - Unit testing of presentation logic with mocks
/// - Dependency injection for views
/// - Easy creation of previews with different states
@MainActor
protocol CatalogViewModelProtocol {

    // MARK: - Data State

    /// All catalog items (unfiltered)
    var items: [CompleteInventoryItemModel] { get }

    /// Items after applying all filters (search, tags, COE, manufacturers)
    var filteredItems: [CompleteInventoryItemModel] { get }

    /// Filtered items after sorting
    var sortedFilteredItems: [CompleteInventoryItemModel] { get }

    // MARK: - Loading State

    /// Whether data is currently being loaded
    var isLoading: Bool { get }

    /// Error message if loading failed
    var errorMessage: String? { get }

    // MARK: - Search & Filter State

    /// Current search text
    var searchText: String { get set }

    /// Whether to search only in item names (true) or all fields (false)
    var searchTitlesOnly: Bool { get set }

    /// Currently selected tags for filtering
    var selectedTags: Set<String> { get set }

    /// Currently selected COEs for filtering
    var selectedCOEs: Set<Int32> { get set }

    /// Currently selected manufacturers for filtering
    var selectedManufacturers: Set<String> { get set }

    // MARK: - Sort State

    /// Current sort option
    var sortOption: SortOption { get set }

    // MARK: - UI State

    /// Visual feedback when search is cleared
    var searchClearedFeedback: Bool { get set }

    // MARK: - Available Options (Computed)

    /// All unique tags available in the catalog
    var allAvailableTags: [String] { get }

    /// Set of user-created tags (for visual distinction)
    var allUserTags: Set<String> { get }

    /// All unique COE values available in the catalog
    var allAvailableCOEs: [Int32] { get }

    /// All unique manufacturers available in the catalog
    var availableManufacturers: [String] { get }

    // MARK: - Filter Counts (for UI display)

    /// Count of items per manufacturer (excluding manufacturer filter)
    var manufacturerCounts: [String: Int] { get }

    /// Count of items per COE (excluding COE filter)
    var coeCounts: [Int32: Int] { get }

    /// Count of items per tag (excluding tag filter)
    var tagCounts: [String: Int] { get }

    // MARK: - Display Helpers

    /// Message to display when no results match filters
    var emptyStateMessage: String { get }

    /// Whether any data has been loaded
    var hasData: Bool { get }

    /// Whether filters are currently active
    var hasActiveFilters: Bool { get }

    // MARK: - Actions

    /// Load catalog data from service
    func loadData() async

    /// Refresh catalog data
    func refreshData() async

    /// Clear all search and filter criteria
    func clearSearch()

    /// Update sort option and persist to settings
    func updateSorting(_ newSortOption: SortOption)

    /// Apply all current filters to update filteredItems
    func applyFilters()
}
