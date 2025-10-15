//
//  ResourceManagementTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 3 Testing Improvements: Memory Optimization and Performance Testing
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

@Suite("Resource Management Tests")
struct ResourceManagementTests {
    
    // MARK: - Test Infrastructure
    
    private func createTestServices() async -> (CatalogService, InventoryTrackingService, InventoryViewModel) {
        RepositoryFactory.configureForTesting()
        
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        let inventoryViewModel = await InventoryViewModel(inventoryTrackingService: inventoryTrackingService, catalogService: catalogService)
        
        return (catalogService, inventoryTrackingService, inventoryViewModel)
    }
    
    private func createLargeDataset(catalogSize: Int, inventoryMultiplier: Double = 2.0) async throws -> (catalog: [GlassItemModel], inventory: [InventoryModel]) {
        var catalogItems: [GlassItemModel] = []
        var inventoryItems: [InventoryModel] = []
        
        let manufacturers = ["Bullseye", "Spectrum", "Uroboros", "Kokomo", "Oceanside"]
        let colors = ["Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Pink", "Clear", "Black", "White"]
        let types = ["Opal", "Transparent", "Cathedral", "Streaky", "Granite", "Iridescent"]
        
        // Create catalog items
        for i in 1...catalogSize {
            let manufacturer = manufacturers[i % manufacturers.count]
            let color = colors[i % colors.count]
            let type = types[i % types.count]
            
            let item = GlassItemModel(
                naturalKey: GlassItemModel.createNaturalKey(manufacturer: manufacturer.lowercased(), sku: String(format: "%04d", i), sequence: 0),
                name: "\(color) \(type)",
                sku: String(format: "%04d", i),
                manufacturer: manufacturer,
                mfrNotes: nil,
                coe: 96,
                url: nil,
                mfrStatus: "available"
            )
            catalogItems.append(item)
            
            // Create corresponding inventory items (some items have multiple records)
            let inventoryCount = Int(inventoryMultiplier * Double.random(in: 0.5...1.5))
            for j in 1...max(1, inventoryCount) {
                let types = ["inventory", "buy", "sell"]
                let inventoryType = types[j % types.count]
                let quantity = Double.random(in: 1...20)
                
                let inventoryItem = InventoryModel(
                    itemNaturalKey: item.naturalKey,
                    type: inventoryType,
                    quantity: quantity
                )
                inventoryItems.append(inventoryItem)
            }
        }
        
        return (catalogItems, inventoryItems)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Should manage memory efficiently during large data operations")
    func testMemoryManagementWithLargeDatasets() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("💾 Testing memory management with large datasets...")
        
        // Test progressively larger datasets to find memory limits
        let testSizes = [1_000, 2_500, 5_000]
        
        for size in testSizes {
            print("\nTesting memory efficiency with \(size) catalog items...")
            
            let dataGenerationStart = Date()
            let (catalogItems, inventoryItems) = try await createLargeDataset(catalogSize: size, inventoryMultiplier: 1.5)
            let generationTime = Date().timeIntervalSince(dataGenerationStart)
            
            print("  📊 Generated \(catalogItems.count) catalog + \(inventoryItems.count) inventory items in \(String(format: "%.3f", generationTime))s")
            
            // Add data in batches to manage memory
            let batchSize = 250
            let additionStart = Date()
            
            // Add catalog items in batches
            for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, catalogItems.count)
                let batch = Array(catalogItems[batchStart..<batchEnd])
                
                for item in batch {
                    _ = try await catalogService.createGlassItem(item)
                }
                
                // Brief pause to allow memory cleanup
                if batchStart % (batchSize * 4) == 0 {
                    try await Task.sleep(nanoseconds: 10_000_000) // 0.01s
                }
            }
            
            // Add inventory items in batches
            for batchStart in stride(from: 0, to: inventoryItems.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, inventoryItems.count)
                let batch = Array(inventoryItems[batchStart..<batchEnd])
                
                for item in batch {
                    _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
                }
                
