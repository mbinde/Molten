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

    // UI-only state (not in ViewModel)
    @State private var showingAddItem = false
    @State private var showingUpgradePrompt = false
    @State private var prefilledNaturalKey: String = ""
    @State private var navigationPath = NavigationPath()
    @State private var showingAddFromCatalog = false
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var refreshTrigger = 0  // Force SwiftUI to refresh list
    @State private var showingLabelDesigner = false
    @State private var showingSharing = false
    @State private var showingQRScanner = false
    @State private var showingManageLocations = false
    @State private var showingHelp = false
    @State private var showingFilterSheet = false
    @State private var scannedQRCode: String? = nil
    @State private var pendingShareCode: String? = nil
    @State private var filterRefreshTrigger = 0  // Force re-evaluation when Settings filters change

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedManufacturers: [String] = []
    @State private var cachedLocations: [String] = []
    @State private var cachedNoLocationCount: Int = 0


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
    private let storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    private let inventoryRepository: InventoryRepository

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
        storageLocationRepository: StorageLocationRepository,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository,
        inventoryRepository: InventoryRepository
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
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
        self.inventoryRepository = inventoryRepository
    }

    // Convenience init for production use
    init(deps: AppDependencies = .shared) {
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
            storageLocationRepository: deps.storageLocationRepository,
            storageLocationDefinitionRepository: deps.storageLocationDefinitionRepository,
            inventoryRepository: deps.inventoryRepository
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
        !viewModel.completeItems.isEmpty && (!viewModel.debouncedSearchText.isEmpty || !viewModel.selectedTags.isEmpty || !viewModel.selectedCOEs.isEmpty || !viewModel.selectedManufacturers.isEmpty || !viewModel.selectedLocations.isEmpty)
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

    // PERFORMANCE OPTIMIZED: Returns cached value for items with no location
    private var noLocationCount: Int {
        return cachedNoLocationCount
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
        var itemsWithNoLocation = 0

        for item in itemsWithInventory {
            allTagsSet.formUnion(item.tags)
            allCOEsSet.insert(item.glassItem.coe)

            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mfr.isEmpty {
                manufacturersSet.insert(mfr)
            }

            // Track if this item has any inventory record with no location
            var hasNoLocation = false

            // Extract locations from inventory records
            for inventoryRecord in item.inventory {
                if let location = inventoryRecord.location, !location.isEmpty {
                    locationsSet.insert(location)
                } else {
                    hasNoLocation = true
                }
            }

            if hasNoLocation {
                itemsWithNoLocation += 1
            }
        }

        cachedAllTags = allTagsSet.sorted()
        cachedAllCOEs = allCOEsSet.sorted()
        cachedManufacturers = manufacturersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        cachedLocations = locationsSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        cachedNoLocationCount = itemsWithNoLocation
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

        // Apply location filter (multi-select)
        // Empty set means "show all", empty string in set means "show items with no location"
        if !viewModel.selectedLocations.isEmpty {
            items = items.filter { item in
                item.inventory.contains { inventory in
                    if let location = inventory.location, !location.isEmpty {
                        return viewModel.selectedLocations.contains(location)
                    } else {
                        return viewModel.selectedLocations.contains(LocationQuickFilterBar.noLocationValue)
                    }
                }
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
        mainNavigationStack
    }

    @ViewBuilder
    private var mainNavigationStack: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
        }
        .overlay(alignment: .topLeading) {
            // Floating location filter button (upper left) - only show if there are locations defined
            if !allAvailableLocations.isEmpty {
                Menu {
                    // "All" option - clears selection
                    Button {
                        viewModel.selectedLocations.removeAll()
                    } label: {
                        if viewModel.selectedLocations.isEmpty {
                            Label("All Locations (\(inventoryItemCount))", systemImage: "checkmark")
                        } else {
                            Text("All Locations (\(inventoryItemCount))")
                        }
                    }

                    Divider()

                    // "(none)" option - items with no location
                    Button {
                        toggleLocation(LocationQuickFilterBar.noLocationValue)
                    } label: {
                        if viewModel.selectedLocations.contains(LocationQuickFilterBar.noLocationValue) {
                            Label("No Location (\(noLocationCount))", systemImage: "checkmark")
                        } else {
                            Text("No Location (\(noLocationCount))")
                        }
                    }

                    // Location options
                    ForEach(allAvailableLocations, id: \.self) { location in
                        Button {
                            toggleLocation(location)
                        } label: {
                            if viewModel.selectedLocations.contains(location) {
                                Label("\(location) (\(locationCounts[location] ?? 0))", systemImage: "checkmark")
                            } else {
                                Text("\(location) (\(locationCounts[location] ?? 0))")
                            }
                        }
                    }

                    Divider()

                    Button {
                        showingManageLocations = true
                    } label: {
                        Label("Manage Locations", systemImage: "gear")
                    }
                } label: {
                    ZStack(alignment: .topLeading) {
                        // Teal outer circle, white inner circle, teal icon
                        ZStack {
                            // Outer teal circle
                            Circle()
                                .fill(DesignSystem.Colors.accentSecondary)
                                .frame(width: 50, height: 50)

                            // Inner white circle
                            Circle()
                                .fill(.white)
                                .frame(width: 36, height: 36)

                            // Combination icon: archivebox with filter lines (overlapping)
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 18, weight: .medium))
                                    .offset(x: -2, y: -2)
                                    .foregroundColor(DesignSystem.Colors.accentSecondary)
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 16, weight: .bold))
                                    .shadow(color: .white, radius: 3, x: 0, y: 0)
                                    .offset(x: 3, y: 3)
                                    .foregroundColor(DesignSystem.Colors.accentSecondary)
                            }
//                            .foregroundColor(DesignSystem.Colors.accentSecondary)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                        // Badge showing selected location count
                        if !viewModel.selectedLocations.isEmpty {
                            Text("\(viewModel.selectedLocations.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(
                                    Circle()
                                        .fill(DesignSystem.Colors.accentPrimary)
                                )
                                .offset(x: -2, y: -2)
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
                .accessibilityIdentifier("inventory_location_filter_button")
            }
        }
    }

    @ViewBuilder
    private var inventoryContentView: some View {
        Group {
            if isEmpty {
                if shouldShowSearchEmptyState { searchEmptyStateView }
                else { inventoryEmptyState }
            } else {
                inventoryListView
            }
        }
        .id(refreshTrigger)
        .navigationTitle("Inventory")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var mainContent: some View {
        inventoryContentView
            .withHelperSheets(
                showingAddItem: $showingAddItem,
                showingLabelDesigner: $showingLabelDesigner,
                showingQRScanner: $showingQRScanner,
                showingUpgradePrompt: $showingUpgradePrompt,
                showingHelp: $showingHelp,
                showingManageLocations: $showingManageLocations,
                showingSharing: $showingSharing,
                pendingShareCode: $pendingShareCode,
                prefilledNaturalKey: prefilledNaturalKey,
                sortedFilteredItems: sortedFilteredItems,
                inventoryItemCount: inventoryItemCount,
                inventoryLimit: entitlementService.getInventoryLimit(),
                storageLocationDefinitionRepository: storageLocationDefinitionRepository,
                storageLocationRepository: storageLocationRepository,
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService,
                loadData: loadData
            )
            .withInventoryFilterSheet(
                showingFilterSheet: $showingFilterSheet,
                sortOption: $viewModel.sortOption,
                selectedTags: $viewModel.selectedTags,
                selectedCOEs: $viewModel.selectedCOEs,
                selectedManufacturers: $viewModel.selectedManufacturers,
                selectedLocations: $viewModel.selectedLocations,
                selectedProductTypes: $viewModel.selectedProductTypes,
                allAvailableTags: cachedAllTags,
                allAvailableCOEs: cachedAllCOEs,
                availableManufacturers: cachedManufacturers,
                availableLocations: cachedLocations,
                availableProductTypes: ["glass", "coatings"],
                tagCounts: viewModel.tagCounts,
                coeCounts: viewModel.coeCounts,
                manufacturerCounts: viewModel.manufacturerCounts,
                locationCounts: viewModel.locationCounts,
                productTypeCounts: viewModel.productTypeCounts,
                manufacturerDisplayName: { GlassManufacturers.fullName(for: $0) ?? $0 },
                productTypeDisplayName: { $0 == "glass" ? "Glass" : "Coatings" }
            )
            .task {
                await loadDataWithCloudKitRetry()
            }
            .refreshable {
                // Invalidate cache to force fresh data load on pull-to-refresh
                await CatalogDataCache.shared.reload(catalogService: catalogService)
                await loadData()
            }
            .onInventoryNotifications(
                catalogService: catalogService,
                loadData: loadData,
                updateFilteredItemsCache: updateFilteredItemsCache,
                setSearchText: { viewModel.debouncedSearchText = $0 },
                filterRefreshTrigger: $filterRefreshTrigger,
                navigationPath: $navigationPath,
                pendingShareCode: $pendingShareCode,
                showingSharing: $showingSharing,
                showingFilterSheet: $showingFilterSheet
            )
            .onFilterChange(viewModel: viewModel, updateCache: updateFilteredItemsCache)
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
                viewModel.debouncedSearchText = ""  // Clear search text
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
                    GlassItemRowView.inventory(item: item, selectedLocations: viewModel.selectedLocations)
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
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .accessibilityIdentifier("inventory.list")
        .id(refreshTrigger)  // Force list to refresh when trigger changes
        .navigationDestination(for: CompleteInventoryItemModel.self) { item in
            InventoryDetailView(
                item: item,
                deps: .shared
            )
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Quick action button - only show if not set to "none"
        if UserSettings.shared.inventoryQuickAction != .none {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // Action depends on user setting
                    switch UserSettings.shared.inventoryQuickAction {
                    case .addInventory:
                        // Check if at limit before showing add screen
                        if let limit = entitlementService.getInventoryLimit(),
                           inventoryItemCount >= limit {
                            showingUpgradePrompt = true
                        } else {
                            showingAddItem = true
                        }
                    case .scanQRCode:
                        showingQRScanner = true
                    case .none:
                        break
                    }
                } label: {
                    Image(systemName: UserSettings.shared.inventoryQuickAction.systemImage)
                }
                .accessibilityIdentifier("inventory_quick_action_button")
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Menu {
                Button {
                    // Check if at limit before showing add screen
                    if let limit = entitlementService.getInventoryLimit(),
                       inventoryItemCount >= limit {
                        showingUpgradePrompt = true
                    } else {
                        showingAddItem = true
                    }
                } label: {
                    Label("Add Inventory", systemImage: "plus")
                }
                .accessibilityIdentifier("inventory_menu_add")

                Button {
                    showingQRScanner = true
                } label: {
                    Label("Scan QR Code", systemImage: "camera")
                }
                .accessibilityIdentifier("inventory_menu_scan_qr")

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

                Divider()

                Button {
                    showingHelp = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
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

    private func toggleLocation(_ location: String) {
        if viewModel.selectedLocations.contains(location) {
            viewModel.selectedLocations.remove(location)
        } else {
            viewModel.selectedLocations.insert(location)
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

    /// Load data with retry logic for CloudKit sync on fresh install
    private func loadDataWithCloudKitRetry() async {
        await loadData()

        // If inventory is empty, CloudKit may still be syncing after fresh install.
        // Poll a few times to catch incoming data.
        guard viewModel.completeItems.isEmpty else { return }

        for _ in 1...5 {
            try? await Task.sleep(for: .seconds(1))
            await CatalogDataCache.shared.reload(catalogService: catalogService)
            await loadData()
            if !viewModel.completeItems.isEmpty { break }
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
            .onChange(of: viewModel.selectedTags) { _, _ in updateCache(); viewModel.notifyFilterCountChanged() }
            .onChange(of: viewModel.selectedCOEs) { _, _ in updateCache(); viewModel.notifyFilterCountChanged() }
            .onChange(of: viewModel.selectedManufacturers) { _, _ in updateCache(); viewModel.notifyFilterCountChanged() }
            .onChange(of: viewModel.selectedProductTypes) { _, _ in updateCache(); viewModel.notifyFilterCountChanged() }
            .onChange(of: viewModel.selectedLocations) { _, _ in updateCache(); viewModel.notifyFilterCountChanged() }
            .onChange(of: viewModel.selectedInventoryType) { _, _ in updateCache() }
            .onChange(of: viewModel.sortOption) { _, _ in updateCache() }
    }
}

// MARK: - Helper Sheets Modifier
// Extracted to reduce body complexity and help Swift compiler

private struct InventoryHelperSheetsModifier: ViewModifier {
    @Binding var showingAddItem: Bool
    @Binding var showingLabelDesigner: Bool
    @Binding var showingQRScanner: Bool
    @Binding var showingUpgradePrompt: Bool
    @Binding var showingHelp: Bool
    @Binding var showingManageLocations: Bool
    @Binding var showingSharing: Bool
    @Binding var pendingShareCode: String?

    let prefilledNaturalKey: String
    let sortedFilteredItems: [CompleteInventoryItemModel]
    let inventoryItemCount: Int
    let inventoryLimit: Int?
    let storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    let storageLocationRepository: StorageLocationRepository
    let inventoryTrackingService: InventoryTrackingService
    let catalogService: CatalogService
    let loadData: () async -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingAddItem, onDismiss: {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await CatalogDataCache.shared.reload(catalogService: catalogService)
                    await loadData()
                }
            }) {
                AddInventoryItemView(
                    prefilledNaturalKey: prefilledNaturalKey.isEmpty ? nil : prefilledNaturalKey,
                    deps: .shared
                )
            }
            .sheet(isPresented: $showingLabelDesigner) {
                LabelDesignerView(items: sortedFilteredItems)
            }
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScannerView { scannedURL in
                    if let url = URL(string: scannedURL) {
                        NotificationCenter.default.post(
                            name: .openMoltenDeepLink,
                            object: nil,
                            userInfo: ["url": url]
                        )
                    }
                }
            }
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "inventory",
                    currentCount: inventoryItemCount,
                    limit: inventoryLimit ?? 0
                )
            }
            .sheet(isPresented: $showingHelp) {
                InventoryHelpView()
            }
            .sheet(isPresented: $showingManageLocations) {
                ManageLocationsView(
                    storageLocationDefinitionRepository: storageLocationDefinitionRepository,
                    storageLocationRepository: storageLocationRepository,
                    inventoryTrackingService: inventoryTrackingService,
                    onLocationsChanged: {
                        Task {
                            await CatalogDataCache.shared.reload(catalogService: catalogService)
                            await loadData()
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showingSharing) {
                NavigationStack {
                    InventorySharingView(pendingShareCode: pendingShareCode)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingSharing = false
                                    pendingShareCode = nil
                                }
                            }
                        }
                }
            }
    }
}

// MARK: - Filter Sheet Modifier
// Extracted to reduce body complexity and help Swift compiler

private struct InventoryFilterSheetModifier: ViewModifier {
    @Binding var showingFilterSheet: Bool
    @Binding var sortOption: InventorySortOption
    @Binding var selectedTags: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedManufacturers: Set<String>
    @Binding var selectedLocations: Set<String>
    @Binding var selectedProductTypes: Set<String>

    let allAvailableTags: [String]
    let allAvailableCOEs: [Int32]
    let availableManufacturers: [String]
    let availableLocations: [String]
    let availableProductTypes: [String]

    let tagCounts: [String: Int]
    let coeCounts: [Int32: Int]
    let manufacturerCounts: [String: Int]
    let locationCounts: [String: Int]
    let productTypeCounts: [String: Int]

    let manufacturerDisplayName: (String) -> String
    let productTypeDisplayName: (String) -> String

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingFilterSheet) {
                InventoryFilterSheet(
                    isPresented: $showingFilterSheet,
                    sortOption: $sortOption,
                    selectedTags: $selectedTags,
                    selectedCOEs: $selectedCOEs,
                    selectedManufacturers: $selectedManufacturers,
                    selectedLocations: $selectedLocations,
                    selectedProductTypes: $selectedProductTypes,
                    allAvailableTags: allAvailableTags,
                    allAvailableCOEs: allAvailableCOEs,
                    availableManufacturers: availableManufacturers,
                    availableLocations: availableLocations,
                    availableProductTypes: availableProductTypes,
                    tagCounts: tagCounts,
                    coeCounts: coeCounts,
                    manufacturerCounts: manufacturerCounts,
                    locationCounts: locationCounts,
                    productTypeCounts: productTypeCounts,
                    manufacturerDisplayName: manufacturerDisplayName,
                    productTypeDisplayName: productTypeDisplayName
                )
            }
    }
}

