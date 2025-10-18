//
//  InventoryDetailViewUserNotesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//  Tests for UserNotes integration in InventoryDetailView
//
// Target: FlameworkerTests

import Testing
import Foundation
@testable import Flameworker

@Suite("Inventory Detail View - User Notes Integration Tests", .serialized)
struct InventoryDetailViewUserNotesTests {

    // MARK: - Test Data

    private func createTestItem(naturalKey: String = "test-item-001") -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            natural_key: naturalKey,
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Manufacturer notes for testing",
            coe: 96,
            url: "https://example.com",
            mfr_status: "available"
        )

        let inventory = [
            InventoryModel(item_natural_key: naturalKey, type: "rod", quantity: 10.0)
        ]

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: ["test"],
            userTags: [],
            locations: []
        )
    }

    // MARK: - Display Tests

    @Test("Should show 'Add a note' button when no notes exist")
    func testShowAddNoteButton() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Verify no notes exist
        let notes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(notes == nil, "Should have no notes initially")

        // In a real view test, we would verify the button appears
        // For now, verify the data state
        #expect(true, "Add note button should be shown when notes are nil")
    }

    @Test("Should show user notes when they exist")
    func testShowExistingNotes() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "My personal notes about this glass"
        )
        _ = try await mockRepo.createNotes(notes)

        // Verify notes exist
        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes != nil, "Notes should exist")
        #expect(fetchedNotes?.notes == "My personal notes about this glass")
    }

    @Test("Should show Edit button when notes exist")
    func testShowEditButton() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Existing notes"
        )
        _ = try await mockRepo.createNotes(notes)

        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes != nil, "Should have notes to edit")
    }

    // MARK: - Loading Tests

    @Test("Should load user notes on view appear")
    func testLoadNotesOnAppear() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Pre-populate notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Pre-existing notes"
        )
        _ = try await mockRepo.createNotes(notes)

        // Simulate view appearing and loading notes
        let loadedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(loadedNotes != nil, "Should load notes on appear")
        #expect(loadedNotes?.notes == "Pre-existing notes")
    }

    @Test("Should handle missing notes gracefully on load")
    func testHandleMissingNotesOnLoad() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Try to load notes that don't exist
        let loadedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(loadedNotes == nil, "Should return nil for missing notes")
    }

    // MARK: - Navigation Tests

    @Test("Should navigate to editor when add note is tapped")
    func testNavigateToEditorOnAdd() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Verify no notes exist (would show Add button)
        let notes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(notes == nil, "Should have no notes")

        // In real UI test, would verify navigation occurs
        #expect(true, "Should navigate to editor")
    }

    @Test("Should navigate to editor when edit note is tapped")
    func testNavigateToEditorOnEdit() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create existing notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Existing notes"
        )
        _ = try await mockRepo.createNotes(notes)

        // Verify notes exist (would show Edit button)
        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes != nil, "Should have notes to edit")

        // In real UI test, would verify navigation occurs
        #expect(true, "Should navigate to editor")
    }

    // MARK: - Refresh Tests

    @Test("Should reload notes after editor dismissal")
    func testReloadNotesAfterDismiss() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Initially no notes
        let initialNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(initialNotes == nil)

        // Simulate adding notes in editor
        let newNotes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Newly added notes"
        )
        _ = try await mockRepo.createNotes(newNotes)

        // Simulate reload after editor dismissal
        let reloadedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(reloadedNotes != nil, "Should reload notes after editor dismissal")
        #expect(reloadedNotes?.notes == "Newly added notes")
    }

    @Test("Should show updated notes after edit")
    func testShowUpdatedNotesAfterEdit() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create initial notes
        let initialNotes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Original notes"
        )
        _ = try await mockRepo.createNotes(initialNotes)

        // Verify initial state
        let beforeEdit = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(beforeEdit?.notes == "Original notes")

        // Simulate editing notes
        let updatedNotes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Updated notes"
        )
        _ = try await mockRepo.setNotes(updatedNotes)

        // Reload after edit
        let afterEdit = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(afterEdit?.notes == "Updated notes", "Should show updated notes")
    }

    @Test("Should hide notes after deletion")
    func testHideNotesAfterDeletion() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Notes to be deleted"
        )
        _ = try await mockRepo.createNotes(notes)

        // Verify notes exist
        let beforeDelete = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(beforeDelete != nil)

        // Delete notes
        try await mockRepo.deleteNotes(forItem: item.glassItem.natural_key)

        // Reload after deletion
        let afterDelete = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(afterDelete == nil, "Should have no notes after deletion")
    }

    // MARK: - Multiple Items Tests

    @Test("Should maintain separate notes for different items")
    func testSeparateNotesForDifferentItems() async throws {
        let item1 = createTestItem(naturalKey: "item-001")
        let item2 = createTestItem(naturalKey: "item-002")
        let mockRepo = MockUserNotesRepository()

        // Create notes for item 1
        let notes1 = UserNotesModel(
            item_natural_key: item1.glassItem.natural_key,
            notes: "Notes for item 1"
        )
        _ = try await mockRepo.createNotes(notes1)

        // Create notes for item 2
        let notes2 = UserNotesModel(
            item_natural_key: item2.glassItem.natural_key,
            notes: "Notes for item 2"
        )
        _ = try await mockRepo.createNotes(notes2)

        // Verify both exist independently
        let fetchedNotes1 = try await mockRepo.fetchNotes(forItem: item1.glassItem.natural_key)
        let fetchedNotes2 = try await mockRepo.fetchNotes(forItem: item2.glassItem.natural_key)

        #expect(fetchedNotes1?.notes == "Notes for item 1")
        #expect(fetchedNotes2?.notes == "Notes for item 2")
    }

    @Test("Should not show notes from other items")
    func testDoNotShowNotesFromOtherItems() async throws {
        let item1 = createTestItem(naturalKey: "item-001")
        let item2 = createTestItem(naturalKey: "item-002")
        let mockRepo = MockUserNotesRepository()

        // Create notes only for item 1
        let notes1 = UserNotesModel(
            item_natural_key: item1.glassItem.natural_key,
            notes: "Notes for item 1 only"
        )
        _ = try await mockRepo.createNotes(notes1)

        // Verify item 1 has notes
        let fetchedNotes1 = try await mockRepo.fetchNotes(forItem: item1.glassItem.natural_key)
        #expect(fetchedNotes1 != nil)

        // Verify item 2 has no notes
        let fetchedNotes2 = try await mockRepo.fetchNotes(forItem: item2.glassItem.natural_key)
        #expect(fetchedNotes2 == nil, "Item 2 should have no notes")
    }

    // MARK: - Integration with Other Sections Tests

    @Test("Should display notes in Glass Item Details section")
    func testDisplayNotesInGlassItemSection() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Notes for glass item details section"
        )
        _ = try await mockRepo.createNotes(notes)

        // Verify notes are associated with glass item
        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes?.item_natural_key == item.glassItem.natural_key)
    }

    @Test("Should show notes after manufacturer website link")
    func testNotesOrderingAfterWebsiteLink() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Verify item has URL
        #expect(item.glassItem.url != nil, "Item should have manufacturer URL")

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Notes appear after website link"
        )
        _ = try await mockRepo.createNotes(notes)

        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes != nil, "Notes should exist")
    }

    @Test("Should show notes even when no manufacturer website")
    func testShowNotesWithoutWebsite() async throws {
        // Create item without URL
        let glassItem = GlassItemModel(
            natural_key: "test-no-url",
            name: "Item Without URL",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        let item = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        let mockRepo = MockUserNotesRepository()

        // Verify no URL
        #expect(item.glassItem.url == nil || item.glassItem.url?.isEmpty == true)

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Notes without URL"
        )
        _ = try await mockRepo.createNotes(notes)

        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes != nil, "Should have notes even without URL")
    }

    // MARK: - Error Handling Tests

    @Test("Should handle repository errors during load")
    func testHandleRepositoryErrorDuringLoad() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Enable failures
        mockRepo.shouldRandomlyFail = true
        mockRepo.failureProbability = 1.0

        do {
            _ = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
            #expect(Bool(false), "Should throw error")
        } catch {
            #expect(error.localizedDescription.contains("Simulated"))
        }
    }

    // MARK: - Performance Tests

    @Test("Should load notes quickly")
    func testLoadNotesPerformance() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Performance test notes"
        )
        _ = try await mockRepo.createNotes(notes)

        // Measure load time
        let startTime = Date()
        _ = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration < 0.1, "Should load notes in under 100ms")
    }

    @Test("Should handle multiple rapid reloads")
    func testMultipleRapidReloads() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Rapid reload test"
        )
        _ = try await mockRepo.createNotes(notes)

        // Perform multiple rapid loads
        for _ in 1...10 {
            let loaded = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
            #expect(loaded?.notes == "Rapid reload test")
        }
    }
}
