//
//  ShoppingListView.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import SwiftUI

struct ShoppingListView: View {
    private let shoppingListService: ShoppingListService

    @State private var shoppingLists: [String: DetailedShoppingListModel] = [:]
    @State private var isLoading = false

    // Search and filter state
    @State private var searchText = ""
    @State private var searchTitlesOnly = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var selectedManufacturers: Set<String> = []  // Not used, but required for SearchAndFilterHeader
    @State private var showingManufacturerSelection = false      // Not used, but required for SearchAndFilterHeader
    @State private var selectedStore: String? = nil
    @State private var showingStoreSelection = false
    @State private var searchClearedFeedback = false
    @State private var sortOption: SortOption = .neededQuantity
    @State private var showingAddItem = false
    @State private var refreshTrigger = 0  // Force SwiftUI to refresh list

    // Shopping mode state
    @StateObject private var shoppingModeState = ShoppingModeState.shared
    @State private var showingExitShoppingModeAlert = false
    @State private var showingCheckoutSheet = false
    @State private var shoppingModeInstructionsExpanded = true

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedAllStores: [String] = []

    enum SortOption: String, CaseIterable {
        case neededQuantity = "Needed Quantity"
        case itemName = "Item Name"
        case store = "Store"

        var icon: String {
            switch self {
            case .neededQuantity: return "exclamationmark.triangle.fill"
            case .itemName: return "textformat.abc"
            case .store: return "building.2"
            }
        }
    }

