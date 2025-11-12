//
//  GlassItemRepositoryDuplicateTests.swift
//  MoltenTests
//
//  Tests for GlassItemRepository handling of duplicate stable_ids
//

import Testing
import Foundation
@testable import Molten

@Suite("GlassItemRepository Duplicate stable_id Handling")
@MainActor
struct GlassItemRepositoryDuplicateTests {

    // MARK: - Setup Helper

    /// Create a fresh repository instance for each test
    private func createRepository() -> MockGlassItemRepository {
        let deps = AppDependencies(forTesting: true)
        let repo = MockGlassItemRepository()
        repo.clearAllData()
        return repo
    }

    // MARK: - Duplicate stable_id Tests

    @Test("Creating item with duplicate stable_id throws error")
    func testCreateWithDuplicateStableIdThrowsError() async throws {
        let repo = createRepository()

        // Create initial item
        let original = GlassItemModel(
            stable_id: "test-dup-001",
            name: "Original Item",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repo.createItem(original)

        // Attempt to create "new" item with same stable_id but different properties
        let duplicate = GlassItemModel(
            stable_id: "test-dup-001",
            name: "Updated Item",
            sku: "001",
            manufacturer: "bullseye",
            coe: 96,
            mfr_status: "discontinued"
        )

        // Should throw duplicateNaturalKey error
        do {
            _ = try await repo.createItem(duplicate)
            Issue.record("Expected duplicateNaturalKey error")
        } catch let error as MockRepositoryError {
            if case .duplicateNaturalKey(let key) = error {
                #expect(key == "test-dup-001")
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        }

        // Verify the original item remains unchanged
        let fetched = try await repo.fetchItem(byStableId: "test-dup-001")
        #expect(fetched?.stable_id == "test-dup-001")
        #expect(fetched?.name == "Original Item")  // Should NOT be updated
        #expect(fetched?.coe == 90)  // Should NOT be updated
    }

    @Test("Fetching item by stable_id returns correct item")
    func testFetchItemByStableId() async throws {
        let repo = createRepository()

        let item = GlassItemModel(
            stable_id: "test-fetch-123",
            name: "Test Item",
            sku: "123",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repo.createItem(item)

        // Fetch the item
        let fetched = try await repo.fetchItem(byStableId: "test-fetch-123")

        // Verify all properties
        #expect(fetched != nil)
        #expect(fetched?.stable_id == "test-fetch-123")
        #expect(fetched?.name == "Test Item")
        #expect(fetched?.sku == "123")
        #expect(fetched?.manufacturer == "bullseye")
        #expect(fetched?.coe == 90)
    }

    @Test("Fetching non-existent item returns nil")
    func testFetchNonExistentItem() async throws {
        let repo = createRepository()

        // Try to fetch item that doesn't exist
        let fetched = try await repo.fetchItem(byStableId: "nonexistent-item")

        #expect(fetched == nil)
    }

    @Test("Multiple items with different stable_ids can coexist")
    func testMultipleItemsWithDifferentStableIds() async throws {
        let repo = createRepository()

        // Create multiple items
        let item1 = GlassItemModel(
            stable_id: "test-multi-001",
            name: "Item 1",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "test-multi-002",
            name: "Item 2",
            sku: "002",
            manufacturer: "bullseye",
            coe: 96,
            mfr_status: "available"
        )

        _ = try await repo.createItem(item1)
        _ = try await repo.createItem(item2)

        // Verify both items exist
        let fetched1 = try await repo.fetchItem(byStableId: "test-multi-001")
        let fetched2 = try await repo.fetchItem(byStableId: "test-multi-002")

        #expect(fetched1?.name == "Item 1")
        #expect(fetched2?.name == "Item 2")

        // Verify they're different items
        #expect(fetched1?.stable_id != fetched2?.stable_id)
    }

    @Test("Updating existing item with updateItem works correctly")
    func testUpdateExistingItem() async throws {
        let repo = createRepository()

        // Create initial item
        let original = GlassItemModel(
            stable_id: "test-update-001",
            name: "Original Name",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        _ = try await repo.createItem(original)

        // Update the item using updateItem (not createItem)
        let updated = GlassItemModel(
            stable_id: "test-update-001",
            name: "Updated Name",
            sku: "001",
            manufacturer: "bullseye",
            coe: 96,
            mfr_status: "discontinued"
        )
        _ = try await repo.updateItem(updated)

        // Verify the update worked
        let fetched = try await repo.fetchItem(byStableId: "test-update-001")
        #expect(fetched?.name == "Updated Name")
        #expect(fetched?.coe == 96)
        #expect(fetched?.mfr_status == "discontinued")
    }
}
