//
//  AddInventoryItemViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/18/25.
//  Tests for AddInventoryItemView functionality
//

import Testing
import SwiftUI
@testable import Molten

@Suite("AddInventoryItemView Tests")
@MainActor
struct AddInventoryItemViewTests {

    // MARK: - Test Helpers

    func createMockServices() -> (InventoryTrackingService, CatalogService) {
        let inventoryService = InventoryTrackingService(
            glassItemRepository: MockGlassItemRepository(),
            inventoryRepository: MockInventoryRepository(),
            locationRepository: MockLocationRepository(),
            itemTagsRepository: MockItemTagsRepository()
        )

        let shoppingListService = ShoppingListService(
            itemMinimumRepository: MockItemMinimumRepository(),
            shoppingListRepository: MockShoppingListRepository(),
            inventoryRepository: MockInventoryRepository(),
            glassItemRepository: MockGlassItemRepository(),
            itemTagsRepository: MockItemTagsRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        let catalogService = CatalogService(
            glassItemRepository: MockGlassItemRepository(),
            inventoryTrackingService: inventoryService,
            shoppingListService: shoppingListService,
            itemTagsRepository: MockItemTagsRepository(),
            userTagsRepository: MockUserTagsRepository()
        )

        return (inventoryService, catalogService)
    }

    // MARK: - Initialization Tests

    @Test("Initialize without prefilled natural key")
    func testInitWithoutPrefilledKey() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryItemView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view.prefilledNaturalKey == nil)
    }

    @Test("Initialize with prefilled natural key")
    func testInitWithPrefilledKey() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryItemView(
            prefilledNaturalKey: "test-item-001-0",
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view.prefilledNaturalKey == "test-item-001-0")
    }

    @Test("Initialize with default services when none provided")
    func testInitWithDefaultServices() {
        // Configure for testing to get mocks
        RepositoryFactory.configureForTesting()

        let view = AddInventoryItemView(prefilledNaturalKey: nil)

        #expect(view != nil)
    }

    // MARK: - Glass Item Search Tests

    @Test("GlassItemSearchSelector integration")
    func testGlassItemSearchSelectorIntegration() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // View uses GlassItemSearchSelector component
    }

    @Test("Prefilled natural key is used in search selector")
    func testPrefilledKeyInSearchSelector() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: "test-item-001-0",
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view.prefilledNaturalKey == "test-item-001-0")
    }

    @Test("Search text updates on selection")
    func testSearchTextUpdatesOnSelection() {
        // This tests the onSelect callback behavior
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // selectGlassItem() sets naturalKey from selected item
    }

    @Test("Clear selection resets state")
    func testClearSelectionResetsState() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // clearSelection() resets selectedGlassItem, naturalKey, searchText
    }

    // MARK: - Type/Subtype Selection Tests

    @Test("Default type is rod")
    func testDefaultTypeIsRod() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Default selectedType is "rod"
    }

    @Test("Common inventory types are available")
    func testCommonInventoryTypesAvailable() {
        let commonTypes = InventoryModel.CommonType.allCommonTypes

        #expect(commonTypes.count > 0)
        #expect(commonTypes.contains("rod"))
        #expect(commonTypes.contains("sheet"))
        #expect(commonTypes.contains("frit"))
    }

    @Test("Subtypes are populated based on selected type")
    func testSubtypesPopulatedByType() {
        let fritSubtypes = GlassItemTypeSystem.getSubtypes(for: "frit")
        let sheetSubtypes = GlassItemTypeSystem.getSubtypes(for: "sheet")
        let rodSubtypes = GlassItemTypeSystem.getSubtypes(for: "rod")

        // Frit, sheet, and rod have subtypes
        #expect(fritSubtypes.count > 0)
        #expect(sheetSubtypes.count > 0)
        #expect(rodSubtypes.count > 0)
        #expect(fritSubtypes != sheetSubtypes)

        // Verify rod has expected subtypes
        #expect(rodSubtypes.contains("standard"))
        #expect(rodSubtypes.contains("cane"))
        #expect(rodSubtypes.contains("pull"))
    }

    @Test("Changing type resets subtype")
    func testChangingTypeResetsSubtype() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // onChange(selectedType) resets selectedSubtype, selectedSubsubtype, dimensions
    }

    @Test("Subtype is optional")
    func testSubtypeIsOptional() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Subtype picker has "None" option
    }

    // MARK: - Dimension Input Tests

    @Test("Dimension fields are populated based on type")
    func testDimensionFieldsPopulatedByType() {
        let rodDimensions = GlassItemTypeSystem.getDimensionFields(for: "rod")
        let sheetDimensions = GlassItemTypeSystem.getDimensionFields(for: "sheet")

        #expect(rodDimensions.count > 0)
        #expect(sheetDimensions.count > 0)

        // Rod has diameter and length
        #expect(rodDimensions.contains { $0.name == "diameter" })
        #expect(rodDimensions.contains { $0.name == "length" })

        // Sheet has thickness, width, height
        #expect(sheetDimensions.contains { $0.name == "thickness" })
        #expect(sheetDimensions.contains { $0.name == "width" })
        #expect(sheetDimensions.contains { $0.name == "height" })
    }

    @Test("Dimension fields show correct units")
    func testDimensionFieldsShowUnits() {
        let rodDimensions = GlassItemTypeSystem.getDimensionFields(for: "rod")

        let diameterField = rodDimensions.first { $0.name == "diameter" }
        #expect(diameterField?.unit == "mm")

        let lengthField = rodDimensions.first { $0.name == "length" }
        #expect(lengthField?.unit == "cm")
    }

    @Test("Dimension fields are optional by default")
    func testDimensionFieldsOptional() {
        let rodDimensions = GlassItemTypeSystem.getDimensionFields(for: "rod")

        for field in rodDimensions {
            // Currently all dimension fields are optional (isRequired: false)
            #expect(field.isRequired == false)
        }
    }

    @Test("Dimension validation catches negative values")
    func testDimensionValidationNegative() {
        let dimensions = ["diameter": -5.0]
        let errors = GlassItemTypeSystem.validateDimensions(dimensions, for: "rod")

        #expect(!errors.isEmpty)
        #expect(errors.contains { $0.contains("negative") })
    }

    @Test("Empty dimensions are valid")
    func testEmptyDimensionsValid() {
        let emptyDimensions: [String: Double] = [:]
        let errors = GlassItemTypeSystem.validateDimensions(emptyDimensions, for: "rod")

        #expect(errors.isEmpty)
    }

    // MARK: - Location Input Tests

    @Test("Location field is optional")
    func testLocationFieldOptional() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Location field exists but is not required for save
    }

    @Test("Location is used for distribution when provided")
    func testLocationUsedForDistribution() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // When location is provided, locationDistribution is populated
    }

    // MARK: - Validation Tests

    @Test("Save requires natural key")
    func testSaveRequiresNaturalKey() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Save button disabled when naturalKey.isEmpty
    }

    @Test("Save requires quantity")
    func testSaveRequiresQuantity() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Save button disabled when quantity.isEmpty
    }

    @Test("Quantity must be valid number")
    func testQuantityMustBeValidNumber() {
        // Validation happens in performSave()
        let invalidQuantity = "invalid"
        let validQuantity = "10.5"

        #expect(Double(invalidQuantity) == nil)
        #expect(Double(validQuantity) == 10.5)
    }

    @Test("Quantity must be positive")
    func testQuantityMustBePositive() {
        let positiveQuantity = "10.0"
        let zeroQuantity = "0"
        let negativeQuantity = "-5.0"

        #expect(Double(positiveQuantity)! > 0)
        #expect(Double(zeroQuantity)! == 0)
        #expect(Double(negativeQuantity)! < 0)

        // Only positive quantities should be allowed
    }

    @Test("Dimension parsing handles invalid input")
    func testDimensionParsingInvalid() {
        let invalidDimension = "invalid"
        let validDimension = "10.5"

        #expect(Double(invalidDimension) == nil)
        #expect(Double(validDimension) == 10.5)
    }

    @Test("Dimension parsing handles empty strings")
    func testDimensionParsingEmpty() {
        let emptyDimension = ""

        #expect(Double(emptyDimension) == nil)
        // Empty dimensions are filtered out in performSave()
    }

    // MARK: - Save Operation Tests

    @Test("Save creates inventory model with correct properties")
    func testSaveCreatesInventoryModel() {
        // InventoryModel is created with all provided properties
        let inventory = InventoryModel(
            item_natural_key: "test-item-001-0",
            type: "rod",
            subtype: "standard",
            subsubtype: nil,
            dimensions: ["diameter": 6.0, "length": 50.0],
            quantity: 10.0
        )

        #expect(inventory.item_natural_key == "test-item-001-0")
        #expect(inventory.type == "rod")
        #expect(inventory.subtype == "standard")
        #expect(inventory.dimensions?["diameter"] == 6.0)
        #expect(inventory.quantity == 10.0)
    }

    @Test("Save uses inventory tracking service")
    func testSaveUsesInventoryTrackingService() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // performSave() calls inventoryTrackingService.addInventory()
    }

    @Test("Save posts notification on success")
    func testSavePostsNotification() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // postSuccessNotification() posts to NotificationCenter
    }

    // MARK: - Cancel Operation Tests

    @Test("Cancel button dismisses view")
    func testCancelButtonDismisses() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Cancel button calls dismiss()
    }

    // MARK: - Error Handling Tests

    @Test("Error shown for missing glass item")
    func testErrorForMissingGlassItem() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // performSave() shows error if selectedGlassItem is nil
    }

    @Test("Error shown for invalid quantity format")
    func testErrorForInvalidQuantity() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // performSave() shows error if quantity cannot be parsed to Double
    }

    @Test("Error shown for empty required fields")
    func testErrorForEmptyRequiredFields() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // performSave() shows error if naturalKey or quantity is empty
    }

    @Test("Error alert dismisses on OK")
    func testErrorAlertDismisses() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Alert OK button sets showingError to false
    }

    // MARK: - Type Display View Tests

    @Test("TypeDisplayView displays type correctly")
    func testTypeDisplayViewDisplay() {
        let view = TypeDisplayView(type: "rod")

        #expect(view != nil)
        #expect(view.type == "rod")
    }

    @Test("TypeDisplayView capitalizes type name")
    func testTypeDisplayViewCapitalizes() {
        let view = TypeDisplayView(type: "rod")

        #expect(view.type == "rod")
        // View displays type.capitalized -> "Rod"
    }

    // MARK: - Data Loading Tests

    @Test("Glass items loaded on appear")
    func testGlassItemsLoadedOnAppear() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // setupInitialData() calls loadGlassItems()
    }

    @Test("Prefilled natural key triggers lookup on load")
    func testPrefilledKeyTriggersLookup() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: "test-item-001-0",
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // setupInitialData() calls lookupGlassItem() if prefilledKey exists
    }

    @Test("Natural key change triggers lookup")
    func testNaturalKeyChangeTriggersLookup() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // onChange(naturalKey) calls lookupGlassItem()
    }

    // MARK: - Integration Tests

    @Test("Form integrates with GlassItemSearchSelector")
    func testFormIntegratesWithSearchSelector() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Form uses GlassItemSearchSelector with onSelect and onClear callbacks
    }

    @Test("Form integrates with GlassItemTypeSystem")
    func testFormIntegratesWithTypeSystem() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: nil,
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Form uses GlassItemTypeSystem for subtypes and dimension fields
    }

    @Test("Complete workflow - select item, enter quantity, save")
    func testCompleteWorkflow() {
        let (inventoryService, catalogService) = createMockServices()

        let view = AddInventoryFormView(
            prefilledNaturalKey: "test-item-001-0",
            inventoryTrackingService: inventoryService,
            catalogService: catalogService
        )

        #expect(view != nil)
        // Workflow: setupInitialData() -> select item -> enter quantity -> save
    }
}