// MARK: - Notification Handlers Modifier
// Extracted to reduce body complexity and help Swift compiler

private struct NotificationHandlersModifier: ViewModifier {
    let catalogService: CatalogService
    let loadData: () async -> Void
    let updateFilteredItemsCache: () -> Void
    let setSearchText: (String) -> Void
    @Binding var filterRefreshTrigger: Int
    @Binding var navigationPath: NavigationPath
    @Binding var pendingShareCode: String?
    @Binding var showingSharing: Bool
    @Binding var showingFilterSheet: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .applyInventorySearch)) { notification in
                if let searchText = notification.userInfo?["searchText"] as? String {
                    setSearchText(searchText)
                    updateFilteredItemsCache()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { _ in
                Task {
                    await CatalogDataCache.shared.reload(catalogService: catalogService)
                    await loadData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryChanged)) { _ in
                Task {
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
                navigationPath = NavigationPath()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showInventoryFilters)) { _ in
                showingFilterSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToInventorySharingWithCode)) { notification in
                if let shareCode = notification.userInfo?["shareCode"] as? String {
                    pendingShareCode = shareCode
                    showingSharing = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                filterRefreshTrigger += 1
                updateFilteredItemsCache()
            }
            .onReceive(NotificationCenter.default.publisher(for: .cloudKitImportCompleted)) { _ in
                // Refresh inventory when CloudKit import completes (e.g., after fresh install)
                Task {
                    await CatalogDataCache.shared.reload(catalogService: catalogService)
                    await loadData()
                }
            }
    }
}

