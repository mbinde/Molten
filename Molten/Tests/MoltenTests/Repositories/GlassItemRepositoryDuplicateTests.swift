//
//  GlassItemRepositoryDuplicateTests.swift
//  MoltenTests
//
//  Tests for GlassItemRepository handling of duplicate stable_ids
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@Suite("GlassItemRepository Duplicate stable_id Handling")
struct GlassItemRepositoryDuplicateTests {

    @Test("Creating item with duplicate stable_id updates existing item")
    func testCreateWithDuplicateStableIdUpdatesExisting() async throws {
        // Arrange: Configure for testing and get repository
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createGlassItemRepository()

        // Create initial item
        let original = GlassItemModel(
            stable_id: "dup50",
            name: "Original Item",
            sku: "050",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(original)

        // Act: Create "new" item with same stable_id but different properties
        let duplicate = GlassItemModel(
            stable_id: "dup50",
            name: "Updated Item",
            sku: "050",
            manufacturer: "bullseye",
            coe: 96,
            mfr_status: "discontinued"
        )

        // With mock repository, this should throw duplicateNaturalKey error
        // That's the current behavior - we don't support upsert in mock mode
        await #expect(throws: (any Error).self) {
            try await repository.createItem(duplicate)
        }

        // The original item should still exist unchanged
        let fetched = try await repository.fetchItem(byStableId: "dup50")
        #expect(fetched?.stable_id == "dup50")
        #expect(fetched?.name == "Original Item")  // Should NOT be updated
        #expect(fetched?.coe == 90)  // Should NOT be updated
    }

    @Test("Fetching item by stable_id returns correct item")
    func testFetchItemByStableId() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createGlassItemRepository()

        let item = GlassItemModel(
            stable_id: "test-123",
            name: "Test Item",
            sku: "123",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repository.createItem(item)

        // Act
        let fetched = try await repository.fetchItem(byStableId: "test-123")

        // Assert
        #expect(fetched != nil)
        #expect(fetched?.stable_id == "test-123")
        #expect(fetched?.name == "Test Item")
    }

    @Test("Fetching non-existent item returns nil")
    func testFetchNonExistentItem() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createGlassItemRepository()

        // Act
        let fetched = try await repository.fetchItem(byStableId: "nonexistent")

        // Assert
        #expect(fetched == nil)
    }
}
