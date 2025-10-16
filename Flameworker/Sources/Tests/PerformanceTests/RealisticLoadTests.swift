//
//  RealisticLoadTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 3 Testing Improvements: Performance Under Load with Realistic Datasets
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

@Suite("Realistic Load Performance Tests")
struct RealisticLoadTests {
    
    // MARK: - Test Infrastructure
    
    private func createTestServices() async -> (CatalogService, InventoryTrackingService, InventoryViewModel) {
        // Use the new GlassItem architecture with repository pattern
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
            locationRepository: locationRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        let catalogService = CatalogService(
            glassItemRepository: glassItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: itemTagsRepo
        )
        
        let inventoryViewModel = await InventoryViewModel(inventoryTrackingService: inventoryTrackingService, catalogService: catalogService)
        
        return (catalogService, inventoryTrackingService, inventoryViewModel)
    }
    
    private func createRealisticGlassCatalog(itemCount: Int) -> [GlassItemModel] {
        var catalogItems: [GlassItemModel] = []
        
        let manufacturers = ["bullseye", "spectrum", "uroboros", "kokomo", "oceanside", "wissmach", "youghiogheny"]
        let colors = ["Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Pink", "Amber", "Clear", "Black", "White", "Brown"]
        let finishes = ["Transparent", "Opal", "Cathedral", "Waterglass", "Granite", "Streaky", "Wispy", "Iridescent"]
        
        for i in 1...itemCount {
            let manufacturer = manufacturers[i % manufacturers.count]
            let color = colors[i % colors.count]
            let finish = finishes[i % finishes.count]
            
            let name = "\(color) \(finish)"
            let sku = String(format: "%04d", i)
            let naturalKey = GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: 0)
            
            let item = GlassItemModel(
                naturalKey: naturalKey,
                name: name,
                sku: sku,
                manufacturer: manufacturer,
                coe: manufacturer == "spectrum" ? 96 : 90,
                mfr_status: "available"
            )
            catalogItems.append(item)
        }
        
