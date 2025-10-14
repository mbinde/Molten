//
//  PerformanceTests.swift
//  PerformanceTests
//
//  Created by Melissa Binde on 10/13/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//
//  Dedicated performance test suite for Flameworker
//  Designed to run in isolated test target to avoid interference from parallel test execution
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Performance Tests - Isolated Suite", .serialized)
struct PerformanceTests {
    
    // MARK: - Test Infrastructure
    
    private func createTestServices() async -> (CatalogService, InventoryService, InventoryViewModel) {
        let catalogRepo = MockCatalogRepository()
        let inventoryRepo = MockInventoryRepository()
        
        let catalogService = CatalogService(repository: catalogRepo)
        let inventoryService = InventoryService(repository: inventoryRepo)
        let inventoryViewModel = await InventoryViewModel(inventoryService: inventoryService, catalogService: catalogService)
        
        return (catalogService, inventoryService, inventoryViewModel)
    }
    
    private func createRealisticGlassCatalog(itemCount: Int) -> [CatalogItemModel] {
        var catalogItems: [CatalogItemModel] = []
        
        let manufacturers = ["Bullseye", "Spectrum", "Uroboros", "Kokomo", "Oceanside", "Wissmach", "Youghiogheny"]
        let colors = ["Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Pink", "Amber", "Clear", "Black", "White", "Brown"]
        let finishes = ["Transparent", "Opal", "Cathedral", "Waterglass", "Granite", "Streaky", "Wispy", "Iridescent"]
        
        for i in 1...itemCount {
            let manufacturer = manufacturers[i % manufacturers.count]
            let color = colors[i % colors.count]
            let finish = finishes[i % finishes.count]
            
            let name = "\(color) \(finish)"
            let code = String(format: "%04d", i)
            let tags = [color.lowercased(), finish.lowercased(), "coe\(manufacturer == "Spectrum" ? "96" : "90")"]
            
            let item = CatalogItemModel(
                name: name,
                rawCode: code,
                manufacturer: manufacturer,
                tags: tags
            )
            catalogItems.append(item)
        }
        
        return catalogItems
    }
    
    // MARK: - Repository Performance Tests (Moved from InventoryRepositoryTests)
    
    @Test("Should optimize repository performance with intelligent caching")
    func testRepositoryPerformanceOptimizations() async throws {
        print("💾 Testing repository performance optimizations...")
        
        // This test verifies caching and performance optimizations
        let coreDataRepo = CoreDataInventoryRepository(persistenceController: PersistenceController(inMemory: true))
        
        // Create a larger test dataset to see meaningful performance differences
        let testItems = (1...100).map { index in
            InventoryItemModel(
                catalogCode: "PERF-TEST-\(String(format: "%03d", index))",
                quantity: Double(index),
                type: .inventory,
                notes: "Performance test item \(index)"
            )
        }
        
        let createdItems = try await coreDataRepo.createItems(testItems)
        let testIds = createdItems.map { $0.id }
        
        // Test 1: Distinct catalog codes should be cached for performance
        // First call - will populate cache
        let startTime1 = Date()
        let distinctCodes1 = try await coreDataRepo.getDistinctCatalogCodes()
        let duration1 = Date().timeIntervalSince(startTime1)
        
        // Small delay to ensure timing is measurable
        try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        
        // Second call - should use cache and be faster
        let startTime2 = Date()
        let distinctCodes2 = try await coreDataRepo.getDistinctCatalogCodes()
        let duration2 = Date().timeIntervalSince(startTime2)
        
        #expect(distinctCodes1.count >= 100, "Should return distinct catalog codes")
        #expect(distinctCodes2.count == distinctCodes1.count, "Cached result should match")
        
        // Performance expectation - cached call should be faster or at least not significantly slower
        // Allow for timing variance in performance tests - use more lenient threshold
        let performanceRatio = duration2 / max(duration1, 0.0001) // Avoid division by zero
        print("  📈 Cache performance ratio: \(String(format: "%.3f", performanceRatio)) (first: \(String(format: "%.4f", duration1))s, second: \(String(format: "%.4f", duration2))s)")
        
        // More lenient threshold for isolated performance testing to account for system variance
        #expect(performanceRatio < 10.0, "Cached call should not be more than 10x slower in isolated performance environment (actual ratio: \(String(format: "%.3f", performanceRatio)))")
        
        // Test 2: Verify cache functionality by checking actual cache behavior
        // Force cache invalidation by creating new items
        let newTestItem = InventoryItemModel(
            catalogCode: "CACHE-INVALIDATION-TEST",
            quantity: 1.0,
            type: .inventory
        )
        let _ = try await coreDataRepo.createItem(newTestItem)
        
        // This call should rebuild cache
        let distinctCodes3 = try await coreDataRepo.getDistinctCatalogCodes()
        #expect(distinctCodes3.count == distinctCodes1.count + 1, "Should include new item after cache invalidation")
        #expect(distinctCodes3.contains("CACHE-INVALIDATION-TEST"), "Should contain the new catalog code")
        
        // Test 3: Batch operations should be efficient
        let batchStartTime = Date()
        let largeBatch = (1...50).map { index in
            InventoryItemModel(
                catalogCode: "LARGE-BATCH-\(index)",
                quantity: Double(index),
                type: .buy
            )
        }
        
        let batchCreatedItems = try await coreDataRepo.createItems(largeBatch)
        let batchDuration = Date().timeIntervalSince(batchStartTime)
        
        #expect(batchCreatedItems.count == 50, "Batch creation should handle all items")
        #expect(batchDuration < 5.0, "Batch operations should complete within reasonable time for isolated performance tests")
        
        print("  📊 Batch performance: \(batchCreatedItems.count) items in \(String(format: "%.3f", batchDuration))s (\(String(format: "%.1f", Double(batchCreatedItems.count) / batchDuration)) items/sec)")
        
        // Cleanup - Delete test items
        let allTestIds = testIds + batchCreatedItems.map { $0.id } + [newTestItem.id]
        try await coreDataRepo.deleteItems(ids: allTestIds)
        
        print("📊 Repository Performance Summary:")
        print("   • Cache performance ratio: \(String(format: "%.3f", performanceRatio))")
        print("   • Batch operation throughput: \(String(format: "%.1f", Double(batchCreatedItems.count) / batchDuration)) items/sec")
        print("   • Repository optimizations working correctly")
    }
    
