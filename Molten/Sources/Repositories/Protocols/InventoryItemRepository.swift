//
//  LegacyInventoryItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  DEPRECATED: This entire file is deprecated in favor of the new GlassItem architecture
//

import Foundation
import CoreData

/// Repository protocol for inventory item operations, following established pattern
/// LEGACY: This will be replaced by the new GlassItem-based repository system
/// DEPRECATED: Use InventoryRepository instead
@available(*, deprecated, message: "Use InventoryRepository with InventoryModel instead")
protocol LegacyInventoryItemRepository {
    // Basic CRUD operations - all deprecated
    func fetchItems(matching predicate: NSPredicate?) async throws -> [Any]
    func fetchItem(byId id: String) async throws -> Any?
    func createItem(_ item: Any) async throws -> Any
    func updateItem(_ item: Any) async throws -> Any
    func deleteItem(id: String) async throws
    
    // Batch operations for efficiency - all deprecated
    func createItems(_ items: [Any]) async throws -> [Any]
    func deleteItems(ids: [String]) async throws
    func deleteItems(byCatalogCode catalogCode: String) async throws
    
    // Search & Filter operations - all deprecated
    func searchItems(text: String) async throws -> [Any]
    func fetchItems(byType type: String) async throws -> [Any]
    func fetchItems(byCatalogCode catalogCode: String) async throws -> [Any]
    
    // Business logic operations - all deprecated
    func getTotalQuantity(forCatalogCode catalogCode: String, type: String) async throws -> Double
    func getDistinctCatalogCodes() async throws -> [String]
    func consolidateItems(byCatalogCode: Bool) async throws -> [Any]
}

/// Migration guide for developers
struct LegacyInventoryMigrationGuide {
    static let migrationInstructions = """
    This LegacyInventoryItemRepository is deprecated. Please migrate to the new GlassItem architecture:
    
    OLD ARCHITECTURE:
    - InventoryItemModel -> Use InventoryModel instead
    - InventoryItemType -> Use String type identifiers instead
    - ConsolidatedInventoryModel -> Use CompleteInventoryItemModel instead
    - LegacyInventoryItemRepository -> Use InventoryRepository instead
    
    NEW ARCHITECTURE MAPPING:
    1. Replace InventoryItemModel with InventoryModel
    2. Replace InventoryItemType enum with String type field
    3. Replace ConsolidatedInventoryModel with CompleteInventoryItemModel
    4. Use InventoryRepository for CRUD operations
    5. Use InventoryTrackingService for business logic
    6. Use CatalogService for complete glass item management
    
    EXAMPLE MIGRATION:
    
    // Old:
    let legacyRepo: LegacyInventoryItemRepository = ...
    let items = try await legacyRepo.fetchItems(matching: nil)
    
    // New:
    let inventoryRepo: InventoryRepository = RepositoryFactory.createInventoryRepository()
    let inventories = try await inventoryRepo.fetchInventory(matching: nil)
    
    // For complete items with glass item data:
    let catalogService = RepositoryFactory.createCatalogService()
    let completeItems = try await catalogService.getAllGlassItems()
    """
}