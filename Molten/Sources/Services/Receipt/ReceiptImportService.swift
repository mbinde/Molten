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

/// Confidence level for potential duplicate detection
enum DuplicateConfidence: Comparable {
    case high      // Same order number (any date) - very likely duplicate
    case medium    // Same supplier + significant item overlap (50%+)
    case low       // Same supplier + some item overlap or same supplier + recent

    var displayName: String {
        switch self {
        case .high: return "Likely duplicate"
        case .medium: return "Possible duplicate"
        case .low: return "Similar purchase"
        }
    }
}

/// A potential duplicate purchase record with confidence and reasons
struct PotentialDuplicate: Identifiable {
    var id: UUID { existingRecord.id }
    let existingRecord: PurchaseRecordModel
    let confidence: DuplicateConfidence
    let reasons: [String]
    let itemOverlapPercentage: Double?  // nil if not calculated
}

/// Result of attempting to match existing inventory
struct InventoryMatchResult: Sendable {
    /// Total quantity available to match
    let availableQuantity: Double
    /// Total quantity requested from receipt
    let requestedQuantity: Double
    /// The locations that would be matched/split
    let matchingLocations: [StorageLocationModel]
    /// Whether we have enough inventory to fully match
    nonisolated var isFullMatch: Bool { availableQuantity >= requestedQuantity }
    /// Shortfall if not enough inventory
    nonisolated var shortfall: Double { max(0, requestedQuantity - availableQuantity) }
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

        // Note: We intentionally don't use sender_email for matching because when
        // users forward receipts, the sender_email is always THEIR email (the forwarder),
        // not the retailer's email. This would incorrectly match all receipts forwarded
        // on the same day.

        return nil
    }

    /// Find potential duplicate purchases (for user warning, not automatic deduplication)
    /// This finds records that might be related to the same order, even if not exact matches
    func findPotentialDuplicates(
        orderNumber: String?,
        supplier: String,
        receiptItems: [ReceiptItem],
        excludingRecordId: UUID? = nil
    ) async throws -> [PotentialDuplicate] {
        var candidates: [PotentialDuplicate] = []
        var seenIds = Set<UUID>()

        // Exclude the already-matched exact duplicate if provided
        if let excludeId = excludingRecordId {
            seenIds.insert(excludeId)
        }

        // Strategy 1: Same order number (any date) - HIGH confidence
        if let orderNumber = orderNumber, !orderNumber.isEmpty {
            let orderMatches = try await purchaseRecordRepository.fetchRecords(byOrderNumber: orderNumber)
            for record in orderMatches where !seenIds.contains(record.id) {
                seenIds.insert(record.id)
                var reasons = ["Same order number: \(orderNumber)"]

                // Check item overlap for extra context
                let overlap = calculateItemOverlap(receiptItems: receiptItems, existingRecord: record)
                if let overlap = overlap, overlap > 0 {
                    reasons.append("\(Int(overlap * 100))% of items match")
                }

                candidates.append(PotentialDuplicate(
                    existingRecord: record,
                    confidence: .high,
                    reasons: reasons,
                    itemOverlapPercentage: overlap
                ))
            }
        }

        // Strategy 2: Same supplier + recent (within 30 days) + item overlap
        let recentFromSupplier = try await purchaseRecordRepository.fetchRecentRecords(bySupplier: supplier, within: 30)
        for record in recentFromSupplier where !seenIds.contains(record.id) {
            let overlap = calculateItemOverlap(receiptItems: receiptItems, existingRecord: record)

            // Require at least some item overlap to flag as potential duplicate
            guard let overlap = overlap, overlap > 0.3 else { continue }

            seenIds.insert(record.id)

            let confidence: DuplicateConfidence = overlap >= 0.5 ? .medium : .low
            var reasons = ["\(Int(overlap * 100))% of items match"]

            // Add date context
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            reasons.append("From \(supplier) on \(formatter.string(from: record.datePurchased))")

            candidates.append(PotentialDuplicate(
                existingRecord: record,
                confidence: confidence,
                reasons: reasons,
                itemOverlapPercentage: overlap
            ))
        }

        // Sort by confidence (high first), then by date (most recent first)
        return candidates.sorted { a, b in
            if a.confidence != b.confidence {
                return a.confidence > b.confidence
            }
            return a.existingRecord.datePurchased > b.existingRecord.datePurchased
        }
    }

    /// Calculate what percentage of receipt items match items in an existing record
    /// Returns nil if we can't calculate (no items with hashes)
    private func calculateItemOverlap(receiptItems: [ReceiptItem], existingRecord: PurchaseRecordModel) -> Double? {
        guard !receiptItems.isEmpty else { return nil }
        guard !existingRecord.items.isEmpty else { return nil }

        // Get hashes from existing record items
        let existingHashes = Set(existingRecord.items.compactMap { $0.receiptLineHash })

        // Also match by item_stable_id in case hashes aren't available
        let existingStableIds = Set(existingRecord.items.map { $0.item_stable_id })

        var matchCount = 0
        for receiptItem in receiptItems {
            // Check hash match
            if existingHashes.contains(receiptItem.lineHash) {
                matchCount += 1
                continue
            }

            // Check stable_id match (if the receipt item has a catalog match)
            if let stableId = receiptItem.catalogStableId, existingStableIds.contains(stableId) {
                matchCount += 1
            }
        }

        return Double(matchCount) / Double(receiptItems.count)
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
    /// - Parameters:
    ///   - itemStableId: The catalog item's stable ID
    ///   - itemType: The inventory type (e.g., "rod", "frit")
    ///   - quantity: The quantity (weight in grams for weight-based types, count for others)
    ///   - containerCount: Optional number of containers/jars (for frit tracked by jars)
    ///   - purchaseRecordItemId: ID of the purchase record item
    ///   - unitPrice: Price per unit
    ///   - currency: Currency code
    ///   - locationName: Storage location name
    func importAsNewInventory(
        itemStableId: String,
        itemType: String,
        quantity: Double,
        containerCount: Double? = nil,
        purchaseRecordItemId: UUID,
        unitPrice: Decimal?,
        currency: String?,
        locationName: String = "",
        purchaseDate: Date? = nil
    ) async throws -> StorageLocationModel {
        // Find or create inventory record
        let inventories = try await inventoryRepository.fetchInventory(forItem: itemStableId, type: itemType)
        var inventory = inventories.first

        if inventory == nil {
            // Create new inventory record with the imported quantity
            let newInventory = InventoryModel(
                id: UUID(),
                item_stable_id: itemStableId,
                type: itemType,
                quantity: quantity,
                date_added: Date(),
                date_modified: Date()
            )
            inventory = try await inventoryRepository.createInventory(newInventory)
        } else {
            // Update existing inventory to add the imported quantity
            let existingQuantity = inventory!.quantity
            let updatedInventory = InventoryModel(
                id: inventory!.id,
                item_stable_id: inventory!.item_stable_id,
                type: inventory!.type,
                quantity: existingQuantity + quantity,
                date_added: inventory!.date_added,
                date_modified: Date()
            )
            inventory = try await inventoryRepository.updateInventory(updatedInventory)
        }

        guard let inv = inventory else {
            throw ReceiptImportError.inventoryCreationFailed
        }

        // Create storage location linked to purchase
        // Use purchase date if provided, otherwise fall back to current date
        let locationDate = purchaseDate ?? Date()
        let storageLocation = StorageLocationModel(
            id: UUID(),
            inventoryId: inv.id,
            locationName: locationName,
            quantity: quantity,
            containerCount: containerCount,
            dateAdded: locationDate,
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
