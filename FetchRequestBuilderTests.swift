//
//  FetchRequestBuilderTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import CoreData

@testable import Flameworker

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(Testing)

@Suite("FetchRequestBuilder Tests")
struct FetchRequestBuilderTests {
    
    // Simple test context creation for basic tests
    private func createCleanTestContext() -> NSManagedObjectContext {
        let testController = PersistenceController.createTestController()
        return testController.container.viewContext
    }
    
    // Helper to create test data
    private func createTestCatalogItems(in context: NSManagedObjectContext) throws {
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create diverse test data
        let item1 = service.create(in: context)
        item1.name = "Red Glass Rod"
        item1.code = "RGR-001"
        item1.manufacturer = "Bullseye Glass"
        
        let item2 = service.create(in: context)
        item2.name = "Blue Glass Sheet"
        item2.code = "BGS-002"
        item2.manufacturer = "Spectrum Glass"
        
        let item3 = service.create(in: context)
        item3.name = "Green Glass Frit"
        item3.code = "GGF-003"
        item3.manufacturer = "Bullseye Glass"
        
        let item4 = service.create(in: context)
        item4.name = "Clear Glass Rod"
        item4.code = "CGR-004"
        item4.manufacturer = "Spectrum Glass"
        
        try CoreDataHelpers.safeSave(context: context, description: "Test catalog items")
    }
    
    @Test("Should build compound AND predicate")
    func testCompoundAndPredicate() throws {
        // Arrange
        let context = createCleanTestContext()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        // Act - Find items that are glass AND from Bullseye
        let results = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Glass"))
            .and(NSPredicate(format: "manufacturer == %@", "Bullseye Glass"))
            .execute(in: context)
        
        // Assert
        #expect(results.count == 2, "Should find 2 Bullseye glass items")
        let names = results.compactMap { $0.name }
        #expect(names.contains("Red Glass Rod"), "Should contain Red Glass Rod")
        #expect(names.contains("Green Glass Frit"), "Should contain Green Glass Frit")
    }
    
    @Test("Should build compound OR predicate")
    func testCompoundOrPredicate() throws {
        // Arrange
        let context = createCleanTestContext()
        try createTestCatalogItems(in: context)
        
        let builder = FetchRequestBuilder<CatalogItem>(entityName: "CatalogItem")
        
        // Act - Find items that are either Red OR Blue
        let results = try builder
            .where(NSPredicate(format: "name CONTAINS[cd] %@", "Red"))
            .or(NSPredicate(format: "name CONTAINS[cd] %@", "Blue"))
            .execute(in: context)
        
        // Assert
        #expect(results.count == 2, "Should find 2 items (Red or Blue)")
        let names = results.compactMap { $0.name }
        #expect(names.contains("Red Glass Rod"), "Should contain Red Glass Rod")
        #expect(names.contains("Blue Glass Sheet"), "Should contain Blue Glass Sheet")
    }
}

#endif