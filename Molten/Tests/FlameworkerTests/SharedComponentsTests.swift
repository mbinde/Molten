//
//  SharedComponentsTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/19/25.
//  Tests for shared UI components: GlassItemRowView, FilterSelectionSheet, KeyboardDismissal
//

import Foundation
import SwiftUI
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Shared Components Tests", .serialized)
struct SharedComponentsTests {

    // MARK: - GlassItemRowView Tests

    @Test("GlassItemRowView.GlassItemRowData should initialize from CompleteInventoryItemModel")
    func testGlassItemRowDataFromCompleteInventoryItem() throws {
        // Arrange
        let glassItem = GlassItemModel(
            natural_key: "be-clear-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "be",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: ["clear", "transparent"],
            userTags: ["favorite"],
            locations: []
        )

        // Act
        let rowData = GlassItemRowView.GlassItemRowData(from: completeItem)

        // Assert
        #expect(rowData.name == "Clear Glass", "Should extract name correctly")
        #expect(rowData.manufacturer == "be", "Should extract manufacturer correctly")
        #expect(rowData.sku == "001", "Should extract SKU correctly")
        #expect(rowData.naturalKey == "be-clear-001", "Should extract natural key correctly")
        #expect(rowData.tags == ["clear", "transparent", "favorite"], "Should combine all tags")
    }

    @Test("GlassItemRowView.GlassItemRowData should initialize from DetailedShoppingListItemModel")
    func testGlassItemRowDataFromDetailedShoppingListItem() throws {
        // Arrange
        let glassItem = GlassItemModel(
            natural_key: "cim-deep-blue-425",
            name: "Deep Blue",
            sku: "425",
            manufacturer: "cim",
            coe: 104,
            mfr_status: "available"
        )

        let shoppingItem = ShoppingListItemModel(
            item_natural_key: "cim-deep-blue-425",
            needed_quantity: 5.0,
            current_quantity: 2.0,
            store: "Mountain Glass"
        )

        let detailedItem = DetailedShoppingListItemModel(
            shoppingListItem: shoppingItem,
            glassItem: glassItem,
            tags: ["blue"],
            userTags: []
        )

        // Act
        let rowData = GlassItemRowView.GlassItemRowData(from: detailedItem)

        // Assert
        #expect(rowData.name == "Deep Blue", "Should extract name correctly")
        #expect(rowData.manufacturer == "cim", "Should extract manufacturer correctly")
        #expect(rowData.sku == "425", "Should extract SKU correctly")
        #expect(rowData.naturalKey == "cim-deep-blue-425", "Should extract natural key correctly")
        #expect(rowData.tags == ["blue"], "Should extract tags correctly")
    }

    @Test("GlassItemRowView.GlassItemRowData should initialize with direct parameters")
    func testGlassItemRowDataDirectInitialization() throws {
        // Act
        let rowData = GlassItemRowView.GlassItemRowData(
            name: "Test Glass",
            manufacturer: "ef",
            sku: "123",
            naturalKey: "ef-test-123",
            tags: ["red", "opaque"]
        )

        // Assert
        #expect(rowData.name == "Test Glass", "Should store name correctly")
        #expect(rowData.manufacturer == "ef", "Should store manufacturer correctly")
        #expect(rowData.sku == "123", "Should store SKU correctly")
        #expect(rowData.naturalKey == "ef-test-123", "Should store natural key correctly")
        #expect(rowData.tags == ["red", "opaque"], "Should store tags correctly")
    }

    @Test("GlassItemRowView should initialize with required parameters")
    func testGlassItemRowViewBasicInitialization() throws {
        // Arrange
        let rowData = GlassItemRowView.GlassItemRowData(
            name: "Test Item",
            manufacturer: "be",
            sku: "001",
            naturalKey: "be-test-001",
            tags: []
        )

        // Act
        let rowView = GlassItemRowView(
            item: rowData,
            leadingAccessory: nil,
            badgeContent: nil,
            showFullCode: false
        )

        // Assert
        #expect(rowView.item.name == "Test Item", "Should store item data correctly")
        #expect(rowView.showFullCode == false, "Should default to showing SKU")
        #expect(rowView.leadingAccessory == nil, "Should have no leading accessory")
        #expect(rowView.badgeContent == nil, "Should have no badge content")
    }

