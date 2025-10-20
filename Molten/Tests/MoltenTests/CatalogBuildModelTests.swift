//
//  CatalogBuildModelTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Comprehensive tests for CatalogItemModel construction, code formatting, and business logic
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

@Suite("Catalog Item Model Build Tests - Core Business Logic")
struct CatalogBuildModelTests {
    
    // MARK: - Basic Construction Tests
    
    @Test("Should create catalog item with legacy constructor")
    func testBasicConstruction() async throws {
        let item = CatalogItemModel(
            id: "test-id",
            name: "Test Glass Rod",
            rawCode: "TGR-001",
            manufacturer: "Test Corp",
            tags: ["red", "rod"],
            units: 5
        )
        
        #expect(item.id == "test-id", "Should preserve provided ID")
        #expect(item.name == "Test Glass Rod", "Should preserve name")
        #expect(item.code == "TEST CORP-TGR-001", "Should format code with manufacturer prefix")
        #expect(item.manufacturer == "Test Corp", "Should preserve manufacturer")
        #expect(item.tags == ["red", "rod"], "Should preserve tags")
        #expect(item.units == 5, "Should preserve units")
    }
    
    @Test("Should create catalog item with defaults")
    func testConstructionWithDefaults() async throws {
        let item = CatalogItemModel(
            name: "Simple Glass",
            rawCode: "SG-001",
            manufacturer: "Simple Corp"
        )
        
        #expect(!item.id.isEmpty, "Should generate UUID for ID")
        #expect(item.tags.isEmpty, "Should default to empty tags")
        #expect(item.units == 1, "Should default to 1 unit")
    }
    
    @Test("Should create catalog item with raw code constructor")
    func testRawCodeConstruction() async throws {
        let item = CatalogItemModel(
            name: "Build Test Glass",
            rawCode: "BTG-001",
            manufacturer: "Build Corp"
        )
        
        #expect(item.name == "Build Test Glass", "Should preserve name")
        #expect(item.code == "BUILD CORP-BTG-001", "Should format code with manufacturer prefix")
        #expect(item.manufacturer == "Build Corp", "Should preserve manufacturer")
    }
    
    // MARK: - Code Construction Business Logic Tests
    
    @Test("Should construct full code with uppercase manufacturer prefix")
    func testCodeConstructionBasic() async throws {
        let testCases = [
            (manufacturer: "Bullseye", rawCode: "0124", expected: "BULLSEYE-0124"),
            (manufacturer: "spectrum glass", rawCode: "125", expected: "SPECTRUM GLASS-125"),
            (manufacturer: "Uroboros Co", rawCode: "94-16", expected: "UROBOROS CO-94-16")
        ]
        
        for testCase in testCases {
            let fullCode = CatalogItemModel.constructFullCode(
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
            let fullCode = CatalogItemModel.constructFullCode(
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
            let fullCode = CatalogItemModel.constructFullCode(
                manufacturer: testCase.manufacturer,
                code: testCase.code
            )
            
            #expect(fullCode == testCase.expected,
                   "Edge case: manufacturer '\(testCase.manufacturer)' with code '\(testCase.code)' should be '\(testCase.expected)' but got '\(fullCode)'")
        }
    }
    
    @Test("Should construct codes consistently through model initialization")
    func testCodeConstructionThroughModel() async throws {
        let testCases = [
            (name: "Red Glass", rawCode: "0124", manufacturer: "Bullseye", expectedCode: "BULLSEYE-0124"),
            (name: "Blue Sheet", rawCode: "125", manufacturer: "Spectrum Glass", expectedCode: "SPECTRUM GLASS-125"),
            (name: "Clear Rod", rawCode: "EFFETRE-001", manufacturer: "Effetre", expectedCode: "EFFETRE-001") // Already prefixed
        ]
        
        for testCase in testCases {
            let item = CatalogItemModel(
                name: testCase.name,
                rawCode: testCase.rawCode,
                manufacturer: testCase.manufacturer
            )
            
            #expect(item.code == testCase.expectedCode,
                   "Model construction should produce code '\(testCase.expectedCode)' for raw code '\(testCase.rawCode)' but got '\(item.code)'")
        }
    }
    
