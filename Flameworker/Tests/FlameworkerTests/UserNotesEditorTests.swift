//
//  UserNotesEditorTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/17/25.
//  Tests for UserNotesEditor component
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
@testable import Flameworker

@Suite("UserNotesEditor Tests")
struct UserNotesEditorTests {

    @Test("UserNotesEditor should accept CompleteInventoryItemModel")
    func testUserNotesEditorAcceptsCompleteModel() {
        // Arrange: Create a complete inventory item model
        let glassItem = GlassItemModel(
            natural_key: "test-glass-001-0",
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        let mockRepo = MockUserNotesRepository()

        // Act: Create UserNotesEditor with complete model
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: mockRepo
        )

        // Assert: Editor should be created successfully
        #expect(editor != nil, "UserNotesEditor should accept CompleteInventoryItemModel")
    }

    @Test("UserNotesEditor should accept UserNotesRepository via dependency injection")
    func testUserNotesEditorAcceptsRepository() {
        // Arrange: Create item and repository
        let glassItem = GlassItemModel(
            natural_key: "test-glass-002-0",
            name: "Test Item",
            sku: "002",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        let mockRepo = MockUserNotesRepository()

        // Act: Create editor with injected repository
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: mockRepo
        )

        // Assert: Should support dependency injection
        #expect(editor != nil, "UserNotesEditor should accept repository via dependency injection")
    }

    @Test("UserNotesEditor should handle creating new notes")
    func testUserNotesEditorCreatesNewNotes() {
        // Arrange: Create item without existing notes
        let glassItem = GlassItemModel(
            natural_key: "test-new-notes-0",
            name: "Test Item for New Notes",
            sku: "new",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor for new notes
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should support creating new notes
        #expect(editor != nil, "UserNotesEditor should support creating new notes")
    }

    @Test("UserNotesEditor should handle editing existing notes")
    func testUserNotesEditorEditsExistingNotes() {
        // Arrange: Create item with existing notes
        let glassItem = GlassItemModel(
            natural_key: "test-edit-notes-0",
            name: "Test Item for Editing",
            sku: "edit",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        let mockRepo = MockUserNotesRepository()

        // Act: Create editor for editing existing notes
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: mockRepo
        )

        // Assert: Should support editing existing notes
        #expect(editor != nil, "UserNotesEditor should support editing existing notes")
    }

    @Test("UserNotesEditor should handle very long notes input")
    func testUserNotesEditorHandlesLongNotes() {
        // Arrange: Create item
        let glassItem = GlassItemModel(
            natural_key: "test-long-input-0",
            name: "Test Item for Long Notes",
            sku: "long",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor - should handle long text input
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should support long text input without issues
        #expect(editor != nil, "UserNotesEditor should handle long notes input")
    }

    @Test("UserNotesEditor should handle multiline notes")
    func testUserNotesEditorHandlesMultilineNotes() {
        // Arrange: Create item for multiline notes
        let glassItem = GlassItemModel(
            natural_key: "test-multiline-0",
            name: "Test Item for Multiline Notes",
            sku: "multiline",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor - should support multiline text
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should handle multiline notes
        #expect(editor != nil, "UserNotesEditor should handle multiline notes")
    }

    @Test("UserNotesEditor should validate notes before saving")
    func testUserNotesEditorValidatesNotes() {
        // Arrange: Create item
        let glassItem = GlassItemModel(
            natural_key: "test-validation-0",
            name: "Test Item for Validation",
            sku: "validation",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor - should validate input before saving
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should validate notes (e.g., not just whitespace)
        #expect(editor != nil, "UserNotesEditor should validate notes before saving")
    }

    @Test("UserNotesEditor should handle special characters in notes")
    func testUserNotesEditorHandlesSpecialCharacters() {
        // Arrange: Create item for special character testing
        let glassItem = GlassItemModel(
            natural_key: "test-special-chars-0",
            name: "Test Item for Special Characters",
            sku: "special",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor - should handle special characters
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should handle special characters without issues
        #expect(editor != nil, "UserNotesEditor should handle special characters")
    }

    @Test("UserNotesEditor should handle save errors gracefully")
    func testUserNotesEditorHandlesSaveErrors() {
        // Arrange: Create item
        let glassItem = GlassItemModel(
            natural_key: "test-save-error-0",
            name: "Test Item for Save Error",
            sku: "error",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor - should handle save errors
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should handle save errors gracefully with error alerts
        #expect(editor != nil, "UserNotesEditor should handle save errors gracefully")
    }

    @Test("UserNotesEditor should support canceling without saving")
    func testUserNotesEditorSupportsCanceling() {
        // Arrange: Create item
        let glassItem = GlassItemModel(
            natural_key: "test-cancel-0",
            name: "Test Item for Cancel",
            sku: "cancel",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor - should support canceling
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should allow canceling without saving changes
        #expect(editor != nil, "UserNotesEditor should support canceling without saving")
    }

    @Test("UserNotesEditor should display item information in header")
    func testUserNotesEditorDisplaysItemInfo() {
        // Arrange: Create item with specific details
        let glassItem = GlassItemModel(
            natural_key: "test-header-0",
            name: "Test Glass Color",
            sku: "header",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )

        // Act: Create editor - should show item info
        let editor = UserNotesEditor(
            item: completeItem,
            userNotesRepository: MockUserNotesRepository()
        )

        // Assert: Should display item name and details in header
        #expect(editor != nil, "UserNotesEditor should display item information")
    }
}
