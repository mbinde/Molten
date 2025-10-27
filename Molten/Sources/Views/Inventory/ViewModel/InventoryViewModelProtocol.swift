//
//  InventoryViewModelProtocol.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol defining the Inventory view's presentation logic for testability
//

import Foundation
import SwiftUI

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

    /// Currently selected inventory types for filtering
    var selectedTypes: Set<String> { get set }

    // MARK: - Computed Properties

    /// Whether any data has been loaded
    var hasData: Bool { get }

    /// Whether an error occurred
    var hasError: Bool { get }

    /// Available inventory types for filtering
    var availableInventoryTypes: [String] { get }

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
