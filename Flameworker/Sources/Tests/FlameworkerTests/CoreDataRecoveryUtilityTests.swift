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
    
    // MARK: - Test Helpers
    
    /// Create an isolated test persistence controller
    private func createTestPersistenceController() -> PersistenceController {
        return PersistenceController(inMemory: true)
    }
    
    @Test("Should verify store health for clean store")
    func testVerifyStoreHealthClean() throws {
        // Arrange - Create clean test store
        let testController = createTestPersistenceController()
        
        // Act - Verify store health
        let isHealthy = CoreDataRecoveryUtility.verifyStoreHealth(testController)
        
        // Assert - Clean store should be healthy
        #expect(isHealthy, "Clean test store should be healthy")
        #expect(testController.isReady, "Test controller should be ready")
        #expect(!testController.hasStoreLoadingError, "Test controller should not have loading errors")
    }
    
    @Test("Should generate entity count report for empty store")
    func testGenerateEntityCountReportEmpty() throws {
        // Arrange - Create empty test store
        let testController = createTestPersistenceController()
        let context = testController.container.viewContext
        
        // Act - Generate entity count report
        let report = CoreDataRecoveryUtility.generateEntityCountReport(in: context)
        
        // Assert - Report should be generated and contain entity information
        #expect(report.contains("Entity Count Report"), "Report should have proper header")
        #expect(report.contains("CatalogItem"), "Report should include CatalogItem entity")
        #expect(report.contains(": 0"), "Empty store should show 0 counts")
    }
    
    @Test("Should generate entity count report with actual data")
    func testGenerateEntityCountReportWithData() throws {
        // Arrange - Create test store with data
        let testController = createTestPersistenceController()
        let context = testController.container.viewContext
        
        // Add test data
        if let catalogItem = PersistenceController.createCatalogItem(in: context) {
            catalogItem.name = "Test Item"
            catalogItem.code = "TEST-001"
            catalogItem.manufacturer = "TestCorp"
            
            try context.save()
        }
        
        // Act - Generate entity count report
        let report = CoreDataRecoveryUtility.generateEntityCountReport(in: context)
        
        // Assert - Report should show the added data
        #expect(report.contains("Entity Count Report"), "Report should have proper header")
        #expect(report.contains("CatalogItem"), "Report should include CatalogItem entity")
        #expect(report.contains(": 1"), "Store with one item should show count of 1")
    }
    
    @Test("Should validate data integrity for clean store")
    func testValidateDataIntegrityClean() throws {
        // Arrange - Create clean test store  
        let testController = createTestPersistenceController()
        let context = testController.container.viewContext
        
        // Act - Validate data integrity
        let issues = CoreDataRecoveryUtility.validateDataIntegrity(in: context)
        
        // Assert - Clean store should have no integrity issues
        #expect(issues.isEmpty, "Clean store should have no data integrity issues")
    }
    
    @Test("Should detect data integrity issues with invalid data")
    func testValidateDataIntegrityIssues() throws {
        // Arrange - Create test store with invalid data
        let testController = createTestPersistenceController()
        let context = testController.container.viewContext
        
        // Add invalid test data (missing required fields)
        if let invalidItem = PersistenceController.createCatalogItem(in: context) {
            // Leave name, code, and manufacturer empty to trigger validation issues
            invalidItem.name = ""
            invalidItem.code = ""
            invalidItem.manufacturer = ""
            
            try context.save()
        }
        
        // Act - Validate data integrity
        let issues = CoreDataRecoveryUtility.validateDataIntegrity(in: context)
        
        // Assert - Should detect integrity issues
        #expect(!issues.isEmpty, "Should detect data integrity issues")
        #expect(issues.count >= 3, "Should detect missing name, code, and manufacturer")
        
        let issueText = issues.joined(separator: " ")
        #expect(issueText.contains("name"), "Should detect missing name issue")
        #expect(issueText.contains("code"), "Should detect missing code issue")
        #expect(issueText.contains("manufacturer"), "Should detect missing manufacturer issue")
    }
    
    @Test("Should measure performance for empty store")
    func testMeasureQueryPerformanceEmpty() throws {
        // Arrange - Create empty test store
        let testController = createTestPersistenceController()
        let context = testController.container.viewContext
        
        // Act - Measure query performance on empty store
        let performanceReport = CoreDataRecoveryUtility.measureQueryPerformance(in: context)
        
        // Assert - Performance report should handle empty store gracefully
        #expect(performanceReport.contains("Query Performance Report"), "Should have performance report header")
        #expect(performanceReport.contains("CatalogItem Performance"), "Should include CatalogItem performance")
        #expect(performanceReport.contains("Count (0 entities)"), "Should show zero entity count")
        #expect(performanceReport.contains("ms"), "Should include timing measurements even for empty store")
    }
    
    @Test("Should diagnose model structure without errors")
    func testDiagnoseModel() throws {
        // Arrange - Create test controller
        let testController = createTestPersistenceController()
        
        // Act & Assert - Should not throw when diagnosing model
        // This test verifies the method executes without crashing
        // The actual logging output is verified manually during development
        CoreDataRecoveryUtility.diagnoseModel(testController)
        
        // If we reach this point without throwing, the test passes
        #expect(true, "Model diagnosis should complete without errors")
    }
    
    @Test("Should print recovery instructions without errors")
    func testPrintRecoveryInstructions() throws {
        // Act & Assert - Should not throw when printing instructions
        // This test verifies the method executes without crashing
        // The actual instruction content is verified manually during development
        CoreDataRecoveryUtility.printRecoveryInstructions()
        
        // If we reach this point without throwing, the test passes
        #expect(true, "Recovery instructions should print without errors")
    }
    
    @Test("Should handle reset operations safely")
    func testResetPersistentStoreSafety() async throws {
        // Arrange - Create test controller
        let testController = createTestPersistenceController()
        
        // Verify store is initially healthy
        let initialHealth = CoreDataRecoveryUtility.verifyStoreHealth(testController)
        #expect(initialHealth, "Test store should start healthy")
        
        // Act - Perform reset operation
        let resetSuccess = await CoreDataRecoveryUtility.resetPersistentStore(testController)
        
        // Assert - Reset should complete successfully
        #expect(resetSuccess, "Store reset should complete successfully")
        
        // Verify store is still accessible after reset
        let postResetHealth = CoreDataRecoveryUtility.verifyStoreHealth(testController)
        #expect(postResetHealth, "Store should be healthy after reset")
    }
}

#endif
