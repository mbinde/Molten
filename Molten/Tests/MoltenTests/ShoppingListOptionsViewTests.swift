//
//  ShoppingListOptionsViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//  Comprehensive tests for ShoppingListOptionsView
//
//  ⚠️ IMPORTANT: This file must be added to the FlameworkerTests target via Xcode
//  to ensure proper target membership. Do NOT add via command line.
//
//  Instructions:
//  1. Open Flameworker.xcodeproj in Xcode
//  2. Add this file to Tests/FlameworkerTests/
//  3. In the file inspector, ensure Target Membership is set to "FlameworkerTests" ONLY
//  4. Remove the .todo extension
//  5. Build and run tests
//

import Foundation

// Standard test framework imports pattern
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

// Use Swift Testing if available
#if canImport(Testing)

@Suite("ShoppingListOptionsView Tests")
struct ShoppingListOptionsViewTests {

    // MARK: - Validation Tests

    @Test("Should reject empty quantity")
    func testRejectEmptyQuantity() {
        let quantity = ""
        let quantityValue = Double(quantity)

        #expect(quantityValue == nil)
    }

    @Test("Should reject non-numeric quantity")
    func testRejectNonNumericQuantity() {
        let quantity = "abc"
        let quantityValue = Double(quantity)

        #expect(quantityValue == nil)
    }

    @Test("Should reject zero quantity")
    func testRejectZeroQuantity() {
        let quantity = "0"
        guard let quantityValue = Double(quantity) else {
            Issue.record("Failed to parse quantity")
            return
        }

        #expect(quantityValue <= 0)
    }

    @Test("Should reject negative quantity")
    func testRejectNegativeQuantity() {
        let quantity = "-5"
        guard let quantityValue = Double(quantity) else {
            Issue.record("Failed to parse quantity")
            return
        }

        #expect(quantityValue <= 0)
    }

    @Test("Should accept valid integer quantity")
    func testAcceptIntegerQuantity() {
        let quantity = "10"
        guard let quantityValue = Double(quantity) else {
            Issue.record("Failed to parse quantity")
            return
        }

        #expect(quantityValue > 0)
        #expect(quantityValue == 10.0)
    }

    @Test("Should accept valid decimal quantity")
    func testAcceptDecimalQuantity() {
        let quantity = "10.5"
        guard let quantityValue = Double(quantity) else {
            Issue.record("Failed to parse quantity")
            return
        }

        #expect(quantityValue > 0)
        #expect(quantityValue == 10.5)
    }

    // MARK: - Store Field Tests

    @Test("Should trim whitespace from store name")
    func testTrimStoreWhitespace() {
        let store = "  Frantz Art Glass  "
        let storeValue = store.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalStore = storeValue.isEmpty ? nil : storeValue

        #expect(finalStore == "Frantz Art Glass")
    }

    @Test("Should convert empty store to nil")
    func testEmptyStoreToNil() {
        let store = ""
        let storeValue = store.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalStore = storeValue.isEmpty ? nil : storeValue

        #expect(finalStore == nil)
    }

    @Test("Should convert whitespace-only store to nil")
    func testWhitespaceStoreToNil() {
        let store = "   "
        let storeValue = store.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalStore = storeValue.isEmpty ? nil : storeValue

        #expect(finalStore == nil)
    }

    @Test("Should preserve valid store name")
    func testPreserveValidStoreName() {
        let store = "Olympic Color"
        let storeValue = store.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalStore = storeValue.isEmpty ? nil : storeValue

        #expect(finalStore == "Olympic Color")
    }

    // MARK: - Repository Integration Tests

    @Test("Should add item to shopping list with quantity only")
    func testAddItemQuantityOnly() async throws {
        let mockRepo = MockShoppingListRepository()

        // Add item with quantity only (no store)
        let item = try await mockRepo.addQuantity(
            10.0,
            toItem: "bullseye-0001-0",
            store: nil
        )

        #expect(item.quantity == 10.0)
        #expect(item.store == nil)
        #expect(item.item_natural_key == "bullseye-0001-0")
    }

    @Test("Should add item to shopping list with quantity and store")
    func testAddItemWithStore() async throws {
        let mockRepo = MockShoppingListRepository()

        // Add item with quantity and store
        let item = try await mockRepo.addQuantity(
            5.0,
            toItem: "cim-123-0",
            store: "Frantz Art Glass"
        )

        #expect(item.quantity == 5.0)
        #expect(item.store == "Frantz Art Glass")
        #expect(item.item_natural_key == "cim-123-0")
    }

    @Test("Should update existing item quantity")
    func testUpdateExistingQuantity() async throws {
        let mockRepo = MockShoppingListRepository()

        // Create initial item
        let initial = try await mockRepo.addQuantity(
            5.0,
            toItem: "ef-456-0",
            store: "Olympic Color"
        )

        #expect(initial.quantity == 5.0)

        // Add more quantity to same item/store
        let updated = try await mockRepo.addQuantity(
            3.0,
            toItem: "ef-456-0",
            store: "Olympic Color"
        )

        #expect(updated.quantity == 8.0) // Should be 5 + 3
        #expect(updated.item_natural_key == "ef-456-0")
        #expect(updated.store == "Olympic Color")
    }

