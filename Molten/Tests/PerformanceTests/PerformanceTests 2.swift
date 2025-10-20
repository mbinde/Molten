//
//  PerformanceTests.swift
//  FlameworkerPerformanceTests
//
//  Created by Assistant on 10/15/25.
//  Performance and memory pressure tests for Flameworker
//  
//  IMPORTANT: Add this file to the PerformanceTests target, NOT the main test target
//  These tests use large datasets and are designed to stress-test the system
//
/*
import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

// MARK: - Performance Test Infrastructure

/// Performance-specific test data size guard with higher limits
struct PerformanceTestDataSizeGuard {
    static let maxItemsPerTest = 10000
    static let maxInventoryPerTest = 15000
    
    /// Validate that performance test data size is reasonable
    static func validateDataSize(items: Int = 0, inventory: Int = 0) {
        guard items <= maxItemsPerTest else {
            fatalError("Performance test attempting to create \(items) items, maximum is \(maxItemsPerTest)")
        }
        
        guard inventory <= maxInventoryPerTest else {
            fatalError("Performance test attempting to create \(inventory) inventory records, maximum is \(maxInventoryPerTest)")
        }
    }
}

/// Performance-optimized mock repositories (no data size guards)
class PerformanceMockGlassItemRepository: GlassItemRepository {
    private var items: [GlassItemModel] = []
    
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        // No size guard for performance tests
        if items.contains(where: { $0.naturalKey == item.naturalKey }) {
            throw RepositoryError.duplicateNaturalKey(item.naturalKey)
        }
        items.append(item)
        return item
    }
    
    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        var createdItems: [GlassItemModel] = []
        for item in items {
            let created = try await createItem(item)
            createdItems.append(created)
        }
        return createdItems
    }
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        return items
    }
    
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        return items.filter { $0.manufacturer == manufacturer }
    }
    
    func searchItems(text: String) async throws -> [GlassItemModel] {
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(text) ||
            item.manufacturer.localizedCaseInsensitiveContains(text) ||
            item.naturalKey.localizedCaseInsensitiveContains(text)
        }
    }
    
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        guard let index = items.firstIndex(where: { $0.naturalKey == item.naturalKey }) else {
            throw RepositoryError.itemNotFound
        }
        items[index] = item
        return item
    }
    
    func deleteItem(naturalKey: String) async throws {
        items.removeAll { $0.naturalKey == naturalKey }
    }
    
    func deleteItems(naturalKeys: [String]) async throws {
        items.removeAll { naturalKeys.contains($0.naturalKey) }
    }
    
    func naturalKeyExists(_ naturalKey: String) async throws -> Bool {
        return items.contains { $0.naturalKey == naturalKey }
    }
    
    func generateNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        let baseKey = "\(manufacturer.lowercased())-\(sku.lowercased())-"
        var sequence = items.count // Start from current count for performance
        let candidateKey = "\(baseKey)\(sequence)"
        return candidateKey
    }
    
    func fetchItem(byNaturalKey naturalKey: String) async throws -> GlassItemModel? {
        return items.first { $0.naturalKey == naturalKey }
    }
    
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        return items.filter { $0.coe == coe }
    }
    
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        return items.filter { $0.mfr_status == status }
    }
    
    func getDistinctManufacturers() async throws -> [String] {
        return Array(Set(items.map { $0.manufacturer })).sorted()
    }
    
    func getDistinctCOEValues() async throws -> [Int32] {
        return Array(Set(items.map { $0.coe })).sorted()
    }
    
    func getDistinctStatuses() async throws -> [String] {
        return Array(Set(items.map { $0.mfr_status })).sorted()
    }
    
    func clearAllData() {
        items.removeAll()
    }
}

class PerformanceMockInventoryRepository: InventoryRepository {
    private var items: [InventoryModel] = []
    
    func fetchInventory(matching predicate: NSPredicate?) async throws -> [InventoryModel] {
        return items
    }
    
    func fetchInventory(byId id: UUID) async throws -> InventoryModel? {
        return items.first { $0.id == id }
    }
    
    func fetchInventory(forItem itemNaturalKey: String) async throws -> [InventoryModel] {
        return items.filter { $0.itemNaturalKey == itemNaturalKey }
    }
    
    func fetchInventory(forItem itemNaturalKey: String, type: String) async throws -> [InventoryModel] {
        return items.filter { $0.itemNaturalKey == itemNaturalKey && $0.type == type }
    }
    
    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        // No size guard for performance tests
        items.append(inventory)
        return inventory
    }
    
    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel] {
        items.append(contentsOf: inventories)
        return inventories
    }
    
    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        guard let index = items.firstIndex(where: { $0.id == inventory.id }) else {
            throw RepositoryError.itemNotFound
        }
        items[index] = inventory
        return inventory
    }
    
    func deleteInventory(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }
    
    func deleteInventory(forItem itemNaturalKey: String) async throws {
        items.removeAll { $0.itemNaturalKey == itemNaturalKey }
    }
    
    func deleteInventory(forItem itemNaturalKey: String, type: String) async throws {
        items.removeAll { $0.itemNaturalKey == itemNaturalKey && $0.type == type }
    }
    
    func getTotalQuantity(forItem itemNaturalKey: String) async throws -> Double {
        return items.filter { $0.itemNaturalKey == itemNaturalKey }.reduce(0) { $0 + $1.quantity }
    }
    
    func getTotalQuantity(forItem itemNaturalKey: String, type: String) async throws -> Double {
        return items.filter { $0.itemNaturalKey == itemNaturalKey && $0.type == type }.reduce(0) { $0 + $1.quantity }
    }
    
    func addQuantity(_ quantity: Double, toItem itemNaturalKey: String, type: String) async throws -> InventoryModel {
        if let existingIndex = items.firstIndex(where: { $0.item_natural_key == itemNaturalKey && $0.type == type }) {
            items[existingIndex] = InventoryModel(
                id: items[existingIndex].id,
                item_natural_key: itemNaturalKey,
                type: type,
                quantity: items[existingIndex].quantity + quantity
            )
            return items[existingIndex]
        } else {
            let newInventory = InventoryModel(
                id: UUID(),
                item_natural_key: itemNaturalKey,
                type: type,
                quantity: quantity
            )
            items.append(newInventory)
            return newInventory
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromItem itemNaturalKey: String, type: String) async throws -> InventoryModel? {
        guard let existingIndex = items.firstIndex(where: { $0.itemNaturalKey == itemNaturalKey && $0.type == type }) else {
            throw RepositoryError.itemNotFound
        }
        
        let newQuantity = items[existingIndex].quantity - quantity
        if newQuantity <= 0 {
            items.remove(at: existingIndex)
            return nil
        } else {
            items[existingIndex] = InventoryModel(
                id: items[existingIndex].id,
                item_natural_key: itemNaturalKey,
                type: type,
                quantity: newQuantity
            )
            return items[existingIndex]
        }
    }
    
    func setQuantity(_ quantity: Double, forItem itemNaturalKey: String, type: String) async throws -> InventoryModel? {
        if let existingIndex = items.firstIndex(where: { $0.itemNaturalKey == itemNaturalKey && $0.type == type }) {
            if quantity <= 0 {
                items.remove(at: existingIndex)
                return nil
            } else {
                items[existingIndex] = InventoryModel(
                    id: items[existingIndex].id,
                    item_natural_key: itemNaturalKey,
                    type: type,
                    quantity: quantity
                )
                return items[existingIndex]
            }
        } else if quantity > 0 {
            let newInventory = InventoryModel(
                id: UUID(),
                item_natural_key: itemNaturalKey,
                type: type,
                quantity: quantity
            )
            items.append(newInventory)
            return newInventory
        }
        return nil
    }
    
    func getDistinctTypes() async throws -> [String] {
        return Array(Set(items.map { $0.type })).sorted()
    }
    
    func getItemsWithInventory() async throws -> [String] {
        return Array(Set(items.map { $0.itemNaturalKey })).sorted()
    }
    
    func getItemsWithInventory(ofType type: String) async throws -> [String] {
        return Array(Set(items.filter { $0.type == type }.map { $0.itemNaturalKey })).sorted()
    }
    
    func getItemsWithLowInventory(threshold: Double) async throws -> [(itemNaturalKey: String, type: String, quantity: Double)] {
        return items
            .filter { $0.quantity > 0 && $0.quantity < threshold }
            .map { (itemNaturalKey: $0.itemNaturalKey, type: $0.type, quantity: $0.quantity) }
    }
    
    func getItemsWithZeroInventory() async throws -> [String] {
        return []
    }
    
    func getInventorySummary() async throws -> [InventorySummaryModel] {
        let grouped = Dictionary(grouping: items, by: { $0.itemNaturalKey })
        return grouped.map { key, inventories in
            InventorySummaryModel(itemNaturalKey: key, inventories: inventories)
        }
    }
    
    func getInventorySummary(forItem itemNaturalKey: String) async throws -> InventorySummaryModel? {
        let itemInventories = items.filter { $0.itemNaturalKey == itemNaturalKey }
        guard !itemInventories.isEmpty else { return nil }
        
        return InventorySummaryModel(itemNaturalKey: itemNaturalKey, inventories: itemInventories)
    }
    
    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        let grouped = Dictionary(grouping: items, by: { $0.itemNaturalKey })
        return grouped.mapValues { inventories in
            inventories.reduce(0) { $0 + $1.quantity } * defaultPricePerUnit
        }
    }
    
    func clearAllData() {
        items.removeAll()
    }
}

// MARK: - Performance Test Suite

@Suite("Performance Tests - Large Dataset Handling")
struct PerformanceTests2 {
    
    /// Create performance test environment with no size limits
    private func createPerformanceTestEnvironment() -> (PerformanceMockGlassItemRepository, PerformanceMockInventoryRepository) {
        return (PerformanceMockGlassItemRepository(), PerformanceMockInventoryRepository())
    }
    
    @Test("Should handle large catalog datasets efficiently")
    func testLargeCatalogPerformance() async throws {
        let (glassRepo, inventoryRepo) = createPerformanceTestEnvironment()
        
        print("Creating large catalog dataset...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create 1500 catalog items
        for i in 1...1500 {
            let item = GlassItemModel(
                natural_key: "perf-catalog-\(String(format: "%04d", i))-0",
                name: "Performance Test Item \(i)",
                sku: "PERF-\(String(format: "%04d", i))",
                manufacturer: "Performance Corp \(i % 10)", // 10 different manufacturers
                coe: Int32([90, 96, 104].randomElement() ?? 96),
                mfr_status: "available"
            )
            _ = try await glassRepo.createItem(item)
        }
        
        let creationTime = CFAbsoluteTimeGetCurrent() - startTime
        print("Created 1500 items in \(creationTime) seconds")
        
        // Test search performance
        let searchStartTime = CFAbsoluteTimeGetCurrent()
        let searchResults = try await glassRepo.searchItems(text: "Performance")
        let searchTime = CFAbsoluteTimeGetCurrent() - searchStartTime
        
        print("Search completed in \(searchTime) seconds, found \(searchResults.count) items")
        
        #expect(searchResults.count == 1500, "Should find all 1500 items")
        #expect(creationTime < 2.0, "Should create 1500 items in under 2 seconds")
        #expect(searchTime < 0.5, "Should search 1500 items in under 0.5 seconds")
    }
    
    @Test("Should optimize memory usage patterns under pressure")
    func testMemoryPressureOptimization() async throws {
        let (glassRepo, inventoryRepo) = createPerformanceTestEnvironment()
        
        print("Setting up shared dataset: 1500 catalog + 2265 inventory items")
        
        // Create catalog items
        var catalogItems: [GlassItemModel] = []
        for i in 1...1500 {
            let item = GlassItemModel(
                natural_key: "memory-catalog-\(String(format: "%04d", i))-0",
                name: "Memory Test Item \(i)",
                sku: "MEM-\(String(format: "%04d", i))",
                manufacturer: "Memory Corp",
                coe: 96,
                mfr_status: "available"
            )
            catalogItems.append(item)
            _ = try await glassRepo.createItem(item)
        }
        
        // Create inventory items (1.5x catalog items = 2265 inventory records)
        var inventoryItems: [InventoryModel] = []
        for (index, catalogItem) in catalogItems.enumerated() {
            // Each catalog item gets 1-2 inventory records
            let baseInventory = InventoryModel(
                id: UUID(),
                item_natural_key: catalogItem.natural_key,
                type: "inventory",
                quantity: Double.random(in: 1...100)
            )
            inventoryItems.append(baseInventory)
            _ = try await inventoryRepo.createInventory(baseInventory)
            
            // Some items get a second inventory record
            if index % 2 == 0 {
                let buyInventory = InventoryModel(
                    id: UUID(),
                    item_natural_key: catalogItem.natural_key,
                    type: "buy",
                    quantity: Double.random(in: 1...50)
                )
                inventoryItems.append(buyInventory)
                _ = try await inventoryRepo.createInventory(buyInventory)
            }
        }
        
        print("Dataset created: \(catalogItems.count) catalog + \(inventoryItems.count) inventory")
        
        // Memory pressure test: Multiple concurrent operations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Heavy search operations
            for i in 1...20 {
                group.addTask {
                    do {
                        _ = try await glassRepo.searchItems(text: "Memory Test Item \(i * 10)")
                    } catch {
                        print("Search \(i) failed under memory pressure: \(error)")
                    }
                }
            }
            
            // Task 2: Inventory operations
            for i in 1...10 {
                group.addTask {
                    do {
                        _ = try await inventoryRepo.getTotalQuantity(forItem: "memory-catalog-\(String(format: "%04d", i * 10))-0")
                    } catch {
                        print("Inventory operation \(i) failed under memory pressure: \(error)")
                    }
                }
            }
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("Memory pressure test completed in \(totalTime) seconds")
        
        // Verify data integrity after memory pressure
        let finalCatalogCount = try await glassRepo.fetchItems(matching: nil).count
        let finalInventoryCount = try await inventoryRepo.fetchInventory(matching: nil).count
        
        #expect(finalCatalogCount == 1500, "Should maintain all 1500 catalog items after memory pressure")
        #expect(finalInventoryCount == 2265, "Should maintain all 2265 inventory items after memory pressure")
        #expect(totalTime < 5.0, "Should complete memory pressure test in under 5 seconds")
        
        print("✅ Memory usage optimization test passed")
        print("   - Maintained data integrity under pressure")
        print("   - Completed concurrent operations efficiently")
        print("   - Final counts: \(finalCatalogCount) catalog, \(finalInventoryCount) inventory")
    }
    
    @Test("Should handle bulk operations efficiently")
    func testBulkOperationPerformance() async throws {
        let (glassRepo, inventoryRepo) = createPerformanceTestEnvironment()
        
        print("Testing bulk operation performance...")
        
        // Create items for bulk operations
        var bulkItems: [GlassItemModel] = []
        for i in 1...500 {
            let item = GlassItemModel(
                natural_key: "bulk-item-\(String(format: "%03d", i))-0",
                name: "Bulk Item \(i)",
                sku: "BULK-\(String(format: "%03d", i))",
                manufacturer: "Bulk Corp",
                coe: 96,
                mfr_status: "available"
            )
            bulkItems.append(item)
        }
        
        // Test bulk creation performance
        let bulkCreateStart = CFAbsoluteTimeGetCurrent()
        let createdItems = try await glassRepo.createItems(bulkItems)
        let bulkCreateTime = CFAbsoluteTimeGetCurrent() - bulkCreateStart
        
        print("Bulk created \(createdItems.count) items in \(bulkCreateTime) seconds")
        
        // Test bulk search performance
        let bulkSearchStart = CFAbsoluteTimeGetCurrent()
        let searchResults = try await glassRepo.searchItems(text: "Bulk")
        let bulkSearchTime = CFAbsoluteTimeGetCurrent() - bulkSearchStart
        
        print("Bulk search found \(searchResults.count) items in \(bulkSearchTime) seconds")
        
        #expect(createdItems.count == 500, "Should bulk create all 500 items")
        #expect(searchResults.count == 500, "Should find all 500 bulk items")
        #expect(bulkCreateTime < 1.0, "Should bulk create 500 items in under 1 second")
        #expect(bulkSearchTime < 0.1, "Should search 500 items in under 0.1 seconds")
    }
}
 
 */

// MARK: - Usage Instructions

/*
 TO USE THIS FILE:
 
 1. Add this file to your PerformanceTests target (NOT the main test target)
 2. Create a separate PerformanceTests target in Xcode if you don't have one
 3. The main test suite will remain fast and lean with the 100/500 item limits
 4. Performance tests can run separately when needed
 
 This separation ensures:
 - Main tests run quickly during development
 - Performance tests can stress-test with large datasets
 - CI/CD can run main tests frequently, performance tests less frequently
 - No accidental large dataset creation in regular tests
 */
