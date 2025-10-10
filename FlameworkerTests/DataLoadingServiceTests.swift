//
//  DataLoadingServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation
import CoreData

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

// Use Swift Testing if available, otherwise fall back to XCTest
#if canImport(Testing)

@Suite("DataLoadingService Tests")
struct DataLoadingServiceTests {
    
    @Test("Should maintain singleton pattern")
    func testDataLoadingServiceSingleton() throws {
        // Act
        let instance1 = DataLoadingService.shared
        let instance2 = DataLoadingService.shared
        
        // Assert
        #expect(instance1 === instance2)
    }
    
    @Test("Should decode valid JSON data into CatalogItemData array")
    func testDecodeCatalogItemsWithValidJSON() throws {
        // Arrange
        let validJSON = """
        [
            {
                "code": "TEST-001",
                "name": "Test Item 1",
                "manufacturer": "Test Manufacturer",
                "type": "rod",
                "tags": "clear,borosilicate"
            },
            {
                "code": "TEST-002", 
                "name": "Test Item 2",
                "manufacturer": "Another Manufacturer",
                "type": "frit",
                "tags": "colored,fine"
            }
        ]
        """
        
        let jsonData = validJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act
        let result = try service.decodeCatalogItems(from: jsonData)
        
        // Assert
        #expect(result.count == 2)
        #expect(result[0].code == "TEST-001")
        #expect(result[0].name == "Test Item 1") 
        #expect(result[1].code == "TEST-002")
        #expect(result[1].name == "Test Item 2")
    }
    
    @Test("Should throw error for invalid JSON data")
    func testDecodeCatalogItemsWithInvalidJSON() throws {
        // Arrange
        let invalidJSON = """
        [
            {
                "code": "TEST-001",
                "name": "Test Item 1"
                // Missing comma and closing bracket - invalid JSON
            }
        """
        
        let jsonData = invalidJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act & Assert
        #expect(throws: Error.self) {
            try service.decodeCatalogItems(from: jsonData)
        }
    }
    
    // MARK: - Enhanced JSON Decoding Tests
    
    @Test("Should handle empty JSON array correctly")
    func testDecodeEmptyJSONArray() throws {
        // Arrange
        let emptyJSON = "[]"
        let jsonData = emptyJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act
        let result = try service.decodeCatalogItems(from: jsonData)
        
        // Assert
        #expect(result.isEmpty, "Empty JSON array should return empty array")
        #expect(result.count == 0, "Count should be zero for empty array")
    }
    
    @Test("Should handle JSON with missing optional fields")
    func testDecodeJSONWithMissingOptionalFields() throws {
        // Arrange
        let partialJSON = """
        [
            {
                "code": "PARTIAL-001",
                "name": "Minimal Item"
            },
            {
                "code": "PARTIAL-002",
                "name": "Another Item",
                "manufacturer": "Test Manufacturer"
            }
        ]
        """
        
        let jsonData = partialJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act
        let result = try service.decodeCatalogItems(from: jsonData)
        
        // Assert
        #expect(result.count == 2, "Should decode items with missing optional fields")
        #expect(result[0].code == "PARTIAL-001", "Should preserve code")
        #expect(result[0].name == "Minimal Item", "Should preserve name")
        #expect(result[1].manufacturer == "Test Manufacturer", "Should preserve manufacturer when present")
    }
    
    @Test("Should handle JSON with null values")
    func testDecodeJSONWithNullValues() throws {
        // Arrange
        let nullJSON = """
        [
            {
                "code": "NULL-001",
                "name": "Item with Nulls",
                "manufacturer": null,
                "type": null,
                "tags": null
            }
        ]
        """
        
        let jsonData = nullJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act
        let result = try service.decodeCatalogItems(from: jsonData)
        
        // Assert
        #expect(result.count == 1, "Should handle null values gracefully")
        #expect(result[0].code == "NULL-001", "Should preserve non-null fields")
        #expect(result[0].name == "Item with Nulls", "Should preserve non-null fields")
    }
    
    @Test("Should fail gracefully with malformed data structures")
    func testDecodeJSONWithMalformedData() throws {
        // Arrange - JSON that's valid but has wrong structure
        let malformedJSON = """
        {
            "not_an_array": "this should be an array"
        }
        """
        
        let jsonData = malformedJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act & Assert
        #expect(throws: Error.self) {
            try service.decodeCatalogItems(from: jsonData)
        }
    }
    
    @Test("Should handle large JSON datasets efficiently")
    func testDecodeLargeJSONDataset() throws {
        // Arrange - Generate a large JSON array
        var items: [String] = []
        for i in 1...100 {
            let item = """
            {
                "code": "LARGE-\(String(format: "%03d", i))",
                "name": "Large Dataset Item \(i)",
                "manufacturer": "Manufacturer \(i % 10)",
                "type": "\(i % 2 == 0 ? "rod" : "frit")",
                "tags": "test,large,dataset"
            }
            """
            items.append(item)
        }
        
        let largeJSON = "[\(items.joined(separator: ","))]"
        let jsonData = largeJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act
        let startTime = Date()
        let result = try service.decodeCatalogItems(from: jsonData)
        let endTime = Date()
        
        // Assert
        #expect(result.count == 100, "Should decode all 100 items")
        #expect(result[0].code == "LARGE-001", "Should preserve first item")
        #expect(result[99].code == "LARGE-100", "Should preserve last item")
        
        let processingTime = endTime.timeIntervalSince(startTime)
        #expect(processingTime < 1.0, "Should process 100 items in under 1 second (actual: \(processingTime)s)")
    }
    
    // MARK: - Error Handling and Edge Cases
    
    @Test("Should handle empty data gracefully")
    func testDecodeEmptyData() throws {
        // Arrange
        let emptyData = Data()
        let service = DataLoadingService.shared
        
        // Act & Assert
        #expect(throws: Error.self) {
            try service.decodeCatalogItems(from: emptyData)
        }
    }
    
    @Test("Should handle non-UTF8 data")
    func testDecodeNonUTF8Data() throws {
        // Arrange - Create some non-UTF8 data
        let nonUTF8Data = Data([0xFF, 0xFE, 0xFD])
        let service = DataLoadingService.shared
        
        // Act & Assert
        #expect(throws: Error.self) {
            try service.decodeCatalogItems(from: nonUTF8Data)
        }
    }
    
    @Test("Should handle Unicode characters in JSON")
    func testDecodeUnicodeJSON() throws {
        // Arrange
        let unicodeJSON = """
        [
            {
                "code": "UNICODE-001",
                "name": "Émile's Special Glass 🔥",
                "manufacturer": "Mañufacturer Spéciàl",
                "tags": "émoji,spéciàl,中文"
            }
        ]
        """
        
        let jsonData = unicodeJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act
        let result = try service.decodeCatalogItems(from: jsonData)
        
        // Assert
        #expect(result.count == 1, "Should handle Unicode characters")
        #expect(result[0].name == "Émile's Special Glass 🔥", "Should preserve Unicode in names")
        #expect(result[0].manufacturer == "Mañufacturer Spéciàl", "Should preserve Unicode in manufacturer")
    }
}

