//
//  ItemShoppingModelTests.swift
//  FlameworkerTests
//
//  Tests for ItemShoppingModel domain model
//  Tests business logic, validation, and data transformations
//

import Testing
import Foundation
@testable import Flameworker

@Suite("ItemShoppingModel Tests")
struct ItemShoppingModelTests {

    // MARK: - Model Creation Tests

    @Test("Create with all fields")
    func testCreateWithAllFields() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz Art Glass",
            type: "rod",
            subtype: "standard",
            subsubtype: nil
        )

        #expect(item.item_natural_key == "cim-001-0")
        #expect(item.quantity == 5.0)
        #expect(item.store == "Frantz Art Glass")
        #expect(item.type == "rod")
        #expect(item.subtype == "standard")
        #expect(item.subsubtype == nil)
        #expect(item.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("Create with minimal fields")
    func testCreateWithMinimalFields() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 3.0
        )

        #expect(item.item_natural_key == "cim-001-0")
        #expect(item.quantity == 3.0)
        #expect(item.store == nil)
        #expect(item.type == nil)
        #expect(item.subtype == nil)
        #expect(item.subsubtype == nil)
    }

    @Test("Create with explicit ID")
    func testCreateWithExplicitId() {
        let customId = UUID()
        let item = ItemShoppingModel(
            id: customId,
            item_natural_key: "test-001",
            quantity: 1.0
        )

        #expect(item.id == customId)
    }

    @Test("Create with explicit date")
    func testCreateWithExplicitDate() {
        let customDate = Date(timeIntervalSince1970: 1000000)
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            dateAdded: customDate
        )

        #expect(item.dateAdded == customDate)
    }

    // MARK: - Business Logic Validation Tests

    @Test("Trims whitespace from natural key")
    func testTrimsNaturalKey() {
        let item = ItemShoppingModel(
            item_natural_key: "  cim-001-0  ",
            quantity: 1.0
        )

        #expect(item.item_natural_key == "cim-001-0")
    }

    @Test("Trims whitespace from store")
    func testTrimsStore() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            store: "  Frantz Art Glass  "
        )

        #expect(item.store == "Frantz Art Glass")
    }

    @Test("Trims whitespace from type/subtype/subsubtype")
    func testTrimsTypeFields() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            type: "  rod  ",
            subtype: "  standard  ",
            subsubtype: "  pulled  "
        )

        #expect(item.type == "rod")
        #expect(item.subtype == "standard")
        #expect(item.subsubtype == "pulled")
    }

    @Test("Clamps negative quantity to zero")
    func testClampsNegativeQuantity() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: -5.0
        )

        #expect(item.quantity == 0.0)
    }

    @Test("Allows zero quantity")
    func testAllowsZeroQuantity() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 0.0
        )

        #expect(item.quantity == 0.0)
    }

    @Test("Allows positive quantity")
    func testAllowsPositiveQuantity() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 42.5
        )

        #expect(item.quantity == 42.5)
    }

    // MARK: - Business Logic Methods Tests

    @Test("isForStore - exact match")
    func testIsForStoreExactMatch() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            store: "Frantz Art Glass"
        )

        #expect(item.isForStore("Frantz Art Glass") == true)
    }

    @Test("isForStore - case insensitive match")
    func testIsForStoreCaseInsensitive() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            store: "Frantz Art Glass"
        )

        #expect(item.isForStore("FRANTZ ART GLASS") == true)
        #expect(item.isForStore("frantz art glass") == true)
    }

    @Test("isForStore - no match")
    func testIsForStoreNoMatch() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            store: "Frantz Art Glass"
        )

        #expect(item.isForStore("Olympic Color") == false)
    }

    @Test("isForStore - nil store returns false")
    func testIsForStoreNilStore() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            store: nil
        )

        #expect(item.isForStore("Any Store") == false)
    }

    @Test("matchesSearchText - natural key match")
    func testMatchesSearchTextNaturalKey() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 1.0
        )

        #expect(item.matchesSearchText("cim") == true)
        #expect(item.matchesSearchText("001") == true)
        #expect(item.matchesSearchText("CIM-001") == true)
    }

    @Test("matchesSearchText - store match")
    func testMatchesSearchTextStore() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 1.0,
            store: "Frantz Art Glass"
        )

        #expect(item.matchesSearchText("frantz") == true)
        #expect(item.matchesSearchText("FRANTZ") == true)
        #expect(item.matchesSearchText("art") == true)
    }

    @Test("matchesSearchText - no match")
    func testMatchesSearchTextNoMatch() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 1.0,
            store: "Frantz Art Glass"
        )

        #expect(item.matchesSearchText("bullseye") == false)
        #expect(item.matchesSearchText("xyz") == false)
    }

    @Test("matchesSearchText - empty search returns false")
    func testMatchesSearchTextEmpty() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 1.0
        )

        #expect(item.matchesSearchText("") == false)
    }

    @Test("withQuantity - creates copy with new quantity")
    func testWithQuantity() {
        let original = ItemShoppingModel(
            id: UUID(),
            item_natural_key: "test-001",
            quantity: 5.0,
            store: "Frantz"
        )

        let updated = original.withQuantity(10.0)

        #expect(updated.quantity == 10.0)
        #expect(updated.id == original.id)
        #expect(updated.item_natural_key == original.item_natural_key)
        #expect(updated.store == original.store)
    }

    @Test("withQuantity - clamps negative to zero")
    func testWithQuantityClampsNegative() {
        let original = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 5.0
        )

        let updated = original.withQuantity(-3.0)

        #expect(updated.quantity == 0.0)
    }

    @Test("withStore - creates copy with new store")
    func testWithStore() {
        let original = ItemShoppingModel(
            id: UUID(),
            item_natural_key: "test-001",
            quantity: 5.0,
            store: "Frantz"
        )

        let updated = original.withStore("Olympic Color")

        #expect(updated.store == "Olympic Color")
        #expect(updated.id == original.id)
        #expect(updated.item_natural_key == original.item_natural_key)
        #expect(updated.quantity == original.quantity)
    }

    @Test("withStore - can set to nil")
    func testWithStoreNil() {
        let original = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 5.0,
            store: "Frantz"
        )

        let updated = original.withStore(nil)

        #expect(updated.store == nil)
    }

    // MARK: - Validation Tests

    @Test("hasValidQuantity - zero is invalid")
    func testHasValidQuantityZero() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 0.0
        )

        #expect(item.hasValidQuantity == false)
    }

    @Test("hasValidQuantity - positive is valid")
    func testHasValidQuantityPositive() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 5.0
        )

        #expect(item.hasValidQuantity == true)
    }

    @Test("isValid - valid item")
    func testIsValidTrue() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        #expect(item.isValid == true)
    }

    @Test("isValid - empty natural key is invalid")
    func testIsValidEmptyKey() {
        let item = ItemShoppingModel(
            item_natural_key: "",
            quantity: 5.0
        )

        #expect(item.isValid == false)
    }

    @Test("isValid - whitespace-only natural key is invalid")
    func testIsValidWhitespaceKey() {
        let item = ItemShoppingModel(
            item_natural_key: "   ",
            quantity: 5.0
        )

        #expect(item.isValid == false)
    }

    @Test("isValid - zero quantity is invalid")
    func testIsValidZeroQuantity() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 0.0
        )

        #expect(item.isValid == false)
    }

    @Test("validationErrors - valid item has no errors")
    func testValidationErrorsValid() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        #expect(item.validationErrors.isEmpty == true)
    }

    @Test("validationErrors - empty natural key")
    func testValidationErrorsEmptyKey() {
        let item = ItemShoppingModel(
            item_natural_key: "",
            quantity: 5.0
        )

        #expect(item.validationErrors.count == 1)
        #expect(item.validationErrors.contains("Item natural key is required"))
    }

    @Test("validationErrors - zero quantity")
    func testValidationErrorsZeroQuantity() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 0.0
        )

        #expect(item.validationErrors.count == 1)
        #expect(item.validationErrors.contains("Quantity must be greater than 0"))
    }

    @Test("validationErrors - multiple errors")
    func testValidationErrorsMultiple() {
        let item = ItemShoppingModel(
            item_natural_key: "",
            quantity: 0.0
        )

        #expect(item.validationErrors.count == 2)
        #expect(item.validationErrors.contains("Item natural key is required"))
        #expect(item.validationErrors.contains("Quantity must be greater than 0"))
    }

    // MARK: - Formatting Tests

    @Test("formattedQuantity - whole number")
    func testFormattedQuantityWhole() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 5.0
        )

        #expect(item.formattedQuantity == "5")
    }

    @Test("formattedQuantity - decimal number")
    func testFormattedQuantityDecimal() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 5.75
        )

        #expect(item.formattedQuantity == "5.75")
    }

    @Test("formattedQuantity - rounds to 2 decimals")
    func testFormattedQuantityRounding() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 5.12345
        )

        #expect(item.formattedQuantity == "5.12")
    }

    @Test("formattedQuantity - zero")
    func testFormattedQuantityZero() {
        let item = ItemShoppingModel(
            item_natural_key: "test-001",
            quantity: 0.0
        )

        #expect(item.formattedQuantity == "0")
    }

    // MARK: - Change Detection Tests

    @Test("hasChanges - no changes")
    func testHasChangesNone() {
        let item1 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz"
        )

        let item2 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz"
        )

        #expect(ItemShoppingModel.hasChanges(existing: item1, new: item2) == false)
    }

    @Test("hasChanges - natural key changed")
    func testHasChangesNaturalKey() {
        let item1 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        let item2 = ItemShoppingModel(
            item_natural_key: "cim-002-0",
            quantity: 5.0
        )

        #expect(ItemShoppingModel.hasChanges(existing: item1, new: item2) == true)
    }

    @Test("hasChanges - quantity changed")
    func testHasChangesQuantity() {
        let item1 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        let item2 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 10.0
        )

        #expect(ItemShoppingModel.hasChanges(existing: item1, new: item2) == true)
    }

    @Test("hasChanges - store changed")
    func testHasChangesStore() {
        let item1 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz"
        )

        let item2 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Olympic"
        )

        #expect(ItemShoppingModel.hasChanges(existing: item1, new: item2) == true)
    }

    @Test("hasChanges - store nil to value")
    func testHasChangesStoreNilToValue() {
        let item1 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: nil
        )

        let item2 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz"
        )

        #expect(ItemShoppingModel.hasChanges(existing: item1, new: item2) == true)
    }

    // MARK: - Equatable Tests

    @Test("Equatable - same values are equal")
    func testEquatableSame() {
        let id = UUID()
        let date = Date()

        let item1 = ItemShoppingModel(
            id: id,
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz",
            type: "rod",
            subtype: "standard",
            subsubtype: nil,
            dateAdded: date
        )

        let item2 = ItemShoppingModel(
            id: id,
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz",
            type: "rod",
            subtype: "standard",
            subsubtype: nil,
            dateAdded: date
        )

        #expect(item1 == item2)
    }

    @Test("Equatable - different IDs are not equal")
    func testEquatableDifferentId() {
        let item1 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        let item2 = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        #expect(item1 != item2)
    }

    // MARK: - Codable Tests

    @Test("Codable - encode and decode with all fields")
    func testCodableAllFields() throws {
        let original = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz Art Glass",
            type: "rod",
            subtype: "standard",
            subsubtype: "pulled"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ItemShoppingModel.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.item_natural_key == original.item_natural_key)
        #expect(decoded.quantity == original.quantity)
        #expect(decoded.store == original.store)
        #expect(decoded.type == original.type)
        #expect(decoded.subtype == original.subtype)
        #expect(decoded.subsubtype == original.subsubtype)
    }

    @Test("Codable - encode and decode with minimal fields")
    func testCodableMinimalFields() throws {
        let original = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ItemShoppingModel.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.item_natural_key == original.item_natural_key)
        #expect(decoded.quantity == original.quantity)
        #expect(decoded.store == nil)
        #expect(decoded.type == nil)
    }

    // MARK: - Dictionary Conversion Tests

    @Test("from(dictionary:) - valid dictionary")
    func testFromDictionaryValid() {
        let dict: [String: Any] = [
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "item_natural_key": "cim-001-0",
            "quantity": 5.0,
            "store": "Frantz",
            "type": "rod",
            "subtype": "standard",
            "dateAdded": 1000000.0
        ]

        let item = ItemShoppingModel.from(dictionary: dict)

        #expect(item != nil)
        #expect(item?.item_natural_key == "cim-001-0")
        #expect(item?.quantity == 5.0)
        #expect(item?.store == "Frantz")
        #expect(item?.type == "rod")
        #expect(item?.subtype == "standard")
    }

    @Test("from(dictionary:) - minimal dictionary")
    func testFromDictionaryMinimal() {
        let dict: [String: Any] = [
            "item_natural_key": "cim-001-0",
            "quantity": 5.0
        ]

        let item = ItemShoppingModel.from(dictionary: dict)

        #expect(item != nil)
        #expect(item?.item_natural_key == "cim-001-0")
        #expect(item?.quantity == 5.0)
        #expect(item?.store == nil)
    }

    @Test("from(dictionary:) - missing natural key returns nil")
    func testFromDictionaryMissingKey() {
        let dict: [String: Any] = [
            "quantity": 5.0
        ]

        let item = ItemShoppingModel.from(dictionary: dict)

        #expect(item == nil)
    }

    @Test("from(dictionary:) - missing quantity returns nil")
    func testFromDictionaryMissingQuantity() {
        let dict: [String: Any] = [
            "item_natural_key": "cim-001-0"
        ]

        let item = ItemShoppingModel.from(dictionary: dict)

        #expect(item == nil)
    }

    @Test("toDictionary - all fields")
    func testToDictionaryAllFields() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz",
            type: "rod",
            subtype: "standard",
            subsubtype: "pulled"
        )

        let dict = item.toDictionary()

        #expect(dict["item_natural_key"] as? String == "cim-001-0")
        #expect(dict["quantity"] as? Double == 5.0)
        #expect(dict["store"] as? String == "Frantz")
        #expect(dict["type"] as? String == "rod")
        #expect(dict["subtype"] as? String == "standard")
        #expect(dict["subsubtype"] as? String == "pulled")
        #expect(dict["id"] as? String != nil)
        #expect(dict["dateAdded"] as? TimeInterval != nil)
    }

    @Test("toDictionary - minimal fields")
    func testToDictionaryMinimalFields() {
        let item = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0
        )

        let dict = item.toDictionary()

        #expect(dict["item_natural_key"] as? String == "cim-001-0")
        #expect(dict["quantity"] as? Double == 5.0)
        #expect(dict["store"] == nil)
        #expect(dict["type"] == nil)
        #expect(dict["subtype"] == nil)
        #expect(dict["subsubtype"] == nil)
    }

    @Test("toDictionary and back - round trip")
    func testDictionaryRoundTrip() {
        let original = ItemShoppingModel(
            item_natural_key: "cim-001-0",
            quantity: 5.0,
            store: "Frantz",
            type: "rod"
        )

        let dict = original.toDictionary()
        let restored = ItemShoppingModel.from(dictionary: dict)

        #expect(restored != nil)
        #expect(restored?.item_natural_key == original.item_natural_key)
        #expect(restored?.quantity == original.quantity)
        #expect(restored?.store == original.store)
        #expect(restored?.type == original.type)
    }

    // MARK: - CommonStore Tests

    @Test("CommonStore has expected values")
    func testCommonStoreValues() {
        #expect(ItemShoppingModel.CommonStore.frantzArtGlass == "Frantz Art Glass")
        #expect(ItemShoppingModel.CommonStore.olympicColor == "Olympic Color")
        #expect(ItemShoppingModel.CommonStore.bullseyeGlass == "Bullseye Glass Co")
        #expect(ItemShoppingModel.CommonStore.glassAlchemy == "Glass Alchemy")
        #expect(ItemShoppingModel.CommonStore.northstarGlassworks == "Northstar Glassworks")
        #expect(ItemShoppingModel.CommonStore.online == "Online")
        #expect(ItemShoppingModel.CommonStore.local == "Local")
    }

    @Test("CommonStore allCommonStores contains all stores")
    func testCommonStoreAll() {
        let allStores = ItemShoppingModel.CommonStore.allCommonStores

        #expect(allStores.count == 7)
        #expect(allStores.contains("Frantz Art Glass"))
        #expect(allStores.contains("Olympic Color"))
        #expect(allStores.contains("Bullseye Glass Co"))
        #expect(allStores.contains("Glass Alchemy"))
        #expect(allStores.contains("Northstar Glassworks"))
        #expect(allStores.contains("Online"))
        #expect(allStores.contains("Local"))
    }
}
