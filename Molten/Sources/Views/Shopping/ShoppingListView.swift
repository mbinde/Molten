//
//  ShoppingListView.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import SwiftUI
import CoreData
import Combine

enum SearchScope: String, CaseIterable {
    case allFields = "All fields"
    case titlesOnly = "Only titles"
}

struct ShoppingListView: View {
    // MIGRATION COMPLETE: ViewModel manages search, filters, sorting, loading, and data
    @State private var viewModel: ShoppingListViewModel
    @Environment(EntitlementService.self) private var entitlementService
    private let shoppingListService: ShoppingListService
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let purchaseService: PurchaseRecordService
    private let subscriptionService: SubscriptionServiceProtocol
    private let userNotesRepository: UserNotesRepository
    private let userTagsRepository: UserTagsRepository
    private let shoppingListRepository: ShoppingListRepository
    #if canImport(UIKit)
    private let userImageRepository: UserImageRepository
    #endif
    private let kilnScheduleService: KilnScheduleService
    private let glassItemRepository: GlassItemRepository

    // UI-only state (not in ViewModel)
    @State private var searchScope: SearchScope = .allFields
    @State private var showingAllTags = false
    @State private var showingCOESelection = false
    @State private var selectedProductTypes: Set<String> = []  // Not used in shopping list, but required by SearchAndFilterHeader
    @State private var showingProductTypeSelection = false
    @State private var showingManufacturerSelection = false
    @State private var showingStoreSelection = false
    @State private var searchClearedFeedback = false
    @State private var showingAddItem = false
    @State private var refreshTrigger = 0  // Force SwiftUI to refresh list
    @State private var navigationPath = NavigationPath()
    @State private var showingUpgradePrompt = false

    // Shopping mode state
    @StateObject private var shoppingModeState = ShoppingModeState.shared
    @State private var showingExitShoppingModeAlert = false
    @State private var showingCheckoutSheet = false
    @State private var shoppingModeInstructionsExpanded = true
    @State private var toAddToBasketExpanded = true

    // Collapsible store sections state
    @State private var expandedStores: Set<String> = []
    @State private var expandedManufacturers: Set<String> = []

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedAllStores: [String] = []
    @State private var cachedAllManufacturers: [String] = []

    // Local search text state - isolates TextField from ViewModel to prevent full view re-renders
    // The ViewModel's searchText setter handles debouncing and triggers filtering
    @State private var localSearchText = ""

    // Accept ViewModel directly (protocol-based pattern)
    #if canImport(UIKit)
    init(viewModel: ShoppingListViewModel,
         shoppingListService: ShoppingListService,
         catalogService: CatalogService,
         inventoryTrackingService: InventoryTrackingService,
         purchaseService: PurchaseRecordService,
         subscriptionService: SubscriptionServiceProtocol = AppDependencies.shared.subscriptionService,
         userNotesRepository: UserNotesRepository,
         userTagsRepository: UserTagsRepository,
         shoppingListRepository: ShoppingListRepository,
         userImageRepository: UserImageRepository,
         kilnScheduleService: KilnScheduleService,
         glassItemRepository: GlassItemRepository) {
        self._viewModel = State(initialValue: viewModel)
        self.shoppingListService = shoppingListService
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
        self.purchaseService = purchaseService
        self.subscriptionService = subscriptionService
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.userImageRepository = userImageRepository
        self.kilnScheduleService = kilnScheduleService
        self.glassItemRepository = glassItemRepository
    }
    #else
    init(viewModel: ShoppingListViewModel,
         shoppingListService: ShoppingListService,
         catalogService: CatalogService,
         inventoryTrackingService: InventoryTrackingService,
         purchaseService: PurchaseRecordService,
         subscriptionService: SubscriptionServiceProtocol = AppDependencies.shared.subscriptionService,
         userNotesRepository: UserNotesRepository,
         userTagsRepository: UserTagsRepository,
         shoppingListRepository: ShoppingListRepository,
         kilnScheduleService: KilnScheduleService,
         glassItemRepository: GlassItemRepository) {
        self._viewModel = State(initialValue: viewModel)
        self.shoppingListService = shoppingListService
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
        self.purchaseService = purchaseService
        self.subscriptionService = subscriptionService
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.kilnScheduleService = kilnScheduleService
        self.glassItemRepository = glassItemRepository
    }
    #endif