    init(shoppingListService: ShoppingListService) {
        self.shoppingListService = shoppingListService
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

    /// Recompute caches when shopping list data changes
    /// This is expensive (O(n)) so only call when data actually changes
    private func updateCaches() {
        let allItems = shoppingLists.values.flatMap { $0.items }

        // Extract all tags and COEs
        var allTagsSet = Set<String>()
        var allCOEsSet = Set<Int32>()

        for item in allItems {
            allTagsSet.formUnion(item.tags)
            allCOEsSet.insert(item.glassItem.coe)
        }

        cachedAllTags = allTagsSet.sorted()
        cachedAllCOEs = allCOEsSet.sorted()
        cachedAllStores = Array(shoppingLists.keys).sorted()
    }

    private var filteredShoppingLists: [String: DetailedShoppingListModel] {
        var filtered = shoppingLists

        // Apply store filter
        if let selectedStore = selectedStore {
            filtered = filtered.filter { $0.key == selectedStore }
        }

        // Apply search filter
        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    let allFields = [
                        item.glassItem.name,
                        item.glassItem.natural_key,
                        item.glassItem.manufacturer,
                        item.glassItem.sku
                    ]
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count,
                    totalValue: list.totalValue
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    !selectedTags.isDisjoint(with: Set(item.tags))
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count,
                    totalValue: list.totalValue
                )
            }.filter { !$0.value.items.isEmpty }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            filtered = filtered.mapValues { list in
                let filteredItems = list.items.filter { item in
                    selectedCOEs.contains(item.glassItem.coe)
                }
                return DetailedShoppingListModel(
                    store: list.store,
                    items: filteredItems,
                    totalItems: filteredItems.count,
                    totalValue: list.totalValue
                )
            }.filter { !$0.value.items.isEmpty }
        }

        return filtered
    }

    // Should we group by store? Only when explicitly sorting by store
    private var shouldGroupByStore: Bool {
        sortOption == .store
    }

    // All items flattened (for non-grouped view)
    private var allFlattenedItems: [DetailedShoppingListItemModel] {
        let allItems = filteredShoppingLists.values.flatMap { $0.items }
        switch sortOption {
        case .neededQuantity:
            return allItems.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        case .itemName:
            return allItems.sorted { $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending }
        case .store:
            // Group by store (handled separately)
            return allItems
        }
    }

    // Items split by basket status (for shopping mode)
    private var itemsNotInBasket: [DetailedShoppingListItemModel] {
        allFlattenedItems.filter { !shoppingModeState.isInBasket(itemNaturalKey: $0.glassItem.natural_key) }
    }

    private var itemsInBasket: [DetailedShoppingListItemModel] {
        allFlattenedItems.filter { shoppingModeState.isInBasket(itemNaturalKey: $0.glassItem.natural_key) }
    }

    private var sortedStores: [String] {
        switch sortOption {
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
        case .store:
            // Sort stores alphabetically (same as itemName for stores)
            return filteredShoppingLists.keys.sorted()
        }
    }

    // Helper to determine if we should show search empty state
    private var shouldShowSearchEmptyState: Bool {
        !shoppingLists.isEmpty && (!searchText.isEmpty || !selectedTags.isEmpty || !selectedCOEs.isEmpty || selectedStore != nil)
    }

    // Helper for sort menu content
    private var sortMenuView: AnyView {
        AnyView(
            Group {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
        )
    }

    /// Count items per tag based on current filters (excluding tag filter itself)
    private var tagCounts: [String: Int] {
        let allItems = shoppingLists.values.flatMap { $0.items }

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
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter controls
                SearchAndFilterHeader(
                    searchText: $searchText,
                    searchTitlesOnly: $searchTitlesOnly,
                    selectedTags: $selectedTags,
                    showingAllTags: $showingAllTags,
                    allAvailableTags: allAvailableTags,
                    selectedCOEs: $selectedCOEs,
                    showingCOESelection: $showingCOESelection,
                    allAvailableCOEs: allAvailableCOEs,
                    selectedManufacturers: $selectedManufacturers,
                    showingManufacturerSelection: $showingManufacturerSelection,
                    allAvailableManufacturers: [],  // Not used in shopping list view
                    sortMenuContent: { sortMenuView },
                    searchClearedFeedback: $searchClearedFeedback,
                    searchPlaceholder: "Search shopping list..."
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
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredShoppingLists.isEmpty {
                    if shouldShowSearchEmptyState {
                        searchEmptyStateView
                    } else {
                        emptyStateView
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
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        NotificationCenter.default.post(name: .showSettings, object: nil)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    Button {
                        NotificationCenter.default.post(name: .showSettings, object: nil)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                #endif

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
                            Label("Checkout", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(shoppingModeState.basketItemCount == 0)
                    } else {
                        // Start Shopping button when not in shopping mode
                        Button {
                            shoppingModeState.enableShoppingMode()
                        } label: {
                            Label("Start Shopping", systemImage: "cart")
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAllTags) {
                FilterSelectionSheet.tags(
                    availableTags: allAvailableTags,
                    selectedTags: $selectedTags,
                    itemCounts: tagCounts
                )
            }
            .sheet(isPresented: $showingCOESelection) {
                FilterSelectionSheet.coes(
                    availableCOEs: allAvailableCOEs,
                    selectedCOEs: $selectedCOEs
                )
            }
            .sheet(isPresented: $showingStoreSelection) {
                FilterSelectionSheet.stores(
                    availableStores: allAvailableStores,
                    selectedStores: Binding(
                        get: { selectedStore.map { Set([$0]) } ?? [] },
                        set: { selectedStore = $0.first }
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
                        shoppingListService: shoppingListService
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
                    inventoryTrackingService: RepositoryFactory.createInventoryTrackingService(),
                    shoppingListService: shoppingListService,
                    purchaseService: RepositoryFactory.createPurchaseRecordService(),
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
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 80))
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

    private var searchEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(.title2)
                .fontWeight(.bold)

            Text("No items match your search or filter criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shoppingListContent: some View {
        List {
            if shoppingModeState.isShoppingModeEnabled {
                // Shopping mode: split into basket sections
                if !itemsNotInBasket.isEmpty {
                    Section(header: Text("To Add to Basket (\(itemsNotInBasket.count))")) {
                        ForEach(itemsNotInBasket, id: \.shoppingListItem.itemNaturalKey) { item in
                            GlassItemRowView.shoppingList(
                                item: item,
                                showStore: true,
                                isShoppingMode: true,
                                isInBasket: false,
                                onBasketToggle: {
                                    shoppingModeState.toggleBasket(itemNaturalKey: item.glassItem.natural_key)
                                }
                            )
                        }
                    }
                }

                if !itemsInBasket.isEmpty {
                    Section(header: Text("In Basket (\(itemsInBasket.count))")) {
                        ForEach(itemsInBasket, id: \.shoppingListItem.itemNaturalKey) { item in
                            GlassItemRowView.shoppingList(
                                item: item,
                                showStore: true,
                                isShoppingMode: true,
                                isInBasket: true,
                                onBasketToggle: {
                                    shoppingModeState.toggleBasket(itemNaturalKey: item.glassItem.natural_key)
                                }
                            )
                        }
                    }
                }
            } else if shouldGroupByStore {
                // Grouped by store
                ForEach(sortedStores, id: \.self) { store in
                    if let list = filteredShoppingLists[store] {
                        Section(header: storeHeader(store: store, itemCount: list.totalItems)) {
                            ForEach(sortedItems(for: list), id: \.shoppingListItem.itemNaturalKey) { item in
                                GlassItemRowView.shoppingList(item: item)
                            }
                        }
                    }
                }
            } else {
                // Flat list (no grouping by store)
                ForEach(allFlattenedItems, id: \.shoppingListItem.itemNaturalKey) { item in
                    GlassItemRowView.shoppingList(item: item, showStore: true)
                }
            }
        }
        .id(refreshTrigger)  // Force list to refresh when trigger changes
    }

    private func sortedItems(for list: DetailedShoppingListModel) -> [DetailedShoppingListItemModel] {
        switch sortOption {
        case .neededQuantity:
            return list.items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        case .itemName:
            return list.items.sorted { $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending }
        case .store:
            // Already sorted by store at the section level
            return list.items.sorted { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        }
    }

    private func storeHeader(store: String, itemCount: Int) -> some View {
        HStack {
            Text(store)
                .font(.headline)
            Spacer()
            Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
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
                        .font(.caption)
                        .foregroundColor(.secondary)
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

                if let selectedStore = selectedStore {
                    Text(selectedStore)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .lineLimit(1)

                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.caption)
                        .onTapGesture {
                            withAnimation {
                                self.selectedStore = nil
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
            .foregroundColor(selectedStore == nil ? DesignSystem.Colors.textSecondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip + DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Padding.buttonVertical)
            .background(selectedStore == nil ? DesignSystem.Colors.backgroundInput : DesignSystem.Colors.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private func loadShoppingList() async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("🛒 ShoppingListView: Loading shopping list...")
            shoppingLists = try await shoppingListService.generateAllShoppingLists()
            updateCaches()  // PERFORMANCE: Update cached filter values
            refreshTrigger += 1  // Force SwiftUI to refresh the list
            print("🛒 ShoppingListView: Loaded \(shoppingLists.count) stores with \(shoppingLists.values.flatMap { $0.items }.count) total items")
        } catch {
            print("❌ ShoppingListView: Error loading shopping list: \(error)")
            shoppingLists = [:]
            updateCaches()  // Clear caches on error
        }
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
        quantities[item.glassItem.natural_key] ?? item.shoppingListItem.neededQuantity
    }

    private func setQuantity(for item: DetailedShoppingListItemModel, value: Double) {
        quantities[item.glassItem.natural_key] = value
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
                        ForEach(basketItems, id: \.glassItem.natural_key) { item in
                            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                // Item info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.glassItem.name)
                                        .font(.headline)
                                    Text(item.glassItem.natural_key)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
                        if quantities[item.glassItem.natural_key] == nil {
                            quantities[item.glassItem.natural_key] = item.shoppingListItem.neededQuantity
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
                    let quantity = quantities[item.glassItem.natural_key] ?? item.shoppingListItem.neededQuantity
                    return PurchaseRecordItemModel(
                        itemNaturalKey: item.glassItem.natural_key,
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
                    let quantity = quantities[item.glassItem.natural_key] ?? item.shoppingListItem.neededQuantity
                    let itemKey = item.glassItem.natural_key

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
                        forItem: item.glassItem.natural_key
                    )
                    print("  ✓ Removed \(item.glassItem.natural_key)")
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
    let _ = RepositoryFactory.configureForTesting()
    let shoppingListService = RepositoryFactory.createShoppingListService()
    return ShoppingListView(shoppingListService: shoppingListService)
}
