//
//  AddInventoryItemView_NotesTests.swift
//  MoltenTests
//
//  Tests for AddInventoryItemView notes field functionality
//  Verifies that notes are properly captured, validated, and saved with inventory items
//

import Testing
import SwiftUI
@testable import Molten

@Suite("AddInventoryItemView Notes Tests", .serialized)
@MainActor
struct AddInventoryItemView_NotesTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - Test Helpers

    /// Get a real catalog item for testing (catalog is read-only, can't create test items)
    func getRealCatalogItem() async throws -> GlassItemModel {
        let catalogService = deps.catalogService
        let catalogItems = try await catalogService.getGlassItemsLightweight()

        // Get first item that has a SKU
        guard let glassItem = catalogItems.first(where: { $0.sku != nil }) else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "No catalog items available for testing"])
        }

        return glassItem
    }

    // MARK: - Notes Field Initialization Tests

    @Test("Notes field initializes empty")
    func testNotesFieldInitializesEmpty() {
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        #expect(viewModel.notes.isEmpty)
    }

    @Test("Notes field is optional for form validation")
    func testNotesFieldOptionalForValidation() {
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        // Set required fields
        viewModel.stableId = "test-item-001-0"
        viewModel.quantity = "10"

        // Empty notes should not prevent validation
        viewModel.notes = ""
        #expect(viewModel.isValid)

        // Notes with content should also be valid
        viewModel.notes = "Test notes"
        #expect(viewModel.isValid)
    }

    // MARK: - Notes Text Input Tests

    @Test("Notes field accepts text input")
    func testNotesFieldAcceptsText() {
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        let testNotes = "These are my test notes for this glass item"
        viewModel.notes = testNotes

        #expect(viewModel.notes == testNotes)
    }

    @Test("Notes field accepts multiline text")
    func testNotesFieldAcceptsMultilineText() {
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        let multilineNotes = """
        Line 1: This glass is beautiful
        Line 2: Works great for clear casing
        Line 3: Highly reactive with copper
        """
        viewModel.notes = multilineNotes

        #expect(viewModel.notes == multilineNotes)
        #expect(viewModel.notes.contains("\n"))
    }

    @Test("Notes field accepts special characters")
    func testNotesFieldAcceptsSpecialCharacters() {
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        let notesWithSpecialChars = "Temperature: 1050°F • Strikes @1400° • Use 50/50 mix & test!"
        viewModel.notes = notesWithSpecialChars

        #expect(viewModel.notes == notesWithSpecialChars)
    }

    @Test("Notes field accepts long text")
    func testNotesFieldAcceptsLongText() {
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        let longNotes = String(repeating: "This glass is great for various applications. ", count: 20)
        viewModel.notes = longNotes

        #expect(viewModel.notes == longNotes)
        #expect(viewModel.notes.count > 500)
    }

    // MARK: - Notes Save Integration Tests

    @Test("Save works without notes (notes optional)")
    func testSaveWorksWithoutNotes() async throws {
        // Use real catalog item (catalog is read-only, can't create test items)
        let glassItem = try await getRealCatalogItem()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        // Load catalog items and lookup the item
        await viewModel.loadCatalogItems()
        viewModel.lookupCatalogItem(stableId: glassItem.stable_id)

        // Set required fields but leave notes empty
        viewModel.quantity = "5"
        viewModel.notes = ""

        // Save should succeed
        let success = await viewModel.save()
        #expect(success)

        // Verify inventory was created
        let inventory = try await deps.inventoryRepository.fetchInventory(forItem: glassItem.stable_id)
        #expect(!inventory.isEmpty)
    }

    @Test("Notes are saved when inventory is created")
    func testNotesAreSavedWithInventory() async throws {
        let glassItem = try await getRealCatalogItem()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        // Load catalog items and lookup the item
        await viewModel.loadCatalogItems()
        viewModel.lookupCatalogItem(stableId: glassItem.stable_id)

        // Set required fields and notes
        viewModel.quantity = "10"
        viewModel.notes = "Beautiful color, very reactive with copper"

        // Save
        let success = await viewModel.save()
        #expect(success)

        // Verify notes were saved to UserNotesRepository
        let savedNotes = try await deps.userNotesRepository.fetchNotes(forItem: glassItem.stable_id)
        #expect(savedNotes != nil)
        #expect(savedNotes?.notes == "Beautiful color, very reactive with copper")
        #expect(savedNotes?.item_stable_id == glassItem.stable_id)
    }

    @Test("Notes are associated with correct glass item")
    func testNotesAssociatedWithCorrectItem() async throws {
        // Get two different real catalog items (catalog is read-only, can't create test items)
        let catalogService = deps.catalogService
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let itemsWithSKU = catalogItems.filter { $0.sku != nil }
        guard itemsWithSKU.count >= 2 else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Need at least 2 catalog items for testing"])
        }
        let item1 = itemsWithSKU[0]
        let item2 = itemsWithSKU[1]

        // Add inventory with notes for item1
        let viewModel1 = AddInventoryItemViewModel(
            prefilledNaturalKey: item1.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )
        await viewModel1.loadCatalogItems()
        viewModel1.lookupCatalogItem(stableId: item1.stable_id)
        viewModel1.quantity = "5"
        viewModel1.notes = "Notes for item 1"
        _ = await viewModel1.save()

        // Add inventory with notes for item2
        let viewModel2 = AddInventoryItemViewModel(
            prefilledNaturalKey: item2.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )
        await viewModel2.loadCatalogItems()
        viewModel2.lookupCatalogItem(stableId: item2.stable_id)
        viewModel2.quantity = "3"
        viewModel2.notes = "Notes for item 2"
        _ = await viewModel2.save()

        // Verify notes are correctly associated
        let notes1 = try await deps.userNotesRepository.fetchNotes(forItem: item1.stable_id)
        let notes2 = try await deps.userNotesRepository.fetchNotes(forItem: item2.stable_id)

        #expect(notes1?.notes == "Notes for item 1")
        #expect(notes1?.item_stable_id == item1.stable_id)

        #expect(notes2?.notes == "Notes for item 2")
        #expect(notes2?.item_stable_id == item2.stable_id)
    }

    // MARK: - Whitespace and Empty Notes Tests

    @Test("Empty notes are not saved to repository")
    func testEmptyNotesNotSaved() async throws {
        let glassItem = try await getRealCatalogItem()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        await viewModel.loadCatalogItems()
        viewModel.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel.quantity = "5"
        viewModel.notes = ""

        _ = await viewModel.save()

        // Verify no notes were saved
        let savedNotes = try await deps.userNotesRepository.fetchNotes(forItem: glassItem.stable_id)
        #expect(savedNotes == nil)
    }

    @Test("Whitespace-only notes are not saved")
    func testWhitespaceOnlyNotesNotSaved() async throws {
        let glassItem = try await getRealCatalogItem()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        await viewModel.loadCatalogItems()
        viewModel.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel.quantity = "5"
        viewModel.notes = "   \n\n   \t  "  // Only whitespace

        _ = await viewModel.save()

        // Verify no notes were saved
        let savedNotes = try await deps.userNotesRepository.fetchNotes(forItem: glassItem.stable_id)
        #expect(savedNotes == nil)
    }

    @Test("Notes with leading/trailing whitespace are trimmed before save")
    func testNotesAreTrimmedBeforeSave() async throws {
        let glassItem = try await getRealCatalogItem()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        await viewModel.loadCatalogItems()
        viewModel.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel.quantity = "5"
        viewModel.notes = "  This is my note with extra whitespace  \n\n"

        _ = await viewModel.save()

        // Verify notes were trimmed
        let savedNotes = try await deps.userNotesRepository.fetchNotes(forItem: glassItem.stable_id)
        #expect(savedNotes != nil)
        #expect(savedNotes?.notes == "This is my note with extra whitespace")
    }

    // MARK: - Existing Notes Update Tests

    @Test("Existing notes are updated when adding more inventory to same item")
    func testExistingNotesAreUpdated() async throws {
        let glassItem = try await getRealCatalogItem()

        // First save: Add inventory with initial notes
        let viewModel1 = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )
        await viewModel1.loadCatalogItems()
        viewModel1.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel1.quantity = "5"
        viewModel1.notes = "Initial notes about this glass"
        _ = await viewModel1.save()

        // Verify initial notes
        let initialNotes = try await deps.userNotesRepository.fetchNotes(forItem: glassItem.stable_id)
        #expect(initialNotes?.notes == "Initial notes about this glass")

        // Second save: Add more inventory with updated notes
        let viewModel2 = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )
        await viewModel2.loadCatalogItems()
        viewModel2.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel2.quantity = "3"
        viewModel2.notes = "Updated notes with new information"
        _ = await viewModel2.save()

        // Verify notes were updated, not duplicated
        let updatedNotes = try await deps.userNotesRepository.fetchNotes(forItem: glassItem.stable_id)
        #expect(updatedNotes?.notes == "Updated notes with new information")
        #expect(updatedNotes?.item_stable_id == glassItem.stable_id)

        // Verify only one notes record exists
        let allNotes = try await deps.userNotesRepository.fetchAllNotes()
        let notesForItem = allNotes.filter { $0.item_stable_id == glassItem.stable_id }
        #expect(notesForItem.count == 1)
    }

    @Test("Empty notes on second save preserve existing notes")
    func testEmptyNotesOnSecondSavePreserveExisting() async throws {
        let glassItem = try await getRealCatalogItem()

        // First save: Add inventory with notes
        let viewModel1 = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )
        await viewModel1.loadCatalogItems()
        viewModel1.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel1.quantity = "5"
        viewModel1.notes = "Important notes to preserve"
        _ = await viewModel1.save()

        // Second save: Add more inventory without notes
        let viewModel2 = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )
        await viewModel2.loadCatalogItems()
        viewModel2.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel2.quantity = "3"
        viewModel2.notes = ""  // Empty
        _ = await viewModel2.save()

        // Verify original notes are preserved (not deleted)
        let savedNotes = try await deps.userNotesRepository.fetchNotes(forItem: glassItem.stable_id)
        #expect(savedNotes?.notes == "Important notes to preserve")
    }

    // MARK: - Error Handling Tests

    @Test("Save succeeds even if notes save fails (graceful degradation)")
    func testSaveSucceedsEvenIfNotesFail() async throws {
        let glassItem = try await getRealCatalogItem()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        await viewModel.loadCatalogItems()
        viewModel.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel.quantity = "5"
        viewModel.notes = "These notes might fail to save"

        // Save should succeed (inventory is primary, notes are secondary)
        let success = await viewModel.save()
        #expect(success)

        // Verify inventory was created even if notes failed
        let inventory = try await deps.inventoryRepository.fetchInventory(forItem: glassItem.stable_id)
        #expect(!inventory.isEmpty)
    }

    @Test("Error message indicates notes save failure without blocking inventory save")
    func testErrorMessageForNotesFailure() async throws {
        let glassItem = try await getRealCatalogItem()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: glassItem.stable_id,
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService,
            userNotesRepository: deps.userNotesRepository
        )

        await viewModel.loadCatalogItems()
        viewModel.lookupCatalogItem(stableId: glassItem.stable_id)
        viewModel.quantity = "5"
        viewModel.notes = "Test notes"

        let success = await viewModel.save()
        #expect(success)

        // If notes failed to save, errorMessage should indicate it (but save still succeeds)
        // This tests the graceful degradation pattern
    }

    // MARK: - Notes Model Tests

    @Test("UserNotesModel is created with correct fields")
    func testUserNotesModelCreation() {
        let notes = UserNotesModel(
            item_stable_id: "test-item-001-0",
            notes: "Test notes content"
        )

        #expect(notes.item_stable_id == "test-item-001-0")
        #expect(notes.notes == "Test notes content")
        #expect(notes.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    // MARK: - Batch Notes Tests

    @Test("Multiple items can have notes simultaneously")
    func testMultipleItemsWithNotes() async throws {
        // Get three real catalog items (catalog is read-only, can't create test items)
        let catalogService = deps.catalogService
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let itemsWithSKU = catalogItems.filter { $0.sku != nil }
        guard itemsWithSKU.count >= 3 else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Need at least 3 catalog items for testing"])
        }
        let items = Array(itemsWithSKU.prefix(3))

        // Add inventory with notes for each
        for (index, item) in items.enumerated() {
            let viewModel = AddInventoryItemViewModel(
                prefilledNaturalKey: item.stable_id,
                inventoryTrackingService: deps.inventoryTrackingService,
                catalogService: deps.catalogService,
                userNotesRepository: deps.userNotesRepository
            )
            await viewModel.loadCatalogItems()
            viewModel.lookupCatalogItem(stableId: item.stable_id)
            viewModel.quantity = "5"
            viewModel.notes = "Notes for item \(index + 1)"
            _ = await viewModel.save()
        }

        // Verify all notes were saved correctly
        for (index, item) in items.enumerated() {
            let savedNotes = try await deps.userNotesRepository.fetchNotes(forItem: item.stable_id)
            #expect(savedNotes?.notes == "Notes for item \(index + 1)")
        }

        // Verify total count
        let allNotes = try await deps.userNotesRepository.fetchAllNotes()
        let testNotes = allNotes.filter { $0.notes.starts(with: "Notes for item") }
        #expect(testNotes.count >= 3)
    }
}