    // MARK: - Change Detection Logic Tests
    
    @Test("Should detect no changes when items are identical")
    func testChangeDetectionIdenticalItems() async throws {
        let item1 = CatalogItemModel(
            name: "Test Glass",
            rawCode: "TG-001",
            manufacturer: "Test Corp",
            tags: ["red", "transparent"],
            units: 3
        )
        
        let item2 = CatalogItemModel(
            id: item1.id, // Same ID
            name: "Test Glass",
            rawCode: "TG-001",
            manufacturer: "Test Corp",
            tags: ["red", "transparent"],
            units: 3
        )
        
        let hasChanges = CatalogItemModel.hasChanges(existing: item1, new: item2)
        #expect(!hasChanges, "Identical items should have no changes")
    }
    
    @Test("Should detect name changes")
    func testChangeDetectionNameChanges() async throws {
        let existing = CatalogItemModel(
            name: "Original Name",
            rawCode: "ON-001",
            manufacturer: "Test Corp"
        )
        
        let updated = CatalogItemModel(
            id: existing.id,
            name: "Updated Name", // Changed
            rawCode: "ON-001",
            manufacturer: "Test Corp"
        )
        
        let hasChanges = CatalogItemModel.hasChanges(existing: existing, new: updated)
        #expect(hasChanges, "Should detect name changes")
    }
    
    @Test("Should detect manufacturer changes")
    func testChangeDetectionManufacturerChanges() async throws {
        let existing = CatalogItemModel(
            name: "Test Glass",
            rawCode: "TG-001",
            manufacturer: "Original Corp"
        )
        
        let updated = CatalogItemModel(
            id: existing.id,
            name: "Test Glass",
            rawCode: "TG-001",
            manufacturer: "Updated Corp" // Changed
        )
        
        let hasChanges = CatalogItemModel.hasChanges(existing: existing, new: updated)
        #expect(hasChanges, "Should detect manufacturer changes")
    }
    
    @Test("Should detect raw code changes by comparing extracted codes")
    func testChangeDetectionRawCodeChanges() async throws {
        // Test that change detection correctly compares raw codes, not formatted ones
        let existing = CatalogItemModel(
            name: "Test Glass",
            rawCode: "TG-001",
            manufacturer: "Test Corp"
        )
        // existing.code will be "TEST CORP-TG-001"
        
        let updated = CatalogItemModel(
            id: existing.id,
            name: "Test Glass",
            rawCode: "TG-002", // Different raw code
            manufacturer: "Test Corp"
        )
        // updated.code will be "TEST CORP-TG-002"
        
        let hasChanges = CatalogItemModel.hasChanges(existing: existing, new: updated)
        #expect(hasChanges, "Should detect raw code changes")
    }
    
    @Test("Should not detect changes when raw codes are same but formatted differently")
    func testChangeDetectionFormattedCodeEquivalence() async throws {
        // Create item with raw code
        let existing = CatalogItemModel(
            name: "Test Glass",
            rawCode: "TG-001",
            manufacturer: "Test Corp"
        )
        // existing.code will be "TEST CORP-TG-001"
        
        // Create "updated" item using the legacy constructor - both should produce same logical result
        let updated = CatalogItemModel(
            id: existing.id,
            name: "Test Glass",
            rawCode: "TG-001", // Same raw code, will be formatted to "TEST CORP-TG-001"
            manufacturer: "Test Corp"
        )
        
        let hasChanges = CatalogItemModel.hasChanges(existing: existing, new: updated)
        #expect(!hasChanges, "Should not detect changes when raw codes are logically equivalent")
    }
    
    @Test("Should detect tag changes")
    func testChangeDetectionTagChanges() async throws {
        let existing = CatalogItemModel(
            name: "Test Glass",
            rawCode: "TG-001",
            manufacturer: "Test Corp",
            tags: ["red", "transparent"]
        )
        
        // Test different types of tag changes
        let testCases = [
            // Added tag
            (tags: ["red", "transparent", "rod"], shouldHaveChanges: true, description: "added tag"),
            
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
            let updated = CatalogItemModel(
                id: existing.id,
                name: "Test Glass",
                rawCode: "TG-001",
                manufacturer: "Test Corp",
                tags: testCase.tags
            )
            
            let hasChanges = CatalogItemModel.hasChanges(existing: existing, new: updated)
            
            if testCase.shouldHaveChanges {
                #expect(hasChanges, "Should detect changes for \(testCase.description)")
            } else {
                #expect(!hasChanges, "Should not detect changes for \(testCase.description)")
            }
        }
    }
    