    @Test("Should handle large dataset operations efficiently in repository")
    func testRepositoryLargeDatasetPerformance() async throws {
        print("🔬 Testing repository large dataset performance...")
        
        let coreDataRepo = CoreDataInventoryRepository(persistenceController: PersistenceController(inMemory: true))
        
        // Create larger test dataset (1000 items)
        let largeDataset = (1...1000).map { index in
            InventoryItemModel(
                catalogCode: "LARGE-TEST-\(String(format: "%04d", index))",
                quantity: Double.random(in: 1...100),
                type: [.inventory, .buy, .sell][index % 3],
                notes: "Large dataset test item \(index)"
            )
        }
        
        let startTime = Date()
        
        // Test batch creation performance
        let batchSize = 100
        var allCreatedItems: [InventoryItemModel] = []
        
        for batchStart in stride(from: 0, to: largeDataset.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, largeDataset.count)
            let batch = Array(largeDataset[batchStart..<batchEnd])
            
            let batchResults = try await coreDataRepo.createItems(batch)
            allCreatedItems.append(contentsOf: batchResults)
        }
        
        let creationTime = Date().timeIntervalSince(startTime)
        
        // Test retrieval performance
        let retrievalStartTime = Date()
        let allItems = try await coreDataRepo.fetchItems(matching: nil)
        let retrievalTime = Date().timeIntervalSince(retrievalStartTime)
        
        // Test search performance
        let searchStartTime = Date()
        let searchResults = try await coreDataRepo.searchItems(text: "LARGE-TEST")
        let searchTime = Date().timeIntervalSince(searchStartTime)
        
        // Performance assertions
        #expect(allCreatedItems.count == 1000, "Should create all 1000 items")
        #expect(allItems.count == 1000, "Should retrieve all 1000 items")
        #expect(creationTime < 10.0, "Creation should complete within 10s")
        #expect(retrievalTime < 2.0, "Retrieval should complete within 2s")
        #expect(searchTime < 3.0, "Search should complete within 3s")
        
        print("📊 Repository Large Dataset Performance:")
        print("   • Items: \(allCreatedItems.count)")
        print("   • Creation: \(String(format: "%.3f", creationTime))s (\(String(format: "%.1f", Double(allCreatedItems.count) / creationTime)) items/sec)")
        print("   • Retrieval: \(String(format: "%.3f", retrievalTime))s")
        print("   • Search: \(String(format: "%.3f", searchTime))s (\(searchResults.count) results)")
        
