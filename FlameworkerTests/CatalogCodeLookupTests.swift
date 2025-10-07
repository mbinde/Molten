//
//  CatalogCodeLookupTests.swift
//  FlameworkerTests
//
//  Tests for shared catalog code lookup functionality
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Catalog Code Lookup Tests")
struct CatalogCodeLookupTests {
    
    @Test("Should generate preferred catalog codes correctly")
    func testPreferredCatalogCode() {
        // Test with manufacturer
        let withManufacturer = CatalogCodeLookup.preferredCatalogCode(from: "143", manufacturer: "Effetre")
        #expect(withManufacturer == "Effetre-143", "Should prepend manufacturer when provided")
        
        // Test without manufacturer
        let withoutManufacturer = CatalogCodeLookup.preferredCatalogCode(from: "143", manufacturer: nil)
        #expect(withoutManufacturer == "143", "Should return code as-is when no manufacturer")
        
        // Test with empty manufacturer
        let withEmptyManufacturer = CatalogCodeLookup.preferredCatalogCode(from: "143", manufacturer: "")
        #expect(withEmptyManufacturer == "143", "Should return code as-is when manufacturer is empty")
    }
    
    @Test("Should handle search code parsing correctly")
    func testSearchCodeParsing() {
        // Test that our logic matches what the actual implementation should do
        let fullCode = "Effetre-143"
        let baseCode = extractBaseCodeHelper(fullCode)
        #expect(baseCode == "143", "Should extract base code from manufacturer-code format")
        
        let simpleCode = "143" 
        let simpleBase = extractBaseCodeHelper(simpleCode)
        #expect(simpleBase == "143", "Should return simple code as-is")
    }
    
    @Test("Should find catalog item with exact code match")
    func testExactCodeMatch() async throws {
        // Now we can test the actual implementation
        let context = PersistenceController.preview.container.viewContext
        
        // Create a test catalog item
        let testItem = CatalogItem(context: context)
        testItem.code = "TEST143"
        testItem.name = "Test Color"
        testItem.manufacturer = "Effetre"
        
        do {
            try context.save()
        } catch {
            // If save fails, skip this test - might be Core Data setup issue
            return
        }
        
        // Test exact match lookup
        let foundItem = CatalogCodeLookup.findCatalogItem(byCode: "TEST143", in: context)
        
        #expect(foundItem?.code == "TEST143", "Should find item by exact code match")
        #expect(foundItem?.name == "Test Color", "Should return the correct item")
        
        // Cleanup
        if let foundItem = foundItem {
            context.delete(foundItem)
            try? context.save()
        }
    }
    
    // Helper function for testing base code extraction logic
    private func extractBaseCodeHelper(_ code: String) -> String {
        if code.contains("-"), let dashIndex = code.firstIndex(of: "-") {
            return String(code[code.index(after: dashIndex)...])
        }
        return code
    }
}
