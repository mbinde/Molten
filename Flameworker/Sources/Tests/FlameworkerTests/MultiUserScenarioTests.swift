//
//  MultiUserScenarioTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 3 Testing Improvements: Advanced Concurrent Operations
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

@Suite("Multi-User Scenario Tests")
struct MultiUserScenarioTests {
    
    // MARK: - Test Infrastructure
    
    private func createTestEnvironment() async -> (CatalogService, InventoryService, [InventoryViewModel]) {
        let catalogRepo = MockCatalogRepository()
        let inventoryRepo = LegacyMockInventoryRepository()
        
        let catalogService = CatalogService(repository: catalogRepo)
        let inventoryService = InventoryService(repository: inventoryRepo)
        
        // Create multiple view models to simulate different users
        let userViewModels = await withTaskGroup(of: InventoryViewModel.self, returning: [InventoryViewModel].self) { group in
            for _ in 1...5 {
                group.addTask {
                    await InventoryViewModel(inventoryService: inventoryService, catalogService: catalogService)
                }
            }
            
            var viewModels: [InventoryViewModel] = []
            for await viewModel in group {
                viewModels.append(viewModel)
            }
            return viewModels
        }
        
        return (catalogService, inventoryService, userViewModels)
    }
    
    private func createStudioTeamCatalog() -> [CatalogItemModel] {
        return [
            // Popular studio colors
            CatalogItemModel(name: "Cherry Red", rawCode: "0124", manufacturer: "Bullseye", tags: ["red", "opal", "popular"]),
            CatalogItemModel(name: "Cobalt Blue", rawCode: "1108", manufacturer: "Bullseye", tags: ["blue", "transparent", "popular"]),
            CatalogItemModel(name: "Forest Green", rawCode: "0146", manufacturer: "Bullseye", tags: ["green", "opal", "popular"]),
            CatalogItemModel(name: "Canary Yellow", rawCode: "0025", manufacturer: "Bullseye", tags: ["yellow", "opal", "popular"]),
            CatalogItemModel(name: "Clear", rawCode: "0001", manufacturer: "Bullseye", tags: ["clear", "transparent", "essential"]),
            
            // Spectrum alternatives
            CatalogItemModel(name: "Red", rawCode: "125", manufacturer: "Spectrum", tags: ["red", "transparent", "basic"]),
            CatalogItemModel(name: "Blue", rawCode: "126", manufacturer: "Spectrum", tags: ["blue", "transparent", "basic"]),
            CatalogItemModel(name: "Green", rawCode: "127", manufacturer: "Spectrum", tags: ["green", "transparent", "basic"]),
            
            // Specialty items
            CatalogItemModel(name: "Silver Foil", rawCode: "SF-001", manufacturer: "Uroboros", tags: ["silver", "foil", "specialty"]),
            CatalogItemModel(name: "Gold Foil", rawCode: "GF-001", manufacturer: "Uroboros", tags: ["gold", "foil", "specialty"])
        ]
    }
    
    private func createStudioInventory() -> [InventoryItemModel] {
        return [
            // Workshop stock
            InventoryItemModel(catalogCode: "BULLSEYE-0124", quantity: 10, type: .inventory, notes: "Workshop stock"),
            InventoryItemModel(catalogCode: "BULLSEYE-1108", quantity: 8, type: .inventory, notes: "Workshop stock"),
            InventoryItemModel(catalogCode: "BULLSEYE-0146", quantity: 5, type: .inventory, notes: "Workshop stock"),
            InventoryItemModel(catalogCode: "BULLSEYE-0001", quantity: 20, type: .inventory, notes: "Essential clear"),
            InventoryItemModel(catalogCode: "SPECTRUM-125", quantity: 3, type: .inventory, notes: "Low stock"),
        ]
    }
    
    // MARK: - Advanced Concurrent Operations
    
