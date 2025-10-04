//
//  SortUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
@testable import Flameworker

@Suite("SortUtilities Tests - Comprehensive Sorting Logic")
struct SortUtilitiesTests {
    
    // MARK: - Test Data Setup
    
    /// Helper to create a mock CatalogItem for testing
    private func createMockCatalogItem(
        name: String? = nil,
        code: String? = nil,
        manufacturer: String? = nil
    ) -> MockCatalogItem {
        return MockCatalogItem(name: name, code: code, manufacturer: manufacturer)
    }
    
    // MARK: - Sort by Name Tests
    
    @Test("Should sort catalog items by name ascending")
    func testSortByNameAscending() {
        // Arrange
        let items = [
            createMockCatalogItem(name: "Zebra Glass"),
            createMockCatalogItem(name: "Alpha Glass"),
            createMockCatalogItem(name: "Beta Glass")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].name == "Alpha Glass")
        #expect(sortedItems[1].name == "Beta Glass") 
        #expect(sortedItems[2].name == "Zebra Glass")
    }
    
    @Test("Should handle nil names when sorting by name")
    func testSortByNameWithNilValues() {
        // Arrange
        let items = [
            createMockCatalogItem(name: "Beta Glass"),
            createMockCatalogItem(name: nil),
            createMockCatalogItem(name: "Alpha Glass")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].name == "Alpha Glass")
        #expect(sortedItems[1].name == "Beta Glass")
        #expect(sortedItems[2].name == nil, "Nil names should sort to end")
    }
    
    @Test("Should handle empty names when sorting by name")
    func testSortByNameWithEmptyValues() {
        // Arrange
        let items = [
            createMockCatalogItem(name: "Charlie Glass"),
            createMockCatalogItem(name: ""),
            createMockCatalogItem(name: "Alpha Glass"),
            createMockCatalogItem(name: "   ") // whitespace only
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 4)
        #expect(sortedItems[0].name == "Alpha Glass")
        #expect(sortedItems[1].name == "Charlie Glass")
        // Empty and whitespace names should sort to end
        #expect(sortedItems[2].name == "" || sortedItems[2].name == "   ")
        #expect(sortedItems[3].name == "" || sortedItems[3].name == "   ")
    }
    
    // MARK: - Sort by Code Tests
    
    @Test("Should sort catalog items by code ascending")
    func testSortByCodeAscending() {
        // Arrange
        let items = [
            createMockCatalogItem(code: "CIM-789"),
            createMockCatalogItem(code: "CIM-123"),
            createMockCatalogItem(code: "CIM-456")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .code)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].code == "CIM-123")
        #expect(sortedItems[1].code == "CIM-456")
        #expect(sortedItems[2].code == "CIM-789")
    }
    
    @Test("Should handle nil codes when sorting by code")
    func testSortByCodeWithNilValues() {
        // Arrange
        let items = [
            createMockCatalogItem(code: "CIM-456"),
            createMockCatalogItem(code: nil),
            createMockCatalogItem(code: "CIM-123")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .code)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].code == "CIM-123")
        #expect(sortedItems[1].code == "CIM-456")
        #expect(sortedItems[2].code == nil, "Nil codes should sort to end")
    }
    
    // MARK: - Sort by Manufacturer Tests
    
    @Test("Should sort catalog items by manufacturer with COE priority") 
    func testSortByManufacturerWithCOE() {
        // Arrange - Create items with manufacturers from different COE groups
        let items = [
            createMockCatalogItem(manufacturer: "Kugler"),     // COE 104
            createMockCatalogItem(manufacturer: "Bullseye"),   // COE 90
            createMockCatalogItem(manufacturer: "Effetre")     // COE 104
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .manufacturer)
        
        // Assert
        #expect(sortedItems.count == 3)
        // COE 90 should come first (Bullseye), then COE 104 items alphabetically
        #expect(sortedItems[0].manufacturer == "Bullseye")
        // Within COE 104, Effetre should come before Kugler alphabetically
        #expect(sortedItems[1].manufacturer == "Effetre")
        #expect(sortedItems[2].manufacturer == "Kugler")
    }
    
    @Test("Should handle unknown manufacturers when sorting")
    func testSortByManufacturerWithUnknownManufacturers() {
        // Arrange - Mix known and unknown manufacturers
        let items = [
            createMockCatalogItem(manufacturer: "Unknown Brand"),
            createMockCatalogItem(manufacturer: "Bullseye"),      // COE 90
            createMockCatalogItem(manufacturer: "Another Unknown")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .manufacturer)
        
        // Assert
        #expect(sortedItems.count == 3)
        // Known COE manufacturers should come first
        #expect(sortedItems[0].manufacturer == "Bullseye")
        // Unknown manufacturers should sort alphabetically at end
        let unknownManufacturers = sortedItems.dropFirst().map { $0.manufacturer }
        #expect(unknownManufacturers.contains("Another Unknown"))
        #expect(unknownManufacturers.contains("Unknown Brand"))
    }
    
    @Test("Should handle nil manufacturers when sorting")
    func testSortByManufacturerWithNilValues() {
        // Arrange
        let items = [
            createMockCatalogItem(manufacturer: "Kugler"),
            createMockCatalogItem(manufacturer: nil),
            createMockCatalogItem(manufacturer: "Bullseye")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .manufacturer)
        
        // Assert
        #expect(sortedItems.count == 3)
        // Known manufacturers should come first in COE order
        #expect(sortedItems[0].manufacturer == "Bullseye") // COE 90
        #expect(sortedItems[1].manufacturer == "Kugler")   // COE 104
        #expect(sortedItems[2].manufacturer == nil, "Nil manufacturers should sort to end")
    }
    
    // MARK: - Edge Cases and Robustness Tests
    
    @Test("Should handle empty array")
    func testSortEmptyArray() {
        // Arrange
        let items: [MockCatalogItem] = []
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.isEmpty)
    }
    
    @Test("Should handle single item array")
    func testSortSingleItemArray() {
        // Arrange
        let items = [createMockCatalogItem(name: "Single Item")]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 1)
        #expect(sortedItems[0].name == "Single Item")
    }
    
    @Test("Should handle case insensitive sorting")
    func testCaseInsensitiveSorting() {
        // Arrange
        let items = [
            createMockCatalogItem(name: "zebra Glass"),  // lowercase z
            createMockCatalogItem(name: "Alpha Glass"),  // uppercase A  
            createMockCatalogItem(name: "beta Glass")    // lowercase b
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].name == "Alpha Glass")
        #expect(sortedItems[1].name == "beta Glass") 
        #expect(sortedItems[2].name == "zebra Glass")
    }
}

// MARK: - Mock Objects for Testing

/// Mock CatalogItem for testing SortUtilities without Core Data dependencies
class MockCatalogItem: CatalogSortable {
    var name: String?
    var code: String? 
    var manufacturer: String?
    
    init(name: String? = nil, code: String? = nil, manufacturer: String? = nil) {
        self.name = name
        self.code = code
        self.manufacturer = manufacturer
    }
}
