//
//  MockJSONDataLoader.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Protocol for JSON data loading (for dependency injection)
protocol JSONDataLoading {
    func findCatalogJSONData() throws -> Data
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData]
}

/// Make the existing JSONDataLoader conform to the protocol
extension JSONDataLoader: JSONDataLoading {}

/// Mock implementation of JSONDataLoading for testing
/// Provides controlled test data instead of loading from actual JSON files
class MockJSONDataLoader: JSONDataLoading {
    
    // MARK: - Test Configuration
    
    /// Controls what test data to return
    var testDataMode: TestDataMode = .small
    
    /// Custom test data (used when mode is .custom)
    var customTestData: [CatalogItemData] = []
    
    enum TestDataMode {
        case empty       // Return empty array
        case small       // Return 2-3 test items
        case medium      // Return ~10 test items
        case custom      // Return customTestData
    }
    
    // MARK: - JSONDataLoading Implementation
    
    func findCatalogJSONData() throws -> Data {
        // For mock, we don't actually need to encode JSON, 
        // just return some dummy data since decodeCatalogItems ignores it
        return Data()
    }
    
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        // Return our controlled test data
        return getTestCatalogData()
    }
    
    // MARK: - Test Data Generation
    
    private func getTestCatalogData() -> [CatalogItemData] {
        switch testDataMode {
        case .empty:
            return []
            
        case .small:
            return [
                CatalogItemData(
                    id: "test1",
                    code: "TESTMFG-001",
                    manufacturer: "TestManufacturer",
                    name: "Test Red Glass",
                    manufacturer_description: "Test red glass for unit tests",
                    synonyms: ["red", "test"],
                    tags: ["red", "test", "unit-test"],
                    image_path: nil,
                    coe: "96",
                    stock_type: "rod",
                    image_url: nil,
                    manufacturer_url: "https://test.example.com"
                ),
                CatalogItemData(
                    id: "test2",
                    code: "TESTMFG-002",
                    manufacturer: "TestManufacturer",
                    name: "Test Blue Glass",
                    manufacturer_description: "Test blue glass for unit tests",
                    synonyms: ["blue", "test"],
                    tags: ["blue", "test", "unit-test"],
                    image_path: nil,
                    coe: "104",
                    stock_type: "rod",
                    image_url: nil,
                    manufacturer_url: "https://test.example.com"
                ),
                CatalogItemData(
                    id: "test3",
                    code: "ANOTHERMFG-001",
                    manufacturer: "AnotherTestMfg",
                    name: "Test Clear Glass",
                    manufacturer_description: "Test clear glass for unit tests",
                    synonyms: ["clear", "transparent"],
                    tags: ["clear", "test", "unit-test"],
                    image_path: nil,
                    coe: "90",
                    stock_type: "sheet",
                    image_url: nil,
                    manufacturer_url: "https://another.test.example.com"
                )
            ]
            
        case .medium:
            var items: [CatalogItemData] = []
            
            // Start with the small data
            items.append(contentsOf: [
                CatalogItemData(
                    id: "test1",
                    code: "TESTMFG-001",
                    manufacturer: "TestManufacturer",
                    name: "Test Red Glass",
                    manufacturer_description: "Test red glass for unit tests",
                    synonyms: ["red", "test"],
                    tags: ["red", "test", "unit-test"],
                    image_path: nil,
                    coe: "96",
                    stock_type: "rod",
                    image_url: nil,
                    manufacturer_url: "https://test.example.com"
                ),
                CatalogItemData(
                    id: "test2",
                    code: "TESTMFG-002",
                    manufacturer: "TestManufacturer",
                    name: "Test Blue Glass",
                    manufacturer_description: "Test blue glass for unit tests",
                    synonyms: ["blue", "test"],
                    tags: ["blue", "test", "unit-test"],
                    image_path: nil,
                    coe: "104",
                    stock_type: "rod",
                    image_url: nil,
                    manufacturer_url: "https://test.example.com"
                ),
                CatalogItemData(
                    id: "test3",
                    code: "ANOTHERMFG-001",
                    manufacturer: "AnotherTestMfg",
                    name: "Test Clear Glass",
                    manufacturer_description: "Test clear glass for unit tests",
                    synonyms: ["clear", "transparent"],
                    tags: ["clear", "test", "unit-test"],
                    image_path: nil,
                    coe: "90",
                    stock_type: "sheet",
                    image_url: nil,
                    manufacturer_url: "https://another.test.example.com"
                )
            ])
            
            // Add more test items
            for i in 4...10 {
                items.append(CatalogItemData(
                    id: "test\(i)",
                    code: "TESTMFG-\(String(format: "%03d", i))",
                    manufacturer: "TestManufacturer",
                    name: "Test Glass \(i)",
                    manufacturer_description: "Test glass item \(i) for unit tests",
                    synonyms: nil,
                    tags: ["test", "unit-test", "item\(i)"],
                    image_path: nil,
                    coe: i % 2 == 0 ? "96" : "104",
                    stock_type: "rod",
                    image_url: nil,
                    manufacturer_url: "https://test.example.com"
                ))
            }
            return items
            
        case .custom:
            return customTestData
        }
    }
    
    // MARK: - Test Helpers
    
    /// Set up the mock to return empty data
    func configureForEmptyData() {
        testDataMode = .empty
    }
    
    /// Set up the mock to return small, controllable test data
    func configureForSmallData() {
        testDataMode = .small
    }
    
    /// Set up the mock to return medium-sized test data
    func configureForMediumData() {
        testDataMode = .medium
    }
    
    /// Set up the mock to return custom test data
    func configureForCustomData(_ data: [CatalogItemData]) {
        customTestData = data
        testDataMode = .custom
    }
}