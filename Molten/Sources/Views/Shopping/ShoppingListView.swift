//
//  ShoppingListView.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import SwiftUI

struct ShoppingListView: View {
    // MIGRATION COMPLETE: ViewModel manages search, filters, sorting, loading, and data
    @State private var viewModel: ShoppingListViewModel
    private let shoppingListService: ShoppingListService
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let purchaseService: PurchaseRecordService
    private let userNotesRepository: UserNotesRepository
    private let userTagsRepository: UserTagsRepository
    private let shoppingListRepository: ShoppingListRepository
    private let userImageRepository: UserImageRepository
    private let kilnScheduleService: KilnScheduleService
    private let glassItemRepository: GlassItemRepository

    // UI-only state (not in ViewModel)
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

    // Shopping mode state
    @StateObject private var shoppingModeState = ShoppingModeState.shared
    @State private var showingExitShoppingModeAlert = false
    @State private var showingCheckoutSheet = false
    @State private var shoppingModeInstructionsExpanded = true

    // Collapsible store sections state
    @State private var expandedStores: Set<String> = []
    @State private var expandedManufacturers: Set<String> = []

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedAllStores: [String] = []
    @State private var cachedAllManufacturers: [String] = []

    // Accept ViewModel directly (protocol-based pattern)
    init(viewModel: ShoppingListViewModel,
         shoppingListService: ShoppingListService,
         catalogService: CatalogService,
         inventoryTrackingService: InventoryTrackingService,
         purchaseService: PurchaseRecordService,
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
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.userImageRepository = userImageRepository
        self.kilnScheduleService = kilnScheduleService
        self.glassItemRepository = glassItemRepository
    }

