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

/// Repository-based InventoryView that uses the new GlassItem architecture
struct InventoryView: View {
    @State private var searchText = ""
    @State private var searchTitlesOnly = false  // Inventory doesn't need title-only search
    @State private var showingAddItem = false
    @State private var prefilledNaturalKey: String = ""
    @State private var navigationPath = NavigationPath()
    @State private var showingAddFromCatalog = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var selectedManufacturers: Set<String> = []
    @State private var showingManufacturerSelection = false
    @State private var sortOption: InventorySortOption = .name
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var searchClearedFeedback = false
    @State private var glassItems: [CompleteInventoryItemModel] = []
    @State private var isLoading = false
    @State private var refreshTrigger = 0  // Force SwiftUI to refresh list
    @State private var showingLabelDesigner = false

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedManufacturers: [String] = []

    // CRITICAL: Service instances (not optional - always provided)
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService

    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Flameworker", category: "InventoryView")

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

    // Initialize with repository-based services
    init(
        catalogService: CatalogService = RepositoryFactory.createCatalogService(),
        inventoryTrackingService: InventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
    ) {
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
    }
    
    // Computed properties
    private var filteredItems: [CompleteInventoryItemModel] {
        var items = glassItems

        // Only show items with inventory (totalQuantity > 0)
        items = items.filter { $0.totalQuantity > 0 }

        // Apply manufacturer filter
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.tags))
            }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        // Apply search filter using SearchTextParser for advanced search (including grey/gray synonyms)
        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                let allFields = [
                    item.glassItem.name,
                    item.glassItem.natural_key,
                    item.glassItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        return items
    }
    
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return filteredItems.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
            switch sortOption {
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

    // MARK: - Filter Counts (for display in filter selection sheets)

    /// Count items per manufacturer based on current filters (excluding manufacturer filter itself)
    private var manufacturerCounts: [String: Int] {
        var items = glassItems.filter { $0.totalQuantity > 0 }

        // Apply all filters EXCEPT manufacturer
        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.tags))
            }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                let allFields = [
                    item.glassItem.name,
                    item.glassItem.natural_key,
                    item.glassItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        // Count items per manufacturer
        var counts: [String: Int] = [:]
        for item in items {
            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            counts[mfr, default: 0] += 1
        }
        return counts
    }

    /// Count items per COE based on current filters (excluding COE filter itself)
    private var coeCounts: [Int32: Int] {
        var items = glassItems.filter { $0.totalQuantity > 0 }

        // Apply all filters EXCEPT COE
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.tags))
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                let allFields = [
                    item.glassItem.name,
                    item.glassItem.natural_key,
                    item.glassItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        // Count items per COE
        var counts: [Int32: Int] = [:]
        for item in items {
            counts[item.glassItem.coe, default: 0] += 1
        }
        return counts
    }

    /// Count items per tag based on current filters (excluding tag filter itself)
    private var tagCounts: [String: Int] {
        var items = glassItems.filter { $0.totalQuantity > 0 }

        // Apply all filters EXCEPT tags
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                let allFields = [
                    item.glassItem.name,
                    item.glassItem.natural_key,
                    item.glassItem.manufacturer
                ]
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }

        // Count items per tag
        var counts: [String: Int] = [:]
        for item in items {
            for tag in item.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    /// Recompute caches when inventory data changes
    /// This is expensive (O(n)) so only call when data actually changes
    private func updateCaches() {
        let itemsWithInventory = glassItems.filter { $0.totalQuantity > 0 }

        // Extract all tags, COEs, and manufacturers
        var allTagsSet = Set<String>()
        var allCOEsSet = Set<Int32>()
        var manufacturersSet = Set<String>()

        for item in itemsWithInventory {
            allTagsSet.formUnion(item.tags)
            allCOEsSet.insert(item.glassItem.coe)

            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mfr.isEmpty {
                manufacturersSet.insert(mfr)
            }
        }

        cachedAllTags = allTagsSet.sorted()
        cachedAllCOEs = allCOEsSet.sorted()
        cachedManufacturers = manufacturersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search and filter controls using shared component
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
                    allAvailableManufacturers: allAvailableManufacturers,
                    manufacturerDisplayName: { code in
                        GlassManufacturers.fullName(for: code) ?? code
                    },
                    manufacturerCounts: manufacturerCounts,
                    coeCounts: coeCounts,
                    tagCounts: tagCounts,
                    sortMenuContent: {
                        AnyView(
                            Group {
                                ForEach(InventorySortOption.allCases, id: \.self) { option in
                                    Button {
                                        sortOption = option
                                    } label: {
                                        Label(option.title, systemImage: option.icon)
                                    }
                                }
                            }
                        )
                    },
                    searchClearedFeedback: $searchClearedFeedback,
                    searchPlaceholder: "Search inventory by name, code, manufacturer..."
                )

                // Main content
                Group {
                    if isEmpty {
                        inventoryEmptyState
                    } else {
                        inventoryListView
                    }
                }
            }
            .navigationTitle("Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
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
                    selectedCOEs: $selectedCOEs,
                    itemCounts: coeCounts
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
                    inventoryTrackingService: inventoryTrackingService,
                    catalogService: catalogService
                )
            }
            .sheet(isPresented: $showingLabelDesigner) {
                LabelDesignerView(items: sortedFilteredItems)
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
        }
    }
    
    // MARK: - Views
    
    private var inventoryEmptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "archivebox")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("No Inventory Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start tracking your glass inventory by adding your first item")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Add Item") {
                    showingAddItem = true
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var inventoryListView: some View {
        List {
            ForEach(sortedFilteredItems, id: \.id) { item in
                NavigationLink(value: item) {
                    GlassItemRowView.inventory(item: item)
                }
            }
        }
        .id(refreshTrigger)  // Force list to refresh when trigger changes
        .navigationDestination(for: CompleteInventoryItemModel.self) { item in
            InventoryDetailView(
                item: item,
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }

                ImportInventoryTriggerView {
                    // Refresh inventory after import completes
                    Task {
                        await CatalogDataCache.shared.reload(catalogService: catalogService)
                        await loadData()
                    }
                }

                Divider()

                Button {
                    showingLabelDesigner = true
                } label: {
                    Label("Print Labels", systemImage: "qrcode")
                }
                .disabled(sortedFilteredItems.isEmpty)
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        log.info("🔄 InventoryView loadData() called")
        isLoading = true

        // Use preloaded cache for faster performance
        let items = await CatalogDataCache.loadItems(using: catalogService)
        await MainActor.run {
            let itemsWithInventory = items.filter { $0.totalQuantity > 0 }
            let previousWithInventory = glassItems.filter { $0.totalQuantity > 0 }
            log.info("✅ Loaded \(items.count) glass items (previously had \(glassItems.count))")
            log.info("📊 Items with inventory: \(itemsWithInventory.count) (previously \(previousWithInventory.count))")
            glassItems = items
            updateCaches()  // PERFORMANCE: Update cached filter values
            refreshTrigger += 1  // Force SwiftUI to refresh the list
            isLoading = false
        }
    }
}

#Preview {
    InventoryView()
}
