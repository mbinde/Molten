//
//  TestConfiguration.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Configuration utilities for mock-only testing
//

import Foundation
import CryptoKit
@testable import Molten

/// Test configuration for FlameworkerTests - Mock Only Testing
struct TestConfiguration {
    
    /// Verify we're running in mock-only mode
    nonisolated static func ensureMockOnlyMode() {
        // Enforce Core Data prevention (in a detached task)
        Task { @MainActor in
            CoreDataPreventionSystem.enforceNoCoreDataPolicy()
        }

        print("🔧 TEST CONFIG: FlameworkerTests running in mock-only mode")
        print("🔧 All repositories should be Mock* implementations")
        print("🔧 No Core Data operations should occur")
    }

    /// Create completely isolated mock repositories
    nonisolated static func createIsolatedMockRepositories() -> (
        glassItem: MockGlassItemRepository,
        inventory: MockInventoryRepository,
        location: MockStorageLocationRepository,
        itemTags: MockItemTagsRepository,
        itemMinimum: MockItemMinimumRepository
    ) {
        ensureMockOnlyMode()

        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockStorageLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let userTagsRepo = MockUserTagsRepository()
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

    /// Alias for createIsolatedMockRepositories for backward compatibility
    nonisolated static func setupMockOnlyTestEnvironment() -> (
        glassItem: MockGlassItemRepository,
        inventory: MockInventoryRepository,
        location: MockStorageLocationRepository,
        itemTags: MockItemTagsRepository,
        itemMinimum: MockItemMinimumRepository
    ) {
        return createIsolatedMockRepositories()
    }
    
    /// Verify no Core Data leakage in mock repositories
    @MainActor
    static func verifyNoCoreDdataLeakage(glassItemRepo: MockGlassItemRepository) async throws {
        // Store the initial count
        let initialCount = await glassItemRepo.getItemCount()

        // Add a unique marker that should only exist in our mock
        let marker = GlassItemModel(
            stable_id: "AUTO_ID",
            name: "Test Isolation Marker",
            sku: "isolation-marker",
            manufacturer: "test",
            mfr_notes: "Should only exist in mock",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        let createdMarker = try await glassItemRepo.createItem(marker)
        let markerStableId = createdMarker.stable_id

        // Verify it exists in our mock
        let items = try await glassItemRepo.fetchItems(matching: nil)
        let hasMarker = items.contains { $0.stable_id == markerStableId }

        if !hasMarker {
            throw TestError.coreDataLeakage("Marker item not found in mock repository - possible Core Data leakage")
        }

        // Verify the count increased by 1
        let finalCount = await glassItemRepo.getItemCount()
        if finalCount != initialCount + 1 {
            throw TestError.coreDataLeakage("Item count mismatch - expected \(initialCount + 1), got \(finalCount)")
        }

        print("✅ TEST CONFIG: No Core Data leakage detected")
    }
}

/// Errors specific to test configuration
enum TestError: Error {
    case coreDataLeakage(String)
    case mockConfigurationFailure(String)
    case presetNotFound

    var localizedDescription: String {
        switch self {
        case .coreDataLeakage(let message):
            return "Core Data leakage detected: \(message)"
        case .mockConfigurationFailure(let message):
            return "Mock configuration failed: \(message)"
        case .presetNotFound:
            return "Preset not found in test"
        }
    }
}
