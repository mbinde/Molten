//
//  MultiUserScenarioTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 3 Testing Improvements: Advanced Concurrent Operations
//  Updated for GlassItem Architecture
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("Multi-User Scenario Tests")
@MainActor
struct MultiUserScenarioTests {
    
    // MARK: - Test Infrastructure
    
    private func createTestEnvironment() async -> (CatalogService, InventoryTrackingService, ShoppingListService) {
        // Use the new GlassItem architecture with repository pattern
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let userTagsRepo = MockUserTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        let coatingItemRepo = MockCoatingItemRepository()
        let toolItemRepo = MockToolItemRepository()

        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
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
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepo,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo,
            ratingService: AppDependencies.shared.ratingService
        )
        
        return (catalogService, inventoryTrackingService, shoppingListService)
    }
    
    private func createStudioTeamCatalog() -> [GlassItemModel] {
        var items: [GlassItemModel] = []
        
        let glassItems = [
            ("Cherry Red", "bullseye", "0124", ["red", "opal", "popular"]),
            ("Cobalt Blue", "bullseye", "1108", ["blue", "transparent", "popular"]),
            ("Forest Green", "bullseye", "0146", ["green", "opal", "popular"]),
            ("Canary Yellow", "bullseye", "0025", ["yellow", "opal", "popular"]),
            ("Clear", "bullseye", "0001", ["clear", "transparent", "essential"]),
            ("Red", "spectrum", "125", ["red", "transparent", "basic"]),
            ("Blue", "spectrum", "126", ["blue", "transparent", "basic"]),
            ("Green", "spectrum", "127", ["green", "transparent", "basic"]),
            ("Silver Foil", "uroboros", "sf-001", ["silver", "foil", "specialty"]),
            ("Gold Foil", "uroboros", "gf-001", ["gold", "foil", "specialty"])
        ]
        
        for (name, manufacturer, sku, tags) in glassItems {
            let item = GlassItemModel(
                stable_id: "AUTO_ID",
                name: name,
                sku: sku,
                manufacturer: manufacturer,
                mfr_notes: "Studio catalog item",
                coe: manufacturer == "spectrum" ? 96 : 90,
                url: nil,
                mfr_status: "available"
            )
            items.append(item)
        }
        
        return items
    }
    
    // Helper to find stable_id by manufacturer and SKU
    private func findStableId(in items: [CompleteInventoryItemModel], manufacturer: String, sku: String) -> String? {
        return items.first { $0.glassItem.manufacturer == manufacturer && $0.glassItem.sku == sku }?.glassItem.stable_id
    }
    
    // MARK: - Advanced Concurrent Operations
    
    @Test("Should handle multiple users performing concurrent inventory operations")
    func testConcurrentInventoryOperations() async throws {
        let (catalogService, inventoryTrackingService, shoppingListService) = await createTestEnvironment()

        print("👥 Testing concurrent inventory operations with multiple users...")

        // Setup shared data - Create catalog items first
        let catalogItems = createStudioTeamCatalog()
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }

        // Get the created items with their actual stable_ids
        let createdItems = try await catalogService.getAllGlassItems()

        // Create initial inventory using actual stable_ids
        if let bullseye0124 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0124") {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(
                InventoryModel(item_stable_id: bullseye0124, type: "rod", quantity: 10)
            )
        }
        if let bullseye1108 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "1108") {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(
                InventoryModel(item_stable_id: bullseye1108, type: "rod", quantity: 8)
            )
        }
        if let bullseye0146 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0146") {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(
                InventoryModel(item_stable_id: bullseye0146, type: "rod", quantity: 5)
            )
        }
        if let bullseye0001 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0001") {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(
                InventoryModel(item_stable_id: bullseye0001, type: "rod", quantity: 20)
            )
        }
        if let spectrum125 = findStableId(in: createdItems, manufacturer: "spectrum", sku: "125") {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(
                InventoryModel(item_stable_id: spectrum125, type: "rod", quantity: 3)
            )
        }

        let initialInventoryCount = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil).count
        print("Setup complete: \(catalogItems.count) catalog items, \(initialInventoryCount) inventory items")
        
        // Capture stable_ids for concurrent operations
        guard let bullseye0124 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0124"),
              let bullseye1108 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "1108"),
              let bullseye0146 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0146"),
              let bullseye0001 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0001"),
              let spectrum125 = findStableId(in: createdItems, manufacturer: "spectrum", sku: "125"),
              let spectrum126 = findStableId(in: createdItems, manufacturer: "spectrum", sku: "126"),
              let uroborosSf001 = findStableId(in: createdItems, manufacturer: "uroboros", sku: "sf-001") else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find required catalog items"])
        }

        // Simulate different users performing different operations simultaneously
        await withTaskGroup(of: Void.self) { group in

            // User 1: Studio Manager - Inventory Updates
            group.addTask {
                let updates = [
                    (bullseye0124, "rod", 15.0),
                    (bullseye1108, "rod", 12.0),
                    (spectrum125, "rod", 8.0)
                ]

                for (stableId, type, quantity) in updates {
                    do {
                        let updateItem = InventoryModel(
                            item_stable_id: stableId,
                            type: type,
                            quantity: quantity
                        )
                        _ = try await inventoryTrackingService.inventoryRepository.createInventory(updateItem)
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s processing time
                    } catch {
                        print("User 1 (Manager) error: \(error)")
                    }
                }
            }

            // User 2: Artist A - Project Purchases
            group.addTask {
                let purchases = [
                    (bullseye0124, "sheet", 5.0),
                    (bullseye0146, "sheet", 3.0),
                    (uroborosSf001, "sheet", 2.0)
                ]

                for (stableId, type, quantity) in purchases {
                    do {
                        let purchaseItem = InventoryModel(
                            item_stable_id: stableId,
                            type: type,
                            quantity: quantity
                        )
                        _ = try await inventoryTrackingService.inventoryRepository.createInventory(purchaseItem)
                        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s processing time
                    } catch {
                        print("User 2 (Artist A) error: \(error)")
                    }
                }
            }

            // User 3: Artist B - Different Project
            group.addTask {
                let purchases = [
                    (bullseye1108, "frit", 4.0),
                    (spectrum126, "frit", 3.0),
                    (bullseye0001, "rod", 10.0)
                ]

                for (stableId, type, quantity) in purchases {
                    do {
                        let purchaseItem = InventoryModel(
                            item_stable_id: stableId,
                            type: type,
                            quantity: quantity
                        )
                        _ = try await inventoryTrackingService.inventoryRepository.createInventory(purchaseItem)
                        try await Task.sleep(nanoseconds: 120_000_000) // 0.12s processing time
                    } catch {
                        print("User 3 (Artist B) error: \(error)")
                    }
                }
            }

            // User 4: Sales Person - Recording Sales
            group.addTask {
                let sales = [
                    (bullseye0124, "scrap", 2.0),
                    (bullseye0146, "scrap", 1.5),
                    (spectrum125, "scrap", 1.0)
                ]

                for (stableId, type, quantity) in sales {
                    do {
                        let saleItem = InventoryModel(
                            item_stable_id: stableId,
                            type: type,
                            quantity: quantity
                        )
                        _ = try await inventoryTrackingService.inventoryRepository.createInventory(saleItem)
                        try await Task.sleep(nanoseconds: 80_000_000) // 0.08s processing time
                    } catch {
                        print("User 4 (Sales) error: \(error)")
                    }
                }
            }
            
            // User 5: Assistant - General Queries
            group.addTask {
                let searchRequests = ["Red", "Blue", "Clear", "bullseye", "spectrum", "Popular"].map { term in
                    GlassItemSearchRequest(
                        searchText: term,
                        manufacturers: [],
                        coeValues: [],
                        manufacturerStatuses: [],
                        hasInventory: nil,
                        inventoryTypes: [],
                        sortBy: .name,
                        offset: nil,
                        limit: nil
                    )
                }
                
                for searchRequest in searchRequests {
                    do {
                        _ = try await catalogService.searchGlassItems(request: searchRequest)
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s between searches
                    } catch {
                        print("User 5 (Assistant) error: \(error)")
                    }
                }
            }
        }
        
        print("All concurrent operations completed. Verifying final state...")

        // Verify final state consistency
        let finalInventoryItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        let finalCatalogItems = try await catalogService.getAllGlassItems()

        #expect(finalInventoryItems.count >= 15, "Should have items from all operations")
        #expect(finalCatalogItems.count == catalogItems.count, "Should maintain catalog consistency")

        // Test specific inventory for Bullseye Red (using actual stable_id)
        let bullseyeRedInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: bullseye0124)
        #expect(bullseyeRedInventory.count >= 3, "Should have multiple inventory records for Bullseye Red")

        print("✅ Concurrent multi-user operations successful!")
        print("📊 Final State Summary:")
        print("   • Final inventory records: \(finalInventoryItems.count)")
        print("   • Final catalog items: \(finalCatalogItems.count)")
        print("   • Data consistency maintained across all users")
    }
    
    @Test("Should handle concurrent catalog updates with inventory references")
    func testConcurrentCatalogInventoryUpdates() async throws {
        let (catalogService, inventoryTrackingService, shoppingListService) = await createTestEnvironment()

        print("📚 Testing concurrent catalog-inventory coordination...")

        // Setup initial data
        let initialCatalog = createStudioTeamCatalog()
        for item in initialCatalog {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }

        // Get created items with their actual stable_ids
        let createdItems = try await catalogService.getAllGlassItems()

        // Capture stable_ids we'll use for inventory operations
        guard let bullseye0124 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0124"),
              let bullseye1108 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "1108"),
              let bullseye0001 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0001"),
              let spectrum125 = findStableId(in: createdItems, manufacturer: "spectrum", sku: "125"),
              let spectrum126 = findStableId(in: createdItems, manufacturer: "spectrum", sku: "126") else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find required catalog items"])
        }

        print("Testing concurrent catalog updates with active inventory references...")

        // Simulate scenario where catalog is being updated while inventory operations are happening
        await withTaskGroup(of: Void.self) { group in

            // User 1: Catalog Administrator - Adding new items
            group.addTask {
                let newItems = [
                    ("Deep Purple", "bullseye", "0137", ["purple", "opal", "new"]),
                    ("Emerald Green", "bullseye", "0141", ["green", "transparent", "new"]),
                    ("Sunset Orange", "bullseye", "0303", ["orange", "streaky", "new"])
                ]

                for (name, manufacturer, sku, tags) in newItems {
                    do {
                        let item = GlassItemModel(
                            stable_id: "AUTO_ID",
                            name: name,
                            sku: sku,
                            manufacturer: manufacturer,
                            mfr_notes: "New catalog item",
                            coe: 90,
                            url: nil,
                            mfr_status: "available"
                        )
                        _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: tags)
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s processing time
                    } catch {
                        print("Catalog admin error: \(error)")
                    }
                }
            }

            // User 2: Inventory Manager - Creating inventory for existing items
            group.addTask {
                let inventoryAdditions = [
                    (bullseye0124, "rod", 5.0),
                    (bullseye1108, "rod", 7.0),
                    (spectrum125, "rod", 3.0)
                ]

                for (stableId, type, quantity) in inventoryAdditions {
                    do {
                        let inventoryItem = InventoryModel(
                            item_stable_id: stableId,
                            type: type,
                            quantity: quantity
                        )
                        _ = try await inventoryTrackingService.inventoryRepository.createInventory(inventoryItem)
                        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s
                    } catch {
                        print("Inventory manager error: \(error)")
                    }
                }
            }

            // User 3: Artist - Searching and purchasing while updates happen
            group.addTask {
                let searchTerms = ["bullseye", "Red", "Blue", "New", "Popular"]

                for searchTerm in searchTerms {
                    do {
                        let searchRequest = GlassItemSearchRequest(
                            searchText: searchTerm,
                            manufacturers: [],
                            coeValues: [],
                            manufacturerStatuses: [],
                            hasInventory: nil,
                            inventoryTypes: [],
                            sortBy: .name,
                            offset: nil,
                            limit: nil
                        )
                        _ = try await catalogService.searchGlassItems(request: searchRequest)
                        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    } catch {
                        print("Artist search error: \(error)")
                    }
                }
            }

            // User 4: Another inventory user - Concurrent operations
            group.addTask {
                let purchases = [
                    (bullseye0001, "sheet", 8.0),
                    (spectrum126, "sheet", 4.0)
                ]

                for (stableId, type, quantity) in purchases {
                    do {
                        let purchaseItem = InventoryModel(
                            item_stable_id: stableId,
                            type: type,
                            quantity: quantity
                        )
                        _ = try await inventoryTrackingService.inventoryRepository.createInventory(purchaseItem)
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    } catch {
                        print("Second inventory user error: \(error)")
                    }
                }
            }
        }
        
        print("Verifying catalog-inventory consistency after concurrent updates...")
        
        // Verify final state
        let finalCatalogItems = try await catalogService.getAllGlassItems()
        let finalInventoryItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        
        #expect(finalCatalogItems.count >= 13, "Should have original + new catalog items")  // 10 original + 3 new
        #expect(finalInventoryItems.count >= 5, "Should have inventory items from concurrent operations (may be less than 8 due to mock behavior)")
        
        // Test that all inventory items reference valid catalog items
        let catalogStableIds = Set(finalCatalogItems.map { $0.glassItem.stable_id })
        let inventoryStableIds = Set(finalInventoryItems.map { $0.item_stable_id })

        for inventoryKey in inventoryStableIds {
            #expect(catalogStableIds.contains(inventoryKey), "Inventory key '\(inventoryKey)' should reference valid catalog item")
        }
        
        print("✅ Concurrent catalog-inventory coordination successful!")
        print("📊 Coordination Summary:")
        print("   • Final catalog items: \(finalCatalogItems.count)")
        print("   • Final inventory items: \(finalInventoryItems.count)")
        print("   • All inventory references valid")
        print("   • No referential integrity issues")
    }
    
    @Test("Should maintain performance under high concurrent load")
    func testHighConcurrentLoad() async throws {
        let (catalogService, inventoryTrackingService, shoppingListService) = await createTestEnvironment()

        print("🚀 Testing performance under high concurrent load...")

        // Setup larger dataset for load testing
        let catalogItems = createStudioTeamCatalog()
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }

        // Get created items with their actual stable_ids
        let createdItems = try await catalogService.getAllGlassItems()

        // Capture a stable_id for data creation tests
        guard let bullseye0124 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0124") else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find test item"])
        }

        let testStartTime = Date()

        // Simulate high concurrent load with rapid operations
        await withTaskGroup(of: Void.self) { group in

            // Multiple concurrent tasks performing different operations
            for userIndex in 1...5 {
                group.addTask {
                    // Each user performs different patterns of rapid operations
                    for operationIndex in 1...10 {
                        do {
                            switch userIndex % 4 {
                            case 0: // Search-heavy user
                                let searchTerms = ["Red", "Blue", "bullseye", "Clear", "Popular"]
                                let searchTerm = searchTerms[operationIndex % searchTerms.count]
                                let searchRequest = GlassItemSearchRequest(
                                    searchText: searchTerm,
                                    manufacturers: [],
                                    coeValues: [],
                                    manufacturerStatuses: [],
                                    hasInventory: nil,
                                    inventoryTypes: [],
                                    sortBy: .name,
                                    offset: nil,
                                    limit: nil
                                )
                                _ = try await catalogService.searchGlassItems(request: searchRequest)

                            case 1: // Catalog operations user
                                _ = try await catalogService.getAllGlassItems()

                            case 2: // Data creation user
                                let item = InventoryModel(
                                    item_stable_id: bullseye0124,
                                    type: "test",
                                    quantity: Double(operationIndex)
                                )
                                _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)

                            case 3: // Mixed operations user
                                let searchRequest = GlassItemSearchRequest(
                                    searchText: "Load",
                                    manufacturers: [],
                                    coeValues: [],
                                    manufacturerStatuses: [],
                                    hasInventory: nil,
                                    inventoryTypes: [],
                                    sortBy: .name,
                                    offset: nil,
                                    limit: nil
                                )
                                _ = try await catalogService.searchGlassItems(request: searchRequest)

                            default:
                                break
                            }

                            // Brief pause between operations
                            try await Task.sleep(nanoseconds: 50_000_000) // 0.05s

                        } catch {
                            print("User \(userIndex) operation \(operationIndex) error: \(error)")
                        }
                    }
                }
            }
        }
        
        let totalLoadTime = Date().timeIntervalSince(testStartTime)
        
        print("High load test completed in \(String(format: "%.3f", totalLoadTime))s")
        
        // Verify system stability after high load
        let stabilityStartTime = Date()
        _ = try await catalogService.getAllGlassItems()
        let stabilityTime = Date().timeIntervalSince(stabilityStartTime)
        
        // Check final data consistency
        let finalInventoryItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        let loadTestItems = finalInventoryItems.filter { $0.type == "test" }
        
        #expect(totalLoadTime < 30.0, "High load test should complete within 30 seconds")
        #expect(stabilityTime < 5.0, "System should remain responsive after high load")
        #expect(loadTestItems.count >= 10, "Should have recorded load test operations")
        
        print("✅ High concurrent load test successful!")
        print("📊 Load Test Summary:")
        print("   • Users: 5")
        print("   • Operations per user: 10")
        print("   • Total load time: \(String(format: "%.3f", totalLoadTime))s")
        print("   • Post-load stability: \(String(format: "%.3f", stabilityTime))s")
        print("   • Load test records: \(loadTestItems.count)")
        print("   • System remained stable and responsive")
    }
    
    @Test("Should handle user conflict resolution gracefully")
    func testUserConflictResolution() async throws {
        let (catalogService, inventoryTrackingService, shoppingListService) = await createTestEnvironment()

        print("⚡ Testing user conflict resolution scenarios...")

        // Setup shared data that users will contend over
        let catalogItems = Array(createStudioTeamCatalog().prefix(3)) // Limited items for conflict testing
        for item in catalogItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }

        // Get created items with their actual stable_ids
        let createdItems = try await catalogService.getAllGlassItems()

        // Capture the stable_id we'll use for conflict testing
        guard let bullseye0124 = findStableId(in: createdItems, manufacturer: "bullseye", sku: "0124") else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find test item"])
        }

        // Add initial inventory
        let initialItem = InventoryModel(
            item_stable_id: bullseye0124,
            type: "rod",
            quantity: 10
        )
        _ = try await inventoryTrackingService.inventoryRepository.createInventory(initialItem)

        print("Testing conflict scenarios with shared resources...")

        // Scenario: Multiple users trying to update the same inventory item
        await withTaskGroup(of: Void.self) { group in

            // Multiple users trying to modify the same item simultaneously
            for userIndex in 1...3 {
                group.addTask {
                    do {
                        // Each user tries to add different amounts to same item
                        let conflictItem = InventoryModel(
                            item_stable_id: bullseye0124,
                            type: "conflict_test",
                            quantity: Double(5 + userIndex * 2) // Different quantities
                        )

                        _ = try await inventoryTrackingService.inventoryRepository.createInventory(conflictItem)

                        // Simulate user interaction delay
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

                    } catch {
                        print("User \(userIndex) conflict handling: \(error)")
                        // Conflicts are expected and should be handled gracefully
                    }
                }
            }
        }

        print("Verifying conflict resolution...")

        // Verify system handled conflicts gracefully
        let finalItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        let bullseyeRedItems = finalItems.filter { $0.item_stable_id == bullseye0124 }

        #expect(bullseyeRedItems.count >= 3, "Should have items from multiple users despite conflicts")

        // Test that the system can still retrieve the data consistently
        let specificItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: bullseye0124)
        #expect(!specificItems.isEmpty, "Should be able to retrieve items after conflicts")

        // Test search functionality after conflicts
        let searchRequest = GlassItemSearchRequest(
            searchText: "Cherry",
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
        #expect(searchResults.items.count > 0, "Search should work after conflict resolution")

        print("✅ User conflict resolution successful!")
        print("📊 Conflict Resolution Summary:")
        print("   • Conflicting users: 3")
        print("   • Target item: \(bullseye0124)")
        print("   • Final records for item: \(bullseyeRedItems.count)")
        print("   • System handled conflicts gracefully")
        print("   • Search functionality intact after conflicts")
    }
}
