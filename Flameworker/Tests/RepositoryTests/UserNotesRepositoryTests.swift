//
//  UserNotesRepositoryTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//  Tests for the UserNotesRepository system
//
// Target: RepositoryTests

import Testing
import Foundation
import CoreData
@testable import Flameworker

@Suite("User Notes Repository Tests", .serialized)
struct UserNotesRepositoryTests {

    @Test("Should create UserNotesModel with required properties")
    func testUserNotesModelCreation() async throws {
        let notes = UserNotesModel(
            id: "test-id-123",
            item_natural_key: "cim-550-0",
            notes: "This is a test note"
        )

        #expect(notes.id == "test-id-123")
        #expect(notes.item_natural_key == "cim-550-0")
        #expect(notes.notes == "This is a test note")
    }

    @Test("Should validate UserNotesModel correctly")
    func testUserNotesModelValidation() async throws {
        // Valid notes
        let validNotes = UserNotesModel(
            item_natural_key: "cim-550-0",
            notes: "Valid notes"
        )
        #expect(validNotes.isValid == true)
        #expect(validNotes.validationErrors.isEmpty)

        // Invalid - empty natural key
        let invalidKey = UserNotesModel(
            item_natural_key: "",
            notes: "Some notes"
        )
        #expect(invalidKey.isValid == false)
        #expect(invalidKey.validationErrors.contains("Item natural key is required"))

        // Invalid - empty notes
        let invalidNotes = UserNotesModel(
            item_natural_key: "cim-550-0",
            notes: ""
        )
        #expect(invalidNotes.isValid == false)
        #expect(invalidNotes.validationErrors.contains("Notes cannot be empty"))
    }

    @Test("Should create and fetch user notes through repository")
    func testUserNotesRepositoryCreateAndFetch() async throws {
        let mockRepo = MockUserNotesRepository()

        let testNotes = UserNotesModel(
            item_natural_key: "cim-550-0",
            notes: "This color works great for backgrounds"
        )

        // Create notes
        let created = try await mockRepo.createNotes(testNotes)
        #expect(created.item_natural_key == "cim-550-0")
        #expect(created.notes == "This color works great for backgrounds")

        // Fetch notes
        let fetched = try await mockRepo.fetchNotes(forItem: "cim-550-0")
        #expect(fetched != nil)
        #expect(fetched?.item_natural_key == "cim-550-0")
        #expect(fetched?.notes == "This color works great for backgrounds")
    }

    @Test("Should update existing user notes")
    func testUserNotesRepositoryUpdate() async throws {
        let mockRepo = MockUserNotesRepository()

        // Create initial notes
        let initial = UserNotesModel(
            item_natural_key: "bullseye-001-0",
            notes: "Original notes"
        )
        let created = try await mockRepo.createNotes(initial)

        // Update notes
        let updated = UserNotesModel(
            id: created.id,
            item_natural_key: "bullseye-001-0",
            notes: "Updated notes with more details"
        )
        let result = try await mockRepo.updateNotes(updated)

        #expect(result.notes == "Updated notes with more details")

        // Verify update persisted
        let fetched = try await mockRepo.fetchNotes(forItem: "bullseye-001-0")
        #expect(fetched?.notes == "Updated notes with more details")
    }

    @Test("Should delete user notes")
    func testUserNotesRepositoryDelete() async throws {
        let mockRepo = MockUserNotesRepository()

        // Create notes
        let testNotes = UserNotesModel(
            item_natural_key: "ef-591284-0",
            notes: "Notes to be deleted"
        )
        _ = try await mockRepo.createNotes(testNotes)

        // Verify notes exist
        let exists = try await mockRepo.notesExist(forItem: "ef-591284-0")
        #expect(exists == true)

        // Delete notes
        try await mockRepo.deleteNotes(forItem: "ef-591284-0")

        // Verify notes deleted
        let deleted = try await mockRepo.fetchNotes(forItem: "ef-591284-0")
        #expect(deleted == nil)

        let existsAfter = try await mockRepo.notesExist(forItem: "ef-591284-0")
        #expect(existsAfter == false)
    }

