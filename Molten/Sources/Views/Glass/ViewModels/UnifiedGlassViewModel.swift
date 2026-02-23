//
//  UnifiedGlassViewModel.swift
//  Molten
//
//  Created by Assistant on 2/5/26.
//  Unified ViewModel combining Catalog, Inventory, and Shopping list views
//

import Foundation
import SwiftUI
import Combine

/// Quick filter modes for the unified glass view
enum GlassQuickFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case myGlass = "Mine"
    case wishList = "Wish List"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .myGlass: return "archivebox"
        case .wishList: return "heart"
        }
    }
}

/// Sort options for the unified glass view
enum UnifiedGlassSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case manufacturer = "Manufacturer"
    case code = "Code"
    case rating = "Rating"
    case quantity = "Quantity"

    var id: String { rawValue }
}

/// Unified ViewModel for the Glass view
///
/// Combines functionality from CatalogViewModel, InventoryViewModel, and ShoppingListViewModel
/// into a single view with quick-filter tabs (All / My Glass / Wish List)
@MainActor
@Observable
class UnifiedGlassViewModel {

    // MARK: - Dependencies

    private let catalogService: CatalogService
    private let shoppingListService: ShoppingListService
    private let inventoryTrackingService: InventoryTrackingService

    // MARK: - UserDefaults Keys

    private static let quickFilterKey = "unifiedGlass.quickFilter"
    private static let sortOptionKey = "unifiedGlass.sortOption"
    private static let productTypeFilterKey = "unifiedGlass.selectedProductTypes"
    private static let coeFilterKey = "unifiedGlass.selectedCOEs"
    private static let manufacturerFilterKey = "unifiedGlass.selectedManufacturers"
    private static let tagsFilterKey = "unifiedGlass.selectedTags"
    private static let searchTitlesOnlyKey = "unifiedGlass.searchTitlesOnly"
    private static let selectedLocationsKey = "unifiedGlass.selectedLocations"
    private static let selectedStoreKey = "unifiedGlass.selectedStore"
    private static let onlineInStockOnlyKey = "unifiedGlass.onlineInStockOnly"

    // MARK: - Data State

    /// All catalog items (complete with inventory data)
    var allItems: [CompleteInventoryItemModel] = []

    /// Shopping list data by store
    var shoppingLists: [String: DetailedShoppingListModel] = [:]

    /// Items after applying quick filter and all other filters
    var filteredItems: [CompleteInventoryItemModel] = []

    /// Shopping list items (filtered) - only populated when quickFilter == .wishList
    var filteredShoppingItems: [DetailedShoppingListItemModel] = []

    /// Loading state
    var isLoading = true

    /// Error message if loading failed
    var errorMessage: String?

    // MARK: - Quick Filter State

    var quickFilter: GlassQuickFilter = .all {
        didSet {
            if quickFilter != oldValue {
                saveQuickFilter()
                applyFilters()
            }
        }
    }

    // MARK: - Search State

    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?
    private static let searchDebounceDelay: UInt64 = 300_000_000 // 300ms

    @ObservationIgnored private var _searchText = ""
    var searchText: String {
        get { _searchText }
        set {
            _searchText = newValue
            debounceSearch(newValue)
        }
    }

    var debouncedSearchText = ""

    var searchTitlesOnly = false {  // TODO: revert to true later - temporarily searching descriptions too
        didSet {
            if searchTitlesOnly != oldValue {
                saveSearchTitlesOnly()
                applyFilters()
            }
        }
    }

    // MARK: - Filter State (persists across quick-filter switches)

    var selectedTags: Set<String> = [] {
        didSet {
            if selectedTags != oldValue {
                saveTagsFilter()
                applyFilters()
            }
        }
    }

    var selectedCOEs: Set<Int32> = [] {
        didSet {
            if selectedCOEs != oldValue {
                saveCOEFilter()
                applyFilters()
            }
        }
    }

    var selectedManufacturers: Set<String> = [] {
        didSet {
            if selectedManufacturers != oldValue {
                saveManufacturerFilter()
                applyFilters()
            }
        }
    }