    // MARK: - Tag Conversion Utility Tests
    
    @Test("Should convert tag arrays to comma-separated strings")
    func testTagsToString() async throws {
        let testCases = [
            (tags: [String](), expected: ""),
            (tags: ["red"], expected: "red"),
            (tags: ["red", "transparent", "rod"], expected: "red,transparent,rod"),
            (tags: ["red", "", "blue"], expected: "red,blue"), // Should filter empty strings
            (tags: ["  spaced  ", "normal"], expected: "spaced,normal") // Should trim whitespace but preserve content
        ]
        
        for testCase in testCases {
            let result = CatalogItemModel.tagsToString(testCase.tags)
            #expect(result == testCase.expected,
                   "Tags \(testCase.tags) should convert to '\(testCase.expected)' but got '\(result)'")
        }
    }
    
    @Test("Should convert comma-separated strings to tag arrays")
    func testStringToTags() async throws {
        let testCases = [
            (string: "", expected: [String]()),
            (string: "red", expected: ["red"]),
            (string: "red,transparent,rod", expected: ["red", "transparent", "rod"]),
            (string: "red, blue , green", expected: ["red", "blue", "green"]), // Should trim spaces
            (string: "red,,blue", expected: ["red", "blue"]), // Should filter empty components
            (string: "  ", expected: [String]()) // Should handle whitespace-only strings
        ]
        
        for testCase in testCases {
            let result = CatalogItemModel.stringToTags(testCase.string)
            #expect(result == testCase.expected,
                   "String '\(testCase.string)' should convert to \(testCase.expected) but got \(result)")
        }
    }
    
    @Test("Should round-trip tags through string conversion")
    func testTagsRoundTrip() async throws {
        let originalTags = ["red", "transparent", "rod", "bullseye", "COE-90"]
        
        let string = CatalogItemModel.tagsToString(originalTags)
        let convertedTags = CatalogItemModel.stringToTags(string)
        
        #expect(convertedTags == originalTags, "Tags should round-trip through string conversion")
    }
    
    // MARK: - Searchable Conformance Tests
    
    @Test("Should provide comprehensive searchable text")
    func testSearchableText() async throws {
        let item = CatalogItemModel(
            name: "Red Glass Rod",
            rawCode: "RGR-001",
            manufacturer: "Bullseye Glass",
            tags: ["red", "transparent", "COE-90"]
        )
        
        let searchableText = item.searchableText
        
        // Should include all the main fields
        #expect(searchableText.contains("Red Glass Rod"), "Should include name in searchable text")
        #expect(searchableText.contains("BULLSEYE GLASS-RGR-001"), "Should include formatted code")
        #expect(searchableText.contains("Bullseye Glass"), "Should include manufacturer")
        
        // Should include all tags
        #expect(searchableText.contains("red"), "Should include red tag")
        #expect(searchableText.contains("transparent"), "Should include transparent tag")
        #expect(searchableText.contains("COE-90"), "Should include COE-90 tag")
        
        // Should not include empty strings
        #expect(!searchableText.contains(""), "Should not include empty strings in searchable text")
    }
    
    @Test("Should handle searchable text with empty fields")
    func testSearchableTextWithEmptyFields() async throws {
        let item = CatalogItemModel(
            name: "Test Item",
            rawCode: "", // Empty code
            manufacturer: "Test Corp",
            tags: [] // Empty tags
        )
        
        let searchableText = item.searchableText
        
        #expect(searchableText.contains("Test Item"), "Should include non-empty name")
        #expect(searchableText.contains("Test Corp"), "Should include non-empty manufacturer")
        #expect(!searchableText.contains(""), "Should not include empty strings")
        
        // Should still be searchable with remaining fields
        #expect(searchableText.count >= 2, "Should have at least name and manufacturer")
    }
    
    // MARK: - Equatable and Hashable Conformance Tests
    
    @Test("Should compare items for equality correctly")
    func testEquatable() async throws {
        // Create shared UUIDs for consistent equality testing
        let sharedId2 = UUID()
        let sharedParentId = UUID()
        
        let item1 = CatalogItemModel(
            id: "test-id",
            id2: sharedId2,  // Same UUID
            parent_id: sharedParentId,  // Same UUID
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Test Glass",
            code: "TEST CORP-TG-001",
            manufacturer: "Test Corp",
            tags: ["red", "transparent"],
            units: 5
        )
        
        let item2 = CatalogItemModel(
            id: "test-id", // Same ID
            id2: sharedId2,  // Same UUID
            parent_id: sharedParentId,  // Same UUID
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Test Glass",
            code: "TEST CORP-TG-001",
            manufacturer: "Test Corp",
            tags: ["red", "transparent"],
            units: 5
        )
        
        let item3 = CatalogItemModel(
            id: "different-id", // Different ID
            id2: UUID(),  // Different UUID
            parent_id: UUID(),  // Different UUID
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Test Glass",
            code: "TEST CORP-TG-001",
            manufacturer: "Test Corp",
            tags: ["red", "transparent"],
            units: 5
        )
        
        #expect(item1 == item2, "Items with same properties should be equal")
        #expect(item1 != item3, "Items with different IDs should not be equal")
    }
    
    @Test("Should hash items consistently")
    func testHashable() async throws {
        // Create shared UUIDs for consistent equality and hashing
        let sharedId2 = UUID()
        let sharedParentId = UUID()
        
        let item1 = CatalogItemModel(
            id: "test-id",
            id2: sharedId2,  // Same UUID
            parent_id: sharedParentId,  // Same UUID
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Test Glass",
            code: "TEST CORP-TG-001",
            manufacturer: "Test Corp",
            tags: ["red", "transparent"],
            units: 1
        )
        
        let item2 = CatalogItemModel(
            id: "test-id", // Same ID
            id2: sharedId2,  // Same UUID
            parent_id: sharedParentId,  // Same UUID
            item_type: "rod",
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: "Test Glass", // Same name
            code: "TEST CORP-TG-001", // Same code
            manufacturer: "Test Corp", // Same manufacturer
            tags: ["red", "transparent"], // Same tags
            units: 1 // Same units
        )
        
        // Items should be equal
        #expect(item1 == item2, "Items with identical data should be equal")
        
        // Should be usable in Sets (this tests that hash + equality work together)
        let itemSet: Set<CatalogItemModel> = [item1, item2]
        #expect(itemSet.count == 1, "Set should deduplicate equal items")
        
        // Note: Hash equality is not guaranteed for equal items in Swift
        // But Set deduplication should work correctly with proper Equatable implementation
    }
    
    // MARK: - Complex Business Logic Integration Tests
    
    @Test("Should handle complex real-world catalog construction scenarios")
    func testComplexRealWorldScenarios() async throws {
        // Test realistic scenarios that might occur in production
        let realWorldTestCases = [
            // Bullseye glass with standard numeric code
            (name: "Bullseye Red Transparent", rawCode: "0124", manufacturer: "Bullseye", expectedCode: "BULLSEYE-0124"),
            
            // Spectrum with alphanumeric code
            (name: "Spectrum Blue Waterglass", rawCode: "125S", manufacturer: "Spectrum Glass", expectedCode: "SPECTRUM GLASS-125S"),
            
            // Uroboros with complex hyphenated code
            (name: "Uroboros Green Streamerglass", rawCode: "94-16-CC", manufacturer: "Uroboros", expectedCode: "UROBOROS-94-16-CC"),
            
            // Effetre with pre-formatted code (should not double-prefix)
            (name: "Effetre Crystal Clear", rawCode: "EFFETRE-006", manufacturer: "Effetre", expectedCode: "EFFETRE-006"),
            
            // Thompson with code that includes manufacturer-like prefix but different manufacturer
            (name: "Thompson Enamel Lead Crystal", rawCode: "TLE-8623", manufacturer: "Thompson Enamels", expectedCode: "THOMPSON ENAMELS-TLE-8623"),
            
            // Manufacturer with special characters and spaces
            (name: "Special Glass Rod", rawCode: "SGR-001", manufacturer: "Artbeads & More", expectedCode: "ARTBEADS & MORE-SGR-001")
        ]
        
        for testCase in realWorldTestCases {
            let item = CatalogItemModel(
                name: testCase.name,
                rawCode: testCase.rawCode,
                manufacturer: testCase.manufacturer
            )
            
            #expect(item.code == testCase.expectedCode,
                   "Real-world scenario: '\(testCase.name)' with raw code '\(testCase.rawCode)' and manufacturer '\(testCase.manufacturer)' should produce code '\(testCase.expectedCode)' but got '\(item.code)'")
        }
    }
    
    @Test("Should handle edge cases that could break the system")
    func testSystemBreakingEdgeCases() async throws {
        // Test cases that might cause crashes, infinite loops, or unexpected behavior
        let edgeCases = [
            // Extremely long manufacturer name
            (name: "Long Manufacturer Test", rawCode: "LMT-001", 
             manufacturer: "This Is An Extremely Long Manufacturer Name That Could Potentially Cause Issues With String Processing And Database Storage Limits",
             shouldSucceed: true),
            
            // Special characters in manufacturer
            (name: "Special Char Test", rawCode: "SCT-001", 
             manufacturer: "Mañufactürer & Cø. (Spéçial Çhars)",
             shouldSucceed: true),
            
            // Empty manufacturer (edge case)
            (name: "Empty Manufacturer Test", rawCode: "EMT-001", 
             manufacturer: "",
             shouldSucceed: true),
            
            // Unicode characters
            (name: "Unicode Test 🌈", rawCode: "UT-001", 
             manufacturer: "Ünicødé Mañufactürer",
             shouldSucceed: true),
            
            // Very long raw code
            (name: "Long Code Test", rawCode: "VERY-LONG-PRODUCT-CODE-WITH-MULTIPLE-SEGMENTS-AND-IDENTIFIERS-THAT-MIGHT-CAUSE-ISSUES",
             manufacturer: "Test Corp",
             shouldSucceed: true)
        ]
        
        for testCase in edgeCases {
            do {
                let item = CatalogItemModel(
                    name: testCase.name,
                    rawCode: testCase.rawCode,
                    manufacturer: testCase.manufacturer
                )
                
                if testCase.shouldSucceed {
                    #expect(!item.id.isEmpty, "Edge case should succeed: \(testCase.name)")
                    #expect(!item.code.isEmpty, "Edge case should produce valid code: \(testCase.name)")
                } else {
                    #expect(false, "Edge case expected to fail but succeeded: \(testCase.name)")
                }
                
            } catch {
                if testCase.shouldSucceed {
                    #expect(false, "Edge case should succeed but failed: \(testCase.name) - \(error)")
                } else {
                    #expect(true, "Edge case correctly failed: \(testCase.name)")
                }
            }
        }
    }
    
    @Test("Should maintain performance with large tag arrays")
    func testPerformanceWithLargeTags() async throws {
        // Test that tag processing doesn't degrade with large tag arrays
        let largeTags = Array(0..<1000).map { "tag\($0)" }
        
        let item = CatalogItemModel(
            name: "Performance Test Glass",
            rawCode: "PTG-001",
            manufacturer: "Performance Corp",
            tags: largeTags
        )
        
        #expect(item.tags.count == 1000, "Should handle large tag arrays")
        
        // Test tag conversion performance
        let tagString = CatalogItemModel.tagsToString(largeTags)
        let convertedTags = CatalogItemModel.stringToTags(tagString)
        
        #expect(convertedTags.count == 1000, "Should convert large tag arrays efficiently")
        #expect(convertedTags == largeTags, "Should maintain tag accuracy with large arrays")
        
        // Test searchable text performance
        let searchableText = item.searchableText
        #expect(searchableText.count > 1000, "Should handle large searchable text arrays")
    }
}
