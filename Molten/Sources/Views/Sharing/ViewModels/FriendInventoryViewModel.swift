//
//  FriendInventoryViewModel.swift
//  Molten
//
//  ViewModel for viewing a friend's shared inventory
//

import Foundation
import SwiftUI
import CoreData

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
    var comparisonMode: InventoryComparisonMode = .all

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

    // MARK: - Initialization

    init(
        friend: FriendShare,
        sharingManager: InventorySharingManager = RepositoryFactory.createInventorySharingManager(),
        catalogService: CatalogService = RepositoryFactory.createCatalogService(),
        sharedInventoryRepository: CoreDataSharedInventoryRepository = CoreDataSharedInventoryRepository(
            context: PersistenceController.shared.container.viewContext,
            catalogRepository: RepositoryFactory.createGlassItemRepository()
        )
    ) {
        self.friend = friend
        self.sharingManager = sharingManager
        self.catalogService = catalogService
        self.sharedInventoryRepository = sharedInventoryRepository
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
            // Need to show my items that aren't in their list
            let friendStableIds = Set(items.map { $0.snapshot.stableId })
            let myItemsTheyDontHave = myInventory.filter { myItem in
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

        return items
    }

    // MARK: - Helper Methods

    /// Check if I have an item in my inventory
    private func iHaveItem(stableId: String) -> Bool {
        return myInventory.contains { $0.catalogItem.stable_id == stableId }
    }

    // MARK: - Filter Management

    func clearAllFilters() {
        searchText = ""
        searchTitlesOnly = false
        selectedManufacturers.removeAll()
        selectedCOEs.removeAll()
        selectedTags.removeAll()
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
    let tags: [String]
    let coe: Int32
}
