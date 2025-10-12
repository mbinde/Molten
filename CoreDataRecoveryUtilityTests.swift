//
//  CoreDataRecoveryUtilityTests.swift
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

@Suite("CoreDataRecoveryUtility Tests", .serialized)
struct CoreDataRecoveryUtilityTests {
    
    // Use completely isolated test context for reliability
    private func createCompletelyIsolatedTestContext() throws -> (controller: PersistenceController, context: NSManagedObjectContext) {
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        // Verify context is completely clean
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        let existingCount = try context.count(for: fetchRequest)
        
        if existingCount != 0 {
            print("⚠️ CoreDataRecoveryUtility test context not clean, found \(existingCount) existing items - cleaning up")
            let existingItems = try context.fetch(fetchRequest)
            for item in existingItems {
                context.delete(item)
            }
            try context.save()
        }
        
        return (testController, context)
    }
    
    @Test("Should validate data integrity for clean store")
    func testValidateDataIntegrityClean() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create a valid test entity with all required fields
        let entity = service.create(in: context)
        entity.name = "Valid Item"
        entity.code = "VALID-001"
        entity.manufacturer = "Valid Manufacturer"
        
        try CoreDataHelpers.safeSave(context: context, description: "Valid test entity")
        
        // Act
        let issues = CoreDataRecoveryUtility.validateDataIntegrity(in: context)
        
        // Assert
        #expect(issues.isEmpty, "Should have no data integrity issues with valid data")
        
        // Keep reference to test controller
        _ = testController
    }
    
    @Test("Should generate entity count report for empty store")
    func testGenerateEntityCountReportEmpty() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        
        // Act
        let report = CoreDataRecoveryUtility.generateEntityCountReport(in: context)
        
        // Assert
        #expect(report != nil, "Should generate a report")
        #expect(report.contains("Entity Count Report"), "Should contain report title")
        #expect(report.contains("CatalogItem: 0"), "Should show CatalogItem with count 0")
        
        // Keep reference to test controller
        _ = testController
    }
    
    @Test("Should generate entity count report with actual data")
    func testGenerateEntityCountReportWithData() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create a test entity
        let entity = service.create(in: context)
        entity.name = "Test Item"
        entity.code = "TEST-001"
        entity.manufacturer = "Test Manufacturer"
        
        try CoreDataHelpers.safeSave(context: context, description: "Test entity for count report")
        
        // Act
        let report = CoreDataRecoveryUtility.generateEntityCountReport(in: context)
        
        // Assert
        #expect(report != nil, "Should generate a report")
        #expect(report.contains("Entity Count Report"), "Should contain report title")
        #expect(report.contains("CatalogItem: 1"), "Should show CatalogItem with count 1")
        
        // Keep reference to test controller
        _ = testController
    }
}

#endif