//
//  FriendInventoryViewModel.swift
//  Molten
//
//  ViewModel for viewing a friend's shared inventory
//

import Foundation
import SwiftUI
import CoreData

/// Sort options for friend inventory
enum FriendInventorySortOption: String, CaseIterable {
    case name = "Name"
    case quantity = "Quantity"
    case manufacturer = "Manufacturer"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .name: return "textformat.abc"
        case .quantity: return "archivebox.fill"
        case .manufacturer: return "building.2"
        }
    }
}

/// Comparison mode for filtering friend inventory
enum InventoryComparisonMode {
    case all                // Show all items
    case theyHaveIDoNot     // Items friend has but I don't
    case iHaveTheyDoNot     // Items I have but friend doesn't
    case weBothHave         // Items we both have
}

@MainActor
@Observable
class FriendInventoryViewModel {

    // MARK: - Properties

    private let catalogService: CatalogService
    private let sharingManager: InventorySharingManager
    private let sharedInventoryRepository: CoreDataSharedInventoryRepository
    let friend: FriendShare

    // State
    var isLoading = false
    var errorMessage: String?
    var rawInventory: [InventoryItemSnapshot] = []
    private var myInventory: [CompleteInventoryItemModel] = []

    // Enriched inventory (with catalog data)
    var enrichedInventory: [EnrichedFriendInventoryItem] = []

    // Search and filter
    var searchText = ""
    var searchTitlesOnly = false
    var selectedManufacturers: Set<String> = []
    var selectedCOEs: Set<Int32> = []
    var selectedTags: Set<String> = []
    var selectedProductTypes: Set<String> = []
    var comparisonMode: InventoryComparisonMode = .all
    var sortOption: FriendInventorySortOption = .name

    // Computed filter options
    var availableManufacturers: [String] {
        Array(Set(enrichedInventory.map { $0.snapshot.manufacturer })).sorted()
    }

    var availableCOEs: [Int32] {
        Array(Set(enrichedInventory.compactMap { $0.catalogData?.coe })).sorted()
    }

    var availableTags: [String] {
        Array(Set(enrichedInventory.flatMap { $0.catalogData?.tags ?? [] })).sorted()
    }

    var availableProductTypes: [String] {
        Array(Set(enrichedInventory.map { $0.snapshot.unit })).sorted()
    }

    // MARK: - Filter Counts

    var manufacturerCounts: [String: Int] {
        computeManufacturerCounts()
    }

    var coeCounts: [Int32: Int] {
        computeCOECounts()
    }

    var tagCounts: [String: Int] {
        computeTagCounts()
    }

    var productTypeCounts: [String: Int] {
        computeProductTypeCounts()
    }

    // MARK: - Initialization

    init(
        friend: FriendShare,
        sharingManager: InventorySharingManager,
        catalogService: CatalogService,
        sharedInventoryRepository: CoreDataSharedInventoryRepository
    ) {
        self.friend = friend
        self.sharingManager = sharingManager
        self.catalogService = catalogService
        self.sharedInventoryRepository = sharedInventoryRepository
    }

    /// Convenience init using AppDependencies
    convenience init(friend: FriendShare, deps: AppDependencies = AppDependencies()) {
        let sharedInventoryRepository = CoreDataSharedInventoryRepository(
            context: PersistenceController.shared.container.viewContext,
            catalogRepository: deps.glassItemRepository
        )
        self.init(
            friend: friend,
            sharingManager: deps.inventorySharingManager,
            catalogService: deps.catalogService,
            sharedInventoryRepository: sharedInventoryRepository
        )
    }

    // MARK: - Data Loading

    /// Load inventory from cache first, then optionally refresh from server
    func loadInventory(forceRefresh: Bool = false) async {
        // Load my inventory for comparison
        await loadMyInventory()

        // Try to load from Core Data cache first
        if !forceRefresh {
            do {
                let cached = try await sharedInventoryRepository.getSnapshot(shareCode: friend.shareCode)
                if !cached.isEmpty {
                    rawInventory = cached
                    await enrichInventoryData()
                } else {
                    // Show loading state if no cache available
                    isLoading = true
                }
            } catch {
                // If cache load fails, show loading state
                isLoading = true
            }
        } else {
            // Show loading state when forcing refresh
            isLoading = true
        }

        // Always refresh from server to get latest data
        await refreshFromServer()
    }

