//
//  ServiceValidationTests.swift
//  MoltenTests
//
//  Unit tests for ServiceValidation class
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

@MainActor
@Suite("ServiceValidation Tests")
struct ServiceValidationTests {

    // MARK: - ValidationResult Tests

    @Test("ValidationResult success creates valid result")
    func testValidationResultSuccess() {
        let result = ValidationResult.success()

        #expect(result.isValid == true)
        #expect(result.errors.isEmpty)
    }

    @Test("ValidationResult failure creates invalid result with errors")
    func testValidationResultFailure() {
        let errors = ["Error 1", "Error 2"]
        let result = ValidationResult.failure(errors: errors)

        #expect(result.isValid == false)
        #expect(result.errors.count == 2)
        #expect(result.errors == errors)
    }

    @Test("ValidationResult can be created with custom values")
    func testValidationResultCustomInit() {
        let result = ValidationResult(isValid: false, errors: ["Custom error"])

        #expect(result.isValid == false)
        #expect(result.errors.count == 1)
        #expect(result.errors.first == "Custom error")
    }

    // MARK: - GlassItem Validation Tests

    @Test("Valid GlassItem passes validation")
    func testValidGlassItem() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == true)
        #expect(result.errors.isEmpty)
    }

    @Test("GlassItem with empty name fails validation")
    func testGlassItemEmptyName() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == false)
        #expect(result.errors.contains("GlassItem name is required and cannot be empty"))
    }

    @Test("GlassItem with whitespace-only name fails validation")
    func testGlassItemWhitespaceName() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "   \n  ",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == false)
        #expect(result.errors.contains("GlassItem name is required and cannot be empty"))
    }

    @Test("GlassItem with empty stable_id fails validation")
    func testGlassItemEmptyStableId() {
        let glassItem = GlassItemModel(
            stable_id: "",
            name: "Clear Glass",
            sku: "TEST-SKU",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == false)
        #expect(result.errors.contains("GlassItem stable_id is required and cannot be empty"))
    }

    @Test("GlassItem with empty manufacturer fails validation")
    func testGlassItemEmptyManufacturer() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "",
            coe: 90,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == false)
        #expect(result.errors.contains("GlassItem manufacturer is required and cannot be empty"))
    }

    @Test("GlassItem with COE below 80 fails validation")
    func testGlassItemCOETooLow() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 79,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == false)
        #expect(result.errors.contains("COE value should be between 80 and 120"))
    }

    @Test("GlassItem with COE above 120 fails validation")
    func testGlassItemCOETooHigh() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 121,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == false)
        #expect(result.errors.contains("COE value should be between 80 and 120"))
    }

    @Test("GlassItem with COE 80 (boundary) passes validation")
    func testGlassItemCOEMinBoundary() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 80,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == true)
    }

    @Test("GlassItem with COE 120 (boundary) passes validation")
    func testGlassItemCOEMaxBoundary() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 120,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == true)
    }

    @Test("GlassItem with multiple validation errors accumulates all errors")
    func testGlassItemMultipleErrors() {
        let glassItem = GlassItemModel(
            stable_id: "",
            name: "",
            sku: "TEST-SKU",
            manufacturer: "",
            coe: 50,
            mfr_status: "available"
        )

        let result = ServiceValidation.validateGlassItem(glassItem)

        #expect(result.isValid == false)
        #expect(result.errors.count == 4) // name, stable_id, manufacturer, COE
    }

    // MARK: - InventoryModel Validation Tests

    @Test("Valid InventoryModel passes validation")
    func testValidInventoryModel() {
        let inventory = InventoryModel(
            item_stable_id: "test-001",
            type: "rod",
            quantity: 5.0
        )

        let result = ServiceValidation.validateInventoryModel(inventory)

        #expect(result.isValid == true)
        #expect(result.errors.isEmpty)
    }

    @Test("InventoryModel with empty item_stable_id fails validation")
    func testInventoryModelEmptyStableId() {
        let inventory = InventoryModel(
            item_stable_id: "",
            type: "rod",
            quantity: 5.0
        )

        let result = ServiceValidation.validateInventoryModel(inventory)

        #expect(result.isValid == false)
        #expect(result.errors.contains("Item natural key is required and cannot be empty"))
    }

    @Test("InventoryModel with empty type fails validation")
    func testInventoryModelEmptyType() {
        let inventory = InventoryModel(
            item_stable_id: "test-001",
            type: "",
            quantity: 5.0
        )

        let result = ServiceValidation.validateInventoryModel(inventory)

        #expect(result.isValid == false)
        #expect(result.errors.contains("Inventory type is required and cannot be empty"))
    }

    @Test("InventoryModel with zero quantity passes validation")
    func testInventoryModelZeroQuantity() {
        let inventory = InventoryModel(
            item_stable_id: "test-001",
            type: "rod",
            quantity: 0.0
        )

        let result = ServiceValidation.validateInventoryModel(inventory)

        #expect(result.isValid == true)
    }

    // MARK: - CompleteInventoryItemModel Validation Tests

    @Test("Valid CompleteInventoryItemModel passes validation")
    func testValidCompleteInventoryItem() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let inventory1 = InventoryModel(
            item_stable_id: "test-001",
            type: "rod",
            quantity: 5.0
        )

        let inventory2 = InventoryModel(
            item_stable_id: "test-001",
            type: "tube",
            quantity: 3.0
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [inventory1, inventory2],
            tags: [],
            userTags: []
        )

        let result = ServiceValidation.validateCompleteInventoryItem(completeItem)

        #expect(result.isValid == true)
        #expect(result.errors.isEmpty)
    }

    @Test("CompleteInventoryItemModel with invalid GlassItem fails validation")
    func testCompleteInventoryItemInvalidGlassItem() {
        let glassItem = GlassItemModel(
            stable_id: "",
            name: "",
            sku: "TEST-SKU",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let inventory = InventoryModel(
            item_stable_id: "",
            type: "rod",
            quantity: 5.0
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [inventory],
            tags: [], userTags: []
        )

        let result = ServiceValidation.validateCompleteInventoryItem(completeItem)

        #expect(result.isValid == false)
        // Should fail on GlassItem validation before checking inventory
    }

    @Test("CompleteInventoryItemModel with mismatched stable_ids fails validation")
    func testCompleteInventoryItemMismatchedStableIds() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let inventory = InventoryModel(
            item_stable_id: "different-id",
            type: "rod",
            quantity: 5.0
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [inventory],
            tags: [], userTags: []
        )

        let result = ServiceValidation.validateCompleteInventoryItem(completeItem)

        #expect(result.isValid == false)
        #expect(result.errors.contains { $0.contains("does not match GlassItem stable_id") })
    }

    @Test("CompleteInventoryItemModel with empty inventory passes validation")
    func testCompleteInventoryItemEmptyInventory() {
        let glassItem = GlassItemModel(
            stable_id: "test-001",
            name: "Clear Glass",
            sku: "001",
            manufacturer: "Bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [], userTags: []
        )

        let result = ServiceValidation.validateCompleteInventoryItem(completeItem)

        #expect(result.isValid == true)
    }

    // MARK: - PurchaseRecord Validation Tests

    @Test("Valid PurchaseRecord passes validation")
    func testValidPurchaseRecord() {
        let purchaseRecord = PurchaseRecordModel(
            supplier: "Test Store"
        )

        let result = ServiceValidation.validatePurchaseRecord(purchaseRecord)

        #expect(result.isValid == true)
    }

    @Test("Invalid PurchaseRecord fails validation")
    func testInvalidPurchaseRecord() {
        let purchaseRecord = PurchaseRecordModel(
            supplier: ""  // Invalid empty store name
        )

        let result = ServiceValidation.validatePurchaseRecord(purchaseRecord)

        #expect(result.isValid == false)
        #expect(!result.errors.isEmpty)
    }
}
