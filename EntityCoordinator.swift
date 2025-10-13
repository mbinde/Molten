//
//  EntityCoordinator.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Coordination service that works across multiple entity repositories
class EntityCoordinator {
    private let catalogService: CatalogService?
    private let inventoryService: InventoryService?
    private let purchaseService: PurchaseService?
    
    init(catalogService: CatalogService? = nil, 
         inventoryService: InventoryService? = nil,
         purchaseService: PurchaseService? = nil) {
        self.catalogService = catalogService
        self.inventoryService = inventoryService
        self.purchaseService = purchaseService
    }
    
    // MARK: - Catalog + Inventory Coordination
    
    func getInventoryForCatalogItem(catalogItemCode: String) async throws -> CatalogInventoryCoordination {
        guard let catalogService = catalogService,
              let inventoryService = inventoryService else {
            throw CoordinationError.missingServices
        }
        
        // Get catalog item by code
        let catalogItems = try await catalogService.searchItems(searchText: catalogItemCode)
        guard let catalogItem = catalogItems.first(where: { $0.code == catalogItemCode }) else {
            throw CoordinationError.catalogItemNotFound
        }
        
        // Get related inventory items
        let inventoryItems = try await inventoryService.getItems(byCatalogCode: catalogItemCode)
        
        let totalQuantity = inventoryItems.reduce(0) { $0 + $1.quantity }
        let hasInventory = totalQuantity > 0
        
        return CatalogInventoryCoordination(
            catalogItem: catalogItem,
            inventoryItems: inventoryItems,
            totalQuantity: totalQuantity,
            hasInventory: hasInventory
        )
    }
    
    // MARK: - Purchase + Inventory Correlation
    
    func correlatePurchasesWithInventory(catalogCode: String) async throws -> PurchaseInventoryCorrelation {
        guard let inventoryService = inventoryService,
              let purchaseService = purchaseService else {
            throw CoordinationError.missingServices
        }
        
        // Get inventory items for this catalog code
        let inventoryItems = try await inventoryService.getItems(byCatalogCode: catalogCode)
        let buyItems = inventoryItems.filter { $0.type == .buy }
        let totalQuantityPurchased = buyItems.reduce(0) { $0 + $1.quantity }
        
        // Get purchase records (simplified - in reality would need better correlation)
        let allPurchases = try await purchaseService.getAllRecords()
        let relatedPurchases = allPurchases.filter { purchase in
            purchase.notes?.contains(catalogCode) == true
        }
        
        let totalSpent = relatedPurchases.reduce(0.0) { $0 + $1.price }
        let averagePricePerUnit = totalQuantityPurchased > 0 ? totalSpent / Double(totalQuantityPurchased) : 0.0
        
        return PurchaseInventoryCorrelation(
            catalogCode: catalogCode,
            totalSpent: totalSpent,
            totalQuantityPurchased: totalQuantityPurchased,
            averagePricePerUnit: averagePricePerUnit,
            purchaseRecords: relatedPurchases,
            inventoryItems: buyItems
        )
    }
}

// MARK: - Coordination Data Models

struct CatalogInventoryCoordination {
    let catalogItem: CatalogItemModel
    let inventoryItems: [InventoryItemModel]
    let totalQuantity: Int
    let hasInventory: Bool
}

struct PurchaseInventoryCorrelation {
    let catalogCode: String
    let totalSpent: Double
    let totalQuantityPurchased: Int
    let averagePricePerUnit: Double
    let purchaseRecords: [PurchaseRecordModel]
    let inventoryItems: [InventoryItemModel]
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