    @Test("Should create separate entries for different stores")
    func testSeparateEntriesPerStore() async throws {
        let mockRepo = MockShoppingListRepository()

        // Add same item to two different stores
        let item1 = try await mockRepo.addQuantity(
            10.0,
            toItem: "bullseye-0001-0",
            store: "Frantz Art Glass"
        )

        let item2 = try await mockRepo.addQuantity(
            5.0,
            toItem: "bullseye-0001-0",
            store: "Olympic Color"
        )

        #expect(item1.store == "Frantz Art Glass")
        #expect(item2.store == "Olympic Color")
        #expect(item1.quantity == 10.0)
        #expect(item2.quantity == 5.0)

        // Fetch all items for this natural key
        let allItems = try await mockRepo.fetchAllItems()
        let itemsForKey = allItems.filter { $0.item_natural_key == "bullseye-0001-0" }

        #expect(itemsForKey.count == 2)
    }

    // MARK: - Edge Cases

    @Test("Should handle very large quantities")
    func testVeryLargeQuantity() async throws {
        let mockRepo = MockShoppingListRepository()

        let item = try await mockRepo.addQuantity(
            999999.99,
            toItem: "test-item",
            store: nil
        )

        #expect(item.quantity == 999999.99)
    }

    @Test("Should handle very small decimal quantities")
    func testVerySmallQuantity() async throws {
        let mockRepo = MockShoppingListRepository()

        let item = try await mockRepo.addQuantity(
            0.01,
            toItem: "test-item",
            store: nil
        )

        #expect(item.quantity == 0.01)
    }

    @Test("Should handle store names with special characters")
    func testStoreNamesWithSpecialChars() async throws {
        let mockRepo = MockShoppingListRepository()

        let item = try await mockRepo.addQuantity(
            5.0,
            toItem: "test-item",
            store: "Art & Glass Co."
        )

        #expect(item.store == "Art & Glass Co.")
    }

    @Test("Should handle long store names")
    func testLongStoreName() async throws {
        let mockRepo = MockShoppingListRepository()

        let longStore = "The International Glass Art Supply Company and Workshop Emporium"
        let item = try await mockRepo.addQuantity(
            5.0,
            toItem: "test-item",
            store: longStore
        )

        #expect(item.store == longStore)
    }

    // MARK: - ItemShoppingModel Validation

    @Test("ItemShoppingModel should validate quantity > 0")
    func testModelQuantityValidation() {
        let validModel = ItemShoppingModel(
            item_natural_key: "test-item",
            quantity: 10.0,
            store: nil
        )

        #expect(validModel.isValid)
        #expect(validModel.hasValidQuantity)
    }

    @Test("ItemShoppingModel should reject negative quantity")
    func testModelRejectNegativeQuantity() {
        // Model enforces non-negative in init
        let model = ItemShoppingModel(
            item_natural_key: "test-item",
            quantity: -5.0,
            store: nil
        )

        // Init should clamp to 0
        #expect(model.quantity == 0.0)
        #expect(!model.isValid) // Invalid because quantity must be > 0
    }

    @Test("ItemShoppingModel should trim natural key")
    func testModelTrimNaturalKey() {
        let model = ItemShoppingModel(
            item_natural_key: "  bullseye-0001-0  ",
            quantity: 5.0,
            store: nil
        )

        #expect(model.item_natural_key == "bullseye-0001-0")
    }

    @Test("ItemShoppingModel should trim store name")
    func testModelTrimStoreName() {
        let model = ItemShoppingModel(
            item_natural_key: "test-item",
            quantity: 5.0,
            store: "  Frantz Art Glass  "
        )

        #expect(model.store == "Frantz Art Glass")
    }
}

#else

#if canImport(XCTest)
import XCTest

// Fallback to XCTest if Swift Testing is not available
class ShoppingListOptionsViewTests: XCTestCase {

    func testRejectEmptyQuantity() {
        let quantity = ""
        let quantityValue = Double(quantity)

        XCTAssertNil(quantityValue)
    }

    func testAcceptValidQuantity() {
        let quantity = "10"
        let quantityValue = Double(quantity)

        XCTAssertNotNil(quantityValue)
        XCTAssertEqual(quantityValue, 10.0)
    }

    func testTrimStoreWhitespace() {
        let store = "  Frantz Art Glass  "
        let storeValue = store.trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(storeValue, "Frantz Art Glass")
    }

    func testAddItemQuantityOnly() async throws {
        let mockRepo = MockShoppingListRepository()

        let item = try await mockRepo.addQuantity(
            10.0,
            toItem: "bullseye-0001-0",
            store: nil
        )

        XCTAssertEqual(item.quantity, 10.0)
        XCTAssertNil(item.store)
    }

    func testUpdateExistingQuantity() async throws {
        let mockRepo = MockShoppingListRepository()

        _ = try await mockRepo.addQuantity(
            5.0,
            toItem: "ef-456-0",
            store: "Olympic Color"
        )

        let updated = try await mockRepo.addQuantity(
            3.0,
            toItem: "ef-456-0",
            store: "Olympic Color"
        )

        XCTAssertEqual(updated.quantity, 8.0)
    }
}
#endif

#endif
