//
//  InventoryImportServiceTests.swift
//  MoltenTests
//
//  Tests for InventoryImportService with all four import modes
//

import Testing
import Foundation
@testable import Molten

@Suite("Inventory Import Service Tests")
struct InventoryImportServiceTests {

    // MARK: - Test Setup Helpers

    /// Create a test JSON file with sample inventory data
    func createTestImportFile(items: [ImportItem]) throws -> URL {
        let importData = InventoryImportData(
            version: "1.0",
            generated: Date(),
            items: items
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(importData)

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_import_\(UUID().uuidString).json")
        try jsonData.write(to: fileURL)

        return fileURL
    }

    /// Create test import items
    func createTestItems() -> [ImportItem] {
        return [
            ImportItem(
                code: "bullseye-001-0",
                name: "Bullseye Clear",
                manufacturer: "Bullseye",
                coe: "90",
                type: "rod",
                quantity: 10,
                location: "Shelf A"
            ),
            ImportItem(
                code: "spectrum-96-0",
                name: "Spectrum Clear",
                manufacturer: "Spectrum",
                coe: "96",
                type: "rod",
                quantity: 5,
                location: "Shelf B"
            ),
            ImportItem(
                code: "cim-874-0",
                name: "CIM Intense Black",
                manufacturer: "CiM",
                coe: "104",
                type: "stringer",
                quantity: 3,
                location: nil
            )
        ]
    }

    /// Setup service with mock repositories
    func createTestService() -> InventoryImportService {
        RepositoryFactory.configureForTesting()

        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryService = RepositoryFactory.createInventoryTrackingService()
        let locationRepo = RepositoryFactory.createLocationRepository()

        return InventoryImportService(
            catalogService: catalogService,
            inventoryTrackingService: inventoryService,
            locationRepository: locationRepo
        )
    }

    /// Add test glass items to catalog
    func populateTestCatalog() async throws {
        let catalogService = RepositoryFactory.createCatalogService()

        // Create test glass items that match our import data
        _ = try await catalogService.createGlassItem(
            code: "BU-001",
            name: "Bullseye Clear",
            manufacturer: "bullseye",
            description: "Test item",
            coe: "90",
            color_family: nil,
            isTransparent: true,
            isStriking: false,
            tags: []
        )

        _ = try await catalogService.createGlassItem(
            code: "SP-96",
            name: "Spectrum Clear",
            manufacturer: "spectrum",
            description: "Test item",
            coe: "96",
            color_family: nil,
            isTransparent: true,
            isStriking: false,
            tags: []
        )

        _ = try await catalogService.createGlassItem(
            code: "CIM-874",
            name: "CIM Intense Black",
            manufacturer: "cim",
            description: "Test item",
            coe: "104",
            color_family: "black",
            isTransparent: false,
            isStriking: false,
            tags: []
        )
    }

    // MARK: - Import Mode Enum Tests

    @Test("Import mode enum has all cases")
    func testImportModeEnum() {
        #expect(InventoryImportMode.allCases.count == 4)
        #expect(InventoryImportMode.allCases.contains(.eraseAndReplace))
        #expect(InventoryImportMode.allCases.contains(.addNewOnly))
        #expect(InventoryImportMode.allCases.contains(.addAndIncrease))
        #expect(InventoryImportMode.allCases.contains(.askPerItem))
    }

    @Test("Import mode has display properties")
    func testImportModeDisplayProperties() {
        let mode = InventoryImportMode.eraseAndReplace
        #expect(!mode.displayName.isEmpty)
        #expect(!mode.description.isEmpty)
        #expect(!mode.icon.isEmpty)
    }

    // MARK: - Preview Tests

    @Test("Preview import shows correct item count")
    func testPreviewImport() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let preview = try await service.previewImport(from: fileURL)

        #expect(preview.itemCount == 3)
        #expect(preview.version == "1.0")
        #expect(preview.manufacturerBreakdown.count > 0)
    }

    @Test("Preview import shows manufacturer breakdown")
    func testPreviewManufacturerBreakdown() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let preview = try await service.previewImport(from: fileURL)

