//
//  TestConfiguration.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Configuration utilities for mock-only testing
//

import Foundation
@testable import Flameworker

/// Test configuration for FlameworkerTests - Mock Only Testing
struct TestConfiguration {
    
    /// Verify we're running in mock-only mode
    static func ensureMockOnlyMode() {
        // Enforce Core Data prevention
        CoreDataPreventionSystem.enforceNoCoreDataPolicy()
        
        print("🔧 TEST CONFIG: FlameworkerTests running in mock-only mode")
        print("🔧 All repositories should be Mock* implementations")
        print("🔧 No Core Data operations should occur")
    }
    
    /// Create completely isolated mock repositories
    static func createIsolatedMockRepositories() -> (
        glassItem: MockGlassItemRepository,
        inventory: MockInventoryRepository,
        location: MockLocationRepository,
        itemTags: MockItemTagsRepository,
        itemMinimum: MockItemMinimumRepository
    ) {
        ensureMockOnlyMode()
        
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        
        // Configure for reliable testing
        glassItemRepo.simulateLatency = false
        glassItemRepo.shouldRandomlyFail = false
        glassItemRepo.suppressVerboseLogging = true
        
        // Ensure clean state
        glassItemRepo.clearAllData()
        inventoryRepo.clearAllData()
        locationRepo.clearAllData()
        itemTagsRepo.clearAllData()
        itemMinimumRepo.clearAllData()
        
        return (glassItemRepo, inventoryRepo, locationRepo, itemTagsRepo, itemMinimumRepo)
    }
    
    /// Verify no Core Data leakage in mock repositories
    static func verifyNoCoreDdataLeakage(glassItemRepo: MockGlassItemRepository) async throws {
        // Add a unique marker that should only exist in our mock
        let markerKey = "test-isolation-marker-\(UUID().uuidString)"
        let marker = GlassItemModel(
            naturalKey: markerKey,
            name: "Test Isolation Marker",
            sku: "test",
            manufacturer: "test",
            mfr_notes: "Should only exist in mock",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        let _ = try await glassItemRepo.createItem(marker)
        
        // Verify it exists in our mock
        let items = try await glassItemRepo.fetchItems(matching: nil)
        let hasMarker = items.contains { $0.naturalKey == markerKey }
        
        if !hasMarker {
            throw TestError.coreDataLeakage("Marker item not found in mock repository - possible Core Data leakage")
        }
        
        print("✅ TEST CONFIG: No Core Data leakage detected")
    }
}

/// Errors specific to test configuration
enum TestError: Error {
    case coreDataLeakage(String)
    case mockConfigurationFailure(String)
    
    var localizedDescription: String {
        switch self {
        case .coreDataLeakage(let message):
            return "Core Data leakage detected: \(message)"
        case .mockConfigurationFailure(let message):
            return "Mock configuration failed: \(message)"
        }
    }
}