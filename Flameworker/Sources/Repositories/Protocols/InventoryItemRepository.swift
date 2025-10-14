//
//  LegacyInventoryItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData

/// Repository protocol for inventory item operations, following established pattern
/// LEGACY: This will be replaced by the new GlassItem-based repository system
protocol LegacyInventoryItemRepository {
    // Basic CRUD operations
    func fetchItems(matching predicate: NSPredicate?) async throws -> [InventoryItemModel]
    func fetchItem(byId id: String) async throws -> InventoryItemModel?
    func createItem(_ item: InventoryItemModel) async throws -> InventoryItemModel
    func updateItem(_ item: InventoryItemModel) async throws -> InventoryItemModel
    func deleteItem(id: String) async throws
    
    // Batch operations for efficiency
    func createItems(_ items: [InventoryItemModel]) async throws -> [InventoryItemModel]
    func deleteItems(ids: [String]) async throws
    func deleteItems(byCatalogCode catalogCode: String) async throws
    
    // Search & Filter operations  
    func searchItems(text: String) async throws -> [InventoryItemModel]
    func fetchItems(byType type: InventoryItemType) async throws -> [InventoryItemModel]
    func fetchItems(byCatalogCode catalogCode: String) async throws -> [InventoryItemModel]
    
    // Business logic operations
    func getTotalQuantity(forCatalogCode catalogCode: String, type: InventoryItemType) async throws -> Double
    func getDistinctCatalogCodes() async throws -> [String]
    func consolidateItems(byCatalogCode: Bool) async throws -> [ConsolidatedInventoryModel]
}