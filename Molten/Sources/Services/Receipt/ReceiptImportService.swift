//
//  ReceiptImportService.swift
//  Molten
//
//  Service for importing receipt items into Core Data inventory.
//  Handles:
//  - PurchaseRecord deduplication (matching re-forwarded receipts)
//  - StorageLocation matching and splitting (linking to existing inventory)
//  - Creating new inventory from purchases
//

import Foundation

/// Import mode for receipt items
enum ReceiptImportMode {
    /// Add items as new inventory entries
    case addNew
    /// Try to match with existing inventory (and split if needed)
    case matchExisting
}

/// Result of attempting to match existing inventory
struct InventoryMatchResult {
    /// Total quantity available to match
    let availableQuantity: Double
    /// Total quantity requested from receipt
    let requestedQuantity: Double
    /// The locations that would be matched/split
    let matchingLocations: [StorageLocationModel]
    /// Whether we have enough inventory to fully match
    var isFullMatch: Bool { availableQuantity >= requestedQuantity }
    /// Shortfall if not enough inventory
    var shortfall: Double { max(0, requestedQuantity - availableQuantity) }
}

/// Options when inventory is less than receipt quantity
enum PartialMatchResolution {
    /// Add new inventory for the difference
    case addDifference
    /// Link what exists, create new for full receipt quantity (total = existing + receipt qty)
    case addFullQuantity
    /// Link what exists, record remainder as consumed
    case recordAsConsumed
}

/// Receipt import service - orchestrates importing receipts into Core Data
class ReceiptImportService {

    // MARK: - Dependencies

    private let purchaseRecordRepository: PurchaseRecordRepository
    private let storageLocationRepository: StorageLocationRepository
    private let inventoryRepository: InventoryRepository
    private let consumptionRepository: InventoryConsumptionRecordRepository

    // MARK: - Initialization

    init(
        purchaseRecordRepository: PurchaseRecordRepository,
        storageLocationRepository: StorageLocationRepository,
        inventoryRepository: InventoryRepository,
        consumptionRepository: InventoryConsumptionRecordRepository
    ) {
        self.purchaseRecordRepository = purchaseRecordRepository
        self.storageLocationRepository = storageLocationRepository
        self.inventoryRepository = inventoryRepository
        self.consumptionRepository = consumptionRepository
    }

    // MARK: - PurchaseRecord Deduplication

    /// Find an existing PurchaseRecord that matches this receipt (for deduplication)
    /// Returns nil if this is a new receipt that hasn't been imported before
    func findExistingPurchaseRecord(
        emailReceiptId: String?,
        orderNumber: String?,
        supplier: String,
        senderEmail: String?,
        orderDate: Date,
        total: Decimal?
    ) async throws -> PurchaseRecordModel? {
        // Strategy 1: Exact match by email receipt ID
        if let emailReceiptId = emailReceiptId {
            if let existing = try await purchaseRecordRepository.fetchRecord(byEmailReceiptId: emailReceiptId) {
                return existing
            }
        }

        // Strategy 2: Match by order number + supplier + same day
        if let orderNumber = orderNumber, !orderNumber.isEmpty {
            let matches = try await purchaseRecordRepository.fetchRecords(
                byOrderNumber: orderNumber,
                supplier: supplier,
                on: orderDate
            )
            if let existing = matches.first {
                return existing
            }
        }

        // Strategy 3: Match by sender email + same day + approximate total
        if let senderEmail = senderEmail {
            let matches = try await purchaseRecordRepository.fetchRecords(
                bySenderEmail: senderEmail,
                on: orderDate
            )
            // If we have a total, try to match approximately
            if let total = total {
                for match in matches {
                    if let matchTotal = match.totalPrice {
                        // Allow 1% tolerance for rounding differences
                        let tolerance = abs(matchTotal) * Decimal(0.01)
                        if abs(matchTotal - total) <= tolerance {
                            return match
                        }
                    }
                }
            }
            // If no total or no total match, return first match by sender/date
            if let existing = matches.first {
                return existing
            }
        }

        return nil
    }

    // MARK: - StorageLocation Matching

    /// Find existing unlinked StorageLocations that could match a receipt item
    /// Returns locations sorted by closeness to order date
    func findMatchingLocations(
        itemStableId: String,
        orderDate: Date,
        requestedQuantity: Double
    ) async throws -> InventoryMatchResult {
        // Find the inventory record for this item
        let inventories = try await inventoryRepository.fetchInventory(forItem: itemStableId)
        guard let inventory = inventories.first else {
            return InventoryMatchResult(
                availableQuantity: 0,
                requestedQuantity: requestedQuantity,
                matchingLocations: []
            )
        }

        // Get unlinked locations for this inventory
        // First try locations added on or after the order date
        var locations = try await storageLocationRepository.fetchUnlinkedLocations(
            forInventory: inventory.id,
            addedOnOrAfter: orderDate
        )

        // If not enough, also get locations from before order date (sorted by date descending)
        let availableAfter = locations.reduce(0.0) { $0 + $1.quantity }
        if availableAfter < requestedQuantity {
            let olderLocations = try await storageLocationRepository.fetchUnlinkedLocations(
                forInventory: inventory.id,
                addedOnOrAfter: nil
            ).filter { $0.dateAdded < orderDate }
            .sorted { $0.dateAdded > $1.dateAdded } // Most recent first

            locations.append(contentsOf: olderLocations)
        }

        // Sort by closeness to order date
        locations.sort { loc1, loc2 in
            let diff1 = abs(loc1.dateAdded.timeIntervalSince(orderDate))
            let diff2 = abs(loc2.dateAdded.timeIntervalSince(orderDate))
            return diff1 < diff2
        }

        let totalAvailable = locations.reduce(0.0) { $0 + $1.quantity }

        return InventoryMatchResult(
            availableQuantity: totalAvailable,
            requestedQuantity: requestedQuantity,
            matchingLocations: locations
        )
    }