    var selectedProductTypes: Set<String> = [] {
        didSet {
            if selectedProductTypes != oldValue {
                saveProductTypeFilter()
                applyFilters()
            }
        }
    }

    // MARK: - Context-Specific Filters

    /// Location filter (only used in "My Glass" mode)
    var selectedLocations: Set<String> = [] {
        didSet {
            if selectedLocations != oldValue {
                saveLocationsFilter()
                applyFilters()
            }
        }
    }

    /// Store filter (only used in "Wish List" mode)
    var selectedStore: String? = nil {
        didSet {
            if selectedStore != oldValue {
                saveStoreFilter()
                applyFilters()
            }
        }
    }

    /// Online stock filter - when true, only show items available online
    var onlineInStockOnly: Bool = false {
        didSet {
            if onlineInStockOnly != oldValue {
                saveOnlineInStockFilter()
                applyFilters()
            }
        }
    }

    // MARK: - Sort State

    var sortOption: UnifiedGlassSortOption = .name {
        didSet {
            if sortOption != oldValue {
                saveSortOption()
                applyFilters()
            }
        }
    }

    // MARK: - Color Search State

    /// Whether color search is currently active
    var colorSearchActive = false

    /// The selected color for searching
    var searchColor: Color = .blue

    /// Color match tolerance (Delta E: 3 = very close, 25 = similar)
    var colorTolerance: Double = 12.0

    /// Which color variance levels to include in search results
    var colorVarianceFilter: ColorVarianceFilter = .high

    /// Cached color distances for sorting (stable_id -> distance)
    private var colorDistanceCache: [String: Double] = [:]

    /// Apply color search and filter the list
    func applyColorSearch() {
        colorSearchActive = true
        applyFilters()
    }

    /// Clear color search and return to normal list
    func clearColorSearch() {
        colorSearchActive = false
        colorDistanceCache.removeAll()
        applyFilters()
    }

    // MARK: - Cached Values

    private var cachedAllTags: [String] = []
    private var cachedUserTags: Set<String> = []
    private var cachedAllCOEs: [Int32] = []
    private var cachedManufacturers: [String] = []
    private var cachedLocations: [String] = []
    private var cachedStores: [String] = []

    // MARK: - Filter Counts

    private(set) var manufacturerCounts: [String: Int] = [:]
    private(set) var coeCounts: [Int32: Int] = [:]
    private(set) var tagCounts: [String: Int] = [:]
    private(set) var productTypeCounts: [String: Int] = [:]
    private(set) var locationCounts: [String: Int] = [:]

    // Observer for UserDefaults changes
    nonisolated(unsafe) private var userDefaultsObserver: NSObjectProtocol?

    // MARK: - Initialization

    init(catalogService: CatalogService, shoppingListService: ShoppingListService, inventoryTrackingService: InventoryTrackingService) {
        self.catalogService = catalogService
        self.shoppingListService = shoppingListService
        self.inventoryTrackingService = inventoryTrackingService

        loadSavedState()
        setupUserDefaultsObserver()
    }