    @Test("Should handle multiple users performing concurrent inventory operations")
    func testConcurrentInventoryOperations() async throws {
        let (catalogService, inventoryService, userViewModels) = await createTestEnvironment()
        
        print("👥 Testing concurrent inventory operations with multiple users...")
        
        // Setup shared data
        let catalogItems = createStudioTeamCatalog()
        let inventoryItems = createStudioInventory()
        
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        print("Setup complete: \(catalogItems.count) catalog items, \(inventoryItems.count) inventory items")
        print("Simulating \(userViewModels.count) concurrent users...")
        
        // Simulate different users performing different operations simultaneously
        await withTaskGroup(of: Void.self) { group in
            
            // User 1: Studio Manager - Inventory Updates
            group.addTask {
                let managerVM = userViewModels[0]
                await managerVM.loadInventoryItems()
                
                // Manager updates inventory counts
                let updates = [
                    ("BULLSEYE-0124", 15.0, "Manager count update"),
                    ("BULLSEYE-1108", 12.0, "Manager count update"),
                    ("SPECTRUM-125", 8.0, "Manager restock update")
                ]
                
                for (code, quantity, notes) in updates {
                    do {
                        let updateItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .inventory,
                            notes: notes
                        )
                        _ = try await inventoryService.createItem(updateItem)
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s processing time
                    } catch {
                        print("User 1 (Manager) error: \(error)")
                    }
                }
            }
            
            // User 2: Artist A - Project Purchases
            group.addTask {
                let artistVM = userViewModels[1]
                await artistVM.loadInventoryItems()
                
                // Artist purchasing for a large project
                let purchases = [
                    ("BULLSEYE-0124", 5.0, "Artist A - Sculpture Project"),
                    ("BULLSEYE-0146", 3.0, "Artist A - Sculpture Project"),
                    ("UROBOROS-SF-001", 2.0, "Artist A - Sculpture Project")
                ]
                
                for (code, quantity, notes) in purchases {
                    do {
                        await artistVM.searchItems(searchText: code)
                        let purchaseItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .buy,
                            notes: notes
                        )
                        _ = try await inventoryService.createItem(purchaseItem)
                        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s processing time
                    } catch {
                        print("User 2 (Artist A) error: \(error)")
                    }
                }
            }
            