    // MARK: - StorageLocation Splitting

    /// Link and split storage locations to match a purchase
    /// Returns the new/updated locations that are now linked to the purchase
    func linkAndSplitLocations(
        matchResult: InventoryMatchResult,
        purchaseRecordItemId: UUID,
        unitPrice: Decimal?,
        currency: String?
    ) async throws -> [StorageLocationModel] {
        var linkedLocations: [StorageLocationModel] = []
        var remainingToLink = matchResult.requestedQuantity

        for location in matchResult.matchingLocations {
            guard remainingToLink > 0 else { break }

            if location.quantity <= remainingToLink {
                // Link entire location
                let linked = StorageLocationModel(
                    id: location.id,
                    inventoryId: location.inventoryId,
                    storageLocationId: location.storageLocationId,
                    locationName: location.locationName,
                    quantity: location.quantity,
                    containerCount: location.containerCount,
                    dateAdded: location.dateAdded,
                    dateModified: Date(),
                    isTransfer: location.isTransfer,
                    workspaceId: location.workspaceId,
                    purchaseRecordItemId: purchaseRecordItemId,
                    unitPrice: unitPrice,
                    currency: currency
                )
                _ = try await storageLocationRepository.updateLocationById(linked)
                linkedLocations.append(linked)
                remainingToLink -= location.quantity
            } else {
                // Split: reduce original, create new linked portion
                // 1. Update original to have reduced quantity (unlinked remainder)
                let remainder = StorageLocationModel(
                    id: location.id,
                    inventoryId: location.inventoryId,
                    storageLocationId: location.storageLocationId,
                    locationName: location.locationName,
                    quantity: location.quantity - remainingToLink,
                    containerCount: nil, // Don't split container count
                    dateAdded: location.dateAdded,
                    dateModified: Date(),
                    isTransfer: location.isTransfer,
                    workspaceId: location.workspaceId,
                    purchaseRecordItemId: nil,
                    unitPrice: nil,
                    currency: nil
                )
                _ = try await storageLocationRepository.updateLocationById(remainder)

                // 2. Create new record for the linked portion
                let linked = StorageLocationModel(
                    id: UUID(),
                    inventoryId: location.inventoryId,
                    storageLocationId: location.storageLocationId,
                    locationName: location.locationName,
                    quantity: remainingToLink,
                    containerCount: nil,
                    dateAdded: location.dateAdded, // Inherit original date
                    dateModified: Date(),
                    isTransfer: false,
                    workspaceId: location.workspaceId,
                    purchaseRecordItemId: purchaseRecordItemId,
                    unitPrice: unitPrice,
                    currency: currency
                )
                _ = try await storageLocationRepository.createLocation(linked)
                linkedLocations.append(linked)
                remainingToLink = 0
            }
        }

        return linkedLocations
    }

    // MARK: - Import Operations

    /// Import a single receipt item as new inventory
    func importAsNewInventory(
        itemStableId: String,
        itemType: String,
        quantity: Double,
        purchaseRecordItemId: UUID,
        unitPrice: Decimal?,
        currency: String?,
        locationName: String = ""
    ) async throws -> StorageLocationModel {
        // Find or create inventory record
        let inventories = try await inventoryRepository.fetchInventory(forItem: itemStableId, type: itemType)
        var inventory = inventories.first

        if inventory == nil {
            // Create new inventory record
            let newInventory = InventoryModel(
                id: UUID(),
                item_stable_id: itemStableId,
                type: itemType,
                quantity: 0, // Will be updated by storage location
                date_added: Date(),
                date_modified: Date()
            )
            inventory = try await inventoryRepository.createInventory(newInventory)
        }

        guard let inv = inventory else {
            throw ReceiptImportError.inventoryCreationFailed
        }

        // Create storage location linked to purchase
        let storageLocation = StorageLocationModel(
            id: UUID(),
            inventoryId: inv.id,
            locationName: locationName,
            quantity: quantity,
            dateAdded: Date(),
            dateModified: Date(),
            purchaseRecordItemId: purchaseRecordItemId,
            unitPrice: unitPrice,
            currency: currency
        )

        return try await storageLocationRepository.createLocation(storageLocation)
    }

    /// Handle partial match by recording shortfall as consumed
    func recordAsConsumed(
        matchResult: InventoryMatchResult,
        unitPrice: Decimal?,
        currency: String?
    ) async throws {
        guard matchResult.shortfall > 0 else { return }
        guard let firstLocation = matchResult.matchingLocations.first else { return }

        let consumptionRecord = InventoryConsumptionRecordModel(
            id: UUID(),
            storageLocationId: firstLocation.id,
            quantity: matchResult.shortfall,
            containerCount: nil,
            date: Date(),
            unitPrice: unitPrice,
            currency: currency
        )

        _ = try await consumptionRepository.createOrUpdateConsumptionRecord(consumptionRecord)
    }
}

// MARK: - Errors

enum ReceiptImportError: Error, LocalizedError {
    case inventoryCreationFailed
    case purchaseRecordNotFound
    case invalidItemStableId

    var errorDescription: String? {
        switch self {
        case .inventoryCreationFailed:
            return "Failed to create inventory record"
        case .purchaseRecordNotFound:
            return "Purchase record not found"
        case .invalidItemStableId:
            return "Invalid item stable ID"
        }
    }
}