private extension View {
    func onFilterChange(viewModel: InventoryViewModel, updateCache: @escaping () -> Void) -> some View {
        modifier(FilterChangeModifier(viewModel: viewModel, updateCache: updateCache))
    }

    func withHelperSheets(
        showingAddItem: Binding<Bool>,
        showingLabelDesigner: Binding<Bool>,
        showingQRScanner: Binding<Bool>,
        showingUpgradePrompt: Binding<Bool>,
        showingHelp: Binding<Bool>,
        showingManageLocations: Binding<Bool>,
        showingSharing: Binding<Bool>,
        pendingShareCode: Binding<String?>,
        prefilledNaturalKey: String,
        sortedFilteredItems: [CompleteInventoryItemModel],
        inventoryItemCount: Int,
        inventoryLimit: Int?,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository,
        storageLocationRepository: StorageLocationRepository,
        inventoryTrackingService: InventoryTrackingService,
        catalogService: CatalogService,
        loadData: @escaping () async -> Void
    ) -> some View {
        modifier(InventoryHelperSheetsModifier(
            showingAddItem: showingAddItem,
            showingLabelDesigner: showingLabelDesigner,
            showingQRScanner: showingQRScanner,
            showingUpgradePrompt: showingUpgradePrompt,
            showingHelp: showingHelp,
            showingManageLocations: showingManageLocations,
            showingSharing: showingSharing,
            pendingShareCode: pendingShareCode,
            prefilledNaturalKey: prefilledNaturalKey,
            sortedFilteredItems: sortedFilteredItems,
            inventoryItemCount: inventoryItemCount,
            inventoryLimit: inventoryLimit,
            storageLocationDefinitionRepository: storageLocationDefinitionRepository,
            storageLocationRepository: storageLocationRepository,
            inventoryTrackingService: inventoryTrackingService,
            catalogService: catalogService,
            loadData: loadData
        ))
    }

