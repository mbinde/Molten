//
//  CatalogItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData

/// Repository protocol that abstracts Core Data complexity away from business logic
protocol CatalogItemRepository {
    /// Fetch items with optional predicate filtering
    func fetchItems(matching predicate: NSPredicate?) async throws -> [CatalogItemModel]
    
    /// Create a new catalog item
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel
    
    /// Update an existing catalog item
    func updateItem(_ item: CatalogItemModel) async throws -> CatalogItemModel
    
    /// Search items by text across name, code, and manufacturer fields
    func searchItems(text: String) async throws -> [CatalogItemModel]
}