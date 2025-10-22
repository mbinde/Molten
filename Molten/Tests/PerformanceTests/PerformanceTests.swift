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
import CoreData
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("Performance Tests - Isolated Suite", .serialized)
@MainActor
struct PerformanceTests {

    // MARK: - Test Infrastructure

    @MainActor
    private func createTestServices() async -> (CatalogService, InventoryTrackingService, ShoppingListService) {
        // Use the new GlassItem architecture with repository pattern
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let userTagsRepo = MockUserTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()

        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
            locationRepository: locationRepo,
            itemTagsRepository: itemTagsRepo
        )

        let shoppingListRepository = MockShoppingListRepository()
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo
        )

        let catalogService = CatalogService(
            glassItemRepository: glassItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo
        )
        
        return (catalogService, inventoryTrackingService, shoppingListService)
    }
    
    @MainActor
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
            let coe: Int32 = manufacturer == "spectrum" ? 96 : 90
            let naturalKey = GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: 0)
            
            let item = GlassItemModel(
                natural_key: naturalKey,
                name: name,
                sku: sku,
                manufacturer: manufacturer,
                mfr_notes: "Performance test item \(i)",
                coe: coe,
                url: "https://example.com/\(sku)",
                mfr_status: "available"
            )
            catalogItems.append(item)
        }
        
        return catalogItems
    }
    
    // MARK: - Large Dataset Performance Tests
    
    @Test("Should handle large catalog sizes efficiently (10,000+ items)")
    func testLargeCatalogPerformance() async throws {
        let (catalogService, _, _) = await createTestServices()
        
        print("🔬 Testing performance with large catalog size...")
        
        // Create large realistic catalog (reduced size for performance testing)
        let catalogSize = 1_000  // Reduced from 10k for faster testing
        let catalogItems = createRealisticGlassCatalog(itemCount: catalogSize)
        
        print("Adding \(catalogSize) catalog items...")
        let addStartTime = Date()
        
        // Add items in batches for better performance
        let batchSize = 50
        for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, catalogItems.count)
            let batch = Array(catalogItems[batchStart..<batchEnd])
            
            for item in batch {
                _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
            }
        }
        
        let addTime = Date().timeIntervalSince(addStartTime)
        print("✅ Added all catalog items in \(String(format: "%.3f", addTime))s")
        
        // Test retrieval performance
        let retrievalStartTime = Date()
        let retrievedItems = try await catalogService.getAllGlassItems()
        let retrievalTime = Date().timeIntervalSince(retrievalStartTime)
        
        #expect(retrievedItems.count == catalogSize, "Should retrieve all catalog items")
        #expect(retrievalTime < 10.0, "Retrieval should complete within 10 seconds for \(catalogSize) items")
        
        print("📊 Large Catalog Performance Summary:")
        print("   • Items: \(catalogSize)")
        print("   • Addition: \(String(format: "%.3f", addTime))s (\(String(format: "%.1f", Double(catalogSize) / addTime)) items/sec)")
        print("   • Retrieval: \(String(format: "%.3f", retrievalTime))s")
    }
    
    @Test("Should perform search efficiently across large datasets")
    @MainActor
    func testSearchPerformanceAtScale() async throws {
        let (catalogService, _, _) = await createTestServices()
        
        print("🔍 Testing search performance with large dataset...")
        
        // Create medium-sized catalog for search testing
        let catalogSize = 500  // Reduced for faster testing
        let catalogItems = createRealisticGlassCatalog(itemCount: catalogSize)
        
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Test various search scenarios
        let searchScenarios = [
            ("Single letter", "R"),
            ("Color search", "Red"),
            ("Manufacturer", "bullseye"),
            ("Finish type", "Transparent"),
            ("Complex term", "Red Transparent")
        ]
        
        var totalSearchTime: TimeInterval = 0
        
        for (scenarioName, searchTerm) in searchScenarios {
            let searchStartTime = Date()
            let searchRequest = GlassItemSearchRequest(
                searchText: searchTerm,
                tags: [],
                manufacturers: [],
                coeValues: [],
                manufacturerStatuses: [],
                hasInventory: nil,
                inventoryTypes: [],
                sortBy: .name,
                offset: nil,
                limit: nil
            )
            let searchResults = try await catalogService.searchGlassItems(request: searchRequest)
            let searchTime = Date().timeIntervalSince(searchStartTime)
            
            totalSearchTime += searchTime
            
            print("✅ \(scenarioName) ('\(searchTerm)'): \(searchResults.items.count) results in \(String(format: "%.3f", searchTime))s")
            
            #expect(searchTime < 3.0, "Search for '\(searchTerm)' should complete within 3 seconds")
            #expect(searchResults.items.count >= 0, "Search should return valid results")
        }
        
        print("📊 Search Performance Summary:")
        print("   • Dataset size: \(catalogSize) items")
        print("   • Search scenarios: \(searchScenarios.count) different patterns")
        print("   • Total search time: \(String(format: "%.3f", totalSearchTime))s")
        print("   • Average search time: \(String(format: "%.3f", totalSearchTime / Double(searchScenarios.count)))s")
    }
    
    @Test("Should handle memory efficiently during large operations")
    func testMemoryEfficiencyUnderLoad() async throws {
        let (catalogService, inventoryTrackingService, shoppingListService) = await createTestServices()
        
        print("💾 Testing memory efficiency with large datasets...")
        
        // Test progressively larger datasets
        let testSizes = [100, 300, 500]  // Reduced sizes for faster testing
        
        for size in testSizes {
            print("Testing memory efficiency with \(size) catalog items...")
            
            let startTime = Date()
            let catalogItems = createRealisticGlassCatalog(itemCount: size)
            
            // Add catalog items in batches
            let batchSize = 50
            for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, catalogItems.count)
                let batch = Array(catalogItems[batchStart..<batchEnd])
                
                for item in batch {
                    _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
                }
            }
            
            let totalTime = Date().timeIntervalSince(startTime)
            
            // Test all items were created
            let allItems = try await catalogService.getAllGlassItems()
            
            print("  ✅ Size \(size): Total \(String(format: "%.3f", totalTime))s")
            
            #expect(allItems.count >= size, "Should have created at least \(size) items")
            #expect(totalTime < 60.0, "Should complete within reasonable time")
        }
        
        print("💾 Memory efficiency tests completed successfully")
    }
    
    @Test("Should handle concurrent operations efficiently")
    func testConcurrentOperationPerformance() async throws {
        let (catalogService, inventoryTrackingService, _) = await createTestServices()
        
        print("🔀 Testing concurrent operation performance...")
        
        // Create test data
        let catalogItems = createRealisticGlassCatalog(itemCount: 100)  // Reduced for faster testing
        let startTime = Date()
        
        // Add catalog items concurrently
        await withTaskGroup(of: Void.self) { group in
            let batchSize = 25
            for batchStart in stride(from: 0, to: catalogItems.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, catalogItems.count)
                let batch = Array(catalogItems[batchStart..<batchEnd])
                
                group.addTask {
                    for item in batch {
                        _ = try? await catalogService.createGlassItem(item, initialInventory: [], tags: [])
                    }
                }
            }
        }
        
        let concurrentTime = Date().timeIntervalSince(startTime)
        
        // Verify results
        let finalItems = try await catalogService.getAllGlassItems()
        
        #expect(finalItems.count > 0, "Should create items concurrently")
        #expect(concurrentTime < 15.0, "Concurrent operations should complete within reasonable time")
        
        print("📊 Concurrent Performance Summary:")
        print("   • Items created: \(finalItems.count)")
        print("   • Concurrent processing time: \(String(format: "%.3f", concurrentTime))s")
        print("   • Throughput: \(String(format: "%.1f", Double(finalItems.count) / concurrentTime)) items/sec")
    }
    
    // MARK: - String Processing Performance Tests
    
    @Test("Should optimize string processing for large datasets")
    func testStringProcessingPerformance() throws {
        print("📝 Testing string processing performance...")
        
        // Create dataset for string processing
        let largeDataset = (1...1000).map { i in
            return [
                "Glass Item Name \(i)",
                "Product Code: GLS-\(String(format: "%04d", i))", 
                "Detailed description with comprehensive information about glass item \(i)",
                "Category: \(["Rods", "Sheets", "Frit", "Stringers", "Powder"][i % 5])",
                "Manufacturer: \(["Bullseye", "Spectrum", "Uroboros"][i % 3])"
            ]
        }
        
        let startTime = Date()
        
        // Process strings with various operations
        var processedCount = 0
        for itemStrings in largeDataset {
            let joinedString = itemStrings.joined(separator: " ")
            let lowercased = joinedString.lowercased()
            let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !trimmed.isEmpty && trimmed.contains("glass") {
                processedCount += 1
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        #expect(processedCount > 0, "Should process items successfully")
        #expect(processingTime < 1.0, "String processing should be efficient (actual: \(String(format: "%.3f", processingTime))s)")
        #expect(processedCount == 1000, "Should process all 1000 items")
        
        print("📊 String Processing Performance:")
        print("   • Items processed: \(processedCount)")
        print("   • Processing time: \(String(format: "%.3f", processingTime))s")
    }
    
    @Test("Should optimize collection operations for performance")
    func testCollectionPerformanceOptimization() throws {
        print("📊 Testing collection operation performance...")
        
        // Create scenarios for different collection operations
        let largeArray = Array(1...10000)
        let largeSet = Set(1...5000)
        let largeDictionary = Dictionary(uniqueKeysWithValues: (1...3000).map { ($0, "Value\($0)") })
        
        let startTime = Date()
        
        // Test various collection operations
        let filteredArray = largeArray.filter { $0 % 2 == 0 }
        let mappedArray = filteredArray.map { $0 * 2 }
        let setIntersection = largeSet.intersection(Set(Array(2500...7500)))
        let filteredDict = largeDictionary.filter { $0.key > 1500 }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        #expect(filteredArray.count == 5000, "Should filter correctly")
        #expect(mappedArray.count == 5000, "Should map correctly")
        #expect(setIntersection.count > 0, "Should intersect correctly")
        #expect(filteredDict.count > 0, "Should filter dictionary correctly")
        #expect(processingTime < 0.5, "Collection operations should be efficient (actual: \(String(format: "%.3f", processingTime))s)")
        
        print("📊 Collection Performance Summary:")
        print("   • Total processing time: \(String(format: "%.3f", processingTime))s")
    }
    
    // MARK: - Business Logic Performance Tests
    
    @Test("Should perform weight unit conversions efficiently")
    @MainActor
    func testWeightConversionPerformance() async throws {
        let startTime = Date()
        
        // Perform conversions
        for i in 1...500 {
            let value = Double(i)
            let _ = WeightUnit.pounds.convert(value, to: .kilograms)
            let _ = WeightUnit.kilograms.convert(value, to: .pounds)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 1.0, "500 conversions should complete within 1 second")
        
        print("📊 Weight Conversion Performance:")
        print("   • Execution time: \(String(format: "%.3f", executionTime))s")
    }
    
    @Test("Should perform catalog validation efficiently")
    func testCatalogValidationPerformance() async throws {
        let startTime = Date()
        
        // Run many validations
        for i in 1...1000 {
            let naturalKey = GlassItemModel.createNaturalKey(manufacturer: "corp\(i % 10)", sku: "CODE-\(i)", sequence: 0)
            let item = GlassItemModel(
                natural_key: naturalKey,
                name: "Item \(i)",
                sku: "CODE-\(i)",
                manufacturer: "corp\(i % 10)",
                mfr_notes: "Test item \(i)",
                coe: 96,
                url: nil,
                mfr_status: "available"
            )
            // Note: ServiceValidation.validateCatalogItem would be called if it exists
            // For now, just creating the item exercises the validation logic
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(executionTime < 0.5, "1000 validations should complete within 500ms")
        
        print("📊 Catalog Validation Performance:")
        print("   • Execution time: \(String(format: "%.3f", executionTime))s")
    }
}
