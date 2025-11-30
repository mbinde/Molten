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
    private var shouldShowSearchEmptyState: Bool {
        !viewModel.shoppingLists.isEmpty && (!viewModel.searchText.isEmpty || !viewModel.selectedTags.isEmpty || !viewModel.selectedCOEs.isEmpty || !viewModel.selectedManufacturers.isEmpty || viewModel.selectedStore != nil)
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
                    )
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
                Group {
                    if viewModel.isLoading {
                        LoadingStateView()
                    } else if filteredShoppingLists.isEmpty {
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
                    viewModel.selectedStore = storeName
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
                // Refresh view when subscription changes (removes limit warnings)
                Task {
                    await loadShoppingList()
                }
            }
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

// MARK: - Checkout Sheet

struct CheckoutSheet: View {
    let basketItems: [DetailedShoppingListItemModel]
    let shoppingModeState: ShoppingModeState
    let inventoryTrackingService: InventoryTrackingService
    let shoppingListService: ShoppingListService
    let purchaseService: PurchaseRecordService?
    let subscriptionService: SubscriptionServiceProtocol
    let onComplete: () -> Void
    let onExitWithoutCheckout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var addToInventory = true
    @State private var removeFromList = true
    @State private var createPurchaseRecord = false
    @State private var isProcessing = false
    @State private var quantities: [String: Double] = [:] // natural_key -> adjusted quantity
    @State private var showInventoryLimitWarning = false
    @State private var currentInventoryCount = 0

    // Purchase record fields
    @State private var supplier = ""
    @State private var subtotal: String = ""
    @State private var tax: String = ""
    @State private var shipping: String = ""
    @State private var currency = "USD"
    @State private var notes = ""

    // Error handling
    @State private var showCheckoutError = false
    @State private var checkoutErrorMessage = ""

    // Helper methods for quantity binding
    private func getQuantity(for item: DetailedShoppingListItemModel) -> Double {
        quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
    }

    private func setQuantity(for item: DetailedShoppingListItemModel, value: Double) {
        quantities[item.catalogItem.stable_id] = value
    }

    // Sorted basket items by name
    private var sortedBasketItems: [DetailedShoppingListItemModel] {
        basketItems.sorted { $0.catalogItem.name.localizedCaseInsensitiveCompare($1.catalogItem.name) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Checkout options at top
                VStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Checkout Options")
                            .font(.headline)
                            .padding(.horizontal, DesignSystem.Spacing.xs)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Toggle("Add to inventory", isOn: $addToInventory)
                                .tint(.accentColor)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .accessibilityIdentifier("checkout_add_to_inventory_toggle")
                            Toggle("Remove from shopping list", isOn: $removeFromList)
                                .tint(.accentColor)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .accessibilityIdentifier("checkout_remove_from_list_toggle")

                            if FeatureFlags.ENABLE_PURCHASES && purchaseService != nil {
                                Toggle("Create purchase record", isOn: $createPurchaseRecord)
                                    .tint(.accentColor)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                    .accessibilityIdentifier("checkout_create_purchase_toggle")
                            }
                        }

                        // Purchase record fields (shown when toggle is enabled)
                        if FeatureFlags.ENABLE_PURCHASES && createPurchaseRecord && purchaseService != nil {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Purchase Details")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                    .padding(.top, DesignSystem.Spacing.xs)

                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    HStack {
                                        Text("Supplier:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("Supplier name", text: $supplier)
                                            #if os(iOS)
                                            .textFieldStyle(.roundedBorder)
                                            #endif
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.xs)

                                    HStack {
                                        Text("Subtotal:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("0.00", text: $subtotal)
                                            #if os(iOS)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                            #endif
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.xs)

                                    HStack {
                                        Text("Tax:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("0.00", text: $tax)
                                            #if os(iOS)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                            #endif
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.xs)

                                    HStack {
                                        Text("Shipping:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("0.00", text: $shipping)
                                            #if os(iOS)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                            #endif
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.xs)

                                    HStack {
                                        Text("Notes:")
                                            .frame(width: 80, alignment: .leading)
                                        TextField("Optional notes", text: $notes)
                                            #if os(iOS)
                                            .textFieldStyle(.roundedBorder)
                                            #endif
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                                }
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                        }

                        HStack(spacing: DesignSystem.Spacing.md) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .accessibilityIdentifier("checkout_cancel_button")

                            Button(action: {
                                Task {
                                    await performCheckout()
                                }
                            }) {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Checkout")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .disabled(isProcessing)
                            .accessibilityIdentifier("checkout_confirm_button")
                        }
                    }
                }
                .padding()
                #if os(iOS)
                .background(Color(UIColor.systemGroupedBackground))
                #else
                .background(Color(nsColor: NSColor.windowBackgroundColor))
                #endif

                // Items list below
                List {
                    Section(header: Text("Items in Basket (\(sortedBasketItems.count))")) {
                        ForEach(sortedBasketItems, id: \.shoppingListItem.item_stable_id) { item in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                // Item info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.catalogItem.name)
                                        .font(.headline)
                                    Text(item.catalogItem.stable_id)
                                        .secondaryCaption()
                                }

                                Spacer()

                                // Quantity editor
                                VStack(alignment: .trailing, spacing: 2) {
                                    TextField("Qty", value: Binding(
                                        get: { getQuantity(for: item) },
                                        set: { setQuantity(for: item, value: $0) }
                                    ), format: .number)
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    #if os(iOS)
                                    .textFieldStyle(.roundedBorder)
                                    #endif

                                    Text("rod")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .onAppear {
                    // Initialize quantities from shoppingModeState (user-adjusted quantities)
                    for item in basketItems {
                        if quantities[item.catalogItem.stable_id] == nil {
                            // Use the quantity from shopping mode state, or default to needed quantity
                            quantities[item.catalogItem.stable_id] = shoppingModeState.getQuantity(for: item.catalogItem.stable_id) ?? item.shoppingListItem.neededQuantity
                        }
                    }

                    // Check inventory limit for free tier users
                    Task {
                        let isPro = await subscriptionService.hasProAccess()
                        let itemsWithInventory = try? await inventoryTrackingService.getItemsWithInventory()
                        currentInventoryCount = itemsWithInventory?.count ?? 0

                        // Only show warning if user is NOT Pro AND at/over the limit
                        if !isPro && currentInventoryCount >= FeatureFlags.FREE_TIER_INVENTORY_LIMIT {
                            showInventoryLimitWarning = true
                        }
                    }
                }
            }
            .navigationTitle("Checkout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert("Inventory Limit Reached", isPresented: $showInventoryLimitWarning) {
                Button("OK") {
                    // User acknowledged the warning
                    // Disable "Add to inventory" toggle if they're at/over limit
                    addToInventory = false
                }
                Button("Upgrade to Pro") {
                    addToInventory = false
                    Task {
                        try? await subscriptionService.presentPaywall()
                    }
                }
            } message: {
                Text("You currently have \(currentInventoryCount) items in your inventory. Free tier users are limited to \(FeatureFlags.FREE_TIER_INVENTORY_LIMIT) items.\n\nIf you complete this checkout, items will not be added to your inventory unless you upgrade to Pro.")
            }
            .alert("Checkout Error", isPresented: $showCheckoutError) {
                Button("OK") {
                    // User acknowledged the error, they can try again
                }
            } message: {
                Text(checkoutErrorMessage)
            }
        }
    }

    private func performCheckout() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            var purchaseRecordId: UUID? = nil

            // Create purchase record first (if requested)
            if createPurchaseRecord, let purchaseService = purchaseService {
                print("🛒 Checkout: Creating purchase record...")

                // Parse decimal values from string inputs
                let subtotalDecimal = Decimal(string: subtotal.isEmpty ? "0" : subtotal)
                let taxDecimal = Decimal(string: tax.isEmpty ? "0" : tax)
                let shippingDecimal = Decimal(string: shipping.isEmpty ? "0" : shipping)

                // Create line items from basket
                let purchaseItems = basketItems.enumerated().map { index, item in
                    let quantity = quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
                    return PurchaseRecordItemModel(
                        item_stable_id: item.catalogItem.stable_id,
                        type: "rod",  // Default type - could be made configurable
                        quantity: quantity,
                        orderIndex: Int32(index)
                    )
                }

                // Create the purchase record
                let purchaseRecord = PurchaseRecordModel(
                    supplier: supplier.isEmpty ? "Unknown" : supplier,
                    subtotal: subtotalDecimal,
                    tax: taxDecimal,
                    shipping: shippingDecimal,
                    currency: currency,
                    notes: notes.isEmpty ? nil : notes,
                    items: purchaseItems
                )

                let createdRecord = try await purchaseService.createRecord(purchaseRecord)
                purchaseRecordId = createdRecord.id
                print("  ✓ Created purchase record: \(createdRecord.id)")
            }

            // Add to inventory
            if addToInventory {
                print("🛒 Checkout: Adding \(basketItems.count) items to inventory...")
                for item in basketItems {
                    // Use the adjusted quantity from the text field, or default to needed quantity
                    let quantity = quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
                    let itemKey = item.catalogItem.stable_id

                    // Add inventory using the adjusted quantity
                    // Type defaults to "rod" but could be made configurable
                    _ = try await inventoryTrackingService.addInventory(
                        quantity: quantity,
                        type: "rod",
                        toItem: itemKey
                    )
                    print("  ✓ Added \(quantity) of \(itemKey)")
                }
            }

            // Remove from shopping list or adjust quantities
            if removeFromList {
                print("🛒 Checkout: Processing \(basketItems.count) items from shopping list...")
                for item in basketItems {
                    let boughtQuantity = quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
                    let neededQuantity = item.shoppingListItem.neededQuantity

                    if boughtQuantity >= neededQuantity {
                        // Bought enough or more - remove from list completely
                        try await shoppingListService.shoppingListRepository.deleteItem(
                            forItem: item.catalogItem.stable_id
                        )
                        print("  ✓ Removed \(item.catalogItem.stable_id) (bought \(boughtQuantity) of \(neededQuantity) needed)")
                    } else {
                        // Bought less than needed - keep the difference in the shopping list
                        let remainingQuantity = neededQuantity - boughtQuantity
                        try await shoppingListService.shoppingListRepository.updateNeededQuantity(
                            forItem: item.catalogItem.stable_id,
                            neededQuantity: remainingQuantity
                        )
                        print("  ✓ Updated \(item.catalogItem.stable_id) to \(remainingQuantity) remaining (bought \(boughtQuantity) of \(neededQuantity) needed)")
                    }
                }
            }

            if let recordId = purchaseRecordId {
                print("🛒 Checkout: Complete! Purchase record: \(recordId)")
            } else {
                print("🛒 Checkout: Complete!")
            }

            // Clear basket and exit shopping mode
            await MainActor.run {
                shoppingModeState.clearBasket()
                shoppingModeState.disableShoppingMode()
                dismiss()

                // Notify other views to refresh
                if addToInventory {
                    NotificationCenter.default.post(name: .inventoryItemAdded, object: nil)
                }

                onComplete()
            }
        } catch {
            print("❌ Checkout error: \(error)")
            await MainActor.run {
                // Show error alert - don't dismiss so user can try again
                checkoutErrorMessage = "Checkout failed: \(error.localizedDescription)"
                showCheckoutError = true
            }
        }
    }

    private func exitWithoutCheckout() {
        // Dismiss the checkout sheet first
        dismiss()

        // Then trigger the parent's cancelShoppingMode() which shows the alert
        Task { @MainActor in
            // Small delay to let the sheet dismiss first
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Call the parent's exit handler which will show the alert
            onExitWithoutCheckout()
        }
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return ShoppingListView(deps: deps)
}
