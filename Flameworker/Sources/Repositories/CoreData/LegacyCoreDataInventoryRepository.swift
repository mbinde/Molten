//
//  LegacyCoreDataInventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData

/// Core Data implementation of LegacyInventoryItemRepository for production use
/// LEGACY: This will be replaced by the new GlassItem-based repository system
/// Assumes InventoryItem entity exists in .xcdatamodeld with automatic code generation
class LegacyCoreDataInventoryRepository: LegacyInventoryItemRepository {
    private let persistenceController: PersistenceController
    
    // Performance optimization: Caching
    private var distinctCatalogCodesCache: [String]?
    private var cacheLastUpdated: Date?
    private let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
    
    // Performance metrics
    private var operationCount: Int = 0
    private var cacheHits: Int = 0
    private var totalOperationTime: TimeInterval = 0.0
    private let operationQueue = DispatchQueue(label: "inventory.repository.metrics", attributes: .concurrent)
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [InventoryItemModel] {
        let startTime = Date()
        defer { recordOperation(duration: Date().timeIntervalSince(startTime)) }
        
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
            
            let coreDataItems = try context.fetch(fetchRequest)
            return coreDataItems.map { $0.toModel() }
        }
    }
    
    func fetchItem(byId id: String) async throws -> InventoryItemModel? {
        let predicate = NSPredicate(format: "id == %@", id)
        let items = try await fetchItems(matching: predicate)
        return items.first
    }
    
    func createItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        let startTime = Date()
        defer { recordOperation(duration: Date().timeIntervalSince(startTime)) }
        
        let context = persistenceController.container.newBackgroundContext()
        
        let result = try await context.perform {
            // Check if item with same ID already exists
            let existingRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            existingRequest.predicate = NSPredicate(format: "id == %@", item.id)
            existingRequest.fetchLimit = 1
            
            let existingItems = try context.fetch(existingRequest)
            
            let coreDataItem: InventoryItem
            if let existing = existingItems.first {
                // Update existing item instead of creating duplicate
                coreDataItem = existing
                coreDataItem.catalog_code = item.catalogCode
                coreDataItem.count = item.quantity
                coreDataItem.type = item.type.rawValue
                coreDataItem.notes = item.notes
            } else {
                // Create new item
                coreDataItem = InventoryItem(context: context)
                coreDataItem.id = item.id
                coreDataItem.catalog_code = item.catalogCode
                coreDataItem.count = item.quantity
                coreDataItem.type = item.type.rawValue
                coreDataItem.notes = item.notes
            }
            
            try context.save()
            
            return coreDataItem.toModel()
        }
        
        // Invalidate cache when data changes
        invalidateCache()
        
        return result
    }
    
    func createItems(_ items: [InventoryItemModel]) async throws -> [InventoryItemModel] {
        let startTime = Date()
        defer { recordOperation(duration: Date().timeIntervalSince(startTime)) }
        
        let context = persistenceController.container.newBackgroundContext()
        
        let result = try await context.perform {
            var createdItems: [InventoryItemModel] = []
            
            // Process items in batches for memory efficiency
            let batchSize = 100
            for batch in items.chunked(into: batchSize) {
                for item in batch {
                    // Check if item with same ID already exists
                    let existingRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
                    existingRequest.predicate = NSPredicate(format: "id == %@", item.id)
                    existingRequest.fetchLimit = 1
                    
                    let existingItems = try context.fetch(existingRequest)
                    
                    let coreDataItem: InventoryItem
                    if let existing = existingItems.first {
                        // Update existing item
                        coreDataItem = existing
                        coreDataItem.catalog_code = item.catalogCode
                        coreDataItem.count = item.quantity
                        coreDataItem.type = item.type.rawValue
                        coreDataItem.notes = item.notes
                    } else {
                        // Create new item
                        coreDataItem = InventoryItem(context: context)
                        coreDataItem.id = item.id
                        coreDataItem.catalog_code = item.catalogCode
                        coreDataItem.count = item.quantity
                        coreDataItem.type = item.type.rawValue
                        coreDataItem.notes = item.notes
                    }
                    
                    createdItems.append(coreDataItem.toModel())
                }
                
                // Save batch
                try context.save()
            }
            
            return createdItems
        }
        
        // Invalidate cache when data changes
        invalidateCache()
        
        return result
    }
    
    func updateItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id)
            fetchRequest.fetchLimit = 1
            
            let items = try context.fetch(fetchRequest)
            guard let coreDataItem = items.first else {
                throw NSError(
                    domain: "CoreDataInventoryRepository", 
                    code: 404, 
                    userInfo: [NSLocalizedDescriptionKey: "Item not found with id: \(item.id)"]
                )
            }
            
            coreDataItem.catalog_code = item.catalogCode
            coreDataItem.count = item.quantity
            coreDataItem.type = item.type.rawValue
            coreDataItem.notes = item.notes
            
            try context.save()
            
            return coreDataItem.toModel()
        }
    }
    
    func deleteItem(id: String) async throws {
        let startTime = Date()
        defer { recordOperation(duration: Date().timeIntervalSince(startTime)) }
        
        let context = persistenceController.container.newBackgroundContext()
        
        try await context.perform {
            let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            
            let items = try context.fetch(fetchRequest)
            for item in items {
                context.delete(item)
            }
            
            if !items.isEmpty {
                try context.save()
            }
        }
        
        // Invalidate cache when data changes
        invalidateCache()
    }
    
    func deleteItems(ids: [String]) async throws {
        let startTime = Date()
        defer { recordOperation(duration: Date().timeIntervalSince(startTime)) }
        
        let context = persistenceController.container.newBackgroundContext()
        
        try await context.perform {
            // Process deletions in batches for efficiency
            let batchSize = 100
            for batch in ids.chunked(into: batchSize) {
                let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
                fetchRequest.predicate = NSPredicate(format: "id IN %@", batch)
                
                let items = try context.fetch(fetchRequest)
                for item in items {
                    context.delete(item)
                }
                
                // Save batch
                if !items.isEmpty {
                    try context.save()
                }
            }
        }
        
        // Invalidate cache when data changes
        invalidateCache()
    }
    
    func deleteItems(byCatalogCode catalogCode: String) async throws {
        let startTime = Date()
        defer { recordOperation(duration: Date().timeIntervalSince(startTime)) }
        
        let context = persistenceController.container.newBackgroundContext()
        
        try await context.perform {
            let fetchRequest = NSFetchRequest<InventoryItem>(entityName: "InventoryItem")
            fetchRequest.predicate = NSPredicate(format: "catalog_code == %@", catalogCode)
            
            let items = try context.fetch(fetchRequest)
            for item in items {
                context.delete(item)
            }
            
            if !items.isEmpty {
                try context.save()
            }
        }
        
        // Invalidate cache when data changes
        invalidateCache()
    }
    
    // MARK: - Search & Filter Operations
    
    func searchItems(text: String) async throws -> [InventoryItemModel] {
        guard !text.isEmpty else {
            return try await fetchItems(matching: nil)
        }
        
        let predicate = NSPredicate(format: "catalog_code CONTAINS[cd] %@ OR notes CONTAINS[cd] %@", text, text)
        return try await fetchItems(matching: predicate)
    }
    
    func fetchItems(byType type: InventoryItemType) async throws -> [InventoryItemModel] {
        let predicate = NSPredicate(format: "type == %d", type.rawValue)
        return try await fetchItems(matching: predicate)
    }
    
    func fetchItems(byCatalogCode catalogCode: String) async throws -> [InventoryItemModel] {
        let predicate = NSPredicate(format: "catalog_code == %@", catalogCode)
        return try await fetchItems(matching: predicate)
    }
    
    // MARK: - Business Logic Operations
    
    func getTotalQuantity(forCatalogCode catalogCode: String, type: InventoryItemType) async throws -> Double {
        let items = try await fetchItems(byCatalogCode: catalogCode)
        return items
            .filter { $0.type == type }
            .reduce(0.0) { $0 + $1.quantity }
    }
    
    func getDistinctCatalogCodes() async throws -> [String] {
        let startTime = Date()
        defer { recordOperation(duration: Date().timeIntervalSince(startTime)) }
        
        // Check cache first
        if let cachedCodes = distinctCatalogCodesCache,
           let lastUpdated = cacheLastUpdated,
           Date().timeIntervalSince(lastUpdated) < cacheExpiryInterval {
            recordCacheHit()
            return cachedCodes
        }
        
        // Cache miss - fetch from Core Data
        let items = try await fetchItems(matching: nil)
        let distinctCodes = Array(Set(items.map { $0.catalogCode })).sorted()
        
        // Update cache
        distinctCatalogCodesCache = distinctCodes
        cacheLastUpdated = Date()
        
        return distinctCodes
    }
    
    func consolidateItems(byCatalogCode: Bool) async throws -> [ConsolidatedInventoryModel] {
        guard byCatalogCode else { return [] }
        
        let items = try await fetchItems(matching: nil)
        let grouped = Dictionary(grouping: items) { $0.catalogCode }
        
        return grouped.map { (catalogCode, items) in
            ConsolidatedInventoryModel(catalogCode: catalogCode, items: items)
        }.sorted { $0.catalogCode < $1.catalogCode }
    }
}