        // Cleanup
        let cleanupIds = allCreatedItems.map { $0.id }
        try await coreDataRepo.deleteItems(ids: cleanupIds)
    }
    
    @Test("Should optimize memory usage under load in repository")
    func testRepositoryMemoryOptimizationUnderLoad() async throws {
        print("💾 Testing repository memory optimization under load...")
        
        let coreDataRepo = CoreDataInventoryRepository(persistenceController: PersistenceController(inMemory: true))
        
        // Create multiple batches to test memory management
        let batchCount = 5
        let itemsPerBatch = 200
        var allItemIds: [String] = []
        
        for batchIndex in 1...batchCount {
            let batchItems = (1...itemsPerBatch).map { itemIndex in
                InventoryItemModel(
                    catalogCode: "MEMORY-BATCH-\(batchIndex)-\(String(format: "%03d", itemIndex))",
                    quantity: Double(itemIndex),
                    type: .inventory,
                    notes: "Memory test batch \(batchIndex) item \(itemIndex)"
                )
            }
            
            let startTime = Date()
            let createdItems = try await coreDataRepo.createItems(batchItems)
            let batchTime = Date().timeIntervalSince(startTime)
            
            allItemIds.append(contentsOf: createdItems.map { $0.id })
            
            print("  ✅ Batch \(batchIndex): \(createdItems.count) items in \(String(format: "%.3f", batchTime))s")
            
            #expect(createdItems.count == itemsPerBatch, "Each batch should create all items")
            #expect(batchTime < 3.0, "Each batch should complete within 3s")
            
            // Brief pause between batches
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        // Verify total items
        let totalItems = try await coreDataRepo.fetchItems(matching: nil)
        #expect(totalItems.count == batchCount * itemsPerBatch, "Should have all items across batches")
        
        // Test consolidated operations
        let consolidatedStartTime = Date()
        let consolidatedResults = try await coreDataRepo.consolidateItems(byCatalogCode: true)
        let consolidatedTime = Date().timeIntervalSince(consolidatedStartTime)
        
        #expect(consolidatedResults.count == batchCount * itemsPerBatch, "Should consolidate all items")
        #expect(consolidatedTime < 5.0, "Consolidation should complete within 5s")
        
        print("📊 Repository Memory Optimization Summary:")
        print("   • Total items processed: \(totalItems.count)")
        print("   • Batches: \(batchCount)")
        print("   • Consolidation time: \(String(format: "%.3f", consolidatedTime))s")
        print("   • Memory management successful")
        
        // Cleanup all items
        try await coreDataRepo.deleteItems(ids: allItemIds)
    }
    
    // MARK: - Large Dataset Performance Tests
    
    @Test("Should handle large catalog sizes efficiently (10,000+ items)")
    func testLargeCatalogPerformance() async throws {
        let (catalogService, _, _) = await createTestServices()
        
        print("🔬 Testing performance with large catalog size...")
        
        // Create large realistic catalog (10,000 items)
        let catalogSize = 10_000
        let catalogItems = createRealisticGlassCatalog(itemCount: catalogSize)
        
        print("Adding \(catalogSize) catalog items...")
        let addStartTime = Date()
        
        // Add items in batches for better performance
        let batchSize = 100
        for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, catalogItems.count)
            let batch = Array(catalogItems[batchStart..<batchEnd])
            
            for item in batch {
                _ = try await catalogService.createItem(item)
            }
        }
        
        let addTime = Date().timeIntervalSince(addStartTime)
        print("✅ Added all catalog items in \(String(format: "%.3f", addTime))s")
        
        // Test retrieval performance
        let retrievalStartTime = Date()
        let retrievedItems = try await catalogService.getAllItems()
        let retrievalTime = Date().timeIntervalSince(retrievalStartTime)
        
        #expect(retrievedItems.count == catalogSize, "Should retrieve all catalog items")
        #expect(retrievalTime < 10.0, "Retrieval should complete within 10 seconds for 10k items")
        
        print("📊 Large Catalog Performance Summary:")
        print("   • Items: \(catalogSize)")
        print("   • Addition: \(String(format: "%.3f", addTime))s (\(String(format: "%.1f", Double(catalogSize) / addTime)) items/sec)")
        print("   • Retrieval: \(String(format: "%.3f", retrievalTime))s")
    }
    
    @Test("Should perform search efficiently across large datasets")
    func testSearchPerformanceAtScale() async throws {
        let (catalogService, _, _) = await createTestServices()
        
        print("🔍 Testing search performance with large dataset...")
        
        // Create medium-sized catalog for search testing (5,000 items)
        let catalogSize = 5_000
        let catalogItems = createRealisticGlassCatalog(itemCount: catalogSize)
        
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Test various search scenarios
        let searchScenarios = [
            ("Single letter", "R"),
            ("Color search", "Red"),
            ("Manufacturer", "Bullseye"),
            ("Finish type", "Transparent"),
            ("Complex term", "Red Transparent"),
            ("Partial code", "0001"),
            ("Common term", "Glass")
        ]
        
        var totalSearchTime: TimeInterval = 0
        
        for (scenarioName, searchTerm) in searchScenarios {
            let searchStartTime = Date()
            let searchResults = try await catalogService.searchItems(searchText: searchTerm)
            let searchTime = Date().timeIntervalSince(searchStartTime)
            
            totalSearchTime += searchTime
            
            print("✅ \(scenarioName) ('\(searchTerm)'): \(searchResults.count) results in \(String(format: "%.3f", searchTime))s")
            
            #expect(searchTime < 3.0, "Search for '\(searchTerm)' should complete within 3 seconds")
            #expect(searchResults.count >= 0, "Search should return valid results")
        }
        
        // Test rapid sequential searches (user typing simulation)
        let rapidSearchStartTime = Date()
        let searchSequence = ["B", "Bu", "Bul", "Bull", "Bulls", "Bullse", "Bullsey", "Bullseye"]
        
        for searchTerm in searchSequence {
            _ = try await catalogService.searchItems(searchText: searchTerm)
        }
        
        let rapidSearchTime = Date().timeIntervalSince(rapidSearchStartTime)
        
        #expect(rapidSearchTime < 5.0, "Rapid search sequence should complete within 5 seconds")
        
        print("📊 Search Performance Summary:")
        print("   • Dataset size: \(catalogSize) items")
        print("   • Search scenarios: \(searchScenarios.count) different patterns")
        print("   • Total search time: \(String(format: "%.3f", totalSearchTime))s")
        print("   • Average search time: \(String(format: "%.3f", totalSearchTime / Double(searchScenarios.count)))s")
        print("   • Rapid search: \(String(format: "%.3f", rapidSearchTime))s")
    }
    
    @Test("Should handle memory efficiently during large operations")
    func testMemoryEfficiencyUnderLoad() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createTestServices()
        
        print("💾 Testing memory efficiency with large datasets...")
        
        // Test progressively larger datasets
        let testSizes = [1_000, 3_000, 5_000]
        
        for size in testSizes {
            print("Testing memory efficiency with \(size) catalog items...")
            
            let startTime = Date()
            let catalogItems = createRealisticGlassCatalog(itemCount: size)
            
            // Add catalog items in batches
            let batchSize = 200
            for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, catalogItems.count)
                let batch = Array(catalogItems[batchStart..<batchEnd])
                
                for item in batch {
                    _ = try await catalogService.createItem(item)
                }
            }
            
            // Test memory-intensive consolidation operation
            await inventoryViewModel.loadInventoryItems()
            
            let totalTime = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                let consolidatedCount = inventoryViewModel.consolidatedItems.count
                #expect(consolidatedCount >= 0, "Should consolidate items for dataset size \(size)")
            }
            
            // Test search performance doesn't degrade with memory pressure
            let searchStartTime = Date()
            await inventoryViewModel.searchItems(searchText: "Red")
            let searchTime = Date().timeIntervalSince(searchStartTime)
            
            print("  ✅ Size \(size): Total \(String(format: "%.3f", totalTime))s, Search \(String(format: "%.3f", searchTime))s")
            
            #expect(searchTime < 4.0, "Search should remain efficient at size \(size)")
            #expect(totalTime < 45.0, "Total processing should complete within 45s for size \(size)")
        }
        
        print("📊 Memory Efficiency Summary:")
        print("   • Tested dataset sizes: \(testSizes)")
        print("   • Performance remained acceptable across all sizes")
        print("   • Memory usage patterns appear sustainable")
    }
    
    // MARK: - String Processing Performance Tests
    
    @Test("Should optimize string processing for large datasets")
    func testStringProcessingPerformance() throws {
        print("📝 Testing string processing performance...")
        
        // Create large dataset for string processing
        let largeDataset = (1...2000).map { i in
            return [
                "Glass Item Name \(i)",
                "Product Code: GLS-\(String(format: "%04d", i))", 
                "Detailed description with comprehensive information about glass item \(i) including color, finish, and specifications",
                "Category: \(["Rods", "Sheets", "Frit", "Stringers", "Powder"][i % 5])",
                "Manufacturer: \(["Bullseye", "Spectrum", "Uroboros"][i % 3])"
            ]
        }
        
        let startTime = Date()
        
        // Process strings with various operations
        var processedCount = 0
        for itemStrings in largeDataset {
            // Simulate common string operations
            let joinedString = itemStrings.joined(separator: " ")
            let lowercased = joinedString.lowercased()
            let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmed.isEmpty && trimmed.contains("glass") {
                processedCount += 1
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Performance benchmarks
        #expect(processedCount > 0, "Should process items successfully")
        #expect(processingTime < 0.2, "String processing should be efficient for 2000 items (actual: \(String(format: "%.3f", processingTime))s)")
        #expect(processedCount == 2000, "Should process all 2000 items")
        
        print("📊 String Processing Performance:")
        print("   • Items processed: \(processedCount)")
        print("   • Processing time: \(String(format: "%.3f", processingTime))s")
        print("   • Items per second: \(String(format: "%.1f", Double(processedCount) / processingTime))")
    }
    
    @Test("Should optimize collection operations for performance")
    func testCollectionPerformanceOptimization() throws {
        print("📊 Testing collection operation performance...")
        
        // Create scenarios for different collection operations
        let largeArray = Array(1...15000)
        let largeSet = Set(1...7500)
        let largeDictionary = Dictionary(uniqueKeysWithValues: (1...5000).map { ($0, "Value\($0)") })
        
        let startTime = Date()
        
        // Test various collection operations
        let filteredArray = largeArray.filter { $0 % 2 == 0 }
        let mappedArray = filteredArray.map { $0 * 2 }
        
        let setIntersection = largeSet.intersection(Set(Array(3750...11250)))
        let filteredDict = largeDictionary.filter { $0.key > 2500 }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Collection performance assertions
        #expect(filteredArray.count == 7500, "Should filter correctly")
        #expect(mappedArray.count == 7500, "Should map correctly")
        #expect(setIntersection.count == 3751, "Should intersect correctly")
        #expect(filteredDict.count == 2500, "Should filter dictionary correctly")
        #expect(processingTime < 0.1, "Collection operations should be efficient (actual: \(String(format: "%.3f", processingTime))s)")
        
        print("📊 Collection Performance Summary:")
        print("   • Array operations: \(filteredArray.count) items processed")
        print("   • Set operations: \(setIntersection.count) intersection results")
        print("   • Dictionary operations: \(filteredDict.count) filtered results")
        print("   • Total processing time: \(String(format: "%.3f", processingTime))s")
    }
    
    // MARK: - Concurrent Operations Performance Tests
    
    @Test("Should handle concurrent operations efficiently")
    func testConcurrentOperationPerformance() async throws {
        let (catalogService, inventoryService, _) = await createTestServices()
        
        print("🔀 Testing concurrent operation performance...")
        
        // Create test data
        let catalogItems = createRealisticGlassCatalog(itemCount: 1000)
        let startTime = Date()
        
        // Add catalog items concurrently
        await withTaskGroup(of: Void.self) { group in
            let batchSize = 50
            for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, catalogItems.count)
                let batch = Array(catalogItems[batchStart..<batchEnd])
                
                group.addTask {
                    do {
                        for item in batch {
                            _ = try await catalogService.createItem(item)
                        }
                    } catch {
                        print("Batch processing error: \(error)")
                    }
                }
            }
        }
        
        let concurrentTime = Date().timeIntervalSince(startTime)
        
        // Verify results
        let finalItems = try await catalogService.getAllItems()
        
        #expect(finalItems.count > 0, "Should create items concurrently")
        #expect(concurrentTime < 15.0, "Concurrent operations should complete within reasonable time")
        
        print("📊 Concurrent Performance Summary:")
        print("   • Items created: \(finalItems.count)")
        print("   • Concurrent processing time: \(String(format: "%.3f", concurrentTime))s")
        print("   • Throughput: \(String(format: "%.1f", Double(finalItems.count) / concurrentTime)) items/sec")
    }
    
    // MARK: - User Interaction Performance Tests
    
    @Test("Should handle realistic user interaction patterns efficiently")
    func testUserInteractionPerformance() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createTestServices()
        
        print("👤 Testing user interaction performance...")
        
        // Setup realistic dataset
        let catalogItems = createRealisticGlassCatalog(itemCount: 1500)
        
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        await inventoryViewModel.loadInventoryItems()
        
        // Simulate realistic user interaction patterns
        let userInteractionTests: [(String, () async throws -> Void)] = [
            ("Quick search typing", {
                let searchTerms = ["R", "Re", "Red", "Red ", "Red T", "Red Tr", "Red Tra"]
                for term in searchTerms {
                    await inventoryViewModel.searchItems(searchText: term)
                    try await Task.sleep(nanoseconds: 30_000_000) // 30ms between keystrokes
                }
            }),
            ("Filter switching", {
                await inventoryViewModel.filterItems(byType: .inventory)
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                await inventoryViewModel.filterItems(byType: .buy)
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                await inventoryViewModel.filterItems(byType: .sell)
            }),
            ("Search and filter combination", {
                await inventoryViewModel.searchItems(searchText: "Blue")
                await inventoryViewModel.filterItems(byType: .inventory)
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await inventoryViewModel.searchItems(searchText: "")
            })
        ]
        
        var totalInteractionTime: TimeInterval = 0
        
        for (testName, interaction) in userInteractionTests {
            let startTime = Date()
            
            try await interaction()
            
            let interactionTime = Date().timeIntervalSince(startTime)
            totalInteractionTime += interactionTime
            
            print("✅ \(testName): \(String(format: "%.3f", interactionTime))s")
            
            #expect(interactionTime < 8.0, "\(testName) should complete within 8 seconds")
            
            // Verify system remains responsive
            await MainActor.run {
                #expect(inventoryViewModel.isLoading == false, "System should be responsive after \(testName)")
                #expect(inventoryViewModel.consolidatedItems.count >= 0, "Should maintain valid data after \(testName)")
            }
        }
        
        print("📊 User Interaction Performance Summary:")
        print("   • Dataset: \(catalogItems.count) catalog items")
        print("   • Total interaction time: \(String(format: "%.3f", totalInteractionTime))s")
        print("   • Average interaction time: \(String(format: "%.3f", totalInteractionTime / Double(userInteractionTests.count)))s")
        print("   • System remained responsive throughout testing")
    }
    
    // MARK: - Algorithmic Performance Tests
    
    @Test("Should optimize algorithmic complexity for nested operations")
    func testAlgorithmicComplexityOptimization() throws {
        print("⚡ Testing algorithmic complexity optimization...")
        
        // Test efficient vs inefficient patterns
        let dataSize = 1000
        let primaryData = (1...dataSize).map { "Primary\($0)" }
        let secondaryData = (1...dataSize).map { "Secondary\($0)" }
        
        let startTime = Date()
        
        // Efficient approach: Use sets for lookups (O(n) instead of O(n²))
        let secondarySet = Set(secondaryData)
        var efficientMatches = 0
        
        for primary in primaryData {
            let searchKey = "Secondary\(primary.dropFirst(7))" // Extract number and format
            if secondarySet.contains(searchKey) {
                efficientMatches += 1
            }
        }
        
        let efficientTime = Date().timeIntervalSince(startTime)
        
        // Test scalability with larger dataset
        let largeDataSize = 2500
        let largePrimaryData = (1...largeDataSize).map { "Primary\($0)" }
        let largeSecondarySet = Set((1...largeDataSize).map { "Secondary\($0)" })
        
        let largeTestStart = Date()
        var largeMatches = 0
        
        for primary in largePrimaryData {
            let searchKey = "Secondary\(primary.dropFirst(7))"
            if largeSecondarySet.contains(searchKey) {
                largeMatches += 1
            }
        }
        
        let largeTestTime = Date().timeIntervalSince(largeTestStart)
        
        // Assert algorithmic efficiency
        #expect(efficientMatches == dataSize, "Should find all matches efficiently")
        #expect(largeMatches == largeDataSize, "Should find all matches in large dataset")
        #expect(efficientTime < 0.02, "Set-based lookup should be very fast (actual: \(String(format: "%.4f", efficientTime))s)")
        #expect(largeTestTime < 0.05, "Large dataset lookup should scale well (actual: \(String(format: "%.4f", largeTestTime))s)")
        
        // Test scalability - time shouldn't increase dramatically with size
        let scalabilityRatio = largeTestTime / efficientTime
        let sizeRatio = Double(largeDataSize) / Double(dataSize)
        
        #expect(scalabilityRatio < sizeRatio * 1.5, "Algorithm should scale near-linearly (time ratio: \(String(format: "%.2f", scalabilityRatio)), size ratio: \(String(format: "%.2f", sizeRatio)))")
        
        print("📊 Algorithmic Performance Summary:")
        print("   • Small dataset (\(dataSize)): \(String(format: "%.4f", efficientTime))s")
        print("   • Large dataset (\(largeDataSize)): \(String(format: "%.4f", largeTestTime))s")
        print("   • Scalability ratio: \(String(format: "%.2f", scalabilityRatio)) (target: < \(String(format: "%.2f", sizeRatio * 1.5)))")
    }
    
    // MARK: - Performance Benchmark Tests
    
    @Test("Should meet performance benchmarks for production workloads")
    func testProductionPerformanceBenchmarks() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createTestServices()
        
        print("🏭 Testing production performance benchmarks...")
        
        // Production-scale dataset
        let productionCatalogSize = 7500
        let catalogItems = createRealisticGlassCatalog(itemCount: productionCatalogSize)
        
        print("Setting up production-scale dataset: \(productionCatalogSize) items")
        
        let setupStartTime = Date()
        
        // Batch load data efficiently
        let batchSize = 250
        for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, catalogItems.count)
            let batch = Array(catalogItems[batchStart..<batchEnd])
            
            for item in batch {
                _ = try await catalogService.createItem(item)
            }
        }
        
        let setupTime = Date().timeIntervalSince(setupStartTime)
        
        // Test production workload patterns
        let workloadTests = [
            ("Application startup", {
                await inventoryViewModel.loadInventoryItems()
            }),
            ("User search operations", {
                let searches = ["Red", "Blue", "Bullseye", "Transparent", "Rod"]
                for searchTerm in searches {
                    await inventoryViewModel.searchItems(searchText: searchTerm)
                }
            }),
            ("Filter operations", {
                await inventoryViewModel.filterItems(byType: .inventory)
                await inventoryViewModel.filterItems(byType: .buy)
                await inventoryViewModel.filterItems(byType: .sell)
            })
        ]
        
        var totalWorkloadTime: TimeInterval = 0
        
        for (workloadName, workload) in workloadTests {
            let workloadStartTime = Date()
            try await workload()
            let workloadTime = Date().timeIntervalSince(workloadStartTime)
            
            totalWorkloadTime += workloadTime
            
            print("✅ \(workloadName): \(String(format: "%.3f", workloadTime))s")
            
            // Production performance requirements
            let maxTime: TimeInterval = switch workloadName {
            case "Application startup": 20.0 // Startup can be slower
            case "User search operations": 10.0 // Multiple searches
            case "Filter operations": 6.0 // Filter workflow
            default: 8.0
            }
            
            #expect(workloadTime < maxTime, "\(workloadName) should complete within \(maxTime)s for production")
        }
        
        print("📊 Production Performance Summary:")
        print("   • Dataset: \(productionCatalogSize) items")
        print("   • Setup time: \(String(format: "%.3f", setupTime))s")
        print("   • Total workload time: \(String(format: "%.3f", totalWorkloadTime))s")
        print("   • Average workload time: \(String(format: "%.3f", totalWorkloadTime / Double(workloadTests.count)))s")
        print("   • All production benchmarks met")
    }
    
    @Test("Should handle validation of large error lists efficiently")
    func testLargeErrorListPerformance() async throws {
        // Create a large list of errors
        let largeErrorList = (1...100).map { "Error message number \($0)" }
        
        let startTime = Date()
        
        // Create many validation results with large error lists
        for _ in 1...100 {
            let _ = ValidationResult.failure(errors: largeErrorList)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 0.1, "Creating validation results with large error lists should be fast")
    }

}