    // Convenience init for production use
    init(deps: AppDependencies = .shared) {
        let viewModel = ShoppingListViewModel(shoppingListService: deps.shoppingListService)
        #if canImport(UIKit)
        self.init(
            viewModel: viewModel,
            shoppingListService: deps.shoppingListService,
            catalogService: deps.catalogService,
            inventoryTrackingService: deps.inventoryTrackingService,
            purchaseService: deps.purchaseRecordService,
            userNotesRepository: deps.userNotesRepository,
            userTagsRepository: deps.userTagsRepository,
            shoppingListRepository: deps.shoppingListRepository,
            userImageRepository: deps.userImageRepository,
            kilnScheduleService: deps.kilnScheduleService,
            glassItemRepository: deps.glassItemRepository
        )
        #else
        self.init(
            viewModel: viewModel,
            shoppingListService: deps.shoppingListService,
            catalogService: deps.catalogService,
            inventoryTrackingService: deps.inventoryTrackingService,
            purchaseService: deps.purchaseRecordService,
            userNotesRepository: deps.userNotesRepository,
            userTagsRepository: deps.userTagsRepository,
            shoppingListRepository: deps.shoppingListRepository,
            kilnScheduleService: deps.kilnScheduleService,
            glassItemRepository: deps.glassItemRepository
        )
        #endif
    }

    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allAvailableTags: [String] {
        return cachedAllTags
    }

    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allAvailableCOEs: [Int32] {
        return cachedAllCOEs
    }

    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allAvailableStores: [String] {
        return cachedAllStores
    }

    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allAvailableManufacturers: [String] {
        return cachedAllManufacturers
    }

