//
//  EntityCoordinator.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated for GlassItem architecture - 10/14/25
//

import Foundation

/// Coordination service that works across multiple entity repositories
class EntityCoordinator {
    private let catalogService: CatalogService?
    private let inventoryTrackingService: InventoryTrackingService?
    private let purchaseRecordService: PurchaseRecordService?
    
    init(catalogService: CatalogService? = nil, 
         inventoryTrackingService: InventoryTrackingService? = nil,
         purchaseRecordService: PurchaseRecordService? = nil) {
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
        self.purchaseRecordService = purchaseRecordService
    }
    
    // MARK: - Catalog + Inventory Coordination
    
    func getInventoryForGlassItem(naturalKey: String) async throws -> GlassItemInventoryCoordination {
        guard let catalogService = catalogService,
              let inventoryTrackingService = inventoryTrackingService else {
            throw CoordinationError.missingServices
        }
        
        // Get complete glass item data
        guard let completeItem = try await inventoryTrackingService.getCompleteItem(naturalKey: naturalKey) else {
            throw CoordinationError.catalogItemNotFound
        }
        
        // Get inventory summary for this item
        let inventorySummary = try await inventoryTrackingService.getInventorySummary(for: naturalKey)
        
        let totalQuantity = inventorySummary?.summary.totalQuantity ?? 0.0
        let hasInventory = totalQuantity > 0
        
        return GlassItemInventoryCoordination(
            completeItem: completeItem,
            inventorySummary: inventorySummary,
            totalQuantity: totalQuantity,
            hasInventory: hasInventory
        )
    }
    
    // MARK: - Purchase + Inventory Correlation
    
    func correlatePurchasesWithInventory(naturalKey: String) async throws -> PurchaseInventoryCorrelation {
        guard let inventoryTrackingService = inventoryTrackingService,
              let purchaseRecordService = purchaseRecordService else {
            throw CoordinationError.missingServices
        }
        
        // Get complete item data
        guard let completeItem = try await inventoryTrackingService.getCompleteItem(naturalKey: naturalKey) else {
            throw CoordinationError.catalogItemNotFound
        }
        
        // Get inventory for this item
        let inventoryRecords = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: naturalKey)
        let totalQuantityInInventory = inventoryRecords.reduce(0.0) { $0 + $1.quantity }
        
        // Get purchase records (simplified - in reality would need better correlation)
        let allPurchases = try await purchaseRecordService.getAllRecords()
        let relatedPurchases = allPurchases.filter { purchase in
            // Correlate by natural key or glass item name
            purchase.notes?.contains(naturalKey) == true ||
            purchase.notes?.contains(completeItem.glassItem.name) == true
        }
        
        let totalSpent = relatedPurchases.compactMap { $0.totalPrice }.reduce(Decimal(0), +)
        let totalSpentDouble = NSDecimalNumber(decimal: totalSpent).doubleValue
        let averagePricePerUnit = totalQuantityInInventory > 0 ? totalSpentDouble / totalQuantityInInventory : 0.0
        
        return PurchaseInventoryCorrelation(
            naturalKey: naturalKey,
            totalSpent: totalSpentDouble,
            totalQuantityInInventory: totalQuantityInInventory,
            averagePricePerUnit: averagePricePerUnit,
            purchaseRecords: relatedPurchases,
            inventoryRecords: inventoryRecords,
            completeItem: completeItem
        )
    }
    
    // MARK: - Glass Item Search with Inventory Context
    
    func searchGlassItemsWithInventoryContext(searchText: String) async throws -> [GlassItemInventoryCoordination] {
        guard let catalogService = catalogService,
              let inventoryTrackingService = inventoryTrackingService else {
            throw CoordinationError.missingServices
        }
        
        // Search glass items
        let glassItems = try await catalogService.getAllGlassItems()
        let filteredItems = glassItems.filter { item in
            item.glassItem.name.localizedCaseInsensitiveContains(searchText) ||
            item.glassItem.natural_key.localizedCaseInsensitiveContains(searchText) ||
            item.glassItem.manufacturer.localizedCaseInsensitiveContains(searchText)
        }
        
        // Get inventory context for each item
        var results: [GlassItemInventoryCoordination] = []
        
        for item in filteredItems {
            let inventorySummary = try await inventoryTrackingService.getInventorySummary(for: item.glassItem.natural_key)
            let totalQuantity = inventorySummary?.summary.totalQuantity ?? 0.0
            let hasInventory = totalQuantity > 0
            
            let coordination = GlassItemInventoryCoordination(
                completeItem: item,
                inventorySummary: inventorySummary,
                totalQuantity: totalQuantity,
                hasInventory: hasInventory
            )
            
            results.append(coordination)
        }
        
        return results
    }
}

// MARK: - Coordination Data Models

struct GlassItemInventoryCoordination {
    let completeItem: CompleteInventoryItemModel
    let inventorySummary: DetailedInventorySummaryModel?
    let totalQuantity: Double
    let hasInventory: Bool
    
    /// Convenience access to glass item data
    var glassItem: GlassItemModel {
        return completeItem.glassItem
    }
    
    /// Convenience access to tags
    var tags: [String] {
        return completeItem.tags
    }
    
    /// Convenience access to locations
    var locations: [LocationModel] {
        return completeItem.locations
    }
}

struct PurchaseInventoryCorrelation {
    let naturalKey: String
    let totalSpent: Double
    let totalQuantityInInventory: Double
    let averagePricePerUnit: Double
    let purchaseRecords: [PurchaseRecordModel]
    let inventoryRecords: [InventoryModel]
    let completeItem: CompleteInventoryItemModel
    
    /// Convenience access to glass item data
    var glassItem: GlassItemModel {
        return completeItem.glassItem
    }
}

// MARK: - Coordination Errors

enum CoordinationError: Error, LocalizedError {
    case missingServices
    case catalogItemNotFound
    case inventoryItemNotFound
    case purchaseRecordNotFound
    
    var errorDescription: String? {
        switch self {
        case .missingServices:
            return "Required services not provided to coordinator"
        case .catalogItemNotFound:
            return "Catalog item not found"
        case .inventoryItemNotFound:
            return "Inventory item not found"
        case .purchaseRecordNotFound:
            return "Purchase record not found"
        }
    }
}
