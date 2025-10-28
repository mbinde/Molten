//
//  InventoryViewModelProtocol.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol defining the Inventory view's presentation logic for testability
//

import Foundation
import SwiftUI

/// Sort options for inventory items
enum InventorySortOption: String, CaseIterable {
    case name = "Name"
    case totalQuantity = "Total Quantity"
    case manufacturer = "Manufacturer"
    case dateAdded = "Date Added"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .name: return "textformat.abc"
        case .totalQuantity: return "archivebox.fill"
        case .manufacturer: return "building.2"
        case .dateAdded: return "calendar"
        }
    }
}

/// Protocol defining the inventory view's presentation logic
///
/// This protocol enables:
/// - Unit testing of presentation logic with mocks
/// - Dependency injection for views
/// - Easy creation of previews with different states
@MainActor
protocol InventoryViewModelProtocol {

    // MARK: - Data State

    /// All complete inventory items (unfiltered)
    var completeItems: [CompleteInventoryItemModel] { get }

    /// Items after applying filters (search, type)
    var filteredItems: [CompleteInventoryItemModel] { get }

    // MARK: - Loading State

    /// Whether data is currently being loaded
    var isLoading: Bool { get }

    /// Error message if operation failed
    var errorMessage: String? { get }

    // MARK: - Search & Filter State

    /// Current search text
    var searchText: String { get set }

    /// Whether to search titles only (vs full text)
    var searchTitlesOnly: Bool { get set }

    /// Currently selected inventory types for filtering
    var selectedTypes: Set<String> { get set }

    /// Currently selected tags for filtering
    var selectedTags: Set<String> { get set }

    /// Currently selected COEs for filtering
    var selectedCOEs: Set<Int32> { get set }

    /// Currently selected manufacturers for filtering
    var selectedManufacturers: Set<String> { get set }

    /// Current sort option
    var sortOption: InventorySortOption { get set }

    // MARK: - Computed Properties

    /// Whether any data has been loaded
    var hasData: Bool { get }

    /// Whether an error occurred
    var hasError: Bool { get }

    /// Available inventory types for filtering
    var availableInventoryTypes: [String] { get }

    /// Available tags for filtering
    var availableTags: [String] { get }

    /// Available COEs for filtering
    var availableCOEs: [Int32] { get }

    /// Available manufacturers for filtering
    var availableManufacturers: [String] { get }

    /// Total number of complete items
    var totalItemsCount: Int { get }

    /// Number of filtered items
    var filteredItemsCount: Int { get }

    // MARK: - Data Loading

    /// Load all inventory items
    func loadInventoryItems() async

    // MARK: - Search & Filter

    /// Search items by text
    func searchItems(searchText: String) async

    /// Filter items by type
    func filterItems(byType type: String) async

    /// Apply all current filters
    func applyFilters() async

    // MARK: - CRUD Operations

    /// Add inventory for an item
    func addInventory(quantity: Double, type: String, toItemNaturalKey stableId: String) async

    /// Update an existing inventory record
    func updateInventory(_ inventory: InventoryModel) async

    /// Delete a single inventory record
    func deleteInventory(id: UUID) async

    /// Delete multiple inventory records
    func deleteInventories(ids: [UUID]) async

    // MARK: - New Architecture Methods

    /// Get detailed inventory summary for an item
    func getDetailedInventorySummary(for stableId: String) async -> DetailedInventorySummaryModel?

    /// Get items below stock threshold
    func getLowStockItems(threshold: Double) async
}
