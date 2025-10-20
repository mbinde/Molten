//
//  CatalogItemModelPhase1Tests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Tests for Phase 1 enhancements to CatalogItemModel - Parent-Child Architecture
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

@Suite("CatalogItemModel Phase 1 Tests - Parent-Child Architecture")
struct CatalogItemModelPhase1Tests {
    
    // MARK: - Parent-Child Constructor Tests
    
    @Test("Should create child item from parent")
    func testChildFromParentConstruction() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Red Glass",
            base_code: "BULLSEYE-0124",
            manufacturer: "Bullseye",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        let child = CatalogItemModel(
            parent: parent,
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil
        )
        
        #expect(child.parent_id == parent.id, "Child should reference parent ID")
        #expect(child.item_type == "rod", "Should set item type")
        #expect(child.manufacturer == "Bullseye", "Should inherit manufacturer from parent")
        #expect(child.tags == ["red", "transparent"], "Should inherit tags from parent")
        #expect(child.name.contains("Red Glass"), "Should construct name from parent")
        #expect(child.code.contains("BULLSEYE-0124"), "Should construct code from parent")
    }
    
    @Test("Should create child with subtype")
    func testChildWithSubtypeConstruction() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Clear Frit",
            base_code: "BULLSEYE-0001",
            manufacturer: "Bullseye",
            coe: "90",
            tags: ["clear", "frit"]
        )
        
        let child = CatalogItemModel(
            parent: parent,
            item_type: "frit",
            item_subtype: "fine",
            stock_type: nil
        )
        
        #expect(child.item_type == "frit", "Should set item type")
        #expect(child.item_subtype == "fine", "Should set item subtype")
        #expect(child.name.contains("fine"), "Should include subtype in name")
    }
    
    // MARK: - Validation Tests for Parent-Child Relationship
    
    @Test("Should validate child with valid parent relationship")
    func testValidChildParentRelationship() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let child = CatalogItemModel(
            parent: parent,
            item_type: "rod"
        )
        
        try child.validateParentRelationship(with: parent)
        #expect(true, "Valid parent-child relationship should pass validation")
    }
    
    @Test("Should detect parent ID mismatch")
    func testParentIdMismatch() async throws {
        let parent1 = CatalogItemParentModel(
            base_name: "Test Glass 1",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let parent2 = CatalogItemParentModel(
            base_name: "Test Glass 2",
            base_code: "TEST-002",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let child = CatalogItemModel(
            parent: parent1,
            item_type: "rod"
        )
        
        #expect(throws: CatalogValidationError.self) {
            try child.validateParentRelationship(with: parent2)
        }
    }
    
    @Test("Should detect manufacturer inconsistency")
    func testManufacturerInconsistency() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Parent Corp",
            coe: "90"
        )
        
        // Create child with different manufacturer using full constructor
        let child = CatalogItemModel(
            parent_id: parent.id,
            item_type: "rod",
            name: "Test Glass Rod",
            code: "CHILD-001",
            manufacturer: "Child Corp", // Different manufacturer
            tags: []
        )
        
        #expect(throws: CatalogValidationError.self) {
            try child.validateParentRelationship(with: parent)
        }
    }
    
    // MARK: - Item Type and Subtype Validation Tests
    
    @Test("Should validate valid item types")
    func testValidItemTypes() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let validTypes = ["rod", "frit", "sheet", "stringers", "powder", "misc"]
        
        for itemType in validTypes {
            let child = CatalogItemModel(
                parent: parent,
                item_type: itemType
            )
            
            try child.validate()
            #expect(true, "Item type '\(itemType)' should be valid")
        }
    }
    
    @Test("Should detect invalid item types")
    func testInvalidItemTypes() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let invalidTypes = ["", "invalid", "INVALID", "rod-frit", "rod,frit"]
        
        for itemType in invalidTypes {
            let child = CatalogItemModel(
                parent_id: parent.id,
                item_type: itemType,
                name: "Test Item",
                code: "TEST-001",
                manufacturer: "Test Corp"
            )
            
            #expect(throws: CatalogValidationError.self) {
                try child.validate()
            }
        }
    }
    
    @Test("Should validate valid item subtypes")
    func testValidItemSubtypes() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let validSubtypes = ["coarse", "fine", "medium", "10x10", "20x20", "5x5"]
        
        for subtype in validSubtypes {
            let child = CatalogItemModel(
                parent: parent,
                item_type: "frit",
                item_subtype: subtype
            )
            
            try child.validate()
            #expect(true, "Item subtype '\(subtype)' should be valid")
        }
    }
    
    // MARK: - Name and Code Construction Logic Tests
    
    @Test("Should construct variant names correctly")
    func testVariantNameConstruction() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Red Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let testCases = [
            (itemType: "rod", subtype: nil as String?, expectedName: "Red Glass Rod"),
            (itemType: "frit", subtype: "fine", expectedName: "Red Glass Frit (fine)"),
            (itemType: "sheet", subtype: nil as String?, expectedName: "Red Glass Sheet"),
            (itemType: "stringers", subtype: nil as String?, expectedName: "Red Glass Stringers")
        ]
        
        for testCase in testCases {
            let constructedName = CatalogItemModel.constructVariantName(
                parent: parent,
                itemType: testCase.itemType,
                itemSubtype: testCase.subtype
            )
            
            #expect(constructedName == testCase.expectedName,
                   "Name for type '\(testCase.itemType)' and subtype '\(testCase.subtype ?? "nil")' should be '\(testCase.expectedName)' but got '\(constructedName)'")
        }
    }
    
    @Test("Should construct variant codes correctly")
    func testVariantCodeConstruction() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let testCases = [
            (itemType: "rod", subtype: nil as String?, expectedSuffix: "R"),
            (itemType: "frit", subtype: "fine", expectedSuffix: "F-F"),
            (itemType: "sheet", subtype: nil as String?, expectedSuffix: "S"),
            (itemType: "stringers", subtype: nil as String?, expectedSuffix: "ST"),
            (itemType: "powder", subtype: "coarse", expectedSuffix: "P-C")
        ]
        
        for testCase in testCases {
            let constructedCode = CatalogItemModel.constructVariantCode(
                parent: parent,
                itemType: testCase.itemType,
                itemSubtype: testCase.subtype
            )
            
            let expectedCode = "TEST-001-\(testCase.expectedSuffix)"
            #expect(constructedCode == expectedCode,
                   "Code for type '\(testCase.itemType)' and subtype '\(testCase.subtype ?? "nil")' should be '\(expectedCode)' but got '\(constructedCode)'")
        }
    }
    
    // MARK: - URL Validation Tests
    
    @Test("Should validate valid URLs")
    func testValidURLValidation() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let validURLs = [
            "https://example.com",
            "http://manufacturer.com/product",
            "https://www.glass-supplier.co.uk/catalog/item",
            "ftp://files.manufacturer.com/images/glass.jpg"
        ]
        
        for url in validURLs {
            let child = CatalogItemModel(
                parent: parent,
                item_type: "rod",
                manufacturer_url: url
            )
            
            try child.validate()
            #expect(true, "URL '\(url)' should be valid")
        }
    }
    
    @Test("Should validate URL fields when present")
    func testURLValidationLogic() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        // Test 1: Valid URLs should pass
        let childWithValidURL = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: parent.id,
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: "https://example.com",
            image_path: nil,
            image_url: "https://images.example.com/glass.jpg",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "Test Corp",
            tags: [],
            units: 1
        )
        
        try childWithValidURL.validate()
        #expect(true, "Valid URLs should pass validation")
        
        // Test 2: Empty URLs should pass (they're optional)
        let childWithEmptyURL = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: parent.id,
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: "",
            image_path: nil,
            image_url: "",
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "Test Corp",
            tags: [],
            units: 1
        )
        
        try childWithEmptyURL.validate()
        #expect(true, "Empty URLs should pass validation")
        
        // Test 3: nil URLs should pass (they're optional)
        let childWithNilURL = CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: parent.id,
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Test Item",
            code: "TEST-001",
            manufacturer: "Test Corp",
            tags: [],
            units: 1
        )
        
        try childWithNilURL.validate()
        #expect(true, "Nil URLs should pass validation")
    }
    
    // MARK: - Legacy Compatibility Tests
    
    @Test("Should extract item types from legacy names")
    func testItemTypeExtraction() async throws {
        let testCases = [
            (name: "Red Glass Rod", expectedType: "rod", expectedSubtype: nil as String?),
            (name: "Clear Frit Fine", expectedType: "frit", expectedSubtype: "fine"),
            (name: "Blue Sheet Glass", expectedType: "sheet", expectedSubtype: nil as String?),
            (name: "Green Stringer", expectedType: "stringers", expectedSubtype: nil as String?),
            (name: "White Powder", expectedType: "powder", expectedSubtype: nil as String?),
            (name: "Mixed Color Glass", expectedType: "misc", expectedSubtype: nil as String?)
        ]
        
        for testCase in testCases {
            let legacyItem = CatalogItemModel(
                name: testCase.name,
                rawCode: "TEST-001",
                manufacturer: "Test Corp"
            )
            
            #expect(legacyItem.item_type == testCase.expectedType,
                   "Name '\(testCase.name)' should extract type '\(testCase.expectedType)' but got '\(legacyItem.item_type)'")
            
            #expect(legacyItem.item_subtype == testCase.expectedSubtype,
                   "Name '\(testCase.name)' should extract subtype '\(testCase.expectedSubtype ?? "nil")' but got '\(legacyItem.item_subtype ?? "nil")'")
        }
    }
    
    @Test("Should maintain backward compatibility with legacy constructor")
    func testLegacyConstructorCompatibility() async throws {
        let legacyItem = CatalogItemModel(
            name: "Legacy Glass Rod",
            rawCode: "LGR-001",
            manufacturer: "Legacy Corp"
        )
        
        // Should have new parent-child fields populated
        #expect(!legacyItem.id.isEmpty, "Should have legacy ID")
        #expect(legacyItem.id2.description.count > 0, "Should have new ID")
        #expect(legacyItem.parent_id.description.count > 0, "Should have parent ID")
        #expect(!legacyItem.item_type.isEmpty, "Should have item type")
        
        // Should have proper code formatting
        #expect(legacyItem.code == "LEGACY CORP-LGR-001", "Should format code with manufacturer prefix")
        
        // Should validate successfully
        try legacyItem.validate()
        #expect(true, "Legacy item should validate successfully")
    }
}
