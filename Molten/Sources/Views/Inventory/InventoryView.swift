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
    @State private var filterRefreshTrigger = 0  // Force re-evaluation when Settings filters change

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedManufacturers: [String] = []
    @State private var cachedLocations: [String] = []

    // Local search text state - isolates TextField from ViewModel to prevent full view re-renders
    // Debouncing happens here in the View, and we only update ViewModel.debouncedSearchText after delay
    @State private var localSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?

    // Cached filtered items - only recomputed when filters/data actually change, not on every keystroke
    @State private var cachedFilteredItems: [CompleteInventoryItemModel] = []
    @State private var cachedSortedFilteredItems: [CompleteInventoryItemModel] = []

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
    
    // Use cached filtered items to avoid recomputation on every keystroke
    // These are updated via updateFilteredItemsCache() when filters actually change
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        cachedSortedFilteredItems
    }

    private var isEmpty: Bool {
        cachedFilteredItems.isEmpty
    }

    private var shouldShowSearchEmptyState: Bool {
        // Use debouncedSearchText to avoid triggering re-renders on every keystroke
        !viewModel.completeItems.isEmpty && (!viewModel.debouncedSearchText.isEmpty || !viewModel.selectedTags.isEmpty || !viewModel.selectedCOEs.isEmpty || !viewModel.selectedManufacturers.isEmpty || viewModel.selectedLocation != nil)
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
        return viewModel.completeItems.filter { $0.hasInventory }.count
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
        let itemsWithInventory = viewModel.completeItems.filter { $0.hasInventory }

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

    /// Update cached filtered items - call this when filters change, not on every keystroke
    private func updateFilteredItemsCache() {
        var items = viewModel.completeItems

        // Only show items with inventory (weight OR containers)
        items = items.filter { $0.hasInventory }

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
        // Apply global manufacturer filter from Settings (if enabled)
        if UserSettings.shared.applyFiltersToInventory {
            if let data = UserDefaults.standard.data(forKey: "selectedManufacturerFilter"),
               let selectedManufacturers = try? JSONDecoder().decode(Set<String>.self, from: data),
               !selectedManufacturers.isEmpty {
                items = items.filter { item in
                    selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
                }
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
                if item.catalogItem.itemType != .glass { return true }
                if let coe = item.catalogItem.coe { return viewModel.selectedCOEs.contains(coe) }
                return false
            }
        }
        // Apply global COE filter from Settings (if enabled)
        if UserSettings.shared.applyFiltersToInventory {
            let globalCOEs = COEGlassPreference.selectedCOETypes
            if !globalCOEs.isEmpty && globalCOEs.count < COEGlassType.allCases.count {
                let globalCOEValues = Set(globalCOEs.map { Int32($0.rawValue) })
                items = items.filter { item in
                    if let coe = item.catalogItem.coe { return globalCOEValues.contains(coe) }
                    return false
                }
            }
        }

        // Apply inventory type filter
        if let inventoryType = viewModel.selectedInventoryType {
            items = items.filter { item in
                item.inventory.contains { $0.type == inventoryType }
            }
        }

        // Legacy multi-select inventory type filter
        if !viewModel.selectedTypes.isEmpty {
            items = items.filter { item in
                item.inventory.contains { viewModel.selectedTypes.contains($0.type) }
            }
        }

        // Apply location filter
        if let location = viewModel.selectedLocation {
            items = items.filter { item in
                item.inventory.contains { $0.location == location }
            }
        }

        // Apply search filter
        if !viewModel.debouncedSearchText.isEmpty && SearchTextParser.isSearchTextMeaningful(viewModel.debouncedSearchText) {
            let searchMode = SearchTextParser.parseSearchText(viewModel.debouncedSearchText)
            items = items.filter { item in
                let allFields = [item.catalogItem.name, item.catalogItem.stable_id, item.catalogItem.manufacturer]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        cachedFilteredItems = items

        // Apply sorting
        cachedSortedFilteredItems = items.sorted { (item1, item2) in
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
                let item1Date = item1.inventory.map { $0.date_added }.max() ?? Date.distantPast
                let item2Date = item2.inventory.map { $0.date_added }.max() ?? Date.distantPast
                return item1Date > item2Date
            }
        }
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
                        displayName: displayNameForProductType,
                        typeCounts: viewModel.productTypeCounts
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

                // Usage banner (only show for free tier)
                if entitlementService.currentTier == .free {
                    UsageBanner(
                        featureName: "unique inventory items",
                        currentCount: inventoryItemCount,
                        limit: entitlementService.getInventoryLimit(),
                        onUpgradeTap: {
                            showingUpgradePrompt = true
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

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
            .navigationTitle("Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(
                text: $localSearchText,
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
            .onChange(of: localSearchText) { oldValue, newValue in
                // Debounce search locally - only update ViewModel after delay
                // This prevents any ViewModel observation triggers during typing
                searchDebounceTask?.cancel()

                if newValue.isEmpty {
                    // Clear immediately when user clears search
                    viewModel.debouncedSearchText = ""
                    updateFilteredItemsCache()
                } else {
                    // Debounce non-empty searches
                    searchDebounceTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                        if !Task.isCancelled {
                            viewModel.debouncedSearchText = newValue
                            updateFilteredItemsCache()
                        }
                    }
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .inventoryChanged)) { _ in
                Task {
                    // Refresh after QR scan inventory changes
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
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                // When UserDefaults changes (e.g., COE filter, manufacturer filter, or applyFiltersToInventory in Settings),
                // increment the trigger to force filteredItems to re-evaluate
                filterRefreshTrigger += 1
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
            // Use debouncedSearchText to avoid re-renders on every keystroke
            searchTerm: viewModel.debouncedSearchText.isEmpty ? nil : viewModel.debouncedSearchText,
            filters: activeFilters,
            onClearFilters: {
                localSearchText = ""  // Clear local search text
                viewModel.debouncedSearchText = ""  // Clear debounced text directly
                viewModel.selectedTags.removeAll()
                viewModel.selectedCOEs.removeAll()
                viewModel.selectedManufacturers.removeAll()
                updateFilteredItemsCache()
            }
        )
    }
    
    private var inventoryListView: some View {
        List {
            // Limit warning banner (shows at 75%+ usage for free tier)
            if let limit = entitlementService.getInventoryLimit() {
                LimitWarningBanner(
                    currentCount: inventoryItemCount,
                    limit: limit,
                    featureName: "items",
                    onUpgradeTap: { showingUpgradePrompt = true }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }

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
            .accessibilityIdentifier("inventory_add_button")
        }

        ToolbarItem(placement: .confirmationAction) {
            Menu {
                Button {
                    showingAddItem = true
                } label: {
                    Label("Add Inventory", systemImage: "plus")
                }
                .accessibilityIdentifier("inventory_menu_add")

                Divider()

                Button {
                    showingSharing = true
                } label: {
                    Label("Inventory Sharing", systemImage: "person.2")
                }
                .accessibilityIdentifier("inventory_menu_sharing")

                Button {
                    showingLabelDesigner = true
                } label: {
                    Label("Print Labels", systemImage: "qrcode")
                }
                .disabled(sortedFilteredItems.isEmpty)
                .accessibilityIdentifier("inventory_menu_print_labels")

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
            .accessibilityIdentifier("inventory_menu")
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
            #if DEBUG
            let uitestLog = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")
            uitestLog.warning("📋 [InventoryView] loadData complete: \(viewModel.completeItems.count) total, \(itemsWithInventory.count) with inventory")
            if let firstItem = itemsWithInventory.first {
                uitestLog.warning("📋 [InventoryView] First item: \(firstItem.glassItem.stable_id), qty=\(firstItem.totalQuantity)")
            }
            #endif
            updateCaches()  // PERFORMANCE: Update cached filter values
            updateFilteredItemsCache()  // PERFORMANCE: Update filtered items cache
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

            // Remove the item from the array entirely
            // This is necessary because:
            // 1. filteredItems uses `$0.hasInventory` filter
            // 2. If we just clear inventory, the item disappears from the filtered list
            // 3. But SwiftUI's collection view expects the count to match during animation
            // 4. Removing from the source array keeps everything in sync
            //
            // Note: The next reload will restore catalog items - we're just removing from
            // the in-memory cache to keep the UI consistent during the delete animation
            if let index = viewModel.completeItems.firstIndex(where: { $0.id == item.id }) {
                log.info("🗑️ removeFromCache: Found at index \(index), removing from array")
                viewModel.completeItems.remove(at: index)
                log.info("🗑️ removeFromCache: Removed item, new count = \(viewModel.completeItems.count)")
            } else {
                log.warning("🗑️ removeFromCache: Item NOT FOUND in completeItems!")
            }

            log.info("🗑️ removeFromCache END: completeItems.count = \(viewModel.completeItems.count)")
            // Note: Don't increment refreshTrigger here - the array mutation already triggers SwiftUI update
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

// MARK: - Filter Change Modifier
// Extracted to reduce body complexity and help Swift compiler

private struct FilterChangeModifier: ViewModifier {
    @Bindable var viewModel: InventoryViewModel
    let updateCache: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.selectedTags) { _, _ in updateCache() }
            .onChange(of: viewModel.selectedCOEs) { _, _ in updateCache() }
            .onChange(of: viewModel.selectedManufacturers) { _, _ in updateCache() }
            .onChange(of: viewModel.selectedProductTypes) { _, _ in updateCache() }
            .onChange(of: viewModel.selectedLocation) { _, _ in updateCache() }
            .onChange(of: viewModel.selectedInventoryType) { _, _ in updateCache() }
            .onChange(of: viewModel.sortOption) { _, _ in updateCache() }
    }
}

private extension View {
    func onFilterChange(viewModel: InventoryViewModel, updateCache: @escaping () -> Void) -> some View {
        modifier(FilterChangeModifier(viewModel: viewModel, updateCache: updateCache))
    }
}

#Preview {
    InventoryView()
}
