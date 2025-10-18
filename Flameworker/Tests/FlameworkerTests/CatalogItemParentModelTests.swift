//
//  CatalogItemParentModelTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Comprehensive tests for CatalogItemParentModel - Phase 1 Foundation Code
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

@Suite("CatalogItemParentModel Tests - Phase 1 Foundation")
struct CatalogItemParentModelTests {
    
    // MARK: - Basic Construction Tests
    
    @Test("Should create parent item with direct constructor")
    func testBasicConstruction() async throws {
        let parentId = UUID()
        let parent = CatalogItemParentModel(
            id: parentId,
            base_name: "Red Glass",
            base_code: "BULLSEYE-0124",
            manufacturer: "Bullseye",
            coe: "90",
            tags: ["red", "transparent", "coe90"]
        )
        
        #expect(parent.id == parentId, "Should preserve provided ID")
        #expect(parent.base_name == "Red Glass", "Should preserve base name")
        #expect(parent.base_code == "BULLSEYE-0124", "Should preserve base code")
        #expect(parent.manufacturer == "Bullseye", "Should preserve manufacturer")
        #expect(parent.coe == "90", "Should preserve COE")
        #expect(parent.tags == ["red", "transparent", "coe90"], "Should preserve tags")
    }
    
    @Test("Should create parent item with defaults")
    func testConstructionWithDefaults() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Simple Glass",
            base_code: "SG-001",
            manufacturer: "Simple Corp",
            coe: "96"
        )
        
        #expect(!parent.id.description.isEmpty, "Should generate UUID for ID")
        #expect(parent.tags.isEmpty, "Should default to empty tags")
    }
    
    @Test("Should create parent with raw code constructor")
    func testRawCodeConstruction() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Build Test Glass",
            raw_base_code: "BTG-001",
            manufacturer: "Build Corp",
            coe: "104"
        )
        
        #expect(parent.base_name == "Build Test Glass", "Should preserve base name")
        #expect(parent.base_code == "BUILD CORP-BTG-001", "Should format code with manufacturer prefix")
        #expect(parent.manufacturer == "Build Corp", "Should preserve manufacturer")
        #expect(parent.coe == "104", "Should preserve COE")
    }
    
    // MARK: - Code Construction Logic Tests
    
    @Test("Should construct full code with uppercase manufacturer prefix")
    func testCodeConstructionBasic() async throws {
        let testCases = [
            (manufacturer: "Bullseye", rawCode: "0124", expected: "BULLSEYE-0124"),
            (manufacturer: "spectrum glass", rawCode: "125", expected: "SPECTRUM GLASS-125"),
            (manufacturer: "Uroboros Co", rawCode: "94-16", expected: "UROBOROS CO-94-16")
        ]
        
        for testCase in testCases {
            let fullCode = CatalogItemParentModel.constructFullCode(
                manufacturer: testCase.manufacturer,
                code: testCase.rawCode
            )
            
            #expect(fullCode == testCase.expected,
                   "Code construction for manufacturer '\(testCase.manufacturer)' and raw code '\(testCase.rawCode)' should be '\(testCase.expected)' but got '\(fullCode)'")
        }
    }
    
    @Test("Should not double-prefix codes that already have correct manufacturer prefix")
    func testCodeConstructionAvoidDoublePrefix() async throws {
        let testCases = [
            (manufacturer: "Effetre", code: "EFFETRE-BLU-002", expected: "EFFETRE-BLU-002"),
            (manufacturer: "Thompson", code: "THOMPSON-TTL-8623", expected: "THOMPSON-TTL-8623"),
            (manufacturer: "Bullseye Glass", code: "BULLSEYE GLASS-0124", expected: "BULLSEYE GLASS-0124")
        ]
        
        for testCase in testCases {
            let fullCode = CatalogItemParentModel.constructFullCode(
                manufacturer: testCase.manufacturer,
                code: testCase.code
            )
            
            #expect(fullCode == testCase.expected,
                   "Code with existing prefix '\(testCase.code)' should not be double-prefixed, expected '\(testCase.expected)' but got '\(fullCode)'")
        }
    }
    
    @Test("Should handle tricky code construction cases")
    func testCodeConstructionEdgeCases() async throws {
        // Test cases that might confuse the prefix detection logic
        let testCases = [
            // Hyphen in product code that's NOT a manufacturer separator
            (manufacturer: "Thompson", code: "TTL-8623", expected: "THOMPSON-TTL-8623"),
            
            // Similar manufacturer names but different
            (manufacturer: "Bullseye", code: "BULLSEYE GLASS-001", expected: "BULLSEYE-BULLSEYE GLASS-001"),
            
            // Partial manufacturer match in code
            (manufacturer: "Spectrum Glass", code: "SPEC-001", expected: "SPECTRUM GLASS-SPEC-001"),
            
            // Empty raw code
            (manufacturer: "Test Corp", code: "", expected: "TEST CORP-"),
            
            // Code with multiple hyphens
            (manufacturer: "Multi Corp", code: "MC-SUB-001", expected: "MULTI CORP-MC-SUB-001")
        ]
        
        for testCase in testCases {
            let fullCode = CatalogItemParentModel.constructFullCode(
                manufacturer: testCase.manufacturer,
                code: testCase.code
            )
            
            #expect(fullCode == testCase.expected,
                   "Edge case: manufacturer '\(testCase.manufacturer)' with code '\(testCase.code)' should be '\(testCase.expected)' but got '\(fullCode)'")
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Should validate complete parent items successfully")
    func testValidParentValidation() async throws {
        let validParent = CatalogItemParentModel(
            base_name: "Valid Glass Rod",
            base_code: "VALID-001",
            manufacturer: "Valid Corp",
            coe: "90",
            tags: ["valid", "test", "glass"]
        )
        
        try validParent.validate()
        // If we reach here, validation passed
        #expect(true, "Valid parent should pass validation")
    }
    
    @Test("Should detect empty base name validation failures")
    func testInvalidBaseNameValidation() async throws {
        let invalidParent = CatalogItemParentModel(
            base_name: "",
            base_code: "VALID-001",
            manufacturer: "Valid Corp",
            coe: "90"
        )
        
        #expect(throws: CatalogValidationError.self) {
            try invalidParent.validate()
        }
    }
    
    @Test("Should detect whitespace-only base name validation failures")
    func testWhitespaceBaseNameValidation() async throws {
        let invalidParent = CatalogItemParentModel(
            base_name: "   \t\n   ",
            base_code: "VALID-001", 
            manufacturer: "Valid Corp",
            coe: "90"
        )
        
        #expect(throws: CatalogValidationError.self) {
            try invalidParent.validate()
        }
    }
    
    @Test("Should detect empty base code validation failures")
    func testInvalidBaseCodeValidation() async throws {
        let invalidParent = CatalogItemParentModel(
            base_name: "Valid Glass",
            base_code: "",
            manufacturer: "Valid Corp",
            coe: "90"
        )
        
        #expect(throws: CatalogValidationError.self) {
            try invalidParent.validate()
        }
    }
    
    @Test("Should detect empty manufacturer validation failures")
    func testInvalidManufacturerValidation() async throws {
        let invalidParent = CatalogItemParentModel(
            base_name: "Valid Glass",
            base_code: "VALID-001",
            manufacturer: "",
            coe: "90"
        )
        
        #expect(throws: CatalogValidationError.self) {
            try invalidParent.validate()
        }
    }
    
    // MARK: - COE Validation Tests
    
    @Test("Should validate valid COE values")
    func testValidCOEValidation() async throws {
        let validCOEValues = ["80", "90", "96", "104", "120", "50", "200"]
        
        for coe in validCOEValues {
            let parent = CatalogItemParentModel(
                base_name: "Test Glass",
                base_code: "TEST-001",
                manufacturer: "Test Corp",
                coe: coe
            )
            
            try parent.validate()
            // If we reach here, validation passed
            #expect(true, "COE value '\(coe)' should be valid")
        }
    }
    
    @Test("Should detect empty COE validation failures")
    func testEmptyCOEValidation() async throws {
        let invalidParent = CatalogItemParentModel(
            base_name: "Valid Glass",
            base_code: "VALID-001",
            manufacturer: "Valid Corp",
            coe: ""
        )
        
        #expect(throws: CatalogValidationError.self) {
            try invalidParent.validate()
        }
    }
    
    @Test("Should detect invalid COE format validation failures")
    func testInvalidCOEFormatValidation() async throws {
        let invalidCOEValues = ["abc", "90.5", "-90", "300", "49", "201", "90-96", "COE90"]
        
        for coe in invalidCOEValues {
            let invalidParent = CatalogItemParentModel(
                base_name: "Test Glass",
                base_code: "TEST-001",
                manufacturer: "Test Corp",
                coe: coe
            )
            
            #expect(throws: CatalogValidationError.self) {
                try invalidParent.validate()
            }
        }
    }
    
    @Test("Should detect invalid base code characters")
    func testInvalidBaseCodeCharacters() async throws {
        let invalidCodes = ["TEST@001", "TEST!001", "TEST#001", "TEST%001", "TEST<001", "TEST>001"]
        
        for code in invalidCodes {
            let invalidParent = CatalogItemParentModel(
                base_name: "Test Glass",
                base_code: code,
                manufacturer: "Test Corp",
                coe: "90"
            )
            
            #expect(throws: CatalogValidationError.self) {
                try invalidParent.validate()
            }
        }
    }
    
    @Test("Should allow valid base code characters")
    func testValidBaseCodeCharacters() async throws {
        let validCodes = ["TEST-001", "TEST_001", "TEST.001", "TEST001", "T-E-S-T"]
        
        for code in validCodes {
            let validParent = CatalogItemParentModel(
                base_name: "Test Glass",
                base_code: code,
                manufacturer: "Test Corp",
                coe: "90"
            )
            
            try validParent.validate()
            #expect(true, "Base code '\(code)' should be valid")
        }
    }
    
    @Test("Should detect empty tags validation failures")
    func testInvalidTagsValidation() async throws {
        let invalidParent = CatalogItemParentModel(
            base_name: "Valid Glass",
            base_code: "VALID-001",
            manufacturer: "Valid Corp",
            coe: "90",
            tags: ["valid", "", "another"]  // Empty string in tags
        )
        
        #expect(throws: CatalogValidationError.self) {
            try invalidParent.validate()
        }
    }
    
    @Test("Should allow valid tags")
    func testValidTagsValidation() async throws {
        let validParent = CatalogItemParentModel(
            base_name: "Valid Glass",
            base_code: "VALID-001",
            manufacturer: "Valid Corp",
            coe: "90",
            tags: ["red", "transparent", "coe90", "bullseye"]
        )
        
        try validParent.validate()
        #expect(true, "Valid tags should pass validation")
    }
    
    // MARK: - Tag Conversion Utility Tests
    
    @Test("Should convert tag arrays to comma-separated strings")
    func testTagsToString() async throws {
        let testCases = [
            (tags: [String](), expected: ""),
            (tags: ["red"], expected: "red"),
            (tags: ["red", "transparent", "coe90"], expected: "red,transparent,coe90"),
            (tags: ["red", "", "blue"], expected: "red,blue"), // Should filter empty strings
            (tags: ["  spaced  ", "normal"], expected: "spaced,normal") // Should trim whitespace but preserve content
        ]
        
        for testCase in testCases {
            let result = CatalogItemParentModel.tagsToString(testCase.tags)
            #expect(result == testCase.expected,
                   "Tags \(testCase.tags) should convert to '\(testCase.expected)' but got '\(result)'")
        }
    }
    
    @Test("Should convert comma-separated strings to tag arrays")
    func testStringToTags() async throws {
        let testCases = [
            (string: "", expected: [String]()),
            (string: "red", expected: ["red"]),
            (string: "red,transparent,coe90", expected: ["red", "transparent", "coe90"]),
            (string: "red, blue , green", expected: ["red", "blue", "green"]), // Should trim spaces
            (string: "red,,blue", expected: ["red", "blue"]), // Should filter empty components
            (string: "  ", expected: [String]()) // Should handle whitespace-only strings
        ]
        
        for testCase in testCases {
            let result = CatalogItemParentModel.stringToTags(testCase.string)
            #expect(result == testCase.expected,
                   "String '\(testCase.string)' should convert to \(testCase.expected) but got \(result)")
        }
    }
    
    @Test("Should round-trip tags through string conversion")
    func testTagsRoundTrip() async throws {
        let originalTags = ["red", "transparent", "coe90", "bullseye", "COE-90"]
        
        let string = CatalogItemParentModel.tagsToString(originalTags)
        let convertedTags = CatalogItemParentModel.stringToTags(string)
        
        #expect(convertedTags == originalTags, "Tags should round-trip through string conversion")
    }
    
    // MARK: - Change Detection Tests
    
    @Test("Should detect no changes when parents are identical")
    func testChangeDetectionIdenticalParents() async throws {
        let parent1 = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "BULLSEYE-001",
            manufacturer: "Bullseye",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        let parent2 = CatalogItemParentModel(
            id: parent1.id, // Same ID
            base_name: "Test Glass",
            base_code: "BULLSEYE-001",
            manufacturer: "Bullseye",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        let hasChanges = CatalogItemParentModel.hasChanges(existing: parent1, new: parent2)
        #expect(!hasChanges, "Identical parents should have no changes")
    }
    
    @Test("Should detect base name changes")
    func testChangeDetectionBaseNameChanges() async throws {
        let existing = CatalogItemParentModel(
            base_name: "Original Name",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let updated = CatalogItemParentModel(
            id: existing.id,
            base_name: "Updated Name", // Changed
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let hasChanges = CatalogItemParentModel.hasChanges(existing: existing, new: updated)
        #expect(hasChanges, "Should detect base name changes")
    }
    
    @Test("Should detect manufacturer changes")
    func testChangeDetectionManufacturerChanges() async throws {
        let existing = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "ORIGINAL-001",
            manufacturer: "Original Corp",
            coe: "90"
        )
        
        let updated = CatalogItemParentModel(
            id: existing.id,
            base_name: "Test Glass",
            base_code: "UPDATED-001",
            manufacturer: "Updated Corp", // Changed
            coe: "90"
        )
        
        let hasChanges = CatalogItemParentModel.hasChanges(existing: existing, new: updated)
        #expect(hasChanges, "Should detect manufacturer changes")
    }
    
    @Test("Should detect COE changes")
    func testChangeDetectionCOEChanges() async throws {
        let existing = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let updated = CatalogItemParentModel(
            id: existing.id,
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "96" // Changed
        )
        
        let hasChanges = CatalogItemParentModel.hasChanges(existing: existing, new: updated)
        #expect(hasChanges, "Should detect COE changes")
    }
    
    @Test("Should detect raw code changes by comparing extracted codes")
    func testChangeDetectionRawCodeChanges() async throws {
        // Test that change detection correctly compares raw codes, not formatted ones
        let existing = CatalogItemParentModel(
            base_name: "Test Glass",
            raw_base_code: "TG-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        // existing.base_code will be "TEST CORP-TG-001"
        
        let updated = CatalogItemParentModel(
            id: existing.id,
            base_name: "Test Glass",
            raw_base_code: "TG-002", // Different raw code
            manufacturer: "Test Corp",
            coe: "90"
        )
        // updated.base_code will be "TEST CORP-TG-002"
        
        let hasChanges = CatalogItemParentModel.hasChanges(existing: existing, new: updated)
        #expect(hasChanges, "Should detect raw code changes")
    }
    
    @Test("Should not detect changes when raw codes are same but formatted differently")
    func testChangeDetectionFormattedCodeEquivalence() async throws {
        // Create parent with raw code
        let existing = CatalogItemParentModel(
            base_name: "Test Glass",
            raw_base_code: "TG-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        // existing.base_code will be "TEST CORP-TG-001"
        
        // Create "updated" parent using direct constructor with already-formatted code
        let updated = CatalogItemParentModel(
            id: existing.id,
            base_name: "Test Glass",
            base_code: "TEST CORP-TG-001", // Same logical code, but provided pre-formatted
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let hasChanges = CatalogItemParentModel.hasChanges(existing: existing, new: updated)
        #expect(!hasChanges, "Should not detect changes when raw codes are logically equivalent")
    }
    
    @Test("Should detect tag changes")
    func testChangeDetectionTagChanges() async throws {
        let existing = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        // Test different types of tag changes
        let testCases = [
            // Added tag
            (tags: ["red", "transparent", "coe90"], shouldHaveChanges: true, description: "added tag"),
            
            // Removed tag
            (tags: ["red"], shouldHaveChanges: true, description: "removed tag"),
            
            // Reordered tags (order matters)
            (tags: ["transparent", "red"], shouldHaveChanges: true, description: "reordered tags"),
            
            // Same tags
            (tags: ["red", "transparent"], shouldHaveChanges: false, description: "same tags"),
            
            // Empty tags
            (tags: [String](), shouldHaveChanges: true, description: "empty tags")
        ]
        
        for testCase in testCases {
            let updated = CatalogItemParentModel(
                id: existing.id,
                base_name: "Test Glass",
                base_code: "TEST-001",
                manufacturer: "Test Corp",
                coe: "90",
                tags: testCase.tags
            )
            
            let hasChanges = CatalogItemParentModel.hasChanges(existing: existing, new: updated)
            
            if testCase.shouldHaveChanges {
                #expect(hasChanges, "Should detect changes for \(testCase.description)")
            } else {
                #expect(!hasChanges, "Should not detect changes for \(testCase.description)")
            }
        }
    }
    
    // MARK: - Parent-Child Relationship Validation Tests
    
    @Test("Should validate valid parent-child relationships")
    func testValidParentChildRelationship() async throws {
        let parentId = UUID()
        let parent = CatalogItemParentModel(
            id: parentId,
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let children = [
            CatalogItemModel(
                parent_id: parentId,
                item_type: "rod",
                name: "Test Glass Rod",
                code: "TEST CORP-TEST-001-R",
                manufacturer: "Test Corp"
            ),
            CatalogItemModel(
                parent_id: parentId,
                item_type: "frit",
                item_subtype: "fine",
                name: "Test Glass Frit Fine",
                code: "TEST CORP-TEST-001-F-F",
                manufacturer: "Test Corp"
            )
        ]
        
        try CatalogItemParentModel.validateParentChildRelationship(parent: parent, children: children)
        #expect(true, "Valid parent-child relationship should pass validation")
    }
    
    @Test("Should detect orphaned children")
    func testOrphanedChildrenValidation() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let orphanedChild = CatalogItemModel(
            parent_id: UUID(), // Different parent ID
            item_type: "rod",
            name: "Orphaned Rod",
            code: "TEST-002",
            manufacturer: "Test Corp"
        )
        
        #expect(throws: CatalogValidationError.self) {
            try CatalogItemParentModel.validateParentChildRelationship(parent: parent, children: [orphanedChild])
        }
    }
    
    @Test("Should detect inconsistent manufacturer between parent and child")
    func testInconsistentManufacturerValidation() async throws {
        let parentId = UUID()
        let parent = CatalogItemParentModel(
            id: parentId,
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90"
        )
        
        let inconsistentChild = CatalogItemModel(
            parent_id: parentId,
            item_type: "rod",
            name: "Different Manufacturer Rod",
            code: "DIFFERENT-001",
            manufacturer: "Different Corp" // Different manufacturer
        )
        
        #expect(throws: CatalogValidationError.self) {
            try CatalogItemParentModel.validateParentChildRelationship(parent: parent, children: [inconsistentChild])
        }
    }
    
    // MARK: - Searchable Conformance Tests
    
    @Test("Should provide comprehensive searchable text")
    func testSearchableText() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Red Glass Rod",
            base_code: "BULLSEYE-0124",
            manufacturer: "Bullseye Glass",
            coe: "90",
            tags: ["red", "transparent", "COE-90"]
        )
        
        let searchableText = parent.searchableText
        
        // Should include all the main fields
        #expect(searchableText.contains("Red Glass Rod"), "Should include base name in searchable text")
        #expect(searchableText.contains("BULLSEYE-0124"), "Should include base code")
        #expect(searchableText.contains("Bullseye Glass"), "Should include manufacturer")
        #expect(searchableText.contains("90"), "Should include COE")
        
        // Should include all tags
        #expect(searchableText.contains("red"), "Should include red tag")
        #expect(searchableText.contains("transparent"), "Should include transparent tag")
        #expect(searchableText.contains("COE-90"), "Should include COE-90 tag")
        
        // Should not include empty strings
        #expect(!searchableText.contains(""), "Should not include empty strings in searchable text")
    }
    
    @Test("Should handle searchable text with empty fields")
    func testSearchableTextWithEmptyFields() async throws {
        let parent = CatalogItemParentModel(
            base_name: "Test Item",
            base_code: "", // Empty code
            manufacturer: "Test Corp",
            coe: "90",
            tags: [] // Empty tags
        )
        
        let searchableText = parent.searchableText
        
        #expect(searchableText.contains("Test Item"), "Should include non-empty base name")
        #expect(searchableText.contains("Test Corp"), "Should include non-empty manufacturer")
        #expect(searchableText.contains("90"), "Should include non-empty COE")
        #expect(!searchableText.contains(""), "Should not include empty strings")
        
        // Should still be searchable with remaining fields
        #expect(searchableText.count >= 3, "Should have at least base name, manufacturer, and COE")
    }
    
    // MARK: - Equatable and Hashable Conformance Tests
    
    @Test("Should compare parents for equality correctly")
    func testEquatable() async throws {
        let parent1 = CatalogItemParentModel(
            id: UUID(),
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        let parent2 = CatalogItemParentModel(
            id: parent1.id, // Same ID
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        let parent3 = CatalogItemParentModel(
            id: UUID(), // Different ID
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        #expect(parent1 == parent2, "Parents with same properties should be equal")
        #expect(parent1 != parent3, "Parents with different IDs should not be equal")
    }
    
    @Test("Should hash parents consistently")
    func testHashable() async throws {
        let sharedId = UUID()
        
        let parent1 = CatalogItemParentModel(
            id: sharedId,
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        let parent2 = CatalogItemParentModel(
            id: sharedId, // Same ID
            base_name: "Test Glass",
            base_code: "TEST-001",
            manufacturer: "Test Corp",
            coe: "90",
            tags: ["red", "transparent"]
        )
        
        // Items should be equal
        #expect(parent1 == parent2, "Parents with identical data should be equal")
        
        // Should be usable in Sets
        let parentSet: Set<CatalogItemParentModel> = [parent1, parent2]
        #expect(parentSet.count == 1, "Set should deduplicate equal parents")
    }
    
    // MARK: - Edge Cases and Performance Tests
    
    @Test("Should handle edge case parent values")
    func testParentEdgeCases() async throws {
        // Test very long field values
        let longName = String(repeating: "Very Long Name ", count: 100)
        let longCode = String(repeating: "CODE", count: 50)
        let longManufacturer = String(repeating: "Manufacturer Corp ", count: 20)
        
        let longParent = CatalogItemParentModel(
            base_name: longName,
            base_code: longCode,
            manufacturer: longManufacturer,
            coe: "90"
        )
        
        try longParent.validate()
        #expect(true, "Parent with very long fields should still be valid")
        
        // Test single character fields
        let shortParent = CatalogItemParentModel(
            base_name: "A",
            base_code: "B",
            manufacturer: "C",
            coe: "90"
        )
        
        try shortParent.validate()
        #expect(true, "Parent with single character fields should be valid")
        
        // Test special characters
        let specialParent = CatalogItemParentModel(
            base_name: "Glass-Rod (Special) [Test]",
            base_code: "GR-001-SP",
            manufacturer: "Corp & Co.",
            coe: "90"
        )
        
        try specialParent.validate()
        #expect(true, "Parent with special characters should be valid")
    }
    
    @Test("Should maintain performance with large tag arrays")
    func testPerformanceWithLargeTags() async throws {
        // Test that tag processing doesn't degrade with large tag arrays
        let largeTags = Array(0..<1000).map { "tag\($0)" }
        
        let parent = CatalogItemParentModel(
            base_name: "Performance Test Glass",
            base_code: "PTG-001",
            manufacturer: "Performance Corp",
            coe: "90",
            tags: largeTags
        )
        
        try parent.validate()
        #expect(parent.tags.count == 1000, "Should handle large tag arrays")
        
        // Test tag conversion performance
        let tagString = CatalogItemParentModel.tagsToString(largeTags)
        let convertedTags = CatalogItemParentModel.stringToTags(tagString)
        
        #expect(convertedTags.count == 1000, "Should convert large tag arrays efficiently")
        #expect(convertedTags == largeTags, "Should maintain tag accuracy with large arrays")
        
        // Test searchable text performance
        let searchableText = parent.searchableText
        #expect(searchableText.count > 1000, "Should handle large searchable text arrays")
    }
}
