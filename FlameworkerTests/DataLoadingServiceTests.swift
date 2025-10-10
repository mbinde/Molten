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