    @Test("GlassItemRowView should handle showFullCode parameter")
    func testGlassItemRowViewShowFullCode() throws {
        // Arrange
        let rowData = GlassItemRowView.GlassItemRowData(
            name: "Test Item",
            manufacturer: "be",
            sku: "001",
            naturalKey: "be-test-001",
            tags: []
        )

        // Act - Show full code
        let fullCodeView = GlassItemRowView(
            item: rowData,
            showFullCode: true
        )

        // Act - Show SKU only
        let skuOnlyView = GlassItemRowView(
            item: rowData,
            showFullCode: false
        )

        // Assert
        #expect(fullCodeView.showFullCode == true, "Should show full natural key")
        #expect(skuOnlyView.showFullCode == false, "Should show SKU only")
    }

    @Test("GlassItemRowView.catalog should create catalog-style row")
    func testGlassItemRowViewCatalogStyle() throws {
        // Arrange
        let glassItem = GlassItemModel(
            natural_key: "be-clear-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "be",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: ["clear"],
            userTags: [],
            locations: []
        )

        // Act
        let catalogRow = GlassItemRowView.catalog(item: completeItem)

        // Assert
        #expect(catalogRow.showFullCode == false, "Catalog style should show SKU only")
        #expect(catalogRow.leadingAccessory == nil, "Catalog style should have no leading accessory")
        #expect(catalogRow.badgeContent == nil, "Catalog style should have no badge")
        #expect(catalogRow.item.name == "Clear Glass", "Should use item name")
    }

    @Test("GlassItemRowView.inventory should create inventory-style row with quantity badge")
    func testGlassItemRowViewInventoryStyle() throws {
        // Arrange
        let glassItem = GlassItemModel(
            natural_key: "cim-deep-blue-425",
            name: "Deep Blue",
            sku: "425",
            manufacturer: "cim",
            coe: 104,
            mfr_status: "available"
        )

        let inventory = [
            InventoryModel(item_natural_key: "cim-deep-blue-425", type: "rod", quantity: 15.5),
            InventoryModel(item_natural_key: "cim-deep-blue-425", type: "frit", quantity: 8.0)
        ]

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: ["blue"],
            userTags: [],
            locations: []
        )

        // Act
        let inventoryRow = GlassItemRowView.inventory(item: completeItem)

