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

@Suite("CoreDataRecoveryUtility Tests - DISABLED during repository pattern migration", .serialized)
struct CoreDataRecoveryUtilityTests {
    
    // Use completely isolated test context for reliability  
    private func createCompletelyIsolatedTestContext() throws -> (controller: PersistenceController, context: NSManagedObjectContext) {
        print("🔧 Creating truly isolated recovery test context...")
        
        // Create completely new test controller for each test to ensure isolation
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        
        print("  📋 New controller: \(ObjectIdentifier(testController))")
        print("  📋 New context: \(ObjectIdentifier(context))")
        
        // Verify this is truly a clean context by checking all entities
        let entities = testController.container.managedObjectModel.entities
        var foundExistingData = false
        
        for entityDescription in entities {
            guard let entityName = entityDescription.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let existingItems = try context.fetch(fetchRequest)
                if !existingItems.isEmpty {
                    print("  ⚠️ Found \(existingItems.count) existing \(entityName) entities in supposedly clean context!")
                    foundExistingData = true
                    
                    // Delete them
                    for item in existingItems {
                        context.delete(item)
                    }
                }
            } catch {
                print("  ⚠️ Could not check \(entityName): \(error)")
            }
        }
        
        if foundExistingData {
            print("  💾 Cleaning up unexpected data...")
            try context.save()
            print("  ✅ Cleanup completed")
        } else {
            print("  ✅ Context is truly clean")
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
    
    @Test("Should detect data integrity issues")
    func testValidateDataIntegrityIssues() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create entity with missing required field (no name)
        let invalidEntity = service.create(in: context)
        invalidEntity.code = "INVALID-001"
        invalidEntity.manufacturer = "Test Manufacturer"
        // Intentionally leaving name as nil to create data integrity issue
        
        try CoreDataHelpers.safeSave(context: context, description: "Invalid test entity")
        
        // Act
        let issues = CoreDataRecoveryUtility.validateDataIntegrity(in: context)
        
        // Assert
        #expect(!issues.isEmpty, "Should detect data integrity issues")
        #expect(issues.contains { $0.contains("name") && $0.contains("missing") }, "Should detect missing name field")
        
        // Keep reference to test controller
        _ = testController
    }
    
    @Test("Should measure query performance for basic operations")
    func testMeasureQueryPerformanceBasic() throws {
        // Arrange - Use completely isolated context
        let (testController, context) = try createCompletelyIsolatedTestContext()
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create some test data for performance measurement
        for i in 1...5 {
            let entity = service.create(in: context)
            entity.name = "Performance Test Item \(i)"
            entity.code = "PERF-\(String(format: "%03d", i))"
            entity.manufacturer = "Performance Manufacturer"
        }
        
        try CoreDataHelpers.safeSave(context: context, description: "Performance test entities")
        
        // Act
        let performanceReport = CoreDataRecoveryUtility.measureQueryPerformance(in: context)
        
        // Assert
        #expect(performanceReport != nil, "Should generate a performance report")
        #expect(performanceReport.contains("Query Performance Report"), "Should contain report title")
        #expect(performanceReport.contains("CatalogItem"), "Should contain CatalogItem performance data")
        #expect(performanceReport.contains("ms"), "Should show timing in milliseconds")
        
        // Keep reference to test controller
        _ = testController
    }
    
    @Test("Should measure performance for empty store")
    func testMeasureQueryPerformanceEmpty() throws {
        // Arrange - Use completely isolated context (Empty store)
        let (testController, context) = try createCompletelyIsolatedTestContext()
        
        // Act
        let performanceReport = CoreDataRecoveryUtility.measureQueryPerformance(in: context)
        
        // Assert
        #expect(performanceReport != nil, "Should generate a performance report even for empty store")
        #expect(performanceReport.contains("Query Performance Report"), "Should contain report title")
        #expect(performanceReport.contains("CatalogItem"), "Should still measure CatalogItem queries")
        #expect(performanceReport.contains("0 entities"), "Should indicate empty store")
        
        // Keep reference to test controller
        _ = testController
    }
}

#endif
