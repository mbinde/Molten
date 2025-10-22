//
//  NewTestTemplate.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Template for creating new mock-only tests in FlameworkerTests
//

import Foundation
// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

// TEMPLATE: Copy this structure for all new tests in FlameworkerTests

@Suite("Your Test Suite Name Here", .serialized)
@MainActor
struct YourNewTestSuite: MockOnlyTestSuite {

    // REQUIRED: Call this in every test or in a setup method
    init() {
        ensureMockOnlyEnvironment() // This prevents Core Data usage!
    }

    @Test("Your test description here")
    func testYourFunctionality() async throws {
        // STEP 1: Always start with TestConfiguration for mock repositories
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        // STEP 2: Use TestDataSetup for consistent test data (optional)
        let testItems = TestDataSetup.createStandardTestGlassItems().prefix(3)
        
        for item in testItems {
            _ = try await repos.glassItem.createItem(item)
        }
        
        // STEP 3: Test your functionality using ONLY mock repositories
        let allItems = try await repos.glassItem.fetchItems(matching: nil)
        
        // STEP 4: Use SearchUtilities for search operations (not repository search methods)
        let searchResults = SearchUtilities.filter(allItems, with: "search term")
        
        // STEP 5: Make your assertions
        #expect(allItems.count == 3, "Should have created test items")
        #expect(searchResults.count >= 0, "Should handle search operations")
        
        // OPTIONAL: Verify no Core Data leakage
        try await TestConfiguration.verifyNoCoreDdataLeakage(glassItemRepo: repos.glassItem)
    }
    
    @Test("Another test example")
    func testAnotherFeature() async throws {
        // ALWAYS start with mock setup
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        // Your test logic here using ONLY mocks
        // ❌ DO NOT USE:
        // - import CoreData
        // - PersistenceController
        // - NSManagedObjectContext  
        // - CoreDataCatalogRepository
        // - .save() operations
        
        // ✅ DO USE:
        // - Mock* repositories from repos
        // - TestDataSetup utilities
        // - SearchUtilities for search
        // - ValidationUtilities for validation
        
        #expect(true, "Your assertions here")
    }
}

/*
🚨 CRITICAL RULES FOR FlameworkerTests:

❌ FORBIDDEN:
• import CoreData
• PersistenceController usage
• NSManagedObjectContext creation
• Any Core Data repository implementations
• Direct .save() operations on contexts

✅ REQUIRED:
• Start every test with TestConfiguration.setupMockOnlyTestEnvironment()
• Use TestDataSetup for consistent test data
• Use SearchUtilities.filter() for search operations
• Use ValidationUtilities for input validation
• Implement MockOnlyTestSuite protocol
• Call ensureMockOnlyEnvironment() in init or test setup

📁 FILE NAMING:
• End test files with "Tests.swift" 
• Use descriptive names like "ServiceNameTests.swift"

🔍 VERIFICATION:
The CoreDataPreventionSystem will automatically detect and prevent Core Data usage.
If you see a Core Data violation error, follow the solution steps in the error message.

📖 EXAMPLES:
See existing files like:
• SearchUtilitiesConfigurationTests.swift
• ViewUtilitiesTests.swift  
• InventorySearchSuggestionsTests.swift

For Core Data integration testing, create a separate test target.
*/