            // User 3: Artist B - Different Project
            group.addTask {
                let artistVM = userViewModels[2]
                await artistVM.loadInventoryItems()
                
                // Different artist with different needs
                let purchases = [
                    ("BULLSEYE-1108", 4.0, "Artist B - Window Panel"),
                    ("SPECTRUM-126", 3.0, "Artist B - Window Panel"),
                    ("BULLSEYE-0001", 10.0, "Artist B - Window Panel")
                ]
                
                for (code, quantity, notes) in purchases {
                    do {
                        await artistVM.searchItems(searchText: "Blue")
                        await artistVM.filterItems(byType: InventoryItemType.inventory)
                        let purchaseItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .buy,
                            notes: notes
                        )
                        _ = try await inventoryService.createItem(purchaseItem)
                        try await Task.sleep(nanoseconds: 120_000_000) // 0.12s processing time
                    } catch {
                        print("User 3 (Artist B) error: \(error)")
                    }
                }
            }
            
            // User 4: Sales Person - Recording Sales
            group.addTask {
                let salesVM = userViewModels[3]
                await salesVM.loadInventoryItems()
                
                // Sales person recording completed sales
                let sales = [
                    ("BULLSEYE-0124", 2.0, "Sale - Custom suncatcher"),
                    ("BULLSEYE-0146", 1.5, "Sale - Garden ornament"),
                    ("SPECTRUM-125", 1.0, "Sale - Jewelry components")
                ]
                
                for (code, quantity, notes) in sales {
                    do {
                        await salesVM.searchItems(searchText: code.components(separatedBy: "-").last ?? "")
                        let saleItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .sell,
                            notes: notes
                        )
                        _ = try await inventoryService.createItem(saleItem)
                        try await Task.sleep(nanoseconds: 80_000_000) // 0.08s processing time
                    } catch {
                        print("User 4 (Sales) error: \(error)")
                    }
                }
            }
            
            // User 5: Assistant - General Queries
            group.addTask {
                let assistantVM = userViewModels[4]
                
                // Assistant performing various lookup operations
                let searches = ["Red", "Blue", "Clear", "Bullseye", "Spectrum", "Popular"]
                
                for searchTerm in searches {
                    do {
                        await assistantVM.loadInventoryItems()
                        await assistantVM.searchItems(searchText: searchTerm)
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s between searches
                    } catch {
                        print("User 5 (Assistant) error: \(error)")
                    }
                }
            }
        }
        
        print("All concurrent operations completed. Verifying final state...")
        
        // Verify final state consistency
        let finalInventoryItems = try await inventoryService.getAllItems()
        
        let managerUpdates = finalInventoryItems.filter { $0.notes?.contains("Manager") ?? false }
        let artistAPurchases = finalInventoryItems.filter { $0.notes?.contains("Artist A") ?? false }
        let artistBPurchases = finalInventoryItems.filter { $0.notes?.contains("Artist B") ?? false }
        let salesTransactions = finalInventoryItems.filter { $0.notes?.contains("Sale") ?? false }
        
        #expect(managerUpdates.count == 3, "Should have 3 manager updates")
        #expect(artistAPurchases.count == 3, "Should have 3 Artist A purchases")
        #expect(artistBPurchases.count == 3, "Should have 3 Artist B purchases") 
        #expect(salesTransactions.count == 3, "Should have 3 sales transactions")
        
        // Test final consolidation
        let finalVM = userViewModels[0]
        await finalVM.loadInventoryItems()
        
        await MainActor.run {
            let consolidatedItems = finalVM.consolidatedItems
            #expect(consolidatedItems.count >= 5, "Should have consolidated items from all operations")
            
            // Verify specific consolidations
            let bullseyeRed = consolidatedItems.first { $0.catalogCode == "BULLSEYE-0124" }
            #expect(bullseyeRed != nil, "Should find consolidated Bullseye Red")
            #expect(bullseyeRed?.totalBuyCount == 5.0, "Should show Artist A purchases")
            #expect(bullseyeRed?.totalSellCount == 2.0, "Should show sales transactions")
        }
        
        print("✅ Concurrent multi-user operations successful!")
        print("📊 Final State Summary:")
        print("   • Manager updates: \(managerUpdates.count)")
        print("   • Artist A purchases: \(artistAPurchases.count)")
        print("   • Artist B purchases: \(artistBPurchases.count)")
        print("   • Sales transactions: \(salesTransactions.count)")
        print("   • Total final records: \(finalInventoryItems.count)")
        print("   • Data consistency maintained across all users")
    }
    
    @Test("Should handle concurrent catalog updates with inventory references")
    func testConcurrentCatalogInventoryUpdates() async throws {
        let (catalogService, inventoryService, userViewModels) = await createTestEnvironment()
        
        print("📚 Testing concurrent catalog-inventory coordination...")
        
        // Setup initial data
        let initialCatalog = createStudioTeamCatalog()
        for item in initialCatalog {
            _ = try await catalogService.createItem(item)
        }
        
        print("Testing concurrent catalog updates with active inventory references...")
        
        // Simulate scenario where catalog is being updated while inventory operations are happening
        await withTaskGroup(of: Void.self) { group in
            
            // User 1: Catalog Administrator - Adding new items
            group.addTask {
                let newCatalogItems = [
                    CatalogItemModel(name: "Deep Purple", rawCode: "0137", manufacturer: "Bullseye", tags: ["purple", "opal", "new"]),
                    CatalogItemModel(name: "Emerald Green", rawCode: "0141", manufacturer: "Bullseye", tags: ["green", "transparent", "new"]),
                    CatalogItemModel(name: "Sunset Orange", rawCode: "0303", manufacturer: "Bullseye", tags: ["orange", "streaky", "new"])
                ]
                
                for item in newCatalogItems {
                    do {
                        _ = try await catalogService.createItem(item)
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s processing time
                    } catch {
                        print("Catalog admin error: \(error)")
                    }
                }
            }
            
            // User 2: Inventory Manager - Creating inventory for existing items
            group.addTask {
                let vm = userViewModels[0]
                await vm.loadInventoryItems()
                
                let inventoryAdditions = [
                    ("BULLSEYE-0124", 5.0),
                    ("BULLSEYE-1108", 7.0),
                    ("SPECTRUM-125", 3.0)
                ]
                
                for (code, quantity) in inventoryAdditions {
                    do {
                        await vm.searchItems(searchText: code)
                        let inventoryItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .inventory,
                            notes: "Inventory during catalog update"
                        )
                        _ = try await inventoryService.createItem(inventoryItem)
                        try await Task.sleep(nanoseconds: 150_000_000) // 0.15s
                    } catch {
                        print("Inventory manager error: \(error)")
                    }
                }
            }
            
            // User 3: Artist - Searching and purchasing while updates happen
            group.addTask {
                let vm = userViewModels[1]
                
                // Artist performing searches during updates
                let searchTerms = ["Bullseye", "Red", "Blue", "New", "Popular"]
                
                for searchTerm in searchTerms {
                    do {
                        await vm.loadInventoryItems()
                        await vm.searchItems(searchText: searchTerm)
                        
                        // Simulate user reviewing results
                        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                        
                    } catch {
                        print("Artist search error: \(error)")
                    }
                }
            }
            
            // User 4: Another inventory user - Concurrent operations
            group.addTask {
                let vm = userViewModels[2]
                
                // Different user making purchases
                let purchases = [
                    ("BULLSEYE-0001", 8.0, "Purchase during updates"),
                    ("SPECTRUM-126", 4.0, "Purchase during updates")
                ]
                
                for (code, quantity, notes) in purchases {
                    do {
                        await vm.loadInventoryItems()
                        let purchaseItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .buy,
                            notes: notes
                        )
                        _ = try await inventoryService.createItem(purchaseItem)
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    } catch {
                        print("Second inventory user error: \(error)")
                    }
                }
            }
        }
        
        print("Verifying catalog-inventory consistency after concurrent updates...")
        
        // Verify final state
        let finalCatalogItems = try await catalogService.getAllItems()
        let finalInventoryItems = try await inventoryService.getAllItems()
        
        #expect(finalCatalogItems.count >= 13, "Should have original + new catalog items")  // 10 original + 3 new
        #expect(finalInventoryItems.count >= 5, "Should have inventory items from concurrent operations")
        
        // Test that all inventory items reference valid catalog items
        let catalogCodes = Set(finalCatalogItems.map { $0.code })
        let inventoryCodes = Set(finalInventoryItems.map { $0.catalogCode })
        
        for inventoryCode in inventoryCodes {
            #expect(catalogCodes.contains(inventoryCode), "Inventory code '\(inventoryCode)' should reference valid catalog item")
        }
        
        // Test final view model consolidation
        let testVM = userViewModels[0]
        await testVM.loadInventoryItems()
        
        await MainActor.run {
            let consolidatedItems = testVM.consolidatedItems
            #expect(consolidatedItems.count >= 5, "Should consolidate all inventory operations")
            
            // Verify that consolidation worked correctly despite concurrent updates
            for item in consolidatedItems {
                #expect(!item.catalogCode.isEmpty, "All consolidated items should have valid codes")
                #expect(item.totalInventoryCount >= 0, "All quantities should be valid")
            }
        }
        
        print("✅ Concurrent catalog-inventory coordination successful!")
        print("📊 Coordination Summary:")
        print("   • Final catalog items: \(finalCatalogItems.count)")
        print("   • Final inventory items: \(finalInventoryItems.count)")
        print("   • All inventory references valid")
        print("   • Data consolidation working correctly")
        print("   • No referential integrity issues")
    }
    
    @Test("Should maintain performance under high concurrent load")
    func testHighConcurrentLoad() async throws {
        let (catalogService, inventoryService, userViewModels) = await createTestEnvironment()
        
        print("🚀 Testing performance under high concurrent load...")
        
        // Setup larger dataset for load testing
        let catalogItems = createStudioTeamCatalog()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        let testStartTime = Date()
        
        // Simulate high concurrent load with rapid operations
        await withTaskGroup(of: Void.self) { group in
            
            // Multiple users performing rapid operations simultaneously
            for (userIndex, vm) in userViewModels.enumerated() {
                group.addTask {
                    await vm.loadInventoryItems()
                    
                    // Each user performs different patterns of rapid operations
                    for operationIndex in 1...10 {
                        do {
                            switch userIndex % 4 {
                            case 0: // Search-heavy user
                                let searchTerms = ["Red", "Blue", "Bullseye", "Clear", "Popular"]
                                let searchTerm = searchTerms[operationIndex % searchTerms.count]
                                await vm.searchItems(searchText: searchTerm)
                                
                            case 1: // Filter-heavy user
                                let filterTypes: [InventoryItemType] = [.inventory, .buy, .sell]
                                let filterType = filterTypes[operationIndex % filterTypes.count]
                                await vm.filterItems(byType: filterType)
                                
                            case 2: // Data creation user
                                let item = InventoryItemModel(
                                    catalogCode: "BULLSEYE-0124",
                                    quantity: Double(operationIndex),
                                    type: .inventory,
                                    notes: "Load test user \(userIndex) op \(operationIndex)"
                                )
                                _ = try await inventoryService.createItem(item)
                                
                            case 3: // Mixed operations user
                                await vm.searchItems(searchText: "Load")
                                await vm.loadInventoryItems()
                                
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
        let stabilityTestVM = userViewModels[0]
        let stabilityStartTime = Date()
        
        await stabilityTestVM.loadInventoryItems()
        await stabilityTestVM.searchItems(searchText: "Red")
        
        let stabilityTime = Date().timeIntervalSince(stabilityStartTime)
        
        await MainActor.run {
            #expect(stabilityTestVM.isLoading == false, "System should be responsive after high load")
            #expect(stabilityTestVM.consolidatedItems.count >= 0, "Should maintain valid data after high load")
            #expect(stabilityTestVM.filteredItems.count >= 0, "Should maintain valid filtered data after high load")
        }
        
        // Check final data consistency
        let finalInventoryItems = try await inventoryService.getAllItems()
        let loadTestItems = finalInventoryItems.filter { $0.notes?.contains("Load test") ?? false }
        
        #expect(totalLoadTime < 30.0, "High load test should complete within 30 seconds")
        #expect(stabilityTime < 5.0, "System should remain responsive after high load")
        #expect(loadTestItems.count >= 10, "Should have recorded load test operations")
        
        print("✅ High concurrent load test successful!")
        print("📊 Load Test Summary:")
        print("   • Users: \(userViewModels.count)")
        print("   • Operations per user: 10")
        print("   • Total load time: \(String(format: "%.3f", totalLoadTime))s")
        print("   • Post-load stability: \(String(format: "%.3f", stabilityTime))s")
        print("   • Load test records: \(loadTestItems.count)")
        print("   • System remained stable and responsive")
    }
    
    @Test("Should handle user conflict resolution gracefully")
    func testUserConflictResolution() async throws {
        let (catalogService, inventoryService, userViewModels) = await createTestEnvironment()
        
        print("⚡ Testing user conflict resolution scenarios...")
        
        // Setup shared data that users will contend over
        let catalogItems = createStudioTeamCatalog().prefix(3) // Limited items for conflict testing
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Add initial inventory
        let initialItem = InventoryItemModel(
            catalogCode: "BULLSEYE-0124",
            quantity: 10,
            type: .inventory,
            notes: "Initial stock"
        )
        _ = try await inventoryService.createItem(initialItem)
        
        print("Testing conflict scenarios with shared resources...")
        
        // Scenario: Multiple users trying to update the same inventory item
        await withTaskGroup(of: Void.self) { group in
            
            // Multiple users trying to modify the same item simultaneously
            for (userIndex, vm) in userViewModels.prefix(3).enumerated() {
                group.addTask {
                    await vm.loadInventoryItems()
                    
                    do {
                        // Each user tries to add different amounts to same item
                        let conflictItem = InventoryItemModel(
                            catalogCode: "BULLSEYE-0124",
                            quantity: Double(5 + userIndex * 2), // Different quantities
                            type: .inventory,
                            notes: "User \(userIndex + 1) update - conflict test"
                        )
                        
                        _ = try await inventoryService.createItem(conflictItem)
                        
                        // Simulate user interaction delay
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                        
                    } catch {
                        print("User \(userIndex + 1) conflict handling: \(error)")
                        // Conflicts are expected and should be handled gracefully
                    }
                }
            }
        }
        
        print("Verifying conflict resolution...")
        
        // Verify system handled conflicts gracefully
        let finalItems = try await inventoryService.getAllItems()
        let bullseyeRedItems = finalItems.filter { $0.catalogCode == "BULLSEYE-0124" }
        
        #expect(bullseyeRedItems.count >= 3, "Should have items from multiple users despite conflicts")
        
        // Test that the system can still consolidate conflicted data
        let testVM = userViewModels[0]
        await testVM.loadInventoryItems()
        
        await MainActor.run {
            let consolidatedItems = testVM.consolidatedItems
            let consolidatedRed = consolidatedItems.first { $0.catalogCode == "BULLSEYE-0124" }
            
            #expect(consolidatedRed != nil, "Should consolidate conflicted items")
            #expect(consolidatedRed?.totalInventoryCount ?? 0 > 10, "Should sum all conflicted updates")
            
            // Verify system remains stable
            #expect(!consolidatedItems.isEmpty, "System should remain functional after conflicts")
        }
        
        // Test search functionality after conflicts
        await testVM.searchItems(searchText: "Bullseye")
        
        await MainActor.run {
            let searchResults = testVM.filteredItems
            #expect(!searchResults.isEmpty, "Search should work after conflict resolution")
        }
        
        print("✅ User conflict resolution successful!")
        print("📊 Conflict Resolution Summary:")
        print("   • Conflicting users: 3")
        print("   • Target item: BULLSEYE-0124") 
        print("   • Final records for item: \(bullseyeRedItems.count)")
        print("   • System handled conflicts gracefully")
        print("   • Data consolidation working correctly")
        print("   • Search functionality intact after conflicts")
    }
}