    /// Load user's own inventory for comparison
    private func loadMyInventory() async {
        do {
            myInventory = try await catalogService.getAllGlassItems()
            // Only keep items with inventory quantity
            myInventory = myInventory.filter { $0.totalQuantity > 0 }
        } catch {
            // If we can't load user's inventory, comparison filters won't work
            // But we can still show friend's inventory
            myInventory = []
        }
    }

    /// Refresh inventory from server
    private func refreshFromServer() async {
        errorMessage = nil

        do {
            let result = try await sharingManager.refreshFriendShare(shareCode: friend.shareCode)

            if !result.isValid {
                errorMessage = "Warning: Share signature is invalid. Data may have been tampered with."
            }

            rawInventory = result.items

            // Enrich with catalog data
            await enrichInventoryData()

        } catch SharingManagerError.shareDeletedByOwner {
            // Share was deleted by owner - clear cached data and show message
            print("🔐 [VIEW] Share was deleted by owner, clearing UI")
            rawInventory = []
            enrichedInventory = []
            errorMessage = "This share is no longer available. The owner has deleted it."
        } catch {
            // Only show error if we don't have cached data
            if rawInventory.isEmpty {
                errorMessage = "Failed to load inventory: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    /// Enriches snapshot data with catalog information (name, image, tags, COE)
    private func enrichInventoryData() async {
        var enriched: [EnrichedFriendInventoryItem] = []

        for snapshot in rawInventory {
            // Try to find matching catalog item
            if let catalogItem = try? await catalogService.getGlassItemByNaturalKey(snapshot.stableId) {
                enriched.append(EnrichedFriendInventoryItem(
                    snapshot: snapshot,
                    catalogData: CatalogData(
                        name: catalogItem.glassItem.name,
                        imagePath: catalogItem.glassItem.image_path,
                        imageThumbPath: catalogItem.glassItem.image_thumb_path,
                        tags: catalogItem.allTags,
                        coe: catalogItem.glassItem.coe
                    )
                ))
            } else {
                // Item not in our catalog - use basic data only
                enriched.append(EnrichedFriendInventoryItem(
                    snapshot: snapshot,
                    catalogData: nil
                ))
            }
        }

        enrichedInventory = enriched
    }

    // MARK: - Filtering

    var filteredInventory: [EnrichedFriendInventoryItem] {
        var items = enrichedInventory

        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                // Search by name (if available)
                if let name = item.catalogData?.name, name.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // Search by manufacturer
                if item.snapshot.manufacturer.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // Search by SKU
                if item.snapshot.sku.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                // Search by stable ID
                if item.snapshot.stableId.localizedCaseInsensitiveContains(searchText) {
                    return true
                }

                return false
            }
        }

        // Apply manufacturer filter
        if !selectedManufacturers.isEmpty {
            items = items.filter { selectedManufacturers.contains($0.snapshot.manufacturer) }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                if let coe = item.catalogData?.coe {
                    return selectedCOEs.contains(coe)
                }
                return false
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { item in
                if let tags = item.catalogData?.tags {
                    return !selectedTags.isDisjoint(with: Set(tags))
                }
                return false
            }
        }

        // Apply product type filter
        if !selectedProductTypes.isEmpty {
            items = items.filter { selectedProductTypes.contains($0.snapshot.unit) }
        }

        // Apply comparison filter
        switch comparisonMode {
        case .all:
            break // Show all items (no additional filtering)

        case .theyHaveIDoNot:
            // Show items friend has but I don't
            items = items.filter { friendItem in
                !iHaveItem(stableId: friendItem.snapshot.stableId)
            }

        case .iHaveTheyDoNot:
            // Show items I have but friend doesn't
            // First, apply the same filters to my inventory
            var filteredMyInventory = myInventory

            // Apply manufacturer filter
            if !selectedManufacturers.isEmpty {
                filteredMyInventory = filteredMyInventory.filter { selectedManufacturers.contains($0.catalogItem.manufacturer) }
            }

            // Apply COE filter
            if !selectedCOEs.isEmpty {
                filteredMyInventory = filteredMyInventory.filter { myItem in
                    if let coe = myItem.catalogItem.coe {
                        return selectedCOEs.contains(coe)
                    }
                    return false
                }
            }

            // Apply tag filter
            if !selectedTags.isEmpty {
                filteredMyInventory = filteredMyInventory.filter { myItem in
                    !selectedTags.isDisjoint(with: Set(myItem.allTags))
                }
            }

            // Apply product type filter
            if !selectedProductTypes.isEmpty {
                filteredMyInventory = filteredMyInventory.filter { myItem in
                    // Check if any of the item's inventory types match selected types
                    myItem.inventory.contains { inventory in
                        selectedProductTypes.contains(inventory.type)
                    }
                }
            }

            // Apply search filter
            if !searchText.isEmpty {
                filteredMyInventory = filteredMyInventory.filter { myItem in
                    myItem.catalogItem.name.localizedCaseInsensitiveContains(searchText) ||
                    myItem.catalogItem.manufacturer.localizedCaseInsensitiveContains(searchText) ||
                    (myItem.catalogItem.sku?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    myItem.catalogItem.stable_id.localizedCaseInsensitiveContains(searchText)
                }
            }

            // Now find items in filtered my inventory that aren't in friend's list
            let friendStableIds = Set(enrichedInventory.map { $0.snapshot.stableId })
            let myItemsTheyDontHave = filteredMyInventory.filter { myItem in
                !friendStableIds.contains(myItem.catalogItem.stable_id)
            }

            // Convert my items to enriched format
            items = myItemsTheyDontHave.compactMap { myItem in
                EnrichedFriendInventoryItem(
                    snapshot: InventoryItemSnapshot(
                        stableId: myItem.catalogItem.stable_id,
                        manufacturer: myItem.catalogItem.manufacturer,
                        sku: myItem.catalogItem.sku ?? "",
                        quantity: myItem.totalQuantity,
                        unit: myItem.inventory.first?.type ?? "unknown",
                        location: myItem.inventory.first?.location
                    ),
                    catalogData: CatalogData(
                        name: myItem.catalogItem.name,
                        imagePath: myItem.catalogItem.image_path,
                        imageThumbPath: myItem.catalogItem.image_thumb_path,
                        tags: myItem.allTags,
                        coe: myItem.catalogItem.coe ?? 0
                    )
                )
            }

        case .weBothHave:
            // Show items we both have
            items = items.filter { friendItem in
                iHaveItem(stableId: friendItem.snapshot.stableId)
            }
        }

        // Apply sorting
        switch sortOption {
        case .name:
            items.sort { lhs, rhs in
                let lhsName = lhs.catalogData?.name ?? lhs.snapshot.stableId
                let rhsName = rhs.catalogData?.name ?? rhs.snapshot.stableId
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }
        case .quantity:
            items.sort { lhs, rhs in
                lhs.snapshot.quantity > rhs.snapshot.quantity
            }
        case .manufacturer:
            items.sort { lhs, rhs in
                lhs.snapshot.manufacturer.localizedCaseInsensitiveCompare(rhs.snapshot.manufacturer) == .orderedAscending
            }
        }

        return items
    }

    // MARK: - Helper Methods

    /// Check if I have an item in my inventory
    private func iHaveItem(stableId: String) -> Bool {
        return myInventory.contains { $0.catalogItem.stable_id == stableId }
    }

    // MARK: - Filter Count Computation

    /// Count items per manufacturer based on current filters (excluding manufacturer filter itself)
    private func computeManufacturerCounts() -> [String: Int] {
        var items = enrichedInventory

        // Apply all filters EXCEPT manufacturer
        if !selectedTags.isEmpty {
            items = items.filter { item in
                guard let tags = item.catalogData?.tags else { return false }
                return !selectedTags.isDisjoint(with: Set(tags))
            }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                guard let coe = item.catalogData?.coe else { return false }
                return selectedCOEs.contains(coe)
            }
        }

        if !selectedProductTypes.isEmpty {
            items = items.filter { selectedProductTypes.contains($0.snapshot.unit) }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.catalogData?.name ?? ""
                let manufacturer = item.snapshot.manufacturer
                let sku = item.snapshot.sku
                let stableId = item.snapshot.stableId

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        var counts: [String: Int] = [:]
        for item in items {
            counts[item.snapshot.manufacturer, default: 0] += 1
        }
        return counts
    }

    /// Count items per COE based on current filters (excluding COE filter itself)
    private func computeCOECounts() -> [Int32: Int] {
        var items = enrichedInventory

        // Apply all filters EXCEPT COE
        if !selectedManufacturers.isEmpty {
            items = items.filter { selectedManufacturers.contains($0.snapshot.manufacturer) }
        }

        if !selectedTags.isEmpty {
            items = items.filter { item in
                guard let tags = item.catalogData?.tags else { return false }
                return !selectedTags.isDisjoint(with: Set(tags))
            }
        }

        if !selectedProductTypes.isEmpty {
            items = items.filter { selectedProductTypes.contains($0.snapshot.unit) }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.catalogData?.name ?? ""
                let manufacturer = item.snapshot.manufacturer
                let sku = item.snapshot.sku
                let stableId = item.snapshot.stableId

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        var counts: [Int32: Int] = [:]
        for item in items {
            if let coe = item.catalogData?.coe {
                counts[coe, default: 0] += 1
            }
        }
        return counts
    }

    /// Count items per tag based on current filters (excluding tag filter itself)
    private func computeTagCounts() -> [String: Int] {
        var items = enrichedInventory

        // Apply all filters EXCEPT tags
        if !selectedManufacturers.isEmpty {
            items = items.filter { selectedManufacturers.contains($0.snapshot.manufacturer) }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                guard let coe = item.catalogData?.coe else { return false }
                return selectedCOEs.contains(coe)
            }
        }

        if !selectedProductTypes.isEmpty {
            items = items.filter { selectedProductTypes.contains($0.snapshot.unit) }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.catalogData?.name ?? ""
                let manufacturer = item.snapshot.manufacturer
                let sku = item.snapshot.sku
                let stableId = item.snapshot.stableId

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        var counts: [String: Int] = [:]
        for item in items {
            if let tags = item.catalogData?.tags {
                for tag in tags {
                    counts[tag, default: 0] += 1
                }
            }
        }
        return counts
    }

    /// Count items per product type based on current filters (excluding product type filter itself)
    private func computeProductTypeCounts() -> [String: Int] {
        var items = enrichedInventory

        // Apply all filters EXCEPT product type
        if !selectedManufacturers.isEmpty {
            items = items.filter { selectedManufacturers.contains($0.snapshot.manufacturer) }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                guard let coe = item.catalogData?.coe else { return false }
                return selectedCOEs.contains(coe)
            }
        }

        if !selectedTags.isEmpty {
            items = items.filter { item in
                guard let tags = item.catalogData?.tags else { return false }
                return !selectedTags.isDisjoint(with: Set(tags))
            }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.catalogData?.name ?? ""
                let manufacturer = item.snapshot.manufacturer
                let sku = item.snapshot.sku
                let stableId = item.snapshot.stableId

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        var counts: [String: Int] = [:]
        for item in items {
            counts[item.snapshot.unit, default: 0] += 1
        }
        return counts
    }

    // MARK: - Filter Management

    func clearAllFilters() {
        searchText = ""
        searchTitlesOnly = false
        selectedManufacturers.removeAll()
        selectedCOEs.removeAll()
        selectedTags.removeAll()
        selectedProductTypes.removeAll()
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Supporting Types

/// Enriched friend inventory item with catalog data
struct EnrichedFriendInventoryItem: Identifiable {
    let snapshot: InventoryItemSnapshot
    let catalogData: CatalogData?

    var id: String { snapshot.stableId }
}

/// Catalog data for enriching friend inventory
struct CatalogData {
    let name: String
    let imagePath: String?
    let imageThumbPath: String?
    let tags: [String]
    let coe: Int32
}
