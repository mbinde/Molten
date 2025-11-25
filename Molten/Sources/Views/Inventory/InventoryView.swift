//
//
//  InventoryView.swift
//  Flameworker
//
//  Migrated to Repository Pattern on 10/12/25 by Assistant
//  Updated for GlassItem architecture on 10/14/25
//

import SwiftUI
import Foundation
import OSLog
import CoreData

enum InventorySearchScope: String, CaseIterable {
    case allFields = "All fields"
    case titlesOnly = "Only titles"
}

/// Repository-based InventoryView that uses the new GlassItem architecture
struct InventoryView: View, CachedDataDeletion {
    // MIGRATION COMPLETE: ViewModel manages search, filters, sorting, loading, and data
    @State private var viewModel: InventoryViewModel
    @Environment(EntitlementService.self) private var entitlementService

    // Search scope state
    @State private var searchScope: InventorySearchScope = .allFields

    // Performance timing (DEBUG builds only)
    @State private var performanceTimer = PerformanceTimer()

    // UI-only state (not in ViewModel)
    @State private var showingAddItem = false
    @State private var showingUpgradePrompt = false
    @State private var prefilledNaturalKey: String = ""
    @State private var navigationPath = NavigationPath()
    @State private var showingAddFromCatalog = false
    @State private var showingAllTags = false
    @State private var showingCOESelection = false
    @State private var showingManufacturerSelection = false
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var refreshTrigger = 0  // Force SwiftUI to refresh list
    @State private var showingLabelDesigner = false
    @State private var showingSharing = false
    @State private var pendingShareCode: String? = nil

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedManufacturers: [String] = []
    @State private var cachedLocations: [String] = []

    // CRITICAL: Service instances (not optional - always provided)
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let userNotesRepository: UserNotesRepository
    private let userTagsRepository: UserTagsRepository
    private let shoppingListRepository: ShoppingListRepository
    private let userImageRepository: UserImageRepository
    private let kilnScheduleService: KilnScheduleService
    private let glassItemRepository: GlassItemRepository
    private let storageLocationRepository: StorageLocationRepository

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Flameworker", category: "InventoryView")

    // Accept ViewModel directly (protocol-based pattern)
    init(
        viewModel: InventoryViewModel,
        catalogService: CatalogService,
        inventoryTrackingService: InventoryTrackingService,
        userNotesRepository: UserNotesRepository,
        userTagsRepository: UserTagsRepository,
        shoppingListRepository: ShoppingListRepository,
        userImageRepository: UserImageRepository,
        kilnScheduleService: KilnScheduleService,
        glassItemRepository: GlassItemRepository,
        storageLocationRepository: StorageLocationRepository
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.userImageRepository = userImageRepository
        self.kilnScheduleService = kilnScheduleService
        self.glassItemRepository = glassItemRepository
        self.storageLocationRepository = storageLocationRepository
    }

    // Convenience init for production use
    init(deps: AppDependencies = AppDependencies()) {
        let viewModel = InventoryViewModel(
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService
        )
        self.init(
            viewModel: viewModel,
            catalogService: deps.catalogService,
            inventoryTrackingService: deps.inventoryTrackingService,
            userNotesRepository: deps.userNotesRepository,
            userTagsRepository: deps.userTagsRepository,
            shoppingListRepository: deps.shoppingListRepository,
            userImageRepository: deps.userImageRepository,
            kilnScheduleService: deps.kilnScheduleService,
            glassItemRepository: deps.glassItemRepository,
            storageLocationRepository: deps.storageLocationRepository
        )
    }
    