    /// Recompute caches when shopping list data changes
    /// This is expensive (O(n)) so only call when data actually changes
    private func updateCaches() {
        let allItems = viewModel.shoppingLists.values.flatMap { $0.items }

        // Extract all tags, COEs, and manufacturers
        var allTagsSet = Set<String>()
        var allCOEsSet = Set<Int32>()
        var manufacturersSet = Set<String>()

        for item in allItems {
            allTagsSet.formUnion(item.tags)
            if let coe = item.catalogItem.coe {
                allCOEsSet.insert(coe)
            }

            let mfr = item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mfr.isEmpty {
                manufacturersSet.insert(mfr)
            }
        }

        cachedAllTags = allTagsSet.sorted()
        cachedAllCOEs = allCOEsSet.sorted()
        cachedAllStores = Array(viewModel.shoppingLists.keys).sorted()
        cachedAllManufacturers = manufacturersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredShoppingLists: [String: DetailedShoppingListModel] {
        var filtered = viewModel.shoppingLists

        // Apply store filter
        if let selectedStore = viewModel.selectedStore {
            filtered = filtered.filter { $0.key == selectedStore }
        }

        // Apply search filter
        if !viewModel.searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(viewModel.searchText) {
            let searchMode = SearchTextParser.parseSearchText(viewModel.searchText)
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    let allFields = [
                        item.catalogItem.name,
                        item.catalogItem.stable_id,
                        item.catalogItem.manufacturer,
                        item.catalogItem.sku
                    ]
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply tag filter
        if !viewModel.selectedTags.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    !viewModel.selectedTags.isDisjoint(with: Set(item.tags))
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply COE filter (only affects glass items - coatings/tools don't have COE)
        if !viewModel.selectedCOEs.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    // Non-glass items (coatings, tools) don't have COE - don't filter them out
                    if item.catalogItem.itemType != .glass {
                        return true
                    }
                    if let coe = item.catalogItem.coe {
                        return viewModel.selectedCOEs.contains(coe)
                    }
                    return false
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply manufacturer filter
        if !viewModel.selectedManufacturers.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    viewModel.selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply inventory type filter (Kind)
        if let inventoryType = viewModel.selectedInventoryType {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    item.shoppingListItem.type == inventoryType
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count
                )
            }.filter { !$0.value.items.isEmpty }
        }

        return filtered
    }

    // Should we group by store? Only when explicitly sorting by store
    private var shouldGroupByStore: Bool {
        viewModel.sortOption == .store
    }

    // Should we group by manufacturer? Only when explicitly sorting by manufacturer
    private var shouldGroupByManufacturer: Bool {
        viewModel.sortOption == .manufacturer
    }

    // All items flattened (for non-grouped view)
    private var allFlattenedItems: [DetailedShoppingListItemModel] {
        let allItems = filteredShoppingLists.values.flatMap { $0.items }
        switch viewModel.sortOption {
        case .neededQuantity:
            return allItems.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        case .itemName:
            return allItems.sorted { $0.catalogItem.name.localizedCaseInsensitiveCompare($1.catalogItem.name) == .orderedAscending }
        case .store, .manufacturer:
            // Group by store or manufacturer (handled separately)
            return allItems
        }
    }

    // Items split by basket status (for shopping mode)
    private var itemsNotInBasket: [DetailedShoppingListItemModel] {
        allFlattenedItems.filter { !shoppingModeState.isInBasket(item_stable_id: $0.catalogItem.stable_id) }
    }

    private var itemsInBasket: [DetailedShoppingListItemModel] {
        allFlattenedItems.filter { shoppingModeState.isInBasket(item_stable_id: $0.catalogItem.stable_id) }
    }

    private var itemsInBasketCount: Int {
        itemsInBasket.count
    }

    private var totalItemsInViewCount: Int {
        allFlattenedItems.count
    }

    /// Total number of unique shopping list items (for usage banner)
    private var shoppingListItemCount: Int {
        viewModel.totalItemsCount
    }

    // Check if Settings filters (COE/Manufacturer) are active and filtering items
    private var hasSettingsFiltersActive: Bool {
        guard UserSettings.shared.applyFiltersToInventory else { return false }

        // Check if COE filter is active (not all COEs selected)
        let globalCOEs = COEGlassPreference.selectedCOETypes
        let hasCOEFilter = !globalCOEs.isEmpty && globalCOEs.count < COEGlassType.allCases.count

        // Check if manufacturer filter is active
        var hasManufacturerFilter = false
        if let data = UserDefaults.standard.data(forKey: "selectedManufacturerFilter"),
           let selectedManufacturers = try? JSONDecoder().decode(Set<String>.self, from: data),
           !selectedManufacturers.isEmpty {
            hasManufacturerFilter = true
        }

        return hasCOEFilter || hasManufacturerFilter
    }

    private var sortedStores: [String] {
        switch viewModel.sortOption {
        case .neededQuantity:
            // Sort stores by total needed quantity (descending)
            return filteredShoppingLists.keys.sorted { store1, store2 in
                let qty1 = filteredShoppingLists[store1]?.items.reduce(0.0) { $0 + $1.shoppingListItem.neededQuantity } ?? 0
                let qty2 = filteredShoppingLists[store2]?.items.reduce(0.0) { $0 + $1.shoppingListItem.neededQuantity } ?? 0
                return qty1 > qty2
            }
        case .itemName:
            // Sort stores alphabetically
            return filteredShoppingLists.keys.sorted()
        case .store, .manufacturer:
            // Sort stores alphabetically (same as itemName for stores)
            return filteredShoppingLists.keys.sorted()
        }
    }

    // Items grouped by manufacturer
    private var itemsGroupedByManufacturer: [String: [DetailedShoppingListItemModel]] {
        let allItems = filteredShoppingLists.values.flatMap { $0.items }
        var grouped: [String: [DetailedShoppingListItemModel]] = [:]

        for item in allItems {
            let manufacturer = item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            grouped[manufacturer, default: []].append(item)
        }

        return grouped
    }

    private var sortedManufacturers: [String] {
        itemsGroupedByManufacturer.keys.sorted { mfr1, mfr2 in
            mfr1.localizedCaseInsensitiveCompare(mfr2) == .orderedAscending
        }
    }

    // Helper to determine if we should show search empty state
    // Check if there are actual items (not just empty store entries)
    private var viewModelHasAnyItems: Bool {
        viewModel.shoppingLists.values.contains { !$0.items.isEmpty }
    }

    private var shouldShowSearchEmptyState: Bool {
        viewModelHasAnyItems && (!viewModel.searchText.isEmpty || !viewModel.selectedTags.isEmpty || !viewModel.selectedCOEs.isEmpty || !viewModel.selectedManufacturers.isEmpty || viewModel.selectedStore != nil)
    }

    // Active filters for empty state display
    private var activeFiltersForEmptyState: [String] {
        var activeFilters: [String] = []
        if !viewModel.selectedTags.isEmpty {
            activeFilters.append("\(viewModel.selectedTags.count) tag\(viewModel.selectedTags.count == 1 ? "" : "s")")
        }
        if !viewModel.selectedCOEs.isEmpty {
            activeFilters.append("COE \(viewModel.selectedCOEs.map { String($0) }.joined(separator: ", "))")
        }
        if !viewModel.selectedManufacturers.isEmpty {
            activeFilters.append("\(viewModel.selectedManufacturers.count) manufacturer\(viewModel.selectedManufacturers.count == 1 ? "" : "s")")
        }
        if let store = viewModel.selectedStore {
            activeFilters.append("store '\(store)'")
        }
        return activeFilters
    }

    // Helper for sort menu content
    private var sortMenuView: AnyView {
        AnyView(
            Group {
                ForEach(ShoppingListSortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortOption = option
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
        )
    }

    /// Count items per tag based on current filters (excluding tag filter itself)
    private var tagCounts: [String: Int] {
        var allItems = viewModel.shoppingLists.values.flatMap { $0.items }

        // Apply all filters EXCEPT tags
        // Apply search filter
        if !viewModel.searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(viewModel.searchText) {
            let searchMode = SearchTextParser.parseSearchText(viewModel.searchText)
            allItems = allItems.filter { item in
                let allFields = [
                    item.catalogItem.name,
                    item.catalogItem.stable_id,
                    item.catalogItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        // Apply product type filter
        if !viewModel.selectedProductTypes.isEmpty {
            allItems = allItems.filter { item in
                viewModel.selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply manufacturer filter
        if !viewModel.selectedManufacturers.isEmpty {
            allItems = allItems.filter { item in
                viewModel.selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Apply COE filter
        if !viewModel.selectedCOEs.isEmpty {
            allItems = allItems.filter { item in
                if let coe = item.catalogItem.coe {
                    return viewModel.selectedCOEs.contains(coe)
                }
                return false
            }
        }

        // Apply store filter
        if let selectedStore = viewModel.selectedStore {
            allItems = allItems.filter { item in
                item.shoppingListItem.store == selectedStore
            }
        }

        // Count items per tag
        var counts: [String: Int] = [:]
        for item in allItems {
            for tag in item.allTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    private var manufacturerCounts: [String: Int] {
        var allItems = viewModel.shoppingLists.values.flatMap { $0.items }

        // Apply all filters EXCEPT manufacturer
        // Apply search filter
        if !viewModel.searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(viewModel.searchText) {
            let searchMode = SearchTextParser.parseSearchText(viewModel.searchText)
            allItems = allItems.filter { item in
                let allFields = [
                    item.catalogItem.name,
                    item.catalogItem.stable_id,
                    item.catalogItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        // Apply product type filter
        if !viewModel.selectedProductTypes.isEmpty {
            allItems = allItems.filter { item in
                viewModel.selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply tag filter
        if !viewModel.selectedTags.isEmpty {
            allItems = allItems.filter { item in
                !viewModel.selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        // Apply COE filter
        if !viewModel.selectedCOEs.isEmpty {
            allItems = allItems.filter { item in
                if let coe = item.catalogItem.coe {
                    return viewModel.selectedCOEs.contains(coe)
                }
                return false
            }
        }

        // Apply store filter
        if let selectedStore = viewModel.selectedStore {
            allItems = allItems.filter { item in
                item.shoppingListItem.store == selectedStore
            }
        }

        // Count items per manufacturer
        var counts: [String: Int] = [:]
        for item in allItems {
            let manufacturer = item.catalogItem.manufacturer
            counts[manufacturer, default: 0] += 1
        }
        return counts
    }

    private var storeCounts: [String: Int] {
        // Count items per store based on current filters (excluding store filter itself)
        var counts: [String: Int] = [:]

        for (storeName, shoppingList) in viewModel.shoppingLists {
            var filteredItems = shoppingList.items

            // Apply all filters EXCEPT store
            // Apply search filter
            if !viewModel.searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(viewModel.searchText) {
                let searchMode = SearchTextParser.parseSearchText(viewModel.searchText)
                filteredItems = filteredItems.filter { item in
                    let allFields = [
                        item.catalogItem.name,
                        item.catalogItem.stable_id,
                        item.catalogItem.manufacturer
                    ]
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
            }

            // Apply product type filter
            if !viewModel.selectedProductTypes.isEmpty {
                filteredItems = filteredItems.filter { item in
                    viewModel.selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
                }
            }

            // Apply manufacturer filter
            if !viewModel.selectedManufacturers.isEmpty {
                filteredItems = filteredItems.filter { item in
                    viewModel.selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }

            // Apply tag filter
            if !viewModel.selectedTags.isEmpty {
                filteredItems = filteredItems.filter { item in
                    !viewModel.selectedTags.isDisjoint(with: Set(item.allTags))
                }
            }

            // Apply COE filter
            if !viewModel.selectedCOEs.isEmpty {
                filteredItems = filteredItems.filter { item in
                    if let coe = item.catalogItem.coe {
                        return viewModel.selectedCOEs.contains(coe)
                    }
                    return false
                }
            }

            counts[storeName] = filteredItems.count
        }
        return counts
    }

    private var inventoryTypeCounts: [String: Int] {
        // Count items per inventory type based on current filters (excluding inventory type filter itself)
        var allItems = viewModel.shoppingLists.values.flatMap { $0.items }

        // Apply all filters EXCEPT inventory type
        // Apply search filter
        if !viewModel.searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(viewModel.searchText) {
            let searchMode = SearchTextParser.parseSearchText(viewModel.searchText)
            allItems = allItems.filter { item in
                let allFields = [
                    item.catalogItem.name,
                    item.catalogItem.stable_id,
                    item.catalogItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        // Apply product type filter
        if !viewModel.selectedProductTypes.isEmpty {
            allItems = allItems.filter { item in
                viewModel.selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply manufacturer filter
        if !viewModel.selectedManufacturers.isEmpty {
            allItems = allItems.filter { item in
                viewModel.selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Apply tag filter
        if !viewModel.selectedTags.isEmpty {
            allItems = allItems.filter { item in
                !viewModel.selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        // Apply COE filter
        if !viewModel.selectedCOEs.isEmpty {
            allItems = allItems.filter { item in
                if let coe = item.catalogItem.coe {
                    return viewModel.selectedCOEs.contains(coe)
                }
                return false
            }
        }

        // Apply store filter
        if let selectedStore = viewModel.selectedStore {
            allItems = allItems.filter { item in
                item.shoppingListItem.store == selectedStore
            }
        }

        // Count items per type
        var counts: [String: Int] = [:]
        for item in allItems {
            counts[item.shoppingListItem.type, default: 0] += 1
        }
        return counts
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Filter header using reusable ModernFilterHeader component
                ModernFilterHeader(
                    searchTitlesOnly: $viewModel.searchTitlesOnly,
                    sortOption: $viewModel.sortOption,
                    sortOptions: Array(ShoppingListSortOption.allCases),
                    sortOptionIcon: { $0.icon },
                    selectedTags: $viewModel.selectedTags,
                    selectedCOEs: $viewModel.selectedCOEs,
                    selectedManufacturers: $viewModel.selectedManufacturers,
                    showingTagsSheet: $showingAllTags,
                    showingCOESheet: $showingCOESelection,
                    showingManufacturerSheet: $showingManufacturerSelection,
                    productTypeFilter: .init(
                        selectedProductTypes: $viewModel.selectedProductTypes,
                        availableTypes: FeatureFlags.availableProductTypes,
                        displayName: displayNameForProductType,
                        typeCounts: viewModel.productTypeCounts
                    ),
                    storeFilter: .init(
                        selectedStore: $viewModel.selectedStore,
                        availableStores: allAvailableStores,
                        itemCounts: storeCounts,
                        onClear: { viewModel.selectedStore = nil }
                    ),
                    inventoryTypeFilter: .init(
                        selectedType: $viewModel.selectedInventoryType,
                        availableTypes: viewModel.availableInventoryTypes,
                        itemCounts: inventoryTypeCounts,
                        displayName: { GlassTerminologySettings.shared.displayName(for: $0) },
                        onClear: { viewModel.selectedInventoryType = nil }
                    ),
                    coeFilter: .init(
                        selectedCOEs: $viewModel.selectedCOEs,
                        availableCOEs: allAvailableCOEs
                    ),
                    showSort: false  // Sort is in the toolbar instead
                )

                // Usage banner (only show for free tier when not in shopping mode)
                if entitlementService.currentTier == .free && !shoppingModeState.isShoppingModeEnabled {
                    UsageBanner(
                        featureName: "shopping list items",
                        currentCount: shoppingListItemCount,
                        limit: entitlementService.getShoppingListLimit(),
                        filteredCount: viewModel.filteredItems.count,
                        hasSettingsFilters: hasSettingsFiltersActive,
                        onUpgradeTap: {
                            showingUpgradePrompt = true
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Shopping mode instructions
                if shoppingModeState.isShoppingModeEnabled {
                    ShoppingModeInstructionsBanner(
                        isExpanded: $shoppingModeInstructionsExpanded,
                        itemsInBasketCount: itemsInBasketCount,
                        totalItemsInViewCount: totalItemsInViewCount
                    )
                }

                // Main content
                // Check if there are actual items, not just empty store entries
                let hasAnyItems = filteredShoppingLists.values.contains { !$0.items.isEmpty }
                Group {
                    if viewModel.isLoading {
                        LoadingStateView()
                    } else if !hasAnyItems {
                        if shouldShowSearchEmptyState {
                            ShoppingListEmptyStates.searchResults(
                                searchTerm: viewModel.searchText.isEmpty ? nil : viewModel.searchText,
                                activeFilters: activeFiltersForEmptyState,
                                onClearFilters: {
                                    localSearchText = ""  // Sync local state with ViewModel
                                    viewModel.searchText = ""
                                    viewModel.clearFilters()
                                }
                            )
                        } else {
                            ShoppingListEmptyStates.standard(onAddItem: { showingAddItem = true })
                        }
                    } else {
                        shoppingListContent
                    }
                }
                .id(refreshTrigger)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(
                text: $localSearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search shopping list..."
            )
            .onChange(of: localSearchText) { oldValue, newValue in
                // Sync local state to ViewModel - debouncing happens in ViewModel
                viewModel.searchText = newValue
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbar {
                // Custom title: "Shopping List" or green "Checkout" button
                ToolbarItem(placement: .principal) {
                    if shoppingModeState.isShoppingModeEnabled {
                        Button {
                            if shoppingModeState.basketItemCount == 0 {
                                // No items in basket - just cancel shopping mode
                                cancelShoppingMode()
                            } else {
                                // Items in basket - proceed to checkout
                                showingCheckoutSheet = true
                            }
                        } label: {
                            Text("Checkout")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityIdentifier("shopping.checkoutButton.title")
                    } else {
                        Text("Shopping List")
                            .font(.headline)
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    if shoppingModeState.isShoppingModeEnabled {
                        // Cancel button when in shopping mode
                        Button {
                            cancelShoppingMode()
                        } label: {
                            Text("Cancel")
                        }
                        .accessibilityIdentifier("shopping_cancel_button")
                    } else {
                        // Sort button when not in shopping mode
                        Menu {
                            ForEach(ShoppingListSortOption.allCases, id: \.self) { option in
                                Button {
                                    viewModel.sortOption = option
                                } label: {
                                    Label(option.rawValue, systemImage: option.icon)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityIdentifier("shopping_sort_button")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !shoppingModeState.isShoppingModeEnabled {
                        // Start Shopping button when not in shopping mode
                        Button {
                            shoppingModeState.enableShoppingMode()
                        } label: {
                            Image(systemName: "cart")
                        }
                        .accessibilityIdentifier("shopping_start_mode_button")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Check if at limit before showing add screen
                        if let limit = entitlementService.getShoppingListLimit(),
                           shoppingListItemCount >= limit {
                            showingUpgradePrompt = true
                        } else {
                            showingAddItem = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("shopping_add_item_button")
                }
            }
            .sheet(isPresented: $showingAllTags) {
                FilterSelectionSheet.tags(
                    availableTags: allAvailableTags,
                    selectedTags: $viewModel.selectedTags,
                    itemCounts: tagCounts
                )
            }
            .sheet(isPresented: $showingCOESelection) {
                FilterSelectionSheet.coes(
                    availableCOEs: allAvailableCOEs,
                    selectedCOEs: $viewModel.selectedCOEs
                )
            }
            .sheet(isPresented: $showingManufacturerSelection) {
                FilterSelectionSheet.manufacturers(
                    availableManufacturers: allAvailableManufacturers,
                    selectedManufacturers: $viewModel.selectedManufacturers,
                    manufacturerDisplayName: { code in
                        GlassManufacturers.fullName(for: code) ?? code
                    },
                    itemCounts: manufacturerCounts
                )
            }
            .sheet(isPresented: $showingStoreSelection) {
                FilterSelectionSheet.stores(
                    availableStores: allAvailableStores,
                    selectedStores: Binding(
                        get: { viewModel.selectedStore.map { Set([$0]) } ?? [] },
                        set: { viewModel.selectedStore = $0.first }
                    )
                )
            }
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "shopping list items",
                    currentCount: shoppingListItemCount,
                    limit: entitlementService.getShoppingListLimit() ?? 10
                )
            }
            .sheet(isPresented: $showingAddItem, onDismiss: {
                // Add delay for Core Data sync like in InventoryView
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await loadShoppingList()
                }
            }) {
                NavigationStack {
                    AddShoppingListItemView(
                        deps: .shared
                    )
                }
            }
            .task {
                await loadShoppingList()
            }
            // NOTE: Removed .onAppear - it was causing duplicate concurrent calls with .task
            // .task already handles initial load when view appears
            .onShoppingListNotifications(
                loadShoppingList: loadShoppingList,
                setSelectedStore: { viewModel.selectedStore = $0 }
            )
            .alert("Keep Basket Items?", isPresented: $showingExitShoppingModeAlert) {
                Button("Keep Items", role: .cancel) {
                    shoppingModeState.disableShoppingMode()
                }
                Button("Clear Basket", role: .destructive) {
                    shoppingModeState.clearBasket()
                    shoppingModeState.disableShoppingMode()
                }
            } message: {
                Text("You have \(shoppingModeState.basketItemCount) item(s) in your basket. Do you want to keep them for next time?")
            }
            .sheet(isPresented: $showingCheckoutSheet) {
                CheckoutSheet(
                    basketItems: itemsInBasket,
                    shoppingModeState: shoppingModeState,
                    inventoryTrackingService: inventoryTrackingService,
                    shoppingListService: shoppingListService,
                    purchaseService: purchaseService,
                    subscriptionService: subscriptionService,
                    onComplete: {
                        Task {
                            await loadShoppingList()
                        }
                    },
                    onExitWithoutCheckout: {
                        // Trigger the same cancelShoppingMode flow
                        cancelShoppingMode()
                    }
                )
            }
            .navigationDestination(for: CompleteInventoryItemModel.self) { item in
                InventoryDetailView(
                    item: item,
                    deps: .shared
                )
            }
        }
    }


    private var shoppingListContent: some View {
        List {
            if shoppingModeState.isShoppingModeEnabled {
                // Shopping mode: split into basket sections
                if !itemsNotInBasket.isEmpty {
                    Section {
                        if toAddToBasketExpanded {
                            ForEach(itemsNotInBasket, id: \.shoppingListItem.item_stable_id) { item in
                                let rowView = GlassItemRowView.shoppingList(
                                    item: item,
                                    showStore: true,
                                    isShoppingMode: true,
                                    isInBasket: false,
                                    quantity: Binding(
                                        get: {
                                            shoppingModeState.getQuantity(for: item.catalogItem.stable_id) ?? item.shoppingListItem.neededQuantity
                                        },
                                        set: { newValue in
                                            shoppingModeState.setQuantity(for: item.catalogItem.stable_id, quantity: newValue)
                                        }
                                    ),
                                    onBasketToggle: {
                                        shoppingModeState.toggleBasket(item_stable_id: item.catalogItem.stable_id)
                                    }
                                )

                                HStack(spacing: 12) {
                                    // Leading accessory (checkbox + quantity) stays interactive
                                    if let leadingAccessory = rowView.leadingAccessory {
                                        leadingAccessory
                                    }

                                    // Thumbnail (not clickable)
                                    rowView.thumbnail

                                    // Only the text content is tappable for navigation
                                    Button {
                                        navigationPath.append(toCompleteInventoryItem(item))
                                    } label: {
                                        HStack {
                                            rowView.textContent
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                .accessibilityIdentifier("shopping.item.\(item.catalogItem.stable_id)")
                            }
                            .onDelete { indexSet in
                                Task {
                                    for index in indexSet {
                                        await deleteShoppingItem(itemsNotInBasket[index])
                                    }
                                }
                            }
                        }
                    } header: {
                        Button {
                            withAnimation {
                                toAddToBasketExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Text("To Add to Basket (\(itemsNotInBasket.count))")
                                Spacer()
                                Image(systemName: toAddToBasketExpanded ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !itemsInBasket.isEmpty {
                    Section(header: Text("In Basket (\(itemsInBasket.count))")) {
                        ForEach(itemsInBasket, id: \.shoppingListItem.item_stable_id) { item in
                            let rowView = GlassItemRowView.shoppingList(
                                item: item,
                                showStore: true,
                                isShoppingMode: true,
                                isInBasket: true,
                                quantity: Binding(
                                    get: {
                                        shoppingModeState.getQuantity(for: item.catalogItem.stable_id) ?? item.shoppingListItem.neededQuantity
                                    },
                                    set: { newValue in
                                        shoppingModeState.setQuantity(for: item.catalogItem.stable_id, quantity: newValue)
                                    }
                                ),
                                onBasketToggle: {
                                    shoppingModeState.toggleBasket(item_stable_id: item.catalogItem.stable_id)
                                }
                            )

                            HStack(spacing: 12) {
                                // Leading accessory (checkbox + quantity) stays interactive
                                if let leadingAccessory = rowView.leadingAccessory {
                                    leadingAccessory
                                }

                                // Thumbnail (not clickable)
                                rowView.thumbnail

                                // Only the text content is tappable for navigation
                                Button {
                                    navigationPath.append(toCompleteInventoryItem(item))
                                } label: {
                                    HStack {
                                        rowView.textContent
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .accessibilityIdentifier("shopping.item.\(item.catalogItem.stable_id)")
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await deleteShoppingItem(itemsInBasket[index])
                                }
                            }
                        }
                    }
                }
            } else if shouldGroupByStore {
                // Grouped by store
                ForEach(sortedStores, id: \.self) { (store: String) in
                    if let list = filteredShoppingLists[store] {
                        Section(header: storeHeader(store: store, itemCount: list.totalItems)) {
                            if expandedStores.contains(store) {
                                ForEach(sortedItems(for: list), id: \.shoppingListItem.item_stable_id) { (item: DetailedShoppingListItemModel) in
                                    NavigationLink(value: item.completeItem) {
                                        GlassItemRowView.shoppingList(item: item)
                                    }
                                    .accessibilityIdentifier("shopping.item.\(item.catalogItem.stable_id)")
                                }
                                .onDelete { indexSet in
                                    Task {
                                        let items = sortedItems(for: list)
                                        for index in indexSet {
                                            await deleteShoppingItem(items[index])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if shouldGroupByManufacturer {
                // Grouped by manufacturer
                ForEach(sortedManufacturers, id: \.self) { manufacturer in
                    if let items = itemsGroupedByManufacturer[manufacturer] {
                        Section(header: manufacturerHeader(manufacturer: manufacturer, itemCount: items.count)) {
                            if expandedManufacturers.contains(manufacturer) {
                                ForEach(sortedManufacturerItems(items), id: \.shoppingListItem.item_stable_id) { item in
                                    NavigationLink(value: item.completeItem) {
                                        GlassItemRowView.shoppingList(item: item, showStore: true)
                                    }
                                    .accessibilityIdentifier("shopping.item.\(item.catalogItem.stable_id)")
                                }
                                .onDelete { indexSet in
                                    Task {
                                        let sortedItems = sortedManufacturerItems(items)
                                        for index in indexSet {
                                            await deleteShoppingItem(sortedItems[index])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // Flat list (no grouping by store or manufacturer)
                ForEach(allFlattenedItems, id: \.shoppingListItem.item_stable_id) { item in
                    NavigationLink(value: item.completeItem) {
                        GlassItemRowView.shoppingList(item: item, showStore: true)
                    }
                    .accessibilityIdentifier("shopping.item.\(item.catalogItem.stable_id)")
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await deleteShoppingItem(allFlattenedItems[index])
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("shopping.list")
    }

    private func sortedItems(for list: DetailedShoppingListModel) -> [DetailedShoppingListItemModel] {
        switch viewModel.sortOption {
        case .neededQuantity:
            return list.items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        case .itemName:
            return list.items.sorted { $0.catalogItem.name.localizedCaseInsensitiveCompare($1.catalogItem.name) == .orderedAscending }
        case .store, .manufacturer:
            // Already sorted by store/manufacturer at the section level
            return list.items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        }
    }

    private func sortedManufacturerItems(_ items: [DetailedShoppingListItemModel]) -> [DetailedShoppingListItemModel] {
        // When grouping by manufacturer, sort items by needed quantity
        return items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
    }

    private func storeHeader(store: String, itemCount: Int) -> some View {
        CollapsibleSectionHeader.withItemCount(
            title: store,
            itemCount: itemCount,
            isExpanded: expandedStores.contains(store),
            onToggle: {
                withAnimation {
                    if expandedStores.contains(store) {
                        expandedStores.remove(store)
                    } else {
                        expandedStores.insert(store)
                    }
                }
            }
        )
    }

    private func manufacturerHeader(manufacturer: String, itemCount: Int) -> some View {
        CollapsibleSectionHeader.withItemCount(
            title: manufacturer,
            itemCount: itemCount,
            isExpanded: expandedManufacturers.contains(manufacturer),
            onToggle: {
                withAnimation {
                    if expandedManufacturers.contains(manufacturer) {
                        expandedManufacturers.remove(manufacturer)
                    } else {
                        expandedManufacturers.insert(manufacturer)
                    }
                }
            }
        )
    }

    // MARK: - Helper Methods

    /// Convert DetailedShoppingListItemModel to CompleteInventoryItemModel for navigation
    private func toCompleteInventoryItem(_ item: DetailedShoppingListItemModel) -> CompleteInventoryItemModel {
        CompleteInventoryItemModel(
            catalogItem: item.catalogItem,
            inventory: [], // Will be loaded by detail view
            tags: item.tags,
            userTags: item.userTags,
            rating: nil
        )
    }

    // MARK: - Custom Deletion Pattern
    //
    // ⚠️ IMPORTANT: This view does NOT use CachedDataDeletion protocol
    // (see Molten/Sources/Utilities/DeletionHelpers.swift)
    //
    // WHY: ShoppingListView has a complex nested data structure:
    //      Dictionary<String, DetailedShoppingListModel> where each model contains an array of items
    //      This requires custom cache manipulation logic (mapValues + filter)
    //
    // PATTERN: This implementation follows the SAME three-step pattern as CachedDataDeletion:
    //   1. Delete from database (performDeletion)
    //   2. Immediate cache removal (removeFromCache) - custom logic for nested structure
    //   3. Deferred reload (reloadData) - 0.3s delay prevents animation crashes
    //
    // ⚠️ MAINTENANCE: If you update DeletionHelpers.swift, apply equivalent changes here:
    //   - Timing (currently 0.3s / 300_000_000 nanoseconds)
    //   - Error handling pattern
    //   - Cache update sequence
    //
    private func deleteShoppingItem(_ item: DetailedShoppingListItemModel) async {
        do {
            // Step 1: Delete from database
            try await shoppingListRepository.deleteItem(forItem: item.catalogItem.stable_id)

            // Step 2: Immediately update the view model to remove the deleted item
            // This ensures counters and other UI elements update right away
            // No full reload needed - just update local state to avoid image flashing
            await MainActor.run {
                // Remove from the view model's shopping lists by creating new filtered dictionaries
                // (Custom logic needed because of nested Dictionary<String, DetailedShoppingListModel> structure)
                viewModel.shoppingLists = viewModel.shoppingLists.mapValues { list in
                    let filteredItems = list.items.filter { $0.shoppingListItem.item_stable_id != item.catalogItem.stable_id }
                    return DetailedShoppingListModel(
                        store: list.store,
                        items: filteredItems,
                        totalItems: filteredItems.count
                    )
                }
                // Remove empty stores
                viewModel.shoppingLists = viewModel.shoppingLists.filter { !$0.value.items.isEmpty }
                updateCaches()
            }
        } catch {
            print("❌ Failed to delete shopping item: \(error)")
        }
    }


    private func loadShoppingList() async {
        await viewModel.loadShoppingLists()

        // Update view-specific caches and state
        updateCaches()  // PERFORMANCE: Update cached filter values

        // Initialize all stores as expanded by default
        expandedStores = Set(viewModel.shoppingLists.keys)

        // Initialize all manufacturers as expanded by default
        expandedManufacturers = Set(cachedAllManufacturers)

        refreshTrigger += 1  // Force SwiftUI to refresh the list
    }

    private func cancelShoppingMode() {
        // Canceling shopping mode
        if shoppingModeState.hasItemsInBasket {
            // Show alert to ask about keeping basket items
            showingExitShoppingModeAlert = true
        } else {
            // No items in basket, just exit
            shoppingModeState.disableShoppingMode()
        }
    }

    private func displayNameForProductType(_ type: String) -> String {
        switch type.lowercased() {
        case "glass": return "Glass"
        case "coating": return "Coatings"
        case "tool": return "Tools"
        default: return type.capitalized
        }
    }
}

// MARK: - Notification Handlers Modifier
// Extracted to reduce body complexity and help Swift compiler

private struct ShoppingListNotificationHandlersModifier: ViewModifier {
    let loadShoppingList: () async -> Void
    let setSelectedStore: (String) -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { _ in
                Task {
                    await loadShoppingList()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryChanged)) { _ in
                Task {
                    // Refresh after QR scan inventory changes
                    await loadShoppingList()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .shoppingListItemAdded)) { _ in
                Task {
                    await loadShoppingList()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .filterShoppingListByStore)) { notification in
                if let storeName = notification.userInfo?["storeName"] as? String {
                    setSelectedStore(storeName)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
                // Refresh view when subscription changes (removes limit warnings)
                Task {
                    await loadShoppingList()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitImportCompleted)) { _ in
                // Refresh shopping list when CloudKit import completes (e.g., after fresh install)
                Task {
                    await loadShoppingList()
                }
            }
    }
}

private extension View {
    func onShoppingListNotifications(
        loadShoppingList: @escaping () async -> Void,
        setSelectedStore: @escaping (String) -> Void
    ) -> some View {
        modifier(ShoppingListNotificationHandlersModifier(
            loadShoppingList: loadShoppingList,
            setSelectedStore: setSelectedStore
        ))
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return ShoppingListView(deps: deps)
}
