//
//  AddInventoryItemViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/28/25.
//  Tests for AddInventoryItemViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for AddInventoryItemViewModel presentation logic
///
/// Tests cover: initialization, validation, type selection, glass item search, dimension handling, save logic
@Suite("AddInventoryItemViewModel Tests")
@MainActor
struct AddInventoryItemViewModelTests {

    // MARK: - Initialization Tests

    @Test("Should initialize with default values")
    func testInitialization() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()

        // Act
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Assert default values
        #expect(viewModel.stableId.isEmpty)
        #expect(viewModel.selectedGlassItem == nil)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.quantity.isEmpty)
        #expect(viewModel.selectedType == "rod")  // Default type
        #expect(viewModel.selectedSubtype == nil)
        #expect(viewModel.selectedSubsubtype == nil)
        #expect(viewModel.dimensions.isEmpty)
        #expect(viewModel.notes.isEmpty)
        #expect(viewModel.location.isEmpty)
        #expect(viewModel.glassItems.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isDimensionsExpanded == false)
    }

    @Test("Should initialize with prefilled natural key")
    func testInitializationWithPrefilledKey() async throws {
        // Arrange & Act
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: stableId,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Assert
        #expect(viewModel.stableId == stableId)
    }

    // MARK: - Validation Tests

    @Test("Should validate required fields")
    func testValidation() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Act & Assert - empty fields invalid
        #expect(viewModel.isValid == false)

        // Act - set stableId only
        viewModel.stableId = "bullseye-001-0"
        #expect(viewModel.isValid == false)  // Still invalid (no quantity)

        // Act - set quantity only
        viewModel.stableId = ""
        viewModel.quantity = "5"
        #expect(viewModel.isValid == false)  // Still invalid (no stableId)

        // Act - set both
        viewModel.stableId = "bullseye-001-0"
        viewModel.quantity = "5"
        #expect(viewModel.isValid == true)
    }

    @Test("Should validate quantity as decimal")
    func testQuantityValidation() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Act & Assert - valid inputs
        viewModel.quantity = "5.5"
        #expect(viewModel.parsedQuantity == 5.5)

        viewModel.quantity = "10"
        #expect(viewModel.parsedQuantity == 10.0)

        // Act & Assert - invalid inputs
        viewModel.quantity = ""
        #expect(viewModel.parsedQuantity == nil)

        viewModel.quantity = "abc"
        #expect(viewModel.parsedQuantity == nil)

        viewModel.quantity = "-5"
        #expect(viewModel.parsedQuantity == nil)
    }

    // MARK: - Glass Item Selection Tests

    @Test("Should load glass items")
    func testLoadGlassItems() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        mockGlassItemRepo.items = [
            GlassItemModel(stable_id: generateStableId(manufacturer: "bullseye", sku: "001"), name: "Clear", sku: "001", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "bullseye", sku: "254"), name: "Red", sku: "254", manufacturer: "bullseye", coe: 90, mfr_status: "available")
        ]

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Act
        await viewModel.loadGlassItems()

        // Assert
        #expect(viewModel.glassItems.count == 2)
        #expect(viewModel.isLoading == false)
    }

    @Test("Should select glass item")
    func testSelectGlassItem() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let item = GlassItemModel(stable_id: stableId, name: "Clear", sku: "001", manufacturer: "bullseye", coe: 90, mfr_status: "available")

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Act
        viewModel.selectGlassItem(item)

        // Assert
        #expect(viewModel.selectedGlassItem?.stable_id == stableId)
        #expect(viewModel.stableId == stableId)
    }

    @Test("Should clear selection")
    func testClearSelection() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let item = GlassItemModel(stable_id: stableId, name: "Clear", sku: "001", manufacturer: "bullseye", coe: 90, mfr_status: "available")

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.selectGlassItem(item)
        viewModel.searchText = "Clear"

        // Act
        viewModel.clearSelection()

        // Assert
        #expect(viewModel.selectedGlassItem == nil)
        #expect(viewModel.stableId.isEmpty)
        #expect(viewModel.searchText.isEmpty)
    }

    // MARK: - Type Selection Tests

    @Test("Should reset subtype when type changes")
    func testTypeChangeResetsSubtype() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.selectedType = "tube"
        viewModel.selectedSubtype = "borosilicate"
        viewModel.selectedSubsubtype = "thin-wall"
        viewModel.dimensions = ["length": "12", "diameter": "8"]
        viewModel.isDimensionsExpanded = true

        // Act
        viewModel.didChangeType()

        // Assert
        #expect(viewModel.selectedSubtype == nil)
        #expect(viewModel.selectedSubsubtype == nil)
        #expect(viewModel.dimensions.isEmpty)
        #expect(viewModel.isDimensionsExpanded == false)
    }

    @Test("Should reset subsubtype when subtype changes")
    func testSubtypeChangeResetsSubsubtype() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.selectedSubtype = "borosilicate"
        viewModel.selectedSubsubtype = "thin-wall"

        // Act
        viewModel.didChangeSubtype()

        // Assert
        #expect(viewModel.selectedSubsubtype == nil)
    }

    @Test("Should compute quantity unit label based on type")
    func testQuantityUnitLabel() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Act & Assert - different types
        viewModel.selectedType = "rod"
        #expect(viewModel.quantityUnitLabel == "rod")

        viewModel.selectedType = "tube"
        #expect(viewModel.quantityUnitLabel == "tubes")

        viewModel.selectedType = "frit"
        #expect(viewModel.quantityUnitLabel == "lbs")

        viewModel.selectedType = "sheet"
        #expect(viewModel.quantityUnitLabel == "sheets")
    }

    // MARK: - Save Tests

    @Test("Should save valid inventory item")
    func testSaveInventoryItem() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let item = GlassItemModel(stable_id: stableId, name: "Clear", sku: "001", manufacturer: "bullseye", coe: 90, mfr_status: "available")

        // Add item to repository so it exists when save() validates it
        _ = try await glassItemRepo.createItem(item)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: glassItemRepo
        )

        viewModel.selectGlassItem(item)
        viewModel.quantity = "5.0"
        viewModel.selectedType = "rod"
        viewModel.location = "Shelf A"
        viewModel.notes = "Test notes"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should not save with empty stableId")
    func testSaveInvalidStableId() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.stableId = ""
        viewModel.quantity = "5.0"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Should not save with invalid quantity")
    func testSaveInvalidQuantity() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let item = GlassItemModel(stable_id: stableId, name: "Clear", sku: "001", manufacturer: "bullseye", coe: 90, mfr_status: "available")

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.selectGlassItem(item)
        viewModel.quantity = "abc"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Should handle save with missing glass item")
    func testSaveWithMissingItem() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Set stableId but don't select glass item (selectedGlassItem will be nil)
        viewModel.stableId = "non-existent-001"
        viewModel.quantity = "5.0"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Should handle empty location as nil")
    func testEmptyLocationHandling() async throws {
        // Arrange
        RepositoryFactory.configureForTesting()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let item = GlassItemModel(stable_id: stableId, name: "Clear", sku: "001", manufacturer: "bullseye", coe: 90, mfr_status: "available")

        // Add item to repository so it exists when save() validates it
        _ = try await glassItemRepo.createItem(item)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            glassItemRepository: glassItemRepo
        )

        viewModel.selectGlassItem(item)
        viewModel.quantity = "5.0"
        viewModel.location = ""  // Empty location

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == true)
        // Note: We can't directly verify the location is nil with the real service,
        // but the test verifies that save succeeds with empty location
    }
}

// MARK: - Mock Repositories

// Mock glass item repository for testing
final class MockGlassItemRepositoryForViewModel: GlassItemRepository, @unchecked Sendable {
    var items: [GlassItemModel] = []

    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        return items
    }

    // Other required methods with minimal implementation
    func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? { nil }
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel { item }
    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] { items }
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel { item }
    func deleteItem(stableId: String) async throws {}
    func deleteItems(stableIds: [String]) async throws {}
    func searchItems(text: String) async throws -> [GlassItemModel] { [] }
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] { [] }
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] { [] }
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] { [] }
    func getDistinctManufacturers() async throws -> [String] { [] }
    func getDistinctCOEValues() async throws -> [Int32] { [] }
    func getDistinctStatuses() async throws -> [String] { [] }
    func stableIdExists(_ stableId: String) async throws -> Bool { false }
    func generateNextNaturalKey(manufacturer: String, sku: String) async throws -> String { "\(manufacturer)-\(sku)-0" }
}
