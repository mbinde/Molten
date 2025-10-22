//
//  DemoDataGenerator.swift
//  Molten
//
//  Generates realistic demo data for screenshots and demonstrations
//  Creates inventory records, shopping list items, project plans, etc.
//

import Foundation

/// Generates realistic demo data for screenshot automation
@MainActor
class DemoDataGenerator {

    private let catalogService: CatalogService
    private let inventoryService: InventoryTrackingService
    private let shoppingListService: ShoppingListService
    private let purchaseRecordService: PurchaseRecordService

    init(catalogService: CatalogService,
         inventoryService: InventoryTrackingService,
         shoppingListService: ShoppingListService,
         purchaseRecordService: PurchaseRecordService) {
        self.catalogService = catalogService
        self.inventoryService = inventoryService
        self.shoppingListService = shoppingListService
        self.purchaseRecordService = purchaseRecordService
    }

    /// Generate all demo data for screenshots
    func generateDemoData() async throws {
        print("🎬 [DEMO DATA] Starting demo data generation...")

        // Step 1: Create inventory records for some demo items
        try await createInventoryRecords()

        // Step 2: Add items to shopping list
        try await createShoppingListItems()

        // Step 3: Create a purchase record
        try await createPurchaseRecords()

        // Step 4: Create project plans (future enhancement)
        // try await createProjectPlans()

        print("✅ [DEMO DATA] Demo data generation complete!")
    }

    // MARK: - Inventory Records

    private func createInventoryRecords() async throws {
        print("📦 [DEMO DATA] Creating inventory records...")

        // Get some demo items to add inventory for
        let allItems = try await catalogService.getAllGlassItems()

        // Pick a variety of items (first 100)
        let demoItems = allItems.prefix(100)

        var created = 0
        for item in demoItems {
            // Check if it already has inventory
            if let completeItem = try await inventoryService.getCompleteItem(naturalKey: item.natural_key) {
                if !completeItem.inventory.isEmpty {
                    continue
                }
            }

            // Create inventory with random whole number quantities (no decimals)
            let quantity = Double(Int.random(in: 1...20))
            let type = ["rod", "frit", "sheet"].randomElement() ?? "rod"

            _ = try await inventoryService.addInventory(
                quantity: quantity,
                type: type,
                toItem: item.natural_key,
                distributedTo: [(location: selectRandomLocation(), quantity: quantity)]
            )

            created += 1
        }

        print("   ✅ Created \(created) inventory records")
    }

    // MARK: - Shopping List

    private func createShoppingListItems() async throws {
        print("🛒 [DEMO DATA] Creating shopping list items...")

        // Get items to add to shopping list
        let allItems = try await catalogService.getAllGlassItems()

        // Pick 20 items for shopping list (starting from index 10)
        let shoppingItems = allItems.dropFirst(10).prefix(20)

        var added = 0
        for item in shoppingItems {
            // Check if already in shopping list
            let existingShoppingItems = try await shoppingListService.shoppingListRepository.fetchAllItems()
            let alreadyAdded = existingShoppingItems.contains { $0.item_natural_key == item.natural_key }

            if alreadyAdded {
                continue
            }

            // Add to shopping list via repository with whole number quantities
            let quantity = Double(Int.random(in: 1...10))
            let type = ["rod", "frit", "sheet"].randomElement() ?? "rod"
            let store = ["Frantz", "Mountain Glass", "Hot Glass Color"].randomElement() ?? "Frantz"

            let shoppingItem = ItemShoppingModel(
                id: UUID(),
                item_natural_key: item.natural_key,
                quantity: quantity,
                store: store,
                type: type,
                subtype: nil,
                subsubtype: nil,
                dateAdded: Date()
            )

            _ = try await shoppingListService.shoppingListRepository.createItem(shoppingItem)

            added += 1
        }

        print("   ✅ Added \(added) shopping list items")
    }

    // MARK: - Purchase Records

    private func createPurchaseRecords() async throws {
        print("💰 [DEMO DATA] Creating purchase records...")

        // Create 1-2 purchase records
        let allItems = try await catalogService.getAllGlassItems()

        // Pick a few items for a purchase
        let purchasedItems = Array(allItems.prefix(3))

        if purchasedItems.isEmpty {
            return
        }

        // Create purchase items with whole number quantities
        var purchaseItems: [PurchaseRecordItemModel] = []
        for (index, item) in purchasedItems.enumerated() {
            let quantity = Double(Int.random(in: 1...5))
            let type = ["rod", "frit", "sheet"].randomElement() ?? "rod"
            let pricePerUnit = Double.random(in: 5...25)

            let purchaseItem = PurchaseRecordItemModel(
                itemNaturalKey: item.natural_key,
                type: type,
                quantity: quantity,
                totalPrice: Decimal(pricePerUnit * quantity),
                orderIndex: Int32(index)
            )

            purchaseItems.append(purchaseItem)
        }

        // Create the purchase record
        let vendor = ["Frantz", "Mountain Glass", "Hot Glass Color"].randomElement() ?? "Frantz"
        let purchaseDate = Date().addingTimeInterval(-60 * 60 * 24 * Double.random(in: 1...30))  // 1-30 days ago

        let purchaseRecord = PurchaseRecordModel(
            supplier: vendor,
            datePurchased: purchaseDate,
            subtotal: Decimal(Double.random(in: 50...200)),
            tax: Decimal(Double.random(in: 5...20)),
            shipping: Decimal(Double.random(in: 10...30)),
            notes: "Demo purchase for screenshots",
            items: purchaseItems
        )

        _ = try await purchaseRecordService.createRecord(purchaseRecord)

        print("   ✅ Created 1 purchase record with \(purchaseItems.count) items")
    }

    // MARK: - Helpers

    private func selectRandomLocation() -> String {
        let locations = ["Studio", "Workshop", "Storage", "Shelf A", "Shelf B", "Cabinet 1"]
        return locations.randomElement() ?? "Studio"
    }
}
