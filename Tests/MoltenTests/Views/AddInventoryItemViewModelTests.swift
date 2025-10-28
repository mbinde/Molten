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
        // Arrange & Act
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: "bullseye-001-0",
            inventoryTrackingService: mockInventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Assert
        #expect(viewModel.stableId == "bullseye-001-0")
    }

    // MARK: - Validation Tests

    @Test("Should validate required fields")
    func testValidation() async throws {
        // Arrange
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        mockGlassItemRepo.items = [
            GlassItemModel(stable_id: "bullseye-001-0", manufacturer: "bullseye", sku: "001", variant: 0, name: "Clear", coe: 90, type: .rod),
            GlassItemModel(stable_id: "bullseye-254-0", manufacturer: "bullseye", sku: "254", variant: 0, name: "Red", coe: 90, type: .rod)
        ]

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let item = GlassItemModel(stable_id: "bullseye-001-0", manufacturer: "bullseye", sku: "001", variant: 0, name: "Clear", coe: 90, type: .rod)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        // Act
        viewModel.selectGlassItem(item)

        // Assert
        #expect(viewModel.selectedGlassItem?.stable_id == "bullseye-001-0")
        #expect(viewModel.stableId == "bullseye-001-0")
    }

    @Test("Should clear selection")
    func testClearSelection() async throws {
        // Arrange
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let item = GlassItemModel(stable_id: "bullseye-001-0", manufacturer: "bullseye", sku: "001", variant: 0, name: "Clear", coe: 90, type: .rod)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let item = GlassItemModel(stable_id: "bullseye-001-0", manufacturer: "bullseye", sku: "001", variant: 0, name: "Clear", coe: 90, type: .rod)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
            glassItemRepository: mockGlassItemRepo
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
        #expect(mockInventoryService.addInventoryCalled == true)
        #expect(mockInventoryService.lastAddedQuantity == 5.0)
        #expect(mockInventoryService.lastAddedType == "rod")
        #expect(mockInventoryService.lastAddedStableId == "bullseye-001-0")
        #expect(mockInventoryService.lastAddedLocation == "Shelf A")
    }

    @Test("Should not save with empty stableId")
    func testSaveInvalidStableId() async throws {
        // Arrange
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.stableId = ""
        viewModel.quantity = "5.0"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(mockInventoryService.addInventoryCalled == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Should not save with invalid quantity")
    func testSaveInvalidQuantity() async throws {
        // Arrange
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let item = GlassItemModel(stable_id: "bullseye-001-0", manufacturer: "bullseye", sku: "001", variant: 0, name: "Clear", coe: 90, type: .rod)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.selectGlassItem(item)
        viewModel.quantity = "abc"

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == false)
        #expect(mockInventoryService.addInventoryCalled == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Should handle save errors")
    func testSaveError() async throws {
        // Arrange
        let mockInventoryService = MockInventoryTrackingService()
        mockInventoryService.shouldThrowError = true

        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let item = GlassItemModel(stable_id: "bullseye-001-0", manufacturer: "bullseye", sku: "001", variant: 0, name: "Clear", coe: 90, type: .rod)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.selectGlassItem(item)
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
        let mockInventoryService = MockInventoryTrackingService()
        let mockGlassItemRepo = MockGlassItemRepositoryForViewModel()
        let item = GlassItemModel(stable_id: "bullseye-001-0", manufacturer: "bullseye", sku: "001", variant: 0, name: "Clear", coe: 90, type: .rod)

        let viewModel = AddInventoryItemViewModel(
            prefilledNaturalKey: nil,
            inventoryTrackingService: mockInventoryService,
            glassItemRepository: mockGlassItemRepo
        )

        viewModel.selectGlassItem(item)
        viewModel.quantity = "5.0"
        viewModel.location = ""  // Empty location

        // Act
        let result = await viewModel.save()

        // Assert
        #expect(result == true)
        #expect(mockInventoryService.lastAddedLocation == nil)
    }
}

// MARK: - Mock Services

final class MockInventoryTrackingService: InventoryTrackingService, @unchecked Sendable {
    var addInventoryCalled = false
    var shouldThrowError = false
    var lastAddedQuantity: Double?
    var lastAddedType: String?
    var lastAddedStableId: String?
    var lastAddedLocation: String?

    private let inventoryRepository: InventoryRepository
    private let glassItemRepository: GlassItemRepository
    private let locationRepository: LocationRepository

    init() {
        self.inventoryRepository = MockInventoryRepository()
        self.glassItemRepository = MockGlassItemRepositoryForViewModel()
        self.locationRepository = MockLocationRepository()
    }

    func addInventory(quantity: Double, type: String, toItem itemStableId: String, atLocation locationName: String?) async throws -> InventoryModel {
        addInventoryCalled = true
        lastAddedQuantity = quantity
        lastAddedType = type
        lastAddedStableId = itemStableId
        lastAddedLocation = locationName

        if shouldThrowError {
            throw NSError(domain: "MockInventoryTrackingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }

        return InventoryModel(item_stable_id: itemStableId, type: type, quantity: quantity)
    }

    // Required protocol methods
    var inventoryRepo: InventoryRepository { inventoryRepository }
    var glassItemRepo: GlassItemRepository { glassItemRepository }
    var locationRepo: LocationRepository { locationRepository }
}

final class MockCatalogService: CatalogService, @unchecked Sendable {
    var items: [GlassItemModel] = []

    private var _glassItemRepository: MockGlassItemRepositoryForViewModel
    private let inventoryRepository: InventoryRepository
    private let purchaseRecordRepository: PurchaseRecordRepository

    init() {
        self._glassItemRepository = MockGlassItemRepositoryForViewModel()
        self.inventoryRepository = MockInventoryRepository()
        self.purchaseRecordRepository = MockPurchaseRecordRepository()
    }

    // Required protocol methods
    var glassItemRepo: GlassItemRepository {
        // Update the mock repository with items before returning
        _glassItemRepository.items = items
        return _glassItemRepository
    }
    var inventoryRepo: InventoryRepository { inventoryRepository }
    var purchaseRecordRepo: PurchaseRecordRepository { purchaseRecordRepository }
}

// Mock glass item repository for testing
final class MockGlassItemRepositoryForViewModel: GlassItemRepository, @unchecked Sendable {
    var items: [GlassItemModel] = []

    func fetchItems(matching query: String?) async throws -> [GlassItemModel] {
        return items
    }

    // Other required methods with minimal implementation
    func fetchItem(naturalKey: String) async throws -> GlassItemModel? { nil }
    func fetchItem(manufacturer: String, sku: String, variant: Int) async throws -> GlassItemModel? { nil }
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel { item }
    func updateItem(_ item: GlassItemModel) async throws {}
    func deleteItem(naturalKey: String) async throws {}
    func searchItems(query: String, filters: [String: Any]) async throws -> [GlassItemModel] { [] }
    func getItemsForManufacturer(_ manufacturer: String) async throws -> [GlassItemModel] { [] }
    func getItemsWithCOE(_ coe: Int32) async throws -> [GlassItemModel] { [] }
}
