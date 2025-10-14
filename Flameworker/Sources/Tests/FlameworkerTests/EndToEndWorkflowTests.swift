//
//  EndToEndWorkflowTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 2 Testing Improvements: Complete User Journey Testing
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

@Suite("End-to-End User Workflows")
struct EndToEndWorkflowTests {
    
    // MARK: - Test Infrastructure
    
    private func createCompleteTestEnvironment() async -> (CatalogService, InventoryService, InventoryViewModel) {
        let catalogRepo = MockCatalogRepository()
        let inventoryRepo = MockInventoryRepository()
        
        let catalogService = CatalogService(repository: catalogRepo)
        let inventoryService = InventoryService(repository: inventoryRepo)
        
        let inventoryViewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        return (catalogService, inventoryService, inventoryViewModel)
    }
    
    private func createGlassStudioCatalogData() -> [CatalogItemModel] {
        return [
            // Bullseye Glass Collection
            CatalogItemModel(name: "Red Opal", rawCode: "0124", manufacturer: "Bullseye", tags: ["red", "opal", "coe90"]),
            CatalogItemModel(name: "Blue Transparent", rawCode: "1108", manufacturer: "Bullseye", tags: ["blue", "transparent", "coe90"]),
            CatalogItemModel(name: "Clear", rawCode: "0001", manufacturer: "Bullseye", tags: ["clear", "transparent", "coe90"]),
            
            // Spectrum Glass Collection  
            CatalogItemModel(name: "Medium Amber", rawCode: "125", manufacturer: "Spectrum", tags: ["amber", "transparent", "coe96"]),
            CatalogItemModel(name: "Cranberry Pink", rawCode: "347", manufacturer: "Spectrum", tags: ["pink", "transparent", "coe96"]),
            
            // Uroboros Collection
            CatalogItemModel(name: "Red with Silver", rawCode: "94-16", manufacturer: "Uroboros", tags: ["red", "silver", "dichroic", "coe90"]),
            CatalogItemModel(name: "Green Granite", rawCode: "92-14", manufacturer: "Uroboros", tags: ["green", "granite", "textured", "coe90"])
        ]
    }
    
    private func createInitialInventoryData() -> [InventoryItemModel] {
        return [
            // Starting inventory - what a glass studio might have
            InventoryItemModel(catalogCode: "BULLSEYE-0124", quantity: 5.0, type: .inventory, notes: "Workshop stock"),
            InventoryItemModel(catalogCode: "BULLSEYE-1108", quantity: 3.0, type: .inventory, notes: "Low stock"),
            InventoryItemModel(catalogCode: "SPECTRUM-125", quantity: 8.0, type: .inventory, notes: "Popular color"),
            InventoryItemModel(catalogCode: "UROBOROS-94-16", quantity: 1.0, type: .inventory, notes: "Special order item")
        ]
    }
    
    // MARK: - Complete Catalog Management Workflow
    
    @Test("Should support complete catalog management workflow")
    func testCatalogManagementWorkflow() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createCompleteTestEnvironment()
        
        // STEP 1: Import catalog data (simulating loading from JSON/CSV/API)
        print("Step 1: Importing catalog data...")
        let catalogData = createGlassStudioCatalogData()
        
        var importedCatalogItems: [CatalogItemModel] = []
        for item in catalogData {
            let savedItem = try await catalogService.createItem(item)
            importedCatalogItems.append(savedItem)
        }
        
        #expect(importedCatalogItems.count == 7, "Should import 7 catalog items")
        print("✅ Imported \(importedCatalogItems.count) catalog items")
        
        // STEP 2: Search for specific items (user looking for red glass)
        print("Step 2: Searching for red glass...")
        let redItems = try await catalogService.searchItems(searchText: "red")
        
        #expect(redItems.count >= 2, "Should find at least 2 red items")
        let redCodes = redItems.map { $0.code }
        #expect(redCodes.contains("BULLSEYE-0124"), "Should find Bullseye Red Opal")
        #expect(redCodes.contains("UROBOROS-94-16"), "Should find Uroboros Red with Silver")
        print("✅ Found \(redItems.count) red glass items")
        
        // STEP 3: Filter by manufacturer (user wants Bullseye glass specifically)
        print("Step 3: Filtering by Bullseye manufacturer...")
        let allItems = try await catalogService.getAllItems()
        let bullseyeItems = allItems.filter { $0.manufacturer == "Bullseye" }
        
        #expect(bullseyeItems.count == 3, "Should find 3 Bullseye items")
        print("✅ Filtered to \(bullseyeItems.count) Bullseye items")
        
