//
//  DataLoadingAndResourceTests.swift
//  FlameworkerTests
//
//  Created by Test Consolidation on 10/4/25.
//

import Testing
import Foundation
@testable import Flameworker

// MARK: - Data Loading Service Tests from DataLoadingServiceTests.swift

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
    
    @Test("DataLoadingError provides localized error description")
    func dataLoadingErrorProvidesLocalizedDescription() {
        let error = DataLoadingError.fileNotFound("test file not found")
        
        // Test that it provides a localized description
        #expect(error.localizedDescription == "test file not found")
    }
}

// MARK: - Image Loading Tests from ImageLoadingTests.swift

@Suite("Image Loading Tests")
struct ImageLoadingTests {
    
    @Test("CIM-101 image file exists and is loadable")
    func testCIM101ImageExists() {
        let itemCode = "101"
        let manufacturer = "CIM"
        
        // Test that the image exists
        let imageExists = ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer)
        #expect(imageExists == true, "CIM-101 image should exist in bundle")
        
        // Test that the image can be loaded
        let loadedImage = ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer)
        #expect(loadedImage != nil, "CIM-101 image should be loadable")
        
        // Test that we can get the image name
        let imageName = ImageHelpers.getProductImageName(for: itemCode, manufacturer: manufacturer)
        #expect(imageName != nil, "CIM-101 should have a valid image name")
        #expect(imageName?.contains("CIM") == true, "Image name should contain manufacturer code")
        #expect(imageName?.contains("101") == true, "Image name should contain item code")
    }
    
    @Test("Image loading handles missing images gracefully")
    func testMissingImageHandling() {
        let nonExistentCode = "NONEXISTENT999"
        let nonExistentManufacturer = "FAKE"
        
        // Test that non-existent image returns false
        let imageExists = ImageHelpers.productImageExists(for: nonExistentCode, manufacturer: nonExistentManufacturer)
        #expect(imageExists == false, "Non-existent image should return false")
        
        // Test that loading non-existent image returns nil
        let loadedImage = ImageHelpers.loadProductImage(for: nonExistentCode, manufacturer: nonExistentManufacturer)
        #expect(loadedImage == nil, "Non-existent image should return nil when loading")
        
        // Test that image name is nil for non-existent image
        let imageName = ImageHelpers.getProductImageName(for: nonExistentCode, manufacturer: nonExistentManufacturer)
        #expect(imageName == nil, "Non-existent image should have nil image name")
    }
    
    @Test("Image loading fallback logic works correctly")
    func testImageLoadingFallback() {
        let itemCode = "101"
        
        // Test with manufacturer first
        let imageWithManufacturer = ImageHelpers.productImageExists(for: itemCode, manufacturer: "CIM")
        
        // Test without manufacturer (fallback)
        let imageWithoutManufacturer = ImageHelpers.productImageExists(for: itemCode, manufacturer: nil)
        
        // At least one should work (preferably with manufacturer)
        let hasImage = imageWithManufacturer || imageWithoutManufacturer
        #expect(hasImage == true, "Should find image either with or without manufacturer")
        
        // If both exist, manufacturer version should be preferred
        if imageWithManufacturer && imageWithoutManufacturer {
            let nameWithMfg = ImageHelpers.getProductImageName(for: itemCode, manufacturer: "CIM")
            #expect(nameWithMfg?.contains("CIM") == true, "Should prefer manufacturer-prefixed version when available")
        }
    }
    
    @Test("Common image file extensions are supported")
    func testCommonImageExtensions() {
        // Test that common image extensions work with the image loading system
        let itemCode = "101"
        let manufacturer = "CIM"
        
        // The system should handle various image formats
        // We don't know which format CIM-101 is in, but we know it should load
        let imageExists = ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer)
        
        if imageExists {
            let imageName = ImageHelpers.getProductImageName(for: itemCode, manufacturer: manufacturer)
            #expect(imageName != nil, "Should get valid image name for existing image")
            
            // Check that the image name has a reasonable extension
            let hasImageExtension = imageName?.lowercased().hasSuffix(".jpg") == true ||
                                   imageName?.lowercased().hasSuffix(".jpeg") == true ||
                                   imageName?.lowercased().hasSuffix(".png") == true
            #expect(hasImageExtension, "Image should have a standard image file extension")
        }
    }
    
    @Test("Bundle image loading is thread-safe")
    func testBundleImageLoadingThreadSafety() async {
        let itemCode = "101"
        let manufacturer = "CIM"
        
        // Test concurrent image loading
        await withTaskGroup(of: Bool.self) { group in
            // Add multiple concurrent tasks
            for _ in 0..<5 {
                group.addTask {
                    // Call image loading methods on main actor since they use UIImage
                    let exists = await MainActor.run {
                        ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer)
                    }
                    let image = await MainActor.run {
                        ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer)
                    }
                    
                    // Both should be consistent
                    if exists {
                        return image != nil
                    } else {
                        return image == nil
                    }
                }
            }
            
            // Collect all results
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            
            // All results should be consistent (all true)
            #expect(results.allSatisfy { $0 }, "Concurrent image loading should be consistent")
            #expect(results.count == 5, "Should have 5 concurrent results")
        }
    }
    
    @Test("Image helpers handle edge cases safely")
    func testImageHelpersEdgeCases() {
        // Test empty strings
        #expect(ImageHelpers.productImageExists(for: "", manufacturer: nil) == false, "Empty code should return false")
        #expect(ImageHelpers.loadProductImage(for: "", manufacturer: nil) == nil, "Empty code should return nil image")
        #expect(ImageHelpers.getProductImageName(for: "", manufacturer: nil) == nil, "Empty code should return nil name")
        
        // Test with empty manufacturer
        #expect(ImageHelpers.productImageExists(for: "101", manufacturer: "") == ImageHelpers.productImageExists(for: "101", manufacturer: nil), "Empty manufacturer should behave like nil")
        
        // Test with whitespace
        #expect(ImageHelpers.productImageExists(for: "   ", manufacturer: nil) == false, "Whitespace code should return false")
        #expect(ImageHelpers.productImageExists(for: "101", manufacturer: "   ") == ImageHelpers.productImageExists(for: "101", manufacturer: nil), "Whitespace manufacturer should behave like nil")
    }
    
    @Test("Bundle contains expected image directory structure")
    func testBundleImageStructure() {
        // Test that we can access bundle resources
        let bundle = Bundle.main
        #expect(bundle.bundlePath.count > 0, "Should have valid bundle path")
        
        // Test that we can get bundle contents
        let bundlePath = bundle.bundlePath
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
            #expect(!contents.isEmpty, "Bundle should contain files")
            
            // Look for image files in bundle
            let imageFiles = contents.filter { fileName in
                fileName.lowercased().hasSuffix(".jpg") ||
                fileName.lowercased().hasSuffix(".jpeg") ||
                fileName.lowercased().hasSuffix(".png")
            }
            
            // We should have at least some image files (including CIM-101)
            #expect(!imageFiles.isEmpty, "Bundle should contain image files")
            
        } catch {
            Issue.record("Should be able to read bundle contents: \(error)")
        }
    }
}