// MARK: - Performance Metrics and Caching

extension LegacyCoreDataInventoryRepository {
    
    /// Performance metrics for monitoring repository operations
    struct PerformanceMetrics {
        let totalOperations: Int
        let cacheHitRate: Double
        let averageOperationTime: TimeInterval
    }
    
    /// Get current performance metrics
    func getPerformanceMetrics() async -> PerformanceMetrics {
        return await operationQueue.sync {
            let hitRate = operationCount > 0 ? Double(cacheHits) / Double(operationCount) : 0.0
            let avgTime = operationCount > 0 ? totalOperationTime / Double(operationCount) : 0.0
            
            return PerformanceMetrics(
                totalOperations: operationCount,
                cacheHitRate: hitRate,
                averageOperationTime: avgTime
            )
        }
    }
    
    /// Record an operation for performance tracking
    private func recordOperation(duration: TimeInterval) {
        operationQueue.async(flags: .barrier) {
            self.operationCount += 1
            self.totalOperationTime += duration
        }
    }
    
    /// Record a cache hit
    private func recordCacheHit() {
        operationQueue.async(flags: .barrier) {
            self.cacheHits += 1
        }
    }
    
    /// Invalidate all caches when data changes
    private func invalidateCache() {
        distinctCatalogCodesCache = nil
        cacheLastUpdated = nil
    }
}

// MARK: - InventoryItem Core Data Extension

extension InventoryItem {
    /// Convert Core Data InventoryItem to InventoryItemModel
    func toModel() -> InventoryItemModel {
        return InventoryItemModel(
            id: self.id ?? UUID().uuidString,
            catalogCode: self.catalog_code ?? "",
            quantity: self.count,
            type: InventoryItemType(rawValue: self.type) ?? .inventory,
            notes: self.notes,
            location: nil  // Not stored in Core Data
        )
    }
}