    nonisolated deinit {
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func loadSavedState() {
        // Quick filter
        if let savedFilter = UserDefaults.standard.string(forKey: Self.quickFilterKey),
           let filter = GlassQuickFilter(rawValue: savedFilter) {
            self._quickFilter = filter
        }

        // Sort option
        if let savedSort = UserDefaults.standard.string(forKey: Self.sortOptionKey),
           let sort = UnifiedGlassSortOption(rawValue: savedSort) {
            self._sortOption = sort
        }

        // Product type filter
        if let savedData = UserDefaults.standard.data(forKey: Self.productTypeFilterKey),
           let savedTypes = try? JSONDecoder().decode(Set<String>.self, from: savedData) {
            self._selectedProductTypes = savedTypes
        }

        // COE filter
        if let savedData = UserDefaults.standard.data(forKey: Self.coeFilterKey),
           let savedCOEs = try? JSONDecoder().decode([Int32].self, from: savedData) {
            self._selectedCOEs = Set(savedCOEs)
        }

        // Manufacturer filter
        if let savedData = UserDefaults.standard.data(forKey: Self.manufacturerFilterKey),
           let savedManufacturers = try? JSONDecoder().decode([String].self, from: savedData) {
            self._selectedManufacturers = Set(savedManufacturers)
        }

        // Tags filter
        if let savedData = UserDefaults.standard.data(forKey: Self.tagsFilterKey),
           let savedTags = try? JSONDecoder().decode([String].self, from: savedData) {
            self._selectedTags = Set(savedTags)
        }

        // Search titles only
        if UserDefaults.standard.object(forKey: Self.searchTitlesOnlyKey) != nil {
            self._searchTitlesOnly = UserDefaults.standard.bool(forKey: Self.searchTitlesOnlyKey)
        }

        // Locations filter
        if let savedData = UserDefaults.standard.data(forKey: Self.selectedLocationsKey),
           let savedLocations = try? JSONDecoder().decode([String].self, from: savedData) {
            self._selectedLocations = Set(savedLocations)
        }

        // Store filter
        self._selectedStore = UserDefaults.standard.string(forKey: Self.selectedStoreKey)

        // Online in stock filter
        if UserDefaults.standard.object(forKey: Self.onlineInStockOnlyKey) != nil {
            self._onlineInStockOnly = UserDefaults.standard.bool(forKey: Self.onlineInStockOnlyKey)
        }
    }

    private func setupUserDefaultsObserver() {
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Reapply filters when global settings change
            self?.applyFilters()
        }
    }

    // MARK: - Computed Properties

    var allAvailableTags: [String] { cachedAllTags }
    var allUserTags: Set<String> { cachedUserTags }
    var allAvailableCOEs: [Int32] { cachedAllCOEs }
    var availableManufacturers: [String] { cachedManufacturers }
    var availableLocations: [String] { cachedLocations }
    var availableStores: [String] { cachedStores }

    var hasData: Bool { !allItems.isEmpty }

    var hasActiveFilters: Bool {
        !debouncedSearchText.isEmpty ||
        !selectedTags.isEmpty ||
        !selectedCOEs.isEmpty ||
        !selectedManufacturers.isEmpty ||
        !selectedProductTypes.isEmpty ||
        !selectedLocations.isEmpty ||
        selectedStore != nil ||
        onlineInStockOnly
    }

    var activeFilterCount: Int {
        var count = 0
        if !selectedTags.isEmpty { count += 1 }
        if !selectedCOEs.isEmpty { count += 1 }
        if !selectedManufacturers.isEmpty { count += 1 }
        if !selectedProductTypes.isEmpty { count += 1 }
        if !selectedLocations.isEmpty { count += 1 }
        if selectedStore != nil { count += 1 }
        if onlineInStockOnly { count += 1 }
        return count
    }

    var emptyStateMessage: String {
        generateEmptyStateMessage()
    }

    /// Set of item stable_ids that are on the shopping list
    var shoppingListItemIds: Set<String> {
        Set(shoppingLists.values.flatMap { $0.items.map { $0.catalogItem.stable_id } })
    }

    /// Set of item stable_ids that have inventory
    var inventoryItemIds: Set<String> {
        Set(allItems.filter { $0.hasInventory }.map { $0.catalogItem.stable_id })
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load catalog items via cache (includes online stock enrichment) and shopping lists in parallel
            async let catalogItems = CatalogDataCache.loadItems(using: catalogService)
            async let shoppingData = shoppingListService.generateAllShoppingLists()

            allItems = await catalogItems
            shoppingLists = try await shoppingData

            updateCaches()
            applyFilters()
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
            allItems = []
            shoppingLists = [:]
            filteredItems = []
            filteredShoppingItems = []
        }