    // Convenience init for production use
    init(deps: AppDependencies = AppDependencies()) {
        let viewModel = ShoppingListViewModel(shoppingListService: deps.shoppingListService)
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
            allCOEsSet.insert(item.glassItem.coe)

            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
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
                        item.glassItem.name,
                        item.glassItem.stable_id,
                        item.glassItem.manufacturer,
                        item.glassItem.sku
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

        // Apply COE filter
        if !viewModel.selectedCOEs.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    viewModel.selectedCOEs.contains(item.glassItem.coe)
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
                    viewModel.selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
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
            return allItems.sorted { $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending }
        case .store, .manufacturer:
            // Group by store or manufacturer (handled separately)
            return allItems
        }
    }

    // Items split by basket status (for shopping mode)
    private var itemsNotInBasket: [DetailedShoppingListItemModel] {
        allFlattenedItems.filter { !shoppingModeState.isInBasket(item_stable_id: $0.glassItem.stable_id) }
    }

    private var itemsInBasket: [DetailedShoppingListItemModel] {
        allFlattenedItems.filter { shoppingModeState.isInBasket(item_stable_id: $0.glassItem.stable_id) }
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
            let manufacturer = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let allItems = viewModel.shoppingLists.values.flatMap { $0.items }

        // Count items per tag
        var counts: [String: Int] = [:]
        for item in allItems {
            for tag in item.allTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search and filter controls
                // TODO: Migrate to native .searchable() with FilterChipsRow component (see CatalogView)
                StandardSearchAndFilterHeader(
                    searchText: $viewModel.searchText,
                    searchTitlesOnly: $viewModel.searchTitlesOnly,
                    selectedTags: $viewModel.selectedTags,
                    selectedCOEs: $viewModel.selectedCOEs,
                    selectedManufacturers: $viewModel.selectedManufacturers,
                    selectedProductTypes: $selectedProductTypes,
                    showingAllTags: $showingAllTags,
                    showingCOESelection: $showingCOESelection,
                    showingManufacturerSelection: $showingManufacturerSelection,
                    showingProductTypeSelection: $showingProductTypeSelection,
                    allAvailableTags: allAvailableTags,
                    allAvailableCOEs: allAvailableCOEs,
                    allAvailableManufacturers: allAvailableManufacturers,
                    allAvailableProductTypes: ["glass", "coating", "tool"],
                    sortMenuContent: { sortMenuView },
                    searchPlaceholder: "Search shopping list...",
                    searchClearedFeedback: $searchClearedFeedback
                )

                // Store filter (if multiple stores available)
                if allAvailableStores.count > 1 {
                    storeFilterButton
                        .padding(.horizontal, DesignSystem.Padding.standard)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.background)
                }

                // Shopping mode instructions
                if shoppingModeState.isShoppingModeEnabled {
                    shoppingModeInstructions
                }

                // Main content
                if viewModel.isLoading {
                    LoadingStateView()
                } else if filteredShoppingLists.isEmpty {
                    if shouldShowSearchEmptyState {
                        searchEmptyStateView
                    } else {
                        standardizedEmptyStateView
                    }
                } else {
                    shoppingListContent
                }
            }
            .navigationTitle("Shopping List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if shoppingModeState.isShoppingModeEnabled {
                        // Cancel button when in shopping mode
                        Button {
                            cancelShoppingMode()
                        } label: {
                            Text("Cancel")
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if shoppingModeState.isShoppingModeEnabled {
                        // Checkout button when in shopping mode
                        Button {
                            showingCheckoutSheet = true
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .accessibilityIdentifier("shopping.checkoutButton")
                        .disabled(shoppingModeState.basketItemCount == 0)
                    } else {
                        // Start Shopping button when not in shopping mode
                        Button {
                            shoppingModeState.enableShoppingMode()
                        } label: {
                            Image(systemName: "cart")
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
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
                    }
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
            .sheet(isPresented: $showingAddItem, onDismiss: {
                // Add delay for Core Data sync like in InventoryView
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await loadShoppingList()
                }
            }) {
                NavigationStack {
                    AddShoppingListItemView(
                        deps: AppDependencies()
                    )
                }
            }
            .task {
                await loadShoppingList()
            }
            .onAppear {
                Task {
                    await loadShoppingList()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { _ in
                Task {
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
                    deps: AppDependencies()
                )
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 80, weight: .regular))
                .foregroundColor(.secondary)

            Text("No items on your shopping list yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Set minimum quantities in the catalog to automatically generate shopping lists")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                showingAddItem = true
            }) {
                Text("Add to Shopping List")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var standardizedEmptyStateView: some View {
        CustomEmptyStateView(
            icon: "cart",
            title: "No items on your shopping list yet",
            description: "Set minimum quantities in the catalog to automatically generate shopping lists",
            actionButton: .init(
                title: "Add to Shopping List",
                action: { showingAddItem = true },
                style: .prominent
            )
        )
    }

    private var searchEmptyStateView: some View {
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

        return CustomEmptyStateView.searchResults(
            searchTerm: viewModel.searchText.isEmpty ? nil : viewModel.searchText,
            filters: activeFilters,
            onClearFilters: {
                viewModel.searchText = ""
                viewModel.clearFilters()
            }
        )
    }

    private var shoppingListContent: some View {
        List {
            if shoppingModeState.isShoppingModeEnabled {
                // Shopping mode: split into basket sections
                if !itemsNotInBasket.isEmpty {
                    Section(header: Text("To Add to Basket (\(itemsNotInBasket.count))")) {
                        ForEach(itemsNotInBasket, id: \.shoppingListItem.item_stable_id) { item in
                            GlassItemRowView.shoppingList(
                                item: item,
                                showStore: true,
                                isShoppingMode: true,
                                isInBasket: false,
                                onBasketToggle: {
                                    shoppingModeState.toggleBasket(item_stable_id: item.glassItem.stable_id)
                                }
                            )
                            .accessibilityIdentifier("shopping.item.\(item.glassItem.stable_id)")
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    await deleteShoppingItem(itemsNotInBasket[index])
                                }
                            }
                        }
                    }
                }

                if !itemsInBasket.isEmpty {
                    Section(header: Text("In Basket (\(itemsInBasket.count))")) {
                        ForEach(itemsInBasket, id: \.shoppingListItem.item_stable_id) { item in
                            GlassItemRowView.shoppingList(
                                item: item,
                                showStore: true,
                                isShoppingMode: true,
                                isInBasket: true,
                                onBasketToggle: {
                                    shoppingModeState.toggleBasket(item_stable_id: item.glassItem.stable_id)
                                }
                            )
                            .accessibilityIdentifier("shopping.item.\(item.glassItem.stable_id)")
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
                                    .accessibilityIdentifier("shopping.item.\(item.glassItem.stable_id)")
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
                                    .accessibilityIdentifier("shopping.item.\(item.glassItem.stable_id)")
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
                    .accessibilityIdentifier("shopping.item.\(item.glassItem.stable_id)")
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
        .id(refreshTrigger)  // Force list to refresh when trigger changes
    }

    private func sortedItems(for list: DetailedShoppingListModel) -> [DetailedShoppingListItemModel] {
        switch viewModel.sortOption {
        case .neededQuantity:
            return list.items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        case .itemName:
            return list.items.sorted { $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending }
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

    private func deleteShoppingItem(_ item: DetailedShoppingListItemModel) async {
        do {
            // Delete the shopping list item
            try await shoppingListRepository.deleteItem(forItem: item.glassItem.stable_id)

            // Immediately update the view model to remove the deleted item
            // This ensures counters and other UI elements update right away
            await MainActor.run {
                // Remove from the view model's shopping lists by creating new filtered dictionaries
                viewModel.shoppingLists = viewModel.shoppingLists.mapValues { list in
                    let filteredItems = list.items.filter { $0.shoppingListItem.item_stable_id != item.glassItem.stable_id }
                    return DetailedShoppingListModel(
                        store: list.store,
                        items: filteredItems,
                        totalItems: filteredItems.count
                    )
                }
            }

            // Defer full reload to allow .onDelete animation to complete
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
                await viewModel.loadShoppingLists()
                updateCaches()
            }
        } catch {
            print("❌ Failed to delete shopping item: \(error)")
        }
    }

    private var shoppingModeInstructions: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Button(action: {
                withAnimation {
                    shoppingModeInstructionsExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "cart.fill")
                        .foregroundColor(.green)
                    Text("Shopping Mode")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: shoppingModeInstructionsExpanded ? "chevron.up" : "chevron.down")
                        .secondaryCaptionStyle()
                }
            }
            .buttonStyle(.plain)

            if shoppingModeInstructionsExpanded {
                Text("Tap on items to confirm that you've added them to your basket. When you're done, click \"Checkout\" and they'll be removed from your list and added to your inventory.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(Color.green.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal, DesignSystem.Padding.standard)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private var storeFilterButton: some View {
        Button {
            showingStoreSelection = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "building.2")
                    .font(DesignSystem.Typography.captionSmall)

                if let selectedStore = viewModel.selectedStore {
                    Text(selectedStore)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .lineLimit(1)

                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.caption)
                        .onTapGesture {
                            withAnimation {
                                viewModel.selectedStore = nil
                            }
                        }
                } else {
                    Text("All Stores")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(viewModel.selectedStore == nil ? DesignSystem.Colors.textSecondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(viewModel.selectedStore == nil ? DesignSystem.Colors.backgroundInput : DesignSystem.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private func loadShoppingList() async {
        print("🛒 ShoppingListView: Loading shopping list...")
        await viewModel.loadShoppingLists()

        // Update view-specific caches and state
        updateCaches()  // PERFORMANCE: Update cached filter values

        // Initialize all stores as expanded by default
        expandedStores = Set(viewModel.shoppingLists.keys)

        // Initialize all manufacturers as expanded by default
        expandedManufacturers = Set(cachedAllManufacturers)

        refreshTrigger += 1  // Force SwiftUI to refresh the list
        print("🛒 ShoppingListView: Loaded \(viewModel.shoppingLists.count) stores with \(viewModel.shoppingLists.values.flatMap { $0.items }.count) total items")
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
}

// MARK: - Checkout Sheet

struct CheckoutSheet: View {
    let basketItems: [DetailedShoppingListItemModel]
    let shoppingModeState: ShoppingModeState
    let inventoryTrackingService: InventoryTrackingService
    let shoppingListService: ShoppingListService
    let purchaseService: PurchaseRecordService?
    let onComplete: () -> Void
    let onExitWithoutCheckout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var addToInventory = true
    @State private var removeFromList = true
    @State private var createPurchaseRecord = false
    @State private var isProcessing = false
    @State private var quantities: [String: Double] = [:] // natural_key -> adjusted quantity

    // Purchase record fields
    @State private var supplier = ""
    @State private var subtotal: String = ""
    @State private var tax: String = ""
    @State private var shipping: String = ""
    @State private var currency = "USD"
    @State private var notes = ""

    // Helper methods for quantity binding
    private func getQuantity(for item: DetailedShoppingListItemModel) -> Double {
        quantities[item.glassItem.stable_id] ?? item.shoppingListItem.neededQuantity
    }

    private func setQuantity(for item: DetailedShoppingListItemModel, value: Double) {
        quantities[item.glassItem.stable_id] = value
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Action buttons at top
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Exit without checkout (red button)
                    Button(action: {
                        exitWithoutCheckout()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Exit Shopping Mode Without Checking Out")
                                .fontWeight(.medium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.medium)

                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.xs)

                    // Checkout options
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Checkout Options")
                            .font(.headline)
                            .padding(.horizontal, DesignSystem.Spacing.xs)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Toggle("Add to inventory", isOn: $addToInventory)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                            Toggle("Remove from shopping list", isOn: $removeFromList)
                                .padding(.horizontal, DesignSystem.Spacing.xs)

                            if purchaseService != nil {
                                Toggle("Create purchase record", isOn: $createPurchaseRecord)
                                    .padding(.horizontal, DesignSystem.Spacing.xs)
                            }
                        }

                        // Purchase record fields (shown when toggle is enabled)
                        if createPurchaseRecord && purchaseService != nil {
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
                    Section(header: Text("Items in Basket (\(basketItems.count))")) {
                        ForEach(basketItems, id: \.glassItem.stable_id) { item in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                // Item info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.glassItem.name)
                                        .font(.headline)
                                    Text(item.glassItem.stable_id)
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
                    // Initialize quantities with needed amounts
                    for item in basketItems {
                        if quantities[item.glassItem.stable_id] == nil {
                            quantities[item.glassItem.stable_id] = item.shoppingListItem.neededQuantity
                        }
                    }
                }
            }
            .navigationTitle("Checkout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                    let quantity = quantities[item.glassItem.stable_id] ?? item.shoppingListItem.neededQuantity
                    return PurchaseRecordItemModel(
                        item_stable_id: item.glassItem.stable_id,
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
                    let quantity = quantities[item.glassItem.stable_id] ?? item.shoppingListItem.neededQuantity
                    let itemKey = item.glassItem.stable_id

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

            // Remove from shopping list
            if removeFromList {
                print("🛒 Checkout: Removing \(basketItems.count) items from shopping list...")
                for item in basketItems {
                    try await shoppingListService.shoppingListRepository.deleteItem(
                        forItem: item.glassItem.stable_id
                    )
                    print("  ✓ Removed \(item.glassItem.stable_id)")
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
            // TODO: Show error alert to user
            // For now, still exit shopping mode but alert the user
            await MainActor.run {
                // Don't clear the basket or exit shopping mode on error
                // so the user can try again
                dismiss()
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
