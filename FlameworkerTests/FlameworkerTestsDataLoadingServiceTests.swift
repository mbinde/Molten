//
//  DataLoadingServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("DataLoadingService Tests")
struct DataLoadingServiceTests {
    
    // MARK: - Test Data Setup
    
    private var testData: Data {
        let catalogItems = [
            [
                "name": "Test Item 1",
                "code": "TEST001",
                "manufacturer": "Test Manufacturer"
            ],
            [
                "name": "Test Item 2", 
                "code": "TEST002",
                "manufacturer": "Test Manufacturer"
            ]
        ]
        
        return try! JSONSerialization.data(withJSONObject: catalogItems)
    }
    
    // MARK: - Singleton Tests
    
    @Test("DataLoadingService shared instance is singleton")
    func dataLoadingServiceIsSingleton() {
        let instance1 = DataLoadingService.shared
        let instance2 = DataLoadingService.shared
        
        #expect(instance1 === instance2)
    }
    
    // MARK: - JSON Decoding Tests
    
    @Test("Decode catalog items from valid JSON")
    func decodeCatalogItemsFromValidJSON() throws {
        let service = DataLoadingService.shared
        
        let items = try service.decodeCatalogItems(from: testData)
        
        #expect(items.count == 2)
        #expect(items[0].name == "Test Item 1")
        #expect(items[0].code == "TEST001")
        #expect(items[1].name == "Test Item 2")
        #expect(items[1].code == "TEST002")
    }
    
    @Test("Decode catalog items from invalid JSON throws error")
    func decodeCatalogItemsFromInvalidJSONThrows() {
        let service = DataLoadingService.shared
        let invalidData = "invalid json".data(using: .utf8)!
        
        #expect(throws: Error.self) {
            try service.decodeCatalogItems(from: invalidData)
        }
    }
    
    @Test("Decode catalog items from empty JSON array")
    func decodeCatalogItemsFromEmptyJSON() throws {
        let service = DataLoadingService.shared
        let emptyData = "[]".data(using: .utf8)!
        
        let items = try service.decodeCatalogItems(from: emptyData)
        
        #expect(items.isEmpty)
    }
    
    // MARK: - DataLoadingError Tests
    
    @Test("DataLoadingError file not found description")
    func dataLoadingErrorFileNotFound() {
        let error = DataLoadingError.fileNotFound("test.json not found")
        
        #expect(error.errorDescription == "test.json not found")
    }
    
    @Test("DataLoadingError decoding failed description")
    func dataLoadingErrorDecodingFailed() {
        let error = DataLoadingError.decodingFailed("Invalid JSON format")
        
        #expect(error.errorDescription == "Invalid JSON format")
    }
    
    @Test("DataLoadingError conforms to LocalizedError")
    func dataLoadingErrorIsLocalizedError() {
        let error = DataLoadingError.fileNotFound("test")
        
        #expect(error is LocalizedError)
    }
}