//
//  ShoppingListViewModel.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol-based ViewModel for ShoppingListView - enables testability
//

import Foundation
import SwiftUI

/// ViewModel for the Shopping List view
///
/// Manages presentation logic for:
/// - Loading shopping lists
/// - Searching and filtering items
/// - Shopping mode with checkout
/// - Sorting and grouping items
@MainActor
@Observable
class ShoppingListViewModel: ShoppingListViewModelProtocol {

    // MARK: - Dependencies

    private let shoppingListService: ShoppingListService

    // MARK: - Published State

    var shoppingLists: [String: DetailedShoppingListModel] = [:]
    var isLoading = false
    var errorMessage: String?

    // MARK: - Search & Filter State

    var searchText = "" {
        didSet {
            if searchText != oldValue {
                applyFilters()
            }
        }
    }

    var searchTitlesOnly = false {
        didSet {
            if searchTitlesOnly != oldValue {
                applyFilters()
            }
        }
    }

    var selectedTags: Set<String> = [] {
        didSet {
            if selectedTags != oldValue {
                applyFilters()
            }
        }
    }

    var selectedCOEs: Set<Int32> = [] {
        didSet {
            if selectedCOEs != oldValue {
                applyFilters()
            }
        }
    }

    var selectedManufacturers: Set<String> = [] {
        didSet {
            if selectedManufacturers != oldValue {
                applyFilters()
            }
        }
    }

    var selectedStore: String? = nil {
        didSet {
            if selectedStore != oldValue {
                applyFilters()
            }
        }
    }

    var selectedProductTypes: Set<String> = [] {
        didSet {
            if selectedProductTypes != oldValue {
                applyFilters()
            }
        }
    }

    var selectedInventoryType: String? = nil {
        didSet {
            if selectedInventoryType != oldValue {
                applyFilters()
            }
        }
    }

    // MARK: - Sort State

    var sortOption: ShoppingListSortOption = .neededQuantity {
        didSet {
            if sortOption != oldValue {
                applyFilters()
            }
        }
    }

    // MARK: - Shopping Mode State

    var isShoppingModeActive = false
    var checkedItems: Set<String> = []

    // MARK: - Filtered State (computed internally)

    private var _filteredItems: [DetailedShoppingListItemModel] = []

    var filteredItems: [DetailedShoppingListItemModel] {
        _filteredItems
    }

    // MARK: - Initialization

    // Observer for UserDefaults changes
    nonisolated(unsafe) private var userDefaultsObserver: NSObjectProtocol?

    init(shoppingListService: ShoppingListService) {
        self.shoppingListService = shoppingListService

        // Set up observer for UserDefaults changes (COE filter, manufacturer filter, applyFiltersToInventory)
        setupUserDefaultsObserver()
    }

    nonisolated deinit {
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Set up observer for UserDefaults changes to apply global filters immediately
    private func setupUserDefaultsObserver() {
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // When UserDefaults changes (e.g., COE filter, manufacturer filter, applyFiltersToInventory in Settings),
            // reapply filters to update the view immediately
            self?.applyFilters()
        }
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !shoppingLists.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var totalItemsCount: Int {
        shoppingLists.values.reduce(0) { $0 + $1.items.count }
    }

    var itemsNeedingRestockCount: Int {
        shoppingLists.values.flatMap { $0.items }.filter { $0.shoppingListItem.neededQuantity > 0 }.count
    }

    var availableTags: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let tagsSet = Set(allItems.flatMap { $0.tags })
        return Array(tagsSet).sorted()
    }