        // Should have breakdown by manufacturer
        let bullseyeCount = preview.manufacturerBreakdown.first { $0.manufacturer == "Bullseye" }?.count
        #expect(bullseyeCount == 1)
    }

    // MARK: - Erase and Replace Mode Tests

    @Test("Erase and replace mode deletes existing inventory")
    func testEraseAndReplaceDeletesExisting() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let inventoryRepo = RepositoryFactory.createInventoryRepository()

        // Add existing inventory
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Verify existing inventory exists
        let beforeCount = try await inventoryRepo.fetchInventory(matching: nil).count
        #expect(beforeCount == 1)

        // Import with erase mode
        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .eraseAndReplace)

        // All items should be imported (old deleted, new added)
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Should have exactly 3 items now (old one deleted)
        let afterInventory = try await inventoryRepo.fetchInventory(matching: nil)
        #expect(afterInventory.count == 3)

        // Old quantity should be gone, replaced with import quantity
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: "bullseye-001-0", type: "rod")
        #expect(bullseyeInventory.first?.quantity == 10.0)
    }

    // MARK: - Add New Only Mode Tests

    @Test("Add new only mode skips existing items")
    func testAddNewOnlySkipsExisting() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let inventoryRepo = RepositoryFactory.createInventoryRepository()

        // Add one existing inventory item
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Import with add new only mode
        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addNewOnly)

        // Should import 2 new items, skip 1 existing
        #expect(result.successCount == 2)
        #expect(result.skippedCount == 1)

        // Existing item quantity should be unchanged
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: "bullseye-001-0", type: "rod")
        #expect(bullseyeInventory.first?.quantity == 100.0)

        // New items should be added
        let spectrumInventory = try await inventoryRepo.fetchInventory(forItem: "spectrum-96-0", type: "rod")
        #expect(spectrumInventory.first?.quantity == 5.0)
    }

    @Test("Add new only mode imports all items when none exist")
    func testAddNewOnlyImportsAllWhenEmpty() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        // No existing inventory

        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addNewOnly)

        // All items should be imported
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)
    }

    // MARK: - Add and Increase Mode Tests

    @Test("Add and increase mode increases existing quantities")
    func testAddAndIncreaseModeIncreasesQuantities() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let inventoryRepo = RepositoryFactory.createInventoryRepository()

        // Add existing inventory with quantity 100
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Import with add and increase mode (import has quantity 10)
        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addAndIncrease)

        // All items should be imported (1 increased, 2 added)
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Existing item should have quantity increased (100 + 10 = 110)
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: "bullseye-001-0", type: "rod")
        #expect(bullseyeInventory.first?.quantity == 110.0)

        // New items should be added with import quantity
        let spectrumInventory = try await inventoryRepo.fetchInventory(forItem: "spectrum-96-0", type: "rod")
        #expect(spectrumInventory.first?.quantity == 5.0)
    }

    @Test("Add and increase mode adds new items")
    func testAddAndIncreaseModeAddsNewItems() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        // No existing inventory

        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addAndIncrease)

        // All items should be imported as new
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)
    }

    // MARK: - Interactive Ask Per Item Mode Tests

    @Test("Ask per item mode calls delegate for conflicts")
    func testAskPerItemModeCallsDelegate() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let inventoryRepo = RepositoryFactory.createInventoryRepository()

        // Add existing inventory
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Create service and set mock delegate
        let service = createTestService()
        let mockDelegate = MockImportDelegate(action: .skip)
        service.delegate = mockDelegate

        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .askPerItem)

        // Delegate should have been called for the existing item
        #expect(mockDelegate.callCount == 1)

        // Should skip the conflicting item and add the 2 new ones
        #expect(result.successCount == 2)
        #expect(result.skippedCount == 1)
    }

    @Test("Ask per item mode replace action works")
    func testAskPerItemModeReplaceAction() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let inventoryRepo = RepositoryFactory.createInventoryRepository()

        // Add existing inventory
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Create service with delegate that chooses replace
        let service = createTestService()
        let mockDelegate = MockImportDelegate(action: .replace)
        service.delegate = mockDelegate

        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .askPerItem)

        // All items should be imported
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Existing item should be replaced with import quantity
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: "bullseye-001-0", type: "rod")
        #expect(bullseyeInventory.first?.quantity == 10.0)
    }

    @Test("Ask per item mode increase action works")
    func testAskPerItemModeIncreaseAction() async throws {
        RepositoryFactory.configureForTesting()
        try await populateTestCatalog()

        let inventoryRepo = RepositoryFactory.createInventoryRepository()

        // Add existing inventory
        let existingInventory = InventoryModel(
            id: UUID(),
            item_stable_id: "bullseye-001-0",
            type: "rod",
            quantity: 100.0,
            date_added: Date(),
            date_modified: Date()
        )
        _ = try await inventoryRepo.createInventory(existingInventory)

        // Create service with delegate that chooses increase
        let service = createTestService()
        let mockDelegate = MockImportDelegate(action: .increase)
        service.delegate = mockDelegate

        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .askPerItem)

        // All items should be imported
        #expect(result.successCount == 3)
        #expect(result.skippedCount == 0)

        // Existing item should have increased quantity (100 + 10 = 110)
        let bullseyeInventory = try await inventoryRepo.fetchInventory(forItem: "bullseye-001-0", type: "rod")
        #expect(bullseyeInventory.first?.quantity == 110.0)
    }

    // MARK: - Error Handling Tests

    @Test("Import fails with invalid JSON")
    func testImportFailsWithInvalidJSON() async throws {
        RepositoryFactory.configureForTesting()

        let service = createTestService()

        // Create invalid JSON file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("invalid.json")
        try "invalid json".write(to: fileURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        await #expect(throws: InventoryImportError.self) {
            try await service.importInventory(from: fileURL, mode: .addNewOnly)
        }
    }

    @Test("Import handles item not found error")
    func testImportHandlesItemNotFound() async throws {
        RepositoryFactory.configureForTesting()
        // Don't populate catalog - items won't be found

        let service = createTestService()
        let items = createTestItems()
        let fileURL = try createTestImportFile(items: items)

        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let result = try await service.importInventory(from: fileURL, mode: .addNewOnly)

        // All items should fail (not found in catalog)
        #expect(result.successCount == 0)
        #expect(result.failedItems.count == 3)
    }
}

// MARK: - Mock Delegate

@MainActor
class MockImportDelegate: InventoryImportDelegate {
    let action: ImportItemAction
    var callCount = 0

    init(action: ImportItemAction) {
        self.action = action
    }

    func shouldImportItem(_ item: ImportItem, existing: InventoryModel) async -> ImportItemAction {
        callCount += 1
        return action
    }
}