    func withInventoryFilterSheet(
        showingFilterSheet: Binding<Bool>,
        sortOption: Binding<InventorySortOption>,
        selectedTags: Binding<Set<String>>,
        selectedCOEs: Binding<Set<Int32>>,
        selectedManufacturers: Binding<Set<String>>,
        selectedLocations: Binding<Set<String>>,
        selectedProductTypes: Binding<Set<String>>,
        allAvailableTags: [String],
        allAvailableCOEs: [Int32],
        availableManufacturers: [String],
        availableLocations: [String],
        availableProductTypes: [String],
        tagCounts: [String: Int],
        coeCounts: [Int32: Int],
        manufacturerCounts: [String: Int],
        locationCounts: [String: Int],
        productTypeCounts: [String: Int],
        manufacturerDisplayName: @escaping (String) -> String,
        productTypeDisplayName: @escaping (String) -> String
    ) -> some View {
        modifier(InventoryFilterSheetModifier(
            showingFilterSheet: showingFilterSheet,
            sortOption: sortOption,
            selectedTags: selectedTags,
            selectedCOEs: selectedCOEs,
            selectedManufacturers: selectedManufacturers,
            selectedLocations: selectedLocations,
            selectedProductTypes: selectedProductTypes,
            allAvailableTags: allAvailableTags,
            allAvailableCOEs: allAvailableCOEs,
            availableManufacturers: availableManufacturers,
            availableLocations: availableLocations,
            availableProductTypes: availableProductTypes,
            tagCounts: tagCounts,
            coeCounts: coeCounts,
            manufacturerCounts: manufacturerCounts,
            locationCounts: locationCounts,
            productTypeCounts: productTypeCounts,
            manufacturerDisplayName: manufacturerDisplayName,
            productTypeDisplayName: productTypeDisplayName
        ))
    }

    func onInventoryNotifications(
        catalogService: CatalogService,
        loadData: @escaping () async -> Void,
        updateFilteredItemsCache: @escaping () -> Void,
        setSearchText: @escaping (String) -> Void,
        filterRefreshTrigger: Binding<Int>,
        navigationPath: Binding<NavigationPath>,
        pendingShareCode: Binding<String?>,
        showingSharing: Binding<Bool>,
        showingFilterSheet: Binding<Bool>
    ) -> some View {
        modifier(NotificationHandlersModifier(
            catalogService: catalogService,
            loadData: loadData,
            updateFilteredItemsCache: updateFilteredItemsCache,
            setSearchText: setSearchText,
            filterRefreshTrigger: filterRefreshTrigger,
            navigationPath: navigationPath,
            pendingShareCode: pendingShareCode,
            showingSharing: showingSharing,
            showingFilterSheet: showingFilterSheet
        ))
    }
}

#Preview {
    InventoryView()
}