    var availableCOEs: [Int32] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let coeSet = Set(allItems.compactMap { $0.catalogItem.coe })
        return Array(coeSet).sorted()
    }

    var availableManufacturers: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let mfgSet = Set(allItems.map { $0.catalogItem.manufacturer })
        return Array(mfgSet).sorted()
    }

    var availableStores: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let storesSet = Set(allItems.map { $0.shoppingListItem.store })
        return Array(storesSet).sorted()
    }

    var availableInventoryTypes: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let typesSet = Set(allItems.map { $0.shoppingListItem.type })
        return Array(typesSet).sorted()
    }

    /// Count of items per product type (glass, coating, tool)
    var productTypeCounts: [String: Int] {
        computeProductTypeCounts()
    }

    private func computeProductTypeCounts() -> [String: Int] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        var counts: [String: Int] = [:]
        for item in allItems {
            let productType = item.catalogItem.itemType.rawValue
            counts[productType, default: 0] += 1
        }
        return counts
    }

    // MARK: - Data Loading

    func loadShoppingLists() async {
        isLoading = true
        errorMessage = nil

        do {
            shoppingLists = try await shoppingListService.generateAllShoppingLists()
            applyFilters()
        } catch {
            errorMessage = "Failed to load shopping lists: \(error.localizedDescription)"
            shoppingLists = [:]
            _filteredItems = []
        }

        isLoading = false
    }

    func refreshShoppingLists() async {
        await loadShoppingLists()
    }

    // MARK: - Search & Filter

    func searchItems(text: String) {
        searchText = text
    }

    func clearFilters() {
        searchText = ""
        searchTitlesOnly = false
        selectedTags = []
        selectedCOEs = []
        selectedManufacturers = []
        selectedStore = nil
    }

    // MARK: - Shopping Mode

    func startShoppingMode() {
        isShoppingModeActive = true
        checkedItems = []
    }

    func cancelShoppingMode() {
        isShoppingModeActive = false
        checkedItems = []
    }

    func toggleItemChecked(_ itemId: String) {
        if checkedItems.contains(itemId) {
            checkedItems.remove(itemId)
        } else {
            checkedItems.insert(itemId)
        }
    }

    func performCheckout() async throws {
        // Note: Actual checkout logic (purchase records, inventory updates)
        // is handled by the view layer in ShoppingListView's CheckoutSheet
        // This ViewModel method just cleans up the shopping mode state

        // Exit shopping mode
        cancelShoppingMode()

        // Refresh lists to reflect any changes
        await refreshShoppingLists()
    }

    // MARK: - Private Helpers

    private func applyFilters() {
        var allItems = shoppingLists.values.flatMap { $0.items }

        // Apply search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            allItems = allItems.filter { item in
                if searchTitlesOnly {
                    return item.catalogItem.name.lowercased().contains(searchLower)
                } else {
                    return item.catalogItem.name.lowercased().contains(searchLower) ||
                           item.catalogItem.manufacturer.lowercased().contains(searchLower) ||
                           item.allTags.contains(where: { $0.lowercased().contains(searchLower) })
                }
            }
        }

        // Apply product type filter
        if !selectedProductTypes.isEmpty {
            allItems = allItems.filter { item in
                selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            allItems = allItems.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        // Apply COE filter (only affects glass items - coatings/tools don't have COE)
        // First apply manual filter (from UI)
        if !selectedCOEs.isEmpty {
            allItems = allItems.filter { item in
                // Non-glass items (coatings, tools) don't have COE - don't filter them out
                if item.catalogItem.itemType != .glass {
                    return true
                }
                if let coe = item.catalogItem.coe {
                    return selectedCOEs.contains(coe)
                }
                return false
            }
        }
        // Then apply global COE filter from Settings (if enabled)
        if UserSettings.shared.applyFiltersToInventory {
            let globalCOEs = COEGlassPreference.selectedCOETypes
            // Only apply if it's a subset (not all COEs selected)
            if !globalCOEs.isEmpty && globalCOEs.count < COEGlassType.allCases.count {
                let globalCOEValues = Set(globalCOEs.map { Int32($0.rawValue) })
                allItems = allItems.filter { item in
                    if let coe = item.catalogItem.coe {
                        return globalCOEValues.contains(coe)
                    }
                    return false
                }
            }
        }

        // Apply manufacturer filter
        // First apply manual filter (from UI)
        if !selectedManufacturers.isEmpty {
            allItems = allItems.filter { item in
                selectedManufacturers.contains(item.catalogItem.manufacturer)
            }
        }
        // Then apply global manufacturer filter from Settings (if enabled)
        if UserSettings.shared.applyFiltersToInventory {
            if let data = UserDefaults.standard.data(forKey: "selectedManufacturerFilter"),
               let selectedManufacturers = try? JSONDecoder().decode(Set<String>.self, from: data),
               !selectedManufacturers.isEmpty {
                allItems = allItems.filter { item in
                    selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        // Apply store filter
        if let store = selectedStore {
            allItems = allItems.filter { item in
                item.shoppingListItem.store == store
            }
        }

        // Apply inventory type filter (Kind)
        if let inventoryType = selectedInventoryType {
            allItems = allItems.filter { item in
                item.shoppingListItem.type == inventoryType
            }
        }

        // Apply sorting
        allItems = sortItems(allItems)

        _filteredItems = allItems
    }

    private func sortItems(_ items: [DetailedShoppingListItemModel]) -> [DetailedShoppingListItemModel] {
        switch sortOption {
        case .neededQuantity:
            return items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        case .itemName:
            return items.sorted { $0.catalogItem.name.localizedCaseInsensitiveCompare($1.catalogItem.name) == .orderedAscending }
        case .store:
            return items.sorted { $0.shoppingListItem.store.localizedCaseInsensitiveCompare($1.shoppingListItem.store) == .orderedAscending }
        case .manufacturer:
            return items.sorted { $0.catalogItem.manufacturer.localizedCaseInsensitiveCompare($1.catalogItem.manufacturer) == .orderedAscending }
        }
    }
}