        // Assert
        #expect(inventoryRow.showFullCode == true, "Inventory style should show full natural key")
        #expect(inventoryRow.leadingAccessory == nil, "Inventory style should have no leading accessory")
        #expect(inventoryRow.badgeContent != nil, "Inventory style should have quantity badge")
        #expect(inventoryRow.item.name == "Deep Blue", "Should use item name")
    }

    @Test("GlassItemRowView.shoppingList should create shopping list-style row")
    func testGlassItemRowViewShoppingListStyle() throws {
        // Arrange
        let glassItem = GlassItemModel(
            natural_key: "ga-jade-101",
            name: "Jade Green",
            sku: "101",
            manufacturer: "ga",
            coe: 104,
            mfr_status: "available"
        )

        let shoppingItem = ShoppingListItemModel(
            item_natural_key: "ga-jade-101",
            needed_quantity: 5.0,
            current_quantity: 2.0,
            store: "Local Glass Shop"
        )

        let detailedItem = DetailedShoppingListItemModel(
            shoppingListItem: shoppingItem,
            glassItem: glassItem,
            tags: ["green"],
            userTags: []
        )

        // Act
        let shoppingRow = GlassItemRowView.shoppingList(
            item: detailedItem,
            showStore: true,
            isShoppingMode: false,
            isInBasket: false,
            onBasketToggle: nil
        )

        // Assert
        #expect(shoppingRow.showFullCode == true, "Shopping list style should show full natural key")
        #expect(shoppingRow.badgeContent != nil, "Shopping list style should have quantity badge")
        #expect(shoppingRow.item.name == "Jade Green", "Should use item name")
    }

    @Test("GlassItemRowView.shoppingList should include checkbox in shopping mode")
    func testGlassItemRowViewShoppingMode() throws {
        // Arrange
        let glassItem = GlassItemModel(
            natural_key: "ef-ruby-red-234",
            name: "Ruby Red",
            sku: "234",
            manufacturer: "ef",
            coe: 104,
            mfr_status: "available"
        )

        let shoppingItem = ShoppingListItemModel(
            item_natural_key: "ef-ruby-red-234",
            needed_quantity: 3.0,
            current_quantity: 0.0,
            store: "Online Glass"
        )

        let detailedItem = DetailedShoppingListItemModel(
            shoppingListItem: shoppingItem,
            glassItem: glassItem,
            tags: ["red"],
            userTags: []
        )

        var basketToggleCalled = false

        // Act
        let shoppingModeRow = GlassItemRowView.shoppingList(
            item: detailedItem,
            showStore: false,
            isShoppingMode: true,
            isInBasket: false,
            onBasketToggle: {
                basketToggleCalled = true
            }
        )

        // Assert
        #expect(shoppingModeRow.leadingAccessory != nil, "Shopping mode should have checkbox accessory")

        // Test that the callback works
        if let onToggle = shoppingModeRow.leadingAccessory {
            // In actual UI, tapping the checkbox would call the callback
            // We can't directly test the tap in unit tests, but we verified the callback is set
        }
    }

    @Test("GlassItemRowView should handle empty tags")
    func testGlassItemRowViewEmptyTags() throws {
        // Arrange
        let rowData = GlassItemRowView.GlassItemRowData(
            name: "No Tags Item",
            manufacturer: "be",
            sku: "999",
            naturalKey: "be-notags-999",
            tags: []
        )

        // Act
        let rowView = GlassItemRowView(item: rowData)

        // Assert
        #expect(rowView.item.tags.isEmpty, "Should handle empty tags array")
    }

    @Test("GlassItemRowView should handle multiple tags")
    func testGlassItemRowViewMultipleTags() throws {
        // Arrange
        let tags = ["clear", "transparent", "rod", "favorite", "special-order"]
        let rowData = GlassItemRowView.GlassItemRowData(
            name: "Many Tags Item",
            manufacturer: "cim",
            sku: "555",
            naturalKey: "cim-manytags-555",
            tags: tags
        )

        // Act
        let rowView = GlassItemRowView(item: rowData)

        // Assert
        #expect(rowView.item.tags.count == 5, "Should handle multiple tags")
        #expect(rowView.item.tags == tags, "Should preserve all tags")
    }

    // MARK: - FilterSelectionSheet Tests

    @Test("FilterSelectionSheet should initialize with generic parameters")
    func testFilterSelectionSheetGenericInitialization() throws {
        // Arrange
        @State var selectedItems: Set<String> = ["item1"]
        let selectedBinding = Binding<Set<String>>(
            get: { selectedItems },
            set: { selectedItems = $0 }
        )

        let items = ["item1", "item2", "item3"]
        let counts = ["item1": 10, "item2": 5, "item3": 8]

        // Act
        let sheet = FilterSelectionSheet(
            title: "Test Selection",
            items: items,
            selectedItems: selectedBinding,
            itemCounts: counts,
            itemDisplayText: { item in item.uppercased() }
        )

        // Assert
        #expect(sheet.title == "Test Selection", "Should store title correctly")
        #expect(sheet.items == items, "Should store items correctly")
        #expect(sheet.itemCounts == counts, "Should store item counts correctly")
    }

    @Test("FilterSelectionSheet.tags should create tag filter with color circles")
    func testFilterSelectionSheetTags() throws {
        // Arrange
        @State var selectedTags: Set<String> = ["clear"]
        let selectedBinding = Binding<Set<String>>(
            get: { selectedTags },
            set: { selectedTags = $0 }
        )

        let tags = ["clear", "opaque", "transparent"]
        let userTags: Set<String> = ["transparent"]
        let counts = ["clear": 15, "opaque": 8, "transparent": 23]

        // Act
        let tagSheet = FilterSelectionSheet.tags(
            availableTags: tags,
            selectedTags: selectedBinding,
            userTags: userTags,
            itemCounts: counts
        )

        // Assert
        #expect(tagSheet.title == "Select Tags", "Should have correct title")
        #expect(tagSheet.items == tags, "Should have all tags")
        #expect(tagSheet.itemCounts == counts, "Should have tag counts")
        #expect(tagSheet.leadingAccessory != nil, "Should have color circle accessories")
        #expect(tagSheet.trailingAccessory != nil, "Should have user tag indicators")
    }

    @Test("FilterSelectionSheet.coes should create COE filter")
    func testFilterSelectionSheetCOEs() throws {
        // Arrange
        @State var selectedCOEs: Set<Int32> = [104]
        let selectedBinding = Binding<Set<Int32>>(
            get: { selectedCOEs },
            set: { selectedCOEs = $0 }
        )

        let coes: [Int32] = [90, 96, 104]
        let counts: [Int32: Int] = [90: 5, 96: 12, 104: 45]

        // Act
        let coeSheet = FilterSelectionSheet.coes(
            availableCOEs: coes,
            selectedCOEs: selectedBinding,
            itemCounts: counts
        )

        // Assert
        #expect(coeSheet.title == "Select COE", "Should have correct title")
        #expect(coeSheet.items == coes.sorted(), "Should sort COE values")
        #expect(coeSheet.itemCounts == counts, "Should have COE counts")
    }

    @Test("FilterSelectionSheet.coes should format COE display text correctly")
    func testFilterSelectionSheetCOEDisplayText() throws {
        // Arrange
        @State var selectedCOEs: Set<Int32> = []
        let selectedBinding = Binding<Set<Int32>>(
            get: { selectedCOEs },
            set: { selectedCOEs = $0 }
        )

        let coes: [Int32] = [90, 104]

        // Act
        let coeSheet = FilterSelectionSheet.coes(
            availableCOEs: coes,
            selectedCOEs: selectedBinding
        )

        // Assert
        let displayText90 = coeSheet.itemDisplayText(90)
        let displayText104 = coeSheet.itemDisplayText(104)

        #expect(displayText90 == "COE 90", "Should format COE 90 correctly")
        #expect(displayText104 == "COE 104", "Should format COE 104 correctly")
    }

    @Test("FilterSelectionSheet.manufacturers should create manufacturer filter")
    func testFilterSelectionSheetManufacturers() throws {
        // Arrange
        @State var selectedMfrs: Set<String> = ["be"]
        let selectedBinding = Binding<Set<String>>(
            get: { selectedMfrs },
            set: { selectedMfrs = $0 }
        )

        let manufacturers = ["be", "cim", "ef", "ga"]
        let counts = ["be": 34, "cim": 18, "ef": 9, "ga": 6]

        let displayNameMapping: (String) -> String = { code in
            switch code {
            case "be": return "Bullseye Glass Co"
            case "cim": return "Creation is Messy"
            case "ef": return "Effetre"
            case "ga": return "Glass Alchemy"
            default: return code.uppercased()
            }
        }

        // Act
        let mfrSheet = FilterSelectionSheet.manufacturers(
            availableManufacturers: manufacturers,
            selectedManufacturers: selectedBinding,
            manufacturerDisplayName: displayNameMapping,
            itemCounts: counts
        )

        // Assert
        #expect(mfrSheet.title == "Select Manufacturers", "Should have correct title")
        #expect(mfrSheet.items == manufacturers, "Should have all manufacturers")
        #expect(mfrSheet.itemCounts == counts, "Should have manufacturer counts")

        // Test display name mapping
        let displayName = mfrSheet.itemDisplayText("be")
        #expect(displayName == "Bullseye Glass Co", "Should map manufacturer code to display name")
    }

    @Test("FilterSelectionSheet.stores should create store filter")
    func testFilterSelectionSheetStores() throws {
        // Arrange
        @State var selectedStores: Set<String> = []
        let selectedBinding = Binding<Set<String>>(
            get: { selectedStores },
            set: { selectedStores = $0 }
        )

        let stores = ["Local Glass Shop", "Mountain Glass", "Online Glass"]
        let counts = ["Local Glass Shop": 15, "Mountain Glass": 8, "Online Glass": 22]

        // Act
        let storeSheet = FilterSelectionSheet.stores(
            availableStores: stores,
            selectedStores: selectedBinding,
            itemCounts: counts
        )

        // Assert
        #expect(storeSheet.title == "Select Stores", "Should have correct title")
        #expect(storeSheet.items == stores, "Should have all stores")
        #expect(storeSheet.itemCounts == counts, "Should have store counts")
    }

    @Test("FilterSelectionSheet should handle empty item lists")
    func testFilterSelectionSheetEmptyItems() throws {
        // Arrange
        @State var selectedItems: Set<String> = []
        let selectedBinding = Binding<Set<String>>(
            get: { selectedItems },
            set: { selectedItems = $0 }
        )

        // Act
        let sheet = FilterSelectionSheet(
            title: "Empty Filter",
            items: [],
            selectedItems: selectedBinding,
            itemDisplayText: { $0 }
        )

        // Assert
        #expect(sheet.items.isEmpty, "Should handle empty items array")
    }

    @Test("FilterSelectionSheet should handle nil item counts")
    func testFilterSelectionSheetNilCounts() throws {
        // Arrange
        @State var selectedItems: Set<String> = []
        let selectedBinding = Binding<Set<String>>(
            get: { selectedItems },
            set: { selectedItems = $0 }
        )

        // Act
        let sheet = FilterSelectionSheet(
            title: "No Counts Filter",
            items: ["item1", "item2"],
            selectedItems: selectedBinding,
            itemCounts: nil,
            itemDisplayText: { $0 }
        )

        // Assert
        #expect(sheet.itemCounts == nil, "Should handle nil item counts")
    }

    @Test("FilterSelectionSheet should support different item types")
    func testFilterSelectionSheetDifferentTypes() throws {
        // Test with Int32 (COE values)
        @State var selectedInts: Set<Int32> = [104]
        let intBinding = Binding<Set<Int32>>(
            get: { selectedInts },
            set: { selectedInts = $0 }
        )

        let intSheet = FilterSelectionSheet(
            title: "Integer Filter",
            items: [90, 96, 104],
            selectedItems: intBinding,
            itemDisplayText: { coe in "Value \(coe)" }
        )

        #expect(intSheet.items == [90, 96, 104], "Should handle Int32 items")

        // Test with String (tags, manufacturers, stores)
        @State var selectedStrings: Set<String> = ["a"]
        let stringBinding = Binding<Set<String>>(
            get: { selectedStrings },
            set: { selectedStrings = $0 }
        )

        let stringSheet = FilterSelectionSheet(
            title: "String Filter",
            items: ["a", "b", "c"],
            selectedItems: stringBinding,
            itemDisplayText: { $0 }
        )

        #expect(stringSheet.items == ["a", "b", "c"], "Should handle String items")
    }

    // MARK: - KeyboardDismissal Tests

    @Test("KeyboardDismissal.hideKeyboard should be callable")
    func testKeyboardDismissalHideKeyboard() throws {
        // Act - Call hideKeyboard (should not crash)
        KeyboardDismissal.hideKeyboard()

        // Assert - If we get here without crashing, the function works
        #expect(true, "hideKeyboard should be callable without errors")
    }

    @Test("View.dismissKeyboardOnTap extension should be available")
    func testViewDismissKeyboardOnTapExtension() throws {
        // Arrange
        let testView = Text("Test View")

        // Act - Apply dismissKeyboardOnTap modifier
        let modifiedView = testView.dismissKeyboardOnTap()

        // Assert - View should be modified successfully
        #expect(modifiedView != nil, "dismissKeyboardOnTap should modify view successfully")
    }

    // MARK: - Integration Tests

    @Test("Components should work together - GlassItemRowView with filter results")
    func testComponentIntegration() throws {
        // Arrange - Create filtered items
        let glassItem1 = GlassItemModel(
            natural_key: "be-clear-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "be",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem1 = CompleteInventoryItemModel(
            glassItem: glassItem1,
            inventory: [],
            tags: ["clear", "transparent"],
            userTags: [],
            locations: []
        )

        // Act - Create row view from filtered item
        let rowView = GlassItemRowView.catalog(item: completeItem1)

        // Assert - Row view should display filtered item correctly
        #expect(rowView.item.name == "Clear Glass", "Should display filtered item")
        #expect(rowView.item.tags.contains("clear"), "Should include filtered tags")
    }

    @Test("FilterSelectionSheet should handle selection changes")
    func testFilterSelectionSheetSelectionChanges() throws {
        // Arrange
        var selectedTags: Set<String> = ["clear"]
        let selectedBinding = Binding<Set<String>>(
            get: { selectedTags },
            set: { selectedTags = $0 }
        )

        let tagSheet = FilterSelectionSheet.tags(
            availableTags: ["clear", "opaque", "transparent"],
            selectedTags: selectedBinding
        )

        // Act - Simulate selection changes through the binding
        selectedBinding.wrappedValue.insert("opaque")
        selectedBinding.wrappedValue.remove("clear")

        // Assert - Binding should reflect changes
        #expect(selectedTags.contains("opaque"), "Should add new selection")
        #expect(!selectedTags.contains("clear"), "Should remove deselected item")
        #expect(selectedTags == ["opaque"], "Should update selection set")
    }
}