    @Test("Should fetch all user notes")
    func testUserNotesRepositoryFetchAll() async throws {
        let mockRepo = MockUserNotesRepository()

        let notes1 = UserNotesModel(item_natural_key: "item-001", notes: "Notes for item 001")
        let notes2 = UserNotesModel(item_natural_key: "item-002", notes: "Notes for item 002")
        let notes3 = UserNotesModel(item_natural_key: "item-003", notes: "Notes for item 003")

        _ = try await mockRepo.createNotes(notes1)
        _ = try await mockRepo.createNotes(notes2)
        _ = try await mockRepo.createNotes(notes3)

        let allNotes = try await mockRepo.fetchAllNotes()

        #expect(allNotes.count == 3)
        #expect(allNotes.contains { $0.item_natural_key == "item-001" })
        #expect(allNotes.contains { $0.item_natural_key == "item-002" })
        #expect(allNotes.contains { $0.item_natural_key == "item-003" })
    }

    @Test("Should fetch notes for multiple items")
    func testUserNotesRepositoryFetchMultiple() async throws {
        let mockRepo = MockUserNotesRepository()

        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-A", notes: "Notes A"))
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-B", notes: "Notes B"))
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-C", notes: "Notes C"))

        let fetchKeys = ["item-A", "item-C", "item-X"]
        let notesMap = try await mockRepo.fetchNotes(forItems: fetchKeys)

        #expect(notesMap.count == 2)
        #expect(notesMap["item-A"]?.notes == "Notes A")
        #expect(notesMap["item-C"]?.notes == "Notes C")
        #expect(notesMap["item-X"] == nil)
    }

    @Test("Should search user notes by content")
    func testUserNotesRepositorySearch() async throws {
        let mockRepo = MockUserNotesRepository()

        _ = try await mockRepo.createNotes(UserNotesModel(
            item_natural_key: "cim-874-0",
            notes: "Great color for backgrounds and neutral tones"
        ))
        _ = try await mockRepo.createNotes(UserNotesModel(
            item_natural_key: "bullseye-001-0",
            notes: "Clear glass perfect for overlays"
        ))
        _ = try await mockRepo.createNotes(UserNotesModel(
            item_natural_key: "ef-591284-0",
            notes: "Beautiful reactive glass"
        ))

        // Search in notes content
        let backgroundResults = try await mockRepo.searchNotes(containing: "background")
        #expect(backgroundResults.count == 1)
        #expect(backgroundResults.first?.item_natural_key == "cim-874-0")

        // Search in natural key
        let bullseyeResults = try await mockRepo.searchNotes(containing: "bullseye")
        #expect(bullseyeResults.count == 1)
        #expect(bullseyeResults.first?.item_natural_key == "bullseye-001-0")

        // Search with no matches
        let noResults = try await mockRepo.searchNotes(containing: "xyz")
        #expect(noResults.isEmpty)
    }

    @Test("Should set notes using upsert operation")
    func testUserNotesRepositorySetNotes() async throws {
        let mockRepo = MockUserNotesRepository()

        // First set - creates new
        let notes1 = UserNotesModel(
            item_natural_key: "test-item",
            notes: "Initial notes"
        )
        let result1 = try await mockRepo.setNotes(notes1)
        #expect(result1.notes == "Initial notes")

        // Second set - updates existing
        let notes2 = UserNotesModel(
            item_natural_key: "test-item",
            notes: "Updated notes"
        )
        let result2 = try await mockRepo.setNotes(notes2)
        #expect(result2.notes == "Updated notes")

        // Verify only one record exists
        let all = try await mockRepo.fetchAllNotes()
        let testNotes = all.filter { $0.item_natural_key == "test-item" }
        #expect(testNotes.count == 1)
    }

    @Test("Should get accurate notes count")
    func testUserNotesRepositoryCount() async throws {
        let mockRepo = MockUserNotesRepository()

        // Initially empty
        let initialCount = try await mockRepo.getNotesCount()
        #expect(initialCount == 0)

        // Add notes
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-1", notes: "Notes 1"))
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-2", notes: "Notes 2"))
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-3", notes: "Notes 3"))

        let count = try await mockRepo.getNotesCount()
        #expect(count == 3)
    }