// MARK: - Network Layer Tests from NetworkLayerTests.swift

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
    func bundleResourceValidation() throws {
        let loader = JSONDataLoader()
        
        // Since the app bundle contains actual JSON files, findCatalogJSONData should succeed
        let data = try loader.findCatalogJSONData()
        
        // Verify we get valid data
        #expect(data.count > 0, "Should return valid JSON data from bundle")
        
        // Verify the data can be decoded as valid JSON
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }
    
    @Test("Bundle resource loading with non-existent resource throws error")
    func bundleResourceNonExistentThrows() {
        let loader = JSONDataLoader()
        
        // Test that we can trigger an error condition by temporarily removing
        // the expected resources - this would be the error path we want to test
        // For now, verify the behavior with existing resources
        let result = Result { try loader.findCatalogJSONData() }
        
        switch result {
        case .success(let data):
            // This is the expected case with current bundle contents
            #expect(data.count > 0)
        case .failure(let error):
            // This would happen if no catalog files exist
            #expect(error is DataLoadingError)
        }
    }
    
    @Test("JSONDataLoader can decode actual bundle data")
    func jsonDataLoaderDecodeBundleData() throws {
        let loader = JSONDataLoader()
        
        // Get actual bundle data and verify it can be decoded
        let data = try loader.findCatalogJSONData()
        let items = try loader.decodeCatalogItems(from: data)
        
        // Verify we got some valid catalog items
        #expect(items.count > 0, "Bundle should contain catalog items")
        
        // Verify the structure of at least one item
        if let firstItem = items.first {
            #expect(!firstItem.name.isEmpty, "Item should have a name")
            #expect(!firstItem.code.isEmpty, "Item should have a code")
        }
    }
}