//
//  UserNotesEditorTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//  Tests for UserNotesEditor view component
//
// Target: FlameworkerTests

import Testing
import Foundation
@testable import Flameworker

@Suite("User Notes Editor Tests", .serialized)
struct UserNotesEditorTests {

    // MARK: - Test Data

    private func createTestItem() -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            natural_key: "test-item-001",
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )
    }

    // MARK: - Repository Interaction Tests

    @Test("Should load existing notes on appear")
    func testLoadExistingNotes() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Pre-populate with test notes
        let existingNotes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "These are my existing notes"
        )
        _ = try await mockRepo.createNotes(existingNotes)

        // Verify notes exist
        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes != nil, "Should fetch existing notes")
        #expect(fetchedNotes?.notes == "These are my existing notes")
    }

    @Test("Should handle no existing notes gracefully")
    func testLoadNoExistingNotes() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Try to fetch notes that don't exist
        let fetchedNotes = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetchedNotes == nil, "Should return nil when no notes exist")
    }

    @Test("Should save new notes successfully")
    func testSaveNewNotes() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create new notes
        let newNotes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "These are my new notes"
        )

        let saved = try await mockRepo.setNotes(newNotes)
        #expect(saved.notes == "These are my new notes")
        #expect(saved.item_natural_key == item.glassItem.natural_key)

        // Verify they were saved
        let fetched = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetched?.notes == "These are my new notes")
    }

    @Test("Should update existing notes successfully")
    func testUpdateExistingNotes() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create initial notes
        let initialNotes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Initial notes"
        )
        _ = try await mockRepo.createNotes(initialNotes)

        // Update notes
        let updatedNotes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Updated notes"
        )
        let saved = try await mockRepo.setNotes(updatedNotes)

        #expect(saved.notes == "Updated notes")

        // Verify update persisted
        let fetched = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(fetched?.notes == "Updated notes")
    }

    @Test("Should delete notes successfully")
    func testDeleteNotes() async throws {
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
        #expect(beforeDelete != nil, "Notes should exist before deletion")

        // Delete notes
        try await mockRepo.deleteNotes(forItem: item.glassItem.natural_key)

        // Verify deletion
        let afterDelete = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(afterDelete == nil, "Notes should be nil after deletion")
    }

    // MARK: - Validation Tests

    @Test("Should reject empty notes")
    func testRejectEmptyNotes() async throws {
        let mockRepo = MockUserNotesRepository()

        let emptyNotes = UserNotesModel(
            item_natural_key: "test-item",
            notes: ""
        )

        #expect(!emptyNotes.isValid, "Empty notes should be invalid")
        #expect(emptyNotes.validationErrors.contains("Notes cannot be empty"))

        // Repository should reject invalid notes
        do {
            _ = try await mockRepo.createNotes(emptyNotes)
            #expect(Bool(false), "Should throw error for invalid notes")
        } catch {
            #expect(error.localizedDescription.contains("Invalid"), "Should indicate invalid data")
        }
    }

    @Test("Should reject whitespace-only notes")
    func testRejectWhitespaceOnlyNotes() async throws {
        let mockRepo = MockUserNotesRepository()

        let whitespaceNotes = UserNotesModel(
            item_natural_key: "test-item",
            notes: "   \n\t  "
        )

        #expect(!whitespaceNotes.isValid, "Whitespace-only notes should be invalid")
        #expect(whitespaceNotes.validationErrors.contains("Notes cannot be empty"))
    }

    @Test("Should trim whitespace from notes")
    func testTrimWhitespace() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        let notesWithWhitespace = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "  These are my notes  \n"
        )

        #expect(notesWithWhitespace.notes == "These are my notes", "Should trim whitespace")

        let saved = try await mockRepo.setNotes(notesWithWhitespace)
        #expect(saved.notes == "These are my notes", "Saved notes should be trimmed")
    }

    // MARK: - Character Limit Tests

    @Test("Should accept notes within character limit")
    func testAcceptNotesWithinLimit() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes with 1000 characters (well within 5000 limit)
        let longNotes = String(repeating: "a", count: 1000)
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: longNotes
        )

        #expect(notes.isValid, "Notes within limit should be valid")
        #expect(notes.characterCount == 1000)

        let saved = try await mockRepo.setNotes(notes)
        #expect(saved.notes.count == 1000)
    }

    @Test("Should handle notes at character limit")
    func testHandleNotesAtLimit() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Create notes with exactly 5000 characters
        let maxNotes = String(repeating: "a", count: 5000)
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: maxNotes
        )

        #expect(notes.isValid, "Notes at limit should be valid")
        #expect(notes.characterCount == 5000)

        let saved = try await mockRepo.setNotes(notes)
        #expect(saved.notes.count == 5000)
    }

    // MARK: - Notes Metadata Tests

    @Test("Should provide word count")
    func testProvideWordCount() {
        let notes = UserNotesModel(
            item_natural_key: "test-item",
            notes: "This is a test note with eight words"
        )

        #expect(notes.wordCount == 8, "Should count words correctly")
    }

    @Test("Should provide character count")
    func testProvideCharacterCount() {
        let notes = UserNotesModel(
            item_natural_key: "test-item",
            notes: "Test"
        )

        #expect(notes.characterCount == 4, "Should count characters correctly")
    }

    @Test("Should handle multi-line notes")
    func testHandleMultilineNotes() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        let multilineNotes = """
        Line 1: First line of notes
        Line 2: Second line of notes
        Line 3: Third line of notes
        """

        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: multilineNotes
        )

        #expect(notes.isValid, "Multi-line notes should be valid")

        let saved = try await mockRepo.setNotes(notes)
        #expect(saved.notes.contains("Line 1"))
        #expect(saved.notes.contains("Line 2"))
        #expect(saved.notes.contains("Line 3"))
    }

    // MARK: - Concurrent Operations Tests

    @Test("Should handle rapid save operations")
    func testRapidSaveOperations() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Perform multiple rapid saves
        for i in 1...10 {
            let notes = UserNotesModel(
                item_natural_key: item.glassItem.natural_key,
                notes: "Notes version \(i)"
            )
            _ = try await mockRepo.setNotes(notes)
        }

        // Final state should be last save
        let final = try await mockRepo.fetchNotes(forItem: item.glassItem.natural_key)
        #expect(final?.notes == "Notes version 10", "Should save final version")
    }

    // MARK: - Edge Cases

    @Test("Should handle special characters in notes")
    func testHandleSpecialCharacters() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        let specialCharNotes = "Special chars: !@#$%^&*()_+-={}[]|:\";<>?,./~`"
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: specialCharNotes
        )

        #expect(notes.isValid, "Notes with special characters should be valid")

        let saved = try await mockRepo.setNotes(notes)
        #expect(saved.notes == specialCharNotes, "Should preserve special characters")
    }

    @Test("Should handle emoji in notes")
    func testHandleEmoji() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        let emojiNotes = "Great color! 🔥🎨✨"
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: emojiNotes
        )

        #expect(notes.isValid, "Notes with emoji should be valid")

        let saved = try await mockRepo.setNotes(notes)
        #expect(saved.notes == emojiNotes, "Should preserve emoji")
    }

    @Test("Should handle Unicode characters in notes")
    func testHandleUnicode() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        let unicodeNotes = "日本語 한글 中文 Español"
        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: unicodeNotes
        )

        #expect(notes.isValid, "Notes with Unicode should be valid")

        let saved = try await mockRepo.setNotes(notes)
        #expect(saved.notes == unicodeNotes, "Should preserve Unicode characters")
    }

    // MARK: - Error Handling Tests

    @Test("Should handle repository errors gracefully")
    func testHandleRepositoryErrors() async throws {
        let item = createTestItem()
        let mockRepo = MockUserNotesRepository()

        // Enable random failures
        mockRepo.shouldRandomlyFail = true
        mockRepo.failureProbability = 1.0 // Always fail

        let notes = UserNotesModel(
            item_natural_key: item.glassItem.natural_key,
            notes: "Test notes"
        )

        do {
            _ = try await mockRepo.setNotes(notes)
            #expect(Bool(false), "Should throw error when repository fails")
        } catch {
            #expect(error.localizedDescription.contains("Simulated"), "Should get repository error")
        }
    }
}