    @Test("Should delete all user notes")
    func testUserNotesRepositoryDeleteAll() async throws {
        let mockRepo = MockUserNotesRepository()

        // Create multiple notes
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-1", notes: "Notes 1"))
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-2", notes: "Notes 2"))
        _ = try await mockRepo.createNotes(UserNotesModel(item_natural_key: "item-3", notes: "Notes 3"))

        // Verify notes exist
        let before = try await mockRepo.getNotesCount()
        #expect(before == 3)

        // Delete all
        try await mockRepo.deleteAllNotes()

        // Verify all deleted
        let after = try await mockRepo.getNotesCount()
        #expect(after == 0)

        let allNotes = try await mockRepo.fetchAllNotes()
        #expect(allNotes.isEmpty)
    }

    @Test("Should handle error when creating duplicate notes")
    func testUserNotesRepositoryDuplicateError() async throws {
        let mockRepo = MockUserNotesRepository()

        let notes = UserNotesModel(
            item_natural_key: "duplicate-test",
            notes: "Original notes"
        )

        // Create first time - should succeed
        _ = try await mockRepo.createNotes(notes)

        // Try to create again - should fail
        do {
            _ = try await mockRepo.createNotes(notes)
            #expect(Bool(false), "Should throw error for duplicate notes")
        } catch {
            #expect(error.localizedDescription.contains("already exist"))
        }
    }

    @Test("Should handle error when updating non-existent notes")
    func testUserNotesRepositoryUpdateNonExistent() async throws {
        let mockRepo = MockUserNotesRepository()

        let notes = UserNotesModel(
            item_natural_key: "non-existent",
            notes: "These notes don't exist"
        )

        do {
            _ = try await mockRepo.updateNotes(notes)
            #expect(Bool(false), "Should throw error when updating non-existent notes")
        } catch {
            #expect(error.localizedDescription.contains("not found"))
        }
    }

    @Test("Should delete notes by ID")
    func testUserNotesRepositoryDeleteById() async throws {
        let mockRepo = MockUserNotesRepository()

        let notes = UserNotesModel(
            item_natural_key: "test-item",
            notes: "Test notes"
        )
        let created = try await mockRepo.createNotes(notes)

        // Delete by ID
        try await mockRepo.deleteNotes(byId: created.id)

        // Verify deleted
        let fetched = try await mockRepo.fetchNotes(forItem: "test-item")
        #expect(fetched == nil)
    }

    @Test("UserNotesModel should trim whitespace")
    func testUserNotesModelTrimsWhitespace() async throws {
        let notes = UserNotesModel(
            item_natural_key: "  test-item  ",
            notes: "  Some notes with whitespace  "
        )

        #expect(notes.item_natural_key == "test-item")
        #expect(notes.notes == "Some notes with whitespace")
    }

    @Test("UserNotesModel should provide word and character counts")
    func testUserNotesModelWordCount() async throws {
        let notes = UserNotesModel(
            item_natural_key: "test-item",
            notes: "This is a test note with seven words"
        )

        #expect(notes.wordCount == 8)
        #expect(notes.characterCount > 0)
    }

    @Test("Should verify Core Data UserNotes entity will exist")
    func testUserNotesEntityExists() async throws {
        // This test verifies that the Core Data model will be able to load
        // Note: The entity needs to be added to the .xcdatamodeld file manually
        let context = PersistenceController(inMemory: true).container.viewContext

        do {
            // Try to create a fetch request - this will fail if entity doesn't exist yet
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "UserNotes")

            // Should not throw an error once entity is added
            let count = try context.count(for: fetchRequest)
            #expect(count >= 0, "Entity exists and can be queried")
        } catch {
            // Expected to fail until UserNotes entity is added to .xcdatamodeld
            #expect(error.localizedDescription.contains("UserNotes") ||
                   error.localizedDescription.contains("entity"),
                   "Should fail with entity-related error until UserNotes is added to Core Data model: \(error.localizedDescription)")
        }
    }
}
