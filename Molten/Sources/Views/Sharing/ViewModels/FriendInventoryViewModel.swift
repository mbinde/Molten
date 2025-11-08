//
//  FriendInventoryViewModel.swift
//  Molten
//
//  ViewModel for viewing a friend's shared inventory
//

import Foundation
import SwiftUI
import CoreData

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

    // Enriched inventory (with catalog data)
    var enrichedInventory: [EnrichedFriendInventoryItem] = []

    // Search and filter
    var searchText = ""
    var searchTitlesOnly = false
    var selectedManufacturers: Set<String> = []
    var selectedCOEs: Set<Int32> = []
    var selectedTags: Set<String> = []

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

        return items
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
