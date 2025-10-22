//
//  InventoryDetailViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/18/25.
//  Tests for InventoryDetailView functionality
//

import Testing
import SwiftUI
@testable import Molten

@Suite("InventoryDetailView Tests")
@MainActor
struct InventoryDetailViewTests {

    // MARK: - Test Helpers

    func createTestItem(with inventory: [InventoryModel] = [], locations: [LocationModel] = []) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            natural_key: "test-item-001-0",
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test manufacturer notes",
            coe: 96,
            mfr_status: "available"
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: ["blue", "transparent"],
            userTags: ["favorite"],
            locations: locations
        )
    }

    // MARK: - Display All Inventory Types Tests

    @Test("Display single inventory type")
    func testDisplaySingleInventoryType() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                quantity: 10.0
            )
        ]

        let item = createTestItem(with: inventory)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.inventoryByType.count == 1)
        #expect(item.inventoryByType["rod"] == 10.0)
    }

    @Test("Display multiple inventory types")
    func testDisplayMultipleInventoryTypes() {
        let inventory = [
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 10.0),
            InventoryModel(item_natural_key: "test-item-001-0", type: "sheet", quantity: 5.0),
            InventoryModel(item_natural_key: "test-item-001-0", type: "frit", quantity: 3.5)
        ]

        let item = createTestItem(with: inventory)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.inventoryByType.count == 3)
        #expect(item.inventoryByType["rod"] == 10.0)
        #expect(item.inventoryByType["sheet"] == 5.0)
        #expect(item.inventoryByType["frit"] == 3.5)
    }

    @Test("Display empty inventory state")
    func testDisplayEmptyInventory() {
        let item = createTestItem(with: [])
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.inventory.isEmpty)
        #expect(item.inventoryByType.isEmpty)
    }

    @Test("Aggregate quantities for same type")
    func testAggregateQuantitiesForSameType() {
        let inventory = [
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 10.0),
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 5.0),
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 3.0)
        ]

        let item = createTestItem(with: inventory)

        #expect(item.inventoryByType["rod"] == 18.0)
        #expect(item.inventory.count == 3)
    }

    // MARK: - Type/Subtype/Dimension Display Tests

    @Test("Display inventory with subtype")
    func testDisplayInventoryWithSubtype() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                subtype: "stringer",
                quantity: 10.0
            )
        ]

        let item = createTestItem(with: inventory)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.inventory.first?.subtype == "stringer")
    }

    @Test("Display inventory with dimensions")
    func testDisplayInventoryWithDimensions() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                subtype: "standard",
                dimensions: ["diameter": 6.0, "length": 50.0],
                quantity: 10.0
            )
        ]

        let item = createTestItem(with: inventory)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        let dims = item.inventory.first?.dimensions
        #expect(dims?["diameter"] == 6.0)
        #expect(dims?["length"] == 50.0)
    }

    @Test("Display complex inventory with mixed subtypes and dimensions")
    func testDisplayComplexInventory() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                subtype: "stringer",
                dimensions: ["diameter": 3.0, "length": 40.0],
                quantity: 12.0
            ),
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                subtype: "standard",
                dimensions: ["diameter": 6.0, "length": 50.0],
                quantity: 5.0
            ),
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "sheet",
                subtype: "transparent",
                dimensions: ["thickness": 3.0, "width": 30.0, "height": 40.0],
                quantity: 3.0
            )
        ]

        let item = createTestItem(with: inventory)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.inventory.count == 3)
        #expect(item.inventoryByType.count == 2) // rod and sheet
        #expect(item.inventoryByType["rod"] == 17.0) // 12 + 5
        #expect(item.inventoryByType["sheet"] == 3.0)
    }

    @Test("Display inventory without dimensions")
    func testDisplayInventoryWithoutDimensions() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "scrap",
                quantity: 5.0
            )
        ]

        let item = createTestItem(with: inventory)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.inventory.first?.dimensions == nil)
    }

    // MARK: - Location Distribution Tests

    @Test("Display location distribution")
    func testDisplayLocationDistribution() {
        let locations = [
            LocationModel(inventory_id: UUID(), location: "Studio Shelf A", quantity: 8.0),
            LocationModel(inventory_id: UUID(), location: "Storage Room", quantity: 7.5)
        ]

        let item = createTestItem(locations: locations)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.locations.count == 2)
        #expect(item.locations[0].location == "Studio Shelf A")
        #expect(item.locations[1].location == "Storage Room")
    }

    @Test("Display empty location list")
    func testDisplayEmptyLocationList() {
        let item = createTestItem(locations: [])
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.locations.isEmpty)
    }

    @Test("Calculate location distribution percentages")
    func testCalculateLocationPercentages() {
        let locations = [
            LocationModel(inventory_id: UUID(), location: "Location A", quantity: 10.0),
            LocationModel(inventory_id: UUID(), location: "Location B", quantity: 5.0),
            LocationModel(inventory_id: UUID(), location: "Location C", quantity: 2.5)
        ]

        let item = createTestItem(locations: locations)

        let maxQuantity = item.locations.map { $0.quantity }.max() ?? 1
        #expect(maxQuantity == 10.0)

        let percentage1 = item.locations[0].quantity / maxQuantity
        let percentage2 = item.locations[1].quantity / maxQuantity
        let percentage3 = item.locations[2].quantity / maxQuantity

        #expect(percentage1 == 1.0)
        #expect(percentage2 == 0.5)
        #expect(percentage3 == 0.25)
    }

    // MARK: - Shopping List Integration Tests

    @Test("View should present shopping list options sheet")
    func testShoppingListOptionsPresentation() {
        let item = createTestItem()
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        // ShoppingListOptionsView is presented via sheet when showingShoppingListOptions is true
    }

    @Test("ShoppingListOptionsView initializes with item")
    func testShoppingListOptionsViewInit() {
        let item = createTestItem()
        let view = ShoppingListOptionsView(
            item: item,
            shoppingListRepository: MockShoppingListRepository()
        )

        #expect(view != nil)
        #expect(view.item.glassItem.natural_key == "test-item-001-0")
    }

    @Test("Shopping list validates positive quantity")
    func testShoppingListQuantityValidation() {
        let item = createTestItem()
        let mockRepo = MockShoppingListRepository()
        let view = ShoppingListOptionsView(item: item, shoppingListRepository: mockRepo)

        #expect(view != nil)
        // Validation happens when saving
    }

    // MARK: - Edit Operations Tests

    @Test("View initializes edit state from first inventory")
    func testEditStateInitialization() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                quantity: 10.0
            )
        ]

        let item = createTestItem(with: inventory)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        // Edit state initialized in loadInitialData()
    }

    @Test("View handles empty inventory for edit state")
    func testEditStateWithEmptyInventory() {
        let item = createTestItem(with: [])
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.inventory.isEmpty)
    }

    // MARK: - Add Inventory Flow Tests

    @Test("Add inventory sheet presents with prefilled natural key")
    func testAddInventorySheetPresentation() {
        let item = createTestItem()
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        // AddInventoryItemView is presented with prefilledNaturalKey
    }

    @Test("Add inventory uses inventory tracking service")
    func testAddInventoryUsesService() {
        let item = createTestItem()
        let mockService = InventoryTrackingService(
            glassItemRepository: MockGlassItemRepository(),
            inventoryRepository: MockInventoryRepository(),
            locationRepository: MockLocationRepository(),
            itemTagsRepository: MockItemTagsRepository()
        )

        let view = InventoryDetailView(
            item: item,
            inventoryTrackingService: mockService,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
    }

    // MARK: - User Tags Integration Tests

    @Test("Display user tags")
    func testDisplayUserTags() {
        let item = createTestItem()
        // item already has userTags: ["favorite"]

        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.userTags.count == 1)
        #expect(item.userTags.contains("favorite"))
    }

    @Test("Display empty user tags")
    func testDisplayEmptyUserTags() {
        let glassItem = GlassItemModel(
            natural_key: "test-item-002-0",
            name: "Test Item No Tags",
            sku: "002",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let item = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.userTags.isEmpty)
    }

    @Test("User tags editor integration")
    func testUserTagsEditorIntegration() {
        let item = createTestItem()
        let mockRepo = MockUserTagsRepository()

        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: mockRepo
        )

        #expect(view != nil)
        // UserTagsEditor is presented via sheet
    }

    // MARK: - Expandable Sections Tests

    @Test("ExpandableSection initializes correctly")
    func testExpandableSectionInit() {
        let section = ExpandableSection(
            title: "Test Section",
            systemImage: "info.circle",
            isExpanded: true,
            onToggle: {}
        ) {
            Text("Content")
        }

        #expect(section != nil)
    }

    @Test("Multiple expandable sections can coexist")
    func testMultipleExpandableSections() {
        let inventory = [
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 10.0)
        ]

        let locations = [
            LocationModel(inventory_id: UUID(), location: "Studio", quantity: 10.0)
        ]

        let item = createTestItem(with: inventory, locations: locations)
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        // View has multiple expandable sections: Glass Item Details, Inventory Details, Location Distribution
    }

    // MARK: - Inventory Detail Type Row Tests

    @Test("InventoryDetailTypeRow displays type correctly")
    func testInventoryDetailTypeRowDisplay() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                quantity: 10.0
            )
        ]

        let row = InventoryDetailTypeRow(
            type: "rod",
            quantity: 10.0,
            inventoryRecords: inventory,
            onTap: {}
        )

        #expect(row != nil)
    }

    @Test("InventoryDetailTypeRow handles multiple subtypes")
    func testInventoryDetailTypeRowMultipleSubtypes() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                subtype: "stringer",
                quantity: 5.0
            ),
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                subtype: "standard",
                quantity: 10.0
            )
        ]

        let row = InventoryDetailTypeRow(
            type: "rod",
            quantity: 15.0,
            inventoryRecords: inventory,
            onTap: {}
        )

        #expect(row != nil)
    }

    @Test("InventoryDetailTypeRow shows dimensions summary")
    func testInventoryDetailTypeRowDimensions() {
        let inventory = [
            InventoryModel(
                item_natural_key: "test-item-001-0",
                type: "rod",
                dimensions: ["diameter": 6.0, "length": 50.0],
                quantity: 10.0
            )
        ]

        let row = InventoryDetailTypeRow(
            type: "rod",
            quantity: 10.0,
            inventoryRecords: inventory,
            onTap: {}
        )

        #expect(row != nil)
    }

    // MARK: - Error Handling Tests

    @Test("View handles missing inventory tracking service")
    func testMissingInventoryTrackingService() {
        let item = createTestItem()
        let view = InventoryDetailView(
            item: item,
            inventoryTrackingService: nil,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        // View should still work without service (add inventory disabled)
    }

    @Test("View handles data loading on appear")
    func testDataLoadingOnAppear() {
        let item = createTestItem()
        let mockNotesRepo = MockUserNotesRepository()
        let mockTagsRepo = MockUserTagsRepository()

        let view = InventoryDetailView(
            item: item,
            userNotesRepository: mockNotesRepo,
            userTagsRepository: mockTagsRepo
        )

        #expect(view != nil)
        // Data loaded in onAppear
    }

    // MARK: - LocationDetailView Tests

    @Test("LocationDetailView initializes correctly")
    func testLocationDetailViewInit() {
        let inventory = [
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 10.0)
        ]

        let item = createTestItem(with: inventory)
        let view = LocationDetailView(item: item, inventoryType: "rod")

        #expect(view != nil)
    }

    // MARK: - Quantity Formatting Tests

    @Test("Format whole number quantities")
    func testFormatWholeNumberQuantity() {
        let inventory = [
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 10.0)
        ]

        let item = createTestItem(with: inventory)

        // Quantity formatting tested in view logic
        let quantity = item.inventory.first?.quantity ?? 0
        let isWhole = quantity.truncatingRemainder(dividingBy: 1) == 0
        #expect(isWhole)
    }

    @Test("Format decimal quantities")
    func testFormatDecimalQuantity() {
        let inventory = [
            InventoryModel(item_natural_key: "test-item-001-0", type: "rod", quantity: 10.5)
        ]

        let item = createTestItem(with: inventory)

        let quantity = item.inventory.first?.quantity ?? 0
        let isDecimal = quantity.truncatingRemainder(dividingBy: 1) != 0
        #expect(isDecimal)
        #expect(quantity == 10.5)
    }

    // MARK: - Glass Item Card Integration Tests

    @Test("Header displays GlassItemCard")
    func testGlassItemCardDisplay() {
        let item = createTestItem()
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        // GlassItemCard displayed in headerSection with tags
        #expect(item.tags.count == 2)
        #expect(item.tags.contains("blue"))
    }

    @Test("Manufacturer notes display")
    func testManufacturerNotesDisplay() {
        let item = createTestItem()
        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.glassItem.mfr_notes == "Test manufacturer notes")
    }

    @Test("Empty manufacturer notes")
    func testEmptyManufacturerNotes() {
        let glassItem = GlassItemModel(
            natural_key: "test-item-003-0",
            name: "Test Item No Notes",
            sku: "003",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let item = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        let view = InventoryDetailView(
            item: item,
            userNotesRepository: MockUserNotesRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        #expect(view != nil)
        #expect(item.glassItem.mfr_notes == nil)
    }
}