        isLoading = false
    }

    func refreshData() async {
        await loadData()
    }

    // MARK: - Search

    private func debounceSearch(_ text: String) {
        searchDebounceTask?.cancel()

        if text.isEmpty {
            debouncedSearchText = ""
            applyFilters()
            return
        }

        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: Self.searchDebounceDelay)
                if !Task.isCancelled && _searchText == text {
                    debouncedSearchText = text
                    applyFilters()
                }
            } catch {
                // Cancelled
            }
        }
    }

    func clearAllFilters() {
        searchText = ""
        debouncedSearchText = ""
        selectedTags = []
        selectedCOEs = []
        selectedManufacturers = []
        selectedProductTypes = []
        selectedLocations = []
        selectedStore = nil
        onlineInStockOnly = false
    }

    // MARK: - Filtering

    func applyFilters() {
        switch quickFilter {
        case .all:
            applyAllModeFilters()
        case .myGlass:
            applyMyGlassFilters()
        case .wishList:
            applyWishListFilters()
        }

        updateFilterCounts()
        notifyFilterCountChanged()
    }

    private func applyAllModeFilters() {
        var filtered = allItems

        // Apply common filters
        filtered = applyCommonFilters(to: filtered)

        // Sort
        filteredItems = sortItems(filtered)
        filteredShoppingItems = []
    }

    private func applyMyGlassFilters() {
        // Start with items that have inventory
        var filtered = allItems.filter { $0.hasInventory }

        // Apply common filters
        filtered = applyCommonFilters(to: filtered)

        // Apply location filter (specific to My Glass mode)
        if !selectedLocations.isEmpty {
            filtered = filtered.filter { item in
                let itemLocations = item.locations
                if itemLocations.isEmpty {
                    return selectedLocations.contains(LocationQuickFilterBar.noLocationValue)
                } else {
                    return !selectedLocations.isDisjoint(with: Set(itemLocations))
                }
            }
        }

        // Sort
        filteredItems = sortItems(filtered)
        filteredShoppingItems = []
    }

    private func applyWishListFilters() {
        var items = shoppingLists.values.flatMap { $0.items }

        // Apply search filter
        if !debouncedSearchText.isEmpty {
            let searchLower = debouncedSearchText.lowercased()
            items = items.filter { item in
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
            items = items.filter { selectedProductTypes.contains($0.catalogItem.itemType.rawValue) }
        }

        // Apply manufacturer filter
        if !selectedManufacturers.isEmpty {
            items = items.filter { selectedManufacturers.contains($0.catalogItem.manufacturer) }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                if item.catalogItem.itemType != .glass { return true }
                if let coe = item.catalogItem.coe {
                    return selectedCOEs.contains(coe)
                }
                return false
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { !selectedTags.isDisjoint(with: Set($0.allTags)) }
        }

        // Apply store filter (specific to Wish List mode)
        if let store = selectedStore {
            items = items.filter { $0.shoppingListItem.store == store }
        }

        // Sort
        filteredShoppingItems = sortShoppingItems(items)
        filteredItems = []
    }

    private func applyCommonFilters(to items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        var filtered = items

        // Search filter
        if !debouncedSearchText.isEmpty && SearchTextParser.isSearchTextMeaningful(debouncedSearchText) {
            let searchMode = SearchTextParser.parseSearchText(debouncedSearchText)
            filtered = filtered.filter { item in
                if searchTitlesOnly {
                    return SearchTextParser.matchesName(name: item.catalogItem.name, mode: searchMode)
                } else {
                    let allFields = [
                        item.catalogItem.name,
                        item.catalogItem.stable_id,
                        item.catalogItem.manufacturer,
                        item.catalogItem.sku,
                        item.catalogItem.mfr_notes
                    ].compactMap { $0 }
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
            }
        }

        // Product type filter
        if !selectedProductTypes.isEmpty {
            filtered = filtered.filter { selectedProductTypes.contains($0.catalogItem.itemType.rawValue) }
        }

        // Manufacturer filter
        if !selectedManufacturers.isEmpty {
            filtered = filtered.filter { selectedManufacturers.contains($0.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }

        // COE filter
        if !selectedCOEs.isEmpty {
            filtered = filtered.filter { item in
                if item.catalogItem.itemType != .glass { return true }
                if let coe = item.catalogItem.coe {
                    return selectedCOEs.contains(coe)
                }
                return true
            }
        }

        // Tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { !selectedTags.isDisjoint(with: Set($0.allTags)) }
        }

        // Online in stock filter
        if onlineInStockOnly {
            filtered = filtered.filter { $0.isOnlineInStock }
        }

        // Color search filter
        if colorSearchActive {
            filtered = applyColorFilter(to: filtered)
        }

        return filtered
    }

    /// Apply color search filter and sort by color match quality
    private func applyColorFilter(to items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        // Clear cache for fresh calculation
        colorDistanceCache.removeAll()

        // Filter items that match the color criteria
        var matchingItems: [(item: CompleteInventoryItemModel, distance: Double)] = []

        for item in items {
            // Get dominant colors from the catalog item
            let dominantColors = item.catalogItem.dominant_colors ?? []

            // Skip items without color data
            guard !dominantColors.isEmpty else { continue }

            // Get color confidence (high, medium, low) - defaults to "medium" if not set
            let confidence = item.catalogItem.color_confidence ?? "medium"

            // Check if this item's variance level is included in the filter
            let isIncludedByVariance = colorVarianceFilter.includes(confidence: confidence)

            // If item is excluded by variance filter, skip it entirely
            guard isIncludedByVariance else { continue }

            // Calculate color distance
            if let distance = ColorDistance.minimumDistance(from: searchColor, to: dominantColors) {
                // For low-confidence (high-variance) items, include them regardless of distance
                // but give them a penalty for sorting purposes
                if confidence == "low" {
                    // Always include low-confidence items (reactive, dichroic, etc.)
                    // Use max of actual distance and 30 to sort them after good matches
                    let sortDistance = max(distance, 30.0)
                    matchingItems.append((item, sortDistance))
                    colorDistanceCache[item.catalogItem.stable_id] = sortDistance
                } else if distance <= colorTolerance {
                    // Normal matching based on tolerance
                    matchingItems.append((item, distance))
                    colorDistanceCache[item.catalogItem.stable_id] = distance
                }
            }
        }

        // Sort by color match quality (best matches first)
        matchingItems.sort { $0.distance < $1.distance }

        return matchingItems.map { $0.item }
    }

    // MARK: - Sorting

    private func sortItems(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        items.sorted { item1, item2 in
            switch sortOption {
            case .name:
                return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
            case .manufacturer:
                return item1.catalogItem.manufacturer.localizedCaseInsensitiveCompare(item2.catalogItem.manufacturer) == .orderedAscending
            case .code:
                return item1.catalogItem.stable_id.localizedCaseInsensitiveCompare(item2.catalogItem.stable_id) == .orderedAscending
            case .rating:
                switch (item1.rating, item2.rating) {
                case (.some(let r1), .some(let r2)):
                    if r1.averageRating != r2.averageRating {
                        return r1.averageRating > r2.averageRating
                    }
                    return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
                }
            case .quantity:
                let q1 = item1.totalQuantity
                let q2 = item2.totalQuantity
                if q1 != q2 {
                    return q1 > q2
                }
                return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
            }
        }
    }

    private func sortShoppingItems(_ items: [DetailedShoppingListItemModel]) -> [DetailedShoppingListItemModel] {
        items.sorted { item1, item2 in
            switch sortOption {
            case .name:
                return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
            case .manufacturer:
                return item1.catalogItem.manufacturer.localizedCaseInsensitiveCompare(item2.catalogItem.manufacturer) == .orderedAscending
            case .code:
                return item1.catalogItem.stable_id.localizedCaseInsensitiveCompare(item2.catalogItem.stable_id) == .orderedAscending
            case .rating, .quantity:
                // For shopping items, default to name sort for these options
                return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
            }
        }
    }

    // MARK: - Cache Updates

    private func updateCaches() {
        var allTagsSet = Set<String>()
        var userTagsSet = Set<String>()
        var allCOEsSet = Set<Int32>()
        var manufacturersSet = Set<String>()
        var locationsSet = Set<String>()

        for item in allItems {
            allTagsSet.formUnion(item.allTags)
            userTagsSet.formUnion(item.userTags)

            if let coe = item.catalogItem.coe {
                allCOEsSet.insert(coe)
            }

            let mfr = item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mfr.isEmpty {
                manufacturersSet.insert(mfr)
            }

            locationsSet.formUnion(item.locations)
        }

        cachedAllTags = allTagsSet.sorted()
        cachedUserTags = userTagsSet
        cachedAllCOEs = allCOEsSet.sorted()
        cachedManufacturers = manufacturersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        cachedLocations = locationsSet.sorted()

        // Update stores from shopping lists
        let storesSet = Set(shoppingLists.values.flatMap { $0.items.map { $0.shoppingListItem.store } })
        cachedStores = storesSet.sorted()
    }

    private func updateFilterCounts() {
        // Compute counts based on current quick filter context
        manufacturerCounts = computeManufacturerCounts()
        coeCounts = computeCOECounts()
        tagCounts = computeTagCounts()
        productTypeCounts = computeProductTypeCounts()
        locationCounts = computeLocationCounts()
    }

    private func computeManufacturerCounts() -> [String: Int] {
        let baseItems: [CompleteInventoryItemModel]
        switch quickFilter {
        case .all:
            baseItems = allItems
        case .myGlass:
            baseItems = allItems.filter { $0.hasInventory }
        case .wishList:
            // For wish list, count from shopping items
            var counts: [String: Int] = [:]
            for item in shoppingLists.values.flatMap({ $0.items }) {
                counts[item.catalogItem.manufacturer, default: 0] += 1
            }
            return counts
        }

        var counts: [String: Int] = [:]
        for item in baseItems {
            counts[item.catalogItem.manufacturer, default: 0] += 1
        }
        return counts
    }

    private func computeCOECounts() -> [Int32: Int] {
        let baseItems: [CompleteInventoryItemModel]
        switch quickFilter {
        case .all:
            baseItems = allItems.filter { $0.catalogItem.itemType == .glass }
        case .myGlass:
            baseItems = allItems.filter { $0.hasInventory && $0.catalogItem.itemType == .glass }
        case .wishList:
            var counts: [Int32: Int] = [:]
            for item in shoppingLists.values.flatMap({ $0.items }) {
                if let coe = item.catalogItem.coe {
                    counts[coe, default: 0] += 1
                }
            }
            return counts
        }

        var counts: [Int32: Int] = [:]
        for item in baseItems {
            if let coe = item.catalogItem.coe {
                counts[coe, default: 0] += 1
            }
        }
        return counts
    }

    private func computeTagCounts() -> [String: Int] {
        let baseItems: [CompleteInventoryItemModel]
        switch quickFilter {
        case .all:
            baseItems = allItems
        case .myGlass:
            baseItems = allItems.filter { $0.hasInventory }
        case .wishList:
            var counts: [String: Int] = [:]
            for item in shoppingLists.values.flatMap({ $0.items }) {
                for tag in item.allTags {
                    counts[tag, default: 0] += 1
                }
            }
            return counts
        }

        var counts: [String: Int] = [:]
        for item in baseItems {
            for tag in item.allTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    private func computeProductTypeCounts() -> [String: Int] {
        let baseItems: [CompleteInventoryItemModel]
        switch quickFilter {
        case .all:
            baseItems = allItems
        case .myGlass:
            baseItems = allItems.filter { $0.hasInventory }
        case .wishList:
            var counts: [String: Int] = [:]
            for item in shoppingLists.values.flatMap({ $0.items }) {
                counts[item.catalogItem.itemType.rawValue, default: 0] += 1
            }
            return counts
        }

        var counts: [String: Int] = [:]
        for item in baseItems {
            counts[item.catalogItem.itemType.rawValue, default: 0] += 1
        }
        return counts
    }

    private func computeLocationCounts() -> [String: Int] {
        // Only relevant for My Glass mode
        guard quickFilter == .myGlass else { return [:] }

        let baseItems = allItems.filter { $0.hasInventory }
        var counts: [String: Int] = [:]
        for item in baseItems {
            for location in item.locations {
                counts[location, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - Persistence

    private func saveQuickFilter() {
        UserDefaults.standard.set(quickFilter.rawValue, forKey: Self.quickFilterKey)
    }

    private func saveSortOption() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortOptionKey)
    }

    private func saveProductTypeFilter() {
        if let encoded = try? JSONEncoder().encode(selectedProductTypes) {
            UserDefaults.standard.set(encoded, forKey: Self.productTypeFilterKey)
        }
    }

    private func saveCOEFilter() {
        if let encoded = try? JSONEncoder().encode(Array(selectedCOEs)) {
            UserDefaults.standard.set(encoded, forKey: Self.coeFilterKey)
        }
    }

    private func saveManufacturerFilter() {
        if let encoded = try? JSONEncoder().encode(Array(selectedManufacturers)) {
            UserDefaults.standard.set(encoded, forKey: Self.manufacturerFilterKey)
        }
    }

    private func saveTagsFilter() {
        if let encoded = try? JSONEncoder().encode(Array(selectedTags)) {
            UserDefaults.standard.set(encoded, forKey: Self.tagsFilterKey)
        }
    }

    private func saveSearchTitlesOnly() {
        UserDefaults.standard.set(searchTitlesOnly, forKey: Self.searchTitlesOnlyKey)
    }

    private func saveLocationsFilter() {
        if let encoded = try? JSONEncoder().encode(Array(selectedLocations)) {
            UserDefaults.standard.set(encoded, forKey: Self.selectedLocationsKey)
        }
    }

    private func saveStoreFilter() {
        if let store = selectedStore {
            UserDefaults.standard.set(store, forKey: Self.selectedStoreKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedStoreKey)
        }
    }

    private func saveOnlineInStockFilter() {
        UserDefaults.standard.set(onlineInStockOnly, forKey: Self.onlineInStockOnlyKey)
    }

    private func notifyFilterCountChanged() {
        NotificationCenter.default.post(
            name: .catalogFilterCountChanged,
            object: nil,
            userInfo: ["count": activeFilterCount]
        )
    }

    private func generateEmptyStateMessage() -> String {
        var filters: [String] = []

        if !debouncedSearchText.isEmpty {
            filters.append("'\(debouncedSearchText)'")
        }

        if !selectedManufacturers.isEmpty {
            let mfrText = selectedManufacturers.count == 1 ? "manufacturer" : "manufacturers"
            let mfrList = selectedManufacturers.sorted().compactMap { GlassManufacturers.fullName(for: $0) ?? $0 }.joined(separator: ", ")
            filters.append("\(mfrText) \(mfrList)")
        }

        if !selectedTags.isEmpty {
            let tagText = selectedTags.count == 1 ? "tag" : "tags"
            filters.append("\(tagText) '\(selectedTags.sorted().joined(separator: "', '"))'")
        }

        if !selectedCOEs.isEmpty {
            let coeText = selectedCOEs.count == 1 ? "COE" : "COEs"
            let coeList = selectedCOEs.sorted().map { String($0) }.joined(separator: ", ")
            filters.append("\(coeText) \(coeList)")
        }

        let modeText: String
        switch quickFilter {
        case .all:
            modeText = "catalog items"
        case .myGlass:
            modeText = "items in your inventory"
        case .wishList:
            modeText = "items on your wish list"
        }

        if filters.isEmpty {
            return "No \(modeText) found"
        } else {
            return "No \(modeText) match " + filters.joined(separator: " and ")
        }
    }
}

// MARK: - Service Access

extension UnifiedGlassViewModel {
    var exposedCatalogService: CatalogService { catalogService }
    var exposedShoppingListService: ShoppingListService { shoppingListService }
    var exposedInventoryTrackingService: InventoryTrackingService { inventoryTrackingService }
}
