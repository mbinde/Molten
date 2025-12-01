//
//  LabelDesignerViewTests.swift
//  MoltenTests
//
//  Tests for LabelDesignerView - specifically label count calculation logic
//  for weight-based inventory types (frit, powder, enamel)
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
@testable import Molten

@Suite("LabelDesignerView Tests")
@MainActor
struct LabelDesignerViewTests {

    // MARK: - Helper Methods

    /// Create a test inventory item with the given type and quantity
    private func createTestItem(
        stableId: String = "test-mfr-sku-0",
        name: String = "Test Item",
        type: String,
        quantity: Double,
        containerCount: Double? = nil
    ) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: "SKU-001",
            manufacturer: "test",
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "active",
            image_url: nil,
            image_path: nil,
            image_thumb_path: nil,
            dominant_colors: nil
        )

        let inventory = [
            InventoryModel(
                id: UUID(),
                item_stable_id: stableId,
                type: type,
                subtype: nil,
                subsubtype: nil,
                dimensions: nil,
                quantity: quantity,
                containerCount: containerCount,
                location: "Studio"
            )
        ]

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )
    }

    // MARK: - Weight-Based Type Detection Tests

    @Test("Should identify frit as weight-based type")
    func testFritIsWeightBased() {
        let item = createTestItem(type: "frit", quantity: 100)
        let inventory = item.inventory.first!

        #expect(inventory.isWeightBasedType == true)
    }

    @Test("Should identify powder as weight-based type")
    func testPowderIsWeightBased() {
        let item = createTestItem(type: "powder", quantity: 50)
        let inventory = item.inventory.first!

        #expect(inventory.isWeightBasedType == true)
    }

    @Test("Should identify enamel as weight-based type")
    func testEnamelIsWeightBased() {
        let item = createTestItem(type: "enamel", quantity: 25)
        let inventory = item.inventory.first!

        #expect(inventory.isWeightBasedType == true)
    }

    @Test("Should identify flakes as weight-based type")
    func testFlakesIsWeightBased() {
        let item = createTestItem(type: "flakes", quantity: 30)
        let inventory = item.inventory.first!

        #expect(inventory.isWeightBasedType == true)
    }

    @Test("Should identify rod as NOT weight-based type")
    func testRodIsNotWeightBased() {
        let item = createTestItem(type: "rod", quantity: 10)
        let inventory = item.inventory.first!

        #expect(inventory.isWeightBasedType == false)
    }

    @Test("Should identify tube as NOT weight-based type")
    func testTubeIsNotWeightBased() {
        let item = createTestItem(type: "tube", quantity: 5)
        let inventory = item.inventory.first!

        #expect(inventory.isWeightBasedType == false)
    }

    @Test("Should identify sheet as NOT weight-based type")
    func testSheetIsNotWeightBased() {
        let item = createTestItem(type: "sheet", quantity: 3)
        let inventory = item.inventory.first!

        #expect(inventory.isWeightBasedType == false)
    }

    // MARK: - Label Count Calculation Tests

    @Test("Should use quantity directly for rod types (10 rods = 10 labels)")
    func testRodLabelCount() {
        let item = createTestItem(type: "rod", quantity: 10)

        // For non-weight-based types, label count = quantity
        let labelCount = LabelCountCalculator.calculateLabelCount(for: item)

        #expect(labelCount == 10)
    }

    @Test("Should use quantity directly for tube types (5 tubes = 5 labels)")
    func testTubeLabelCount() {
        let item = createTestItem(type: "tube", quantity: 5)

        let labelCount = LabelCountCalculator.calculateLabelCount(for: item)

        #expect(labelCount == 5)
    }

    @Test("Should default to 1 label for weight-based types without user-specified count")
    func testFritDefaultLabelCount() {
        let item = createTestItem(type: "frit", quantity: 100)

        // For weight-based types without user-specified count, default to 1
        let labelCount = LabelCountCalculator.calculateLabelCount(for: item)

        #expect(labelCount == 1)
    }

    @Test("Should use containerCount for weight-based types when available")
    func testFritWithContainerCount() {
        let item = createTestItem(type: "frit", quantity: 100, containerCount: 3)

        // For weight-based types with containerCount, use that
        let labelCount = LabelCountCalculator.calculateLabelCount(for: item)

        #expect(labelCount == 3)
    }

    @Test("Should use user-override count for weight-based types")
    func testFritWithUserOverride() {
        let item = createTestItem(stableId: "test-frit-1", type: "frit", quantity: 100, containerCount: 3)
        var overrides: [String: Int] = [:]
        overrides["test-frit-1:frit"] = 5  // User wants 5 labels

        let labelCount = LabelCountCalculator.calculateLabelCount(for: item, userOverrides: overrides)

        #expect(labelCount == 5)
    }

    // MARK: - Multiple Inventory Records Tests

    @Test("Should sum label counts across multiple inventory types")
    func testMultipleInventoryTypes() {
        let glassItem = GlassItemModel(
            stable_id: "test-multi-type",
            name: "Multi Type Item",
            sku: "SKU-002",
            manufacturer: "test",
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "active",
            image_url: nil,
            image_path: nil,
            image_thumb_path: nil,
            dominant_colors: nil
        )

        // Item has both rods (5) and frit (2 jars)
        let inventory = [
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-multi-type",
                type: "rod",
                subtype: nil,
                subsubtype: nil,
                dimensions: nil,
                quantity: 5,
                containerCount: nil,
                location: "Studio"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-multi-type",
                type: "frit",
                subtype: nil,
                subsubtype: nil,
                dimensions: nil,
                quantity: 100,
                containerCount: 2,
                location: "Studio"
            )
        ]

        let item = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )

        // 5 rods + 2 frit jars = 7 labels
        let labelCount = LabelCountCalculator.calculateTotalLabelCount(for: [item])

        #expect(labelCount == 7)
    }

    // MARK: - Weight-Based Items Detection Tests

    @Test("Should identify items needing label count input")
    func testIdentifyWeightBasedItems() {
        let rodItem = createTestItem(stableId: "test-rod", type: "rod", quantity: 10)
        let fritItem = createTestItem(stableId: "test-frit", type: "frit", quantity: 100)
        let powderItem = createTestItem(stableId: "test-powder", type: "powder", quantity: 50)

        let items = [rodItem, fritItem, powderItem]

        let weightBasedItems = LabelCountCalculator.itemsNeedingLabelCountInput(from: items)

        // Should include frit and powder, but not rod
        #expect(weightBasedItems.count == 2)
        #expect(weightBasedItems.contains { $0.item.catalogItem.stable_id == "test-frit" })
        #expect(weightBasedItems.contains { $0.item.catalogItem.stable_id == "test-powder" })
        #expect(!weightBasedItems.contains { $0.item.catalogItem.stable_id == "test-rod" })
    }

    @Test("Should not need input for weight-based items with containerCount set")
    func testWeightBasedWithContainerCountNoInput() {
        // Frit item with containerCount already set - no need to ask
        let fritWithJars = createTestItem(stableId: "test-frit", type: "frit", quantity: 100, containerCount: 3)

        let items = [fritWithJars]

        let weightBasedItems = LabelCountCalculator.itemsNeedingLabelCountInput(from: items)

        // Should be empty - containerCount is already set
        #expect(weightBasedItems.isEmpty)
    }

    @Test("Should need input for weight-based items without containerCount")
    func testWeightBasedWithoutContainerCountNeedsInput() {
        // Frit item without containerCount - need to ask
        let fritNoJars = createTestItem(stableId: "test-frit", type: "frit", quantity: 100, containerCount: nil)

        let items = [fritNoJars]

        let weightBasedItems = LabelCountCalculator.itemsNeedingLabelCountInput(from: items)

        // Should include the frit item
        #expect(weightBasedItems.count == 1)
        #expect(weightBasedItems.first?.item.catalogItem.stable_id == "test-frit")
    }

    // MARK: - UUID-Based Override Tests

    /// Create a test inventory item with a specific UUID for testing UUID-based overrides
    private func createTestItemWithUUID(
        inventoryId: UUID,
        stableId: String = "test-mfr-sku-0",
        name: String = "Test Item",
        type: String,
        quantity: Double,
        containerCount: Double? = nil
    ) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: "SKU-001",
            manufacturer: "test",
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "active",
            image_url: nil,
            image_path: nil,
            image_thumb_path: nil,
            dominant_colors: nil
        )

        let inventory = [
            InventoryModel(
                id: inventoryId,
                item_stable_id: stableId,
                type: type,
                subtype: nil,
                subsubtype: nil,
                dimensions: nil,
                quantity: quantity,
                containerCount: containerCount,
                location: "Studio"
            )
        ]

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )
    }

    @Test("Should use UUID-based override when provided")
    func testUUIDBasedOverride() {
        let inventoryId = UUID()
        let item = createTestItemWithUUID(inventoryId: inventoryId, type: "rod", quantity: 10)

        var uuidOverrides: [UUID: Int] = [:]
        uuidOverrides[inventoryId] = 3  // Override to 3 labels

        let labelCount = LabelCountCalculator.calculateLabelCount(
            for: item,
            inventoryRecordOverrides: uuidOverrides
        )

        #expect(labelCount == 3)
    }

    @Test("UUID override takes priority over type-based override")
    func testUUIDOverridePriorityOverTypeOverride() {
        let inventoryId = UUID()
        let item = createTestItemWithUUID(
            inventoryId: inventoryId,
            stableId: "test-rod-1",
            type: "rod",
            quantity: 10
        )

        var typeOverrides: [String: Int] = [:]
        typeOverrides["test-rod-1:rod"] = 5  // Type-based override: 5

        var uuidOverrides: [UUID: Int] = [:]
        uuidOverrides[inventoryId] = 2  // UUID-based override: 2 (should win)

        let labelCount = LabelCountCalculator.calculateLabelCount(
            for: item,
            userOverrides: typeOverrides,
            inventoryRecordOverrides: uuidOverrides
        )

        // UUID override should take priority
        #expect(labelCount == 2)
    }

    @Test("Should use type override when no UUID override exists")
    func testFallbackToTypeOverride() {
        let inventoryId = UUID()
        let item = createTestItemWithUUID(
            inventoryId: inventoryId,
            stableId: "test-rod-1",
            type: "rod",
            quantity: 10
        )

        var typeOverrides: [String: Int] = [:]
        typeOverrides["test-rod-1:rod"] = 5  // Type-based override: 5

        // No UUID override provided
        let labelCount = LabelCountCalculator.calculateLabelCount(
            for: item,
            userOverrides: typeOverrides,
            inventoryRecordOverrides: [:]
        )

        #expect(labelCount == 5)
    }

    @Test("Should use default when no overrides exist")
    func testFallbackToDefault() {
        let inventoryId = UUID()
        let item = createTestItemWithUUID(inventoryId: inventoryId, type: "rod", quantity: 10)

        // No overrides
        let labelCount = LabelCountCalculator.calculateLabelCount(
            for: item,
            userOverrides: [:],
            inventoryRecordOverrides: [:]
        )

        // Default for rod is quantity (10)
        #expect(labelCount == 10)
    }

    @Test("UUID override works for weight-based types")
    func testUUIDOverrideForWeightBased() {
        let inventoryId = UUID()
        let item = createTestItemWithUUID(
            inventoryId: inventoryId,
            type: "frit",
            quantity: 100,
            containerCount: 3  // Has 3 jars
        )

        var uuidOverrides: [UUID: Int] = [:]
        uuidOverrides[inventoryId] = 1  // Only print 1 label

        let labelCount = LabelCountCalculator.calculateLabelCount(
            for: item,
            inventoryRecordOverrides: uuidOverrides
        )

        // Should use UUID override (1), not containerCount (3)
        #expect(labelCount == 1)
    }

    // MARK: - defaultLabelCount Tests

    @Test("defaultLabelCount returns quantity for count-based types")
    func testDefaultLabelCountForRod() {
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: "test-item",
            type: "rod",
            subtype: nil,
            subsubtype: nil,
            dimensions: nil,
            quantity: 10,
            containerCount: nil,
            location: "Studio"
        )

        #expect(inventory.defaultLabelCount == 10)
    }

    @Test("defaultLabelCount returns containerCount for weight-based types with jars")
    func testDefaultLabelCountForFritWithJars() {
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: "test-item",
            type: "frit",
            subtype: nil,
            subsubtype: nil,
            dimensions: nil,
            quantity: 100,
            containerCount: 3,
            location: "Studio"
        )

        #expect(inventory.defaultLabelCount == 3)
    }

    @Test("defaultLabelCount returns 1 for weight-based types without jars")
    func testDefaultLabelCountForFritNoJars() {
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: "test-item",
            type: "frit",
            subtype: nil,
            subsubtype: nil,
            dimensions: nil,
            quantity: 100,
            containerCount: nil,
            location: "Studio"
        )

        #expect(inventory.defaultLabelCount == 1)
    }

    @Test("defaultLabelCount returns 1 for weight-based types with zero jars")
    func testDefaultLabelCountForFritZeroJars() {
        let inventory = InventoryModel(
            id: UUID(),
            item_stable_id: "test-item",
            type: "frit",
            subtype: nil,
            subsubtype: nil,
            dimensions: nil,
            quantity: 100,
            containerCount: 0,
            location: "Studio"
        )

        #expect(inventory.defaultLabelCount == 1)
    }
}