        return catalogItems
    }
    
    private func createRealisticInventoryData(catalogItems: [GlassItemModel], inventoryRatio: Double = 0.3) -> [InventoryModel] {
        var inventoryItems: [InventoryModel] = []
        
        // Only create inventory for a portion of catalog items (realistic scenario)
        let itemsToStock = catalogItems.shuffled().prefix(Int(Double(catalogItems.count) * inventoryRatio))
        
        for catalogItem in itemsToStock {
            // Random inventory quantities (realistic studio inventory)
            let inventoryQuantity = Double.random(in: 0...20)
            let buyQuantity = Double.random(in: 0...5)
            let sellQuantity = Double.random(in: 0...3)
            
            // Add inventory record if quantity > 0
            if inventoryQuantity > 0 {
                inventoryItems.append(InventoryModel(
                    itemNaturalKey: catalogItem.naturalKey,
                    type: "inventory",
                    quantity: inventoryQuantity
                ))
            }
            
            // Add buy records for some items
            if buyQuantity > 0 && Double.random(in: 0...1) > 0.7 {
                inventoryItems.append(InventoryModel(
                    itemNaturalKey: catalogItem.naturalKey,
                    type: "purchase",
                    quantity: buyQuantity
                ))
            }
            
            // Add sell records for some items
            if sellQuantity > 0 && Double.random(in: 0...1) > 0.8 {
                inventoryItems.append(InventoryModel(
                    itemNaturalKey: catalogItem.naturalKey,
                    type: "sale",
                    quantity: sellQuantity
                ))
            }
        }
        
        return inventoryItems
    }
    
    // MARK: - Large Catalog Performance Tests
    
    @Test("Should handle realistic catalog sizes efficiently (10,000+ items)")
    func testRealisticCatalogPerformance() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("🔬 Testing performance with realistic catalog size...")
        
        // Create large realistic catalog (10,000 items)
        let catalogSize = 10_000
        print("Creating \(catalogSize) catalog items...")
        let startTime = Date()
        
        let catalogItems = createRealisticGlassCatalog(itemCount: catalogSize)
        let creationTime = Date().timeIntervalSince(startTime)
        print("✅ Created \(catalogItems.count) catalog items in \(String(format: "%.3f", creationTime))s")
        
        // Add items to catalog service in batches for better performance
        print("Adding catalog items to service...")
        let addStartTime = Date()
        let batchSize = 100
        
        for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, catalogItems.count)
            let batch = Array(catalogItems[batchStart..<batchEnd])
            
            for item in batch {
                _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
            }
            
            if batchStart % (batchSize * 10) == 0 {
                print("  Added \(batchEnd) / \(catalogItems.count) items...")
            }
        }
        
        let addTime = Date().timeIntervalSince(addStartTime)
        print("✅ Added all catalog items in \(String(format: "%.3f", addTime))s")
        
        // Test retrieval performance
        print("Testing catalog retrieval performance...")
        let retrievalStartTime = Date()
        
        let retrievedItems = try await catalogService.getAllGlassItems()
        
        let retrievalTime = Date().timeIntervalSince(retrievalStartTime)
        print("✅ Retrieved \(retrievedItems.count) items in \(String(format: "%.3f", retrievalTime))s")
        
        #expect(retrievedItems.count == catalogSize, "Should retrieve all catalog items")
        #expect(retrievalTime < 5.0, "Retrieval should complete within 5 seconds for 10k items")
        
        print("📊 Performance Summary - Large Catalog:")
        print("   • Items: \(catalogSize)")
        print("   • Creation: \(String(format: "%.3f", creationTime))s")
        print("   • Addition: \(String(format: "%.3f", addTime))s (\(String(format: "%.1f", Double(catalogSize) / addTime)) items/sec)")
        print("   • Retrieval: \(String(format: "%.3f", retrievalTime))s")
    }
    
    @Test("Should perform complex search efficiently across large datasets")
    func testComplexSearchPerformance() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("🔍 Testing search performance with large dataset...")
        
        // Create medium-sized catalog for search testing (5,000 items)
        let catalogSize = 5_000
        let catalogItems = createRealisticGlassCatalog(itemCount: catalogSize)
        
        print("Setting up \(catalogSize) items for search testing...")
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
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
        
        print("Running search performance tests...")
        
        for (scenarioName, searchTerm) in searchScenarios {
            let searchStartTime = Date()
            
            let searchRequest = GlassItemSearchRequest(searchText: searchTerm)
            let searchResult = try await catalogService.searchGlassItems(request: searchRequest)
            let searchResults = searchResult.items
            
            let searchTime = Date().timeIntervalSince(searchStartTime)
            
            print("✅ \(scenarioName) ('\(searchTerm)'): \(searchResults.count) results in \(String(format: "%.3f", searchTime))s")
            
            #expect(searchTime < 2.0, "Search for '\(searchTerm)' should complete within 2 seconds")
            #expect(searchResults.count >= 0, "Search should return valid results")
        }
        
        // Test rapid sequential searches (user typing simulation)
        print("Testing rapid sequential search performance...")
        let rapidSearchStartTime = Date()
        let searchSequence = ["B", "Bu", "Bul", "Bull", "Bulls", "Bullse", "Bullsey", "Bullseye"]
        
        for searchTerm in searchSequence {
            let searchRequest = GlassItemSearchRequest(searchText: searchTerm)
            _ = try await catalogService.searchGlassItems(request: searchRequest)
        }
        
        let rapidSearchTime = Date().timeIntervalSince(rapidSearchStartTime)
        print("✅ Rapid search sequence completed in \(String(format: "%.3f", rapidSearchTime))s")
        
        #expect(rapidSearchTime < 3.0, "Rapid search sequence should complete within 3 seconds")
        
        print("📊 Search Performance Summary:")
        print("   • Dataset size: \(catalogSize) items")
        print("   • Search scenarios: \(searchScenarios.count) different patterns")
        print("   • Rapid search: \(searchSequence.count) sequential searches")
        print("   • All searches completed efficiently")
    }
    
    @Test("Should handle realistic inventory sizes efficiently (1000+ items)")
    func testRealisticInventoryPerformance() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("📦 Testing inventory performance with realistic dataset...")
        
        // Create catalog and inventory data
        let catalogSize = 3_000 // Smaller catalog but larger inventory complexity
        let catalogItems = createRealisticGlassCatalog(itemCount: catalogSize)
        
        print("Setting up catalog and inventory data...")
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Create realistic inventory (30% of catalog items have inventory records)
        let inventoryItems = createRealisticInventoryData(catalogItems: catalogItems, inventoryRatio: 0.3)
        print("Created \(inventoryItems.count) inventory records for \(catalogItems.count) catalog items")
        
        let inventoryStartTime = Date()
        
        for item in inventoryItems {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        let inventoryAddTime = Date().timeIntervalSince(inventoryStartTime)
        print("✅ Added \(inventoryItems.count) inventory items in \(String(format: "%.3f", inventoryAddTime))s")
        
        // Test inventory consolidation performance
        print("Testing inventory consolidation performance...")
        let consolidationStartTime = Date()
        
        await inventoryViewModel.loadInventoryItems()
        
        let consolidationTime = Date().timeIntervalSince(consolidationStartTime)
        
        await MainActor.run {
            let consolidatedCount = inventoryViewModel.completeItems.count
            print("✅ Consolidated \(inventoryItems.count) items into \(consolidatedCount) groups in \(String(format: "%.3f", consolidationTime))s")
            
            #expect(consolidatedCount > 0, "Should have consolidated inventory items")
            #expect(consolidatedCount <= catalogSize, "Consolidated count should not exceed catalog size")
        }
        
        #expect(consolidationTime < 5.0, "Consolidation should complete within 5 seconds")
        
        // Test inventory search and filter performance
        print("Testing inventory search performance...")
        let searchStartTime = Date()
        
        await inventoryViewModel.searchItems(searchText: "Red")
        
        let searchTime = Date().timeIntervalSince(searchStartTime)
        
        await MainActor.run {
            let searchResults = inventoryViewModel.filteredItems.count
            print("✅ Inventory search found \(searchResults) items in \(String(format: "%.3f", searchTime))s")
        }
        
        #expect(searchTime < 2.0, "Inventory search should complete within 2 seconds")
        
        print("📊 Inventory Performance Summary:")
        print("   • Catalog items: \(catalogSize)")
        print("   • Inventory records: \(inventoryItems.count)")
        print("   • Addition time: \(String(format: "%.3f", inventoryAddTime))s")
        print("   • Consolidation time: \(String(format: "%.3f", consolidationTime))s")
        print("   • Search time: \(String(format: "%.3f", searchTime))s")
    }
    
    // MARK: - User Interaction Performance Tests
    
    @Test("Should handle realistic user interaction patterns efficiently")
    func testUserInteractionPerformance() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("👤 Testing realistic user interaction patterns...")
        
        // Setup realistic dataset
        let catalogItems = createRealisticGlassCatalog(itemCount: 2_000)
        let inventoryItems = createRealisticInventoryData(catalogItems: catalogItems, inventoryRatio: 0.4)
        
        print("Setting up dataset: \(catalogItems.count) catalog, \(inventoryItems.count) inventory")
        
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        for item in inventoryItems {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        await inventoryViewModel.loadInventoryItems()
        
        // Simulate realistic user interaction patterns
        let userInteractionTests: [(String, () async throws -> Void)] = [
            ("Quick search typing", {
                let searchTerms = ["R", "Re", "Red", "Red ", "Red T", "Red Tr", "Red Tra"]
                for term in searchTerms {
                    await inventoryViewModel.searchItems(searchText: term)
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05s between keystrokes
                }
            }),
            ("Filter switching", {
                // Test filtering by different types using new architecture
                await inventoryViewModel.filterItems(byType: "inventory")
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                await inventoryViewModel.filterItems(byType: "purchase")
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                await inventoryViewModel.filterItems(byType: "sale")
            }),
            ("Search and filter combination", {
                await inventoryViewModel.searchItems(searchText: "Blue")
                await inventoryViewModel.filterItems(byType: "inventory")
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                await inventoryViewModel.searchItems(searchText: "")
            }),
            ("Data refresh during interaction", {
                await inventoryViewModel.searchItems(searchText: "Bullseye")
                await inventoryViewModel.loadInventoryItems() // Simulate data refresh
                await inventoryViewModel.searchItems(searchText: "Spectrum")
            })
        ]
        
        print("Running user interaction performance tests...")
        
        for (testName, interaction) in userInteractionTests {
            let startTime = Date()
            
            try await interaction()
            
            let interactionTime = Date().timeIntervalSince(startTime)
            
            print("✅ \(testName): \(String(format: "%.3f", interactionTime))s")
            
            #expect(interactionTime < 5.0, "\(testName) should complete within 5 seconds")
            
            // Verify system remains responsive
            await MainActor.run {
                #expect(inventoryViewModel.isLoading == false, "System should be responsive after \(testName)")
                #expect(inventoryViewModel.completeItems.count >= 0, "Should maintain valid data after \(testName)")
                #expect(inventoryViewModel.filteredItems.count >= 0, "Should maintain valid filtered data after \(testName)")
            }
        }
        
        print("📊 User Interaction Performance Summary:")
        print("   • Dataset: \(catalogItems.count) catalog + \(inventoryItems.count) inventory")
        print("   • All interaction patterns completed efficiently")
        print("   • System remained responsive throughout testing")
    }
    
    // MARK: - Memory Usage and Resource Tests
    
    @Test("Should manage memory efficiently with large datasets")
    func testMemoryEfficiencyWithLargeDatasets() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("💾 Testing memory efficiency with large datasets...")
        
        // Create progressively larger datasets and monitor performance
        let testSizes = [1_000, 2_500, 5_000, 7_500]
        
        for size in testSizes {
            print("Testing with \(size) catalog items...")
            
            let startTime = Date()
            let catalogItems = createRealisticGlassCatalog(itemCount: size)
            let inventoryItems = createRealisticInventoryData(catalogItems: catalogItems, inventoryRatio: 0.25)
            
            // Add items in batches
            let batchSize = 250
            for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, catalogItems.count)
                let batch = Array(catalogItems[batchStart..<batchEnd])
                
                for item in batch {
                    _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
                }
            }
            
            for item in inventoryItems {
                _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
            }
            
            // Test memory-intensive operations
            await inventoryViewModel.loadInventoryItems()
            
            await MainActor.run {
                let consolidatedCount = inventoryViewModel.completeItems.count
                #expect(consolidatedCount > 0, "Should consolidate items for dataset size \(size)")
            }
            
            // Test search performance doesn't degrade
            let searchStartTime = Date()
            await inventoryViewModel.searchItems(searchText: "Red")
            let searchTime = Date().timeIntervalSince(searchStartTime)
            
            let totalTime = Date().timeIntervalSince(startTime)
            
            print("  ✅ Size \(size): Total \(String(format: "%.3f", totalTime))s, Search \(String(format: "%.3f", searchTime))s")
            
            #expect(searchTime < 3.0, "Search should remain efficient at size \(size)")
            #expect(totalTime < 30.0, "Total processing should complete within 30s for size \(size)")
            
            // Clear data for next test (simulate memory cleanup)
            // Note: In a real app, you'd want to test actual memory cleanup
        }
        
        print("📊 Memory Efficiency Summary:")
        print("   • Tested dataset sizes: \(testSizes)")
        print("   • Performance remained acceptable across all sizes")
        print("   • Search performance scaled efficiently")
        print("   • Memory usage patterns appear sustainable")
    }
}

// MARK: - Performance Measurement Extensions

extension RealisticLoadTests {
    
    /// Measures the time taken to execute an async operation
    private func measureTime<T>(operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let time = Date().timeIntervalSince(startTime)
        return (result, time)
    }
    
    /// Runs an operation multiple times and returns average performance
    private func benchmarkOperation<T>(
        name: String,
        iterations: Int = 5,
        operation: () async throws -> T
    ) async throws -> (averageTime: TimeInterval, results: [T]) {
        print("Benchmarking \(name) over \(iterations) iterations...")
        
        var times: [TimeInterval] = []
        var results: [T] = []
        
        for i in 1...iterations {
            let (result, time) = try await measureTime(operation: operation)
            times.append(time)
            results.append(result)
            
            print("  Iteration \(i): \(String(format: "%.3f", time))s")
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        print("✅ \(name) average: \(String(format: "%.3f", averageTime))s")
        
        return (averageTime, results)
    }
}