    // Computed properties
    private var filteredItems: [CompleteInventoryItemModel] {
        var items = viewModel.completeItems

        // Only show items with inventory (totalQuantity > 0)
        items = items.filter { $0.totalQuantity > 0 }

        // Apply product type filter
        if !viewModel.selectedProductTypes.isEmpty {
            items = items.filter { item in
                viewModel.selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply manufacturer filter
        if !viewModel.selectedManufacturers.isEmpty {
            items = items.filter { item in
                viewModel.selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Apply tag filter
        if !viewModel.selectedTags.isEmpty {
            items = items.filter { item in
                !viewModel.selectedTags.isDisjoint(with: Set(item.tags))
            }
        }

        // Apply COE filter
        if !viewModel.selectedCOEs.isEmpty {
            items = items.filter { item in
                if let coe = item.catalogItem.coe {
                    return viewModel.selectedCOEs.contains(coe)
                }
                return false
            }
        }

        // Apply inventory type filter (rod, tube, frit, etc.) - single selection from dropdown
        if let inventoryType = viewModel.selectedInventoryType {
            items = items.filter { item in
                item.inventory.contains { inventory in
                    inventory.type == inventoryType
                }
            }
        }

        // Legacy multi-select inventory type filter (keep for backwards compatibility if used elsewhere)
        if !viewModel.selectedTypes.isEmpty {
            items = items.filter { item in
                item.inventory.contains { inventory in
                    viewModel.selectedTypes.contains(inventory.type)
                }
            }
        }

        // Apply location filter
        if let location = viewModel.selectedLocation {
            items = items.filter { item in
                item.inventory.contains { inventory in
                    inventory.location == location
                }
            }
        }

        // Apply search filter using SearchTextParser for advanced search (including grey/gray synonyms)
        if !viewModel.searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(viewModel.searchText) {
            let searchMode = SearchTextParser.parseSearchText(viewModel.searchText)
            items = items.filter { item in
                let allFields = [
                    item.catalogItem.name,
                    item.catalogItem.stable_id,
                    item.catalogItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        return items
    }
    
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return filteredItems.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
            switch viewModel.sortOption {
            case .name:
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            case .totalQuantity:
                return item1.totalQuantity != item2.totalQuantity ?
                    item1.totalQuantity > item2.totalQuantity :
                    item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            case .manufacturer:
                return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending
            case .dateAdded:
                // Sort by most recent first (descending order) - get the newest date_added from inventory
                let item1Date = item1.inventory.map { $0.date_added }.max() ?? Date.distantPast
                let item2Date = item2.inventory.map { $0.date_added }.max() ?? Date.distantPast
                return item1Date > item2Date
            }
        }
    }
    
    private var isEmpty: Bool {
        filteredItems.isEmpty
    }

    private var shouldShowSearchEmptyState: Bool {
        !viewModel.completeItems.isEmpty && (!viewModel.searchText.isEmpty || !viewModel.selectedTags.isEmpty || !viewModel.selectedCOEs.isEmpty || !viewModel.selectedManufacturers.isEmpty || viewModel.selectedLocation != nil)
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
    private var allAvailableManufacturers: [String] {
        return cachedManufacturers
    }

    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allAvailableLocations: [String] {
        return cachedLocations
    }

    // Count of unique items with inventory (for subscription banner)
    private var inventoryItemCount: Int {
        return viewModel.completeItems.filter { $0.totalQuantity > 0 }.count
    }

    // MARK: - Filter Counts (for display in filter selection sheets)

    // MARK: - Filter Counts

    // Delegate filter counts to ViewModel for DRY approach
    private var manufacturerCounts: [String: Int] {
        viewModel.manufacturerCounts
    }

    private var coeCounts: [Int32: Int] {
        viewModel.coeCounts
    }

    private var tagCounts: [String: Int] {
        viewModel.tagCounts
    }

    private var locationCounts: [String: Int] {
        viewModel.locationCounts
    }

    /// Recompute caches when inventory data changes
    /// This is expensive (O(n)) so only call when data actually changes
    private func updateCaches() {
        let itemsWithInventory = viewModel.completeItems.filter { $0.totalQuantity > 0 }

        // Extract all tags, COEs, manufacturers, and locations
        var allTagsSet = Set<String>()
        var allCOEsSet = Set<Int32>()
        var manufacturersSet = Set<String>()
        var locationsSet = Set<String>()

        for item in itemsWithInventory {
            allTagsSet.formUnion(item.tags)
            allCOEsSet.insert(item.glassItem.coe)

            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mfr.isEmpty {
                manufacturersSet.insert(mfr)
            }

            // Extract locations from inventory records
            for inventoryRecord in item.inventory {
                if let location = inventoryRecord.location, !location.isEmpty {
                    locationsSet.insert(location)
                }
            }
        }

        cachedAllTags = allTagsSet.sorted()
        cachedAllCOEs = allCOEsSet.sorted()
        cachedManufacturers = manufacturersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        cachedLocations = locationsSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Filter header using reusable ModernFilterHeader component
                ModernFilterHeader(
                    searchTitlesOnly: $viewModel.searchTitlesOnly,
                    sortOption: $viewModel.sortOption,
                    sortOptions: Array(InventorySortOption.allCases),
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
                        displayName: displayNameForProductType
                    ),
                    locationFilter: .init(
                        selectedLocation: $viewModel.selectedLocation,
                        availableLocations: allAvailableLocations,
                        itemCounts: locationCounts,
                        onClear: { viewModel.selectedLocation = nil }
                    ),
                    inventoryTypeFilter: .init(
                        selectedType: $viewModel.selectedInventoryType,
                        availableTypes: viewModel.availableInventoryTypes,
                        itemCounts: viewModel.inventoryTypeCounts,
                        displayName: { GlassTerminologySettings.shared.displayName(for: $0) },
                        onClear: { viewModel.selectedInventoryType = nil }
                    )
                )

                // Main content
                Group {
                    if isEmpty {
                        if shouldShowSearchEmptyState {
                            searchEmptyStateView
                        } else {
                            inventoryEmptyState
                        }
                    } else {
                        inventoryListView
                    }
                }
                .id(refreshTrigger)
            }
            .performanceTitle("Inventory", timer: performanceTimer)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search inventory by name, code, manufacturer..."
            )
            .searchScopes($searchScope, activation: .onSearchPresentation) {
                ForEach(InventorySearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue)
                }
            }
            .onChange(of: searchScope) { oldValue, newValue in
                viewModel.searchTitlesOnly = (newValue == .titlesOnly)
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbar {
                toolbarContent
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
                    selectedCOEs: $viewModel.selectedCOEs,
                    itemCounts: coeCounts
                )
            }
            .sheet(isPresented: $showingManufacturerSelection) {
                FilterSelectionSheet.manufacturers(
                    availableManufacturers: allAvailableManufacturers,
                    selectedManufacturers: $viewModel.selectedManufacturers,
                    manufacturerDisplayName: { code in
                        GlassManufacturers.fullName(for: code) ?? code.uppercased()
                    },
                    itemCounts: manufacturerCounts
                )
            }
            .sheet(isPresented: $showingAddItem, onDismiss: {
                log.info("📋 Add inventory sheet dismissed, waiting for Core Data sync...")
                // Add a small delay to allow background context save to propagate
                Task {
                    // Wait a bit for the background context save to complete and propagate
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    // Invalidate cache to force fresh data load
                    await CatalogDataCache.shared.reload(catalogService: catalogService)
                    await loadData()
                }
            }) {
                AddInventoryItemView(
                    prefilledNaturalKey: prefilledNaturalKey.isEmpty ? nil : prefilledNaturalKey,
                    deps: AppDependencies()
                )
            }
            .sheet(isPresented: $showingLabelDesigner) {
                LabelDesignerView(items: sortedFilteredItems)
            }
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "inventory",
                    currentCount: inventoryItemCount,
                    limit: entitlementService.getInventoryLimit() ?? 0
                )
            }
            .fullScreenCover(isPresented: $showingSharing) {
                NavigationStack {
                    InventorySharingView(pendingShareCode: pendingShareCode)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingSharing = false
                                    // Clear pending share code after dismissing
                                    pendingShareCode = nil
                                }
                            }
                        }
                }
            }
            .task {
                await loadData()
                performanceTimer.complete()
            }
            .refreshable {
                // Invalidate cache to force fresh data load on pull-to-refresh
                await CatalogDataCache.shared.reload(catalogService: catalogService)
                await loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { _ in
                Task {
                    // Invalidate cache to force fresh data load
                    await CatalogDataCache.shared.reload(catalogService: catalogService)
                    await loadData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .ratingSubmitted)) { notification in
                Task {
                    let ratingService = AppDependencies.shared.ratingService
                    let itemId = notification.object as? String

                    // IMPORTANT: Server needs time to rebuild bulk cache after invalidation.
                    // Retry fetching until we find the new rating or timeout after 3 seconds.
                    var attempts = 0
                    let maxAttempts = 6  // 6 attempts × 500ms = 3 seconds max

                    while attempts < maxAttempts {
                        let freshRatings = try? await ratingService.fetchAllRatingsBulk(forceRefresh: true)

                        // If we're looking for a specific item, check if it's in the results
                        if let itemId = itemId {
                            let itemRating = freshRatings?.first(where: { $0.itemStableId == itemId })
                            if itemRating != nil {
                                break  // Success! Found the new rating
                            } else {
                                attempts += 1
                                if attempts < maxAttempts {
                                    try? await Task.sleep(nanoseconds: 500_000_000)  // Wait 500ms before retry
                                }
                            }
                        } else {
                            break  // No specific item to check for, just use what we got
                        }
                    }

                    // Invalidate cache to force fresh data load when ratings change
                    await CatalogDataCache.shared.reload(catalogService: catalogService)
                    await loadData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetInventoryNavigation)) { _ in
                // Reset navigation when user taps Inventory tab while already on Inventory
                navigationPath = NavigationPath()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToInventorySharingWithCode)) { notification in
                // Extract share code from notification and show sharing view
                if let shareCode = notification.userInfo?["shareCode"] as? String {
                    pendingShareCode = shareCode
                    showingSharing = true
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var inventoryEmptyState: some View {
        CustomEmptyStateView(
            icon: "archivebox",
            title: "No Inventory Yet",
            description: "Start tracking your glass inventory by adding your first item using the + button in the menu bar"
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

        return CustomEmptyStateView.searchResults(
            searchTerm: viewModel.searchText.isEmpty ? nil : viewModel.searchText,
            filters: activeFilters,
            onClearFilters: {
                viewModel.searchText = ""
                viewModel.selectedTags.removeAll()
                viewModel.selectedCOEs.removeAll()
                viewModel.selectedManufacturers.removeAll()
            }
        )
    }
    
    private var inventoryListView: some View {
        List {
            ForEach(sortedFilteredItems, id: \.id) { item in
                NavigationLink(value: item) {
                    GlassItemRowView.inventory(item: item, selectedLocation: viewModel.selectedLocation)
                }
                .id("\(item.id)-\(item.rating?.totalRatings ?? 0)-\(item.rating?.averageRating ?? 0)")  // Force re-render when rating changes
                .accessibilityIdentifier("inventory.item.\(item.glassItem.stable_id)")
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        await deleteInventoryItem(sortedFilteredItems[index])
                    }
                }
            }
        }
        .accessibilityIdentifier("inventory.list")
        .id(refreshTrigger)  // Force list to refresh when trigger changes
        .navigationDestination(for: CompleteInventoryItemModel.self) { item in
            InventoryDetailView(
                item: item,
                deps: AppDependencies()
            )
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddItem = true
            } label: {
                Image(systemName: "plus")
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Menu {
                Button {
                    showingAddItem = true
                } label: {
                    Label("Add Inventory", systemImage: "plus")
                }

                Divider()

                Button {
                    showingSharing = true
                } label: {
                    Label("Inventory Sharing", systemImage: "person.2")
                }

                Button {
                    showingLabelDesigner = true
                } label: {
                    Label("Print Labels", systemImage: "qrcode")
                }
                .disabled(sortedFilteredItems.isEmpty)

                ImportInventoryTriggerView {
                    // Refresh inventory after import completes
                    Task {
                        await CatalogDataCache.shared.reload(catalogService: catalogService)
                        await loadData()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - Helper Methods

    private func displayNameForProductType(_ type: String) -> String {
        switch type.lowercased() {
        case "glass": return "Glass"
        case "coating": return "Coatings"
        case "tool": return "Tools"
        default: return type.capitalized
        }
    }

    private func loadData() async {
        log.info("🔄 InventoryView loadData() called")

        // Delegate to ViewModel
        await viewModel.loadInventoryItems()

        // Update view-specific caches and state
        await MainActor.run {
            let itemsWithInventory = viewModel.completeItems.filter { $0.totalQuantity > 0 }
            updateCaches()  // PERFORMANCE: Update cached filter values
            refreshTrigger += 1  // Force SwiftUI to refresh the list
        }
    }

    // MARK: - CachedDataDeletion Protocol Implementation

    func performDeletion(for item: CompleteInventoryItemModel) async throws {
        let stableId = item.glassItem.stable_id

        // Delete all inventory records and their associated storage locations
        for inventory in item.inventory {
            // Delete storage locations for this inventory record
            try await storageLocationRepository.deleteLocations(forInventory: inventory.id)

            // Delete the inventory record itself
            try await inventoryTrackingService.deleteInventory(id: inventory.id)
        }

        // Clean up orphaned user data (tags and notes)
        // Remove all user tags for this item
        try await userTagsRepository.removeAllTags(fromItem: stableId)

        // Delete user notes for this item (if any exist)
        try await userNotesRepository.deleteNotes(forItem: stableId)

        log.info("✅ Deleted inventory and associated data for item: \(stableId)")
    }

    func removeFromCache(_ item: CompleteInventoryItemModel) async {
        await MainActor.run {
            log.info("🗑️ removeFromCache START: completeItems.count = \(viewModel.completeItems.count)")
            log.info("🗑️ removeFromCache: Looking for item \(item.glassItem.stable_id)")

            // DON'T remove the catalog item - just update it to have no inventory
            // The catalog should always contain all items
            if let index = viewModel.completeItems.firstIndex(where: { $0.id == item.id }) {
                let existing = viewModel.completeItems[index]
                log.info("🗑️ removeFromCache: Found at index \(index), inventory count = \(existing.inventory.count)")

                // Create new item with empty inventory (all properties are immutable)
                let updatedItem = CompleteInventoryItemModel(
                    catalogItem: existing.catalogItem,
                    inventory: [],  // Clear inventory records
                    tags: existing.tags,
                    userTags: existing.userTags,
                    rating: existing.rating
                )
                viewModel.completeItems[index] = updatedItem
                log.info("🗑️ removeFromCache: Updated item, new inventory count = \(updatedItem.inventory.count)")
            } else {
                log.warning("🗑️ removeFromCache: Item NOT FOUND in completeItems!")
            }

            log.info("🗑️ removeFromCache END: completeItems.count = \(viewModel.completeItems.count)")
            log.info("🗑️ removeFromCache: Incrementing refreshTrigger from \(refreshTrigger) to \(refreshTrigger + 1)")
            refreshTrigger += 1  // Force SwiftUI to refresh (updates counters, UI)
        }
    }

    func reloadData() async {
        log.info("🔄 reloadData: Starting deferred reload...")
        // CRITICAL: Force cache reload from Core Data
        // Without this, loadInventoryItems() returns stale cache data and undoes our in-place update
        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await viewModel.loadInventoryItems()
        log.info("🔄 reloadData: Reload complete - \(viewModel.completeItems.count) items")
    }

    func updateDerivedCaches() {
        updateCaches()
    }

    // Convenience wrapper for .onDelete handler
    private func deleteInventoryItem(_ item: CompleteInventoryItemModel) async {
        await deleteItem(item)
    }
}

#Preview {
    InventoryView()
}