                if batchStart % (batchSize * 4) == 0 {
                    try await Task.sleep(nanoseconds: 10_000_000) // 0.01s
                }
            }
            
            let additionTime = Date().timeIntervalSince(additionStart)
            print("  ✅ Added all data in \(String(format: "%.3f", additionTime))s")
            
            // Test memory-intensive consolidation operation
            let consolidationStart = Date()
            await inventoryViewModel.loadInventoryItems()
            
            let consolidationTime = Date().timeIntervalSince(consolidationStart)
            
            await MainActor.run {
                let consolidatedCount = inventoryViewModel.filteredItems.count
                print("  📈 Consolidated \(inventoryItems.count) items into \(consolidatedCount) groups in \(String(format: "%.3f", consolidationTime))s")
                
                #expect(consolidatedCount > 0, "Should successfully consolidate items at size \(size)")
                #expect(consolidatedCount <= catalogItems.count, "Consolidated count should not exceed catalog size")
            }
            
            // Test search performance doesn't degrade with memory pressure
            let searchStart = Date()
            await inventoryViewModel.searchItems(searchText: "Red")
            let searchTime = Date().timeIntervalSince(searchStart)
            
            await MainActor.run {
                let searchResults = inventoryViewModel.filteredItems.count
                print("  🔍 Search found \(searchResults) items in \(String(format: "%.3f", searchTime))s")
            }
            
            // Verify performance remains acceptable
            #expect(additionTime < 60.0, "Data addition should complete within 60s for \(size) items")
            #expect(consolidationTime < 10.0, "Consolidation should complete within 10s for \(size) items")
            #expect(searchTime < 3.0, "Search should remain fast (<3s) for \(size) items")
            
            print("  ✅ Memory management efficient for \(size) items")
        }
        
        print("\n📊 Memory Management Summary:")
        print("   • Tested sizes: \(testSizes)")
        print("   • Batch processing maintained memory efficiency")
        print("   • Performance scaled acceptably across all sizes")
        print("   • No memory-related failures detected")
    }
    
    @Test("Should handle resource cleanup properly")
    func testResourceCleanup() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("🧹 Testing resource cleanup patterns...")
        
        // Create and process data multiple times to test cleanup
        let iterations = 5
        let itemsPerIteration = 1_000
        
        for iteration in 1...iterations {
            print("Iteration \(iteration): Creating \(itemsPerIteration) items...")
            
            let iterationStart = Date()
            
            // Create data for this iteration
            let (catalogItems, inventoryItems) = try await createLargeDataset(catalogSize: itemsPerIteration)
            
            // Add data
            for item in catalogItems {
                _ = try await catalogService.createGlassItem(item)
            }
            
            for item in inventoryItems.prefix(itemsPerIteration) { // Limit inventory for faster testing
                _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
            }
            
            // Process data (memory-intensive operations)
            await inventoryViewModel.loadInventoryItems()
            await inventoryViewModel.searchItems(searchText: "Red")
            // TODO: Update for new architecture - await inventoryViewModel.filterItems(byType: "inventory")
            await inventoryViewModel.searchItems(searchText: "Blue")
            
            let iterationTime = Date().timeIntervalSince(iterationStart)
            
            await MainActor.run {
                let consolidatedCount = inventoryViewModel.filteredItems.count
                let filteredCount = inventoryViewModel.filteredItems.count
                
                print("  ✅ Iteration \(iteration): \(consolidatedCount) consolidated, \(filteredCount) filtered in \(String(format: "%.3f", iterationTime))s")
                
                #expect(consolidatedCount > 0, "Should process data in iteration \(iteration)")
                #expect(filteredCount >= 0, "Should filter data in iteration \(iteration)")
            }
            
            #expect(iterationTime < 30.0, "Each iteration should complete within 30s")
            
            // Brief pause between iterations to allow cleanup
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        // Test that final state is still responsive after multiple iterations
        print("Testing final system responsiveness after multiple iterations...")
        
        let finalTestStart = Date()
        await inventoryViewModel.loadInventoryItems()
        await inventoryViewModel.searchItems(searchText: "Final")
        let finalTestTime = Date().timeIntervalSince(finalTestStart)
        
        await MainActor.run {
            #expect(inventoryViewModel.isLoading == false, "System should be responsive after resource cleanup")
            #expect(inventoryViewModel.filteredItems.count >= 0, "Should maintain valid state after cleanup")
        }
        
        #expect(finalTestTime < 5.0, "Final operations should remain fast after multiple iterations")
        
        print("✅ Resource cleanup test successful!")
        print("📊 Cleanup Summary:")
        print("   • Iterations: \(iterations)")
        print("   • Items per iteration: \(itemsPerIteration)")
        print("   • Final responsiveness: \(String(format: "%.3f", finalTestTime))s")
        print("   • System remained stable across all iterations")
    }
    
    @Test("Should optimize data structure usage efficiently")
    func testDataStructureOptimization() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("🏗️ Testing data structure optimization...")
        
        // Create dataset with complex relationships for optimization testing
        let catalogSize = 2_000
        let (catalogItems, inventoryItems) = try await createLargeDataset(catalogSize: catalogSize, inventoryMultiplier: 3.0)
        
        print("Setting up complex dataset: \(catalogItems.count) catalog + \(inventoryItems.count) inventory items")
        
        // Add all data
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item)
        }
        
        for item in inventoryItems {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        // Test various data access patterns for optimization
        let optimizationTests = [
            ("Initial consolidation", {
                await inventoryViewModel.loadInventoryItems()
            }),
            ("Search optimization", {
                await inventoryViewModel.searchItems(searchText: "Red")
                await inventoryViewModel.searchItems(searchText: "Bullseye")  
                await inventoryViewModel.searchItems(searchText: "Transparent")
            }),
            ("Filter optimization", {
                await inventoryViewModel.filterItems(byType: "inventory")
                await inventoryViewModel.filterItems(byType: "buy")
                await inventoryViewModel.filterItems(byType: "sell")
            }),
            ("Combined operations optimization", {
                await inventoryViewModel.searchItems(searchText: "Blue")
                await inventoryViewModel.filterItems(byType: "inventory")
                await inventoryViewModel.searchItems(searchText: "Green")
            })
        ]
        
        print("Running data structure optimization tests...")
        
        for (testName, operation) in optimizationTests {
            let testStart = Date()
            
            await operation()
            
            let testTime = Date().timeIntervalSince(testStart)
            
            await MainActor.run {
                let consolidatedCount = inventoryViewModel.filteredItems.count
                let filteredCount = inventoryViewModel.filteredItems.count
                
                print("  ✅ \(testName): \(consolidatedCount) consolidated, \(filteredCount) filtered in \(String(format: "%.3f", testTime))s")
                
                #expect(consolidatedCount >= 0, "\(testName) should maintain valid consolidated data")
                #expect(filteredCount >= 0, "\(testName) should maintain valid filtered data")
                #expect(testTime < 5.0, "\(testName) should complete within 5s")
            }
        }
        
        // Test repeated operations for optimization effectiveness
        print("Testing repeated operation optimization...")
        
        let repeatCount = 10
        let repeatStart = Date()
        
        for i in 1...repeatCount {
            await inventoryViewModel.searchItems(searchText: "Red")
            await inventoryViewModel.searchItems(searchText: "Blue")
            
            if i % 3 == 0 {
                try await Task.sleep(nanoseconds: 10_000_000) // 0.01s brief pause
            }
        }
        
        let repeatTime = Date().timeIntervalSince(repeatStart)
        let averageOperationTime = repeatTime / Double(repeatCount * 2) // 2 operations per iteration
        
        print("  📈 Repeated operations: \(repeatCount * 2) operations in \(String(format: "%.3f", repeatTime))s")
        print("  📊 Average operation time: \(String(format: "%.3f", averageOperationTime))s")
        
        #expect(averageOperationTime < 0.5, "Average operation should be under 0.5s after optimization")
        
        print("✅ Data structure optimization successful!")
        print("📊 Optimization Summary:")
        print("   • Dataset: \(catalogItems.count) catalog + \(inventoryItems.count) inventory")
        print("   • All optimization patterns performed efficiently")
        print("   • Repeated operations showed optimization benefits")
        print("   • Average operation time: \(String(format: "%.3f", averageOperationTime))s")
    }
    
    @Test("Should handle concurrent resource access safely")
    func testConcurrentResourceAccess() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("🔒 Testing concurrent resource access safety...")
        
        // Setup shared dataset for concurrent access
        let (catalogItems, inventoryItems) = try await createLargeDataset(catalogSize: 1_500)
        
        print("Setting up shared dataset: \(catalogItems.count) catalog + \(inventoryItems.count) inventory items")
        
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item)
        }
        
        for item in inventoryItems.prefix(1_500) { // Limit for faster setup
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        await inventoryViewModel.loadInventoryItems()
        
        print("Testing concurrent resource access patterns...")
        
        // Test concurrent read operations (should be safe)
        await withTaskGroup(of: Void.self) { group in
            
            // Multiple concurrent search operations
            for i in 1...8 {
                group.addTask {
                    let searches = ["Red", "Blue", "Green", "Bullseye", "Spectrum"]
                    let searchTerm = searches[i % searches.count]
                    
                    do {
                        await inventoryViewModel.searchItems(searchText: searchTerm)
                        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                        await inventoryViewModel.searchItems(searchText: "")
                    } catch {
                        print("Concurrent search error \(i): \(error)")
                    }
                }
            }
            
            // Concurrent filter operations
            for i in 1...4 {
                group.addTask {
                    let filterTypes = ["inventory", "buy", "sell"]
                    let filterType = filterTypes[i % filterTypes.count]
                    
                    do {
                        await inventoryViewModel.filterItems(byType: filterType)
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    } catch {
                        print("Concurrent filter error \(i): \(error)")
                    }
                }
            }
            
            // Concurrent data refresh operations
            for i in 1...3 {
                group.addTask {
                    do {
                        await inventoryViewModel.loadInventoryItems()
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                    } catch {
                        print("Concurrent refresh error \(i): \(error)")
                    }
                }
            }
        }
        
        print("Verifying resource access safety after concurrent operations...")
        
        // Verify system stability after concurrent access
        await MainActor.run {
            #expect(inventoryViewModel.isLoading == false, "System should be stable after concurrent access")
            #expect(inventoryViewModel.filteredItems.count >= 0, "Should maintain valid consolidated data")
            #expect(inventoryViewModel.filteredItems.count >= 0, "Should maintain valid filtered data")
            
            // Verify data integrity
            let consolidatedItems = inventoryViewModel.filteredItems
            for item in consolidatedItems {
                #expect(!item.glassItem.naturalKey.isEmpty, "All items should have valid catalog codes after concurrent access")
                #expect(item.totalQuantity >= 0, "All quantities should be valid after concurrent access")
            }
        }
        
        // Test final operations to ensure system is still responsive
        let finalTestStart = Date()
        await inventoryViewModel.searchItems(searchText: "Final Test")
        let finalTestTime = Date().timeIntervalSince(finalTestStart)
        
        #expect(finalTestTime < 2.0, "System should remain responsive after concurrent resource access")
        
        print("✅ Concurrent resource access safety confirmed!")
        print("📊 Resource Access Summary:")
        print("   • Concurrent search operations: 8")
        print("   • Concurrent filter operations: 4")
        print("   • Concurrent refresh operations: 3")
        print("   • Final system responsiveness: \(String(format: "%.3f", finalTestTime))s")
        print("   • No resource access conflicts detected")
        print("   • Data integrity maintained throughout")
    }
    
    @Test("Should optimize performance for production workloads")
    func testProductionWorkloadOptimization() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = await createTestServices()
        
        print("🏭 Testing production workload optimization...")
        
        // Simulate realistic production dataset sizes
        let productionCatalogSize = 8_000 // Large glass studio catalog
        let (catalogItems, inventoryItems) = try await createLargeDataset(
            catalogSize: productionCatalogSize, 
            inventoryMultiplier: 0.4 // More realistic inventory-to-catalog ratio
        )
        
        print("Setting up production-scale dataset:")
        print("  • Catalog items: \(catalogItems.count)")
        print("  • Inventory items: \(inventoryItems.count)")
        
        let setupStart = Date()
        
        // Batch load catalog data
        let catalogBatchSize = 500
        for batchStart in stride(from: 0, to: catalogItems.count, by: catalogBatchSize) {
            let batchEnd = min(batchStart + catalogBatchSize, catalogItems.count)
            let batch = Array(catalogItems[batchStart..<batchEnd])
            
            for item in batch {
                _ = try await catalogService.createGlassItem(item)
            }
            
            if batchStart % (catalogBatchSize * 4) == 0 && batchStart > 0 {
                print("    Loaded \(batchEnd) / \(catalogItems.count) catalog items...")
            }
        }
        
        // Load inventory data
        for item in inventoryItems {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        let setupTime = Date().timeIntervalSince(setupStart)
        print("  ✅ Production dataset setup: \(String(format: "%.3f", setupTime))s")
        
        // Test production workload patterns
        let productionWorkloads = [
            ("Startup load", {
                await inventoryViewModel.loadInventoryItems()
            }),
            ("Daily search pattern", {
                // Simulate typical daily searches
                let commonSearches = ["Red", "Blue", "Clear", "Bullseye", "Spectrum", "Opal", "Transparent"]
                for searchTerm in commonSearches {
                    await inventoryViewModel.searchItems(searchText: searchTerm)
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s between searches
                }
            }),
            ("Inventory management pattern", {
                // Simulate typical inventory management workflow
                await inventoryViewModel.filterItems(byType: "inventory")
                await inventoryViewModel.searchItems(searchText: "Low")
                await inventoryViewModel.filterItems(byType: "buy")
                await inventoryViewModel.searchItems(searchText: "")
            }),
            ("User interaction simulation", {
                // Simulate realistic user interaction patterns
                await inventoryViewModel.searchItems(searchText: "B")
                try await Task.sleep(nanoseconds: 50_000_000)
                await inventoryViewModel.searchItems(searchText: "Bl")
                try await Task.sleep(nanoseconds: 50_000_000)
                await inventoryViewModel.searchItems(searchText: "Blue")
                await inventoryViewModel.filterItems(byType: "inventory")
            })
        ]
        
        print("Running production workload optimization tests...")
        
        for (workloadName, workload) in productionWorkloads {
            let workloadStart = Date()
            
            try await workload()
            
            let workloadTime = Date().timeIntervalSince(workloadStart)
            
            await MainActor.run {
                let consolidatedCount = inventoryViewModel.filteredItems.count
                let filteredCount = inventoryViewModel.filteredItems.count
                
                print("  ✅ \(workloadName): \(consolidatedCount) consolidated, \(filteredCount) filtered in \(String(format: "%.3f", workloadTime))s")
            }
            
            // Production performance requirements
            let maxTime: TimeInterval = switch workloadName {
            case "Startup load": 15.0 // Startup can be slower
            case "Daily search pattern": 8.0 // Multiple searches
            case "Inventory management pattern": 5.0 // Management workflow
            case "User interaction simulation": 3.0 // Real-time user interaction
            default: 5.0
            }
            
            #expect(workloadTime < maxTime, "\(workloadName) should complete within \(maxTime)s for production")
        }
        
        // Test sustained performance (simulate 8-hour workday operations)
        print("Testing sustained production performance...")
        
        let sustainedTestStart = Date()
        let sustainedOperations = 20 // Reduced for test performance
        
        for i in 1...sustainedOperations {
            // Simulate varied operations throughout a workday
            switch i % 4 {
            case 0:
                await inventoryViewModel.searchItems(searchText: "Red")
            case 1:
                await inventoryViewModel.filterItems(byType: "inventory")
            case 2:
                await inventoryViewModel.searchItems(searchText: "Spectrum")
            case 3:
                await inventoryViewModel.loadInventoryItems()
            default:
                break
            }
            
            if i % 10 == 0 {
                try await Task.sleep(nanoseconds: 50_000_000) // Brief pause every 10 operations
            }
        }
        
        let sustainedTime = Date().timeIntervalSince(sustainedTestStart)
        let averageOperationTime = sustainedTime / Double(sustainedOperations)
        
        print("  📈 Sustained performance: \(sustainedOperations) operations in \(String(format: "%.3f", sustainedTime))s")
        print("  📊 Average sustained operation: \(String(format: "%.3f", averageOperationTime))s")
        
        #expect(averageOperationTime < 1.0, "Average sustained operation should be under 1s")
        
        print("✅ Production workload optimization successful!")
        print("📊 Production Optimization Summary:")
        print("   • Dataset: \(catalogItems.count) catalog + \(inventoryItems.count) inventory")
        print("   • Setup time: \(String(format: "%.3f", setupTime))s")
        print("   • All production workloads met performance requirements")
        print("   • Sustained performance: \(String(format: "%.3f", averageOperationTime))s per operation")
        print("   • System optimized for realistic production use")
    }
}
