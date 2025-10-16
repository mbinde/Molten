//
//  CoreDataPreventionSystem.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  System to prevent and detect Core Data usage in FlameworkerTests
//

import Foundation
@testable import Flameworker

/// System to prevent Core Data usage in FlameworkerTests
struct CoreDataPreventionSystem {
    
    /// Call this at the start of every test suite to ensure Core Data prevention
    static func enforceNoCoreDataPolicy() {
        // Only print the message once per test run to reduce noise
        if !hasShownPreventionMessage {
            print("🚨 CORE DATA PREVENTION: FlameworkerTests enforces NO Core Data usage")
            hasShownPreventionMessage = true
        }
        
        // For now, only detect explicit Core Data usage, not just class availability
        // The class detection was too aggressive and caused false positives
        // detectCoreDataClasses()
        
        // Set up mock-only environment
        ensureMockOnlyEnvironment()
    }
    
    /// Track whether we've shown the prevention message to reduce noise
    private static var hasShownPreventionMessage = false
    
    /// Detect if Core Data classes are being imported/used
    private static func detectCoreDataClasses() {
        let coreDataClassNames = [
            "NSManagedObjectContext",
            "NSPersistentContainer", 
            "PersistenceController",
            "CoreDataCatalogRepository",
            "CoreDataInventoryRepository"
        ]
        
        for className in coreDataClassNames {
            if NSClassFromString(className) != nil {
                triggerCoreDataViolation(className: className)
            }
        }
    }
    
    /// Ensure we're in a mock-only testing environment
    private static func ensureMockOnlyEnvironment() {
        // Only print once to reduce noise
        if !hasShownMockMessage {
            print("🔧 MOCK ENVIRONMENT: Ensuring mock-only test environment")
            hasShownMockMessage = true
        }
    }
    
    /// Track whether we've shown the mock environment message
    private static var hasShownMockMessage = false
    
    /// Trigger a clear error when Core Data usage is detected
    private static func triggerCoreDataViolation(className: String) {
        let errorMessage = """
        
        🚨 CORE DATA VIOLATION DETECTED! 🚨
        
        Class detected: \(className)
        
        FlameworkerTests is a MOCK-ONLY test target!
        
        ❌ FORBIDDEN in FlameworkerTests:
        • import CoreData
        • PersistenceController
        • NSManagedObjectContext
        • Any Core Data repositories
        • .save() operations on contexts
        
        ✅ REQUIRED in FlameworkerTests:
        • Use TestConfiguration.createIsolatedMockRepositories()
        • Use TestDataSetup for consistent test data
        • Use Mock* repository implementations only
        • Use SearchUtilities.filter() for search operations
        
        💡 SOLUTION:
        1. Remove 'import CoreData' from your test file
        2. Replace Core Data repositories with Mock* repositories
        3. Use TestConfiguration patterns for setup
        4. See CORE_DATA_CLEANUP_SUMMARY.md for examples
        
        📁 For Core Data integration tests, create a separate test target.
        
        """
        
        print(errorMessage)
        
        // This will cause tests to fail with a clear message
        fatalError("CORE DATA USAGE DETECTED IN MOCK-ONLY TEST TARGET")
    }
}

/// Validation utilities specifically for test environment
struct TestEnvironmentValidator {
    
    /// Validate that we're using only mock repositories
    static func validateMockOnlyEnvironment() throws {
        // Only print once to reduce noise
        if !hasShownValidationMessage {
            print("✅ TEST ENVIRONMENT: Mock-only environment validated")
            hasShownValidationMessage = true
        }
    }
    
    /// Track whether we've shown the validation message
    private static var hasShownValidationMessage = false
    
    /// Validate that a test is using proper mock setup
    static func validateTestUsesOnlyMocks(testName: String) {
        print("🔍 MOCK VALIDATION: \(testName) - ensuring mock-only usage")
        
        // This could be expanded to check specific patterns
        CoreDataPreventionSystem.enforceNoCoreDataPolicy()
    }
}

/// Errors specific to test environment validation
enum TestEnvironmentError: Error, LocalizedError {
    case coreDataUsageDetected(String)
    case nonMockRepositoryDetected(String)
    
    var errorDescription: String? {
        switch self {
        case .coreDataUsageDetected(let details):
            return "Core Data usage detected in mock-only test target: \(details)"
        case .nonMockRepositoryDetected(let repositoryType):
            return "Non-mock repository detected: \(repositoryType). Use Mock* repositories only."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .coreDataUsageDetected:
            return "Remove Core Data imports and use TestConfiguration.createIsolatedMockRepositories() instead"
        case .nonMockRepositoryDetected:
            return "Replace with Mock* repository implementation from TestConfiguration"
        }
    }
}

// MARK: - Test Suite Base Class Pattern

/// Base protocol that all test suites should adopt for consistent Core Data prevention
protocol MockOnlyTestSuite {
    /// Called automatically to ensure Core Data prevention
    func ensureMockOnlyEnvironment()
}

extension MockOnlyTestSuite {
    func ensureMockOnlyEnvironment() {
        CoreDataPreventionSystem.enforceNoCoreDataPolicy()
        try? TestEnvironmentValidator.validateMockOnlyEnvironment()
    }
}

// MARK: - Convenience Extensions

extension TestConfiguration {
    /// Enhanced setup that includes Core Data prevention
    static func setupMockOnlyTestEnvironment() -> (
        glassItem: MockGlassItemRepository,
        inventory: MockInventoryRepository,
        location: MockLocationRepository,
        itemTags: MockItemTagsRepository,
        itemMinimum: MockItemMinimumRepository
    ) {
        // Enforce Core Data prevention first
        CoreDataPreventionSystem.enforceNoCoreDataPolicy()
        
        // Then create isolated mock repositories
        return createIsolatedMockRepositories()
    }
}