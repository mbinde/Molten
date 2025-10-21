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

@testable import Molten

@Suite("End-to-End User Workflows", .serialized)
struct EndToEndWorkflowTests: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    // MARK: - Test Infrastructure Using Working Pattern
    
    private func createCompleteTestEnvironment() async throws -> (
        catalogService: CatalogService,
        inventoryTrackingService: InventoryTrackingService,
        inventoryViewModel: InventoryViewModel
    ) {
        // Clear singleton cache to ensure clean test state
        await CatalogDataCache.shared.clear()

        // Use the working TestConfiguration pattern
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        let userTagsRepo = MockUserTagsRepository()

        // Create services using the same repository instances
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: repos.glassItem,
            inventoryRepository: repos.inventory,
            locationRepository: repos.location,
            itemTagsRepository: repos.itemTags
        )

        let shoppingListRepository = MockShoppingListRepository()
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: repos.itemMinimum,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: repos.inventory,
            glassItemRepository: repos.glassItem,
            itemTagsRepository: repos.itemTags,
            userTagsRepository: userTagsRepo
        )

        let catalogService = CatalogService(
            glassItemRepository: repos.glassItem,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: repos.itemTags,
            userTagsRepository: userTagsRepo
        )
        
        let inventoryViewModel = await InventoryViewModel(
            inventoryTrackingService: inventoryTrackingService,
            catalogService: catalogService
        )
        
        return (catalogService, inventoryTrackingService, inventoryViewModel)
    }
    
    private func createGlassStudioCatalogData() -> [GlassItemModel] {
        return [
            // Bullseye Glass Collection - use consistent manufacturer naming
            GlassItemModel(natural_key: GlassItemModel.createNaturalKey(manufacturer: "bullseye", sku: "0124", sequence: 0), name: "Red Opal", sku: "0124", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: GlassItemModel.createNaturalKey(manufacturer: "bullseye", sku: "1108", sequence: 0), name: "Blue Transparent", sku: "1108", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: GlassItemModel.createNaturalKey(manufacturer: "bullseye", sku: "0001", sequence: 0), name: "Clear", sku: "0001", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            
            // Spectrum Glass Collection - use consistent manufacturer naming 
            GlassItemModel(natural_key: GlassItemModel.createNaturalKey(manufacturer: "spectrum", sku: "125", sequence: 0), name: "Medium Amber", sku: "125", manufacturer: "spectrum", coe: 96, mfr_status: "available"),
            GlassItemModel(natural_key: GlassItemModel.createNaturalKey(manufacturer: "spectrum", sku: "347", sequence: 0), name: "Cranberry Pink", sku: "347", manufacturer: "spectrum", coe: 96, mfr_status: "available"),
            
            // Uroboros Collection - use consistent manufacturer naming
            GlassItemModel(natural_key: GlassItemModel.createNaturalKey(manufacturer: "uroboros", sku: "94-16", sequence: 0), name: "Red with Silver", sku: "94-16", manufacturer: "uroboros", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: GlassItemModel.createNaturalKey(manufacturer: "uroboros", sku: "92-14", sequence: 0), name: "Green Granite", sku: "92-14", manufacturer: "uroboros", coe: 90, mfr_status: "available")
        ]
    }
    
    private func createInitialInventoryData() -> [InventoryModel] {
        return [
            // Starting inventory - what a glass studio might have
            InventoryModel(item_natural_key: "bullseye-0124-0", type: "inventory", quantity: 5.0),
            InventoryModel(item_natural_key: "bullseye-1108-0", type: "inventory", quantity: 3.0),
            InventoryModel(item_natural_key: "spectrum-125-0", type: "inventory", quantity: 8.0),
            InventoryModel(item_natural_key: "uroboros-94-16-0", type: "inventory", quantity: 1.0)
        ]
    }
    
    // MARK: - Complete Catalog Management Workflow
    
    @Test("Should support complete catalog management workflow")
    func testCatalogManagementWorkflow() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = try await createCompleteTestEnvironment()
        
        // STEP 1: Import catalog data (simulating loading from JSON/CSV/API)
        print("Step 1: Importing catalog data...")
        let catalogData = createGlassStudioCatalogData()
        
        var importedGlassItems: [GlassItemModel] = []
        for item in catalogData {
            let savedItem = try await catalogService.createGlassItem(item, initialInventory: [], tags: ["red", "opal", "coe90"])
            importedGlassItems.append(savedItem.glassItem)
        }
        
        #expect(importedGlassItems.count == 7, "Should import 7 glass items")
        print("✅ Imported \(importedGlassItems.count) catalog items")
        
        // STEP 2: Search for specific items (user looking for red glass)
        print("Step 2: Searching for red glass...")
        let redItems = try await inventoryTrackingService.searchItems(text: "red", withTags: [], hasInventory: false, inventoryTypes: [])
        
        #expect(redItems.count >= 2, "Should find at least 2 red items")
        let redNames = redItems.map { $0.glassItem.name }
        #expect(redNames.contains("Red Opal"), "Should find Bullseye Red Opal")
        #expect(redNames.contains("Red with Silver"), "Should find Uroboros Red with Silver")
        print("✅ Found \(redItems.count) red glass items")
        
        // STEP 3: Filter by manufacturer (user wants Bullseye glass specifically)
        print("Step 3: Filtering by Bullseye manufacturer...")
        let allItems = try await catalogService.getAllGlassItems()
        let bullseyeItems = allItems.filter { $0.glassItem.manufacturer == "bullseye" }
        
        #expect(bullseyeItems.count == 3, "Should find 3 Bullseye items")
        print("✅ Filtered to \(bullseyeItems.count) Bullseye items")
        
        // STEP 4: Add selected items to inventory (user decides to stock up)
        print("Step 4: Adding selected items to inventory...")
        let itemsToStock = [
            ("bullseye-0124-0", 10.0), // Red Opal - popular color
            ("bullseye-0001-0", 5.0),  // Clear - essential basic
        ]
        
        for (naturalKey, quantity) in itemsToStock {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: "inventory",
                toItem: naturalKey,
                distributedTo: []
            )
        }
        
        // STEP 5: Create purchase records (user records their purchase)
        print("Step 5: Recording purchase...")
        for (naturalKey, quantity) in itemsToStock {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: "buy",
                toItem: naturalKey,
                distributedTo: []
            )
        }
        
        // STEP 6: Update inventory view to see consolidated results
        print("Step 6: Updating inventory view...")
        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await inventoryViewModel.loadInventoryItems()

        await MainActor.run {
            #expect(inventoryViewModel.filteredItems.count >= 2, "Should show filtered inventory items")
            
            let bullseyeRed = inventoryViewModel.filteredItems.first { $0.glassItem.natural_key == "bullseye-0124-0" }
            #expect(bullseyeRed != nil, "Should find Bullseye Red in inventory")
            let inventoryQty = bullseyeRed?.inventoryByType["inventory"] ?? 0.0
            let buyQty = bullseyeRed?.inventoryByType["buy"] ?? 0.0
            #expect(inventoryQty == 10.0, "Should show 10 units in inventory")
            #expect(buyQty == 10.0, "Should show 10 units purchased")
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
        let (catalogService, inventoryTrackingService, inventoryViewModel) = try await createCompleteTestEnvironment()
        
        // SETUP: Create catalog and initial inventory
        print("Setup: Creating catalog and initial inventory...")
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        let initialInventory = createInitialInventoryData()
        for item in initialInventory {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        // STEP 1: View current inventory status
        print("Step 1: Viewing current inventory...")
        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await inventoryViewModel.loadInventoryItems()

        await MainActor.run {
            let initialCount = inventoryViewModel.filteredItems.count
            #expect(initialCount >= 4, "Should show at least 4 different catalog items in inventory")
            print("✅ Initial inventory shows \(initialCount) different items")
        }
        
        // STEP 2: Search for items that might be low stock (manual check)
        print("Step 2: Checking for low stock items...")
        
        await MainActor.run {
            let allItems = inventoryViewModel.filteredItems
            let lowStockItems = allItems.filter { $0.inventoryByType["inventory"] ?? 0.0 <= 3.0 }
            #expect(lowStockItems.count >= 1, "Should find low stock items")
            
            let foundUroboros = lowStockItems.contains { $0.glassItem.natural_key == "uroboros-94-16-0" }
            #expect(foundUroboros, "Should find Uroboros item with 1 unit as low stock")
            print("✅ Found \(lowStockItems.count) low stock items")
        }
        
        // STEP 3: Create purchase order for low stock items
        print("Step 3: Creating purchase order for restocking...")
        let restockItems = [
            ("uroboros-94-16-0", 5.0),  // Restock the low quantity item
            ("bullseye-1108-0", 7.0),   // Also low at 3 units, bring up to 10
        ]
        
        for (naturalKey, quantity) in restockItems {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: "buy",
                toItem: naturalKey,
                distributedTo: []
            )
        }
        
        // STEP 4: Receive shipment and update inventory
        print("Step 4: Receiving shipment and updating inventory...")
        for (naturalKey, quantity) in restockItems {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: "inventory",
                toItem: naturalKey,
                distributedTo: []
            )
        }
        
        // STEP 5: Verify updated quantities
        print("Step 5: Verifying updated inventory...")
        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await inventoryViewModel.loadInventoryItems()

        await MainActor.run {
            let uroborosItem = inventoryViewModel.filteredItems.first { $0.glassItem.natural_key == "uroboros-94-16-0" }
            #expect(uroborosItem != nil, "Should find Uroboros item after restock")
            let inventoryQty = uroborosItem?.inventoryByType["inventory"] ?? 0.0
            let buyQty = uroborosItem?.inventoryByType["buy"] ?? 0.0
            #expect(inventoryQty == 6.0, "Should show 6 units (1 original + 5 restocked)")
            #expect(buyQty == 5.0, "Should show 5 units purchased")
            
            let bullseyeBlue = inventoryViewModel.filteredItems.first { $0.glassItem.natural_key == "bullseye-1108-0" }
            let blueInventoryQty = bullseyeBlue?.inventoryByType["inventory"] ?? 0.0
            #expect(blueInventoryQty == 10.0, "Should show 10 units (3 original + 7 restocked)")
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
        let (catalogService, inventoryTrackingService, inventoryViewModel) = try await createCompleteTestEnvironment()
        
        // SETUP: Create catalog
        print("Setup: Creating catalog...")
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: ["red", "blue"])
        }
        
        // STEP 1: Search catalog for project needs (user planning a red and blue piece)
        print("Step 1: Searching catalog for project materials...")
        let projectColors = ["red", "blue"]
        var selectedItems: [(naturalKey: String, name: String, quantity: Double)] = []
        
        for color in projectColors {
            let colorItems = try await inventoryTrackingService.searchItems(text: color, withTags: [], hasInventory: false, inventoryTypes: [])
            if let firstItem = colorItems.first {
                selectedItems.append((
                    naturalKey: firstItem.glassItem.natural_key,
                    name: firstItem.glassItem.name,
                    quantity: 2.0 // 2 sheets for project
                ))
            }
        }
        
        #expect(selectedItems.count == 2, "Should select 2 items for project")
        print("✅ Selected \(selectedItems.count) items for project")
        
        // STEP 2: Create purchase record
        print("Step 2: Creating purchase record...")
        var purchaseItems: [InventoryModel] = []
        
        for item in selectedItems {
            let purchaseItem = try await inventoryTrackingService.addInventory(
                quantity: item.quantity,
                type: "buy",
                toItem: item.naturalKey,
                distributedTo: []
            )
            purchaseItems.append(purchaseItem)
        }
        
        #expect(purchaseItems.count == 2, "Should create 2 purchase records")
        
        // STEP 3: Confirm purchase details
        print("Step 3: Confirming purchase details...")
        let allInventories = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        let projectPurchases = allInventories.filter { inventory in
            inventory.type == "buy" && selectedItems.contains { selectedItem in inventory.item_natural_key == selectedItem.naturalKey }
        }
        
        #expect(projectPurchases.count == 2, "Should find 2 project purchases")
        
        let totalCost = projectPurchases.reduce(0.0) { $0 + $1.quantity } // Quantity as proxy for cost
        #expect(totalCost == 4.0, "Should calculate total quantity of 4 sheets")
        
        // STEP 4: Record purchase in system (update inventory)
        print("Step 4: Recording received materials in inventory...")
        for purchaseItem in projectPurchases {
            _ = try await inventoryTrackingService.addInventory(
                quantity: purchaseItem.quantity,
                type: "inventory",
                toItem: purchaseItem.item_natural_key,
                distributedTo: []
            )
        }
        
        // STEP 5: Update inventory view and verify
        print("Step 5: Updating inventory view...")
        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await inventoryViewModel.loadInventoryItems()

        await MainActor.run {
            let inventoryItems = inventoryViewModel.filteredItems
            
            // Find the purchased items in inventory
            for selectedItem in selectedItems {
                let foundItem = inventoryItems.first { $0.glassItem.natural_key == selectedItem.naturalKey }
                #expect(foundItem != nil, "Should find \(selectedItem.name) in inventory")
                let inventoryQty = foundItem?.inventoryByType["inventory"] ?? 0.0
                let buyQty = foundItem?.inventoryByType["buy"] ?? 0.0
                #expect(inventoryQty == selectedItem.quantity, "Should show correct inventory quantity")
                #expect(buyQty == selectedItem.quantity, "Should show correct purchase quantity")
            }
        }
        
        // STEP 6: Generate purchase report (summary)
        print("Step 6: Generating purchase summary...")
        let finalInventoryState = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        let purchasesSummary = finalInventoryState.filter { $0.type == "buy" }
        let inventorySummary = finalInventoryState.filter { $0.type == "inventory" }
        
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
            print("   - \(item.name) (\(item.naturalKey)): \(item.quantity) sheets")
        }
    }
    
    // MARK: - Multi-User Scenario Workflow
    
    @Test("Should handle concurrent user operations workflow")
    func testConcurrentUserWorkflow() async throws {
        let (catalogService, inventoryTrackingService, inventoryViewModel) = try await createCompleteTestEnvironment()
        
        // SETUP: Create shared catalog
        print("Setup: Creating shared catalog...")
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
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
                    ("bullseye-0124-0", 15.0),
                    ("spectrum-125-0", 12.0),
                    ("uroboros-94-16-0", 8.0)
                ]
                
                for (naturalKey, quantity) in managerUpdates {
                    do {
                        _ = try await inventoryTrackingService.addInventory(
                            quantity: quantity,
                            type: "inventory",
                            toItem: naturalKey,
                            distributedTo: []
                        )
                        
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
                    ("bullseye-1108-0", 3.0),
                    ("spectrum-347-0", 2.0),
                    ("uroboros-92-14-0", 1.0)
                ]
                
                for (naturalKey, quantity) in artistPurchases {
                    do {
                        _ = try await inventoryTrackingService.addInventory(
                            quantity: quantity,
                            type: "buy",
                            toItem: naturalKey,
                            distributedTo: []
                        )
                        
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

        // Force cache reload to ensure we get fresh data
        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await inventoryViewModel.loadInventoryItems()

        await MainActor.run {
            let consolidatedItems = inventoryViewModel.filteredItems
            
            // Should have items from both users
            #expect(consolidatedItems.count >= 6, "Should have items from both concurrent users")
            
            // Verify specific items were processed
            let bullseyeRed = consolidatedItems.first { $0.glassItem.natural_key == "bullseye-0124-0" }
            let redInventoryQty = bullseyeRed?.inventoryByType["inventory"] ?? 0.0
            #expect(redInventoryQty == 15.0, "Manager's inventory update should be recorded")
            
            let spectrumPink = consolidatedItems.first { $0.glassItem.natural_key == "spectrum-347-0" }
            let pinkBuyQty = spectrumPink?.inventoryByType["buy"] ?? 0.0
            #expect(pinkBuyQty == 2.0, "Artist's purchase should be recorded")
        }
        
        // Verify data consistency after concurrent operations
        let finalInventoryItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        let managerItems = finalInventoryItems.filter { $0.type == "inventory" }
        let artistItems = finalInventoryItems.filter { $0.type == "buy" }
        
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
        let (catalogService, inventoryTrackingService, inventoryViewModel) = try await createCompleteTestEnvironment()
        
        print("🎨 Starting daily glass studio workflow...")
        
        // MORNING: Setup catalog and check inventory
        print("\n☀️ Morning: Setting up studio catalog and checking inventory")
        
        let catalogData = createGlassStudioCatalogData()
        for item in catalogData {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        let initialInventory = createInitialInventoryData()
        for item in initialInventory {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }

        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await inventoryViewModel.loadInventoryItems()

        await MainActor.run {
            let morningInventory = inventoryViewModel.filteredItems
            #expect(morningInventory.count >= 4, "Morning inventory check shows at least 4 different glass types")
            print("✅ Morning inventory: \(morningInventory.count) glass types available")
        }
        
        // MIDDAY: Artists create projects and use materials
        print("\n🌞 Midday: Artists working on projects")
        
        let projectMaterials = [
            ("bullseye-0124-0", 2.0),
            ("spectrum-125-0", 1.5),
        ]
        
        for (naturalKey, quantity) in projectMaterials {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: "sell",
                toItem: naturalKey,
                distributedTo: []
            )
        }
        
        // AFTERNOON: Receive shipment and update inventory
        print("\n🌅 Afternoon: Receiving shipment")
        
        let shipmentItems = [
            ("bullseye-0001-0", 10.0),
            ("uroboros-92-14-0", 3.0),
        ]
        
        for (naturalKey, quantity) in shipmentItems {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: "inventory",
                toItem: naturalKey,
                distributedTo: []
            )
        }
        
        // EVENING: End of day reporting and planning
        print("\n🌙 Evening: End of day reporting")

        await CatalogDataCache.shared.reload(catalogService: catalogService)
        await inventoryViewModel.loadInventoryItems()

        await MainActor.run {
            let eveningInventory = inventoryViewModel.filteredItems
            
            // Verify daily transactions
            let bullseyeRed = eveningInventory.first { $0.glassItem.natural_key == "bullseye-0124-0" }
            let redInventoryQty = bullseyeRed?.inventoryByType["inventory"] ?? 0.0
            let redSellQty = bullseyeRed?.inventoryByType["sell"] ?? 0.0
            #expect(redInventoryQty == 5.0, "Red glass should show original inventory")
            #expect(redSellQty == 2.0, "Should show 2 units sold today")
            
            // Calculate net quantity manually (inventory - sell)
            let redNetQuantity = redInventoryQty - redSellQty
            #expect(redNetQuantity == 3.0, "Net quantity should be 3 (5 - 2)")
            
            let bullseyeClear = eveningInventory.first { $0.glassItem.natural_key == "bullseye-0001-0" }
            let clearInventoryQty = bullseyeClear?.inventoryByType["inventory"] ?? 0.0
            #expect(clearInventoryQty == 10.0, "Clear glass shipment received")
            
            print("✅ End of day inventory updated successfully")
        }
        
        // Generate daily summary report
        let finalInventoryItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        let dailySales = finalInventoryItems.filter { 
            $0.type == "sell"
        }
        let dailyReceived = finalInventoryItems.filter { inventory in
            inventory.type == "inventory" && shipmentItems.contains { shipmentItem in inventory.item_natural_key == shipmentItem.0 }
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
