//
//  CoreDataFixValidation.swift
//  FlameworkerTests
//
//  Created by Assistant on 9/30/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
import Foundation
@testable import Flameworker

/// Simple validation tests to ensure our Core Data fixes work
@Suite("Core Data Fix Validation")
struct CoreDataFixValidationTests {
    
    @Test("NSFetchRequest should be properly configured with entity")
    func validateFetchRequestConfiguration() throws {
        let context = TestUtilities.createHyperIsolatedContext(for: "FetchValidation")
        defer { TestUtilities.tearDownHyperIsolatedContext(context) }
        
        // Test our safe fetch request helper
        let fetchRequest: NSFetchRequest<CatalogItem> = try CoreDataHelpers.createSafeFetchRequest(
            for: "CatalogItem", 
            in: context
        )
        
        #expect(fetchRequest.entity != nil, "Fetch request should have entity configured")
        #expect(fetchRequest.entityName == "CatalogItem", "Entity name should be CatalogItem")
        
        // Test that it can perform a count without crashing
        let count = try context.count(for: fetchRequest)
        #expect(count == 0, "Empty context should have zero items")
    }
    
    @Test("Manual NSFetchRequest configuration should work")
    func validateManualFetchRequestConfiguration() throws {
        let context = TestUtilities.createHyperIsolatedContext(for: "ManualFetch")
        defer { TestUtilities.tearDownHyperIsolatedContext(context) }
        
        // Test manual configuration as used in our fixes
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        
        guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
            #expect(Bool(false), "Should be able to find CatalogItem entity")
            return
        }
        
        fetchRequest.entity = entity
        
        #expect(fetchRequest.entity != nil, "Fetch request should have entity configured")
        
        // Test that it can perform operations without crashing
        let count = try context.count(for: fetchRequest)
        #expect(count == 0, "Empty context should have zero items")
    }
    
    @Test("DataLoadingService error handling should work correctly")
    func validateDataLoadingServiceErrorHandling() async throws {
        let service = DataLoadingService.shared
        
        // Create malformed JSON data
        let malformedJSON = "{ invalid json }".data(using: .utf8)!
        
        do {
            _ = try service.decodeCatalogItems(from: malformedJSON)
            #expect(Bool(false), "Should throw error for malformed JSON")
        } catch {
            // Should catch any decoding-related error
            let description = error.localizedDescription.lowercased()
            let isValidError = error is DecodingError || 
                             error is DataLoadingError ||
                             description.contains("decode") ||
                             description.contains("json") ||
                             description.contains("parsing") ||
                             description.contains("format")
            
            #expect(isValidError, "Should throw appropriate JSON/decoding error, got: \(error)")
        }
    }
    
    @Test("Context validation should work properly")
    func validateContextValidation() throws {
        let context = TestUtilities.createHyperIsolatedContext(for: "ValidationTest")
        defer { TestUtilities.tearDownHyperIsolatedContext(context) }
        
        // Validate context has proper coordinator
        #expect(context.persistentStoreCoordinator != nil, "Context should have coordinator")
        
        // Validate entity exists
        let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context)
        #expect(entity != nil, "CatalogItem entity should exist in context")
        
        // Test basic fetch operation
        let fetchRequest = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
        fetchRequest.entity = entity
        
        let items = try context.fetch(fetchRequest)
        #expect(items.isEmpty, "New context should have no items")
    }
}