        // STEP 4: Add selected items to inventory (user decides to stock up)
        print("Step 4: Adding selected items to inventory...")
        let itemsToStock = [
            ("BULLSEYE-0124", 10.0), // Red Opal - popular color
            ("BULLSEYE-0001", 5.0),  // Clear - essential basic
        ]
        
        for (catalogCode, quantity) in itemsToStock {
            let inventoryItem = InventoryItemModel(
                catalogCode: catalogCode,
                quantity: quantity,
                type: .inventory,
                notes: "Initial stocking from catalog workflow"
            )
            _ = try await inventoryService.createItem(inventoryItem)
        }
        
        // STEP 5: Create purchase records (user records their purchase)
        print("Step 5: Recording purchase...")
        for (catalogCode, quantity) in itemsToStock {
            let purchaseItem = InventoryItemModel(
                catalogCode: catalogCode,
                quantity: quantity,
                type: .buy,
                notes: "Purchase order #PO-2024-001"
            )
            _ = try await inventoryService.createItem(purchaseItem)
        }
        
        // STEP 6: Update inventory view to see consolidated results
        print("Step 6: Updating inventory view...")
        await inventoryViewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(inventoryViewModel.consolidatedItems.count >= 2, "Should show consolidated inventory items")
            
            let bullseyeRed = inventoryViewModel.consolidatedItems.first { $0.catalogCode == "BULLSEYE-0124" }
            #expect(bullseyeRed != nil, "Should find Bullseye Red in inventory")
            #expect(bullseyeRed?.totalInventoryCount == 10.0, "Should show 10 units in inventory")
            #expect(bullseyeRed?.totalBuyCount == 10.0, "Should show 10 units purchased")
        }
        
        print("✅ Complete catalog management workflow successful!")
        print("   - Imported 7 catalog items")
        print("   - Searched and filtered successfully") 
        print("   - Added 2 items to inventory")
        print("   - Recorded purchases")
        print("   - Updated inventory view with consolidated data")
    }
    
    // MARK: - Complete Inventory Management Workflow
    
    @Test("Should support complete inventory management workflow")
    func testInventoryManagementWorkflow() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createCompleteTestEnvironment()
        
        // SETUP: Create catalog and initial inventory
        print("Setup: Creating catalog and initial inventory...")
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createItem(item)
        }
        
        let initialInventory = createInitialInventoryData()
        for item in initialInventory {
            _ = try await inventoryService.createItem(item)
        }
        
        // STEP 1: View current inventory status
        print("Step 1: Viewing current inventory...")
        await inventoryViewModel.loadInventoryItems()
        
        await MainActor.run {
            let initialCount = inventoryViewModel.consolidatedItems.count
            #expect(initialCount == 4, "Should show 4 different catalog items in inventory")
            print("✅ Initial inventory shows \(initialCount) different items")
        }
        
        // STEP 2: Search for items that might be low stock (manual check)
        print("Step 2: Checking for low stock items...")
        
        await MainActor.run {
            let allItems = inventoryViewModel.consolidatedItems
            let lowStockItems = allItems.filter { $0.totalInventoryCount <= 3.0 }
            #expect(lowStockItems.count >= 1, "Should find low stock items")
            
            let foundUroboros = lowStockItems.contains { $0.catalogCode == "UROBOROS-94-16" }
            #expect(foundUroboros, "Should find Uroboros item with 1 unit as low stock")
            print("✅ Found \(lowStockItems.count) low stock items")
        }
        
        // STEP 3: Create purchase order for low stock items
        print("Step 3: Creating purchase order for restocking...")
        let restockItems = [
            ("UROBOROS-94-16", 5.0),  // Restock the low quantity item
            ("BULLSEYE-1108", 7.0),   // Also low at 3 units, bring up to 10
        ]
        
        for (catalogCode, quantity) in restockItems {
            let purchaseItem = InventoryItemModel(
                catalogCode: catalogCode,
                quantity: quantity,
                type: .buy,
                notes: "Restock order - low inventory alert"
            )
            _ = try await inventoryService.createItem(purchaseItem)
        }
        
        // STEP 4: Receive shipment and update inventory
        print("Step 4: Receiving shipment and updating inventory...")
        for (catalogCode, quantity) in restockItems {
            let receivedItem = InventoryItemModel(
                catalogCode: catalogCode,
                quantity: quantity,
                type: .inventory,
                notes: "Received shipment - restock"
            )
            _ = try await inventoryService.createItem(receivedItem)
        }
        
        // STEP 5: Verify updated quantities
        print("Step 5: Verifying updated inventory...")
        await inventoryViewModel.loadInventoryItems()
        
        await MainActor.run {
            let uroborosItem = inventoryViewModel.consolidatedItems.first { $0.catalogCode == "UROBOROS-94-16" }
            #expect(uroborosItem != nil, "Should find Uroboros item after restock")
            #expect(uroborosItem?.totalInventoryCount == 6.0, "Should show 6 units (1 original + 5 restocked)")
            #expect(uroborosItem?.totalBuyCount == 5.0, "Should show 5 units purchased")
            
            let bullseyeBlue = inventoryViewModel.consolidatedItems.first { $0.catalogCode == "BULLSEYE-1108" }
            #expect(bullseyeBlue?.totalInventoryCount == 10.0, "Should show 10 units (3 original + 7 restocked)")
        }
        
        print("✅ Complete inventory management workflow successful!")
        print("   - Viewed initial inventory (4 items)")
        print("   - Identified low stock items")
        print("   - Created purchase orders")
        print("   - Updated inventory with received shipments")
        print("   - Verified final quantities")
    }
    
    // MARK: - Complete Purchase Workflow
    
    @Test("Should support complete purchase workflow")
    func testCompletePurchaseWorkflow() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createCompleteTestEnvironment()
        
        // SETUP: Create catalog
        print("Setup: Creating catalog...")
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createItem(item)
        }
        
        // STEP 1: Search catalog for project needs (user planning a red and blue piece)
        print("Step 1: Searching catalog for project materials...")
        let projectColors = ["red", "blue"]
        var selectedItems: [(code: String, name: String, quantity: Double)] = []
        
        for color in projectColors {
            let colorItems = try await catalogService.searchItems(searchText: color)
            if let firstItem = colorItems.first {
                selectedItems.append((
                    code: firstItem.code,
                    name: firstItem.name,
                    quantity: 2.0 // 2 sheets for project
                ))
            }
        }
        
        #expect(selectedItems.count == 2, "Should select 2 items for project")
        print("✅ Selected \(selectedItems.count) items for project")
        
        // STEP 2: Create purchase record
        print("Step 2: Creating purchase record...")
        var purchaseItems: [InventoryItemModel] = []
        
        for item in selectedItems {
            let purchaseItem = InventoryItemModel(
                catalogCode: item.code,
                quantity: item.quantity,
                type: .buy,
                notes: "Project purchase: Red & Blue Art Piece - PO#2024-015"
            )
            let savedPurchase = try await inventoryService.createItem(purchaseItem)
            purchaseItems.append(savedPurchase)
        }
        
        #expect(purchaseItems.count == 2, "Should create 2 purchase records")
        
        // STEP 3: Confirm purchase details
        print("Step 3: Confirming purchase details...")
        let allPurchases = try await inventoryService.getAllItems()
        let projectPurchases = allPurchases.filter { 
            $0.type == .buy && ($0.notes?.contains("PO#2024-015") ?? false)
        }
        
        #expect(projectPurchases.count == 2, "Should find 2 project purchases")
        
        let totalCost = projectPurchases.reduce(0.0) { $0 + $1.quantity } // Quantity as proxy for cost
        #expect(totalCost == 4.0, "Should calculate total quantity of 4 sheets")
        
        // STEP 4: Record purchase in system (update inventory)
        print("Step 4: Recording received materials in inventory...")
        for purchaseItem in projectPurchases {
            let inventoryItem = InventoryItemModel(
                catalogCode: purchaseItem.catalogCode,
                quantity: purchaseItem.quantity,
                type: .inventory,
                notes: "Received: \(purchaseItem.notes ?? "")"
            )
            _ = try await inventoryService.createItem(inventoryItem)
        }
        
        // STEP 5: Update inventory view and verify
        print("Step 5: Updating inventory view...")
        await inventoryViewModel.loadInventoryItems()
        
        await MainActor.run {
            let inventoryItems = inventoryViewModel.consolidatedItems
            
            // Find the purchased items in inventory
            for selectedItem in selectedItems {
                let foundItem = inventoryItems.first { $0.catalogCode == selectedItem.code }
                #expect(foundItem != nil, "Should find \(selectedItem.name) in inventory")
                #expect(foundItem?.totalInventoryCount == selectedItem.quantity, "Should show correct inventory quantity")
                #expect(foundItem?.totalBuyCount == selectedItem.quantity, "Should show correct purchase quantity")
            }
        }
        
        // STEP 6: Generate purchase report (summary)
        print("Step 6: Generating purchase summary...")
        let finalInventoryState = try await inventoryService.getAllItems()
        let purchasesSummary = finalInventoryState.filter { $0.type == .buy }
        let inventorySummary = finalInventoryState.filter { $0.type == .inventory }
        
        #expect(purchasesSummary.count == 2, "Should have 2 purchase records")
        #expect(inventorySummary.count == 2, "Should have 2 inventory records")
        
        print("✅ Complete purchase workflow successful!")
        print("   - Searched catalog for project needs")
        print("   - Selected 2 items (red and blue glass)")
        print("   - Created purchase records")
        print("   - Confirmed purchase details")
        print("   - Updated inventory with received materials")
        print("   - Generated purchase summary")
        print("   Purchase Summary:")
        for item in selectedItems {
            print("   - \(item.name) (\(item.code)): \(item.quantity) sheets")
        }
    }
    
    // MARK: - Multi-User Scenario Workflow
    
    @Test("Should handle concurrent user operations workflow")
    func testConcurrentUserWorkflow() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createCompleteTestEnvironment()
        
        // SETUP: Create shared catalog
        print("Setup: Creating shared catalog...")
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createItem(item)
        }
        
        print("Simulating concurrent user operations...")
        
        // SCENARIO: Two users working simultaneously
        // User 1: Studio manager updating inventory
        // User 2: Artist creating project purchases
        
        await withTaskGroup(of: Void.self) { group in
            
            // User 1 Task: Studio Manager - Inventory Updates
            group.addTask {
                print("User 1 (Manager): Starting inventory updates...")
                
                let managerUpdates = [
                    ("BULLSEYE-0124", 15.0),
                    ("SPECTRUM-125", 12.0),
                    ("UROBOROS-94-16", 8.0)
                ]
                
                for (code, quantity) in managerUpdates {
                    do {
                        let inventoryItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .inventory,
                            notes: "Manager update - inventory count"
                        )
                        _ = try await inventoryService.createItem(inventoryItem)
                        
                        // Simulate processing time
                        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                        
                    } catch {
                        print("User 1 error: \(error)")
                    }
                }
                print("User 1 (Manager): Completed inventory updates")
            }
            
            // User 2 Task: Artist - Project Purchases
            group.addTask {
                print("User 2 (Artist): Starting project purchases...")
                
                let artistPurchases = [
                    ("BULLSEYE-1108", 3.0),
                    ("SPECTRUM-347", 2.0),
                    ("UROBOROS-92-14", 1.0)
                ]
                
                for (code, quantity) in artistPurchases {
                    do {
                        let purchaseItem = InventoryItemModel(
                            catalogCode: code,
                            quantity: quantity,
                            type: .buy,
                            notes: "Artist project - Spring Collection"
                        )
                        _ = try await inventoryService.createItem(purchaseItem)
                        
                        // Simulate processing time
                        try await Task.sleep(nanoseconds: 30_000_000) // 0.03 seconds
                        
                    } catch {
                        print("User 2 error: \(error)")
                    }
                }
                print("User 2 (Artist): Completed project purchases")
            }
        }
        
        // Verify concurrent operations completed successfully
        print("Verifying concurrent operations results...")
        
        await inventoryViewModel.loadInventoryItems()
        
        await MainActor.run {
            let consolidatedItems = inventoryViewModel.consolidatedItems
            
            // Should have items from both users
            #expect(consolidatedItems.count >= 6, "Should have items from both concurrent users")
            
            // Verify specific items were processed
            let bullseyeRed = consolidatedItems.first { $0.catalogCode == "BULLSEYE-0124" }
            #expect(bullseyeRed?.totalInventoryCount == 15.0, "Manager's inventory update should be recorded")
            
            let spectrumPink = consolidatedItems.first { $0.catalogCode == "SPECTRUM-347" }
            #expect(spectrumPink?.totalBuyCount == 2.0, "Artist's purchase should be recorded")
        }
        
        // Verify data consistency after concurrent operations
        let finalInventoryItems = try await inventoryService.getAllItems()
        let managerItems = finalInventoryItems.filter { $0.notes?.contains("Manager update") ?? false }
        let artistItems = finalInventoryItems.filter { $0.notes?.contains("Artist project") ?? false }
        
        #expect(managerItems.count == 3, "Should have 3 manager inventory updates")
        #expect(artistItems.count == 3, "Should have 3 artist purchases")
        
        print("✅ Concurrent user workflow successful!")
        print("   - Manager updated inventory for 3 items")
        print("   - Artist created purchases for 3 items")
        print("   - No data corruption or conflicts")
        print("   - Final inventory view shows consolidated results")
    }
    
    // MARK: - Complete Studio Daily Workflow
    
    @Test("Should handle complete daily studio workflow")
    func testCompleteDailyStudioWorkflow() async throws {
        let (catalogService, inventoryService, inventoryViewModel) = await createCompleteTestEnvironment()
        
        print("🎨 Starting daily glass studio workflow...")
        
        // MORNING: Setup catalog and check inventory
        print("\n☀️ Morning: Setting up studio catalog and checking inventory")
        
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createItem(item)
        }
        
        let initialInventory = createInitialInventoryData()
        for item in initialInventory {
            _ = try await inventoryService.createItem(item)
        }
        
        await inventoryViewModel.loadInventoryItems()
        
        await MainActor.run {
            let morningInventory = inventoryViewModel.consolidatedItems
            #expect(morningInventory.count == 4, "Morning inventory check shows 4 different glass types")
            print("✅ Morning inventory: \(morningInventory.count) glass types available")
        }
        
        // MIDDAY: Artists create projects and use materials
        print("\n🌞 Midday: Artists working on projects")
        
        let projectMaterials = [
            ("BULLSEYE-0124", 2.0, "Sold - Custom suncatcher project"),
            ("SPECTRUM-125", 1.5, "Sold - Jewelry component"),
        ]
        
        for (code, quantity, notes) in projectMaterials {
            let saleItem = InventoryItemModel(
                catalogCode: code,
                quantity: quantity,
                type: .sell,
                notes: notes
            )
            _ = try await inventoryService.createItem(saleItem)
        }
        
        // AFTERNOON: Receive shipment and update inventory
        print("\n🌅 Afternoon: Receiving shipment")
        
        let shipmentItems = [
            ("BULLSEYE-0001", 10.0, "Shipment - Weekly clear glass order"),
            ("UROBOROS-92-14", 3.0, "Shipment - Special order granite"),
        ]
        
        for (code, quantity, notes) in shipmentItems {
            let receivedItem = InventoryItemModel(
                catalogCode: code,
                quantity: quantity,
                type: .inventory,
                notes: notes
            )
            _ = try await inventoryService.createItem(receivedItem)
        }
        
        // EVENING: End of day reporting and planning
        print("\n🌙 Evening: End of day reporting")
        
        await inventoryViewModel.loadInventoryItems()
        
        await MainActor.run {
            let eveningInventory = inventoryViewModel.consolidatedItems
            
            // Verify daily transactions
            let bullseyeRed = eveningInventory.first { $0.catalogCode == "BULLSEYE-0124" }
            #expect(bullseyeRed?.totalInventoryCount == 5.0, "Red glass should show original inventory")
            #expect(bullseyeRed?.totalSellCount == 2.0, "Should show 2 units sold today")
            
            // Calculate net quantity manually (inventory - sell)
            let redNetQuantity = (bullseyeRed?.totalInventoryCount ?? 0) - (bullseyeRed?.totalSellCount ?? 0)
            #expect(redNetQuantity == 3.0, "Net quantity should be 3 (5 - 2)")
            
            let bullseyeClear = eveningInventory.first { $0.catalogCode == "BULLSEYE-0001" }
            #expect(bullseyeClear?.totalInventoryCount == 10.0, "Clear glass shipment received")
            
            print("✅ End of day inventory updated successfully")
        }
        
        // Generate daily summary report
        let finalInventoryItems = try await inventoryService.getAllItems()
        let dailySales = finalInventoryItems.filter { 
            $0.type == .sell && ($0.notes?.localizedCaseInsensitiveContains("sold") ?? false)
        }
        let dailyReceived = finalInventoryItems.filter {
            $0.type == .inventory && ($0.notes?.localizedCaseInsensitiveContains("shipment") ?? false)
        }
        
        #expect(dailySales.count == 2, "Should record 2 sales today")
        #expect(dailyReceived.count == 2, "Should record 2 shipment items today")
        
        let totalSalesQuantity = dailySales.reduce(0.0) { $0 + $1.quantity }
        let totalReceivedQuantity = dailyReceived.reduce(0.0) { $0 + $1.quantity }
        
        print("✅ Complete daily studio workflow successful!")
        print("\n📊 Daily Summary Report:")
        print("   • Morning inventory: 4 glass types")
        print("   • Sales today: \(dailySales.count) transactions, \(totalSalesQuantity) units")
        print("   • Received today: \(dailyReceived.count) shipments, \(totalReceivedQuantity) units")
        print("   • Evening inventory: Updated and reconciled")
        print("   • Net inventory change: +\(totalReceivedQuantity - totalSalesQuantity) units")
    }
}