#else

// Fallback to XCTest if Swift Testing is not available
class DataLoadingServiceTests: XCTestCase {
    
    func testDataLoadingServiceSingleton() throws {
        // Act
        let instance1 = DataLoadingService.shared
        let instance2 = DataLoadingService.shared
        
        // Assert
        XCTAssertTrue(instance1 === instance2)
    }
    
    func testDecodeCatalogItemsWithValidJSON() throws {
        // Arrange
        let validJSON = """
        [
            {
                "code": "TEST-001",
                "name": "Test Item 1",
                "manufacturer": "Test Manufacturer",
                "type": "rod",
                "tags": "clear,borosilicate"
            },
            {
                "code": "TEST-002", 
                "name": "Test Item 2",
                "manufacturer": "Another Manufacturer",
                "type": "frit",
                "tags": "colored,fine"
            }
        ]
        """
        
        let jsonData = validJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act
        let result = try service.decodeCatalogItems(from: jsonData)
        
        // Assert
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].code, "TEST-001")
        XCTAssertEqual(result[0].name, "Test Item 1")
        XCTAssertEqual(result[1].code, "TEST-002")
        XCTAssertEqual(result[1].name, "Test Item 2")
    }
    
    func testDecodeCatalogItemsWithInvalidJSON() throws {
        // Arrange
        let invalidJSON = """
        [
            {
                "code": "TEST-001",
                "name": "Test Item 1"
                // Missing comma and closing bracket - invalid JSON
            }
        """
        
        let jsonData = invalidJSON.data(using: .utf8)!
        let service = DataLoadingService.shared
        
        // Act & Assert
        XCTAssertThrowsError(try service.decodeCatalogItems(from: jsonData)) { error in
            // Verify it's a decoding error
            XCTAssertTrue(error is DecodingError || error is DataLoadingError)
        }
    }
}

#endif