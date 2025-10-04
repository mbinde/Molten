//  NetworkLayerTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("Network Layer Tests")
struct NetworkLayerTests {
    
    @Test("Basic network test setup")
    func basicNetworkTest() {
        // Simple test to ensure we can create tests in this suite
        let testValue = "network"
        #expect(testValue == "network")
    }
    
    @Test("JSONDataLoader can be created")
    func jsonDataLoaderCreation() {
        let loader = JSONDataLoader()
        // Basic test that we can instantiate the JSON loader
        #expect(loader != nil)
    }
    
    @Test("DataLoadingService singleton exists")
    func dataLoadingServiceSingleton() {
        let service = DataLoadingService.shared
        // Test that singleton can be accessed
        #expect(service != nil)
    }
    
    @Test("DataLoadingService returns same instance")
    func dataLoadingServiceSameInstance() {
        let service1 = DataLoadingService.shared
        let service2 = DataLoadingService.shared
        // Test singleton pattern
        #expect(service1 === service2)
    }
    
    @Test("JSONDataLoader handles empty data gracefully")
    func jsonDataLoaderEmptyData() {
        let loader = JSONDataLoader()
        let emptyData = Data()
        
        #expect(throws: Error.self) {
            try loader.decodeCatalogItems(from: emptyData)
        }
    }
    
    @Test("DataLoadingError types can be created")
    func dataLoadingErrorTypes() {
        let fileError = DataLoadingError.fileNotFound("test.json")
        let decodingError = DataLoadingError.decodingFailed("bad json")
        
        #expect(fileError.errorDescription == "test.json")
        #expect(decodingError.errorDescription == "bad json")
    }
    
    @Test("JSONDataLoader handles valid JSON array")
    func jsonDataLoaderValidArray() throws {
        let loader = JSONDataLoader()
        let validJSON = """
        [
            {
                "name": "Test Item",
                "code": "TEST001",
                "manufacturer": "Test Mfg"
            }
        ]
        """.data(using: .utf8)!
        
        let items = try loader.decodeCatalogItems(from: validJSON)
        #expect(items.count == 1)
        #expect(items.first?.name == "Test Item")
    }
    
    @Test("JSONDataLoader handles malformed JSON")
    func jsonDataLoaderMalformedJSON() {
        let loader = JSONDataLoader()
        let malformedJSON = "{ invalid json }".data(using: .utf8)!
        
        #expect(throws: Error.self) {
            try loader.decodeCatalogItems(from: malformedJSON)
        }
    }
    
    @Test("Bundle resource loading validates resource names")
    func bundleResourceValidation() {
        let loader = JSONDataLoader()
        
        // Test that findCatalogJSONData eventually throws if no valid files exist
        // This is testing the error path when bundle resources aren't available
        #expect(throws: DataLoadingError.self) {
            try loader.findCatalogJSONData()
        }
    }
    
    // TODO: Add more comprehensive bundle loading tests when test resources are available
}